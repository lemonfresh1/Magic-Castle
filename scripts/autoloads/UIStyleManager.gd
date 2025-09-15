# UIStyleManager.gd - Centralized UI styling and layout management
# Location: res://Pyramids/scripts/autoloads/UIStyleManager.gd
# Last Updated: Added comprehensive design system [Date]

# TODO: REFACTOR - Split into theme components (1,199 lines)
# See roadmap: res://docs/CodebaseImprovementRoadmap.md
# Priority: HIGH - Used by 17+ scripts
# Split into:
#   - UIConstants.gd (sizes, spacing)
#   - UIColors.gd (theme colors)
#   - UIFonts.gd (typography)
#   - UIAnimations.gd (transitions)

extends Node

@onready var theme = ThemeConstants

# Debug
var debug_enabled: bool = false  # Per-script debug toggle
var global_debug: bool = false   # Ready for global toggle integration

# Design system colors - from your design doc
var colors = {
	# Primary Colors
	"primary": Color("#10b981"),
	"primary_dark": Color("#059669"),
	"primary_light": Color("#d1fae5"),
	"primary_focus": Color(0.063, 0.725, 0.506, 0.1),
	
	# Play Button Mode Colors
	"play_solo": Color("#10b981"),        # Green (same as primary)
	"play_solo_dark": Color("#059669"),   # Dark green (same as primary_dark)
	"play_multiplayer": Color("#E53935"),  # Red
	"play_multiplayer_dark": Color("#C62828"), # Dark red
	"play_tournament": Color("#FFB300"),   # Gold
	"play_tournament_dark": Color("#F57C00"), # Dark gold

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
	"warning_muted": Color("#FFBD00"), 
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
	"bg_color": Color(1.0, 1.0, 1.0, 1.0),
	"border_color": Color(1.0, 1.0, 1.0, 1.0),
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

var game_style = {
	# Proportional sizes (as percentages)
	"top_bar_height_percent": 0.24,  # 15% of screen
	"board_area_height_percent": 0.76,  # 85% of screen
	"draw_zone_width_percent": 0.08,  # 8% of screen width
	
	# Draw zones - MORE VISIBLE COLORS
	"draw_zone_bg_color": Color(0.1, 0.2, 0.3, 0.1),  # Dark blue-gray with 50% alpha
	"draw_zone_border_color": Color(0.2, 0.4, 0.6, 0.2),  # Matching border
	"draw_zone_text_color": Color(0.9, 0.95, 1.0, 1.0),  # Keep bright white
	"draw_zone_pulse_alpha_min": 0.5,  # Higher minimum
	"draw_zone_pulse_alpha_max": 1.0,  # Full opacity at peak
	"draw_zone_pulse_duration": 1.5,  # Faster pulse
	
	# Top bar - MORE VISIBLE
	"top_bar_bg_color": Color(0.15, 0.15, 0.15, 0.95),  # Darker, more opaque
	"top_bar_border_color": Color(0.4, 0.4, 0.4, 0.5),  # More visible border
	
	# Progress bars
	"timer_bar_bg": Color(0.2, 0.8, 0.2, 0.3),
	"timer_bar_fill": Color(0.2, 0.8, 0.2),
	"combo_bar_bg": Color(0.9, 0.9, 0.2, 0.3),
	"combo_bar_fill": Color(0.9, 0.9, 0.2),
	
	# Cards (keeping some fixed for gameplay consistency)
	"card_width_mobile": 50,
	"card_height_mobile": 70,
	"card_overlap_y": 25,
	"card_spacing_min": 3,
	
	# Animations
	"draw_zone_click_scale": 0.95,
	"draw_zone_click_duration": 0.1
}

var card_colors = {
	"pyramid_gold": Color("#FFD700"),          # Classic gold
	"pyramid_gold_dark": Color("#B8860B"),     # Darker gold
	"pyramid_gold_light": Color("#FFF8DC"),    # Light gold
	"pyramid_sand": Color("#F4E4BC"),          # Sand color
	"pyramid_stone": Color("#8B7355"),         # Stone brown
	"pyramid_copper": Color("#B87333"),        # Copper bronze
	"pyramid_turquoise": Color("#40E0D0"),     # Nile turquoise
	"pyramid_lapis": Color("#26619C"),         # Lapis blue
	"pyramid_emerald": Color("#50C878"),       # Emerald green
	"pyramid_ruby": Color("#E0115F"),          # Ruby red
	"pyramid_obsidian": Color("#2F2F2F"),      # Obsidian black
	"pyramid_papyrus": Color("#FDF5E6"),       # Papyrus cream
	"neon_cyan": Color("#00FFFF"),             # Neon cyan
	"neon_magenta": Color("#FF00FF"),          # Neon magenta
	"neon_green": Color("#00FF80"),            # Neon green
	"neon_orange": Color("#FF8000")            # Neon orange
}

var item_card_style = {
	# === CORE SIZES BY LAYOUT ===
	"size_portrait": Vector2(90, 126),
	"size_landscape": Vector2(191, 126),  # 2x portrait width + separator
	"size_reduction": 0.5,  # 50% of original export size
	
	# === CONTEXT-SPECIFIC SIZES ===
	"size_showcase": Vector2(60, 80),
	"size_profile": Vector2(80, 100),
	"size_inventory": Vector2(120, 160),
	"size_shop": Vector2(120, 160),
	"size_game": Vector2(180, 252),  # Full size cards in game
	
	# === GRID CONFIGURATION ===
	"grid_separator": 12,  # Space between cards in grid
	"grid_spacing": 12,
	"grid_slots_card": 1,  # How many columns a card takes
	"grid_slots_board": 2,  # How many columns a board takes
	
	# === LABEL POSITIONING (as percentages of card height) ===
	"label_slot_1_top": 0.55,
	"label_slot_1_bottom": 0.85,
	"label_slot_2_top": 0.85,
	"label_slot_2_bottom": 1.0,
	
	# === FONT SIZES ===
	"font_size_name": 14,
	"font_size_price": 16,
	"font_size_lock": 16,
	"name_size_showcase": 14,
	"name_size_profile": 16,
	"name_size_default": 18,
	
	# === SPACING & PADDING ===
	"card_padding": 8,
	"equipped_badge_margin": 4,
	
	# === VISUAL PROPERTIES ===
	"label_bg_alpha": 0.5,
	"corner_radius": 0,  # No rounded corners
	"shadow_size": 4,
	"shadow_alpha": 0.3,
	
	# === EQUIPPED INDICATOR ===
	"equipped_badge_size": 24,
	"equipped_badge_color": Color("#10b981"),
	
	# === LOCK OVERLAY ===
	"lock_overlay_opacity": 0.8,
	"lock_text_color": Color.WHITE,
	
	# === BORDERS ===
	"card_border_width_normal": 2,
	"card_border_width_epic": 3,
	"border_use_rounded": false  # Explicitly no rounded corners
}

var mode_colors = {
	"test": {
		"primary": Color(0.3, 0.8, 0.3),  # Green
		"dark": Color(0.2, 0.6, 0.2)
	},
	"classic": {
		"primary": Color(0.2, 0.5, 0.8),  # Blue
		"dark": Color(0.15, 0.4, 0.65)
	},
	"timed_rush": {
		"primary": Color(0.9, 0.3, 0.3),  # Red
		"dark": Color(0.7, 0.2, 0.2)
	},
	"zen": {
		"primary": Color(0.5, 0.7, 0.9),  # Light blue
		"dark": Color(0.4, 0.6, 0.8)
	},
	"daily_challenge": {
		"primary": Color(0.9, 0.7, 0.2),  # Gold/Yellow
		"dark": Color(0.7, 0.5, 0.1)
	},
	"puzzle_master": {
		"primary": Color(0.7, 0.4, 0.9),  # Purple
		"dark": Color(0.6, 0.3, 0.8)
	}
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
	_debug_log("Initializing...")
	
	# Safe redirect - if ThemeConstants loaded, use it; otherwise fall back to local
	if theme:
		_debug_log("ThemeConstants loaded - redirecting variables")
		
		# Redirect all local variables to theme variables
		colors = theme.colors
		typography = theme.typography
		spacing = theme.spacing
		dimensions = theme.dimensions
		borders = theme.borders
		shadows = theme.shadows
		opacity = theme.opacity
		animations = theme.animations
		battle_pass_style = theme.battle_pass_style
		holiday_style = theme.holiday_style
		panel_style_config = theme.panel_style_config
		scroll_config = theme.scroll_config
		filter_style_config = theme.filter_style_config
		game_style = theme.game_style
		card_colors = theme.card_colors
		item_card_style = theme.item_card_style
		mode_colors = theme.mode_colors
		
		_debug_log("Now using ThemeConstants data")
		_debug_log("Redirected %d theme dictionaries" % 16)
	else:
		push_error("⚠️ ThemeConstants not found - using local fallback data")
		_debug_log("ERROR: ThemeConstants not found in autoloads")
		_debug_log("Check that ThemeConstants loads BEFORE UIStyleManager")
	
	print("UIStyleManager ready - using %s data source" % ("ThemeConstants" if theme else "local"))

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[UISTYLEMANAGER] %s" % message)

# Helper functions to access design system values
func get_color(color_name: String) -> Color:
	var result = colors.get(color_name, Color.WHITE)
	_debug_log("get_color('%s') = %s" % [color_name, result])
	return result

func get_rank_color(tier: String) -> Color:
	"""Get color for rank tiers using existing color palette"""
	match tier.to_lower():
		"bronze": return colors.warning_muted  # Bronzish #FFBD00
		"silver": return colors.gray_400       # Silver gray
		"gold": return colors.warning          # Gold #f59e0b
		"platinum": return colors.info         # Blue #3b82f6
		"diamond": return colors.premium       # Purple #8b5cf6
		_: return colors.gray_500

func get_spacing(key: String) -> int:
	var result = spacing.get(key, spacing.space_4)
	_debug_log("get_spacing('%s') = %d" % [key, result])
	return result

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

func apply_panel_style_no_shadow(panel: PanelContainer, panel_id: String = "") -> void:
	"""Apply panel styling WITHOUT shadow"""
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
	
	# NO SHADOW - that's the difference
	style.shadow_size = 0
	
	# Apply the style
	panel.add_theme_stylebox_override("panel", style)
	
	# Track the panel if it has an ID
	if panel_id != "":
		styled_panels[panel_id] = panel

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
	
	# Special handling for transparent buttons
	if button_type == "transparent" or button_type == "icon_only":
		var empty_style = StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty_style)
		button.add_theme_stylebox_override("hover", empty_style)
		button.add_theme_stylebox_override("pressed", empty_style)
		button.add_theme_stylebox_override("disabled", empty_style)
		button.add_theme_stylebox_override("focus", empty_style)
		
		button.add_theme_color_override("font_color", Color.TRANSPARENT)
		button.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
		button.add_theme_color_override("icon_normal_color", Color.WHITE)
		button.add_theme_color_override("icon_hover_color", Color.WHITE)
		button.add_theme_color_override("icon_pressed_color", Color.WHITE)
		button.add_theme_color_override("icon_disabled_color", Color(0.5, 0.5, 0.5))
		
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("button_type", button_type)
		return
	
	# Regular button styling continues below
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	var style_disabled = StyleBoxFlat.new()
	
	# Base styling
	match button_type:
		"primary":
			style_normal.bg_color = colors.primary
			style_hover.bg_color = colors.primary_dark
			style_disabled.bg_color = colors.primary
			button.add_theme_color_override("font_color", colors.white)
			button.add_theme_color_override("font_disabled_color", colors.white)
		"danger":
			style_normal.bg_color = colors.error
			style_hover.bg_color = colors.error.darkened(0.1)
			style_disabled.bg_color = colors.error
			button.add_theme_color_override("font_color", colors.white)
			button.add_theme_color_override("font_disabled_color", colors.white)
		"success":
			style_normal.bg_color = colors.success
			style_hover.bg_color = colors.primary_dark
			style_disabled.bg_color = colors.error
			button.add_theme_color_override("font_color", colors.white)
			button.add_theme_color_override("font_disabled_color", colors.white)
		"warning":
			style_normal.bg_color = colors.warning_muted
			style_hover.bg_color = colors.warning_muted.darkened(0.1)
			style_disabled.bg_color = colors.warning_muted
			button.add_theme_color_override("font_color", colors.gray_900)
			button.add_theme_color_override("font_disabled_color", colors.gray_900)
		"secondary":
			style_normal.bg_color = colors.white
			style_hover.bg_color = colors.gray_50
			style_disabled.bg_color = colors.white
			style_normal.border_color = colors.gray_200
			style_normal.set_border_width_all(borders.width_thin)
			style_disabled.border_color = colors.gray_200
			style_disabled.set_border_width_all(borders.width_thin)
			button.add_theme_color_override("font_color", colors.gray_700)
			button.add_theme_color_override("font_disabled_color", colors.gray_700)
		_:
			style_normal.bg_color = colors.white
			style_hover.bg_color = colors.gray_50
			style_disabled.bg_color = colors.white
			button.add_theme_color_override("font_color", colors.gray_600)
			button.add_theme_color_override("font_disabled_color", colors.gray_600)
	
	# Size-based adjustments
	match size:
		"large":
			button.custom_minimum_size.y = dimensions.action_button_height
			button.add_theme_font_size_override("font_size", typography.size_body_large)
			style_normal.set_corner_radius_all(dimensions.corner_radius_medium)
		"small":
			button.custom_minimum_size.y = dimensions.small_button_height
			button.add_theme_font_size_override("font_size", typography.size_body_small)
			style_normal.set_corner_radius_all(dimensions.corner_radius_small)
		"medium":
			button.custom_minimum_size.y = dimensions.medium_button_height
			button.add_theme_font_size_override("font_size", typography.size_body)
			style_normal.set_corner_radius_all(dimensions.corner_radius_medium)
		_:
			button.add_theme_font_size_override("font_size", typography.size_body)
			style_normal.set_corner_radius_all(dimensions.corner_radius_medium)
	
	# Content margins
	style_normal.content_margin_left = spacing.button_padding_h
	style_normal.content_margin_right = spacing.button_padding_h
	style_normal.content_margin_top = spacing.button_padding_v
	style_normal.content_margin_bottom = spacing.button_padding_v
	
	# Copy styling to other states
	style_hover = style_normal.duplicate()
	style_pressed = style_normal.duplicate()
	style_disabled = style_normal.duplicate()
	
	# Adjust hover state
	if button_type == "warning":
		style_hover.bg_color = colors.warning_muted.darkened(0.15)
	
	# Add hover shadow for non-transparent buttons
	var shadow = get_shadow_config("small")
	style_hover.shadow_size = shadow.size
	style_hover.shadow_color = shadow.color
	style_hover.shadow_offset = shadow.offset
	
	# Apply styles
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("button_type", button_type)

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
	
	scroll.horizontal_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_NEVER

	
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

#GAME

# Screen size helpers 
func get_screen_size() -> Vector2:
	"""Get the actual current screen/viewport size"""
	# Since UIStyleManager is an autoload, we can access the viewport from anywhere
	var viewport = get_viewport()
	if viewport:
		return viewport.get_visible_rect().size
	else:
		# Fallback for edge cases during initialization
		return Vector2(1200.0, 540.0)

func get_proportional_size(base_value: float, axis: String = "width") -> float:
	"""Convert a base value to screen-proportional size
	Base reference is 1200x540 (our design resolution)"""
	var screen = get_screen_size()
	var base_width = 1200.0   # Our design reference width
	var base_height = 540.0   # Our design reference height
	
	if axis == "width":
		return base_value * (screen.x / base_width)
	else:
		return base_value * (screen.y / base_height)

func get_scale_factor() -> float:
	"""Get a uniform scale factor based on the smaller dimension
	Useful for keeping aspect ratios consistent"""
	var screen = get_screen_size()
	var width_scale = screen.x / 1200.0
	var height_scale = screen.y / 540.0
	return min(width_scale, height_scale)

func is_portrait_mode() -> bool:
	"""Check if device is in portrait orientation"""
	var screen = get_screen_size()
	return screen.y > screen.x

func get_safe_area_margins() -> Dictionary:
	"""Get safe area margins for notches/rounded corners
	TODO: Implement actual safe area detection for mobile"""
	# For now, return conservative margins
	var screen = get_screen_size()
	return {
		"top": 20 if is_portrait_mode() else 0,
		"bottom": 20 if is_portrait_mode() else 0,
		"left": 20,
		"right": 20
	}

func get_game_dimension(key: String) -> float:
	"""Get game-specific dimensions based on screen size"""
	var screen = get_screen_size()
	
	match key:
		"top_bar_height":
			return screen.y * game_style.top_bar_height_percent
		"board_area_height":
			return screen.y * game_style.board_area_height_percent
		"draw_zone_width":
			return screen.x * game_style.draw_zone_width_percent
		_:
			# Check if it's in game_style as a direct value
			return game_style.get(key, 100.0)

# Game-specific styling functions
func apply_game_progress_bar_style(progress_bar: ProgressBar, bar_type: String = "timer") -> void:
	"""Apply game-specific progress bar styling"""
	var bg_style = StyleBoxFlat.new()
	var fill_style = StyleBoxFlat.new()
	
	match bar_type:
		"timer":
			bg_style.bg_color = game_style.timer_bar_bg
			fill_style.bg_color = game_style.timer_bar_fill
		"combo":
			bg_style.bg_color = game_style.combo_bar_bg
			fill_style.bg_color = game_style.combo_bar_fill
		_:
			bg_style.bg_color = colors.gray_200
			fill_style.bg_color = colors.primary
	
	# Common styling
	bg_style.set_corner_radius_all(dimensions.corner_radius_small)
	fill_style.set_corner_radius_all(dimensions.corner_radius_small)
	
	progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func apply_draw_zone_style(zone: Control) -> StyleBoxFlat:
	"""Create and return draw zone style"""
	var style = StyleBoxFlat.new()
	style.bg_color = game_style.draw_zone_bg_color
	style.border_color = game_style.draw_zone_border_color
	style.set_border_width_all(borders.width_medium)
	style.set_corner_radius_all(dimensions.corner_radius_small)
	return style

func apply_top_bar_panel_style(panel: Panel) -> void:
	"""Apply top bar specific panel styling - white with shadow like other panels"""
	var style = StyleBoxFlat.new()
	
	# Use white background with slight transparency like other panels
	style.bg_color = Color(1.0, 1.0, 1.0, 0.95)  # White with 95% opacity
	
	# Add rounded corners
	style.set_corner_radius_all(dimensions.corner_radius_medium)
	
	# Add shadow for depth (downward shadow)
	style.shadow_size = shadows.size_medium
	style.shadow_offset = Vector2(0, 2)
	style.shadow_color = shadows.color_medium
	
	panel.add_theme_stylebox_override("panel", style)

func create_draw_zone_animation(zone: Control, available: bool = true) -> void:
	"""Create pulse animation for draw zone when cards available"""
	if not available:
		zone.modulate.a = 0.3
		return
	
	# Create pulse tween
	var tween = zone.create_tween()
	tween.set_loops()
	tween.tween_property(zone, "modulate:a", game_style.draw_zone_pulse_alpha_max, game_style.draw_zone_pulse_duration / 2)
	tween.tween_property(zone, "modulate:a", game_style.draw_zone_pulse_alpha_min, game_style.draw_zone_pulse_duration / 2)

func animate_draw_zone_click(zone: Control) -> void:
	"""Animate draw zone on click"""
	var tween = zone.create_tween()
	tween.tween_property(zone, "scale", Vector2.ONE * game_style.draw_zone_click_scale, game_style.draw_zone_click_duration)
	tween.tween_property(zone, "scale", Vector2.ONE, game_style.draw_zone_click_duration)

func apply_label_style(label: Label, style_type: String = "body") -> void:
	"""Apply consistent label styling based on type"""
	match style_type:
		"header":
			label.add_theme_font_size_override("font_size", typography.size_title)  # Use existing 24
			label.add_theme_color_override("font_color", colors.gray_900)
		"title":
			label.add_theme_font_size_override("font_size", typography.size_title)  # Use existing 24
			label.add_theme_color_override("font_color", colors.gray_900)
		"body":
			label.add_theme_font_size_override("font_size", typography.size_body)  # Existing 18
			label.add_theme_color_override("font_color", colors.gray_700)
		"body_small":
			label.add_theme_font_size_override("font_size", typography.size_body_small)  # Existing 16
			label.add_theme_color_override("font_color", colors.gray_700)
		"caption":
			label.add_theme_font_size_override("font_size", typography.size_caption)  # Existing 14
			label.add_theme_color_override("font_color", colors.gray_600)
		"overlay":
			label.add_theme_font_size_override("font_size", typography.size_body_small)  # Use existing 16
			label.add_theme_color_override("font_color", colors.white)
		"success":
			label.add_theme_font_size_override("font_size", typography.size_body)  # Existing 18
			label.add_theme_color_override("font_color", colors.success)
		"error":
			label.add_theme_font_size_override("font_size", typography.size_body)  # Existing 18
			label.add_theme_color_override("font_color", colors.error)

func apply_menu_button_style(button: Button, button_type: String = "default") -> void:
	"""Apply menu button styling for main menu buttons"""
	# Get the panel if it exists
	var main_panel = button.get_node_or_null("MainPanel")
	if not main_panel or not main_panel is PanelContainer:
		return
	
	# Get the label and icon for styling
	var label = button.get_node_or_null("MainPanel/MarginContainer/Label")
	var icon = button.get_node_or_null("MainPanel/MarginContainer/Icon")
	
	# Create panel style
	var panel_style = StyleBoxFlat.new()
	
	# Configure based on button type and SET SIZE DIRECTLY
	if button_type == "play":
		# Play button - green, larger but flatter
		panel_style.bg_color = colors.primary
		panel_style.border_color = colors.primary_dark
		
		# Set size directly on the button
		button.size = Vector2(300, 70)
		button.custom_minimum_size = Vector2(300, 70)
		
		# Also set the panel size
		main_panel.custom_minimum_size = Vector2(300, 70)
		main_panel.size = Vector2(300, 70)
		
		# FULLY ROUNDED for play button (35px = half of 70px height)
		panel_style.set_corner_radius_all(35)
		
		if label:
			label.add_theme_color_override("font_color", colors.white)
			label.add_theme_font_size_override("font_size", typography.size_title)  # 24px
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			
			# Center the label in the full button width
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		# Default buttons - white background, flatter
		panel_style.bg_color = colors.white
		panel_style.border_color = colors.gray_300
		
		# Set size directly on the button
		button.size = Vector2(300, 48)
		button.custom_minimum_size = Vector2(300, 48)
		
		# Also set the panel size
		main_panel.custom_minimum_size = Vector2(300, 48)
		main_panel.size = Vector2(300, 48)
		
		# Fully rounded for other buttons too (24px = half of 48px height)
		panel_style.set_corner_radius_all(24)
		
		if label:
			label.add_theme_color_override("font_color", colors.gray_900)
			label.add_theme_font_size_override("font_size", typography.size_body)  # 18px
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.08))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			
			# Center the label in the full button width
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Common styling for all menu buttons
	panel_style.set_border_width_all(borders.width_thin)  # 1px border
	
	# Add shadow
	panel_style.shadow_size = shadows.size_small
	panel_style.shadow_offset = shadows.offset_small
	panel_style.shadow_color = Color(0, 0, 0, 0.1)
	
	# Apply the style to the panel
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Configure margins
	var margin_container = button.get_node_or_null("MainPanel/MarginContainer")
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", spacing.space_8)  # 16px
		margin_container.add_theme_constant_override("margin_right", spacing.space_4)
		margin_container.add_theme_constant_override("margin_top", spacing.space_2)   # 8px
		margin_container.add_theme_constant_override("margin_bottom", spacing.space_2) # 8px
	
	# Position icon absolutely on the left
	if icon:
		icon.visible = true
		
		# Position icon on the left with custom anchors
		icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		icon.anchor_left = 0.0
		icon.anchor_top = 0.5
		icon.anchor_right = 0.0
		icon.anchor_bottom = 0.5
		
		if button_type == "play":
			icon.modulate = colors.white
			icon.custom_minimum_size = Vector2(32, 32)
			icon.position.x = 20  # Push it 20px from the left edge
			icon.position.y = -16  # Center vertically (half of icon height)
		else:
			icon.modulate = colors.gray_700
			icon.custom_minimum_size = Vector2(24, 24)
			icon.position.x = 16  # Push it 16px from the left edge
			icon.position.y = -12  # Center vertically (half of icon height)
		
		icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Remove focus rectangle
	var empty_style = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("focus", empty_style)
	
	# For pressed state
	if button_type != "play":
		# Create pressed state style
		var pressed_style = panel_style.duplicate()
		pressed_style.bg_color = colors.gray_100
		pressed_style.border_color = colors.primary
		pressed_style.set_border_width_all(borders.width_medium)
		
		# Store the styles on the button for toggle functionality
		button.set_meta("normal_style", panel_style)
		button.set_meta("pressed_style", pressed_style)

