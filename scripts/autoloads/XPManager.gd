# XPManager.gd - Autoload for XP and level progression
# Path: res://Magic-Castle/scripts/autoloads/XPManager.gd
# Manages player XP, levels, and progression rewards
extends Node

signal xp_gained(amount: int, source: String)
signal level_up(new_level: int, rewards: Dictionary)
signal prestige_up(prestige_level: int)

const SAVE_PATH = "user://xp_data.save"

# Level progression
var current_xp: int = 0
var current_level: int = 1
var current_prestige: int = 0  # 0=none, 1=bronze, 2=silver, 3=gold, 4=diamond

# XP requirements (level 1-50)
var xp_per_level: Array[int] = []
const BASE_XP = 100
const XP_GROWTH = 1.15  # 15% more each level

# Daily XP tracking
var daily_games_played: int = 0
var daily_reset_timestamp: int = 0
var xp_multiplier: float = 1.0  # Soft cap system

# XP sources
const XP_PER_ROUND = 10
const XP_GAME_COMPLETE = 50
const XP_FIRST_WIN_BONUS = 100
const XP_ACHIEVEMENT_BASE = 100

func _ready():
	print("XPManager initializing...")
	_generate_xp_table()
	load_xp_data()
	_check_daily_reset()
	print("XPManager ready - Level %d (Prestige %d)" % [current_level, current_prestige])

func _generate_xp_table():
	xp_per_level.clear()
	xp_per_level.append(0)  # Level 0 doesn't exist
	
	for level in range(1, 51):
		var xp_required = int(BASE_XP * pow(XP_GROWTH, level - 1))
		xp_per_level.append(xp_required)

# === XP EARNING ===
func add_xp(amount: int, source: String = "gameplay"):
	# Apply soft cap multiplier
	var actual_amount = int(amount * xp_multiplier)
	
	current_xp += actual_amount
	xp_gained.emit(actual_amount, source)
	
	# Check for level up
	while current_xp >= get_xp_for_next_level() and current_level < 50:
		_level_up()
	
	# Check for prestige
	if current_level >= 50 and current_xp >= get_xp_for_next_level():
		_prestige_up()
	
	save_xp_data()

func add_round_xp(round_number: int, cleared: bool):
	var xp = XP_PER_ROUND * round_number
	if cleared:
		xp = int(xp * 1.5)
	add_xp(xp, "round_%d" % round_number)

func add_game_complete_xp(mode: String, rounds_completed: int):
	var xp = XP_GAME_COMPLETE
	
	# Mode bonuses
	match mode:
		"rush":
			xp = int(xp * 1.5)
		"chill":
			xp = int(xp * 0.8)
	
	# Bonus for completing all rounds
	if rounds_completed >= GameModeManager.get_max_rounds():
		xp += 50
	
	add_xp(xp, "game_complete_%s" % mode)

func add_achievement_xp(achievement_id: String):
	var achievement = AchievementManager.achievements.get(achievement_id, {})
	var rarity = achievement.get("rarity", AchievementManager.Rarity.COMMON)
	
	# XP based on rarity
	var xp = XP_ACHIEVEMENT_BASE
	match rarity:
		AchievementManager.Rarity.UNCOMMON:
			xp *= 2
		AchievementManager.Rarity.RARE:
			xp *= 3
		AchievementManager.Rarity.EPIC:
			xp *= 5
		AchievementManager.Rarity.LEGENDARY:
			xp *= 10
	
	add_xp(xp, "achievement_%s" % achievement_id)

# === LEVEL PROGRESSION ===
func _level_up():
	current_xp -= get_xp_for_next_level()
	current_level += 1
	
	# Calculate rewards
	var rewards = {
		"stars": 10 + (current_level / 5) * 5,  # 10, 15, 20, 25...
		"unlock": _get_level_unlock(current_level)
	}
	
	# Add stars
	StarManager.add_stars(rewards.stars, "level_up_%d" % current_level)
	
	level_up.emit(current_level, rewards)
	print("LEVEL UP! Now level %d. Earned %d stars!" % [current_level, rewards.stars])

