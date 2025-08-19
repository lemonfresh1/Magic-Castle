# GameModeManager.gd - COMPLETE VERSION with all missing methods
# Path: res://Pyramids/scripts/autoloads/GameModeManager.gd

extends Node

# Current mode configuration
var current_mode_id: String = "test"
var current_mode_config: Dictionary = {}

# Available modes with round-based rules
var available_modes = {
	"test": {
		"display_name": "TestMode",
		"timer_enabled": true,
		"base_timer": 50,
		"timer_decrease_per_round": 10,
		"undo_enabled": false,
		"undo_penalty": 50,
		"base_draw_limit": 20,
		"draw_limit_decrease": 0,
		"combo_timeout": 15.0,
		"slot_2_unlock": 2,
		"slot_3_unlock": 6,
		"base_points_start": 100,
		"base_points_per_round": 10,
		"max_rounds": 2,
		"card_visibility": "even_rounds"  # NEW: always, never, odd_rounds, even_rounds
	},
	"classic": {
		"display_name": "Classic",
		"timer_enabled": true,
		"base_timer": 60,
		"timer_decrease_per_round": 2,
		"undo_enabled": true,
		"undo_penalty": 50,
		"base_draw_limit": 20,
		"draw_limit_decrease": 0,
		"combo_timeout": 10.0,
		"slot_2_unlock": 2,
		"slot_3_unlock": 6,
		"base_points_start": 100,
		"base_points_per_round": 10,
		"max_rounds": 10,
		"card_visibility": "always"  # NEW: always, never, odd_rounds, even_rounds
	},
	"timed_rush": {
		"display_name": "Timed Rush",
		"timer_enabled": true,
		"base_timer": 50,
		"timer_decrease_per_round": 3,
		"undo_enabled": false,
		"undo_penalty": 0,
		"base_draw_limit": 18,
		"draw_limit_decrease": 1,
		"combo_timeout": 7.0,
		"slot_2_unlock": 3,
		"slot_3_unlock": 7,
		"base_points_start": 100,
		"base_points_per_round": 15,
		"max_rounds": 5,
		"card_visibility": "always"  # NEW: always, never, odd_rounds, even_rounds
	},
	"zen": {
		"display_name": "Zen Mode",
		"timer_enabled": false,
		"base_timer": 0,
		"timer_decrease_per_round": 0,
		"undo_enabled": true,
		"undo_penalty": 0,
		"base_draw_limit": 999,
		"draw_limit_decrease": 0,
		"combo_timeout": 999.0,
		"slot_2_unlock": 5,
		"slot_3_unlock": 10,
		"base_points_start": 100,
		"base_points_per_round": 10,
		"max_rounds": 10,
		"card_visibility": "always"  # NEW: always, never, odd_rounds, even_rounds
	},
	"daily_challenge": {
		"display_name": "Daily Challenge",
		"timer_enabled": false,
		"base_timer": 0,
		"timer_decrease_per_round": 0,
		"undo_enabled": false,
		"undo_penalty": 100,
		"base_draw_limit": 24,
		"draw_limit_decrease": 0,
		"combo_timeout": 5.0,
		"slot_2_unlock": 4,
		"slot_3_unlock": 5,
		"base_points_start": 100,
		"base_points_per_round": 10,
		"max_rounds": 10,
		"card_visibility": "never"  # NEW: always, never, odd_rounds, even_rounds
	},
	"puzzle_master": {
		"display_name": "Puzzle Master",
		"timer_enabled": false,
		"base_timer": 0,
		"timer_decrease_per_round": 0,
		"undo_enabled": false,
		"undo_penalty": 0,
		"base_draw_limit": 0,
		"draw_limit_decrease": 0,
		"combo_timeout": 5.0,
		"slot_2_unlock": 999,
		"slot_3_unlock": 999,
		"base_points_start": 100,
		"base_points_per_round": 10,
		"max_rounds": 1,
		"card_visibility": "always"  # NEW: always, never, odd_rounds, even_rounds
	}
}

