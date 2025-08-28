# DebugPanel.gd - Debug panel with tabbed interface
# Path: res://Pyramids/scripts/ui/debug/DebugPanel.gd
# Last Updated: Converted to tabbed interface [Date]

extends Panel

# UI References
var close_button: Button
var tab_container: TabContainer

# Tab content containers
var clear_container: ScrollContainer
var unlock_container: ScrollContainer
var stats_container: ScrollContainer
var xp_container: ScrollContainer
var stars_container: ScrollContainer

# Stat editor references
var stat_editors = {}

# Stats we want to be able to edit
var editable_stats = [
	{"id": "games_played", "name": "Games Played", "max": 1000},
	{"id": "rounds_cleared", "name": "Rounds Cleared", "max": 1000},
	{"id": "cards_clicked", "name": "Cards Clicked", "max": 10000},
	{"id": "cards_drawn", "name": "Cards Drawn", "max": 5000},
	{"id": "highscore", "name": "Highscore", "max": 1000000},
	{"id": "longest_combo", "name": "Longest Combo", "max": 50},
	{"id": "aces_played", "name": "Aces Played", "max": 1000},
	{"id": "kings_played", "name": "Kings Played", "max": 1000},
	{"id": "suit_bonuses", "name": "Suit Bonuses", "max": 1000},
	{"id": "total_peaks_cleared", "name": "Total Peaks", "max": 1000},
	{"id": "perfect_rounds", "name": "Perfect Rounds", "max": 100},
	{"id": "total_score", "name": "Total Score", "max": 10000000}
]

func _ready():
	visible = false
	z_index = 2000
	
	# Set size
	custom_minimum_size = Vector2(1000, 400)
	size = Vector2(1000, 400)
	
	# Set position with offset from top-left
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	position = Vector2(20, 20)
	
	# Create the UI structure
	_create_ui_structure()
	
	# Style the panel
	_setup_panel_style()
	
	# Create all tabs
	_create_clear_tab()
	_create_unlock_tab()
	_create_stats_tab()
	_create_xp_tab()
	_create_stars_tab()

func _create_ui_structure():
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Create margin container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	# Create main vbox
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Create header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Debug Panel"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(hide)
	header.add_child(close_button)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Create tab container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

func _setup_panel_style():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	panel_style.border_color = Color(0.3, 0.3, 0.3)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", panel_style)

func _create_clear_tab():
	# Create scroll container
	clear_container = ScrollContainer.new()
	clear_container.name = "Clear"
	tab_container.add_child(clear_container)
	
	# Create content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	clear_container.add_child(content)
	
	# Add padding
	var padding = MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 20)
	content.add_child(padding)
	
	var inner_content = VBoxContainer.new()
	inner_content.add_theme_constant_override("separation", 10)
	padding.add_child(inner_content)
	
	# Title
	var title = Label.new()
	title.text = "Reset Functions"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	inner_content.add_child(title)
	
	_add_separator(inner_content)
	
	# Individual reset buttons
	var reset_achievements_btn = _create_button("Reset All Achievements", _reset_achievements_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_achievements_btn)
	
	var reset_inventory_btn = _create_button("Reset Inventory", _reset_inventory_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_inventory_btn)

	var reset_owned_items_btn = _create_button("Reset Owned Items (Shop & ItemManager)", _reset_owned_items_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_owned_items_btn)

	var reset_stats_btn = _create_button("Reset All Stats", _reset_stats_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_stats_btn)
	
	var reset_missions_btn = _create_button("Reset All Missions", _reset_missions_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_missions_btn)
	
	var reset_season_pass_btn = _create_button("Reset Season Pass", _reset_season_pass_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_season_pass_btn)
	
	var reset_holiday_event_btn = _create_button("Reset Holiday Event", _reset_holiday_event_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_holiday_event_btn)
	
	_add_separator(inner_content)
	
	# MASTER RESET
	var reset_all_btn = _create_button("⚠️ RESET EVERYTHING ⚠️", _reset_all_with_confirm, Color(1.0, 0.3, 0.3))
	reset_all_btn.add_theme_font_size_override("font_size", 18)
	inner_content.add_child(reset_all_btn)

