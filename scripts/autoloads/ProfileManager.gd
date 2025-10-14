# ProfileManager.gd - Core profile management with expansion points
extends Node

signal profile_loaded
signal profile_updated
signal sync_failed(error: String)

# Core data (needed now)
var player_id: String = ""
var player_name: String = "Player"
var is_loaded: bool = false

# Cached profile data
var profile_cache: Dictionary = {}

# Sync queue for batching updates
var sync_queue: Array = []
var sync_timer: Timer

func _ready():
	# Setup sync timer
	sync_timer = Timer.new()
	sync_timer.wait_time = 5.0  # Batch updates every 5 seconds
	sync_timer.timeout.connect(_process_sync_queue)
	add_child(sync_timer)
	sync_timer.start()
	
	# Listen for auth changes
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.authenticated.connect(_on_authenticated)

# === CORE FUNCTIONS (Needed Today) ===

func _on_authenticated(user_data: Dictionary) -> void:
	"""Handle new authentication"""
	player_id = user_data.get("id", "")
	if player_id != "":
		# CHANGE: Don't create profiles at all for now
		# Just set a guest name
		if player_id.begins_with("anon") or true:  # Always skip profile for now
			player_name = "Guest%d" % (randi() % 9999)
			is_loaded = true
			profile_loaded.emit()
			print("[ProfileManager] Anonymous user: %s" % player_name)
			return
		# Original profile loading (disabled for now)
		# load_profile()

func load_profile() -> void:
	"""Load profile from database"""
	if not has_node("/root/SupabaseManager"):
		return
		
	var supabase = get_node("/root/SupabaseManager")
	
	# For now, just get/create basic profile
	var response = await supabase.fetch_data("pyramids_profiles", "id", player_id)
	
	if response and response.size() > 0:
		# Profile exists
		profile_cache = response[0]
		player_name = profile_cache.get("display_name", "Player")
	else:
		# Create new profile
		await create_profile()
	
	is_loaded = true
	profile_loaded.emit()
	print("[ProfileManager] Profile loaded for: %s" % player_name)

func create_profile() -> void:
	"""Create initial profile"""
	var profile_data = {
		"id": player_id,
		"display_name": "Player%d" % (randi() % 9999),
		"level": 1,
		"mmr": 1000,  # Added to match your table
		"stats": {},  # Added to match your table
		"equipped": {}  # Added to match your table
	}
	
	var supabase = get_node("/root/SupabaseManager")
	await supabase.insert_data("pyramids_profiles", profile_data)
	
	profile_cache = profile_data
	player_name = profile_data.display_name

func update_display_name(new_name: String) -> void:
	"""Update player display name"""
	player_name = new_name
	profile_cache["display_name"] = new_name
	
	sync_queue.append({
		"table": "pyramids_profiles",
		"data": {"display_name": new_name},
		"player_id": player_id
	})

# === STATS (Placeholder) ===

func save_stat(stat_id: int, value: int) -> void:
	"""TODO: Save individual stat"""
	print("[ProfileManager] TODO: Save stat %d = %d" % [stat_id, value])
	# sync_queue.append({...})

func increment_stat(stat_id: int, amount: int = 1) -> void:
	"""TODO: Increment a stat by amount"""
	print("[ProfileManager] TODO: Increment stat %d by %d" % [stat_id, amount])

func get_stat(stat_id: int) -> int:
	"""TODO: Get stat value"""
	return 0

# === ACHIEVEMENTS (Placeholder) ===

func update_achievement_progress(achievement_id: int, progress: int) -> void:
	"""TODO: Update achievement progress"""
	print("[ProfileManager] TODO: Update achievement %d progress to %d" % [achievement_id, progress])

func unlock_achievement_tier(achievement_id: int, tier: int) -> void:
	"""TODO: Unlock specific achievement tier"""
	print("[ProfileManager] TODO: Unlock achievement %d tier %d" % [achievement_id, tier])

func get_achievement_progress(achievement_id: int) -> int:
	"""TODO: Get current achievement progress"""
	return 0

# === INVENTORY (Placeholder) ===

func add_item(item_id: int) -> void:
	"""TODO: Add item to inventory"""
	print("[ProfileManager] TODO: Add item %d" % item_id)

func has_item(item_id: int) -> bool:
	"""TODO: Check if player owns item"""
	return false

func get_owned_items() -> Array:
	"""TODO: Get all owned item IDs"""
	return []

# === EQUIPMENT (Placeholder) ===

func equip_item(slot: String, item_id: int) -> void:
	"""TODO: Equip item in slot"""
	print("[ProfileManager] TODO: Equip item %d in slot %s" % [item_id, slot])

func get_equipped_item(slot: String) -> int:
	"""TODO: Get equipped item in slot"""
	return 0

func update_displayed_items(item_ids: Array) -> void:
	"""TODO: Update showcase items"""
	print("[ProfileManager] TODO: Update displayed items: %s" % str(item_ids))

# === CURRENCY (Placeholder) ===

func add_stars(amount: int) -> void:
	"""TODO: Add stars to profile"""
	print("[ProfileManager] TODO: Add %d stars" % amount)
	profile_cache["stars"] = profile_cache.get("stars", 0) + amount
	# Queue sync

func spend_stars(amount: int) -> bool:
	"""TODO: Spend stars if available"""
	var current = profile_cache.get("stars", 0)
	if current >= amount:
		profile_cache["stars"] = current - amount
		# Queue sync
		return true
	return false

func get_stars() -> int:
	"""Get current star balance"""
	return profile_cache.get("stars", 0)

# === PROGRESSION (Placeholder) ===

func update_season_pass_progress(progress: Dictionary) -> void:
	"""TODO: Update season pass progress"""
	print("[ProfileManager] TODO: Update season pass")

func update_daily_mission_progress(mission_id: int, progress: int) -> void:
	"""TODO: Update daily mission progress"""
	print("[ProfileManager] TODO: Update mission %d progress to %d" % [mission_id, progress])

func claim_daily_mission(mission_id: int) -> void:
	"""TODO: Claim daily mission rewards"""
	print("[ProfileManager] TODO: Claim mission %d" % mission_id)

# === SYNC SYSTEM ===

func _process_sync_queue() -> void:
	"""Process any pending updates"""
	if sync_queue.is_empty():
		return
		
	# TODO: Batch process all updates
	print("[ProfileManager] TODO: Sync %d pending updates" % sync_queue.size())
	sync_queue.clear()

func force_sync() -> void:
	"""Force immediate sync"""
	_process_sync_queue()

# === UTILITY ===

func clear_cache() -> void:
	"""Clear local cache (for logout)"""
	profile_cache.clear()
	player_id = ""
	player_name = "Player"
	is_loaded = false

func get_profile_data() -> Dictionary:
	"""Get full profile cache"""
	return profile_cache