func get_card_color(color_name: String) -> Color:
	return card_colors.get(color_name, Color.WHITE)

func apply_item_card_style(card: PanelContainer, mode: String = "inventory") -> void:
	"""Apply consistent item card styling"""
	var style = StyleBoxFlat.new()
	
	# Background
	style.bg_color = colors.white
	
	# Border
	style.border_color = colors.gray_200
	style.set_border_width_all(borders.width_thin)
	
	# Corner radius
	style.set_corner_radius_all(dimensions.corner_radius_medium)
	
	# Shadow
	style.shadow_size = shadows.size_small
	style.shadow_offset = shadows.offset_small
	style.shadow_color = shadows.color_default
	
	card.add_theme_stylebox_override("panel", style)
	
	# Set size based on mode
	match mode:
		"showcase":
			card.custom_minimum_size = item_card_style.size_showcase
		"profile":
			card.custom_minimum_size = item_card_style.size_profile
		_:
			card.custom_minimum_size = item_card_style.size_inventory

func apply_item_card_rarity_border(card: PanelContainer, rarity: String) -> void:
	"""Apply rarity-based border glow to item card"""
	var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	
	match rarity:
		"epic", "legendary", "mythic":
			var color = get_rarity_color(rarity)
			style.border_color = color
			style.set_border_width_all(borders.width_medium)
			# Add glow
			style.shadow_color = color
			style.shadow_color.a = 0.3
			style.shadow_size = shadows.size_medium
	
	card.add_theme_stylebox_override("panel", style)