func _ready():
	print("GameModeManager initialized")
	# Load saved mode from SettingsSystem
	if SettingsSystem:
		var saved_mode = SettingsSystem.get_game_mode()
		if saved_mode and available_modes.has(saved_mode):
			set_game_mode(saved_mode, {})
		else:
			set_game_mode("test", {})
	else:
		set_game_mode("test", {})

func set_game_mode(mode_id: String, config: Dictionary = {}):
	"""Set game mode with optional config overrides"""
	if not available_modes.has(mode_id):
		push_error("Invalid game mode: " + mode_id)
		return
	
	current_mode_id = mode_id
	current_mode_config = available_modes[mode_id].duplicate()
	current_mode_config.merge(config, true)
	
	_apply_mode_settings()
	
	# Special handling
	match mode_id:
		"daily_challenge":
			_setup_daily_seed()
		"puzzle_master":
			_load_puzzle_deck()
	
	# Save to SettingsSystem
	if SettingsSystem:
		SettingsSystem.save_game_mode(mode_id)
	
	print("Game mode set to: %s" % mode_id)
	SignalBus.game_mode_changed.emit(mode_id)

func set_current_mode(mode_name: String):
	"""Alias for compatibility with SettingsUI"""
	set_game_mode(mode_name, {})

func _apply_mode_settings():
	"""Apply settings to game systems"""
	# Just emit a signal that settings changed
	if SignalBus.has_signal("game_settings_changed"):
		SignalBus.game_settings_changed.emit(current_mode_config)

# === NEW METHOD FOR GAMESTATE ===
func handle_round_start(round: int) -> Dictionary:
	"""Handle round start and return configuration"""
	var round_data = {
		"time_limit": get_round_time_limit(round),
		"draw_limit": get_draw_pile_limit(round),
		"combo_timeout": get_combo_timeout()
	}
	
	print("Round %d starting with config: %s" % [round, round_data])
	return round_data

# === ROUND-BASED GETTERS ===

func get_draw_pile_limit(round: int = 1) -> int:
	"""Get draw limit for specific round"""
	var base_limit = current_mode_config.get("base_draw_limit", 24)
	var decrease = current_mode_config.get("draw_limit_decrease", 0)
	var limit = base_limit - (decrease * (round - 1))
	return max(0, limit)

func get_round_time_limit(round: int = 1) -> int:
	"""Get time limit for specific round"""
	if not current_mode_config.get("timer_enabled", false):
		return 0
	
	var base_time = current_mode_config.get("base_timer", 60)
	var decrease = current_mode_config.get("timer_decrease_per_round", 0)
	var time_limit = base_time - (decrease * (round - 1))
	return max(20, time_limit)

func get_base_card_points(round: int) -> int:
	"""Get base points for cards in this round"""
	var base_points = current_mode_config.get("base_points_start", 100)
	var points_per_round = current_mode_config.get("base_points_per_round", 10)
	return base_points + (points_per_round * (round - 1))

func get_max_rounds() -> int:
	"""Get maximum rounds for current mode"""
	return current_mode_config.get("max_rounds", 10)

func should_unlock_slot(combo: int, slot_number: int) -> bool:
	"""Check if combo unlocks a slot"""
	match slot_number:
		2:
			return combo >= current_mode_config.get("slot_2_unlock", 5)
		3:
			return combo >= current_mode_config.get("slot_3_unlock", 10)
		_:
			return false

func get_combo_timeout() -> float:
	"""Get combo timeout duration"""
	return current_mode_config.get("combo_timeout", 5.0)

func should_show_timer() -> bool:
	"""Check if timer should be displayed"""
	return current_mode_config.get("timer_enabled", false)

func get_current_mode() -> String:
	return current_mode_id

func get_mode_config() -> Dictionary:
	return current_mode_config

func get_mode_display_name() -> String:
	return current_mode_config.get("display_name", "Unknown")

