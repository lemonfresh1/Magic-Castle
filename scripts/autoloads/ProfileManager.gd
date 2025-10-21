# ProfileManager.gd - Complete profile management with Supabase sync
# Location: res://Pyramids/scripts/autoloads/ProfileManager.gd
# Last Updated: Fixed script structure and sync issues

extends Node

# === SIGNALS ===
signal profile_loaded(profile_data: Dictionary)
signal profile_created(profile_data: Dictionary)
signal profile_updated(field: String, value: Variant)
signal sync_completed()
signal sync_failed(error: String)
signal display_name_changed(new_name: String)

# === PROFILE DATA ===
var profile: Dictionary = {}
var is_loaded: bool = false
var is_syncing: bool = false
var user_id: String = ""
var is_anonymous: bool = true

# === SYNC MANAGEMENT ===
var sync_queue: Array[Dictionary] = []
var sync_timer: Timer
var sync_retry_count: int = 0
const MAX_SYNC_RETRIES: int = 3
const SYNC_INTERVAL: float = 5.0

# === OFFLINE CACHE ===
const PROFILE_CACHE_PATH = "user://profile_cache.save"
var offline_mode: bool = false

# === DEBUG ===
var debug_enabled: bool = true

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[ProfileManager] %s" % message)

func _ready():
	_setup_sync_timer()
	_connect_signals()
	# Don't load cache on startup - wait for authentication
	
	# Connect to game signals for sync triggers
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("game_over"):
			signal_bus.game_over.connect(_on_game_over)

func _setup_sync_timer() -> void:
	sync_timer = Timer.new()
	sync_timer.name = "SyncTimer"
	sync_timer.wait_time = SYNC_INTERVAL
	sync_timer.timeout.connect(_process_sync_queue)
	add_child(sync_timer)

func _connect_signals() -> void:
	# Connect to SupabaseManager auth events
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.authenticated.connect(_on_authenticated)
		supabase.profile_loaded.connect(_on_profile_loaded)
		supabase.connection_failed.connect(_on_connection_failed)

# === AUTHENTICATION HANDLERS ===

func _on_authenticated(user_data: Dictionary) -> void:
	"""Handle successful authentication"""
	debug_log("Authenticated: %s" % user_data.get("id", "unknown"))
	
	user_id = user_data.get("id", "")
	
	# Check if anonymous user
	is_anonymous = user_data.get("is_anonymous", false)
	if not is_anonymous and user_data.has("email"):
		is_anonymous = user_data.get("email", "").is_empty()
	
	debug_log("User ID set to: %s (anonymous: %s)" % [user_id, is_anonymous])
	
	# SupabaseManager will handle profile check/creation
	# We'll get notified via _on_profile_loaded

func _on_profile_loaded(profile_data: Dictionary) -> void:
	"""Handle profile data from SupabaseManager"""
	debug_log("Profile data received: %s" % profile_data.get("display_name", "Unknown"))
	
	# Store profile data
	profile = profile_data.duplicate()
	is_loaded = true
	
	# CRITICAL: Set user_id from profile data
	if profile.has("id"):
		user_id = profile["id"]
		debug_log("User ID set from profile: %s" % user_id)
	else:
		debug_log("WARNING: No ID in profile data!")
	
	# Ensure all expected fields exist with defaults
	_ensure_profile_fields()
	
	# Update last login time
	var current_time = Time.get_datetime_string_from_system()
	profile["last_login_at"] = current_time
	debug_log("Updating last_login_at to: %s" % current_time)
	
	# Queue the update to sync
	_queue_update({
		"last_login_at": current_time,
		"last_sync_at": current_time
	})
	
	# Save to cache
	_save_profile_cache()
	
	# Start sync timer
	sync_timer.start()
	debug_log("Sync timer started (interval: %d seconds)" % SYNC_INTERVAL)
	
	# Force an immediate sync for login time
	_process_sync_queue()
	
	# Emit signal
	profile_loaded.emit(profile)
	if has_node("/root/SignalBus"):
		SignalBus.profile_loaded.emit(profile)

func _on_connection_failed(error: String) -> void:
	"""Handle connection failure - switch to offline mode"""
	debug_log("Connection failed: %s - Entering offline mode" % error)
	offline_mode = true
	_load_cached_profile()

# === PROFILE MANAGEMENT ===

func _ensure_profile_fields() -> void:
	"""Ensure all expected fields exist with proper defaults"""
	var defaults = {
		"id": user_id,
		"username": null,
		"display_name": "Player",
		"mmr": 1000,
		"xp": 0,
		"stars": 0,
		"prestige": 0,
		"auth_provider": "anonymous",
		"is_anonymous": is_anonymous,
		"avatar_id": "avatar_default",
		"banner_id": "banner_default",
		"equipped_frame": null,
		"equipped_title": null,
		"displayed_items": [],
		"stats": {},
		"equipped": {},
		"last_login_at": Time.get_datetime_string_from_system(),
		"last_sync_at": Time.get_datetime_string_from_system()
	}
	
	for key in defaults:
		if not profile.has(key):
			profile[key] = defaults[key]

