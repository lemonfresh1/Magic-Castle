# MissionManager.gd - Manages all mission types and progress
# Path: res://Magic-Castle/scripts/autoloads/MissionManager.gd
# Tracks daily, season pass, and event missions
extends Node

signal mission_progress_updated(mission_id: String, old_value: int, new_value: int)
signal mission_completed(mission_id: String)

const SAVE_PATH = "user://missions.save"

# Mission definitions
# TODO: Refactor mission system when scaling beyond MVP:
# - Create separate managers: DailyMissionManager, SeasonPassManager, EventMissionManager
# - Move mission data to Resource files (.tres) for easy editing in Inspector
# - Structure: MissionManager -> SubManagers -> MissionResource files
# - Each season/event gets its own .tres file (Season1Missions.tres, ChristmasMissions.tres)
# - Create MissionResource class extending Resource with exported properties
# - This will support 100+ missions without code bloat and allow hot-swapping content
# CURRENT: Simple dictionaries work fine for ~20-30 missions during MVP testing
var daily_missions = {
	"daily_games": {
		"id": "daily_games",
		"type": "daily",
		"title": "Daily Player",
		"description": "Games Played:",
		"target": 5,
		"reward_stars": 50,
		"track_stat": "games_played_today"
	}
}

var season_missions = {
	"season_games": {
		"id": "season_games",
		"type": "season",
		"title": "Season Player",
		"description": "Games Played:",
		"target": 6,
		"reward_stars": 100,
		"track_stat": "games_played_season"
	}
}

var event_missions = {
	"event_games": {
		"id": "event_games",
		"type": "event",
		"title": "Event Player",
		"description": "Games Played:",
		"target": 7,
		"reward_stars": 150,
		"track_stat": "games_played_event"
	}
}

# Progress tracking
var mission_progress = {}  # mission_id -> current_value
var completed_missions = []  # Array of completed mission IDs
var last_reset_date = ""  # For daily reset

func _ready():
	print("MissionManager initializing...")
	load_missions()
	_check_daily_reset()
	print("MissionManager ready")

func _check_daily_reset():
	var today = Time.get_date_string_from_system()
	if last_reset_date != today:
		_reset_daily_missions()
		last_reset_date = today
		save_missions()

func _reset_daily_missions():
	print("Resetting daily missions")
	for mission_id in daily_missions:
		mission_progress[mission_id] = 0
		if mission_id in completed_missions:
			completed_missions.erase(mission_id)

func track_game_completed():
	"""Called when a game ends to update mission progress"""
	var missions_progressed = []
	
	# Check all active missions
	var all_missions = {}
	all_missions.merge(daily_missions)
	all_missions.merge(season_missions)
	all_missions.merge(event_missions)
	
	for mission_id in all_missions:
		var mission = all_missions[mission_id]
		
		# Skip if already completed
		if mission_id in completed_missions:
			continue
		
		# For now, all missions track games played
		if mission.track_stat.begins_with("games_played"):
			var old_value = mission_progress.get(mission_id, 0)
			var new_value = old_value + 1
			
			mission_progress[mission_id] = new_value
			mission_progress_updated.emit(mission_id, old_value, new_value)
			
			missions_progressed.append({
				"mission": mission,
				"old_value": old_value,
				"new_value": new_value
			})
			
			# Check completion
			if new_value >= mission.target:
				_complete_mission(mission_id)
	
	save_missions()
	return missions_progressed

func _complete_mission(mission_id: String):
	if mission_id in completed_missions:
		return
	
	completed_missions.append(mission_id)
	mission_completed.emit(mission_id)
	
	# Award stars
	var mission = get_mission_by_id(mission_id)
	if mission and mission.has("reward_stars"):
		StarManager.add_stars(mission.reward_stars, "mission_" + mission_id)
		print("Mission completed: %s (+%d stars)" % [mission.title, mission.reward_stars])

func get_mission_by_id(mission_id: String) -> Dictionary:
	if mission_id in daily_missions:
		return daily_missions[mission_id]
	elif mission_id in season_missions:
		return season_missions[mission_id]
	elif mission_id in event_missions:
		return event_missions[mission_id]
	return {}

func get_mission_progress(mission_id: String) -> int:
	return mission_progress.get(mission_id, 0)

func is_mission_completed(mission_id: String) -> bool:
	return mission_id in completed_missions

func get_all_active_missions() -> Array:
	var active = []
	
	# Add all mission types
	for mission in daily_missions.values():
		if not is_mission_completed(mission.id):
			active.append(mission)
	
	for mission in season_missions.values():
		if not is_mission_completed(mission.id):
			active.append(mission)
	
	for mission in event_missions.values():
		if not is_mission_completed(mission.id):
			active.append(mission)
	
	return active

# Persistence
func save_missions():
	var save_data = {
		"version": 1,
		"progress": mission_progress,
		"completed": completed_missions,
		"last_reset": last_reset_date
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
			last_reset_date = save_data.get("last_reset", "")

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
