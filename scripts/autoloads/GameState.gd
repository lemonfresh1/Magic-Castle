# GameState.gd - Core game state management and round orchestration autoload
# Path: res://Pyramids/scripts/autoloads/GameState.gd
# Last Updated: Enhanced documentation, added debug system, reorganized functions
#
# Purpose: Central authority for game state, managing rounds, scoring, seeding, and game flow.
# Handles single and multiplayer modes, deterministic seed generation for rounds, timing,
# and coordinates between all game systems. Tracks game context for different play modes
# (standard, seeded, tournament, battle, custom lobby) and their leaderboard eligibility.
#
# Dependencies:
# - SignalBus (autoload) - Global event system for game-wide signals
# - GameConstants (autoload) - Core game constants and rules
# - GameModeManager (autoload) - Manages different game modes and round settings
# - CardManager (autoload) - Card system management and valid move checking
# - ScoreSystem (autoload) - Score calculation and combo tracking
# - StatsManager (autoload) - Statistics tracking and persistence
# - AchievementManager (autoload) - Achievement checking and unlocking
# - XPManager (autoload) - Experience point management
# - StarManager (autoload) - Star rewards management
# - MultiplayerManager (optional) - Multiplayer lobby and networking
#
# Game Flow:
# 1. start_new_game() - Initialize game with mode and optional seed
# 2. start_round() - Generate round-specific seed from master seed
# 3. Game plays out with timer and card clearing
# 4. check_round_end() - Monitor win/lose conditions
# 5. end_round() - Calculate scores, show score screen
# 6. _continue_to_next_round() or _end_game() based on rounds
# 7. Track stats, achievements, and leaderboard eligibility
#
# Seed System:
# - Master game_seed generates deterministic round seeds
# - Round seeds ensure consistent gameplay for replays
# - Seeded games marked for separate leaderboards
# - See: res://docs/Seedsystem.txt
#
# Context System:
# - Standard: Random seed, affects global leaderboard
# - Seeded: Custom seed, separate leaderboard
# - Tournament/Battle/Lobby: Special modes with custom rules (TODO)

extends Node

# Debug configuration
var debug_enabled: bool = false
var global_debug: bool = false

# === GAME MODE ===
var game_mode: String = "single" # "single", "multi"
var is_multiplayer: bool = false

# === ROUND STATE ===
var current_round: int = 1
var is_round_active: bool = false
var round_time_limit: int = 60
var time_remaining: float = 60.0

# === SEED SYSTEM ===
var game_seed: int = 0  # Master seed for entire game
var deck_seed: int = 0  # Current round seed (for compatibility)
var round_rng: RandomNumberGenerator  # RNG for generating round seeds

# === CARD STATE ===
var cards_cleared: int = 0
var board_cleared: bool = false

# === SCORE STATE ===
var current_score: int = 0
var round_scores: Array[int] = []
var total_score: int = 0
var round_stats: Array[Dictionary] = []  # Track each round's details

# === MULTIPLAYER ===
var multiplayer_scores: Dictionary = {}  # player_id -> total_score
var multiplayer_round_data: Array = []   # Track each round's results

# === TIMER ===
var game_timer: Timer

# === GAME CONTEXT ===
var game_context: Dictionary = {
	"type": "standard",  # standard, seeded, tournament, battle, custom_lobby
	"is_seeded": false,
	"seed_source": "",  # "manual", "leaderboard", "tournament_123", "battle_456"
	"affects_global_leaderboard": true,
	"affects_mode_leaderboard": true,  # For mode-specific boards
	"tournament_id": "",  # TODO:TOURNAMENT - Implement tournament support
	"battle_id": "",  # TODO:BATTLE - Implement battle support
	"custom_lobby_id": ""  # TODO:CUSTOM_LOBBY - Implement custom lobby support
}

# === INITIALIZATION ===

func _ready() -> void:
	# CRITICAL: Initialize random number generator with system time
	randomize()
	debug_log("Randomized RNG seed: %d" % randi())
	
	_setup_timer()
	_connect_signals()
	set_process(false)  # Don't process until round starts

