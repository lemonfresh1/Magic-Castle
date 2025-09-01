# MissionUI.gd - Daily and weekly missions interface
# Location: res://Pyramids/scripts/ui/missions/MissionUI.gd
# Last Updated: Refactored to match SeasonPassUI structure [Date]

extends PanelContainer

signal mission_ui_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Pyramids/scenes/ui/missions/MissionCard.tscn")

var filter_mode: String = "all"  # all, completed, open - SINGLE filter for both tabs
var mission_cards = {}  # mission_id -> card instance
var pending_level_ups: Array = []
var claim_in_progress: bool = false

func _ready():
	# Wait for next frame to ensure nodes are ready
	await get_tree().process_frame
	
	if not tab_container:
		push_error("MissionUI: TabContainer not found!")
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "mission_ui")
	
	# Setup all tabs
	await _initialize_all_tabs()
	
	# Connect signals
	_connect_all_signals()
	
	# Populate current tab
	_populate_current_tab()
	
	if XPManager:
		XPManager.level_up_occurred.connect(_on_level_up_occurred)

func _initialize_all_tabs():
	"""Initialize all tabs"""
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)
		await get_tree().process_frame
	
	# Setup Daily Missions tab
	var daily_tab = tab_container.get_node_or_null("Daily Missions")
	if daily_tab:
		_setup_missions_tab(daily_tab, "daily")
		await get_tree().process_frame
	
	# Setup Weekly Missions tab
	var weekly_tab = tab_container.get_node_or_null("Weekly Missions")
	if weekly_tab:
		_setup_missions_tab(weekly_tab, "weekly")
		await get_tree().process_frame

func _connect_all_signals():
	"""Connect all signals after tabs are initialized"""
	# Connect tab changed signal
	if not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Connect to mission updates
	if UnifiedMissionManager:
		if not UnifiedMissionManager.mission_completed.is_connected(_on_mission_completed):
			UnifiedMissionManager.mission_completed.connect(_on_mission_completed)
		if not UnifiedMissionManager.missions_reset.is_connected(_on_missions_reset):
			UnifiedMissionManager.missions_reset.connect(_on_missions_reset)

func _setup_missions_tab(tab: Control, mission_type: String):
	"""Setup a missions tab with filter button - EXACT same as SeasonPassUI"""
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if filter_button.get_item_count() == 0:
			filter_button.add_item("All")
			filter_button.add_item("Open")
			filter_button.add_item("Completed")
			filter_button.selected = 0
		
		if not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed)
		
		# Apply filter styling with appropriate color
		var color = Color("#5ABFFF") if mission_type == "daily" else Color("#9B5AFF")
		UIStyleManager.style_filter_button(filter_button, color)

func _on_tab_changed(tab_idx: int):
	"""Handle tab changes"""
	_populate_current_tab()

func _populate_current_tab():
	"""Populate content for the currently active tab"""
	var current_tab_idx = tab_container.current_tab
	var current_tab_name = tab_container.get_tab_title(current_tab_idx)
	var current_tab = tab_container.get_child(current_tab_idx)
	
	match current_tab_name:
		"Overview":
			_refresh_overview()
		"Daily Missions", "Weekly Missions":
			var scroll = current_tab.find_child("ScrollContainer", true, false)
			if scroll:
				var has_content = false
				for child in scroll.get_children():
					if child.name == "MarginContainer":
						has_content = true
						break
				
				if not has_content:
					# First time - create content
					await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)
				else:
					# Update existing cards
					_update_mission_visibility()

func _populate_overview_content(vbox: VBoxContainer) -> void:
	"""Content for Overview tab"""
	var summary = UnifiedMissionManager.get_mission_summary()
	
	var header = Label.new()
	header.text = "Mission Progress"
	header.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_title"))
	header.add_theme_color_override("font_color", UIStyleManager.get_color("gray_900"))
	vbox.add_child(header)
	
	# Add some spacing after header
	var spacer = Control.new()
	spacer.custom_minimum_size.y = UIStyleManager.get_spacing("space_3")
	vbox.add_child(spacer)
	
	# Show progress for standard missions
	var standard_stats = summary.get("standard", {})
	var daily_label = Label.new()
	daily_label.text = "Daily: %d/%d completed" % [
		standard_stats.get("daily_complete", 0), 
		standard_stats.get("daily_total", 0)
	]
	daily_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	daily_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	vbox.add_child(daily_label)
	
	var weekly_label = Label.new()
	weekly_label.text = "Weekly: %d/%d completed" % [
		standard_stats.get("weekly_complete", 0), 
		standard_stats.get("weekly_total", 0)
	]
	weekly_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	weekly_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	vbox.add_child(weekly_label)

func _populate_missions_content(vbox: VBoxContainer) -> void:
	"""Initial population of missions - EXACT same structure as SeasonPassUI"""
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	# Clear mission cards tracking
	mission_cards.clear()
	
	# Determine which tab we're in
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	
	# Get all missions for this type
	var missions = UnifiedMissionManager.get_missions_for_system("standard", mission_type)
	
	# Sort missions: claimable first, then uncompleted, then claimed
	missions.sort_custom(func(a, b):
		var a_claimable = a.is_completed and not a.is_claimed
		var b_claimable = b.is_completed and not b.is_claimed
		if a_claimable != b_claimable:
			return a_claimable
		if a.is_claimed != b.is_claimed:
			return b.is_claimed
		return false
	)
	
	# Update the claim handler connection
	for mission in missions:
		var card = mission_card_scene.instantiate()
		vbox.add_child(card)
		card.setup(mission, mission_type)
		
		# Store reference to card
		mission_cards[mission.id] = card
		
		# Modified claim handler with level-up tracking
		if card.has_signal("mission_claimed"):
			card.mission_claimed.connect(func(mission_id): 
				claim_in_progress = true
				pending_level_ups.clear()
				UnifiedMissionManager.claim_mission(mission_id, "standard")
				_update_mission_visibility()
				call_deferred("_show_pending_notifications")
				claim_in_progress = false
			)
	
	# Apply initial filter
	_apply_mission_filter()

