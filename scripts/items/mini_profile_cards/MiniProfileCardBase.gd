# MiniProfileCardBase.gd - Base class for mini profile card styles
# Location: res://Pyramids/scripts/items/mini_profile_cards/MiniProfileCardBase.gd
# Last Updated: Simplified to style data only [August 24, 2025]

class_name MiniProfileCardBase
extends Resource

# Core properties
@export var card_name: String = "base"
@export var display_name: String = "Classic Profile"

# Card dimensions (for reference)
const CARD_WIDTH: int = 200
const CARD_HEIGHT: int = 200

# Main Panel Style
@export var main_bg_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var main_border_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var main_border_width: int = 2
@export var main_corner_radius: int = 8

# Stats Panel Style
@export var stats_bg_color: Color = Color(0.1, 0.1, 0.1, 0.2)
@export var stats_border_color: Color = Color(0.2, 0.2, 0.2, 0.3)
@export var stats_border_width: int = 1
@export var stats_corner_radius: int = 4

# Bottom Section Style
@export var bot_bg_color: Color = Color(0.1, 0.1, 0.1, 0.3)
@export var bot_border_color: Color = Color(0.3, 0.3, 0.3, 0.3)
@export var bot_border_width: int = 1
@export var bot_corner_radius: int = 4

# Accent color for special effects
@export var accent_color: Color = Color("#a487ff")

# Get style for main panel
func get_main_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = main_bg_color
	style.border_color = main_border_color
	style.set_border_width_all(main_border_width)
	style.set_corner_radius_all(main_corner_radius)
	return style

# Get style for stats panel
func get_stats_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = stats_bg_color
	style.border_color = stats_border_color
	style.set_border_width_all(stats_border_width)
	style.set_corner_radius_all(stats_corner_radius)
	style.set_content_margin_all(4)
	return style

# Get style for bottom section
func get_bot_section_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bot_bg_color
	style.border_color = bot_border_color
	style.set_border_width_all(bot_border_width)
	style.set_corner_radius_all(bot_corner_radius)
	return style
