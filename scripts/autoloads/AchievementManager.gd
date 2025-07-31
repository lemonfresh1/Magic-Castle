# AchievementManager.gd - Enhanced achievement system with progress tracking
# Path: res://Magic-Castle/scripts/autoloads/AchievementManager.gd
# Added 9 new long-term achievements, "new" badge system, rarity tiers
extends Node

signal achievement_unlocked(achievement_id: String)
signal achievement_progress_updated(achievement_id: String, progress: float)

const SAVE_PATH = "user://achievements.save"

# Rarity tiers for visual display
enum Rarity {
	COMMON,      # Gray - 45%
	UNCOMMON,    # Green - 30%
	RARE,        # Blue - 15%
	EPIC,        # Purple - 7%
	LEGENDARY,   # Orange - 2.5%
	MYTHIC       # Red - 0.5%
}

# Achievement definitions (18 total)
var achievements = {
	# === STARTER TIER (5-10 stars) ===
	"first_game": {
		"name": "First Steps",
		"description": "Complete your first game",
		"stars": 5,
		"rarity": Rarity.COMMON,
		"requirement": {"type": "games_played", "value": 1},
		"icon": "Play.png"
	},
	"board_clear": {
		"name": "Winner",
		"description": "Clear a board",
		"stars": 10,
		"rarity": Rarity.COMMON,
		"requirement": {"type": "boards_cleared", "value": 1},
		"icon": "Trophy.png"
	},
	"play_10": {
		"name": "Dedicated",
		"description": "Play 10 games",
		"stars": 10,
		"rarity": Rarity.COMMON,
		"requirement": {"type": "games_played", "value": 10},
		"icon": "Team.png"
	},
	"combo_5": {
		"name": "Combo Starter", 
		"description": "Reach a 5 card combo",
		"stars": 10,
		"rarity": Rarity.COMMON,
		"requirement": {"type": "combo", "value": 5},
		"icon": "Flower.png"
	},
	"speed_clear": {
		"name": "Speed Demon",
		"description": "Clear a board in under 50 seconds",
		"stars": 10,
		"rarity": Rarity.COMMON,
		"requirement": {"type": "speed_clear", "value": 50},
		"icon": "Gear.png"
	},
	
	# === SKILL TIER (15-25 stars) ===
	"combo_10": {
		"name": "Combo Master",
		"description": "Reach a 10 card combo", 
		"stars": 20,
		"rarity": Rarity.UNCOMMON,
		"requirement": {"type": "combo", "value": 10},
		"icon": "Flower2.png"
	},
	"all_peaks": {
		"name": "Peak Performance",
		"description": "Clear all 3 peaks in one game",
		"stars": 15,
		"rarity": Rarity.UNCOMMON,
		"requirement": {"type": "peaks_cleared", "value": 3},
		"icon": "Sun.png"
	},
	"score_10k": {
		"name": "High Scorer",
		"description": "Score over 10,000 points",
		"stars": 20,
		"rarity": Rarity.UNCOMMON,
		"requirement": {"type": "score", "value": 10000},
		"icon": "Coin2.png"
	},
	"perfect_round": {
		"name": "Flawless",
		"description": "Complete a round with no invalid clicks",
		"stars": 25,
		"rarity": Rarity.UNCOMMON,
		"requirement": {"type": "perfect_round", "value": 1},
		"icon": "Lightbulb.png"
	},
	"ace_hunter": {
		"name": "Ace Hunter",
		"description": "Play 50 Aces",
		"stars": 15,
		"rarity": Rarity.UNCOMMON,
		"requirement": {"type": "aces_played", "value": 50},
		"icon": "Cloud.png"
	},
	"king_slayer": {
		"name": "King Slayer",
		"description": "Play 50 Kings",
		"stars": 15,
		"rarity": Rarity.UNCOMMON,
		"requirement": {"type": "kings_played", "value": 50},
		"icon": "Coin.png"
	},
	"suit_master": {
		"name": "Suit Master",
		"description": "Get 100 suit bonuses",
		"stars": 20,
		"rarity": Rarity.RARE,
		"requirement": {"type": "suit_bonuses", "value": 100},
		"icon": "Cutlery.png"
	},
	
	# === GRIND TIER (30-50 stars) ===
	"peak_crusher": {
		"name": "Peak Crusher",
		"description": "Clear 100 peaks total",
		"stars": 30,
		"rarity": Rarity.RARE,
		"requirement": {"type": "total_peaks", "value": 100},
		"icon": "CookingPot.png"
	},
	"card_collector": {
		"name": "Card Collector",
		"description": "Draw 500 cards from the pile",
		"stars": 35,
		"rarity": Rarity.RARE,
		"requirement": {"type": "cards_drawn", "value": 500},
		"icon": "Exit.png"
	},
	"tap_master": {
		"name": "Tap Master",
		"description": "Successfully play 1000 cards",
		"stars": 40,
		"rarity": Rarity.EPIC,
		"requirement": {"type": "cards_played", "value": 1000},
		"icon": "Eye.png"
	},
	"veteran": {
		"name": "Veteran",
		"description": "Play 100 games",
		"stars": 45,
		"rarity": Rarity.EPIC,
		"requirement": {"type": "games_played", "value": 100},
		"icon": "FlowerPot.png"
	},
	"perfect_week": {
		"name": "Perfect Week",
		"description": "Complete 7 perfect rounds",
		"stars": 50,
		"rarity": Rarity.EPIC,
		"requirement": {"type": "perfect_rounds", "value": 7},
		"icon": "Info.png"
	},
	
	# === LEGENDARY TIER (100 stars) ===
	"million_club": {
		"name": "Million Club",
		"description": "Reach 1,000,000 total score",
		"stars": 100,
		"rarity": Rarity.LEGENDARY,
		"requirement": {"type": "total_score", "value": 1000000},
		"icon": "Key.png"
	}
}

