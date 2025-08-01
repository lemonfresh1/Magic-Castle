# GameModeBase.gd - Base class for game modes
# Path: res://Magic-Castle/scripts/game/GameModeBase.gd
class_name GameModeBase
extends Resource

# === GAME MODE PROPERTIES ===
@export var mode_name: String = "base_mode"
@export var display_name: String = "Base Mode"
@export var description: String = "Base game mode template"

# === LAYOUT CONFIGURATION ===
@export var board_card_count: int = 28
@export var pyramid_layout: Array[int] = [3, 6, 9, 10]  # Cards per row from top
@export var starting_slots: int = 1
@export var max_slots: int = 3

# === GAME RULES ===
@export var max_rounds: int = 10
@export var starting_time: int = 60
@export var time_decrease_per_round: int = 3
@export var draw_pile_limits: Array[int] = [21, 20, 20, 19, 19, 18, 17, 16, 16, 15]

# === SCORING RULES ===
@export var base_points_start: int = 100
@export var base_points_per_round: int = 10
@export var combo_unlock_thresholds: Array[int] = [2, 6]  # When to unlock slots 2 and 3

# === VIRTUAL METHODS (Override in subclasses) ===
func get_round_visibility_mode(round_number: int) -> String:
	# Returns "all_visible" or "progressive"
	return "all_visible" if round_number % 2 == 0 else "progressive"

func calculate_board_layout() -> Array[Vector2]:
	# Override to provide different board layouts
	return []

func is_valid_card_selection(card_data: CardData, slot_cards: Array[CardData]) -> bool:
	# Default tri-peaks rules
	for slot_card in slot_cards:
		if slot_card and card_data.is_valid_next_card(slot_card):
			return true
	return false

func get_win_condition() -> String:
	return "clear_all_peaks"  # or "clear_all_cards", "reach_score", etc.

func should_unlock_slot(current_combo: int, slot_number: int) -> bool:
	if slot_number < 2 or slot_number > combo_unlock_thresholds.size() + 1:
		return false
	return current_combo >= combo_unlock_thresholds[slot_number - 2]

# === SCORING METHODS ===
func get_base_card_points(round: int) -> int:
	return base_points_start + (base_points_per_round * (round - 1))

func get_draw_pile_limit(round: int) -> int:
	if round < 1 or round > draw_pile_limits.size():
		return draw_pile_limits[-1]
	return draw_pile_limits[round - 1]

# === SPECIAL RULES ===
func on_round_start(round_number: int) -> Dictionary:
	# Return any special setup data for this round
	return {}

func on_card_played(card_data: CardData, combo_count: int) -> Dictionary:
	# Return any special effects from playing this card
	return {}

func on_round_end(round_number: int, board_cleared: bool) -> Dictionary:
	# Return any special bonuses or effects
	return {}
