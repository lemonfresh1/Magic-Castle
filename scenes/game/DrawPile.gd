# DrawPile.gd
extends Control

@onready var card_back: TextureRect = $CardBack
@onready var count_label: Label = $CountLabel

var sprite_sheet: Texture2D = preload("res://Magic-Castle/assets/cards/cards_spritesheet.png")
const CARD_WIDTH = 57
const CARD_HEIGHT = 80
const CARD_GAP = 2

func _ready() -> void:
	# Set up card back image
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = sprite_sheet
	# Card back at column 1, row 4
	atlas_texture.region = Rect2(
		1 * (CARD_WIDTH + CARD_GAP),
		4 * (CARD_HEIGHT + CARD_GAP),
		CARD_WIDTH,
		CARD_HEIGHT
	)
	card_back.texture = atlas_texture
	card_back.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Connect input
	gui_input.connect(_on_gui_input)
	
	# Start updating counter
	set_process(true)
	set_process_unhandled_key_input(true)  # Enable keyboard input

func _process(_delta: float) -> void:
	# Show draws remaining according to game rules, not physical pile size
	if CardManager and GameState:
		var draw_limit = GameConstants.get_draw_pile_limit(GameState.current_round)
		var cards_already_drawn = CardManager.cards_drawn
		var pile_size = CardManager.draw_pile.size()
		
		# Show the number of draws still allowed
		var draws_remaining = min(pile_size, draw_limit - cards_already_drawn)
		draws_remaining = max(0, draws_remaining)
		
		count_label.text = str(draws_remaining)
		modulate.a = 1.0 if draws_remaining > 0 else 0.5

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check draw pile mode setting
			var click_pos = event.position
			var draw_allowed = false
			
			match SettingsSystem.draw_pile_mode:
				SettingsSystem.DrawPileMode.LEFT_ONLY:
					draw_allowed = click_pos.x < size.x * 0.5
				SettingsSystem.DrawPileMode.RIGHT_ONLY:
					draw_allowed = click_pos.x >= size.x * 0.5
				SettingsSystem.DrawPileMode.BOTH_SIDES:
					draw_allowed = true
			
			if draw_allowed:
				_attempt_draw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed and not event.echo:
			_attempt_draw()
			get_viewport().set_input_as_handled()

func _attempt_draw() -> void:
	# Check if we can actually draw
	var can_draw = CardManager.draw_pile.size() > 0 and CardManager.cards_drawn < GameConstants.get_draw_pile_limit(GameState.current_round)
	
	if can_draw:
		SignalBus.draw_pile_clicked.emit()
