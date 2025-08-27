# MultiplayerScreen.gd - Works with existing scene structure
# Location: res://Pyramids/scenes/ui/menus/MultiplayerScreen.gd
# Last Updated: Integrated MultiplayerManager and GameSettingsPanel [Date]

extends Control

# Scene references
var highscores_panel_scene = preload("res://Pyramids/scenes/ui/components/HighscoresPanel.tscn")
var game_settings_panel_script = preload("res://Pyramids/scripts/ui/components/GameSettingsPanel.gd")

# Existing nodes from scene
@onready var background: ColorRect = $Background
@onready var main_container: MarginContainer = $MainContainer
@onready var content_hbox: HBoxContainer = $MainContainer/ContentHBox
@onready var left_section: Control = $MainContainer/ContentHBox/LeftSection
@onready var right_section: VBoxContainer = $MainContainer/ContentHBox/RightSection

# Top buttons
@onready var buttons_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/PanelContainer
@onready var buttons_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer
@onready var buttons_hbox: HBoxContainer = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer/ButtonsHBox
@onready var create_lobby_btn: Button = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer/ButtonsHBox/CreateLobby
@onready var join_lobby_btn: Button = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer/ButtonsHBox/JoinLobby
@onready var create_battleground_btn: Button = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer/ButtonsHBox/CreateBattleground
@onready var join_battleground_btn: Button = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer/ButtonsHBox/JoinBattleground
@onready var join_tournament_btn: Button = $MainContainer/ContentHBox/RightSection/PanelContainer/MarginContainer/ButtonsHBox/JoinTournament

# Middle section
@onready var middle_vbox: VBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox
@onready var game_mode_stats_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeStatsPanel
@onready var stats_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeStatsPanel/MarginContainer
@onready var stats_grid: GridContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeStatsPanel/MarginContainer/StatsGrid
@onready var game_mode_settings_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeSettingsPanel
@onready var settings_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeSettingsPanel/MarginContainer
@onready var settings_grid: GridContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeSettingsPanel/MarginContainer/SettingsGrid

# Right section buttons
@onready var right_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel
@onready var right_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer
@onready var right_vbox: VBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox
var swipe_mode_button_scene = preload("res://Pyramids/scenes/ui/components/SwipeModeButton.tscn")
@onready var mode_selector: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/ModeSelector
@onready var ranked_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/RankedButton
@onready var unranked_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/UnrankedButton
@onready var back_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/BackButton

# UI References
var leaderboard_panel: Control
var mode_description_label: RichTextLabel
var game_settings_component: Control  # NEW: Reusable settings panel

# State
var current_mode: String = "Classic"
var current_mode_id: String = "classic"
var current_queue_type: String = ""
var player_stats: Dictionary = {}

signal mode_selected(mode: String)
signal queue_joined(mode: String, queue_type: String)
signal lobby_action(action: String)

func _ready():
	_setup_styles()
	_setup_leaderboard()
	_setup_buttons()
	_setup_stats_panel()
	_setup_game_settings_component()  # NEW
	_load_player_stats()
	
	# Initialize MultiplayerManager if available
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.select_game_mode(current_mode_id)
		
		# Load local player data
		# TODO: Get real player data from save system
		mp_manager.set_local_player_data({
			"name": "Player",
			"level": 1,
			"prestige": 0,
			"stats": player_stats
		})
	
	if leaderboard_panel:
		leaderboard_panel.load_scores({})

