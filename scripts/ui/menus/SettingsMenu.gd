# SettingsMenu.gd
extends Control

# Section References
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/Header/BackButton
@onready var sections_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Sections

# Game Mode Section
@onready var game_mode_section: Panel = $Panel/MarginContainer/VBoxContainer/Sections/GameModeSection
@onready var mode_left_button: Button = $Panel/MarginContainer/VBoxContainer/Sections/GameModeSection/ModeSelector/HBoxContainer/LeftButton
@onready var mode_label: Label = $Panel/MarginContainer/VBoxContainer/Sections/GameModeSection/ModeSelector/HBoxContainer/ModeLabel
@onready var mode_right_button: Button = $Panel/MarginContainer/VBoxContainer/Sections/GameModeSection/ModeSelector/HBoxContainer/RightButton
@onready var mode_description: Label = $Panel/MarginContainer/VBoxContainer/Sections/GameModeSection/ModeSelector/DescriptionLabel

# Card Skin Section
@onready var card_skin_section: Panel = $Panel/MarginContainer/VBoxContainer/Sections/CardSkinSection
@onready var card_preview: Control = $Panel/MarginContainer/VBoxContainer/Sections/CardSkinSection/SkinSelector/PreviewContainer/CardPreview
@onready var card_skin_name: Label = $Panel/MarginContainer/VBoxContainer/Sections/CardSkinSection/SkinSelector/SkinName
@onready var high_contrast_check: CheckBox = $Panel/MarginContainer/VBoxContainer/Sections/CardSkinSection/SkinSelector/HighContrastCheck

# Audio Section
@onready var error_sound_toggle: CheckBox = $Panel/MarginContainer/VBoxContainer/Sections/AudioSection/ErrorSoundToggle
@onready var success_sound_toggle: CheckBox = $Panel/MarginContainer/VBoxContainer/Sections/AudioSection/SuccessSoundToggle
@onready var sfx_volume_slider: HSlider = $Panel/MarginContainer/VBoxContainer/Sections/AudioSection/SFXVolume/Slider
@onready var music_volume_slider: HSlider = $Panel/MarginContainer/VBoxContainer/Sections/AudioSection/MusicVolume/Slider

# Input Section
@onready var input_left_only: Button = $Panel/MarginContainer/VBoxContainer/Sections/InputSection/Options/LeftOnly
@onready var input_right_only: Button = $Panel/MarginContainer/VBoxContainer/Sections/InputSection/Options/RightOnly
@onready var input_both: Button = $Panel/MarginContainer/VBoxContainer/Sections/InputSection/Options/Both

# Available modes (including placeholders)
var available_modes: Array[Dictionary] = [
	{"name": "tri_peaks", "display": "Tri-Peaks", "description": "Classic tri-peaks solitaire", "available": true},
	{"name": "time_rush", "display": "Time Rush", "description": "Race against time!", "available": false},
	{"name": "quicky", "display": "Quicky", "description": "Quick 5-minute games", "available": false}
]
var current_mode_index: int = 0

# Available card skins
var available_card_skins: Array[Dictionary] = [
	{"name": "default", "display": "Classic", "has_contrast": true},
	{"name": "modern", "display": "Modern", "has_contrast": false},
	{"name": "retro", "display": "Retro", "has_contrast": true}
]
var current_skin_index: int = 0

signal settings_closed

func _ready() -> void:
	_connect_controls()
	_load_current_settings()

func _connect_controls() -> void:
	back_button.pressed.connect(_on_back_pressed)
	
	# Game mode
	mode_left_button.pressed.connect(_on_mode_left)
	mode_right_button.pressed.connect(_on_mode_right)
	
	# Card skin
	# Add card skin navigation connections
	
	# Audio
	error_sound_toggle.toggled.connect(_on_error_sound_toggled)
	success_sound_toggle.toggled.connect(_on_success_sound_toggled)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	
	# Input
	input_left_only.pressed.connect(func(): _on_input_mode_selected(SettingsSystem.DrawPileMode.LEFT_ONLY))
	input_right_only.pressed.connect(func(): _on_input_mode_selected(SettingsSystem.DrawPileMode.RIGHT_ONLY))
	input_both.pressed.connect(func(): _on_input_mode_selected(SettingsSystem.DrawPileMode.BOTH_SIDES))

func _load_current_settings() -> void:
	# Find current mode
	for i in range(available_modes.size()):
		if available_modes[i].name == SettingsSystem.current_game_mode:
			current_mode_index = i
			break
	_update_mode_display()
	
	# Load audio settings
	error_sound_toggle.button_pressed = SettingsSystem.sound_enabled
	success_sound_toggle.button_pressed = SettingsSystem.sound_enabled
	
	# Load input mode
	match SettingsSystem.draw_pile_mode:
		SettingsSystem.DrawPileMode.LEFT_ONLY:
			input_left_only.button_pressed = true
		SettingsSystem.DrawPileMode.RIGHT_ONLY:
			input_right_only.button_pressed = true
		SettingsSystem.DrawPileMode.BOTH_SIDES:
			input_both.button_pressed = true

func _update_mode_display() -> void:
	var mode = available_modes[current_mode_index]
	mode_label.text = mode.display
	mode_description.text = mode.description
	
	# Grey out if unavailable
	mode_label.modulate = Color.WHITE if mode.available else Color(0.5, 0.5, 0.5)
	mode_description.modulate = Color.WHITE if mode.available else Color(0.5, 0.5, 0.5)

func _on_mode_left() -> void:
	current_mode_index = wrapi(current_mode_index - 1, 0, available_modes.size())
	_update_mode_display()
	
	# Only save if mode is available
	if available_modes[current_mode_index].available:
		SettingsSystem.set_game_mode(available_modes[current_mode_index].name)

func _on_mode_right() -> void:
	current_mode_index = wrapi(current_mode_index + 1, 0, available_modes.size())
	_update_mode_display()
	
	# Only save if mode is available
	if available_modes[current_mode_index].available:
		SettingsSystem.set_game_mode(available_modes[current_mode_index].name)

func _on_error_sound_toggled(pressed: bool) -> void:
	SettingsSystem.set_sound_enabled(pressed)

func _on_success_sound_toggled(pressed: bool) -> void:
	SettingsSystem.set_sound_enabled(pressed)

func _on_sfx_volume_changed(value: float) -> void:
	# Store in SettingsSystem when you add volume support
	pass

func _on_music_volume_changed(value: float) -> void:
	# Store in SettingsSystem when you add volume support
	pass

func _on_input_mode_selected(mode: SettingsSystem.DrawPileMode) -> void:
	SettingsSystem.set_draw_pile_mode(mode)

func _on_back_pressed() -> void:
	settings_closed.emit()
