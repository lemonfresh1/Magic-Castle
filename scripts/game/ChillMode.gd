# ChillMode.gd - Relaxed mode with no time pressure
# Path: res://Pyramids/scripts/game_modes/ChillMode.gd
class_name ChillMode
extends GameModeBase

func _init():
	mode_name = "chill"
	display_name = "Chill"
	description = "Relax with no time limits and extended combos"
	
	# Chill configuration - same board as tri-peaks
	board_card_count = 28
	pyramid_layout = [3, 6, 9, 10]
	starting_slots = 1
	max_slots = 3
	
	max_rounds = 10
	starting_time = 0  # No timer
	time_decrease_per_round = 0
	
	# Same draw limits as standard
	draw_pile_limits = [21, 20, 20, 19, 19, 18, 17, 16, 16, 15]
	
	# Standard scoring (no multiplier reduction)
	base_points_start = 100
	base_points_per_round = 10
	combo_unlock_thresholds = [2, 6]

func get_round_visibility_mode(round_number: int) -> String:
	# Chill mode: always all visible for relaxed play
	return "all_visible"

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
	return {
		"visibility_mode": get_round_visibility_mode(round_number),
		"time_limit": 0,  # No timer
		"draw_limit": get_draw_pile_limit(round_number),
		"combo_timeout": 720.0,  # 12 minutes - effectively infinite
		"chill_mode": true  # Flag for UI adaptations
	}

func on_card_played(card_data: CardData, combo_count: int) -> Dictionary:
	var effects = {}
	effects["suit_bonus"] = false
	effects["peak_cleared"] = false
	effects["zen_points"] = combo_count * 10  # Bonus points for long combos
	return effects

func on_round_end(round_number: int, board_cleared: bool) -> Dictionary:
	var bonuses = {}
	
	if board_cleared:
		# No time bonus in chill mode
		bonuses["time_bonus"] = false
		bonuses["cards_bonus"] = true
		bonuses["full_clear_bonus"] = 1000
		bonuses["zen_master"] = true  # Special chill mode achievement trigger
	
	return bonuses
