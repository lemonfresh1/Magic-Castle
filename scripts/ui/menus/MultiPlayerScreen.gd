# MultiplayerScreen.gd - Works with existing scene structure
# Location: res://Pyramids/scenes/ui/menus/MultiplayerScreen.gd
# Last Updated: Added debugging for stats issues [Date]

extends Control

# === DEBUG CONFIGURATION ===
var debug_enabled: bool = true  # Set to true for debugging
var global_debug: bool = true

# Scene references
var highscores_panel_scene = preload("res://Pyramids/scenes/ui/components/HighscoresPanel.tscn")
var game_settings_panel_script = preload("res://Pyramids/scripts/ui/components/GameSettingsPanel.gd")

# Existing nodes from scene
@onready var background: ColorRect = $Background
@onready var main_container: MarginContainer = $MainContainer
@onready var content_hbox: HBoxContainer = $MainContainer/ContentHBox
@onready var left_section: Control = $MainContainer/ContentHBox/LeftSection
@onready var right_section: VBoxContainer = $MainContainer/ContentHBox/RightSection

# Middle section
@onready var middle_vbox: VBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox
@onready var game_mode_stats_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeStatsPanel
@onready var stats_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeStatsPanel/MarginContainer
@onready var stats_grid: GridContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeStatsPanel/MarginContainer/StatsGrid
@onready var game_mode_settings_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeSettingsPanel
@onready var settings_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeSettingsPanel/MarginContainer
@onready var settings_grid: GridContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/MiddleSectionVBox/GameModeSettingsPanel/MarginContainer/SettingsGrid

# Right section panel and buttons
@onready var right_panel: PanelContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel
@onready var right_margin: MarginContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer
@onready var right_section_v_box: VBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox
@onready var h_box_container: HBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/HBoxContainer
@onready var solo_button: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/HBoxContainer/SoloButton
@onready var multiplayer_button: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/HBoxContainer/MultiplayerButton
@onready var mode_selector: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/ModeSelector
@onready var unranked_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/UnrankedButton
@onready var lobby_h_box: HBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox
@onready var create_lobby: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox/CreateLobby
@onready var join_lobby: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox/JoinLobby
@onready var battleground_h_box: HBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattlegroundHBox
@onready var create_battleground: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattlegroundHBox/CreateBattleground
@onready var join_battleground: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattlegroundHBox/JoinBattleground
@onready var join_tournament: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/JoinTournament
@onready var back_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/BackButton

# Old ranked button reference (to hide it)
@onready var ranked_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/RankedButton

# UI References
var leaderboard_panel: Control
var mode_description_label: RichTextLabel
var game_settings_component: Control
var multiplayer_leaderboard_script = preload("res://Pyramids/scripts/ui/components/MultiplayerLeaderboard.gd")
var swipe_mode_button_scene = preload("res://Pyramids/scenes/ui/components/SwipeModeButton.tscn")

# === ICON PATHS ===
const ICON_PATH_BASE = "res://Pyramids/assets/icons/menu/"

# State
var current_mode: String = "Classic"
var current_mode_id: String = "classic"
var current_queue_type: String = ""
var player_stats: Dictionary = {}
var is_solo_mode: bool = false  # false = multiplayer, true = solo

signal mode_selected(mode: String)
signal queue_joined(mode: String, queue_type: String)
signal lobby_action(action: String)

func debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[MultiplayerScreen] %s" % message)

