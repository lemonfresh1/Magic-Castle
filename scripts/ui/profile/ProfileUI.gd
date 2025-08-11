# ProfileUI.gd - Profile interface showing player overview and owned skins
# Location: res://Pyramids/scripts/ui/profile/ProfileUI.gd
# Last Updated: Added ItemManager support for equipping items [Date]

extends PanelContainer

signal profile_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var inventory_item_card_scene = preload("res://Pyramids/scenes/ui/inventory/InventoryItemCard.tscn")

var current_filter: String = "all"
var skin_cards = []

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "profile_ui")
		
	_update_overview()
	_setup_skins_tab()

func _update_overview():
	var overview_tab = tab_container.get_node_or_null("Overview")
	if not overview_tab:
		return
		
	var vbox = overview_tab.find_child("VBoxContainer", true, false)
	if not vbox:
		return
	
	# Clear existing labels
	for child in vbox.get_children():
		child.queue_free()
	
	# Add player info labels
	var name_label = Label.new()
	name_label.text = "Player Name: Stefan"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	vbox.add_child(name_label)
	
	var level_label = Label.new()
	var level = XPManager.current_level if XPManager else 1
	level_label.text = "Player Level: %d" % level
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	vbox.add_child(level_label)
	
	var games_label = Label.new()
	var games = 0
	if StatsManager:
		var stats = StatsManager.get_total_stats()
		games = stats.games_played
	games_label.text = "Games Played: %d" % games
	games_label.add_theme_font_size_override("font_size", 18)
	games_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	vbox.add_child(games_label)

func _setup_skins_tab():
	var skins_tab = tab_container.get_node_or_null("Skins")
	if not skins_tab:
		return
	
	# Connect filter button - it's called "OptionButton" in the scene
	var filter_button = skins_tab.find_child("OptionButton", true, false)
	if filter_button:
		filter_button.clear()
		filter_button.add_item("All")
		filter_button.add_item("Equipped")
		filter_button.add_item("By Rarity")
		if not filter_button.item_selected.is_connected(_on_skins_filter_changed):
			filter_button.item_selected.connect(_on_skins_filter_changed)
		# Apply filter styling with purple theme
		UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
	
	# Fix scroll container sizing
	var scroll_container = skins_tab.find_child("ScrollContainer", true, false)
	if scroll_container:
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(600, 300)
		scroll_container.self_modulate.a = 0  # Make transparent
	
	# Populate skins
	_populate_skins()

func _populate_skins():
	var skins_tab = tab_container.get_node_or_null("Skins")
	if not skins_tab:
		return
		
	var scroll_container = skins_tab.find_child("ScrollContainer", true, false)
	if not scroll_container:
		return
	
	# Create grid if it doesn't exist
	var grid = scroll_container.get_child(0) if scroll_container.get_child_count() > 0 else null
	if not grid:
		grid = GridContainer.new()
		grid.name = "SkinsGrid"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		scroll_container.add_child(grid)
	
	# Get all owned skins (all categories)
	var owned_skins = _get_all_owned_skins()
	_populate_skins_grid(grid, owned_skins)

func _get_all_owned_skins() -> Array:
	var skins = []
	
	# Get owned items from all skin categories - UPDATED CATEGORIES
	var categories = ["card_fronts", "card_backs", "board_skins", "avatars", "frames", "emojis"]
	for category in categories:
		var items = ShopManager.get_items_by_category(category)
		for item in items:
			if ShopManager.is_item_owned(item.id):
				skins.append(item)
	
	return skins

func _populate_skins_grid(grid: GridContainer, skins: Array):
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
	skin_cards.clear()
	
	# Apply current filter
	match current_filter:
		"all":
			# Sort alphabetically
			skins.sort_custom(func(a, b): return a.display_name < b.display_name)
		"equipped":
			# Filter to only equipped
			skins = skins.filter(func(item): return _is_item_equipped(item))
		"rarity":
			# Sort by rarity (highest first)
			skins.sort_custom(func(a, b): return a.rarity > b.rarity)
	
	# Add cards
	for skin in skins:
		var card = inventory_item_card_scene.instantiate()
		card.setup(skin)
		card.item_clicked.connect(_on_skin_clicked)
		grid.add_child(card)
		skin_cards.append(card)
		
		# Connect to refresh when items are equipped
		if ItemManager and not ItemManager.item_equipped.is_connected(_on_item_equipped):
			ItemManager.item_equipped.connect(_on_item_equipped)

