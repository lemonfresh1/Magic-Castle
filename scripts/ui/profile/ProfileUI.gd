# ProfileUI.gd - Profile interface showing player stats and equipped items
# Location: res://Pyramids/scripts/ui/profile/ProfileUI.gd
# Last Updated: Cleaned up debug output, reorganized structure [Date]
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

# === SIGNALS ===
signal profile_closed

# === NODE REFERENCES ===
@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

# === PROPERTIES ===
var current_filter: String = "all"
var item_cards = []

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	if UIStyleManager:
		UIStyleManager.apply_panel_style(self, "profile_ui")
	
	if EquipmentManager:
		if not EquipmentManager.item_equipped.is_connected(_on_item_equipped):
			EquipmentManager.item_equipped.connect(_on_item_equipped)
		if not EquipmentManager.item_unequipped.is_connected(_on_item_unequipped):
			EquipmentManager.item_unequipped.connect(_on_item_unequipped)
	
	_update_overview()
	_setup_items_tab()

# === CORE FUNCTIONALITY ===

func _update_overview():
	"""Update the overview tab with player stats and equipped items"""
	var overview_tab = tab_container.get_node_or_null("Overview")
	if not overview_tab:
		return
	
	var vbox = overview_tab.find_child("VBoxContainer", true, false)
	if not vbox:
		return
	
	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	
	# Player info
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
	
	# Equipped items summary
	var equipped_label = Label.new()
	equipped_label.text = "\nEquipped Items:"
	equipped_label.add_theme_font_size_override("font_size", 20)
	equipped_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	vbox.add_child(equipped_label)
	
	if EquipmentManager:
		var equipped_items = EquipmentManager.get_equipped_items()
		
		# Card Front
		_add_equipped_item_label(vbox, "card_front", "Card Front", equipped_items)
		
		# Card Back
		_add_equipped_item_label(vbox, "card_back", "Card Back", equipped_items)
		
		# Board
		_add_equipped_item_label(vbox, "board", "Board", equipped_items)
		
		# Avatar
		_add_equipped_item_label(vbox, "avatar", "Avatar", equipped_items)
		
		# Frame
		_add_equipped_item_label(vbox, "frame", "Frame", equipped_items)

func _setup_items_tab():
	"""Setup the items/skins tab with filters and grid"""
	var items_tab = tab_container.get_node_or_null("Skins")
	if not items_tab:
		items_tab = tab_container.get_node_or_null("Items")
	if not items_tab:
		return
	
	# Setup filter
	var filter_button = items_tab.find_child("OptionButton", true, false)
	if filter_button:
		filter_button.clear()
		filter_button.add_item("All")
		filter_button.add_item("Equipped")
		filter_button.add_item("By Rarity")
		if not filter_button.item_selected.is_connected(_on_items_filter_changed):
			filter_button.item_selected.connect(_on_items_filter_changed)
		if UIStyleManager:
			UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
	
	# Setup scroll container
	var scroll_container = items_tab.find_child("ScrollContainer", true, false)
	if scroll_container:
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(600, 300)
		scroll_container.self_modulate.a = 0
	
	_populate_items()

func _populate_items():
	"""Populate the items tab with owned items"""
	var items_tab = tab_container.get_node_or_null("Skins")
	if not items_tab:
		items_tab = tab_container.get_node_or_null("Items")
	if not items_tab:
		return
	
	var scroll_container = items_tab.find_child("ScrollContainer", true, false)
	if not scroll_container:
		return
	
	# Clear existing
	for child in scroll_container.get_children():
		child.queue_free()
	
	var container = _create_flow_container()
	scroll_container.add_child(container)
	
	var owned_items = _get_all_owned_items()
	_populate_flow_container(container, owned_items)

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
	for child in container.get_children():
		child.queue_free()
	item_cards.clear()
	
	# Apply filter
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
	
	var current_row = null
	var current_columns_used = 0
	var MAX_COLUMNS = 4
	
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
		
		var card = unified_item_card_scene.instantiate()
		card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		
		if columns_needed == 2:
			card.custom_minimum_size = Vector2(192, 126)
		else:
			card.custom_minimum_size = Vector2(90, 126)
		
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		if not card.clicked.is_connected(_on_item_clicked):
			card.clicked.connect(_on_item_clicked)
		
		current_row.add_child(card)
		item_cards.append(card)
		current_columns_used += columns_needed
	
	# Fill remaining space
	if current_row and current_columns_used < MAX_COLUMNS:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

# === PUBLIC INTERFACE ===

func show_profile():
	"""Show the profile UI"""
	visible = true
	_update_overview()
	_populate_items()

func hide_profile():
	"""Hide the profile UI"""
	visible = false
	profile_closed.emit()

# === PRIVATE HELPERS ===

func _get_all_owned_items() -> Array:
	"""Get all owned items from EquipmentManager"""
	if not EquipmentManager:
		return []
	
	var owned_ids = EquipmentManager.save_data.owned_items
	var result = []
	
	if ItemManager:
		for item_id in owned_ids:
			var item = ItemManager.get_item(item_id)
			if item:
				result.append(item)
	
	return result

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

func _add_equipped_item_label(parent: Node, category: String, display_name: String, equipped_items: Dictionary):
	"""Helper to add a label for an equipped item"""
	var item_id = equipped_items.get(category, "")
	if item_id != "" and ItemManager:
		var item = ItemManager.get_item(item_id)
		if item:
			var label = Label.new()
			label.text = "%s: %s" % [display_name, item.display_name]
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
			parent.add_child(label)

func _refresh_all_cards():
	"""Refresh equipped status on all visible cards"""
	_populate_items()

# === SIGNAL HANDLERS ===

func _on_items_filter_changed(index: int):
	"""Handle filter selection change"""
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
	
	if EquipmentManager and EquipmentManager.is_item_equipped(item.id):
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
	
	if EquipmentManager:
		var success = EquipmentManager.equip_item(item.id)
		if success:
			_refresh_all_cards()
			
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
	_update_overview()

func _on_item_unequipped(item_id: String, category: String):
	"""Called when any item is unequipped via EquipmentManager"""
	_refresh_all_cards()
	_update_overview()
