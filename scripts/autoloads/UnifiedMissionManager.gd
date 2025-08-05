# UnifiedMissionManager.gd - Single manager for all mission types
# Location: res://Magic-Castle/scripts/autoloads/UnifiedMissionManager.gd
# Last Updated: Created unified mission system [Date]

extends Node

signal mission_progress_updated(mission_id: String, current: int, target: int, system: String)
signal mission_completed(mission_id: String, system: String)
signal mission_claimed(mission_id: String, rewards: Dictionary, system: String)
signal missions_reset(reset_type: String) # "daily" or "weekly"

const SAVE_PATH = "user://unified_missions.save"

# Mission templates - 5 daily, 2 weekly (same for all systems)
const MISSION_TEMPLATES = {
	# Daily missions
	"daily_play_1": {"name": "First Game", "desc": "Play 1 game", "target": 1, "track": "games_played", "type": "daily"},
	"daily_play_3": {"name": "Triple Play", "desc": "Play 3 games", "target": 3, "track": "games_played", "type": "daily"},
	"daily_win_1": {"name": "Daily Winner", "desc": "Win 1 game", "target": 1, "track": "games_won", "type": "daily"},
	"daily_score_30k": {"name": "High Scorer", "desc": "Score 30,000 in one game", "target": 1, "track": "high_score", "type": "daily"},
	"daily_combo_10": {"name": "Combo Master", "desc": "Achieve 10+ combo", "target": 1, "track": "combo_10", "type": "daily"},
	
	# Weekly missions
	"weekly_play_15": {"name": "Dedicated Player", "desc": "Play 15 games", "target": 15, "track": "games_played", "type": "weekly"},
	"weekly_score_200k": {"name": "Point Master", "desc": "Score 200,000 total", "target": 200000, "track": "total_score", "type": "weekly"}
}

# Reward configurations per system
const REWARDS = {
	"standard": {
		"daily": {"stars": 10, "xp": 50},
		"weekly": {"stars": 50, "xp": 200}
	},
	"season_pass": {
		"daily": {"sp": 2},
		"weekly": {"sp": 5}
	},
	"holiday": {
		"daily": {"hp": 2},
		"weekly": {"hp": 5}
	}
}

# Mission progress tracking
var mission_progress = {} # {system: {mission_id: {current: 0, completed: false, claimed: false}}}
var last_daily_reset = ""
var last_weekly_reset = ""

# Track high scores for single-game achievements
var current_game_score = 0
var current_game_combo = 0

func _ready():
	print("UnifiedMissionManager initializing...")
	load_missions()
	_check_mission_resets()
	
	# Connect to game signals
	call_deferred("_connect_signals")
	
	print("UnifiedMissionManager ready")

func _connect_signals():
	if SignalBus:
		# Core game signals - SIMPLIFIED
		if not SignalBus.game_over.is_connected(_on_game_over):
			SignalBus.game_over.connect(_on_game_over)
		if not SignalBus.score_changed.is_connected(_on_score_changed):
			SignalBus.score_changed.connect(_on_score_changed)
		if not SignalBus.combo_updated.is_connected(_on_combo_updated):
			SignalBus.combo_updated.connect(_on_combo_updated)
		if not SignalBus.round_started.is_connected(_on_round_started):
			SignalBus.round_started.connect(_on_round_started)

func _check_mission_resets():
	var today = Time.get_date_string_from_system()
	var datetime = Time.get_datetime_dict_from_system()
	
	# Check daily reset
	if last_daily_reset != today:
		_reset_missions("daily")
		last_daily_reset = today
	
	# Check weekly reset (Monday = 1)
	var days_since_epoch = Time.get_unix_time_from_system() / 86400
	var week_number = int(days_since_epoch / 7)
	var week_string = "week_%d" % week_number
	
	if last_weekly_reset != week_string and datetime.weekday == 1:
		_reset_missions("weekly")
		last_weekly_reset = week_string
	
	save_missions()

