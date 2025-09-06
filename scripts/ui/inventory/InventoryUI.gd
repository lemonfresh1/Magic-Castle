# InventoryUI.gd - Inventory interface showing owned items
# Location: res://Pyramids/scripts/ui/inventory/InventoryUI.gd  
# Last Updated: Updated to use DialogService popup system [Date]
#
# InventoryUI handles:
# - Displaying owned items from EquipmentManager
# - Filtering owned items by category/equipped status
# - Initiating equip actions via DialogService
# - Showing item details and equipped status
#
# Flow: EquipmentManager → InventoryUI → DialogService → EquipPopup → EquipmentManager (equip)
# Dependencies: EquipmentManager (for ownership/equipped state), ItemManager (for item data), DialogService (for popups)

extends PanelContainer

# === SIGNALS ===
signal inventory_closed

# === NODE REFERENCES ===
@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

# === PROPERTIES ===
var tabs = {}
var current_filter = "all"
var item_cards = []

const FILTER_OPTIONS = [
	{"id": "all", "name": "All"},
	{"id": "equipped", "name": "Equipped"},
	{"id": "type", "name": "By Type"},
	{"id": "rarity", "name": "By Rarity"}
]

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	if PopupQueue:
		PopupQueue.current_popup = null
		PopupQueue.clear_queue()
	
	UIStyleManager.apply_panel_style(self, "inventory_ui")
	
	_connect_equipment_signals()
	_connect_dialog_signals()
	_setup_tabs()
	_populate_inventory()

# === CORE FUNCTIONALITY ===

func _setup_tabs():
	"""Map existing tabs by their names"""
	tabs = {
		"all": tab_container.get_node_or_null("All"),
		"card_skins": tab_container.get_node_or_null("Cards"),
		"card_backs": tab_container.get_node_or_null("Card Backs"),
		"board_skins": tab_container.get_node_or_null("Boards"),
		"mini_profile_cards": tab_container.get_node_or_null("Mini Profiles"),
		"avatars": tab_container.get_node_or_null("Avatars"),
		"frames": tab_container.get_node_or_null("Frames"),
		"emojis": tab_container.get_node_or_null("Emojis"),
		"sounds": tab_container.get_node_or_null("Sounds")
	}
	
	# Remove null tabs
	var keys_to_remove = []
	for key in tabs:
		if not tabs[key]:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		tabs.erase(key)
	
	# Disable future features
	if tabs.has("sounds") and tabs["sounds"]:
		var sounds_index = tab_container.get_tab_idx_from_control(tabs["sounds"])
		if sounds_index >= 0:
			tab_container.set_tab_disabled(sounds_index, true)
	
	# Setup filter buttons
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
		
		var filter_button = tab.find_child("FilterButton", true, false)
		
		if filter_button:
			filter_button.clear()
			if category_id == "all":
				for option in FILTER_OPTIONS:
					filter_button.add_item(option.name)
			else:
				filter_button.add_item("All")
				filter_button.add_item("Equipped")
			
			if not filter_button.item_selected.is_connected(_on_filter_changed):
				filter_button.item_selected.connect(_on_filter_changed.bind(category_id))
			
			UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
		
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if scroll_container:
			scroll_container.self_modulate.a = 0
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(600, 300)

func _populate_inventory():
	"""Populate all tabs with owned items"""
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
		
		if category_id == "all":
			var container = _create_flow_container()
			scroll_container.add_child(container)
			_populate_flow_container(container, items, category_id)
		else:
			var grid = GridContainer.new()
			grid.name = "ItemGrid"
			var is_landscape = category_id in ["boards", "board_skins", "mini_profile_cards"]
			grid.columns = 3 if is_landscape else 6
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			scroll_container.add_child(grid)
			_populate_grid(grid, items, category_id)

func _get_owned_items_for_category(category_id: String) -> Array:
	"""Get owned items as UnifiedItemData objects"""
	if not EquipmentManager or not ItemManager:
		return []
	
	var category_map = {
		"all": "",
		"card_skins": "card_front",
		"card_backs": "card_back",
		"board_skins": "board",
		"boards": "board",
		"mini_profile_cards": "mini_profile_card",
		"avatars": "avatar",
		"frames": "frame",
		"emojis": "emoji"
	}
	
	var category_key = category_map.get(category_id, category_id)
	
	var owned_ids = []
	if category_key == "":
		owned_ids = EquipmentManager.save_data.owned_items
	else:
		for item_id in EquipmentManager.save_data.owned_items:
			var item = ItemManager.get_item(item_id)
			if item and item.get_category_name() == category_key:
				owned_ids.append(item_id)
	
	var result = []
	for item_id in owned_ids:
		var item = ItemManager.get_item(item_id)
		if item:
			result.append(item)
	
	return result

