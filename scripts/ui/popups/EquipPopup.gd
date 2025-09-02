# EquipPopup.gd - Popup for confirming item equipment with visual display
# Location: res://Pyramids/scripts/ui/popups/EquipPopup.gd
# Last Updated: Revised to match RewardClaimPopup display style

extends PopupBase
class_name EquipPopup

# Item display
var item_container: CenterContainer
var cards_hbox: HBoxContainer  # For emoji replacement scenario
var new_item_card: UnifiedItemCard
var old_item_card: UnifiedItemCard  # For emoji replacement
var arrow_label: Label  # Arrow between items

# Message
var message_label: Label

# Button
var equip_button: StyledButton

# Data
var item_id: String = ""
var item_name: String = ""
var category: String = ""
var old_emoji_id: String = ""  # For emoji replacement

func _ready():
	super._ready()
	set_popup_size(Vector2(350, 250))
	_create_content()

func _create_content():
	# Item display container (centered)
	item_container = CenterContainer.new()
	item_container.custom_minimum_size = Vector2(300, 120)
	content_container.add_child(item_container)
	
	# Message label
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
	message_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
	content_container.add_child(message_label)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 16
	content_container.add_child(spacer)
	
	# Button container
	var button_container = CenterContainer.new()
	content_container.add_child(button_container)
	
	# Equip button
	equip_button = StyledButton.new()
	equip_button.text = "Equip"
	equip_button.button_style = "success"  # Green
	equip_button.button_size = "medium"
	equip_button.custom_minimum_size.x = 120
	equip_button.pressed.connect(_on_equip_pressed)
	button_container.add_child(equip_button)

func setup(title: String, message: String, item_id_param: String, category_param: String):
	"""Setup the equip popup with item details"""
	set_title(title)
	item_id = item_id_param
	category = category_param
	
	# Clear previous content
	for child in item_container.get_children():
		child.queue_free()
	
	# Get item data
	var item = ItemManager.get_item(item_id) if ItemManager else null
	if not item:
		message_label.text = message
		return
	
	# Check if this is an emoji replacement scenario
	var is_emoji_replacement = false
	if category == "emoji" and EquipmentManager:
		var equipped_emojis = EquipmentManager.get_equipped_emojis()
		if equipped_emojis.size() >= 4:
			is_emoji_replacement = true
			old_emoji_id = equipped_emojis[0]  # Will replace the oldest
	
	# Create display based on scenario
	if is_emoji_replacement and old_emoji_id != "":
		_setup_emoji_replacement(item, old_emoji_id)
		message_label.text = "Replace oldest emoji with new one?"
		# Don't resize for emoji replacement - keep at 350x250
		# set_popup_size(Vector2(450, 350))  # REMOVE THIS LINE
	else:
		_setup_single_item(item)
		message_label.text = message

func _setup_single_item(item: UnifiedItemData):
	"""Setup display for a single item - like RewardClaimPopup"""
	# Load UnifiedItemCard scene
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if not ResourceLoader.exists(card_scene_path):
		push_error("UnifiedItemCard scene not found")
		return
	
	var card_scene = load(card_scene_path)
	new_item_card = card_scene.instantiate()
	
	# Use same size as RewardClaimPopup
	new_item_card.custom_minimum_size = Vector2(86, 86)
	new_item_card.size = Vector2(86, 86)
	
	item_container.add_child(new_item_card)
	
	# Setup card with the item data
	new_item_card.setup(item, UnifiedItemCard.DisplayMode.SHOWCASE)
	
	# Apply white panel style like RewardClaimPopup
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.border_color = Color("#E5E7EB")
	style.set_border_width_all(1)
	
	new_item_card.call_deferred("add_theme_stylebox_override", "panel", style)

func _setup_emoji_replacement(new_item: UnifiedItemData, old_id: String):
	"""Setup display for emoji replacement (old -> new)"""
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if not ResourceLoader.exists(card_scene_path):
		push_error("UnifiedItemCard scene not found")
		return
	
	var card_scene = load(card_scene_path)
	
	# Create HBox for side-by-side display
	cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 20)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	item_container.add_child(cards_hbox)
	
	# Old emoji card
	var old_item = ItemManager.get_item(old_id) if ItemManager else null
	if old_item:
		old_item_card = card_scene.instantiate()
		old_item_card.custom_minimum_size = Vector2(86, 86)
		old_item_card.size = Vector2(86, 86)
		old_item_card.modulate.a = 0.5  # Dim the old item
		cards_hbox.add_child(old_item_card)
		
		old_item_card.setup(old_item, UnifiedItemCard.DisplayMode.SHOWCASE)
		
		# Style
		var old_style = StyleBoxFlat.new()
		old_style.bg_color = Color(0.95, 0.95, 0.95)  # Grayed out
		old_style.set_corner_radius_all(12)
		old_style.border_color = Color("#E5E7EB")
		old_style.set_border_width_all(1)
		old_item_card.call_deferred("add_theme_stylebox_override", "panel", old_style)
	
	# Arrow
	arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.add_theme_font_size_override("font_size", 32)
	arrow_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	cards_hbox.add_child(arrow_label)
	
	# New emoji card
	new_item_card = card_scene.instantiate()
	new_item_card.custom_minimum_size = Vector2(86, 86)
	new_item_card.size = Vector2(86, 86)
	cards_hbox.add_child(new_item_card)
	
	new_item_card.setup(new_item, UnifiedItemCard.DisplayMode.SHOWCASE)
	
	# Style with green border to indicate new
	var new_style = StyleBoxFlat.new()
	new_style.bg_color = Color.WHITE
	new_style.set_corner_radius_all(12)
	new_style.border_color = ThemeConstants.colors.primary  # Green border
	new_style.set_border_width_all(2)
	new_item_card.call_deferred("add_theme_stylebox_override", "panel", new_style)

func _on_equip_pressed():
	confirmed.emit()
	close()
