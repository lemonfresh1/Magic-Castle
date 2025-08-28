# AchievementManager.gd - Systematic achievement system with 3 tiers per stat
# Path: res://Pyramids/scripts/autoloads/AchievementManager.gd
# Last Updated: Simplified to 3-tier system for all tracked stats [2025-08-28]
extends Node

signal achievement_unlocked(achievement_id: String)
signal achievement_progress_updated(achievement_id: String, progress: float)

const SAVE_PATH = "user://achievements.save"

# Tier definitions for consistent progression
const TIER_MULTIPLIERS = {
	"bronze": 1,
	"silver": 5,
	"gold": 20
}

# Icon cycling - reuse icons across achievements
const ICON_LIST = [
	"Play.png", "Trophy.png", "Team.png", "Flower.png", "Gear.png",
	"Flower2.png", "Sun.png", "Coin2.png", "Lightbulb.png", "Cloud.png",
	"Coin.png", "Cutlery.png", "CookingPot.png", "Exit.png", "Eye.png",
	"FlowerPot.png", "Info.png", "Key.png"
]

# Achievement definitions - 3 tiers for each stat type
var achievement_definitions = {}
var unlocked_achievements: Array[String] = []
var achievement_progress = {}
var seen_achievements: Array[String] = []
var session_unlocked_achievements: Array[String] = []

func _ready():
	_generate_achievements()
	load_achievements()

func _generate_achievements():
	"""Generate achievements programmatically for all tracked stats"""
	var icon_index = 0
	
	# Define stat progressions with base values
	var stat_configs = [
		# Core gameplay
		{"stat": "games_played", "name": "Player", "base": 1, "multipliers": [1, 50, 200]},
		{"stat": "total_rounds", "name": "Round Master", "base": 1, "multipliers": [5, 100, 500]},
		{"stat": "total_score", "name": "Score Hunter", "base": 1000, "multipliers": [1, 50, 500]},
		{"stat": "highscore", "name": "High Scorer", "base": 1000, "multipliers": [5, 20, 50]},
		
		# Card interactions
		{"stat": "cards_clicked", "name": "Card Tapper", "base": 1, "multipliers": [100, 1000, 5000]},
		{"stat": "cards_drawn", "name": "Draw Master", "base": 1, "multipliers": [50, 500, 2000]},
		{"stat": "invalid_clicks", "name": "Precision", "base": 100, "multipliers": [1, 0.5, 0.1]}, # Less is better
		
		# Combos and streaks
		{"stat": "combo", "name": "Combo King", "base": 1, "multipliers": [5, 15, 30]},
		{"stat": "perfect_rounds", "name": "Perfectionist", "base": 1, "multipliers": [1, 10, 50]},
		{"stat": "suit_bonuses", "name": "Suit Master", "base": 1, "multipliers": [20, 100, 500]},
		
		# Peak achievements
		{"stat": "total_peaks_cleared", "name": "Peak Crusher", "base": 1, "multipliers": [10, 100, 500]},
		{"stat": "peak_clears_3", "name": "Triple Threat", "base": 1, "multipliers": [1, 10, 50]},
		
		# Speed achievements  
		{"stat": "fastest_clear", "name": "Speed Runner", "base": 120, "multipliers": [1, 0.5, 0.25]}, # Less is better
		{"stat": "time_ran_out", "name": "Time Fighter", "base": 50, "multipliers": [1, 0.5, 0.1]}, # Less is better
		
		# Efficiency
		{"stat": "most_cards_remaining", "name": "Efficient", "base": 1, "multipliers": [5, 15, 25]},
		{"stat": "highest_round_reached", "name": "Endurance", "base": 1, "multipliers": [5, 10, 15]}
	]
	
	# Generate 3 tiers for each stat
	for config in stat_configs:
		var tiers = ["bronze", "silver", "gold"]
		var tier_names = ["Novice", "Expert", "Master"]
		var tier_stars = [5, 20, 50]
		
		for i in range(3):
			var tier = tiers[i]
			var achievement_id = "%s_%s" % [config.stat, tier]
			var requirement_value = int(config.base * config.multipliers[i])
			
			# For "less is better" stats, invert the display
			var description = ""
			if config.stat in ["invalid_clicks", "fastest_clear", "time_ran_out"]:
				if config.stat == "fastest_clear":
					description = "Clear a round in under %d seconds" % requirement_value
				elif config.stat == "time_ran_out":
					description = "Complete %d rounds before time expires" % requirement_value
				else:
					description = "Make fewer than %d invalid clicks total" % requirement_value
			else:
				# Format large numbers nicely
				var formatted_value = _format_number(requirement_value)
				if config.stat == "highscore":
					description = "Reach a score of %s" % formatted_value
				elif config.stat == "combo":
					description = "Get a %d card combo" % requirement_value
				elif config.stat == "peak_clears_3":
					description = "Clear all 3 peaks %d times" % requirement_value
				else:
					description = "Reach %s %s" % [formatted_value, config.stat.replace("_", " ")]
			
			achievement_definitions[achievement_id] = {
				"name": "%s %s" % [tier_names[i], config.name],
				"description": description,
				"stars": tier_stars[i],
				"requirement": {"type": config.stat, "value": requirement_value},
				"icon": ICON_LIST[icon_index % ICON_LIST.size()],
				"tier": i + 1
			}
			
			icon_index += 1