func _populate_grid(grid: GridContainer, items: Array, tab_id: String):
	"""Populate a grid container with items"""
	for child in grid.get_children():
		child.queue_free()
	
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id") != tab_id)
	
	match current_filter:
		"type":
			_populate_grid_by_type(grid, items, tab_id)
		"rarity":
			items.sort_custom(func(a, b): return a.rarity > b.rarity)
			for item in items:
				var card = _create_inventory_card(item, tab_id)
				grid.add_child(card)
				item_cards.append(card)
		_:
			items.sort_custom(func(a, b): return a.display_name < b.display_name)
			for item in items:
				var card = _create_inventory_card(item, tab_id)
				grid.add_child(card)
				item_cards.append(card)

func _populate_grid_by_type(grid: GridContainer, items: Array, tab_id: String):
	"""Populate grid with items grouped by type"""
	var items_by_type = {}
	for item in items:
		if not items_by_type.has(item.category):
			items_by_type[item.category] = []
		items_by_type[item.category].append(item)
	
	var first_type = true
	for type in ["card_skins", "board_skins", "avatars", "frames", "emojis"]:
		if not items_by_type.has(type):
			continue
		
		if not first_type:
			_add_grid_spacer_row(grid)
		
		var header_container = HBoxContainer.new()
		header_container.custom_minimum_size = Vector2(520, 30)
		
		var type_label = Label.new()
		type_label.text = _get_type_display_name(type)
		type_label.add_theme_font_size_override("font_size", 16)
		type_label.add_theme_color_override("font_color", Color("#a487ff"))
		header_container.add_child(type_label)
		
		grid.add_child(header_container)
		
		for i in range(3):
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(1, 1)
			grid.add_child(spacer)
		
		items_by_type[type].sort_custom(func(a, b): return a.display_name < b.display_name)
		
		for item in items_by_type[type]:
			var card = _create_inventory_card(item, tab_id)
			grid.add_child(card)
			item_cards.append(card)
		
		first_type = false

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
	for child in container.get_children():
		child.queue_free()
	
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	match current_filter:
		"type":
			_populate_flow_container_by_type(container, items, tab_id)
			return
		"rarity":
			items.sort_custom(func(a, b):
				return a.rarity > b.rarity if a is UnifiedItemData and b is UnifiedItemData else false
			)
		"equipped":
			items = items.filter(func(item): return _is_item_equipped(item))
		_:
			items.sort_custom(func(a, b):
				return a.display_name < b.display_name if a is UnifiedItemData and b is UnifiedItemData else false
			)
	
	var current_row = null
	var current_columns_used = 0
	var MAX_COLUMNS = 6
	
	for item in items:
		if not item is UnifiedItemData:
			continue
		
		var columns_needed = 2 if item.category in [UnifiedItemData.Category.BOARD, UnifiedItemData.Category.MINI_PROFILE_CARD] else 1
		
		if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 10)
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(current_row)
			current_columns_used = 0
		
		var card = _create_inventory_card(item, tab_id)
		if card:
			if columns_needed == 2:
				card.custom_minimum_size = UIStyleManager.get_item_card_style("size_landscape")
			else:
				card.custom_minimum_size = UIStyleManager.get_item_card_style("size_portrait")
			
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			current_row.add_child(card)
			item_cards.append(card)
			current_columns_used += columns_needed
	
	if current_row and current_columns_used < MAX_COLUMNS:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

func _populate_flow_container_by_type(container: VBoxContainer, items: Array, tab_id: String):
	"""Populate flow container grouped by type"""
	var items_by_type = {}
	for item in items:
		if not item is UnifiedItemData:
			continue
		
		var cat_name = item.get_category_name()
		if not items_by_type.has(cat_name):
			items_by_type[cat_name] = []
		items_by_type[cat_name].append(item)
	
	var first_category = true
	for category in ["card_front", "card_back", "board", "mini_profile_card", "avatar", "frame", "emoji"]:
		if not items_by_type.has(category):
			continue
		
		var header = Label.new()
		header.text = _get_type_display_name(category)
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color("#a487ff"))
		container.add_child(header)
		
		items_by_type[category].sort_custom(func(a, b): 
			return a.display_name < b.display_name
		)
		
		var current_row = null
		var current_columns_used = 0
		var MAX_COLUMNS = 6
		
		for item in items_by_type[category]:
			var columns_needed = 2 if item.category in [UnifiedItemData.Category.BOARD, UnifiedItemData.Category.MINI_PROFILE_CARD] else 1
			
			if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
				current_row = HBoxContainer.new()
				current_row.add_theme_constant_override("separation", 10)
				current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				container.add_child(current_row)
				current_columns_used = 0
			
			var card = _create_inventory_card(item, tab_id)
			if card:
				if columns_needed == 2:
					card.custom_minimum_size = UIStyleManager.get_item_card_style("size_landscape")
				else:
					card.custom_minimum_size = UIStyleManager.get_item_card_style("size_portrait")
				
				card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				current_row.add_child(card)
				item_cards.append(card)
				current_columns_used += columns_needed
		
		if current_row and current_columns_used < MAX_COLUMNS:
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_child(spacer)
		
		if not first_category:
			var separator = HSeparator.new()
			container.add_child(separator)
		first_category = false

