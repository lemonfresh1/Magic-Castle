# PopupTestScene.gd - Comprehensive test scene for all popup types (FIXED)
# Location: res://Pyramids/scripts/test/PopupTestScene.gd
# Last Updated: Fixed popup instantiation for scene-based approach

extends Control

# Scenes
var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
var popup_base_scene = preload("res://Pyramids/scenes/ui/popups/PopupBase.tscn")

# Test data
var test_stars: int = 500
var test_items = []
var owned_items = ["card_classic", "board_green"]  # Start with defaults
var equipped_items = {"card_front": "card_classic", "board": "board_green", "emoji": []}

# UI References
var star_label: Label
var star_input: SpinBox
var items_grid: GridContainer
var popup_buttons_container: VBoxContainer
var scroll_container: ScrollContainer

func _ready():
	# Set control size
	custom_minimum_size = Vector2(1200, 540)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_create_ui()
	_load_test_items()
	_populate_items()
	_create_popup_test_buttons()

func _create_ui():
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# Header with star balance
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)
	
	var star_container = HBoxContainer.new()
	star_container.add_theme_constant_override("separation", 10)
	header.add_child(star_container)
	
	var star_icon = Label.new()
	star_icon.text = "⭐"
	star_icon.add_theme_font_size_override("font_size", 24)
	star_container.add_child(star_icon)
	
	star_label = Label.new()
	star_label.text = "Stars: %d" % test_stars
	star_label.add_theme_font_size_override("font_size", 24)
	star_container.add_child(star_label)
	
	star_input = SpinBox.new()
	star_input.value = test_stars
	star_input.max_value = 9999
	star_input.min_value = 0
	star_input.value_changed.connect(_on_stars_changed)
	star_container.add_child(star_input)
	
	# Add spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Title
	var title = Label.new()
	title.text = "Popup System Test Scene"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	header.add_child(title)
	
	# Scroll container for all content
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(1000, 450)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 20)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_vbox)
	
	# Section 1: Items (Shop/Inventory simulation)
	var items_section = _create_section("Items (Click to test Purchase/Equip)", content_vbox)
	
	items_grid = GridContainer.new()
	items_grid.columns = 6
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	items_section.add_child(items_grid)
	
	# Add owned/unowned indicators
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 20)
	items_section.add_child(legend)
	
	var unowned_label = Label.new()
	unowned_label.text = "🛒 = Unowned (click to purchase)"
	unowned_label.add_theme_font_size_override("font_size", 14)
	legend.add_child(unowned_label)
	
	var owned_label = Label.new()
	owned_label.text = "✓ = Owned (click to equip)"
	owned_label.add_theme_font_size_override("font_size", 14)
	legend.add_child(owned_label)
	
	# Section 2: Popup Test Buttons
	var popup_section = _create_section("Direct Popup Tests", content_vbox)
	
	popup_buttons_container = VBoxContainer.new()
	popup_buttons_container.add_theme_constant_override("separation", 10)
	popup_section.add_child(popup_buttons_container)

func _create_section(title: String, parent: Control) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	parent.add_child(section)
	
	# Section header
	var header = HBoxContainer.new()
	section.add_child(header)
	
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	header.add_child(label)
	
	var separator = HSeparator.new()
	section.add_child(separator)
	
	return section

func _load_test_items():
	if not ItemManager:
		push_error("ItemManager not available")
		return
	
	# Get variety of items for testing
	var categories = ["card_fronts", "card_backs", "boards", "emojis", "avatars", "frames"]
	for category in categories:
		var items = ItemManager.get_items_by_category(category)
		for item in items:
			if test_items.size() >= 18:  # Limit for testing
				break
			test_items.append(item)
		if test_items.size() >= 18:
			break

func _populate_items():
	# Clear grid
	for child in items_grid.get_children():
		child.queue_free()
	
	# Wait for cleanup
	await get_tree().process_frame
	
	# Create cards
	for item in test_items:
		if not item is UnifiedItemData:
			continue
			
		var card = unified_item_card_scene.instantiate()
		items_grid.add_child(card)
		
		var is_owned = item.id in owned_items
		var display_mode = UnifiedItemCard.DisplayMode.SHOP if not is_owned else UnifiedItemCard.DisplayMode.INVENTORY
		
		card.setup(item, display_mode)
		
		# Connect WITHOUT binding - card already emits the item
		card.clicked.connect(_on_item_clicked)

