# MissionUI.gd - Daily and weekly missions interface
# Location: res://Magic-Castle/scripts/ui/missions/MissionUI.gd
# Last Updated: Fixed filter overlap issue like SeasonPassUI [Date]

extends PanelContainer

signal mission_ui_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Magic-Castle/scenes/ui/missions/MissionCard.tscn")

var daily_filter_mode: String = "all"  # all, completed, open
var weekly_filter_mode: String = "all"
var daily_mission_cards = []
var weekly_mission_cards = []

func _ready():
	# Wait for next frame to ensure nodes are ready
	await get_tree().process_frame
	
	if not tab_container:
		push_error("MissionUI: TabContainer not found!")
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "mission_ui")
	
	# Setup tabs only once
	call_deferred("_setup_tabs")
	call_deferred("_populate_all_missions")

func _setup_tabs():
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)
	
	# Setup Daily Missions tab
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if daily_tab:
		_setup_daily_missions_tab(daily_tab)
	
	# Setup Weekly Missions tab
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if weekly_tab:
		_setup_weekly_missions_tab(weekly_tab)

func _populate_overview_content(vbox: VBoxContainer) -> void:
	"""Content for Overview tab"""
	var label = Label.new()
	label.text = "Coming Soon"
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(label)

func _setup_daily_missions_tab(tab: Control):
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if not filter_button.item_selected.is_connected(_on_daily_filter_changed):
			filter_button.item_selected.connect(_on_daily_filter_changed)
		# Apply filter styling with daily blue theme color
		UIStyleManager.style_filter_button(filter_button, Color("#5ABFFF"))

func _setup_weekly_missions_tab(tab: Control):
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if not filter_button.item_selected.is_connected(_on_weekly_filter_changed):
			filter_button.item_selected.connect(_on_weekly_filter_changed)
		# Apply filter styling with weekly purple theme color
		UIStyleManager.style_filter_button(filter_button, Color("#9B5AFF"))

func _populate_all_missions():
	await _populate_daily_missions()
	await _populate_weekly_missions()

func _populate_daily_missions():
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if not daily_tab:
		return
	
	# Use UIStyleManager for consistent setup
	await UIStyleManager.setup_scrollable_content(daily_tab, _populate_daily_missions_content)

func _populate_daily_missions_content(vbox: VBoxContainer) -> void:
	"""Content for Daily Missions tab"""
	# Ensure VBox fills space and aligns to top
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	daily_mission_cards.clear()
	
	# Get daily missions as array
	var daily_missions_array = MissionManager.daily_missions.values()
	
	# Debug print
	print("Daily missions filter mode: ", daily_filter_mode)
	
	# Track if we have any missions to show
	var has_missions = false
	
	# Add mission cards
	for mission in daily_missions_array:
		# Get completion status
		var is_completed = MissionManager.is_mission_completed(mission.id)
		
		# Apply filter BEFORE creating the card
		var should_show = false
		match daily_filter_mode:
			"completed":
				should_show = is_completed
			"open":
				should_show = not is_completed
			"all":
				should_show = true
		
		print("Mission ", mission.id, " - completed: ", is_completed, ", should_show: ", should_show)
		
		if should_show:
			has_missions = true
			
			# Convert to format expected by MissionCard
			var mission_data = {
				"id": mission.id,
				"display_name": mission.title,
				"description": "%s %d/%d" % [mission.description, MissionManager.get_mission_progress(mission.id), mission.target],
				"current_value": MissionManager.get_mission_progress(mission.id),
				"target_value": mission.target,
				"rewards": {
					"stars": mission.get("reward_stars", 0),
					"xp": mission.get("reward_xp", 0)
				},
				"is_completed": is_completed,
				"is_claimed": false
			}
			
			var card = mission_card_scene.instantiate()
			vbox.add_child(card)
			card.setup(mission_data, "daily")
			daily_mission_cards.append(card)
	
	# If no missions match filter, show a message
	if not has_missions:
		var empty_label = Label.new()
		empty_label.text = "No missions to display"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(empty_label)

