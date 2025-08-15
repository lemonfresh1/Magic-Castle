# MainMenu.gd - Main menu with hidden debug panel access and integrated menu system
# Location: res://Pyramids/scripts/ui/menus/MainMenu.gd
# Last Updated: Fixed ItemDatabase references to use ItemManager [Date]
#
# MainMenu handles:
# - Main game menu with Play, Shop, Missions, Season Pass, Holiday buttons
# - Profile card display with player stats
# - Settings (cog) and star display in top-right
# - Hidden debug panel (triple-tap version label)
# - Dynamic menu panel system for all UI overlays
# - Button state management (selected/deselected)
# - Background gradient rendering
#
# Menu Panel System:
# - All UI panels (shop, inventory, profile, etc.) are managed through menu_configs
# - Panels are created on-demand and cached in menu_instances
# - UIManager handles the open/close state and animations
# - Buttons automatically toggle based on panel state
#
# Flow: MainMenu → UIManager → Individual UI Panels (ShopUI, ProfileUI, etc.)
# Dependencies: UIManager (for panel management), StarManager (for currency), ProfileManager (for stats)

extends Control

# Preload scenes
const ButtonLayoutScene = preload("res://Pyramids/scenes/ui/components/ButtonLayout.tscn")
const CogBoxScene = preload("res://Pyramids/scenes/ui/components/CogBox.tscn")
const StarBoxScene = preload("res://Pyramids/scenes/ui/components/StarBox.tscn")
const ShopUIScene = preload("res://Pyramids/scenes/ui/shop/ShopUI.tscn")

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
		"scene": "res://Pyramids/scenes/ui/shop/ShopUI.tscn",
		"script": "res://Pyramids/scripts/ui/shop/ShopUI.gd",
		"signals": {
			"shop_closed": "_on_shop_closed",
			"item_purchased": "_on_shop_item_purchased"
		},
		"show_method": "show_shop"
	},
	"inventory": {
		"scene": "res://Pyramids/scenes/ui/inventory/InventoryUI.tscn",
		"script": "res://Pyramids/scripts/ui/inventory/InventoryUI.gd",
		"signals": {
			"inventory_closed": "_on_inventory_closed"
		},
		"show_method": "show_inventory"
	},
	"profile": {
		"scene": "res://Pyramids/scenes/ui/profile/ProfileUI.tscn",
		"script": "res://Pyramids/scripts/ui/profile/ProfileUI.gd",
		"signals": {
			"profile_closed": "_on_profile_closed"
		},
		"show_method": "show_profile"
	},
	"achievements": {
		"scene": "res://Pyramids/scenes/ui/achievements/AchievementsUI.tscn",
		"script": "res://Pyramids/scripts/ui/achievements/AchievementsUI.gd",
		"signals": {
			"achievements_closed": "_on_achievements_closed"
		},
		"show_method": "show_achievements"
	},
	"inbox": {
		"scene": "res://Pyramids/scenes/ui/inbox/InboxUI.tscn",
		"script": "res://Pyramids/scripts/ui/inbox/InboxUI.gd",
		"signals": {
			"inbox_closed": "_on_inbox_closed"
		},
		"show_method": "show_inbox"
	},
	"stats": {
		"scene": "res://Pyramids/scenes/ui/stats/StatsUI.tscn",
		"script": "res://Pyramids/scripts/ui/stats/StatsUI.gd",
		"signals": {
			"stats_closed": "_on_stats_closed"
		},
		"show_method": "show_stats"
	},
	"clan": {
		"scene": "res://Pyramids/scenes/ui/clan/ClanUI.tscn",
		"script": "res://Pyramids/scripts/ui/clan/ClanUI.gd",
		"signals": {
			"clan_closed": "_on_clan_closed"
		},
		"show_method": "show_clan"
	},
	"followers": {
		"scene": "res://Pyramids/scenes/ui/followers/FollowersUI.tscn",
		"script": "res://Pyramids/scripts/ui/followers/FollowersUI.gd",
		"signals": {
			"followers_closed": "_on_followers_closed"
		},
		"show_method": "show_followers"
	},
	"referral": {
		"scene": "res://Pyramids/scenes/ui/referral/ReferralUI.tscn",
		"script": "res://Pyramids/scripts/ui/referral/ReferralUI.gd",
		"signals": {
			"referral_closed": "_on_referral_closed"
		},
		"show_method": "show_referral"
	},
	"missions": {
		"scene": "res://Pyramids/scenes/ui/missions/MissionUI.tscn",
		"script": "res://Pyramids/scripts/ui/missions/MissionUI.gd", 
		"signals": {
			"mission_completed": "_on_mission_completed",
			"missions_closed": "_on_missions_closed"
		},
		"show_method": "refresh_missions"
	},
	"season_pass": {
		"scene": "res://Pyramids/scenes/ui/seasonpass/SeasonPassUI.tscn",
		"script": "res://Pyramids/scripts/ui/seasonpass/SeasonPassUI.gd",
		"signals": {
			"tier_claimed": "_on_tier_claimed",
			"season_pass_closed": "_on_season_pass_closed"
		},
		"show_method": "show_season_pass"
	},
	"holiday": {
		"scene": "res://Pyramids/scenes/ui/holiday/HolidayUI.tscn", 
		"script": "res://Pyramids/scripts/ui/holiday/HolidayUI.gd",
		"signals": {
			"event_completed": "_on_holiday_event_completed",
			"holiday_closed": "_on_holiday_closed"
		},
		"show_method": "show_holiday_event"
	},
	"settings": {
		"scene": "res://Pyramids/scenes/ui/settings/SettingsUI.tscn",
		"script": "",  # Empty string - scene already has script
		"signals": {
			"settings_closed": "_on_settings_closed"
		},
		"show_method": "show_settings"
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
	{"name": "Play", "position": Vector2(880, 185), "icon": "res://Pyramids/assets/ui/menu/play.png"},
	{"name": "Shop", "position": Vector2(880, 275), "icon": "res://Pyramids/assets/ui/menu/play.png"},
	{"name": "Missions", "position": Vector2(880, 335), "icon": "res://Pyramids/assets/ui/menu/play.png"},
	{"name": "Season Pass", "position": Vector2(880, 395), "icon": "res://Pyramids/assets/ui/menu/play.png"},
	{"name": "Holiday", "position": Vector2(880, 455), "icon": "res://Pyramids/assets/ui/menu/play.png"}
]

