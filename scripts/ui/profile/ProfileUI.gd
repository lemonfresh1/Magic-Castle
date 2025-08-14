# ProfileUI.gd - Profile interface showing player stats and equipped items
# Location: res://Pyramids/scripts/ui/profile/ProfileUI.gd
# Last Updated: Replaced all "skin" references with "item", using UnifiedItemCard [Date]
#
# ProfileUI handles:
# - Displaying player stats (level, games played)
# - Showing equipped items across all categories
# - Quick equipment changes
# - Loadout overview
#
# Flow: EquipmentManager → ProfileUI → UnifiedItemCard → EquipmentManager (equip)
# Dependencies: EquipmentManager (for equipped items), XPManager (for level), StatsManager (for stats)

extends PanelContainer

signal profile_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

var current_filter: String = "all"
var item_cards = []

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	if UIStyleManager:
		UIStyleManager.apply_panel_style(self, "profile_ui")
	
	# Connect to EquipmentManager signals
	if EquipmentManager:
		if not EquipmentManager.item_equipped.is_connected(_on_item_equipped):
			EquipmentManager.item_equipped.connect(_on_item_equipped)
		if not EquipmentManager.item_unequipped.is_connected(_on_item_unequipped):
			EquipmentManager.item_unequipped.connect(_on_item_unequipped)
		
	_update_overview()
	_setup_items_tab()

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
	
	# Add equipped items summary
	var equipped_label = Label.new()
	equipped_label.text = "\nEquipped Items:"
	equipped_label.add_theme_font_size_override("font_size", 20)
	equipped_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	vbox.add_child(equipped_label)
	
	if EquipmentManager:
		var equipped_items = EquipmentManager.get_equipped_items()
		
		# Card Front
		var card_front = equipped_items.get("card_front", "")
		if card_front != "" and ItemManager:
			var item = ItemManager.get_item(card_front)
			if item:
				var cf_label = Label.new()
				cf_label.text = "Card Front: %s" % item.display_name
				cf_label.add_theme_font_size_override("font_size", 16)
				cf_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
				vbox.add_child(cf_label)
		
		# Card Back
		var card_back = equipped_items.get("card_back", "")
		if card_back != "" and ItemManager:
			var item = ItemManager.get_item(card_back)
			if item:
				var cb_label = Label.new()
				cb_label.text = "Card Back: %s" % item.display_name
				cb_label.add_theme_font_size_override("font_size", 16)
				cb_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
				vbox.add_child(cb_label)
		
		# Board
		var board = equipped_items.get("board", "")
		if board != "" and ItemManager:
			var item = ItemManager.get_item(board)
			if item:
				var b_label = Label.new()
				b_label.text = "Board: %s" % item.display_name
				b_label.add_theme_font_size_override("font_size", 16)
				b_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
				vbox.add_child(b_label)

func _setup_items_tab():
	# Change tab name from "Skins" to "Items" if possible
	var items_tab = tab_container.get_node_or_null("Skins")
	if not items_tab:
		items_tab = tab_container.get_node_or_null("Items")
	if not items_tab:
		return
	
	# Connect filter button
	var filter_button = items_tab.find_child("OptionButton", true, false)
	if filter_button:
		filter_button.clear()
		filter_button.add_item("All")
		filter_button.add_item("Equipped")
		filter_button.add_item("By Rarity")
		if not filter_button.item_selected.is_connected(_on_items_filter_changed):
			filter_button.item_selected.connect(_on_items_filter_changed)
		# Apply filter styling with purple theme
		if UIStyleManager:
			UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
	
	# Fix scroll container sizing
	var scroll_container = items_tab.find_child("ScrollContainer", true, false)
	if scroll_container:
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(600, 300)
		scroll_container.self_modulate.a = 0  # Make transparent
	
	# Populate items
	_populate_items()

func _populate_items():
	var items_tab = tab_container.get_node_or_null("Skins")
	if not items_tab:
		items_tab = tab_container.get_node_or_null("Items")
	if not items_tab:
		return
		
	var scroll_container = items_tab.find_child("ScrollContainer", true, false)
	if not scroll_container:
		return
	
	# Clear existing container
	for child in scroll_container.get_children():
		child.queue_free()
	
	# Use flow container for mixed items
	var container = _create_flow_container()
	scroll_container.add_child(container)
	
	# Get all owned items
	var owned_items = _get_all_owned_items()
	_populate_flow_container(container, owned_items)

func _get_all_owned_items() -> Array:
	"""Get all owned items from EquipmentManager"""
	print("ProfileUI: Getting owned items...")
	
	if not EquipmentManager:
		print("  ERROR: EquipmentManager not found!")
		return []
	
	# Get owned item IDs from EquipmentManager
	var owned_ids = EquipmentManager.save_data.owned_items
	print("  Found %d owned item IDs" % owned_ids.size())
	
	var result = []
	
	# Convert IDs to UnifiedItemData objects
	if ItemManager:
		for item_id in owned_ids:
			var item = ItemManager.get_item(item_id)
			if item:
				result.append(item)
				print("    - Added: %s" % item.display_name)
			else:
				print("    - WARNING: Item not found in ItemManager: %s" % item_id)
	else:
		print("  ERROR: ItemManager not available!")
	
	print("  Returning %d UnifiedItemData objects" % result.size())
	return result

