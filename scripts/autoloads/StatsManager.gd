# StatsManager.gd - Enhanced statistics tracking for achievements
# Path: res://Pyramids/scripts/autoloads/StatsManager.gd  
# Last Updated: Fixed mode names to match GameModeManager [Date]
extends Node

const SAVE_PATH = "user://stats.save"
const STATS_VERSION = 4  # Incremented for mode name fix

var mode_highscores: Dictionary = {}  # mode_id -> Array of {player_name, score, timestamp}
var player_best_scores: Dictionary = {}  # mode_id -> best_score
var daily_reward_claimed_today: bool = false
var last_claim_date: String = ""

# Main stats dictionary - FIXED MODE NAMES
var stats = {
	"version": STATS_VERSION,
	
	# Best scores for each round (1-10)
	"best_rounds": {}, # round_number: {score, seed, date, mode}
	
	# Overall records
	"highscore": {"score": 0, "seed": 0, "date": "", "mode": ""},
	"longest_combo": {"combo": 0, "seed": 0, "date": "", "mode": ""},
	
	# Per mode statistics - UPDATED TO MATCH GAMEMODEMANAGER
	"mode_stats": {
		"classic": _create_mode_stats(),      # Was "tri_peaks"
		"timed_rush": _create_mode_stats(),   # Was "rush"
		"test": _create_mode_stats(),         # Unchanged
		"zen": _create_mode_stats(),          # NEW
		"daily_challenge": _create_mode_stats(), # NEW
		"puzzle_master": _create_mode_stats()    # NEW
	},
	
	# Total statistics (across all modes)
	"total_stats": _create_mode_stats()
}

# Temporary tracking for current game
var current_game_stats = {
	"cards_clicked": 0,
	"cards_drawn": 0,
	"invalid_clicks": 0,
	"highest_combo": 0,
	"time_started": 0,
	"perfect_rounds": [],
	"round_invalid_clicks": 0,
	"suit_bonuses": 0
}

# Enhanced multiplayer stats structure - FIXED MODE NAMES
var multiplayer_stats = {
	"classic": _create_multiplayer_stats(),
	"timed_rush": _create_multiplayer_stats(),
	"test": _create_multiplayer_stats(),
	"zen": _create_multiplayer_stats(),           # NEW
	"daily_challenge": _create_multiplayer_stats(), # NEW
	"puzzle_master": _create_multiplayer_stats()    # NEW
}

var daily_logins: int = 0
var last_login_date: String = ""
var login_streak: int = 0

func _ready() -> void:
	print("StatsManager initializing...")
	load_stats()
	_fix_mode_names()  # Run migration on startup
	print("StatsManager ready")

func _create_mode_stats() -> Dictionary:
	return {
		"games_played": 0,
		"total_rounds": 0,
		"time_ran_out": 0,
		"cards_clicked": 0,
		"cards_drawn": 0,
		"invalid_clicks": 0,
		"peak_clears": {"1": 0, "2": 0, "3": 0},
		"perfect_rounds": 0,
		"fastest_clear": -1.0,
		"most_cards_remaining": 0,
		"suit_bonuses": 0,
		"total_score": 0,
		"highest_round_reached": 0,
		"total_peaks_cleared": 0
	}

func _create_multiplayer_stats() -> Dictionary:
	return {
		"games": 0,
		"first_place": 0,  # Track 1st place finishes
		"placements": [0, 0, 0, 0, 0, 0, 0, 0],  # Track positions 1-8
		"average_rank": 0.0,
		"highscore": 0,
		"longest_combo": 0,
		"fastest_clear": -1.0,  # Time in seconds
		"total_score": 0,
		"average_score": 0.0,
		"current_win_streak": 0,  # Current consecutive wins
		"best_win_streak": 0,      # Best win streak ever
		"mmr": 1000               # Starting MMR
	}

