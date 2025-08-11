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
	
	var game_mode_name = GameModeManager.get_current_mode().mode_name
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
	
	var mode = GameModeManager.get_current_mode().mode_name
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
	# CRITICAL: Calculate final total score from all rounds
	total_score = 0
	for score in round_scores:
		total_score += score
	
	# Track game end
	var mode = GameModeManager.get_current_mode().mode_name
	StatsManager.end_game(mode, total_score, current_round - 1)
	AchievementManager.check_achievements()
	
	# CRITICAL: Emit game_over signal with correct total
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
	# TODO: Remove before release - Press E to instantly end round
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			_delayed_end_round("DEBUG: Forced end")
			get_viewport().set_input_as_handled()
