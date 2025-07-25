#Card.gd
extends Control

@onready var card_sprite: TextureRect = $CardSprite
@onready var area_2d: Area2D = $Area2D

var card_data: CardData = null
var is_face_up: bool = true
var is_selectable: bool = false
var board_index: int = -1
var cards_blocking_me: Array[Node] = []
var has_been_revealed: bool = false
var is_on_board: bool = true

# Visual effects
const INVALID_TINT = Color(1.5, 0.8, 0.8)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Connect collision signals
	if area_2d:
		area_2d.area_entered.connect(_on_area_entered)
		area_2d.area_exited.connect(_on_area_exited)

func setup(data: CardData, index: int = -1) -> void:
	card_data = data
	board_index = index
	if not is_node_ready():
		await ready
	
	# Set sizes and fix positioning
	if index == -1:  # Slot card
		# FORCE proper positioning
		position = Vector2.ZERO  # Position relative to parent
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 0.0
		
		custom_minimum_size = Vector2(80, 110)
		size = Vector2(80, 110)
		
		if card_sprite:
			# RESET anchors for slot cards
			card_sprite.anchor_left = 0.0
			card_sprite.anchor_top = 0.0
			card_sprite.anchor_right = 0.0
			card_sprite.anchor_bottom = 0.0
			
			card_sprite.position = Vector2.ZERO
			card_sprite.size = Vector2(80, 110)
			card_sprite.custom_minimum_size = Vector2(80, 110)
		
		print("SLOT: Card positioned at %v, size %v" % [position, size])
	else:  # Board card
		custom_minimum_size = Vector2(90, 126)
		size = Vector2(90, 126)
		
		if card_sprite:
			card_sprite.custom_minimum_size = Vector2(90, 126)
			card_sprite.size = Vector2(90, 126)
	
	# Only set up collision for board cards
	if index >= 0 and area_2d:
		is_on_board = true
		if index >= 18:  # Bottom row
			z_index = 4
			area_2d.collision_layer = 1
			area_2d.collision_mask = 0
		elif index >= 9:  # Row 2
			z_index = 3
			area_2d.collision_layer = 2
			area_2d.collision_mask = 1
		elif index >= 3:  # Row 3
			z_index = 2
			area_2d.collision_layer = 4
			area_2d.collision_mask = 2
		else:  # Top row (peaks)
			z_index = 1
			area_2d.collision_layer = 8
			area_2d.collision_mask = 4
		
		# Set initial visibility based on round
		if GameState.current_round % 2 == 0:  # EVEN rounds - all visible
			is_face_up = true
			has_been_revealed = true
		else:  # ODD rounds - progressive reveal
			is_face_up = (index >= 18)
			has_been_revealed = is_face_up
		
		# Wait for physics to settle
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check_visibility()
	else:
		# Slot cards are always face up
		is_face_up = true
		is_on_board = false
		z_index = 25
		if area_2d:
			area_2d.monitoring = false
			area_2d.monitorable = false
	
	_update_display()

