# ShopUI.gd - Shop interface for browsing and purchasing items
# Location: res://Pyramids/scripts/ui/shop/ShopUI.gd
# Last Updated: Refactored to use UnifiedItemCard and proper category naming [Date]
#
# ShopUI handles:
# - Displaying purchasable items from ShopManager using UnifiedItemCard
# - Smart grid layout (4 slots per row, boards take 2 slots)
# - Filtering items by ownership/affordability/sales
# - Purchase flow through proper manager chain
# - Hiding owned items from display
#
# Flow: ItemManager → ShopManager → ShopUI → UnifiedItemCard → EquipmentManager
# Dependencies: ShopManager (for items/pricing), EquipmentManager (for ownership), StarManager (for balance)

extends PanelContainer

signal shop_closed
signal item_purchased(item_id: String)

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

# Tab references mapped by category id (using singular forms)
var tabs = {}
var current_filter = "all"
var current_sort = "default"
var item_cards = []  # Keep track of all item cards for filtering
var _is_populated = false

# Filter options
const FILTER_OPTIONS = [
	{"id": "all", "name": "All"},
	{"id": "can_afford", "name": "Can Afford"},
	{"id": "not_owned", "name": "Not Owned"},  # Removed "owned" since we hide them
	{"id": "on_sale", "name": "On Sale"}
]

# Sort options
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
	
	# Apply panel styling
	if UIStyleManager:
		UIStyleManager.apply_panel_style(self, "shop_ui")
	
	# Make sure tab container expands
	if tab_container:
		tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
	_setup_tabs()
	_populate_shop()
	
	# Connect to ShopManager signals
	if ShopManager:
		if not ShopManager.item_purchased.is_connected(_on_item_purchased):
			ShopManager.item_purchased.connect(_on_item_purchased)
		if not ShopManager.shop_refreshed.is_connected(_on_shop_refreshed):
			ShopManager.shop_refreshed.connect(_on_shop_refreshed)
		if not ShopManager.insufficient_funds.is_connected(_on_insufficient_funds):
			ShopManager.insufficient_funds.connect(_on_insufficient_funds)

func _setup_tabs():
	# Map existing tabs by their names - using SINGULAR category names
	tabs = {
		"highlights": tab_container.get_node_or_null("Highlights"),
		"all": tab_container.get_node_or_null("All"),
		"card_front": tab_container.get_node_or_null("Cards"),  # Changed to singular
		"card_back": tab_container.get_node_or_null("Card Backs"),  # Changed to singular
		"board": tab_container.get_node_or_null("Boards"),  # Changed to singular
		"avatar": tab_container.get_node_or_null("Avatars"),  # Changed to singular
		"frame": tab_container.get_node_or_null("Frames"),  # Changed to singular
		"emoji": tab_container.get_node_or_null("Emojis"),  # Changed to singular
		"sounds": tab_container.get_node_or_null("Sounds")  # Future category
	}
	
	# Remove any null tabs
	var keys_to_remove = []
	for key in tabs:
		if not tabs[key]:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		tabs.erase(key)
	
	# Disable sounds tab if it exists (future feature)
	if tabs.has("sounds") and tabs["sounds"]:
		var sounds_index = tab_container.get_tab_idx_from_control(tabs["sounds"])
		if sounds_index >= 0:
			tab_container.set_tab_disabled(sounds_index, true)
	
	# Setup each tab with proper grid and controls
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
			
		# Find or create the filter/sort buttons
		var filter_button = tab.find_child("FilterButton", true, false)
		var sort_button = tab.find_child("SortButton", true, false)
		
		if filter_button:
			if not filter_button.item_selected.is_connected(_on_filter_changed):
				filter_button.item_selected.connect(_on_filter_changed.bind(category_id))
			# Apply filter styling
			if UIStyleManager:
				UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
		
		if sort_button:
			if not sort_button.item_selected.is_connected(_on_sort_changed):
				sort_button.item_selected.connect(_on_sort_changed.bind(category_id))
			# Apply filter styling to sort button too
			if UIStyleManager:
				UIStyleManager.style_filter_button(sort_button, Color("#a487ff"))
		
		# Setup scroll container
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		if scroll_container:
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(600, 300)

