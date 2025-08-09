# MobileTopBar.gd - Mobile-optimized top bar with UIStyleManager integration
# Path: res://Magic-Castle/scripts/game/MobileTopBar.gd
# Last Updated: Applied UIStyleManager and new structure

extends Control

# === SCENE REFERENCES (Updated for new structure) ===
@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var hbox_container: HBoxContainer = $Panel/MarginContainer/HBoxContainer

# Left Section
@onready var left_section: HBoxContainer = $Panel/MarginContainer/HBoxContainer/LeftSection
@onready var menu_button: Button = $Panel/MarginContainer/HBoxContainer/LeftSection/MenuButton
@onready var timer_container: Control = $Panel/MarginContainer/HBoxContainer/LeftSection/TimerContainer
@onready var timer_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/LeftSection/TimerContainer/TimerBar
@onready var timer_label: Label = $Panel/MarginContainer/HBoxContainer/LeftSection/TimerContainer/TimerLabel

# Center Section  
@onready var center_section: HBoxContainer = $Panel/MarginContainer/HBoxContainer/CenterSection
@onready var draw_pile_container: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/DrawPileContainer
@onready var draw_pile_sprite: TextureRect = $Panel/MarginContainer/HBoxContainer/CenterSection/DrawPileContainer/DrawPileSprite
@onready var draw_pile_label: Label = $Panel/MarginContainer/HBoxContainer/CenterSection/DrawPileContainer/DrawPileLabel
@onready var card_slot_1: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot1
@onready var card_slot_2: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot2
@onready var slot_2_background: TextureRect = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot2/Background
@onready var slot_2_countdown: Label = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot2/ComboCountdown1
@onready var card_slot_3: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot3
@onready var slot_3_background: TextureRect = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot3/Background2
@onready var slot_3_countdown: Label = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot3/ComboCountdown2

# Right Section
@onready var right_section: HBoxContainer = $Panel/MarginContainer/HBoxContainer/RightSection
@onready var combo_container: Control = $Panel/MarginContainer/HBoxContainer/RightSection/ComboContainer
@onready var combo_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/RightSection/ComboContainer/ComboBar
@onready var combo_label: Label = $Panel/MarginContainer/HBoxContainer/RightSection/ComboContainer/ComboLabel
@onready var pause_button: Button = $Panel/MarginContainer/HBoxContainer/RightSection/PauseButton

# State
var is_paused: bool = false
var slot_cards: Array[Control] = []
var card_scene = preload("res://Magic-Castle/scenes/game/Card.tscn")
var card_back_texture = preload("res://Magic-Castle/assets/cards/card_back.png")

func _ready() -> void:
	# Set up proportional sizing
	_setup_proportional_layout()
	
	# Apply UIStyleManager styling
	_apply_ui_styles()
	
	# Set draw pile texture
	if draw_pile_sprite:
		draw_pile_sprite.texture = card_back_texture
	
	# Connect button signals
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	
	# Add draw pile interaction
	if draw_pile_container:
		draw_pile_container.gui_input.connect(_on_draw_pile_input)
	
	# Connect game signals
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.combo_updated.connect(_on_combo_updated)
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	
	# Initial setup
	if pause_button:
		pause_button.visible = not GameState.is_multiplayer
	
	if slot_2_countdown:
		slot_2_countdown.text = str(GameConstants.SLOT_2_UNLOCK_COMBO)
	if slot_3_countdown:
		slot_3_countdown.text = str(GameConstants.SLOT_3_UNLOCK_COMBO)
	
	# Enable processing
	set_process(true)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_proportional_layout() -> void:
	# Make the top bar fill entire width
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	position = Vector2(0, 0)  # Ensure it starts at top-left
	
	# Set the top bar height based on screen size
	var screen = UIStyleManager.get_screen_size()
	var top_bar_height = UIStyleManager.get_game_dimension("top_bar_height")
	
	size = Vector2(screen.x, top_bar_height)  # Full width
	custom_minimum_size = Vector2(screen.x, top_bar_height)
	
	# Make panel fill the entire control
	if panel:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.position = Vector2(0, 0)
		panel.size = Vector2(screen.x, top_bar_height)
	
	# Add proper margins to the container
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", UIStyleManager.get_spacing("space_4"))
		margin_container.add_theme_constant_override("margin_right", UIStyleManager.get_spacing("space_4"))
		margin_container.add_theme_constant_override("margin_top", UIStyleManager.get_spacing("space_2"))
		margin_container.add_theme_constant_override("margin_bottom", UIStyleManager.get_spacing("space_2"))
	
	# Set stretch ratios for sections
	if left_section:
		left_section.size_flags_stretch_ratio = 1.4
		left_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if center_section:
		center_section.size_flags_stretch_ratio = 1.0
		center_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if right_section:
		right_section.size_flags_stretch_ratio = 1.72
		right_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Ensure proper z-index so it doesn't overlap cards
	z_index = 10  # Lower than cards which are at 25