func _create_popup_test_buttons():
	# Row 1: Success variants
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	popup_buttons_container.add_child(row1)
	
	var success_btn = Button.new()
	success_btn.text = "Test Success (with item)"
	success_btn.pressed.connect(_test_success_with_item)
	row1.add_child(success_btn)
	
	var success_icon_btn = Button.new()
	success_icon_btn.text = "Test Success (battlepass)"
	success_icon_btn.pressed.connect(_test_success_with_icon)
	row1.add_child(success_icon_btn)
	
	# Row 2: Error variants
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	popup_buttons_container.add_child(row2)
	
	var error_btn = Button.new()
	error_btn.text = "Test Error (Insufficient Funds)"
	error_btn.pressed.connect(_test_error_insufficient)
	row2.add_child(error_btn)
	
	var error_generic_btn = Button.new()
	error_generic_btn.text = "Test Error (Generic)"
	error_generic_btn.pressed.connect(_test_error_generic)
	row2.add_child(error_generic_btn)
	
	# Row 3: Kick/Leave
	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	popup_buttons_container.add_child(row3)
	
	var kick_btn = Button.new()
	kick_btn.text = "Test Kick Popup"
	kick_btn.pressed.connect(_test_kick_popup)
	row3.add_child(kick_btn)
	
	var leave_btn = Button.new()
	leave_btn.text = "Test Leave Popup"
	leave_btn.pressed.connect(_test_leave_popup)
	row3.add_child(leave_btn)
	
	# Row 4: Special cases
	var row4 = HBoxContainer.new()
	row4.add_theme_constant_override("separation", 10)
	popup_buttons_container.add_child(row4)
	
	var emoji_max_btn = Button.new()
	emoji_max_btn.text = "Test Emoji at Max (4 equipped)"
	emoji_max_btn.pressed.connect(_test_emoji_at_max)
	row4.add_child(emoji_max_btn)
	
	var reward_btn = Button.new()
	reward_btn.text = "Test Reward Popup"
	reward_btn.pressed.connect(_test_reward_popup)
	row4.add_child(reward_btn)
	
	# Row 5: Purchase variations
	var row5 = HBoxContainer.new()
	row5.add_theme_constant_override("separation", 10)
	popup_buttons_container.add_child(row5)
	
	var purchase_item_btn = Button.new()
	purchase_item_btn.text = "Test Purchase (Item)"
	purchase_item_btn.pressed.connect(_test_purchase_item)
	row5.add_child(purchase_item_btn)
	
	var purchase_bp_btn = Button.new()
	purchase_bp_btn.text = "Test Purchase (Battle Pass)"
	purchase_bp_btn.pressed.connect(_test_purchase_battlepass)
	row5.add_child(purchase_bp_btn)

# === HELPER: Create popup with correct scene instantiation ===
func _create_popup(popup_class: Script) -> PopupBase:
	"""Helper to properly instantiate popup from scene with script attached"""
	var popup = popup_base_scene.instantiate()
	popup.set_script(popup_class)
	get_tree().root.add_child(popup)
	return popup

# === Item Click Handlers ===

func _on_item_clicked(item: UnifiedItemData):
	print("Item clicked: %s (owned: %s)" % [item.display_name, item.id in owned_items])
	
	var is_owned = item.id in owned_items
	
	if not is_owned:
		# Show purchase popup
		_show_purchase_popup(item)
	else:
		# Show equip popup
		_show_equip_popup(item)

func _show_purchase_popup(item: UnifiedItemData):
	var popup = _create_popup(PurchasePopup)
	popup.setup_with_item("Confirm Purchase", item, 200, "stars")
	
	popup.confirmed.connect(func():
		print("Purchase confirmed: %s" % item.display_name)
		test_stars -= 200
		_update_star_display()
		owned_items.append(item.id)
		_populate_items()
		
		# Show success
		var success = _create_popup(SuccessPopup)
		success.setup_with_item("Purchase Complete!", "You now own %s!" % item.display_name, item)
		success.display()
	)
	
	popup.cancelled.connect(func():
		print("Purchase cancelled: %s" % item.display_name)
	)
	
	popup.display()