func _setup_styles():
	"""Apply styles to existing nodes"""
	# Background gradient
	UIStyleManager.apply_menu_gradient_background(self)
	
	# Set margins for containers
	main_container.add_theme_constant_override("margin_left", 20)
	main_container.add_theme_constant_override("margin_right", 20)
	main_container.add_theme_constant_override("margin_top", 20)
	main_container.add_theme_constant_override("margin_bottom", 20)
	
	# Set separation for HBox
	content_hbox.add_theme_constant_override("separation", 20)
	
	# Set section ratios (50/50)
	left_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_section.size_flags_stretch_ratio = 0.5
	right_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_section.size_flags_stretch_ratio = 0.5
	
	# Style panels
	UIStyleManager.apply_panel_style(buttons_panel, "secondary")
	UIStyleManager.apply_panel_style(game_mode_stats_panel, "secondary")     # Player stats
	UIStyleManager.apply_panel_style(game_mode_settings_panel, "tertiary")  # Mode settings
	UIStyleManager.apply_panel_style(right_panel, "secondary")
	
	# Set margins for top button panel
	buttons_margin.add_theme_constant_override("margin_left", 20)
	buttons_margin.add_theme_constant_override("margin_right", 20)
	buttons_margin.add_theme_constant_override("margin_top", 15)
	buttons_margin.add_theme_constant_override("margin_bottom", 15)
	
	# Set margins for middle section panels (smaller margins for nested panels)
	stats_margin.add_theme_constant_override("margin_left", 15)
	stats_margin.add_theme_constant_override("margin_right", 15)
	stats_margin.add_theme_constant_override("margin_top", 12)
	stats_margin.add_theme_constant_override("margin_bottom", 12)
	
	settings_margin.add_theme_constant_override("margin_left", 15)
	settings_margin.add_theme_constant_override("margin_right", 15)
	settings_margin.add_theme_constant_override("margin_top", 12)
	settings_margin.add_theme_constant_override("margin_bottom", 12)
	
	# Set margins for right panel
	right_margin.add_theme_constant_override("margin_left", 20)
	right_margin.add_theme_constant_override("margin_right", 20)
	right_margin.add_theme_constant_override("margin_top", 15)
	right_margin.add_theme_constant_override("margin_bottom", 15)
	
	# Set spacing for VBoxes
	middle_vbox.add_theme_constant_override("separation", 15)
	right_vbox.add_theme_constant_override("separation", 15)
	
	# Set spacing for ButtonsHBox
	buttons_hbox.add_theme_constant_override("separation", 10)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Set spacing for RightSectionMain HBox
	var right_section_main = $MainContainer/ContentHBox/RightSection/RightSectionMain
	if right_section_main:
		right_section_main.add_theme_constant_override("separation", 15)

