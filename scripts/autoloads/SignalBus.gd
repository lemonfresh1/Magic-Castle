# SignalBus.gd - Autoload for centralized game signals
# Path: res://Pyramids/scripts/autoloads/SignalBus.gd
# Last Updated: Added complete auth and profile system signals

extends Node

# === CARD GAMEPLAY SIGNALS ===
signal card_selected(card: Node)
signal card_invalid_selected(card: Node)
signal combo_updated(count: int)
signal combo_multiplier_changed(multiplier: float)
signal draw_pile_clicked()
signal reveal_all_cards

# === SCORE SIGNALS ===
signal score_changed(points: int, reason: String)

# === GAME FLOW SIGNALS ===
signal round_started(round_number: int)
signal round_completed(score: int)
signal game_over(total_score: int)
signal timer_expired()

# === GAME TRACKING SIGNALS ===
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
signal game_settings_changed(settings: Dictionary)
signal game_ended(final_score: int)

# === LOBBY SIGNALS ===
signal lobby_player_joined(player_id: String, player_data: Dictionary)
signal lobby_player_left(player_id: String)
signal lobby_player_ready_changed(player_id: String, ready: bool)
signal lobby_all_players_ready()
signal lobby_start_requested()
signal lobby_invite_requested(slot_index: int)
signal lobby_player_kicked(player_id: String)

# === MULTIPLAYER GAME SIGNALS ===
signal multiplayer_round_continue  # When score screen countdown ends
signal multiplayer_game_complete   # When final game is over
signal multiplayer_scores_updated(scores: Array)  # When scores change

# === AUTH & PROFILE SIGNALS ===
signal auth_state_changed(data: Dictionary)  # Login/logout events
signal profile_loaded(profile: Dictionary)
signal profile_updated(field: String, value: Variant)
signal profile_sync_completed()
signal profile_sync_failed(error: String)

# === ACCOUNT SIGNALS ===
signal anonymous_account_created()
signal account_upgraded(user_data: Dictionary)
signal username_set(username: String)
signal display_name_changed(display_name: String)

# === CUSTOMIZATION SIGNALS ===
signal avatar_changed(avatar_id: String)
signal banner_changed(banner_id: String)
signal frame_equipped(frame_id: String)
signal title_equipped(title_id: String)
signal showcase_updated(item_ids: Array)

# === PROGRESSION SIGNALS ===
signal xp_gained(amount: int, new_total: int)
signal level_up(new_level: int)
signal prestige_gained(new_prestige: int)
signal stars_changed(amount: int, new_total: int)

# === UI SIGNALS ===
signal show_login_ui()
signal show_profile_ui()
signal show_username_prompt()
signal show_upgrade_prompt()

# === ERROR SIGNALS ===
signal profile_error(error_type: String, message: String)
signal network_error(message: String)

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

func emit_profile_event(event_type: String, data: Variant = null) -> void:
	match event_type:
		"loaded":
			profile_loaded.emit(data as Dictionary)
		"updated":
			if data is Array and data.size() >= 2:
				profile_updated.emit(data[0] as String, data[1])
		"sync_complete":
			profile_sync_completed.emit()
		"sync_failed":
			profile_sync_failed.emit(data as String)

func emit_auth_event(event_type: String, data: Variant = null) -> void:
	match event_type:
		"state_changed":
			auth_state_changed.emit(data as Dictionary)
		"anonymous_created":
			anonymous_account_created.emit()
		"account_upgraded":
			account_upgraded.emit(data as Dictionary)

# === DEBUG HELPERS ===

func log_event(message: String) -> void:
	print("[SignalBus] %s" % message)
	debug_message.emit(message)
