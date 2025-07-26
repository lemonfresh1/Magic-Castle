# GameState.gd - Autoload for game state management
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

# === TIMER ===
var game_timer: Timer

func _ready() -> void:
	print("GameState initializing...")
	_setup_timer()
	_connect_signals()
	set_process(false)  # Don't process until round starts
	print("GameState initialized")

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
	print("Starting new game - Mode: %s" % mode)
	
	game_mode = mode
	is_multiplayer = (mode == "multi")
	current_round = 1
	total_score = 0
	round_scores.clear()
	
	start_round()

func start_round() -> void:
	print("=== STARTING ROUND %d ===" % current_round)
	
	# Generate new seed for each round
	deck_seed = randi()
	
	# Calculate round parameters using GameModeManager
	round_time_limit = GameModeManager.get_round_time_limit(current_round)
	time_remaining = float(round_time_limit)
	
	# Reset round state - LOG EACH RESET
	print("Resetting round state...")
	current_score = 0
	print("  - current_score reset to 0")
	cards_cleared = 0
	print("  - cards_cleared reset to 0")
	board_cleared = false
	print("  - board_cleared reset to false")
	is_round_active = true
	print("  - is_round_active set to true")
	
	# Start timer
	set_process(true)
	
	print("Round %d started - Seed: %d, Time: %ds" % [current_round, deck_seed, round_time_limit])
	print("About to emit round_started signal...")
	SignalBus.round_started.emit(current_round)
	print("Signal emitted")

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
		print("Round ending: %s" % reason)
		_delayed_end_round(reason)

func _delayed_end_round(reason: String) -> void:
	"""End round with a small delay to ensure all systems sync"""
	# Wait 0.2 seconds for all systems to process
	await get_tree().create_timer(0.2).timeout
	
	# Double-check we should still end
	if not is_round_active:
		return
		
	print("Ending round after delay: %s" % reason)
	end_round()

func end_round() -> void:
	"""Actually end the current round"""
	is_round_active = false
	set_process(false)  # Stop timer processing
	
	# Calculate scores through ScoreSystem
	var scores = ScoreSystem.calculate_round_scores(board_cleared)
	
	# Store round score
	round_scores.append(scores.round_total)
	
	print("Round %d completed - Score: %d" % [current_round, scores.round_total])
	SignalBus.round_completed.emit(scores.round_total)
	
	# Show score screen
	_show_score_screen(scores)

func _show_score_screen(scores: Dictionary) -> void:
	"""Display the score screen"""
	var score_screen = get_tree().get_first_node_in_group("score_screen")
	if not score_screen:
		var score_scene = load("res://Magic-Castle/scenes/ui/ScoreScreen.tscn")
		if score_scene:
			score_screen = score_scene.instantiate()
			score_screen.add_to_group("score_screen")
			get_tree().root.add_child(score_screen)
		else:
			print("Warning: ScoreScreen.tscn not found")
			_continue_to_next_round()
			return
	
	score_screen.show_round_complete(current_round, scores)

func _continue_to_next_round() -> void:
	"""Continue to next round or end game"""
	# Update total score
	if round_scores.size() > 0:
		total_score += round_scores[-1]
	
	current_round += 1
	
	# Check if game is complete
	if current_round > GameConstants.MAX_ROUNDS:
		_end_game()
	else:
		start_round()

func _end_game() -> void:
	print("Game completed! Final score: %d" % total_score)
	SignalBus.game_over.emit(total_score)
	
	var score_screen = get_tree().get_first_node_in_group("score_screen")
	if score_screen:
		score_screen.show_game_complete(total_score)
	else:
		get_tree().change_scene_to_file("res://Magic-Castle/scenes/menus/MainMenu.tscn")

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
	return float(current_round - 1) / float(GameConstants.MAX_ROUNDS)

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
	print("Timer expired!")
	check_round_end()

# === GAME STATE QUERIES ===
func is_game_active() -> bool:
	return is_round_active

func is_final_round() -> bool:
	return current_round >= GameConstants.MAX_ROUNDS

func get_rounds_remaining() -> int:
	return max(0, GameConstants.MAX_ROUNDS - current_round + 1)

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
	print("=== GAME STATE ===")
	for key in info:
		print("%s: %s" % [key, str(info[key])])
	print("===================")
