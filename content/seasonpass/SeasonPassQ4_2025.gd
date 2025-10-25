# SeasonPassQ1_2025.gd - Q1 2025 Season Pass Content Definition
# Location: res://content/season_passes/SeasonPassQ1_2025.gd
# Last Updated: Created Q1 2025 season with 12 weeks of progressive missions

extends Node

# ============================================================================
# SEASON METADATA
# ============================================================================

const SEASON_ID = "q4_2025"
const SEASON_NAME = "Castle Foundations"
const SEASON_THEME = "medieval"
const START_DATE = "2025-10-01"  # Season starts Jan 1, 2025
const END_DATE = "2025-12-31"    # Season ends March 31, 2025

# Week unlock dates (Mondays at 00:00 server time)
# These are the dates when each week's missions become available
const WEEK_UNLOCK_DATES = [
	"2025-10-06",  # Week 1  - Monday, January 6
	"2025-10-13",  # Week 2  - Monday, January 13
	"2025-10-20",  # Week 3  - Monday, January 20
	"2025-10-27",  # Week 4  - Monday, January 27
	"2025-11-03",  # Week 5  - Monday, February 3
	"2025-11-10",  # Week 6  - Monday, February 10
	"2025-11-17",  # Week 7  - Monday, February 17
	"2025-11-24",  # Week 8  - Monday, February 24
	"2025-11-31",  # Week 9  - Monday, March 3
	"2025-12-7",  # Week 10 - Monday, March 10
	"2025-12-14",  # Week 11 - Monday, March 17
	"2025-12-21",  # Week 12 - Monday, March 24 (last week)
]

# ============================================================================
# MISSION DEFINITIONS (120 missions total: 10 per week × 12 weeks)
# ============================================================================
# Mission Structure:
# {
#   "id": unique identifier (required)
#   "name": display name (required)
#   "desc": description (required)
#   "target": target value (required)
#   "track": stat to track from StatsManager (required)
#   "reward_sp": season points reward (required)
# }
#
# Available track types from StatsManager:
# - games_played: Total games completed
# - games_won: Total games won
# - high_score: Score X in a single game
# - total_score: Cumulative score across all games
# - combo_10, combo_15, combo_20: Achieve combo of X+
# - perfect_rounds: Complete rounds with no invalid clicks
# - peak_clears_9: Clear all 3 peaks in a game
# - fastest_clear: Complete game in under X seconds
# - cards_clicked: Click X cards total
# - suit_bonus: Trigger X suit bonuses
# - aces_played: Play X aces
# - kings_played: Play X kings
# ============================================================================