func _apply_ui_styles() -> void:
	# Style the panel with white background and shadow
	if panel:
		UIStyleManager.apply_top_bar_panel_style(panel)
	
	# Style progress bars
	if timer_bar:
		UIStyleManager.apply_game_progress_bar_style(timer_bar, "timer")
		timer_bar.max_value = 60  # Set max value
	if combo_bar:
		UIStyleManager.apply_game_progress_bar_style(combo_bar, "combo")
		combo_bar.max_value = 15  # Set max for combo timer
	
	# Style buttons with primary style for better contrast on white
	if menu_button:
		UIStyleManager.apply_button_style(menu_button, "primary", "small")
		menu_button.text = "Menu"
	if pause_button:
		UIStyleManager.apply_button_style(pause_button, "primary", "small")
		pause_button.text = "Pause"
	
	# Style labels with dark colors for white background
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
		timer_label.add_theme_color_override("font_color", UIStyleManager.get_color("white"))
		timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		timer_label.add_theme_constant_override("shadow_offset_x", 2)
		timer_label.add_theme_constant_override("shadow_offset_y", 2)
		timer_label.add_theme_constant_override("outline_size", 6)
		timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	
	if combo_label:
		combo_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
		combo_label.add_theme_color_override("font_color", UIStyleManager.get_color("white"))
		combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		combo_label.add_theme_constant_override("shadow_offset_x", 2)
		combo_label.add_theme_constant_override("shadow_offset_y", 2)
		combo_label.add_theme_constant_override("outline_size", 6)
		combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	
	if draw_pile_label:
		draw_pile_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_h2"))  # Much bigger
		draw_pile_label.add_theme_color_override("font_color", UIStyleManager.get_color("white"))
		draw_pile_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		draw_pile_label.add_theme_constant_override("shadow_offset_x", 3)
		draw_pile_label.add_theme_constant_override("shadow_offset_y", 3)
		draw_pile_label.add_theme_constant_override("outline_size", 10)
		draw_pile_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	
	# Style countdown labels
	if slot_2_countdown:
		slot_2_countdown.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_title"))
		slot_2_countdown.add_theme_color_override("font_color", UIStyleManager.get_color("gray_500"))
	
	if slot_3_countdown:
		slot_3_countdown.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_title"))
		slot_3_countdown.add_theme_color_override("font_color", UIStyleManager.get_color("gray_500"))
	
	# Set minimum sizes for card slots
	var slot_size = UIStyleManager.get_proportional_size(80, "width")
	if card_slot_1:
		card_slot_1.custom_minimum_size = Vector2(slot_size, slot_size * 1.375)
	if card_slot_2:
		card_slot_2.custom_minimum_size = Vector2(slot_size, slot_size * 1.375)
	if card_slot_3:
		card_slot_3.custom_minimum_size = Vector2(slot_size, slot_size * 1.375)

func _process(_delta: float) -> void:
	if GameState.is_round_active and not is_paused:
		# Update timer label
		if GameState.round_time_limit > 0:
			timer_bar.value = GameState.time_remaining
			timer_label.text = "%d" % int(GameState.time_remaining)
		
		# Update combo bar and label
		if ScoreSystem.combo_timer and not ScoreSystem.combo_timer.is_stopped():
			combo_bar.visible = true
			combo_bar.value = ScoreSystem.combo_timer.time_left
			combo_label.text = "%.1f" % ScoreSystem.combo_timer.time_left
		else:
			combo_bar.visible = false
			combo_label.text = ""
		
		# Update draw pile label
		if CardManager:
			var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
			var cards_already_drawn = CardManager.cards_drawn
			var pile_size = CardManager.draw_pile.size()
			var draws_remaining = min(pile_size, draw_limit - cards_already_drawn)
			draws_remaining = max(0, draws_remaining)
			draw_pile_label.text = "%d" % draws_remaining

