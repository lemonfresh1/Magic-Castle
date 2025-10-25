# UnifiedMissionManager.gd - Unified mission system for all game modes
# Location: res://Pyramids/scripts/autoloads/UnifiedMissionManager.gd
# Last Updated: Added daily rotation, weekly tracking, season/holiday support [2025-01-XX]
#
# Manages three mission systems:
# 1. Standard Missions: 5 rotating daily + 10 fixed weekly missions
# 2. Season Pass Missions: 120 missions across 12 weeks (loaded from content files)
# 3. Holiday Event Missions: All missions available day 1 (loaded from content files)
#
# Features:
# - Daily mission rotation (36 pool → 5 per day, deterministic)
# - Weekly stat tracking (resets Monday)
# - Combo cascading (high combos complete lower combo missions)
# - Season pass week-based unlocking
# - Holiday event flat mission list
# - Progress syncing to Supabase (Phase 3)

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal mission_progress_updated(mission_id: String, current: int, target: int, system: String)
signal mission_completed(mission_id: String, system: String)
signal mission_claimed(mission_id: String, rewards: Dictionary, system: String)
signal missions_reset(reset_type: String) # "daily" or "weekly"

# ============================================================================
# CONSTANTS - SAVE PATH
# ============================================================================

const SAVE_PATH = "user://unified_missions.save"

# ============================================================================
# CONSTANTS - DAILY MISSION POOL (36 missions, pick 5 per day)
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
# CONSTANTS - WEEKLY MISSION POOL (10 fixed missions, no rotation)
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
# CONSTANTS - REWARDS
# ============================================================================

const REWARDS = {
	"standard": {
		"daily": {"xp": 50},      # 5 missions × 50 XP = 250 XP/day
		"weekly": {"xp": 100}     # 10 missions × 100 XP = 1,000 XP/week
	},
	"season_pass": {
		# Loaded dynamically from season content files
	},
	"holiday": {
		# Loaded dynamically from holiday content files
	}
}

# ============================================================================
# STATE VARIABLES
# ============================================================================

# Mission progress tracking: {system: {mission_id: {current: int, completed: bool, claimed: bool}}}
var mission_progress = {}

# Reset tracking
var last_daily_reset = ""
var last_weekly_reset = ""

# Current game tracking (for single-game missions)
var current_game_score = 0
var current_game_combo = 0

# Loaded content from files
var loaded_season_content: Dictionary = {}
var loaded_holiday_content: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	load_missions()
	_check_mission_resets()
	
	# Connect to game signals
	call_deferred("_connect_signals")

func _connect_signals():
	"""Connect to SignalBus for game events"""
	if not SignalBus:
		push_warning("SignalBus not found")
		return
	
	# Core game signals
	if not SignalBus.game_over.is_connected(_on_game_over):
		SignalBus.game_over.connect(_on_game_over)
	if not SignalBus.score_changed.is_connected(_on_score_changed):
		SignalBus.score_changed.connect(_on_score_changed)
	if not SignalBus.combo_updated.is_connected(_on_combo_updated):
		SignalBus.combo_updated.connect(_on_combo_updated)
	if not SignalBus.round_started.is_connected(_on_round_started):
		SignalBus.round_started.connect(_on_round_started)
	
	# Weekly stat updates from StatsManager
	if SignalBus.has_signal("weekly_stat_updated"):
		if not SignalBus.weekly_stat_updated.is_connected(_on_weekly_stat_updated):
			SignalBus.weekly_stat_updated.connect(_on_weekly_stat_updated)

# ============================================================================
# RESET LOGIC
# ============================================================================

func _check_mission_resets():
	"""Check if daily or weekly missions need to reset"""
	var today = Time.get_date_string_from_system()
	var datetime = Time.get_datetime_dict_from_system()
	
	# Check daily reset (midnight)
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
	"""Reset missions of a specific type (daily/weekly)"""
	# Only reset standard missions
	if not mission_progress.has("standard"):
		mission_progress["standard"] = {}
	
	# Get today's daily missions or all weekly missions
	var missions_to_reset = []
	
	if reset_type == "daily":
		# Get today's 5 daily missions
		var today = Time.get_date_string_from_system()
		missions_to_reset = get_daily_missions_for_date(today)
	elif reset_type == "weekly":
		# All weekly missions
		missions_to_reset = WEEKLY_MISSION_POOL
	
	# Reset progress for these missions
	for template in missions_to_reset:
		var mission_id = template.id
		mission_progress["standard"][mission_id] = {
			"current": 0,
			"completed": false,
			"claimed": false
		}
	
	missions_reset.emit(reset_type)

# ============================================================================
# MISSION RETRIEVAL
# ============================================================================

