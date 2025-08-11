#Card.gd
# Path: res://Pyramids/scenes/game/Card.gd
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
	
	# Check if we should use sprites or programmatic display
	if SettingsSystem.current_card_skin == "sprites":
		# Use existing sprite logic
		var card_path = "res://Pyramids/assets/cards/"
		
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
				# FORCE CardSprite to fill the entire card
				card_sprite.position = Vector2.ZERO
				card_sprite.size = size  # Make it same size as the main card
	else:
		# Programmatic card display
		card_sprite.visible = false
		
		# Defer creation to avoid "busy setting up children" error
		if not has_node("CardBG"):
			call_deferred("_create_programmatic_card")
		else:
			# Update existing card
			_update_programmatic_card()

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
			var is_blocked = not cards_blocking_me.is_empty()
			
			if is_blocked:
				# Card is blocked - just flash, no penalty
				flash_invalid()
				return
			
			# Card is unblocked, check if valid move
			if is_selectable:
				SignalBus.card_selected.emit(self)
			else:
				# Unblocked but wrong value - this gets the penalty
				SignalBus.card_invalid_selected.emit(self)
				flash_invalid()

func flash_invalid() -> void:
	modulate = INVALID_TINT
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

func _create_programmatic_card() -> void:
	# Create background
	var bg = Panel.new()
	bg.name = "CardBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE if is_face_up else Color(0.8, 0.2, 0.4)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	bg.add_theme_stylebox_override("panel", style)
	
	add_child(bg)
	move_child(bg, 0)
	
	# Create labels
	var rank_label = Label.new()
	rank_label.name = "RankLabel"
	rank_label.position = Vector2(10, 10)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rank_label)
	
	var suit_label = Label.new()
	suit_label.name = "SuitLabel"
	suit_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	suit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(suit_label)
	
	# Update the card display
	_update_programmatic_card()
	
func _update_programmatic_card() -> void:
	# Update background color
	if has_node("CardBG"):
		var bg = get_node("CardBG")
		var style = bg.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = Color.WHITE if is_face_up else Color(0.8, 0.2, 0.4)
	
	# Update labels if face up
	if is_face_up:
		var rank_label = get_node_or_null("RankLabel")
		var suit_label = get_node_or_null("SuitLabel")
		
		if rank_label and suit_label:
			# Set rank text
			var rank_text = ""
			match card_data.rank:
				1: rank_text = "A"
				11: rank_text = "J"
				12: rank_text = "Q"
				13: rank_text = "K"
				_: rank_text = str(card_data.rank)
			rank_label.text = rank_text
			
			# Set suit text and color
			var suit_text = ""
			var card_color = Color.BLACK
			match card_data.suit:
				CardData.Suit.HEARTS:
					suit_text = "♥"
					card_color = Color.RED if not SettingsSystem.high_contrast else Color(0.92, 0.28, 0.28)  # Nice red
				CardData.Suit.DIAMONDS:
					suit_text = "♦"
					card_color = Color.RED if not SettingsSystem.high_contrast else Color(0.56, 0.82, 0.52)  # Godot-style green (#8ed084)
				CardData.Suit.CLUBS:
					suit_text = "♣"
					card_color = Color.BLACK if not SettingsSystem.high_contrast else Color(0.28, 0.55, 0.75)  # Godot-style blue (#478cbf)
				CardData.Suit.SPADES:
					suit_text = "♠"
					card_color = Color.BLACK if not SettingsSystem.high_contrast else Color(0.2, 0.2, 0.2)  # Dark gray
						
			suit_label.text = suit_text
			rank_label.modulate = card_color
			suit_label.modulate = card_color
			
			# Apply font sizes
			var font_size = 32
			match SettingsSystem.current_card_skin:
				"modern": font_size = 36
				"retro": font_size = 28
			
			rank_label.add_theme_font_size_override("font_size", font_size)
			suit_label.add_theme_font_size_override("font_size", font_size + 4)
			
			rank_label.visible = true
			suit_label.visible = true
		else:
			# Labels don't exist yet, create them next frame
			call_deferred("_update_programmatic_card")
	else:
		# Hide labels when face down
		if has_node("RankLabel"):
			get_node("RankLabel").visible = false
		if has_node("SuitLabel"):
			get_node("SuitLabel").visible = false
