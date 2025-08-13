# InventoryUI.gd - Inventory interface showing owned items
# Location: res://Pyramids/scripts/ui/inventory/InventoryUI.gd
# Last Updated: Minimal cleanup - panel styling and filter buttons only [Date]

extends PanelContainer

signal inventory_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var inventory_item_card_scene = preload("res://Pyramids/scenes/ui/inventory/InventoryItemCard.tscn")

# Tab references mapped by category id
var tabs = {}
var current_filter = "all"
var item_cards = []

# Filter options for inventory
const FILTER_OPTIONS = [
	{"id": "all", "name": "All"},
	{"id": "equipped", "name": "Equipped"},
	{"id": "type", "name": "By Type"},
	{"id": "rarity", "name": "By Rarity"}
]

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "inventory_ui")
	
	# Connect to ItemManager signals for equipment updates
	if ItemManager:
		if not ItemManager.item_equipped.is_connected(_on_item_equipped_signal):
			ItemManager.item_equipped.connect(_on_item_equipped_signal)
		if not ItemManager.item_unequipped.is_connected(_on_item_unequipped_signal):
			ItemManager.item_unequipped.connect(_on_item_unequipped_signal)

	_connect_new_equipment_system()


	_setup_tabs()
	_populate_inventory()

func _setup_tabs():
	# Map existing tabs by their names (no Highlights in inventory)
	tabs = {
		"all": tab_container.get_node_or_null("All"),
		"card_skins": tab_container.get_node_or_null("Cards"),
		"card_backs": tab_container.get_node_or_null("Card Backs"),
		"board_skins": tab_container.get_node_or_null("Boards"),
		"avatars": tab_container.get_node_or_null("Avatars"),
		"frames": tab_container.get_node_or_null("Frames"),
		"emojis": tab_container.get_node_or_null("Emojis"),
		"sounds": tab_container.get_node_or_null("Sounds")
	}
	
	# Remove any null tabs
	var keys_to_remove = []
	for key in tabs:
		if not tabs[key]:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		tabs.erase(key)
	
	# Disable sounds tab if it exists
	if tabs.has("sounds") and tabs["sounds"]:
		var sounds_index = tab_container.get_tab_idx_from_control(tabs["sounds"])
		if sounds_index >= 0:
			tab_container.set_tab_disabled(sounds_index, true)
	
	# Connect filter buttons for each tab
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
			
		# Find the filter button
		var filter_button = tab.find_child("FilterButton", true, false)
		
		# Update filter options for inventory
		if filter_button:
			filter_button.clear()
			# Only show "By Type" and "By Rarity" for "All" tab
			if category_id == "all":
				for option in FILTER_OPTIONS:
					filter_button.add_item(option.name)
			else:
				# Other tabs only get basic filters
				filter_button.add_item("All")
				filter_button.add_item("Equipped")
			
			if not filter_button.item_selected.is_connected(_on_filter_changed):
				filter_button.item_selected.connect(_on_filter_changed.bind(category_id))
			
			# Apply filter styling with purple theme
			UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
		
		# Fix scroll container sizing
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if scroll_container:
			scroll_container.self_modulate.a = 0
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(600, 300)

func _populate_inventory():
	# Populate each tab with owned items only
	for category_id in tabs:
		if category_id == "sounds":
			continue
			
		var items = _get_owned_items_for_category(category_id)
		var tab = tabs[category_id]
		if not tab:
			continue
			
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		
		if scroll_container:
			# Create grid if it doesn't exist
			var grid = scroll_container.get_child(0) if scroll_container.get_child_count() > 0 else null
			if not grid:
				grid = GridContainer.new()
				grid.name = "ItemGrid"
				grid.columns = 4
				grid.add_theme_constant_override("h_separation", 10)
				grid.add_theme_constant_override("v_separation", 10)
				grid.self_modulate.a = 0
				scroll_container.add_child(grid)
			
			_populate_grid(grid, items, category_id)

func _get_owned_items_for_category(category_id: String) -> Array:
	var all_items = []
	
	match category_id:
		"all":
			all_items = ShopManager.get_all_items()
		_:
			all_items = ShopManager.get_items_by_category(category_id)
	
	# Filter to only owned items
	return all_items.filter(func(item): return ShopManager.is_item_owned(item.id))

