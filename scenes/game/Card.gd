# Card.gd - Individual playing card for the game board and slots
# Location: res://Pyramids/scenes/game/Card.gd
# Last Updated: Refactored to use new equipment system, simplified display flow [Date]
#
# Card handles:
# - Displaying card front/back with sprites or procedural rendering
# - Managing card state (face up/down, selectable, blocked)
# - Animating procedural card designs
# - Collision detection for pyramid layout
# - Input handling for card selection
#
# Flow: CardManager → Card → EquipmentManager (for skins) → ItemManager (for procedural instances)
# Dependencies: CardData (for rank/suit), EquipmentManager (equipped items), ItemManager (procedural instances), CardManager (game logic)

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

# Animation support
var current_card_back_instance = null
var current_card_front_instance = null

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
	
	# Set sizes
	if index == -1:  # Slot card
		position = Vector2.ZERO
		custom_minimum_size = Vector2(80, 110)
		size = Vector2(80, 110)
		
		if card_sprite:
			card_sprite.position = Vector2.ZERO
			card_sprite.size = Vector2(80, 110)
			card_sprite.custom_minimum_size = Vector2(80, 110)
	else:  # Board card
		custom_minimum_size = Vector2(90, 126)
		size = Vector2(90, 126)
		
		if card_sprite:
			card_sprite.custom_minimum_size = Vector2(90, 126)
			card_sprite.size = Vector2(90, 126)
	
	# Setup collision for board cards
	if index >= 0 and area_2d:
		is_on_board = true
		_setup_collision_layers(index)
		
		# Set initial visibility
		if GameState.current_round % 2 == 0:  # EVEN rounds
			is_face_up = true
			has_been_revealed = true
		else:  # ODD rounds
			is_face_up = (index >= 18)
			has_been_revealed = is_face_up
		
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check_visibility()
	else:
		# Slot cards
		is_face_up = true
		is_on_board = false
		z_index = 25
		if area_2d:
			area_2d.monitoring = false
			area_2d.monitorable = false
	
	_update_display()

func _setup_collision_layers(index: int) -> void:
	"""Setup collision layers based on card position"""
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
	else:  # Top row
		z_index = 1
		area_2d.collision_layer = 8
		area_2d.collision_mask = 4

func _update_display() -> void:
	"""Main display update - routes to front or back"""
	if not card_data:
		return
	
	# Clean up old canvases
	_cleanup_canvases()
	
	if is_face_up:
		_display_card_front()
	else:
		_display_card_back()

