# Location: res://Pyramids/scenes/ui/menus/MultiplayerScreen.gd
# Last Updated: Updated for StyledButton and renamed nodes [Date]

extends Control

# === DEBUG CONFIGURATION ===
var debug_enabled: bool = false  # Set to true for debugging
var global_debug: bool = true
var is_mobile_platform: bool = false  # Track if on mobile

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
@onready var debug_button: CheckButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/HBoxContainer/DebugButton
@onready var mode_selector: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/ModeSelector
@onready var unranked_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/UnrankedButton

# Updated Lobby and Battle buttons with StyledButton and new names
@onready var lobby_h_box: HBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox
@onready var lobby_rect: TextureRect = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox/LobbyRect
@onready var create_lobby: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox/CreateLobby
@onready var join_lobby: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/LobbyHBox/JoinLobby
@onready var battle_h_box: HBoxContainer = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattleHBox
@onready var battle_rect: TextureRect = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattleHBox/BattleRect
@onready var create_battle: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattleHBox/CreateBattle
@onready var join_battle: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/BattleHBox/JoinBattle
@onready var join_tournament: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/JoinTournament
@onready var seed_button: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/VBoxContainer/SeedButton
@onready var back_button: StyledButton = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/VBoxContainer/BackButton

# Old ranked button reference (to hide it)
@onready var ranked_button: Button = $MainContainer/ContentHBox/RightSection/RightSectionMain/RightSectionPanel/MarginContainer/RightSectionVBox/RankedButton

# UI References
var leaderboard_panel: Control
var mode_description_label: RichTextLabel
var game_settings_component: Control
var multiplayer_leaderboard_script = preload("res://Pyramids/scripts/ui/components/MultiplayerLeaderboard.gd")
var swipe_mode_button_scene = preload("res://Pyramids/scenes/ui/components/SwipeModeButton.tscn")

# Debug panel reference - FIXED NAME
@onready var debug_panel: ScrollContainer = $MainContainer/ContentHBox/LeftSection/DebugPanel

# Debug text display
var debug_messages: Array[String] = []
var max_debug_messages: int = 50

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
	
	# Check if we're on mobile platform
	var os_name = OS.get_name()
	is_mobile_platform = (os_name == "Android" or os_name == "iOS")
	
	# Disable debug features on mobile
	if is_mobile_platform:
		debug_enabled = false
		global_debug = false
	
	debug_log("Platform: %s, Mobile: %s" % [os_name, is_mobile_platform])
	
	# Load persistent mode selection FIRST
	if SettingsSystem:
		# Load both play mode (solo/multi) and game mode
		var preferred_mode = SettingsSystem.get_preferred_play_mode()
		is_solo_mode = (preferred_mode == "Solo")
		debug_log("Loaded preferred play mode: %s (is_solo: %s)" % [preferred_mode, is_solo_mode])
		
		# Load the game mode (classic/rush/test)
		current_mode_id = SettingsSystem.get_game_mode()
		if current_mode_id == "" or current_mode_id == "tri_peaks":
			current_mode_id = "classic"  # Default/migrate old value
		current_mode = _get_mode_display_name_from_id(current_mode_id)
		debug_log("Loaded preferred game mode: %s (%s)" % [current_mode, current_mode_id])
	else:
		is_solo_mode = false
		current_mode = "Classic"
		current_mode_id = "classic"
		debug_log("No SettingsSystem, defaulting to multiplayer classic")
	
	_setup_styles()
	_setup_solo_multiplayer_buttons()
	_setup_leaderboard()
	_setup_buttons()
	_setup_stats_panel()
	_setup_game_settings_component()
	_load_player_stats()
	
	# Setup debug panel
	_setup_debug_panel()
	
	# Sync the mode selector to loaded mode AFTER setup
	if mode_selector and mode_selector.has_method("set_mode_by_id"):
		mode_selector.set_mode_by_id(current_mode_id)
		debug_log("Synced mode selector to: %s" % current_mode_id)
	
	# Update UI based on loaded selection
	_update_solo_multiplayer_selection()
	_update_multiplayer_buttons_visibility()
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
	
	debug_log("=== READY COMPLETE ===")

