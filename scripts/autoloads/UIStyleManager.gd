# UIStyleManager.gd - Centralized UI styling and layout management
# Location: res://Magic-Castle/scripts/autoloads/UIStyleManager.gd
# Last Updated: Added transparent border to filter popup panels [Date]

extends Node

# Panel styling configuration
var panel_style_config = {
	"bg_color": Color(1.0, 1.0, 1.0, 0.847),
	"border_color": Color(1.0, 1.0, 1.0, 0.863),
	"border_width": 1,
	"corner_radius": 12,
	"shadow_size": 5,
	"shadow_offset_y": 3,
	"shadow_color": Color(0.445, 0.445, 0.445, 0.6)
}

# Scroll container configuration
var scroll_config = {
	"width": 600,
	"height": 300,
	"margin_left": 5,
	"margin_right": 5,
	"margin_top": 2,
	"margin_bottom": 9,
	"content_separation": 10
}

# TODO: Add viewport-based responsive sizing
# var responsive_config = {
#     "enabled": false,
#     "scale_factor": 1.0,
#     "min_width": 400,
#     "min_height": 200
# }

# Dictionary to track styled panels for easy updates
var styled_panels = {}

func _ready():
	print("UIStyleManager initialized")

func apply_panel_style(panel: PanelContainer, panel_id: String = "") -> void:
	"""Apply the standard panel styling to a PanelContainer"""
	if not panel:
		return
	
	var style = StyleBoxFlat.new()
	
	# Background
	style.bg_color = panel_style_config.bg_color
	
	# Border
	style.border_color = panel_style_config.border_color
	style.set_border_width_all(panel_style_config.border_width)
	
	# Corners
	style.set_corner_radius_all(panel_style_config.corner_radius)
	
	# Shadow
	style.shadow_size = panel_style_config.shadow_size
	style.shadow_offset = Vector2(0, panel_style_config.shadow_offset_y)
	style.shadow_color = panel_style_config.shadow_color
	
	# Apply the style
	panel.add_theme_stylebox_override("panel", style)
	
	# Track the panel if it has an ID
	if panel_id != "":
		styled_panels[panel_id] = panel

func setup_scrollable_content(parent: Control, content_callback: Callable, config_overrides: Dictionary = {}) -> Control:
	"""
	Universal function to setup any container with proper ScrollContainer and margins
	Returns the created VBox for additional customization if needed
	
	parent: The parent container to setup
	content_callback: Function to call to populate the content (receives VBox as parameter)
	config_overrides: Dictionary to override default settings
		- width: custom scroll width
		- height: custom scroll height
		- margin_left: custom left margin
		- margin_right: custom right margin
		- margin_top: custom top margin
		- margin_bottom: custom bottom margin
		- separation: custom content separation
	"""
	# Ensure parent has proper size flags
	parent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Get configuration values
	var width = config_overrides.get("width", scroll_config.width)
	var height = config_overrides.get("height", scroll_config.height)
	var margin_left = config_overrides.get("margin_left", scroll_config.margin_left)
	var margin_right = config_overrides.get("margin_right", scroll_config.margin_right)
	var margin_top = config_overrides.get("margin_top", scroll_config.margin_top)
	var margin_bottom = config_overrides.get("margin_bottom", scroll_config.margin_bottom)
	var separation = config_overrides.get("separation", scroll_config.content_separation)
	
	# Find or create ScrollContainer
	var scroll = parent.find_child("ScrollContainer", true, false)
	if not scroll:
		scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		parent.add_child(scroll)
	
	# Configure ScrollContainer with proper anchors
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 0
	scroll.offset_top = 0
	scroll.offset_right = 0
	scroll.offset_bottom = 0
	scroll.custom_minimum_size = Vector2(width, height)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.visible = true
	
	# Clear existing content
	for child in scroll.get_children():
		child.queue_free()
	
	# Wait for cleanup
	await parent.get_tree().process_frame
	
	# Create MarginContainer with all four margins
	var margin_container = MarginContainer.new()
	margin_container.name = "MarginContainer"
	margin_container.add_theme_constant_override("margin_left", margin_left)
	margin_container.add_theme_constant_override("margin_right", margin_right)
	margin_container.add_theme_constant_override("margin_top", margin_top)
	margin_container.add_theme_constant_override("margin_bottom", margin_bottom)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)
	
	# Create VBox
	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", separation)
	margin_container.add_child(vbox)
	
	# Call content callback if provided
	if content_callback and content_callback.is_valid():
		content_callback.call(vbox)
	
	return vbox

