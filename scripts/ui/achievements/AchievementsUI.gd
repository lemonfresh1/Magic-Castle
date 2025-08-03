# AchievementsUI.gd - Achievements interface with 4 per row layout
# Location: res://Magic-Castle/scripts/ui/achievements/AchievementsUI.gd
# Last Updated: Created achievements UI with sorting and filtering [Date]

extends PanelContainer

signal achievements_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var achievement_item_scene = preload("res://Magic-Castle/scenes/ui/achievements/AchievementItemCard.tscn")

var sort_mode: String = "rarity_low"  # rarity_low, rarity_high, alphabetical
var filter_mode: String = "all"  # all, completed, open
var achievement_cards = []

func _ready():
	# Debug prints
	print("AchievementsUI _ready called")
	print("Node name: ", name)
	print("Has MarginContainer: ", has_node("MarginContainer"))
	
	# Wait for next frame to ensure @onready vars are initialized
	await get_tree().process_frame
	
	print("After await - tab_container is: ", tab_container)
	
	if not tab_container:
		print("ERROR: TabContainer not found!")
		# Try to find it manually
		var margin = get_node_or_null("MarginContainer")
		print("MarginContainer found: ", margin != null)
		if margin:
			var tc = margin.get_node_or_null("TabContainer")
			print("TabContainer found manually: ", tc != null)
		return
		
	_setup_achievements_tab()
	_populate_achievements()

func _setup_achievements_tab():
	var achievements_tab = tab_container.get_node_or_null("Achievements")
	if not achievements_tab:
		print("ERROR: Achievements tab not found!")
		return
	
	print("Setting up achievements tab...")
	
	# Find existing buttons first
	var filter_button = achievements_tab.find_child("FilterButton", true, false)
	var sort_button = achievements_tab.find_child("SortButton", true, false)
	
	print("Found FilterButton: ", filter_button != null)
	print("Found SortButton: ", sort_button != null)
	
	# If buttons exist in scene, just connect them
	if filter_button:
		print("Connecting existing FilterButton")
		if not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed)
		_style_option_button(filter_button)
	
	if sort_button:
		print("Connecting existing SortButton")
		if not sort_button.item_selected.is_connected(_on_sort_changed):
			sort_button.item_selected.connect(_on_sort_changed)
		_style_option_button(sort_button)
	
	# Create scroll container if needed
	var scroll = achievements_tab.find_child("ScrollContainer", true, false)
	if not scroll:
		print("Creating ScrollContainer")
		var vbox = achievements_tab.find_child("VBoxContainer", true, false)
		if vbox:
			scroll = ScrollContainer.new()
			vbox.add_child(scroll)
	else:
		print("Found existing ScrollContainer")
	
	if scroll:
		_setup_scroll_container(scroll)

func _setup_scroll_container(scroll_container: ScrollContainer):
	if not scroll_container:
		return
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(600, 300)
	scroll_container.self_modulate.a = 0  # Make transparent

func _populate_achievements():
	var achievements_tab = tab_container.get_node_or_null("Achievements")
	if not achievements_tab:
		return
		
	var scroll = achievements_tab.find_child("ScrollContainer", true, false)
	if not scroll:
		return
	
	# Create grid if it doesn't exist
	var grid = scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if not grid:
		grid = GridContainer.new()
		grid.name = "AchievementsGrid"
		grid.columns = 4  # 4 per row as requested
		grid.add_theme_constant_override("h_separation", 15)
		grid.add_theme_constant_override("v_separation", 15)
		scroll.add_child(grid)
	
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
	achievement_cards.clear()
	
	# Get all achievement IDs
	var achievement_ids = []
	for id in AchievementManager.achievements:
		achievement_ids.append(id)
	
	# Apply filter
	match filter_mode:
		"completed":
			achievement_ids = achievement_ids.filter(func(id): return AchievementManager.is_unlocked(id))
		"open":
			achievement_ids = achievement_ids.filter(func(id): return not AchievementManager.is_unlocked(id))
	
	# Apply sort
	match sort_mode:
		"rarity_low":
			achievement_ids.sort_custom(func(a, b): 
				var rarity_a = AchievementManager.achievements[a].rarity
				var rarity_b = AchievementManager.achievements[b].rarity
				return rarity_a < rarity_b
			)
		"rarity_high":
			achievement_ids.sort_custom(func(a, b): 
				var rarity_a = AchievementManager.achievements[a].rarity
				var rarity_b = AchievementManager.achievements[b].rarity
				return rarity_a > rarity_b
			)
		"alphabetical":
			achievement_ids.sort_custom(func(a, b): 
				var name_a = AchievementManager.achievements[a].name
				var name_b = AchievementManager.achievements[b].name
				return name_a < name_b
			)
	
	# Add achievement items
	for id in achievement_ids:
		var item = achievement_item_scene.instantiate()
		grid.add_child(item)
		item.setup(id)
		achievement_cards.append(item)

func _on_sort_changed(index: int):
	match index:
		0:
			sort_mode = "rarity_low"
		1:
			sort_mode = "rarity_high"
		2:
			sort_mode = "alphabetical"
	
	_populate_achievements()

func _on_filter_changed(index: int):
	match index:
		0:
			filter_mode = "all"
		1:
			filter_mode = "completed"
		2:
			filter_mode = "open"
	
	_populate_achievements()

func _style_option_button(button: OptionButton):
	var popup = button.get_popup()
	
	# Popup background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#a487ff")
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	popup.add_theme_stylebox_override("panel", panel_style)
	
	# Hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#b497ff")
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("hover", hover_style)

func show_achievements():
	visible = true
	_populate_achievements()

func hide_achievements():
	visible = false
	achievements_closed.emit()
