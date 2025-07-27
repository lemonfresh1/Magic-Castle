# SettingsMenu.gd - Updated with correct paths
# Path: res://Magic-Castle/scripts/ui/menus/SettingsMenu.gd
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

# Card Skin Section
@onready var card_skin_section: Panel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CardSkinSection
@onready var card_left_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/LeftButton
@onready var card_preview_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/PreviewContainer
@onready var card_right_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/RightButton
@onready var card_skin_name: Label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CardSkinSection/MarginContainer/VBoxContainer/ModeSelector/SkinName
@onready var high_contrast_check: CheckButton = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HighContrastCheck

# Board Skin Section
@onready var board_skin_section: Panel = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BoardSkinSection
@onready var board_left_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BoardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/LeftButton
@onready var board_preview_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BoardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/PreviewContainer
@onready var board_right_button: Button = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BoardSkinSection/MarginContainer/VBoxContainer/ModeSelector/HBoxContainer/RightButton
@onready var board_skin_name: Label = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BoardSkinSection/MarginContainer/VBoxContainer/ModeSelector/SkinName

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

# Available options
var available_modes: Array[Dictionary] = [
	{"name": "tri_peaks", "display": "Tri-Peaks", "description": "Classic tri-peaks solitaire", "available": true},
	{"name": "time_rush", "display": "Time Rush", "description": "Race against time!", "available": false},
	{"name": "quicky", "display": "Quicky", "description": "Quick 5-minute games", "available": false}
]

var available_card_skins: Array[Dictionary] = [
	{"name": "default", "display": "Classic", "has_contrast": false},
	{"name": "classic_code", "display": "Classic HD", "has_contrast": true},
	{"name": "modern", "display": "Modern", "has_contrast": false}
]

var available_board_skins: Array[Dictionary] = [
	{"name": "green", "display": "Classic Green"},
	{"name": "blue", "display": "Ocean Blue"},
	{"name": "sunset", "display": "Sunset"}
]

var current_mode_index: int = 0
var current_card_skin_index: int = 0
var current_board_skin_index: int = 0

signal settings_closed

func _ready() -> void:
	# Set up container properties
	_setup_containers()
	
	# Connect all signals
	_connect_controls()
	
	# Load current settings
	_load_current_settings()

func _setup_containers() -> void:
	# Ensure scroll container is set up properly
	scroll_container.custom_minimum_size.y = 300
	
	# Set minimum heights for each section
	if game_mode_section:
		game_mode_section.custom_minimum_size.y = 150
	if card_skin_section:
		card_skin_section.custom_minimum_size.y = 180
	if board_skin_section:
		board_skin_section.custom_minimum_size.y = 120
	if audio_section:
		audio_section.custom_minimum_size.y = 220
	if input_section:
		input_section.custom_minimum_size.y = 120
	
	# Add separation between sections
	sections_container.add_theme_constant_override("separation", 15)

func _connect_controls() -> void:
	# Back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Game mode controls
	if mode_left_button:
		mode_left_button.pressed.connect(_on_mode_left)
	if mode_right_button:
		mode_right_button.pressed.connect(_on_mode_right)
	
	# Card skin controls
	if card_left_button:
		card_left_button.pressed.connect(_on_card_skin_left)
	if card_right_button:
		card_right_button.pressed.connect(_on_card_skin_right)
	if high_contrast_check:
		high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	
	# Board skin controls
	if board_left_button:
		board_left_button.pressed.connect(_on_board_skin_left)
	if board_right_button:
		board_right_button.pressed.connect(_on_board_skin_right)
	
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
		left_button.pressed.connect(func(): _on_input_mode_selected(SettingsSystem.DrawPileMode.LEFT_ONLY))
	if right_button:
		right_button.pressed.connect(func(): _on_input_mode_selected(SettingsSystem.DrawPileMode.RIGHT_ONLY))
	if both_button:
		both_button.pressed.connect(func(): _on_input_mode_selected(SettingsSystem.DrawPileMode.BOTH_SIDES))