func _reset_missions(reset_type: String):
	print("Resetting %s missions" % reset_type)
	
	# Reset for all systems
	for system in ["standard", "season_pass", "holiday"]:
		if not mission_progress.has(system):
			mission_progress[system] = {}
		
		# Reset missions of this type
		for mission_id in MISSION_TEMPLATES:
			var mission = MISSION_TEMPLATES[mission_id]
			if mission.type == reset_type:
				mission_progress[system][mission_id] = {
					"current": 0,
					"completed": false,
					"claimed": false
				}
	
	missions_reset.emit(reset_type)

func get_missions_for_system(system: String, mission_type: String = "all") -> Array:
	"""Get missions formatted for a specific system (standard/season_pass/holiday)"""
	var missions = []
	
	# Ensure system exists in progress
	if not mission_progress.has(system):
		mission_progress[system] = {}
	
	for mission_id in MISSION_TEMPLATES:
		var template = MISSION_TEMPLATES[mission_id]
		
		# Filter by type if specified
		if mission_type != "all" and template.type != mission_type:
			continue
		
		# Get or create progress
		if not mission_progress[system].has(mission_id):
			mission_progress[system][mission_id] = {
				"current": 0,
				"completed": false,
				"claimed": false
			}
		
		var progress = mission_progress[system][mission_id]
		
		# Build mission data with appropriate rewards
		var rewards = REWARDS[system][template.type].duplicate()
		
		missions.append({
			"id": mission_id,
			"display_name": template.name,
			"description": template.desc,
			"current_value": progress.current,
			"target_value": template.target,
			"rewards": rewards,
			"is_completed": progress.completed,
			"is_claimed": progress.claimed,
			"mission_type": template.type
		})
	
	return missions

func update_progress(track_type: String, value: int = 1):
	"""Update progress for all active missions tracking this stat"""
	var missions_completed = []
	
	for mission_id in MISSION_TEMPLATES:
		var template = MISSION_TEMPLATES[mission_id]
		
		if template.track != track_type:
			continue
		
		# Update for all systems
		for system in ["standard", "season_pass", "holiday"]:
			if not mission_progress.has(system):
				mission_progress[system] = {}
			
			if not mission_progress[system].has(mission_id):
				mission_progress[system][mission_id] = {
					"current": 0,
					"completed": false,
					"claimed": false
				}
			
			var progress = mission_progress[system][mission_id]
			
			# Skip if already completed
			if progress.completed:
				continue
			
			# Update progress
			var old_value = progress.current
			progress.current = min(progress.current + value, template.target)
			
			# Emit progress update
			mission_progress_updated.emit(mission_id, progress.current, template.target, system)
			
			# Check completion
			if progress.current >= template.target and not progress.completed:
				progress.completed = true
				missions_completed.append({"mission_id": mission_id, "system": system})
				mission_completed.emit(mission_id, system)
	
	if missions_completed.size() > 0:
		save_missions()
	
	return missions_completed

func claim_mission(mission_id: String, system: String) -> bool:
	"""Claim rewards for a completed mission"""
	if not mission_progress.has(system) or not mission_progress[system].has(mission_id):
		return false
	
	var progress = mission_progress[system][mission_id]
	if not progress.completed or progress.claimed:
		return false
	
	var template = MISSION_TEMPLATES[mission_id]
	var rewards = REWARDS[system][template.type].duplicate()
	
	# Grant rewards based on system
	if system == "standard":
		if rewards.has("stars"):
			StarManager.add_stars(rewards.stars, "mission_%s" % mission_id)
		if rewards.has("xp"):
			XPManager.add_xp(rewards.xp, "mission_%s" % mission_id)
	elif system == "season_pass":
		if rewards.has("sp"):
			SeasonPassManager.add_season_points(rewards.sp, "mission_%s" % mission_id)
	elif system == "holiday":
		if rewards.has("hp"):
			# For now, use season points (HP would be added later)
			SeasonPassManager.add_season_points(rewards.hp, "holiday_mission_%s" % mission_id)
	
	progress.claimed = true
	mission_claimed.emit(mission_id, rewards, system)
	save_missions()
	
	return true

