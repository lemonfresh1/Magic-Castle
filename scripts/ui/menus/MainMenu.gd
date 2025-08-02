# MainMenu.gd - Main menu with hidden debug panel access
# Path: res://Magic-Castle/scripts/ui/menus/MainMenu.gd
# Updated with ButtonLayout instances and new UI elements
extends Control

# Preload scenes
const ButtonLayoutScene = preload("res://Magic-Castle/scenes/ui/components/ButtonLayout.tscn")
const CogBoxScene = preload("res://Magic-Castle/scenes/ui/components/CogBox.tscn")
const StarBoxScene = preload("res://Magic-Castle/scenes/ui/components/StarBox.tscn")
const ShopUIScene = preload("res://Magic-Castle/scenes/ui/shop/ShopUI.tscn")

# Overlay References
@onready var settings_overlay: Control = $SettingsOverlay
@onready var achievements_overlay: Control = $AchievementsOverlay

# New elements
@onready var version_label: Label = $VersionLabel
@onready var debug_panel: Panel = $DebugPanel
var profile_card: PanelContainer = null

# Dictionary to store all menu panel instances
var menu_instances = {}

# Configuration for all menu panels
var menu_configs = {
	"shop": {
		"scene": "res://Magic-Castle/scenes/ui/shop/ShopUI.tscn",
		"script": "res://Magic-Castle/scripts/ui/shop/ShopUI.gd",
		"signals": {
			"shop_closed": "_on_shop_closed",
			"item_purchased": "_on_shop_item_purchased"
		},
		"show_method": "show_shop"
	},
	"inventory": {
		"scene": "res://Magic-Castle/scenes/ui/inventory/InventoryUI.tscn",
		"script": "res://Magic-Castle/scripts/ui/inventory/InventoryUI.gd",
		"signals": {
			"inventory_closed": "_on_inventory_closed"
		},
		"show_method": "show_inventory"
	},
	"missions": {
		"scene": "res://Magic-Castle/scenes/ui/missions/MissionUI.tscn",
		"script": "res://Magic-Castle/scripts/ui/missions/MissionUI.gd", 
		"signals": {
			"mission_completed": "_on_mission_completed",
			"missions_closed": "_on_missions_closed"
		},
		"show_method": "refresh_missions"
	},
	"season_pass": {
		"scene": "res://Magic-Castle/scenes/ui/season/SeasonPassUI.tscn",
		"script": "res://Magic-Castle/scripts/ui/season/SeasonPassUI.gd",
		"signals": {
			"tier_claimed": "_on_tier_claimed",
			"season_pass_closed": "_on_season_pass_closed"
		},
		"show_method": "show_season_pass"
	},
	"holiday": {
		"scene": "res://Magic-Castle/scenes/ui/holiday/HolidayUI.tscn", 
		"script": "res://Magic-Castle/scripts/ui/holiday/HolidayUI.gd",
		"signals": {
			"event_completed": "_on_holiday_event_completed",
			"holiday_closed": "_on_holiday_closed"
		},
		"show_method": "show_holiday_event"
	}
}

# Button instances
var play_button: Button
var shop_button: Button
var daily_mission_button: Button
var season_pass_button: Button
var holiday_button: Button
var cog_button: Button
var star_box: PanelContainer

# Debug access
var version_tap_count: int = 0
var version_tap_timer: Timer

# Button configurations
var button_configs = [
	{"name": "Play", "position": Vector2(930, 110), "has_progress": false, "theme": "Play", "icon": "res://Magic-Castle/assets/ui/menu/play.png"},
	{"name": "Shop", "position": Vector2(930, 195), "has_progress": false, "theme": "Shop", "icon": "res://Magic-Castle/assets/ui/menu/play.png"},
	{"name": "Missions", "position": Vector2(930, 280), "has_progress": true, "theme": "Missions", "icon": "res://Magic-Castle/assets/ui/menu/play.png"},
	{"name": "Season Pass", "position": Vector2(930, 365), "has_progress": true, "theme": "Season Pass", "icon": "res://Magic-Castle/assets/ui/menu/play.png"},
	{"name": "Holiday", "position": Vector2(930, 450), "has_progress": true, "theme": "Holiday", "icon": "res://Magic-Castle/assets/ui/menu/play.png"}
]

