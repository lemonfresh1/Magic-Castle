# MobileTopBar.gd - Functional updates only, no layout changes
# Path: res://Magic-Castle/scripts/game/MobileTopBar.gd
extends Control

# === SCENE REFERENCES ===
@onready var menu_button: Button = $Panel/MarginContainer/HBoxContainer/Menu
@onready var timer_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/TimerContainer/TimerBar
@onready var timer_label: Label = $Panel/MarginContainer/HBoxContainer/TimerContainer/TimerLabel
@onready var draw_pile_sprite: TextureRect = $Panel/MarginContainer/HBoxContainer/DrawPile/DrawPileSprite
@onready var draw_pile_label: Label = $Panel/MarginContainer/HBoxContainer/DrawPile/DrawPileLabel
@onready var card_slot_1: Control = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot1
@onready var card_slot_2: Control = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot2
@onready var slot_2_background: TextureRect = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot2/Background
@onready var slot_2_countdown: Label = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot2/ComboCountdown1
@onready var card_slot_3: Control = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot3
@onready var slot_3_background: TextureRect = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot3/Background
@onready var slot_3_countdown: Label = $Panel/MarginContainer/HBoxContainer/CardSlots/CardSlot3/ComboCountdown2
@onready var combo_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/ComboContainer/ComboBar
@onready var combo_label: Label = $Panel/MarginContainer/HBoxContainer/ComboContainer/ComboLabel
@onready var pause_button: Button = $Panel/MarginContainer/HBoxContainer/Pause

# State
var is_paused: bool = false
var slot_cards: Array[Control] = []
var card_scene = preload("res://Magic-Castle/scenes/game/Card.tscn")
var card_back_texture = preload("res://Magic-Castle/assets/cards/card_back.png")

func _ready() -> void:
	# Apply bar colors
	_style_timer_bar()
	_style_combo_bar()
	
	# Set draw pile texture
	draw_pile_sprite.texture = card_back_texture
	
	# Connect signals
	menu_button.pressed.connect(_on_menu_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.combo_updated.connect(_on_combo_updated)
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	
	# Initial setup
	pause_button.visible = not GameState.is_multiplayer
	slot_2_countdown.text = str(GameConstants.SLOT_2_UNLOCK_COMBO)
	slot_3_countdown.text = str(GameConstants.SLOT_3_UNLOCK_COMBO)
	
	set_process(true)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _style_timer_bar() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.8, 0.2, 0.3)  # Green with transparency
	bg.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("background", bg)
	
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.8, 0.2)  # Green
	fill.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("fill", fill)

func _style_combo_bar() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.9, 0.9, 0.2, 0.3)  # Yellow with transparency
	bg.set_corner_radius_all(4)
	combo_bar.add_theme_stylebox_override("background", bg)
	
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.9, 0.2)  # Yellow
	fill.set_corner_radius_all(4)
	combo_bar.add_theme_stylebox_override("fill", fill)

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
	slot_2_countdown.text = str(GameConstants.SLOT_2_UNLOCK_COMBO)
	slot_3_countdown.text = str(GameConstants.SLOT_3_UNLOCK_COMBO)
	call_deferred("update_slots")
