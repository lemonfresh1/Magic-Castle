# AchievementManager.gd - Achievement system with 15 core achievements × 5 tiers each
# Path: res://Pyramids/scripts/autoloads/AchievementManager.gd
# Last Updated: Refactored for 5-tier system with manual claiming [2025-08-28]

extends Node

signal achievement_unlocked(achievement_id: String, tier: int)
signal achievement_progress_updated(achievement_id: String, progress: float)
signal achievement_claimed(achievement_id: String, tier: int)

const SAVE_PATH = "user://achievements.save"

# 5-Tier system
const TIER_NAMES = ["Bronze", "Silver", "Gold", "Platinum", "Diamond"]
const TIER_COLORS = [
	Color(0.72, 0.45, 0.20),  # Bronze
	Color(0.75, 0.75, 0.75),  # Silver  
	Color(1.0, 0.84, 0.0),     # Gold
	Color(0.5, 0.8, 0.9),      # Platinum (light blue)
	Color(0.7, 0.4, 1.0)       # Diamond (purple)
]
const TIER_STAR_REWARDS = [10, 25, 50, 100, 200]
const TIER_XP_REWARDS = [100, 250, 500, 1000, 2000]

# Achievement definitions - 15 core achievements with 5 tiers each
var achievement_definitions = {}
var unlocked_tiers = {}  # Format: {achievement_id: highest_unlocked_tier}
var claimed_tiers = {}   # Format: {achievement_id: highest_claimed_tier}
var achievement_progress = {}
var new_achievements = []  # List of newly unlocked but not viewed achievements
var session_achievements = []  # Achievements unlocked in this session

# Debug
var debug_enabled: bool = false  # Per-script debug toggle
var global_debug: bool = true   # Ready for global toggle integration

func _ready():
	_generate_achievements()
	load_achievements()
	
func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[ACHIEVEMENTMANAGER] %s" % message)

func _generate_achievements():
	"""Generate 14 core achievements with 5 tiers each"""
	
	# Define the 14 core achievements with their tier progressions
	var achievements = [
		# === CORE GAMEPLAY (4) ===
		{
			"id": "dedicated_player",
			"name": "Dedicated Player",
			"base_desc": "Play {value} games",
			"values": [1, 10, 50, 200, 1000],
			"stat": "games_played"
		},
		{
			"id": "score_hunter", 
			"name": "Score Hunter",
			"base_desc": "Score {value} points total",
			"values": [1000, 10000, 100000, 500000, 2000000],
			"stat": "total_score"
		},
		{
			"id": "highscore_master",
			"name": "Highscore Master",
			"base_desc": "Reach a highscore of {value}",
			"values": [1000, 10000, 25000, 50000, 80000],
			"stat": "highscore"
		},
		{
			"id": "speed_demon",
			"name": "Speed Demon",
			"base_desc": "Clear a round in under {value} seconds",
			"values": [50, 45, 40, 35, 30],
			"stat": "fastest_clear",
			"inverse": true  # Lower is better
		},
		
		# === SKILL & COMBOS (4) ===
		{
			"id": "combo_master",
			"name": "Combo Master",
			"base_desc": "Achieve a {value}x combo",
			"values": [5, 10, 18, 25, 28],
			"stat": "combo"
		},
		{
			"id": "perfect_player",
			"name": "Perfect Player",
			"base_desc": "Get {value} perfect rounds",
			"values": [1, 10, 50, 150, 500],
			"stat": "perfect_rounds"
		},
		{
			"id": "efficiency_expert",
			"name": "Efficiency Expert",
			"base_desc": "Win with {value}+ cards remaining",
			"values": [5, 8, 12, 15, 18],
			"stat": "most_cards_remaining"
		},
		{
			"id": "suit_specialist",
			"name": "Suit Specialist",
			"base_desc": "Collect {value} suit bonuses",
			"values": [10, 50, 200, 500, 2000],
			"stat": "suit_bonuses"
		},
		
		# === MULTIPLAYER & SOCIAL (6) ===
		{
			"id": "multiplayer_champion",
			"name": "Multiplayer Champion",
			"base_desc": "Win {value} multiplayer games",
			"values": [1, 10, 50, 150, 500],
			"stat": "mp_wins"
		},
		{
			"id": "social_player",
			"name": "Social Player",
			"base_desc": "Play {value} multiplayer games",
			"values": [5, 25, 100, 300, 1000],
			"stat": "mp_games"
		},
		{
			"id": "unstoppable",
			"name": "Unstoppable",
			"base_desc": "Get a {value} game win streak",
			"values": [3, 5, 7, 12, 20],
			"stat": "best_win_streak"
		},
		{
			"id": "daily_dedication",
			"name": "Daily Dedication",
			"base_desc": "Login for {value} consecutive days",
			"values": [1, 7, 30, 120, 365],
			"stat": "login_streak"
		},
		{
			"id": "collection_master",
			"name": "Collection Master",
			"base_desc": "Collect {value} unique items",
			"values": [5, 10, 25, 50, 100],
			"stat": "items_collected"
		},
		{
			"id": "progamer",
			"name": "Pro Gamer",
			"base_desc": "Reach {value} MMR",
			"values": [1100, 1300, 1500, 2000, 2500],
			"stat": "mmr"
		}
	]
	
	# Generate all tier variations
	for achievement in achievements:
		for tier in range(5):  # 0-4 for 5 tiers
			var achievement_id = "%s_tier_%d" % [achievement.id, tier + 1]
			var tier_value = achievement.values[tier]
			
			# Generate icon filename based on achievement id and tier
			var icon_filename = "%s_ach_t%d.png" % [achievement.id, tier + 1]
			
			achievement_definitions[achievement_id] = {
				"base_id": achievement.id,
				"name": "%s %s" % [TIER_NAMES[tier], achievement.name],
				"description": achievement.base_desc.replace("{value}", str(tier_value)),
				"icon": icon_filename,  # Now tier-specific
				"tier": tier + 1,
				"tier_name": TIER_NAMES[tier],
				"tier_color": TIER_COLORS[tier],
				"star_reward": TIER_STAR_REWARDS[tier],
				"xp_reward": TIER_XP_REWARDS[tier],
				"requirement": {
					"type": achievement.stat,
					"value": tier_value,
					"inverse": achievement.get("inverse", false)
				}
			}

