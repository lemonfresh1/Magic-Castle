# UIStyleManager.gd - Centralized UI styling and layout management
# Location: res://Magic-Castle/scripts/autoloads/UIStyleManager.gd
# Last Updated: Added comprehensive design system [Date]

extends Node

# Design system colors - from your design doc
var colors = {
	# Primary Colors
	"primary": Color("#10b981"),
	"primary_dark": Color("#059669"),
	"primary_light": Color("#d1fae5"),
	"primary_focus": Color(0.063, 0.725, 0.506, 0.1),
	
	# Neutral Palette
	"gray_900": Color("#111827"),  # Primary text
	"gray_700": Color("#374151"),  # Secondary text
	"gray_600": Color("#4b5563"),  # Tertiary text
	"gray_500": Color("#6b7280"),  # Muted text
	"gray_400": Color("#9ca3af"),  # Disabled text
	"gray_300": Color("#d1d5db"),  # Borders - disabled
	"gray_200": Color("#e5e7eb"),  # Borders - inactive
	"gray_100": Color("#f3f4f6"),  # Borders - active
	"gray_50": Color("#f9fafb"),   # Hover backgrounds
	"white": Color.WHITE,
	"base_bg": Color("#fafafa"),   # Page background
	
	# Semantic Colors
	"error": Color("#ef4444"),
	"error_light": Color("#fee2e2"),
	"warning": Color("#f59e0b"),
	"warning_light": Color("#fef3c7"),
	"success": Color("#10b981"),
	"info": Color("#3b82f6"),
	"info_light": Color("#dbeafe"),
	
	# Special Colors
	"premium": Color("#8b5cf6"),
	"premium_dark": Color("#7c3aed"),
	"premium_light": Color("#ede9fe")
}

# Typography specifications
var typography = {
	# Font sizes
	"size_display": 48,    # Play button only
	"size_h1": 40,
	"size_h2": 36,
	"size_h3": 32,
	"size_title": 24,
	"size_body_large": 20,
	"size_body": 18,
	"size_body_small": 16,
	"size_caption": 14,
	"size_micro": 12,
	
	# Font weights (if using dynamic fonts)
	"weight_regular": 400,
	"weight_medium": 500,
	"weight_bold": 700
}

# Spacing system - base unit of 4px
var spacing = {
	"unit": 4,
	"space_1": 4,      # 4px
	"space_2": 8,      # 8px
	"space_3": 12,     # 12px
	"space_4": 16,     # 16px
	"space_5": 20,     # 20px
	"space_6": 24,     # 24px
	"space_8": 32,     # 32px
	"space_10": 40,    # 40px
	"space_12": 48,    # 48px
	"space_16": 64,    # 64px
	"space_20": 80,    # 80px
	
	# Component specific
	"card_padding": 20,
	"button_padding_h": 24,
	"button_padding_v": 8,
	"modal_padding": 32,
	"section_spacing": 48
}

# Component dimensions
var dimensions = {
	# Buttons
	"play_button_size": Vector2(560, 100),
	"menu_button_size": Vector2(560, 80),
	"action_button_height": 50,
	"medium_button_height": 30,
	"small_button_height": 20,
	
	# Cards and panels
	"reward_card_size": Vector2(180, 170),
	"tier_column_width": 120,
	"tier_column_height": 187,
	"mission_card_height": 80,
	
	# Progress bars
	"progress_bar_height": 50,
	"small_progress_height": 30,
	
	# Modals
	"modal_min_width": 400,
	"modal_max_width": 600,
	
	# Corner radius
	"corner_radius_small": 8,
	"corner_radius_medium": 12,
	"corner_radius_large": 16,
	"corner_radius_xl": 25,
	"corner_radius_round": 50  # For pills/play button
}

# Border specifications
var borders = {
	"width_thin": 1,
	"width_medium": 2,
	"width_thick": 3,
	"width_focus": 2
}

# Shadow specifications
var shadows = {
	# Shadow sizes
	"size_small": 2,
	"size_medium": 4,
	"size_large": 8,
	"size_xl": 20,
	
	# Shadow colors
	"color_default": Color(0, 0, 0, 0.08),
	"color_medium": Color(0, 0, 0, 0.15),
	"color_large": Color(0, 0, 0, 0.25),
	"color_primary": Color(0.063, 0.725, 0.506, 0.3),  # Primary with transparency
	
	# Shadow offsets
	"offset_small": Vector2(0, 1),
	"offset_medium": Vector2(0, 2),
	"offset_large": Vector2(0, 4)
}

var opacity = {
	"full": 1.0,
	"claimed": 0.6,      # Dimmed claimed rewards
	"locked": 0.4,       # Locked rewards
	"lock_strong": 0.8,  # Lock overlay - not reached
	"lock_medium": 0.6,  # Lock overlay - no premium
	"lock_weak": 0.5,    # Lock overlay - default
	"lock_faint": 0.3,   # Lock overlay - claimed
}