func get_rarity_color(rarity: String) -> Color:
	"""Get the color for a rarity tier"""
	match rarity:
		"common": return colors.gray_500
		"uncommon": return colors.success
		"rare": return colors.info
		"epic": return colors.premium
		"legendary": return colors.warning
		"mythic": return colors.error
		_: return colors.gray_400

func get_item_card_style(key: String):
	"""Safely get item card style value"""
	return item_card_style.get(key, null)

func get_item_card_size(context: String, item_category: UnifiedItemData.Category = UnifiedItemData.Category.CARD_FRONT) -> Vector2:
	"""Get the appropriate card size for a context and item type"""
	# Determine if landscape or portrait
	var is_landscape = item_category == UnifiedItemData.Category.BOARD
	
	# Get base size based on context
	match context:
		"shop":
			return item_card_style.size_landscape if is_landscape else item_card_style.size_portrait
		"inventory":
			return item_card_style.size_landscape if is_landscape else item_card_style.size_portrait
		"profile":
			return Vector2(140, 98) if is_landscape else Vector2(70, 98)  # Smaller for profile
		"showcase":
			return item_card_style.size_showcase
		"game":
			return item_card_style.size_game
		_:
			return item_card_style.size_portrait

func get_border_width(key: String) -> int:
	"""Get border width value"""
	return borders.get(key, 2)

