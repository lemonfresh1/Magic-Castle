# SettingsSystem.gd - Autoload for game settings and preferences
# Path: res://Pyramids/scripts/autoloads/SettingsSystem.gd
# Last Updated: Refactored to work with new manager architecture
#
# SettingsSystem handles:
# - User preferences (audio, controls, performance)
# - Draw zone configuration sync with DrawZoneManager
# - Game mode preferences sync with GameModeManager
# - Display settings and UI scaling for mobile
# - Player profile basics (name, ID generation)
# - Battery saver and performance options
#
# Flow: User input → SettingsSystem → Sync with managers → Save to disk
# Dependencies: DrawZoneManager (for zones), GameModeManager (for modes), AudioServer (for volume)

extends Node

# === DRAW PILE PREFERENCES ===
enum DrawPileMode {
	LEFT_ONLY,
	RIGHT_ONLY,
	BOTH_SIDES,
	NONE  # For potential PC mode
}

# === CURRENT SETTINGS ===
var draw_pile_mode: DrawPileMode = DrawPileMode.BOTH_SIDES  # Default to both for mobile
var sound_enabled: bool = true
var animation_speed: float = 1.0
var haptic_enabled: bool = true

# === GAME SETTINGS ===
var current_game_mode: String = "tri_peaks"
var preferred_play_mode: String = "Solo"  # Default to Solo


# === AUDIO SETTINGS ===
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var error_sounds_enabled: bool = true
var success_sounds_enabled: bool = true

# === PROFILE SETTINGS ===
var player_name: String = "Player"
var player_id: String = ""  # For multiplayer/cloud saves

# Stats are now handled by StatsManager
# Ads are now handled by AdManager

# === MOBILE SETTINGS ===
var target_screen_width: int = 1080   # Pixel 8 width
var target_screen_height: int = 2400  # Pixel 8 height
var ui_scale_factor: float = 1.0

# === PERFORMANCE SETTINGS ===
var particle_effects_enabled: bool = true
var reduce_animations: bool = false
var battery_saver_mode: bool = false

func _ready() -> void:
	print("SettingsSystem initialized")
	_detect_screen_settings()
	load_settings()
	_sync_with_managers()

func _detect_screen_settings() -> void:
	var screen_size = DisplayServer.screen_get_size()
	var window_size = get_viewport().get_visible_rect().size
	
	print("Screen size: %v, Window size: %v" % [screen_size, window_size])
	
	# Calculate scale factor for UI elements
	ui_scale_factor = min(window_size.x / target_screen_width, window_size.y / target_screen_height)
	ui_scale_factor = max(ui_scale_factor, 0.5)  # Don't scale too small
	
	print("UI scale factor: %.2f" % ui_scale_factor)

func _sync_with_managers() -> void:
	"""Sync settings with the new manager architecture"""
	# Sync draw zones with DrawZoneManager
	if DrawZoneManager:
		var zone_mode = _convert_to_draw_zone_mode(draw_pile_mode)
		DrawZoneManager.set_draw_mode(zone_mode)

func _convert_to_draw_zone_mode(mode: DrawPileMode) -> int:
	"""Convert SettingsSystem mode to DrawZoneManager mode"""
	match mode:
		DrawPileMode.LEFT_ONLY:
			return DrawZoneManager.DrawZoneMode.LEFT_ONLY
		DrawPileMode.RIGHT_ONLY:
			return DrawZoneManager.DrawZoneMode.RIGHT_ONLY
		DrawPileMode.BOTH_SIDES:
			return DrawZoneManager.DrawZoneMode.BOTH
		DrawPileMode.NONE:
			return DrawZoneManager.DrawZoneMode.NONE
		_:
			return DrawZoneManager.DrawZoneMode.BOTH

# === DRAW PILE SETTINGS ===
func set_draw_pile_mode(mode: DrawPileMode) -> void:
	draw_pile_mode = mode
	
	# Sync with DrawZoneManager
	if DrawZoneManager:
		var zone_mode = _convert_to_draw_zone_mode(mode)
		DrawZoneManager.set_draw_mode(zone_mode)
	
	save_settings()

func get_draw_pile_mode() -> DrawPileMode:
	return draw_pile_mode

func is_left_draw_enabled() -> bool:
	return draw_pile_mode == DrawPileMode.LEFT_ONLY or draw_pile_mode == DrawPileMode.BOTH_SIDES

func is_right_draw_enabled() -> bool:
	return draw_pile_mode == DrawPileMode.RIGHT_ONLY or draw_pile_mode == DrawPileMode.BOTH_SIDES

# Note: set_left_draw_enabled and set_right_draw_enabled removed to prevent recursion
# Use set_draw_pile_mode directly instead

# === AUDIO SETTINGS ===
func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	SignalBus.sound_setting_changed.emit(enabled)
	save_settings()

func is_sound_enabled() -> bool:
	return sound_enabled

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(sfx_volume))
	save_settings()

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(music_volume))
	save_settings()

# === GAME MODE ===
func set_game_mode(mode_name: String) -> void:
	"""Set game mode and emit signal for GameModeManager to handle"""
	if current_game_mode == mode_name:
		return  # No change needed
	
	current_game_mode = mode_name
	save_settings()
	
	# Emit signal for GameModeManager to react
	SignalBus.game_mode_changed.emit(mode_name)