func is_mode_unlocked(mode_id: String) -> bool:
	"""Check if mode is unlocked"""
	match mode_id:
		"test", "classic", "timed_rush", "zen":
			return true
		"daily_challenge":
			return StatsManager.get_total_stats().games_played >= 10
		"puzzle_master":
			return false  # Premium feature
		_:
			return false

func get_all_mode_info() -> Array[Dictionary]:
	"""Get info about all modes for UI display"""
	var mode_info: Array[Dictionary] = []
	
	for mode_id in available_modes:
		var mode = available_modes[mode_id]
		mode_info.append({
			"name": mode_id,
			"display": mode.display_name,
			"description": _get_mode_description(mode_id),
			"available": is_mode_unlocked(mode_id),
			"unlock_requirement": _get_unlock_requirement(mode_id)
		})
	
	return mode_info

func _get_mode_description(mode_id: String) -> String:
	"""Get description for mode"""
	match mode_id:
		"test":
			return "Test Mode"
		"classic":
			return "Traditional pyramid solitaire"
		"timed_rush":
			return "Race against the clock!"
		"zen":
			return "Relaxed gameplay, no pressure"
		"daily_challenge":
			return "New puzzle every day"
		"puzzle_master":
			return "Handcrafted challenges"
		_:
			return ""

func _get_unlock_requirement(mode_id: String) -> String:
	"""Get unlock requirement text"""
	match mode_id:
		"daily_challenge":
			return "Play 10 games"
		"puzzle_master":
			return "Premium feature"
		_:
			return ""

# === SPECIAL MODE FUNCTIONS ===

func _setup_daily_seed():
	"""Set daily challenge seed"""
	var today = Time.get_date_dict_from_system()
	var seed_value = today.year * 10000 + today.month * 100 + today.day
	GameState.deck_seed = seed_value
	print("Daily seed: %d" % seed_value)

func _load_puzzle_deck():
	"""Load preset puzzle configuration"""
	# TODO: Load specific puzzle deck
	pass


# === CARD VISIBILITY METHODS ===

func should_card_start_face_up(card_index: int, round: int) -> bool:
	"""Determine if a card should start face up based on mode settings"""
	var visibility_mode = current_mode_config.get("card_visibility", "always")
	
	match visibility_mode:
		"always":
			return true
		"never":
			return false
		"odd_rounds":
			return round % 2 == 1  # Face up on rounds 1, 3, 5...
		"even_rounds":
			return round % 2 == 0  # Face up on rounds 2, 4, 6...
		_:
			return true  # Default to visible

func should_card_be_visible(card_index: int, round: int) -> bool:
	"""Check if a card should be visible (face up) - used for checking during play"""
	var visibility_mode = current_mode_config.get("card_visibility", "always")
	
	# If mode is "never", cards can still be revealed by clearing blockers
	if visibility_mode == "never":
		return false  # Let can_reveal_card handle it
	
	# Otherwise use same logic as start
	return should_card_start_face_up(card_index, round)

func can_reveal_card(card_index: int, blockers: Array) -> bool:
	"""Check if a card can be revealed based on blockers"""
	var visibility_mode = current_mode_config.get("card_visibility", "always")
	
	# In "never" mode, cards reveal when unblocked
	if visibility_mode == "never":
		return blockers.is_empty()
	
	# In other modes, this is only called if card isn't already visible
	return blockers.is_empty()

func get_visibility_mode(round: int) -> String:
	"""Get visibility mode for current round"""
	# Could vary by mode, but for now keep it simple
	match current_mode_id:
		"puzzle_master":
			return "progressive"  # Cards reveal as you clear
		_:
			return "all_visible"  # All cards visible from start

func get_slot_unlock_requirement(slot_number: int) -> int:
	"""Get combo requirement to unlock a slot"""
	match slot_number:
		2:
			return current_mode_config.get("slot_2_unlock", 2)
		3:
			return current_mode_config.get("slot_3_unlock", 6)
		_:
			return 0