# === MODE NAME MIGRATION ===
func _fix_mode_names() -> void:
	"""One-time fix to migrate old mode names to new ones"""
	var needs_save = false
	
	# Check if we need to migrate
	if stats.version < STATS_VERSION:
		print("Migrating stats from version %d to %d" % [stats.get("version", 0), STATS_VERSION])
		
		# Migrate mode_stats
		if stats.mode_stats.has("tri_peaks"):
			print("  Migrating tri_peaks -> classic")
			stats.mode_stats["classic"] = stats.mode_stats["tri_peaks"]
			stats.mode_stats.erase("tri_peaks")
			needs_save = true
		
		if stats.mode_stats.has("rush"):
			print("  Migrating rush -> timed_rush")
			stats.mode_stats["timed_rush"] = stats.mode_stats["rush"]
			stats.mode_stats.erase("rush")
			needs_save = true
		
		if stats.mode_stats.has("chill"):
			print("  Removing unused chill mode")
			stats.mode_stats.erase("chill")
			needs_save = true
		
		# Ensure all expected modes exist
		for mode in ["classic", "timed_rush", "test", "zen", "daily_challenge", "puzzle_master"]:
			if not stats.mode_stats.has(mode):
				print("  Adding new mode: %s" % mode)
				stats.mode_stats[mode] = _create_mode_stats()
				needs_save = true
			if not multiplayer_stats.has(mode):
				multiplayer_stats[mode] = _create_multiplayer_stats()
				needs_save = true
		
		# Update version
		stats.version = STATS_VERSION
		needs_save = true
	
	# Also ensure multiplayer stats have all modes
	for mode in ["classic", "timed_rush", "test", "zen", "daily_challenge", "puzzle_master"]:
		if not multiplayer_stats.has(mode):
			multiplayer_stats[mode] = _create_multiplayer_stats()
			needs_save = true
	
	if needs_save:
		save_stats()
		print("Mode names migration completed!")

# === SAVE/LOAD ===
func save_stats() -> void:
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file:
		var save_data = {
			"stats": stats,
			"mode_highscores": mode_highscores,
			"player_best_scores": player_best_scores,
			"multiplayer_stats": multiplayer_stats,
			"daily_logins": daily_logins,
			"last_login_date": last_login_date,
			"login_streak": login_streak
		}
		save_file.store_var(save_data)
		save_file.close()
		print("Stats saved successfully (v%d)" % STATS_VERSION)

func load_stats() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if save_file:
			var loaded_data = save_file.get_var()
			save_file.close()
			
			if loaded_data:
				if loaded_data.has("stats"):
					# New format with separate sections
					stats = loaded_data.stats
					mode_highscores = loaded_data.get("mode_highscores", {})
					player_best_scores = loaded_data.get("player_best_scores", {})
					
					# Load login data
					daily_logins = loaded_data.get("daily_logins", 0)
					last_login_date = loaded_data.get("last_login_date", "")
					login_streak = loaded_data.get("login_streak", 0)
					
					# Load multiplayer stats
					var loaded_mp = loaded_data.get("multiplayer_stats", {})
					if loaded_mp:
						multiplayer_stats = loaded_mp
					
					print("Loaded stats v%d with %d mode highscores and %d day streak" % 
						[stats.get("version", 0), mode_highscores.size(), login_streak])
				elif loaded_data.has("version"):
					# Old format - just stats
					stats = loaded_data
					mode_highscores = {}
					player_best_scores = {}
					print("Loaded legacy stats format")
				
				_migrate_stats_if_needed()
				print("Stats loaded successfully")
	else:
		print("No stats file found at %s" % SAVE_PATH)