func _populate_grid(grid: GridContainer, items: Array, tab_id: String):
	# Clear existing items
	for child in grid.get_children():
		child.queue_free()
	
	# Clear tracked cards for this tab
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id") != tab_id)
	
	# Handle different filter modes
	match current_filter:
		"type":
			_populate_grid_by_type(grid, items, tab_id)
		"rarity":
			# Just sort by rarity without headers - like profile UI
			items.sort_custom(func(a, b): return a.rarity > b.rarity)
			for item in items:
				var card = _create_inventory_card(item, tab_id)
				grid.add_child(card)
				item_cards.append(card)
		_:
			# Normal population (alphabetical)
			items.sort_custom(func(a, b): return a.display_name < b.display_name)
			for item in items:
				var card = _create_inventory_card(item, tab_id)
				grid.add_child(card)
				item_cards.append(card)

func _populate_grid_by_type(grid: GridContainer, items: Array, tab_id: String):
	# Group items by type
	var items_by_type = {}
	for item in items:
		if not items_by_type.has(item.category):
			items_by_type[item.category] = []
		items_by_type[item.category].append(item)
	
	# Add items with type headers
	var first_type = true
	for type in ["card_skins", "board_skins", "avatars", "frames", "emojis"]:
		if not items_by_type.has(type):
			continue
			
		# Add spacing between sections (not for first)
		if not first_type:
			_add_grid_spacer_row(grid)
		
		# Create header container that spans full width
		var header_container = HBoxContainer.new()
		header_container.custom_minimum_size = Vector2(520, 30)  # Full width
		
		var type_label = Label.new()
		type_label.text = _get_type_display_name(type)
		type_label.add_theme_font_size_override("font_size", 16)
		type_label.add_theme_color_override("font_color", Color("#a487ff"))
		header_container.add_child(type_label)
		
		grid.add_child(header_container)
		
		# Fill remaining cells in header row
		for i in range(3):
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(1, 1)
			grid.add_child(spacer)
		
		# Sort items alphabetically within type
		items_by_type[type].sort_custom(func(a, b): return a.display_name < b.display_name)
		
		# Add items of this type
		for item in items_by_type[type]:
			var card = _create_inventory_card(item, tab_id)
			grid.add_child(card)
			item_cards.append(card)
		
		first_type = false

func _add_grid_spacer_row(grid: GridContainer):
	# Add a full row of minimal spacers
	for i in range(4):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(1, 20)
		grid.add_child(spacer)

func _get_type_display_name(type: String) -> String:
	match type:
		"card_skins": return "Card Skins"
		"board_skins": return "Board Skins"
		"avatars": return "Avatars"
		"frames": return "Frames"
		"emojis": return "Emojis"
		_: return type.capitalize()

func _get_rarity_display_name(rarity: ShopManager.Rarity) -> String:
	match rarity:
		ShopManager.Rarity.COMMON: return "Common"
		ShopManager.Rarity.UNCOMMON: return "Uncommon"
		ShopManager.Rarity.RARE: return "Rare"
		ShopManager.Rarity.EPIC: return "Epic"
		ShopManager.Rarity.LEGENDARY: return "Legendary"
		ShopManager.Rarity.MYTHIC: return "Mythic"
		_: return "Unknown"

func _create_inventory_card(item: ShopManager.ShopItem, tab_id: String):
	var card = inventory_item_card_scene.instantiate()
	
	# Set metadata
	card.set_meta("tab_id", tab_id)
	card.set_meta("item_data", item)
	
	# Setup the card
	card.setup(item)
	
	# Connect for equip functionality
	if not card.item_clicked.is_connected(_on_item_clicked):
		card.item_clicked.connect(_on_item_clicked)
	
	return card

func _on_filter_changed(index: int, tab_id: String):
	# Get the appropriate filter based on tab
	if tab_id == "all":
		current_filter = FILTER_OPTIONS[index].id
	else:
		# Other tabs have limited options
		current_filter = ["all", "equipped"][index]
	
	_apply_filters(tab_id)

func _apply_filters(tab_id: String):
	var tab = tabs.get(tab_id)
	if not tab:
		return
	
	# Handle special filters that require repopulation
	if current_filter in ["type", "rarity"]:
		_refresh_current_tab()
		return
	
	# Handle regular filters
	var grid = tab.find_child("ItemGrid", true, false)
	if not grid:
		return
	
	for card in grid.get_children():
		if not card.has_meta("item_data"):  # Skip spacers and labels
			continue
			
		var should_show = true
		
		match current_filter:
			"all":
				should_show = true
			"equipped":
				# Check if item is currently equipped
				var item_data = card.get_meta("item_data")
				var equipped_items = ShopManager.shop_data.equipped
				should_show = (
					equipped_items.card_skin == item_data.id or
					equipped_items.board_skin == item_data.id or
					equipped_items.avatar == item_data.id or
					equipped_items.frame == item_data.id or
					item_data.id in equipped_items.selected_emojis
				)
		
		card.visible = should_show