func _populate_shop():
	"""Populate each tab with items, filtering out owned items"""
	for category_id in tabs:
		if category_id == "sounds":
			continue
		
		var items = _get_items_for_category(category_id)
		
		# Filter out owned items
		items = items.filter(func(item): 
			var item_data = item.get("item_data")
			if not item_data:
				return false
			return not EquipmentManager.is_item_owned(item_data.id) if EquipmentManager else true
		)
		
		var tab = tabs[category_id]
		if not tab:
			continue
		
		var scroll_container = tab.find_child("ScrollContainer", true, false)
		
		if scroll_container:
			# Clear existing container
			for child in scroll_container.get_children():
				child.queue_free()
			
			# Mixed content tabs use flow container
			if category_id in ["all", "highlights"]:
				var container = _create_flow_container()
				scroll_container.add_child(container)
				_populate_flow_container(container, items, category_id)
			else:
				# Single-category tabs use regular grid
				var container = _create_regular_grid(category_id)
				scroll_container.add_child(container)
				_populate_grid(container, items, category_id)
	
	_is_populated = true

func _create_regular_grid(category_id: String) -> GridContainer:
	"""Create a regular grid for single-category tabs"""
	var grid = GridContainer.new()
	grid.name = "ItemGrid"
	
	# Set columns based on category
	if category_id == "board":
		grid.columns = 2  # Boards are wider
	else:
		grid.columns = 4  # Regular items
	
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	return grid

func _create_flow_container() -> Control:
	"""Create a container that handles mixed-size items in rows"""
	var container = VBoxContainer.new()
	container.name = "FlowContainer"
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return container

func _create_smart_container() -> Control:
	"""Create a smart container that handles mixed item sizes"""
	var container = Control.new()
	container.name = "SmartContainer"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 100)
	
	# Add method to handle smart layout
	container.set_meta("items", [])
	container.set_meta("current_row", 0)
	container.set_meta("current_slot", 0)
	container.set_meta("row_height", 150)
	container.set_meta("item_spacing", 10)
	
	# Create a simple smart add function
	var add_func = func(card: Control, slots_needed: int):
		var items = container.get_meta("items")
		var current_slot = container.get_meta("current_slot")
		var current_row = container.get_meta("current_row")
		var row_height = container.get_meta("row_height")
		var spacing = container.get_meta("item_spacing")
		
		# Check if item fits in current row
		if current_slot + slots_needed > 4:
			current_row += 1
			current_slot = 0
		
		# Calculate position - DON'T resize the card!
		var slot_width = 90  # Fixed width per slot
		var x_pos = current_slot * (slot_width + spacing)
		var y_pos = current_row * (row_height + spacing)
		
		# Set card position WITHOUT changing its size
		card.position = Vector2(x_pos, y_pos)
		
		# Make sure card doesn't expand
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		container.add_child(card)
		items.append(card)
		
		# Update slot tracking
		current_slot += slots_needed
		if current_slot >= 4:
			current_row += 1
			current_slot = 0
		
		container.set_meta("current_slot", current_slot)
		container.set_meta("current_row", current_row)
		container.set_meta("items", items)
		
		# Update container height
		container.custom_minimum_size.y = (current_row + 1) * (row_height + spacing)
	
	container.set_meta("add_item_smart", add_func)
	
	return container

func _populate_grid(grid: GridContainer, items: Array, tab_id: String):
	"""Populate a regular grid with items"""
	# Clear existing items
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	# Clear tracked cards for this tab
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	# For mixed content tabs (all, highlights), handle board spacing
	if tab_id in ["all", "highlights"]:
		# Separate items by type
		var cards = []
		var boards = []
		
		for item in items:
			var item_data = item.get("item_data")
			if item_data.category == UnifiedItemData.Category.BOARD:
				boards.append(item)
			else:
				cards.append(item)
		
		# Add cards first (they fit nicely in grid)
		for item in cards:
			var card = _create_item_card(item, tab_id)
			if card:
				grid.add_child(card)
				item_cards.append(card)
		
		# If we have an odd number of cards, add a spacer
		if cards.size() % 4 != 0:
			var spacers_needed = 4 - (cards.size() % 4)
			for i in spacers_needed:
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(90, 126)
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				grid.add_child(spacer)
		
		# Now add boards (they take 2 columns each)
		for item in boards:
			var card = _create_item_card(item, tab_id)
			if card:
				grid.add_child(card)
				item_cards.append(card)
				# Add a spacer after each board since they take 2 slots
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(0, 0)
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				grid.add_child(spacer)
	else:
		# Single category tabs - just add items normally
		for item in items:
			var card = _create_item_card(item, tab_id)
			if card:
				grid.add_child(card)
				item_cards.append(card)

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
	
	for item in items:
		var item_data = item.get("item_data")
		var columns_needed = 2 if item_data.category == UnifiedItemData.Category.BOARD else 1
		
		# Check if we need a new row
		if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
			# Create new row
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 10)
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(current_row)
			current_columns_used = 0
		
		# Create the card
		var card = _create_item_card(item, tab_id)
		if card:
			# Set size based on columns needed
			if columns_needed == 2:
				card.custom_minimum_size = Vector2(192, 126)  # Board size
			else:
				card.custom_minimum_size = Vector2(90, 126)   # Card size
			
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			current_row.add_child(card)
			item_cards.append(card)
			
			current_columns_used += columns_needed
	
	# Fill remaining space in last row if needed
	if current_row and current_columns_used < MAX_COLUMNS:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

