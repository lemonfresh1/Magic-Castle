# AchievementsUI.gd - Achievements interface with 4 per row layout
# Location: res://Pyramids/scripts/ui/achievements/AchievementsUI.gd
# Last Updated: Updated for new achievement_definitions structure [2025-08-28]

extends PanelContainer

signal achievements_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var achievement_item_scene = preload("res://Pyramids/scenes/ui/achievements/AchievementItemCard.tscn")

var sort_mode: String = "tier_low"  # tier_low, tier_high, alphabetical, stars_low, stars_high
var filter_mode: String = "all"  # all, completed, open
var achievement_cards = []

func _ready():
	# Wait for next frame to ensure @onready vars are initialized
	await get_tree().process_frame
	
	if not tab_container:
		push_error("AchievementsUI: TabContainer not found!")
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "achievements_ui")
	
	_setup_achievements_tab()
	_populate_achievements()

func _setup_achievements_tab():
	var achievements_tab = tab_container.get_node_or_null("Achievements")
	if not achievements_tab:
		push_error("AchievementsUI: Achievements tab not found!")
		return
	
	# Find and connect filter/sort buttons
	var filter_button = achievements_tab.find_child("FilterButton", true, false)
	var sort_button = achievements_tab.find_child("SortButton", true, false)
	
	if filter_button:
		if not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed)
		# Apply filter styling with purple theme for achievements
		UIStyleManager.style_filter_button(filter_button, Color("#a487ff"))
	
	if sort_button:
		if not sort_button.item_selected.is_connected(_on_sort_changed):
			sort_button.item_selected.connect(_on_sort_changed)
		# Apply same styling to sort button
		UIStyleManager.style_filter_button(sort_button, Color("#a487ff"))
	
	# Fix scroll container sizing (exactly like InventoryUI)
	var scroll_container = achievements_tab.find_child("ScrollContainer", true, false)
	if scroll_container:
		scroll_container.self_modulate.a = 0
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(600, 300)

func _populate_achievements():
	var achievements_tab = tab_container.get_node_or_null("Achievements")
	if not achievements_tab:
		return
	
	var scroll_container = achievements_tab.find_child("ScrollContainer", true, false)
	
	if scroll_container:
		# Create grid if it doesn't exist (exactly like InventoryUI)
		var grid = scroll_container.get_child(0) if scroll_container.get_child_count() > 0 else null
		if not grid:
			grid = GridContainer.new()
			grid.name = "AchievementsGrid"
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 15)
			grid.add_theme_constant_override("v_separation", 15)
			grid.self_modulate.a = 0
			scroll_container.add_child(grid)
		
		_populate_grid(grid)

func _populate_grid(grid: GridContainer):
	# Clear existing items
	for child in grid.get_children():
		child.queue_free()
	
	# Clear existing cards
	achievement_cards.clear()
	
	# Get all achievement IDs - UPDATED to use achievement_definitions
	var achievement_ids = []
	for id in AchievementManager.achievement_definitions:
		achievement_ids.append(id)
	
	# Apply filter
	match filter_mode:
		"completed":
			achievement_ids = achievement_ids.filter(func(id): return AchievementManager.is_unlocked(id))
		"open":
			achievement_ids = achievement_ids.filter(func(id): return not AchievementManager.is_unlocked(id))
	
	# Apply sort - UPDATED for new structure
	match sort_mode:
		"tier_low":
			achievement_ids.sort_custom(func(a, b): 
				var tier_a = AchievementManager.achievement_definitions[a].get("tier", 1)
				var tier_b = AchievementManager.achievement_definitions[b].get("tier", 1)
				return tier_a < tier_b
			)
		"tier_high":
			achievement_ids.sort_custom(func(a, b): 
				var tier_a = AchievementManager.achievement_definitions[a].get("tier", 1)
				var tier_b = AchievementManager.achievement_definitions[b].get("tier", 1)
				return tier_a > tier_b
			)
		"stars_low":
			achievement_ids.sort_custom(func(a, b): 
				var stars_a = AchievementManager.achievement_definitions[a].stars
				var stars_b = AchievementManager.achievement_definitions[b].stars
				return stars_a < stars_b
			)
		"stars_high":
			achievement_ids.sort_custom(func(a, b): 
				var stars_a = AchievementManager.achievement_definitions[a].stars
				var stars_b = AchievementManager.achievement_definitions[b].stars
				return stars_a > stars_b
			)
		"alphabetical":
			achievement_ids.sort_custom(func(a, b): 
				var name_a = AchievementManager.achievement_definitions[a].name
				var name_b = AchievementManager.achievement_definitions[b].name
				return name_a < name_b
			)
	
	# Add achievement items directly to grid (like InventoryUI does)
	for id in achievement_ids:
		var item = achievement_item_scene.instantiate()
		grid.add_child(item)
		item.setup(id)
		achievement_cards.append(item)

func _on_sort_changed(index: int):
	# Updated sort options to match new system
	match index:
		0:
			sort_mode = "tier_low"
		1:
			sort_mode = "tier_high"
		2:
			sort_mode = "alphabetical"
		3:
			sort_mode = "stars_low"
		4:
			sort_mode = "stars_high"
	
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

func show_achievements():
	visible = true
	_populate_achievements()

func hide_achievements():
	visible = false
	achievements_closed.emit()