func _on_item_clicked(item: ShopManager.ShopItem):
	# Check if item is already equipped
	if _is_item_already_equipped(item):
		print("Item already equipped: ", item.display_name)
		return  # Don't show dialog
	
	# Create equip dialog
	var dialog = preload("res://Pyramids/scripts/ui/dialogs/EquipDialog.gd").new()
	get_tree().root.add_child(dialog)
	
	dialog.setup_for_item(item)
	dialog.item_equipped.connect(_on_item_equipped)
	dialog.popup()

func _is_item_already_equipped(item: ShopManager.ShopItem) -> bool:
	# Check with ItemManager first for ItemManager items
	if ItemManager and (item.id.begins_with("board_") or item.id.begins_with("card_")):
		var category = _get_item_category(item.category)
		if category != -1:
			var equipped_id = ItemManager.get_equipped_item(category)
			return equipped_id == item.id
	
	# Fallback to ShopManager data
	var equipped = ShopManager.shop_data.equipped
	match item.category:
		"card_skins":
			return equipped.card_skin == item.id
		"board_skins":
			return equipped.board_skin == item.id
		"avatars":
			return equipped.avatar == item.id
		"frames":
			return equipped.frame == item.id
		"emojis":
			return item.id in equipped.selected_emojis
	
	return false

func _get_item_category(shop_category: String) -> UnifiedItemData.Category:
	match shop_category:
		"card_skins": return UnifiedItemData.Category.CARD_FRONT
		"board_skins": return UnifiedItemData.Category.BOARD
		"avatars": return UnifiedItemData.Category.AVATAR
		"frames": return UnifiedItemData.Category.FRAME
		"emojis": return UnifiedItemData.Category.EMOJI
		_: return -1

func _on_item_equipped(item_id: String):
	print("Item equipped: ", item_id)
	# Refresh all cards to update equipped status
	_refresh_all_cards()

func _on_item_unequipped(item_id: String):
	print("Item unequipped: ", item_id)
	# Refresh all cards to update equipped status
	_refresh_all_cards()

func _refresh_all_cards():
	# Refresh equipped status on all visible cards
	for card in item_cards:
		if card and is_instance_valid(card) and card.has_method("refresh_equipped_status"):
			card.refresh_equipped_status()
	
	# If showing equipped filter, refresh the grid
	if current_filter == "equipped":
		_refresh_current_tab()

func _refresh_current_tab():
	var current_tab_idx = tab_container.current_tab
	var current_tab_control = tab_container.get_child(current_tab_idx)
	
	# Find which category this tab represents
	var category_id = ""
	for id in tabs:
		if tabs[id] == current_tab_control:
			category_id = id
			break
	
	if category_id:
		var items = _get_owned_items_for_category(category_id)
		var grid = current_tab_control.find_child("ItemGrid", true, false)
		
		if grid:
			_populate_grid(grid, items, category_id)

func show_inventory():
	visible = true
	_populate_inventory()  # Refresh on show

func hide_inventory():
	visible = false
	inventory_closed.emit()

func _on_item_equipped_signal(item_id: String, category: String):
	print("[InventoryUI] Item equipped signal received: ", item_id)
	# Refresh all cards to update equipped status
	_refresh_all_cards()

func _on_item_unequipped_signal(item_id: String, category: String):
	print("[InventoryUI] Item unequipped signal received: ", item_id)
	# Refresh all cards to update equipped status
	_refresh_all_cards()

func _connect_new_equipment_system():
	"""Connect to new EquipmentManager - runs alongside old system"""
	# Only connect if it exists
	if not EquipmentManager:
		print("[InventoryUI] TODO: EquipmentManager not found - using old system")
		return
	
	print("[InventoryUI] Connecting to NEW EquipmentManager (parallel to old system)")
	
	# Connect to NEW system signals
	if not EquipmentManager.item_equipped.is_connected(_on_new_equipment_equipped):
		EquipmentManager.item_equipped.connect(_on_new_equipment_equipped)
	if not EquipmentManager.item_unequipped.is_connected(_on_new_equipment_unequipped):
		EquipmentManager.item_unequipped.connect(_on_new_equipment_unequipped)

# NEW handlers that work alongside old ones
func _on_new_equipment_equipped(item_id: String, category: String):
	print("[InventoryUI] NEW SYSTEM: Item equipped - ", item_id)
	# TODO: Once verified working, merge with existing _on_item_equipped_signal

func _on_new_equipment_unequipped(item_id: String, category: String):
	print("[InventoryUI] NEW SYSTEM: Item unequipped - ", item_id)
	# TODO: Once verified working, merge with existing _on_item_unequipped_signal
