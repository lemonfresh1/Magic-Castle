# SignalBus.gd - Autoload for centralized game signals
# Path: res://Magic-Castle/scripts/autoloads/SignalBus.gd
# Last Updated: Added mission and achievement tracking signals [Date]

extends Node

# === CARD GAMEPLAY SIGNALS ===
signal card_selected(card: Node)
signal card_invalid_selected(card: Node)
signal combo_updated(count: int)
signal combo_multiplier_changed(multiplier: float)
signal draw_pile_clicked()

# === SCORE SIGNALS ===
signal score_changed(points: int, reason: String)

# === GAME FLOW SIGNALS ===
signal round_started(round_number: int)
signal round_completed(score: int)
signal game_over(total_score: int)
signal timer_expired()

# === GAME TRACKING SIGNALS (NEW) ===
signal game_won(final_score: int, time_elapsed: float)
signal game_lost(final_score: int, reason: String)
signal perfect_clear_achieved()
signal streak_achieved(streak_count: int)
signal special_combo_completed(combo_type: String)

# === SETTINGS SIGNALS ===
signal draw_pile_mode_changed(mode: int)
signal sound_setting_changed(enabled: bool)
signal card_skin_changed(skin_name: String)
signal board_skin_changed(skin_name: String)
signal game_mode_changed(mode_name: String)
signal high_contrast_changed(enabled: bool)

# === AUDIO SIGNALS ===
signal play_sound_effect(sound_name: String)
signal play_random_sound(sound_group: String)

# === MOBILE UI SIGNALS ===
signal mobile_layout_changed()
signal ui_scale_changed(scale_factor: float)

# === DEBUG SIGNALS ===
signal debug_message(message: String)

func _ready() -> void:
	print("SignalBus initialized")
	debug_message.emit("SignalBus ready with %d signals" % get_signal_list().size())

# === UTILITY FUNCTIONS ===
func emit_card_selection(card: Node, is_valid: bool) -> void:
	if is_valid:
		card_selected.emit(card)
	else:
		card_invalid_selected.emit(card)

func emit_score_update(points: int, reason: String) -> void:
	score_changed.emit(points, reason)
	debug_message.emit("Score: %+d (%s)" % [points, reason])

func emit_combo_change(combo_count: int, multiplier: float = 1.0) -> void:
	combo_updated.emit(combo_count)
	combo_multiplier_changed.emit(multiplier)

func emit_round_event(event_type: String, data: Variant = null) -> void:
	match event_type:
		"started":
			round_started.emit(data as int)
		"completed":
			round_completed.emit(data as int)
		"game_over":
			game_over.emit(data as int)
		"timer_expired":
			timer_expired.emit()

func emit_game_result(won: bool, score: int, time: float = 0.0, reason: String = "") -> void:
	if won:
		game_won.emit(score, time)
	else:
		game_lost.emit(score, reason)
	
	# Also emit general game_over
	game_over.emit(score)

func emit_audio_event(sound_type: String, sound_name: String) -> void:
	match sound_type:
		"effect":
			play_sound_effect.emit(sound_name)
		"random":
			play_random_sound.emit(sound_name)

# === DEBUG HELPERS ===
func log_event(message: String) -> void:
	print("[SignalBus] %s" % message)
	debug_message.emit(message)
