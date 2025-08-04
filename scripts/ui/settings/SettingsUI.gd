# SettingsUI.gd - Settings interface using the panel system
# Location: res://Magic-Castle/scripts/ui/settings/SettingsUI.gd
# Last Updated: Integrated with UIStyleManager [Date]

extends PanelContainer

signal settings_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer

# Direct references using the renamed paths
@onready var scroll_container: ScrollContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer
@onready var v_box_container: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer

# [Keep all existing @onready references - they're already correct]
# Game Mode Section
@onready var game_mode_section: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section
@onready var game_mode_title: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_title
@onready var game_mode_separator: HSeparator = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_title2
@onready var game_mode_selector: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_selector
@onready var game_mode_controls: HBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_selector/game_mode_controls
@onready var game_mode_left_button: Button = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_selector/game_mode_controls/game_mode_left_button
@onready var game_mode_label: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_selector/game_mode_controls/game_mode_label
@onready var game_mode_right_button: Button = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_selector/game_mode_controls/game_mode_right_button
@onready var game_mode_description: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/game_mode_section/game_mode_selector/game_mode_description

# Card Section
@onready var card_section: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section
@onready var card_title: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_title
@onready var card_separator: HSeparator = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_separator
@onready var card_selector: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector
@onready var card_controls: HBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector/card_controls
@onready var card_left_button: Button = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector/card_controls/card_left_button
@onready var card_preview_container: HBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector/card_controls/card_preview_container
@onready var card_right_button: Button = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector/card_controls/card_right_button
@onready var card_skin_name: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector/card_skin_name
@onready var card_high_contrast_check: CheckButton = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/card_section/card_selector/card_high_contrast_check

# Board Section
@onready var board_section: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section
@onready var board_title: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_title
@onready var board_separator: HSeparator = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_separator
@onready var board_selector: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_selector
@onready var board_controls: HBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_selector/board_controls
@onready var board_left_button: Button = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_selector/board_controls/board_left_button
@onready var board_preview_container: HBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_selector/board_controls/board_preview_container
@onready var board_right_button: Button = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_selector/board_controls/board_right_button
@onready var board_skin_name: Label = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/board_section/board_selector/board_skin_name

# Available options from existing settings
var available_modes: Array[Dictionary] = []
var available_card_skins: Array[Dictionary] = [
	{"name": "sprites", "display": "Classic", "has_contrast": false},
	{"name": "classic", "display": "Classic HD", "has_contrast": true},
	{"name": "modern", "display": "Modern", "has_contrast": false},
	{"name": "retro", "display": "Retro", "has_contrast": true}
]
var available_board_skins: Array[Dictionary] = [
	{"name": "classic", "display": "Classic Green"},
	{"name": "green", "display": "Green Felt"},
	{"name": "blue", "display": "Ocean Blue"},
	{"name": "sunset", "display": "Sunset"}
]

var current_mode_index: int = 0
var current_card_skin_index: int = 0
var current_board_skin_index: int = 0

var board_preview_instance: Panel

# Other UI references that we'll create
var sfx_slider: HSlider
var music_slider: HSlider
var sfx_label: Label
var music_label: Label

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "settings_ui")
	
	available_modes = GameModeManager.get_all_mode_info()
	
	# Connect signals for Game tab
	_connect_game_controls()
	_fix_scroll_container()

	# Create content for Audio/Input tabs
	_setup_audio_tab()
	_setup_input_tab()
	
	_load_current_settings()
	
	# Create previews after loading settings
	await get_tree().process_frame
	_create_card_previews()
	_create_board_preview()

	await get_tree().process_frame
	_debug_game_tab()

# Add this debug function to your SettingsUI.gd after _ready()

