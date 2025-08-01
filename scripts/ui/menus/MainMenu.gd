# MainMenu.gd - Main menu with hidden debug panel access
# Path: res://Magic-Castle/scripts/ui/menus/MainMenu.gd
# Added version label with triple-tap debug panel, star display
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

# New elements
@onready var version_label: Label = $VersionLabel
@onready var star_display: Label = $StarDisplay
@onready var debug_panel: Panel = $DebugPanel
var profile_card: PanelContainer = null

# Debug access
var version_tap_count: int = 0
var version_tap_timer: Timer

func _ready() -> void:
	# Set up the gradient background FIRST
	_setup_menu_background()
	
	_setup_profile_card()
	_connect_buttons()
	_hide_overlays()
	_update_ui_state()
	_setup_version_label()
	_setup_star_display()
	_setup_debug_panel()
	
	# Connect to star changes
	StarManager.stars_changed.connect(_on_stars_changed)
	
	# Safely connect overlay signals
	if settings_overlay and settings_overlay.has_node("SettingsMenu"):
		var settings_menu = settings_overlay.get_node("SettingsMenu")
		settings_menu.settings_closed.connect(_on_settings_closed)
	else:
		pass

	if achievements_overlay and achievements_overlay.has_node("AchievementsPanel"):
		var achievements_panel = achievements_overlay.get_node("AchievementsPanel")
		achievements_panel.achievements_closed.connect(_on_achievements_closed)
	else:
		pass

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

func _setup_version_label():
	if not version_label:
		version_label = Label.new()
		version_label.name = "VersionLabel"
		add_child(version_label)
	
	# Position in bottom-left with proper margins
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version_label.anchor_left = 0.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 0.0
	version_label.anchor_bottom = 1.0
	
	# Set text
	version_label.text = "v0.3.0"
	version_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))  # More visible
	version_label.add_theme_font_size_override("font_size", 14)  # Slightly bigger
	
	# Make clickable
	version_label.mouse_filter = Control.MOUSE_FILTER_PASS
	version_label.gui_input.connect(_on_version_label_input)
	
	# Create tap timer if needed
	if not version_tap_timer:
		version_tap_timer = Timer.new()
		version_tap_timer.wait_time = 0.5
		version_tap_timer.one_shot = true
		version_tap_timer.timeout.connect(_reset_version_taps)
		add_child(version_tap_timer)

func _setup_star_display():
	if not star_display:
		star_display = Label.new()
		star_display.name = "StarDisplay"
		add_child(star_display)
	
	# Position in top-right with proper margins
	star_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	star_display.anchor_left = 1.0
	star_display.anchor_top = 0.0
	star_display.anchor_right = 1.0
	star_display.anchor_bottom = 0.0
	
	# Update star count
	_update_star_display()
	
	# Style
	star_display.add_theme_font_size_override("font_size", 24)
	star_display.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))  # Brighter yellow

func _setup_debug_panel():
	# Create if doesn't exist
	if not debug_panel:
		var debug_scene = preload("res://Magic-Castle/scenes/ui/debug/DebugPanel.tscn")
		debug_panel = debug_scene.instantiate()
		add_child(debug_panel)
		move_child(debug_panel, get_child_count() - 1)  # On top

func _update_star_display():
	if star_display:
		var total_stars = StarManager.get_balance()
		star_display.text = "⭐ %d" % total_stars

func _on_stars_changed(new_total: int, change: int):
	_update_star_display()
	
	# Animate star change
	if star_display and change != 0:
		var tween = create_tween()
		tween.tween_property(star_display, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(star_display, "scale", Vector2.ONE, 0.1)

func _on_version_label_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		version_tap_count += 1
		version_tap_timer.start()
		
		if version_tap_count >= 3:
			_show_debug_panel()
			version_tap_count = 0

func _reset_version_taps():
	version_tap_count = 0

func _show_debug_panel():
	if debug_panel and debug_panel.has_method("show_panel"):
		debug_panel.show_panel()

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
	
	# Update star display
	_update_star_display()

func _on_start_pressed() -> void:
	GameState.reset_game_completely()
	GameModeManager._load_current_mode()
	get_tree().change_scene_to_file("res://Magic-Castle/scenes/game/MobileGameBoard.tscn")

func _on_multiplayer_pressed() -> void:
	# Placeholder - just show a message
	print("Multiplayer coming soon!")
	# Could show a "Coming Soon" popup

func _on_settings_pressed() -> void:
	menu_container.visible = false
	settings_overlay.visible = true

func _on_achievements_pressed() -> void:
	get_tree().change_scene_to_file("res://Magic-Castle/scenes/ui/menus/AchievementsScreen.tscn")

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
	_update_ui_state()

# Called when returning from a game
func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh UI when window gains focus
		_update_ui_state()

func _setup_profile_card():
	if not profile_card:
		var profile_card_scene = preload("res://Magic-Castle/scenes/ui/components/ProfileCard.tscn")
		profile_card = profile_card_scene.instantiate()
		profile_card.name = "ProfileCard"
		add_child(profile_card)
	
	# Position in top-left with proper margins
	profile_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	profile_card.anchor_left = 0.0
	profile_card.anchor_top = 0.0
	profile_card.anchor_right = 0.6
	profile_card.anchor_bottom = 0.15
	profile_card.position = Vector2(20, 20)  # 20px margin from edges
	
	# Connect signals
	if profile_card.has_signal("section_selected"):
		profile_card.section_selected.connect(_on_profile_section_selected)

# Add this handler function:
func _on_profile_section_selected(section: String) -> void:
	# This will handle the expandable content below the profile card
	print("Section selected: %s" % section)
	# Future: Show expandable content based on section