# Animation durations
var animations = {
	"duration_instant": 0.0,
	"duration_fast": 0.1,      # Clicks
	"duration_normal": 0.15,   # Hovers
	"duration_medium": 0.2,    # Modals
	"duration_slow": 0.3,      # Page transitions
	"duration_slower": 0.4     # Complex animations
}

# Battle pass style configuration
var battle_pass_style = {
	# Tier column colors
	"tier_bg": Color.WHITE,
	"tier_bg_locked": Color("#F3F4F6"),
	"tier_bg_current": Color("#10b981"),
	"tier_border": Color("#E5E7EB"),
	"tier_border_current": Color("#10b981"),
	"tier_shadow": Color(0, 0, 0, 0.08),
	
	# Progress bar
	"progress_bg": Color("#E5E7EB"),
	"progress_fill": Color("#10b981"),
	"progress_text": Color("#374151"),
	
	# Dimensions
	"tier_corner_radius": 12,
	"tier_border_width": 1,
	"tier_shadow_size": 4,
	"tier_width": 120,
	"tier_height": 187,
	
	# Typography
	"tier_number_size": 20,
	"reward_amount_size": 16,
	"progress_text_size": 18
}

# Holiday theme overrides
var holiday_style = {
	"tier_bg": Color.WHITE,
	"tier_bg_locked": Color("#FEF3C7"),  # Warm holiday tint
	"tier_bg_current": Color("#DC2626"),  # Holiday red
	"tier_border": Color("#FCD34D"),      # Golden border
	"tier_border_current": Color("#DC2626"),
	"progress_fill": Color("#DC2626"),
	# Rest inherits from battle_pass_style
}

# Panel styling configuration (existing)
var panel_style_config = {
	"bg_color": Color(1.0, 1.0, 1.0, 0.847),
	"border_color": Color(1.0, 1.0, 1.0, 0.863),
	"border_width": 1,
	"corner_radius": 12,
	"shadow_size": 5,
	"shadow_offset_y": 3,
	"shadow_color": Color(0.445, 0.445, 0.445, 0.6)
}

# Scroll container configuration (existing)
var scroll_config = {
	"width": 600,
	"height": 300,
	"margin_left": 5,
	"margin_right": 5,
	"margin_top": 2,
	"margin_bottom": 9,
	"content_separation": 10
}

# Filter button styling configuration (existing)
var filter_style_config = {
	"normal_color": Color(0.565, 0.525, 1.0),
	"hover_color": Color(0.565, 0.525, 1.0),  # Same as normal for mobile
	"pressed_color": Color(0.644, 0.529, 1.0),
	"corner_radius": 12,
	"content_margin_h": 20,  # Left and right
	"content_margin_v": -1   # Top and bottom
}

# Dictionary to track styled panels for easy updates
var styled_panels = {}

