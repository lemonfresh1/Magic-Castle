# DisplayItemCard.gd - Compact item/achievement display for MiniProfileCard
# Location: res://Pyramids/scripts/ui/components/DisplayItemCard.gd
# Last Updated: Initial implementation for showcase slots

extends PanelContainer

signal clicked(item_id: String, item_type: String)

# Display types
enum ItemType {
	ACHIEVEMENT,
	ITEM,
	EMPTY
}

# Properties
@export var slot_size: int = 50
@export var padding: int = 3
@export var show_border: bool = true

# Internal
var item_id: String = ""
var item_type: ItemType = ItemType.EMPTY
var icon_texture: Texture2D = null
var is_hovering: bool = false

# Node references
@onready var icon_rect: TextureRect

func _ready() -> void:
	# FIXED: Enforce 50x50 size strictly
	slot_size = 50  # Force to 50
	custom_minimum_size = Vector2(50, 50)
	size = Vector2(50, 50)
	
	# IMPORTANT: Prevent expansion
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create icon TextureRect
	icon_rect = TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Apply padding
	icon_rect.set_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = padding
	icon_rect.offset_top = padding
	icon_rect.offset_right = -padding
	icon_rect.offset_bottom = -padding
	
	add_child(icon_rect)
	
	# Setup style
	_setup_style()
	
	# Connect input
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_achievement(achievement_id: String) -> void:
	"""Display an achievement icon"""
	item_id = achievement_id
	item_type = ItemType.ACHIEVEMENT
	
	if achievement_id == "":
		set_empty()
		return
	
	# Get achievement data
	if not AchievementManager or not AchievementManager.achievements.has(achievement_id):
		print("DisplayItemCard: Achievement not found: ", achievement_id)
		set_empty()
		return
	
	var achievement = AchievementManager.achievements[achievement_id]
	var icon_name = achievement.get("icon", "")
	
	# Load achievement icon
	var icon_path = "res://Pyramids/assets/icons/achievements/" + icon_name
	if ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)
		icon_rect.texture = icon_texture
		_update_visual_state()
	else:
		print("DisplayItemCard: Achievement icon not found: ", icon_path)
		_show_placeholder("A")

func set_item(item_id_param: String) -> void:
	"""Display an item icon"""
	item_id = item_id_param
	item_type = ItemType.ITEM
	
	if item_id == "":
		set_empty()
		return
	
	# Try to get item from ItemManager
	var item_data = null
	if ItemManager and ItemManager.has_method("get_item"):
		item_data = ItemManager.get_item(item_id)
	
	if not item_data:
		print("DisplayItemCard: Item not found: ", item_id)
		_show_placeholder("?")
		return
	
	# Try different icon paths
	var paths_to_try = []
	
	# Add paths from UnifiedItemData pattern
	if item_data.has("icon_path") and item_data.icon_path != "":
		paths_to_try.append(item_data.icon_path)
	if item_data.has("texture_path") and item_data.texture_path != "":
		paths_to_try.append(item_data.texture_path)
	if item_data.has("preview_texture_path") and item_data.preview_texture_path != "":
		paths_to_try.append(item_data.preview_texture_path)
	
	# Add fallback paths based on category
	var category_folder = ""
	if item_data.has_method("get_category_folder"):
		category_folder = item_data.get_category_folder()
	elif item_data.has("category"):
		category_folder = str(item_data.category).to_lower()
	
	if category_folder != "":
		paths_to_try.append("res://Pyramids/assets/icons/%s/%s.png" % [category_folder, item_id])
		paths_to_try.append("res://Magic-Castle/assets/%s/%s.png" % [category_folder, item_id])
	
	# Try to load icon
	var loaded = false
	for path in paths_to_try:
		if ResourceLoader.exists(path):
			icon_texture = load(path)
			icon_rect.texture = icon_texture
			loaded = true
			break
	
	if not loaded:
		print("DisplayItemCard: Item icon not found for: ", item_id)
		_show_placeholder("I")
	
	_update_visual_state()

func set_empty() -> void:
	"""Set to empty state"""
	item_id = ""
	item_type = ItemType.EMPTY
	icon_texture = null
	icon_rect.texture = null
	_update_visual_state()

func _setup_style() -> void:
	"""Setup the panel style"""
	var style = StyleBoxFlat.new()
	
	# Dark semi-transparent background
	style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	
	# Border
	if show_border:
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	
	# Rounded corners
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", style)

func _update_visual_state() -> void:
	"""Update visual based on state"""
	var style = get_theme_stylebox("panel")
	if not style is StyleBoxFlat:
		return
	
	if item_type == ItemType.EMPTY:
		# Empty slot - very transparent
		style.bg_color = Color(0.1, 0.1, 0.1, 0.2)
		style.border_color = Color(0.2, 0.2, 0.2, 0.3)
		modulate.a = 0.5
	else:
		# Has content
		style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
		style.border_color = Color(0.4, 0.4, 0.4, 0.6)
		modulate.a = 1.0
		
		# Check if unlocked (for achievements)
		if item_type == ItemType.ACHIEVEMENT:
			if AchievementManager and not AchievementManager.is_unlocked(item_id):
				modulate.a = 0.3  # Dim if not unlocked
				icon_rect.modulate = Color(0.5, 0.5, 0.5)
			else:
				icon_rect.modulate = Color.WHITE
		
		# Hover effect
		if is_hovering:
			style.border_color = Color(0.6, 0.6, 0.6, 1.0)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2

func _show_placeholder(text: String) -> void:
	"""Show a text placeholder when icon is missing"""
	# Clear texture
	icon_rect.texture = null
	
	# TODO: Create a procedural placeholder texture with the letter
	# For now, just leave empty
	print("TODO: Create placeholder with text: ", text)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if item_type != ItemType.EMPTY:
				print("DisplayItemCard clicked: ", item_id, " (", ItemType.keys()[item_type], ")")
				clicked.emit(item_id, ItemType.keys()[item_type])
				
				# TODO: Show expanded view
				print("TODO: Show expanded view for item")

func _on_mouse_entered() -> void:
	is_hovering = true
	if item_type != ItemType.EMPTY:
		_update_visual_state()
		
		# Small scale animation
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)

func _on_mouse_exited() -> void:
	is_hovering = false
	_update_visual_state()
	
	# Reset scale
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# Public helper to get display info
func get_display_name() -> String:
	match item_type:
		ItemType.ACHIEVEMENT:
			if AchievementManager and AchievementManager.achievements.has(item_id):
				return AchievementManager.achievements[item_id].get("name", item_id)
		ItemType.ITEM:
			if ItemManager and ItemManager.has_method("get_item"):
				var item = ItemManager.get_item(item_id)
				if item and item.has("display_name"):
					return item.display_name
	return item_id

func get_display_description() -> String:
	match item_type:
		ItemType.ACHIEVEMENT:
			if AchievementManager and AchievementManager.achievements.has(item_id):
				return AchievementManager.achievements[item_id].get("description", "")
		ItemType.ITEM:
			if ItemManager and ItemManager.has_method("get_item"):
				var item = ItemManager.get_item(item_id)
				if item and item.has("description"):
					return item.description
	return ""
