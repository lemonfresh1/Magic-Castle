# SettingsSystem.gd - Autoload for game settings and preferences
extends Node

# === DRAW PILE PREFERENCES ===
enum DrawPileMode {
	LEFT_ONLY,
	RIGHT_ONLY,
	BOTH_SIDES
}

# === CURRENT SETTINGS ===
var draw_pile_mode: DrawPileMode = DrawPileMode.LEFT_ONLY
var sound_enabled: bool = true
var animation_speed: float = 1.0  # Placeholder for future
var haptic_enabled: bool = true   # Placeholder for future

# === SKIN SETTINGS (Placeholders) ===
var current_card_skin: String = "default"
var current_board_skin: String = "default"
var current_game_mode: String = "tri_peaks"
var high_contrast: bool = true

# === MOBILE SETTINGS ===
var target_screen_width: int = 1080   # Pixel 8 width
var target_screen_height: int = 2400  # Pixel 8 height
var ui_scale_factor: float = 1.0

func _ready() -> void:
	print("SettingsSystem initialized")
	_detect_screen_settings()
	load_settings()

func _detect_screen_settings() -> void:
	var screen_size = DisplayServer.screen_get_size()
	var window_size = get_viewport().get_visible_rect().size
	
	print("Screen size: %v, Window size: %v" % [screen_size, window_size])
	
	# Calculate scale factor for UI elements
	ui_scale_factor = min(window_size.x / target_screen_width, window_size.y / target_screen_height)
	ui_scale_factor = max(ui_scale_factor, 0.5)  # Don't scale too small
	
	print("UI scale factor: %.2f" % ui_scale_factor)

# === DRAW PILE SETTINGS ===
func set_draw_pile_mode(mode: DrawPileMode) -> void:
	draw_pile_mode = mode
	SignalBus.draw_pile_mode_changed.emit(mode)
	save_settings()

func get_draw_pile_mode() -> DrawPileMode:
	return draw_pile_mode

func is_left_draw_enabled() -> bool:
	return draw_pile_mode == DrawPileMode.LEFT_ONLY or draw_pile_mode == DrawPileMode.BOTH_SIDES

func is_right_draw_enabled() -> bool:
	return draw_pile_mode == DrawPileMode.RIGHT_ONLY or draw_pile_mode == DrawPileMode.BOTH_SIDES

# === AUDIO SETTINGS ===
func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	SignalBus.sound_setting_changed.emit(enabled)
	save_settings()

func is_sound_enabled() -> bool:
	return sound_enabled

# === SKIN SYSTEM (Foundation) ===
func set_card_skin(skin_name: String) -> void:
	current_card_skin = skin_name
	SignalBus.card_skin_changed.emit(skin_name)
	save_settings()

func set_board_skin(skin_name: String) -> void:
	current_board_skin = skin_name
	SignalBus.board_skin_changed.emit(skin_name)
	save_settings()

func set_game_mode(mode_name: String) -> void:
	current_game_mode = mode_name
	SignalBus.game_mode_changed.emit(mode_name)
	save_settings()

# === PERSISTENCE ===
func save_settings() -> void:
	var config = ConfigFile.new()
	
	# Draw pile settings
	config.set_value("draw_pile", "mode", draw_pile_mode)
	
	# Audio settings
	config.set_value("audio", "sound_enabled", sound_enabled)
	
	# Skin settings
	config.set_value("skins", "card_skin", current_card_skin)
	config.set_value("skins", "board_skin", current_board_skin)
	
	# Game mode
	config.set_value("gameplay", "game_mode", current_game_mode)
	config.set_value("gameplay", "animation_speed", animation_speed)
	
	var error = config.save("user://settings.cfg")
	if error == OK:
		print("Settings saved successfully")
	else:
		print("Error saving settings: %d" % error)

func load_settings() -> void:
	var config = ConfigFile.new()
	var error = config.load("user://settings.cfg")
	
	if error != OK:
		print("No settings file found, using defaults")
		return
	
	# Load draw pile settings
	draw_pile_mode = config.get_value("draw_pile", "mode", DrawPileMode.LEFT_ONLY)
	
	# Load audio settings
	sound_enabled = config.get_value("audio", "sound_enabled", true)
	
	# Load skin settings
	current_card_skin = config.get_value("skins", "card_skin", "default")
	current_board_skin = config.get_value("skins", "board_skin", "default")
	
	# Load game mode
	current_game_mode = config.get_value("gameplay", "game_mode", "tri_peaks")
	animation_speed = config.get_value("gameplay", "animation_speed", 1.0)
	
	print("Settings loaded: draw_mode=%d, sound=%s" % [draw_pile_mode, sound_enabled])

# === MOBILE OPTIMIZATION ===
func get_scaled_size(base_size: Vector2) -> Vector2:
	return base_size * ui_scale_factor

func get_scaled_font_size(base_size: int) -> int:
	return int(base_size * ui_scale_factor)