func _migrate_stats_if_needed() -> void:
	if stats.version < STATS_VERSION:
		print("Additional migration needed from version %d to %d" % [stats.version, STATS_VERSION])
		
		# Remove deprecated fields from existing stats
		for mode in stats.mode_stats:
			var mode_stat = stats.mode_stats[mode]
			# Remove old fields if they exist
			if mode_stat.has("rounds_cleared"):
				mode_stat.erase("rounds_cleared")
			if mode_stat.has("rounds_failed"):
				mode_stat.erase("rounds_failed")
			if mode_stat.has("aces_played"):
				mode_stat.erase("aces_played")
			if mode_stat.has("kings_played"):
				mode_stat.erase("kings_played")
			
			# Ensure total_peaks_cleared exists
			if not mode_stat.has("total_peaks_cleared"):
				var total = 0
				var peak_data = mode_stat.get("peak_clears", {})
				total += peak_data.get("1", 0)
				total += peak_data.get("2", 0) * 2
				total += peak_data.get("3", 0) * 3
				mode_stat["total_peaks_cleared"] = total
		
		# Clean up total_stats too
		var total = stats.total_stats
		if total.has("rounds_cleared"):
			total.erase("rounds_cleared")
		if total.has("rounds_failed"):
			total.erase("rounds_failed")
		if total.has("aces_played"):
			total.erase("aces_played")
		if total.has("kings_played"):
			total.erase("kings_played")
		
		if not total.has("total_peaks_cleared"):
			var total_peaks = 0
			var peak_data = total.get("peak_clears", {})
			total_peaks += peak_data.get("1", 0)
			total_peaks += peak_data.get("2", 0) * 2
			total_peaks += peak_data.get("3", 0) * 3
			total["total_peaks_cleared"] = total_peaks

# === GAME TRACKING ===
func start_game(mode: String, game_type: String = "solo") -> void:
	print("StatsManager: Starting game in %s mode (%s)" % [mode, game_type])
	current_game_stats = {
		"cards_clicked": 0,
		"cards_drawn": 0,
		"invalid_clicks": 0,
		"highest_combo": 0,
		"time_started": Time.get_ticks_msec(),
		"perfect_rounds": [],
		"round_invalid_clicks": 0,
		"suit_bonuses": 0
	}
	
	# Create composite key
	var stats_key = "%s_%s" % [mode, game_type]
	
	# Ensure mode exists in mode_stats with composite key
	if not stats.mode_stats.has(stats_key):
		print("Creating stats entry for: %s" % stats_key)
		stats.mode_stats[stats_key] = _create_mode_stats()
	
	if stats.mode_stats.has(stats_key):
		stats.mode_stats[stats_key].games_played += 1
	stats.total_stats.games_played += 1
	
	save_stats()

func end_game(mode: String, final_score: int, rounds_completed: int, game_type: String = "solo") -> void:
	print("StatsManager: Game ended - Mode: %s (%s), Score: %d, Rounds: %d" % [mode, game_type, final_score, rounds_completed])
	
	# Create composite key
	var stats_key = "%s_%s" % [mode, game_type]
	
	# Ensure mode exists with composite key
	if not stats.mode_stats.has(stats_key):
		print("Warning: Mode '%s' not in stats, creating it" % stats_key)
		stats.mode_stats[stats_key] = _create_mode_stats()
	
	# Update mode and total stats with accumulated values
	if stats.mode_stats.has(stats_key):
		var mode_stat = stats.mode_stats[stats_key]
		mode_stat.cards_clicked += current_game_stats.cards_clicked
		mode_stat.cards_drawn += current_game_stats.cards_drawn
		mode_stat.invalid_clicks += current_game_stats.invalid_clicks
		mode_stat.total_score += final_score
		
		if rounds_completed > mode_stat.highest_round_reached:
			mode_stat.highest_round_reached = rounds_completed
	
	# Update totals
	stats.total_stats.cards_clicked += current_game_stats.cards_clicked
	stats.total_stats.cards_drawn += current_game_stats.cards_drawn
	stats.total_stats.invalid_clicks += current_game_stats.invalid_clicks
	stats.total_stats.total_score += final_score
	
	# Check for new highscore (SEPARATED by game_type)
	var highscore_key = "highscore_%s" % game_type
	if not stats.has(highscore_key):
		stats[highscore_key] = {"score": 0, "seed": 0, "date": "", "mode": "", "game_type": game_type}
	
	if final_score > stats[highscore_key].score:
		stats[highscore_key] = {
			"score": final_score,
			"seed": GameState.deck_seed,
			"date": _get_current_date(),
			"mode": mode,
			"game_type": game_type
		}
	
	# Check for longest combo (SEPARATED by game_type)
	var combo_key = "longest_combo_%s" % game_type
	if not stats.has(combo_key):
		stats[combo_key] = {"combo": 0, "seed": 0, "date": "", "mode": "", "game_type": game_type}
	
	if current_game_stats.highest_combo > stats[combo_key].combo:
		stats[combo_key] = {
			"combo": current_game_stats.highest_combo,
			"seed": GameState.deck_seed,
			"date": _get_current_date(),
			"mode": mode,
			"game_type": game_type
		}
	
	# Save mode-specific highscore with composite key for leaderboard
	var leaderboard_key = "%s_%s" % [mode, game_type]
	save_score(leaderboard_key, final_score, SettingsSystem.player_name if SettingsSystem else "Player")
	
	save_stats()