func _ready():
	debug_log("=== READY START ===")
	
	# Load persistent selection first
	if SettingsSystem:
		var preferred_mode = SettingsSystem.get_preferred_play_mode()
		is_solo_mode = (preferred_mode == "Solo")
		debug_log("Loaded preferred mode: %s (is_solo: %s)" % [preferred_mode, is_solo_mode])
	else:
		is_solo_mode = false
		debug_log("No SettingsSystem, defaulting to multiplayer")
	
	_setup_styles()
	_setup_solo_multiplayer_buttons()
	_setup_leaderboard()
	_setup_buttons()
	_setup_stats_panel()
	_setup_game_settings_component()
	_load_player_stats()
	
	# Update UI based on loaded selection
	_update_solo_multiplayer_selection()
	_update_multiplayer_buttons_visibility()  # Update visibility on load
	_refresh_leaderboard_for_current_mode()
	
	# Initialize MultiplayerManager if available and in multiplayer mode
	if not is_solo_mode and has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.select_game_mode(current_mode_id)
		
		# Load local player data for multiplayer
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
	
	# Set section ratios (45/55) - more space for right section
	left_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_section.size_flags_stretch_ratio = 0.6
	right_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_section.size_flags_stretch_ratio = 1
	
	# Style panels
	UIStyleManager.apply_panel_style(game_mode_stats_panel, "secondary")
	UIStyleManager.apply_panel_style(game_mode_settings_panel, "tertiary")
	UIStyleManager.apply_panel_style(right_panel, "secondary")
	
	# Set margins for panels
	stats_margin.add_theme_constant_override("margin_left", 15)
	stats_margin.add_theme_constant_override("margin_right", 15)
	stats_margin.add_theme_constant_override("margin_top", 12)
	stats_margin.add_theme_constant_override("margin_bottom", 12)
	
	settings_margin.add_theme_constant_override("margin_left", 15)
	settings_margin.add_theme_constant_override("margin_right", 15)
	settings_margin.add_theme_constant_override("margin_top", 12)
	settings_margin.add_theme_constant_override("margin_bottom", 12)
	
	right_margin.add_theme_constant_override("margin_left", 20)
	right_margin.add_theme_constant_override("margin_right", 20)
	right_margin.add_theme_constant_override("margin_top", 15)
	right_margin.add_theme_constant_override("margin_bottom", 15)
	
	# Set spacing for VBoxes
	middle_vbox.add_theme_constant_override("separation", 15)
	right_section_v_box.add_theme_constant_override("separation", 15)
	
	# Set spacing for HBoxContainers
	lobby_h_box.add_theme_constant_override("separation", 10)
	battleground_h_box.add_theme_constant_override("separation", 10)
	
	# Set spacing for RightSectionMain HBox
	var right_section_main = $MainContainer/ContentHBox/RightSection/RightSectionMain
	if right_section_main:
		right_section_main.add_theme_constant_override("separation", 15)
	
	# Set minimum size for stats panel to prevent resizing
	game_mode_stats_panel.custom_minimum_size = Vector2(0, 120)

func _setup_solo_multiplayer_buttons():
	"""Setup the solo/multiplayer toggle buttons"""
	h_box_container.add_theme_constant_override("separation", 10)
	
	# Connect button signals
	solo_button.pressed.connect(_on_solo_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)

func _setup_leaderboard():
	"""Add multiplayer leaderboard to left section"""
	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.set_script(multiplayer_leaderboard_script)
	left_section.add_child(leaderboard_panel)
	
	# The script's _ready() will configure it automatically
	leaderboard_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_buttons():
	"""Configure existing buttons"""
	# Lobby buttons - keep text from scene
	create_lobby.pressed.connect(func(): _on_lobby_action("create_lobby"))
	UIStyleManager.apply_button_style(create_lobby, "secondary", "small")
	
	join_lobby.pressed.connect(func(): _on_lobby_action("join_lobby"))
	UIStyleManager.apply_button_style(join_lobby, "secondary", "small")
	
	# Battleground buttons - keep text from scene
	create_battleground.pressed.connect(func(): _on_lobby_action("create_battleground"))
	UIStyleManager.apply_button_style(create_battleground, "secondary", "small")
	
	join_battleground.pressed.connect(func(): _on_lobby_action("join_battleground"))
	UIStyleManager.apply_button_style(join_battleground, "secondary", "small")
	
	# Tournament button
	join_tournament.focus_mode = Control.FOCUS_NONE
	join_tournament.pressed.connect(func(): _on_lobby_action("join_tournament"))
	UIStyleManager.apply_button_style(join_tournament, "secondary", "medium")
	
	# Back button
	back_button.text = "Menu"
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.pressed.connect(_on_back_pressed)
	UIStyleManager.apply_button_style(back_button, "primary", "medium")
	
	# Configure existing ModeSelector if it's a Button (not SwipeModeButton yet)
	if mode_selector and not mode_selector.has_signal("mode_changed"):
		# Replace with SwipeModeButton
		var swipe_button = swipe_mode_button_scene.instantiate()
		swipe_button.name = "ModeSelector"
		swipe_button.custom_minimum_size = Vector2(0, 60)
		swipe_button.focus_mode = Control.FOCUS_NONE
		swipe_button.mode_changed.connect(_on_mode_changed)
		swipe_button.mode_id_changed.connect(_on_mode_id_changed)
		
		# Replace the existing mode_selector
		var parent = mode_selector.get_parent()
		var index = mode_selector.get_index()
		mode_selector.queue_free()
		parent.add_child(swipe_button)
		parent.move_child(swipe_button, index)
		mode_selector = swipe_button
	elif mode_selector:
		# Already a SwipeModeButton, just connect signals
		mode_selector.mode_changed.connect(_on_mode_changed)
		mode_selector.mode_id_changed.connect(_on_mode_id_changed)
	
	# Hide ranked button - we only use unranked as "Play"
	if ranked_button:
		ranked_button.visible = false
	
	# Configure Play button (unranked_button)
	unranked_button.text = "▶️ Play"
	unranked_button.focus_mode = Control.FOCUS_NONE
	unranked_button.custom_minimum_size = Vector2(0, 80)
	unranked_button.pressed.connect(func(): _on_queue_selected("play"))
	UIStyleManager.apply_button_style(unranked_button, "success", "large")

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
	middle_vbox.move_child(mode_description_label, 0)