func _prestige_up():
	if current_prestige >= 4:  # Max prestige
		return
	
	current_level = 50  # Stay at 50
	current_xp = 0
	current_prestige += 1
	
	# Big star reward for prestige
	var prestige_stars = 100 * current_prestige
	StarManager.add_stars(prestige_stars, "prestige_%d" % current_prestige)
	
	prestige_up.emit(current_prestige)
	print("PRESTIGE UP! Now %s prestige!" % get_prestige_name())

# === DAILY SYSTEM ===
func _check_daily_reset():
	var current_day = Time.get_date_dict_from_system().day
	var saved_day = Time.get_date_dict_from_unix_time(daily_reset_timestamp).day
	
	if current_day != saved_day:
		daily_games_played = 0
		daily_reset_timestamp = Time.get_unix_time_from_system()
		save_xp_data()

func update_daily_games():
	daily_games_played += 1
	
	# Update XP multiplier (soft cap)
	if daily_games_played <= 10:
		xp_multiplier = 1.0
	elif daily_games_played <= 20:
		xp_multiplier = 0.5
	else:
		xp_multiplier = 0.25

func check_first_win_bonus() -> bool:
	return daily_games_played == 1

# === GETTERS ===
func get_current_level() -> int:
	if current_prestige > 0:
		return 50
	return current_level

func get_display_level() -> String:
	if current_prestige > 0:
		return "%s %d" % [get_prestige_name(), current_level]
	return str(current_level)

func get_prestige_name() -> String:
	match current_prestige:
		1: return "Bronze"
		2: return "Silver"
		3: return "Gold"
		4: return "Diamond"
		_: return ""

func get_prestige_color() -> Color:
	match current_prestige:
		1: return Color(0.8, 0.5, 0.3)  # Bronze
		2: return Color(0.75, 0.75, 0.75)  # Silver
		3: return Color(1.0, 0.84, 0)  # Gold
		4: return Color(0.7, 0.9, 1.0)  # Diamond
		_: return Color.WHITE

func get_xp_for_next_level() -> int:
	if current_level >= 50:
		# Prestige XP requirement
		return 10000 * (current_prestige + 1)
	
	if current_level < xp_per_level.size():
		return xp_per_level[current_level]
	return 999999

func get_xp_progress() -> float:
	var needed = get_xp_for_next_level()
	if needed <= 0:
		return 1.0
	return float(current_xp) / float(needed)

# === UNLOCKS ===
func _get_level_unlock(level: int) -> String:
	# Define what unlocks at each level
	match level:
		5: return "rush_mode"
		10: return "chill_mode"
		15: return "custom_games"
		20: return "leaderboards"
		25: return "multiplayer"
		30: return "tournaments"
		40: return "season_pass_discount"
		50: return "prestige_system"
		_: return ""

func is_feature_unlocked(feature: String) -> bool:
	match feature:
		"rush_mode": return current_level >= 5
		"chill_mode": return current_level >= 10
		"custom_games": return current_level >= 15
		"leaderboards": return current_level >= 20
		"multiplayer": return current_level >= 25
		"tournaments": return current_level >= 30
		_: return true

# === PERSISTENCE ===
func save_xp_data():
	var save_data = {
		"version": 1,
		"current_xp": current_xp,
		"current_level": current_level,
		"current_prestige": current_prestige,
		"daily_games": daily_games_played,
		"daily_reset": daily_reset_timestamp
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_xp_data():
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data and save_data.has("current_xp"):
			current_xp = save_data.get("current_xp", 0)
			current_level = save_data.get("current_level", 1)
			current_prestige = save_data.get("current_prestige", 0)
			daily_games_played = save_data.get("daily_games", 0)
			daily_reset_timestamp = save_data.get("daily_reset", 0)

# === DEBUG ===
func add_debug_xp(amount: int):
	add_xp(amount, "debug")

func set_debug_level(level: int):
	current_level = clamp(level, 1, 50)
	current_xp = 0
	save_xp_data()

func reset_xp():
	current_xp = 0
	current_level = 1
	current_prestige = 0
	daily_games_played = 0
	save_xp_data()