func _populate_smart_container(container: Control, items: Array, tab_id: String):
	"""Populate smart container with mixed-size items"""
	# Clear existing items
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	# Reset container state
	if container.has_meta("current_slot"):
		container.set_meta("current_slot", 0)
		container.set_meta("current_row", 0)
		container.set_meta("items", [])
	
	# Clear tracked cards for this tab
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	# Sort items to group by type for better layout
	items.sort_custom(func(a, b):
		# First sort by category to group similar items
		var cat_a = a.get("item_data").category if a.has("item_data") else 0
		var cat_b = b.get("item_data").category if b.has("item_data") else 0
		if cat_a != cat_b:
			return cat_a < cat_b
		# Then by rarity
		var rar_a = a.get("item_data").rarity if a.has("item_data") else 0
		var rar_b = b.get("item_data").rarity if b.has("item_data") else 0
		return rar_a > rar_b
	)
	
	# Create a GridContainer instead of smart container for "All" tab
	if tab_id == "all":
		# Replace container with a grid
		var grid = GridContainer.new()
		grid.name = "AllItemsGrid"
		grid.columns = 4  # 4 columns for all items
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Replace the container
		var parent = container.get_parent()
		parent.remove_child(container)
		container.queue_free()
		parent.add_child(grid)
		
		# Add items to grid
		for item in items:
			var card = _create_item_card(item, tab_id)
			if card:
				grid.add_child(card)
				item_cards.append(card)
	else:
		# Use smart container for highlights (mixed sizes)
		for item in items:
			var card = _create_item_card(item, tab_id)
			if card:
				var item_data = item.get("item_data")
				var slots_needed = 2 if item_data and item_data.category == UnifiedItemData.Category.BOARD else 1
				
				# Use smart add if available
				if container.has_meta("add_item_smart"):
					var add_func = container.get_meta("add_item_smart")
					add_func.call(card, slots_needed)
				else:
					container.add_child(card)
				
				item_cards.append(card)

func _create_item_card(item: Dictionary, tab_id: String) -> Control:
	"""Create a UnifiedItemCard for a shop item"""
	# The item parameter is a Dictionary from ShopManager._create_display_dict()
	# It contains an "item_data" field with the actual UnifiedItemData
	
	var item_data = item.get("item_data")
	if not item_data or not item_data is UnifiedItemData:
		push_warning("ShopUI: Invalid item data in shop display dictionary")
		return null
	
	# Create the card
	var card = unified_item_card_scene.instantiate() if unified_item_card_scene else null
	if not card:
		push_warning("ShopUI: Could not instantiate UnifiedItemCard scene")
		return null
	
	# Store metadata
	card.set_meta("tab_id", tab_id)
	card.set_meta("shop_item", item)  # Store the full shop display dictionary
	card.set_meta("item_data", item_data)  # Store the UnifiedItemData
	
	# Setup the card with SHOP display mode
	card.setup(item_data, UnifiedItemCard.DisplayMode.SHOP)
	
	# Connect signals - FIX: Make sure the signal exists and connects properly
	if card.has_signal("clicked"):
		if not card.clicked.is_connected(_on_item_clicked):
			card.clicked.connect(_on_item_clicked)
		else:
			print("ShopUI: Signal already connected")
	else:
		push_error("ShopUI: UnifiedItemCard doesn't have 'clicked' signal!")
	
	return card

