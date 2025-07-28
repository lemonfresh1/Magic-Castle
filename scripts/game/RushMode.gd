# RushMode.gd - Fast-paced 5-round mode
class_name RushMode
extends GameModeBase

func _init():
	mode_name = "rush"
	display_name = "Rush"
	description = "Quick 5-round challenge with aggressive timing"
	
	# Rush configuration - same board as tri-peaks
	board_card_count = 28
	pyramid_layout = [3, 6, 9, 10]
	starting_slots = 1
	max_slots = 3
	
	# Only 5 rounds
	max_rounds = 5
	
	# Use aggressive times from standard rounds 6-10
	starting_time = 50  # Round 6 time
	time_decrease_per_round = 0  # We'll use fixed array
	
	# Draw limits from rounds 6-10 of standard mode
	draw_pile_limits = [18, 17, 16, 16, 15]  # Only 5 values!
	
	# Higher base points for rush mode
	base_points_start = 150  # 1.5x multiplier built into base
	base_points_per_round = 15  # 1.5x of standard
	combo_unlock_thresholds = [2, 6]  # Same as standard

func get_round_visibility_mode(round_number: int) -> String:
	# Rush mode: always progressive for added challenge
	return "progressive"

func calculate_board_layout() -> Array[Vector2]:
	# Same layout as tri-peaks
	return []

func is_valid_card_selection(card_data: CardData, slot_cards: Array[CardData]) -> bool:
	# Same rules as tri-peaks
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
	# Simple array for round times (no mapping needed)
	var round_times = [50, 50, 40, 40, 30]
	var time_limit = round_times[clampi(round_number - 1, 0, 4)]
	
	return {
		"visibility_mode": get_round_visibility_mode(round_number),
		"time_limit": time_limit,
		"draw_limit": get_draw_pile_limit(round_number),
		"score_multiplier": 1.5  # For UI display
	}

func on_card_played(card_data: CardData, combo_count: int) -> Dictionary:
	var effects = {}
	effects["suit_bonus"] = false
	effects["peak_cleared"] = false
	effects["rush_bonus"] = true  # Special indicator for rush mode
	return effects

func on_round_end(round_number: int, board_cleared: bool) -> Dictionary:
	var bonuses = {}
	
	if board_cleared:
		bonuses["time_bonus"] = true
		bonuses["cards_bonus"] = true
		bonuses["full_clear_bonus"] = 1500  # Higher bonus for rush
		bonuses["rush_completion"] = round_number == 5  # Completed all 5 rounds
	
	return bonuses
