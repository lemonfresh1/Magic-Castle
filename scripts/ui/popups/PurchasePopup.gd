# PurchasePopup.gd - Purchase confirmation popup with item display
# Location: res://Pyramids/scripts/ui/popups/PurchasePopup.gd
# Last Updated: Display item with price button

extends PopupBase
class_name PurchasePopup

# Item display
var item_container: CenterContainer
var item_card: UnifiedItemCard
var icon_texture: TextureRect  # ADD: For battlepass/other icons

# Message
var message_label: Label

# Buttons
var price_button: StyledButton  # Shows price and confirms
var cancel_button: StyledButton

# Data
var item_id: String = ""
var price: int = 0
var currency: String = "stars"

func _ready():
	super._ready()
	set_popup_size(Vector2(350, 250))
	_create_content()

func _create_content():
	# Item display container
	item_container = CenterContainer.new()
	item_container.custom_minimum_size = Vector2(300, 100)
	content_container.add_child(item_container)
	
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
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 16)
	content_container.add_child(button_container)
	
	# Cancel button (red)
	cancel_button = StyledButton.new()
	cancel_button.text = "Cancel"
	cancel_button.button_style = "danger"  # Red
	cancel_button.button_size = "medium"
	cancel_button.custom_minimum_size.x = 100
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)
	
	# Price button (green with price)
	price_button = StyledButton.new()
	price_button.button_style = "success"  # Green
	price_button.button_size = "medium"
	price_button.custom_minimum_size.x = 120
	price_button.pressed.connect(_on_buy_pressed)
	button_container.add_child(price_button)

func setup(title: String, message: String, price_param: int, currency_param: String):
	set_title(title)
	price = price_param
	currency = currency_param
	
	# Parse item from message if possible
	# Message format: "Purchase ItemName for X stars?"
	var item_name = ""
	if "Purchase " in message:
		var parts = message.split(" for ")
		if parts.size() > 0:
			item_name = parts[0].replace("Purchase ", "")
	
	message_label.text = message
	
	# Set price button text
	price_button.text = "%d ⭐" % price
	
	# Try to get and display the item
	if item_name != "" and ItemManager:
		# Try to find item by name
		for item_id_check in ItemManager.all_items:
			var item = ItemManager.get_item(item_id_check)
			if item and item.display_name == item_name:
				_setup_item_display(item)
				break

func setup_with_item(title: String, item: UnifiedItemData, price_param: int, currency_param: String = "stars"):
	"""Alternative setup with direct item reference"""
	set_title(title)
	price = price_param
	currency = currency_param
	item_id = item.id
	
	message_label.text = "Purchase %s?" % item.display_name
	price_button.text = "%d ⭐" % price
	
	_setup_item_display(item)

func setup_with_icon(title: String, message: String, icon_path: String, price_param: int, currency_param: String = "stars"):
	"""Setup with custom icon (like battlepass)"""
	set_title(title)
	price = price_param
	currency = currency_param
	
	message_label.text = message
	price_button.text = "%d ⭐" % price
	
	# Clear container
	for child in item_container.get_children():
		child.queue_free()
	
	# Create icon display
	icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(64, 64)
	icon_texture.size = Vector2(64, 64)
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_container.add_child(icon_texture)
	
	if ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)

func _setup_item_display(item: UnifiedItemData):
	"""Display the item being purchased"""
	# Clear previous
	for child in item_container.get_children():
		child.queue_free()
	
	# Load UnifiedItemCard scene
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if not ResourceLoader.exists(card_scene_path):
		push_error("UnifiedItemCard scene not found")
		return
	
	var card_scene = load(card_scene_path)
	item_card = card_scene.instantiate()
	
	# Same size as RewardClaimPopup
	item_card.custom_minimum_size = Vector2(86, 86)
	item_card.size = Vector2(86, 86)
	
	item_container.add_child(item_card)
	
	# Setup card
	item_card.setup(item, UnifiedItemCard.DisplayMode.SHOP)
	
	# Apply style
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.border_color = Color("#E5E7EB")
	style.set_border_width_all(1)
	
	item_card.call_deferred("add_theme_stylebox_override", "panel", style)

func _on_buy_pressed():
	confirmed.emit()
	close()

func _on_cancel_pressed():
	cancelled.emit()
	close()
