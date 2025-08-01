# TriPeaksMode.gd - Standard tri-peaks game mode
# Path: res://Magic-Castle/scripts/game/TriPeaksMode.gd
class_name TriPeaksMode
extends GameModeBase

func _init():
	mode_name = "tri_peaks"
	display_name = "Tri-Peaks"
	description = "Classic tri-peaks solitaire with combo multipliers"
	
	# Standard tri-peaks configuration
	board_card_count = 28
	pyramid_layout = [3, 6, 9, 10]
	starting_slots = 1
	max_slots = 3
	
	max_rounds = 10
	starting_time = 60
	time_decrease_per_round = 3
	draw_pile_limits = [21, 20, 20, 19, 19, 18, 17, 16, 16, 15]
	
	base_points_start = 100
	base_points_per_round = 10
	combo_unlock_thresholds = [2, 6]

func get_round_visibility_mode(round_number: int) -> String:
	# Even rounds: all visible, Odd rounds: progressive reveal
	return "all_visible" if round_number % 2 == 0 else "progressive"

func calculate_board_layout() -> Array[Vector2]:
	# Standard tri-peaks pyramid positions
	# This would be called by the board to get card positions
	var positions: Array[Vector2] = []
	
	# The actual positioning logic would go here
	# For now, return empty array (board handles its own positioning)
	return positions

func is_valid_card_selection(card_data: CardData, slot_cards: Array[CardData]) -> bool:
	# Standard tri-peaks rules: ±1 value from any active slot
	for slot_card in slot_cards:
		if slot_card and card_data.is_valid_next_card(slot_card):
			return true
	return false

func get_win_condition() -> String:
	return "clear_all_peaks"

func should_unlock_slot(current_combo: int, slot_number: int) -> bool:
	# Slot 2 unlocks at combo 2, Slot 3 unlocks at combo 6
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
	
	# Check for suit bonus
	effects["suit_bonus"] = false  # Would check against previous card
	
	# Check for peak clearing  
	effects["peak_cleared"] = false  # Would check card position
	
	return effects

func on_round_end(round_number: int, board_cleared: bool) -> Dictionary:
	var bonuses = {}
	
	if board_cleared:
		bonuses["time_bonus"] = true
		bonuses["cards_bonus"] = true
		bonuses["full_clear_bonus"] = 1000
	
	return bonuses
