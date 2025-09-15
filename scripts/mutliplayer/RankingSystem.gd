# RankingSystem.gd - Handles MMR calculations for multiplayer
# Location: res://Pyramids/scripts/multiplayer/RankingSystem.gd
# Last Updated: Created flexible ranking system for any lobby size [Date]
#
# Dependencies:
#   - StatsManager: To update multiplayer stats
#   - UIStyleManager: For rank colors (not used here, UI handles that)
#
# Flow: Game End → RankingSystem.calculate_mmr_change() → StatsManager update
#
# Functionality:
#   • Calculate MMR changes based on placement and lobby size
#   • First place always +25, last always -25, scaled in between
#   • Determine rank tiers from MMR values
#   • Support for any lobby size (2-8 players)
#
# Usage:
#   var mmr_change = RankingSystem.calculate_mmr_change(current_mmr, placement, player_count)
#   var tier = RankingSystem.get_rank_tier(mmr)

class_name RankingSystem
extends RefCounted

# === CONSTANTS ===

# MMR calculation constants
const BASE_K_FACTOR: int = 32  # Standard ELO K-factor (for future use)
const MAX_PLACEMENT_BONUS: int = 25  # First place bonus
const MAX_PLACEMENT_PENALTY: int = -25  # Last place penalty
const DEFAULT_MMR: int = 1000  # Starting MMR for new players
const MIN_MMR: int = 0  # Can't go below 0
const MAX_MMR: int = 5000  # Soft cap

# Rank tier definitions with MMR ranges
const RANK_TIERS: Dictionary = {
	"Bronze": {"min": 0, "max": 1250, "division_size": 250},
	"Silver": {"min": 1250, "max": 1500, "division_size": 250},
	"Gold": {"min": 1500, "max": 1750, "division_size": 250},
	"Platinum": {"min": 1750, "max": 2000, "division_size": 250},
	"Diamond": {"min": 2000, "max": 99999, "division_size": 500}
}

# Minimum games before ranked
const MIN_GAMES_FOR_RANKED: int = 5

# === PUBLIC STATIC METHODS ===

static func calculate_mmr_change(current_mmr: int, placement: int, player_count: int, lobby_avg_mmr: int = DEFAULT_MMR) -> int:
	"""
	Calculate MMR change based on placement and lobby size
	
	Args:
		current_mmr: Player's current MMR
		placement: Final placement (1 = first, player_count = last)
		player_count: Total players in the lobby
		lobby_avg_mmr: Average MMR of all players (for future ELO calculation)
	
	Returns:
		MMR change (positive or negative)
	"""
	
	# Validate inputs
	if placement < 1 or placement > player_count:
		push_error("Invalid placement %d for %d players" % [placement, player_count])
		return 0
	
	if player_count < 2:
		# No MMR change for solo games
		return 0
	
	# Linear interpolation between +25 (1st) and -25 (last)
	var placement_bonus: int = 0
	
	if player_count == 2:
		# Simple win/loss for 1v1
		placement_bonus = MAX_PLACEMENT_BONUS if placement == 1 else MAX_PLACEMENT_PENALTY
	else:
		# Scale linearly based on position
		var position_ratio: float = float(placement - 1) / float(player_count - 1)
		var bonus_range: float = MAX_PLACEMENT_BONUS - MAX_PLACEMENT_PENALTY
		placement_bonus = int(MAX_PLACEMENT_BONUS - (position_ratio * bonus_range))
	
	# TODO: Add proper ELO calculation when we have all player MMRs
	# For now, we could add a simple modifier based on lobby strength
	var elo_modifier: float = 1.0
	if lobby_avg_mmr != DEFAULT_MMR and current_mmr != DEFAULT_MMR:
		# Slightly adjust based on lobby difficulty
		# Playing against stronger opponents = bigger rewards/smaller penalties
		var difficulty_factor: float = float(lobby_avg_mmr) / float(current_mmr)
		difficulty_factor = clamp(difficulty_factor, 0.5, 1.5)  # Limit adjustment
		
		if placement_bonus > 0:
			# Won against stronger players = more points
			elo_modifier = difficulty_factor
		else:
			# Lost to stronger players = less penalty
			elo_modifier = 2.0 - difficulty_factor
	
	var final_change: int = int(placement_bonus * elo_modifier)
	
	# Ensure MMR stays within bounds
	var new_mmr: int = current_mmr + final_change
	if new_mmr < MIN_MMR:
		final_change = MIN_MMR - current_mmr
	elif new_mmr > MAX_MMR:
		final_change = MAX_MMR - current_mmr
	
	return final_change

static func get_rank_tier(mmr: int) -> String:
	"""Get rank tier name from MMR value"""
	for tier_name in RANK_TIERS:
		var tier: Dictionary = RANK_TIERS[tier_name]
		if mmr >= tier.min and mmr < tier.max:
			return tier_name
	return "Bronze"  # Default to Bronze

static func get_rank_division(mmr: int) -> int:
	"""
	Get division within rank (1-5)
	Returns 0 if unranked
	"""
	var tier_name: String = get_rank_tier(mmr)
	var tier: Dictionary = RANK_TIERS.get(tier_name, {})
	
	if tier.is_empty():
		return 0
	
	# Calculate division within tier
	var mmr_in_tier: int = mmr - tier.min
	var division_size: int = tier.get("division_size", 250)
	var division: int = (mmr_in_tier / division_size) + 1
	
	# Cap at 5 divisions max
	return min(division, 5)