func check_achievements():
	"""Simplified achievement checking"""
	var stats = StatsManager.get_total_stats()
	var current_game = StatsManager.current_game_stats
	
	for id in achievement_definitions:
		if id in unlocked_achievements:
			continue
		
		var achievement = achievement_definitions[id]
		var requirement = achievement.requirement
		var current_value = _get_stat_value(requirement.type, stats, current_game)
		
		# Special handling for "less is better" stats
		var unlocked = false
		if requirement.type in ["invalid_clicks", "fastest_clear", "time_ran_out"]:
			if requirement.type == "fastest_clear" and stats.fastest_clear > 0:
				unlocked = stats.fastest_clear <= requirement.value
			elif requirement.type == "time_ran_out":
				# This is actually "rounds completed without timeout"
				var successful_rounds = stats.total_rounds - stats.time_ran_out
				unlocked = successful_rounds >= requirement.value
			elif requirement.type == "invalid_clicks":
				unlocked = stats.games_played >= 10 and stats.invalid_clicks <= requirement.value
		else:
			unlocked = current_value >= requirement.value
		
		# Update progress
		var progress = 0.0
		if requirement.type in ["fastest_clear"]:
			if stats.fastest_clear > 0:
				progress = min(float(requirement.value) / float(stats.fastest_clear), 1.0)
		elif requirement.type in ["invalid_clicks", "time_ran_out"]:
			# Special progress calculation for inverse stats
			progress = 1.0 if unlocked else 0.5  # Binary for now
		else:
			progress = min(float(current_value) / float(requirement.value), 1.0)
		
		var old_progress = achievement_progress.get(id, 0.0)
		if progress > old_progress:
			achievement_progress[id] = progress
			achievement_progress_updated.emit(id, progress)
		
		if unlocked:
			unlock_achievement(id)

func _get_stat_value(stat_type: String, stats: Dictionary, current_game: Dictionary):
	"""Get current value for a stat type"""
	match stat_type:
		"games_played": return stats.games_played
		"total_rounds": return stats.total_rounds
		"total_score": return stats.total_score
		"highscore": return StatsManager.get_highscore().score
		"cards_clicked": return stats.cards_clicked
		"cards_drawn": return stats.cards_drawn
		"invalid_clicks": return stats.invalid_clicks
		"combo": return StatsManager.get_longest_combo().combo
		"perfect_rounds": return stats.perfect_rounds
		"suit_bonuses": return stats.suit_bonuses
		"total_peaks_cleared": return stats.total_peaks_cleared
		"peak_clears_3": return stats.peak_clears.get("3", 0)
		"fastest_clear": return stats.fastest_clear if stats.fastest_clear > 0 else 999
		"time_ran_out": return stats.time_ran_out
		"most_cards_remaining": return stats.most_cards_remaining
		"highest_round_reached": return stats.highest_round_reached
		_: return 0

func _format_number(num: int) -> String:
	"""Format large numbers for display"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%dK" % (num / 1000)
	else:
		return str(num)

func unlock_achievement(id: String):
	if id in unlocked_achievements:
		return
	
	unlocked_achievements.append(id)
	achievement_progress[id] = 1.0
	session_unlocked_achievements.append(id)
	
	save_achievements()
	achievement_unlocked.emit(id)
	
	var achievement = achievement_definitions[id]
	print("Achievement Unlocked: %s (+%d stars)" % [achievement.name, achievement.stars])
	
	# Award XP if enabled
	if XPManager and XPManager.has_method("add_achievement_xp"):
		if XPManager.rewards_enabled:
			XPManager.add_achievement_xp(id)

func mark_achievement_seen(id: String):
	if id not in seen_achievements:
		seen_achievements.append(id)
		save_achievements()

func is_achievement_new(id: String) -> bool:
	return id in unlocked_achievements and id not in seen_achievements

func get_achievement_progress(id: String) -> float:
	if id in unlocked_achievements:
		return 1.0
	return achievement_progress.get(id, 0.0)

func get_total_stars_earned() -> int:
	var total = 0
	for id in unlocked_achievements:
		if achievement_definitions.has(id):
			total += achievement_definitions[id].stars
	return total

func is_unlocked(id: String) -> bool:
	return id in unlocked_achievements

func get_achievements_for_stat(stat_type: String) -> Array:
	"""Get all achievements for a specific stat type"""
	var results = []
	for id in achievement_definitions:
		if achievement_definitions[id].requirement.type == stat_type:
			results.append(id)
	return results

func get_tier_for_achievement(id: String) -> int:
	"""Get tier (1-3) for an achievement"""
	if achievement_definitions.has(id):
		return achievement_definitions[id].get("tier", 1)
	return 0

func save_achievements():
	var save_data = {
		"version": 3,
		"unlocked": unlocked_achievements,
		"progress": achievement_progress,
		"seen": seen_achievements
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_achievements():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var save_data = file.get_var()
			file.close()
			
			if save_data and save_data.has("unlocked"):
				# Migrate old achievement IDs if needed
				var migrated_unlocked = []
				for old_id in save_data.unlocked:
					# Check if it's an old format achievement
					if achievement_definitions.has(old_id):
						migrated_unlocked.append(old_id)
					# Skip old achievements that don't exist anymore
				
				unlocked_achievements.assign(migrated_unlocked)
				achievement_progress = save_data.get("progress", {})
				seen_achievements.assign(save_data.get("seen", []))

func reset_all_achievements():
	print("Resetting all achievements...")
	unlocked_achievements.clear()
	achievement_progress.clear()
	seen_achievements.clear()
	save_achievements()
	print("All achievements reset")

func get_and_clear_session_achievements() -> Array[String]:
	var achievements = session_unlocked_achievements.duplicate()
	session_unlocked_achievements.clear()
	return achievements