func get_missions_for_system(system: String, mission_type: String = "all", week_filter: int = -1) -> Array:
	"""Get missions for a specific system with optional filtering
	
	Args:
		system: "standard", "season_pass", or "holiday"
		mission_type: "all", "daily", or "weekly" (standard only)
		week_filter: Week number for season pass (1-12), -1 for all unlocked weeks
	
	Returns:
		Array of mission dictionaries
	"""
	if system == "season_pass" and loaded_season_content.size() > 0:
		return _get_season_pass_missions(week_filter)
	elif system == "holiday" and loaded_holiday_content.size() > 0:
		return _get_holiday_missions()
	else:
		# Standard missions (daily/weekly)
		return _get_standard_missions(mission_type)

func _get_standard_missions(mission_type: String) -> Array:
	"""Get standard daily/weekly missions with rotation"""
	var missions = []
	var today = Time.get_date_string_from_system()
	
	# Ensure standard system exists
	if not mission_progress.has("standard"):
		mission_progress["standard"] = {}
	
	# Get daily missions (5 rotating from pool)
	if mission_type == "daily" or mission_type == "all":
		var daily = get_daily_missions_for_date(today)
		
		for template in daily:
			var mission_id = template.id
			
			# Ensure progress exists
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
	
	# Get weekly missions (all 10, no rotation)
	if mission_type == "weekly" or mission_type == "all":
		for template in WEEKLY_MISSION_POOL:
			var mission_id = template.id
			
			# Ensure progress exists
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
		# Show specific week (if unlocked)
		if week_filter <= current_week:
			weeks_to_show.append("week_%d" % week_filter)
	
	# Ensure season_pass system exists
	if not mission_progress.has("season_pass"):
		mission_progress["season_pass"] = {}
	
	# Build mission list
	for week_key in weeks_to_show:
		if not loaded_season_content.missions.has(week_key):
			continue
		
		var week_missions = loaded_season_content.missions[week_key]
		
		for template in week_missions:
			var mission_id = template.id
			
			# Ensure progress exists
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

func _get_holiday_missions() -> Array:
	"""Get all holiday event missions (no filtering, all available day 1)"""
	var missions = []
	
	if loaded_holiday_content.size() == 0:
		return missions
	
	# Ensure holiday system exists
	if not mission_progress.has("holiday"):
		mission_progress["holiday"] = {}
	
	for template in loaded_holiday_content.missions:
		var mission_id = template.id
		
		# Ensure progress exists
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
# DAILY ROTATION
# ============================================================================

func get_daily_missions_for_date(date_string: String) -> Array:
	"""Get 5 missions from pool based on date (deterministic)
	
	Same date always returns same missions. Uses date as RNG seed.
	"""
	var seed_value = _date_to_seed(date_string)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	# Create indices array and shuffle using seeded RNG
	var indices = range(DAILY_MISSION_POOL.size())
	
	# Fisher-Yates shuffle with seeded RNG
	for i in range(indices.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = indices[i]
		indices[i] = indices[j]
		indices[j] = temp
	
	# Pick first 5
	var selected = []
	for i in range(5):
		selected.append(DAILY_MISSION_POOL[indices[i]].duplicate())
	
	return selected

func _date_to_seed(date_string: String) -> int:
	"""Convert YYYY-MM-DD date to deterministic seed"""
	var parts = date_string.split("-")
	return int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])

# ============================================================================
# PROGRESS TRACKING
# ============================================================================

func update_progress(track_type: String, value: int = 1):
	"""Update progress for all active missions tracking this stat
	
	Note: missions_completed is a LOCAL ARRAY tracking which missions completed
		  in this specific update call. It's different from mission_progress which
		  is the PERSISTENT DICTIONARY storing all mission states.
	"""
	var missions_completed = []  # Array of missions that completed in this call
	
	# Handle weekly-specific tracks
	if track_type.begins_with("weekly_"):
		var weekly_stat = track_type.replace("weekly_", "")
		_update_weekly_missions(weekly_stat, value)
		return missions_completed
	
	# Handle standard and season/holiday tracks
	# Check daily missions
	var today = Time.get_date_string_from_system()
	var daily_missions = get_daily_missions_for_date(today)
	
	for template in daily_missions:
		if template.track != track_type:
			continue
		
		_update_mission_progress("standard", template.id, template.target, value, missions_completed)
	
	# Check weekly missions
	for template in WEEKLY_MISSION_POOL:
		if template.track != track_type:
			continue
		
		_update_mission_progress("standard", template.id, template.target, value, missions_completed)
	
	# Check season pass missions
	if loaded_season_content.size() > 0:
		var current_week = get_current_week_for_season(loaded_season_content)
		
		for i in range(1, current_week + 1):
			var week_key = "week_%d" % i
			if not loaded_season_content.missions.has(week_key):
				continue
			
			for template in loaded_season_content.missions[week_key]:
				if template.track != track_type:
					continue
				
				_update_mission_progress("season_pass", template.id, template.target, value, missions_completed)
	
	# Check holiday missions
	if loaded_holiday_content.size() > 0:
		for template in loaded_holiday_content.missions:
			if template.track != track_type:
				continue
			
			_update_mission_progress("holiday", template.id, template.target, value, missions_completed)
	
	if missions_completed.size() > 0:
		save_missions()
	
	return missions_completed