const MISSIONS = {
	# ========================================================================
	# WEEK 1 - Beginner Friendly (Available Jan 6)
	# ========================================================================
	"week_1": [
		{
			"id": "q1_w1_play_1",
			"name": "First Step",
			"desc": "Play 1 game",
			"target": 1,
			"track": "games_played",
			"reward_sp": 2
		},
		{
			"id": "q1_w1_play_3",
			"name": "Getting Started",
			"desc": "Play 3 games",
			"target": 3,
			"track": "games_played",
			"reward_sp": 3
		},
		{
			"id": "q1_w1_win_1",
			"name": "First Victory",
			"desc": "Win 1 game",
			"target": 1,
			"track": "games_won",
			"reward_sp": 3
		},
		{
			"id": "q1_w1_score_10k",
			"name": "Point Collector",
			"desc": "Score 10,000 in one game",
			"target": 10000,
			"track": "high_score",
			"reward_sp": 2
		},
		{
			"id": "q1_w1_total_25k",
			"name": "Score Builder",
			"desc": "Score 25,000 total points",
			"target": 25000,
			"track": "total_score",
			"reward_sp": 3
		},
		{
			"id": "q1_w1_combo_5",
			"name": "Combo Starter",
			"desc": "Achieve a 5+ combo",
			"target": 1,
			"track": "combo_5",
			"reward_sp": 2
		},
		{
			"id": "q1_w1_cards_25",
			"name": "Card Clicker",
			"desc": "Click 25 cards",
			"target": 25,
			"track": "cards_clicked",
			"reward_sp": 2
		},
		{
			"id": "q1_w1_peaks_1",
			"name": "Peak Performer",
			"desc": "Clear 1 peak in any game",
			"target": 1,
			"track": "peak_clears_any",
			"reward_sp": 2
		},
		{
			"id": "q1_w1_aces_3",
			"name": "Ace Hunter",
			"desc": "Play 3 Aces",
			"target": 3,
			"track": "aces_played",
			"reward_sp": 2
		},
		{
			"id": "q1_w1_kings_3",
			"name": "King Collector",
			"desc": "Play 3 Kings",
			"target": 3,
			"track": "kings_played",
			"reward_sp": 2
		}
	],
	
	# ========================================================================
	# WEEK 2 - Building Momentum (Available Jan 13)
	# ========================================================================
	"week_2": [
		{
			"id": "q1_w2_play_5",
			"name": "Regular Player",
			"desc": "Play 5 games",
			"target": 5,
			"track": "games_played",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_win_3",
			"name": "Triple Victory",
			"desc": "Win 3 games",
			"target": 3,
			"track": "games_won",
			"reward_sp": 4
		},
		{
			"id": "q1_w2_score_20k",
			"name": "Score Climber",
			"desc": "Score 20,000 in one game",
			"target": 20000,
			"track": "high_score",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_total_75k",
			"name": "Point Accumulator",
			"desc": "Score 75,000 total points",
			"target": 75000,
			"track": "total_score",
			"reward_sp": 4
		},
		{
			"id": "q1_w2_combo_8",
			"name": "Combo Builder",
			"desc": "Achieve an 8+ combo",
			"target": 1,
			"track": "combo_8",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_cards_50",
			"name": "Card Counter",
			"desc": "Click 50 cards",
			"target": 50,
			"track": "cards_clicked",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_peaks_3",
			"name": "Peak Clearer",
			"desc": "Clear 3 peaks total",
			"target": 3,
			"track": "peak_clears_any",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_suit_bonus_3",
			"name": "Suit Matcher",
			"desc": "Trigger 3 suit bonuses",
			"target": 3,
			"track": "suit_bonus",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_aces_5",
			"name": "Ace Specialist",
			"desc": "Play 5 Aces",
			"target": 5,
			"track": "aces_played",
			"reward_sp": 3
		},
		{
			"id": "q1_w2_kings_5",
			"name": "King Master",
			"desc": "Play 5 Kings",
			"target": 5,
			"track": "kings_played",
			"reward_sp": 3
		}
	],
	
	# ========================================================================
	# WEEK 3 - Skill Development (Available Jan 20)
	# ========================================================================
	"week_3": [
		{
			"id": "q1_w3_play_7",
			"name": "Weekly Warrior",
			"desc": "Play 7 games",
			"target": 7,
			"track": "games_played",
			"reward_sp": 4
		},
		{
			"id": "q1_w3_win_5",
			"name": "Win Streak",
			"desc": "Win 5 games",
			"target": 5,
			"track": "games_won",
			"reward_sp": 5
		},
		{
			"id": "q1_w3_score_30k",
			"name": "High Scorer",
			"desc": "Score 30,000 in one game",
			"target": 30000,
			"track": "high_score",
			"reward_sp": 4
		},
		{
			"id": "q1_w3_total_150k",
			"name": "Score Mountain",
			"desc": "Score 150,000 total points",
			"target": 150000,
			"track": "total_score",
			"reward_sp": 5
		},
		{
			"id": "q1_w3_combo_10",
			"name": "Combo Expert",
			"desc": "Achieve a 10+ combo",
			"target": 1,
			"track": "combo_10",
			"reward_sp": 4
		},
		{
			"id": "q1_w3_perfect_1",
			"name": "Flawless Round",
			"desc": "Complete 1 perfect round",
			"target": 1,
			"track": "perfect_rounds",
			"reward_sp": 4
		},
		{
			"id": "q1_w3_cards_100",
			"name": "Century Clicker",
			"desc": "Click 100 cards",
			"target": 100,
			"track": "cards_clicked",
			"reward_sp": 4
		},
		{
			"id": "q1_w3_peaks_9",
			"name": "Peak Champion",
			"desc": "Clear all 9 peaks in one game",
			"target": 1,
			"track": "peak_clears_9",
			"reward_sp": 5
		},
		{
			"id": "q1_w3_suit_bonus_5",
			"name": "Suit Master",
			"desc": "Trigger 5 suit bonuses",
			"target": 5,
			"track": "suit_bonus",
			"reward_sp": 4
		},
		{
			"id": "q1_w3_aces_10",
			"name": "Ace Commander",
			"desc": "Play 10 Aces",
			"target": 10,
			"track": "aces_played",
			"reward_sp": 4
		}
	],
	
	# ========================================================================
	# WEEK 4 - Challenge Rising (Available Jan 27)
	# ========================================================================
	"week_4": [
		{
			"id": "q1_w4_play_10",
			"name": "Dedicated Player",
			"desc": "Play 10 games",
			"target": 10,
			"track": "games_played",
			"reward_sp": 5
		},
		{
			"id": "q1_w4_win_7",
			"name": "Lucky Seven",
			"desc": "Win 7 games",
			"target": 7,
			"track": "games_won",
			"reward_sp": 6
		},
		{
			"id": "q1_w4_score_40k",
			"name": "Score Elite",
			"desc": "Score 40,000 in one game",
			"target": 40000,
			"track": "high_score",
			"reward_sp": 5
		},
		{
			"id": "q1_w4_total_250k",
			"name": "Quarter Million",
			"desc": "Score 250,000 total points",
			"target": 250000,
			"track": "total_score",
			"reward_sp": 6
		},
		{
			"id": "q1_w4_combo_12",
			"name": "Combo Chain",
			"desc": "Achieve a 12+ combo",
			"target": 1,
			"track": "combo_12",
			"reward_sp": 5
		},
		{
			"id": "q1_w4_perfect_2",
			"name": "Perfect Pair",
			"desc": "Complete 2 perfect rounds",
			"target": 2,
			"track": "perfect_rounds",
			"reward_sp": 5
		},
		{
			"id": "q1_w4_cards_150",
			"name": "Card Marathon",
			"desc": "Click 150 cards",
			"target": 150,
			"track": "cards_clicked",
			"reward_sp": 5
		},
		{
			"id": "q1_w4_peaks_9_twice",
			"name": "Peak Repeater",
			"desc": "Clear all peaks twice",
			"target": 2,
			"track": "peak_clears_9",
			"reward_sp": 6
		},
		{
			"id": "q1_w4_suit_bonus_8",
			"name": "Suit Expert",
			"desc": "Trigger 8 suit bonuses",
			"target": 8,
			"track": "suit_bonus",
			"reward_sp": 5
		},
		{
			"id": "q1_w4_kings_10",
			"name": "King Royalty",
			"desc": "Play 10 Kings",
			"target": 10,
			"track": "kings_played",
			"reward_sp": 5
		}
	],
	
	# ========================================================================
	# WEEK 5 - Mid-Season Push (Available Feb 3)
	# ========================================================================
	"week_5": [
		{
			"id": "q1_w5_play_12",
			"name": "Consistent Player",
			"desc": "Play 12 games",
			"target": 12,
			"track": "games_played",
			"reward_sp": 6
		},
		{
			"id": "q1_w5_win_10",
			"name": "Double Digits",
			"desc": "Win 10 games",
			"target": 10,
			"track": "games_won",
			"reward_sp": 7
		},
		{
			"id": "q1_w5_score_50k",
			"name": "Fifty Grand",
			"desc": "Score 50,000 in one game",
			"target": 50000,
			"track": "high_score",
			"reward_sp": 6
		},
		{
			"id": "q1_w5_total_400k",
			"name": "Point Fortress",
			"desc": "Score 400,000 total points",
			"target": 400000,
			"track": "total_score",
			"reward_sp": 7
		},
		{
			"id": "q1_w5_combo_15",
			"name": "Combo Master",
			"desc": "Achieve a 15+ combo",
			"target": 1,
			"track": "combo_15",
			"reward_sp": 6
		},
		{
			"id": "q1_w5_perfect_3",
			"name": "Perfect Trinity",
			"desc": "Complete 3 perfect rounds",
			"target": 3,
			"track": "perfect_rounds",
			"reward_sp": 6
		},
		{
			"id": "q1_w5_cards_200",
			"name": "Double Century",
			"desc": "Click 200 cards",
			"target": 200,
			"track": "cards_clicked",
			"reward_sp": 6
		},
		{
			"id": "q1_w5_peaks_9_triple",
			"name": "Peak Dominator",
			"desc": "Clear all peaks 3 times",
			"target": 3,
			"track": "peak_clears_9",
			"reward_sp": 7
		},
		{
			"id": "q1_w5_suit_bonus_10",
			"name": "Suit Legend",
			"desc": "Trigger 10 suit bonuses",
			"target": 10,
			"track": "suit_bonus",
			"reward_sp": 6
		},
		{
			"id": "q1_w5_aces_15",
			"name": "Ace Overlord",
			"desc": "Play 15 Aces",
			"target": 15,
			"track": "aces_played",
			"reward_sp": 6
		}
	],
	
	# ========================================================================
	# WEEK 6 - Expert Territory (Available Feb 10)
	# ========================================================================
	"week_6": [
		{
			"id": "q1_w6_play_15",
			"name": "Committed Player",
			"desc": "Play 15 games",
			"target": 15,
			"track": "games_played",
			"reward_sp": 7
		},
		{
			"id": "q1_w6_win_12",
			"name": "Victory Dozen",
			"desc": "Win 12 games",
			"target": 12,
			"track": "games_won",
			"reward_sp": 8
		},
		{
			"id": "q1_w6_score_60k",
			"name": "Sixty Milestone",
			"desc": "Score 60,000 in one game",
			"target": 60000,
			"track": "high_score",
			"reward_sp": 7
		},
		{
			"id": "q1_w6_total_600k",
			"name": "Half Million Plus",
			"desc": "Score 600,000 total points",
			"target": 600000,
			"track": "total_score",
			"reward_sp": 8
		},
		{
			"id": "q1_w6_combo_18",
			"name": "Combo Legend",
			"desc": "Achieve an 18+ combo",
			"target": 1,
			"track": "combo_18",
			"reward_sp": 7
		},
		{
			"id": "q1_w6_perfect_5",
			"name": "Perfect Five",
			"desc": "Complete 5 perfect rounds",
			"target": 5,
			"track": "perfect_rounds",
			"reward_sp": 7
		},
		{
			"id": "q1_w6_cards_300",
			"name": "Triple Century",
			"desc": "Click 300 cards",
			"target": 300,
			"track": "cards_clicked",
			"reward_sp": 7
		},
		{
			"id": "q1_w6_peaks_9_five",
			"name": "Peak Grandmaster",
			"desc": "Clear all peaks 5 times",
			"target": 5,
			"track": "peak_clears_9",
			"reward_sp": 8
		},
		{
			"id": "q1_w6_suit_bonus_15",
			"name": "Suit Virtuoso",
			"desc": "Trigger 15 suit bonuses",
			"target": 15,
			"track": "suit_bonus",
			"reward_sp": 7
		},
		{
			"id": "q1_w6_kings_15",
			"name": "King Dynasty",
			"desc": "Play 15 Kings",
			"target": 15,
			"track": "kings_played",
			"reward_sp": 7
		}
	],
	
	# ========================================================================
	# WEEK 7 - Advanced Challenges (Available Feb 17)
	# ========================================================================
	"week_7": [
		{
			"id": "q1_w7_play_18",
			"name": "Seasoned Veteran",
			"desc": "Play 18 games",
			"target": 18,
			"track": "games_played",
			"reward_sp": 8
		},
		{
			"id": "q1_w7_win_15",
			"name": "Winning Streak",
			"desc": "Win 15 games",
			"target": 15,
			"track": "games_won",
			"reward_sp": 9
		},
		{
			"id": "q1_w7_score_75k",
			"name": "Seventy Five K",
			"desc": "Score 75,000 in one game",
			"target": 75000,
			"track": "high_score",
			"reward_sp": 8
		},
		{
			"id": "q1_w7_total_800k",
			"name": "Eight Hundred K",
			"desc": "Score 800,000 total points",
			"target": 800000,
			"track": "total_score",
			"reward_sp": 9
		},
		{
			"id": "q1_w7_combo_20",
			"name": "Combo Virtuoso",
			"desc": "Achieve a 20+ combo",
			"target": 1,
			"track": "combo_20",
			"reward_sp": 8
		},
		{
			"id": "q1_w7_perfect_7",
			"name": "Perfect Week",
			"desc": "Complete 7 perfect rounds",
			"target": 7,
			"track": "perfect_rounds",
			"reward_sp": 8
		},
		{
			"id": "q1_w7_cards_400",
			"name": "Quad Century",
			"desc": "Click 400 cards",
			"target": 400,
			"track": "cards_clicked",
			"reward_sp": 8
		},
		{
			"id": "q1_w7_peaks_9_seven",
			"name": "Peak Immortal",
			"desc": "Clear all peaks 7 times",
			"target": 7,
			"track": "peak_clears_9",
			"reward_sp": 9
		},
		{
			"id": "q1_w7_suit_bonus_20",
			"name": "Suit Prodigy",
			"desc": "Trigger 20 suit bonuses",
			"target": 20,
			"track": "suit_bonus",
			"reward_sp": 8
		},
		{
			"id": "q1_w7_aces_20",
			"name": "Ace Supremacy",
			"desc": "Play 20 Aces",
			"target": 20,
			"track": "aces_played",
			"reward_sp": 8
		}
	],
	
	# ========================================================================
	# WEEK 8 - Elite Tier (Available Feb 24)
	# ========================================================================
	"week_8": [
		{
			"id": "q1_w8_play_20",
			"name": "Twenty Games",
			"desc": "Play 20 games",
			"target": 20,
			"track": "games_played",
			"reward_sp": 9
		},
		{
			"id": "q1_w8_win_18",
			"name": "Victory Master",
			"desc": "Win 18 games",
			"target": 18,
			"track": "games_won",
			"reward_sp": 10
		},
		{
			"id": "q1_w8_score_90k",
			"name": "Ninety Thousand",
			"desc": "Score 90,000 in one game",
			"target": 90000,
			"track": "high_score",
			"reward_sp": 9
		},
		{
			"id": "q1_w8_total_1m",
			"name": "Million Club",
			"desc": "Score 1,000,000 total points",
			"target": 1000000,
			"track": "total_score",
			"reward_sp": 10
		},
		{
			"id": "q1_w8_combo_22",
			"name": "Combo Deity",
			"desc": "Achieve a 22+ combo",
			"target": 1,
			"track": "combo_22",
			"reward_sp": 9
		},
		{
			"id": "q1_w8_perfect_10",
			"name": "Perfect Ten",
			"desc": "Complete 10 perfect rounds",
			"target": 10,
			"track": "perfect_rounds",
			"reward_sp": 9
		},
		{
			"id": "q1_w8_cards_500",
			"name": "Five Hundred Club",
			"desc": "Click 500 cards",
			"target": 500,
			"track": "cards_clicked",
			"reward_sp": 9
		},
		{
			"id": "q1_w8_peaks_9_ten",
			"name": "Peak Perfection",
			"desc": "Clear all peaks 10 times",
			"target": 10,
			"track": "peak_clears_9",
			"reward_sp": 10
		},
		{
			"id": "q1_w8_suit_bonus_25",
			"name": "Suit Grandmaster",
			"desc": "Trigger 25 suit bonuses",
			"target": 25,
			"track": "suit_bonus",
			"reward_sp": 9
		},
		{
			"id": "q1_w8_kings_20",
			"name": "King Emperor",
			"desc": "Play 20 Kings",
			"target": 20,
			"track": "kings_played",
			"reward_sp": 9
		}
	],
	
	# ========================================================================
	# WEEK 9 - Final Push Begins (Available Mar 3)
	# ========================================================================
	"week_9": [
		{
			"id": "q1_w9_play_25",
			"name": "Quarter Century",
			"desc": "Play 25 games",
			"target": 25,
			"track": "games_played",
			"reward_sp": 10
		},
		{
			"id": "q1_w9_win_20",
			"name": "Twenty Victories",
			"desc": "Win 20 games",
			"target": 20,
			"track": "games_won",
			"reward_sp": 11
		},
		{
			"id": "q1_w9_score_100k",
			"name": "Century Score",
			"desc": "Score 100,000 in one game",
			"target": 100000,
			"track": "high_score",
			"reward_sp": 10
		},
		{
			"id": "q1_w9_total_1_5m",
			"name": "Million and a Half",
			"desc": "Score 1,500,000 total points",
			"target": 1500000,
			"track": "total_score",
			"reward_sp": 11
		},
		{
			"id": "q1_w9_combo_25",
			"name": "Combo Transcendence",
			"desc": "Achieve a 25+ combo",
			"target": 1,
			"track": "combo_25",
			"reward_sp": 10
		},
		{
			"id": "q1_w9_perfect_12",
			"name": "Perfect Dozen",
			"desc": "Complete 12 perfect rounds",
			"target": 12,
			"track": "perfect_rounds",
			"reward_sp": 10
		},
		{
			"id": "q1_w9_cards_600",
			"name": "Six Hundred Click",
			"desc": "Click 600 cards",
			"target": 600,
			"track": "cards_clicked",
			"reward_sp": 10
		},
		{
			"id": "q1_w9_peaks_9_dozen",
			"name": "Peak Dozen",
			"desc": "Clear all peaks 12 times",
			"target": 12,
			"track": "peak_clears_9",
			"reward_sp": 11
		},
		{
			"id": "q1_w9_suit_bonus_30",
			"name": "Suit Champion",
			"desc": "Trigger 30 suit bonuses",
			"target": 30,
			"track": "suit_bonus",
			"reward_sp": 10
		},
		{
			"id": "q1_w9_aces_25",
			"name": "Ace Champion",
			"desc": "Play 25 Aces",
			"target": 25,
			"track": "aces_played",
			"reward_sp": 10
		}
	],
	
	# ========================================================================
	# WEEK 10 - Legendary Challenges (Available Mar 10)
	# ========================================================================
	"week_10": [
		{
			"id": "q1_w10_play_30",
			"name": "Thirty Strong",
			"desc": "Play 30 games",
			"target": 30,
			"track": "games_played",
			"reward_sp": 11
		},
		{
			"id": "q1_w10_win_25",
			"name": "Victory Marathon",
			"desc": "Win 25 games",
			"target": 25,
			"track": "games_won",
			"reward_sp": 12
		},
		{
			"id": "q1_w10_score_120k",
			"name": "One Twenty K",
			"desc": "Score 120,000 in one game",
			"target": 120000,
			"track": "high_score",
			"reward_sp": 11
		},
		{
			"id": "q1_w10_total_2m",
			"name": "Two Million",
			"desc": "Score 2,000,000 total points",
			"target": 2000000,
			"track": "total_score",
			"reward_sp": 12
		},
		{
			"id": "q1_w10_combo_28",
			"name": "Combo Godlike",
			"desc": "Achieve a 28+ combo",
			"target": 1,
			"track": "combo_28",
			"reward_sp": 11
		},
		{
			"id": "q1_w10_perfect_15",
			"name": "Perfect Fifteen",
			"desc": "Complete 15 perfect rounds",
			"target": 15,
			"track": "perfect_rounds",
			"reward_sp": 11
		},
		{
			"id": "q1_w10_cards_750",
			"name": "Seven Fifty Elite",
			"desc": "Click 750 cards",
			"target": 750,
			"track": "cards_clicked",
			"reward_sp": 11
		},
		{
			"id": "q1_w10_peaks_9_fifteen",
			"name": "Peak Legend",
			"desc": "Clear all peaks 15 times",
			"target": 15,
			"track": "peak_clears_9",
			"reward_sp": 12
		},
		{
			"id": "q1_w10_suit_bonus_35",
			"name": "Suit Paragon",
			"desc": "Trigger 35 suit bonuses",
			"target": 35,
			"track": "suit_bonus",
			"reward_sp": 11
		},
		{
			"id": "q1_w10_kings_25",
			"name": "King Sovereign",
			"desc": "Play 25 Kings",
			"target": 25,
			"track": "kings_played",
			"reward_sp": 11
		}
	],
	
	# ========================================================================
	# WEEK 11 - Epic Finale Prep (Available Mar 17)
	# ========================================================================
	"week_11": [
		{
			"id": "q1_w11_play_35",
			"name": "Epic Dedication",
			"desc": "Play 35 games",
			"target": 35,
			"track": "games_played",
			"reward_sp": 12
		},
		{
			"id": "q1_w11_win_30",
			"name": "Thirty Triumphs",
			"desc": "Win 30 games",
			"target": 30,
			"track": "games_won",
			"reward_sp": 13
		},
		{
			"id": "q1_w11_score_150k",
			"name": "One Fifty K",
			"desc": "Score 150,000 in one game",
			"target": 150000,
			"track": "high_score",
			"reward_sp": 12
		},
		{
			"id": "q1_w11_total_2_5m",
			"name": "Two Point Five Million",
			"desc": "Score 2,500,000 total points",
			"target": 2500000,
			"track": "total_score",
			"reward_sp": 13
		},
		{
			"id": "q1_w11_combo_30",
			"name": "Combo Mythic",
			"desc": "Achieve a 30+ combo",
			"target": 1,
			"track": "combo_30",
			"reward_sp": 12
		},
		{
			"id": "q1_w11_perfect_18",
			"name": "Perfect Eighteen",
			"desc": "Complete 18 perfect rounds",
			"target": 18,
			"track": "perfect_rounds",
			"reward_sp": 12
		},
		{
			"id": "q1_w11_cards_900",
			"name": "Nine Hundred Master",
			"desc": "Click 900 cards",
			"target": 900,
			"track": "cards_clicked",
			"reward_sp": 12
		},
		{
			"id": "q1_w11_peaks_9_twenty",
			"name": "Peak Supreme",
			"desc": "Clear all peaks 20 times",
			"target": 20,
			"track": "peak_clears_9",
			"reward_sp": 13
		},
		{
			"id": "q1_w11_suit_bonus_40",
			"name": "Suit Overlord",
			"desc": "Trigger 40 suit bonuses",
			"target": 40,
			"track": "suit_bonus",
			"reward_sp": 12
		},
		{
			"id": "q1_w11_aces_30",
			"name": "Ace Ultimate",
			"desc": "Play 30 Aces",
			"target": 30,
			"track": "aces_played",
			"reward_sp": 12
		}
	],
	
	# ========================================================================
	# WEEK 12 - GRAND FINALE (Available Mar 24 - Last Week!)
	# ========================================================================
	"week_12": [
		{
			"id": "q1_w12_play_40",
			"name": "Legendary Grind",
			"desc": "Play 40 games",
			"target": 40,
			"track": "games_played",
			"reward_sp": 15
		},
		{
			"id": "q1_w12_win_35",
			"name": "Victory Legend",
			"desc": "Win 35 games",
			"target": 35,
			"track": "games_won",
			"reward_sp": 16
		},
		{
			"id": "q1_w12_score_200k",
			"name": "Two Hundred K",
			"desc": "Score 200,000 in one game",
			"target": 200000,
			"track": "high_score",
			"reward_sp": 15
		},
		{
			"id": "q1_w12_total_3m",
			"name": "Three Million Club",
			"desc": "Score 3,000,000 total points",
			"target": 3000000,
			"track": "total_score",
			"reward_sp": 16
		},
		{
			"id": "q1_w12_combo_35",
			"name": "Combo Ascended",
			"desc": "Achieve a 35+ combo",
			"target": 1,
			"track": "combo_35",
			"reward_sp": 15
		},
		{
			"id": "q1_w12_perfect_20",
			"name": "Perfect Twenty",
			"desc": "Complete 20 perfect rounds",
			"target": 20,
			"track": "perfect_rounds",
			"reward_sp": 15
		},
		{
			"id": "q1_w12_cards_1000",
			"name": "Thousand Click Champion",
			"desc": "Click 1,000 cards",
			"target": 1000,
			"track": "cards_clicked",
			"reward_sp": 15
		},
		{
			"id": "q1_w12_peaks_9_twentyfive",
			"name": "Peak Absolute",
			"desc": "Clear all peaks 25 times",
			"target": 25,
			"track": "peak_clears_9",
			"reward_sp": 16
		},
		{
			"id": "q1_w12_suit_bonus_50",
			"name": "Suit Eternal",
			"desc": "Trigger 50 suit bonuses",
			"target": 50,
			"track": "suit_bonus",
			"reward_sp": 15
		},
		{
			"id": "q1_w12_kings_30",
			"name": "King Eternal",
			"desc": "Play 30 Kings",
			"target": 30,
			"track": "kings_played",
			"reward_sp": 15
		}
	]
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func get_week_number(current_date: String) -> int:
	"""Calculate which week of the season we're currently in (1-12)"""
	# Convert dates to Unix timestamps for comparison
	var current_unix = _date_string_to_unix(current_date)
	var start_unix = _date_string_to_unix(START_DATE)
	var end_unix = _date_string_to_unix(END_DATE)
	
	# If before season start, return 0 (no weeks unlocked)
	if current_unix < start_unix:
		return 0
	
	# If after season end, return 12 (all weeks available)
	if current_unix > end_unix:
		return 12
	
	# Check which week we're in based on unlock dates
	for i in range(WEEK_UNLOCK_DATES.size()):
		var week_unix = _date_string_to_unix(WEEK_UNLOCK_DATES[i])
		if current_unix < week_unix:
			return i  # Return previous week (0-indexed becomes 1-indexed)
	
	# If we've passed all unlock dates, we're in the final week
	return 12

static func get_unlocked_weeks(current_date: String) -> Array:
	"""Get array of unlocked week numbers [1, 2, 3, ...]"""
	var current_week = get_week_number(current_date)
	var unlocked = []
	for i in range(1, current_week + 1):
		unlocked.append(i)
	return unlocked

static func is_season_active(current_date: String) -> bool:
	"""Check if the season is currently active"""
	var current_unix = _date_string_to_unix(current_date)
	var start_unix = _date_string_to_unix(START_DATE)
	var end_unix = _date_string_to_unix(END_DATE)
	return current_unix >= start_unix and current_unix <= end_unix

static func get_days_remaining(current_date: String) -> int:
	"""Get number of days remaining in season"""
	var current_unix = _date_string_to_unix(current_date)
	var end_unix = _date_string_to_unix(END_DATE)
	var diff = end_unix - current_unix
	return max(0, int(diff / 86400))  # Convert seconds to days

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
