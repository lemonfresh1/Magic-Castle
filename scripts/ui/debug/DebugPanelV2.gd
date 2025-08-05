# DebugPanelV2.gd - Enhanced debug panel with tabs and granular controls
# Location: res://Magic-Castle/scripts/ui/debug/DebugPanelV2.gd
# Last Updated: Created tabbed interface with mission controls [Date]
extends Panel

signal debug_panel_closed

# Tab references
var tab_container: TabContainer
var close_button: Button

# Tab controls
var missions_tab: Control
var season_pass_tab: Control
var holiday_tab: Control
var stats_tab: Control
var cheats_tab: Control

func _init():
	# Set panel properties
	modulate = Color(1, 1, 1, 0.95)
	custom_minimum_size = Vector2(600, 500)
	
	# Create the UI structure
	_create_ui()

func _ready():
	print("DebugPanelV2 ready")
	
	# Setup close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Setup tabs
	_setup_missions_tab()
	_setup_season_pass_tab()
	_setup_holiday_tab()
	_setup_stats_tab()
	_setup_cheats_tab()
	
	# Start hidden
	hide()

func _create_ui():
	# Main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)
	
	var title_label = Label.new()
	title_label.text = "Debug Panel"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	header.add_child(close_button)
	
	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Tab container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT
	vbox.add_child(tab_container)
	
	# Create tabs
	missions_tab = Control.new()
	missions_tab.name = "Missions"
	tab_container.add_child(missions_tab)
	
	season_pass_tab = Control.new()
	season_pass_tab.name = "Season Pass"
	tab_container.add_child(season_pass_tab)
	
	holiday_tab = Control.new()
	holiday_tab.name = "Holiday"
	tab_container.add_child(holiday_tab)
	
	stats_tab = Control.new()
	stats_tab.name = "Stats"
	tab_container.add_child(stats_tab)
	
	cheats_tab = Control.new()
	cheats_tab.name = "Cheats"
	tab_container.add_child(cheats_tab)

func _setup_missions_tab():
	if not missions_tab:
		return
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	missions_tab.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Mission Debug Controls"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Reset buttons
	var reset_label = Label.new()
	reset_label.text = "Reset Options:"
	reset_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(reset_label)
	
	var reset_grid = GridContainer.new()
	reset_grid.columns = 2
	reset_grid.add_theme_constant_override("h_separation", 20)
	reset_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(reset_grid)
	
	# Reset all button
	var reset_all_btn = _create_debug_button("Reset ALL Missions", Color.RED)
	reset_all_btn.pressed.connect(_on_reset_all_missions)
	reset_grid.add_child(reset_all_btn)
	
	# Reset daily button
	var reset_daily_btn = _create_debug_button("Reset Daily Only", Color.ORANGE)
	reset_daily_btn.pressed.connect(_on_reset_daily_missions)
	reset_grid.add_child(reset_daily_btn)
	
	# Reset weekly button
	var reset_weekly_btn = _create_debug_button("Reset Weekly Only", Color.ORANGE)
	reset_weekly_btn.pressed.connect(_on_reset_weekly_missions)
	reset_grid.add_child(reset_weekly_btn)
	
	# Force complete buttons
	vbox.add_child(HSeparator.new())
	
	var complete_label = Label.new()
	complete_label.text = "Force Complete Missions:"
	complete_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(complete_label)
	
	# Mission list for completion
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 200)
	vbox.add_child(scroll)
	
	var mission_list = VBoxContainer.new()
	mission_list.name = "MissionList"
	scroll.add_child(mission_list)
	
	# Refresh button
	var refresh_btn = _create_debug_button("Refresh Mission List", Color.BLUE)
	refresh_btn.pressed.connect(_refresh_mission_list)
	vbox.add_child(refresh_btn)

func _setup_season_pass_tab():
	if not season_pass_tab:
		return
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	season_pass_tab.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Season Pass Debug"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Progress controls
	var sp_grid = GridContainer.new()
	sp_grid.columns = 2
	sp_grid.add_theme_constant_override("h_separation", 20)
	sp_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(sp_grid)
	
	# Add SP button
	var add_sp_btn = _create_debug_button("Add 100 SP", Color.GREEN)
	add_sp_btn.pressed.connect(func(): _add_season_points(100))
	sp_grid.add_child(add_sp_btn)
	
	# Add tier button
	var add_tier_btn = _create_debug_button("Complete Tier", Color.GREEN)
	add_tier_btn.pressed.connect(_complete_current_tier)
	sp_grid.add_child(add_tier_btn)
	
	# Reset progress
	var reset_sp_btn = _create_debug_button("Reset Season Pass", Color.RED)
	reset_sp_btn.pressed.connect(_reset_season_pass)
	sp_grid.add_child(reset_sp_btn)
	
	# Grant premium
	var premium_btn = _create_debug_button("Grant Premium Pass", Color.PURPLE)
	premium_btn.pressed.connect(_grant_premium_pass)
	sp_grid.add_child(premium_btn)