func _setup_timer() -> void:
	# Create timer for game timing
	game_timer = Timer.new()
	game_timer.timeout.connect(_on_timer_timeout)
	add_child(game_timer)

func _connect_signals() -> void:
	# Connect to relevant signals
	SignalBus.timer_expired.connect(_on_timer_expired)

func _process(delta: float) -> void:
	if is_round_active and time_remaining > 0:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			SignalBus.timer_expired.emit()
			check_round_end()

# === GAME MANAGEMENT ===

func start_new_game(mode: String = "single", custom_seed: int = 0) -> void:
	debug_log("\n=== START_NEW_GAME DEBUG ===")
	debug_log("Input parameters: mode=%s, custom_seed=%d" % [mode, custom_seed])
	
	# RESET EVERYTHING FIRST
	game_mode = mode
	is_multiplayer = (mode == "multi")
	current_round = 1
	total_score = 0
	round_scores.clear()
	round_stats.clear()
	current_score = 0
	cards_cleared = 0
	board_cleared = false
	
	# CRITICAL: Clear old RNG to ensure deterministic behavior
	if round_rng != null:
		debug_log("Clearing existing round_rng")
	round_rng = null
	deck_seed = 0
	
	# === SEED SYSTEM SETUP ===
	# Check for stored custom seed first (from set_custom_seed)
	if custom_seed == 0 and has_meta("custom_seed"):
		custom_seed = get_meta("custom_seed")
		remove_meta("custom_seed")  # Clear it after use
		debug_log("Found stored custom seed in metadata: %d" % custom_seed)
		# Also check for seed source
		if has_meta("seed_source"):
			var source = get_meta("seed_source")
			game_context.seed_source = source
			remove_meta("seed_source")
	
	# === GAME CONTEXT SETUP ===
	if custom_seed != 0:
		game_seed = custom_seed
		debug_log("Using CUSTOM seed: %d" % game_seed)
		
		# Set context for seeded game
		game_context = {
			"type": "seeded",
			"is_seeded": true,
			"seed_source": game_context.get("seed_source", "manual"),  # Preserve if set
			"affects_global_leaderboard": false,  # Seeded games don't affect global
			"affects_mode_leaderboard": true,  # But they can have their own board
			"tournament_id": "",  # TODO:TOURNAMENT - Check for tournament context
			"battle_id": "",  # TODO:BATTLE - Check for battle context
			"custom_lobby_id": ""  # TODO:CUSTOM_LOBBY - Check for lobby context
		}
		debug_log("Game context set to SEEDED - will NOT affect global leaderboard")
	else:
		game_seed = randi()
		debug_log("Generated NEW RANDOM seed: %d" % game_seed)
		
		# Set context for standard game
		game_context = {
			"type": "standard",
			"is_seeded": false,
			"seed_source": "",
			"affects_global_leaderboard": true,
			"affects_mode_leaderboard": true,
			"tournament_id": "",
			"battle_id": "",
			"custom_lobby_id": ""
		}
		debug_log("Game context set to STANDARD - will affect global leaderboard")
	
	# Initialize FRESH round RNG with our game seed
	round_rng = RandomNumberGenerator.new()
	round_rng.seed = game_seed
	debug_log("Created new round_rng with seed: %d" % game_seed)
	
	# Store game seed for saving to leaderboard
	deck_seed = game_seed
	debug_log("Set deck_seed = game_seed = %d" % game_seed)
	
	var game_mode_name = GameModeManager.get_current_mode()
	var game_type = "multi" if is_multiplayer else "solo"
	debug_log("Game mode: %s, Game type: %s" % [game_mode_name, game_type])
	
	StatsManager.start_game(game_mode_name, game_type)
	XPManager.rewards_enabled = false
	StarManager.rewards_enabled = false
	
	debug_log("=== END START_NEW_GAME ===\n")
	start_round()