func track_suit_bonus(mode: String, game_type: String = "solo") -> void:
	current_game_stats.suit_bonuses += 1
	var stats_key = "%s_%s" % [mode, game_type]
	if stats.mode_stats.has(stats_key):
		stats.mode_stats[stats_key].suit_bonuses += 1
	stats.total_stats.suit_bonuses += 1

func track_peak_clears(peaks_cleared: int, mode: String, game_type: String = "solo") -> void:
	var stats_key = "%s_%s" % [mode, game_type]
	if stats.mode_stats.has(stats_key) and peaks_cleared > 0:
		stats.mode_stats[stats_key].peak_clears[str(peaks_cleared)] += 1
		stats.mode_stats[stats_key].total_peaks_cleared += peaks_cleared
		stats.total_stats.peak_clears[str(peaks_cleared)] += 1
		stats.total_stats.total_peaks_cleared += peaks_cleared

func track_round_end(round: int, cleared: bool, score: int, time_left: float, reason: String, mode: String, game_type: String = "solo") -> void:
	var stats_key = "%s_%s" % [mode, game_type]
	
	# Ensure mode exists
	if not stats.mode_stats.has(stats_key):
		print("Warning: Mode '%s' not in stats, creating it" % stats_key)
		stats.mode_stats[stats_key] = _create_mode_stats()
	
	# Update round stats
	if stats.mode_stats.has(stats_key):
		var mode_stat = stats.mode_stats[stats_key]
		mode_stat.total_rounds += 1
		
		if cleared:
			# Track fastest clear
			var clear_time = GameState.round_time_limit - time_left
			if mode_stat.fastest_clear < 0 or clear_time < mode_stat.fastest_clear:
				mode_stat.fastest_clear = clear_time
			
			# Track most cards remaining
			var cards_remaining = CardManager.draw_pile.size() if CardManager else 0
			if cards_remaining > mode_stat.most_cards_remaining:
				mode_stat.most_cards_remaining = cards_remaining
		else:
			if reason == "Time's up!":
				mode_stat.time_ran_out += 1
		
		# Check for perfect round (no invalid clicks this round)
		if current_game_stats.round_invalid_clicks == 0:
			mode_stat.perfect_rounds += 1
			current_game_stats.perfect_rounds.append(round)
	
	# Update totals
	stats.total_stats.total_rounds += 1
	if cleared:
		var clear_time = GameState.round_time_limit - time_left
		if stats.total_stats.fastest_clear < 0 or clear_time < stats.total_stats.fastest_clear:
			stats.total_stats.fastest_clear = clear_time
		
		var cards_remaining = CardManager.draw_pile.size() if CardManager else 0
		if cards_remaining > stats.total_stats.most_cards_remaining:
			stats.total_stats.most_cards_remaining = cards_remaining
	else:
		if reason == "Time's up!":
			stats.total_stats.time_ran_out += 1
	
	if current_game_stats.round_invalid_clicks == 0:
		stats.total_stats.perfect_rounds += 1
	
	# Check for best round score
	if not stats.best_rounds.has(str(round)) or score > stats.best_rounds[str(round)].score:
		stats.best_rounds[str(round)] = {
			"score": score,
			"seed": GameState.deck_seed,
			"date": _get_current_date(),
			"mode": mode,
			"game_type": game_type  # Add game_type
		}
	
	# Reset round-specific tracking
	current_game_stats.round_invalid_clicks = 0
	
	save_stats()