func _populate_weekly_missions():
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if not weekly_tab:
		return
	
	# Use UIStyleManager for consistent setup
	await UIStyleManager.setup_scrollable_content(weekly_tab, _populate_weekly_missions_content)

func _populate_weekly_missions_content(vbox: VBoxContainer) -> void:
	"""Content for Weekly Missions tab"""
	# Ensure VBox fills space and aligns to top
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	weekly_mission_cards.clear()
	
	# Get weekly missions as array
	var weekly_missions_array = MissionManager.weekly_missions.values()
	
	# Debug print
	print("Weekly missions filter mode: ", weekly_filter_mode)
	
	# Track if we have any missions to show
	var has_missions = false
	
	# Add mission cards
	for mission in weekly_missions_array:
		# Get completion status
		var is_completed = MissionManager.is_mission_completed(mission.id)
		
		# Apply filter BEFORE creating the card
		var should_show = false
		match weekly_filter_mode:
			"completed":
				should_show = is_completed
			"open":
				should_show = not is_completed
			"all":
				should_show = true
		
		print("Mission ", mission.id, " - completed: ", is_completed, ", should_show: ", should_show)
		
		if should_show:
			has_missions = true
			
			# Convert to format expected by MissionCard
			var mission_data = {
				"id": mission.id,
				"display_name": mission.title,
				"description": "%s %d/%d" % [mission.description, MissionManager.get_mission_progress(mission.id), mission.target],
				"current_value": MissionManager.get_mission_progress(mission.id),
				"target_value": mission.target,
				"rewards": {
					"stars": mission.get("reward_stars", 0),
					"xp": mission.get("reward_xp", 0)
				},
				"is_completed": is_completed,
				"is_claimed": false
			}
			
			var card = mission_card_scene.instantiate()
			vbox.add_child(card)
			card.setup(mission_data, "weekly")
			weekly_mission_cards.append(card)
	
	# If no missions match filter, show a message
	if not has_missions:
		var empty_label = Label.new()
		empty_label.text = "No missions to display"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(empty_label)

func _on_daily_filter_changed(index: int):
	match index:
		0:
			daily_filter_mode = "all"
		1:
			daily_filter_mode = "open"
		2:
			daily_filter_mode = "completed"
	
	_refresh_daily_missions()

func _on_weekly_filter_changed(index: int):
	match index:
		0:
			weekly_filter_mode = "all"
		1:
			weekly_filter_mode = "open"
		2:
			weekly_filter_mode = "completed"
	
	_refresh_weekly_missions()

func _refresh_daily_missions():
	"""Refresh daily missions without recreating structure"""
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if not daily_tab:
		return
	
	# Find the existing ContentVBox inside the ScrollContainer
	var scroll = daily_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			# Clear existing content
			for child in vbox.get_children():
				child.queue_free()
			
			# Wait for cleanup
			await get_tree().process_frame
			
			# Repopulate with filtered content
			_populate_daily_missions_content(vbox)
		else:
			push_error("ContentVBox not found in Daily Missions ScrollContainer")
	else:
		push_error("ScrollContainer not found in Daily Missions tab")

func _refresh_weekly_missions():
	"""Refresh weekly missions without recreating structure"""
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if not weekly_tab:
		return
	
	# Find the existing ContentVBox inside the ScrollContainer
	var scroll = weekly_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			# Clear existing content
			for child in vbox.get_children():
				child.queue_free()
			
			# Wait for cleanup
			await get_tree().process_frame
			
			# Repopulate with filtered content
			_populate_weekly_missions_content(vbox)
		else:
			push_error("ContentVBox not found in Weekly Missions ScrollContainer")
	else:
		push_error("ScrollContainer not found in Weekly Missions tab")

func show_mission_ui():
	visible = true
	_populate_all_missions()

func hide_mission_ui():
	visible = false
	mission_ui_closed.emit()

func refresh_missions():
	"""Called to refresh mission display when progress updates"""
	_populate_all_missions()
