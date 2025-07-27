# SettingsSystem.gd - Autoload for game settings and preferences
# Path: res://Magic-Castle/scripts/autoloads/SettingsSystem.gd
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

# === SKIN SETTINGS ===
var current_card_skin: String = "sprites"
var current_board_skin: String = "default"
var current_game_mode: String = "tri_peaks"
var high_contrast: bool = true

# === AUDIO SETTINGS ===
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var error_sounds_enabled: bool = true
var success_sounds_enabled: bool = true

# === PROFILE SETTINGS ===
var player_name: String = "Player"
var player_avatar: String = "default"
var player_frame: String = "basic"

# === STATS TRACKING ===
var total_games_played: int = 0
var total_wins: int = 0
var highest_combo: int = 0
var best_round_score: int = 0
var best_game_score: int = 0

# === AD SETTINGS ===
var ad_skips_remaining: int = 2
var last_ad_skip_date: String = ""
var ads_watched_today: int = 0
var last_ad_watch_date: String = ""

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

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
	save_settings()

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	save_settings()

# === SKIN SYSTEM ===
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

# === STATS METHODS ===
func update_stats(round_score: int, game_score: int, combo: int, won: bool) -> void:
	total_games_played += 1
	if won:
		total_wins += 1
	
	highest_combo = max(highest_combo, combo)
	best_round_score = max(best_round_score, round_score)
	best_game_score = max(best_game_score, game_score)
	
	save_settings()

# === AD MANAGEMENT ===
func get_ad_skips() -> int:
	_check_daily_reset()
	return ad_skips_remaining

func use_ad_skip() -> bool:
	if ad_skips_remaining > 0:
		ad_skips_remaining -= 1
		save_settings()
		return true
	return false

func watch_ad_for_skip() -> bool:
	_check_daily_reset()
	if ads_watched_today < 3:
		ads_watched_today += 1
		ad_skips_remaining = min(ad_skips_remaining + 3, 11)  # Max 11 skips
		last_ad_watch_date = Time.get_date_string_from_system()
		save_settings()
		return true
	return false

func _check_daily_reset() -> void:
	var today = Time.get_date_string_from_system()
	if last_ad_skip_date != today:
		ad_skips_remaining = 2  # Daily reset
		ads_watched_today = 0
		last_ad_skip_date = today
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
	
	# Skin settings
	config.set_value("skins", "card_skin", current_card_skin)
	config.set_value("skins", "board_skin", current_board_skin)
	config.set_value("skins", "high_contrast", high_contrast)
	
	# Game mode
	config.set_value("gameplay", "game_mode", current_game_mode)
	config.set_value("gameplay", "animation_speed", animation_speed)
	
	# Profile settings
	config.set_value("profile", "name", player_name)
	config.set_value("profile", "avatar", player_avatar)
	config.set_value("profile", "frame", player_frame)
	
	# Stats
	config.set_value("stats", "games_played", total_games_played)
	config.set_value("stats", "wins", total_wins)
	config.set_value("stats", "highest_combo", highest_combo)
	config.set_value("stats", "best_round", best_round_score)
	config.set_value("stats", "best_game", best_game_score)
	
	# Ad settings
	config.set_value("ads", "skips_remaining", ad_skips_remaining)
	config.set_value("ads", "last_skip_date", last_ad_skip_date)
	config.set_value("ads", "watched_today", ads_watched_today)
	config.set_value("ads", "last_watch_date", last_ad_watch_date)
	
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
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 1.0)
	error_sounds_enabled = config.get_value("audio", "error_sounds", true)
	success_sounds_enabled = config.get_value("audio", "success_sounds", true)
	
	# Load skin settings
	current_card_skin = config.get_value("skins", "card_skin", "default")
	current_board_skin = config.get_value("skins", "board_skin", "default")
	high_contrast = config.get_value("skins", "high_contrast", true)
	
	# Load game mode
	current_game_mode = config.get_value("gameplay", "game_mode", "tri_peaks")
	animation_speed = config.get_value("gameplay", "animation_speed", 1.0)
	
	# Load profile settings
	player_name = config.get_value("profile", "name", "Player")
	player_avatar = config.get_value("profile", "avatar", "default")
	player_frame = config.get_value("profile", "frame", "basic")
	
	# Load stats
	total_games_played = config.get_value("stats", "games_played", 0)
	total_wins = config.get_value("stats", "wins", 0)
	highest_combo = config.get_value("stats", "highest_combo", 0)
	best_round_score = config.get_value("stats", "best_round", 0)
	best_game_score = config.get_value("stats", "best_game", 0)
	
	# Load ad settings
	ad_skips_remaining = config.get_value("ads", "skips_remaining", 2)
	last_ad_skip_date = config.get_value("ads", "last_skip_date", "")
	ads_watched_today = config.get_value("ads", "watched_today", 0)
	last_ad_watch_date = config.get_value("ads", "last_watch_date", "")
	
	print("Settings loaded: draw_mode=%d, sound=%s" % [draw_pile_mode, sound_enabled])

# === MOBILE OPTIMIZATION ===
func get_scaled_size(base_size: Vector2) -> Vector2:
	return base_size * ui_scale_factor

func get_scaled_font_size(base_size: int) -> int:
	return int(base_size * ui_scale_factor)
