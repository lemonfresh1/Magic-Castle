# PlaySeedDialog.gd - Interactive dialog for starting games with custom seeds via clipboard paste
# Location: res://Pyramids/scripts/ui/popups/PlaySeedDialog.gd
# Last Updated: Added debug system, enhanced documentation, reorganized functions
#
# Purpose: Provides a user-friendly interface for playing Magic Castle Solitaire with custom seeds.
# Allows players to paste seeds from clipboard, validates them, and launches games with the selected
# seed and game mode. Includes visual feedback for successful/failed seed insertion.
#
# Dependencies:
# - GameModeManager (autoload) - Configures and manages different game modes
# - GameState (autoload) - Stores the custom seed and game configuration
# - ThemeConstants (autoload, optional) - Provides theme colors for consistent UI styling
#
# Scene Structure:
# - Root: ColorRect (backdrop that can be clicked to close)
#   - StyledPanel (main dialog container)
#     - MarginContainer
#       - VBoxContainer
#         - TitleLabel ("Play with Seed")
#         - SeedLabel (displays current seed or error)
#         - InfoLabel (shows mode and instructions)
#         - HBoxContainer (button container)
#           - PlayButton (disabled until valid seed)
#           - InsertSeedButton (pastes from clipboard)
#           - LeaveButton (closes dialog)
#
# Flow:
# 1. Dialog opens with mode already set from calling context
# 2. User clicks "Insert" button to paste seed from clipboard
# 3. System validates seed (numeric, within 32-bit range)
# 4. If valid: enables Play button, shows seed, provides visual feedback
# 5. If invalid: shows error message with red flash
# 6. Play button configures GameModeManager, sets seed in GameState, starts game
# 7. Backdrop clicks or Leave button close the dialog
#
# Seed Validation:
# - Must be numeric (non-numeric characters are stripped)
# - Must be between 1 and 4,294,967,295 (32-bit unsigned max)
# - Source is marked as "manual" for tracking purposes
#
# Note: Seeded games are always single-player mode
# See also: res://docs/Seedsystem.txt

extends ColorRect

# Debug configuration
var debug_enabled: bool = false
var global_debug: bool = false

# UI References
@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var seed_label = $StyledPanel/MarginContainer/VBoxContainer/SeedLabel
@onready var info_label = $StyledPanel/MarginContainer/VBoxContainer/InfoLabel
@onready var play_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/PlayButton
@onready var insert_seed_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/InsertSeedButton
@onready var leave_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/LeaveButton

# Signals
signal play_pressed(seed: int, mode: String)

# State
var current_seed: int = 0
var current_mode_id: String = "classic"
var current_mode_display: String = "Classic"

# === INITIALIZATION ===

func _ready():
	"""Initialize dialog UI and connections"""
	debug_log("Dialog ready, initializing UI")
	
	# Enable input on the backdrop
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_backdrop_input)
	
	# Setup labels
	if title_label:
		title_label.text = "Play with Seed"
	
	if seed_label:
		seed_label.text = "No seed selected"
		seed_label.add_theme_font_size_override("font_size", 18)
		if ThemeConstants:
			seed_label.add_theme_color_override("font_color", ThemeConstants.colors.error)
		else:
			seed_label.add_theme_color_override("font_color", Color("#ef4444"))
	
	if info_label:
		info_label.text = "Click 'Insert' to paste a seed from clipboard"
		info_label.add_theme_font_size_override("font_size", 18)
		info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
		play_button.disabled = true  # Start disabled
	
	if insert_seed_button:
		insert_seed_button.pressed.connect(_on_insert_seed_pressed)
	
	if leave_button:
		leave_button.pressed.connect(func():
			debug_log("Leave button pressed, closing dialog")
			queue_free()
		)

func setup(mode_id: String = "classic", mode_display: String = "Classic"):
	"""Setup with game mode (called from outside)"""
	debug_log("Setting up with mode: %s (%s)" % [mode_id, mode_display])
	current_mode_id = mode_id
	current_mode_display = mode_display
	
	# Update info to show current mode
	if info_label:
		info_label.text = "Mode: %s | Click 'Insert' to paste seed" % current_mode_display
		info_label.add_theme_font_size_override("font_size", 18)