func check_daily_login():
	var today = Time.get_date_string_from_system()
	
	if last_login_date != today:
		var yesterday = _get_yesterday_date_string()
		
		# Check if consecutive login
		if last_login_date == yesterday:
			# Consecutive day - increment streak
			login_streak += 1
		elif last_login_date == "":
			# First login ever
			login_streak = 1
		else:
			# Missed a day - reset streak
			login_streak = 1
		
		# Update login tracking
		last_login_date = today
		daily_logins += 1
		
		# Save after updating
		save_stats()
		
		print("Daily login tracked - Streak: %d, Total logins: %d" % [login_streak, daily_logins])

func _get_yesterday_date_string() -> String:
	"""Get yesterday's date as a string"""
	var yesterday_unix = Time.get_unix_time_from_system() - 86400  # 24 hours in seconds
	var yesterday_dict = Time.get_datetime_dict_from_unix_time(yesterday_unix)
	return "%04d-%02d-%02d" % [yesterday_dict.year, yesterday_dict.month, yesterday_dict.day]

# === MULTIPLAYER TRACKING ===
func track_multiplayer_game(mode: String, placement: int, score: int, combo: int, clear_time: float, player_count: int) -> void:
	"""Track a multiplayer game with placement (1-8)"""
	print("Tracking multiplayer game: Mode=%s, Placement=%d/%d, Score=%d" % [mode, placement, player_count, score])
	
	# Ensure mode exists
	if not multiplayer_stats.has(mode):
		print("Creating multiplayer stats for mode: %s" % mode)
		multiplayer_stats[mode] = _create_multiplayer_stats()
	
	var stat = multiplayer_stats[mode]
	
	# Get current MMR (or default)
	var current_mmr = stat.get("mmr", 1000)
	if current_mmr == 0:
		current_mmr = 1000  # Initialize if not set
	
	# Calculate MMR change (only if RankingSystem exists)
	if has_node("/root/RankingSystem"):
		var mmr_change = RankingSystem.calculate_mmr_change(
			current_mmr,
			placement,
			player_count
		)
		stat["mmr"] = current_mmr + mmr_change
		print("  MMR: %d -> %d (change: %+d)" % [current_mmr, stat["mmr"], mmr_change])
	else:
		# Simple MMR calculation if RankingSystem doesn't exist
		var mmr_change = (player_count - placement) * 10 - 5
		stat["mmr"] = max(100, current_mmr + mmr_change)
		print("  MMR (simple): %d -> %d" % [current_mmr, stat["mmr"]])
	
	# Update basic counters
	stat.games += 1
	stat.total_score += score
	stat.average_score = float(stat.total_score) / float(stat.games)
	
	# Track placement
	if placement > 0 and placement <= 8:
		stat.placements[placement - 1] += 1
		if placement == 1:
			stat.first_place += 1
			# Update win streak
			stat.current_win_streak += 1
			if stat.current_win_streak > stat.best_win_streak:
				stat.best_win_streak = stat.current_win_streak
			print("  First place! Win streak: %d" % stat.current_win_streak)
		else:
			# Reset current streak on non-win
			stat.current_win_streak = 0
	
	# Update records
	if score > stat.highscore:
		stat.highscore = score
		print("  New multiplayer highscore for %s!" % mode)
	
	if combo > stat.longest_combo:
		stat.longest_combo = combo
	
	if clear_time > 0 and (stat.fastest_clear < 0 or clear_time < stat.fastest_clear):
		stat.fastest_clear = clear_time
	
	# Calculate average rank
	_calculate_average_rank(stat)
	print("  Average rank: %.2f" % stat.average_rank)
	
	# Also save as highscore in leaderboard if applicable
	save_score(mode + "_mp", score, SettingsSystem.player_name if SettingsSystem else "Player")
	save_stats()

func _calculate_average_rank(stat: Dictionary) -> void:
	"""Calculate average placement from placement array"""
	var total_rank = 0
	var total_games = 0
	
	for i in range(8):
		var count = stat.placements[i]
		if count > 0:
			total_rank += (i + 1) * count  # i+1 because index 0 = 1st place
			total_games += count
	
	if total_games > 0:
		stat.average_rank = float(total_rank) / float(total_games)
	else:
		stat.average_rank = 0.0

func get_multiplayer_stats(mode: String) -> Dictionary:
	"""Get multiplayer stats for a specific mode"""
	if not multiplayer_stats.has(mode):
		return _create_multiplayer_stats()
	return multiplayer_stats[mode]

