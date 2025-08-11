# GameModeManager.gd - Autoload for managing game modes
# Path: res://Pyramids/scripts/autoloads/GameModeManager.gd
extends Node

# === AVAILABLE GAME MODES ===
var available_modes: Dictionary = {}
var current_mode: GameModeBase = null

func _ready() -> void:
	print("GameModeManager initializing...")
	_register_game_modes()
	_load_current_mode()
	print("GameModeManager ready with %d modes" % available_modes.size())

func _register_game_modes() -> void:
	# Register all available game modes
	var tri_peaks = TriPeaksMode.new()
	available_modes[tri_peaks.mode_name] = tri_peaks
	
	# Register Rush mode
	var rush = RushMode.new()
	available_modes[rush.mode_name] = rush
	
	# Register Chill mode
	var chill = ChillMode.new()
	available_modes[chill.mode_name] = chill
	
	# Register Test mode
	var test = TestMode.new()
	available_modes[test.mode_name] = test
	
	print("Registered game modes: %s" % str(available_modes.keys()))

func _load_current_mode() -> void:
	var mode_name = SettingsSystem.current_game_mode
	if available_modes.has(mode_name):
		current_mode = available_modes[mode_name]
		print("Loaded mode from settings: %s" % mode_name)
	else:
		# Default to tri-peaks
		current_mode = available_modes["tri_peaks"]
		SettingsSystem.set_game_mode("tri_peaks")
	
	print("Current game mode: %s" % current_mode.display_name)

# === MODE MANAGEMENT ===
func set_current_mode(mode_name: String) -> bool:
	if not available_modes.has(mode_name):
		print("Game mode not found: %s" % mode_name)
		return false
	
	current_mode = available_modes[mode_name]
	SettingsSystem.set_game_mode(mode_name)
	print("Switched to game mode: %s" % current_mode.display_name)
	return true

func get_current_mode() -> GameModeBase:
	return current_mode

func get_available_modes() -> Array[GameModeBase]:
	var modes: Array[GameModeBase] = []
	for mode in available_modes.values():
		modes.append(mode)
	return modes

# === GAME RULE QUERIES ===
func get_board_card_count() -> int:
	return current_mode.board_card_count if current_mode else 28

func get_max_rounds() -> int:
	return current_mode.max_rounds if current_mode else 10

func get_round_time_limit(round: int) -> int:
	if not current_mode:
		return 60
		
	# Handle special cases for each mode
	if current_mode.mode_name == "chill":
		return 0  # No timer in chill mode
	elif current_mode.mode_name == "rush":
		# Rush mode uses specific times from on_round_start
		var round_data = current_mode.on_round_start(round)
		return round_data.get("time_limit", 50)
	else:
		# Standard calculation
		return current_mode.starting_time - (current_mode.time_decrease_per_round * (round - 1))

func get_draw_pile_limit(round: int) -> int:
	return current_mode.get_draw_pile_limit(round) if current_mode else 21

func get_base_card_points(round: int) -> int:
	return current_mode.get_base_card_points(round) if current_mode else 100

func get_visibility_mode(round: int) -> String:
	return current_mode.get_round_visibility_mode(round) if current_mode else "all_visible"

func should_unlock_slot(combo: int, slot_number: int) -> bool:
	return current_mode.should_unlock_slot(combo, slot_number) if current_mode else false

func is_valid_card_selection(card_data: CardData, slot_cards: Array[CardData]) -> bool:
	return current_mode.is_valid_card_selection(card_data, slot_cards) if current_mode else false

# === GAME EVENT HANDLERS ===
func handle_round_start(round_number: int) -> Dictionary:
	return current_mode.on_round_start(round_number) if current_mode else {}

func handle_card_played(card_data: CardData, combo_count: int) -> Dictionary:
	return current_mode.on_card_played(card_data, combo_count) if current_mode else {}

func handle_round_end(round_number: int, board_cleared: bool) -> Dictionary:
	return current_mode.on_round_end(round_number, board_cleared) if current_mode else {}

func get_all_mode_info() -> Array[Dictionary]:
	"""Returns info about all modes for the settings menu"""
	var mode_info: Array[Dictionary] = []
	
	# Tri-Peaks (available)
	mode_info.append({
		"name": "tri_peaks",
		"display": "Tri-Peaks",
		"description": "Classic tri-peaks solitaire with combos",
		"available": true,
		"unlock_requirement": ""
	})
	
	# Rush (locked initially)
	mode_info.append({
		"name": "rush",
		"display": "Rush",
		"description": "5 fast rounds with aggressive timing",
		"available": is_mode_unlocked("rush"),
		"unlock_requirement": "Complete 5 games"
	})
	
	# Chill (locked initially)
	mode_info.append({
		"name": "chill",
		"display": "Chill",
		"description": "No time pressure, extended combos",
		"available": is_mode_unlocked("chill"),
		"unlock_requirement": "Reach combo 15"
	})
	
	# Test mode (always available)
	mode_info.append({
		"name": "test",
		"display": "Test Mode",
		"description": "2 rounds for quick testing",
		"available": true,  # Always available
		"unlock_requirement": ""
	})
	
	return mode_info

func is_mode_unlocked(mode_name: String) -> bool:
	# Check unlock conditions based on SettingsSystem stats
	match mode_name:
		"tri_peaks":
			return true
		"test":
			return true  # Always unlocked for testing
		"rush":
			# Unlock after 5 completed games
			return SettingsSystem.total_games_played >= 5
		"chill":
			# Unlock after reaching combo 15
			return SettingsSystem.highest_combo >= 15
		_:
			return false

# === COMBO TIMEOUT ===
func get_combo_timeout() -> float:
	# Get combo timeout from current mode's round data
	if current_mode and current_mode.mode_name == "chill":
		return 720.0  # 12 minutes for chill mode
	else:
		return 5.0  # Default 5 seconds for other modes

# === UI HELPERS ===
func should_show_timer() -> bool:
	# Hide timer in chill mode
	return current_mode.mode_name != "chill" if current_mode else true

func get_score_multiplier_display() -> String:
	# For UI display of mode multiplier
	match current_mode.mode_name:
		"rush":
			return "1.5x"
		"chill":
			return "1.0x"
		_:
			return "1.0x"
