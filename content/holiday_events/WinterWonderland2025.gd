# WinterWonderland2025.gd - Winter Holiday Event Content Definition
# Location: res://Pyramids/content/holiday_events/WinterWonderland2025.gd
# Last Updated: Created Winter 2025 holiday event with 35 missions

extends Node

# ============================================================================
# EVENT METADATA
# ============================================================================

const EVENT_ID = "winter_2025"
const EVENT_NAME = "Winter Wonderland"
const EVENT_THEME = "winter"
const START_DATE = "2025-12-20"  # Event starts December 20, 2025
const END_DATE = "2025-12-27"    # Event ends December 27, 2025 (7 days)
const DURATION_DAYS = 7          # Manual override - can be any number

# Visual/UI elements
const CURRENCY_NAME = "Snowflakes"
const CURRENCY_ICON = "❄️"
const EVENT_COLOR = "#5DADE2"  # Winter blue

# ============================================================================
# MISSION DEFINITIONS (35 missions total - all available day 1)
# ============================================================================
# Mission Structure: Same as Season Pass
# {
#   "id": unique identifier (required)
#   "name": display name (required)
#   "desc": description (required)
#   "target": target value (required)
#   "track": stat to track from StatsManager (required)
#   "reward_hp": holiday points reward (required)
#   "difficulty": "easy", "medium", "hard", "extreme" (for UI sorting)
# }
#
# Holiday Event Mission Design Philosophy:
# - All missions available immediately (no weekly unlocks)
# - Mix of difficulties so players can choose their path
# - Shorter timeframe (7 days) means more achievable goals than season pass
# - Players can focus on what they enjoy (casual or hardcore)
# ============================================================================