func _create_unlock_tab():
	# Create scroll container
	unlock_container = ScrollContainer.new()
	unlock_container.name = "Unlock"
	tab_container.add_child(unlock_container)
	
	# Create content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	unlock_container.add_child(content)
	
	# Add padding
	var padding = MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 20)
	content.add_child(padding)
	
	var inner_content = VBoxContainer.new()
	inner_content.add_theme_constant_override("separation", 10)
	padding.add_child(inner_content)
	
	# Title
	var title = Label.new()
	title.text = "Unlock Functions"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	inner_content.add_child(title)
	
	_add_separator(inner_content)
	
	# Unlock buttons
	var unlock_achievements_btn = _create_button("Unlock All Achievements", _unlock_all_achievements, Color(0.8, 1.0, 0.8))
	inner_content.add_child(unlock_achievements_btn)
	
	var unlock_items_btn = _create_button("Unlock All Shop Items", _unlock_all_items, Color(0.8, 1.0, 0.8))
	inner_content.add_child(unlock_items_btn)
	
	var unlock_season_pass_btn = _create_button("Unlock Premium Season Pass", _unlock_season_pass, Color(0.8, 1.0, 0.8))
	inner_content.add_child(unlock_season_pass_btn)
	
	var unlock_holiday_pass_btn = _create_button("Unlock Premium Holiday Pass", _unlock_holiday_pass, Color(0.8, 1.0, 0.8))
	inner_content.add_child(unlock_holiday_pass_btn)
	
	_add_separator(inner_content)
	
	# Debug progression buttons
	var add_sp_btn = _create_button("Add 100 Season Points", func(): _add_season_points(100), Color(0.8, 0.8, 1.0))
	inner_content.add_child(add_sp_btn)
	
	var add_hp_btn = _create_button("Add 100 Holiday Points", func(): _add_holiday_points(100), Color(0.8, 0.8, 1.0))
	inner_content.add_child(add_hp_btn)
	
	var complete_missions_btn = _create_button("Complete All Active Missions", _complete_all_missions, Color(0.8, 0.8, 1.0))
	inner_content.add_child(complete_missions_btn)
	
	_add_separator(inner_content)
	
	# === NEW DEBUG BUTTONS ===
	# Debug item checks
	var debug_label = Label.new()
	debug_label.text = "Debug Item Tools"
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	inner_content.add_child(debug_label)
	
	var check_pyramid_btn = _create_button("Check Pyramid Items Status", debug_check_pyramid_items, Color(1.0, 1.0, 0.5))
	inner_content.add_child(check_pyramid_btn)
	
	var grant_pyramid_btn = _create_button("Grant Pyramid Items", func():
		if EquipmentManager:
			var granted = []
			if EquipmentManager.grant_item("board_pyramids", "debug"):
				granted.append("board_pyramids")
			if EquipmentManager.grant_item("card_back_classic_pyramids_gold", "debug"):
				granted.append("card_back_classic_pyramids_gold")
			
			if granted.size() > 0:
				print("Granted pyramid items: %s" % granted)
			else:
				print("Failed to grant pyramid items (might already own them)")
	, Color(0.8, 1.0, 0.8))
	inner_content.add_child(grant_pyramid_btn)
	
	var equip_pyramid_btn = _create_button("Equip Pyramid Items", func():
		if EquipmentManager:
			var equipped = []
			if EquipmentManager.equip_item("board_pyramids"):
				equipped.append("board_pyramids")
			if EquipmentManager.equip_item("card_back_classic_pyramids_gold"):
				equipped.append("card_back_classic_pyramids_gold")
			
			if equipped.size() > 0:
				print("Equipped pyramid items: %s" % equipped)
			else:
				print("Failed to equip pyramid items")
	, Color(0.8, 0.8, 1.0))
	inner_content.add_child(equip_pyramid_btn)
	
	var list_owned_btn = _create_button("List All Owned Items", func():
		if EquipmentManager:
			var owned = EquipmentManager.get_owned_items()
			print("\n=== OWNED ITEMS (%d) ===" % owned.size())
			for item in owned:
				if item is UnifiedItemData:
					print("  - %s (id: %s)" % [item.display_name, item.id])
			print("======================\n")
	, Color(1.0, 1.0, 0.5))
	inner_content.add_child(list_owned_btn)

