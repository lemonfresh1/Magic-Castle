# MissionManager.gd - Manages daily and weekly missions
# Location: res://Magic-Castle/scripts/autoloads/MissionManager.gd
# Last Updated: Refactored to handle only daily/weekly missions [Date]

extends Node

signal mission_progress_updated(mission_id: String, old_value: int, new_value: int)
signal mission_completed(mission_id: String)
signal missions_refreshed(mission_type: String)

const SAVE_PATH = "user://missions.save"

# Mission definitions - Daily missions
var daily_missions = {
	"daily_play_3": {
		"id": "daily_play_3",
		"type": "daily",
		"title": "Daily Player",
		"description": "Play games:",
		"target": 3,
		"reward_stars": 50,
		"reward_xp": 100,
		"track_stat": "games_played"
	},
	"daily_win_1": {
		"id": "daily_win_1",
		"type": "daily",
		"title": "Daily Winner",
		"description": "Win games:",
		"target": 1,
		"reward_stars": 75,
		"reward_xp": 150,
		"track_stat": "games_won"
	},
	"daily_score_5k": {
		"id": "daily_score_5k",
		"type": "daily",
		"title": "Score Master",
		"description": "Score points:",
		"target": 5000,
		"reward_stars": 60,
		"reward_xp": 120,
		"track_stat": "score_earned"
	}
}

# Weekly missions
var weekly_missions = {
	"weekly_play_20": {
		"id": "weekly_play_20",
		"type": "weekly",
		"title": "Weekly Grinder",
		"description": "Play games:",
		"target": 20,
		"reward_stars": 300,
		"reward_xp": 500,
		"track_stat": "games_played"
	},
	"weekly_win_10": {
		"id": "weekly_win_10",
		"type": "weekly",
		"title": "Weekly Champion",
		"description": "Win games:",
		"target": 10,
		"reward_stars": 400,
		"reward_xp": 600,
		"track_stat": "games_won"
	},
	"weekly_perfect_3": {
		"id": "weekly_perfect_3",
		"type": "weekly",
		"title": "Perfectionist",
		"description": "Perfect clears:",
		"target": 3,
		"reward_stars": 500,
		"reward_xp": 800,
		"track_stat": "perfect_clears"
	}
}

# Progress tracking
var mission_progress = {}  # mission_id -> current_value
var completed_missions = []  # Array of completed mission IDs
var last_daily_reset = ""  # For daily reset
var last_weekly_reset = ""  # For weekly reset (Monday)

func _ready():
	print("MissionManager initializing...")
	load_missions()
	_check_mission_resets()
	
	# Connect to game signals
	if SignalBus:
		SignalBus.game_won.connect(_on_game_won)
		SignalBus.game_lost.connect(_on_game_lost)
		SignalBus.game_over.connect(_on_game_over)
		SignalBus.score_changed.connect(_on_score_changed)
		SignalBus.perfect_clear_achieved.connect(_on_perfect_clear)
	
	print("MissionManager ready")

func _check_mission_resets():
	var today = Time.get_date_string_from_system()
	var datetime = Time.get_datetime_dict_from_system()
	
	# Check daily reset
	if last_daily_reset != today:
		_reset_daily_missions()
		last_daily_reset = today
		save_missions()
	
	# Check weekly reset (Monday = 1)
	# Use a simple week identifier based on the Monday of each week
	var days_since_epoch = Time.get_unix_time_from_system() / 86400  # Convert to days
	var week_number = int(days_since_epoch / 7)  # Simple week number
	var week_string = "week_%d" % week_number
	
	if last_weekly_reset != week_string and datetime.weekday == 1:
		_reset_weekly_missions()
		last_weekly_reset = week_string
		save_missions()

func _reset_daily_missions():
	print("Resetting daily missions")
	for mission_id in daily_missions:
		mission_progress[mission_id] = 0
		if mission_id in completed_missions:
			completed_missions.erase(mission_id)
	missions_refreshed.emit("daily")

func _reset_weekly_missions():
	print("Resetting weekly missions")
	for mission_id in weekly_missions:
		mission_progress[mission_id] = 0
		if mission_id in completed_missions:
			completed_missions.erase(mission_id)
	missions_refreshed.emit("weekly")

