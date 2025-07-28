# TestMode.gd - Quick 2-round mode for testing
# Path: res://Magic-Castle/scripts/game_modes/TestMode.gd
class_name TestMode
extends GameModeBase

func _init():
	mode_name = "test"
	display_name = "Test Mode"
	description = "2 rounds for quick testing"
	
	# Same as tri-peaks but only 2 rounds
	board_card_count = 28
	pyramid_layout = [3, 6, 9, 10]
	starting_slots = 1
	max_slots = 3
	
	# ONLY 2 ROUNDS for quick testing
	max_rounds = 2
	
	# Standard timing
	starting_time = 60
	time_decrease_per_round = 3
	
	# Only need 2 draw limits
	draw_pile_limits = [21, 20]  # Rounds 1 and 2
	
	# Standard scoring
	base_points_start = 100
	base_points_per_round = 10
	combo_unlock_thresholds = [2, 6]

func get_round_visibility_mode(round_number: int) -> String:
	# Even rounds: all visible, Odd rounds: progressive reveal
	return "all_visible" if round_number % 2 == 0 else "progressive"

func calculate_board_layout() -> Array[Vector2]:
	# Same layout as tri-peaks
	return []

func is_valid_card_selection(card_data: CardData, slot_cards: Array[CardData]) -> bool:
	# Standard tri-peaks rules
	for slot_card in slot_cards:
		if slot_card and card_data.is_valid_next_card(slot_card):
			return true
	return false

func get_win_condition() -> String:
	return "clear_all_peaks"

func should_unlock_slot(current_combo: int, slot_number: int) -> bool:
	# Same as tri-peaks
	match slot_number:
		2: return current_combo >= 2
		3: return current_combo >= 6
		_: return false

func on_round_start(round_number: int) -> Dictionary:
	return {
		"visibility_mode": get_round_visibility_mode(round_number),
		"time_limit": starting_time - (time_decrease_per_round * (round_number - 1)),
		"draw_limit": get_draw_pile_limit(round_number)
	}

func on_card_played(card_data: CardData, combo_count: int) -> Dictionary:
	var effects = {}
	effects["suit_bonus"] = false
	effects["peak_cleared"] = false
	return effects

func on_round_end(round_number: int, board_cleared: bool) -> Dictionary:
	var bonuses = {}
	
	if board_cleared:
		bonuses["time_bonus"] = true
		bonuses["cards_bonus"] = true
		bonuses["full_clear_bonus"] = 1000
		bonuses["test_complete"] = round_number == 2  # Quick completion flag
	
	return bonuses
