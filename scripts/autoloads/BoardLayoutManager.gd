
# BoardLayoutManager.gd - Autoload for managing card positions and board layouts
# Path: res://Pyramids/scripts/autoloads/BoardLayoutManager.gd
# Last Updated: Initial creation - handles all card positioning logic
#
# BoardLayoutManager handles:
# - Card position calculations for any screen size
# - Scale factor determination for mobile/desktop
# - Draw zone space accounting in layout
# - Collision layer/mask assignment by card position
# - Z-index management for proper card layering
# - Support for alternative pyramid layouts (future)
#
# Flow: Screen size → BoardLayoutManager → Position calculations → MobileGameBoard
# Dependencies: SettingsSystem (draw zones), UIStyleManager (dimensions)

extends Node

# === LAYOUT CONSTANTS ===
# Desktop layout
const DESKTOP_CARD_WIDTH: int = 70
const DESKTOP_CARD_HEIGHT: int = 98
const DESKTOP_OVERLAP_Y: int = 35
const DESKTOP_CARD_SPACING: int = 5

# Mobile layout
const MOBILE_CARD_WIDTH: int = 80
const MOBILE_CARD_HEIGHT: int = 110
const MOBILE_OVERLAP_Y_RATIO: float = 0.6  # 60% overlap
const MOBILE_MIN_SPACING: int = 20

# Draw zones
const DRAW_ZONE_BASE_WIDTH: int = 80
const MIN_CARD_SPACING: int = 3

# === CACHED VALUES ===
var cached_positions: Array[Vector2] = []
var cached_scale_factor: float = 1.0
var cached_container_size: Vector2 = Vector2.ZERO
var cached_draw_zone_config: Dictionary = {}

# === PYRAMID STRUCTURE ===
# Standard tri-peaks indices mapping
const PYRAMID_ROWS = [
	[0, 1, 2],           # Top row (3 peaks)
	[3, 4, 5, 6, 7, 8],  # Row 2 (6 cards)
	[9, 10, 11, 12, 13, 14, 15, 16, 17],  # Row 3 (9 cards)
	[18, 19, 20, 21, 22, 23, 24, 25, 26, 27]  # Bottom row (10 cards)
]

# Alternative layouts for future game modes
const PYRAMID_LAYOUTS = {
	"tri_peaks": [3, 6, 9, 10],
	"single_peak": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	"double_peaks": [2, 4, 6, 8, 10],
	"inverted": [10, 9, 6, 3]
}

func _ready() -> void:
	print("BoardLayoutManager initialized")

# === PUBLIC API ===

func calculate_card_positions(container_size: Vector2, is_mobile: bool = true) -> Array[Vector2]:
	"""Calculate positions for all 28 cards based on container size"""
	cached_container_size = container_size
	
	if is_mobile:
		cached_positions = _calculate_mobile_positions(container_size)
	else:
		cached_positions = _calculate_desktop_positions(container_size)
	
	return cached_positions

func get_card_scale_factor(container_size: Vector2, is_mobile: bool = true) -> float:
	"""Calculate the scale factor for cards to fit the container"""
	if is_mobile:
		cached_scale_factor = _calculate_mobile_scale(container_size)
	else:
		cached_scale_factor = _calculate_desktop_scale(container_size)
	
	return cached_scale_factor

func get_adjusted_container_size(full_size: Vector2, draw_zone_mode: String) -> Vector2:
	"""Get container size after accounting for draw zones"""
	var adjusted_size = full_size
	var zone_width = _get_draw_zone_width()
	
	match draw_zone_mode:
		"left", "right":
			adjusted_size.x -= zone_width
		"both":
			adjusted_size.x -= zone_width * 2
	
	return adjusted_size

func get_card_position_at_index(index: int) -> Vector2:
	"""Get the position of a specific card by index"""
	if index < 0 or index >= cached_positions.size():
		push_error("Invalid card index: %d" % index)
		return Vector2.ZERO
	
	return cached_positions[index]

func get_card_row(index: int) -> int:
	"""Get which row a card belongs to (0-3)"""
	if index < 3:
		return 0
	elif index < 9:
		return 1
	elif index < 18:
		return 2
	elif index < 28:
		return 3
	else:
		return -1

func get_cards_in_row(row: int) -> Array[int]:
	"""Get all card indices in a specific row"""
	if row < 0 or row >= PYRAMID_ROWS.size():
		return []
	
	var indices: Array[int] = []
	for idx in PYRAMID_ROWS[row]:
		indices.append(idx)
	return indices

func get_card_size(is_mobile: bool = true) -> Vector2:
	"""Get the base card size for the current platform"""
	if is_mobile:
		return Vector2(MOBILE_CARD_WIDTH, MOBILE_CARD_HEIGHT)
	else:
		return Vector2(DESKTOP_CARD_WIDTH, DESKTOP_CARD_HEIGHT)

