# BoardSkinBase.gd - Base class for all board skins
# Location: res://Pyramids/scripts/items/boards/BoardSkinBase.gd
# Last Updated: Created board skin base class [Date]

class_name BoardSkinBase
extends Resource

@export var skin_name: String = "base"
@export var display_name: String = "Classic Green"

# Board appearance settings
@export var board_bg_color: Color = Color(0.2, 0.5, 0.2)  # Classic green felt
@export var board_pattern_color: Color = Color(0.15, 0.4, 0.15)
@export var board_border_color: Color = Color(0.1, 0.3, 0.1)
@export var board_border_width: int = 4

# Animation settings
@export var supports_animation: bool = false
@export var animation_speed: float = 1.0

# Pattern settings
@export var has_pattern: bool = false
@export var pattern_opacity: float = 0.3
@export var pattern_scale: float = 1.0

# Apply skin to board (for runtime use)
func apply_to_board(board_node: Control) -> void:
	# Override in child classes
	pass

# Draw board background
func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Default implementation - solid color
	canvas.draw_rect(Rect2(Vector2.ZERO, size), board_bg_color)
	
	if has_pattern:
		_draw_pattern(canvas, size)

func _draw_pattern(canvas: CanvasItem, size: Vector2) -> void:
	# Override in child classes for custom patterns
	pass