func _setup_holiday_tab():
	if not holiday_tab:
		return
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	holiday_tab.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Holiday Event Debug"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Event controls
	var hp_grid = GridContainer.new()
	hp_grid.columns = 2
	hp_grid.add_theme_constant_override("h_separation", 20)
	hp_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(hp_grid)
	
	# Add HP button
	var add_hp_btn = _create_debug_button("Add 100 HP", Color.GREEN)
	add_hp_btn.pressed.connect(func(): _add_holiday_points(100))
	hp_grid.add_child(add_hp_btn)
	
	# Complete event tier
	var complete_hp_btn = _create_debug_button("Complete Event Tier", Color.GREEN)
	complete_hp_btn.pressed.connect(_complete_holiday_tier)
	hp_grid.add_child(complete_hp_btn)
	
	# Reset event
	var reset_hp_btn = _create_debug_button("Reset Holiday Event", Color.RED)
	reset_hp_btn.pressed.connect(_reset_holiday_event)
	hp_grid.add_child(reset_hp_btn)
	
	# Force activate event
	var activate_btn = _create_debug_button("Force Activate Event", Color.PURPLE)
	activate_btn.pressed.connect(_force_activate_event)
	hp_grid.add_child(activate_btn)

func _setup_stats_tab():
	if not stats_tab:
		return
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	stats_tab.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Stats & Progress Viewer"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Stats display
	var stats_label = RichTextLabel.new()
	stats_label.name = "StatsDisplay"
	stats_label.custom_minimum_size = Vector2(400, 300)
	stats_label.bbcode_enabled = true
	vbox.add_child(stats_label)
	
	# Refresh button
	var refresh_btn = _create_debug_button("Refresh Stats", Color.BLUE)
	refresh_btn.pressed.connect(_refresh_stats_display)
	vbox.add_child(refresh_btn)

func _setup_cheats_tab():
	if not cheats_tab:
		return
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	cheats_tab.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Game Cheats"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Cheat grid
	var cheat_grid = GridContainer.new()
	cheat_grid.columns = 2
	cheat_grid.add_theme_constant_override("h_separation", 20)
	cheat_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(cheat_grid)
	
	# Add stars
	var stars_btn = _create_debug_button("Add 1000 Stars", Color.YELLOW)
	stars_btn.pressed.connect(func(): StarManager.add_stars(1000, "debug"))
	cheat_grid.add_child(stars_btn)
	
	# Add XP
	var xp_btn = _create_debug_button("Add 5000 XP", Color.CYAN)
	xp_btn.pressed.connect(func(): 
		if has_node("/root/XPManager"):
			get_node("/root/XPManager").add_xp(5000, "debug")
	)
	cheat_grid.add_child(xp_btn)
	
	# Win current game
	var win_btn = _create_debug_button("Instant Win", Color.GREEN)
	win_btn.pressed.connect(_force_win_game)
	cheat_grid.add_child(win_btn)
	
	# Max score
	var score_btn = _create_debug_button("Set Score 50000", Color.PURPLE)
	score_btn.pressed.connect(func(): GameState.score = 50000)
	cheat_grid.add_child(score_btn)

func _create_debug_button(text: String, color: Color = Color.WHITE) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 40)
	btn.add_theme_font_size_override("font_size", 14)
	
	# Create custom style
	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.3
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	return btn

# Mission functions
func _on_reset_all_missions():
	if UnifiedMissionManager:
		UnifiedMissionManager.debug_reset_all_missions()
		_show_notification("All missions reset!")

func _on_reset_daily_missions():
	if UnifiedMissionManager:
		UnifiedMissionManager._reset_daily_missions()
		UnifiedMissionManager.save_missions()
		_show_notification("Daily missions reset!")

func _on_reset_weekly_missions():
	if UnifiedMissionManager:
		UnifiedMissionManager._reset_weekly_missions()
		UnifiedMissionManager.save_missions()
		_show_notification("Weekly missions reset!")

func _refresh_mission_list():
	var mission_list = missions_tab.get_node("MissionList")
	if not mission_list:
		return
		
	# Clear existing
	for child in mission_list.get_children():
		child.queue_free()
	
	# Add all missions
	for system in UnifiedMissionManager.MissionSystem.values():
		var missions = UnifiedMissionManager.get_missions_for_system(system)
		
		for mission in missions:
			var hbox = HBoxContainer.new()
			
			var label = Label.new()
			label.text = "%s (%s)" % [mission["title"], mission["id"]]
			label.custom_minimum_size.x = 250
			hbox.add_child(label)
			
			var complete_btn = Button.new()
			complete_btn.text = "Complete"
			complete_btn.disabled = mission.get("is_completed", false)
			complete_btn.pressed.connect(func(): _force_complete_mission(mission["id"]))
			hbox.add_child(complete_btn)
			
			mission_list.add_child(hbox)

func _force_complete_mission(mission_id: String):
	if UnifiedMissionManager:
		UnifiedMissionManager.debug_complete_mission(mission_id)
		_show_notification("Mission completed: " + mission_id)
		_refresh_mission_list()

# Season Pass functions
func _add_season_points(amount: int):
	if has_node("/root/SeasonPassManager"):
		get_node("/root/SeasonPassManager").add_season_points(amount)
		_show_notification("Added %d Season Points" % amount)

