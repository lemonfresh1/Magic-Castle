# ShopUI.gd - Shop interface for browsing and purchasing items
# Location: res://Pyramids/scripts/ui/shop/ShopUI.gd
# Last Updated: Cleaned up debug output, removed redundant code [Date]
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

# === SIGNALS ===
signal shop_closed
signal item_purchased(item_id: String)

# === NODE REFERENCES ===
@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

# === PROPERTIES ===
var tabs = {}
var current_filter = "all"
var current_sort = "default"
var item_cards = []
var _is_populated = false

const FILTER_OPTIONS = [
	{"id": "all", "name": "All"},
	{"id": "can_afford", "name": "Can Afford"},
	{"id": "not_owned", "name": "Not Owned"},
	{"id": "on_sale", "name": "On Sale"}
]

const SORT_OPTIONS = [
	{"id": "default", "name": "Default"},
	{"id": "price_low", "name": "Price: Low to High"},
	{"id": "price_high", "name": "Price: High to Low"},
	{"id": "rarity", "name": "Rarity"},
	{"id": "name", "name": "A-Z"}
]

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	if UIStyleManager:
		UIStyleManager.apply_panel_style(self, "shop_ui")
	
	# Configure tab container
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

# === CORE FUNCTIONALITY ===

func _setup_tabs():
	"""Map existing tabs by their names"""
	tabs = {
		"highlights": tab_container.get_node_or_null("Highlights"),
		"all": tab_container.get_node_or_null("All"),
		"card_front": tab_container.get_node_or_null("Cards"),
		"card_back": tab_container.get_node_or_null("Card Backs"),
		"board": tab_container.get_node_or_null("Boards"),
		"avatar": tab_container.get_node_or_null("Avatars"),
		"frame": tab_container.get_node_or_null("Frames"),
		"emoji": tab_container.get_node_or_null("Emojis"),
		"mini_profile_card": tab_container.get_node_or_null("Mini Profiles"),  # NEW
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
	
	# Setup each tab with controls
	for category_id in tabs:
		var tab = tabs[category_id]
		if not tab:
			continue
		
		var filter_button = tab.find_child("FilterButton", true, false)
		var sort_button = tab.find_child("SortButton", true, false)
		
		if filter_button:
			if not filter_button.item_selected.is_connected(_on_filter_changed):
				filter_button.item_selected.connect(_on_filter_changed.bind(category_id))
			if UIStyleManager:
				UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
		
		if sort_button:
			if not sort_button.item_selected.is_connected(_on_sort_changed):
				sort_button.item_selected.connect(_on_sort_changed.bind(category_id))
			if UIStyleManager:
				UIStyleManager.style_filter_button(sort_button, Color("#a487ff"))
		
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
			# Clear existing
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
	
	if category_id == "board" or category_id == "mini_profile_card":  # UPDATED
		grid.columns = 3
	else:
		grid.columns = 6
	
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

func _populate_grid(grid: GridContainer, items: Array, tab_id: String):
	"""Populate a regular grid with items"""
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	for item in items:
		var card = _create_item_card(item, tab_id)
		if card:
			grid.add_child(card)
			item_cards.append(card)

func _populate_flow_container(container: VBoxContainer, items: Array, tab_id: String):
	"""Populate container with items using proper row/column logic"""
	for child in container.get_children():
		child.queue_free()
	
	item_cards = item_cards.filter(func(card): return card.get_meta("tab_id", "") != tab_id)
	
	var current_row = null
	var current_columns_used = 0
	var MAX_COLUMNS = 6
	
	for item in items:
		var item_data = item.get("item_data")
		var columns_needed = 2 if item_data.category == UnifiedItemData.Category.BOARD else 1
		
		# Check if we need a new row
		if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 10)
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(current_row)
			current_columns_used = 0
		
		var card = _create_item_card(item, tab_id)  # or _create_inventory_card
		if card:
			if columns_needed == 2:
				card.custom_minimum_size = UIStyleManager.get_item_card_style("size_landscape")
			else:
				card.custom_minimum_size = UIStyleManager.get_item_card_style("size_portrait")
			
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			current_row.add_child(card)
			item_cards.append(card)
			
			current_columns_used += columns_needed
	
	# Fill remaining space in last row
	if current_row and current_columns_used < MAX_COLUMNS:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

func _create_item_card(item: Dictionary, tab_id: String) -> Control:
	"""Create a UnifiedItemCard for a shop item"""
	var item_data = item.get("item_data")
	if not item_data or not item_data is UnifiedItemData:
		push_warning("ShopUI: Invalid item data in shop display dictionary")
		return null
	
	var card = unified_item_card_scene.instantiate() if unified_item_card_scene else null
	if not card:
		push_warning("ShopUI: Could not instantiate UnifiedItemCard scene")
		return null
	
	# Store metadata
	card.set_meta("tab_id", tab_id)
	card.set_meta("shop_item", item)
	card.set_meta("item_data", item_data)
	
	# Setup the card
	card.setup(item_data, UnifiedItemCard.DisplayMode.SHOP)
	
	# Connect signals
	if card.has_signal("clicked"):
		if not card.clicked.is_connected(_on_item_clicked):
			card.clicked.connect(_on_item_clicked)
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
			var shop_category = _category_to_shop_format(category_id)
			return ShopManager.get_items_by_category(shop_category) if ShopManager else []

