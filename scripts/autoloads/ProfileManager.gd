# ProfileManager.gd - Enhanced profile management with better retry logic and DLQ
# Location: res://Pyramids/scripts/autoloads/ProfileManager.gd
# CHANGES FROM ORIGINAL:
# - Added exponential backoff with jitter
# - Added Dead Letter Queue (DLQ)
# - Added handlers for stats/inventory/achievements/missions
# - Enhanced error categorization

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
const SYNC_INTERVAL: float = 5.0

# === RETRY LOGIC (ENHANCED) ===
var retry_count: int = 0
const MAX_SYNC_RETRIES: int = 5
const BASE_RETRY_DELAY: float = 1.0
const MAX_RETRY_DELAY: float = 60.0

# === DEAD LETTER QUEUE (NEW) ===
var dlq: Array[Dictionary] = []
const MAX_DLQ_SIZE: int = 100

# === OFFLINE CACHE ===
const PROFILE_CACHE_PATH = "user://profile_cache.save"
const DLQ_CACHE_PATH = "user://dlq_cache.save"
var offline_mode: bool = false

# === DEBUG ===
var debug_enabled: bool = true

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[ProfileManager] %s" % message)

func _ready():
	_setup_sync_timer()
	_connect_signals()
	_load_dlq()
	
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
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.authenticated.connect(_on_authenticated)
		supabase.profile_loaded.connect(_on_profile_loaded)
		supabase.connection_failed.connect(_on_connection_failed)

# === AUTHENTICATION HANDLERS ===

func _on_authenticated(user_data: Dictionary) -> void:
	debug_log("Authenticated: %s" % user_data.get("id", "unknown"))
	
	user_id = user_data.get("id", "")
	is_anonymous = user_data.get("is_anonymous", false)
	if not is_anonymous and user_data.has("email"):
		is_anonymous = user_data.get("email", "").is_empty()
	
	debug_log("User ID set to: %s (anonymous: %s)" % [user_id, is_anonymous])

func _on_profile_loaded(profile_data: Dictionary) -> void:
	debug_log("Profile data received: %s" % profile_data.get("display_name", "Unknown"))
	
	profile = profile_data.duplicate()
	is_loaded = true
	
	if profile.has("id"):
		user_id = profile["id"]
		debug_log("User ID set from profile: %s" % user_id)
	
	_ensure_profile_fields()
	
	var current_time = Time.get_datetime_string_from_system()
	profile["last_login_at"] = current_time
	
	_queue_update({
		"last_login_at": current_time,
		"last_sync_at": current_time
	})
	
	_save_profile_cache()
	sync_timer.start()
	_process_sync_queue()
	
	profile_loaded.emit(profile)
	if has_node("/root/SignalBus"):
		SignalBus.profile_loaded.emit(profile)

func _on_connection_failed(error: String) -> void:
	debug_log("Connection failed: %s - Entering offline mode" % error)
	offline_mode = true
	_load_cached_profile()

# === PROFILE MANAGEMENT ===

func _ensure_profile_fields() -> void:
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

# === PROFILE UPDATES ===

func update_display_name(new_name: String) -> bool:
	if new_name.length() < 1 or new_name.length() > 30:
		debug_log("Invalid display name length: %d" % new_name.length())
		return false
	
	profile["display_name"] = new_name
	_queue_update({"display_name": new_name})
	_save_profile_cache()
	
	profile_updated.emit("display_name", new_name)
	display_name_changed.emit(new_name)
	if has_node("/root/SignalBus"):
		SignalBus.display_name_changed.emit(new_name)
	
	return true

func set_username(username: String) -> bool:
	if profile.get("username", null) != null:
		debug_log("Username already set!")
		return false
	
	if username.length() < 3 or username.length() > 20:
		debug_log("Invalid username length: %d" % username.length())
		return false
	
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if not regex.search(username):
		debug_log("Invalid username characters")
		return false
	
	profile["username"] = username
	_queue_update({"username": username})
	_save_profile_cache()
	
	profile_updated.emit("username", username)
	return true

# === CURRENCY & XP ===

func add_stars(amount: int) -> void:
	var current_stars = profile.get("stars", 0)
	profile["stars"] = current_stars + amount
	_queue_update({"stars": profile["stars"]})
	_save_profile_cache()
	profile_updated.emit("stars", profile["stars"])

func spend_stars(amount: int) -> bool:
	var current_stars = profile.get("stars", 0)
	if current_stars >= amount:
		profile["stars"] = current_stars - amount
		_queue_update({"stars": profile["stars"]})
		_save_profile_cache()
		profile_updated.emit("stars", profile["stars"])
		return true
	return false

func add_xp(amount: int) -> void:
	var current_xp = profile.get("xp", 0)
	profile["xp"] = current_xp + amount
	_queue_update({"xp": profile["xp"]})
	_save_profile_cache()
	profile_updated.emit("xp", profile["xp"])

