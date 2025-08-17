# SettingsUI.gd - Settings interface using the panel system
# Location: res://Pyramids/scripts/ui/settings/SettingsUI.gd
# Last Updated: Removed card/board skins, cleaned up for refactored managers
#
# SettingsUI handles:
# - Game mode selection through GameModeManager
# - Audio settings (SFX, music, error/success sounds)
# - Draw zone positioning through DrawZoneManager
# - Tab-based organization for clean UX
# - Directing users to Profile/Inventory for cosmetics
#
# Flow: User input → SettingsUI → SettingsSystem/Managers → Apply changes
# Dependencies: GameModeManager (modes), DrawZoneManager (zones), SettingsSystem (preferences)

extends PanelContainer

signal settings_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer

# Direct references for Game tab
@onready var scroll_container: ScrollContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer
@onready var v_box_container: VBoxContainer = $MarginContainer/TabContainer/Game/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer

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

# Available game modes from GameModeManager
var available_modes: Array[Dictionary] = []
var current_mode_index: int = 0

# Audio UI references
var sfx_slider: HSlider
var music_slider: HSlider
var sfx_label: Label
var music_label: Label

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "settings_ui")
	
	# Get available game modes from GameModeManager
	available_modes = GameModeManager.get_all_mode_info()
	
	# Clean up the Game tab - remove card and board sections
	_cleanup_game_tab()
	
	# Connect signals for Game tab
	_connect_game_controls()
	_fix_scroll_container()

	# Create content for Audio/Input tabs
	_setup_audio_tab()
	_setup_input_tab()
	
	_load_current_settings()

func _cleanup_game_tab():
	"""Remove card and board sections from the Game tab"""
	# Find and remove card section
	var card_section = v_box_container.get_node_or_null("card_section")
	if card_section:
		card_section.queue_free()
	
	# Find and remove board section  
	var board_section = v_box_container.get_node_or_null("board_section")
	if board_section:
		board_section.queue_free()
	
	# Ensure game mode section is visible
	if game_mode_section:
		game_mode_section.visible = true
		game_mode_section.modulate = Color.WHITE
	
	# Add a note about where to change cosmetics
	if v_box_container:
		var spacer = Control.new()
		spacer.custom_minimum_size.y = 20
		v_box_container.add_child(spacer)
		
		var note = Label.new()
		note.text = "To change card and board skins, visit your Profile → Inventory"
		note.add_theme_font_size_override("font_size", 14)
		note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_box_container.add_child(note)

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
		game_scroll.custom_minimum_size = Vector2(0, 200)
		
		# Force the VBoxContainer inside to also expand
		if v_box_container:
			v_box_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v_box_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _connect_game_controls():
	"""Connect game mode controls"""
	if game_mode_left_button and not game_mode_left_button.pressed.is_connected(_on_mode_left):
		game_mode_left_button.pressed.connect(_on_mode_left)
		
	if game_mode_right_button and not game_mode_right_button.pressed.is_connected(_on_mode_right):
		game_mode_right_button.pressed.connect(_on_mode_right)

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
	
	# Description
	var desc = Label.new()
	desc.text = "Choose where the draw zones appear on your screen"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
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
		if pressed: _on_input_mode_selected(DrawZoneManager.DrawZoneMode.LEFT_ONLY))
	hbox.add_child(left_button)
	
	var right_button = Button.new()
	right_button.text = "Right Only"
	right_button.toggle_mode = true
	right_button.button_group = input_button_group
	right_button.custom_minimum_size = Vector2(100, 40)
	right_button.toggled.connect(func(pressed): 
		if pressed: _on_input_mode_selected(DrawZoneManager.DrawZoneMode.RIGHT_ONLY))
	hbox.add_child(right_button)
	
	var both_button = Button.new()
	both_button.text = "Both Sides"
	both_button.toggle_mode = true
	both_button.button_group = input_button_group
	both_button.custom_minimum_size = Vector2(100, 40)
	both_button.toggled.connect(func(pressed): 
		if pressed: _on_input_mode_selected(DrawZoneManager.DrawZoneMode.BOTH))
	hbox.add_child(both_button)
	
	# Set current selection based on DrawZoneManager
	var current_mode = DrawZoneManager.get_draw_mode()
	match current_mode:
		DrawZoneManager.DrawZoneMode.LEFT_ONLY:
			left_button.button_pressed = true
		DrawZoneManager.DrawZoneMode.RIGHT_ONLY:
			right_button.button_pressed = true
		DrawZoneManager.DrawZoneMode.BOTH:
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
	var current_mode_name = GameModeManager.get_current_mode() if GameModeManager.get_current_mode() else "classic"
	for i in range(available_modes.size()):
		if available_modes[i].name == current_mode_name:
			current_mode_index = i
			break
	_update_mode_display()
	
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
	if not game_mode_label or not game_mode_description:
		return
		
	var mode = available_modes[current_mode_index]
	game_mode_label.text = mode.display
	game_mode_description.text = mode.description
	
	# Show lock status if not available
	if not mode.available:
		game_mode_description.text += "\n[Locked: %s]" % mode.unlock_requirement
		game_mode_label.modulate = Color(0.5, 0.5, 0.5)
		game_mode_description.modulate = Color(0.5, 0.5, 0.5)
	else:
		game_mode_label.modulate = Color.WHITE
		game_mode_description.modulate = Color.WHITE

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
func _on_input_mode_selected(mode: DrawZoneManager.DrawZoneMode):
	DrawZoneManager.set_draw_mode(mode)
	
	# Also update SettingsSystem for backwards compatibility
	match mode:
		DrawZoneManager.DrawZoneMode.LEFT_ONLY:
			SettingsSystem.set_draw_pile_mode(SettingsSystem.DrawPileMode.LEFT_ONLY)
		DrawZoneManager.DrawZoneMode.RIGHT_ONLY:
			SettingsSystem.set_draw_pile_mode(SettingsSystem.DrawPileMode.RIGHT_ONLY)
		DrawZoneManager.DrawZoneMode.BOTH:
			SettingsSystem.set_draw_pile_mode(SettingsSystem.DrawPileMode.BOTH_SIDES)

# UIManager integration functions
func show_settings():
	visible = true

func hide_settings():
	visible = false
	settings_closed.emit()

func _on_visibility_changed():
	if not visible:
		UIManager.close_panel("settings")
