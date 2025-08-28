# AchievementUnlocked.gd - Displays unlocked achievement with tier border
# Path: res://Pyramids/scripts/ui/components/AchievementUnlocked.gd
# Shows achievement icon, name, and tier-colored border
extends PanelContainer

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/NameLabel

var pending_setup: bool = false
var achievement_data: Dictionary = {}

func _ready() -> void:
	if pending_setup:
		_apply_setup()

func setup(achievement_id: String) -> void:
	achievement_data = AchievementManager.achievement_definitions.get(achievement_id, {})
	if achievement_data.is_empty():
		return
	
	if not is_node_ready():
		pending_setup = true
		return
		
	_apply_setup()

func _apply_setup() -> void:
	# Set minimum height to match MiniMission (68px)
	custom_minimum_size.y = 68.0
	
	# Get tier color for border
	var tier = achievement_data.get("tier", 1)
	var tier_color = _get_tier_color(tier)
	
	# Apply consistent panel styling with MiniMission
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIStyleManager.colors.white
	panel_style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_medium)
	# 1px border with tier color
	panel_style.border_color = tier_color
	panel_style.set_border_width_all(1)
	# Add left and right margins of 6
	panel_style.content_margin_left = 6
	panel_style.content_margin_right = 6
	add_theme_stylebox_override("panel", panel_style)
	
	# Set name with consistent text styling
	if name_label:
		name_label.text = achievement_data.get("name", "")
		name_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_body)
		name_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
	
	# Set icon
	if icon_rect:
		var icon_path = "res://Pyramids/assets/icons/achievements/" + achievement_data.get("icon", "")
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
	
	pending_setup = false

func _get_tier_color(tier: int) -> Color:
	match tier:
		1:  # Bronze
			return Color(0.72, 0.45, 0.20)
		2:  # Silver
			return Color(0.75, 0.75, 0.75)
		3:  # Gold
			return Color(1.0, 0.84, 0.0)
		_:
			return Color(0.6, 0.6, 0.6)