func _get_items_for_category(category_id: String) -> Array:
	"""Get items for a specific category from ShopManager"""
	match category_id:
		"highlights":
			return ShopManager.get_featured_items() if ShopManager else []
		"all":
			return ShopManager.get_all_shop_items() if ShopManager else []
		_:
			# Map our singular category names to ShopManager's expected format
			var shop_category = _category_to_shop_format(category_id)
			return ShopManager.get_items_by_category(shop_category) if ShopManager else []

func _category_to_shop_format(category: String) -> String:
	"""Convert singular category to ShopManager's expected plural format"""
	# ShopManager expects plural forms, so we convert
	match category:
		"card_front": return "card_fronts"
		"card_back": return "card_backs"
		"board": return "boards"
		"avatar": return "avatars"
		"frame": return "frames"
		"emoji": return "emojis"
		_: return category

func _on_filter_changed(index: int, tab_id: String):
	"""Handle filter selection change"""
	if index >= 0 and index < FILTER_OPTIONS.size():
		current_filter = FILTER_OPTIONS[index].id
		_apply_filters(tab_id)

func _on_sort_changed(index: int, tab_id: String):
	"""Handle sort selection change"""
	if index >= 0 and index < SORT_OPTIONS.size():
		current_sort = SORT_OPTIONS[index].id
		_apply_sorting(tab_id)

func _apply_filters(tab_id: String):
	"""Apply current filter to items in a tab"""
	var tab = tabs.get(tab_id)
	if not tab:
		return
	
	# Find all cards in this tab
	var cards_in_tab = item_cards.filter(func(card): return card.get_meta("tab_id", "") == tab_id)
	
	for card in cards_in_tab:
		var should_show = true
		var item_data = card.get_meta("item_data")
		
		match current_filter:
			"can_afford":
				should_show = ShopManager.can_afford_item(item_data.id) if ShopManager else false
			"not_owned":
				should_show = not EquipmentManager.is_item_owned(item_data.id) if EquipmentManager else true
			"on_sale":
				should_show = ShopManager.is_item_on_sale(item_data.id) if ShopManager else false
			"all":
				should_show = true
		
		card.visible = should_show

func _apply_sorting(tab_id: String):
	"""Apply current sort to items in a tab"""
	var tab = tabs.get(tab_id)
	if not tab:
		return
	
	# Get the container (grid or smart container)
	var scroll = tab.find_child("ScrollContainer", true, false)
	if not scroll or scroll.get_child_count() == 0:
		return
	
	var container = scroll.get_child(0)
	
	# Get all cards and sort them
	var cards = []
	for child in container.get_children():
		if child.has_meta("item_data"):
			cards.append(child)
	
	# Sort based on current sort option
	match current_sort:
		"price_low":
			cards.sort_custom(func(a, b): 
				var price_a = ShopManager.get_item_price(a.get_meta("item_data").id) if ShopManager else 0
				var price_b = ShopManager.get_item_price(b.get_meta("item_data").id) if ShopManager else 0
				return price_a < price_b
			)
		"price_high":
			cards.sort_custom(func(a, b):
				var price_a = ShopManager.get_item_price(a.get_meta("item_data").id) if ShopManager else 0
				var price_b = ShopManager.get_item_price(b.get_meta("item_data").id) if ShopManager else 0
				return price_a > price_b
			)
		"rarity":
			cards.sort_custom(func(a, b):
				var rarity_a = a.get_meta("unified_data").rarity if a.has_meta("unified_data") else 0
				var rarity_b = b.get_meta("unified_data").rarity if b.has_meta("unified_data") else 0
				return rarity_a > rarity_b
			)
		"name":
			cards.sort_custom(func(a, b):
				var name_a = a.get_meta("item_data").display_name
				var name_b = b.get_meta("item_data").display_name
				return name_a < name_b
			)
	
	# Re-add cards in sorted order
	for card in cards:
		container.remove_child(card)
	
	# If it's a smart container, we need to re-layout
	if container.has_meta("add_item_smart"):
		container.set_meta("current_slot", 0)
		container.set_meta("current_row", 0)
		var add_func = container.get_meta("add_item_smart")
		for card in cards:
			var item_data = card.get_meta("unified_data")
			var slots_needed = 2 if item_data and item_data.category == "board" else 1
			add_func.call(card, slots_needed)
	else:
		# Regular grid, just re-add
		for card in cards:
			container.add_child(card)