# === SYNC SYSTEM ===

func _queue_update(data: Dictionary) -> void:
	sync_queue.append({
		"timestamp": Time.get_ticks_msec(),
		"data": data,
		"attempt": 0
	})
	
	if sync_queue.size() >= 10:
		_process_sync_queue()

func _process_sync_queue() -> void:
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
	
	# Merge all updates
	var merged_data = {}
	for update in sync_queue:
		merged_data.merge(update.data, true)
	
	# Add sync timestamp
	merged_data["last_sync_at"] = Time.get_datetime_string_from_system()
	
	# Check for system-specific updates
	if merged_data.has("stats_update"):
		var stats_data = merged_data["stats_update"]
		_sync_stats_to_supabase(stats_data)
		merged_data.erase("stats_update")
	
	if merged_data.has("inventory_update"):
		var inventory_data = merged_data["inventory_update"]
		_sync_inventory_to_supabase(inventory_data)
		merged_data.erase("inventory_update")
	
	if merged_data.has("achievement_update"):
		var achievement_data = merged_data["achievement_update"]
		_sync_achievement_to_supabase(achievement_data)
		merged_data.erase("achievement_update")
	
	if merged_data.has("mission_update"):
		var mission_data = merged_data["mission_update"]
		_sync_mission_to_supabase(mission_data)
		merged_data.erase("mission_update")
	
	if merged_data.has("mp_stats_update"):
		var mp_data = merged_data["mp_stats_update"]
		_sync_mp_stats_to_supabase(mp_data)
		merged_data.erase("mp_stats_update")
	
	# Sync remaining profile updates
	if not merged_data.is_empty():
		debug_log("Sync data: %s" % str(merged_data))
		
		if has_node("/root/SupabaseManager"):
			var supabase = get_node("/root/SupabaseManager")
			debug_log("Updating profile ID: %s" % user_id)
			supabase.update("pyramids_profiles", merged_data, {"id": user_id})
			
			sync_queue.clear()
			retry_count = 0
			debug_log("Sync request sent, queue cleared")
			sync_completed.emit()
		else:
			debug_log("ERROR: SupabaseManager not found!")
			_handle_sync_failure("SupabaseManager not found")
	else:
		sync_queue.clear()
		sync_completed.emit()
	
	is_syncing = false

# === SYSTEM-SPECIFIC SYNC (NEW) ===

func _sync_stats_to_supabase(stats_data: Dictionary) -> void:
	"""Sync stats to pyramids_stats table with proper upsert"""
	if user_id.is_empty():
		debug_log("Cannot sync stats - no user_id")
		return
	
	debug_log("Syncing stats to database...")
	
	if not has_node("/root/SupabaseManager"):
		debug_log("SupabaseManager not found")
		return
	
	var supabase = get_node("/root/SupabaseManager")
	stats_data["profile_id"] = user_id
	
	supabase.current_request_type = "stats_upsert"
	
	# Proper Supabase/PostgREST upsert pattern:
	# POST with on_conflict URL parameter + resolution=merge-duplicates header
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_stats?on_conflict=profile_id"
	var headers = supabase._get_db_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: resolution=merge-duplicates,return=representation")
	
	var body = JSON.stringify(stats_data)
	
	# POST with on_conflict URL param = proper upsert
	supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	debug_log("Stats sync request sent (upsert on profile_id)")

func _sync_inventory_to_supabase(inventory_data: Dictionary) -> void:
	debug_log("Syncing inventory to database...")
	# TODO: Implement in Chunk 3

func _sync_achievement_to_supabase(achievement_data: Dictionary) -> void:
	debug_log("Syncing achievement to database...")
	# TODO: Implement in Chunk 4

func _sync_mission_to_supabase(mission_data: Dictionary) -> void:
	debug_log("Syncing mission to database...")
	# TODO: Implement in Chunk 5

func _sync_mp_stats_to_supabase(mp_data: Dictionary) -> void:
	debug_log("Syncing multiplayer stats to database...")
	
	if user_id.is_empty():
		return
	
	if not has_node("/root/SupabaseManager"):
		return
	
	var supabase = get_node("/root/SupabaseManager")
	mp_data["profile_id"] = user_id
	
	supabase.current_request_type = "mp_stats_upsert"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_multiplayer_stats"
	var headers = supabase._get_db_headers()
	headers.append("Prefer: resolution=merge-duplicates,return=representation")
	
	var body = JSON.stringify(mp_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)

# === ENHANCED RETRY LOGIC (NEW) ===