func _setup_debug_panel():
	"""Setup the debug panel with initial information"""
	# Skip debug panel setup entirely on mobile
	if is_mobile_platform:
		if debug_panel:
			debug_panel.visible = false
		return
	
	if not debug_panel:
		debug_log("Debug panel not found in scene")
		return
	
	debug_log("Setting up debug panel (ScrollContainer)")
	
	# Make sure it's visible and sized correctly
	debug_panel.visible = debug_enabled and global_debug
	debug_panel.z_index = 100  # On top
	debug_panel.custom_minimum_size = Vector2(400, 200)
	debug_panel.size = Vector2(400, 200)
	
	# Add a background panel first
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.15, 0.15, 0.15, 0.95)
	debug_panel.add_child(bg)
	
	# Simple approach - just add a TextEdit
	var debug_text = TextEdit.new()
	debug_text.custom_minimum_size = Vector2(400, 200)
	debug_text.size = Vector2(400, 200)
	debug_text.editable = false
	debug_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	debug_text.add_theme_font_size_override("font_size", 11)
	debug_text.add_theme_color_override("font_color", Color.WHITE)
	debug_text.add_theme_color_override("background_color", Color.TRANSPARENT)
	
	debug_panel.add_child(debug_text)
	
	# Store reference
	debug_panel.set_meta("debug_text", debug_text)
	
	debug_log("Debug panel setup complete")
	
	# Initial messages
	_add_debug_message("=== MultiplayerScreen Debug ===")
	_add_debug_message("Mode: %s" % current_mode_id)
	_add_debug_message("Type: %s" % ("Solo" if is_solo_mode else "Multiplayer"))
	_add_debug_message("Stats: %d games" % player_stats.get("games", 0))

func _add_debug_message(msg: String):
	"""Add a message to the debug panel"""
	if not debug_panel:
		return
	
	var debug_text = debug_panel.get_meta("debug_text", null)
	if not debug_text:
		return
	
	var time = Time.get_time_dict_from_system()
	var timestamp = "[%02d:%02d:%02d]" % [time.hour, time.minute, time.second]
	
	debug_text.text += "%s %s\n" % [timestamp, msg]
	
	# Keep only last 50 lines
	var lines = debug_text.text.split("\n")
	if lines.size() > 50:
		lines = lines.slice(-50)
		debug_text.text = "\n".join(lines)
	
	# Scroll to bottom
	debug_text.scroll_vertical = debug_text.get_line_count()

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
	
	# Set section ratios (0.6:1) - correct ratio
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
	battle_h_box.add_theme_constant_override("separation", 10)
	
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
	
	# Connect debug button if it exists and not on mobile
	if debug_button:
		if is_mobile_platform:
			debug_button.visible = false  # Hide debug button on mobile
		else:
			debug_button.text = "Debug"
			debug_button.button_pressed = debug_enabled and global_debug  # Set initial state
			debug_button.toggled.connect(_on_debug_toggled)

func _setup_leaderboard():
	"""Add multiplayer leaderboard to left section"""
	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.set_script(multiplayer_leaderboard_script)
	left_section.add_child(leaderboard_panel)
	
	# The script's _ready() will configure it automatically
	leaderboard_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_buttons():
	"""Configure existing buttons"""
	# Lobby buttons - StyledButtons now, no need for UIStyleManager
	create_lobby.pressed.connect(func(): _on_lobby_action("create_lobby"))
	join_lobby.pressed.connect(func(): _on_lobby_action("join_lobby"))
	
	# Battle buttons - renamed from battleground
	create_battle.pressed.connect(func(): _on_lobby_action("create_battle"))
	join_battle.pressed.connect(func(): _on_lobby_action("join_battle"))
	
	# Tournament button - now StyledButton
	join_tournament.focus_mode = Control.FOCUS_NONE
	join_tournament.pressed.connect(func(): _on_lobby_action("join_tournament"))
	
	# Back button - StyledButton now, no need for UIStyleManager
	back_button.text = "Menu"
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.pressed.connect(_on_back_pressed)
	
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
	unranked_button.text = "Play"
	unranked_button.focus_mode = Control.FOCUS_NONE
	unranked_button.custom_minimum_size = Vector2(0, 80)
	unranked_button.pressed.connect(func(): _on_queue_selected("play"))
	UIStyleManager.apply_button_style(unranked_button, "success", "large")

	# Seed button - solo only
	if seed_button:
		seed_button.text = "Play with Seed"
		seed_button.custom_minimum_size = Vector2(0, 50)  # Same height as back button
		seed_button.pressed.connect(_on_seed_button_pressed)

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
	
	debug_log("Switched to SOLO mode")
	_add_debug_message("Switched to SOLO mode")
	
	# Save preference using existing method
	if SettingsSystem:
		SettingsSystem.set_preferred_play_mode("Solo")
	
	# Update displays
	_load_player_stats()
	_refresh_leaderboard_for_current_mode()
	_update_multiplayer_buttons_visibility()
	
	# Force update GameSettingsPanel with current mode
	if game_settings_component and game_settings_component.has_method("update_mode"):
		debug_log("  Force updating GameSettingsPanel with mode: %s" % current_mode_id)
		game_settings_component.update_mode(current_mode_id)
		
	_sync_mode_selector()