func _setup_leaderboard():
	"""Add leaderboard to left section"""
	leaderboard_panel = highscores_panel_scene.instantiate()
	left_section.add_child(leaderboard_panel)
	
	# Configure for multiplayer
	leaderboard_panel.setup({
		"title": "Leaderboard",
		"columns": [
			{"key": "rank", "label": "#", "width": 30, "align": "left", "format": "rank"},
			{"key": "player", "label": "Player", "width": 120, "align": "left", "format": "player"},
			{"key": "mmr", "label": "MMR", "width": 60, "align": "center", "format": "number"},
			{"key": "winrate", "label": "Win%", "width": 50, "align": "right", "format": "percent"}
		],
		"filters": [
			{"id": "global", "label": "Global", "default": true},
			{"id": "regional", "label": "Regional"},
			{"id": "friends", "label": "Friends"},
			{"id": "clan", "label": "Clan"}
		],
		"row_actions": ["challenge", "friend"],
		"filter_position": "top",
		"max_rows": 50,
		"show_title": true,
		"data_provider": _fetch_leaderboard_data
	})
	
	leaderboard_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_buttons():
	"""Configure existing buttons"""
	# Top action buttons
	create_lobby_btn.text = "➕ Lobby"
	create_lobby_btn.pressed.connect(func(): _on_lobby_action("create_lobby"))
	UIStyleManager.apply_button_style(create_lobby_btn, "secondary", "small")
	
	join_lobby_btn.text = "➡️ Lobby"
	join_lobby_btn.pressed.connect(func(): _on_lobby_action("join_lobby"))
	UIStyleManager.apply_button_style(join_lobby_btn, "secondary", "small")
	
	create_battleground_btn.text = "➕ Battle"
	create_battleground_btn.pressed.connect(func(): _on_lobby_action("create_battleground"))
	UIStyleManager.apply_button_style(create_battleground_btn, "secondary", "small")
	
	join_battleground_btn.text = "➡️ Battle"
	join_battleground_btn.pressed.connect(func(): _on_lobby_action("join_battleground"))
	UIStyleManager.apply_button_style(join_battleground_btn, "secondary", "small")
	
	join_tournament_btn.text = "🏆 Tournament"
	join_tournament_btn.focus_mode = Control.FOCUS_NONE
	join_tournament_btn.pressed.connect(func(): _on_lobby_action("join_tournament"))
	UIStyleManager.apply_button_style(join_tournament_btn, "secondary", "small")
	
	# Back button
	back_button.text = "Menu"
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.pressed.connect(_on_back_pressed)
	UIStyleManager.apply_button_style(back_button, "primary", "medium")
	
	# Configure but don't move the existing buttons
	ranked_button.text = "🏅 Ranked"
	ranked_button.focus_mode = Control.FOCUS_NONE
	ranked_button.custom_minimum_size = Vector2(0, 80)
	ranked_button.visible = false  # TODO: Enable ranked mode in future update
	ranked_button.pressed.connect(func(): _on_queue_selected("ranked"))
	UIStyleManager.apply_button_style(ranked_button, "primary", "large")
	
	# Rename Unranked to Play
	unranked_button.text = "▶️ Play"  # Changed from "🎮 Unranked"
	unranked_button.focus_mode = Control.FOCUS_NONE
	unranked_button.custom_minimum_size = Vector2(0, 80)
	unranked_button.pressed.connect(func(): _on_queue_selected("play"))
	UIStyleManager.apply_button_style(unranked_button, "success", "large")  # Changed to success (green) for main action
	
	back_button.text = "Menu"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.pressed.connect(_on_back_pressed)
	UIStyleManager.apply_button_style(back_button, "primary", "medium")
	
	# Now create and add new elements in order
	# Step 1 Label
	var step1_label = Label.new()
	step1_label.text = "Step 1: Select Mode"
	step1_label.add_theme_font_size_override("font_size", 16)
	step1_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_600)
	right_vbox.add_child(step1_label)
	right_vbox.move_child(step1_label, 0)  # Put at top
	
	# Mode selector
	if mode_selector:
		mode_selector.queue_free()
	
	var swipe_button = swipe_mode_button_scene.instantiate()
	swipe_button.name = "ModeSelector"
	swipe_button.custom_minimum_size = Vector2(0, 60)
	swipe_button.focus_mode = Control.FOCUS_NONE
	swipe_button.mode_changed.connect(_on_mode_changed)
	swipe_button.mode_id_changed.connect(_on_mode_id_changed)  # NEW: Connect to ID signal
	right_vbox.add_child(swipe_button)
	right_vbox.move_child(swipe_button, 1)  # After step 1 label
	
	mode_selector = swipe_button
	
	# Separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 10)
	separator.self_modulate.a = 0  # Invisible separator
	right_vbox.add_child(separator)
	right_vbox.move_child(separator, 2)  # After mode selector
	
	# Step 2 Label
	var step2_label = Label.new()
	step2_label.text = "Step 2: Press to Play"
	step2_label.add_theme_font_size_override("font_size", 16)
	step2_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_600)
	right_vbox.add_child(step2_label)
	right_vbox.move_child(step2_label, 3)  # After separator
	
	# Move the existing buttons to correct positions
	right_vbox.move_child(ranked_button, 4)    # After step 2 label (hidden)
	right_vbox.move_child(unranked_button, 5)  # After ranked (visible as "Play")
	right_vbox.move_child(back_button, 6)      # At the bottom

func _setup_stats_panel():
	"""Setup stats grid structure"""
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 10)
	
	# Add mode description label (hidden by default)
	mode_description_label = RichTextLabel.new()
	mode_description_label.name = "ModeDescription"
	mode_description_label.fit_content = true
	mode_description_label.bbcode_enabled = true
	mode_description_label.visible = false
	middle_vbox.add_child(mode_description_label)
	middle_vbox.move_child(mode_description_label, 0)  # Put before stats panel

func _setup_game_settings_component():
	"""Setup the reusable GameSettingsPanel component"""
	# Clear existing settings grid content
	for child in settings_grid.get_children():
		child.queue_free()
	
	# Create GameSettingsPanel component (VBoxContainer since the script extends it)
	game_settings_component = VBoxContainer.new()
	game_settings_component.set_script(game_settings_panel_script)
	settings_margin.add_child(game_settings_component)
	
	# Hide the old grid since we're using the component
	settings_grid.visible = false
	
	# Setup the component with initial mode
	if game_settings_component.has_method("setup_display"):
		game_settings_component.setup_display(current_mode_id, false, {
			"show_title": true,
			"compact": true
		})

