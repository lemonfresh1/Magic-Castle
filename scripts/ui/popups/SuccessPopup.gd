# SuccessPopup.gd - Success confirmation popup with optional item/icon display
# Location: res://Pyramids/scripts/ui/popups/SuccessPopup.gd
# Last Updated: Created with consistent sizing and optional image

extends PopupBase
class_name SuccessPopup

# Display elements
var icon_container: CenterContainer
var item_card: UnifiedItemCard
var icon_texture: TextureRect  # For non-item icons (like battlepass)
var message_label: Label
var confirm_button: StyledButton

func _ready():
	super._ready()
	set_popup_size(Vector2(350, 250))
	_create_content()

func _create_content():
	# Icon/Item container
	icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(300, 100)
	content_container.add_child(icon_container)
	
	# Message
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
	message_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
	content_container.add_child(message_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	content_container.add_child(spacer)
	
	# Button
	var button_container = CenterContainer.new()
	content_container.add_child(button_container)
	
	confirm_button = StyledButton.new()
	confirm_button.text = "Great!"
	confirm_button.button_style = "success"
	confirm_button.button_size = "medium"
	confirm_button.custom_minimum_size.x = 120
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_container.add_child(confirm_button)

func setup(title: String = "Success!", message: String = "", button_text: String = "Great!"):
	set_title(title)
	message_label.text = message
	confirm_button.text = button_text

func setup_with_item(title: String, message: String, item: UnifiedItemData, button_text: String = "Great!"):
	"""Setup with item display"""
	setup(title, message, button_text)
	
	# Clear container
	for child in icon_container.get_children():
		child.queue_free()
	
	# Create item card
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if ResourceLoader.exists(card_scene_path):
		var card_scene = load(card_scene_path)
		item_card = card_scene.instantiate()
		item_card.custom_minimum_size = Vector2(86, 86)
		item_card.size = Vector2(86, 86)
		icon_container.add_child(item_card)
		
		item_card.setup(item, UnifiedItemCard.DisplayMode.SHOWCASE)
		
		# Apply style
		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(12)
		style.border_color = Color("#E5E7EB")
		style.set_border_width_all(1)
		item_card.call_deferred("add_theme_stylebox_override", "panel", style)

func setup_with_icon(title: String, message: String, icon_path: String, button_text: String = "Great!"):
	"""Setup with custom icon (like battlepass)"""
	setup(title, message, button_text)
	
	# Clear container
	for child in icon_container.get_children():
		child.queue_free()
	
	# Create icon
	icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(64, 64)
	icon_texture.size = Vector2(64, 64)
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.add_child(icon_texture)
	
	if ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)

func _on_confirm_pressed():
	confirmed.emit()
	close()