func _on_multiplayer_pressed():
	"""Handle multiplayer button press"""
	is_solo_mode = false
	_update_solo_multiplayer_selection()
	
	debug_log("Switched to MULTIPLAYER mode")
	_add_debug_message("Switched to MULTIPLAYER mode")
	
	# Save preference using existing method
	if SettingsSystem:
		SettingsSystem.set_preferred_play_mode("Multiplayer")
	
	# Update displays
	_load_player_stats()
	_refresh_leaderboard_for_current_mode()
	_update_multiplayer_buttons_visibility()
	
	# Force update GameSettingsPanel with current mode
	if game_settings_component and game_settings_component.has_method("update_mode"):
		debug_log("  Force updating GameSettingsPanel with mode: %s" % current_mode_id)
		game_settings_component.update_mode(current_mode_id)
	
	# Update MultiplayerManager only when switching TO multiplayer
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.select_game_mode(current_mode_id)
		debug_log("  Updated MultiplayerManager with mode: %s" % current_mode_id)

	_sync_mode_selector()

func _on_seed_button_pressed():
	"""Handle seed button press - show custom seed dialog"""
	var dialog_scene = preload("res://Pyramids/scenes/ui/popups/PlaySeedDialog.tscn")
	if not dialog_scene:
		print("[MultiplayerScreen] Failed to load PlaySeedDialog scene")
		return
	
	var dialog = dialog_scene.instantiate()
	
	# Pass current mode to the dialog
	dialog.setup(current_mode_id, current_mode)
	
	# Connect to handle play signal if needed
	dialog.play_pressed.connect(func(seed, mode):
		print("[MultiplayerScreen] Playing %s with seed: %d" % [mode, seed])
		# The dialog already handles starting the game
	)
	
	get_tree().root.add_child(dialog)

func _on_debug_toggled(button_pressed: bool):
	"""Toggle debug panel visibility"""
	if debug_panel:
		debug_panel.visible = button_pressed
		
		# Update the debug flags
		debug_enabled = button_pressed
		global_debug = button_pressed
		
		if button_pressed:
			_add_debug_message("Debug panel enabled")
		
		debug_log("Debug panel toggled: %s" % button_pressed)

func _sync_mode_selector():
	"""Ensure the mode selector shows the correct mode"""
	if mode_selector and mode_selector.has_method("set_mode_by_id"):
		mode_selector.set_mode_by_id(current_mode_id)
		debug_log("  Synced mode selector to: %s" % current_mode_id)

func _update_solo_multiplayer_selection():
	"""Update visual state of solo/multiplayer buttons"""
	if is_solo_mode:
		solo_button.modulate.a = 1.0
		multiplayer_button.modulate.a = 0.5
	else:
		solo_button.modulate.a = 0.5
		multiplayer_button.modulate.a = 1.0

func _update_multiplayer_buttons_visibility():
	"""Show/hide multiplayer-only buttons based on mode"""
	# In solo mode, hide all multiplayer containers
	# In multiplayer mode, show them
	lobby_h_box.visible = not is_solo_mode
	battle_h_box.visible = not is_solo_mode
	join_tournament.visible = not is_solo_mode
	
	# Seed button is solo-only
	if seed_button:
		seed_button.visible = is_solo_mode

