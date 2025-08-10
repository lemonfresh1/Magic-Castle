# AchievementUnlocked.gd - Displays unlocked achievement with rarity border
# Path: res://Magic-Castle/scripts/ui/components/AchievementUnlocked.gd
# Shows achievement icon, name, and rarity-colored border

extends PanelContainer

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/NameLabel

var pending_setup: bool = false
var achievement_data: Dictionary = {}

func _ready() -> void:
	if pending_setup:
		_apply_setup()

func setup(achievement_id: String) -> void:
	achievement_data = AchievementManager.achievements.get(achievement_id, {})
	if achievement_data.is_empty():
		return
	
	if not is_node_ready():
		pending_setup = true
		return
		
	_apply_setup()

func _apply_setup() -> void:
	# Set minimum height to match MiniMission (68px)
	custom_minimum_size.y = 68.0
	
	# Get rarity color for border
	var rarity = achievement_data.get("rarity", AchievementManager.Rarity.COMMON)
	var rarity_color = AchievementManager.get_rarity_color(rarity)
	
	# Apply consistent panel styling with MiniMission
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIStyleManager.colors.white
	panel_style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_medium)
	# 1px border with rarity color
	panel_style.border_color = rarity_color
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
		var icon_path = "res://Magic-Castle/assets/icons/achievements/" + achievement_data.get("icon", "")
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
	
	pending_setup = false