# Color themes for each button type
var button_themes = {
	"Play": {
		"shadow": Color(0.1, 0.3, 0.1),        # Dark green
		"main_bg": Color(0.2, 0.5, 0.2),      # Green
		"main_border": Color(0.3, 0.7, 0.3),   # Bright green
		"icon_bg": Color.TRANSPARENT,         # Transparent for Play
		"icon_border": Color.TRANSPARENT,     # Transparent for Play
		"progress_bg": Color(0.4, 0.7, 0.4),   # Light green (not used)
		"progress_fill": Color(0.5, 0.9, 0.5), # Bright green (not used)
		"transparent_icon": true               # Flag for special handling
	},
	"Shop": {
		"shadow": Color(0.4, 0.3, 0.1),        # Dark gold/brown
		"main_bg": Color(0.6, 0.5, 0.2),      # Gold
		"main_border": Color(0.8, 0.6, 0.2),   # Bright gold
		"icon_bg": Color(0.7, 0.6, 0.3),      # Light gold
		"icon_border": Color(0.3, 0.2, 0.05),  # Dark brown
		"progress_bg": Color(0.8, 0.7, 0.4),   # Very light gold
		"progress_fill": Color(0.9, 0.7, 0.2), # Bright gold
		"transparent_icon": false
	},
	"Missions": {
		"shadow": Color(0.1, 0.2, 0.4),        # Dark blue
		"main_bg": Color(0.2, 0.4, 0.6),      # Blue
		"main_border": Color(0.3, 0.5, 0.8),   # Bright blue
		"icon_bg": Color.TRANSPARENT,         # Transparent for Missions
		"icon_border": Color.TRANSPARENT,     # Transparent for Missions
		"progress_bg": Color(0.4, 0.6, 0.8),   # Very light blue
		"progress_fill": Color(0.4, 0.6, 0.9), # Bright light blue
		"transparent_icon": true
	},
	"Season Pass": {
		"shadow": Color(0.3, 0.1, 0.3),        # Dark purple
		"main_bg": Color(0.5, 0.2, 0.5),      # Purple
		"main_border": Color(0.7, 0.3, 0.7),   # Bright purple
		"icon_bg": Color(0.6, 0.3, 0.6),      # Light purple
		"icon_border": Color(0.2, 0.05, 0.2),  # Very dark purple
		"progress_bg": Color(0.7, 0.4, 0.7),   # Very light purple
		"progress_fill": Color(0.8, 0.4, 0.8), # Bright light purple
		"transparent_icon": false
	},
	"Holiday": {
		"shadow": Color(0.5, 0.1, 0.1),        # Dark red
		"main_bg": Color(0.7, 0.2, 0.2),      # Red
		"main_border": Color(0.9, 0.3, 0.3),   # Bright red
		"icon_bg": Color(0.8, 0.3, 0.3),      # Light red
		"icon_border": Color(0.4, 0.05, 0.05), # Very dark red
		"progress_bg": Color(0.9, 0.4, 0.4),   # Very light red
		"progress_fill": Color(0.2, 0.6, 0.2), # Green (festive contrast)
		"transparent_icon": false
	}
}

func _ready() -> void:
	# Set up the gradient background FIRST
	_setup_menu_background()
	
	_setup_profile_card()
	_create_buttons()
	_create_ui_elements()
	_hide_overlays()
	_setup_version_label()
	_setup_debug_panel()
	
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

func _apply_button_theme(button_instance: Button, config: Dictionary) -> void:
	var theme_name = config.theme
	if not theme_name or not button_themes.has(theme_name):
		return
	
	var theme = button_themes[theme_name]
	
	# Get all the panels and elements
	var shadow_panel = button_instance.get_node("ShadowPanelContainer")
	var main_panel = button_instance.get_node("ShadowPanelContainer/MainPanelContainer")
	var icon_container = button_instance.get_node("ShadowPanelContainer/MainPanelContainer/MarginContainer/HBoxContainer/IconContainer")
	var icon_margin = button_instance.get_node("ShadowPanelContainer/MainPanelContainer/MarginContainer/HBoxContainer/IconContainer/MarginContainer")
	var icon_texture = button_instance.get_node("ShadowPanelContainer/MainPanelContainer/MarginContainer/HBoxContainer/IconContainer/MarginContainer/Icon")
	var progress_bar = button_instance.get_node("ShadowPanelContainer/MainPanelContainer/MarginContainer/HBoxContainer/LabelContainer/ProgressBar")
	
	# Apply shadow panel style
	if shadow_panel and shadow_panel.has_theme_stylebox_override("panel"):
		var shadow_style = shadow_panel.get_theme_stylebox("panel").duplicate()
		shadow_style.bg_color = theme.shadow
		shadow_panel.add_theme_stylebox_override("panel", shadow_style)
	
	# Apply main panel style
	if main_panel and main_panel.has_theme_stylebox_override("panel"):
		var main_style = main_panel.get_theme_stylebox("panel").duplicate()
		main_style.bg_color = theme.main_bg
		main_style.border_color = theme.main_border
		main_panel.add_theme_stylebox_override("panel", main_style)
	
	# Handle icon container based on transparent_icon flag
	if icon_container and icon_container.has_theme_stylebox_override("panel"):
		var icon_style = icon_container.get_theme_stylebox("panel").duplicate()
		
		if theme.transparent_icon:
			# For Play and Missions - transparent background
			icon_style.bg_color = Color.TRANSPARENT
			icon_style.border_color = Color.TRANSPARENT
			icon_style.border_width_top = 0
			icon_style.border_width_bottom = 0
			icon_style.border_width_left = 0
			icon_style.border_width_right = 0
			
			# Set margins to 0
			if icon_margin:
				icon_margin.add_theme_constant_override("margin_top", 3)
				icon_margin.add_theme_constant_override("margin_bottom", 3)
				icon_margin.add_theme_constant_override("margin_left", 6)
				icon_margin.add_theme_constant_override("margin_right", 0)
		else:
			# For Shop, Season Pass, Holiday - colored background
			icon_style.bg_color = theme.icon_bg
			icon_style.border_color = theme.icon_border
		
		icon_container.add_theme_stylebox_override("panel", icon_style)
	
	# Set the icon texture and size
	if icon_texture:
		
		# Load and set the texture
		if config.has("icon") and config.icon:
			var texture = load(config.icon)
			if texture:
				icon_texture.texture = texture
				icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Apply progress bar styles
	if progress_bar and progress_bar.visible:
		var base_style = progress_bar.get_theme_stylebox("background").duplicate()
		base_style.bg_color = theme.progress_bg
		progress_bar.add_theme_stylebox_override("background", base_style)
		
		var fill_style = progress_bar.get_theme_stylebox("fill").duplicate()
		fill_style.bg_color = theme.progress_fill
		progress_bar.add_theme_stylebox_override("fill", fill_style)

