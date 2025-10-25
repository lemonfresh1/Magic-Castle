# UnifiedMissionManager.gd - Single manager for all mission types
# Location: res://Pyramids/scripts/autoloads/UnifiedMissionManager.gd
# Last Updated: Cleaned debug output while maintaining functionality [Date]

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

# ============================================================================
# DAILY MISSION POOL (36 missions, pick 5 per day)
# ============================================================================
const DAILY_MISSION_POOL = [
	# Easy missions (12)
	{"id": "daily_play_1", "name": "First Game", "desc": "Play 1 game", "target": 1, "track": "games_played"},
	{"id": "daily_play_2", "name": "Warm Up", "desc": "Play 2 games", "target": 2, "track": "games_played"},
	{"id": "daily_win_1", "name": "Daily Winner", "desc": "Win 1 game", "target": 1, "track": "games_won"},
	{"id": "daily_score_15k", "name": "Score Starter", "desc": "Score 15,000 in one game", "target": 15000, "track": "high_score"},
	{"id": "daily_total_50k", "name": "Point Builder", "desc": "Score 50,000 total", "target": 50000, "track": "total_score"},
	{"id": "daily_combo_5", "name": "Combo Starter", "desc": "Achieve 5+ combo", "target": 1, "track": "combo_5"},
	{"id": "daily_perfect_1", "name": "Flawless", "desc": "Complete 1 perfect round", "target": 1, "track": "perfect_rounds"},
	{"id": "daily_cards_30", "name": "Card Counter", "desc": "Click 30 cards", "target": 30, "track": "cards_clicked"},
	{"id": "daily_suit_3", "name": "Suit Starter", "desc": "Trigger 3 suit bonuses", "target": 3, "track": "suit_bonus"},
	{"id": "daily_aces_3", "name": "Ace Hunter", "desc": "Play 3 Aces", "target": 3, "track": "aces_played"},
	{"id": "daily_kings_3", "name": "King Hunter", "desc": "Play 3 Kings", "target": 3, "track": "kings_played"},
	{"id": "daily_draw_10", "name": "Card Drawer", "desc": "Draw 10 cards", "target": 10, "track": "cards_drawn"},
	
	# Medium missions (12)
	{"id": "daily_play_3", "name": "Triple Play", "desc": "Play 3 games", "target": 3, "track": "games_played"},
	{"id": "daily_win_2", "name": "Victory Duo", "desc": "Win 2 games", "target": 2, "track": "games_won"},
	{"id": "daily_score_30k", "name": "High Scorer", "desc": "Score 30,000 in one game", "target": 30000, "track": "high_score"},
	{"id": "daily_total_100k", "name": "Century Club", "desc": "Score 100,000 total", "target": 100000, "track": "total_score"},
	{"id": "daily_combo_8", "name": "Combo Builder", "desc": "Achieve 8+ combo", "target": 1, "track": "combo_8"},
	{"id": "daily_combo_10", "name": "Combo Master", "desc": "Achieve 10+ combo", "target": 1, "track": "combo_10"},
	{"id": "daily_perfect_2", "name": "Perfect Pair", "desc": "Complete 2 perfect rounds", "target": 2, "track": "perfect_rounds"},
	{"id": "daily_peaks_9", "name": "Summit", "desc": "Clear all 9 peaks", "target": 1, "track": "peak_clears_9"},
	{"id": "daily_cards_50", "name": "Card Collector", "desc": "Click 50 cards", "target": 50, "track": "cards_clicked"},
	{"id": "daily_suit_5", "name": "Suit Master", "desc": "Trigger 5 suit bonuses", "target": 5, "track": "suit_bonus"},
	{"id": "daily_aces_5", "name": "Ace Collector", "desc": "Play 5 Aces", "target": 5, "track": "aces_played"},
	{"id": "daily_kings_5", "name": "King Collector", "desc": "Play 5 Kings", "target": 5, "track": "kings_played"},
	
	# Hard missions (12)
	{"id": "daily_play_5", "name": "Dedicated", "desc": "Play 5 games", "target": 5, "track": "games_played"},
	{"id": "daily_win_3", "name": "Triple Winner", "desc": "Win 3 games", "target": 3, "track": "games_won"},
	{"id": "daily_score_50k", "name": "Score Master", "desc": "Score 50,000 in one game", "target": 50000, "track": "high_score"},
	{"id": "daily_total_200k", "name": "Two Hundred K", "desc": "Score 200,000 total", "target": 200000, "track": "total_score"},
	{"id": "daily_combo_12", "name": "Combo Expert", "desc": "Achieve 12+ combo", "target": 1, "track": "combo_12"},
	{"id": "daily_combo_15", "name": "Combo Pro", "desc": "Achieve 15+ combo", "target": 1, "track": "combo_15"},
	{"id": "daily_peaks_9_twice", "name": "Double Summit", "desc": "Clear all peaks twice", "target": 2, "track": "peak_clears_9"},
	{"id": "daily_cards_75", "name": "Card Master", "desc": "Click 75 cards", "target": 75, "track": "cards_clicked"},
	{"id": "daily_suit_8", "name": "Suit Expert", "desc": "Trigger 8 suit bonuses", "target": 8, "track": "suit_bonus"},
	{"id": "daily_aces_8", "name": "Ace Master", "desc": "Play 8 Aces", "target": 8, "track": "aces_played"},
	{"id": "daily_fast_180", "name": "Speed Player", "desc": "Win in under 3 minutes", "target": 180, "track": "fastest_clear"},
	{"id": "daily_draw_25", "name": "Draw Master", "desc": "Draw 25 cards", "target": 25, "track": "cards_drawn"},
]