func _setup_game_settings_component():
	"""Setup the reusable GameSettingsPanel component"""
	for child in settings_grid.get_children():
		child.queue_free()
	
	game_settings_component = VBoxContainer.new()
	game_settings_component.set_script(game_settings_panel_script)
	settings_margin.add_child(game_settings_component)
	
	settings_grid.visible = false
	
	if game_settings_component.has_method("setup_display"):
		game_settings_component.setup_display(current_mode_id, false, {
			"show_title": true,
			"compact": true
		})

func _on_solo_pressed():
	"""Handle solo button press"""
	is_solo_mode = true
	_update_solo_multiplayer_selection()
	
	# Save preference using existing method
	if SettingsSystem:
		SettingsSystem.set_preferred_play_mode("Solo")
	
	# Update displays
	_load_player_stats()
	_refresh_leaderboard_for_current_mode()
	_update_multiplayer_buttons_visibility()

func _on_multiplayer_pressed():
	"""Handle multiplayer button press"""
	is_solo_mode = false
	_update_solo_multiplayer_selection()
	
	# Save preference using existing method
	if SettingsSystem:
		SettingsSystem.set_preferred_play_mode("Multiplayer")
	
	# Update displays
	_load_player_stats()
	_refresh_leaderboard_for_current_mode()
	_update_multiplayer_buttons_visibility()

func _update_solo_multiplayer_selection():
	"""Update visual state of solo/multiplayer buttons"""
	if is_solo_mode:
		solo_button.modulate.a = 1.0
		multiplayer_button.modulate.a = 0.5
	else:
		solo_button.modulate.a = 0.5
		multiplayer_button.modulate.a = 1.0

func _update_multiplayer_buttons_visibility():
	"""Show/hide multiplayer-only buttons based on mode - keeps layout stable"""
	
# Helper function to make container invisible but keep in layout
func _set_container_visibility(container: Control, visible: bool):
	if visible:
		container.modulate.a = 1.0
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		for child in container.get_children():
			if child is Button:
				child.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		container.modulate.a = 0.0
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in container.get_children():
			if child is Button:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Update visibility for multiplayer-only containers
	_set_container_visibility(lobby_h_box, not is_solo_mode)
	_set_container_visibility(battleground_h_box, not is_solo_mode)
	
	# Tournament button
	if is_solo_mode:
		join_tournament.modulate.a = 0.0
		join_tournament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		join_tournament.modulate.a = 1.0
		join_tournament.mouse_filter = Control.MOUSE_FILTER_STOP

func _refresh_leaderboard_for_current_mode():
	"""Refresh leaderboard with current solo/multi and mode selection"""
	if leaderboard_panel and leaderboard_panel.has_method("refresh_for_mode"):
		var mode_key = current_mode_id
		if not is_solo_mode:
			mode_key += "_mp"  # Add multiplayer suffix
		leaderboard_panel.refresh_for_mode(mode_key)