func _create_stats_tab():
	# Create scroll container
	stats_container = ScrollContainer.new()
	stats_container.name = "Stats"
	tab_container.add_child(stats_container)
	
	# Create content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	stats_container.add_child(content)
	
	# Add padding
	var padding = MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 20)
	content.add_child(padding)
	
	var inner_content = VBoxContainer.new()
	inner_content.add_theme_constant_override("separation", 5)
	padding.add_child(inner_content)
	
	# Title
	var title = Label.new()
	title.text = "Stat Editor"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	inner_content.add_child(title)
	
	_add_separator(inner_content)
	
	# Create stat editors
	for stat_data in editable_stats:
		_create_stat_editor(stat_data, inner_content)
	
	_add_separator(inner_content)
	
	# Quick actions
	var max_stats_btn = _create_button("Max All Stats", _max_all_stats, Color(0.8, 0.8, 1.0))
	inner_content.add_child(max_stats_btn)
	
	var check_achievements_btn = _create_button("Check Achievements Now", _check_achievements, Color(0.8, 1.0, 0.8))
	inner_content.add_child(check_achievements_btn)

func _create_xp_tab():
	# Create scroll container
	xp_container = ScrollContainer.new()
	xp_container.name = "XP"
	tab_container.add_child(xp_container)
	
	# Create content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	xp_container.add_child(content)
	
	# Add padding
	var padding = MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 20)
	content.add_child(padding)
	
	var inner_content = VBoxContainer.new()
	inner_content.add_theme_constant_override("separation", 10)
	padding.add_child(inner_content)
	
	# Title
	var title = Label.new()
	title.text = "XP Controls"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	inner_content.add_child(title)
	
	_add_separator(inner_content)
	
	# Current XP/Level display
	var info_container = HBoxContainer.new()
	info_container.add_theme_constant_override("separation", 20)
	
	var current_xp_label = Label.new()
	current_xp_label.name = "CurrentXPLabel"
	current_xp_label.text = "Current XP: 0"
	current_xp_label.add_theme_color_override("font_color", Color.YELLOW)
	info_container.add_child(current_xp_label)
	
	var current_level_label = Label.new()
	current_level_label.name = "CurrentLevelLabel"
	current_level_label.text = "Level: 1"
	current_level_label.add_theme_color_override("font_color", Color.YELLOW)
	info_container.add_child(current_level_label)
	
	inner_content.add_child(info_container)
	
	_add_separator(inner_content)
	
	# Add XP input
	var xp_input_container = HBoxContainer.new()
	xp_input_container.add_theme_constant_override("separation", 10)
	
	var xp_input_label = Label.new()
	xp_input_label.text = "Add XP:"
	xp_input_label.custom_minimum_size.x = 80
	xp_input_container.add_child(xp_input_label)
	
	var xp_input = LineEdit.new()
	xp_input.name = "XPInput"
	xp_input.placeholder_text = "Amount"
	xp_input.custom_minimum_size.x = 150
	xp_input.text = "100"
	xp_input_container.add_child(xp_input)
	
	var add_xp_btn = Button.new()
	add_xp_btn.text = "Add"
	add_xp_btn.pressed.connect(func(): _add_custom_xp(xp_input.text))
	xp_input_container.add_child(add_xp_btn)
	
	inner_content.add_child(xp_input_container)
	
	# Level control
	var level_input_container = HBoxContainer.new()
	level_input_container.add_theme_constant_override("separation", 10)
	
	var level_input_label = Label.new()
	level_input_label.text = "Set Level:"
	level_input_label.custom_minimum_size.x = 80
	level_input_container.add_child(level_input_label)
	
	var level_input = SpinBox.new()
	level_input.name = "LevelInput"
	level_input.min_value = 1
	level_input.max_value = 50
	level_input.value = 1
	level_input.custom_minimum_size.x = 150
	level_input.value_changed.connect(func(value): _set_level(int(value)))
	level_input_container.add_child(level_input)
	
	inner_content.add_child(level_input_container)
	
	_add_separator(inner_content)
	
	# Quick actions
	var give_100_btn = _create_button("Give 100 XP", func(): _add_custom_xp("100"))
	inner_content.add_child(give_100_btn)
	
	var give_1000_btn = _create_button("Give 1000 XP", func(): _add_custom_xp("1000"))
	inner_content.add_child(give_1000_btn)
	
	var level_up_btn = _create_button("Level Up", _level_up_debug)
	inner_content.add_child(level_up_btn)
	
	var max_level_btn = _create_button("Max Level (50)", func(): _set_level(50))
	inner_content.add_child(max_level_btn)
	
	_add_separator(inner_content)
	
	var reset_xp_btn = _create_button("Reset XP & Level", _reset_xp_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_xp_btn)

