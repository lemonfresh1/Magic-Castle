# ProfileUI.gd - Profile interface showing player overview and owned skins
# Location: res://Magic-Castle/scripts/ui/profile/ProfileUI.gd
# Last Updated: Minimal cleanup - panel styling and filter buttons only [Date]

extends PanelContainer

signal profile_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var inventory_item_card_scene = preload("res://Magic-Castle/scenes/ui/inventory/InventoryItemCard.tscn")

var current_filter: String = "all"
var skin_cards = []

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "profile_ui")
		
	_update_overview()
	_setup_skins_tab()

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

func _setup_skins_tab():
	var skins_tab = tab_container.get_node_or_null("Skins")
	if not skins_tab:
		return
	
	print("Setting up skins tab...")
	
	# Connect filter button - it's called "OptionButton" in the scene
	var filter_button = skins_tab.find_child("OptionButton", true, false)
	if filter_button:
		print("Found OptionButton in skins tab")
		filter_button.clear()
		filter_button.add_item("All")
		filter_button.add_item("Equipped")
		filter_button.add_item("By Rarity")
		if not filter_button.item_selected.is_connected(_on_skins_filter_changed):
			filter_button.item_selected.connect(_on_skins_filter_changed)
			print("Connected filter button signal")
		# Apply filter styling with purple theme
		UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
	else:
		print("ERROR: OptionButton not found in skins tab!")
	
	# Fix scroll container sizing
	var scroll_container = skins_tab.find_child("ScrollContainer", true, false)
	if scroll_container:
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(600, 300)
		scroll_container.self_modulate.a = 0  # Make transparent
	
	# Populate skins
	_populate_skins()

func _populate_skins():
	var skins_tab = tab_container.get_node_or_null("Skins")
	if not skins_tab:
		return
		
	var scroll_container = skins_tab.find_child("ScrollContainer", true, false)
	if not scroll_container:
		return
	
	# Create grid if it doesn't exist
	var grid = scroll_container.get_child(0) if scroll_container.get_child_count() > 0 else null
	if not grid:
		grid = GridContainer.new()
		grid.name = "SkinsGrid"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		scroll_container.add_child(grid)
	
	# Get all owned skins (all categories)
	var owned_skins = _get_all_owned_skins()
	_populate_skins_grid(grid, owned_skins)

func _get_all_owned_skins() -> Array:
	var skins = []
	
	# Get owned items from all skin categories
	var categories = ["card_skins", "board_skins", "avatars", "frames", "emojis"]
	for category in categories:
		var items = ShopManager.get_items_by_category(category)
		for item in items:
			if ShopManager.is_item_owned(item.id):
				skins.append(item)
	
	return skins

func _populate_skins_grid(grid: GridContainer, skins: Array):
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
	skin_cards.clear()
	
	# Apply current filter
	match current_filter:
		"all":
			# Sort alphabetically
			skins.sort_custom(func(a, b): return a.display_name < b.display_name)
		"equipped":
			# Filter to only equipped
			skins = skins.filter(func(item): return _is_item_equipped(item))
		"rarity":
			# Sort by rarity (highest first)
			skins.sort_custom(func(a, b): return a.rarity > b.rarity)
	
	# Add cards
	for skin in skins:
		var card = inventory_item_card_scene.instantiate()
		card.setup(skin)
		card.item_clicked.connect(_on_skin_clicked)
		grid.add_child(card)
		skin_cards.append(card)

func _is_item_equipped(item: ShopManager.ShopItem) -> bool:
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

func _on_skins_filter_changed(index: int):
	match index:
		0:
			current_filter = "all"
		1:
			current_filter = "equipped"
		2:
			current_filter = "rarity"
	
	_populate_skins()

func _on_skin_clicked(item: ShopManager.ShopItem):
	print("Skin clicked in profile: ", item.display_name)
	# Could show equip dialog here

func show_profile():
	visible = true
	_update_overview()
	_populate_skins()

func hide_profile():
	visible = false
	profile_closed.emit()