func check_achievements():
	"""Check all achievements against current stats"""
	var stats = StatsManager.get_total_stats()
	var current_game = StatsManager.current_game_stats
	
	# Group achievements by base_id
	var achievements_by_base = {}
	for id in achievement_definitions:
		var base_id = achievement_definitions[id].base_id
		if not achievements_by_base.has(base_id):
			achievements_by_base[base_id] = []
		achievements_by_base[base_id].append(id)
	
	# Check each achievement group
	for base_id in achievements_by_base:
		var achievement_ids = achievements_by_base[base_id]
		# Sort by tier (tier_1 to tier_5)
		achievement_ids.sort()
		
		for achievement_id in achievement_ids:
			var achievement = achievement_definitions[achievement_id]
			var requirement = achievement.requirement
			var tier = achievement.tier
			
			# Skip if already unlocked
			if get_unlocked_tier(base_id) >= tier:
				continue
			
			# Get current value
			var current_value = _get_stat_value(requirement.type, stats, current_game)
			
			# Check if requirement met
			var unlocked = false
			if requirement.get("inverse", false):
				# For "lower is better" stats
				if requirement.type == "fastest_clear" and stats.fastest_clear > 0:
					unlocked = stats.fastest_clear <= requirement.value
			else:
				unlocked = current_value >= requirement.value
			
			# Update progress
			var progress = 0.0
			if requirement.get("inverse", false):
				if current_value > 0:
					progress = min(float(requirement.value) / float(current_value), 1.0)
			else:
				progress = min(float(current_value) / float(requirement.value), 1.0)
			
			achievement_progress[achievement_id] = progress
			achievement_progress_updated.emit(achievement_id, progress)
			
			# Unlock if met
			if unlocked:
				unlock_achievement_tier(base_id, tier)
				break  # Only unlock one tier at a time