func _on_item_clicked(item: UnifiedItemData):
	"""Handle item card click - initiate purchase flow"""
	print("ShopUI: Item clicked: %s" % item.id)  # Debug print
	
	# Double-check ownership (shouldn't happen as owned items are hidden)
	if EquipmentManager and EquipmentManager.is_item_owned(item.id):
		push_warning("ShopUI: Attempted to purchase owned item: " + item.id)
		return
	
	# Show purchase confirmation dialog
	_show_purchase_dialog(item)

func _show_purchase_dialog(item: UnifiedItemData):
	"""Show purchase confirmation dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Confirm Purchase"
	
	var price = ShopManager.get_item_price(item.id) if ShopManager else item.base_price
	var current_stars = StarManager.get_balance() if StarManager else 0
	var can_afford = current_stars >= price
	
	dialog.dialog_text = "Purchase %s for %d ⭐?\n\nYour balance: %d ⭐\nAfter purchase: %d ⭐" % [
		item.display_name,
		price,
		current_stars,
		current_stars - price
	]
	
	if can_afford:
		dialog.ok_button_text = "Buy Now"
		dialog.get_ok_button().pressed.connect(_confirm_purchase.bind(item))
		dialog.get_ok_button().modulate = Color.WHITE
	else:
		dialog.ok_button_text = "Not Enough Stars"
		dialog.get_ok_button().disabled = true
		dialog.get_ok_button().modulate = Color(0.5, 0.5, 0.5)
	
	get_viewport().add_child(dialog)
	dialog.popup_centered()

func _confirm_purchase(item: UnifiedItemData):
	"""Process the purchase through ShopManager"""
	if ShopManager and ShopManager.purchase_item(item.id):
		# Success! The item should now be hidden from shop
		_refresh_current_tab()
		item_purchased.emit(item.id)
		
		# Show success feedback
		_show_purchase_success(item)
	else:
		# Purchase failed - ShopManager will emit insufficient_funds signal
		push_warning("ShopUI: Purchase failed for: " + item.id)

func _show_purchase_success(item: UnifiedItemData):
	"""Show purchase success feedback"""
	var dialog = AcceptDialog.new()
	dialog.title = "Purchase Successful!"
	dialog.dialog_text = "%s has been added to your inventory!" % item.display_name
	dialog.ok_button_text = "Great!"
	
	get_viewport().add_child(dialog)
	dialog.popup_centered()

func _on_item_purchased(item_id: String, price: int, currency: String):
	"""Handle successful purchase - refresh to hide the purchased item"""
	_refresh_current_tab()

func _on_insufficient_funds(needed: int, current: int, currency: String):
	"""Handle insufficient funds signal from ShopManager"""
	var dialog = AcceptDialog.new()
	dialog.title = "Insufficient Funds"
	dialog.dialog_text = "You need %d %s but only have %d %s" % [needed, currency, current, currency]
	dialog.ok_button_text = "OK"
	
	get_viewport().add_child(dialog)
	dialog.popup_centered()

func _on_shop_refreshed(new_sales: Array):
	"""Handle daily sales refresh"""
	# Re-populate shop to show new sales
	_populate_shop()

func _refresh_current_tab():
	"""Refresh the current tab to update item states"""
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
		
		# Filter out owned items
		items = items.filter(func(item):
			return not EquipmentManager.is_item_owned(item.id) if EquipmentManager else true
		)
		
		var scroll = current_tab_control.find_child("ScrollContainer", true, false)
		if scroll and scroll.get_child_count() > 0:
			var container = scroll.get_child(0)
			
			# Re-populate based on container type
			if category_id in ["all", "highlights"]:
				_populate_smart_container(container, items, category_id)
			else:
				_populate_grid(container, items, category_id)

func show_shop():
	"""Show the shop and ensure it's populated"""
	visible = true
	
	# Force layout update
	if is_inside_tree():
		await get_tree().process_frame
	
	# Only populate if not already populated
	if not _is_populated:
		_populate_shop()
	else:
		# Refresh to hide any newly owned items
		_populate_shop()
	
	# Force another layout update after population
	if is_inside_tree():
		await get_tree().process_frame

func hide_shop():
	"""Hide the shop"""
	visible = false
	shop_closed.emit()
