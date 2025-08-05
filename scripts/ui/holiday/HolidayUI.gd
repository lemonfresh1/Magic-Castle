# HolidayUI.gd - Holiday event interface with pass and missions
# Location: res://Magic-Castle/scripts/ui/holiday/HolidayUI.gd
# Last Updated: Simplified to use UnifiedMissionManager [Date]

extends PanelContainer

signal holiday_ui_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Magic-Castle/scenes/ui/missions/MissionCard.tscn")
@onready var pass_layout_scene = preload("res://Magic-Castle/scenes/ui/components/PassLayout.tscn")

var filter_mode: String = "all"  # all, completed, open
var pass_layout: PassLayout

func _ready():
	# Wait for next frame to ensure nodes are ready
	await get_tree().process_frame
	
	if not tab_container:
		push_error("HolidayUI: TabContainer not found!")
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "holiday_ui")
	
	# Connect tab changed signal
	if not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Setup tabs only once
	call_deferred("_setup_tabs")
	
	# Connect to mission updates
	if UnifiedMissionManager:
		UnifiedMissionManager.mission_completed.connect(_on_mission_completed)
		UnifiedMissionManager.missions_reset.connect(_on_missions_reset)

func _setup_tabs():
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)
	
	# Setup Holiday Pass tab with PassLayout
	var holiday_pass_tab = tab_container.get_node_or_null("Holiday Pass")
	if holiday_pass_tab:
		await _setup_holiday_pass_tab(holiday_pass_tab)
	
	# Setup Daily Missions tab
	var daily_missions_tab = tab_container.get_node_or_null("Daily Missions")
	if daily_missions_tab:
		_setup_missions_tab(daily_missions_tab, "daily")
	
	# Setup Weekly Missions tab
	var weekly_missions_tab = tab_container.get_node_or_null("Weekly Missions")
	if weekly_missions_tab:
		_setup_missions_tab(weekly_missions_tab, "weekly")
	
	# Populate current tab
	_populate_current_tab()

func _on_tab_changed(tab_idx: int):
	"""Handle tab changes"""
	print("Tab changed to: ", tab_container.get_tab_title(tab_idx))
	_populate_current_tab()

func _populate_current_tab():
	"""Populate content for the currently active tab"""
	var current_tab_idx = tab_container.current_tab
	var current_tab_name = tab_container.get_tab_title(current_tab_idx)
	var current_tab = tab_container.get_child(current_tab_idx)
	
	print("Populating tab: ", current_tab_name)
	
	match current_tab_name:
		"Daily Missions", "Weekly Missions":
			var scroll = current_tab.find_child("ScrollContainer", true, false)
			if scroll:
				var has_content = false
				for child in scroll.get_children():
					if child.name == "MarginContainer":
						has_content = true
						break
				
				if not has_content:
					print("No content found, setting up scrollable content")
					await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)
				else:
					print("Content exists, refreshing")
					await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)

func _setup_missions_tab(tab: Control, mission_type: String):
	"""Setup a missions tab with filter button"""
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if filter_button.get_item_count() == 0:
			filter_button.add_item("All")
			filter_button.add_item("Open")
			filter_button.add_item("Completed")
			filter_button.selected = 0
		
		if not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed)
		
		# Apply filter styling with holiday red theme color
		UIStyleManager.style_filter_button(filter_button, Color("#FF5A5A"))

func _setup_holiday_pass_tab(holiday_pass_tab: Control):
	"""Setup the Holiday Pass tab with PassLayout inside scrollable content"""
	await UIStyleManager.setup_scrollable_content(holiday_pass_tab, _populate_holiday_pass_content)