func update_mission_progress(track_stat: String, value: int):
	# Update all active missions that track this stat
	var all_missions = {}
	all_missions.merge(daily_missions)
	all_missions.merge(weekly_missions)
	
	for mission_id in all_missions:
		var mission = all_missions[mission_id]
		
		# Skip if already completed
		if mission_id in completed_missions:
			continue
		
		# Check if this mission tracks this stat
		if mission.track_stat == track_stat:
			var old_value = mission_progress.get(mission_id, 0)
			var new_value = old_value + value
			
			mission_progress[mission_id] = new_value
			mission_progress_updated.emit(mission_id, old_value, new_value)
			
			# Check completion
			if new_value >= mission.target:
				_complete_mission(mission_id)
	
	save_missions()

func track_game_completed():
	"""Called when a game ends to update mission progress"""
	var missions_progressed = []
	
	# This is called for compatibility with PostGameSummary
	# The actual tracking happens through signals
	
	var all_missions = {}
	all_missions.merge(daily_missions)
	all_missions.merge(weekly_missions)
	
	for mission_id in all_missions:
		var mission = all_missions[mission_id]
		var progress = mission_progress.get(mission_id, 0)
		
		if progress > 0 and mission_id not in completed_missions:
			missions_progressed.append({
				"mission": mission,
				"old_value": progress - 1,  # Approximate
				"new_value": progress
			})
	
	return missions_progressed

func _complete_mission(mission_id: String):
	if mission_id in completed_missions:
		return
	
	completed_missions.append(mission_id)
	mission_completed.emit(mission_id)
	
	# Award rewards
	var mission = get_mission_by_id(mission_id)
	if mission:
		if mission.has("reward_stars"):
			StarManager.add_stars(mission.reward_stars, "mission_" + mission_id)
		if mission.has("reward_xp"):
			XPManager.add_xp(mission.reward_xp)
		print("Mission completed: %s" % [mission.title])

func get_mission_by_id(mission_id: String) -> Dictionary:
	if mission_id in daily_missions:
		return daily_missions[mission_id]
	elif mission_id in weekly_missions:
		return weekly_missions[mission_id]
	return {}

func get_mission_progress(mission_id: String) -> int:
	return mission_progress.get(mission_id, 0)

func is_mission_completed(mission_id: String) -> bool:
	return mission_id in completed_missions

func get_all_active_missions() -> Dictionary:
	return {
		"daily": daily_missions.values(),
		"weekly": weekly_missions.values()
	}

# Signal handlers
func _on_game_won(final_score: int, time_elapsed: float):
	update_mission_progress("games_won", 1)
	update_mission_progress("games_played", 1)

func _on_game_lost(final_score: int, reason: String):
	update_mission_progress("games_played", 1)

func _on_game_over(total_score: int):
	# Additional tracking if needed
	pass

func _on_perfect_clear():
	update_mission_progress("perfect_clears", 1)

func _on_score_changed(points: int, reason: String):
	if points > 0:
		update_mission_progress("score_earned", points)

# Persistence
func save_missions():
	var save_data = {
		"version": 2,
		"progress": mission_progress,
		"completed": completed_missions,
		"last_daily_reset": last_daily_reset,
		"last_weekly_reset": last_weekly_reset
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_missions():
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data and save_data.has("progress"):
			mission_progress = save_data.progress
			completed_missions = save_data.get("completed", [])
			last_daily_reset = save_data.get("last_daily_reset", "")
			last_weekly_reset = save_data.get("last_weekly_reset", "")

# Debug functions
func reset_all_missions():
	mission_progress.clear()
	completed_missions.clear()
	save_missions()
	print("All missions reset")

func debug_complete_mission(mission_id: String):
	var mission = get_mission_by_id(mission_id)
	if mission:
		mission_progress[mission_id] = mission.target
		_complete_mission(mission_id)

func force_refresh_weekly():
	"""Debug function to force weekly mission refresh"""
	_reset_weekly_missions()
	save_missions()