func _populate_items_grid(grid: GridContainer, items: Array):
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
	item_cards.clear()
	
	# Apply current filter
	match current_filter:
		"all":
			# Sort alphabetically
			items.sort_custom(func(a, b): 
				var name_a = a.display_name if a is UnifiedItemData else ""
				var name_b = b.display_name if b is UnifiedItemData else ""
				return name_a < name_b
			)
		"equipped":
			# Filter to only equipped
			items = items.filter(func(item): return _is_item_equipped(item))
		"rarity":
			# Sort by rarity (highest first)
			items.sort_custom(func(a, b):
				var rar_a = a.rarity if a is UnifiedItemData else 0
				var rar_b = b.rarity if b is UnifiedItemData else 0
				return rar_a > rar_b
			)
	
	# Add cards
	for item in items:
		if not item is UnifiedItemData:
			print("ProfileUI: Skipping non-UnifiedItemData item")
			continue
			
		var card = unified_item_card_scene.instantiate()
		
		# Use INVENTORY mode for profile display
		card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		
		# Connect click signal
		if not card.clicked.is_connected(_on_item_clicked):
			card.clicked.connect(_on_item_clicked)
		
		grid.add_child(card)
		item_cards.append(card)
	
	print("ProfileUI: Added %d cards to grid" % item_cards.size())

func _is_item_equipped(item) -> bool:
	"""Check if an item is equipped"""
	if not EquipmentManager:
		return false
	
	var item_id = ""
	if item is UnifiedItemData:
		item_id = item.id
	elif item is Dictionary and item.has("id"):
		item_id = item.id
	else:
		return false
	
	return EquipmentManager.is_item_equipped(item_id)

func _on_items_filter_changed(index: int):
	match index:
		0:
			current_filter = "all"
		1:
			current_filter = "equipped"
		2:
			current_filter = "rarity"
	
	_populate_items()

func _on_item_clicked(item: UnifiedItemData):
	"""Handle item click - equip if not equipped"""
	if not item:
		return
		
	# Check if item is already equipped
	if EquipmentManager and EquipmentManager.is_item_equipped(item.id):
		print("Item already equipped: ", item.display_name)
		
		# Optionally show unequip dialog
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
	if EquipmentManager:
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

func _on_item_equipped(item_id: String, category: String):
	"""Called when any item is equipped via EquipmentManager"""
	_refresh_all_cards()
	_update_overview()  # Update the overview tab too

func _on_item_unequipped(item_id: String, category: String):
	"""Called when any item is unequipped via EquipmentManager"""
	_refresh_all_cards()
	_update_overview()  # Update the overview tab too

func _refresh_all_cards():
	"""Refresh equipped status on all visible cards"""
	# Just repopulate the grid - simpler than updating each card
	_populate_items()

func show_profile():
	visible = true
	_update_overview()
	_populate_items()

func hide_profile():
	visible = false
	profile_closed.emit()

func _create_flow_container() -> Control:
	"""Create a container that handles mixed-size items in rows"""
	var container = VBoxContainer.new()
	container.name = "FlowContainer"
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return container

func _populate_flow_container(container: VBoxContainer, items: Array):
	"""Populate container with items using proper row/column logic"""
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	item_cards.clear()
	
	var current_row = null
	var current_columns_used = 0
	var MAX_COLUMNS = 4
	
	# Apply filter first
	match current_filter:
		"all":
			items.sort_custom(func(a, b): 
				return a.display_name < b.display_name if a is UnifiedItemData and b is UnifiedItemData else false
			)
		"equipped":
			items = items.filter(func(item): return _is_item_equipped(item))
		"rarity":
			items.sort_custom(func(a, b):
				return a.rarity > b.rarity if a is UnifiedItemData and b is UnifiedItemData else false
			)
	
	for item in items:
		if not item is UnifiedItemData:
			continue
			
		var columns_needed = 2 if item.category == UnifiedItemData.Category.BOARD else 1
		
		# Check if we need a new row
		if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
			# Create new row
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 10)
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(current_row)
			current_columns_used = 0
		
		# Create the card
		var card = unified_item_card_scene.instantiate()
		card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		
		# Set size based on columns needed
		if columns_needed == 2:
			card.custom_minimum_size = Vector2(192, 126)  # Board size
		else:
			card.custom_minimum_size = Vector2(90, 126)   # Card size
		
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		# Connect click signal
		if not card.clicked.is_connected(_on_item_clicked):
			card.clicked.connect(_on_item_clicked)
		
		current_row.add_child(card)
		item_cards.append(card)
		
		current_columns_used += columns_needed
	
	# Fill remaining space in last row if needed
	if current_row and current_columns_used < MAX_COLUMNS:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)