func save_game_mode(mode_name: String) -> void:
	"""Save game mode without emitting signals (called by GameModeManager)"""
	current_game_mode = mode_name
	save_settings()

func get_game_mode() -> String:
	"""Get the current game mode"""
	return current_game_mode

# === PROFILE ===
func set_player_name(name: String) -> void:
	player_name = name
	save_settings()

func generate_player_id() -> String:
	"""Generate a unique player ID if not set"""
	if player_id == "":
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		player_id = "player_%d_%d" % [Time.get_unix_time_from_system(), rng.randi()]
		save_settings()
	return player_id

# === PERFORMANCE SETTINGS ===
func set_particle_effects(enabled: bool) -> void:
	particle_effects_enabled = enabled
	save_settings()

func set_reduce_animations(enabled: bool) -> void:
	reduce_animations = enabled
	save_settings()

func set_battery_saver(enabled: bool) -> void:
	battery_saver_mode = enabled
	
	# Apply battery saver settings
	if enabled:
		particle_effects_enabled = false
		reduce_animations = true
		Engine.max_fps = 30
	else:
		Engine.max_fps = 60
	
	save_settings()

# === PERSISTENCE ===
func save_settings() -> void:
	var config = ConfigFile.new()
	
	# Draw pile settings
	config.set_value("draw_pile", "mode", draw_pile_mode)
	
	# Audio settings
	config.set_value("audio", "sound_enabled", sound_enabled)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "error_sounds", error_sounds_enabled)
	config.set_value("audio", "success_sounds", success_sounds_enabled)
	
	# Game settings
	config.set_value("gameplay", "game_mode", current_game_mode)
	config.set_value("gameplay", "animation_speed", animation_speed)
	config.set_value("gameplay", "haptic_enabled", haptic_enabled)
	config.set_value("gameplay", "preferred_play_mode", preferred_play_mode)

	
	# Profile settings
	config.set_value("profile", "name", player_name)
	config.set_value("profile", "id", player_id)
	
	# Performance settings
	config.set_value("performance", "particle_effects", particle_effects_enabled)
	config.set_value("performance", "reduce_animations", reduce_animations)
	config.set_value("performance", "battery_saver", battery_saver_mode)
	
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
	draw_pile_mode = config.get_value("draw_pile", "mode", DrawPileMode.BOTH_SIDES)
	
	# Load audio settings
	sound_enabled = config.get_value("audio", "sound_enabled", true)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 1.0)
	error_sounds_enabled = config.get_value("audio", "error_sounds", true)
	success_sounds_enabled = config.get_value("audio", "success_sounds", true)
	
	# Load game settings
	current_game_mode = config.get_value("gameplay", "game_mode", "tri_peaks")
	animation_speed = config.get_value("gameplay", "animation_speed", 1.0)
	haptic_enabled = config.get_value("gameplay", "haptic_enabled", true)
	preferred_play_mode = config.get_value("gameplay", "preferred_play_mode", "Solo")

	# Load profile settings
	player_name = config.get_value("profile", "name", "Player")
	player_id = config.get_value("profile", "id", "")
	
	# Load performance settings
	particle_effects_enabled = config.get_value("performance", "particle_effects", true)
	reduce_animations = config.get_value("performance", "reduce_animations", false)
	battery_saver_mode = config.get_value("performance", "battery_saver", false)
	
	# Apply audio settings
	set_sfx_volume(sfx_volume)
	set_music_volume(music_volume)
	
	print("Settings loaded: draw_mode=%d, sound=%s" % [draw_pile_mode, sound_enabled])

# === MOBILE OPTIMIZATION ===
func get_scaled_size(base_size: Vector2) -> Vector2:
	return base_size * ui_scale_factor

func get_scaled_font_size(base_size: int) -> int:
	return int(base_size * ui_scale_factor)

func set_preferred_play_mode(mode: String) -> void:
	preferred_play_mode = mode
	save_settings()

func get_preferred_play_mode() -> String:
	return preferred_play_mode

# === RESET FUNCTIONS ===
func reset_to_defaults() -> void:
	"""Reset all settings to defaults"""
	draw_pile_mode = DrawPileMode.BOTH_SIDES
	sound_enabled = true
	animation_speed = 1.0
	haptic_enabled = true
	current_game_mode = "tri_peaks"
	sfx_volume = 1.0
	music_volume = 1.0
	error_sounds_enabled = true
	success_sounds_enabled = true
	particle_effects_enabled = true
	reduce_animations = false
	battery_saver_mode = false
	
	# Don't reset player name
	save_settings()
	_sync_with_managers()

# === DEBUG ===
func debug_print_settings() -> void:
	"""Print all current settings for debugging"""
	print("\n=== SETTINGS SYSTEM DEBUG ===")
	print("Draw Pile Mode: %s" % DrawPileMode.keys()[draw_pile_mode])
	print("Game Mode: %s" % current_game_mode)
	print("Audio - SFX: %.1f, Music: %.1f" % [sfx_volume, music_volume])
	print("Performance - Particles: %s, Battery Saver: %s" % [particle_effects_enabled, battery_saver_mode])
	print("Player: %s (ID: %s)" % [player_name, player_id])
	print("=============================\n")
