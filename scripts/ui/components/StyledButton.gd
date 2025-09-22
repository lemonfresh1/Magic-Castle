# StyledButton.gd - Self-styling button component
# Location: res://Pyramids/scripts/ui/components/StyledButton.gd
# Last Updated: Added battle and lobby styles [Date]
# Migration path: Use this instead of Button + UIStyleManager.apply_button_style()
extends Button
class_name StyledButton

# Style configuration - UPDATED WITH NEW STYLES
@export_enum("primary", "secondary", "danger", "warning", "success", "transparent", "battle", "lobby", "battle_filled", "lobby_filled") var button_style: String = "primary"
@export_enum("small", "medium", "large") var button_size: String = "medium"

# Runtime style changes
var _current_style: String = ""
var _current_size: String = ""

func _ready():
	# Apply initial style
	_apply_style()
	
	# Re-apply on any export changes in editor
	if Engine.is_editor_hint():
		set_notify_transform(true)

func _notification(what: int):
	# Re-apply style when export vars change in editor
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_apply_style()

# Public method to change style at runtime
func set_button_style(style: String, size: String = ""):
	button_style = style
	if size != "":
		button_size = size
	_apply_style()

func _apply_style():
	# Skip if no changes
	if button_style == _current_style and button_size == _current_size:
		return
	
	_current_style = button_style
	_current_size = button_size
	
	# Get theme reference
	var theme_constants = ThemeConstants
	if not theme_constants:
		push_error("StyledButton: ThemeConstants not found in autoloads")
		return
	
	# Handle transparent buttons specially
	if button_style == "transparent":
		_apply_transparent_style()
		return
	
	# Create style boxes
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	var style_disabled = StyleBoxFlat.new()
	
	# Apply colors based on style
	match button_style:
		"primary":
			style_normal.bg_color = theme_constants.colors.primary
			style_hover.bg_color = theme_constants.colors.primary_dark
			style_pressed.bg_color = theme_constants.colors.primary_dark.darkened(0.1)
			style_disabled.bg_color = theme_constants.colors.primary.lightened(0.3)
			add_theme_color_override("font_color", theme_constants.colors.white)
			add_theme_color_override("font_hover_color", theme_constants.colors.white)
			add_theme_color_override("font_pressed_color", theme_constants.colors.white)
			add_theme_color_override("font_disabled_color", theme_constants.colors.white.darkened(0.3))
			
		"secondary":
			style_normal.bg_color = theme_constants.colors.white
			style_hover.bg_color = theme_constants.colors.gray_50
			style_pressed.bg_color = theme_constants.colors.gray_100
			style_disabled.bg_color = theme_constants.colors.white.darkened(0.05)
			style_normal.border_color = theme_constants.colors.gray_200
			style_normal.set_border_width_all(theme_constants.borders.width_thin)
			style_hover.border_color = theme_constants.colors.gray_300
			style_hover.set_border_width_all(theme_constants.borders.width_thin)
			style_pressed.border_color = theme_constants.colors.gray_300
			style_pressed.set_border_width_all(theme_constants.borders.width_thin)
			style_disabled.border_color = theme_constants.colors.gray_200
			style_disabled.set_border_width_all(theme_constants.borders.width_thin)
			add_theme_color_override("font_color", theme_constants.colors.gray_700)
			add_theme_color_override("font_hover_color", theme_constants.colors.gray_900)
			add_theme_color_override("font_pressed_color", theme_constants.colors.gray_900)
			add_theme_color_override("font_disabled_color", theme_constants.colors.gray_400)
			
		"danger":
			style_normal.bg_color = theme_constants.colors.error
			style_hover.bg_color = theme_constants.colors.error.darkened(0.1)
			style_pressed.bg_color = theme_constants.colors.error.darkened(0.2)
			style_disabled.bg_color = theme_constants.colors.error.lightened(0.3)
			add_theme_color_override("font_color", theme_constants.colors.white)
			add_theme_color_override("font_hover_color", theme_constants.colors.white)
			add_theme_color_override("font_pressed_color", theme_constants.colors.white)
			add_theme_color_override("font_disabled_color", theme_constants.colors.white.darkened(0.3))
			
		"warning":
			style_normal.bg_color = theme_constants.colors.warning_muted
			style_hover.bg_color = theme_constants.colors.warning_muted.darkened(0.1)
			style_pressed.bg_color = theme_constants.colors.warning_muted.darkened(0.2)
			style_disabled.bg_color = theme_constants.colors.warning_muted.lightened(0.3)
			add_theme_color_override("font_color", theme_constants.colors.gray_900)
			add_theme_color_override("font_hover_color", theme_constants.colors.gray_900)
			add_theme_color_override("font_pressed_color", theme_constants.colors.gray_900)
			add_theme_color_override("font_disabled_color", theme_constants.colors.gray_600)
			
		"success":
			style_normal.bg_color = theme_constants.colors.success
			style_hover.bg_color = theme_constants.colors.primary_dark
			style_pressed.bg_color = theme_constants.colors.primary_dark.darkened(0.1)
			style_disabled.bg_color = theme_constants.colors.success.lightened(0.3)
			add_theme_color_override("font_color", theme_constants.colors.white)
			add_theme_color_override("font_hover_color", theme_constants.colors.white)
			add_theme_color_override("font_pressed_color", theme_constants.colors.white)
			add_theme_color_override("font_disabled_color", theme_constants.colors.white.darkened(0.3))
			
		"battle":
			# Battle buttons - white bg with red border/accents
			style_normal.bg_color = theme_constants.colors.white
			style_normal.border_color = theme_constants.colors.play_multiplayer
			style_normal.set_border_width_all(2)
			style_hover.bg_color = theme_constants.colors.play_multiplayer.lightened(0.95)
			style_hover.border_color = theme_constants.colors.play_multiplayer_dark
			style_hover.set_border_width_all(2)
			style_pressed.bg_color = theme_constants.colors.play_multiplayer.lightened(0.9)
			style_pressed.border_color = theme_constants.colors.play_multiplayer_dark
			style_pressed.set_border_width_all(2)
			style_disabled.bg_color = theme_constants.colors.gray_50
			style_disabled.border_color = theme_constants.colors.gray_300
			style_disabled.set_border_width_all(2)
			add_theme_color_override("font_color", theme_constants.colors.play_multiplayer_dark)
			add_theme_color_override("font_hover_color", theme_constants.colors.play_multiplayer_dark)
			add_theme_color_override("font_pressed_color", theme_constants.colors.play_multiplayer_dark.darkened(0.1))
			add_theme_color_override("font_disabled_color", theme_constants.colors.gray_400)
			
		"lobby":
			# Lobby buttons - white bg with gold border/accents
			style_normal.bg_color = theme_constants.colors.white
			style_normal.border_color = theme_constants.colors.play_tournament
			style_normal.set_border_width_all(2)
			style_hover.bg_color = theme_constants.colors.play_tournament.lightened(0.95)
			style_hover.border_color = theme_constants.colors.play_tournament_dark
			style_hover.set_border_width_all(2)
			style_pressed.bg_color = theme_constants.colors.play_tournament.lightened(0.9)
			style_pressed.border_color = theme_constants.colors.play_tournament_dark
			style_pressed.set_border_width_all(2)
			style_disabled.bg_color = theme_constants.colors.gray_50
			style_disabled.border_color = theme_constants.colors.gray_300
			style_disabled.set_border_width_all(2)
			add_theme_color_override("font_color", theme_constants.colors.play_tournament_dark)
			add_theme_color_override("font_hover_color", theme_constants.colors.play_tournament_dark)
			add_theme_color_override("font_pressed_color", theme_constants.colors.play_tournament_dark.darkened(0.1))
			add_theme_color_override("font_disabled_color", theme_constants.colors.gray_400)
			
		"battle_filled":
			# Battle filled - red bg with white text
			style_normal.bg_color = theme_constants.colors.play_multiplayer
			style_hover.bg_color = theme_constants.colors.play_multiplayer_dark
			style_pressed.bg_color = theme_constants.colors.play_multiplayer_dark.darkened(0.1)
			style_disabled.bg_color = theme_constants.colors.play_multiplayer.lightened(0.4)
			add_theme_color_override("font_color", theme_constants.colors.white)
			add_theme_color_override("font_hover_color", theme_constants.colors.white)
			add_theme_color_override("font_pressed_color", theme_constants.colors.white)
			add_theme_color_override("font_disabled_color", theme_constants.colors.white.darkened(0.3))
			
		"lobby_filled":
			# Lobby filled - gold bg with white text
			style_normal.bg_color = theme_constants.colors.play_tournament
			style_hover.bg_color = theme_constants.colors.play_tournament_dark
			style_pressed.bg_color = theme_constants.colors.play_tournament_dark.darkened(0.1)
			style_disabled.bg_color = theme_constants.colors.play_tournament.lightened(0.4)
			add_theme_color_override("font_color", theme_constants.colors.white)
			add_theme_color_override("font_hover_color", theme_constants.colors.white)
			add_theme_color_override("font_pressed_color", theme_constants.colors.white)
			add_theme_color_override("font_disabled_color", theme_constants.colors.white.darkened(0.3))
	
	# Apply size adjustments
	match button_size:
		"small":
			custom_minimum_size.y = theme_constants.dimensions.small_button_height
			add_theme_font_size_override("font_size", theme_constants.typography.size_body_small)
			style_normal.set_corner_radius_all(theme_constants.dimensions.corner_radius_small)
		"medium":
			custom_minimum_size.y = theme_constants.dimensions.medium_button_height
			add_theme_font_size_override("font_size", theme_constants.typography.size_body)
			style_normal.set_corner_radius_all(theme_constants.dimensions.corner_radius_medium)
		"large":
			custom_minimum_size.y = theme_constants.dimensions.action_button_height
			add_theme_font_size_override("font_size", theme_constants.typography.size_body_large)
			style_normal.set_corner_radius_all(theme_constants.dimensions.corner_radius_medium)
	
	# Set content margins
	style_normal.content_margin_left = theme_constants.spacing.button_padding_h
	style_normal.content_margin_right = theme_constants.spacing.button_padding_h
	style_normal.content_margin_top = theme_constants.spacing.button_padding_v
	style_normal.content_margin_bottom = theme_constants.spacing.button_padding_v
	
	# Copy base style properties to other states (preserving unique colors)
	# For hover state
	if not style_hover.border_color:
		style_hover.border_color = style_normal.border_color
	if style_hover.get_border_width(SIDE_LEFT) == 0:
		style_hover.set_border_width_all(style_normal.get_border_width(SIDE_LEFT))
	style_hover.set_corner_radius_all(style_normal.get_corner_radius(CORNER_TOP_LEFT))
	style_hover.content_margin_left = style_normal.content_margin_left
	style_hover.content_margin_right = style_normal.content_margin_right
	style_hover.content_margin_top = style_normal.content_margin_top
	style_hover.content_margin_bottom = style_normal.content_margin_bottom
	
	# For pressed state
	if not style_pressed.border_color:
		style_pressed.border_color = style_normal.border_color
	if style_pressed.get_border_width(SIDE_LEFT) == 0:
		style_pressed.set_border_width_all(style_normal.get_border_width(SIDE_LEFT))
	style_pressed.set_corner_radius_all(style_normal.get_corner_radius(CORNER_TOP_LEFT))
	style_pressed.content_margin_left = style_normal.content_margin_left
	style_pressed.content_margin_right = style_normal.content_margin_right
	style_pressed.content_margin_top = style_normal.content_margin_top
	style_pressed.content_margin_bottom = style_normal.content_margin_bottom
	
	# For disabled state
	if not style_disabled.border_color:
		style_disabled.border_color = style_normal.border_color
	if style_disabled.get_border_width(SIDE_LEFT) == 0:
		style_disabled.set_border_width_all(style_normal.get_border_width(SIDE_LEFT))
	style_disabled.set_corner_radius_all(style_normal.get_corner_radius(CORNER_TOP_LEFT))
	style_disabled.content_margin_left = style_normal.content_margin_left
	style_disabled.content_margin_right = style_normal.content_margin_right
	style_disabled.content_margin_top = style_normal.content_margin_top
	style_disabled.content_margin_bottom = style_normal.content_margin_bottom
	
	# Add subtle shadow on hover for non-flat styles
	if button_style != "secondary":  # Secondary already has border
		style_hover.shadow_size = theme_constants.shadows.size_small
		style_hover.shadow_offset = theme_constants.shadows.offset_small
		style_hover.shadow_color = theme_constants.shadows.color_default
	
	# Apply all styles
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
	add_theme_stylebox_override("disabled", style_disabled)
	
	# Remove focus outline
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("focus", empty_style)
	focus_mode = Control.FOCUS_NONE

func _apply_transparent_style():
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	add_theme_color_override("icon_normal_color", Color.WHITE)
	add_theme_color_override("icon_hover_color", Color.WHITE)
	add_theme_color_override("icon_pressed_color", Color.WHITE)
	add_theme_color_override("icon_disabled_color", Color.WHITE.darkened(0.5))
	
	focus_mode = Control.FOCUS_NONE
