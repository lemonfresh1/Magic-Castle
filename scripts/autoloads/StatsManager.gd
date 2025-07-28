# StatsManager.gd - Autoload for tracking game statistics
# Path: res://Magic-Castle/scripts/managers/StatsManager.gd
extends Node

const SAVE_PATH = "user://stats.save"
const STATS_VERSION = 1

# Main stats dictionary
var stats = {
	"version": STATS_VERSION,
	
	# Best scores for each round (1-10)
	"best_rounds": {}, # round_number: {score, seed, date, mode}
	
	# Overall records
	"highscore": {"score": 0, "seed": 0, "date": "", "mode": ""},
	"longest_combo": {"combo": 0, "seed": 0, "date": "", "mode": ""},
	
	# Per mode statistics
	"mode_stats": {
		"tri_peaks": _create_mode_stats(),
		"rush": _create_mode_stats(),
		"chill": _create_mode_stats(),
		"test": _create_mode_stats()
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
	"perfect_rounds": []  # Array of round numbers with no invalid clicks
}

func _ready() -> void:
	print("StatsManager initializing...")
	load_stats()
	print("StatsManager ready")

func _create_mode_stats() -> Dictionary:
	return {
		"games_played": 0,
		"rounds_cleared": 0,
		"rounds_failed": 0,
		"total_rounds": 0,
		"time_ran_out": 0,
		"cards_clicked": 0,
		"cards_drawn": 0,
		"invalid_clicks": 0,
		"peak_clears": {"1": 0, "2": 0, "3": 0},
		"perfect_rounds": 0,
		"fastest_clear": -1.0,  # seconds, -1 = no clear yet
		"most_cards_remaining": 0,
		"suit_bonuses": 0,
		"total_score": 0,  # For calculating average
		"highest_round_reached": 0
	}

# === SAVE/LOAD ===
func save_stats() -> void:
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file:
		save_file.store_var(stats)
		save_file.close()
		print("Stats saved successfully")
	else:
		print("Failed to save stats")

func load_stats() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if save_file:
			var loaded_stats = save_file.get_var()
			save_file.close()
			
			# Validate and migrate if needed
			if loaded_stats and loaded_stats.has("version"):
				stats = loaded_stats
				_migrate_stats_if_needed()
				print("Stats loaded successfully")
			else:
				print("Invalid stats file, using defaults")
		else:
			print("Failed to load stats")
	else:
		print("No stats file found, using defaults")

func _migrate_stats_if_needed() -> void:
	# Future migrations go here
	if stats.version < STATS_VERSION:
		print("Migrating stats from version %d to %d" % [stats.version, STATS_VERSION])
		stats.version = STATS_VERSION
		save_stats()

# === GAME TRACKING ===
func start_game(mode: String) -> void:
	print("StatsManager: Starting game in %s mode" % mode)  # ADD THIS

	current_game_stats = {
		"cards_clicked": 0,
		"cards_drawn": 0,
		"invalid_clicks": 0,
		"highest_combo": 0,
		"time_started": Time.get_ticks_msec(),
		"perfect_rounds": [],
		"round_invalid_clicks": 0  # Track per round
	}
	
	# Increment games played
	if stats.mode_stats.has(mode):
		stats.mode_stats[mode].games_played += 1
	stats.total_stats.games_played += 1
	
	save_stats()

func end_game(mode: String, final_score: int, rounds_completed: int) -> void:
	print("StatsManager: Game ended - Mode: %s, Score: %d, Rounds: %d" % [mode, final_score, rounds_completed])  # ADD THIS

	# Update mode and total stats with accumulated values
	if stats.mode_stats.has(mode):
		var mode_stat = stats.mode_stats[mode]
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
	
	# Check for new highscore
	if final_score > stats.highscore.score:
		stats.highscore = {
			"score": final_score,
			"seed": GameState.deck_seed,
			"date": _get_current_date(),
			"mode": mode
		}
	
	# Check for longest combo
	if current_game_stats.highest_combo > stats.longest_combo.combo:
		stats.longest_combo = {
			"combo": current_game_stats.highest_combo,
			"seed": GameState.deck_seed,
			"date": _get_current_date(),
			"mode": mode
		}
	
	save_stats()

func track_round_end(round: int, cleared: bool, score: int, time_left: float, reason: String, mode: String) -> void:
	# Update round stats
	if stats.mode_stats.has(mode):
		var mode_stat = stats.mode_stats[mode]
		mode_stat.total_rounds += 1
		
		if cleared:
			mode_stat.rounds_cleared += 1
			
			# Track fastest clear
			var clear_time = GameState.round_time_limit - time_left
			if mode_stat.fastest_clear < 0 or clear_time < mode_stat.fastest_clear:
				mode_stat.fastest_clear = clear_time
			
			# Track most cards remaining
			var cards_remaining = CardManager.draw_pile.size()
			if cards_remaining > mode_stat.most_cards_remaining:
				mode_stat.most_cards_remaining = cards_remaining
		else:
			mode_stat.rounds_failed += 1
			
			if reason == "Time's up!":
				mode_stat.time_ran_out += 1
		
		# Check for perfect round (no invalid clicks this round)
		if current_game_stats.round_invalid_clicks == 0:
			mode_stat.perfect_rounds += 1
			current_game_stats.perfect_rounds.append(round)
	
	# Update totals
	stats.total_stats.total_rounds += 1
	if cleared:
		stats.total_stats.rounds_cleared += 1
		var clear_time = GameState.round_time_limit - time_left
		if stats.total_stats.fastest_clear < 0 or clear_time < stats.total_stats.fastest_clear:
			stats.total_stats.fastest_clear = clear_time
		
		var cards_remaining = CardManager.draw_pile.size()
		if cards_remaining > stats.total_stats.most_cards_remaining:
			stats.total_stats.most_cards_remaining = cards_remaining
	else:
		stats.total_stats.rounds_failed += 1
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
			"mode": mode
		}
	
	# Reset round-specific tracking
	current_game_stats.round_invalid_clicks = 0
	
	save_stats()