func _on_game_over(final_score: int):
	print("\n[UnifiedMissionManager] Game ENDED! Final Score: %d" % final_score)
	
	# Every completed game counts as:
	# 1. A game played
	var played_updates = update_progress("games_played", 1)
	print("  - Updated games_played (%d missions affected)" % played_updates.size())
	
	# 2. A game won (since in single player, completing = winning)
	var won_updates = update_progress("games_won", 1)
	print("  - Updated games_won (%d missions affected)" % won_updates.size())
	
	# 3. Check for high score mission
	if final_score >= 30000:
		var score_updates = update_progress("high_score", 1)
		print("  - Achieved 30k+ score! (%d missions affected)" % score_updates.size())
	
	# Always print mission status after game
	debug_print_mission_status()

# Save/Load
func save_missions():
	var save_data = {
		"version": 1,
		"progress": mission_progress,
		"last_daily_reset": last_daily_reset,
		"last_weekly_reset": last_weekly_reset
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_missions():
	if not FileAccess.file_exists(SAVE_PATH):
		# Initialize empty progress
		for system in ["standard", "season_pass", "holiday"]:
			mission_progress[system] = {}
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data and save_data.has("progress"):
			mission_progress = save_data.progress
			last_daily_reset = save_data.get("last_daily_reset", "")
			last_weekly_reset = save_data.get("last_weekly_reset", "")

# Debug functions
func debug_complete_mission(mission_id: String):
	"""Debug function to instantly complete a mission"""
	if not MISSION_TEMPLATES.has(mission_id):
		push_error("Mission ID not found: " + mission_id)
		return
	
	var template = MISSION_TEMPLATES[mission_id]
	for system in ["standard", "season_pass", "holiday"]:
		if mission_progress.has(system) and mission_progress[system].has(mission_id):
			mission_progress[system][mission_id].current = template.target
			mission_progress[system][mission_id].completed = true
			mission_completed.emit(mission_id, system)
	
	save_missions()

func debug_reset_all():
	"""Debug function to reset all missions"""
	mission_progress.clear()
	for system in ["standard", "season_pass", "holiday"]:
		mission_progress[system] = {}
	_reset_missions("daily")
	_reset_missions("weekly")
	save_missions()

func get_mission_summary() -> Dictionary:
	"""Get a summary of all missions across systems"""
	var summary = {
		"standard": {"daily_complete": 0, "daily_total": 0, "weekly_complete": 0, "weekly_total": 0},
		"season_pass": {"daily_complete": 0, "daily_total": 0, "weekly_complete": 0, "weekly_total": 0},
		"holiday": {"daily_complete": 0, "daily_total": 0, "weekly_complete": 0, "weekly_total": 0}
	}
	
	for system in mission_progress:
		for mission_id in mission_progress[system]:
			if MISSION_TEMPLATES.has(mission_id):
				var template = MISSION_TEMPLATES[mission_id]
				var progress = mission_progress[system][mission_id]
				
				if template.type == "daily":
					summary[system]["daily_total"] += 1
					if progress.completed:
						summary[system]["daily_complete"] += 1
				else:
					summary[system]["weekly_total"] += 1
					if progress.completed:
						summary[system]["weekly_complete"] += 1
	
	return summary

func _on_round_started(round_number: int):
	# Reset single-game trackers at start of round 1
	if round_number == 1:
		current_game_score = 0
		current_game_combo = 0

func _on_score_changed(points: int, reason: String):
	if points > 0:
		current_game_score += points
		update_progress("total_score", points)

func _on_combo_updated(combo_count: int):
	current_game_combo = max(current_game_combo, combo_count)
	if combo_count >= 10:
		update_progress("combo_10", 1)

# Add debug function
func debug_print_mission_status():
	"""Print current status of all missions"""
	print("\n=== MISSION STATUS ===")
	for system in ["standard", "season_pass", "holiday"]:
		print("\n[%s]" % system.to_upper())
		var missions = get_missions_for_system(system)
		for mission in missions:
			print("  %s: %d/%d %s" % [
				mission.display_name,
				mission.current_value,
				mission.target_value,
				"✓" if mission.is_completed else ""
			])
	print("==================\n")
