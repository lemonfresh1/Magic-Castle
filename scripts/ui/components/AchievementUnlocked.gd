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
	# Set name
	if name_label:
		name_label.text = achievement_data.get("name", "")
	
	# Set icon
	if icon_rect:
		var icon_path = "res://Magic-Castle/assets/icons/achievements/" + achievement_data.get("icon", "")
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
	
	# Set border color based on rarity
	var rarity = achievement_data.get("rarity", AchievementManager.Rarity.COMMON)
	var rarity_color = AchievementManager.get_rarity_color(rarity)
	
	# Create custom stylebox with colored border
	var stylebox = get_theme_stylebox("panel")
	if stylebox:
		stylebox = stylebox.duplicate()
		if stylebox is StyleBoxFlat:
			stylebox.border_color = rarity_color
			add_theme_stylebox_override("panel", stylebox)
	
	pending_setup = false
