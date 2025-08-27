# DisplayItemCard.gd - Compact item/achievement display for MiniProfileCard
# Location: res://Pyramids/scripts/ui/components/DisplayItemCard.gd
# Last Updated: Simplified - removed redundant animations and effects

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
var item_data_ref = null  # Store UnifiedItemData reference

# Node references
@onready var icon_rect: TextureRect

func _ready() -> void:
	# Enforce 50x50 size
	custom_minimum_size = Vector2(50, 50)
	size = Vector2(50, 50)
	clip_contents = true
	
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create icon TextureRect
	icon_rect = TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Apply padding
	icon_rect.offset_left = padding
	icon_rect.offset_top = padding
	icon_rect.offset_right = -padding
	icon_rect.offset_bottom = -padding
	
	add_child(icon_rect)
	
	# Setup style
	_setup_style()
	
	# Connect input for clicks only
	gui_input.connect(_on_gui_input)

func set_item(item_id_param: String) -> void:
	"""Display an item icon"""
	item_id = item_id_param
	item_type = ItemType.ITEM
	
	if item_id == "":
		set_empty()
		return
	
	# Get item from ItemManager
	var item_data = null
	if ItemManager:
		item_data = ItemManager.get_item(item_id)
	
	if not item_data:
		set_empty()
		return
	
	# Store reference for expanded view
	item_data_ref = item_data
	
	# Try to load texture
	var paths_to_try = []
	
	if item_data.icon_path:
		paths_to_try.append(item_data.icon_path)
	if item_data.texture_path:
		paths_to_try.append(item_data.texture_path)
	if item_data.preview_texture_path:
		paths_to_try.append(item_data.preview_texture_path)
	
	# Fallback paths
	var category_folder = item_data.get_category_folder()
	if category_folder:
		paths_to_try.append("res://Pyramids/assets/icons/%s/%s.png" % [category_folder, item_id])
		paths_to_try.append("res://Magic-Castle/assets/%s/%s.png" % [category_folder, item_id])
	
	# Load first valid texture
	for path in paths_to_try:
		if ResourceLoader.exists(path):
			icon_rect.texture = load(path)
			break
	
	_update_visual_state()

func set_achievement(achievement_id: String) -> void:
	"""Display an achievement icon"""
	item_id = achievement_id
	item_type = ItemType.ACHIEVEMENT
	
	if achievement_id == "":
		set_empty()
		return
	
	# Get achievement data
	if AchievementManager and AchievementManager.achievements.has(achievement_id):
		var achievement = AchievementManager.achievements[achievement_id]
		var icon_name = achievement.get("icon", "")
		
		var icon_path = "res://Pyramids/assets/icons/achievements/" + icon_name
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
	
	_update_visual_state()

func set_empty() -> void:
	"""Set to empty state"""
	item_id = ""
	item_type = ItemType.EMPTY
	icon_rect.texture = null
	item_data_ref = null
	_update_visual_state()

func _setup_style() -> void:
	"""Setup the panel style"""
	var style = StyleBoxFlat.new()
	
	# Simple dark background
	style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	
	# Simple border
	if show_border:
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)
		style.set_border_width_all(1)
	
	# Small corner radius
	style.set_corner_radius_all(4)
	
	add_theme_stylebox_override("panel", style)

func _update_visual_state() -> void:
	"""Update transparency based on state"""
	if item_type == ItemType.EMPTY:
		modulate.a = 0.5
	else:
		modulate.a = 1.0
		
		# Dim locked achievements
		if item_type == ItemType.ACHIEVEMENT:
			if AchievementManager and not AchievementManager.is_unlocked(item_id):
				icon_rect.modulate = Color(0.5, 0.5, 0.5)
			else:
				icon_rect.modulate = Color.WHITE

func _on_gui_input(event: InputEvent) -> void:
	"""Handle click to show expanded view"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if item_type != ItemType.EMPTY:
				clicked.emit(item_id, ItemType.keys()[item_type])
				
				# Only show expanded view for items
				if item_type == ItemType.ITEM and item_data_ref:
					_show_expanded_view()

func _show_expanded_view() -> void:
	"""Show ItemExpandedView popup"""
	var expanded_popup_scene = load("res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn")
	if not expanded_popup_scene:
		return
	
	var popup = expanded_popup_scene.instantiate()
	get_tree().root.add_child(popup)
	
	if popup.has_method("setup_item"):
		popup.setup_item(item_data_ref)
	
	# Center on screen
	await get_tree().process_frame
	var screen_size = Vector2(get_viewport().size)
	var popup_size = Vector2(popup.size)
	popup.position = (screen_size - popup_size) / 2
	
	if popup.has_signal("closed"):
		popup.closed.connect(func(): popup.queue_free())