# ============================================================================
# WEEKLY MISSION POOL (10 missions - FIXED set, no rotation)
# ============================================================================
const WEEKLY_MISSION_POOL = [
	{"id": "weekly_cards_1000", "name": "Card Grinder", "desc": "Click 1,000 cards", "target": 1000, "track": "weekly_cards_clicked"},
	{"id": "weekly_draw_750", "name": "Draw Master", "desc": "Draw 750 cards", "target": 750, "track": "weekly_cards_drawn"},
	{"id": "weekly_play_20", "name": "20 Games", "desc": "Play 20 games", "target": 20, "track": "weekly_games_played"},
	{"id": "weekly_mp_10", "name": "Multiplayer Enthusiast", "desc": "Play 10 multiplayer games", "target": 10, "track": "weekly_multiplayer_games"},
	{"id": "weekly_login_5", "name": "5 Day Streak", "desc": "Log in 5 days this week", "target": 5, "track": "weekly_logins_this_week"},
	{"id": "weekly_login_7", "name": "Perfect Week", "desc": "Log in all 7 days", "target": 7, "track": "weekly_logins_this_week"},
	{"id": "weekly_suit_50", "name": "Suit Bonanza", "desc": "Trigger 50 suit bonuses", "target": 50, "track": "weekly_suit_bonuses"},
	{"id": "weekly_combo_10", "name": "Combo Achievement", "desc": "Achieve 10+ combo once", "target": 1, "track": "combo_10"},
	{"id": "weekly_high_30k", "name": "High Score Goal", "desc": "Score 30,000 in one game", "target": 30000, "track": "high_score"},
	{"id": "weekly_total_300k", "name": "300K Grind", "desc": "Score 300,000 total this week", "target": 300000, "track": "weekly_total_score"},
]

# ============================================================================
# REWARDS
# ============================================================================
const REWARDS = {
	"standard": {
		"daily": {"xp": 50},      # 5 missions × 50 XP = 250 XP/day
		"weekly": {"xp": 100}     # 10 missions × 100 XP = 1,000 XP/week
	},
	"season_pass": {
		# Will be loaded from content files
	},
	"holiday": {
		# Will be loaded from content files
	}
}

# Mission progress tracking
var mission_progress = {} # {system: {mission_id: {current: 0, completed: false, claimed: false}}}
var last_daily_reset = ""
var last_weekly_reset = ""
var loaded_season_content: Dictionary = {}
var loaded_holiday_content: Dictionary = {}
var missions_completed = []

# Track high scores for single-game achievements
var current_game_score = 0
var current_game_combo = 0

func _ready():
	load_missions()
	_check_mission_resets()
	
	# Connect to game signals
	call_deferred("_connect_signals")

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

func get_missions_for_system(system: String, mission_type: String = "all", week_filter: int = -1) -> Array:
	"""Enhanced with week filtering for season pass"""
	
	if system == "season_pass" and loaded_season_content.size() > 0:
		return _get_season_pass_missions(week_filter)
	elif system == "holiday" and loaded_holiday_content.size() > 0:
		return _get_holiday_missions()
	else:
		# Standard missions (daily/weekly)
		return _get_standard_missions(mission_type)

func update_progress(track_type: String, value: int = 1):
	"""Enhanced with weekly tracking support"""
	
	# Handle weekly-specific tracks
	if track_type.begins_with("weekly_"):
		var weekly_stat = track_type.replace("weekly_", "")
		_update_weekly_missions(weekly_stat, value)
		return
	
	# Handle standard tracks for all systems
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
			HolidayEventManager.add_holiday_points(rewards.hp, "holiday_mission_%s" % mission_id)
	
	progress.claimed = true
	mission_claimed.emit(mission_id, rewards, system)
	save_missions()
	
	return true

