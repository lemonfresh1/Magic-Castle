# InventoryUI.gd - Inventory interface showing owned items
# Location: res://Magic-Castle/scripts/ui/inventory/InventoryUI.gd
# Last Updated: Created inventory system based on shop UI [Date]

extends PanelContainer

signal inventory_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var shop_item_card_scene = preload("res://Magic-Castle/scenes/ui/shop/ShopItemCard.tscn")

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
		
	_setup_tabs()
	_populate_inventory()
	_apply_option_button_styling()

func _setup_tabs():
	# Map existing tabs by their names (no Highlights in inventory)
	tabs = {
		"all": tab_container.get_node_or_null("All"),
		"card_skins": tab_container.get_node_or_null("Cards"),
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
		
		# Set scroll container to transparent
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if scroll_container:
			scroll_container.self_modulate.a = 0
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(0, 300)

func _apply_option_button_styling():
	# Apply custom styling to filter buttons
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
			
		var filter_button = tab.find_child("FilterButton", true, false)
		
		if filter_button:
			_style_option_button(filter_button)

func _style_option_button(button: OptionButton):
	var popup = button.get_popup()
	
	# Popup background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#a487ff")
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_top = 5
	panel_style.border_color = Color.TRANSPARENT
	popup.add_theme_stylebox_override("panel", panel_style)
	
	# Hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#b497ff")
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("hover", hover_style)

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
			_populate_grid_by_rarity(grid, items, tab_id)
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
			
		# Add type header
		if not first_type:
			# Add empty space for visual separation
			for i in range(4):  # Full row of empty space
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(120, 20)
				grid.add_child(spacer)
		
		# Add type label across full width
		var type_label = Label.new()
		type_label.text = _get_type_display_name(type)
		type_label.add_theme_font_size_override("font_size", 16)
		type_label.add_theme_color_override("font_color", Color("#a487ff"))
		grid.add_child(type_label)
		
		# Add 3 empty cells to complete the row
		for i in range(3):
			var spacer = Control.new()
			grid.add_child(spacer)
		
		# Sort items alphabetically within type
		items_by_type[type].sort_custom(func(a, b): return a.display_name < b.display_name)
		
		# Add items of this type
		for item in items_by_type[type]:
			var card = _create_inventory_card(item, tab_id)
			grid.add_child(card)
			item_cards.append(card)
		
		first_type = false

func _populate_grid_by_rarity(grid: GridContainer, items: Array, tab_id: String):
	# Group items by rarity
	var items_by_rarity = {}
	for item in items:
		if not items_by_rarity.has(item.rarity):
			items_by_rarity[item.rarity] = []
		items_by_rarity[item.rarity].append(item)
	
	# Add items with rarity headers (highest to lowest)
	var first_rarity = true
	for rarity in [ShopManager.Rarity.MYTHIC, ShopManager.Rarity.LEGENDARY, 
					ShopManager.Rarity.EPIC, ShopManager.Rarity.RARE, 
					ShopManager.Rarity.UNCOMMON, ShopManager.Rarity.COMMON]:
		if not items_by_rarity.has(rarity):
			continue
			
		# Add spacing between rarities
		if not first_rarity:
			for i in range(4):  # Full row of empty space
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(120, 20)
				grid.add_child(spacer)
		
		# Add rarity label
		var rarity_label = Label.new()
		rarity_label.text = _get_rarity_display_name(rarity)
		rarity_label.add_theme_font_size_override("font_size", 16)
		rarity_label.add_theme_color_override("font_color", ShopManager.get_rarity_color(rarity))
		grid.add_child(rarity_label)
		
		# Add 3 empty cells to complete the row
		for i in range(3):
			var spacer = Control.new()
			grid.add_child(spacer)
		
		# Sort items within rarity alphabetically
		items_by_rarity[rarity].sort_custom(func(a, b): return a.display_name < b.display_name)
		
		# Add items of this rarity
		for item in items_by_rarity[rarity]:
			var card = _create_inventory_card(item, tab_id)
			grid.add_child(card)
			item_cards.append(card)
		
		first_rarity = false

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
	var card = shop_item_card_scene.instantiate()
	card.setup(item)
	
	# Store reference for filtering
	card.set_meta("tab_id", tab_id)
	card.set_meta("item_data", item)
	
	# Inventory-specific modifications
	# Hide price container entirely
	if card.has_node("MarginContainer/VBoxContainer/PriceContainer"):
		var price_container = card.get_node("MarginContainer/VBoxContainer/PriceContainer")
		price_container.visible = false
	
	# Connect for equip functionality (future)
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
	# Future: Show equip dialog or item details
	print("Inventory item clicked: ", item.display_name)

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
