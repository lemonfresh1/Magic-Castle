# SyncManager.gd - Lightweight sync orchestration layer
# Location: res://Pyramids/scripts/autoloads/SyncManager.gd
# Purpose: Central hub for all game data syncing with debouncing/throttling

extends Node

# === SIGNALS ===
signal sync_started(system: String)
signal sync_completed(system: String, success: bool)
signal sync_failed(system: String, error: String)
signal batch_synced(system: String, count: int)

# === STATE ===
var is_syncing: bool = false
var pending_syncs: Dictionary = {}  # system_name -> pending data
var last_sync_times: Dictionary = {}  # system_name -> timestamp

# Debounce timers
var debounce_timers: Dictionary = {}  # key -> Timer

# === CONFIGURATION ===
const SYNC_COOLDOWN_MS: int = 1000  # Minimum time between syncs for same system
const DEBOUNCE_DELAY_MS: int = 1000  # Wait time for debouncing

# === DEBUG ===
var debug_enabled: bool = true

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[SyncManager] %s" % message)

func _ready() -> void:
	debug_log("SyncManager initialized")
	
	# Connect to ProfileManager signals for monitoring
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.sync_completed.connect(_on_profile_sync_completed)
		pm.sync_failed.connect(_on_profile_sync_failed)

# === PROFILE SYNCING ===

func queue_profile_update(data: Dictionary) -> void:
	"""Queue a profile update (immediate, no debouncing)"""
	debug_log("Queueing profile update: %s" % str(data.keys()))
	
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm._queue_update(data)
	else:
		push_error("ProfileManager not found!")

# === STATS SYNCING ===

func queue_stats_update(stats_data: Dictionary, debounce: bool = true) -> void:
	"""Queue stats update with optional debouncing"""
	debug_log("Queueing stats update (debounce: %s)" % debounce)
	
	if debounce:
		_debounced_sync("stats", stats_data, func():
			_sync_stats_immediate(stats_data)
		)
	else:
		_sync_stats_immediate(stats_data)

func _sync_stats_immediate(stats_data: Dictionary) -> void:
	"""Sync stats immediately to database"""
	debug_log("Syncing stats immediately")
	
	if not _can_sync("stats"):
		debug_log("Stats sync throttled (too soon)")
		return
	
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.sync_game_data({"stats_update": stats_data})
		last_sync_times["stats"] = Time.get_ticks_msec()
		sync_started.emit("stats")
	else:
		push_error("ProfileManager not found!")

# === INVENTORY SYNCING ===

func queue_inventory_update(inventory_data: Dictionary, debounce: bool = false) -> void:
	"""Queue inventory update (usually immediate for purchases)"""
	debug_log("Queueing inventory update")
	
	if debounce:
		_debounced_sync("inventory", inventory_data, func():
			_sync_inventory_immediate(inventory_data)
		)
	else:
		_sync_inventory_immediate(inventory_data)

func _sync_inventory_immediate(inventory_data: Dictionary) -> void:
	"""Sync inventory immediately"""
	debug_log("Syncing inventory immediately")
	
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.sync_game_data({"inventory_update": inventory_data})
		last_sync_times["inventory"] = Time.get_ticks_msec()
		sync_started.emit("inventory")

# === ACHIEVEMENTS SYNCING ===

func queue_achievement_update(achievement_data: Dictionary) -> void:
	"""Queue achievement unlock/claim (immediate, no batching)"""
	debug_log("Queueing achievement update: %s" % achievement_data.get("achievement_id", "unknown"))
	
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		# Call directly, bypass batch queue
		pm._sync_achievement_to_supabase(achievement_data)
		last_sync_times["achievements"] = Time.get_ticks_msec()
		sync_started.emit("achievements")
	else:
		push_error("ProfileManager not found!")

# === MISSIONS SYNCING ===

func queue_mission_update(mission_data: Dictionary, debounce: bool = true) -> void:
	"""Queue mission progress update"""
	debug_log("Queueing mission update")
	
	if debounce:
		_debounced_sync("missions", mission_data, func():
			_sync_missions_immediate(mission_data)
		)
	else:
		_sync_missions_immediate(mission_data)

func _sync_missions_immediate(mission_data: Dictionary) -> void:
	"""Sync missions immediately"""
	debug_log("Syncing missions immediately")
	
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.sync_game_data({"mission_update": mission_data})
		last_sync_times["missions"] = Time.get_ticks_msec()
		sync_started.emit("missions")