func _populate_overview_content(vbox: VBoxContainer) -> void:
	"""Content for Overview tab"""
	# For now, still using SeasonPassManager for tier/pass info
	# In future, could have separate HolidayPassManager
	var season_info = SeasonPassManager.get_season_info()
	
	var header = Label.new()
	header.text = "Winter Wonderland"  # Holiday theme name
	header.add_theme_font_size_override("font_size", 32)
	header.add_theme_color_override("font_color", Color("#FF5A5A"))  # Holiday red
	vbox.add_child(header)
	
	# Holiday stats
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 8)
	vbox.add_child(stats_container)
	
	var current_tier_label = Label.new()
	current_tier_label.text = "Current Tier: %d / %d" % [season_info.current_tier, SeasonPassManager.MAX_TIER]
	current_tier_label.add_theme_font_size_override("font_size", 20)
	stats_container.add_child(current_tier_label)
	
	var progress = SeasonPassManager.get_tier_progress()
	var progress_label = Label.new()
	progress_label.text = "Progress: %d / %d HP (%.1f%%)" % [progress.current_sp, progress.required_sp, progress.percentage * 100]
	progress_label.add_theme_font_size_override("font_size", 18)
	stats_container.add_child(progress_label)
	
	var premium_status = Label.new()
	premium_status.text = "Holiday Pass: %s" % ("ACTIVE" if season_info.has_premium else "FREE")
	premium_status.add_theme_font_size_override("font_size", 18)
	premium_status.add_theme_color_override("font_color", Color("#FFD700") if season_info.has_premium else Color("#CCCCCC"))
	stats_container.add_child(premium_status)
	
	# Mission summary from UnifiedMissionManager
	var separator = HSeparator.new()
	separator.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(separator)
	
	var summary = UnifiedMissionManager.get_mission_summary()
	var holiday_stats = summary.get("holiday", {})
	
	var mission_header = Label.new()
	mission_header.text = "Holiday Missions"
	mission_header.add_theme_font_size_override("font_size", 20)
	vbox.add_child(mission_header)
	
	var daily_progress = Label.new()
	daily_progress.text = "Daily: %d/%d completed" % [holiday_stats.get("daily_complete", 0), holiday_stats.get("daily_total", 0)]
	daily_progress.add_theme_font_size_override("font_size", 16)
	vbox.add_child(daily_progress)
	
	var weekly_progress = Label.new()
	weekly_progress.text = "Weekly: %d/%d completed" % [holiday_stats.get("weekly_complete", 0), holiday_stats.get("weekly_total", 0)]
	weekly_progress.add_theme_font_size_override("font_size", 16)
	vbox.add_child(weekly_progress)
	
	# Add another separator
	var separator2 = HSeparator.new()
	separator2.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(separator2)
	
	# Purchase premium button if not owned
	if not season_info.has_premium:
		var purchase_button = Button.new()
		purchase_button.text = "Unlock Holiday Pass - 1000 Stars"
		purchase_button.custom_minimum_size = Vector2(300, 60)
		purchase_button.pressed.connect(_on_purchase_premium)
		vbox.add_child(purchase_button)
		
		# Style the button
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color("#FF5A5A")
		button_style.set_corner_radius_all(8)
		purchase_button.add_theme_stylebox_override("normal", button_style)
		
		var hover_style = button_style.duplicate()
		hover_style.bg_color = Color("#FF7A7A")
		purchase_button.add_theme_stylebox_override("hover", hover_style)
		
		purchase_button.add_theme_font_size_override("font_size", 20)
		purchase_button.add_theme_color_override("font_color", Color.WHITE)

func _populate_holiday_pass_content(vbox: VBoxContainer) -> void:
	"""Content for Holiday Pass tab using UIStyleManager structure"""
	pass_layout = pass_layout_scene.instantiate()
	vbox.add_child(pass_layout)
	
	# Configure pass layout
	pass_layout.pass_type = "season"  # Use season system for now
	pass_layout.theme_type = "holiday"  # Holiday theme
	pass_layout.auto_scroll_to_current = true
	
	# Make PassLayout fill available space
	pass_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Connect signals
	if not pass_layout.tier_clicked.is_connected(_on_tier_clicked):
		pass_layout.tier_clicked.connect(_on_tier_clicked)
	if not pass_layout.reward_claimed.is_connected(_on_reward_claimed):
		pass_layout.reward_claimed.connect(_on_reward_claimed)

