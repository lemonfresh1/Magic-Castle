#ScoreSystem.gd
extends Node

const COMBO_BASE_TIME: float = 15.0

# Scoring state
var combo_timer: Timer
var combo_decay_time: float = 15.0
var combo_decay_increment: float = 0.2
var combo_multiplier: float = 0.05 
var combo_base: float = 1.0
var current_multiplier: float = 1.0

# Track the last selected card for suit bonus
var last_selected_card: CardData = null

# Track peaks cleared
var peaks_cleared: int = 0
var peak_indices: Array[int] = [0, 1, 2]  # Top row cards are peaks

# Round score components (calculated at round end)
var base_score: int = 0
var cards_bonus: int = 0
var time_bonus: int = 0
var clear_bonus: int = 0
var round_total: int = 0

# Score constants
const TIME_BONUS_BASE: int = 10
const TIME_BONUS_PER_ROUND: int = 1
const PEAK_BONUS_1: int = 250
const PEAK_BONUS_2: int = 500
const PEAK_BONUS_3: int = 1000  # This is also full clear
const FIBONACCI_SEQUENCE: Array[int] = [10, 11, 12, 13, 15, 18, 23, 31, 44, 65, 99, 154, 243, 387, 620, 997, 1607, 2594, 4191]

# Pending score calculation to avoid race conditions
var pending_round_end: bool = false

func _ready() -> void:
	print("ScoreSystem initialized")
	
	# Create combo timer
	combo_timer = Timer.new()
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)
	
	# Connect signals
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.combo_updated.connect(_on_combo_updated)
	SignalBus.round_started.connect(_on_round_started)

func calculate_card_score(card: Control) -> int:
	var base_points = GameState.get_base_card_points()
	var total_points = int(base_points * current_multiplier)
	
	# Check for suit bonus - compare with last selected card
	if last_selected_card and card.card_data.suit == last_selected_card.suit:
		total_points += 25
		print("Suit bonus! +25")
	
	# Update last selected card
	last_selected_card = card.card_data
	
	# Check if this was a peak card - IMPROVED timing
	if card.board_index in peak_indices:
		peaks_cleared += 1
		print("Peak cleared! Total peaks: %d" % peaks_cleared)
		
		# If all peaks cleared, mark for board completion
		if peaks_cleared == 3:
			print("ALL PEAKS CLEARED! Board complete!")
			
			# Set board cleared flag immediately
			GameState.board_cleared = true
			
			# Delay the round end check to allow scoring to complete
			if not pending_round_end:
				pending_round_end = true
				_delayed_round_end_check()
	
	return total_points

func _delayed_round_end_check() -> void:
	# Wait a few frames for all scoring to complete
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Only end if we're not already ending
	if pending_round_end and GameState.is_round_active:
		pending_round_end = false
		GameState.check_round_end()

func calculate_round_scores(board_cleared: bool) -> Dictionary:
	# Base score is already in GameState.current_score
	base_score = GameState.current_score
	
	# Calculate each bonus
	cards_bonus = _calculate_cards_bonus(board_cleared)
	time_bonus = _calculate_time_bonus(board_cleared)
	clear_bonus = _calculate_clear_bonus()
	
	# Round total (NOT including base_score again!)
	round_total = base_score + cards_bonus + time_bonus + clear_bonus
	
	print("=== ROUND SCORE BREAKDOWN ===")
	print("Base Score: %d" % base_score)
	print("Cards Bonus: %d" % cards_bonus)
	print("Time Bonus: %d" % time_bonus)
	print("Clear Bonus: %d" % clear_bonus)
	print("Round Total: %d" % round_total)
	print("==============================")
	
	return {
		"base": base_score,
		"cards": cards_bonus,
		"time": time_bonus,
		"clear": clear_bonus,
		"round_total": round_total
	}

func _calculate_cards_bonus(board_cleared: bool) -> int:
	if not board_cleared:
		return 0
	
	# Bonus for remaining draw pile cards - SUM all fibonacci values
	var remaining_draws = GameState.get_draw_pile_limit() - CardManager.cards_drawn
	if remaining_draws > 0:
		var fib_sum = 0
		# Sum up all fibonacci values up to remaining_draws
		for i in range(min(remaining_draws, FIBONACCI_SEQUENCE.size())):
			fib_sum += FIBONACCI_SEQUENCE[i]
		
		var round_multiplier = pow(1.05, GameState.current_round - 1)  # -1 because round 1 = no multiplier
		var bonus = int(fib_sum * round_multiplier)
		print("Cards bonus: Sum of first %d fib = %d × %.2f = %d" % [remaining_draws, fib_sum, round_multiplier, bonus])
		return bonus
	return 0

func _calculate_time_bonus(board_cleared: bool) -> int:
	if not board_cleared:
		return 0
	
	# Bonus for remaining time
	var time_left = int(GameState.time_remaining)
	if time_left > 0:
		var bonus_per_second = TIME_BONUS_BASE + (TIME_BONUS_PER_ROUND * GameState.current_round)
		var bonus = time_left * bonus_per_second
		print("Time bonus: %d seconds × %d = %d" % [time_left, bonus_per_second, bonus])
		return bonus
	return 0

func _calculate_clear_bonus() -> int:
	# Peak clearing bonus
	match peaks_cleared:
		1: return PEAK_BONUS_1
		2: return PEAK_BONUS_2
		3: return PEAK_BONUS_3  # This IS the full board clear
		_: return 0

func update_combo_multiplier(combo: int) -> void:
	# Base 1.1x, +0.05 per card
	current_multiplier = combo_base + (combo_multiplier * (combo - 1))
	SignalBus.combo_multiplier_changed.emit(current_multiplier)
	
	# Update combo timer
	combo_decay_time = max(1.0, COMBO_BASE_TIME - (combo_decay_increment * combo))
	combo_timer.start(combo_decay_time)
	
	print("Multiplier: %.2fx, Timer: %.1fs" % [current_multiplier, combo_decay_time])

# Signal handlers
func _on_card_selected(card: Control) -> void:
	# MOVE PEAK DETECTION HERE - BEFORE any other scoring
	if card.board_index in peak_indices:
		peaks_cleared += 1
		print("Peak cleared! Total peaks: %d" % peaks_cleared)
		
		# Play peak clear sound
		if peaks_cleared <= 2:
			AudioSystem.play_peak_clear_sound(peaks_cleared)
		
		# If all peaks cleared, set flag immediately
		if peaks_cleared == 3:
			print("ALL PEAKS CLEARED! Board complete!")
			GameState.board_cleared = true
	
	# THEN do normal scoring
	var points = calculate_card_score(card)
	GameState.current_score += points
	SignalBus.score_changed.emit(points, "card")

func _on_score_changed(points: int, reason: String) -> void:
	print("Score changed: %+d (%s) - Total: %d" % [points, reason, GameState.current_score])

func _on_combo_updated(combo: int) -> void:
	if combo > 0:
		update_combo_multiplier(combo)
	else:
		current_multiplier = 1.0
		combo_timer.stop()
		last_selected_card = null

func _on_combo_timeout() -> void:
	print("Combo timeout!")
	CardManager.current_combo = 0
	current_multiplier = 1.0
	SignalBus.combo_updated.emit(0)

func _on_round_started(round_number: int) -> void:
	current_multiplier = 1.0
	combo_timer.stop()
	last_selected_card = null
	peaks_cleared = 0
	base_score = 0
	cards_bonus = 0
	time_bonus = 0
	clear_bonus = 0
	round_total = 0
	pending_round_end = false
