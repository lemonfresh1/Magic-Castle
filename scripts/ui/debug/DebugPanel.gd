# DebugPanel.gd - Debug panel with tabbed interface
# Path: res://Magic-Castle/scripts/ui/debug/DebugPanel.gd
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
	# TODO: Implement when InventoryManager is available
	print("Inventory reset! (Not implemented)")

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
	# TODO: Implement when SeasonPassManager is available
	print("Season Pass reset! (Not implemented)")

func _reset_holiday_event():
	# TODO: Implement when HolidayEventManager is available
	print("Holiday Event reset! (Not implemented)")

func _reset_xp():
	if XPManager and XPManager.has_method("reset_xp"):
		XPManager.reset_xp()
	_update_xp_display()
	print("XP reset!")

func _reset_stars():
	if StarManager and StarManager.has_method("reset_stars"):
		StarManager.reset_stars()
	_update_stars_display()
	print("Stars reset!")

func _reset_all():
	_reset_stats()
	_reset_achievements()
	_reset_inventory()
	_reset_xp()
	_reset_stars()
	_reset_missions()
	_reset_season_pass()
	_reset_holiday_event()
	print("=== EVERYTHING RESET ===")

# Unlock functions
func _unlock_all_achievements():
	if AchievementManager:
		for achievement_id in AchievementManager.achievements:
			AchievementManager.unlock_achievement(achievement_id)
	print("All achievements unlocked!")

func _unlock_all_items():
	# TODO: When proper inventory system exists, update this
	print("Unlocking all shop items...")
	
	if ShopManager:
		# Get all items and add to owned
		var all_items = ShopManager.get_all_items()
		for item in all_items:
			if not ShopManager.is_item_owned(item.id):
				ShopManager.shop_data.owned_items.append(item.id)
		ShopManager.save_shop_data()
		print("All shop items unlocked! (%d items)" % all_items.size())
	else:
		print("ShopManager not available")

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
	if amount > 0 and XPManager and XPManager.has_method("add_debug_xp"):
		XPManager.add_debug_xp(amount)
		_update_xp_display()
		print("Added %d XP!" % amount)

func _set_level(level: int):
	if XPManager and XPManager.has_method("set_debug_level"):
		XPManager.set_debug_level(level)
		_update_xp_display()
		print("Set level to %d!" % level)

func _level_up_debug():
	if XPManager:
		var needed = XPManager.get_xp_for_next_level() - XPManager.current_xp
		if needed > 0:
			XPManager.add_debug_xp(needed)
			_update_xp_display()
			print("Leveled up!")

# Star functions
func _add_custom_stars(amount_text: String):
	var amount = amount_text.to_int()
	if amount > 0 and StarManager and StarManager.has_method("add_debug_stars"):
		StarManager.add_debug_stars(amount)
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