var currently_selected_button: Button = null

func _ready() -> void:
	if not get_node_or_null("/root/UIManager"):
		print("MainMenu: Waiting for UIManager...")
		await get_tree().process_frame

	_setup_menu_background()
	
	_setup_profile_card()
	_create_buttons()
	_create_ui_elements()
	_hide_overlays()
	_setup_version_label()
	_setup_debug_panel()
	_connect_ui_manager()
	
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

func _create_buttons() -> void:
	for i in range(button_configs.size()):
		var config = button_configs[i]
		var button_instance = ButtonLayoutScene.instantiate() as Button
		
		add_child(button_instance)
		button_instance.position = config.position
		
		# Get nodes from the ButtonLayout structure
		var label = button_instance.get_node_or_null("MainPanel/MarginContainer/Label")
		var icon = button_instance.get_node_or_null("MainPanel/MarginContainer/Icon")
		
		if label:
			label.text = config.name
		
		# Set icon if it exists
		if icon and config.has("icon"):
			var texture = load(config.icon)
			if texture:
				icon.texture = texture
				icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Apply style and setup based on button type
		if config.name == "Play":
			# Attach SwipePlayButton script to the existing button
			var swipe_script = preload("res://Pyramids/scripts/ui/components/SwipePlayButton.gd")
			button_instance.set_script(swipe_script)
			
			# MANUALLY CALL _ready() since the node is already in the tree
			button_instance._ready()
			
			UIStyleManager.apply_menu_button_style(button_instance, "play")
			play_button = button_instance
			
			# Connect swipe button signals
			if button_instance.has_signal("play_pressed"):
				button_instance.play_pressed.connect(_on_swipe_play_pressed)
			if button_instance.has_signal("mode_changed"):
				button_instance.mode_changed.connect(_on_play_mode_changed)
		else:
			UIStyleManager.apply_menu_button_style(button_instance, "default")
			
			# Store button references
			match config.name:
				"Shop":
					shop_button = button_instance
				"Missions":
					daily_mission_button = button_instance
				"Season Pass":
					season_pass_button = button_instance
				"Holiday":
					holiday_button = button_instance
			
			# Set toggle mode for non-play buttons
			button_instance.toggle_mode = true
			button_instance.pressed.connect(_on_button_pressed.bind(config.name))
		
		# Move to top
		move_child(button_instance, get_child_count() - 1)

func _on_swipe_play_pressed(mode: String):
	print("Playing in mode: " + mode)
	# SwipePlayButton script already handles the game start
	
func _on_play_mode_changed(mode: String):
	print("Mode changed to: " + mode)
	# Could save preference to SettingsSystem
	SettingsSystem.set("last_play_mode", mode)

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
	# Get the button that was pressed
	var pressed_button: Button = null
	match button_name:
		"Play":
			_on_play_pressed()
			return  # Play doesn't toggle, just starts game
		"Shop":
			pressed_button = shop_button
			_on_shop_pressed()
		"Missions":
			pressed_button = daily_mission_button
			_on_daily_mission_pressed()
		"Season Pass":
			pressed_button = season_pass_button
			_on_season_pass_pressed()
		"Holiday":
			pressed_button = holiday_button
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
	get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")

func _on_shop_pressed() -> void:
	_toggle_menu_panel("shop", shop_button)

func _on_daily_mission_pressed() -> void:
	_toggle_menu_panel("missions", daily_mission_button)