func get_pyramid_layout_name() -> String:
	"""Get the current pyramid layout name from game mode"""
	var mode = GameModeManager.get_current_mode()
	if mode:
		return mode.mode_name
	return "tri_peaks"

# === MOBILE LAYOUT CALCULATIONS ===

func _calculate_mobile_positions(container_size: Vector2) -> Array[Vector2]:
	"""Calculate card positions for mobile layout"""
	var positions: Array[Vector2] = []
	
	# Fixed card size for better touch targets
	var card_width = MOBILE_CARD_WIDTH
	var card_height = MOBILE_CARD_HEIGHT
	var card_spacing = MOBILE_MIN_SPACING
	var row_overlap = card_height * MOBILE_OVERLAP_Y_RATIO
	
	# Account for draw zones
	var available_width = _get_available_width(container_size)
	
	# Calculate total pyramid width
	var total_width = card_width * 10 + card_spacing * 9
	
	# Center horizontally
	var start_x = (available_width - total_width) / 2
	start_x += _get_left_offset()  # Account for left draw zone if present
	
	# Calculate vertical positioning
	var pyramid_height = card_height + (row_overlap * 3)
	var start_y = (container_size.y - pyramid_height) / 2
	var base_y = start_y + pyramid_height - card_height
	
	# Initialize with zeros
	for i in range(28):
		positions.append(Vector2.ZERO)
	
	# Bottom row (10 cards) - indices 18-27
	for i in range(10):
		var x = start_x + i * (card_width + card_spacing)
		positions[18 + i] = Vector2(x, base_y)
	
	# Row 3 (9 cards) - indices 9-17
	var row3_start_x = start_x + (card_width + card_spacing) / 2
	for i in range(9):
		var x = row3_start_x + i * (card_width + card_spacing)
		positions[9 + i] = Vector2(x, base_y - row_overlap)
	
	# Row 2 (6 cards) - indices 3-8
	# Special positioning for tri-peaks layout
	var row2_start_x = row3_start_x + (card_width + card_spacing) / 2
	var row2_positions = [0, 1, 3, 4, 6, 7]  # Skip positions 2 and 5 for gaps
	for i in range(6):
		var x = row2_start_x + row2_positions[i] * (card_width + card_spacing)
		positions[3 + i] = Vector2(x, base_y - row_overlap * 2)
	
	# Top row (3 peaks) - indices 0-2
	var row1_start_x = row2_start_x + (card_width + card_spacing) / 2
	var peak_positions = [0, 3, 6]  # Positions for the three peaks
	for i in range(3):
		var x = row1_start_x + peak_positions[i] * (card_width + card_spacing)
		positions[i] = Vector2(x, base_y - row_overlap * 3)
	
	return positions

func _calculate_desktop_positions(container_size: Vector2) -> Array[Vector2]:
	"""Calculate card positions for desktop layout"""
	var positions: Array[Vector2] = []
	
	# Desktop uses smaller cards but similar layout logic
	var card_width = DESKTOP_CARD_WIDTH
	var card_height = DESKTOP_CARD_HEIGHT
	var card_spacing = DESKTOP_CARD_SPACING
	var row_overlap = DESKTOP_OVERLAP_Y
	
	# Account for draw zones
	var available_width = _get_available_width(container_size)
	
	# Calculate total pyramid width
	var total_width = card_width * 10 + card_spacing * 9
	
	# Center the pyramid
	var start_x = (available_width - total_width) / 2
	start_x += _get_left_offset()
	
	# Vertical positioning
	var pyramid_height = card_height + (row_overlap * 3)
	var start_y = (container_size.y - pyramid_height) / 2
	var base_y = start_y + pyramid_height - card_height
	
	# Initialize positions array
	for i in range(28):
		positions.append(Vector2.ZERO)
	
	# Position cards row by row (same logic as mobile but with desktop dimensions)
	# Bottom row (10 cards)
	for i in range(10):
		positions[18 + i] = Vector2(start_x + i * (card_width + card_spacing), base_y)
	
	# Row 3 (9 cards)
	var row3_start = start_x + (card_width + card_spacing) / 2
	for i in range(9):
		positions[9 + i] = Vector2(row3_start + i * (card_width + card_spacing), base_y - row_overlap)
	
	# Row 2 (6 cards with gaps)
	var row2_start = row3_start + (card_width + card_spacing) / 2
	var row2_indices = [0, 1, 3, 4, 6, 7]
	for i in range(6):
		positions[3 + i] = Vector2(row2_start + row2_indices[i] * (card_width + card_spacing), base_y - row_overlap * 2)
	
	# Top row (3 peaks)
	var row1_start = row2_start + (card_width + card_spacing) / 2
	var peak_indices = [0, 3, 6]
	for i in range(3):
		positions[i] = Vector2(row1_start + peak_indices[i] * (card_width + card_spacing), base_y - row_overlap * 3)
	
	return positions

# === SCALE CALCULATIONS ===