func _cleanup_canvases() -> void:
	"""Hide and stop animations on procedural canvases"""
	var front_canvas = get_node_or_null("ProceduralCardFront")
	if front_canvas:
		front_canvas.visible = false
	
	var back_canvas = get_node_or_null("ProceduralCardBack")
	if back_canvas:
		back_canvas.visible = false
	
	# Kill old animation tween
	if has_meta("anim_tween"):
		var old_tween = get_meta("anim_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()

func _display_card_front() -> void:
	"""Display the card front"""
	# Check for equipped custom front
	var equipped_id = ""
	if EquipmentManager:
		var equipped = EquipmentManager.get_equipped_items()
		equipped_id = equipped.get("card_front", "")
	
	# Try procedural/animated
	if equipped_id and ItemManager:
		var instance = ItemManager.get_procedural_instance(equipped_id)
		if instance and instance.has_method("draw_card_front"):
			_setup_procedural_front(instance)
			return
	
	# Fallback to default
	if SettingsSystem.current_card_skin == "sprites":
		_apply_sprite_card_front()
	else:
		_apply_programmatic_card_front()

func _display_card_back() -> void:
	"""Display the card back"""
	# Check for equipped custom back
	var equipped_id = ""
	if EquipmentManager:
		var equipped = EquipmentManager.get_equipped_items()
		equipped_id = equipped.get("card_back", "")
	
	# Try procedural/animated
	if equipped_id and ItemManager:
		var instance = ItemManager.get_procedural_instance(equipped_id)
		if instance and instance.has_method("draw_card_back"):
			_setup_procedural_back(instance)
			return
		
		# Try static texture
		var item = ItemManager.get_item(equipped_id)
		if item and item.texture_path and ResourceLoader.exists(item.texture_path):
			card_sprite.texture = load(item.texture_path)
			card_sprite.visible = true
			return
	
	# Fallback to default
	_apply_default_card_back()

func _setup_procedural_front(instance) -> void:
	"""Setup procedural front with animation"""
	current_card_front_instance = instance
	card_sprite.visible = false
	
	# Create or get canvas
	var canvas = get_node_or_null("ProceduralCardFront")
	if not canvas:
		canvas = Control.new()
		canvas.name = "ProceduralCardFront"
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(canvas)
		move_child(canvas, 0)
	
	# Store references
	canvas.set_meta("instance", instance)
	canvas.set_meta("card_data", card_data)
	
	# Setup animation if needed
	if instance.get("is_animated"):
		_setup_animation(instance, true)
	
	# Connect draw
	if not canvas.draw.is_connected(_on_procedural_front_draw):
		canvas.draw.connect(_on_procedural_front_draw)
	
	canvas.visible = true
	canvas.queue_redraw()

func _setup_procedural_back(instance) -> void:
	"""Setup procedural back with animation"""
	current_card_back_instance = instance
	card_sprite.visible = false
	
	# Create or get canvas
	var canvas = get_node_or_null("ProceduralCardBack")
	if not canvas:
		canvas = Control.new()
		canvas.name = "ProceduralCardBack"
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(canvas)
		move_child(canvas, 0)
	
	# Store reference
	canvas.set_meta("instance", instance)
	
	# Setup animation if needed
	if instance.get("is_animated"):
		_setup_animation(instance, false)
	
	# Connect draw
	if not canvas.draw.is_connected(_on_procedural_back_draw):
		canvas.draw.connect(_on_procedural_back_draw)
	
	canvas.visible = true
	canvas.queue_redraw()

func _setup_animation(instance, is_front: bool) -> void:
	"""Setup animation tween for procedural items"""
	# Kill old tween
	if has_meta("anim_tween"):
		var old_tween = get_meta("anim_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	
	# Create animation tween
	var tween = create_tween()
	tween.set_loops()
	
	var duration = instance.get("animation_duration") if instance.get("animation_duration") else 2.0
	var canvas_name = "ProceduralCardFront" if is_front else "ProceduralCardBack"
	
	tween.tween_method(
		func(phase: float):
			instance.animation_phase = phase
			var canvas = get_node_or_null(canvas_name)
			if canvas and canvas.visible:
				canvas.queue_redraw(),
		0.0,
		1.0,
		duration
	)
	
	set_meta("anim_tween", tween)

func _on_procedural_front_draw() -> void:
	"""Draw callback for procedural fronts"""
	var canvas = get_node("ProceduralCardFront")
	var instance = canvas.get_meta("instance")
	var data = canvas.get_meta("card_data")
	
	if instance and data:
		var rank_str = _get_rank_string(data.rank)
		instance.draw_card_front(canvas, size, rank_str, data.suit)

func _on_procedural_back_draw() -> void:
	"""Draw callback for procedural backs"""
	var canvas = get_node("ProceduralCardBack")
	var instance = canvas.get_meta("instance")
	
	if instance:
		instance.draw_card_back(canvas, size)

func _get_rank_string(rank_value: int) -> String:
	"""Convert numeric rank to display string"""
	match rank_value:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank_value)

func _apply_sprite_card_front() -> void:
	"""Apply traditional sprite-based card front"""
	var rank_name = ["", "ace", "two", "three", "four", "five", "six", 
					"seven", "eight", "nine", "ten", "jack", "queen", "king"][card_data.rank]
	
	var suit_name = ["spades", "hearts", "clubs", "diamonds"][card_data.suit]
	
	var card_path = "res://Pyramids/assets/cards/%s_of_%s.png" % [rank_name, suit_name]
	
	var texture = load(card_path)
	if texture:
		card_sprite.texture = texture
		card_sprite.visible = true
		card_sprite.modulate = Color.WHITE

func _apply_programmatic_card_front() -> void:
	"""Apply programmatic card front"""
	card_sprite.visible = false
	
	if not has_node("CardBG"):
		call_deferred("_create_programmatic_card")
	else:
		_update_programmatic_card()

func _apply_default_card_back() -> void:
	"""Apply the default card back"""
	var canvas = get_node_or_null("ProceduralCardBack")
	if canvas:
		canvas.visible = false
	
	if SettingsSystem.current_card_skin == "sprites":
		card_sprite.texture = load("res://Pyramids/assets/cards/pink_backing.png")
		card_sprite.visible = true
		card_sprite.modulate = Color.WHITE
	else:
		# Programmatic back
		card_sprite.visible = false
		if not has_node("CardBG"):
			call_deferred("_create_programmatic_card")

func set_face_up(face_up: bool) -> void:
	is_face_up = face_up
	if face_up:
		has_been_revealed = true
	_update_display()
	call_deferred("update_selectability")

func remove_from_board() -> void:
	"""Remove card from board"""
	is_on_board = false
	position = Vector2(-2000, -2000)
	z_index = -10
	
	if area_2d:
		area_2d.monitoring = false
		area_2d.monitorable = false
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Clean up animations
	_cleanup_canvases()

# === COLLISION & VISIBILITY ===
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
	if board_index < 0 or not is_on_board:
		set_face_up(true)
		return
	
	if board_index >= 18:
		set_face_up(true)
		return
	
	# Clean invalid blockers
	cards_blocking_me = cards_blocking_me.filter(func(b): return is_instance_valid(b) and b.is_on_board)
	
	var is_blocked = not cards_blocking_me.is_empty()
	
	if GameState.current_round % 2 == 0:
		set_face_up(true)
		update_selectability()
	else:
		set_face_up(not is_blocked)

func update_selectability() -> void:
	if is_face_up and board_index >= 0 and is_on_board:
		var is_blocked = not cards_blocking_me.is_empty()
		if not is_blocked:
			is_selectable = CardManager.get_valid_slot_for_card(card_data) != -1
		else:
			is_selectable = false
	else:
		is_selectable = false

# === INPUT ===
func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	pass

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var is_blocked = not cards_blocking_me.is_empty()
		
		if is_blocked:
			flash_invalid()
			return
		
		if is_selectable:
			SignalBus.card_selected.emit(self)
		else:
			SignalBus.card_invalid_selected.emit(self)
			flash_invalid()

func flash_invalid() -> void:
	modulate = INVALID_TINT
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

# === PROGRAMMATIC CARDS ===
func _create_programmatic_card() -> void:
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
	
	if is_face_up:
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
	
	_update_programmatic_card()

func _update_programmatic_card() -> void:
	if not is_face_up:
		if has_node("RankLabel"):
			get_node("RankLabel").visible = false
		if has_node("SuitLabel"):
			get_node("SuitLabel").visible = false
		return
	
	var rank_label = get_node_or_null("RankLabel")
	var suit_label = get_node_or_null("SuitLabel")
	
	if not rank_label or not suit_label:
		call_deferred("_update_programmatic_card")
		return
	
	rank_label.text = _get_rank_string(card_data.rank)
	
	var suit_symbols = ["♠", "♥", "♣", "♦"]
	suit_label.text = suit_symbols[card_data.suit]
	
	var color = Color.BLACK if card_data.suit in [0, 2] else Color.RED
	rank_label.modulate = color
	suit_label.modulate = color
	
	rank_label.add_theme_font_size_override("font_size", 32)
	suit_label.add_theme_font_size_override("font_size", 36)
	
	rank_label.visible = true
	suit_label.visible = true

func get_board_index() -> int:
	return board_index

func set_selectable(selectable: bool) -> void:
	is_selectable = selectable
