# DebugPanel.gd - Debug panel for editing stats and testing achievements
# Path: res://Magic-Castle/scripts/ui/debug/DebugPanel.gd
extends Panel

var close_button: Button
var stats_container: VBoxContainer
var title_label: Label

# Stat editor scenes (we'll create these as needed)
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
	{"id": "total_score", "name": "Total Score", "max": 10000000},
	{"id": "current_xp", "name": "Current XP", "max": 50000},
	{"id": "current_level", "name": "Current Level", "max": 50}
]

func _ready():
	visible = false
	z_index = 2000
	
	# Set size and position
	custom_minimum_size = Vector2(400, 500)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	size = Vector2(400, 500)
	
	# Create the UI structure
	_create_ui_structure()
	
	# Style the panel
	_setup_panel_style()
	
	# Create content
	_create_stat_editors()
	_create_action_buttons()

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
	title_label = Label.new()
	title_label.text = "Debug Panel"
	title_label.add_theme_font_size_override("font_size", 18)
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
	
	# Create scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	# Create stats container
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 5)
	scroll.add_child(stats_container)

func _setup_panel_style():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	panel_style.border_color = Color(0.3, 0.3, 0.3)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", panel_style)

func _create_stat_editors():
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()
	
	# Add title
	var title = Label.new()
	title.text = "Stat Editor"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	stats_container.add_child(title)
	
	_add_separator()
	
	# Create editor for each stat
	for stat_data in editable_stats:
		_create_stat_editor(stat_data)
	
	_add_separator()

func _create_stat_editor(stat_data: Dictionary):
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
	value_label.custom_minimum_size.x = 60
	value_label.add_theme_color_override("font_color", Color.YELLOW)
	container.add_child(value_label)
	
	# Slider
	var slider = HSlider.new()
	slider.name = "Slider_" + stat_data.id
	slider.min_value = 0
	slider.max_value = stat_data.max
	slider.value = current_value
	slider.custom_minimum_size.x = 120
	slider.value_changed.connect(func(value): _on_stat_changed(stat_data.id, value))
	container.add_child(slider)
	
	# Store reference
	stat_editors[stat_data.id] = {
		"slider": slider,
		"label": value_label
	}
	
	stats_container.add_child(container)

func _create_action_buttons():

	_add_xp_controls()

	_add_separator()

	# Quick actions section
	var actions_label = Label.new()
	actions_label.text = "Quick Actions"
	actions_label.add_theme_font_size_override("font_size", 16)
	actions_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	stats_container.add_child(actions_label)
	
	# Unlock all achievements
	var unlock_all_btn = Button.new()
	unlock_all_btn.text = "Unlock All Achievements"
	unlock_all_btn.pressed.connect(_unlock_all_achievements)
	stats_container.add_child(unlock_all_btn)
	
	# Give 1000 stars
	var give_stars_btn = Button.new()
	give_stars_btn.text = "Give 1000 Stars"
	give_stars_btn.pressed.connect(_give_stars)
	stats_container.add_child(give_stars_btn)
	
	# Max all stats
	var max_stats_btn = Button.new()
	max_stats_btn.text = "Max All Stats"
	max_stats_btn.pressed.connect(_max_all_stats)
	stats_container.add_child(max_stats_btn)
	
	_add_separator()
	
	# Reset section
	var reset_label = Label.new()
	reset_label.text = "Reset Options"
	reset_label.add_theme_font_size_override("font_size", 16)
	reset_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	stats_container.add_child(reset_label)

	# MASTER RESET ALL BUTTON - Very red and prominent
	var reset_all_btn = Button.new()
	reset_all_btn.text = "⚠️ RESET ALL ⚠️"
	reset_all_btn.add_theme_font_size_override("font_size", 18)
	reset_all_btn.modulate = Color(1.0, 0.3, 0.3)  # Very red
	reset_all_btn.pressed.connect(_reset_all_with_confirm)
	stats_container.add_child(reset_all_btn)

	# Add some spacing
	var spacer_reset = Control.new()
	spacer_reset.custom_minimum_size.y = 10
	stats_container.add_child(spacer_reset)

	# Individual reset buttons (less prominent now)
	var reset_stats_btn = Button.new()
	reset_stats_btn.text = "Reset All Stats"
	reset_stats_btn.modulate = Color(1, 0.8, 0.8)
	reset_stats_btn.pressed.connect(_reset_stats_with_confirm)
	stats_container.add_child(reset_stats_btn)

	var reset_achievements_btn = Button.new()
	reset_achievements_btn.text = "Reset All Achievements"
	reset_achievements_btn.modulate = Color(1, 0.8, 0.8)
	reset_achievements_btn.pressed.connect(_reset_achievements_with_confirm)
	stats_container.add_child(reset_achievements_btn)

	var reset_stars_btn = Button.new()
	reset_stars_btn.text = "Reset Stars to 0"
	reset_stars_btn.modulate = Color(1, 0.8, 0.8)
	reset_stars_btn.pressed.connect(_reset_stars_with_confirm)
	stats_container.add_child(reset_stars_btn)

	var reset_xp_btn = Button.new()
	reset_xp_btn.text = "Reset XP & Level"
	reset_xp_btn.modulate = Color(1, 0.8, 0.8)
	reset_xp_btn.pressed.connect(_reset_xp_with_confirm)
	stats_container.add_child(reset_xp_btn)

	var reset_missions_btn = Button.new()
	reset_missions_btn.text = "Reset All Missions"
	reset_missions_btn.modulate = Color(1, 0.8, 0.8)
	reset_missions_btn.pressed.connect(_reset_missions_with_confirm)
	stats_container.add_child(reset_missions_btn)
	
	_add_separator()
	
	# Check achievements button
	var check_btn = Button.new()
	check_btn.text = "Check Achievements Now"
	check_btn.modulate = Color(0.8, 1.0, 0.8)
	check_btn.pressed.connect(_check_achievements)
	stats_container.add_child(check_btn)