func get_win_percentage(mode: String) -> float:
	"""Get first place percentage for a mode"""
	var stat = get_multiplayer_stats(mode)
	if stat.games > 0:
		return float(stat.first_place) / float(stat.games) * 100.0
	return 0.0

# === TRACKING HELPERS ===
func track_card_clicked() -> void:
	current_game_stats.cards_clicked += 1

func track_card_drawn() -> void:
	current_game_stats.cards_drawn += 1

func track_invalid_click() -> void:
	current_game_stats.invalid_clicks += 1
	current_game_stats.round_invalid_clicks += 1

func track_combo(combo: int) -> void:
	if combo > current_game_stats.highest_combo:
		current_game_stats.highest_combo = combo

# === LEADERBOARD FUNCTIONS ===
func save_score(mode_id: String, score: int, player_name: String = "Player"):
	"""Save a score for a specific game mode"""
	if not mode_highscores.has(mode_id):
		mode_highscores[mode_id] = []
	
	mode_highscores[mode_id].append({
		"player_name": player_name,
		"score": score,
		"timestamp": Time.get_unix_time_from_system(),
		"is_current_player": true
	})
	
	# Sort by score (descending)
	mode_highscores[mode_id].sort_custom(func(a, b): return a.score > b.score)
	
	# Keep only top 100
	if mode_highscores[mode_id].size() > 100:
		mode_highscores[mode_id].resize(100)
	
	# Update player's best
	if not player_best_scores.has(mode_id) or score > player_best_scores[mode_id]:
		player_best_scores[mode_id] = score
	
	save_stats()

func get_top_scores(mode_id: String, count: int = 5) -> Array:
	"""Get top scores for a specific mode"""
	if not mode_highscores.has(mode_id):
		return []
	
	var scores = mode_highscores[mode_id]
	return scores.slice(0, min(count, scores.size()))

func get_best_score(mode_id: String) -> int:
	"""Get player's best score for a mode"""
	return player_best_scores.get(mode_id, 0)

func get_player_rank(mode_id: String) -> int:
	"""Get player's rank in a specific mode"""
	var best = get_best_score(mode_id)
	if best == 0:
		return 999
	
	if not mode_highscores.has(mode_id):
		return 1
	
	var rank = 1
	for score_entry in mode_highscores[mode_id]:
		if score_entry.score > best:
			rank += 1
		else:
			break
	
	return rank

# === GETTERS ===
func get_highscore() -> Dictionary:
	"""Get overall highscore across all modes"""
	return stats.highscore

func get_mode_highscore(mode: String) -> int:
	"""Get highscore for a specific mode"""
	return player_best_scores.get(mode, 0)

func get_longest_combo() -> Dictionary:
	return stats.longest_combo

func get_best_round_score(round: int) -> Dictionary:
	var round_key = str(round)
	if stats.best_rounds.has(round_key):
		return stats.best_rounds[round_key]
	return {"score": 0, "seed": 0, "date": "", "mode": ""}

func get_mode_stats(mode: String) -> Dictionary:
	if stats.mode_stats.has(mode):
		return stats.mode_stats[mode]
	# Create if doesn't exist
	print("Warning: Mode '%s' not found in stats, creating it" % mode)
	stats.mode_stats[mode] = _create_mode_stats()
	return stats.mode_stats[mode]

func get_total_stats() -> Dictionary:
	return stats.total_stats

func get_average_score(mode: String = "") -> float:
	var stat_dict = stats.total_stats if mode == "" else get_mode_stats(mode)
	if stat_dict.games_played > 0:
		return float(stat_dict.total_score) / float(stat_dict.games_played)
	return 0.0

func get_clear_rate(mode: String = "") -> float:
	"""Get percentage of successful rounds"""
	var stat_dict = stats.total_stats if mode == "" else get_mode_stats(mode)
	if stat_dict.total_rounds > 0:
		# Successful rounds = total_rounds - time_ran_out
		var successful = stat_dict.total_rounds - stat_dict.time_ran_out
		return float(successful) / float(stat_dict.total_rounds) * 100.0
	return 0.0

