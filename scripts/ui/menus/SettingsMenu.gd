# SettingsMenu.gd - Settings interface for game preferences
# Location: res://Pyramids/scripts/ui/menus/SettingsMenu.gd
# Last Updated: Removed cosmetics management - now in Profile/Inventory
#
# SettingsMenu handles:
# - Game mode selection through GameModeManager
# - Audio settings (SFX, music, error/success sounds)
# - Draw zone position preferences
# - Links to Profile for cosmetic changes
#
# Flow: User input → SettingsMenu → SettingsSystem/Managers → Apply changes
# Dependencies: GameModeManager (modes), DrawZoneManager (zones), SettingsSystem (preferences)

extends Control

# Main structure
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/Header/BackButton
@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var sections_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer

# Game Mode Section
@onready var game_mode_section: Panel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GameModeSection
@onready var mode_left_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GameModeSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/LeftButton
@onready var mode_label: Label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GameModeSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/ModeLabel
@onready var mode_right_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GameModeSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/RightButton
@onready var mode_description: Label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GameModeSection/MarginContainer/VBoxContainer/ModeSelector/DescriptionLabel

# Audio Section
@onready var audio_section: Panel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection
@onready var error_sound_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection/MarginContainer/VBoxContainer/ErrorSoundToggle
@onready var success_sound_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection/MarginContainer/VBoxContainer/SuccessSoundToggle
@onready var sfx_slider: HSlider = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection/MarginContainer/VBoxContainer/SFXContainer/HBoxContainer/Slider
@onready var sfx_label: Label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection/MarginContainer/VBoxContainer/SFXContainer/HBoxContainer/ValueLabel
@onready var music_slider: HSlider = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection/MarginContainer/VBoxContainer/MusicContainer/HBoxContainer/Slider
@onready var music_label: Label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AudioSection/MarginContainer/VBoxContainer/MusicContainer/HBoxContainer/ValueLabel

# Input Section
@onready var input_section: Panel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection
@onready var left_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/MarginContainer/VBoxContainer/HBoxContainer/LeftButton
@onready var right_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/MarginContainer/VBoxContainer/HBoxContainer/RightButton
@onready var both_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/MarginContainer/VBoxContainer/HBoxContainer/BothButton

# Cosmetics Info Section (new - just informational)
@onready var cosmetics_info_section: Panel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CosmeticsInfoSection

# Available game modes
var available_modes: Array[Dictionary] = []
var current_mode_index: int = 0

signal settings_closed

func _ready() -> void:
	# Get available modes from GameModeManager
	available_modes = GameModeManager.get_all_mode_info()
	
	# Remove old card/board sections if they exist in the scene
	_remove_cosmetic_sections()
	
	# Add info section about cosmetics
	_create_cosmetics_info()
	
	# Connect controls
	_connect_controls()	
	_setup_button_groups()
	_load_current_settings()

func _remove_cosmetic_sections() -> void:
	"""Remove card and board skin sections if they exist in the scene"""
	# Find and remove card skin section
	var card_section = sections_container.get_node_or_null("CardSkinSection")
	if card_section:
		card_section.queue_free()
	
	# Find and remove board skin section
	var board_section = sections_container.get_node_or_null("BoardSkinSection")
	if board_section:
		board_section.queue_free()

func _create_cosmetics_info() -> void:
	"""Create an info section directing users to Profile for cosmetics"""
	if cosmetics_info_section:
		return  # Already exists in scene
	
	# Create new info panel
	var info_panel = Panel.new()
	info_panel.name = "CosmeticsInfoSection"
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Customize Appearance"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title)
	
	# Info text
	var info = Label.new()
	info.text = "Card skins, board backgrounds, and other cosmetics can be changed in your Profile → Inventory"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(info)
	
	# Note: Profile button removed to avoid coupling issues
	# Users can access Profile from the main menu
	
	# Add to sections container
	if sections_container:
		sections_container.add_child(info_panel)

func _connect_controls() -> void:
	# Back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Game mode controls
	if mode_left_button:
		mode_left_button.pressed.connect(_on_mode_left)
	if mode_right_button:
		mode_right_button.pressed.connect(_on_mode_right)
	
	# Audio controls
	if error_sound_toggle:
		error_sound_toggle.toggled.connect(_on_error_sound_toggled)
	if success_sound_toggle:
		success_sound_toggle.toggled.connect(_on_success_sound_toggled)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)
	
	# Input controls
	if left_button:
		left_button.toggled.connect(func(pressed): 
			if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.LEFT_ONLY))
	if right_button:
		right_button.toggled.connect(func(pressed): 
			if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.RIGHT_ONLY))
	if both_button:
		both_button.toggled.connect(func(pressed): 
			if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.BOTH_SIDES))