func _add_separator():
	var sep = HSeparator.new()
	stats_container.add_child(sep)
	
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	stats_container.add_child(spacer)

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
		"current_xp":
			return XPManager.current_xp if XPManager else 0
		"current_level":
			return XPManager.current_level if XPManager else 1
		_:
			return stats.get(stat_id, 0)

# Modify _on_stat_changed to handle XP:
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
		"current_xp":
			if XPManager:
				XPManager.current_xp = int_value
				XPManager.save_xp_data()
		"current_level":
			if XPManager and XPManager.has_method("set_debug_level"):
				XPManager.set_debug_level(int_value)
		_:
			if stats.has(stat_id):
				stats[stat_id] = int_value
	
	# Also update current game stats for combo checking
	if stat_id == "longest_combo":
		StatsManager.current_game_stats.highest_combo = int_value

func _unlock_all_achievements():
	if AchievementManager:
		for achievement_id in AchievementManager.achievements:
			AchievementManager.unlock_achievement(achievement_id)
		print("All achievements unlocked!")

func _give_stars():
	if StarManager and StarManager.has_method("add_debug_stars"):
		StarManager.add_debug_stars(1000)
	else:
		print("StarManager not available or missing add_debug_stars method")
	print("Gave 1000 stars!")

func _max_all_stats():
	for stat_data in editable_stats:
		_on_stat_changed(stat_data.id, stat_data.max)
		# Update UI
		if stat_editors.has(stat_data.id):
			stat_editors[stat_data.id].slider.value = stat_data.max
	if StatsManager:
		StatsManager.save_stats()
	print("All stats maxed!")

func _reset_stats_with_confirm():
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to reset ALL statistics?\nThis cannot be undone!"
	dialog.confirmed.connect(_reset_stats)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _reset_stats():
	if StatsManager:
		StatsManager.reset_all_stats()
	# Update UI
	for stat_data in editable_stats:
		var value = _get_stat_value(stat_data.id)
		if stat_editors.has(stat_data.id):
			stat_editors[stat_data.id].slider.value = value
			stat_editors[stat_data.id].label.text = str(value)
	print("All stats reset!")

func _reset_achievements_with_confirm():
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to reset ALL achievements?\nThis cannot be undone!"
	dialog.confirmed.connect(_reset_achievements)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _reset_achievements():
	if AchievementManager:
		AchievementManager.reset_all_achievements()
	print("All achievements reset!")

func _check_achievements():
	# Save stats first
	if StatsManager:
		StatsManager.save_stats()
	# Then check achievements
	if AchievementManager:
		AchievementManager.check_achievements()
	print("Achievements checked!")

func show_panel():
	visible = true
	print("Debug panel shown")
	# Refresh values
	for stat_data in editable_stats:
		var value = _get_stat_value(stat_data.id)
		if stat_editors.has(stat_data.id):
			stat_editors[stat_data.id].slider.value = value
			stat_editors[stat_data.id].label.text = str(value)

func _reset_stars_with_confirm():
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to reset your stars to 0?\nThis cannot be undone!"
	dialog.confirmed.connect(_reset_stars)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _reset_stars():
	if StarManager and StarManager.has_method("reset_stars"):
		StarManager.reset_stars()
		print("Stars reset successfully!")
	else:
		print("StarManager not available or missing reset_stars method")

