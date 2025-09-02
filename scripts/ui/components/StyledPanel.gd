# StyledPanel.gd - Self-styling panel component
# Replaces: PanelContainer + UIStyleManager.apply_panel_style()
extends PanelContainer
class_name StyledPanel

# Panel style configuration
@export_enum("default", "card", "modal", "tier", "transparent") var panel_style: String = "default"
@export var with_shadow: bool = true
@export_enum("small", "medium", "large", "xl") var corner_radius_size: String = "medium"
@export var border_width: int = 1
@export var custom_bg_color: Color = Color.TRANSPARENT  # Override if not transparent

# Runtime style tracking
var _current_style: String = ""
var _current_shadow: bool = true
var _current_radius: String = ""

func _ready():
	_apply_style()
	
	# Re-apply on export changes in editor
	if Engine.is_editor_hint():
		set_notify_transform(true)

func _notification(what: int):
	# Re-apply style when export vars change in editor
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_apply_style()

# Public method to change style at runtime
func set_panel_style(style: String, shadow: bool = true):
	panel_style = style
	with_shadow = shadow
	_apply_style()

func _apply_style():
	# Skip if no changes
	if panel_style == _current_style and with_shadow == _current_shadow and corner_radius_size == _current_radius:
		return
	
	_current_style = panel_style
	_current_shadow = with_shadow
	_current_radius = corner_radius_size
	
	# Get theme reference
	var theme_constants = ThemeConstants
	if not theme_constants:
		push_error("StyledPanel: ThemeConstants not found in autoloads")
		return
	
	# Handle transparent panels specially
	if panel_style == "transparent":
		_apply_transparent_style()
		return
	
	# Create style box
	var style = StyleBoxFlat.new()
	
	# Apply base colors based on panel style
	match panel_style:
		"default":
			style.bg_color = theme_constants.panel_style_config.bg_color if custom_bg_color == Color.TRANSPARENT else custom_bg_color
			style.border_color = theme_constants.panel_style_config.border_color
			style.set_border_width_all(theme_constants.panel_style_config.border_width)
			
		"card":
			style.bg_color = theme_constants.colors.white if custom_bg_color == Color.TRANSPARENT else custom_bg_color
			style.border_color = theme_constants.colors.gray_200
			style.set_border_width_all(border_width)
			
		"modal":
			style.bg_color = theme_constants.colors.white if custom_bg_color == Color.TRANSPARENT else custom_bg_color
			style.border_color = theme_constants.colors.gray_300
			style.set_border_width_all(theme_constants.borders.width_thin)
			
		"tier":
			# For battle pass tier columns
			style.bg_color = theme_constants.battle_pass_style.tier_bg if custom_bg_color == Color.TRANSPARENT else custom_bg_color
			style.border_color = theme_constants.battle_pass_style.tier_border
			style.set_border_width_all(theme_constants.battle_pass_style.tier_border_width)
	
	# Apply corner radius
	var radius = _get_corner_radius(theme_constants)
	style.set_corner_radius_all(radius)
	
	# Apply shadow if enabled
	if with_shadow:
		_apply_shadow(style, theme_constants)
	else:
		style.shadow_size = 0
	
	# Apply the style
	add_theme_stylebox_override("panel", style)

func _get_corner_radius(theme_constants) -> int:
	match corner_radius_size:
		"small":
			return theme_constants.dimensions.corner_radius_small
		"medium":
			return theme_constants.dimensions.corner_radius_medium
		"large":
			return theme_constants.dimensions.corner_radius_large
		"xl":
			return theme_constants.dimensions.corner_radius_xl
		_:
			return theme_constants.dimensions.corner_radius_medium

func _apply_shadow(style: StyleBoxFlat, theme_constants):
	match panel_style:
		"modal":
			# Larger shadow for modals
			style.shadow_size = theme_constants.shadows.size_large
			style.shadow_offset = theme_constants.shadows.offset_large
			style.shadow_color = theme_constants.shadows.color_large
		"card":
			# Medium shadow for cards
			style.shadow_size = theme_constants.shadows.size_medium
			style.shadow_offset = theme_constants.shadows.offset_medium
			style.shadow_color = theme_constants.shadows.color_medium
		_:
			# Default shadow
			style.shadow_size = theme_constants.panel_style_config.shadow_size
			style.shadow_offset = Vector2(0, theme_constants.panel_style_config.shadow_offset_y)
			style.shadow_color = theme_constants.panel_style_config.shadow_color

func _apply_transparent_style():
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)

# Special methods for tier column states (battle pass)
func set_tier_state(state: String):
	var theme_constants = ThemeConstants
	if not theme_constants:
		return
	
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if not style:
		return
	
	match state:
		"locked":
			style.bg_color = theme_constants.battle_pass_style.tier_bg_locked
			style.border_color = theme_constants.colors.gray_300
			style.set_border_width_all(0)
		"claimable":
			style.bg_color = theme_constants.battle_pass_style.tier_bg
			style.border_color = theme_constants.colors.primary
			style.set_border_width_all(theme_constants.borders.width_medium)
		"claimed":
			style.bg_color = theme_constants.battle_pass_style.tier_bg
			style.border_color = theme_constants.colors.gray_400
			style.set_border_width_all(theme_constants.borders.width_thin)
		_:
			style.bg_color = theme_constants.battle_pass_style.tier_bg
			style.border_color = theme_constants.battle_pass_style.tier_border
			style.set_border_width_all(theme_constants.borders.width_thin)
	
	add_theme_stylebox_override("panel", style)
