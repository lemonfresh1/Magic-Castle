# MissionUI.gd - Daily and weekly missions interface
# Location: res://Magic-Castle/scripts/ui/missions/MissionUI.gd
# Last Updated: Simplified to use UnifiedMissionManager [Date]

extends PanelContainer

signal mission_ui_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Magic-Castle/scenes/ui/missions/MissionCard.tscn")

var daily_filter_mode: String = "all"  # all, completed, open
var weekly_filter_mode: String = "all"

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
	
	# Connect to mission updates with more specific handling
	if UnifiedMissionManager:
		UnifiedMissionManager.mission_progress_updated.connect(_on_mission_progress_updated)
		UnifiedMissionManager.mission_completed.connect(_on_mission_completed)
		UnifiedMissionManager.missions_reset.connect(_on_missions_reset)

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
	var summary = UnifiedMissionManager.get_mission_summary()
	
	var header = Label.new()
	header.text = "Mission Progress"
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)
	
	# Show progress for standard missions
	var standard_stats = summary.get("standard", {})
	var daily_label = Label.new()
	daily_label.text = "Daily: %d/%d completed" % [standard_stats.get("daily_complete", 0), standard_stats.get("daily_total", 0)]
	daily_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(daily_label)
	
	var weekly_label = Label.new()
	weekly_label.text = "Weekly: %d/%d completed" % [standard_stats.get("weekly_complete", 0), standard_stats.get("weekly_total", 0)]
	weekly_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(weekly_label)

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
	
	await UIStyleManager.setup_scrollable_content(daily_tab, _populate_daily_missions_content)

func _populate_daily_missions_content(vbox: VBoxContainer) -> void:
	"""Content for Daily Missions tab"""
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	# Get missions from UnifiedMissionManager
	var missions = UnifiedMissionManager.get_missions_for_system("standard", "daily")
	var filtered_missions = []
	
	# Apply filter
	for mission in missions:
		var should_show = false
		match daily_filter_mode:
			"completed":
				should_show = mission.is_completed
			"open":
				should_show = not mission.is_completed
			"all":
				should_show = true
		
		if should_show:
			filtered_missions.append(mission)
	
	# Sort missions: claimable first, then uncompleted, then claimed
	filtered_missions.sort_custom(func(a, b):
		# First priority: Claimable (completed but not claimed)
		var a_claimable = a.is_completed and not a.is_claimed
		var b_claimable = b.is_completed and not b.is_claimed
		if a_claimable != b_claimable:
			return a_claimable  # Claimable ones first
		
		# Second priority: Uncompleted vs claimed
		if a.is_claimed != b.is_claimed:
			return b.is_claimed  # Non-claimed ones first
		
		return false
	)
	
	# Show empty message if no missions
	if filtered_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No missions to display"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(empty_label)
		return
	
	# Add mission cards
	for mission_data in filtered_missions:
		var card = mission_card_scene.instantiate()
		vbox.add_child(card)
		card.setup(mission_data, "daily")
		
		# Connect claim signal
		if card.has_signal("mission_claimed"):
			card.mission_claimed.connect(func(mission_id): 
				UnifiedMissionManager.claim_mission(mission_id, "standard")
				_refresh_daily_missions()
			)

func _populate_weekly_missions():
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if not weekly_tab:
		return
	
	await UIStyleManager.setup_scrollable_content(weekly_tab, _populate_weekly_missions_content)

func _populate_weekly_missions_content(vbox: VBoxContainer) -> void:
	"""Content for Weekly Missions tab"""
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	# Get missions from UnifiedMissionManager
	var missions = UnifiedMissionManager.get_missions_for_system("standard", "weekly")
	var filtered_missions = []
	
	# Apply filter
	for mission in missions:
		var should_show = false
		match weekly_filter_mode:
			"completed":
				should_show = mission.is_completed
			"open":
				should_show = not mission.is_completed
			"all":
				should_show = true
		
		if should_show:
			filtered_missions.append(mission)
	
	# Sort missions: claimable first, then uncompleted, then claimed
	filtered_missions.sort_custom(func(a, b):
		# First priority: Claimable (completed but not claimed)
		var a_claimable = a.is_completed and not a.is_claimed
		var b_claimable = b.is_completed and not b.is_claimed
		if a_claimable != b_claimable:
			return a_claimable  # Claimable ones first
		
		# Second priority: Uncompleted vs claimed
		if a.is_claimed != b.is_claimed:
			return b.is_claimed  # Non-claimed ones first
		
		return false
	)
	
	# Show empty message if no missions
	if filtered_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No missions to display"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(empty_label)
		return
	
	# Add mission cards
	for mission_data in filtered_missions:
		var card = mission_card_scene.instantiate()
		vbox.add_child(card)
		card.setup(mission_data, "weekly")
		
		# Connect claim signal
		if card.has_signal("mission_claimed"):
			card.mission_claimed.connect(func(mission_id): 
				UnifiedMissionManager.claim_mission(mission_id, "standard")
				_refresh_weekly_missions()
			)

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
	"""Refresh daily missions"""
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if not daily_tab:
		return
	
	var scroll = daily_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			for child in vbox.get_children():
				child.queue_free()
			
			await get_tree().process_frame
			_populate_daily_missions_content(vbox)

func _refresh_weekly_missions():
	"""Refresh weekly missions"""
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if not weekly_tab:
		return
	
	var scroll = weekly_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			for child in vbox.get_children():
				child.queue_free()
			
			await get_tree().process_frame
			_populate_weekly_missions_content(vbox)

func _on_mission_progress_updated(mission_id: String, current: int, target: int, system: String):
	"""Handle real-time mission progress updates"""
	if system == "standard":
		# Find and update the specific mission card
		var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
		
		# Determine if this mission should be visible on current tab
		var is_daily_mission = "daily" in mission_id
		var is_weekly_mission = "weekly" in mission_id
		
		if (is_daily_mission and current_tab_name == "Daily Missions") or \
		   (is_weekly_mission and current_tab_name == "Weekly Missions"):
			# Find the card with this mission_id
			var found = false
			var container = tab_container.get_child(tab_container.current_tab)
			var scroll = container.find_child("ScrollContainer", true, false)
			if scroll:
				var vbox = scroll.find_child("ContentVBox", true, false)
				if vbox:
					for child in vbox.get_children():
						if child.has_method("update_progress") and child.mission_data.get("id") == mission_id:
							child.update_progress(current, target)
							found = true
							break
			
			if not found:
				# If not found, refresh the whole tab
				if is_daily_mission:
					_refresh_daily_missions()
				else:
					_refresh_weekly_missions()

func _on_mission_completed(mission_id: String, system: String):
	"""Handle mission completion notification"""
	if system == "standard":
		# Refresh the appropriate tab
		if "daily" in mission_id:
			_refresh_daily_missions()
		elif "weekly" in mission_id:
			_refresh_weekly_missions()

func _on_missions_reset(reset_type: String):
	"""Handle mission reset"""
	if reset_type == "daily":
		_refresh_daily_missions()
	elif reset_type == "weekly":
		_refresh_weekly_missions()

func show_mission_ui():
	visible = true
	_populate_all_missions()

func hide_mission_ui():
	visible = false
	mission_ui_closed.emit()

func refresh_missions():
	"""Called to refresh mission display"""
	_populate_all_missions()