func _update_mission_progress(system: String, mission_id: String, target: int, value: int, missions_completed: Array):
	"""Helper to update a single mission's progress"""
	# Ensure system exists
	if not mission_progress.has(system):
		mission_progress[system] = {}
	
	# Ensure mission exists
	if not mission_progress[system].has(mission_id):
		mission_progress[system][mission_id] = {
			"current": 0,
			"completed": false,
			"claimed": false
		}
	
	var progress = mission_progress[system][mission_id]
	
	# Skip if already completed
	if progress.completed:
		return
	
	# Update progress
	var old_value = progress.current
	progress.current = min(progress.current + value, target)
	
	# Emit progress update
	mission_progress_updated.emit(mission_id, progress.current, target, system)
	
	# Check completion
	if progress.current >= target and not progress.completed:
		progress.completed = true
		missions_completed.append({"mission_id": mission_id, "system": system})
		mission_completed.emit(mission_id, system)

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
		
		# For weekly stats, sync with StatsManager's weekly_stats
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

func claim_mission(mission_id: String, system: String) -> bool:
	"""Claim rewards for a completed mission"""
	if not mission_progress.has(system) or not mission_progress[system].has(mission_id):
		return false
	
	var progress = mission_progress[system][mission_id]
	if not progress.completed or progress.claimed:
		return false
	
	# Determine rewards
	var rewards = {}
	
	if system == "standard":
		# Find mission type (daily or weekly)
		var is_daily = false
		var today = Time.get_date_string_from_system()
		var daily_missions = get_daily_missions_for_date(today)
		
		for template in daily_missions:
			if template.id == mission_id:
				is_daily = true
				break
		
		if is_daily:
			rewards = REWARDS["standard"]["daily"].duplicate()
		else:
			rewards = REWARDS["standard"]["weekly"].duplicate()
	
	elif system == "season_pass":
		# Find mission in loaded content to get SP reward
		if loaded_season_content.size() > 0:
			for week_key in loaded_season_content.missions:
				for template in loaded_season_content.missions[week_key]:
					if template.id == mission_id:
						rewards = {"sp": template.reward_sp}
						break
	
	elif system == "holiday":
		# Find mission in loaded content to get HP reward
		if loaded_holiday_content.size() > 0:
			for template in loaded_holiday_content.missions:
				if template.id == mission_id:
					rewards = {"hp": template.reward_hp}
					break
	
	# Grant rewards
	if system == "standard":
		if rewards.has("xp") and XPManager:
			XPManager.add_xp(rewards.xp, "mission_%s" % mission_id)
	elif system == "season_pass":
		if rewards.has("sp") and SeasonPassManager:
			SeasonPassManager.add_season_points(rewards.sp, "mission_%s" % mission_id)
	elif system == "holiday":
		if rewards.has("hp") and HolidayEventManager:
			HolidayEventManager.add_holiday_points(rewards.hp, "mission_%s" % mission_id)
	
	# Mark as claimed
	progress.claimed = true
	mission_claimed.emit(mission_id, rewards, system)
	save_missions()
	
	return true

# ============================================================================
# CONTENT LOADING (Season Pass & Holiday Events)
# ============================================================================

func load_season_content(season_id: String) -> Dictionary:
	"""Load season pass content from .gd file
	
	Example: load_season_content("Q4_2025") loads SeasonPassQ4_2025.gd
	"""
	var content_path = "res://Pyramids/content/seasonpass/SeasonPass%s.gd" % season_id
	
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

func load_holiday_content(event_id: String) -> Dictionary:
	"""Load holiday event content from .gd file
	
	Example: load_holiday_content("WinterWonderland2025") loads WinterWonderland2025.gd
	"""
	var content_path = "res://Pyramids/content/holiday_events/%s.gd" % event_id
	
	if not FileAccess.file_exists(content_path):
		push_error("Holiday content not found: " + content_path)
		return {}
	
	var content_script = load(content_path)
	if not content_script:
		push_error("Failed to load holiday script")
		return {}
	
	var content = content_script.new()
	
	loaded_holiday_content = {
		"id": content.EVENT_ID,
		"name": content.EVENT_NAME,
		"theme": content.EVENT_THEME,
		"start_date": content.START_DATE,
		"end_date": content.END_DATE,
		"duration_days": content.DURATION_DAYS,
		"currency_name": content.CURRENCY_NAME,
		"currency_icon": content.CURRENCY_ICON,
		"missions": content.MISSIONS
	}
	
	return loaded_holiday_content