func set_game_context(context_type: String, metadata: Dictionary = {}) -> void:
	"""Set game context for special game modes
	TODO:TOURNAMENT - Use this when starting tournament games
	TODO:BATTLE - Use this when starting battle games
	TODO:CUSTOM_LOBBY - Use this when starting custom lobby games
	"""
	game_context.type = context_type
	
	match context_type:
		"tournament":
			game_context.is_seeded = true
			game_context.affects_global_leaderboard = false
			game_context.affects_mode_leaderboard = false
			game_context.tournament_id = metadata.get("tournament_id", "")
			game_context.seed_source = "tournament_" + game_context.tournament_id
			
		"battle":
			game_context.is_seeded = true
			game_context.affects_global_leaderboard = false
			game_context.affects_mode_leaderboard = false
			game_context.battle_id = metadata.get("battle_id", "")
			game_context.seed_source = "battle_" + game_context.battle_id
			
		"custom_lobby":
			game_context.is_seeded = metadata.get("is_seeded", false)
			game_context.affects_global_leaderboard = false
			game_context.affects_mode_leaderboard = true
			game_context.custom_lobby_id = metadata.get("lobby_id", "")
			game_context.seed_source = "lobby_" + game_context.custom_lobby_id
			
		"seeded":
			game_context.is_seeded = true
			game_context.affects_global_leaderboard = false
			game_context.affects_mode_leaderboard = true
			game_context.seed_source = metadata.get("source", "manual")
			
		_:  # "standard"
			game_context.is_seeded = false
			game_context.affects_global_leaderboard = true
			game_context.affects_mode_leaderboard = true
			game_context.seed_source = ""
	
	debug_log("Context set to: %s (global_lb: %s, mode_lb: %s)" % 
		[context_type, game_context.affects_global_leaderboard, game_context.affects_mode_leaderboard])

func reset_game_completely() -> void:
	# Clean up any persistent UI nodes
	var score_screens = get_tree().get_nodes_in_group("score_screen")
	for screen in score_screens:
		screen.queue_free()
	
	var post_game_screens = get_tree().get_nodes_in_group("post_game_summary")
	for screen in post_game_screens:
		screen.queue_free()
	
	# Reset GameState variables
	current_round = 1
	total_score = 0
	round_scores.clear()
	round_stats.clear()
	is_round_active = false
	time_remaining = 0
	cards_cleared = 0
	board_cleared = false
	current_score = 0
	game_seed = 0
	deck_seed = 0
	round_rng = null
	
	# CRITICAL: Clear ALL metadata including custom_seed
	if has_meta("custom_seed"):
		remove_meta("custom_seed")
		debug_log("Cleared custom_seed metadata")
	if has_meta("multiplayer_placement"):
		remove_meta("multiplayer_placement")
	if has_meta("multiplayer_player_count"):
		remove_meta("multiplayer_player_count")
	if has_meta("multiplayer_mode"):
		remove_meta("multiplayer_mode")
	if has_meta("affects_mmr"):
		remove_meta("affects_mmr")
	if has_meta("debug_forced_placement"):
		remove_meta("debug_forced_placement")
	if has_meta("round_end_reason"):
		remove_meta("round_end_reason")
	
	# Reset CardManager
	if CardManager:
		CardManager.current_combo = 0
		CardManager.cards_drawn = 0
		CardManager.slot_cards = [null, null, null]
		CardManager.active_slots = 1
		CardManager.board_cards.clear()
		CardManager.draw_pile.clear()
	
	# Reset ScoreSystem
	if ScoreSystem:
		ScoreSystem.current_multiplier = 1.0
		ScoreSystem.peaks_cleared_indices.clear()
		ScoreSystem.last_selected_card = null
		ScoreSystem.pending_round_end = false
		if ScoreSystem.combo_timer:
			ScoreSystem.combo_timer.stop()
	
	# Ensure game timer is stopped
	if game_timer:
		game_timer.stop()
	
	# Stop processing
	set_process(false)
	
	debug_log("Game completely reset")