const MISSIONS = [
	# ========================================================================
	# EASY MISSIONS (Quick wins for casual players)
	# ========================================================================
	{
		"id": "winter_play_1",
		"name": "First Snowfall",
		"desc": "Play 1 game",
		"target": 1,
		"track": "games_played",
		"reward_hp": 2,
		"difficulty": "easy"
	},
	{
		"id": "winter_play_3",
		"name": "Snow Day",
		"desc": "Play 3 games",
		"target": 3,
		"track": "games_played",
		"reward_hp": 3,
		"difficulty": "easy"
	},
	{
		"id": "winter_win_1",
		"name": "Winter Victory",
		"desc": "Win 1 game",
		"target": 1,
		"track": "games_won",
		"reward_hp": 3,
		"difficulty": "easy"
	},
	{
		"id": "winter_score_15k",
		"name": "Frosted Score",
		"desc": "Score 15,000 in one game",
		"target": 15000,
		"track": "high_score",
		"reward_hp": 2,
		"difficulty": "easy"
	},
	{
		"id": "winter_total_50k",
		"name": "Snowball Rolling",
		"desc": "Score 50,000 total points",
		"target": 50000,
		"track": "total_score",
		"reward_hp": 3,
		"difficulty": "easy"
	},
	{
		"id": "winter_combo_5",
		"name": "Icy Combo",
		"desc": "Achieve a 5+ combo",
		"target": 1,
		"track": "combo_5",
		"reward_hp": 2,
		"difficulty": "easy"
	},
	{
		"id": "winter_cards_30",
		"name": "Card Collector",
		"desc": "Click 30 cards",
		"target": 30,
		"track": "cards_clicked",
		"reward_hp": 2,
		"difficulty": "easy"
	},
	{
		"id": "winter_aces_5",
		"name": "Ace in the Snow",
		"desc": "Play 5 Aces",
		"target": 5,
		"track": "aces_played",
		"reward_hp": 2,
		"difficulty": "easy"
	},
	
	# ========================================================================
	# MEDIUM MISSIONS (Moderate challenge)
	# ========================================================================
	{
		"id": "winter_play_7",
		"name": "Week of Winter",
		"desc": "Play 7 games",
		"target": 7,
		"track": "games_played",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_win_5",
		"name": "Snowman's Streak",
		"desc": "Win 5 games",
		"target": 5,
		"track": "games_won",
		"reward_hp": 6,
		"difficulty": "medium"
	},
	{
		"id": "winter_score_40k",
		"name": "Blizzard Score",
		"desc": "Score 40,000 in one game",
		"target": 40000,
		"track": "high_score",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_total_200k",
		"name": "Avalanche Points",
		"desc": "Score 200,000 total points",
		"target": 200000,
		"track": "total_score",
		"reward_hp": 6,
		"difficulty": "medium"
	},
	{
		"id": "winter_combo_10",
		"name": "Winter Chain",
		"desc": "Achieve a 10+ combo",
		"target": 1,
		"track": "combo_10",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_perfect_2",
		"name": "Pristine Snow",
		"desc": "Complete 2 perfect rounds",
		"target": 2,
		"track": "perfect_rounds",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_cards_100",
		"name": "Century Freeze",
		"desc": "Click 100 cards",
		"target": 100,
		"track": "cards_clicked",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_peaks_9",
		"name": "Mountain Summit",
		"desc": "Clear all 9 peaks in one game",
		"target": 1,
		"track": "peak_clears_9",
		"reward_hp": 6,
		"difficulty": "medium"
	},
	{
		"id": "winter_suit_bonus_5",
		"name": "Matching Mittens",
		"desc": "Trigger 5 suit bonuses",
		"target": 5,
		"track": "suit_bonus",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_kings_8",
		"name": "Royal Winter",
		"desc": "Play 8 Kings",
		"target": 8,
		"track": "kings_played",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	{
		"id": "winter_aces_10",
		"name": "Ace Flurry",
		"desc": "Play 10 Aces",
		"target": 10,
		"track": "aces_played",
		"reward_hp": 5,
		"difficulty": "medium"
	},
	
	# ========================================================================
	# HARD MISSIONS (Challenging goals)
	# ========================================================================
	{
		"id": "winter_play_15",
		"name": "Winter Marathon",
		"desc": "Play 15 games",
		"target": 15,
		"track": "games_played",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	{
		"id": "winter_win_10",
		"name": "Unstoppable Winter",
		"desc": "Win 10 games",
		"target": 10,
		"track": "games_won",
		"reward_hp": 10,
		"difficulty": "hard"
	},
	{
		"id": "winter_score_70k",
		"name": "Ice Palace",
		"desc": "Score 70,000 in one game",
		"target": 70000,
		"track": "high_score",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	{
		"id": "winter_total_500k",
		"name": "Half Million Freeze",
		"desc": "Score 500,000 total points",
		"target": 500000,
		"track": "total_score",
		"reward_hp": 10,
		"difficulty": "hard"
	},
	{
		"id": "winter_combo_15",
		"name": "Frozen Cascade",
		"desc": "Achieve a 15+ combo",
		"target": 1,
		"track": "combo_15",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	{
		"id": "winter_perfect_5",
		"name": "Crystal Clear",
		"desc": "Complete 5 perfect rounds",
		"target": 5,
		"track": "perfect_rounds",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	{
		"id": "winter_cards_250",
		"name": "Card Blizzard",
		"desc": "Click 250 cards",
		"target": 250,
		"track": "cards_clicked",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	{
		"id": "winter_peaks_9_triple",
		"name": "Triple Summit",
		"desc": "Clear all peaks 3 times",
		"target": 3,
		"track": "peak_clears_9",
		"reward_hp": 10,
		"difficulty": "hard"
	},
	{
		"id": "winter_suit_bonus_12",
		"name": "Perfect Pairs",
		"desc": "Trigger 12 suit bonuses",
		"target": 12,
		"track": "suit_bonus",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	{
		"id": "winter_kings_15",
		"name": "King of Winter",
		"desc": "Play 15 Kings",
		"target": 15,
		"track": "kings_played",
		"reward_hp": 8,
		"difficulty": "hard"
	},
	
	# ========================================================================
	# EXTREME MISSIONS (For the hardcore grinders)
	# ========================================================================
	{
		"id": "winter_play_25",
		"name": "Eternal Winter",
		"desc": "Play 25 games",
		"target": 25,
		"track": "games_played",
		"reward_hp": 15,
		"difficulty": "extreme"
	},
	{
		"id": "winter_win_20",
		"name": "Winter Champion",
		"desc": "Win 20 games",
		"target": 20,
		"track": "games_won",
		"reward_hp": 18,
		"difficulty": "extreme"
	},
	{
		"id": "winter_score_100k",
		"name": "Glacial Perfection",
		"desc": "Score 100,000 in one game",
		"target": 100000,
		"track": "high_score",
		"reward_hp": 15,
		"difficulty": "extreme"
	},
	{
		"id": "winter_total_1m",
		"name": "Million Snowflakes",
		"desc": "Score 1,000,000 total points",
		"target": 1000000,
		"track": "total_score",
		"reward_hp": 18,
		"difficulty": "extreme"
	},
	{
		"id": "winter_combo_25",
		"name": "Absolute Zero",
		"desc": "Achieve a 25+ combo",
		"target": 1,
		"track": "combo_25",
		"reward_hp": 15,
		"difficulty": "extreme"
	}
]

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func is_event_active(current_date: String) -> bool:
	"""Check if the holiday event is currently active"""
	var current_unix = _date_string_to_unix(current_date)
	var start_unix = _date_string_to_unix(START_DATE)
	var end_unix = _date_string_to_unix(END_DATE)
	
	# Add 24 hours to end date to include the final day
	end_unix += 86400
	
	return current_unix >= start_unix and current_unix < end_unix

static func get_days_remaining(current_date: String) -> int:
	"""Get number of days remaining in event"""
	var current_unix = _date_string_to_unix(current_date)
	var end_unix = _date_string_to_unix(END_DATE)
	
	# Add 24 hours to include the final day
	end_unix += 86400
	
	var diff = end_unix - current_unix
	return max(0, int(diff / 86400))  # Convert seconds to days

static func get_hours_remaining(current_date: String) -> int:
	"""Get number of hours remaining in event (useful for last day)"""
	var current_unix = _date_string_to_unix(current_date)
	var end_unix = _date_string_to_unix(END_DATE)
	
	# Add 24 hours to include the final day
	end_unix += 86400
	
	var diff = end_unix - current_unix
	return max(0, int(diff / 3600))  # Convert seconds to hours

static func get_event_progress_percentage(current_date: String) -> float:
	"""Get how far through the event we are (0.0 to 1.0)"""
	var current_unix = _date_string_to_unix(current_date)
	var start_unix = _date_string_to_unix(START_DATE)
	var end_unix = _date_string_to_unix(END_DATE) + 86400
	
	if current_unix < start_unix:
		return 0.0
	if current_unix >= end_unix:
		return 1.0
	
	var total_duration = end_unix - start_unix
	var elapsed = current_unix - start_unix
	return float(elapsed) / float(total_duration)

static func get_missions_by_difficulty(difficulty: String) -> Array:
	"""Get all missions of a specific difficulty level"""
	var filtered = []
	for mission in MISSIONS:
		if mission.get("difficulty", "") == difficulty:
			filtered.append(mission)
	return filtered

static func get_total_hp_available() -> int:
	"""Calculate total HP available from all missions"""
	var total = 0
	for mission in MISSIONS:
		total += mission.get("reward_hp", 0)
	return total

static func get_mission_count_by_difficulty() -> Dictionary:
	"""Get count of missions per difficulty level"""
	var counts = {
		"easy": 0,
		"medium": 0,
		"hard": 0,
		"extreme": 0
	}
	for mission in MISSIONS:
		var diff = mission.get("difficulty", "medium")
		if counts.has(diff):
			counts[diff] += 1
	return counts

static func _date_string_to_unix(date_string: String) -> int:
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
