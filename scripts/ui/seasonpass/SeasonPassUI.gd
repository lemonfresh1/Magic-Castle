# SeasonPassUI.gd - Season pass interface with tiers and missions
# Location: res://Magic-Castle/scripts/ui/season_pass/SeasonPassUI.gd
# Last Updated: Created season pass UI with mission display [Date]

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
	
	_setup_tabs()
	_populate_season_missions()

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

func _populate_season_missions():
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
	
	_populate_season_missions()

func _style_filter_button(button: OptionButton):
	var popup = button.get_popup()
	
	# Style the popup
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#FFB75A")  # Season orange
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	popup.add_theme_stylebox_override("panel", panel_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#FFC77A")
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("hover", hover_style)

func show_season_pass_ui():
	visible = true
	_populate_season_missions()

func hide_season_pass_ui():
	visible = false
	season_pass_ui_closed.emit()
