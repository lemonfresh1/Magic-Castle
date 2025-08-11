# XPManager.gd - Autoload for XP and level progression
# Path: res://Pyramids/scripts/autoloads/XPManager.gd
# Manages player XP, levels, and progression rewards
extends Node

signal xp_gained(amount: int, source: String)
signal level_up(new_level: int, rewards: Dictionary)
signal prestige_up(prestige_level: int)

const SAVE_PATH = "user://xp_data.save"

# Level progression
var current_xp: int = 0
var current_level: int = 1
var current_prestige: int = 0  # 0=none, 1-5=bronze, 6-10=silver, 11-15=gold, 16-20=diamond

# Level Requirements (1-50)
const LEVEL_XP_REQUIREMENTS = [
	0, 100, 100, 100, 100, 100, 200, 200, 200, 200,         # 1-10
	200, 400, 400, 400, 400, 400, 600, 600, 600, 600,     # 11-20
	600, 800, 800, 800, 800, 800, 1000, 1000, 1000, 1000, # 21-30
	1000, 1200, 1200, 1200, 1200, 1200, 1500, 1500, 1500, 1500, # 31-40
	1500, 2000, 2000, 2000, 2000, 2000, 2500, 2500, 2500, 2500, # 41-50
	2500 # 50 (for prestige)
]

# Prestige Tiers
const PRESTIGE_NAMES = [
	"", # No prestige
	"Bronze I", "Bronze II", "Bronze III", "Bronze IV", "Bronze V",
	"Silver I", "Silver II", "Silver III", "Silver IV", "Silver V",
	"Gold I", "Gold II", "Gold III", "Gold IV", "Gold V",
	"Diamond I", "Diamond II", "Diamond III", "Diamond IV", "Diamond V"
]

# Level rewards (stars, skins, items, etc)
# Parameters you can use:
# "stars": 50 - Currency reward
# "unlock": "feature_name" - Unlocks a game feature
# "skin": "skin_id" - Unlocks a cosmetic skin
# "title": "Cool Player" - Unlocks a player title
# "emoji": "fire" - Unlocks an emoji for multiplayer
# "frame": "gold_frame" - Unlocks a profile frame
# Example: 15: {"stars": 75, "unlock": "clans", "skin": "card_back_clan", "title": "Clan Member"},
const LEVEL_REWARDS = {
	1: {"stars": 10},  # Starting bonus
	2: {"stars": 50},
	3: {"stars": 50, "unlock": "multiplayer"},
	4: {"stars": 50},
	5: {"stars": 50, "unlock": "daily_missions"},
	6: {"stars": 50, "unlock": "season_pass"},
	7: {"stars": 50, "unlock": "rush_mode"},
	8: {"stars": 50},
	9: {"stars": 50},
	10: {"stars": 50},
	# Add skins/titles for milestone levels like: 10: {"stars": 50, "skin": "card_back_bronze", "title": "Rising Star"},
	11: {"stars": 75},
	12: {"stars": 75},
	13: {"stars": 75},
	14: {"stars": 75},
	15: {"stars": 75, "unlock": "clans"},
	16: {"stars": 75},
	17: {"stars": 75},
	18: {"stars": 75},
	19: {"stars": 75},
	20: {"stars": 75, "unlock": "tournaments"},
	# Consider adding profile frames at 20: {"stars": 75, "unlock": "tournaments", "frame": "tournament_frame"},
	21: {"stars": 100},
	22: {"stars": 100},
	23: {"stars": 100},
	24: {"stars": 100},
	25: {"stars": 100},
	# Good spot for an emoji: 25: {"stars": 100, "emoji": "crown", "title": "Veteran"},
	26: {"stars": 100},
	27: {"stars": 100},
	28: {"stars": 100},
	29: {"stars": 100},
	30: {"stars": 100},
	# Major milestone rewards: 30: {"stars": 100, "skin": "card_back_gold", "frame": "gold_frame"},
	31: {"stars": 100},
	32: {"stars": 100},
	33: {"stars": 100},
	34: {"stars": 100},
	35: {"stars": 100},
	36: {"stars": 100},
	37: {"stars": 100},
	38: {"stars": 100},
	39: {"stars": 100},
	40: {"stars": 100},
	# Epic rewards at 40: {"stars": 100, "skin": "card_back_diamond", "title": "Master"},
	41: {"stars": 100},
	42: {"stars": 100},
	43: {"stars": 100},
	44: {"stars": 100},
	45: {"stars": 100},
	46: {"stars": 100},
	47: {"stars": 100},
	48: {"stars": 100},
	49: {"stars": 100},
	50: {"stars": 100, "unlock": "prestige_system"},
	# Ultimate level 50: {"stars": 100, "unlock": "prestige_system", "skin": "card_back_prestige", "title": "Legend", "frame": "legendary_frame"},
}