func _on_level_up_occurred(old_level: int, new_level: int, rewards: Dictionary):
	"""Track level-ups during mission claims"""
	if claim_in_progress:
		pending_level_ups.append({
			"old_level": old_level,
			"new_level": new_level,
			"rewards": rewards
		})

func _on_filter_changed(index: int):
	"""Handle filter change - SINGLE filter for both tabs"""
	match index:
		0:
			filter_mode = "all"
		1:
			filter_mode = "open"
		2:
			filter_mode = "completed"
	
	_apply_mission_filter()

func _apply_mission_filter():
	"""Show/hide mission cards based on current filter - EXACT same as SeasonPassUI"""
	var visible_count = 0
	
	# Get current missions data
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	var missions = UnifiedMissionManager.get_missions_for_system("standard", mission_type)
	
	# Update visibility for each card
	for mission in missions:
		if not mission_cards.has(mission.id):
			continue
			
		var card = mission_cards[mission.id]
		if not is_instance_valid(card):
			continue
		
		# Determine if card should be visible
		var should_show = false
		match filter_mode:
			"completed":
				should_show = mission.is_completed
			"open":
				should_show = not mission.is_completed
			_:  # "all"
				should_show = true
		
		card.visible = should_show
		if should_show:
			visible_count += 1
	
	# If no visible missions, show a message
	var current_tab = tab_container.get_child(tab_container.current_tab)
	var scroll = current_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			# Remove any existing empty message
			for child in vbox.get_children():
				if child.name == "EmptyMessage":
					child.queue_free()
			
			# Add empty message if needed
			if visible_count == 0:
				var empty_label = Label.new()
				empty_label.name = "EmptyMessage"
				empty_label.text = "No missions to display"
				empty_label.add_theme_font_size_override("font_size", 16)
				empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
				empty_label.modulate = Color(0.7, 0.7, 0.7)
				vbox.add_child(empty_label)

func _update_mission_visibility():
	"""Update mission cards - EXACT same structure as SeasonPassUI"""
	# Get fresh mission data
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	var missions = UnifiedMissionManager.get_missions_for_system("standard", mission_type)
	
	# Create a list to track cards that need repositioning
	var cards_to_reorder = []
	
	# Update each card with fresh data
	for mission in missions:
		if mission_cards.has(mission.id) and is_instance_valid(mission_cards[mission.id]):
			var card = mission_cards[mission.id]
			card.setup(mission, mission_type)  # Refresh the card data
			cards_to_reorder.append({"card": card, "mission": mission})
	
	# Re-sort and reposition cards without recreating them
	cards_to_reorder.sort_custom(func(a, b):
		var a_claimable = a.mission.is_completed and not a.mission.is_claimed
		var b_claimable = b.mission.is_completed and not b.mission.is_claimed
		if a_claimable != b_claimable:
			return a_claimable
		if a.mission.is_claimed != b.mission.is_claimed:
			return b.mission.is_claimed
		return false
	)
	
	# Get the parent vbox
	var current_tab = tab_container.get_child(tab_container.current_tab)
	var scroll = current_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			# Reorder children in VBox
			for i in range(cards_to_reorder.size()):
				var card_data = cards_to_reorder[i]
				vbox.move_child(card_data.card, i)
	
	# Reapply filter
	_apply_mission_filter()

func _refresh_overview():
	"""Refresh the overview tab content"""
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)

func _refresh_missions():
	"""Refresh missions when needed"""
	var current_tab_idx = tab_container.current_tab
	var current_tab_name = tab_container.get_tab_title(current_tab_idx)
	
	# Only refresh if we're on a missions tab
	if current_tab_name in ["Daily Missions", "Weekly Missions"]:
		if mission_cards.size() > 0:
			_update_mission_visibility()
		else:
			var current_tab = tab_container.get_child(current_tab_idx)
			await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)

func _on_mission_completed(mission_id: String, system: String):
	"""Handle mission completion from UnifiedMissionManager"""
	if system == "standard":
		var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
		if ("daily" in mission_id and current_tab_name == "Daily Missions") or \
		   ("weekly" in mission_id and current_tab_name == "Weekly Missions"):
			_update_mission_visibility()

func _on_missions_reset(reset_type: String):
	"""Handle mission reset from UnifiedMissionManager"""
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	if (reset_type == "daily" and current_tab_name == "Daily Missions") or \
	   (reset_type == "weekly" and current_tab_name == "Weekly Missions"):
		# On reset, we need to recreate cards
		mission_cards.clear()
		var current_tab = tab_container.get_child(tab_container.current_tab)
		await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)

func show_mission_ui():
	visible = true
	_populate_current_tab()

func hide_mission_ui():
	visible = false
	mission_ui_closed.emit()

func refresh_missions():
	"""Called to refresh mission display"""
	_refresh_missions()

func _show_pending_notifications():
	"""Show combined notification for mission + level-ups"""
	if pending_level_ups.size() > 0:
		var notification = preload("res://Pyramids/scenes/ui/dialogs/UnifiedRewardNotification.tscn").instantiate()
		get_tree().root.add_child(notification)
		notification.show_level_ups(pending_level_ups)
		pending_level_ups.clear()
