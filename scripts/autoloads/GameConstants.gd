# GameConstants.gd - Autoload for game configuration
# Path: res://Pyramids/scripts/autoloads/GameConstants.gd
extends Node

# === GAME RULES ===
const MAX_ROUNDS: int = 10
const STARTING_TIME: int = 60
const TIME_DECREASE_PER_ROUND: int = 3

# === CARD LAYOUT ===
const TOTAL_CARDS: int = 52
const BOARD_CARDS: int = 28
const PYRAMID_ROWS: int = 4
const BOTTOM_ROW_CARDS: int = 10
const BOTTOM_ROW_START_INDEX: int = 18
const PEAK_INDICES: Array[int] = [0, 1, 2]

# === PYRAMID LAYOUT ===
const ROW_CARD_COUNTS: Array[int] = [3, 6, 9, 10]  # Cards per row from top
const ROW_START_INDICES: Array[int] = [0, 3, 9, 18]  # Starting index for each row

# === SCORING ===
const BASE_POINTS_PER_ROUND: int = 10
const BASE_POINTS_START: int = 100
const INVALID_CLICK_PENALTY: int = -30
const SUIT_BONUS: int = 25
const PEAK_BONUSES: Array[int] = [250, 500, 1000]
const TIME_BONUS_BASE: int = 10
const TIME_BONUS_PER_ROUND: int = 1

# === COMBO SYSTEM ===
const COMBO_BASE_MULTIPLIER: float = 1.0
const COMBO_INCREMENT: float = 0.05
const SLOT_2_UNLOCK_COMBO: int = 2
const SLOT_3_UNLOCK_COMBO: int = 6
const COMBO_DECAY_BASE: float = 15.0
const COMBO_DECAY_INCREMENT: float = 0.2

# === VISUAL CONSTANTS ===
const CARD_WIDTH: int = 90
const CARD_HEIGHT: int = 126
const OVERLAP_Y: int = 40
const INVALID_FLASH_COLOR: Color = Color(1.5, 0.8, 0.8)

# === MOBILE CONSTANTS (NEW) ===
const MOBILE_CARD_WIDTH: int = 50
const MOBILE_CARD_HEIGHT: int = 70
const MOBILE_OVERLAP_Y: int = 25
const DRAW_ZONE_WIDTH: int = 80
const MIN_CARD_SPACING: int = 3
const TOPBAR_HEIGHT: int = 120

# === Z-INDEX LAYERS ===
const Z_CARDS_BASE: int = 1
const Z_CARDS_MAX: int = 4
const Z_UI_ELEMENTS: int = 20
const Z_CARD_SLOTS: int = 25
const Z_SCORE_SCREEN: int = 1000

# === FIBONACCI SEQUENCE FOR BONUSES ===
const FIBONACCI_SEQUENCE: Array[int] = [
	10, 11, 12, 13, 15, 18, 23, 31, 44, 65, 99, 154, 243, 387, 620, 997, 1607, 2594, 4191
]

# === DRAW PILE LIMITS BY ROUND ===
const DRAW_PILE_LIMITS: Array[int] = [21, 20, 20, 19, 19, 18, 17, 16, 16, 15]

# === MOBILE TARGET DIMENSIONS ===
const TARGET_SCREEN_WIDTH: int = 2400   # Landscape width (was 1080)
const TARGET_SCREEN_HEIGHT: int = 1080  # Landscape height (was 2400)

func _ready() -> void:
	print("GameConstants initialized")
	print("Game configured for %d rounds, %d board cards" % [MAX_ROUNDS, BOARD_CARDS])

# === HELPER FUNCTIONS ===
func get_base_card_points(round: int) -> int:
	return BASE_POINTS_START + (BASE_POINTS_PER_ROUND * (round - 1))

func get_draw_pile_limit(round: int) -> int:
	if round < 1 or round > DRAW_PILE_LIMITS.size():
		return DRAW_PILE_LIMITS[-1]  # Default to last value
	return DRAW_PILE_LIMITS[round - 1]

func get_round_time_limit(round: int) -> int:
	# Check if GameModeManager exists and has a current mode
	if Engine.has_singleton("GameModeManager"):
		var gmm = Engine.get_singleton("GameModeManager")
		if gmm and gmm.has_method("get_round_time_limit"):
			return gmm.get_round_time_limit(round)
	
	# Fallback to original calculation
	return STARTING_TIME - (TIME_DECREASE_PER_ROUND * (round - 1))

func is_peak_card(index: int) -> bool:
	return index in PEAK_INDICES

func is_bottom_row_card(index: int) -> bool:
	return index >= BOTTOM_ROW_START_INDEX

func get_card_row(index: int) -> int:
	# Returns which row (0-3) the card is in
	for i in range(ROW_START_INDICES.size()):
		if index < ROW_START_INDICES[i]:
			return i - 1
	return ROW_START_INDICES.size() - 1

func get_row_start_index(row: int) -> int:
	if row < 0 or row >= ROW_START_INDICES.size():
		return -1
	return ROW_START_INDICES[row]

func get_row_card_count(row: int) -> int:
	if row < 0 or row >= ROW_CARD_COUNTS.size():
		return 0
	return ROW_CARD_COUNTS[row]

# === SCORING HELPERS ===
func calculate_combo_multiplier(combo_count: int) -> float:
	if combo_count <= 0:
		return 1.0
	return COMBO_BASE_MULTIPLIER + (COMBO_INCREMENT * (combo_count - 1))

func calculate_combo_timer(combo_count: int) -> float:
	return max(1.0, COMBO_DECAY_BASE - (COMBO_DECAY_INCREMENT * combo_count))

func get_peak_bonus(peaks_cleared: int) -> int:
	if peaks_cleared < 1 or peaks_cleared > PEAK_BONUSES.size():
		return 0
	return PEAK_BONUSES[peaks_cleared - 1]

# === MOBILE HELPERS ===
func calculate_mobile_scale(screen_size: Vector2) -> float:
	var scale_x = screen_size.x / TARGET_SCREEN_WIDTH
	var scale_y = screen_size.y / TARGET_SCREEN_HEIGHT
	return min(scale_x, scale_y)

func get_mobile_card_size(scale_factor: float) -> Vector2:
	return Vector2(MOBILE_CARD_WIDTH * scale_factor, MOBILE_CARD_HEIGHT * scale_factor)

# === VALIDATION HELPERS ===
static func is_valid_round(round: int, max_rounds: int = 10) -> bool:
	return round >= 1 and round <= max_rounds

func is_valid_card_index(index: int) -> bool:
	return index >= 0 and index < BOARD_CARDS

func is_valid_combo_count(combo: int) -> bool:
	return combo >= 0 and combo <= BOARD_CARDS

static func get_max_rounds() -> int:
	if Engine.has_singleton("GameModeManager"):
		var gmm = Engine.get_singleton("GameModeManager")
		if gmm and gmm.has_method("get_max_rounds"):
			return gmm.get_max_rounds()
	return 10  # Fallback