func update_slots() -> void:
	# Clear existing cards
	for card in slot_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	slot_cards.clear()
	
	# Update each slot
	for i in range(3):
		var slot = [card_slot_1, card_slot_2, card_slot_3][i]
		
		# Handle slot 2 and 3 backgrounds/counters
		if i > 0:
			var bg = slot_2_background if i == 1 else slot_3_background
			var countdown = slot_2_countdown if i == 1 else slot_3_countdown
			
			if i < CardManager.active_slots:
				# Slot is unlocked - hide background and counter
				bg.visible = false
				countdown.visible = false
			else:
				# Slot is locked - show background and counter
				bg.visible = true
				countdown.visible = true
				var required = GameConstants.SLOT_2_UNLOCK_COMBO if i == 1 else GameConstants.SLOT_3_UNLOCK_COMBO
				var remaining = max(0, required - CardManager.current_combo)
				countdown.text = "%d" % remaining
		
		# Add card if slot has one
		if i < CardManager.active_slots and CardManager.slot_cards[i] != null:
			var card = card_scene.instantiate()
			slot.add_child(card)
			card.setup(CardManager.slot_cards[i], -1)
			card.position = Vector2.ZERO
			card.size = slot.size
			card.set_selectable(false)
			card.z_index = 25
			slot_cards.append(card)

func _on_menu_pressed() -> void:
	if is_paused:
		is_paused = false
		get_tree().paused = false
		pause_button.text = "Pause"
	GameState.reset_game_completely()
	get_tree().change_scene_to_file("res://Magic-Castle/scenes/ui/menus/MainMenu.tscn")

func _on_pause_pressed() -> void:
	is_paused = not is_paused
	pause_button.text = "Resume" if is_paused else "Pause"
	get_tree().paused = is_paused

func _on_round_started(_round: int) -> void:
	# Hide timer in chill mode
	var show_timer = GameModeManager.should_show_timer()
	timer_bar.visible = show_timer
	timer_label.visible = show_timer
	
	# Reset countdown labels
	slot_2_countdown.text = str(GameConstants.SLOT_2_UNLOCK_COMBO)
	slot_3_countdown.text = str(GameConstants.SLOT_3_UNLOCK_COMBO)
	
	call_deferred("update_slots")

func _on_combo_updated(combo: int) -> void:
	# Update countdown labels
	if CardManager.active_slots < 2:
		var remaining = max(0, GameConstants.SLOT_2_UNLOCK_COMBO - combo)
		slot_2_countdown.text = "%d" % remaining
	
	if CardManager.active_slots < 3:
		var remaining = max(0, GameConstants.SLOT_3_UNLOCK_COMBO - combo)
		slot_3_countdown.text = "%d" % remaining
	
	if combo == 0:
		slot_2_countdown.text = str(GameConstants.SLOT_2_UNLOCK_COMBO)
		slot_3_countdown.text = str(GameConstants.SLOT_3_UNLOCK_COMBO)

func _on_card_selected(_card: Control) -> void:
	call_deferred("update_slots")

func _on_draw_pile_clicked() -> void:
	# Animate the draw pile when clicked
	if draw_pile_container:
		var tween = create_tween()
		tween.tween_property(draw_pile_container, "scale", Vector2(0.95, 0.95), 0.05)
		tween.tween_property(draw_pile_container, "scale", Vector2.ONE, 0.05)
	
	if slot_2_countdown:
		slot_2_countdown.text = str(GameConstants.SLOT_2_UNLOCK_COMBO)
	if slot_3_countdown:
		slot_3_countdown.text = str(GameConstants.SLOT_3_UNLOCK_COMBO)
	
	call_deferred("update_slots")

func _on_draw_pile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if draws available
		if CardManager:
			var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
			var cards_already_drawn = CardManager.cards_drawn
			var pile_size = CardManager.draw_pile.size()
			var draws_remaining = min(pile_size, draw_limit - cards_already_drawn)
			
			if draws_remaining > 0:
				# Animate click
				var tween = create_tween()
				tween.tween_property(draw_pile_container, "scale", Vector2(0.9, 0.9), 0.05)
				tween.tween_property(draw_pile_container, "scale", Vector2.ONE, 0.05)
				
				SignalBus.draw_pile_clicked.emit()