func _load_player_stats():
	"""Load and display player statistics based on solo/multiplayer mode"""
	if is_solo_mode:
		_load_solo_stats()
	else:
		_load_multiplayer_stats()
	
	_update_stats_display()

func _load_solo_stats():
	"""Load solo player statistics"""
	debug_log("Loading solo stats for mode: %s" % current_mode_id)
	
	if StatsManager:
		var mode_stats = StatsManager.get_mode_stats(current_mode_id)
		debug_log("  Mode stats: %s" % str(mode_stats))
		
		var highscore_data = StatsManager.get_highscore()
		debug_log("  Overall highscore data: %s" % str(highscore_data))
		
		# Get mode-specific highscore
		var mode_highscore = StatsManager.get_mode_highscore(current_mode_id)
		debug_log("  Mode-specific highscore: %d" % mode_highscore)
		
		# Check if old method would work
		if highscore_data.get("mode", "") == current_mode_id:
			debug_log("  Old method would give: %d" % highscore_data.get("score", 0))
		
		player_stats = {
			"games_played": mode_stats.get("games_played", 0),
			"highscore": mode_highscore,  # Use the new method
			"perfect_rounds": mode_stats.get("perfect_rounds", 0),
			"mode": "solo"
		}
		debug_log("  Final solo stats: %s" % str(player_stats))
	else:
		player_stats = {
			"games_played": 0,
			"highscore": 0,
			"perfect_rounds": 0,
			"mode": "solo"
		}

func _load_multiplayer_stats():
	"""Load multiplayer statistics"""
	debug_log("Loading multiplayer stats for ALL modes (combined)")
	
	var total_first_place = 0
	var total_games = 0
	var total_average_rank = 0.0
	var modes_with_games = 0
	
	# Calculate combined stats across all multiplayer modes
	if StatsManager:
		for mode in ["classic", "timed_rush", "test"]:
			var mode_stats = StatsManager.get_multiplayer_stats(mode)
			debug_log("  Mode %s multiplayer stats: %s" % [mode, str(mode_stats)])
			
			if mode_stats.games > 0:
				total_first_place += mode_stats.first_place
				total_games += mode_stats.games
				total_average_rank += mode_stats.average_rank
				modes_with_games += 1
				debug_log("    Added %d games, %d first place, avg rank %.2f" % 
					[mode_stats.games, mode_stats.first_place, mode_stats.average_rank])
	
	# Calculate overall average rank
	if modes_with_games > 0:
		total_average_rank = total_average_rank / float(modes_with_games)
		debug_log("  Calculated avg rank: %.2f (from %d modes with games)" % [total_average_rank, modes_with_games])
	else:
		debug_log("  No modes with games, avg rank stays 0.0")
	
	# Calculate win rate
	var winrate = 0
	if total_games > 0:
		winrate = int(float(total_first_place) / float(total_games) * 100.0)
	
	# Simple MMR calculation based on performance
	var mmr = 1000
	if total_games > 0:
		mmr = 1000 + (total_first_place * 50) - int((total_average_rank - 1) * 25)
		mmr = max(100, mmr)
	
	# Determine rank based on MMR
	var rank = "Unranked"
	if total_games >= 5:
		if mmr >= 2000:
			rank = "Diamond"
		elif mmr >= 1750:
			rank = "Platinum"
		elif mmr >= 1500:
			rank = "Gold"
		elif mmr >= 1250:
			rank = "Silver"
		else:
			rank = "Bronze"
	
	player_stats = {
		"mmr": mmr,
		"first_place": total_first_place,
		"average_rank": total_average_rank,
		"winrate": winrate,
		"rank": rank,
		"games": total_games,
		"mode": "multiplayer"
	}
	
	debug_log("  Final multiplayer stats: %s" % str(player_stats))