func _create_stars_tab():
	# Create scroll container
	stars_container = ScrollContainer.new()
	stars_container.name = "Stars"
	tab_container.add_child(stars_container)
	
	# Create content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	stars_container.add_child(content)
	
	# Add padding
	var padding = MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 20)
	content.add_child(padding)
	
	var inner_content = VBoxContainer.new()
	inner_content.add_theme_constant_override("separation", 10)
	padding.add_child(inner_content)
	
	# Title
	var title = Label.new()
	title.text = "Star Controls"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	inner_content.add_child(title)
	
	_add_separator(inner_content)
	
	# Current stars display
	var current_stars_label = Label.new()
	current_stars_label.name = "CurrentStarsLabel"
	current_stars_label.text = "Current Stars: 0"
	current_stars_label.add_theme_font_size_override("font_size", 16)
	current_stars_label.add_theme_color_override("font_color", Color.YELLOW)
	inner_content.add_child(current_stars_label)
	
	_add_separator(inner_content)
	
	# Add stars input
	var stars_input_container = HBoxContainer.new()
	stars_input_container.add_theme_constant_override("separation", 10)
	
	var stars_input_label = Label.new()
	stars_input_label.text = "Add Stars:"
	stars_input_label.custom_minimum_size.x = 80
	stars_input_container.add_child(stars_input_label)
	
	var stars_input = LineEdit.new()
	stars_input.name = "StarsInput"
	stars_input.placeholder_text = "Amount"
	stars_input.custom_minimum_size.x = 150
	stars_input.text = "100"
	stars_input_container.add_child(stars_input)
	
	var add_stars_btn = Button.new()
	add_stars_btn.text = "Add"
	add_stars_btn.pressed.connect(func(): _add_custom_stars(stars_input.text))
	stars_input_container.add_child(add_stars_btn)
	
	inner_content.add_child(stars_input_container)
	
	_add_separator(inner_content)
	
	# Quick actions
	var give_100_stars_btn = _create_button("Give 100 Stars", func(): _add_custom_stars("100"))
	inner_content.add_child(give_100_stars_btn)
	
	var give_1000_stars_btn = _create_button("Give 1000 Stars", func(): _add_custom_stars("1000"))
	inner_content.add_child(give_1000_stars_btn)
	
	var give_10000_stars_btn = _create_button("Give 10000 Stars", func(): _add_custom_stars("10000"))
	inner_content.add_child(give_10000_stars_btn)
	
	_add_separator(inner_content)
	
	var reset_stars_btn = _create_button("Reset Stars to 0", _reset_stars_with_confirm, Color(1, 0.8, 0.8))
	inner_content.add_child(reset_stars_btn)

# Helper functions
func _create_button(text: String, callback: Callable, color: Color = Color.WHITE) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.modulate = color
	btn.pressed.connect(callback)
	return btn

func _add_separator(parent: Node):
	var sep = HSeparator.new()
	parent.add_child(sep)

func _create_stat_editor(stat_data: Dictionary, parent: Node):
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	
	# Label
	var label = Label.new()
	label.text = stat_data.name + ":"
	label.custom_minimum_size.x = 150
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(label)
	
	# Current value
	var current_value = _get_stat_value(stat_data.id)
	var value_label = Label.new()
	value_label.name = "ValueLabel_" + stat_data.id
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 80
	value_label.add_theme_color_override("font_color", Color.YELLOW)
	container.add_child(value_label)
	
	# Slider
	var slider = HSlider.new()
	slider.name = "Slider_" + stat_data.id
	slider.min_value = 0
	slider.max_value = stat_data.max
	slider.value = current_value
	slider.custom_minimum_size.x = 300
	slider.value_changed.connect(func(value): _on_stat_changed(stat_data.id, value))
	container.add_child(slider)
	
	# Store reference
	stat_editors[stat_data.id] = {
		"slider": slider,
		"label": value_label
	}
	
	parent.add_child(container)

func _get_stat_value(stat_id: String) -> int:
	if not StatsManager:
		return 0
		
	var stats = StatsManager.get_total_stats()
	
	match stat_id:
		"highscore":
			return StatsManager.get_highscore().score
		"longest_combo":
			return StatsManager.get_longest_combo().combo
		"total_peaks_cleared":
			return stats.get("total_peaks_cleared", 0)
		_:
			return stats.get(stat_id, 0)