func create_new_profile(display_name: String = "") -> void:
	"""Create a new profile for current user"""
	if user_id.is_empty():
		push_error("Cannot create profile without user_id")
		return
	
	debug_log("Creating new profile for user: %s" % user_id)
	
	# Generate display name if not provided
	if display_name.is_empty():
		display_name = "Player%d" % (randi() % 9999)
	
	# Create profile data
	profile = {
		"id": user_id,
		"display_name": display_name,
		"username": null,  # Let user set this later
		"mmr": 1000,
		"xp": 0,
		"stars": 0,
		"prestige": 0,
		"auth_provider": "anonymous" if is_anonymous else "email",
		"is_anonymous": is_anonymous,
		"avatar_id": "avatar_default",
		"banner_id": "banner_default",
		"last_login_at": Time.get_datetime_string_from_system()
	}
	
	# Save to Supabase
	if not offline_mode:
		var supabase = get_node("/root/SupabaseManager")
		supabase.insert("pyramids_profiles", profile)
	
	# Mark as loaded and save cache
	is_loaded = true
	_save_profile_cache()
	
	debug_log("Profile created: %s" % display_name)
	profile_created.emit(profile)

# === PROFILE UPDATES ===

func update_display_name(new_name: String) -> bool:
	"""Update display name with validation"""
	# Validate length (1-30 chars as per schema)
	if new_name.length() < 1 or new_name.length() > 30:
		debug_log("Invalid display name length: %d" % new_name.length())
		return false
	
	# Update local profile
	profile["display_name"] = new_name
	
	# Queue sync
	_queue_update({"display_name": new_name})
	
	# Save cache
	_save_profile_cache()
	
	# Emit signals
	profile_updated.emit("display_name", new_name)
	display_name_changed.emit(new_name)
	if has_node("/root/SignalBus"):
		SignalBus.display_name_changed.emit(new_name)
	
	return true

func set_username(username: String) -> bool:
	"""Set username (one-time, cannot be changed)"""
	# Check if already set
	if profile.get("username", null) != null:
		debug_log("Username already set!")
		return false
	
	# Validate length (3-20 chars as per schema)
	if username.length() < 3 or username.length() > 20:
		debug_log("Invalid username length: %d" % username.length())
		return false
	
	# Validate characters (alphanumeric and underscore only)
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if not regex.search(username):
		debug_log("Invalid username characters")
		return false
	
	# Update profile
	profile["username"] = username
	_queue_update({"username": username})
	_save_profile_cache()
	
	profile_updated.emit("username", username)
	return true

func upgrade_anonymous_account(email: String, password: String) -> void:
	"""Upgrade anonymous account to authenticated"""
	if not is_anonymous:
		debug_log("Account is not anonymous")
		return
	
	debug_log("Upgrading anonymous account to email: %s" % email)
	
	# This will be handled by AuthManager
	# Update local state will happen via _on_authenticated callback
	if has_node("/root/AuthManager"):
		var auth_manager = get_node("/root/AuthManager")
		auth_manager.upgrade_anonymous_account(email, password)

# === CUSTOMIZATION ===

func update_avatar(avatar_id: String) -> void:
	"""Update avatar"""
	profile["avatar_id"] = avatar_id
	_queue_update({"avatar_id": avatar_id})
	_save_profile_cache()
	profile_updated.emit("avatar_id", avatar_id)

func update_banner(banner_id: String) -> void:
	"""Update banner"""
	profile["banner_id"] = banner_id
	_queue_update({"banner_id": banner_id})
	_save_profile_cache()
	profile_updated.emit("banner_id", banner_id)

func update_equipped_frame(frame_id: String) -> void:
	"""Update equipped frame"""
	profile["equipped_frame"] = frame_id
	_queue_update({"equipped_frame": frame_id})
	_save_profile_cache()
	profile_updated.emit("equipped_frame", frame_id)

func update_equipped_title(title_id: String) -> void:
	"""Update equipped title"""
	profile["equipped_title"] = title_id
	_queue_update({"equipped_title": title_id})
	_save_profile_cache()
	profile_updated.emit("equipped_title", title_id)

func update_displayed_items(item_ids: Array) -> void:
	"""Update showcase items (max 6)"""
	if item_ids.size() > 6:
		item_ids.resize(6)
	
	profile["displayed_items"] = item_ids
	_queue_update({"displayed_items": item_ids})
	_save_profile_cache()
	profile_updated.emit("displayed_items", item_ids)

# === CURRENCY ===