# === MULTIPLAYER STATS SYNCING ===

func queue_multiplayer_stats_update(mp_data: Dictionary) -> void:
	"""Queue multiplayer stats (sync after each match)"""
	debug_log("Queueing multiplayer stats update")
	
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.sync_game_data({"mp_stats_update": mp_data})
		last_sync_times["multiplayer"] = Time.get_ticks_msec()
		sync_started.emit("multiplayer")

# === HELPER FUNCTIONS ===

func _can_sync(system: String) -> bool:
	"""Check if enough time has passed since last sync"""
	if not last_sync_times.has(system):
		return true
	
	var elapsed = Time.get_ticks_msec() - last_sync_times[system]
	return elapsed >= SYNC_COOLDOWN_MS

func _debounced_sync(key: String, data: Dictionary, callback: Callable) -> void:
	"""Debounce a sync operation - waits for operations to stop before syncing"""
	
	# Cancel existing timer if any
	if debounce_timers.has(key):
		var timer = debounce_timers[key]
		timer.stop()
		timer.queue_free()
	
	# Store pending data (merge with existing if any)
	if pending_syncs.has(key):
		pending_syncs[key].merge(data, true)
	else:
		pending_syncs[key] = data.duplicate()
	
	# Create new debounce timer
	var timer = Timer.new()
	timer.name = "DebounceTimer_%s" % key
	timer.wait_time = DEBOUNCE_DELAY_MS / 1000.0
	timer.one_shot = true
	timer.timeout.connect(func():
		callback.call()
		debounce_timers.erase(key)
		pending_syncs.erase(key)
		timer.queue_free()
	)
	
	add_child(timer)
	debounce_timers[key] = timer
	timer.start()
	
	debug_log("Debouncing %s (%.1fs)" % [key, timer.wait_time])

func _throttled_sync(key: String, interval_ms: int, callback: Callable) -> bool:
	"""Throttle a sync operation - limits frequency of syncs"""
	if not last_sync_times.has(key):
		last_sync_times[key] = 0
	
	var elapsed = Time.get_ticks_msec() - last_sync_times[key]
	if elapsed >= interval_ms:
		last_sync_times[key] = Time.get_ticks_msec()
		callback.call()
		return true
	
	debug_log("Throttled %s (too soon: %dms < %dms)" % [key, elapsed, interval_ms])
	return false

# === BULK OPERATIONS ===

func force_sync_all() -> void:
	"""Force immediate sync of all pending data"""
	debug_log("Force syncing all systems...")
	
	# Trigger any pending debounced syncs
	for key in debounce_timers.keys():
		var timer = debounce_timers[key]
		timer.stop()
		timer.timeout.emit()  # Trigger callback immediately
	
	# Force ProfileManager sync
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.force_sync()

func cancel_pending_syncs() -> void:
	"""Cancel all pending debounced syncs"""
	debug_log("Cancelling all pending syncs")
	
	for key in debounce_timers.keys():
		var timer = debounce_timers[key]
		timer.stop()
		timer.queue_free()
	
	debounce_timers.clear()
	pending_syncs.clear()

# === SIGNAL HANDLERS ===

func _on_profile_sync_completed() -> void:
	debug_log("Profile sync completed")
	is_syncing = false
	# Emit completion for all systems that were in the batch
	for system in last_sync_times.keys():
		sync_completed.emit(system, true)

func _on_profile_sync_failed(error: String) -> void:
	debug_log("Profile sync failed: %s" % error)
	is_syncing = false
	# Emit failure for all systems
	for system in last_sync_times.keys():
		sync_failed.emit(system, error)

# === STATS & MONITORING ===

func get_sync_status() -> Dictionary:
	"""Get current sync status for debugging"""
	return {
		"is_syncing": is_syncing,
		"pending_systems": pending_syncs.keys(),
		"last_sync_times": last_sync_times,
		"active_debounces": debounce_timers.keys()
	}

func get_stats() -> Dictionary:
	"""Get sync statistics"""
	return {
		"total_systems": last_sync_times.size(),
		"pending_debounces": debounce_timers.size(),
		"pending_data_keys": pending_syncs.size()
	}

# === LIFECYCLE ===

func _notification(what: int) -> void:
	"""Handle system notifications"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		debug_log("App closing - forcing final sync")
		force_sync_all()
