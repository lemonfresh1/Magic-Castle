# SeasonPassUI.gd - Season pass interface with tiers and missions
# Location: res://Magic-Castle/scripts/ui/season_pass/SeasonPassUI.gd
# Last Updated: Fixed duplicate scroll container setup [Date]

extends PanelContainer

signal season_pass_ui_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Magic-Castle/scenes/ui/missions/MissionCard.tscn")

var filter_mode: String = "all"  # all, completed, open
var mission_cards = []

func _ready():
	# Wait for next frame to ensure nodes are ready
	await get_tree().process_frame
	
	if not tab_container:
		push_error("SeasonPassUI: TabContainer not found!")
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "season_pass_ui")
	
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
			# Apply filter styling with season orange theme color
			UIStyleManager.style_filter_button(filter_button, Color("#FFB75A"))
		
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
	# Clear previous cards
	mission_cards.clear()
	
	# Create season pass missions from current tier rewards
	var season_missions = _create_season_missions()
	
	# Apply filter
	var filtered_missions = []
	for mission in season_missions:
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
		card.setup(mission, "season")
		mission_cards.append(card)

func _create_season_missions() -> Array:
	# Convert season tiers into mission-like format for display
	var missions = []
	var current_level = SeasonPassManager.get_current_tier()
	var tiers = SeasonPassManager.get_season_tiers()
	
	# Create missions for next 5 unclaimed tiers
	var count = 0
	for tier in tiers:
		if count >= 5:
			break
			
		if not tier.free_claimed or (SeasonPassManager.season_data.has_premium_pass and not tier.premium_claimed):
			var mission_data = {
				"id": "season_tier_%d" % tier.tier,
				"display_name": "Reach Tier %d" % tier.tier,
				"description": "Progress to Season Pass Tier %d" % tier.tier,
				"current_value": current_level,
				"target_value": tier.tier,
				"rewards": {},
				"is_completed": tier.is_unlocked,
				"is_claimed": tier.free_claimed and tier.premium_claimed
			}
			
			# Combine rewards
			if not tier.free_claimed:
				for key in tier.free_rewards:
					mission_data.rewards[key] = tier.free_rewards[key]
			
			if SeasonPassManager.season_data.has_premium_pass and not tier.premium_claimed:
				for key in tier.premium_rewards:
					if mission_data.rewards.has(key):
						mission_data.rewards[key] += tier.premium_rewards[key]
					else:
						mission_data.rewards[key] = tier.premium_rewards[key]
			
			# Add SP (Season Points) as a reward type
			mission_data.rewards["sp"] = tier.tier * 10
			
			missions.append(mission_data)
			count += 1
	
	return missions

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

func show_season_pass_ui():
	visible = true
	# Refresh missions on show
	_refresh_missions()

func hide_season_pass_ui():
	visible = false
	season_pass_ui_closed.emit()
