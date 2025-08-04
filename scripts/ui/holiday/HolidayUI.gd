# HolidayUI.gd - Holiday event interface with missions and rewards
# Location: res://Magic-Castle/scripts/ui/holiday/HolidayUI.gd
# Last Updated: Fixed duplicate scroll container setup [Date]

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
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "holiday_ui")
	
	# Setup tabs only once
	call_deferred("_setup_tabs")

func _setup_tabs():
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)
	
	# Setup Battle Pass tab
	var battle_pass_tab = tab_container.get_node_or_null("Battle Pass")
	if battle_pass_tab:
		await UIStyleManager.setup_scrollable_content(battle_pass_tab, _populate_battle_pass_content)
	
	# Setup Missions tab with both filter and content
	var missions_tab = tab_container.get_node_or_null("Missions")
	if missions_tab:
		# Setup filter button first
		var filter_button = missions_tab.find_child("FilterButton", true, false)
		if filter_button:
			if not filter_button.item_selected.is_connected(_on_filter_changed):
				filter_button.item_selected.connect(_on_filter_changed)
			# Apply filter styling with holiday pink theme color
			UIStyleManager.style_filter_button(filter_button, Color("#FF5A8A"))
		
		# Then setup scrollable content
		await UIStyleManager.setup_scrollable_content(missions_tab, _populate_missions_content)

func _populate_overview_content(vbox: VBoxContainer) -> void:
	"""Content for Overview tab"""
	var label = Label.new()
	label.text = "Coming Soon"
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(label)

func _populate_battle_pass_content(vbox: VBoxContainer) -> void:
	"""Content for Battle Pass tab"""
	var label = Label.new()
	label.text = "Coming Soon"
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(label)

func _populate_missions_content(vbox: VBoxContainer) -> void:
	"""Content for Missions tab"""
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
	
	_refresh_missions()

func _refresh_missions():
	"""Refresh missions when filter changes"""
	var missions_tab = tab_container.get_node_or_null("Missions")
	if not missions_tab:
		return
		
	# Find the existing VBox and repopulate it
	var vbox = missions_tab.find_child("ContentVBox", true, false)
	if vbox:
		# Clear existing content
		for child in vbox.get_children():
			child.queue_free()
		await get_tree().process_frame
		
		# Repopulate with filtered content
		_populate_missions_content(vbox)

func show_holiday_ui():
	visible = true
	# Refresh missions on show
	_refresh_missions()

func hide_holiday_ui():
	visible = false
	holiday_ui_closed.emit()