func _update_display() -> void:
	if not card_data:
		return
	
	var card_path = "res://Magic-Castle/assets/cards/"
	
	if is_face_up:
		# Convert rank and suit to filename
		var rank_name = ""
		match card_data.rank:
			1: rank_name = "ace"
			2: rank_name = "two"
			3: rank_name = "three"
			4: rank_name = "four"
			5: rank_name = "five"
			6: rank_name = "six"
			7: rank_name = "seven"
			8: rank_name = "eight"
			9: rank_name = "nine"
			10: rank_name = "ten"
			11: rank_name = "jack"
			12: rank_name = "queen"
			13: rank_name = "king"
		
		var suit_name = ""
		match card_data.suit:
			CardData.Suit.SPADES: suit_name = "spades"
			CardData.Suit.HEARTS: suit_name = "hearts"
			CardData.Suit.CLUBS: suit_name = "clubs"
			CardData.Suit.DIAMONDS: suit_name = "diamonds"
		
		card_path += rank_name + "_of_" + suit_name + ".png"
	else:
		card_path += "pink_backing.png"
	
	# Load and set texture
	var texture = load(card_path)
	if texture:
		card_sprite.texture = texture
		card_sprite.visible = true
		card_sprite.modulate = Color.WHITE
		
		# DEBUG: Check CardSprite positioning for slot cards
		if board_index == -1:  # Slot card
			# FIX: Change %v to %s for the array
			print("SLOT CardSprite - size: %v, position: %v, anchors: %s" % [
				card_sprite.size, 
				card_sprite.position,
				[card_sprite.anchor_left, card_sprite.anchor_top, card_sprite.anchor_right, card_sprite.anchor_bottom]
			])
			print("SLOT Card main size: %v" % size)
			
			# FORCE CardSprite to fill the entire card
			card_sprite.position = Vector2.ZERO
			card_sprite.size = size  # Make it same size as the main card
			print("SLOT CardSprite AFTER force - size: %v, position: %v" % [card_sprite.size, card_sprite.position])

func _on_area_entered(area: Area2D) -> void:
	if not is_on_board:
		return
		
	var other_card = area.get_parent()
	if other_card and other_card.has_method("get_board_index") and other_card.is_on_board:
		if other_card.board_index > board_index:
			cards_blocking_me.append(other_card)
			_check_visibility()

func _on_area_exited(area: Area2D) -> void:
	if not is_on_board:
		return
		
	var other_card = area.get_parent()
	if other_card:
		cards_blocking_me.erase(other_card)
		_check_visibility()

func _check_visibility() -> void:
	# Skip if not a board card or already removed
	if board_index < 0 or not is_on_board:
		set_face_up(true)
		return
		
	# Bottom row is always visible
	if board_index >= 18:
		set_face_up(true)
		return
	
	# Clean up any invalid references
	var valid_blockers: Array[Node] = []
	for blocker in cards_blocking_me:
		if is_instance_valid(blocker) and blocker.is_on_board:
			valid_blockers.append(blocker)
	cards_blocking_me = valid_blockers
	
	# Check blocking status
	var is_blocked = not cards_blocking_me.is_empty()
	
	# EVEN rounds: All visible, but only unblocked are selectable
	if GameState.current_round % 2 == 0:
		set_face_up(true)  # Always visible
		update_selectability()  # But selectability depends on blocking
	else:
		# ODD rounds: Only visible when unblocked
		set_face_up(not is_blocked)

func remove_from_board() -> void:
	# Instead of destroying, just hide and disable
	is_on_board = false
	position = Vector2(-2000, -2000)  # Move far off screen
	z_index = -10
	
	# Disable collision
	if area_2d:
		area_2d.monitoring = false
		area_2d.monitorable = false
	
	# Disable input
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_board_index() -> int:
	return board_index

func set_face_up(face_up: bool) -> void:
	is_face_up = face_up
	if face_up:
		has_been_revealed = true
	_update_display()
	call_deferred("update_selectability")

func update_selectability() -> void:
	# Only selectable if on board, face up, and not blocked
	if is_face_up and board_index >= 0 and is_on_board:
		# Check if blocked by other cards
		var is_blocked = not cards_blocking_me.is_empty()
		
		# Can only select if not blocked AND is a valid move
		if not is_blocked:
			is_selectable = CardManager.get_valid_slot_for_card(card_data) != -1
		else:
			is_selectable = false
	else:
		is_selectable = false

func set_selectable(selectable: bool) -> void:
	is_selectable = selectable

func _on_mouse_entered() -> void:
	pass  # No hover effects

func _on_mouse_exited() -> void:
	pass  # No hover effects

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_face_up and is_selectable:
				SignalBus.card_selected.emit(self)
			elif is_face_up and not is_selectable:
				SignalBus.card_invalid_selected.emit(self)
				flash_invalid()

func flash_invalid() -> void:
	modulate = INVALID_TINT
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
