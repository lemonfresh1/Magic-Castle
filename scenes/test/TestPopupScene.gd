# PopupTestScene.gd - Comprehensive test scene for all popup types
# Location: res://Pyramids/scripts/test/PopupTestScene.gd
# Last Updated: Created for testing popup system

extends Control

# Scenes
var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

# Test data
var test_stars: int = 500
var test_items = []
var owned_items = ["card_classic", "board_green"]  # Start with defaults
var equipped_items = {"card_front": "card_classic", "board": "board_green", "emoji": []}

# UI References
@onready var star_label: Label
@onready var star_input: SpinBox
@onready var items_grid: GridContainer
@onready var popup_buttons_container: VBoxContainer
@onready var scroll_container: ScrollContainer

func _ready():
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
	header.add_child(star_container)
	
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
	
	# Title
	var title = Label.new()
	title.text = "Popup System Test Scene"
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	
	# Scroll container for all content
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(1000, 600)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 20)
	scroll_container.add_child(content_vbox)
	
	# Section 1: Items (Shop/Inventory simulation)
	var items_section = _create_section("Items (Click to test Purchase/Equip)", content_vbox)
	
	items_grid = GridContainer.new()
	items_grid.columns = 6
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	items_section.add_child(items_grid)
	
	# Section 2: Popup Test Buttons
	var popup_section = _create_section("Direct Popup Tests", content_vbox)
	
	popup_buttons_container = VBoxContainer.new()
	popup_buttons_container.add_theme_constant_override("separation", 10)
	popup_section.add_child(popup_buttons_container)

func _create_section(title: String, parent: Control) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	parent.add_child(section)
	
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	section.add_child(label)
	
	var separator = HSeparator.new()
	section.add_child(separator)
	
	return section

func _load_test_items():
	# Load some test items from ItemManager
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
	
	# Create cards for test items
	for item in test_items:
		var card = unified_item_card_scene.instantiate()
		
		# Determine if owned
		var is_owned = item.id in owned_items
		var display_mode = UnifiedItemCard.DisplayMode.SHOP if not is_owned else UnifiedItemCard.DisplayMode.INVENTORY
		
		card.setup(item, display_mode)
		card.clicked.connect(_on_item_clicked.bind(item))
		
		items_grid.add_child(card)

func _create_popup_test_buttons():
	# Success popup tests
	var success_btn = Button.new()
	success_btn.text = "Test Success Popup (with item)"
	success_btn.pressed.connect(_test_success_with_item)
	popup_buttons_container.add_child(success_btn)
	
	var success_icon_btn = Button.new()
	success_icon_btn.text = "Test Success Popup (battlepass icon)"
	success_icon_btn.pressed.connect(_test_success_with_icon)
	popup_buttons_container.add_child(success_icon_btn)
	
	# Error popup tests
	var error_btn = Button.new()
	error_btn.text = "Test Error Popup (Insufficient Funds)"
	error_btn.pressed.connect(_test_error_insufficient)
	popup_buttons_container.add_child(error_btn)
	
	# Kick/Leave popups
	var kick_btn = Button.new()
	kick_btn.text = "Test Kick Popup"
	kick_btn.pressed.connect(_test_kick_popup)
	popup_buttons_container.add_child(kick_btn)
	
	var leave_btn = Button.new()
	leave_btn.text = "Test Leave Popup"
	leave_btn.pressed.connect(_test_leave_popup)
	popup_buttons_container.add_child(leave_btn)
	
	# Special cases
	var emoji_max_btn = Button.new()
	emoji_max_btn.text = "Test Emoji at Max (4 equipped)"
	emoji_max_btn.pressed.connect(_test_emoji_at_max)
	popup_buttons_container.add_child(emoji_max_btn)
	
	# Reward popup
	var reward_btn = Button.new()
	reward_btn.text = "Test Reward Popup"
	reward_btn.pressed.connect(_test_reward_popup)
	popup_buttons_container.add_child(reward_btn)

# === Item Click Handlers ===

func _on_item_clicked(item: UnifiedItemData):
	var is_owned = item.id in owned_items
	
	if not is_owned:
		# Show purchase popup
		_show_purchase_popup(item)
	else:
		# Show equip popup
		_show_equip_popup(item)

func _show_purchase_popup(item: UnifiedItemData):
	var popup = DialogService.show_purchase(item.display_name, 200, "stars", item.id)
	popup.confirmed.connect(func():
		print("Purchase confirmed: %s" % item.display_name)
		test_stars -= 200
		_update_star_display()
		owned_items.append(item.id)
		_populate_items()
		
		# Show success
		var success = DialogService.show_purchase_success(item.display_name)
	)
	popup.cancelled.connect(func():
		print("Purchase cancelled: %s" % item.display_name)
	)

func _show_equip_popup(item: UnifiedItemData):
	var category = item.get_category_name()
	var popup = DialogService.show_equip(item.display_name, category, item.id)
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

# === Test Button Handlers ===

func _test_success_with_item():
	if test_items.size() > 0:
		DialogService.show_purchase_success(test_items[0].display_name)

func _test_success_with_icon():
	var popup = SuccessPopup.new()
	get_tree().root.add_child(popup)
	popup.setup_with_icon("Battle Pass Purchased!", "You now have access to premium rewards!", 
		"res://Pyramids/assets/ui/bp_star.png", "Awesome!")
	popup.display()

func _test_error_insufficient():
	DialogService.show_insufficient_funds(1000, test_stars, "stars")

func _test_kick_popup():
	var popup = DialogService.show_kick_player("TestPlayer123")
	popup.confirmed.connect(func(): print("Kick confirmed"))
	popup.cancelled.connect(func(): print("Kick cancelled"))

func _test_leave_popup():
	var popup = DialogService.show_leave_lobby()
	popup.confirmed.connect(func(): print("Leave confirmed"))
	popup.cancelled.connect(func(): print("Stay selected"))

func _test_emoji_at_max():
	# Set up 4 emojis equipped
	equipped_items.emoji = ["emoji_cool", "emoji_cry", "emoji_curse", "emoji_love"]
	
	# Try to equip a 5th
	for item in test_items:
		if item.category == UnifiedItemData.Category.EMOJI and item.id not in equipped_items.emoji:
			var popup = DialogService.show_equip(item.display_name, "emoji", item.id)
			break

func _test_reward_popup():
	var rewards = {"stars": 100}
	DialogService.show_reward(rewards)

# === Helpers ===

func _on_stars_changed(value: float):
	test_stars = int(value)
	_update_star_display()

func _update_star_display():
	star_label.text = "Stars: %d" % test_stars