func _category_to_shop_format(category: String) -> String:
	"""Convert singular category to ShopManager's expected plural format"""
	match category:
		"card_front": return "card_fronts"
		"card_back": return "card_backs"
		"board": return "boards"
		"avatar": return "avatars"
		"frame": return "frames"
		"emoji": return "emojis"
		"mini_profile_card": return "mini_profile_cards"  # NEW
		_: return category

func _apply_filters(tab_id: String):
	"""Apply current filter to items in a tab"""
	var tab = tabs.get(tab_id)
	if not tab:
		return
	
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
				var rarity_a = a.get_meta("item_data").rarity
				var rarity_b = b.get_meta("item_data").rarity
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
	for card in cards:
		container.add_child(card)

func _refresh_current_tab():
	"""Refresh the current tab to update item states"""
	var current_tab_idx = tab_container.current_tab
	var current_tab_control = tab_container.get_child(current_tab_idx)
	
	var category_id = ""
	for id in tabs:
		if tabs[id] == current_tab_control:
			category_id = id
			break
	
	if category_id:
		var items = _get_items_for_category(category_id)
		
		items = items.filter(func(item):
			var item_data = item.get("item_data")
			return not EquipmentManager.is_item_owned(item_data.id) if EquipmentManager else true
		)
		
		var scroll = current_tab_control.find_child("ScrollContainer", true, false)
		if scroll and scroll.get_child_count() > 0:
			var container = scroll.get_child(0)
			
			if category_id in ["all", "highlights"]:
				_populate_flow_container(container, items, category_id)
			else:
				_populate_grid(container, items, category_id)

# === PUBLIC INTERFACE ===

func show_shop():
	"""Show the shop and ensure it's populated"""
	visible = true
	
	if is_inside_tree():
		await get_tree().process_frame
	
	# Always refresh to hide newly owned items
	_populate_shop()
	
	if is_inside_tree():
		await get_tree().process_frame

func hide_shop():
	"""Hide the shop"""
	visible = false
	shop_closed.emit()

# === SIGNAL HANDLERS ===

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

func _on_item_clicked(item: UnifiedItemData):
	"""Handle item card click - initiate purchase flow"""
	# Double-check ownership
	if EquipmentManager and EquipmentManager.is_item_owned(item.id):
		push_warning("ShopUI: Attempted to purchase owned item: " + item.id)
		return
	
	_show_purchase_dialog(item)

func _on_item_purchased(item_id: String, price: int, currency: String):
	"""Handle successful purchase - refresh to hide the purchased item"""
	_refresh_current_tab()

func _on_insufficient_funds(needed: int, current: int, currency: String):
	"""Handle insufficient funds signal from ShopManager"""
	var dialog = preload("res://Pyramids/scenes/ui/popups/InsufficientFundsDialog.tscn").instantiate()
	dialog.setup(needed, current)
	get_viewport().add_child(dialog)

func _on_shop_refreshed(new_sales: Array):
	"""Handle daily sales refresh"""
	_populate_shop()

# === PRIVATE HELPERS ===

func _show_purchase_dialog(item: UnifiedItemData):
	"""Show purchase confirmation dialog"""
	var price = ShopManager.get_item_price(item.id) if ShopManager else item.base_price
	var current_stars = StarManager.get_balance() if StarManager else 0
	var can_afford = current_stars >= price
	
	if not can_afford:
		# Use new dialog scene
		var dialog = preload("res://Pyramids/scenes/ui/popups/InsufficientFundsDialog.tscn").instantiate()
		dialog.setup(price, current_stars)
		get_viewport().add_child(dialog)
		return
	
	# Use new purchase dialog scene
	var dialog = preload("res://Pyramids/scenes/ui/popups/PurchaseDialog.tscn").instantiate()
	dialog.setup(item, price)
	dialog.confirmed.connect(_confirm_purchase.bind(item))
	get_viewport().add_child(dialog)

func _confirm_purchase(item: UnifiedItemData):
	"""Process the purchase through ShopManager"""
	if ShopManager and ShopManager.purchase_item(item.id):
		_refresh_current_tab()
		item_purchased.emit(item.id)
		_show_purchase_success(item)
	else:
		push_warning("ShopUI: Purchase failed for: " + item.id)

func _show_purchase_success(item: UnifiedItemData):
	"""Show purchase success feedback"""
	var dialog = preload("res://Pyramids/scenes/ui/popups/SuccessDialog.tscn").instantiate()
	dialog.setup(item)
	get_viewport().add_child(dialog)
