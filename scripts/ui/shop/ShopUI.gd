# ShopUI.gd - Main shop interface controller using MenuBox template
# Location: res://Magic-Castle/scripts/ui/shop/ShopUI.gd
# Last Updated: Complete script with price visibility fixes [Date]

extends PanelContainer

signal shop_closed
signal item_purchased(item_id: String)

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var shop_item_card_scene = preload("res://Magic-Castle/scenes/ui/shop/ShopItemCard.tscn")

# Tab references mapped by category id
var tabs = {}
var current_filter = "all"
var current_sort = "default"
var item_cards = []  # Keep track of all item cards for filtering
var _is_populated = false

# Filter options (matching what's in the scene)
const FILTER_OPTIONS = [
	{"id": "all", "name": "All"},
	{"id": "can_afford", "name": "Can Afford"},
	{"id": "owned", "name": "Owned"},
	{"id": "not_owned", "name": "Not Owned"},
	{"id": "on_sale", "name": "On Sale"}
]

# Sort options (matching what's in the scene)
const SORT_OPTIONS = [
	{"id": "default", "name": "Default"},
	{"id": "price_low", "name": "Price: Low to High"},
	{"id": "price_high", "name": "Price: High to Low"},
	{"id": "rarity", "name": "Rarity"},
	{"id": "name", "name": "A-Z"}
]

func _ready():
	# Only call once
	if not is_node_ready():
		return
	
	# Make sure tab container expands
	if tab_container:
		tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		print("ShopUI: TabContainer size: ", tab_container.size)
		print("ShopUI: TabContainer visible: ", tab_container.visible)
		
	_setup_tabs()
	_populate_shop()
	_apply_option_button_styling()
	
	# Connect to ShopManager signals
	if ShopManager:
		if not ShopManager.item_purchased.is_connected(_on_item_purchased):
			ShopManager.item_purchased.connect(_on_item_purchased)
		if not ShopManager.shop_refreshed.is_connected(_on_shop_refreshed):
			ShopManager.shop_refreshed.connect(_on_shop_refreshed)

func _setup_tabs():
	# Map existing tabs by their names
	tabs = {
		"highlights": tab_container.get_node_or_null("Highlights"),
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
		
		if filter_button and not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed.bind(category_id))
		
		if sort_button and not sort_button.item_selected.is_connected(_on_sort_changed):
			sort_button.item_selected.connect(_on_sort_changed.bind(category_id))
		
		# Set scroll container to expand
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if scroll_container:
			# scroll_container.self_modulate.a = 0  # Temporarily commented out
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(600, 300)  # Set minimum size

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

func _populate_shop():
	print("ShopUI: Starting to populate shop")
	
	# Populate each tab with relevant items
	for category_id in tabs:
		if category_id == "sounds":  # Skip future category
			continue
			
		var items = _get_items_for_category(category_id)
		print("ShopUI: Category %s has %d items" % [category_id, items.size()])
		
		var tab = tabs[category_id]
		if not tab:
			print("ShopUI: Tab not found for category: ", category_id)
			continue
		
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		
		if scroll_container:
			print("ShopUI: Found ScrollContainer for ", category_id)
			print("  - ScrollContainer visible: ", scroll_container.visible)
			print("  - ScrollContainer size: ", scroll_container.size)
			print("  - ScrollContainer modulate: ", scroll_container.modulate)
			
			# Create grid if it doesn't exist
			var grid = scroll_container.get_child(0) if scroll_container.get_child_count() > 0 else null
			if not grid:
				grid = GridContainer.new()
				grid.name = "ItemGrid"
				grid.columns = 4
				grid.add_theme_constant_override("h_separation", 10)
				grid.add_theme_constant_override("v_separation", 10)
				grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
				# grid.self_modulate.a = 0  # Temporarily commented out to test visibility
				scroll_container.add_child(grid)
				print("ShopUI: Created new grid for ", category_id)
			
			print("  - Grid visible: ", grid.visible)
			print("  - Grid size: ", grid.size)
			
			_populate_grid(grid, items, category_id)
		else:
			print("ShopUI: ScrollContainer not found for ", category_id)
	
	_is_populated = true

func _get_items_for_category(category_id: String) -> Array:
	match category_id:
		"highlights":
			return ShopManager.get_featured_items()
		"all":
			return ShopManager.get_all_items()
		_:
			return ShopManager.get_items_by_category(category_id)

func _populate_grid(grid: GridContainer, items: Array, tab_id: String):
	print("ShopUI: Populating grid for %s with %d items" % [tab_id, items.size()])
	
	# Clear existing items immediately
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	# Clear tracked cards for this tab
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	# Create item cards
	for i in range(items.size()):
		var item = items[i]
		var card = shop_item_card_scene.instantiate()
		
		# Store reference for filtering BEFORE adding to grid
		card.set_meta("tab_id", tab_id)
		card.set_meta("item_data", item)
		
		grid.add_child(card)
		card.setup(item)
		
		# Debug card visibility
		if i == 0:  # Only check first card to avoid spam
			print("ShopUI: First card size: ", card.size)
			print("ShopUI: First card visible: ", card.visible)
			print("ShopUI: First card modulate: ", card.modulate)
			print("ShopUI: First card position: ", card.position)
		
		print("ShopUI: Created card for item: ", item.display_name)
		
		# IMPORTANT: Ensure price is visible for shop cards
		var price_container = card.get_node_or_null("MarginContainer/VBoxContainer/PriceContainer")
		if price_container:
			price_container.visible = true
			print("ShopUI: Price container visible for ", item.display_name)
		else:
			print("ShopUI: WARNING - No price container found for ", item.display_name)
		
		item_cards.append(card)
		
		# Connect signals
		if not card.item_clicked.is_connected(_on_item_clicked):
			card.item_clicked.connect(_on_item_clicked)
		if not card.preview_requested.is_connected(_on_preview_requested):
			card.preview_requested.connect(_on_preview_requested)
	
	print("ShopUI: Grid now has %d children" % grid.get_child_count())