func _setup_button_groups() -> void:
	"""Setup button groups for radio button behavior"""
	# Create button group for input mode buttons
	var input_button_group = ButtonGroup.new()
	
	if left_button:
		left_button.button_group = input_button_group
		left_button.toggle_mode = true
	
	if right_button:
		right_button.button_group = input_button_group
		right_button.toggle_mode = true
	
	if both_button:
		both_button.button_group = input_button_group
		both_button.toggle_mode = true

func _load_current_settings() -> void:
	# Load game mode
	var current_mode_name = GameModeManager.get_current_mode() if GameModeManager.get_current_mode() else "classic"
	for i in range(available_modes.size()):
		if available_modes[i].name == current_mode_name:
			current_mode_index = i
			break
	_update_mode_display()
	
	# Load audio settings
	if error_sound_toggle:
		error_sound_toggle.button_pressed = SettingsSystem.error_sounds_enabled
	if success_sound_toggle:
		success_sound_toggle.button_pressed = SettingsSystem.success_sounds_enabled
	if sfx_slider:
		sfx_slider.value = SettingsSystem.sfx_volume * 100
	if music_slider:
		music_slider.value = SettingsSystem.music_volume * 100
	_update_volume_labels()
	
	# Load input mode
	_update_input_buttons()

# === GAME MODE ===
func _update_mode_display() -> void:
	if not mode_label or not mode_description:
		return
		
	var mode = available_modes[current_mode_index]
	mode_label.text = mode.display
	mode_description.text = mode.description
	
	# Show lock status if unavailable
	if not mode.available:
		mode_description.text += "\n[Locked: %s]" % mode.unlock_requirement
		mode_label.modulate = Color(0.5, 0.5, 0.5)
		mode_description.modulate = Color(0.5, 0.5, 0.5)
	else:
		mode_label.modulate = Color.WHITE
		mode_description.modulate = Color.WHITE

func _on_mode_left() -> void:
	current_mode_index = wrapi(current_mode_index - 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		var mode_name = available_modes[current_mode_index].name
		GameModeManager.set_current_mode(mode_name)
		SettingsSystem.set_game_mode(mode_name)

func _on_mode_right() -> void:
	current_mode_index = wrapi(current_mode_index + 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		var mode_name = available_modes[current_mode_index].name
		GameModeManager.set_current_mode(mode_name)
		SettingsSystem.set_game_mode(mode_name)

# === AUDIO ===
func _on_error_sound_toggled(pressed: bool) -> void:
	SettingsSystem.error_sounds_enabled = pressed
	SettingsSystem.save_settings()

func _on_success_sound_toggled(pressed: bool) -> void:
	SettingsSystem.success_sounds_enabled = pressed
	SettingsSystem.save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	SettingsSystem.set_sfx_volume(value / 100.0)
	_update_volume_labels()

func _on_music_volume_changed(value: float) -> void:
	SettingsSystem.set_music_volume(value / 100.0)
	_update_volume_labels()

func _update_volume_labels() -> void:
	if sfx_label and sfx_slider:
		sfx_label.text = "%d%%" % int(sfx_slider.value)
	if music_label and music_slider:
		music_label.text = "%d%%" % int(music_slider.value)

# === INPUT ===
func _update_input_buttons() -> void:
	"""Update draw zone buttons based on current settings"""
	var draw_mode = DrawZoneManager.get_draw_mode()
	
	match draw_mode:
		DrawZoneManager.DrawZoneMode.LEFT_ONLY:
			if left_button: left_button.button_pressed = true
		DrawZoneManager.DrawZoneMode.RIGHT_ONLY:
			if right_button: right_button.button_pressed = true
		DrawZoneManager.DrawZoneMode.BOTH:
			if both_button: both_button.button_pressed = true

func _on_input_mode_selected(mode: SettingsSystem.DrawPileMode) -> void:
	"""Handle draw zone mode selection"""
	SettingsSystem.set_draw_pile_mode(mode)
	_update_input_buttons()

# === NAVIGATION ===
func _on_back_pressed() -> void:
	settings_closed.emit()

# === DEBUG ===
func debug_print_settings() -> void:
	"""Print current settings for debugging"""
	print("\n=== SETTINGS MENU DEBUG ===")
	print("Game Mode: %s" % available_modes[current_mode_index].name)
	print("Draw Zone Mode: %s" % DrawZoneManager.get_draw_mode())
	print("Audio - SFX: %.1f, Music: %.1f" % [SettingsSystem.sfx_volume, SettingsSystem.music_volume])
	print("Error Sounds: %s, Success Sounds: %s" % [
		SettingsSystem.error_sounds_enabled,
		SettingsSystem.success_sounds_enabled
	])
	print("===========================\n")
