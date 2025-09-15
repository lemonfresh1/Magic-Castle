# GameState.gd - Autoload for game state management
# Path: res://Pyramids/scripts/autoloads/GameState.gd
# Last Updated: Cleaned debug output while maintaining functionality [Date]

extends Node

# === GAME MODE ===
var game_mode: String = "single" # "single", "multi"
var is_multiplayer: bool = false

# === ROUND STATE ===
var current_round: int = 1
var is_round_active: bool = false
var round_time_limit: int = 60
var time_remaining: float = 60.0
var deck_seed: int = 0

# === CARD STATE ===
var cards_cleared: int = 0
var board_cleared: bool = false

# === SCORE STATE ===
var current_score: int = 0
var round_scores: Array[int] = []
var total_score: int = 0
var round_stats: Array[Dictionary] = []  # NEW: Track each round's details

# === MULTIPLAYER ===
var multiplayer_scores: Dictionary = {}  # player_id -> total_score
var multiplayer_round_data: Array = []   # Track each round's results

# === TIMER ===
var game_timer: Timer

func _ready() -> void:
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
func start_new_game(mode: String = "single") -> void:
	# RESET EVERYTHING FIRST
	game_mode = mode
	is_multiplayer = (mode == "multi")
	current_round = 1  # Make sure this is 1, not whatever it was before
	total_score = 0
	round_scores.clear()
	round_stats.clear()  # NEW: Clear round stats
	current_score = 0
	cards_cleared = 0
	board_cleared = false
	
	var game_mode_name = GameModeManager.get_current_mode()
	StatsManager.start_game(game_mode_name)
	XPManager.rewards_enabled = false
	StarManager.rewards_enabled = false  # Add similar flag to StarManager
	
	start_round()

func start_round() -> void:
	# Generate new seed for each round
	deck_seed = randi()
	
	# Get round settings from current game mode
	var round_data = GameModeManager.handle_round_start(current_round)
	
	# Calculate round parameters using GameModeManager
	round_time_limit = round_data.get("time_limit", GameModeManager.get_round_time_limit(current_round))
	time_remaining = float(round_time_limit)
	
	# Set combo timeout if specified (for chill mode)
	if round_data.has("combo_timeout") and ScoreSystem.has_method("set_combo_timeout"):
		ScoreSystem.call("set_combo_timeout", round_data.get("combo_timeout", 5.0))
	
	# Reset round state - LOG EACH RESET
	current_score = 0
	cards_cleared = 0
	board_cleared = false
	is_round_active = true
	
	# Start timer
	set_process(true)
	
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
	
	# NEW: Store detailed round stats
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
	
	var mode = GameModeManager.get_current_mode()
	var reason = get_meta("round_end_reason", "Unknown")
	StatsManager.track_round_end(
		current_round,
		board_cleared,
		scores.round_total,
		time_remaining,
		reason,
		mode
	)
	
	# Track peak clears
	if ScoreSystem.peaks_cleared_indices.size() > 0:
		StatsManager.track_peak_clears(ScoreSystem.peaks_cleared_indices.size(), mode)
	
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
	print("=== GAME OVER ===")
	print("Final score: %d" % total_score)
	
	# Get the current game mode
	var mode = GameModeManager.get_current_mode()
	
	# Check if multiplayer or single player
	if game_mode == "multi":
		# MULTIPLAYER PATH
		print("Multiplayer game ending...")
		
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
				print("[TEST MODE] Simulating 8-player lobby")
				player_count = 8
				# Check for forced debug placement, otherwise random
				if has_meta("debug_forced_placement"):
					placement = get_meta("debug_forced_placement")
					remove_meta("debug_forced_placement")
					print("[TEST MODE] Using forced placement: %d" % placement)
				else:
					placement = randi_range(1, 8)
					print("[TEST MODE] Random placement: %d" % placement)
				affects_mmr = true  # Force MMR changes in test
			else:
				# TODO: Get actual placement when you have all player scores
				placement = randi_range(1, player_count)
		
		# Store metadata for PostGameSummary to read
		set_meta("multiplayer_placement", placement)
		set_meta("multiplayer_player_count", player_count)
		set_meta("multiplayer_mode", mode)
		set_meta("affects_mmr", affects_mmr)
		
		print("Multiplayer result: Placed %d/%d in %s mode (affects MMR: %s)" % 
			[placement, player_count, mode, affects_mmr])
		
		# Track multiplayer game only if it affects MMR
		if affects_mmr:
			var max_combo = 0  # TODO: Get from ScoreSystem
			var clear_time = 0.0  # TODO: Track if needed
			
			StatsManager.track_multiplayer_game(
				mode,
				placement,
				total_score,
				max_combo,
				clear_time,
				player_count
			)
			print("MMR updated for matchmaking game")
		else:
			print("Custom/Tournament game - no MMR change")
		
		# Still track regular game for other stats
		StatsManager.end_game(mode, total_score, current_round - 1)
	else:
		# SINGLE PLAYER PATH
		print("Single player game ending...")
		StatsManager.end_game(mode, total_score, current_round - 1)
	
	# Check achievements for both modes
	print("Checking achievements...")
	AchievementManager.check_achievements()
	
	# Emit game over signal
	SignalBus.game_over.emit(total_score)

