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
var current_sort = "default"
var item_cards = []

# Filter options for inventory
const FILTER_OPTIONS = [
	{"id": "all", "name": "All"},
	{"id": "equipped", "name": "Equipped"}
]

# Sort options for inventory
const SORT_OPTIONS = [
	{"id": "name", "name": "A-Z"},
	{"id": "rarity_low", "name": "Rarity: Low to High"},
	{"id": "rarity_high", "name": "Rarity: High to Low"},
	{"id": "type", "name": "By Type"}  # Only for "All" tab
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
	
	# Connect filter/sort buttons for each tab
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
			
		# Find the option buttons
		var filter_button = tab.find_child("FilterButton", true, false)
		var sort_button = tab.find_child("SortButton", true, false)
		
		# Update filter options for inventory
		if filter_button:
			filter_button.clear()
			for option in FILTER_OPTIONS:
				filter_button.add_item(option.name)
			if not filter_button.item_selected.is_connected(_on_filter_changed):
				filter_button.item_selected.connect(_on_filter_changed.bind(category_id))
		
		# Update sort options
		if sort_button:
			sort_button.clear()
			var sort_opts = SORT_OPTIONS.duplicate()
			# Remove "By Type" option for non-All tabs
			if category_id != "all":
				sort_opts = sort_opts.filter(func(opt): return opt.id != "type")
			
			for option in sort_opts:
				sort_button.add_item(option.name)
			if not sort_button.item_selected.is_connected(_on_sort_changed):
				sort_button.item_selected.connect(_on_sort_changed.bind(category_id))
		
		# Set scroll container to transparent
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if scroll_container:
			scroll_container.self_modulate.a = 0
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(0, 300)

func _apply_option_button_styling():
	# Apply custom styling to all OptionButtons
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
			
		var filter_button = tab.find_child("FilterButton", true, false)
		var sort_button = tab.find_child("SortButton", true, false)
		
		if filter_button:
			_style_option_button(filter_button)
		if sort_button:
			_style_option_button(sort_button)

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
	
	# Sort items if needed
	if current_sort == "type" and tab_id == "all":
		_populate_grid_by_type(grid, items, tab_id)
	else:
		# Normal population
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
		
		# Add items of this type
		for item in items_by_type[type]:
			var card = _create_inventory_card(item, tab_id)
			grid.add_child(card)
			item_cards.append(card)
		
		first_type = false

func _get_type_display_name(type: String) -> String:
	match type:
		"card_skins": return "Card Skins"
		"board_skins": return "Board Skins"
		"avatars": return "Avatars"
		"frames": return "Frames"
		"emojis": return "Emojis"
		_: return type.capitalize()

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
	current_filter = FILTER_OPTIONS[index].id
	_apply_filters(tab_id)

func _on_sort_changed(index: int, tab_id: String):
	var sort_opts = SORT_OPTIONS.duplicate()
	if tab_id != "all":
		sort_opts = sort_opts.filter(func(opt): return opt.id != "type")
	
	if index < sort_opts.size():
		current_sort = sort_opts[index].id
		_apply_sorting(tab_id)

func _apply_filters(tab_id: String):
	# Re-populate to apply filters
	_refresh_current_tab()

func _apply_sorting(tab_id: String):
	var tab = tabs.get(tab_id)
	if not tab:
		return
		
	# If sorting by type, we need to repopulate
	if current_sort == "type" and tab_id == "all":
		_refresh_current_tab()
		return
		
	var grid = tab.find_child("ItemGrid", true, false)
	if not grid:
		return
		
	var cards = []
	for card in grid.get_children():
		if card.has_meta("item_data"):  # Skip spacers and labels
			cards.append(card)
	
	# Sort based on current sort option
	match current_sort:
		"name":
			cards.sort_custom(func(a, b): 
				return a.get_meta("item_data").display_name < b.get_meta("item_data").display_name
			)
		"rarity_low":
			cards.sort_custom(func(a, b): 
				return a.get_meta("item_data").rarity < b.get_meta("item_data").rarity
			)
		"rarity_high":
			cards.sort_custom(func(a, b): 
				return a.get_meta("item_data").rarity > b.get_meta("item_data").rarity
			)
	
	# Clear grid and re-add in sorted order
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	for card in cards:
		grid.add_child(card)

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