func _on_game_over(final_score: int):
	# Every completed game counts as:
	# 1. A game played
	update_progress("games_played", 1)
	
	# 2. A game won (since in single player, completing = winning)
	update_progress("games_won", 1)
	
	# 3. Check for high score mission
	if final_score >= 30000:
		update_progress("high_score", 1)

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
	"""Cascade combo updates - completing high combo counts lower ones too"""
	current_game_combo = max(current_game_combo, combo_count)
	
	# Cascade through all combo thresholds
	var combo_thresholds = [3, 5, 8, 10, 12, 15, 20, 22, 25, 30]
	for threshold in combo_thresholds:
		if combo_count >= threshold:
			update_progress("combo_%d" % threshold, 1)

# Add debug function
func debug_print_mission_status():
	"""Print current status of all missions"""
	pass  # Removed debug output


func get_daily_missions_for_date(date_string: String) -> Array:
	"""Get 5 missions from pool based on date (deterministic)"""
	var seed_value = _date_to_seed(date_string)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	# Create indices array and shuffle
	var indices = range(DAILY_MISSION_POOL.size())
	indices.shuffle()  # Uses global RNG seed
	
	# Pick first 5
	var selected = []
	for i in range(5):
		selected.append(DAILY_MISSION_POOL[indices[i]].duplicate())
	
	return selected

func _date_to_seed(date_string: String) -> int:
	"""Convert date to deterministic seed"""
	var parts = date_string.split("-")
	return int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])

func load_season_content(season_id: String) -> Dictionary:
	"""Load season pass content from .gd file"""
	var content_path = "res://Pyramids/content/season_passes/SeasonPass%s.gd" % season_id
	
	if not FileAccess.file_exists(content_path):
		push_error("Season content not found: " + content_path)
		return {}
	
	var content_script = load(content_path)
	if not content_script:
		push_error("Failed to load season script")
		return {}
	
	var content = content_script.new()
	
	loaded_season_content = {
		"id": content.SEASON_ID,
		"name": content.SEASON_NAME,
		"theme": content.SEASON_THEME,
		"start_date": content.START_DATE,
		"end_date": content.END_DATE,
		"week_unlock_dates": content.WEEK_UNLOCK_DATES,
		"missions": content.MISSIONS
	}
	
	return loaded_season_content

func get_current_week_for_season(season_content: Dictionary) -> int:
	"""Calculate current week based on unlock dates"""
	var today = Time.get_date_string_from_system()
	var today_unix = _date_to_unix(today)
	
	var current_week = 0
	for i in range(season_content.week_unlock_dates.size()):
		var unlock_date = season_content.week_unlock_dates[i]
		var unlock_unix = _date_to_unix(unlock_date)
		
		if today_unix >= unlock_unix:
			current_week = i + 1
		else:
			break
	
	return current_week

# ============================================================================
# MISSING HELPER FUNCTIONS FOR UnifiedMissionManager.gd
# Add these to your UnifiedMissionManager.gd file
# ============================================================================

# ============================================================================
# HELPER: Get Standard Missions (Daily/Weekly)
# ============================================================================
func _get_standard_missions(mission_type: String) -> Array:
	"""Get standard daily/weekly missions with rotation"""
	var missions = []
	var today = Time.get_date_string_from_system()
	
	# Get missions based on type
	if mission_type == "daily" or mission_type == "all":
		# Get today's 5 daily missions from pool
		var daily = get_daily_missions_for_date(today)
		
		for template in daily:
			var mission_id = template.id
			
			# Ensure progress exists
			if not mission_progress.has("standard"):
				mission_progress["standard"] = {}
			if not mission_progress["standard"].has(mission_id):
				mission_progress["standard"][mission_id] = {
					"current": 0,
					"completed": false,
					"claimed": false
				}
			
			var progress = mission_progress["standard"][mission_id]
			var rewards = REWARDS["standard"]["daily"].duplicate()
			
			missions.append({
				"id": mission_id,
				"display_name": template.name,
				"description": template.desc,
				"current_value": progress.current,
				"target_value": template.target,
				"rewards": rewards,
				"is_completed": progress.completed,
				"is_claimed": progress.claimed,
				"mission_type": "daily"
			})
	
	if mission_type == "weekly" or mission_type == "all":
		# Get all 10 weekly missions (no rotation)
		for template in WEEKLY_MISSION_POOL:
			var mission_id = template.id
			
			# Ensure progress exists
			if not mission_progress.has("standard"):
				mission_progress["standard"] = {}
			if not mission_progress["standard"].has(mission_id):
				mission_progress["standard"][mission_id] = {
					"current": 0,
					"completed": false,
					"claimed": false
				}
			
			var progress = mission_progress["standard"][mission_id]
			var rewards = REWARDS["standard"]["weekly"].duplicate()
			
			missions.append({
				"id": mission_id,
				"display_name": template.name,
				"description": template.desc,
				"current_value": progress.current,
				"target_value": template.target,
				"rewards": rewards,
				"is_completed": progress.completed,
				"is_claimed": progress.claimed,
				"mission_type": "weekly"
			})
	
	return missions

