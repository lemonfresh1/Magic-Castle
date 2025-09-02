# NotificationDot.gd - Visual notification indicator for UI elements
# Location: res://Pyramids/scripts/ui/components/NotificationDot.gd

extends Control
class_name NotificationDot

# Display modes
enum DisplayMode {
	DOT,      # Simple red dot
	NUMBER,   # Show count
	PULSE     # Animated dot
}

# Configuration
@export var display_mode: DisplayMode = DisplayMode.DOT
@export_enum("error", "warning", "success", "primary", "info") var dot_style: String = "error"
@export var dot_size: int = 12
@export var auto_position: bool = true  # Position in top-right of parent
@export var offset: Vector2 = Vector2(-4, 4)  # Offset from corner
@export var pulse: bool = false

# Components
var dot_panel: Panel
var count_label: Label
var pulse_tween: Tween

# State
var notification_count: int = 0

func _ready():
	# Set size
	custom_minimum_size = Vector2(dot_size, dot_size)
	size = Vector2(dot_size, dot_size)
	
	# Don't block mouse events
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create dot
	_create_dot()
	
	# Auto-position if enabled
	if auto_position and get_parent():
		_position_on_parent()
		
	# Start animation if needed
	if pulse:
		_start_pulse_animation()

func _create_dot():
	# Get color from ThemeConstants based on style
	var color = _get_style_color()
	
	# Create panel for the dot
	dot_panel = Panel.new()
	dot_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot_panel)
	
	# Create style for the dot
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(dot_size / 2)  # Make it circular
	
	# Add subtle border using ThemeConstants
	style.border_color = color.darkened(0.2)
	style.set_border_width_all(ThemeConstants.borders.width_thin)
	
	# Add shadow using ThemeConstants shadow config
	style.shadow_size = ThemeConstants.shadows.size_small
	style.shadow_offset = ThemeConstants.shadows.offset_small
	style.shadow_color = ThemeConstants.shadows.color_default
	
	dot_panel.add_theme_stylebox_override("panel", style)
	
	# Create label for number mode
	if display_mode == DisplayMode.NUMBER:
		count_label = Label.new()
		count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", max(8, dot_size - 4))
		count_label.add_theme_color_override("font_color", ThemeConstants.colors.white)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot_panel.add_child(count_label)
		
		# Adjust size for numbers
		if notification_count > 9:
			custom_minimum_size.x = dot_size * 1.5
			size.x = dot_size * 1.5

func _get_style_color() -> Color:
	"""Get color from ThemeConstants based on style setting"""
	match dot_style:
		"error":
			return ThemeConstants.colors.error
		"warning":
			return ThemeConstants.colors.warning
		"success":
			return ThemeConstants.colors.success
		"primary":
			return ThemeConstants.colors.primary
		"info":
			return ThemeConstants.colors.info
		_:
			return ThemeConstants.colors.error

func _position_on_parent():
	"""Position dot on parent's top-right corner"""
	var parent = get_parent()
	if not parent:
		return
		
	# Wait for parent to be ready
	if not parent.is_inside_tree():
		await parent.ready
	
	# Set anchors to parent's top-right
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	
	# Apply offset
	position = offset

func _start_pulse_animation():
	"""Create pulsing animation"""
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func set_count(count: int):
	"""Set the notification count"""
	notification_count = count
	
	# Update visibility
	visible = count > 0
	
	# Update label if in number mode
	if display_mode == DisplayMode.NUMBER and count_label:
		count_label.text = str(min(count, 99))  # Cap at 99
		
		# Adjust width for double digits
		if count > 9:
			custom_minimum_size.x = dot_size * 1.5
			size.x = dot_size * 1.5
		else:
			custom_minimum_size.x = dot_size
			size.x = dot_size

func increment():
	"""Increment the notification count"""
	set_count(notification_count + 1)

func decrement():
	"""Decrement the notification count"""
	set_count(max(0, notification_count - 1))

func clear():
	"""Clear all notifications"""
	set_count(0)

func set_style(style: String):
	"""Change dot style at runtime"""
	dot_style = style
	if dot_panel:
		var panel_style = dot_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style:
			var new_color = _get_style_color()
			panel_style.bg_color = new_color
			panel_style.border_color = new_color.darkened(0.2)

func set_pulse(enabled: bool):
	"""Enable/disable pulse animation"""
	pulse = enabled
	if enabled:
		_start_pulse_animation()
	elif pulse_tween:
		pulse_tween.kill()
		scale = Vector2.ONE