var unlocked_achievements: Array[String] = []
var achievement_progress = {}  # id -> float (0.0 to 1.0)
var seen_achievements: Array[String] = []  # Tracks which are no longer "new"

func _ready():
	print("AchievementManager initializing...")
	load_achievements()
	print("AchievementManager ready with %d achievements" % achievements.size())

func check_achievements():
	var stats = StatsManager.get_total_stats()
	var current_game = StatsManager.current_game_stats
	
	for id in achievements:
		if id in unlocked_achievements:
			continue
			
		var achievement = achievements[id]
		var requirement = achievement.requirement
		var current_value = 0
		var unlocked = false
		
		match requirement.type:
			"games_played":
				current_value = stats.games_played
			"boards_cleared":
				current_value = stats.rounds_cleared
			"combo":
				current_value = current_game.highest_combo
			"score":
				current_value = StatsManager.get_highscore().score
			"peaks_cleared":
				if ScoreSystem and ScoreSystem.peaks_cleared_indices.size() >= requirement.value:
					current_value = requirement.value
					unlocked = true
			"perfect_round":
				current_value = current_game.perfect_rounds.size()
			"speed_clear":
				if GameState.board_cleared and GameState.round_time_limit > 0:
					var time_taken = GameState.round_time_limit - GameState.time_remaining
					if time_taken <= requirement.value:
						unlocked = true
			"aces_played":
				current_value = stats.aces_played
			"kings_played":
				current_value = stats.kings_played
			"suit_bonuses":
				current_value = stats.suit_bonuses
			"total_peaks":
				current_value = stats.total_peaks_cleared
			"cards_drawn":
				current_value = stats.cards_drawn
			"cards_played":
				current_value = stats.cards_clicked
			"perfect_rounds":
				current_value = stats.perfect_rounds
			"total_score":
				current_value = stats.total_score
		
		# Update progress
		var progress = min(float(current_value) / float(requirement.value), 1.0)
		var old_progress = achievement_progress.get(id, 0.0)
		
		if progress > old_progress:
			achievement_progress[id] = progress
			achievement_progress_updated.emit(id, progress)
		
		# Check for unlock
		if not unlocked:
			unlocked = current_value >= requirement.value
			
		if unlocked:
			unlock_achievement(id)

func unlock_achievement(id: String):
	if id in unlocked_achievements:
		return
		
	unlocked_achievements.append(id)
	achievement_progress[id] = 1.0
	
	# It's "new" until player sees it
	if id not in seen_achievements:
		# This will trigger the NEW badge in UI
		pass
	
	save_achievements()
	achievement_unlocked.emit(id)
	
	var achievement = achievements[id]
	print("Achievement Unlocked: %s (+%d stars)" % [achievement.name, achievement.stars])

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

func get_rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.6, 0.6, 0.6)      # Gray
		Rarity.UNCOMMON: return Color(0.3, 0.8, 0.3)    # Green
		Rarity.RARE: return Color(0.3, 0.5, 0.9)        # Blue
		Rarity.EPIC: return Color(0.7, 0.3, 0.9)        # Purple
		Rarity.LEGENDARY: return Color(0.9, 0.6, 0.2)   # Orange
		Rarity.MYTHIC: return Color(0.9, 0.2, 0.2)      # Red
		_: return Color.WHITE

func save_achievements():
	var save_data = {
		"version": 2,  # Increment for migration
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
				unlocked_achievements.assign(save_data.unlocked)
				achievement_progress = save_data.get("progress", {})
				seen_achievements.assign(save_data.get("seen", []))
				
				# Migrate if old version
				if save_data.get("version", 1) < 2:
					seen_achievements.clear()  # All unlocked are "new" after update

func is_unlocked(id: String) -> bool:
	return id in unlocked_achievements

func get_total_stars_earned() -> int:
	var total = 0
	for id in unlocked_achievements:
		if achievements.has(id):
			total += achievements[id].stars
	return total

func reset_all_achievements() -> void:
	print("Resetting all achievements...")
	unlocked_achievements.clear()
	achievement_progress.clear()
	seen_achievements.clear()
	save_achievements()
	print("All achievements reset")