func _on_season_pass_pressed() -> void:
	_toggle_menu_panel("season_pass", season_pass_button)

func _on_holiday_pressed() -> void:
	_toggle_menu_panel("holiday", holiday_button)

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
		var debug_scene = preload("res://Pyramids/scenes/ui/debug/DebugPanel.tscn")
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
	_toggle_menu_panel("settings", cog_button)

func _on_settings_closed():
	pass

func _on_achievements_closed() -> void:
	achievements_overlay.visible = false

func _setup_profile_card():
	if not profile_card:
		var profile_card_scene = preload("res://Pyramids/scenes/ui/components/ProfileCard.tscn")
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
	# Get the button that was pressed from ProfileCard
	var button = null
	if profile_card:
		match section:
			"profile":
				button = profile_card.profile_button
			"inventory":
				button = profile_card.inventory_button
			"inbox":
				button = profile_card.inbox_button
			"achievements":
				button = profile_card.achievements_button
			"stats":
				button = profile_card.stats_button
			"clan":
				button = profile_card.clan_button
			"followers":
				button = profile_card.followers_button
			"referral":
				button = profile_card.referral_button
	
	# All sections now use the same panel system
	_toggle_menu_panel(section, button)

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
func _toggle_menu_panel(menu_name: String, button: BaseButton = null) -> void:
	var ui_manager = get_node_or_null("/root/UIManager")
	if not ui_manager:
		print("UIManager not found!")
		return
		
	if not menu_configs.has(menu_name):
		print("Unknown menu: ", menu_name)
		return
		
	var config = menu_configs[menu_name]
	
	# Get or create instance
	var instance = null
	if not menu_instances.has(menu_name) or not menu_instances[menu_name]:
		# Create new instance
		instance = _create_menu_panel(config.scene, config.script)
		menu_instances[menu_name] = instance
		
		# Connect signals
		for signal_name in config.get("signals", {}):
			if instance.has_signal(signal_name):
				var method_name = config.signals[signal_name]
				if has_method(method_name):
					instance.connect(signal_name, Callable(self, method_name))
	else:
		instance = menu_instances[menu_name]
	
	# Use UIManager to handle the panel
	ui_manager.open_panel(instance, menu_name, button)

func _on_inventory_closed():
	pass
	
func _connect_ui_manager():
	var ui_manager = get_node_or_null("/root/UIManager")
	if ui_manager:
		if not ui_manager.ui_panel_opened.is_connected(_on_ui_panel_opened):
			ui_manager.ui_panel_opened.connect(_on_ui_panel_opened)
		if not ui_manager.ui_panel_closed.is_connected(_on_ui_panel_closed):
			ui_manager.ui_panel_closed.connect(_on_ui_panel_closed)
	else:
		print("UIManager not available for connection!")

func _on_ui_panel_opened(panel_name: String):
	# When a panel opens, select the corresponding button
	var button_to_select: Button = null
	match panel_name:
		"shop":
			button_to_select = shop_button
		"missions":
			button_to_select = daily_mission_button
		"season_pass":
			button_to_select = season_pass_button
		"holiday":
			button_to_select = holiday_button
	
	if button_to_select:
		# Deselect previous button if any
		if currently_selected_button and currently_selected_button != button_to_select:
			currently_selected_button.button_pressed = false
			_apply_button_state(currently_selected_button, false)
		
		# Select the new button
		currently_selected_button = button_to_select
		button_to_select.button_pressed = true
		_apply_button_state(button_to_select, true)

func _on_ui_panel_closed(panel_name: String) -> void:
	# When a panel closes, deselect the corresponding button
	var button_to_deselect: Button = null
	match panel_name:
		"shop":
			button_to_deselect = shop_button
		"missions":
			button_to_deselect = daily_mission_button
		"season_pass":
			button_to_deselect = season_pass_button
		"holiday":
			button_to_deselect = holiday_button
	
	if button_to_deselect and button_to_deselect == currently_selected_button:
		button_to_deselect.button_pressed = false
		_apply_button_state(button_to_deselect, false)
		currently_selected_button = null

func _on_profile_closed():
	pass

func _on_inbox_closed():
	pass

func _on_stats_closed():
	pass

func _on_clan_closed():
	pass

func _on_followers_closed():
	pass

func _on_referral_closed():
	pass

func _handle_button_toggle(button: Button) -> void:
	pass

# Add function to apply visual states:
func _apply_button_state(button: Button, is_selected: bool) -> void:
	"""Apply visual state to button based on selection"""
	var main_panel = button.get_node_or_null("MainPanel")
	if not main_panel:
		return
	
	if is_selected:
		var pressed_style = button.get_meta("pressed_style", null)
		if pressed_style:
			main_panel.add_theme_stylebox_override("panel", pressed_style)
	else:
		var normal_style = button.get_meta("normal_style", null)
		if normal_style:
			main_panel.add_theme_stylebox_override("panel", normal_style)