func _on_stat_changed(stat_id: String, value: float):
	var int_value = int(value)
	
	# Update label
	if stat_editors.has(stat_id):
		stat_editors[stat_id].label.text = str(int_value)
	
	# Update actual stat
	if not StatsManager:
		return
		
	var stats = StatsManager.stats.total_stats
	
	match stat_id:
		"highscore":
			StatsManager.stats.highscore.score = int_value
		"longest_combo":
			StatsManager.stats.longest_combo.combo = int_value
		_:
			if stats.has(stat_id):
				stats[stat_id] = int_value
	
	# Save changes
	StatsManager.save_stats()

# Reset functions with confirmations
func _reset_achievements_with_confirm():
	_show_confirm_dialog("Reset all achievements?", _reset_achievements)

func _reset_inventory_with_confirm():
	_show_confirm_dialog("Reset all inventory items?", _reset_inventory)

func _reset_stats_with_confirm():
	_show_confirm_dialog("Reset all statistics?", _reset_stats)

func _reset_missions_with_confirm():
	_show_confirm_dialog("Reset all missions?", _reset_missions)

func _reset_season_pass_with_confirm():
	_show_confirm_dialog("Reset Season Pass progress?", _reset_season_pass)

func _reset_holiday_event_with_confirm():
	_show_confirm_dialog("Reset Holiday Event progress?", _reset_holiday_event)

func _reset_xp_with_confirm():
	_show_confirm_dialog("Reset XP and Level?", _reset_xp)

func _reset_stars_with_confirm():
	_show_confirm_dialog("Reset stars to 0?", _reset_stars)

func _reset_all_with_confirm():
	_show_confirm_dialog("⚠️ RESET EVERYTHING? ⚠️\n\nThis will reset:\n• All Stats\n• All Achievements\n• All Inventory\n• All XP & Levels\n• All Stars\n• All Missions\n• Season Pass\n• Holiday Event\n\nThis CANNOT be undone!", _reset_all)

