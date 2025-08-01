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
var available_modes: Array[Dictionary] = []

var available_card_skins: Array[Dictionary] = [
	{"name": "sprites", "display": "Classic", "has_contrast": false},  # Sprite-based
	{"name": "classic", "display": "Classic HD", "has_contrast": true},  # Programmatic
	{"name": "modern", "display": "Modern", "has_contrast": false},
	{"name": "retro", "display": "Retro", "has_contrast": true}
]

var available_board_skins: Array[Dictionary] = [
	{"name": "classic", "display": "Classic Green"},  # This will use classic-bg.png
	{"name": "green", "display": "Green Felt"},      # Color-only version
	{"name": "blue", "display": "Ocean Blue"},
	{"name": "sunset", "display": "Sunset"}
]

var current_mode_index: int = 0
var current_card_skin_index: int = 0
var current_board_skin_index: int = 0
var board_preview_instance: Panel = null


signal settings_closed

func _ready() -> void:
	available_modes = GameModeManager.get_all_mode_info()
	_connect_controls()	
	_setup_button_groups()
	_load_current_settings()
	_create_card_previews()
	_create_board_preview()
	
	# After everything is created, manually adjust panel sizes
	await get_tree().process_frame
	
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
		left_button.toggled.connect(func(pressed): 
			if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.LEFT_ONLY))
	if right_button:
		right_button.toggled.connect(func(pressed): 
			if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.RIGHT_ONLY))
	if both_button:
		both_button.toggled.connect(func(pressed): 
			if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.BOTH_SIDES))

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
		var mode_name = available_modes[current_mode_index].name
		GameModeManager.set_current_mode(mode_name)  # Add this line!
		SettingsSystem.set_game_mode(mode_name)

func _on_mode_right() -> void:
	current_mode_index = wrapi(current_mode_index + 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		var mode_name = available_modes[current_mode_index].name
		GameModeManager.set_current_mode(mode_name)  # Add this line!
		SettingsSystem.set_game_mode(mode_name)

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
	
	for card in card_preview_container.get_children():
		if card.has_method("set_skin"):
			card.set_skin(available_card_skins[current_card_skin_index].name, SettingsSystem.high_contrast)
	
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
	
	# Update preview cards
	if card_preview_container:
		for card in card_preview_container.get_children():
			if card.has_method("set_skin"):
				card.is_high_contrast = pressed
				card._update_display()

# === BOARD SKIN ===
func _update_board_skin_display() -> void:
	if not board_skin_name:
		return
		
	var skin = available_board_skins[current_board_skin_index]
	board_skin_name.text = skin.display
	
	if board_preview_instance and board_preview_instance.has_method("set_skin"):
		board_preview_instance.set_skin(skin.name)  # Use skin.name instead
		
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

func _create_card_previews() -> void:
	if not card_preview_container:
		return
		
	# Clear existing
	for child in card_preview_container.get_children():
		child.queue_free()
	
	# Create preview cards
	var preview_cards = [
		{"rank": 1, "suit": CardData.Suit.HEARTS},
		{"rank": 13, "suit": CardData.Suit.SPADES},
		{"rank": 12, "suit": CardData.Suit.DIAMONDS},
		{"rank": 11, "suit": CardData.Suit.CLUBS}
	]
	
	for i in range(preview_cards.size()):
		var card_data = preview_cards[i]
		var card_preview = preload("res://Magic-Castle/scenes/ui/components/CardPreview.tscn").instantiate()
		card_preview_container.add_child(card_preview)
		card_preview.set_card(card_data.rank, card_data.suit)
		card_preview.set_skin(available_card_skins[current_card_skin_index].name, SettingsSystem.high_contrast)
		card_preview.scale = Vector2(0.8, 0.8)
	
	# Force layout update
	_force_layout_update(card_preview_container)
	
func _create_board_preview() -> void:
	if not board_preview_container:
		return
		
	# Clear existing
	for child in board_preview_container.get_children():
		child.queue_free()
	
	# Create board preview
	board_preview_instance = preload("res://Magic-Castle/scenes/ui/components/BoardPreview.tscn").instantiate()
	board_preview_container.add_child(board_preview_instance)
	board_preview_instance.set_skin(available_board_skins[current_board_skin_index].name)
	
	# Force layout update
	_force_layout_update(board_preview_container)
	
func _force_layout_update(node: Node) -> void:
	# Walk up the tree and force each container to recalculate
	var current = node
	while current and current != scroll_container:
		if current is Container:
			current.queue_sort()
		current = current.get_parent()
	
	# Final update on the scroll container
	await get_tree().process_frame
	if sections_container:
		sections_container.queue_sort()

func _setup_button_groups() -> void:
	# Debug print
	print("Setting up button groups...")
	print("Left button exists: ", left_button != null)
	print("Right button exists: ", right_button != null)
	print("Both button exists: ", both_button != null)
	
	# Create button group for input mode buttons
	var input_button_group = ButtonGroup.new()
	
	if left_button:
		left_button.button_group = input_button_group
		left_button.toggle_mode = true
		left_button.disabled = false  # Ensure not disabled
		print("Left button setup - toggle_mode: ", left_button.toggle_mode)
	
	if right_button:
		right_button.button_group = input_button_group
		right_button.toggle_mode = true
		right_button.disabled = false
		print("Right button setup - toggle_mode: ", right_button.toggle_mode)
	
	if both_button:
		both_button.button_group = input_button_group
		both_button.toggle_mode = true
		both_button.disabled = false
		print("Both button setup - toggle_mode: ", both_button.toggle_mode)
	
	# Debug: Check if buttons are visible and enabled
	for button in [left_button, right_button, both_button]:
		if button:
			print("Button %s - visible: %s, disabled: %s, mouse_filter: %s" % [
				button.name, 
				button.visible, 
				button.disabled,
				button.mouse_filter
			])