# ============================================================================
# HELPER: Get Season Pass Missions
# ============================================================================
func _get_season_pass_missions(week_filter: int = -1) -> Array:
	"""Get season pass missions with optional week filtering"""
	var missions = []
	
	if loaded_season_content.size() == 0:
		return missions
	
	var current_week = get_current_week_for_season(loaded_season_content)
	
	# Determine which weeks to show
	var weeks_to_show = []
	if week_filter == -1:
		# Show all unlocked weeks
		for i in range(1, current_week + 1):
			weeks_to_show.append("week_%d" % i)
	else:
		# Show specific week
		if week_filter <= current_week:
			weeks_to_show.append("week_%d" % week_filter)
	
	# Build mission list
	for week_key in weeks_to_show:
		if not loaded_season_content.missions.has(week_key):
			continue
		
		var week_missions = loaded_season_content.missions[week_key]
		
		for template in week_missions:
			var mission_id = template.id
			
			# Ensure progress exists
			if not mission_progress.has("season_pass"):
				mission_progress["season_pass"] = {}
			if not mission_progress["season_pass"].has(mission_id):
				mission_progress["season_pass"][mission_id] = {
					"current": 0,
					"completed": false,
					"claimed": false
				}
			
			var progress = mission_progress["season_pass"][mission_id]
			
			missions.append({
				"id": mission_id,
				"display_name": template.name,
				"description": template.desc,
				"current_value": progress.current,
				"target_value": template.target,
				"rewards": {"sp": template.reward_sp},
				"is_completed": progress.completed,
				"is_claimed": progress.claimed,
				"mission_type": "season",
				"week": int(week_key.replace("week_", ""))
			})
	
	return missions

# ============================================================================
# HELPER: Get Holiday Event Missions
# ============================================================================
func _get_holiday_missions() -> Array:
	"""Get all holiday event missions (no filtering, all available day 1)"""
	var missions = []
	
	if loaded_holiday_content.size() == 0:
		return missions
	
	for template in loaded_holiday_content.missions:
		var mission_id = template.id
		
		# Ensure progress exists
		if not mission_progress.has("holiday"):
			mission_progress["holiday"] = {}
		if not mission_progress["holiday"].has(mission_id):
			mission_progress["holiday"][mission_id] = {
				"current": 0,
				"completed": false,
				"claimed": false
			}
		
		var progress = mission_progress["holiday"][mission_id]
		
		missions.append({
			"id": mission_id,
			"display_name": template.name,
			"description": template.desc,
			"current_value": progress.current,
			"target_value": template.target,
			"rewards": {"hp": template.reward_hp},
			"is_completed": progress.completed,
			"is_claimed": progress.claimed,
			"mission_type": "holiday",
			"difficulty": template.get("difficulty", "medium")
		})
	
	return missions

# ============================================================================
# HELPER: Update Weekly Missions
# ============================================================================
func _update_weekly_missions(stat_name: String, value: int):
	"""Update progress for weekly missions that track this stat"""
	var track_type = "weekly_%s" % stat_name
	
	# Find all weekly missions tracking this stat
	for template in WEEKLY_MISSION_POOL:
		if template.track != track_type:
			continue
		
		var mission_id = template.id
		
		# Ensure progress exists
		if not mission_progress.has("standard"):
			mission_progress["standard"] = {}
		if not mission_progress["standard"].has(mission_id):
			mission_progress["standard"][mission_id] = {
				"current": 0,
				"completed": false,
				"claimed": false
			}
		
		var progress = mission_progress["standard"][mission_id]
		
		# Skip if already completed
		if progress.completed:
			continue
		
		# Update progress
		var old_value = progress.current
		
		# For weekly stats, set to the actual stat value (not increment)
		# Because StatsManager already tracks the cumulative value
		if StatsManager and StatsManager.weekly_stats.has(stat_name):
			progress.current = StatsManager.weekly_stats[stat_name]
		else:
			progress.current += value
		
		# Clamp to target
		progress.current = min(progress.current, template.target)
		
		# Emit progress update
		mission_progress_updated.emit(mission_id, progress.current, template.target, "standard")
		
		# Check completion
		if progress.current >= template.target and not progress.completed:
			progress.completed = true
			mission_completed.emit(mission_id, "standard")
	
	save_missions()

# ============================================================================
# HELPER: Date to Unix Timestamp
# ============================================================================
func _date_to_unix(date_string: String) -> int:
	"""Convert YYYY-MM-DD string to Unix timestamp"""
	var parts = date_string.split("-")
	if parts.size() != 3:
		return 0
	
	var date_dict = {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	
	return Time.get_unix_time_from_datetime_dict(date_dict)