func update_panel_style_config(new_config: Dictionary) -> void:
	"""Update the panel style configuration and refresh all tracked panels"""
	panel_style_config.merge(new_config, true)
	
	# Refresh all tracked panels
	for panel_id in styled_panels:
		var panel = styled_panels[panel_id]
		if is_instance_valid(panel):
			apply_panel_style(panel, panel_id)

func update_scroll_config(new_config: Dictionary) -> void:
	"""Update the scroll container configuration"""
	scroll_config.merge(new_config, true)

# Filter button styling configuration
var filter_style_config = {
	"normal_color": Color(0.565, 0.525, 1.0),
	"hover_color": Color(0.565, 0.525, 1.0),  # Same as normal for mobile
	"pressed_color": Color(0.644, 0.529, 1.0),
	"corner_radius": 12,
	"content_margin_h": 20,  # Left and right
	"content_margin_v": -1   # Top and bottom
}

func style_filter_button(button: OptionButton, theme_color: Color = Color.WHITE) -> void:
	"""Apply consistent styling to filter buttons"""
	if not button:
		return
	
	# Style the main button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = filter_style_config.normal_color
	style_normal.corner_radius_top_left = filter_style_config.corner_radius
	style_normal.corner_radius_top_right = filter_style_config.corner_radius
	style_normal.corner_radius_bottom_left = filter_style_config.corner_radius
	style_normal.corner_radius_bottom_right = filter_style_config.corner_radius
	style_normal.content_margin_left = filter_style_config.content_margin_h
	style_normal.content_margin_right = filter_style_config.content_margin_h
	style_normal.content_margin_top = filter_style_config.content_margin_v
	style_normal.content_margin_bottom = filter_style_config.content_margin_v
	button.add_theme_stylebox_override("normal", style_normal)
	
	# Hover (same as normal for mobile)
	var style_hover = style_normal.duplicate()
	button.add_theme_stylebox_override("hover", style_hover)
	
	# Pressed
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = filter_style_config.pressed_color
	style_pressed.corner_radius_top_left = filter_style_config.corner_radius
	style_pressed.corner_radius_top_right = filter_style_config.corner_radius
	style_pressed.corner_radius_bottom_left = filter_style_config.corner_radius
	style_pressed.corner_radius_bottom_right = filter_style_config.corner_radius
	style_pressed.content_margin_left = filter_style_config.content_margin_h
	style_pressed.content_margin_right = filter_style_config.content_margin_h
	style_pressed.content_margin_top = filter_style_config.content_margin_v
	style_pressed.content_margin_bottom = filter_style_config.content_margin_v
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# Style the popup panel (uses theme color)
	var popup = button.get_popup()
	if popup:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = theme_color
		panel_style.corner_radius_top_left = 12
		panel_style.corner_radius_top_right = 12
		panel_style.corner_radius_bottom_left = 12
		panel_style.corner_radius_bottom_right = 12
		panel_style.border_width_top = 5
		panel_style.border_color = Color.TRANSPARENT
		popup.add_theme_stylebox_override("panel", panel_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = theme_color.lightened(0.2)
		hover_style.corner_radius_top_left = 8
		hover_style.corner_radius_top_right = 8
		hover_style.corner_radius_bottom_left = 8
		hover_style.corner_radius_bottom_right = 8
		popup.add_theme_stylebox_override("hover", hover_style)

func update_filter_style_config(new_config: Dictionary) -> void:
	"""Update the filter button style configuration"""
	filter_style_config.merge(new_config, true)
	# Note: Would need to track and refresh existing filter buttons if needed