func _complete_current_tier():
	if has_node("/root/SeasonPassManager"):
		var sp_mgr = get_node("/root/SeasonPassManager")
		var needed = sp_mgr.POINTS_PER_TIER - (sp_mgr.current_sp % sp_mgr.POINTS_PER_TIER)
		sp_mgr.add_season_points(needed)
		_show_notification("Completed current tier")

func _reset_season_pass():
	if has_node("/root/SeasonPassManager"):
		var sp_mgr = get_node("/root/SeasonPassManager")
		sp_mgr.current_sp = 0
		sp_mgr.current_tier = 1
		sp_mgr.claimed_tiers.clear()
		sp_mgr.save_data()
		_show_notification("Season Pass reset")

func _grant_premium_pass():
	if has_node("/root/SeasonPassManager"):
		get_node("/root/SeasonPassManager").has_premium = true
		get_node("/root/SeasonPassManager").save_data()
		_show_notification("Premium Pass granted")

# Holiday Event functions
func _add_holiday_points(amount: int):
	if has_node("/root/HolidayEventManager"):
		get_node("/root/HolidayEventManager").add_holiday_points(amount)
		_show_notification("Added %d Holiday Points" % amount)

func _complete_holiday_tier():
	if has_node("/root/HolidayEventManager"):
		var hp_mgr = get_node("/root/HolidayEventManager")
		var needed = hp_mgr.POINTS_PER_TIER - (hp_mgr.current_hp % hp_mgr.POINTS_PER_TIER)
		hp_mgr.add_holiday_points(needed)
		_show_notification("Completed holiday tier")

func _reset_holiday_event():
	if has_node("/root/HolidayEventManager"):
		var hp_mgr = get_node("/root/HolidayEventManager")
		hp_mgr.current_hp = 0
		hp_mgr.current_tier = 1
		hp_mgr.claimed_tiers.clear()
		hp_mgr.save_data()
		_show_notification("Holiday Event reset")

func _force_activate_event():
	if has_node("/root/HolidayEventManager"):
		get_node("/root/HolidayEventManager").is_event_active = true
		get_node("/root/HolidayEventManager").save_data()
		_show_notification("Holiday Event activated")

# Stats functions
func _refresh_stats_display():
	var stats_label = stats_tab.get_node("StatsDisplay")
	if not stats_label:
		return
		
	var stats_text = "[b]Current Game Stats:[/b]\n\n"
	
	# Mission stats
	stats_text += "[color=yellow]Missions:[/color]\n"
	var completed_count = 0
	var claimed_count = 0
	
	for system in UnifiedMissionManager.MissionSystem.values():
		var missions = UnifiedMissionManager.get_missions_for_system(system)
		for mission in missions:
			if mission.get("is_completed", false):
				completed_count += 1
			if mission.get("is_claimed", false):
				claimed_count += 1
	
	stats_text += "Completed: %d\n" % completed_count
	stats_text += "Claimed: %d\n\n" % claimed_count
	
	# Season Pass stats
	if has_node("/root/SeasonPassManager"):
		var sp_mgr = get_node("/root/SeasonPassManager")
		stats_text += "[color=purple]Season Pass:[/color]\n"
		stats_text += "Tier: %d / %d\n" % [sp_mgr.current_tier, sp_mgr.MAX_TIERS]
		stats_text += "SP: %d\n" % sp_mgr.current_sp
		stats_text += "Premium: %s\n\n" % ("Yes" if sp_mgr.has_premium else "No")
	
	# Holiday Event stats
	if has_node("/root/HolidayEventManager"):
		var hp_mgr = get_node("/root/HolidayEventManager")
		stats_text += "[color=red]Holiday Event:[/color]\n"
		stats_text += "Active: %s\n" % ("Yes" if hp_mgr.is_event_active else "No")
		stats_text += "Tier: %d / %d\n" % [hp_mgr.current_tier, hp_mgr.MAX_TIERS]
		stats_text += "HP: %d\n\n" % hp_mgr.current_hp
	
	# Player stats
	stats_text += "[color=cyan]Player:[/color]\n"
	stats_text += "Stars: %d\n" % StarManager.get_star_count()
	
	stats_label.bbcode_text = stats_text

# Game cheat functions
func _force_win_game():
	if GameState.game_active:
		GameState._end_game(true)
		_show_notification("Game won!")

# Utility
func _show_notification(text: String):
	# Simple notification - could be enhanced with actual popup
	print("[DEBUG] " + text)
	
	# Create temporary label
	var notif = Label.new()
	notif.text = text
	notif.add_theme_font_size_override("font_size", 16)
	notif.modulate = Color.GREEN
	notif.position = Vector2(size.x / 2 - 100, 10)
	add_child(notif)
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(notif, "modulate:a", 0.0, 0.5)
	tween.tween_callback(notif.queue_free)

func _on_close_pressed():
	debug_panel_closed.emit()
	hide()

func show_debug_panel():
	show()
	_refresh_mission_list()
	_refresh_stats_display()