func add_stars(amount: int) -> void:
	"""Add stars to profile"""
	var current_stars = profile.get("stars", 0)
	profile["stars"] = current_stars + amount
	_queue_update({"stars": profile["stars"]})
	_save_profile_cache()
	profile_updated.emit("stars", profile["stars"])

func spend_stars(amount: int) -> bool:
	"""Attempt to spend stars"""
	var current_stars = profile.get("stars", 0)
	if current_stars >= amount:
		profile["stars"] = current_stars - amount
		_queue_update({"stars": profile["stars"]})
		_save_profile_cache()
		profile_updated.emit("stars", profile["stars"])
		return true
	return false

func add_xp(amount: int) -> void:
	"""Add XP to profile"""
	var current_xp = profile.get("xp", 0)
	profile["xp"] = current_xp + amount
	_queue_update({"xp": profile["xp"]})
	_save_profile_cache()
	profile_updated.emit("xp", profile["xp"])

# === SYNC SYSTEM ===

func _queue_update(data: Dictionary) -> void:
	"""Queue an update for sync"""
	sync_queue.append({
		"timestamp": Time.get_ticks_msec(),
		"data": data
	})
	
	# Force sync if queue is getting large
	if sync_queue.size() >= 10:
		_process_sync_queue()

func _process_sync_queue() -> void:
	"""Process pending sync updates"""
	if sync_queue.is_empty():
		return
	
	if is_syncing or offline_mode or user_id.is_empty():
		if offline_mode:
			debug_log("Offline mode - skipping sync")
		elif user_id.is_empty():
			debug_log("No user ID - skipping sync")
		return
	
	is_syncing = true
	debug_log("Syncing %d updates to Supabase..." % sync_queue.size())
	
	# Merge all updates into one
	var merged_data = {}
	for update in sync_queue:
		merged_data.merge(update.data, true)
	
	# Add sync timestamp
	merged_data["last_sync_at"] = Time.get_datetime_string_from_system()
	
	debug_log("Sync data: %s" % str(merged_data))
	
	# Send to Supabase
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		debug_log("Updating profile ID: %s" % user_id)
		supabase.update("pyramids_profiles", merged_data, {"id": user_id})
		
		# Clear queue optimistically (could wait for response instead)
		sync_queue.clear()
		debug_log("Sync request sent, queue cleared")
		sync_completed.emit()
	else:
		debug_log("ERROR: SupabaseManager not found!")
		sync_failed.emit("SupabaseManager not found")
	
	is_syncing = false

func force_sync() -> void:
	"""Force immediate sync"""
	if not offline_mode:
		_process_sync_queue()

# === OFFLINE CACHE ===

func _save_profile_cache() -> void:
	"""Save profile to local cache"""
	var file = FileAccess.open(PROFILE_CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(profile)
		file.close()
		debug_log("Profile cached locally")

func _load_cached_profile() -> void:
	"""Load profile from cache"""
	if FileAccess.file_exists(PROFILE_CACHE_PATH):
		var file = FileAccess.open(PROFILE_CACHE_PATH, FileAccess.READ)
		if file:
			profile = file.get_var()
			file.close()
			is_loaded = true
			debug_log("Loaded cached profile: %s" % profile.get("display_name", "Unknown"))
			profile_loaded.emit(profile)

func clear_cache() -> void:
	"""Clear all cached data (for logout)"""
	profile.clear()
	is_loaded = false
	user_id = ""
	is_anonymous = true
	sync_queue.clear()
	sync_timer.stop()
	
	# Delete cache file
	if FileAccess.file_exists(PROFILE_CACHE_PATH):
		DirAccess.remove_absolute(PROFILE_CACHE_PATH)
	
	debug_log("Profile cache cleared")

# === SYNC TRIGGERS ===

func _on_game_over(final_score: int) -> void:
	"""Sync profile when game ends"""
	debug_log("Game over - forcing profile sync")
	force_sync()

func _notification(what: int) -> void:
	"""Handle system notifications including app close"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		debug_log("App closing - final sync")
		force_sync()

func sync_game_data(data: Dictionary) -> void:
	"""Queue game-related data for sync (called by other managers)"""
	debug_log("Queueing game data for sync: %s" % str(data))
	_queue_update(data)

# === GETTERS ===

func get_display_name() -> String:
	return profile.get("display_name", "Player")

func get_username() -> String:
	return profile.get("username", "")

func get_mmr() -> int:
	return profile.get("mmr", 1000)

func get_stars() -> int:
	return profile.get("stars", 0)

func get_xp() -> int:
	return profile.get("xp", 0)

func get_prestige() -> int:
	return profile.get("prestige", 0)

func is_username_set() -> bool:
	var username = profile.get("username", null)
	return username != null and username != ""

func get_avatar_id() -> String:
	return profile.get("avatar_id", "avatar_default")

func get_banner_id() -> String:
	return profile.get("banner_id", "banner_default")

func get_profile_data() -> Dictionary:
	return profile.duplicate()