func get_perfect_round_rate(mode: String = "") -> float:
	var stat_dict = stats.total_stats if mode == "" else get_mode_stats(mode)
	if stat_dict.total_rounds > 0:
		return float(stat_dict.perfect_rounds) / float(stat_dict.total_rounds) * 100.0
	return 0.0

# === UTILITIES ===
func _get_current_date() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]

func reset_all_stats() -> void:
	print("Resetting all statistics...")
	stats = {
		"version": STATS_VERSION,
		"best_rounds": {},
		"highscore": {"score": 0, "seed": 0, "date": "", "mode": ""},
		"longest_combo": {"combo": 0, "seed": 0, "date": "", "mode": ""},
		"mode_stats": {
			"classic": _create_mode_stats(),
			"timed_rush": _create_mode_stats(),
			"test": _create_mode_stats(),
			"zen": _create_mode_stats(),
			"daily_challenge": _create_mode_stats(),
			"puzzle_master": _create_mode_stats()
		},
		"total_stats": _create_mode_stats()
	}
	multiplayer_stats = {
		"classic": _create_multiplayer_stats(),
		"timed_rush": _create_multiplayer_stats(),
		"test": _create_multiplayer_stats(),
		"zen": _create_multiplayer_stats(),
		"daily_challenge": _create_multiplayer_stats(),
		"puzzle_master": _create_multiplayer_stats()
	}
	mode_highscores = {}
	player_best_scores = {}
	save_stats()
	print("All statistics reset")

# === DEBUG ===
func print_stats_summary() -> void:
	print("\n=== STATS SUMMARY ===")
	print("Highscore: %d (%s mode)" % [stats.highscore.score, stats.highscore.mode])
	print("Longest Combo: %d" % stats.longest_combo.combo)
	print("Total Games: %d" % stats.total_stats.games_played)
	print("Total Score: %d" % stats.total_stats.total_score)
	print("Average Score: %.1f" % get_average_score())
	print("Clear Rate: %.1f%%" % get_clear_rate())
	print("Perfect Round Rate: %.1f%%" % get_perfect_round_rate())
	print("Total Peaks Cleared: %d" % stats.total_stats.total_peaks_cleared)
	
	# Print mode-specific stats
	print("\n--- Mode Stats ---")
	for mode in ["classic", "timed_rush", "test"]:
		var mode_stat = get_mode_stats(mode)
		if mode_stat.games_played > 0:
			print("%s: %d games, highscore: %d" % [mode, mode_stat.games_played, get_mode_highscore(mode)])
	print("====================\n")

func print_multiplayer_summary(mode: String = "classic") -> void:
	var stat = get_multiplayer_stats(mode)
	print("\n=== MULTIPLAYER STATS (%s) ===" % mode)
	print("Games Played: %d" % stat.games)
	print("MMR: %d" % stat.get("mmr", 1000))
	print("First Place: %d (%.1f%%)" % [stat.first_place, get_win_percentage(mode)])
	print("Average Rank: %.2f" % stat.average_rank)
	print("Highscore: %d" % stat.highscore)
	print("Longest Combo: %d" % stat.longest_combo)
	print("Average Score: %.1f" % stat.average_score)
	print("Current Win Streak: %d" % stat.current_win_streak)
	print("Best Win Streak: %d" % stat.best_win_streak)
	if stat.fastest_clear > 0:
		print("Fastest Clear: %.1fs" % stat.fastest_clear)
	print("====================\n")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S:
			print_stats_summary()
		elif event.keycode == KEY_M:
			print_multiplayer_summary()