func _debug_game_tab():
	print("\n=== GAME TAB DEBUG ===")
	
	# Check visibility of main containers
	print("Main containers visibility:")
	print("  - game_mode_section visible: ", game_mode_section.visible if game_mode_section else "null")
	print("  - card_section visible: ", card_section.visible if card_section else "null")
	print("  - board_section visible: ", board_section.visible if board_section else "null")
	
	# Check positions and sizes
	if game_mode_section:
		print("\nGame Mode Section:")
		print("  - Position: ", game_mode_section.position)
		print("  - Size: ", game_mode_section.size)
		print("  - Global Position: ", game_mode_section.global_position)
		
	if card_section:
		print("\nCard Section:")
		print("  - Position: ", card_section.position)
		print("  - Size: ", card_section.size)
		print("  - Global Position: ", card_section.global_position)
		
	# Check if content is off-screen
	var viewport_size = get_viewport().size
	print("\nViewport size: ", viewport_size)
	
	# Check the scroll container
	if scroll_container:
		print("\nScroll Container:")
		print("  - Position: ", scroll_container.position)
		print("  - Size: ", scroll_container.size)
		print("  - Scroll vertical: ", scroll_container.scroll_vertical)
		
	# Check v_box_container
	if v_box_container:
		print("\nVBoxContainer:")
		print("  - Position: ", v_box_container.position)
		print("  - Size: ", v_box_container.size)
		print("  - Child count: ", v_box_container.get_child_count())
		
	# Check modulate/transparency
	print("\nTransparency check:")
	print("  - game_mode_section modulate: ", game_mode_section.modulate if game_mode_section else "null")
	print("  - game_mode_section self_modulate: ", game_mode_section.self_modulate if game_mode_section else "null")
	
	# Force visibility and check
	if game_mode_section:
		game_mode_section.visible = true
		game_mode_section.modulate = Color.WHITE
		print("\nForced game_mode_section visible and white")
		
	# Check theme overrides
	if game_mode_title:
		print("\nGame mode title:")
		print("  - Text: ", game_mode_title.text)
		print("  - Font color: ", game_mode_title.get_theme_color("font_color") if game_mode_title.has_theme_color("font_color") else "default")
		print("  - Visible: ", game_mode_title.visible)
		print("  - Size: ", game_mode_title.size)

func _force_layout_update():
	if scroll_container:
		scroll_container.queue_sort()
	if v_box_container:
		v_box_container.queue_sort()
		# Force minimum size
		v_box_container.custom_minimum_size = Vector2(600, 400)
	
	# Ensure sections have minimum height
	for section in [game_mode_section, card_section, board_section]:
		if section:
			section.custom_minimum_size = Vector2(0, 100)
			section.visible = true

func _connect_game_controls():
	print("Connecting game controls...")
	# Game mode controls
	if game_mode_left_button and not game_mode_left_button.pressed.is_connected(_on_mode_left):
		game_mode_left_button.pressed.connect(_on_mode_left)
		print("  - Connected game_mode_left_button")
		
	if game_mode_right_button and not game_mode_right_button.pressed.is_connected(_on_mode_right):
		game_mode_right_button.pressed.connect(_on_mode_right)
		print("  - Connected game_mode_right_button")
	
	# Card skin controls
	if card_left_button and not card_left_button.pressed.is_connected(_on_card_skin_left):
		card_left_button.pressed.connect(_on_card_skin_left)
		print("  - Connected card_left_button")
		
	if card_right_button and not card_right_button.pressed.is_connected(_on_card_skin_right):
		card_right_button.pressed.connect(_on_card_skin_right)
		print("  - Connected card_right_button")
		
	if card_high_contrast_check and not card_high_contrast_check.toggled.is_connected(_on_high_contrast_toggled):
		card_high_contrast_check.toggled.connect(_on_high_contrast_toggled)
		print("  - Connected card_high_contrast_check")
	
	# Board skin controls
	if board_left_button and not board_left_button.pressed.is_connected(_on_board_skin_left):
		board_left_button.pressed.connect(_on_board_skin_left)
		print("  - Connected board_left_button")
		
	if board_right_button and not board_right_button.pressed.is_connected(_on_board_skin_right):
		board_right_button.pressed.connect(_on_board_skin_right)
		print("  - Connected board_right_button")

func _setup_audio_tab():
	var audio_tab = tab_container.get_node_or_null("Audio")
	if not audio_tab:
		return
	
	var margin = audio_tab.get_node_or_null("MarginContainer")
	if not margin:
		return
		
	var vbox = margin.get_node_or_null("VBoxContainer")
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 20)
		margin.add_child(vbox)
	
	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	
	# Title
	var title = Label.new()
	title.text = "Audio Settings"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.643, 0.529, 1, 1))
	vbox.add_child(title)
	
	# Error sounds toggle
	var error_toggle = CheckButton.new()
	error_toggle.text = "Error Sounds"
	error_toggle.button_pressed = SettingsSystem.error_sounds_enabled
	error_toggle.add_theme_color_override("font_color", Color(0.257, 0.257, 0.257))
	error_toggle.toggled.connect(_on_error_sound_toggled)
	vbox.add_child(error_toggle)
	
	# Success sounds toggle
	var success_toggle = CheckButton.new()
	success_toggle.text = "Success Sounds"
	success_toggle.button_pressed = SettingsSystem.success_sounds_enabled
	success_toggle.add_theme_color_override("font_color", Color(0.257, 0.257, 0.257))
	success_toggle.toggled.connect(_on_success_sound_toggled)
	vbox.add_child(success_toggle)
	
	# SFX Volume
	var sfx_container = _create_volume_control("SFX Volume", SettingsSystem.sfx_volume * 100)
	sfx_slider = sfx_container.get_node("HBoxContainer/Slider")
	sfx_label = sfx_container.get_node("HBoxContainer/ValueLabel")
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	vbox.add_child(sfx_container)
	
	# Music Volume
	var music_container = _create_volume_control("Music Volume", SettingsSystem.music_volume * 100)
	music_slider = music_container.get_node("HBoxContainer/Slider")
	music_label = music_container.get_node("HBoxContainer/ValueLabel")
	music_slider.value_changed.connect(_on_music_volume_changed)
	vbox.add_child(music_container)