func _update_stats_display():
	"""Update the player stats grid based on mode"""
	# Clear existing
	for child in stats_grid.get_children():
		child.queue_free()
	
	var stats_to_show = []
	
	if is_solo_mode:
		# Solo stats with icon paths
		stats_to_show = [
			{"icon_path": "gamepad_icon.png", "label": "Games", "value": str(player_stats.get("games_played", 0))},
			{"icon_path": "trophy_icon.png", "label": "Highscore", "value": str(player_stats.get("highscore", 0))},
			{"icon_path": "star_icon.png", "label": "Perfect Rounds", "value": str(player_stats.get("perfect_rounds", 0))}
		]
	else:
		# Multiplayer stats with icon paths
		stats_to_show = [
			{"icon_path": "trophy_icon.png", "label": "Rank", "value": player_stats.get("rank", "Unranked")},
			{"icon_path": "gamesplayed_icon.png", "label": "MMR", "value": str(player_stats.get("mmr", 0))},
			{"icon_path": "trophy_icon.png", "label": "1st Place", "value": str(player_stats.get("first_place", 0))},
			{"icon_path": "winrate_icon.png", "label": "Win Rate", "value": str(player_stats.get("winrate", 0)) + "%"},
			{"icon_path": "star_icon.png", "label": "Avg Rank", "value": "%.1f" % player_stats.get("average_rank", 0.0)},
			{"icon_path": "gamepad_icon.png", "label": "Games", "value": str(player_stats.get("games", 0))}
		]
	
	for stat in stats_to_show:
		# Icon + Label container
		var label_container = HBoxContainer.new()
		label_container.add_theme_constant_override("separation", 5)
		
		# Icon using TextureRect
		var icon = TextureRect.new()
		var icon_path = ICON_PATH_BASE + stat.icon_path
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(20, 20)
		icon.size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# NO modulate - we want the original icon colors
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

func _on_lobby_action(action: String):
	print("Lobby action: " + action)
	
	match action:
		"create_lobby":
			if has_node("/root/MultiplayerManager"):
				var mp_manager = get_node("/root/MultiplayerManager")
				mp_manager.select_game_mode(current_mode_id)
				mp_manager.create_custom_lobby()
				get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")
			else:
				push_error("MultiplayerManager not found!")
				
		"join_lobby":
			print("Join lobby - not implemented yet")
			
		"create_battleground":
			print("Create battleground - not implemented yet")
			
		"join_battleground":
			print("Join battleground - not implemented yet")
			
		"join_tournament":
			print("Join tournament - not implemented yet")
	
	lobby_action.emit(action)

func _on_queue_selected(queue_type: String):
	"""Handle Play button - different behavior for solo vs multiplayer"""
	current_queue_type = queue_type
	
	if is_solo_mode:
		# Solo mode - go directly to game
		print("Starting solo game with mode: %s" % current_mode_id)
		
		# Configure GameModeManager
		if GameModeManager:
			GameModeManager.set_game_mode(current_mode_id, {})
		
		# Set GameState to solo mode
		if GameState:
			GameState.game_mode = "solo"
		
		# Go directly to game
		get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")
	else:
		# Multiplayer mode - existing lobby logic
		if has_node("/root/MultiplayerManager"):
			var mp_manager = get_node("/root/MultiplayerManager")
			mp_manager.select_game_mode(current_mode_id)
			print("Searching for %s lobby with mode: %s" % [queue_type, current_mode_id])
			mp_manager.join_or_create_lobby()
		else:
			print("MultiplayerManager not found, loading GameLobby directly")
			get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")

func _get_mode_id_from_name(mode_name: String) -> String:
	"""Convert display name to mode ID"""
	match mode_name:
		"Classic": return "classic"
		"Rush": return "timed_rush"
		"Test": return "test"
		_: return "classic"

func _on_mode_changed(mode: String):
	"""Handle mode name change (for display)"""
	current_mode = mode
	mode_selected.emit(mode)

func _on_mode_id_changed(mode_id: String):
	"""Handle mode ID change (for game logic)"""
	debug_log("Mode changed to: %s" % mode_id)
	current_mode_id = mode_id
	
	# Update GameSettingsPanel
	if game_settings_component and game_settings_component.has_method("update_mode"):
		debug_log("  Updating GameSettingsPanel with mode: %s" % mode_id)
		game_settings_component.update_mode(mode_id)
	else:
		debug_log("  ERROR: GameSettingsPanel not found or missing update_mode method")
	
	# Refresh leaderboard with proper mode key
	_refresh_leaderboard_for_current_mode()
	
	# Reload stats for new mode
	debug_log("  Reloading stats for new mode")
	_load_player_stats()
	
	# Update MultiplayerManager only if in multiplayer mode
	if not is_solo_mode and has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.select_game_mode(mode_id)
		debug_log("  Updated MultiplayerManager with mode: %s" % mode_id)