func _add_xp_controls():
	# XP Actions section
	var xp_label = Label.new()
	xp_label.text = "XP Controls"
	xp_label.add_theme_font_size_override("font_size", 16)
	xp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	stats_container.add_child(xp_label)
	
	# Add XP input
	var xp_input_container = HBoxContainer.new()
	
	var xp_input_label = Label.new()
	xp_input_label.text = "Add XP:"
	xp_input_label.custom_minimum_size.x = 80
	xp_input_container.add_child(xp_input_label)
	
	var xp_input = LineEdit.new()
	xp_input.name = "XPInput"
	xp_input.placeholder_text = "Amount"
	xp_input.custom_minimum_size.x = 100
	xp_input.text = "100"
	xp_input_container.add_child(xp_input)
	
	var add_xp_btn = Button.new()
	add_xp_btn.text = "Add"
	add_xp_btn.pressed.connect(func(): _add_custom_xp(xp_input.text))
	xp_input_container.add_child(add_xp_btn)
	
	stats_container.add_child(xp_input_container)
	
	# Level up button
	var level_up_btn = Button.new()
	level_up_btn.text = "Level Up (Add XP for Next Level)"
	level_up_btn.pressed.connect(_level_up_debug)
	stats_container.add_child(level_up_btn)
	
	# Give 1000 XP button
	var give_xp_btn = Button.new()
	give_xp_btn.text = "Give 1000 XP"
	give_xp_btn.pressed.connect(func(): _add_custom_xp("1000"))
	stats_container.add_child(give_xp_btn)

func _add_custom_xp(amount_text: String):
	var amount = amount_text.to_int()
	if amount > 0 and XPManager and XPManager.has_method("add_debug_xp"):
		XPManager.add_debug_xp(amount)
		print("Added %d XP!" % amount)
		# Update UI
		if stat_editors.has("current_xp"):
			stat_editors["current_xp"].slider.value = XPManager.current_xp
			stat_editors["current_xp"].label.text = str(XPManager.current_xp)
		if stat_editors.has("current_level"):
			stat_editors["current_level"].slider.value = XPManager.current_level
			stat_editors["current_level"].label.text = str(XPManager.current_level)

func _level_up_debug():
	if XPManager:
		var needed = XPManager.get_xp_for_next_level() - XPManager.current_xp
		if needed > 0:
			XPManager.add_debug_xp(needed)
			print("Added %d XP to level up!" % needed)
		else:
			print("Already at max XP for current level")

func _reset_xp_with_confirm():
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to reset XP and Level?\nThis cannot be undone!"
	dialog.confirmed.connect(_reset_xp)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _reset_xp():
	if XPManager and XPManager.has_method("reset_xp"):
		XPManager.reset_xp()
		# Update UI
		if stat_editors.has("current_xp"):
			stat_editors["current_xp"].slider.value = 0
			stat_editors["current_xp"].label.text = "0"
		if stat_editors.has("current_level"):
			stat_editors["current_level"].slider.value = 1
			stat_editors["current_level"].label.text = "1"
		print("XP and Level reset!")

func _reset_missions_with_confirm():
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to reset ALL missions?\nThis cannot be undone!"
	dialog.confirmed.connect(_reset_missions)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _reset_missions():
	if MissionManager and MissionManager.has_method("reset_all_missions"):
		MissionManager.reset_all_missions()
		print("All missions reset!")
	else:
		print("MissionManager not available or missing reset_all_missions method")
		
func _complete_all_missions():
	if MissionManager:
		# Complete all daily missions
		for mission_id in MissionManager.daily_missions:
			MissionManager.debug_complete_mission(mission_id)
		# Complete all season missions
		for mission_id in MissionManager.season_missions:
			MissionManager.debug_complete_mission(mission_id)
		# Complete all event missions
		for mission_id in MissionManager.event_missions:
			MissionManager.debug_complete_mission(mission_id)
		print("All missions completed!")

func _reset_all_with_confirm():
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "⚠️ WARNING ⚠️\n\nThis will reset:\n• All Statistics\n• All Achievements\n• All Stars\n• All XP & Levels\n• All Missions\n\nThis CANNOT be undone!\n\nAre you absolutely sure?"
	dialog.confirmed.connect(_reset_all)
	dialog.get_ok_button().text = "Yes, Reset Everything"
	dialog.get_ok_button().modulate = Color(1.0, 0.5, 0.5)
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2(400, 300))

func _reset_all():
	print("=== RESETTING EVERYTHING ===")
	
	# Reset stats
	if StatsManager:
		StatsManager.reset_all_stats()
		print("✓ Stats reset")
	
	# Reset achievements
	if AchievementManager:
		AchievementManager.reset_all_achievements()
		print("✓ Achievements reset")
	
	# Reset stars
	if StarManager and StarManager.has_method("reset_stars"):
		StarManager.reset_stars()
		print("✓ Stars reset")
	
	# Reset XP
	if XPManager and XPManager.has_method("reset_xp"):
		XPManager.reset_xp()
		print("✓ XP & Level reset")
	
	# Reset missions
	if MissionManager and MissionManager.has_method("reset_all_missions"):
		MissionManager.reset_all_missions()
		print("✓ Missions reset")
	
	print("=== ALL SYSTEMS RESET ===")
	
	# Update all UI elements
	for stat_data in editable_stats:
		var value = _get_stat_value(stat_data.id)
		if stat_editors.has(stat_data.id):
			stat_editors[stat_data.id].slider.value = value
			stat_editors[stat_data.id].label.text = str(value)
	
	print("Debug panel UI updated")