func _handle_sync_failure(error: String) -> void:
	debug_log("Sync failed: %s (attempt %d/%d)" % [error, retry_count, MAX_SYNC_RETRIES])
	
	var error_category = _categorize_error(error)
	
	if error_category == "permanent":
		debug_log("Permanent failure - moving to DLQ")
		_move_queue_to_dlq(error)
		is_syncing = false
		sync_failed.emit(error)
		return
	
	if retry_count >= MAX_SYNC_RETRIES:
		debug_log("Max retries exceeded - moving to DLQ")
		_move_queue_to_dlq("Max retries exceeded")
		retry_count = 0
		is_syncing = false
		sync_failed.emit("Max retries exceeded")
		return
	
	# Calculate backoff with jitter
	var delay = _calculate_backoff_with_jitter(retry_count)
	retry_count += 1
	
	debug_log("Retrying in %.2fs..." % delay)
	await get_tree().create_timer(delay).timeout
	
	is_syncing = false
	_process_sync_queue()

func _calculate_backoff_with_jitter(attempt: int) -> float:
	"""Exponential backoff with full jitter (AWS recommended pattern)"""
	var exponential = BASE_RETRY_DELAY * pow(2.0, attempt)
	var capped = min(exponential, MAX_RETRY_DELAY)
	var jittered = randf() * capped  # Full jitter: random(0, capped)
	return jittered

func _categorize_error(error: String) -> String:
	"""Categorize error as transient, permanent, or auth"""
	var error_lower = error.to_lower()
	
	# Permanent errors
	if "404" in error_lower or "bad request" in error_lower:
		return "permanent"
	
	# Auth errors
	if "401" in error_lower or "unauthorized" in error_lower:
		return "auth"
	
	# Everything else is transient (retry)
	return "transient"

# === DEAD LETTER QUEUE (NEW) ===

func _move_queue_to_dlq(error: String) -> void:
	"""Move failed sync queue items to Dead Letter Queue"""
	for item in sync_queue:
		var dlq_entry = {
			"data": item.data,
			"error": error,
			"timestamp": Time.get_unix_time_from_system(),
			"attempts": item.get("attempt", 0)
		}
		
		dlq.append(dlq_entry)
	
	sync_queue.clear()
	
	# Trim DLQ if too large
	if dlq.size() > MAX_DLQ_SIZE:
		dlq = dlq.slice(-MAX_DLQ_SIZE)
	
	_save_dlq()
	debug_log("Moved %d items to DLQ (total: %d)" % [sync_queue.size(), dlq.size()])

func _save_dlq() -> void:
	"""Persist DLQ to disk"""
	var file = FileAccess.open(DLQ_CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(dlq)
		file.close()

func _load_dlq() -> void:
	"""Load DLQ from disk"""
	if FileAccess.file_exists(DLQ_CACHE_PATH):
		var file = FileAccess.open(DLQ_CACHE_PATH, FileAccess.READ)
		if file:
			dlq = file.get_var()
			file.close()
			debug_log("Loaded %d items from DLQ" % dlq.size())

func retry_dlq_items() -> void:
	"""Manually retry all DLQ items"""
	if dlq.is_empty():
		debug_log("DLQ is empty")
		return
	
	debug_log("Retrying %d DLQ items..." % dlq.size())
	
	for item in dlq:
		_queue_update(item.data)
	
	dlq.clear()
	_save_dlq()
	_process_sync_queue()

func clear_dlq() -> void:
	"""Clear the dead letter queue"""
	dlq.clear()
	_save_dlq()
	debug_log("DLQ cleared")

func get_dlq_size() -> int:
	return dlq.size()

# === PUBLIC SYNC API ===

func force_sync() -> void:
	if not offline_mode:
		_process_sync_queue()

func sync_game_data(data: Dictionary) -> void:
	debug_log("Queueing game data for sync: %s" % str(data.keys()))
	_queue_update(data)

# === OFFLINE CACHE ===

func _save_profile_cache() -> void:
	var file = FileAccess.open(PROFILE_CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(profile)
		file.close()
		debug_log("Profile cached locally")

func _load_cached_profile() -> void:
	if FileAccess.file_exists(PROFILE_CACHE_PATH):
		var file = FileAccess.open(PROFILE_CACHE_PATH, FileAccess.READ)
		if file:
			profile = file.get_var()
			file.close()
			is_loaded = true
			debug_log("Loaded cached profile: %s" % profile.get("display_name", "Unknown"))
			profile_loaded.emit(profile)

func clear_cache() -> void:
	profile.clear()
	is_loaded = false
	user_id = ""
	is_anonymous = true
	sync_queue.clear()
	sync_timer.stop()
	
	if FileAccess.file_exists(PROFILE_CACHE_PATH):
		DirAccess.remove_absolute(PROFILE_CACHE_PATH)
	
	debug_log("Profile cache cleared")

# === LIFECYCLE ===

func _on_game_over(final_score: int) -> void:
	debug_log("Game over - forcing profile sync")
	force_sync()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		debug_log("App closing - final sync")
		force_sync()

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

func get_profile_data() -> Dictionary:
	return profile.duplicate()