func _create_inventory_card(item, tab_id: String):
	"""Create a UnifiedItemCard for inventory display"""
	if not item is UnifiedItemData:
		return null
	
	var card = unified_item_card_scene.instantiate()
	
	card.set_meta("tab_id", tab_id)
	card.set_meta("item_data", item)
	
	card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
	
	if not card.clicked.is_connected(_on_item_clicked):
		card.clicked.connect(_on_item_clicked)  # Remove the lambda
	
	return card

func _apply_filters(tab_id: String):
	"""Apply filters to current tab"""
	var tab = tabs.get(tab_id)
	if not tab:
		return
	
	if current_filter in ["type", "rarity"]:
		_refresh_current_tab()
		return
	
	var grid = tab.find_child("ItemGrid", true, false)
	if not grid:
		return
	
	for card in grid.get_children():
		if not card.has_meta("item_data"):
			continue
		
		var should_show = true
		
		match current_filter:
			"all":
				should_show = true
			"equipped":
				var item_data = card.get_meta("item_data")
				should_show = EquipmentManager.is_item_equipped(item_data.id) if EquipmentManager else false
		
		card.visible = should_show

func _refresh_current_tab():
	"""Refresh the current tab"""
	var current_tab_idx = tab_container.current_tab
	var current_tab_control = tab_container.get_child(current_tab_idx)
	
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

# === PUBLIC INTERFACE ===

func show_inventory():
	"""Show the inventory"""
	visible = true
	_populate_inventory()

func hide_inventory():
	"""Hide the inventory"""
	visible = false
	inventory_closed.emit()

# === PRIVATE HELPERS ===

func _connect_equipment_signals():
	"""Connect to EquipmentManager signals"""
	if not EquipmentManager:
		return
	
	if not EquipmentManager.item_equipped.is_connected(_on_item_equipped_signal):
		EquipmentManager.item_equipped.connect(_on_item_equipped_signal)
	if not EquipmentManager.item_unequipped.is_connected(_on_item_unequipped_signal):
		EquipmentManager.item_unequipped.connect(_on_item_unequipped_signal)

func _connect_dialog_signals():
	"""Connect to DialogService signals for popup handling"""
	if not DialogService:
		push_error("DialogService not found!")
		return
	
	# Connect to equip confirmation
	if not DialogService.popup_confirmed.is_connected(_on_popup_confirmed):
		DialogService.popup_confirmed.connect(_on_popup_confirmed)

func _add_grid_spacer_row(grid: GridContainer):
	"""Add a full row of minimal spacers"""
	for i in range(4):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(1, 20)
		grid.add_child(spacer)

func _get_type_display_name(type: String) -> String:
	"""Get display name for category type"""
	match type:
		"card_front": return "Card Fronts"
		"card_back": return "Card Backs"
		"board": return "Boards"
		"mini_profile_card": return "Mini Profile Cards"
		"avatar": return "Avatars"
		"frame": return "Frames"
		"emoji": return "Emojis"
		_: return type.capitalize().replace("_", " ")

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

# === SIGNAL HANDLERS ===

func _on_filter_changed(index: int, tab_id: String):
	"""Handle filter selection change"""
	if tab_id == "all":
		current_filter = FILTER_OPTIONS[index].id
	else:
		current_filter = ["all", "equipped"][index]
	
	_apply_filters(tab_id)

func _on_item_clicked(item: UnifiedItemData):
	print("InventoryUI received click for: ", item.display_name if item else "null item")
	if not item or not EquipmentManager:
		print("Early return - item or EquipmentManager missing")
		return
	
	# Always show equip popup - no unequip option
	if DialogService:
		# Show equip confirmation
		var popup = DialogService.show_equip(item.display_name, item.get_category_name(), item.id)
		
		# Store the item data for later use when confirmed
		if popup:
			popup.set_meta("item_to_equip", item)
	else:
		push_error("DialogService not available!")

func _on_popup_confirmed(popup_type: String, data: Dictionary):
	"""Handle confirmation from DialogService popups"""
	if popup_type != "equip":
		return
	
	# Get the item from the data
	var item_id = data.get("item_id", "")
	if item_id == "":
		push_error("No item_id in equip confirmation data")
		return
	
	# Equip the item
	var success = EquipmentManager.equip_item(item_id)
	
	if success:
		# Show success popup
		if DialogService:
			var item = ItemManager.get_item(item_id) if ItemManager else null
			var item_name = item.display_name if item else item_id
			DialogService.show_success("Item Equipped!", "%s has been equipped!" % item_name)
		
		# Refresh the current tab to update equipped badges
		_refresh_current_tab()
	else:
		push_error("Failed to equip item: " + item_id)
		if DialogService:
			DialogService.show_error("Failed to equip item. Please try again.")

func _on_item_equipped_signal(item_id: String, category: String):
	"""Handle item equipped signal from EquipmentManager"""
	_refresh_current_tab()

func _on_item_unequipped_signal(item_id: String, category: String):
	"""Handle item unequipped signal from EquipmentManager"""
	_refresh_current_tab()