func unlock_achievement_tier(base_id: String, tier: int):
	"""Unlock a specific tier of an achievement"""
	var current_tier = get_unlocked_tier(base_id)
	
	_debug_log("🔓 Attempting to unlock %s tier %d (current: %d)" % [base_id, tier, current_tier])
	
	# Can only unlock the next tier
	if tier != current_tier + 1:
		_debug_log("   ❌ Cannot unlock tier %d (not next tier)" % tier)
		return
	
	# Update unlocked tier
	unlocked_tiers[base_id] = tier
	
	# Add to new achievements
	var achievement_id = "%s_tier_%d" % [base_id, tier]
	if achievement_id not in new_achievements:
		new_achievements.append(achievement_id)
	
	# Track for session
	if achievement_id not in session_achievements:
		session_achievements.append(achievement_id)
	
	# Update progress
	achievement_progress[achievement_id] = 1.0
	
	# Save and emit signal
	save_achievements()
	achievement_unlocked.emit(base_id, tier)
	
	var achievement = achievement_definitions[achievement_id]
	_debug_log("   ✅ UNLOCKED: %s" % achievement.name)
	_debug_log("   Rewards available: %d⭐ %dXP" % [achievement.star_reward, achievement.xp_reward])

func claim_achievement_tier(base_id: String, tier: int):
	"""Claim rewards for an unlocked achievement tier - NOW WITH MULTI-TIER CLAIMING"""
	_debug_log("💰 Claiming %s tier %d" % [base_id, tier])
	
	# Check if unlocked
	if get_unlocked_tier(base_id) < tier:
		_debug_log("   ❌ Cannot claim - tier %d not unlocked" % tier)
		return false
	
	# Check if already claimed
	if get_claimed_tier(base_id) >= tier:
		_debug_log("   ❌ Already claimed tier %d" % tier)
		return false
	
	# NEW: Claim all unclaimed lower tiers first
	var current_claimed = get_claimed_tier(base_id)
	var total_stars = 0
	var total_xp = 0
	var tiers_claimed = []
	
	# Claim from lowest unclaimed to requested tier
	for claim_tier in range(current_claimed + 1, tier + 1):
		var achievement_id = "%s_tier_%d" % [base_id, claim_tier]
		var achievement = achievement_definitions[achievement_id]
		
		_debug_log("   📦 Claiming tier %d: %s" % [claim_tier, achievement.name])
		_debug_log("      Rewards: %d⭐ %dXP" % [achievement.star_reward, achievement.xp_reward])
		
		total_stars += achievement.star_reward
		total_xp += achievement.xp_reward
		tiers_claimed.append(claim_tier)
		
		# Remove from new list
		if achievement_id in new_achievements:
			new_achievements.erase(achievement_id)
	
	# Award all rewards at once
	if StarManager:
		StarManager.add_stars(total_stars, "achievement_%s_tiers_%s" % [base_id, tiers_claimed])
		_debug_log("   ⭐ Total stars awarded: %d" % total_stars)
	
	if XPManager and XPManager.has_method("add_xp"):
		XPManager.add_xp(total_xp, "achievement_%s_tiers_%s" % [base_id, tiers_claimed])
		_debug_log("   📊 Total XP awarded: %d" % total_xp)
	
	# Update claimed tier to highest claimed
	claimed_tiers[base_id] = tier
	
	# Save and emit
	save_achievements()
	achievement_claimed.emit(base_id, tier)
	
	_debug_log("   ✅ Successfully claimed tiers %s" % str(tiers_claimed))
	return true

func get_unlocked_tier(base_id: String) -> int:
	"""Get the highest unlocked tier for an achievement (0-5)"""
	return unlocked_tiers.get(base_id, 0)

func get_claimed_tier(base_id: String) -> int:
	"""Get the highest claimed tier for an achievement (0-5)"""
	return claimed_tiers.get(base_id, 0)

func is_achievement_new(achievement_id: String) -> bool:
	"""Check if an achievement is newly unlocked"""
	return achievement_id in new_achievements

func mark_achievement_viewed(achievement_id: String):
	"""Mark an achievement as viewed (remove NEW badge)"""
	if achievement_id in new_achievements:
		new_achievements.erase(achievement_id)
		save_achievements()

func get_achievement_progress(base_id: String, tier: int) -> float:
	"""Get progress toward a specific tier"""
	var achievement_id = "%s_tier_%d" % [base_id, tier]
	
	# If already unlocked, return 1.0
	if get_unlocked_tier(base_id) >= tier:
		return 1.0
	
	return achievement_progress.get(achievement_id, 0.0)