# === ROUND MANAGEMENT ===

func start_round() -> void:
	debug_log("\n=== START_ROUND DEBUG ===")
	debug_log("Current round: %d" % current_round)
	debug_log("Game seed: %d" % game_seed)
	
	# === GENERATE ROUND-SPECIFIC SEED ===
	# Get the next seed in our deterministic sequence
	if round_rng == null:
		debug_log("ERROR: round_rng is null!")
		return
	
	var round_seed = round_rng.randi()
	deck_seed = round_seed  # Set deck_seed for this round
	
	debug_log("Generated round seed: %d (from game seed: %d)" % [round_seed, game_seed])
	
	# Get round settings from current game mode
	var round_data = GameModeManager.handle_round_start(current_round)
	
	# Calculate round parameters using GameModeManager
	round_time_limit = round_data.get("time_limit", GameModeManager.get_round_time_limit(current_round))
	time_remaining = float(round_time_limit)
	
	debug_log("Round time limit: %d seconds" % round_time_limit)
	
	# Set combo timeout if specified (for chill mode)
	if round_data.has("combo_timeout") and ScoreSystem.has_method("set_combo_timeout"):
		ScoreSystem.call("set_combo_timeout", round_data.get("combo_timeout", 5.0))
	
	# Reset round state
	current_score = 0
	cards_cleared = 0
	board_cleared = false
	is_round_active = true
	
	# Start timer
	set_process(true)
	
	debug_log("=== END START_ROUND ===\n")
	SignalBus.round_started.emit(current_round)

func check_round_end() -> void:
	"""Check if round should end and determine the reason"""
	if not is_round_active:
		return
		
	var should_end = false
	var reason = ""
	
	# 1. Board cleared (win condition)
	if cards_cleared == GameConstants.BOARD_CARDS or board_cleared:
		should_end = true
		board_cleared = true
		reason = "Board cleared!"
	
	# 2. No valid moves (lose condition)
	elif not _has_valid_moves():
		should_end = true
		board_cleared = false
		reason = "No valid moves!"
	
	# 3. Time expired (lose condition)
	elif time_remaining <= 0:
		should_end = true
		board_cleared = false
		reason = "Time's up!"
	
	if should_end:
		set_meta("round_end_reason", reason)
		_delayed_end_round(reason)

func _delayed_end_round(reason: String) -> void:
	"""End round with a small delay to ensure all systems sync"""
	# Wait 0.2 seconds for all systems to process
	await get_tree().create_timer(0.2).timeout
	
	# Double-check we should still end
	if not is_round_active:
		return
		
	end_round()

func end_round() -> void:
	"""Actually end the current round"""
	is_round_active = false
	set_process(false)  # Stop timer processing

	# Store peak data before it gets reset
	if ScoreSystem and ScoreSystem.peaks_cleared_indices.size() >= 3:
		pass  # All 3 peaks cleared
	
	# Check speed clear while time_remaining is still valid
	if board_cleared and round_time_limit > 0:
		var time_taken = round_time_limit - time_remaining
		# Board cleared in time_taken seconds
	
	AchievementManager.check_achievements()

	# Calculate scores through ScoreSystem
	var scores = ScoreSystem.calculate_round_scores(board_cleared)
	
	# Store round score
	round_scores.append(scores.round_total)
	
	# Store detailed round stats
	round_stats.append({
		"round": current_round,
		"score": scores.round_total,
		"cleared": board_cleared,
		"cards_cleared": cards_cleared,
		"time_left": int(time_remaining),
		"base_score": scores.base,
		"cards_bonus": scores.cards,
		"time_bonus": scores.time,
		"clear_bonus": scores.clear
	})
	
	SignalBus.round_completed.emit(scores.round_total)
	
	# Get mode and game_type for tracking
	var mode = GameModeManager.get_current_mode()
	var game_type = "multi" if is_multiplayer else "solo"
	var reason = get_meta("round_end_reason", "Unknown")
	
	# Pass game_type to track_round_end
	StatsManager.track_round_end(
		current_round,
		board_cleared,
		scores.round_total,
		time_remaining,
		reason,
		mode,
		game_type
	)
	
	# Track peak clears with game_type
	if ScoreSystem.peaks_cleared_indices.size() > 0:
		StatsManager.track_peak_clears(ScoreSystem.peaks_cleared_indices.size(), mode, game_type)
	
	# Show score screen
	_show_score_screen(scores)

