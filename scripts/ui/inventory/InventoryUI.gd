# InventoryUI.gd - Inventory interface showing owned items
# Location: res://Pyramids/scripts/ui/inventory/InventoryUI.gd  
# Last Updated: Refactored to use EquipmentManager [Date]
#
# InventoryUI handles:
# - Displaying owned items from EquipmentManager
# - Filtering owned items by category/equipped status
# - Initiating equip/unequip actions
# - Showing item details and equipped status
#
# Flow: EquipmentManager → InventoryUI → EquipDialog → EquipmentManager (equip)
# Dependencies: EquipmentManager (for ownership/equipped state), ItemManager (for item data)

extends PanelContainer

signal inventory_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

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
	for category_id in tabs:
		if category_id == "sounds":
			continue
		
		var items = _get_owned_items_for_category(category_id)
		var tab = tabs[category_id]
		if not tab:
			continue
		
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if not scroll_container:
			continue
		
		# Clear existing
		for child in scroll_container.get_children():
			child.queue_free()
		
		# Use flow container for "all" tab, grid for others
		if category_id == "all":
			var container = _create_flow_container()
			scroll_container.add_child(container)
			_populate_flow_container(container, items, category_id)
		else:
			var grid = GridContainer.new()
			grid.name = "ItemGrid"
			grid.columns = 4 if category_id != "boards" and category_id != "board_skins" else 2
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			scroll_container.add_child(grid)
			_populate_grid(grid, items, category_id)

func _get_owned_items_for_category(category_id: String) -> Array:
	"""Get owned items as UnifiedItemData objects"""
	if not EquipmentManager or not ItemManager:
		return []
	
	# Map UI category names to actual category names
	var category_map = {
		"all": "",  # Empty string for all
		"card_skins": "card_front",
		"card_backs": "card_back",
		"board_skins": "board",
		"boards": "board",
		"avatars": "avatar",
		"frames": "frame",
		"emojis": "emoji"
	}
	
	var category_key = category_map.get(category_id, category_id)
	
	# Get owned item IDs
	var owned_ids = []
	if category_key == "":  # All items
		owned_ids = EquipmentManager.save_data.owned_items
	else:
		# Filter by category
		for item_id in EquipmentManager.save_data.owned_items:
			var item = ItemManager.get_item(item_id)
			if item and item.get_category_name() == category_key:
				owned_ids.append(item_id)
	
	# Convert to UnifiedItemData objects
	var result = []
	for item_id in owned_ids:
		var item = ItemManager.get_item(item_id)
		if item:
			result.append(item)
	
	return result

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
		"card_front": return "Card Fronts"
		"card_back": return "Card Backs"
		"board": return "Boards"
		"avatar": return "Avatars"
		"frame": return "Frames"
		"emoji": return "Emojis"
		_: return type.capitalize().replace("_", " ")

func _create_inventory_card(item, tab_id: String):
	"""Create a UnifiedItemCard for inventory display"""
	if not item is UnifiedItemData:
		return null
	
	var card = unified_item_card_scene.instantiate()
	
	# Set metadata
	card.set_meta("tab_id", tab_id)
	card.set_meta("item_data", item)
	
	# Setup with INVENTORY mode
	card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
	
	# Connect for equip functionality - try without bind first
	if not card.clicked.is_connected(_on_item_clicked):
		card.clicked.connect(func(clicked_item): _on_item_clicked(item))  # Use closure instead
	
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

func _on_item_clicked(item: UnifiedItemData):
	"""Handle item click - equip/unequip like ProfileUI does"""
	if not item or not EquipmentManager:
		return
	
	# Check if item is already equipped
	if EquipmentManager.is_item_equipped(item.id):
		print("Item already equipped: ", item.display_name)
		
		# Show unequip dialog
		var dialog = AcceptDialog.new()
		dialog.title = "Item Equipped"
		dialog.dialog_text = "%s is already equipped.\nWould you like to unequip it?" % item.display_name
		dialog.ok_button_text = "Unequip"
		dialog.add_cancel_button("Keep Equipped")
		
		dialog.get_ok_button().pressed.connect(func():
			EquipmentManager.unequip_item(item.id)
			_refresh_all_cards()
		)
		
		get_viewport().add_child(dialog)
		dialog.popup_centered()
		return
	
	# Equip the item
	var success = EquipmentManager.equip_item(item.id)
	if success:
		print("Item equipped: ", item.display_name)
		_refresh_all_cards()
		
		# Show success feedback
		var dialog = AcceptDialog.new()
		dialog.title = "Item Equipped"
		dialog.dialog_text = "%s has been equipped!" % item.display_name
		dialog.ok_button_text = "OK"
		get_viewport().add_child(dialog)
		dialog.popup_centered()
	else:
		push_warning("Failed to equip item: " + item.id)