# Daily XP tracking
var daily_games_played: int = 0
var daily_reset_timestamp: int = 0
var xp_multiplier: float = 1.0  # Soft cap system
var rewards_enabled: bool = true

# XP sources
const XP_PER_ROUND = 10
const XP_GAME_COMPLETE = 50
const XP_FIRST_WIN_BONUS = 100
const XP_ACHIEVEMENT_BASE = 100

func _ready():
	print("XPManager initializing...")
	load_xp_data()
	_check_daily_reset()
	print("XPManager ready - Level %d (Prestige %d)" % [current_level, current_prestige])

# === XP EARNING ===
func add_xp(amount: int, source: String = "gameplay"):
	# Skip if rewards are disabled (during gameplay)
	if not rewards_enabled:
		print("XP: Blocked %d XP from %s (rewards disabled)" % [amount, source])
		return
		
	# Apply soft cap multiplier
	var actual_amount = int(amount * xp_multiplier)

	print("XP: Adding %d XP from %s (multiplier: %.2f)" % [actual_amount, source, xp_multiplier])

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

	print("Achievement XP: %s (rarity %d) = %d XP" % [achievement_id, rarity, xp])

	add_xp(xp, "achievement_%s" % achievement_id)

# === LEVEL PROGRESSION ===
func _level_up():
	current_xp -= get_xp_for_next_level()
	var old_level = current_level
	current_level += 1
	
	# Get rewards from table
	var rewards = LEVEL_REWARDS.get(current_level, {"stars": 50})
	
	# CHANGE: Only add stars if rewards are enabled (not during PostGameSummary calculation)
	if rewards.has("stars") and rewards_enabled:
		StarManager.add_stars(rewards.stars, "level_up_%d" % current_level)
	
	level_up.emit(current_level, rewards)
	print("LEVEL UP! Now level %d. Earned %d stars!" % [current_level, rewards.get("stars", 0)])
	
	# Only show celebration if rewards are enabled (in PostGameSummary)
	if rewards_enabled:
		_show_level_up_celebration(old_level, current_level, rewards)

func _prestige_up():
	if current_prestige >= 20:  # Max prestige (Diamond V)
		return
	
	current_level = 50  # Stay at 50
	current_xp = 0
	current_prestige += 1
	
	# Big star reward for prestige
	var prestige_tier = (current_prestige - 1) / 5 + 1  # 1=Bronze, 2=Silver, etc
	var prestige_stars = 100 * prestige_tier
	StarManager.add_stars(prestige_stars, "prestige_%d" % current_prestige)
	
	prestige_up.emit(current_prestige)
	print("PRESTIGE UP! Now %s!" % get_prestige_name())

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
	if current_prestige < PRESTIGE_NAMES.size():
		return PRESTIGE_NAMES[current_prestige]
	return ""

func get_prestige_color() -> Color:
	if current_prestige == 0:
		return Color.WHITE
	
	var tier = (current_prestige - 1) / 5  # 0=Bronze, 1=Silver, 2=Gold, 3=Diamond
	match tier:
		0: return Color(0.8, 0.5, 0.3)      # Bronze
		1: return Color(0.75, 0.75, 0.75)   # Silver
		2: return Color(1.0, 0.84, 0)       # Gold
		3: return Color(0.7, 0.9, 1.0)      # Diamond
		_: return Color.WHITE

func get_xp_for_next_level() -> int:
	if current_level >= 50:
		# Prestige XP requirement (10k per prestige level)
		return 10000 * (current_prestige + 1)
	
	if current_level < LEVEL_XP_REQUIREMENTS.size():
		return LEVEL_XP_REQUIREMENTS[current_level]
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
		3: return "multiplayer"
		5: return "daily_missions"
		6: return "season_pass"
		7: return "rush_mode"
		15: return "clans"
		20: return "tournaments"
		50: return "prestige_system"
		_: return ""

func is_feature_unlocked(feature: String) -> bool:
	match feature:
		"multiplayer": return current_level >= 3
		"daily_missions": return current_level >= 5
		"season_pass": return current_level >= 6
		"rush_mode": return current_level >= 7
		"clans": return current_level >= 15
		"tournaments": return current_level >= 20
		"prestige_system": return current_level >= 50
		_: return true  # Everything else is unlocked by default

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

func _show_level_up_celebration(old_level: int, new_level: int, rewards: Dictionary) -> void:
	# Don't show during game initialization
	if not get_tree() or not get_tree().root:
		return
		
	# Check if celebration already exists to avoid duplicates
	var existing = get_tree().root.get_node_or_null("LevelUpCelebration")
	if existing:
		existing.queue_free()
	
	# Create and show new celebration
	var celebration_scene = preload("res://Pyramids/scenes/ui/effects/LevelUpCelebration.tscn")
	var celebration = celebration_scene.instantiate()
	celebration.name = "LevelUpCelebration"
	get_tree().root.add_child(celebration)
	celebration.show_level_up(old_level, new_level, rewards)