func get_grid_slots_needed(item_category: UnifiedItemData.Category) -> int:
	"""How many grid columns does this item category need?"""
	match item_category:
		UnifiedItemData.Category.BOARD:
			return item_card_style.grid_slots_board
		_:
			return item_card_style.grid_slots_card

func apply_menu_gradient_background(target_node: Control) -> void:
	"""Apply standard menu gradient background to any screen"""
	# Use existing Background node if it exists
	var bg_rect = target_node.get_node_or_null("Background")
	if not bg_rect:
		bg_rect = ColorRect.new()
		bg_rect.name = "Background"
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		target_node.add_child(bg_rect)
		target_node.move_child(bg_rect, 0)
	
	# Create gradient texture
	var gradient = Gradient.new()
	var gradient_texture = GradientTexture2D.new()
	
	# Set gradient colors - dark forest green to lighter sage green
	gradient.add_point(0.0, Color(0.1, 0.25, 0.15))  # Dark forest green
	gradient.add_point(1.0, Color(0.25, 0.45, 0.3))  # Lighter sage green
	
	# Apply gradient vertically
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)
	
	# Apply to background
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform sampler2D gradient_texture;
	
	void fragment() {
		vec4 gradient_color = texture(gradient_texture, vec2(0.5, UV.y));
		COLOR = gradient_color;
	}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("gradient_texture", gradient_texture)
	
	bg_rect.material = material
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_mode_color(mode_id: String, variant: String = "primary") -> Color:
	"""Get color for a specific game mode"""
	var mode_id_lower = mode_id.to_lower().replace(" ", "_")
	
	# Handle display names -> IDs
	var id_map = {
		"classic": "classic",
		"rush": "timed_rush",
		"zen": "zen",
		"challenge": "daily_challenge",
		"puzzle": "puzzle_master",
		"test": "test",
	}
	
	var mapped_id = id_map.get(mode_id_lower, mode_id_lower)
	
	if mode_colors.has(mapped_id):
		return mode_colors[mapped_id].get(variant, colors.primary)
	
	# Fallback to primary color
	return colors.primary if variant == "primary" else colors.primary_dark

func debug_verify_theme_bridge() -> void:
	_debug_log("=== THEME BRIDGE VERIFICATION ===")
	_debug_log("Theme loaded: %s" % (theme != null))
	if theme:
		_debug_log("Sample color test:")
		_debug_log("  colors.primary = %s" % colors.primary)
		_debug_log("  theme.colors.primary = %s" % theme.colors.primary)
		_debug_log("  Match: %s" % (colors.primary == theme.colors.primary))
		
		# Additional verification
		_debug_log("Dictionary references check:")
		_debug_log("  colors dict id: %s" % colors.get_instance_id())
		_debug_log("  theme.colors id: %s" % theme.colors.get_instance_id())
		_debug_log("  Same object: %s" % (colors.get_instance_id() == theme.colors.get_instance_id()))
	else:
		_debug_log("Theme is null - using fallback data")
	_debug_log("=================================")