func _show_score_screen(scores: Dictionary) -> void:
	"""Display the score screen"""
	var score_screen = get_tree().get_first_node_in_group("score_screen")
	if not score_screen:
		var score_scene = load("res://Pyramids/scenes/ui/game_ui/ScoreScreen.tscn")
		if score_scene:
			score_screen = score_scene.instantiate()
			score_screen.add_to_group("score_screen")
			get_tree().root.add_child(score_screen)
		else:
			_continue_to_next_round()
			return
	
	score_screen.show_round_complete(current_round, scores)

func _continue_to_next_round() -> void:
	"""Continue to next round or end game"""
	# Update total score
	if round_scores.size() > 0:
		total_score += round_scores[-1]
	
	current_round += 1
	
	# Check if game is complete based on current mode
	var max_rounds = GameModeManager.get_max_rounds()
	if current_round > max_rounds:
		_end_game()
	else:
		start_round()

func _end_game() -> void:
	debug_log("\n=== GAME OVER DEBUG ===")
	debug_log("Final score: %d" % total_score)
	debug_log("Game seed was: %d" % game_seed)
	debug_log("Current deck_seed: %d" % deck_seed)
	debug_log("Saving to stats with game_seed: %d" % game_seed)
	
	# Get the current game mode
	var mode = GameModeManager.get_current_mode()
	
	# Determine game type
	var game_type = "multi" if game_mode == "multi" else "solo"
	
	# Check if multiplayer or single player
	if game_mode == "multi":
		# MULTIPLAYER PATH
		debug_log("Multiplayer game ending...")
		
		# Get placement and player count
		var placement = 1
		var player_count = 8  # Default
		var affects_mmr = false
		
		if has_node("/root/MultiplayerManager"):
			var mp_manager = get_node("/root/MultiplayerManager")
			var lobby_info = mp_manager.get_lobby_info()
			player_count = lobby_info.players.size()
			if player_count == 0:
				player_count = 1  # Fallback
			
			# Check if this game affects MMR
			affects_mmr = mp_manager.affects_mmr()
			
			# === TESTING OVERRIDE ===
			# If in test mode and alone, simulate a full lobby
			if mode == "test" and player_count == 1:
				debug_log("[TEST MODE] Simulating 8-player lobby")
				player_count = 8
				# Check for forced debug placement, otherwise random
				if has_meta("debug_forced_placement"):
					placement = get_meta("debug_forced_placement")
					remove_meta("debug_forced_placement")
					debug_log("[TEST MODE] Using forced placement: %d" % placement)
				else:
					placement = randi_range(1, 8)
					debug_log("[TEST MODE] Random placement: %d" % placement)
				affects_mmr = true  # Force MMR changes in test
			else:
				# TODO: Get actual placement when you have all player scores
				placement = randi_range(1, player_count)
		
		# Store metadata for PostGameSummary to read
		set_meta("multiplayer_placement", placement)
		set_meta("multiplayer_player_count", player_count)
		set_meta("multiplayer_mode", mode)
		set_meta("affects_mmr", affects_mmr)
		
		debug_log("Multiplayer result: Placed %d/%d in %s mode (affects MMR: %s)" % 
			[placement, player_count, mode, affects_mmr])
		
		# Track multiplayer game only if it affects MMR
		if affects_mmr:
			var max_combo = 0  # TODO: Get from ScoreSystem
			var clear_time = 0.0  # TODO: Track if needed
			
			# Pass game_seed for multiplayer tracking
			StatsManager.track_multiplayer_game(
				mode,
				placement,
				total_score,
				max_combo,
				clear_time,
				player_count,
				game_seed  # Pass the game seed
			)
			debug_log("MMR updated for matchmaking game")
		else:
			debug_log("Custom/Tournament game - no MMR change")
		
		# Still track regular game for other stats - with game_seed
		StatsManager.end_game(mode, total_score, current_round - 1, game_type)
	else:
		# SINGLE PLAYER PATH
		debug_log("Single player game ending...")
		StatsManager.end_game(mode, total_score, current_round - 1, game_type)
	
	# Check achievements for both modes
	debug_log("Checking achievements...")
	AchievementManager.check_achievements()
	
	debug_log("=== END GAME OVER ===\n")
	
	# Emit game over signal
	SignalBus.game_over.emit(total_score)

