# InventoryItemCard.gd - Individual inventory item display component
# Location: res://Magic-Castle/scripts/ui/inventory/InventoryItemCard.gd
# Last Updated: Updated to match actual scene structure [Date]

extends PanelContainer

signal item_clicked(item_data: ShopManager.ShopItem)
signal preview_requested(item_data: ShopManager.ShopItem)

@onready var icon_texture: TextureRect = $MarginContainer/VBoxContainer/IconContainer/IconTexture
@onready var new_badge: PanelContainer = $MarginContainer/VBoxContainer/IconContainer/NewBadge
@onready var new_label: Label = $MarginContainer/VBoxContainer/IconContainer/NewBadge/Label
@onready var item_name: Label = $MarginContainer/VBoxContainer/NameContainer/ItemName
@onready var equipped_label: Label = $MarginContainer/VBoxContainer/EquippedContainer/Equipped

var item_data: ShopManager.ShopItem
var is_equipped: bool = false

func setup(item: ShopManager.ShopItem):
	item_data = item
	
	# Wait for nodes to be ready if needed
	if not is_node_ready():
		await ready
	
	# Load placeholder icon
	if icon_texture:
		var icon_path = "res://Magic-Castle/assets/placeholder/food/" + item.placeholder_icon
		if FileAccess.file_exists(icon_path):
			icon_texture.texture = load(icon_path)
	
	# Set item name
	if item_name:
		var display_name = item.display_name
		if display_name.length() > 10:
			display_name = display_name.substr(0, 9) + "..."
		
		item_name.text = display_name
		item_name.add_theme_font_size_override("font_size", 12)
	
	# Check equipped status
	_check_equipped_status()
	
	# Update visual state
	_update_visual_state()
	
	# Apply rarity styling
	_apply_rarity_style(item.rarity)

func _check_equipped_status():
	var equipped = ShopManager.shop_data.equipped
	
	match item_data.category:
		"card_skins":
			is_equipped = equipped.card_skin == item_data.id
		"board_skins":
			is_equipped = equipped.board_skin == item_data.id
		"avatars":
			is_equipped = equipped.avatar == item_data.id
		"frames":
			is_equipped = equipped.frame == item_data.id
		"emojis":
			is_equipped = item_data.id in equipped.selected_emojis

func _update_visual_state():
	# Reset visibility
	new_badge.visible = false
	
	# Check if item is new
	if ShopManager.is_item_new(item_data.id):
		new_badge.visible = true
		new_label.text = "NEW"
	
	# Update equipped status text
	if is_equipped:
		equipped_label.text = "Equipped"
		equipped_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))  # Green
		equipped_label.add_theme_font_size_override("font_size", 11)
	else:
		equipped_label.text = "Click to Equip"
		equipped_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))  # Gray
		equipped_label.add_theme_font_size_override("font_size", 10)
	
	# Always clickable in inventory
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modulate = Color.WHITE

func _apply_rarity_style(rarity: ShopManager.Rarity):
	# Create border style based on rarity
	var border_style = StyleBoxFlat.new()
	var color = ShopManager.get_rarity_color(rarity)
	
	border_style.bg_color = Color(1.0, 1.0, 1.0, 0.847)
	border_style.border_color = color
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border_style.corner_radius_top_left = 12
	border_style.corner_radius_top_right = 12
	border_style.corner_radius_bottom_left = 12
	border_style.corner_radius_bottom_right = 12
	
	# Apply glow for higher rarities
	if rarity >= ShopManager.Rarity.EPIC:
		border_style.shadow_color = color
		border_style.shadow_size = 5
		border_style.shadow_offset = Vector2.ZERO
	
	add_theme_stylebox_override("panel", border_style)

func refresh_equipped_status():
	_check_equipped_status()
	_update_visual_state()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			item_clicked.emit(item_data)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			preview_requested.emit(item_data)

func _on_mouse_entered():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Set consistent size
	custom_minimum_size = Vector2(120, 150)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