func _refresh_leaderboard_for_current_mode():
	"""Refresh leaderboard with current solo/multi and mode selection"""
	if leaderboard_panel and leaderboard_panel.has_method("refresh_for_mode"):
		# Set whether it's solo or multiplayer mode first
		if leaderboard_panel.has_method("set_mode_type"):
			leaderboard_panel.set_mode_type(is_solo_mode)
		
		# Then refresh with the current mode - ADD PROPER SUFFIX
		var mode_key = current_mode_id
		if is_solo_mode:
			mode_key += "_solo"  # Add solo suffix
		else:
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
		# Use the NEW typed function with "solo" game type
		var mode_stats = StatsManager.get_mode_stats_typed(current_mode_id, "solo")
		debug_log("  Mode stats (solo): %s" % str(mode_stats))
		
		# Get mode-specific highscore for SOLO
		var mode_highscore = StatsManager.get_mode_highscore_typed(current_mode_id, "solo")
		debug_log("  Solo highscore: %d" % mode_highscore)
		
		player_stats = {
			"games_played": mode_stats.get("games_played", 0),
			"highscore": mode_highscore,
			"perfect_rounds": mode_stats.get("perfect_rounds", 0),
			"mode": "solo"
		}
		debug_log("  Final solo stats: %s" % str(player_stats))
		
		# Log to debug panel
		_add_debug_message("Solo stats for %s:" % current_mode_id)
		_add_debug_message("  Games: %d" % player_stats.games_played)
		_add_debug_message("  Highscore: %d" % player_stats.highscore)
		_add_debug_message("  Perfect: %d" % player_stats.perfect_rounds)
	else:
		player_stats = {
			"games_played": 0,
			"highscore": 0,
			"perfect_rounds": 0,
			"mode": "solo"
		}

func _load_multiplayer_stats():
	"""Load multiplayer statistics for current mode only"""
	debug_log("Loading multiplayer stats for mode: %s" % current_mode_id)
	
	if StatsManager:
		# Get multiplayer-specific stats (these are already separate)
		var mp_stats = StatsManager.get_multiplayer_stats(current_mode_id)
		debug_log("  Multiplayer stats for %s: %s" % [current_mode_id, str(mp_stats)])
		
		# Also get the multi mode stats for additional data
		var mode_stats = StatsManager.get_mode_stats_typed(current_mode_id, "multi")
		debug_log("  Mode stats (multi): %s" % str(mode_stats))
		
		# Get multiplayer highscore
		var multi_highscore = StatsManager.get_mode_highscore_typed(current_mode_id, "multi")
		debug_log("  Multi highscore: %d" % multi_highscore)
		
		# Extract data from multiplayer stats
		var games = mp_stats.get("games", 0)
		var first_place = mp_stats.get("first_place", 0)
		var average_rank = mp_stats.get("average_rank", 0.0)
		var mmr = mp_stats.get("mmr", 1000)
		
		# Calculate win rate for this mode
		var winrate = 0
		if games > 0:
			winrate = int(float(first_place) / float(games) * 100.0)
		
		# Determine rank based on MMR
		var rank = "Unranked"
		if games >= 5:
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
			"first_place": first_place,
			"average_rank": average_rank,
			"winrate": winrate,
			"rank": rank,
			"games": games,
			"highscore": multi_highscore,  # Add multi highscore
			"mode": "multiplayer"
		}
		
		debug_log("  Final multiplayer stats: %s" % str(player_stats))
		
		# Log to debug panel
		_add_debug_message("Multiplayer %s:" % current_mode_id)
		_add_debug_message("  Games: %d" % games)
		_add_debug_message("  Highscore: %d" % multi_highscore)
		_add_debug_message("  1st Place: %d" % first_place)
		_add_debug_message("  Avg Rank: %.2f" % average_rank)
		_add_debug_message("  MMR: %d" % mmr)
	else:
		player_stats = {
			"mmr": 1000,
			"first_place": 0,
			"average_rank": 0.0,
			"winrate": 0,
			"rank": "Unranked",
			"games": 0,
			"highscore": 0,
			"mode": "multiplayer"
		}
		debug_log("  No StatsManager found")

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
			
		"create_battle":  # Updated from create_battleground
			print("Create battle - not implemented yet")
			
		"join_battle":  # Updated from join_battleground
			print("Join battle - not implemented yet")
			
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
	
	# SAVE the mode preference
	if SettingsSystem:
		SettingsSystem.set_game_mode(mode_id)
		debug_log("  Saved preferred game mode: %s" % mode_id)
	
	# Log to debug panel
	_add_debug_message("Mode changed to: %s" % mode_id)
	
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

func _get_mode_display_name_from_id(mode_id: String) -> String:
	"""Convert mode ID to display name"""
	match mode_id:
		"classic": return "Classic"
		"timed_rush": return "Rush"
		"test": return "Test"
		_: return "Classic"