func _return_to_menu() -> void:
	# First reset everything
	reset_game_completely()
	
	# Then return to main menu
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")

# === SEED UTILITIES ===

func get_game_seed() -> int:
	"""Get the master game seed for replay purposes"""
	return game_seed

func set_custom_seed(seed: int, source: String = "manual") -> void:
	"""Set a custom seed for the next game (call before start_new_game)
	
	Args:
		seed: The seed value to use
		source: Where the seed came from - "manual", "leaderboard", "tournament_123", "battle_456"
	"""
	debug_log("\nset_custom_seed called with: %d (source: %s)" % [seed, source])
	set_meta("custom_seed", seed)
	set_meta("seed_source", source)
	debug_log("Stored custom seed in metadata: %d" % seed)
	debug_log("Seed source marked as: %s" % source)

# === STATE QUERIES ===

func is_eligible_for_global_leaderboard() -> bool:
	"""Check if current game should be saved to global leaderboard"""
	return game_context.get("affects_global_leaderboard", true)

func is_eligible_for_mode_leaderboard() -> bool:
	"""Check if current game should be saved to mode-specific leaderboard"""
	return game_context.get("affects_mode_leaderboard", true)

func is_game_active() -> bool:
	return is_round_active

func is_final_round() -> bool:
	return current_round >= GameModeManager.get_max_rounds()

func get_rounds_remaining() -> int:
	return max(0, GameModeManager.get_max_rounds() - current_round + 1)

func get_base_card_points() -> int:
	"""Get base points for current round"""
	return GameModeManager.get_base_card_points(current_round)

func get_draw_pile_limit() -> int:
	"""Get draw pile limit for current round"""
	return GameModeManager.get_draw_pile_limit(current_round)

func get_round_progress() -> float:
	"""Get progress through current round (0.0 to 1.0)"""
	if round_time_limit <= 0:
		return 1.0
	return 1.0 - (time_remaining / round_time_limit)

func get_game_progress() -> float:
	"""Get progress through entire game (0.0 to 1.0)"""
	return float(current_round - 1) / float(GameModeManager.get_max_rounds())

func get_current_round_info() -> Dictionary:
	return {
		"round": current_round,
		"time_limit": round_time_limit,
		"time_remaining": time_remaining,
		"cards_cleared": cards_cleared,
		"current_score": current_score,
		"board_cleared": board_cleared,
		"draw_limit": get_draw_pile_limit()
	}

# === MULTIPLAYER HELPERS ===

func get_player_data() -> Dictionary:
	"""Get current player data for multiplayer"""
	return {
		"round": current_round,
		"score": current_score,
		"total_score": total_score,
		"cards_cleared": cards_cleared,
		"time_remaining": time_remaining,
		"board_cleared": board_cleared
	}

func sync_multiplayer_round(round_data: Dictionary) -> void:
	"""Sync round data in multiplayer (placeholder)"""
	# This will be implemented in multiplayer phase
	pass

