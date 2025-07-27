# MainMenu.gd
extends Control

# UI References
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var start_button: Button = $MenuContainer/StartButton
@onready var multiplayer_button: Button = $MenuContainer/MultiplayerButton
@onready var settings_button: Button = $MenuContainer/SettingsButton
@onready var achievements_button: Button = $MenuContainer/AchievementsButton
@onready var exit_button: Button = $MenuContainer/ExitButton

# Overlay References
@onready var settings_overlay: Control = $SettingsOverlay
@onready var achievements_overlay: Control = $AchievementsOverlay

func _ready() -> void:
	_connect_buttons()
	_hide_overlays()
	_update_ui_state()
	
	# Safely connect overlay signals
	if settings_overlay and settings_overlay.has_node("SettingsMenu"):
		var settings_menu = settings_overlay.get_node("SettingsMenu")
		settings_menu.settings_closed.connect(_on_settings_closed)
	else:
		print("Warning: SettingsMenu not found in SettingsOverlay")
	
	if achievements_overlay and achievements_overlay.has_node("AchievementsPanel"):
		var achievements_panel = achievements_overlay.get_node("AchievementsPanel")
		achievements_panel.achievements_closed.connect(_on_achievements_closed)
	else:
		print("Warning: AchievementsPanel not found in AchievementsOverlay")

func _connect_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _hide_overlays() -> void:
	if settings_overlay:
		settings_overlay.visible = false
	if achievements_overlay:
		achievements_overlay.visible = false

func _update_ui_state() -> void:
	# Update UI based on current game mode
	var current_mode = GameModeManager.get_current_mode()
	if current_mode:
		start_button.text = "Start %s" % current_mode.display_name

func _on_start_pressed() -> void:
	# Transition to game scene
	get_tree().change_scene_to_file("res://Magic-Castle/scenes/game/MobileGameBoard.tscn")

func _on_multiplayer_pressed() -> void:
	# Placeholder - just show a message
	print("Multiplayer coming soon!")

func _on_settings_pressed() -> void:
	menu_container.visible = false
	settings_overlay.visible = true

func _on_achievements_pressed() -> void:
	menu_container.visible = false
	achievements_overlay.visible = true

func _on_exit_pressed() -> void:
	get_tree().quit()

# Called when settings are closed
func _on_settings_closed() -> void:
	settings_overlay.visible = false
	menu_container.visible = true
	_update_ui_state()

# Called when achievements are closed
func _on_achievements_closed() -> void:
	achievements_overlay.visible = false
	menu_container.visible = true
