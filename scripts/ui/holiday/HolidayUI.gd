# HolidayUI.gd - Holiday event interface with missions and rewards
# Location: res://Magic-Castle/scripts/ui/holiday/HolidayUI.gd
# Last Updated: Created holiday UI with mission display [Date]

extends PanelContainer

signal holiday_ui_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Magic-Castle/scenes/ui/missions/MissionCard.tscn")

var filter_mode: String = "all"  # all, completed, open
var mission_cards = []

func _ready():
	# Wait for next frame to ensure nodes are ready
	await get_tree().process_frame
	
	if not tab_container:
		push_error("HolidayUI: TabContainer not found!")
		return
	
	_setup_tabs()
	_populate_missions()

func _setup_tabs():
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		_setup_overview_tab(overview_tab)
	
	# Setup Battle Pass tab
	var battle_pass_tab = tab_container.get_node_or_null("Battle Pass")
	if battle_pass_tab:
		_setup_battle_pass_tab(battle_pass_tab)
	
	# Setup Missions tab
	var missions_tab = tab_container.get_node_or_null("Missions")
	if missions_tab:
		_setup_missions_tab(missions_tab)

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

func _setup_battle_pass_tab(tab: Control):
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

func _setup_missions_tab(tab: Control):
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed)
		_style_filter_button(filter_button)
	
	# Setup scroll container
	var scroll = tab.find_child("ScrollContainer", true, false)
	if scroll:
		_setup_scroll_container(scroll)

func _setup_scroll_container(scroll_container: ScrollContainer):
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(600, 300)

func _populate_missions():
	var missions_tab = tab_container.get_node_or_null("Missions")
	if not missions_tab:
		return
	
	var scroll = missions_tab.find_child("ScrollContainer", true, false)
	if not scroll:
		return
	
	# Create VBox if it doesn't exist
	var vbox = scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "MissionsVBox"
		vbox.add_theme_constant_override("separation", 10)
		scroll.add_child(vbox)
	
	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	mission_cards.clear()
	
	# Get holiday missions
	var missions = HolidayEventManager.get_active_missions()
	
	# Apply filter
	var filtered_missions = []
	for mission in missions:
		match filter_mode:
			"completed":
				if mission.is_completed:
					filtered_missions.append(mission)
			"open":
				if not mission.is_completed:
					filtered_missions.append(mission)
			_:  # "all"
				filtered_missions.append(mission)
	
	# Add mission cards
	for mission in filtered_missions:
		var card = mission_card_scene.instantiate()
		vbox.add_child(card)
		card.setup_from_mission_object(mission, "holiday")
		mission_cards.append(card)

func _on_filter_changed(index: int):
	match index:
		0:
			filter_mode = "all"
		1:
			filter_mode = "open"
		2:
			filter_mode = "completed"
	
	_populate_missions()

func _style_filter_button(button: OptionButton):
	var popup = button.get_popup()
	
	# Style the popup
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#FF5A8A")  # Holiday pink
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	popup.add_theme_stylebox_override("panel", panel_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#FF7AA0")
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("hover", hover_style)

func show_holiday_ui():
	visible = true
	_populate_missions()

func hide_holiday_ui():
	visible = false
	holiday_ui_closed.emit()