func _create_buttons() -> void:
	for i in range(button_configs.size()):
		var config = button_configs[i]
		var button_instance = ButtonLayoutScene.instantiate() as Button
		
		add_child(button_instance)
		
		# Set position
		button_instance.position = config.position
		
		# Get nodes
		var button_label = button_instance.get_node("ShadowPanelContainer/MainPanelContainer/MarginContainer/HBoxContainer/LabelContainer/ButtonLabel")
		var progress_bar = button_instance.get_node("ShadowPanelContainer/MainPanelContainer/MarginContainer/HBoxContainer/LabelContainer/ProgressBar")
		
		if button_label:
			button_label.text = config.name
		else:
			continue
		
		# Apply theme to all buttons
		_apply_button_theme(button_instance, config)
		
		# Handle each button specifics
		match config.name:
			"Play":
				button_label.add_theme_font_size_override("font_size", 36)
				play_button = button_instance
				if progress_bar:
					progress_bar.visible = false
			"Shop":
				button_label.add_theme_font_size_override("font_size", 36)
				shop_button = button_instance
				if progress_bar:
					progress_bar.visible = false
			"Missions":
				daily_mission_button = button_instance
			"Season Pass":
				season_pass_button = button_instance
			"Holiday":
				holiday_button = button_instance

		for button in [play_button, shop_button, daily_mission_button, season_pass_button, holiday_button]:
			if button:
				move_child(button, get_child_count() - 1)
		# Connect button signal - FIXED VERSION
		button_instance.pressed.connect(_on_button_pressed.bind(config.name))

func _create_ui_elements() -> void:
	# Create CogBox
	var cog_box = CogBoxScene.instantiate()
	add_child(cog_box)
	cog_box.position = Vector2(1130.0, 30.0)
	cog_button = cog_box
	
	# Connect cog button - it should be a Button
	if cog_box is Button:
		cog_box.pressed.connect(_on_cog_pressed)
	
	# Create StarBox
	star_box = StarBoxScene.instantiate()
	add_child(star_box)
	star_box.position = Vector2(1000.0, 30.0)

func _on_button_pressed(button_name: String) -> void:
	match button_name:
		"Play":
			_on_play_pressed()
		"Shop":
			_on_shop_pressed()
		"Missions":
			_on_daily_mission_pressed()
		"Season Pass":
			_on_season_pass_pressed()
		"Holiday":
			_on_holiday_pressed()

func _hide_menu_buttons():
	for button in [play_button, shop_button, daily_mission_button, season_pass_button, holiday_button]:
		if button:
			button.visible = false

func _show_menu_buttons():
	for button in [play_button, shop_button, daily_mission_button, season_pass_button, holiday_button]:
		if button:
			button.visible = true

func _on_play_pressed() -> void:
	GameState.reset_game_completely()
	GameModeManager._load_current_mode()
	get_tree().change_scene_to_file("res://Magic-Castle/scenes/game/MobileGameBoard.tscn")

func _on_shop_pressed() -> void:
	_toggle_menu_panel("shop")

func _on_daily_mission_pressed() -> void:
	_toggle_menu_panel("missions")

func _on_season_pass_pressed() -> void:
	_toggle_menu_panel("season_pass")

func _on_holiday_pressed() -> void:
	_toggle_menu_panel("holiday")