func _show_confirm_dialog(text: String, callback: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.confirmed.connect(callback)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

# Actual reset functions
func _reset_achievements():
	if AchievementManager:
		AchievementManager.reset_all_achievements()
	print("Achievements reset!")

func _reset_inventory():
	# Just call the owned items reset
	_reset_owned_items()
	print("Inventory reset!")

func _reset_stats():
	if StatsManager:
		StatsManager.reset_all_stats()
	_refresh_stat_editors()
	print("Stats reset!")

func _reset_missions():
	if UnifiedMissionManager and UnifiedMissionManager.has_method("debug_reset_all"):
		UnifiedMissionManager.debug_reset_all()
	print("Missions reset!")

func _reset_season_pass():
	if SeasonPassManager:
		# Reset the data
		SeasonPassManager.reset_season_data()
		
		# Clear all tier claimed states
		for tier in SeasonPassManager.current_season.tiers:
			tier.free_claimed = false
			tier.premium_claimed = false
		
		# Clear the claimed tiers array
		SeasonPassManager.season_data.claimed_tiers.clear()
		
		# Save and update
		SeasonPassManager.save_season_data()
		SeasonPassManager.season_progress_updated.emit()
		
		print("Season Pass reset! (SP set to 0, Premium removed, Tier 1, All claims cleared)")
	else:
		print("SeasonPassManager not available")

func _reset_holiday_event():
	if HolidayEventManager:
		# Reset the data
		HolidayEventManager.reset_holiday_data()
		
		# Clear all tier claimed states - current_event is a dictionary property
		for tier in HolidayEventManager.current_event.tiers:
			tier.free_claimed = false
			tier.premium_claimed = false
		
		# Clear the claimed tiers array
		HolidayEventManager.holiday_data.claimed_tiers.clear()
		
		# Save and update
		HolidayEventManager.save_holiday_data()
		HolidayEventManager.holiday_progress_updated.emit()
		
		print("Holiday Event reset! (HP set to 0, All claims cleared)")
	else:
		print("HolidayEventManager not available")

func _reset_xp():
	if XPManager and XPManager.has_method("reset_xp"):
		XPManager.reset_xp()  # This exists!
	_update_xp_display()
	print("XP reset!")

func _reset_stars():
	if StarManager and StarManager.has_method("reset_stars"):
		StarManager.reset_stars()  # This exists!
	_update_stars_display()
	print("Stars reset!")

func _reset_all():
	_reset_stats()
	_reset_achievements()
	_reset_owned_items()  # Changed from _reset_inventory()
	_reset_xp()
	_reset_stars()
	_reset_missions()
	_reset_season_pass()
	_reset_holiday_event()
	print("=== EVERYTHING RESET ===")

# Unlock functions
func _unlock_all_achievements():
	"""Unlock all achievement tiers (15 achievements × 5 tiers)"""
	if not AchievementManager:
		print("AchievementManager not available")
		return
	
	print("Unlocking all achievements...")
	var unlocked_count = 0
	
	# Get all base achievements
	var base_achievements = AchievementManager.get_all_base_achievements()
	
	for base_id in base_achievements:
		# Unlock all 5 tiers for this achievement
		for tier in range(1, 6):
			# Set the unlocked tier directly (bypass sequential requirement)
			AchievementManager.unlocked_tiers[base_id] = tier
			
			# Mark progress as complete
			var achievement_id = "%s_tier_%d" % [base_id, tier]
			AchievementManager.achievement_progress[achievement_id] = 1.0
			unlocked_count += 1
	
	# Save the changes
	AchievementManager.save_achievements()
	
	# Emit signals for UI updates
	for base_id in base_achievements:
		AchievementManager.achievement_unlocked.emit(base_id, 5)
	
	print("All achievements unlocked! (%d tiers total)" % unlocked_count)

func _unlock_single_achievement_tier():
	"""Unlock just the next tier of each achievement"""
	if not AchievementManager:
		print("AchievementManager not available")
		return
		
	print("Unlocking next tier for each achievement...")
	var unlocked_count = 0
	
	var base_achievements = AchievementManager.get_all_base_achievements()
	
	for base_id in base_achievements:
		var current_tier = AchievementManager.get_unlocked_tier(base_id)
		if current_tier < 5:
			var next_tier = current_tier + 1
			AchievementManager.unlock_achievement_tier(base_id, next_tier)
			unlocked_count += 1
			print("  %s -> Tier %d" % [base_id, next_tier])
	
	print("Unlocked %d new tiers!" % unlocked_count)

func _claim_all_achievements():
	"""Claim all unlocked but unclaimed achievement rewards"""
	if not AchievementManager:
		print("AchievementManager not available")
		return
		
	print("Claiming all available achievement rewards...")
	var claimed_count = 0
	var total_stars = 0
	var total_xp = 0
	
	var base_achievements = AchievementManager.get_all_base_achievements()
	
	for base_id in base_achievements:
		var unlocked = AchievementManager.get_unlocked_tier(base_id)
		var claimed = AchievementManager.get_claimed_tier(base_id)
		
		# Claim all unclaimed tiers
		for tier in range(claimed + 1, unlocked + 1):
			if AchievementManager.claim_achievement_tier(base_id, tier):
				var achievement_id = "%s_tier_%d" % [base_id, tier]
				var achievement = AchievementManager.achievement_definitions[achievement_id]
				total_stars += achievement.star_reward
				total_xp += achievement.xp_reward
				claimed_count += 1
				print("  Claimed: %s" % achievement.name)
	
	print("Claimed %d achievement tiers! (+%d⭐ +%dXP)" % [claimed_count, total_stars, total_xp])

func _unlock_achievements_up_to_tier(tier: int):
	"""Unlock all achievements up to a specific tier"""
	if not AchievementManager:
		print("AchievementManager not available")
		return
	
	tier = clamp(tier, 1, 5)
	print("Unlocking all achievements up to tier %d..." % tier)
	
	var base_achievements = AchievementManager.get_all_base_achievements()
	
	for base_id in base_achievements:
		# Set the unlocked tier directly
		AchievementManager.unlocked_tiers[base_id] = tier
		
		# Mark progress as complete for all tiers up to this one
		for t in range(1, tier + 1):
			var achievement_id = "%s_tier_%d" % [base_id, t]
			AchievementManager.achievement_progress[achievement_id] = 1.0
	
	# Save and emit
	AchievementManager.save_achievements()
	for base_id in base_achievements:
		AchievementManager.achievement_unlocked.emit(base_id, tier)
	
	print("Done! All achievements at tier %d" % tier)

func _print_achievement_status():
	"""Print current achievement status to console"""
	if not AchievementManager:
		print("AchievementManager not available")
		return
		
	print("\n=== ACHIEVEMENT STATUS ===")
	var base_achievements = AchievementManager.get_all_base_achievements()
	var total_unlocked = 0
	var total_claimed = 0
	var total_claimable = 0
	
	for base_id in base_achievements:
		var unlocked = AchievementManager.get_unlocked_tier(base_id)
		var claimed = AchievementManager.get_claimed_tier(base_id)
		var claimable = unlocked - claimed
		
		total_unlocked += unlocked
		total_claimed += claimed
		total_claimable += claimable
		
		var status = ""
		if unlocked == 0:
			status = "Not started"
		elif claimed == unlocked:
			status = "Tier %d (all claimed)" % unlocked
		else:
			status = "Tier %d (claimed: %d, can claim: %d)" % [unlocked, claimed, claimable]
		
		print("  %s: %s" % [base_id.pad_zeros(20), status])
	
	print("\nSummary:")
	print("  Total Unlocked Tiers: %d / 75" % total_unlocked)
	print("  Total Claimed Tiers: %d / 75" % total_claimed)
	print("  Claimable Now: %d" % total_claimable)
	print("========================\n")

func _unlock_all_items():
	print("Unlocking all shop items...")
	
	# Use the new EquipmentManager system
	if EquipmentManager and ItemManager:
		var all_items = ItemManager.get_all_items()
		var granted = 0
		
		for item_id in all_items:
			var item = all_items[item_id]
			if item and not EquipmentManager.is_item_owned(item_id):
				EquipmentManager.grant_item(item_id, "debug")
				granted += 1
		
		print("All items unlocked! (%d items granted)" % granted)
	else:
		print("EquipmentManager or ItemManager not available")

func _unlock_season_pass():
	if SeasonPassManager:
		# Directly set premium pass
		SeasonPassManager.season_data.has_premium_pass = true
		SeasonPassManager.save_season_data()
		SeasonPassManager.season_progress_updated.emit()
		print("Season Pass premium unlocked!")
	else:
		print("SeasonPassManager not available")

func _unlock_holiday_pass():
	if HolidayEventManager:
		# Directly set premium pass
		HolidayEventManager.holiday_data.has_premium_pass = true
		HolidayEventManager.save_holiday_data()
		HolidayEventManager.holiday_progress_updated.emit()
		print("Holiday Pass premium unlocked!")
	else:
		print("HolidayEventManager not available")

# XP functions
func _add_custom_xp(amount_text: String):
	var amount = amount_text.to_int()
	if amount > 0 and XPManager:
		XPManager.add_debug_xp(amount)  # This exists!
		_update_xp_display()
		print("Added %d XP!" % amount)

func _set_level(level: int):
	if XPManager and XPManager.has_method("set_debug_level"):
		XPManager.set_debug_level(level)  # This exists!
		_update_xp_display()
		print("Set level to %d!" % level)

func _level_up_debug():
	if XPManager:
		var needed = XPManager.get_xp_for_next_level() - XPManager.current_xp
		if needed > 0:
			XPManager.add_debug_xp(needed)  # This exists!
			_update_xp_display()
			print("Leveled up!")

# Star functions
func _add_custom_stars(amount_text: String):
	var amount = amount_text.to_int()
	if amount > 0 and StarManager:
		StarManager.add_stars(amount, "debug")  # This is correct
		_update_stars_display()
		print("Added %d stars!" % amount)

# Other functions
func _max_all_stats():
	for stat_data in editable_stats:
		_on_stat_changed(stat_data.id, stat_data.max)
		# Update UI
		if stat_editors.has(stat_data.id):
			stat_editors[stat_data.id].slider.value = stat_data.max
	print("All stats maxed!")

func _check_achievements():
	if StatsManager:
		StatsManager.save_stats()
	if AchievementManager:
		AchievementManager.check_achievements()
	print("Achievements checked!")

# UI update functions
func _update_xp_display():
	if not XPManager:
		return
	
	var xp_label = get_node_or_null("TabContainer/XP/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/CurrentXPLabel")
	if xp_label:
		xp_label.text = "Current XP: %d" % XPManager.current_xp
	
	var level_label = get_node_or_null("TabContainer/XP/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/CurrentLevelLabel")
	if level_label:
		level_label.text = "Level: %d" % XPManager.current_level
	
	var level_input = get_node_or_null("TabContainer/XP/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/LevelInput")
	if level_input:
		level_input.value = XPManager.current_level

func _update_stars_display():
	if not StarManager:
		return
		
	var stars_label = get_node_or_null("TabContainer/Stars/VBoxContainer/MarginContainer/VBoxContainer/CurrentStarsLabel")
	if stars_label:
		stars_label.text = "Current Stars: %d" % StarManager.get_balance()

func _refresh_stat_editors():
	for stat_data in editable_stats:
		var value = _get_stat_value(stat_data.id)
		if stat_editors.has(stat_data.id):
			stat_editors[stat_data.id].slider.value = value
			stat_editors[stat_data.id].label.text = str(value)

# Show panel override
func show_panel():
	visible = true
	# Update all displays
	_update_xp_display()
	_update_stars_display()
	_refresh_stat_editors()
	print("Debug panel shown")

# New helper functions for season/holiday points
func _add_season_points(amount: int):
	if SeasonPassManager and SeasonPassManager.has_method("add_season_points"):
		SeasonPassManager.add_season_points(amount, "debug")
		print("Added %d Season Points!" % amount)

func _add_holiday_points(amount: int):
	if HolidayEventManager and HolidayEventManager.has_method("add_holiday_points"):
		HolidayEventManager.add_holiday_points(amount, "debug")
		print("Added %d Holiday Points!" % amount)

func _complete_all_missions():
	if UnifiedMissionManager:
		# Get all mission IDs from templates
		for mission_id in UnifiedMissionManager.MISSION_TEMPLATES:
			UnifiedMissionManager.debug_complete_mission(mission_id)
		print("All missions completed!")
	else:
		print("UnifiedMissionManager not available")

func _reset_owned_items_with_confirm():
	_show_confirm_dialog("Reset all owned items?\n\nThis will:\n• Remove all purchased items\n• Keep only default items\n• Reset equipped items to defaults", _reset_owned_items)
	
func _reset_owned_items():
	print("Resetting all owned items...")
	
	# Reset EquipmentManager (this is the new system)
	if EquipmentManager:
		EquipmentManager.reset_all_equipment()  # This method exists
		print("  ✓ EquipmentManager items reset to defaults")
	
	# ShopManager doesn't track ownership anymore in the new system
	# It just provides items from ItemManager
	print("  ShopManager uses EquipmentManager for ownership")
	
	print("All owned items reset! Only default items remain.")

func debug_check_pyramid_items():
	"""Debug function to check pyramid items status"""
	print("\n=== PYRAMID ITEMS DEBUG ===")
	
	var pyramid_items = ["board_pyramids", "card_back_classic_pyramids_gold"]
	
	for item_id in pyramid_items:
		print("\nChecking: %s" % item_id)
		
		# Check ItemManager
		if ItemManager:
			var item = ItemManager.get_item(item_id)
			if item:
				print("  Found in ItemManager:")
				print("    - Display name: %s" % item.display_name)
				print("    - Source: %s" % item.get_source_name())
				print("    - Is purchasable: %s" % item.is_purchasable)
				print("    - Base price: %d" % item.base_price)
			else:
				print("  NOT in ItemManager!")
		
		# Check ownership
		if EquipmentManager:
			var is_owned = EquipmentManager.is_item_owned(item_id)
			print("  Owned: %s" % is_owned)
			
			# Check if it's equipped
			var is_equipped = EquipmentManager.is_item_equipped(item_id)
			print("  Equipped: %s" % is_equipped)
		
		# Check if it's in shop
		if ShopManager:
			var shop_items = ShopManager.get_all_shop_items()
			var in_shop = false
			for shop_item in shop_items:
				if shop_item.get("id") == item_id:  # Use .get() for safety
					in_shop = true
					break
			print("  In shop: %s" % in_shop)
			
			# Check why not in shop
			if not in_shop and ItemManager:
				var item = ItemManager.get_item(item_id)
				if item:
					print("  Why not in shop?")
					if item.source == UnifiedItemData.Source.DEFAULT:
						print("    - It's a DEFAULT item")
					if not item.is_purchasable:
						print("    - It's not purchasable")
					if EquipmentManager and EquipmentManager.is_item_owned(item_id):
						print("    - Player owns it")
	
	print("================================\n")