func track_card_clicked() -> void:
	print("StatsManager: Card clicked! Total: %d" % current_game_stats.cards_clicked)  # ADD THIS

	current_game_stats.cards_clicked += 1

func track_card_drawn() -> void:
	current_game_stats.cards_drawn += 1

func track_invalid_click() -> void:
	current_game_stats.invalid_clicks += 1
	current_game_stats.round_invalid_clicks += 1

func track_combo(combo: int) -> void:
	if combo > current_game_stats.highest_combo:
		current_game_stats.highest_combo = combo

func track_peak_clears(peaks_cleared: int, mode: String) -> void:
	if stats.mode_stats.has(mode) and peaks_cleared > 0:
		stats.mode_stats[mode].peak_clears[str(peaks_cleared)] += 1
		stats.total_stats.peak_clears[str(peaks_cleared)] += 1

func track_suit_bonus(mode: String) -> void:
	if stats.mode_stats.has(mode):
		stats.mode_stats[mode].suit_bonuses += 1
	stats.total_stats.suit_bonuses += 1

# === GETTERS ===
func get_highscore() -> Dictionary:
	return stats.highscore

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
	return _create_mode_stats()

func get_total_stats() -> Dictionary:
	return stats.total_stats

func get_average_score(mode: String = "") -> float:
	var stat_dict = stats.total_stats if mode == "" else get_mode_stats(mode)
	if stat_dict.games_played > 0:
		return float(stat_dict.total_score) / float(stat_dict.games_played)
	return 0.0

func get_clear_rate(mode: String = "") -> float:
	var stat_dict = stats.total_stats if mode == "" else get_mode_stats(mode)
	if stat_dict.total_rounds > 0:
		return float(stat_dict.rounds_cleared) / float(stat_dict.total_rounds) * 100.0
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
			"tri_peaks": _create_mode_stats(),
			"rush": _create_mode_stats(),
			"chill": _create_mode_stats(),
			"test": _create_mode_stats()
		},
		"total_stats": _create_mode_stats()
	}
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
	print("====================\n")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S:
			print_stats_summary()
			print("Current game stats:")
			print("  Cards clicked: %d" % current_game_stats.cards_clicked)
			print("  Cards drawn: %d" % current_game_stats.cards_drawn)
			print("  Invalid clicks: %d" % current_game_stats.invalid_clicks)
			print("  Highest combo: %d" % current_game_stats.highest_combo)