func _setup_input_tab():
	var input_tab = tab_container.get_node_or_null("Input")
	if not input_tab:
		return
	
	var margin = input_tab.get_node_or_null("MarginContainer")
	if not margin:
		return
		
	var vbox = margin.get_node_or_null("VBoxContainer")
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 20)
		margin.add_child(vbox)
	
	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	
	# Title
	var title = Label.new()
	title.text = "Draw Pile Position"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.643, 0.529, 1, 1))
	vbox.add_child(title)
	
	# Button group for input mode
	var input_button_group = ButtonGroup.new()
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var left_button = Button.new()
	left_button.text = "Left Only"
	left_button.toggle_mode = true
	left_button.button_group = input_button_group
	left_button.custom_minimum_size = Vector2(100, 40)
	left_button.toggled.connect(func(pressed): 
		if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.LEFT_ONLY))
	hbox.add_child(left_button)
	
	var right_button = Button.new()
	right_button.text = "Right Only"
	right_button.toggle_mode = true
	right_button.button_group = input_button_group
	right_button.custom_minimum_size = Vector2(100, 40)
	right_button.toggled.connect(func(pressed): 
		if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.RIGHT_ONLY))
	hbox.add_child(right_button)
	
	var both_button = Button.new()
	both_button.text = "Both Sides"
	both_button.toggle_mode = true
	both_button.button_group = input_button_group
	both_button.custom_minimum_size = Vector2(100, 40)
	both_button.toggled.connect(func(pressed): 
		if pressed: _on_input_mode_selected(SettingsSystem.DrawPileMode.BOTH_SIDES))
	hbox.add_child(both_button)
	
	# Set current selection
	match SettingsSystem.draw_pile_mode:
		SettingsSystem.DrawPileMode.LEFT_ONLY:
			left_button.button_pressed = true
		SettingsSystem.DrawPileMode.RIGHT_ONLY:
			right_button.button_pressed = true
		SettingsSystem.DrawPileMode.BOTH_SIDES:
			both_button.button_pressed = true

func _create_volume_control(label_text: String, initial_value: float) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(0.257, 0.257, 0.257))
	container.add_child(label)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 10)
	container.add_child(hbox)
	
	var slider = HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(slider)
	
	var value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "%d%%" % int(initial_value)
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.add_theme_color_override("font_color", Color(0.257, 0.257, 0.257))
	hbox.add_child(value_label)
	
	return container

func _load_current_settings():
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
	
	_update_volume_labels()