func _show_equip_popup(item: UnifiedItemData):
	var category = item.get_category_name()
	
	# Check for emoji replacement
	if category == "emoji" and equipped_items.emoji.size() >= 4:
		equipped_items.emoji = equipped_items.emoji.slice(0, 4)  # Ensure max 4
	
	var popup = _create_popup(EquipPopup)
	popup.setup("Equip Item", "Equip %s?" % item.display_name, item.id, category)
	
	popup.confirmed.connect(func():
		print("Equip confirmed: %s" % item.display_name)
		
		# Update equipped state
		if category == "emoji":
			if equipped_items.emoji.size() >= 4:
				equipped_items.emoji.erase(equipped_items.emoji[0])
			equipped_items.emoji.append(item.id)
		else:
			equipped_items[category] = item.id
		
		_populate_items()
	)
	
	popup.display()

# === Test Button Handlers ===

func _test_success_with_item():
	if test_items.size() > 0:
		var popup = _create_popup(SuccessPopup)
		popup.setup_with_item("Purchase Complete!", "You now own this item!", test_items[0])
		popup.display()

func _test_success_with_icon():
	var popup = _create_popup(SuccessPopup)
	popup.setup_with_icon("Battle Pass Purchased!", "You now have access to premium rewards!", 
		"res://Pyramids/assets/ui/bp_star.png", "Awesome!")
	popup.display()

func _test_error_insufficient():
	var popup = _create_popup(ErrorPopup)
	popup.setup_insufficient_funds(1000, test_stars)
	popup.display()

func _test_error_generic():
	var popup = _create_popup(ErrorPopup)
	popup.setup("Error", "Something went wrong. Please try again.")
	popup.display()

func _test_kick_popup():
	var popup = _create_popup(KickPopup)
	popup.setup("Kick Player", "", "TestPlayer123")
	popup.confirmed.connect(func(): print("Kick confirmed"))
	popup.cancelled.connect(func(): print("Kick cancelled"))
	popup.display()

func _test_leave_popup():
	var popup = _create_popup(LeavePopup)
	popup.setup("Leave Lobby?", "Are you sure you want to leave the current lobby?")
	popup.confirmed.connect(func(): print("Leave confirmed"))
	popup.cancelled.connect(func(): print("Stay selected"))
	popup.display()

func _test_emoji_at_max():
	# Set up 4 emojis equipped
	equipped_items.emoji = ["emoji_cool", "emoji_cry", "emoji_curse", "emoji_love"]
	
	# Find an emoji item to try to equip
	for item in test_items:
		if item.category == UnifiedItemData.Category.EMOJI and item.id not in equipped_items.emoji:
			owned_items.append(item.id)  # Make sure it's owned
			_show_equip_popup(item)
			break

func _test_reward_popup():
	if not RewardClaimPopup:
		push_error("RewardClaimPopup class not found")
		return
	
	# RewardClaimPopup is different - instantiate directly
	var popup = RewardClaimPopup.new()
	get_tree().root.add_child(popup)
	
	var rewards = {"stars": 100}
	popup.setup(rewards)
	
	# Center it manually since it doesn't extend PopupBase
	popup._center_popup()
	
	# Connect signal if needed
	popup.confirmed.connect(func(): print("Reward popup closed"))

func _test_purchase_item():
	if test_items.size() > 0:
		# Find an unowned item
		for item in test_items:
			if item.id not in owned_items:
				_show_purchase_popup(item)
				break

func _test_purchase_battlepass():
	var popup = _create_popup(PurchasePopup)
	popup.setup_with_icon("Confirm Purchase", "Purchase Premium Battle Pass?", 
		"res://Pyramids/assets/ui/bp_star.png", 999, "stars")
	popup.display()

# === Helpers ===

func _on_stars_changed(value: float):
	test_stars = int(value)
	_update_star_display()

func _update_star_display():
	star_label.text = "Stars: %d" % test_stars
	star_input.set_value_no_signal(test_stars)