func _calculate_mobile_scale(container_size: Vector2) -> float:
	"""Calculate scale factor for mobile cards"""
	var available_width = _get_available_width(container_size)
	var available_height = container_size.y - 40  # Leave some margin
	
	# Calculate what scale would fit width-wise
	var max_card_width = (available_width - MIN_CARD_SPACING * 9) / 10
	var width_scale = max_card_width / MOBILE_CARD_WIDTH
	
	# Calculate what scale would fit height-wise
	var total_height_needed = MOBILE_CARD_HEIGHT + (MOBILE_CARD_HEIGHT * MOBILE_OVERLAP_Y_RATIO * 3.5)
	var height_scale = available_height / total_height_needed
	
	# Use the smaller scale to ensure everything fits
	var scale = min(width_scale, height_scale)
	
	# Clamp to reasonable values
	return clamp(scale, 0.5, 1.5)

func _calculate_desktop_scale(container_size: Vector2) -> float:
	"""Calculate scale factor for desktop cards"""
	var available_width = _get_available_width(container_size)
	var available_height = container_size.y - 40
	
	# Similar logic to mobile but with desktop dimensions
	var max_card_width = (available_width - DESKTOP_CARD_SPACING * 9) / 10
	var width_scale = max_card_width / DESKTOP_CARD_WIDTH
	
	var total_height = DESKTOP_CARD_HEIGHT + (DESKTOP_OVERLAP_Y * 3.5)
	var height_scale = available_height / total_height
	
	var scale = min(width_scale, height_scale)
	return clamp(scale, 0.8, 2.0)

# === DRAW ZONE HELPERS ===

func _get_draw_zone_width() -> float:
	"""Get the width of a single draw zone"""
	# Use UIStyleManager if available, otherwise use constant
	if UIStyleManager:
		return UIStyleManager.get_game_dimension("draw_zone_width")
	return DRAW_ZONE_BASE_WIDTH

func _get_available_width(container_size: Vector2) -> float:
	"""Get available width after accounting for draw zones"""
	var width = container_size.x
	
	# Check current draw zone configuration
	if SettingsSystem.is_left_draw_enabled():
		width -= _get_draw_zone_width()
	if SettingsSystem.is_right_draw_enabled():
		width -= _get_draw_zone_width()
	
	return width

func _get_left_offset() -> float:
	"""Get the left offset to account for left draw zone"""
	if SettingsSystem.is_left_draw_enabled():
		return _get_draw_zone_width()
	return 0

# === COLLISION LAYER HELPERS ===

func get_collision_layer_for_card(index: int) -> int:
	"""Get the collision layer for a card at the given index"""
	var row = get_card_row(index)
	match row:
		0: return 8  # Top row
		1: return 4  # Row 2
		2: return 2  # Row 3
		3: return 1  # Bottom row
		_: return 0

func get_collision_mask_for_card(index: int) -> int:
	"""Get the collision mask for a card at the given index"""
	var row = get_card_row(index)
	match row:
		0: return 4  # Top row checks row 2
		1: return 2  # Row 2 checks row 3
		2: return 1  # Row 3 checks bottom row
		3: return 0  # Bottom row checks nothing
		_: return 0

func get_z_index_for_card(index: int) -> int:
	"""Get the z-index for proper card layering"""
	var row = get_card_row(index)
	match row:
		0: return 1  # Top row
		1: return 2  # Row 2
		2: return 3  # Row 3
		3: return 4  # Bottom row
		_: return 0

# === ALTERNATIVE LAYOUTS (Future) ===

func calculate_custom_layout(layout_name: String, container_size: Vector2) -> Array[Vector2]:
	"""Calculate positions for alternative pyramid layouts"""
	if not PYRAMID_LAYOUTS.has(layout_name):
		push_error("Unknown layout: %s" % layout_name)
		return calculate_card_positions(container_size)
	
	# This would implement different pyramid shapes
	# For now, return standard layout
	return calculate_card_positions(container_size)

# === DEBUG HELPERS ===

func get_debug_info() -> Dictionary:
	"""Get debug information about current layout"""
	return {
		"cached_positions": cached_positions.size(),
		"scale_factor": cached_scale_factor,
		"container_size": cached_container_size,
		"draw_zones": {
			"left": SettingsSystem.is_left_draw_enabled(),
			"right": SettingsSystem.is_right_draw_enabled()
		},
		"layout": get_pyramid_layout_name()
	}

func print_layout_debug() -> void:
	"""Print detailed layout information"""
	print("=== BOARD LAYOUT DEBUG ===")
	print("Container: %s" % cached_container_size)
	print("Scale Factor: %.2f" % cached_scale_factor)
	print("Draw Zones - Left: %s, Right: %s" % [
		SettingsSystem.is_left_draw_enabled(),
		SettingsSystem.is_right_draw_enabled()
	])
	print("Positions cached: %d" % cached_positions.size())
	if cached_positions.size() > 0:
		print("First card at: %s" % cached_positions[0])
		print("Last card at: %s" % cached_positions[27])
	print("========================")