func _on_filter_changed(index: int, tab_id: String):
	current_filter = FILTER_OPTIONS[index].id
	_apply_filters(tab_id)

func _on_sort_changed(index: int, tab_id: String):
	current_sort = SORT_OPTIONS[index].id
	_apply_sorting(tab_id)

func _apply_filters(tab_id: String):
	var tab = tabs.get(tab_id)
	if not tab:
		return
		
	var grid = tab.find_child("ItemGrid", true, false)
	if not grid:
		return
		
	for card in grid.get_children():
		var should_show = true
		var item_data = card.get_meta("item_data")
		
		match current_filter:
			"can_afford":
				should_show = ShopManager.can_afford_item(item_data.id) and not card.is_owned
			"owned":
				should_show = card.is_owned
			"not_owned":
				should_show = not card.is_owned
			"on_sale":
				should_show = card.is_on_sale and not card.is_owned
			"all":
				should_show = true
		
		card.visible = should_show

func _apply_sorting(tab_id: String):
	var tab = tabs.get(tab_id)
	if not tab:
		return
		
	var grid = tab.find_child("ItemGrid", true, false)
	if not grid:
		return
		
	var cards = []
	for card in grid.get_children():
		cards.append(card)
	
	# Sort based on current sort option
	match current_sort:
		"price_low":
			cards.sort_custom(func(a, b): 
				return ShopManager.get_item_price(a.item_data.id) < ShopManager.get_item_price(b.item_data.id)
			)
		"price_high":
			cards.sort_custom(func(a, b): 
				return ShopManager.get_item_price(a.item_data.id) > ShopManager.get_item_price(b.item_data.id)
			)
		"rarity":
			cards.sort_custom(func(a, b): 
				return a.item_data.rarity > b.item_data.rarity
			)
		"name":
			cards.sort_custom(func(a, b): 
				return a.item_data.display_name < b.item_data.display_name
			)
	
	# Re-add cards in sorted order
	for card in cards:
		grid.remove_child(card)
	for card in cards:
		grid.add_child(card)

func _on_item_clicked(item: ShopManager.ShopItem):
	# Show purchase confirmation dialog
	_show_purchase_dialog(item)

func _on_preview_requested(item: ShopManager.ShopItem):
	# Future: Show preview overlay
	ShopManager.preview_requested.emit(item.id)

func _show_purchase_dialog(item: ShopManager.ShopItem):
	# Create simple confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Confirm Purchase"
	
	var price = ShopManager.get_item_price(item.id)
	var current_stars = StarManager.get_balance()
	
	dialog.dialog_text = "Purchase %s for %d stars?\n\nYour balance: %d stars\nAfter purchase: %d stars" % [
		item.display_name,
		price,
		current_stars,
		current_stars - price
	]
	
	dialog.ok_button_text = "Buy Now"
	dialog.get_ok_button().pressed.connect(_confirm_purchase.bind(item))
	
	get_viewport().add_child(dialog)
	dialog.popup_centered()

func _confirm_purchase(item: ShopManager.ShopItem):
	if ShopManager.purchase_item(item.id):
		# Success! Update UI
		_refresh_current_tab()
		item_purchased.emit(item.id)

func _on_item_purchased(item_id: String, price: int, currency: String):
	# Refresh the current tab to update owned states
	_refresh_current_tab()

func _on_shop_refreshed(new_sales: Array):
	# Refresh all tabs to show new sales
	_populate_shop()

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
		var items = _get_items_for_category(category_id)
		var grid = current_tab_control.find_child("ItemGrid", true, false)
		
		if grid:
			_populate_grid(grid, items, category_id)

func show_shop():
	print("ShopUI: show_shop() called")
	visible = true
	
	# Force layout update
	if is_inside_tree():
		await get_tree().process_frame
	
	# Only populate if not already populated
	if not _is_populated:
		print("ShopUI: Not populated yet, populating...")
		_populate_shop()
	else:
		print("ShopUI: Already populated, refreshing cards only")
		# Force refresh daily sales check
		ShopManager._check_daily_refresh()
		# Refresh all displayed items
		_refresh_all_shop_cards()
	
	# Force another layout update after population
	if is_inside_tree():
		await get_tree().process_frame
		print("ShopUI: After layout update - TabContainer size: ", tab_container.size)

func _refresh_all_shop_cards():
	# Go through all tabs and refresh each card
	for category_id in tabs:
		var tab = tabs.get(category_id)
		if not tab:
			continue
			
		var grid = tab.find_child("ItemGrid", true, false)
		if not grid:
			continue
			
		# Refresh each shop card
		for child in grid.get_children():
			if child.has_method("refresh_for_shop"):
				child.refresh_for_shop()
			elif child.has_method("setup"):
				# Re-setup the card to ensure proper state
				var item_data = child.get_meta("item_data")
				if item_data:
					child.setup(item_data)
					
					# Force show price container
					var price_container = child.get_node_or_null("MarginContainer/VBoxContainer/PriceContainer")
					if price_container:
						price_container.visible = true

func hide_shop():
	visible = false
	shop_closed.emit()