func _is_item_equipped(item) -> bool:
	"""Check if item is equipped"""
	if not EquipmentManager:
		return false
	
	var item_id = ""
	if item is UnifiedItemData:
		item_id = item.id
	elif item is Dictionary and item.has("id"):
		item_id = item.id
	else:
		return false
	
	return EquipmentManager.is_item_equipped(item_id) if item_id != "" else false

func _on_item_equipped(item_id: String):
	print("Item equipped: ", item_id)
	# Refresh all cards to update equipped status
	_refresh_all_cards()

func _on_item_unequipped(item_id: String):
	print("Item unequipped: ", item_id)
	# Refresh all cards to update equipped status
	_refresh_all_cards()

func _refresh_all_cards():
	"""Refresh the current view"""
	# Just repopulate current tab - simpler and more reliable
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
	"""Connect to EquipmentManager signals"""
	if not EquipmentManager:
		print("[InventoryUI] EquipmentManager not found")
		return
	
	print("[InventoryUI] Connecting to EquipmentManager")
	
	# Connect to EquipmentManager signals
	if not EquipmentManager.item_equipped.is_connected(_on_item_equipped_signal):
		EquipmentManager.item_equipped.connect(_on_item_equipped_signal)
	if not EquipmentManager.item_unequipped.is_connected(_on_item_unequipped_signal):
		EquipmentManager.item_unequipped.connect(_on_item_unequipped_signal)

func _create_flow_container() -> Control:
	"""Create a container that handles mixed-size items in rows"""
	var container = VBoxContainer.new()
	container.name = "FlowContainer"
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return container

func _populate_flow_container(container: VBoxContainer, items: Array, tab_id: String):
	"""Populate container with items using proper row/column logic"""
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	
	# Clear tracked cards
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	var current_row = null
	var current_columns_used = 0
	var MAX_COLUMNS = 4
	
	# Apply filter/sort first
	match current_filter:
		"type":
			# Group by type - handled separately
			_populate_flow_container_by_type(container, items, tab_id)
			return
		"rarity":
			items.sort_custom(func(a, b):
				return a.rarity > b.rarity if a is UnifiedItemData and b is UnifiedItemData else false
			)
		"equipped":
			items = items.filter(func(item): return _is_item_equipped(item))
		_:  # "all"
			items.sort_custom(func(a, b):
				return a.display_name < b.display_name if a is UnifiedItemData and b is UnifiedItemData else false
			)
	
	for item in items:
		if not item is UnifiedItemData:
			continue
		
		var columns_needed = 2 if item.category == UnifiedItemData.Category.BOARD else 1
		
		# Check if we need a new row
		if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 10)
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(current_row)
			current_columns_used = 0
		
		var card = _create_inventory_card(item, tab_id)
		if card:
			if columns_needed == 2:
				card.custom_minimum_size = Vector2(192, 126)
			else:
				card.custom_minimum_size = Vector2(90, 126)
			
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			current_row.add_child(card)
			item_cards.append(card)
			current_columns_used += columns_needed
	
	# Fill remaining space in last row
	if current_row and current_columns_used < MAX_COLUMNS:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

func _populate_flow_container_by_type(container: VBoxContainer, items: Array, tab_id: String):
	"""Populate flow container grouped by type"""
	# Group items by category
	var items_by_type = {}
	for item in items:
		if not item is UnifiedItemData:
			continue
		
		var cat_name = item.get_category_name()
		if not items_by_type.has(cat_name):
			items_by_type[cat_name] = []
		items_by_type[cat_name].append(item)
	
	# Add each category with headers
	var first_category = true
	for category in ["card_front", "card_back", "board", "avatar", "frame", "emoji"]:
		if not items_by_type.has(category):
			continue
		
		# Add category header
		var header = Label.new()
		header.text = _get_type_display_name(category)
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color("#a487ff"))
		container.add_child(header)
		
		# Sort items in this category
		items_by_type[category].sort_custom(func(a, b): 
			return a.display_name < b.display_name
		)
		
		# Create rows for this category
		var current_row = null
		var current_columns_used = 0
		var MAX_COLUMNS = 4
		
		for item in items_by_type[category]:
			var columns_needed = 2 if item.category == UnifiedItemData.Category.BOARD else 1
			
			if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
				current_row = HBoxContainer.new()
				current_row.add_theme_constant_override("separation", 10)
				current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				container.add_child(current_row)
				current_columns_used = 0
			
			var card = _create_inventory_card(item, tab_id)
			if card:
				if columns_needed == 2:
					card.custom_minimum_size = Vector2(192, 126)
				else:
					card.custom_minimum_size = Vector2(90, 126)
				
				card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				current_row.add_child(card)
				item_cards.append(card)
				current_columns_used += columns_needed
		
		# Fill last row if needed
		if current_row and current_columns_used < MAX_COLUMNS:
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_child(spacer)
		
		# Add spacing between categories
		if not first_category:
			var separator = HSeparator.new()
			container.add_child(separator)
		first_category = false