# Game Mode functions
func _on_mode_left():
	current_mode_index = wrapi(current_mode_index - 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		var mode_name = available_modes[current_mode_index].name
		GameModeManager.set_current_mode(mode_name)
		SettingsSystem.set_game_mode(mode_name)

func _on_mode_right():
	current_mode_index = wrapi(current_mode_index + 1, 0, available_modes.size())
	_update_mode_display()
	
	if available_modes[current_mode_index].available:
		var mode_name = available_modes[current_mode_index].name
		GameModeManager.set_current_mode(mode_name)
		SettingsSystem.set_game_mode(mode_name)

func _update_mode_display():
	print("_update_mode_display called")
	if not game_mode_label:
		print("  ERROR: game_mode_label is null!")
		return
	if not game_mode_description:
		print("  ERROR: game_mode_description is null!")
		return
		
	var mode = available_modes[current_mode_index]
	print("  Updating to mode: ", mode.display)
	game_mode_label.text = mode.display
	game_mode_description.text = mode.description
	
	game_mode_label.modulate = Color.WHITE if mode.available else Color(0.5, 0.5, 0.5)
	game_mode_description.modulate = Color.WHITE if mode.available else Color(0.5, 0.5, 0.5)

# Card Skin functions
func _on_card_skin_left():
	current_card_skin_index = wrapi(current_card_skin_index - 1, 0, available_card_skins.size())
	_update_card_skin_display()

func _on_card_skin_right():
	current_card_skin_index = wrapi(current_card_skin_index + 1, 0, available_card_skins.size())
	_update_card_skin_display()

func _update_card_skin_display():
	if not card_skin_name:
		return
		
	var skin = available_card_skins[current_card_skin_index]
	card_skin_name.text = skin.display
	
	if card_high_contrast_check:
		card_high_contrast_check.visible = skin.has_contrast
		if skin.has_contrast:
			card_high_contrast_check.button_pressed = SettingsSystem.high_contrast
	
	if card_preview_container:
		for card in card_preview_container.get_children():
			if card.has_method("set_skin"):
				card.set_skin(skin.name, SettingsSystem.high_contrast)
	
	SettingsSystem.set_card_skin(skin.name)

func _on_high_contrast_toggled(pressed: bool):
	SettingsSystem.high_contrast = pressed
	SettingsSystem.save_settings()
	
	if card_preview_container:
		for card in card_preview_container.get_children():
			if card.has_method("set_skin"):
				card.is_high_contrast = pressed
				card._update_display()

# Board Skin functions
func _on_board_skin_left():
	current_board_skin_index = wrapi(current_board_skin_index - 1, 0, available_board_skins.size())
	_update_board_skin_display()

func _on_board_skin_right():
	current_board_skin_index = wrapi(current_board_skin_index + 1, 0, available_board_skins.size())
	_update_board_skin_display()

func _update_board_skin_display():
	if not board_skin_name:
		return
		
	var skin = available_board_skins[current_board_skin_index]
	board_skin_name.text = skin.display
	
	if board_preview_instance and board_preview_instance.has_method("set_skin"):
		board_preview_instance.set_skin(skin.name)
		
	SettingsSystem.set_board_skin(skin.name)

# Audio functions
func _on_error_sound_toggled(pressed: bool):
	SettingsSystem.error_sounds_enabled = pressed
	SettingsSystem.save_settings()

func _on_success_sound_toggled(pressed: bool):
	SettingsSystem.success_sounds_enabled = pressed
	SettingsSystem.save_settings()

func _on_sfx_volume_changed(value: float):
	SettingsSystem.set_sfx_volume(value / 100.0)
	_update_volume_labels()

func _on_music_volume_changed(value: float):
	SettingsSystem.set_music_volume(value / 100.0)
	_update_volume_labels()

func _update_volume_labels():
	if sfx_label and sfx_slider:
		sfx_label.text = "%d%%" % int(sfx_slider.value)
	if music_label and music_slider:
		music_label.text = "%d%%" % int(music_slider.value)

# Input functions
func _on_input_mode_selected(mode: SettingsSystem.DrawPileMode):
	SettingsSystem.set_draw_pile_mode(mode)

# Preview creation
func _create_card_previews():
	if not card_preview_container:
		return
		
	for child in card_preview_container.get_children():
		child.queue_free()
	
	var preview_cards = [
		{"rank": 1, "suit": CardData.Suit.HEARTS},
		{"rank": 13, "suit": CardData.Suit.SPADES},
		{"rank": 12, "suit": CardData.Suit.DIAMONDS},
		{"rank": 11, "suit": CardData.Suit.CLUBS}
	]
	
	for card_data in preview_cards:
		var card_preview = preload("res://Magic-Castle/scenes/ui/components/CardPreview.tscn").instantiate()
		card_preview_container.add_child(card_preview)
		card_preview.set_card(card_data.rank, card_data.suit)
		card_preview.set_skin(available_card_skins[current_card_skin_index].name, SettingsSystem.high_contrast)
		card_preview.scale = Vector2(0.8, 0.8)

func _create_board_preview():
	if not board_preview_container:
		return
		
	for child in board_preview_container.get_children():
		child.queue_free()
	
	board_preview_instance = preload("res://Magic-Castle/scenes/ui/components/BoardPreview.tscn").instantiate()
	board_preview_container.add_child(board_preview_instance)
	board_preview_instance.set_skin(available_board_skins[current_board_skin_index].name)

# UIManager integration functions
func show_settings():
	visible = true

func hide_settings():
	visible = false
	settings_closed.emit()

func _on_visibility_changed():
	if not visible:
		UIManager.close_panel("settings")

# Add this function to SettingsUI.gd

func _fix_scroll_container():
	# Get the Game tab
	var game_tab = tab_container.get_node_or_null("Game")
	if not game_tab:
		return
		
	# Find the ScrollContainer in the Game tab
	var game_scroll = game_tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer")
	if game_scroll:
		# Set proper size flags
		game_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Ensure it has a minimum size
		game_scroll.custom_minimum_size = Vector2(0, 300)
		
		# Force the VBoxContainer inside to also expand
		if v_box_container:
			v_box_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v_box_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		print("Fixed ScrollContainer size")