static func get_rank_display_name(mmr: int, games_played: int = 0) -> String:
	"""Get full rank display name (e.g., 'Gold III' or 'Unranked')"""
	if games_played < MIN_GAMES_FOR_RANKED:
		return "Unranked (%d/%d)" % [games_played, MIN_GAMES_FOR_RANKED]
	
	var tier: String = get_rank_tier(mmr)
	var division: int = get_rank_division(mmr)
	
	# Roman numerals for divisions
	var roman_numerals: Array[String] = ["", "I", "II", "III", "IV", "V"]
	
	if division > 0 and division < roman_numerals.size():
		return "%s %s" % [tier, roman_numerals[division]]
	else:
		return tier

static func get_mmr_to_next_division(mmr: int) -> int:
	"""Calculate MMR points needed to reach next division"""
	var tier_name: String = get_rank_tier(mmr)
	var tier: Dictionary = RANK_TIERS.get(tier_name, {})
	
	if tier.is_empty():
		return 0
	
	var division_size: int = tier.get("division_size", 250)
	var mmr_in_tier: int = mmr - tier.min
	var current_division_start: int = (mmr_in_tier / division_size) * division_size
	var next_division_start: int = current_division_start + division_size
	
	return next_division_start - mmr_in_tier

static func get_placement_distribution(player_count: int) -> Array:
	"""
	Get MMR changes for all placements in a lobby
	Useful for displaying potential gains/losses
	"""
	var distribution: Array = []
	
	for placement in range(1, player_count + 1):
		var change: int = calculate_mmr_change(DEFAULT_MMR, placement, player_count)
		distribution.append({
			"placement": placement,
			"mmr_change": change
		})
	
	return distribution

# === HELPER METHODS FOR FUTURE FEATURES ===

static func calculate_lobby_average_mmr(player_mmrs: Array) -> int:
	"""Calculate average MMR of all players in lobby"""
	if player_mmrs.is_empty():
		return DEFAULT_MMR
	
	var total: int = 0
	for mmr in player_mmrs:
		total += mmr
	
	return int(total / player_mmrs.size())

static func calculate_expected_placement(player_mmr: int, lobby_mmrs: Array) -> float:
	"""
	Calculate expected placement based on ELO probability
	Lower number = better expected placement
	"""
	if lobby_mmrs.is_empty():
		return 1.0
	
	var better_than_count: float = 0.0
	
	for opponent_mmr in lobby_mmrs:
		if opponent_mmr == player_mmr:
			continue  # Skip self
		
		# ELO win probability formula
		var win_probability: float = 1.0 / (1.0 + pow(10, float(opponent_mmr - player_mmr) / 400.0))
		better_than_count += win_probability
	
	# Expected placement = players you're worse than + 1
	return float(lobby_mmrs.size()) - better_than_count

static func simulate_season_reset(current_mmr: int) -> int:
	"""
	Simulate a soft reset at season end
	Pulls MMR toward center (1500)
	"""
	var center_mmr: int = 1500
	var reset_strength: float = 0.25  # How much to pull toward center
	
	var difference: int = current_mmr - center_mmr
	var new_mmr: int = center_mmr + int(difference * (1.0 - reset_strength))
	
	return clamp(new_mmr, MIN_MMR, MAX_MMR)

# === DEBUG METHODS ===

static func debug_print_lobby_distribution(player_count: int) -> void:
	"""Print MMR changes for all positions in a lobby"""
	print("\n=== MMR Distribution for %d Players ===" % player_count)
	var distribution: Array = get_placement_distribution(player_count)
	
	for entry in distribution:
		var sign: String = "+" if entry.mmr_change >= 0 else ""
		print("Position %d: %s%d MMR" % [entry.placement, sign, entry.mmr_change])
	print("=====================================\n")

static func debug_test_calculations() -> void:
	"""Test various calculation scenarios"""
	print("\n=== Testing RankingSystem ===")
	
	# Test different lobby sizes
	var test_cases: Array = [
		{"players": 8, "placement": 1, "expected": 25},
		{"players": 8, "placement": 4, "expected": 4},
		{"players": 8, "placement": 8, "expected": -25},
		{"players": 4, "placement": 1, "expected": 25},
		{"players": 4, "placement": 2, "expected": 8},
		{"players": 4, "placement": 4, "expected": -25},
		{"players": 2, "placement": 1, "expected": 25},
		{"players": 2, "placement": 2, "expected": -25}
	]
	
	for test in test_cases:
		var result: int = calculate_mmr_change(1000, test.placement, test.players)
		var status: String = "✓" if result == test.expected else "✗"
		print("%s %d players, pos %d: %+d MMR (expected %+d)" % [
			status, test.players, test.placement, result, test.expected
		])
	
	# Test rank tiers
	print("\n--- Rank Tiers ---")
	var test_mmrs: Array = [0, 500, 1250, 1500, 1750, 2000, 3000]
	for mmr in test_mmrs:
		print("MMR %d: %s" % [mmr, get_rank_display_name(mmr, 10)])
	
	print("=============================\n")