func _load_player_stats():
	"""Load and display player statistics"""
	player_stats = {
		"mmr": 1250,
		"wins": 42,
		"losses": 18,
		"winrate": 70,
		"streak": 3,
		"rank": "Gold II"
	}
	
	_update_stats_display()

func _fetch_leaderboard_data(context: Dictionary) -> Array:
	"""Mock leaderboard data"""
	var mock_data = []
	for i in range(50):
		mock_data.append({
			"rank": i + 1,
			"player": "Player" + str(i + 1),
			"mmr": 2000 - (i * 10),
			"winrate": 75 - (i * 0.5)
		})
	return mock_data

func _on_lobby_action(action: String):
	print("Lobby action: " + action)
	
	match action:
		"create_lobby":
			# Create custom lobby with selected mode
			if has_node("/root/MultiplayerManager"):
				var mp_manager = get_node("/root/MultiplayerManager")
				mp_manager.select_game_mode(current_mode_id)
				mp_manager.create_custom_lobby()
				get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")
			else:
				push_error("MultiplayerManager not found!")
				
		"join_lobby":
			# TODO: Show lobby browser or join with code
			print("Join lobby - not implemented yet")
			
		"create_battleground":
			# TODO: Create battleground lobby
			print("Create battleground - not implemented yet")
			
		"join_battleground":
			# TODO: Join battleground
			print("Join battleground - not implemented yet")
			
		"join_tournament":
			# TODO: Show tournament browser
			print("Join tournament - not implemented yet")
	
	lobby_action.emit(action)

func _on_queue_selected(queue_type: String):
	"""Handle Play button - join or create lobby"""
	current_queue_type = queue_type
	
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		
		# Make sure mode is selected
		mp_manager.select_game_mode(current_mode_id)
		
		# TODO: Scan for existing lobbies with same mode
		print("Searching for %s lobby with mode: %s" % [queue_type, current_mode_id])
		
		# For MVP, immediately create/join lobby
		mp_manager.join_or_create_lobby()
	else:
		# Fallback to direct scene change
		print("MultiplayerManager not found, loading GameLobby directly")
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")

func _update_stats_display():
	"""Update the player stats grid"""
	# Clear existing
	for child in stats_grid.get_children():
		child.queue_free()
	
	var stats_to_show = [
		{"icon": "🏆", "label": "Rank", "value": player_stats.get("rank", "Unranked")},
		{"icon": "📊", "label": "MMR", "value": str(player_stats.get("mmr", 0))},
		{"icon": "📈", "label": "Win Rate", "value": str(player_stats.get("winrate", 0)) + "%"},
		{"icon": "🔥", "label": "Streak", "value": str(player_stats.get("streak", 0))},
		{"icon": "✅", "label": "Wins", "value": str(player_stats.get("wins", 0))},
		{"icon": "🎮", "label": "Games", "value": str(player_stats.get("wins", 0) + player_stats.get("losses", 0))}
	]
	
	for stat in stats_to_show:
		# Icon + Label
		var label_container = HBoxContainer.new()
		label_container.add_theme_constant_override("separation", 5)
		
		var icon = Label.new()
		icon.text = stat.icon
		icon.add_theme_font_size_override("font_size", 14)
		label_container.add_child(icon)
		
		var label = Label.new()
		label.text = stat.label + ":"
		label.add_theme_color_override("font_color", UIStyleManager.colors.gray_600)
		label_container.add_child(label)
		
		stats_grid.add_child(label_container)
		
		# Value
		var value = Label.new()
		value.text = stat.value
		value.add_theme_font_size_override("font_size", 16)
		value.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
		stats_grid.add_child(value)

func _get_mode_id_from_name(mode_name: String) -> String:
	"""Convert display name to mode ID"""
	match mode_name:
		"Classic": return "classic"
		"Rush": return "timed_rush"
		"Test": return "test"
		_: return "classic"

# Update handler for mode changes
func _on_mode_changed(mode: String):
	"""Handle mode name change (for display)"""
	current_mode = mode
	mode_selected.emit(mode)

func _on_mode_id_changed(mode_id: String):
	"""Handle mode ID change (for game logic)"""
	current_mode_id = mode_id
	
	# Update GameSettingsPanel
	if game_settings_component and game_settings_component.has_method("update_mode"):
		game_settings_component.update_mode(mode_id)
	
	# Update MultiplayerManager
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.select_game_mode(mode_id)