# === INPUT HANDLERS ===

func _on_backdrop_input(event: InputEvent):
	"""Handle clicks on backdrop to close"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel = $StyledPanel
		if panel:
			var panel_rect = panel.get_global_rect()
			if not panel_rect.has_point(event.global_position):
				debug_log("Backdrop clicked, closing dialog")
				queue_free()

func _on_insert_seed_pressed():
	"""Paste seed from clipboard and validate"""
	var clipboard = DisplayServer.clipboard_get()
	debug_log("Insert button pressed, clipboard content: %s" % clipboard)
	
	# Clean the input - remove non-numeric characters
	var cleaned = ""
	for c in clipboard:
		if c.is_valid_int():
			cleaned += c
	
	if cleaned.length() > 0 and cleaned.is_valid_int():
		var seed_val = cleaned.to_int()
		
		# Validate seed range
		if seed_val > 0 and seed_val <= 4294967295:  # Max 32-bit unsigned
			current_seed = seed_val
			
			# Update display
			if seed_label:
				seed_label.text = "Seed: %d" % current_seed
				seed_label.add_theme_font_size_override("font_size", 18)
				if ThemeConstants:
					seed_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
				else:
					seed_label.add_theme_color_override("font_color", Color("#111827"))
			
			if info_label:
				info_label.text = "Mode: %s" % current_mode_display
				info_label.add_theme_font_size_override("font_size", 18)
				if ThemeConstants:
					info_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
				else:
					info_label.add_theme_color_override("font_color", Color("#111827"))
			
			# Enable play button
			if play_button:
				play_button.disabled = false
			
			# Visual feedback - flash green
			var panel = $StyledPanel
			if panel:
				var original_modulate = panel.modulate
				panel.modulate = Color(0.8, 1.0, 0.8)
				var tween = create_tween()
				tween.tween_property(panel, "modulate", original_modulate, 0.3)
			
			debug_log("Inserted valid seed: %d" % current_seed)
		else:
			_show_error("Invalid seed number (too large)")
	else:
		_show_error("No valid seed in clipboard")

func _on_play_pressed():
	"""Start game with the inserted seed"""
	if current_seed <= 0:
		_show_error("No seed selected")
		return
	
	debug_log("Starting game with seed: %d, mode: %s" % [current_seed, current_mode_id])
	
	# Configure the game mode
	if GameModeManager:
		GameModeManager.set_game_mode(current_mode_id, {})
		debug_log("Set game mode to: %s" % current_mode_id)
	
	# Set the custom seed with source for tracking
	if GameState:
		GameState.set_custom_seed(current_seed, "manual")  # Mark source as manual entry
		GameState.game_mode = "single"  # Seeded games are single player
		debug_log("Set custom seed: %d from manual entry" % current_seed)
	
	# Emit signal
	play_pressed.emit(current_seed, current_mode_id)
	
	# Close dialog and start game
	queue_free()
	
	# Start the game
	get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")

# === UTILITY FUNCTIONS ===

func _show_error(message: String):
	"""Show error message with visual feedback"""
	debug_log("Showing error: %s" % message)
	
	if seed_label:
		seed_label.text = "Invalid seed"
		seed_label.add_theme_font_size_override("font_size", 18)
		if ThemeConstants:
			seed_label.add_theme_color_override("font_color", ThemeConstants.colors.error)
		else:
			seed_label.add_theme_color_override("font_color", Color("#ef4444"))
	
	if info_label:
		info_label.text = message
		info_label.add_theme_font_size_override("font_size", 18)
		if ThemeConstants:
			info_label.add_theme_color_override("font_color", ThemeConstants.colors.error)
		else:
			info_label.add_theme_color_override("font_color", Color("#ef4444"))
	
	# Visual feedback - flash red
	var panel = $StyledPanel
	if panel:
		var original_modulate = panel.modulate
		panel.modulate = Color(1.0, 0.8, 0.8)
		var tween = create_tween()
		tween.tween_property(panel, "modulate", original_modulate, 0.3)

func debug_log(message: String) -> void:
	"""Debug logging with component prefix"""
	if debug_enabled and global_debug:
		print("[PLAYSEEDDIALOG] %s" % message)