func _is_item_equipped(item: ShopManager.ShopItem) -> bool:
	# Check with ItemManager first for ItemManager items
	if ItemManager:
		var category = _get_item_category(item.category)
		if category != -1:
			var equipped_id = ItemManager.get_equipped_item(category)
			return equipped_id == item.id
	
	# Fallback to ShopManager data
	var equipped = ShopManager.shop_data.equipped
	
	match item.category:
		"card_fronts":  # UPDATED
			return equipped.get("card_front", "") == item.id
		"card_backs":   # NEW
			return equipped.get("card_back", "") == item.id
		"board_skins":
			return equipped.board_skin == item.id
		"avatars":
			return equipped.avatar == item.id
		"frames":
			return equipped.frame == item.id
		"emojis":
			return item.id in equipped.selected_emojis
	
	return false

func _get_item_category(shop_category: String) -> ItemData.Category:
	match shop_category:
		"card_fronts": return ItemData.Category.CARD_FRONT  # UPDATED
		"card_backs": return ItemData.Category.CARD_BACK    # NEW
		"board_skins": return ItemData.Category.BOARD
		"avatars": return ItemData.Category.AVATAR
		"frames": return ItemData.Category.FRAME
		"emojis": return ItemData.Category.EMOJI
		_: return -1

func _on_skins_filter_changed(index: int):
	match index:
		0:
			current_filter = "all"
		1:
			current_filter = "equipped"
		2:
			current_filter = "rarity"
	
	_populate_skins()

func _on_skin_clicked(item: ShopManager.ShopItem):
	# Check if item is already equipped
	if _is_item_equipped(item):
		print("Item already equipped: ", item.display_name)
		return  # Don't show dialog
	
	# Create equip dialog using the new custom dialog
	var dialog = preload("res://Pyramids/scripts/ui/dialogs/EquipDialog.gd").new()
	get_tree().root.add_child(dialog)
	
	dialog.setup_for_item(item)
	dialog.item_equipped.connect(_on_item_equipped_from_dialog)
	dialog.popup()

func _direct_equip(item: ShopManager.ShopItem):
	"""Fallback method to equip directly without dialog"""
	var success = false
	
	# Try ItemManager first
	if ItemManager and ItemManager.get_item(item.id):
		success = ItemManager.equip_item(item.id)
		if success:
			# Also update ShopManager for backwards compatibility
			var key = _get_shop_equipped_key(item.category)
			if key != "":
				ShopManager.shop_data.equipped[key] = item.id
				ShopManager.save_shop_data()
	else:
		# Fallback to ShopManager
		success = ShopManager.equip_item(item.id)
	
	if success:
		_refresh_all_cards()

func _get_shop_equipped_key(category: String) -> String:
	match category:
		"card_fronts": return "card_front"  # UPDATED
		"card_backs": return "card_back"    # NEW
		"board_skins": return "board_skin"
		"avatars": return "avatar"
		"frames": return "frame"
		_: return ""

func _on_item_equipped(item_id: String, category: String):
	"""Called when any item is equipped via ItemManager"""
	_refresh_all_cards()

func _on_item_equipped_from_dialog(item_id: String):
	"""Called when item is equipped from dialog"""
	_refresh_all_cards()

func _on_item_unequipped_from_dialog(item_id: String):
	"""Called when item is unequipped from dialog"""
	_refresh_all_cards()

func _refresh_all_cards():
	"""Refresh equipped status on all visible cards"""
	for card in skin_cards:
		if card and is_instance_valid(card) and card.has_method("refresh_equipped_status"):
			card.refresh_equipped_status()
	
	# If showing equipped filter, refresh the grid
	if current_filter == "equipped":
		_populate_skins()

func show_profile():
	visible = true
	_update_overview()
	_populate_skins()

func hide_profile():
	visible = false
	profile_closed.emit()