func get_all_base_achievements() -> Array:
	"""Get list of all base achievement IDs (without tier suffixes)"""
	var base_ids = []
	var seen = {}
	
	for id in achievement_definitions:
		var base_id = achievement_definitions[id].base_id
		if not seen.has(base_id):
			seen[base_id] = true
			base_ids.append(base_id)
	
	return base_ids

func _get_stat_value(stat_type: String, stats: Dictionary, current_game: Dictionary):
	"""Get current value for a stat type"""
	match stat_type:
		"games_played": 
			return stats.games_played
		"total_score": 
			return stats.total_score
		"highscore": 
			return StatsManager.get_highscore().score
		"total_rounds": 
			return stats.total_rounds
		"fastest_clear": 
			return stats.fastest_clear if stats.fastest_clear > 0 else 999
		"combo": 
			return StatsManager.get_longest_combo().combo
		"perfect_rounds": 
			return stats.perfect_rounds
		"peak_clears_3": 
			return stats.peak_clears.get("3", 0)
		"most_cards_remaining": 
			return stats.most_cards_remaining
		"suit_bonuses": 
			return stats.suit_bonuses
		"mp_wins":
			# Aggregate wins across all multiplayer modes
			var total_wins = 0
			if StatsManager.multiplayer_stats:
				for mode in StatsManager.multiplayer_stats:
					total_wins += StatsManager.multiplayer_stats[mode].get("first_place", 0)
			return total_wins
		"mp_games":
			# Aggregate games across all multiplayer modes
			var total_games = 0
			if StatsManager.multiplayer_stats:
				for mode in StatsManager.multiplayer_stats:
					total_games += StatsManager.multiplayer_stats[mode].get("games", 0)
			return total_games
		"best_win_streak":
			# Get best win streak across all modes
			var best_streak = 0
			if StatsManager.multiplayer_stats:
				for mode in StatsManager.multiplayer_stats:
					var mode_streak = StatsManager.multiplayer_stats[mode].get("best_win_streak", 0)
					if mode_streak > best_streak:
						best_streak = mode_streak
			return best_streak
		"login_streak":
			# Directly access the login_streak property
			return StatsManager.login_streak if StatsManager else 0
		"items_collected":
			# Get count from EquipmentManager
			return EquipmentManager.get_owned_count() if EquipmentManager else 0
		"mmr":
			# Get MMR from MultiplayerManager's player data
			if MultiplayerManager:
				var player_data = MultiplayerManager.get_local_player_data()
				return player_data.get("stats", {}).get("mmr", 1000)
			return 1000  # Default MMR
		_: 
			return 0

func save_achievements():
	var save_data = {
		"version": 5,  # New version for 5-tier system
		"unlocked_tiers": unlocked_tiers,
		"claimed_tiers": claimed_tiers,
		"progress": achievement_progress,
		"new": new_achievements
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
			
			if save_data and save_data.has("version") and save_data.version == 5:
				unlocked_tiers = save_data.get("unlocked_tiers", {})
				claimed_tiers = save_data.get("claimed_tiers", {})
				achievement_progress = save_data.get("progress", {})
				new_achievements.assign(save_data.get("new", []))
			else:
				# Reset for new version
				print("Resetting achievements for new 5-tier system")
				reset_all_achievements()

func reset_all_achievements():
	"""Reset all achievement data"""
	unlocked_tiers.clear()
	claimed_tiers.clear()
	achievement_progress.clear()
	new_achievements.clear()
	save_achievements()
	print("All achievements reset")

func get_total_stars_available() -> int:
	"""Get total possible stars from all achievements"""
	var total = 0
	for tier_stars in TIER_STAR_REWARDS:
		total += tier_stars
	return total * 15  # 15 achievements

func get_total_stars_earned() -> int:
	"""Get total stars earned from claimed achievements"""
	var total = 0
	for base_id in claimed_tiers:
		var tier = claimed_tiers[base_id]
		for i in range(tier):
			total += TIER_STAR_REWARDS[i]
	return total

func get_and_clear_session_achievements() -> Array:
	"""Get achievements unlocked in this session and clear the list"""
	var achievements = session_achievements.duplicate()
	session_achievements.clear()
	return achievements

func clear_session_achievements():
	"""Clear session achievements when returning to menu"""
	session_achievements.clear()