func _load_current_settings() -> void:
	# Load game mode
	for i in range(available_modes.size()):
		if available_modes[i].name == SettingsSystem.current_game_mode:
			current_mode_index = i
			break
	_update_mode_display()
	
	# Load card skin
	for i in range(available_card_skins.size()):
		if available_card_skins[i].name == SettingsSystem.current_card_skin:
			current_card_skin_index = i
			break
	_update_card_skin_display()
	
	# Load board skin
	for i in range(available_board_skins.size()):
		if available_board_skins[i].name == SettingsSystem.current_board_skin:
			current_board_skin_index = i
			break
	_update_board_skin_display()
	
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
	
	# Grey out if unavailable
	mode_label.modulate = Color.WHITE if mode.available else Color(0.5, 0.5, 0.5)
	mode_description.modulate = Color.WHITE if mode.available else Color(0.5, 0.5, 0.5)

func _on_mode_left() -> void:
	current_mode_index = wrapi(current_mode_index - 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		SettingsSystem.set_game_mode(available_modes[current_mode_index].name)

func _on_mode_right() -> void:
	current_mode_index = wrapi(current_mode_index + 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		SettingsSystem.set_game_mode(available_modes[current_mode_index].name)

# === CARD SKIN ===
func _update_card_skin_display() -> void:
	if not card_skin_name:
		return
		
	var skin = available_card_skins[current_card_skin_index]
	card_skin_name.text = skin.display
	
	# Show/hide contrast checkbox
	if high_contrast_check:
		high_contrast_check.visible = skin.has_contrast
		if skin.has_contrast:
			high_contrast_check.button_pressed = SettingsSystem.high_contrast
	
	# TODO: Update card previews when implemented
	
	SettingsSystem.set_card_skin(skin.name)

func _on_card_skin_left() -> void:
	current_card_skin_index = wrapi(current_card_skin_index - 1, 0, available_card_skins.size())
	_update_card_skin_display()

func _on_card_skin_right() -> void:
	current_card_skin_index = wrapi(current_card_skin_index + 1, 0, available_card_skins.size())
	_update_card_skin_display()

func _on_high_contrast_toggled(pressed: bool) -> void:
	SettingsSystem.high_contrast = pressed
	SettingsSystem.save_settings()
	# TODO: Update card previews

# === BOARD SKIN ===
func _update_board_skin_display() -> void:
	if not board_skin_name:
		return
		
	var skin = available_board_skins[current_board_skin_index]
	board_skin_name.text = skin.display
	SettingsSystem.set_board_skin(skin.name)

func _on_board_skin_left() -> void:
	current_board_skin_index = wrapi(current_board_skin_index - 1, 0, available_board_skins.size())
	_update_board_skin_display()

func _on_board_skin_right() -> void:
	current_board_skin_index = wrapi(current_board_skin_index + 1, 0, available_board_skins.size())
	_update_board_skin_display()

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
	if sfx_label:
		sfx_label.text = "%d%%" % int(sfx_slider.value)
	if music_label:
		music_label.text = "%d%%" % int(music_slider.value)

# === INPUT ===
func _update_input_buttons() -> void:
	match SettingsSystem.draw_pile_mode:
		SettingsSystem.DrawPileMode.LEFT_ONLY:
			if left_button: left_button.button_pressed = true
			if right_button: right_button.button_pressed = false
			if both_button: both_button.button_pressed = false
		SettingsSystem.DrawPileMode.RIGHT_ONLY:
			if left_button: left_button.button_pressed = false
			if right_button: right_button.button_pressed = true
			if both_button: both_button.button_pressed = false
		SettingsSystem.DrawPileMode.BOTH_SIDES:
			if left_button: left_button.button_pressed = false
			if right_button: right_button.button_pressed = false
			if both_button: both_button.button_pressed = true

func _on_input_mode_selected(mode: SettingsSystem.DrawPileMode) -> void:
	SettingsSystem.set_draw_pile_mode(mode)
	_update_input_buttons()

# === NAVIGATION ===
func _on_back_pressed() -> void:
	settings_closed.emit()