# Add this to UIStyleManager.gd
static func validate_no_hardcoded_styles(script_path: String) -> bool:
	"""Development tool to check for style violations"""
	var file = FileAccess.open(script_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var violations = []
	
	# Check for direct Color usage
	if "Color(" in content and "UIStyleManager" not in content.substr(content.find("Color(") - 50, 50):
		violations.append("Direct Color() constructor found")
	
	# Check for hardcoded sizes
	var size_patterns = ["font_size\", ", "margin\", ", "padding\", "]
	for pattern in size_patterns:
		if pattern in content and not "UIStyleManager" in content:
			violations.append("Hardcoded size value found")
	
	if violations.size() > 0:
		push_error("STYLE VIOLATIONS IN %s: %s" % [script_path, violations])
		return false
	return true

func _ready():
	print("UIStyleManager initialized")

# Helper functions to access design system values
func get_color(color_name: String) -> Color:
	return colors.get(color_name, Color.WHITE)

func get_spacing(key: String) -> int:
	return spacing.get(key, spacing.space_4)

func get_dimension(key: String):
	return dimensions.get(key, 100)

func get_font_size(key: String) -> int:
	return typography.get(key, typography.size_body)

func get_shadow_config(size: String = "medium") -> Dictionary:
	return {
		"size": shadows.get("size_" + size, shadows.size_medium),
		"color": shadows.get("color_default", shadows.color_default),
		"offset": shadows.get("offset_" + size, shadows.offset_medium)
	}

func get_border_config(type: String = "default", width: String = "thin") -> Dictionary:
	return {
		"width": borders.get("width_" + width, borders.width_thin),
		"color": colors.get("gray_200", colors.gray_200)  # Default border color
	}

# Existing panel styling function
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

# New tier column styling function
func apply_tier_column_style(panel: PanelContainer, state: String = "normal", theme: String = "battle_pass") -> void:
	"""Apply tier column styling based on state and theme"""
	var style = StyleBoxFlat.new()
	var config = battle_pass_style if theme == "battle_pass" else holiday_style
	
	# Determine colors based on state
	match state:
		"locked":
			style.bg_color = config.get("tier_bg_locked", colors.gray_50)
			style.border_color = colors.gray_300
			style.set_border_width_all(0)  # No border for locked
		"claimable":
			style.bg_color = config.get("tier_bg", colors.white)
			style.border_color = colors.primary  # Green border for claimable
			style.set_border_width_all(borders.width_medium)
		"claimed":
			style.bg_color = config.get("tier_bg", colors.white)
			style.border_color = colors.gray_400  # Gray border for claimed
			style.set_border_width_all(borders.width_thin)
		_:  # normal
			style.bg_color = config.get("tier_bg", colors.white)
			style.border_color = config.get("tier_border", colors.gray_200)
			style.set_border_width_all(borders.width_thin)
	
	# Apply corner radius
	style.set_corner_radius_all(battle_pass_style.tier_corner_radius)
	
	# Apply shadow
	var shadow = get_shadow_config("medium" if state == "claimable" else "small")
	style.shadow_size = shadow.size
	style.shadow_offset = shadow.offset
	style.shadow_color = shadow.color
	
	panel.add_theme_stylebox_override("panel", style)

# Button styling function
func apply_button_style(button: Button, button_type: String = "default", size: String = "medium") -> void:
	"""Apply button styling following the design system"""
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	
	# Base styling
	match button_type:
		"primary":
			style_normal.bg_color = colors.primary
			style_hover.bg_color = colors.primary_dark
			button.add_theme_color_override("font_color", colors.white)
		"secondary":
			style_normal.bg_color = colors.white
			style_hover.bg_color = colors.gray_50
			style_normal.border_color = colors.gray_200
			style_normal.set_border_width_all(borders.width_thin)
			button.add_theme_color_override("font_color", colors.gray_700)
		_:  # default
			style_normal.bg_color = colors.white
			style_hover.bg_color = colors.gray_50
			button.add_theme_color_override("font_color", colors.gray_600)
	
	# Size-based adjustments
	match size:
		"large":
			button.custom_minimum_size.y = dimensions.action_button_height
			button.add_theme_font_size_override("font_size", typography.size_body_large)
			style_normal.set_corner_radius_all(dimensions.corner_radius_xl)
		"small":
			button.custom_minimum_size.y = dimensions.small_button_height
			button.add_theme_font_size_override("font_size", typography.size_body_small)
			style_normal.set_corner_radius_all(dimensions.corner_radius_small)
		"medium":
			button.custom_minimum_size.y = dimensions.medium_button_height
			button.add_theme_font_size_override("font_size", typography.size_body_small)
			style_normal.set_corner_radius_all(dimensions.corner_radius_small)
		
		_:  # default
			button.add_theme_font_size_override("font_size", typography.size_body)
			style_normal.set_corner_radius_all(dimensions.corner_radius_medium)
	
	# Content margins
	style_normal.content_margin_left = spacing.button_padding_h
	style_normal.content_margin_right = spacing.button_padding_h
	style_normal.content_margin_top = spacing.button_padding_v
	style_normal.content_margin_bottom = spacing.button_padding_v
	
	# Copy styling to hover/pressed states
	style_hover = style_normal.duplicate()
	style_pressed = style_normal.duplicate()
	
	# Add hover shadow
	var shadow = get_shadow_config("small")
	style_hover.shadow_size = shadow.size
	style_hover.shadow_color = shadow.color
	style_hover.shadow_offset = shadow.offset
	
	# Apply styles
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

# Progress bar styling
func apply_progress_bar_style(progress_bar: ProgressBar, theme: String = "battle_pass") -> void:
	"""Apply progress bar styling"""
	var config = battle_pass_style if theme == "battle_pass" else holiday_style
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = config.progress_bg
	bg_style.border_color = colors.gray_200
	bg_style.set_border_width_all(borders.width_thin)
	bg_style.set_corner_radius_all(dimensions.corner_radius_xl)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = config.progress_fill
	fill_style.set_corner_radius_all(dimensions.corner_radius_xl)
	
	progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

# Existing scrollable content setup function
func setup_scrollable_content(parent: Control, content_callback: Callable, config_overrides: Dictionary = {}) -> Control:
	"""
	Universal function to setup any container with proper ScrollContainer and margins
	Returns the created VBox for additional customization if needed
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

# Existing filter button styling
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

# Update functions
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

func update_filter_style_config(new_config: Dictionary) -> void:
	"""Update the filter button style configuration"""
	filter_style_config.merge(new_config, true)
