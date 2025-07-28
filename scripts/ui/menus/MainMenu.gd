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
	# Set up the gradient background FIRST
	_setup_menu_background()
	
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

func _setup_menu_background() -> void:
	# Remove any game board backgrounds that might exist
	if has_node("BackgroundSprite"):
		get_node("BackgroundSprite").queue_free()
	
	# Create gradient background
	var bg_rect = ColorRect.new()
	bg_rect.name = "MenuBackground"
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create gradient texture
	var gradient = Gradient.new()
	var gradient_texture = GradientTexture2D.new()
	
	# Set gradient colors - dark forest green to lighter sage green
	gradient.add_point(0.0, Color(0.1, 0.25, 0.15))  # Dark forest green
	gradient.add_point(1.0, Color(0.25, 0.45, 0.3))  # Lighter sage green
	
	# Apply gradient vertically
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)
	
	# Apply to background
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform sampler2D gradient_texture;
	
	void fragment() {
		vec4 gradient_color = texture(gradient_texture, vec2(0.5, UV.y));
		COLOR = gradient_color;
	}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("gradient_texture", gradient_texture)
	
	bg_rect.material = material
	
	# Add as first child (behind everything)
	add_child(bg_rect)
	move_child(bg_rect, 0)
	
	# Also set the clear color as fallback
	RenderingServer.set_default_clear_color(Color(0.15, 0.3, 0.2))

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
	GameState.reset_game_completely()
	GameModeManager._load_current_mode()
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