# Your existing callback functions stay the same:
func _on_shop_closed():
	# This stays as is
	pass

func _on_shop_item_purchased(item_id: String):
	print("Item purchased from shop: ", item_id)

# Add placeholders for future callbacks:
func _on_mission_completed(mission_id: String):
	print("Mission completed: ", mission_id)

func _on_missions_closed():
	pass

func _on_tier_claimed(tier: int):
	print("Season pass tier claimed: ", tier)

func _on_season_pass_closed():
	pass

func _on_holiday_event_completed(event_id: String):
	print("Holiday event completed: ", event_id)

func _on_holiday_closed():
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

	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_version_label():
	if not version_label:
		version_label = Label.new()
		version_label.name = "VersionLabel"
		add_child(version_label)
	
	# Position in bottom-left with proper margins
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version_label.position = Vector2(20, 500)  # Adjust based on your screen height
	
	# Set text
	version_label.text = "v0.3.0"
	version_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	version_label.add_theme_font_size_override("font_size", 14)
	
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

func _setup_debug_panel():
	# Create if doesn't exist
	if not debug_panel:
		var debug_scene = preload("res://Magic-Castle/scenes/ui/debug/DebugPanel.tscn")
		debug_panel = debug_scene.instantiate()
		add_child(debug_panel)
		move_child(debug_panel, get_child_count() - 1)  # On top

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

func _hide_overlays() -> void:
	if settings_overlay:
		settings_overlay.visible = false
	if achievements_overlay:
		achievements_overlay.visible = false

func _on_cog_pressed() -> void:
	if settings_overlay:
		settings_overlay.visible = true
		# Hide the new buttons
		for button in [play_button, shop_button, daily_mission_button, season_pass_button, holiday_button]:
			if button:
				button.visible = false

func _on_settings_closed() -> void:
	settings_overlay.visible = false
	# Show the new buttons again
	for button in [play_button, shop_button, daily_mission_button, season_pass_button, holiday_button]:
		if button:
			button.visible = true

func _on_achievements_closed() -> void:
	achievements_overlay.visible = false

func _setup_profile_card():
	if not profile_card:
		var profile_card_scene = preload("res://Magic-Castle/scenes/ui/components/ProfileCard.tscn")
		profile_card = profile_card_scene.instantiate()
		profile_card.name = "ProfileCard"
		add_child(profile_card)
	
	# Set custom anchors and margins
	profile_card.anchor_left = 0.0
	profile_card.anchor_top = 0.0
	profile_card.anchor_right = 0.65
	profile_card.anchor_bottom = 0.0

	# Set margins
	profile_card.offset_left = 20
	profile_card.offset_top = 20
	profile_card.offset_right = -20  # Negative to maintain margin from right anchor
	profile_card.offset_bottom = 0  # Height controlled by the ProfileCard's content
	
	# Connect signals
	if profile_card.has_signal("section_selected"):
		profile_card.section_selected.connect(_on_profile_section_selected)

func _on_profile_section_selected(section: String) -> void:
	match section:
		"inventory":
			_toggle_menu_panel("inventory")

func _create_menu_panel(scene_path: String, script_path: String = "") -> PanelContainer:
	var scene = load(scene_path)
	var instance = scene.instantiate() as PanelContainer
	add_child(instance)
	
	# Apply standard positioning (same as profile card)
	instance.anchor_left = 0.0
	instance.anchor_top = 0.0
	instance.anchor_right = 0.65
	instance.anchor_bottom = 0.0
	
	# Standard margins
	instance.offset_left = 20
	instance.offset_top = 90
	instance.offset_right = -20
	instance.offset_bottom = 0
	
	# Always on top
	move_child(instance, get_child_count() - 1)
	
	# Attach script if provided
	if script_path != "":
		var script = load(script_path)
		instance.set_script(script)
		instance._ready()
	
	return instance

# Add this generic toggle function
func _toggle_menu_panel(menu_name: String) -> void:
	if not menu_configs.has(menu_name):
		print("Unknown menu: ", menu_name)
		return
		
	var config = menu_configs[menu_name]
	
	if not menu_instances.has(menu_name) or not menu_instances[menu_name]:
		# Create new instance
		var instance = _create_menu_panel(config.scene, config.script)
		menu_instances[menu_name] = instance
		
		# Connect signals
		for signal_name in config.get("signals", {}):
			if instance.has_signal(signal_name):
				var method_name = config.signals[signal_name]
				if has_method(method_name):
					instance.connect(signal_name, Callable(self, method_name))
	else:
		# Toggle existing instance
		var instance = menu_instances[menu_name]
		instance.visible = !instance.visible
		
		# Call show method if visible
		if instance.visible and config.has("show_method") and instance.has_method(config.show_method):
			instance.call(config.show_method)

func _on_inventory_closed():
	pass