func _populate_missions_content(vbox: VBoxContainer) -> void:
	"""Content for Missions tab - filtered by current tab"""
	print("=== Populating missions with filter: ", filter_mode, " ===")
	
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	# Determine which tab we're in
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	
	print("Current tab: ", current_tab_name, " - Type: ", mission_type)
	
	# Get missions from UnifiedMissionManager
	var missions = UnifiedMissionManager.get_missions_for_system("holiday", mission_type)
	var filtered_missions = []
	
	# Apply filter
	for mission in missions:
		var should_show = false
		match filter_mode:
			"completed":
				should_show = mission.is_completed
			"open":
				should_show = not mission.is_completed
			_:  # "all"
				should_show = true
		
		if should_show:
			filtered_missions.append(mission)
	
	print("Filtered missions count: ", filtered_missions.size())
	
	# If no missions match filter, show a message
	if filtered_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No missions to display"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(empty_label)
		return
	
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
	
	# Add mission cards
	for mission in filtered_missions:
		var card = mission_card_scene.instantiate()
		vbox.add_child(card)
		card.setup(mission, "holiday")  # Use holiday theme
		print("Added mission card: ", mission.display_name)
		
		# Connect claim signal
		if card.has_signal("mission_claimed"):
			card.mission_claimed.connect(func(mission_id): 
				UnifiedMissionManager.claim_mission(mission_id, "holiday")
				_refresh_missions()
			)

func _on_tier_clicked(tier_number: int):
	"""Handle tier click from PassLayout"""
	print("Tier %d clicked" % tier_number)

func _on_reward_claimed(tier_number: int, is_premium: bool):
	"""Handle reward claimed from PassLayout"""
	print("Reward claimed - Tier: %d, Premium: %s" % [tier_number, is_premium])
	
	# Refresh overview if visible
	if tab_container.current_tab == 0:
		_refresh_overview()

func _on_purchase_premium():
	"""Handle premium pass purchase"""
	if SeasonPassManager.purchase_premium_pass():
		print("Holiday pass purchased!")
		# Update pass layout
		if pass_layout:
			pass_layout.set_premium_status(true)
		# Refresh overview
		_refresh_overview()
	else:
		print("Failed to purchase holiday pass - not enough stars")

func _refresh_overview():
	"""Refresh the overview tab content"""
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)

func _on_filter_changed(index: int):
	print("Filter changed to index: ", index)
	match index:
		0:
			filter_mode = "all"
		1:
			filter_mode = "open"
		2:
			filter_mode = "completed"
	
	print("New filter mode: ", filter_mode)
	_refresh_missions()

func _refresh_missions():
	"""Refresh missions when filter changes"""
	print("Refreshing missions with filter: ", filter_mode)
	
	var current_tab_idx = tab_container.current_tab
	var current_tab = tab_container.get_child(current_tab_idx)
	var current_tab_name = tab_container.get_tab_title(current_tab_idx)
	
	# Only refresh if we're on a missions tab
	if current_tab_name in ["Daily Missions", "Weekly Missions"]:
		var scroll = current_tab.find_child("ScrollContainer", true, false)
		if scroll:
			var vbox = scroll.find_child("ContentVBox", true, false)
			if vbox:
				for child in vbox.get_children():
					child.queue_free()
				
				await get_tree().process_frame
				_populate_missions_content(vbox)

func _on_mission_completed(mission_id: String, system: String):
	"""Handle mission completion from UnifiedMissionManager"""
	if system == "holiday":
		# Refresh the appropriate tab if visible
		var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
		if ("daily" in mission_id and current_tab_name == "Daily Missions") or \
		   ("weekly" in mission_id and current_tab_name == "Weekly Missions"):
			_refresh_missions()
		
		# Update pass layout to show new tier progress
		if pass_layout:
			pass_layout.refresh()

func _on_missions_reset(reset_type: String):
	"""Handle mission reset from UnifiedMissionManager"""
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	if (reset_type == "daily" and current_tab_name == "Daily Missions") or \
	   (reset_type == "weekly" and current_tab_name == "Weekly Missions"):
		_refresh_missions()

func show_holiday_ui():
	visible = true
	# Populate current tab on show
	_populate_current_tab()
	
	# Refresh specific content based on current tab
	var current_tab_idx = tab_container.current_tab
	match current_tab_idx:
		0:  # Overview
			_refresh_overview()
		1:  # Holiday Pass
			if pass_layout:
				pass_layout.refresh()

func hide_holiday_ui():
	visible = false
	holiday_ui_closed.emit()