# === HELPER FUNCTIONS ===
func _has_valid_moves() -> bool:
	"""Check if there are any valid moves available (delegated to CardManager)"""
	return CardManager.has_valid_moves() if CardManager else false

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

# === MULTIPLAYER HELPERS (Foundation) ===
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

# === SIGNAL HANDLERS ===
func _on_timer_timeout() -> void:
	SignalBus.timer_expired.emit()

func _on_timer_expired() -> void:
	check_round_end()

# === GAME STATE QUERIES ===
func is_game_active() -> bool:
	return is_round_active

func is_final_round() -> bool:
	return current_round >= GameModeManager.get_max_rounds()

func get_rounds_remaining() -> int:
	return max(0, GameModeManager.get_max_rounds() - current_round + 1)

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

# === DEBUGGING ===
func get_debug_info() -> Dictionary:
	return {
		"game_mode": game_mode,
		"current_round": current_round,
		"is_round_active": is_round_active,
		"time_remaining": time_remaining,
		"cards_cleared": cards_cleared,
		"current_score": current_score,
		"total_score": total_score,
		"deck_seed": deck_seed
	}

func print_game_state() -> void:
	var info = get_debug_info()
	for key in info:
		pass  # Debug output removed

func reset_game_completely() -> void:
	# Clean up any persistent UI nodes
	var score_screens = get_tree().get_nodes_in_group("score_screen")
	for screen in score_screens:
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
	
	# Reset CardManager
	if CardManager:
		CardManager.current_combo = 0
		CardManager.cards_drawn = 0
		CardManager.slot_cards = [null, null, null]
		CardManager.active_slots = 1
	
	# Reset ScoreSystem
	if ScoreSystem:
		ScoreSystem.current_multiplier = 1.0
		ScoreSystem.peaks_cleared_indices.clear()
		ScoreSystem.last_selected_card = null
		ScoreSystem.pending_round_end = false
		if ScoreSystem.combo_timer:
			ScoreSystem.combo_timer.stop()

func _return_to_menu() -> void:
	# First reset everything
	reset_game_completely()
	
	# Then return to main menu
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
		
	if event is InputEventKey and event.pressed:
		# Press 1-8 to force placement in test mode
		if game_mode == "multi" and GameModeManager.get_current_mode() == "test":
			if event.keycode >= KEY_1 and event.keycode <= KEY_8:
				var forced_placement = event.keycode - KEY_0
				set_meta("debug_forced_placement", forced_placement)
				print("[DEBUG] Forcing placement: %d" % forced_placement)

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
	
	print("Multiplayer game ended:")
	print("  Mode: %s" % mode)
	print("  Placement: %d/%d" % [placement, player_count])
	print("  Score: %d" % total_score)
	
	# Track the game in stats
	var max_combo = 0  # TODO: Get from ScoreSystem if available
	var clear_time = 0.0  # TODO: Track fastest clear if applicable
	
	StatsManager.track_multiplayer_game(
		mode,
		placement,
		total_score,
		max_combo,
		clear_time,
		player_count
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

func debug_simulate_multiplayer_end():
	set_meta("multiplayer_placement", randi_range(1, 8))
	set_meta("multiplayer_player_count", 8)
	set_meta("multiplayer_mode", "classic")
	set_meta("affects_mmr", true)
