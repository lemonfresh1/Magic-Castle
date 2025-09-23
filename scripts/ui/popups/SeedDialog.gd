# SeedDialog.gd - Seed display and action dialog for leaderboard entries
# Location: res://Pyramids/scripts/ui/popups/SeedDialog.gd
# Last Updated: Added debug system and reorganized functions
#
# Purpose: Displays seed information from leaderboard entries and provides actions
# to either play with that seed or copy it to clipboard for sharing.
#
# Dependencies:
# - GameModeManager (autoload) - Sets the game mode before playing
# - GameState (autoload) - Manages custom seed storage and game initialization
# - ThemeConstants (autoload) - Color definitions for UI
#
# Scene Structure:
# - Root: ColorRect (backdrop for click-to-close)
# - StyledPanel containing the dialog content
# - Buttons for Play, Copy, and Leave actions
#
# Flow:
# 1. Receives score data from leaderboard containing seed and mode
# 2. Displays seed information in dialog
# 3. Play button → Sets custom seed as "leaderboard" source → Starts seeded game
# 4. Copy button → Copies seed to clipboard for sharing → Auto-closes
# 5. Seeded games are marked and excluded from global leaderboard
#
# Documentation: res://docs/Seedsystem.txt

extends ColorRect

# === NODE REFERENCES ===
@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var play_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/PlayButton
@onready var copy_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/CopyButton
@onready var leave_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/LeaveButton

# === SIGNALS ===
signal confirmed
signal play_pressed(seed: int, mode: String)
signal copy_pressed(seed: int)

# === STATE ===
var seed_value: int = 0
var score_data: Dictionary = {}  # Store the full score data

# === DEBUG ===
var debug_enabled: bool = false
var global_debug: bool = false

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[SEEDDIALOG] %s" % message)

# === INITIALIZATION ===
func _ready():
	# Enable input on the backdrop
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_backdrop_input)
	
	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	
	if copy_button:
		copy_button.pressed.connect(_on_copy_pressed)
	
	if leave_button:
		leave_button.pressed.connect(func():
			queue_free()
		)

# === SETUP ===
func setup(data: Dictionary):
	"""Setup with full score data dictionary"""
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	# Store the full data
	score_data = data
	seed_value = data.get("seed", 0)
	
	# Set title with seed number and optionally player name
	if title_label:
		var player_name = data.get("player_name", "")
		if player_name:
			title_label.text = "Seed: %d (%s)" % [seed_value, player_name]
		else:
			title_label.text = "Seed: %d" % seed_value
	
	_debug_log("Setup with seed: %d, player: %s" % [seed_value, data.get("player_name", "Unknown")])

func setup_simple(seed: int, player_name: String = ""):
	"""Legacy setup for backward compatibility"""
	setup({
		"seed": seed,
		"player_name": player_name,
		"mode": "classic"  # Default to classic if not specified
	})

# === INPUT HANDLERS ===
func _on_backdrop_input(event: InputEvent):
	"""Handle clicks on backdrop to close"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click was on backdrop (not on panel)
		var panel = $StyledPanel
		if panel:
			var panel_rect = panel.get_global_rect()
			if not panel_rect.has_point(event.global_position):
				queue_free()

# === BUTTON HANDLERS ===
func _on_play_pressed():
	"""Handle play button - directly start game with seed"""
	if seed_value > 0:
		_debug_log("Starting game with seed: %d" % seed_value)
		
		# Get mode from the score data (might not exist if old data)
		var mode_id = score_data.get("mode", "")
		
		# If no mode in score data, try to detect from current game state
		if mode_id == "":
			# Check if we're in solo or multiplayer context
			var is_solo = score_data.get("game_type", "") == "solo"
			
			# Try to get current mode from GameModeManager or default to classic
			if GameModeManager:
				mode_id = GameModeManager.get_current_mode()
			else:
				mode_id = "classic"
			
			_debug_log("No mode in score data, using: %s" % mode_id)
		
		# Configure the game mode
		if GameModeManager:
			GameModeManager.set_game_mode(mode_id, {})
			_debug_log("Set game mode to: %s" % mode_id)
		
		# Set the custom seed with source for tracking
		if GameState:
			GameState.set_custom_seed(seed_value, "leaderboard")  # Mark source as leaderboard
			GameState.game_mode = "single"  # Seeded games are single player
			_debug_log("Set custom seed: %d from leaderboard" % seed_value)
		
		# Emit signal
		play_pressed.emit(seed_value, mode_id)
		
		# Close dialog and start game
		queue_free()
		
		# Start the game
		get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")

func _on_copy_pressed():
	"""Handle copy button - copies seed to clipboard"""
	if seed_value > 0:
		_debug_log("Copy pressed - seed: %d" % seed_value)
		DisplayServer.clipboard_set(str(seed_value))
		copy_pressed.emit(seed_value)
		
		# Update title to show copied
		if title_label:
			title_label.text = "Seed %d Copied!" % seed_value
		
		# Auto-close after a short delay
		await get_tree().create_timer(0.8).timeout
		queue_free()
	else:
		_debug_log("No valid seed to copy")
		if title_label:
			title_label.text = "No Seed Available"

# === HELPERS ===
func _get_mode_display_name(mode_id: String) -> String:
	"""Convert mode ID to display name"""
	match mode_id:
		"classic": return "Classic"
		"timed_rush", "rush": return "Rush"
		"test": return "Test"
		_: return "Classic"