func check_and_claim_daily_reward() -> Dictionary:
	"""Check if daily reward is available and claim it"""
	var today = Time.get_date_string_from_system()
	var result = {
		"can_claim": false,
		"claimed": false,
		"streak_continued": false,
		"streak_broken": false,
		"new_streak": 0,
		"rewards": {"stars": 10, "xp": 50}  # Base rewards
	}
	
	# Check if already claimed today
	if last_claim_date == today:
		result.can_claim = false
		return result
	
	# Can claim - check streak
	var yesterday = _get_yesterday_date_string()
	
	if last_claim_date == yesterday:
		# Continuing streak
		login_streak += 1
		result.streak_continued = true
	elif last_claim_date == "":
		# First ever claim
		login_streak = 1
	else:
		# Broke streak
		login_streak = 1
		result.streak_broken = true
	
	# Update tracking
	last_claim_date = today
	daily_logins += 1
	result.claimed = true
	result.can_claim = false
	result.new_streak = login_streak
	
	# Bonus rewards for streaks
	if login_streak >= 7:
		result.rewards.stars = 15
		result.rewards.xp = 75
	if login_streak >= 30:
		result.rewards.stars = 20
		result.rewards.xp = 100
	
	# Apply rewards
	if StarManager:
		StarManager.add_stars(result.rewards.stars, "daily_login")
	if XPManager:
		XPManager.add_xp(result.rewards.xp, "daily_login")
	
	save_stats()
	return result

func has_unclaimed_daily_reward() -> bool:
	"""Check if daily reward is available to claim"""
	var today = Time.get_date_string_from_system()
	return last_claim_date != today

func get_current_login_streak() -> int:
	"""Get the current login streak, accounting for unclaimed today"""
	var today = Time.get_date_string_from_system()
	var yesterday = _get_yesterday_date_string()
	
	# If we claimed yesterday but not today yet, streak is still valid
	if last_claim_date == yesterday:
		return login_streak
	# If we claimed today, return current streak
	elif last_claim_date == today:
		return login_streak
	# Otherwise streak is broken
	else:
		return 0

func get_mode_stats_typed(mode: String, game_type: String = "solo") -> Dictionary:
	"""Get stats for a specific mode and game type combination"""
	var stats_key = "%s_%s" % [mode, game_type]
	if stats.mode_stats.has(stats_key):
		return stats.mode_stats[stats_key]
	# Create if doesn't exist
	print("Warning: Mode '%s' not found in stats, creating it" % stats_key)
	stats.mode_stats[stats_key] = _create_mode_stats()
	return stats.mode_stats[stats_key]

func get_mode_highscore_typed(mode: String, game_type: String = "solo") -> int:
	"""Get highscore for a specific mode and game type"""
	var leaderboard_key = "%s_%s" % [mode, game_type]
	return player_best_scores.get(leaderboard_key, 0)
	
func get_highscore_typed(game_type: String = "solo") -> Dictionary:
	"""Get overall highscore for a specific game type"""
	var key = "highscore_%s" % game_type
	if stats.has(key):
		return stats[key]
	return {"score": 0, "seed": 0, "date": "", "mode": "", "game_type": game_type}

func get_longest_combo_typed(game_type: String = "solo") -> Dictionary:
	"""Get longest combo for a specific game type"""
	var key = "longest_combo_%s" % game_type
	if stats.has(key):
		return stats[key]
	return {"combo": 0, "seed": 0, "date": "", "mode": "", "game_type": game_type}

func get_average_score_typed(mode: String, game_type: String = "solo") -> float:
	"""Get average score for a specific mode and game type"""
	var stats_key = "%s_%s" % [mode, game_type]
	var stat_dict = get_mode_stats_typed(mode, game_type)
	if stat_dict.games_played > 0:
		return float(stat_dict.total_score) / float(stat_dict.games_played)
	return 0.0

func get_clear_rate_typed(mode: String, game_type: String = "solo") -> float:
	"""Get clear rate for a specific mode and game type"""
	var stats_key = "%s_%s" % [mode, game_type]
	var stat_dict = get_mode_stats_typed(mode, game_type)
	if stat_dict.total_rounds > 0:
		var successful = stat_dict.total_rounds - stat_dict.time_ran_out
		return float(successful) / float(stat_dict.total_rounds) * 100.0
	return 0.0

func get_perfect_round_rate_typed(mode: String, game_type: String = "solo") -> float:
	"""Get perfect round rate for a specific mode and game type"""
	var stats_key = "%s_%s" % [mode, game_type]
	var stat_dict = get_mode_stats_typed(mode, game_type)
	if stat_dict.total_rounds > 0:
		return float(stat_dict.perfect_rounds) / float(stat_dict.total_rounds) * 100.0
	return 0.0