func get_current_week_for_season(season_content: Dictionary) -> int:
	"""Calculate current week number based on unlock dates (1-12)
	
	Returns 0 if season hasn't started yet, or the current week number.
	"""
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
# SIGNAL HANDLERS
# ============================================================================

func _on_round_started(round_number: int):
	"""Reset single-game trackers at start of round 1"""
	if round_number == 1:
		current_game_score = 0
		current_game_combo = 0

func _on_score_changed(points: int, reason: String):
	"""Track total score across game"""
	if points > 0:
		current_game_score += points
		update_progress("total_score", points)

func _on_combo_updated(combo_count: int):
	"""Track combos with cascading updates
	
	A combo of 15 will complete missions for combo_3, combo_5, combo_8, combo_10, combo_12, and combo_15
	"""
	current_game_combo = max(current_game_combo, combo_count)
	
	# Cascade through all combo thresholds
	var combo_thresholds = [3, 5, 8, 10, 12, 15, 20, 22, 25, 30]
	for threshold in combo_thresholds:
		if combo_count >= threshold:
			update_progress("combo_%d" % threshold, 1)

func _on_game_over(final_score: int):
	"""Update missions when game ends"""
	# 1. A game played
	update_progress("games_played", 1)
	
	# 2. A game won (in single player, game_over means winning)
	update_progress("games_won", 1)
	
	# 3. Check for high score missions
	if current_game_score >= 15000:
		update_progress("high_score", 1)
	
	# Reset game trackers
	current_game_score = 0
	current_game_combo = 0

func _on_weekly_stat_updated(stat_name: String, value: int):
	"""Handle weekly stat updates from StatsManager"""
	_update_weekly_missions(stat_name, value)

# ============================================================================
# SAVE / LOAD
# ============================================================================

func save_missions():
	"""Save mission progress to disk"""
	var save_data = {
		"version": 2,
		"progress": mission_progress,
		"last_daily_reset": last_daily_reset,
		"last_weekly_reset": last_weekly_reset
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_missions():
	"""Load mission progress from disk"""
	if not FileAccess.file_exists(SAVE_PATH):
		# Initialize empty progress for all systems
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

# ============================================================================
# DEBUG FUNCTIONS
# ============================================================================

func debug_complete_mission(mission_id: String, system: String = "standard"):
	"""Debug: Instantly complete a mission"""
	if not mission_progress.has(system):
		mission_progress[system] = {}
	
	if not mission_progress[system].has(mission_id):
		push_error("Mission not found: %s in system %s" % [mission_id, system])
		return
	
	# Find target value
	var target = 1
	
	# Search in daily pool
	for template in DAILY_MISSION_POOL:
		if template.id == mission_id:
			target = template.target
			break
	
	# Search in weekly pool
	for template in WEEKLY_MISSION_POOL:
		if template.id == mission_id:
			target = template.target
			break
	
	# Complete it
	mission_progress[system][mission_id].current = target
	mission_progress[system][mission_id].completed = true
	mission_completed.emit(mission_id, system)
	
	save_missions()
	print("Debug: Completed mission %s" % mission_id)

func debug_reset_all():
	"""Debug: Reset all mission progress"""
	mission_progress.clear()
	for system in ["standard", "season_pass", "holiday"]:
		mission_progress[system] = {}
	
	last_daily_reset = ""
	last_weekly_reset = ""
	
	save_missions()
	print("Debug: All missions reset")

func get_mission_summary() -> Dictionary:
	"""Get a summary of mission completion across all systems"""
	var summary = {
		"standard": {"daily_complete": 0, "daily_total": 0, "weekly_complete": 0, "weekly_total": 0},
		"season_pass": {"total_complete": 0, "total_available": 0},
		"holiday": {"total_complete": 0, "total_available": 0}
	}
	
	# Standard missions
	if mission_progress.has("standard"):
		var today = Time.get_date_string_from_system()
		var daily_missions = get_daily_missions_for_date(today)
		
		# Count daily
		for template in daily_missions:
			summary["standard"]["daily_total"] += 1
			if mission_progress["standard"].has(template.id):
				if mission_progress["standard"][template.id].completed:
					summary["standard"]["daily_complete"] += 1
		
		# Count weekly
		for template in WEEKLY_MISSION_POOL:
			summary["standard"]["weekly_total"] += 1
			if mission_progress["standard"].has(template.id):
				if mission_progress["standard"][template.id].completed:
					summary["standard"]["weekly_complete"] += 1
	
	return summary

# ============================================================================
# UTILITY HELPERS
# ============================================================================

func _date_to_unix(date_string: String) -> int:
	"""Convert YYYY-MM-DD string to Unix timestamp (midnight)"""
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
