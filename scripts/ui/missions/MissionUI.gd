# MissionUI.gd - Daily and weekly missions interface
# Location: res://Magic-Castle/scripts/ui/missions/MissionUI.gd
# Last Updated: Created mission UI with daily/weekly tabs [Date]

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
	
	_setup_tabs()
	_populate_all_missions()

func _setup_tabs():
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		_setup_overview_tab(overview_tab)
	
	# Setup Daily Missions tab
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if daily_tab:
		_setup_daily_missions_tab(daily_tab)
	
	# Setup Weekly Missions tab
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if weekly_tab:
		_setup_weekly_missions_tab(weekly_tab)

func _setup_overview_tab(tab: Control):
	var scroll = tab.find_child("ScrollContainer", true, false)
	if not scroll:
		return
	
	# Clear any existing content
	for child in scroll.get_children():
		child.queue_free()
	
	# Create VBox
	var vbox = VBoxContainer.new()
	scroll.add_child(vbox)
	
	# Add "Coming Soon" label
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
		_style_filter_button(filter_button, "daily")
	
	# Setup scroll container
	var scroll = tab.find_child("ScrollContainer", true, false)
	if scroll:
		_setup_scroll_container(scroll)

func _setup_weekly_missions_tab(tab: Control):
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if not filter_button.item_selected.is_connected(_on_weekly_filter_changed):
			filter_button.item_selected.connect(_on_weekly_filter_changed)
		_style_filter_button(filter_button, "weekly")
	
	# Setup scroll container
	var scroll = tab.find_child("ScrollContainer", true, false)
	if scroll:
		_setup_scroll_container(scroll)

func _setup_scroll_container(scroll_container: ScrollContainer):
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(600, 300)

func _populate_all_missions():
	_populate_daily_missions()
	_populate_weekly_missions()

func _populate_daily_missions():
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if not daily_tab:
		return
	
	var scroll = daily_tab.find_child("ScrollContainer", true, false)
	if not scroll:
		return
	
	# Clear any existing content
	for child in scroll.get_children():
		child.queue_free()
	daily_mission_cards.clear()
	
	# Create VBox
	var vbox = VBoxContainer.new()
	vbox.name = "DailyMissionsVBox"
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	# Get daily missions as array
	var daily_missions_array = MissionManager.daily_missions.values()
	
	# Add mission cards
	for mission in daily_missions_array:
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
			"is_completed": MissionManager.is_mission_completed(mission.id),
			"is_claimed": false
		}
		
		# Apply filter
		var should_show = true
		match daily_filter_mode:
			"completed":
				should_show = mission_data.is_completed
			"open":
				should_show = not mission_data.is_completed
		
		if should_show:
			var card = mission_card_scene.instantiate()
			vbox.add_child(card)
			card.setup(mission_data, "daily")
			daily_mission_cards.append(card)

func _populate_weekly_missions():
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if not weekly_tab:
		return
	
	var scroll = weekly_tab.find_child("ScrollContainer", true, false)
	if not scroll:
		return
	
	# Clear any existing content
	for child in scroll.get_children():
		child.queue_free()
	weekly_mission_cards.clear()
	
	# Create VBox
	var vbox = VBoxContainer.new()
	vbox.name = "WeeklyMissionsVBox"
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	# Get weekly missions as array
	var weekly_missions_array = MissionManager.weekly_missions.values()
	
	# Add mission cards
	for mission in weekly_missions_array:
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
			"is_completed": MissionManager.is_mission_completed(mission.id),
			"is_claimed": false
		}
		
		# Apply filter
		var should_show = true
		match weekly_filter_mode:
			"completed":
				should_show = mission_data.is_completed
			"open":
				should_show = not mission_data.is_completed
		
		if should_show:
			var card = mission_card_scene.instantiate()
			vbox.add_child(card)
			card.setup(mission_data, "weekly")
			weekly_mission_cards.append(card)

func _on_daily_filter_changed(index: int):
	match index:
		0:
			daily_filter_mode = "all"
		1:
			daily_filter_mode = "open"
		2:
			daily_filter_mode = "completed"
	
	_populate_daily_missions()

func _on_weekly_filter_changed(index: int):
	match index:
		0:
			weekly_filter_mode = "all"
		1:
			weekly_filter_mode = "open"
		2:
			weekly_filter_mode = "completed"
	
	_populate_weekly_missions()

func _style_filter_button(button: OptionButton, type: String):
	var popup = button.get_popup()
	
	# Style based on mission type
	var color = Color("#5ABFFF") if type == "daily" else Color("#9B5AFF")  # Light blue for daily, purple for weekly
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = color
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	popup.add_theme_stylebox_override("panel", panel_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("hover", hover_style)

func show_mission_ui():
	visible = true
	_populate_all_missions()

func hide_mission_ui():
	visible = false
	mission_ui_closed.emit()

func refresh_missions():
	"""Called to refresh mission display when progress updates"""
	_populate_all_missions()