func _handle_multiplayer_end(mode: String) -> void:
	"""Handle multiplayer game completion"""
	
	# Get player count and placement from MultiplayerManager
	var player_count = 8  # Default
	var local_player_id = ""
	var placement = 1  # Default to first for now
	
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		var lobby_info = mp_manager.get_lobby_info()
		player_count = lobby_info.players.size()
		if player_count == 0:
			player_count = 1  # Fallback
		local_player_id = mp_manager.local_player_data.get("id", "")
		
		# TODO: Get actual placement when networking is implemented
		# For now, simulate placement based on score
		placement = randi_range(1, player_count)  # Random for testing
	
	# Store metadata for PostGameSummary to use
	set_meta("multiplayer_placement", placement)
	set_meta("multiplayer_player_count", player_count)
	set_meta("multiplayer_mode", mode)
	
	debug_log("Multiplayer game ended:")
	debug_log("  Mode: %s" % mode)
	debug_log("  Placement: %d/%d" % [placement, player_count])
	debug_log("  Score: %d" % total_score)
	
	# Track the game in stats with game_seed
	var max_combo = 0  # TODO: Get from ScoreSystem if available
	var clear_time = 0.0  # TODO: Track fastest clear if applicable
	
	StatsManager.track_multiplayer_game(
		mode,
		placement,
		total_score,
		max_combo,
		clear_time,
		player_count,
		game_seed  # Pass the game seed
	)
	
	# Still call regular end game for achievements
	StatsManager.end_game(mode, total_score, current_round - 1)
	AchievementManager.check_achievements()

func _calculate_placement(my_score: int, all_scores: Array) -> int:
	"""Calculate placement based on score"""
	var placement = 1
	for score in all_scores:
		if score > my_score:
			placement += 1
	return placement

func _get_multiplayer_final_scores() -> Array:
	"""Get all player scores - TODO: Get from network"""
	# MOCK DATA for testing
	return [
		total_score,  # Our score
		total_score + randi_range(-500, 500),
		total_score + randi_range(-500, 500),
		total_score + randi_range(-500, 500),
		total_score + randi_range(-500, 500),
		total_score + randi_range(-500, 500),
		total_score + randi_range(-500, 500),
		total_score + randi_range(-500, 500)
	]

# === HELPER FUNCTIONS ===

func _has_valid_moves() -> bool:
	"""Check if there are any valid moves available (delegated to CardManager)"""
	return CardManager.has_valid_moves() if CardManager else false

# === SIGNAL HANDLERS ===

func _on_timer_timeout() -> void:
	SignalBus.timer_expired.emit()

func _on_timer_expired() -> void:
	check_round_end()

# === DEBUG FUNCTIONS ===

func debug_log(message: String) -> void:
	"""Debug logging with component prefix"""
	if debug_enabled and global_debug:
		print("[GAMESTATE] %s" % message)

func get_debug_info() -> Dictionary:
	return {
		"game_mode": game_mode,
		"current_round": current_round,
		"is_round_active": is_round_active,
		"time_remaining": time_remaining,
		"cards_cleared": cards_cleared,
		"current_score": current_score,
		"total_score": total_score,
		"game_seed": game_seed,
		"current_round_seed": deck_seed
	}

func print_game_state() -> void:
	var info = get_debug_info()
	for key in info:
		debug_log("%s: %s" % [key, info[key]])

func debug_simulate_multiplayer_end():
	set_meta("multiplayer_placement", randi_range(1, 8))
	set_meta("multiplayer_player_count", 8)
	set_meta("multiplayer_mode", "classic")
	set_meta("affects_mmr", true)

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			_delayed_end_round("DEBUG: Forced end")
			get_viewport().set_input_as_handled()
		# Press 1-8 to force placement in test mode
		if game_mode == "multi" and GameModeManager.get_current_mode() == "test":
			if event.keycode >= KEY_1 and event.keycode <= KEY_8:
				var forced_placement = event.keycode - KEY_0
				set_meta("debug_forced_placement", forced_placement)
				debug_log("[DEBUG] Forcing placement: %d" % forced_placement)
