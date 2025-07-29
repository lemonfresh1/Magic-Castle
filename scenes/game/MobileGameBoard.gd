# MobileGameBoard.gd - Mobile-optimized game board
# Path: res://Magic-Castle/scenes/game/MobileGameBoard.gd
extends Control

# === SCENE REFERENCES ===
@onready var board_area: Control = $BoardArea  
@onready var cards_container: Control = $BoardArea/CardsContainer
@onready var left_draw_zone: Control = $BoardArea/LeftDrawZone
@onready var right_draw_zone: Control = $BoardArea/RightDrawZone

# === PRELOADS ===
var card_scene = preload("res://Magic-Castle/scenes/game/Card.tscn")
var mobile_topbar_scene = preload("res://Magic-Castle/scenes/ui/game_ui/MobileTopBar.tscn")

# === MOBILE LAYOUT CONSTANTS ===
const MOBILE_CARD_WIDTH: int = 50
const MOBILE_CARD_HEIGHT: int = 70
const MOBILE_OVERLAP_Y: int = 25
const DRAW_ZONE_WIDTH: int = 80
const MIN_CARD_SPACING: int = 3

# === GAME STATE ===
var board_card_nodes: Array[Control] = []
var mobile_top_bar: Control = null

func _ready() -> void:
	_setup_mobile_layout()
	_setup_draw_zones()
	_connect_signals()
	CardManager.set_game_board(self)
	set_process_unhandled_key_input(true)
	GameState.start_new_game("single")
	_apply_board_skin()
	SignalBus.board_skin_changed.connect(_apply_board_skin)

func _setup_mobile_layout() -> void:
	# Create and add mobile top bar
	mobile_top_bar = mobile_topbar_scene.instantiate()
	add_child(mobile_top_bar)
	move_child(mobile_top_bar, 0)
	
	var screen_size = get_viewport().get_visible_rect().size
	
	# Give more space to top bar, reduce board by 10%
	board_area.position = Vector2(0, 140)  # Increased from 60
	board_area.size = Vector2(screen_size.x, (screen_size.y - 150) * 0.9)  # 10% smaller height
	
	# Adjust cards container accordingly
	cards_container.position = Vector2(10, 10)
	cards_container.size = Vector2(screen_size.x - 20, board_area.size.y - 20)

func _calculate_mobile_card_scale() -> float:
	var container_size = cards_container.size
	
	# Account for draw zones
	var available_width = container_size.x
	if SettingsSystem.is_left_draw_enabled() and not SettingsSystem.is_right_draw_enabled():
		available_width -= DRAW_ZONE_WIDTH
	elif SettingsSystem.is_right_draw_enabled() and not SettingsSystem.is_left_draw_enabled():
		available_width -= DRAW_ZONE_WIDTH
	elif SettingsSystem.is_left_draw_enabled() and SettingsSystem.is_right_draw_enabled():
		available_width -= DRAW_ZONE_WIDTH * 2
	
	# Calculate scale for mobile
	var max_card_width = (available_width - MIN_CARD_SPACING * 9) / 10
	var available_height = container_size.y - 40
	var total_height_needed = MOBILE_CARD_HEIGHT + (MOBILE_OVERLAP_Y * 3.5)
	
	var scale_factor = min(max_card_width / MOBILE_CARD_WIDTH, available_height / total_height_needed)
	scale_factor = clamp(scale_factor, 0.6, 1.5)
	
	return scale_factor

func _setup_draw_zones() -> void:
	# Configure draw zones based on settings
	left_draw_zone.visible = SettingsSystem.is_left_draw_enabled()
	right_draw_zone.visible = SettingsSystem.is_right_draw_enabled()

	# Ensure zones can receive mouse input
	left_draw_zone.mouse_filter = Control.MOUSE_FILTER_PASS  # ADD THIS
	right_draw_zone.mouse_filter = Control.MOUSE_FILTER_PASS  # ADD THIS
	
	if left_draw_zone.visible:
		left_draw_zone.custom_minimum_size.x = DRAW_ZONE_WIDTH
		if not left_draw_zone.gui_input.is_connected(_on_left_draw_zone_input):
			left_draw_zone.gui_input.connect(_on_left_draw_zone_input)
		_setup_draw_zone_visual(left_draw_zone, "⬅ TAP TO DRAW")
	
	if right_draw_zone.visible:
		right_draw_zone.custom_minimum_size.x = DRAW_ZONE_WIDTH
		if not right_draw_zone.gui_input.is_connected(_on_right_draw_zone_input):
			right_draw_zone.gui_input.connect(_on_right_draw_zone_input)
		_setup_draw_zone_visual(right_draw_zone, "TAP TO DRAW ➡")
	
	_adjust_board_layout()

func _setup_draw_zone_visual(zone: Control, text: String) -> void:
	# Add visual background
	var background = ColorRect.new()
	background.color = Color(0.2, 0.4, 0.6, 0.3)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ADD THIS
	zone.add_child(background)
	
	# Add instructional label
	var label = Label.new()
	label.text = text
	label.rotation = PI / 2
	label.add_theme_font_size_override("font_size", SettingsSystem.get_scaled_font_size(10))
	label.anchors_preset = Control.PRESET_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ADD THIS
	zone.add_child(label)

func _adjust_board_layout() -> void:
	var margin_left = 20 if left_draw_zone.visible else 5
	var margin_right = 20 if right_draw_zone.visible else 5
	
	cards_container.position.x = margin_left
	cards_container.position.y = 5
	cards_container.size.x = board_area.size.x - margin_left - margin_right
	cards_container.size.y = board_area.size.y - 10

func _connect_signals() -> void:
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)  # ADD THIS
	SignalBus.draw_pile_mode_changed.connect(_on_draw_pile_mode_changed)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_trigger_draw_pile()
			get_viewport().set_input_as_handled()

# === DRAW ZONE HANDLING ===
func _on_left_draw_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger_draw_pile()

func _on_right_draw_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger_draw_pile()

func _trigger_draw_pile() -> void:
	SignalBus.draw_pile_clicked.emit()
	
	# UPDATE: Force slot update after drawing
	if mobile_top_bar and mobile_top_bar.has_method("update_slots"):
		# Wait a frame for CardManager to process the draw
		await get_tree().process_frame
		mobile_top_bar.update_slots()

# === GAME BOARD MANAGEMENT ===
func _on_round_started(_round: int) -> void:
	clear_board()
	await get_tree().process_frame
	setup_mobile_board()
	
	if mobile_top_bar and mobile_top_bar.has_method("update_slots"):
		await get_tree().process_frame
		await get_tree().process_frame
		mobile_top_bar.update_slots()

func clear_board() -> void:
	for card in board_card_nodes:
		if card:
			card.queue_free()
	board_card_nodes.clear()

func setup_mobile_board() -> void:
	var positions = calculate_mobile_card_positions()
	var scale_factor = _calculate_mobile_card_scale()
	
	# Create cards
	for i in range(28):
		if i >= CardManager.board_cards.size():
			break
			
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		card.setup(CardManager.board_cards[i], i)
		card.position = positions[i]
		
		board_card_nodes.append(card)
	
	# Let physics settle
	await get_tree().physics_frame
	await get_tree().physics_frame
	update_all_cards()

func calculate_mobile_card_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var container_size = cards_container.size
	
	# Use larger fixed card size for better spacing
	var card_width = 80
	var card_height = 110
	var card_spacing = 20
	var row_overlap = card_height * 0.6
	
	# Center the pyramid both horizontally and vertically
	var total_width = card_width * 10 + card_spacing * 9
	var start_x = (container_size.x - total_width) / 2
	
	var pyramid_height = card_height + (row_overlap * 3)
	var start_y = (container_size.y - pyramid_height) / 2
	var base_y = start_y + pyramid_height - card_height
	
	# Initialize positions array
	for i in range(28):
		positions.append(Vector2.ZERO)
	
	# Bottom row (10 cards) - indices 18-27
	for i in range(10):
		var x = start_x + i * (card_width + card_spacing)
		positions[18 + i] = Vector2(x, base_y)
	
	# Row 2 (9 cards) - indices 9-17
	var row2_start_x = start_x + (card_width + card_spacing) / 2
	for i in range(9):
		var x = row2_start_x + i * (card_width + card_spacing)
		positions[9 + i] = Vector2(x, base_y - row_overlap)
	
	# Row 3 (6 cards) - indices 3-8
	var row3_start_x = row2_start_x + (card_width + card_spacing) / 2
	var row3_indices = [0, 1, 3, 4, 6, 7]
	for i in range(6):
		var x = row3_start_x + row3_indices[i] * (card_width + card_spacing)
		positions[3 + i] = Vector2(x, base_y - row_overlap * 2)
	
	# Top row (3 cards - peaks) - indices 0-2
	var row4_start_x = row3_start_x + (card_width + card_spacing) / 2
	var peak_indices = [0, 3, 6]
	for i in range(3):
		var x = row4_start_x + peak_indices[i] * (card_width + card_spacing)
		positions[i] = Vector2(x, base_y - row_overlap * 3)
	
	return positions

func update_all_cards() -> void:
	for card in board_card_nodes:
		if card and card.is_on_board:
			card._check_visibility()
			card.update_selectability()

func _on_card_selected(card: Control) -> void:
	# Remove from board
	var index = board_card_nodes.find(card)
	if index != -1:
		board_card_nodes[index] = null
		card.remove_from_board()
	
	# UPDATE: Always update slots after card selection
	if mobile_top_bar and mobile_top_bar.has_method("update_slots"):
		mobile_top_bar.update_slots()
	
	# Update remaining cards
	await get_tree().process_frame
	await get_tree().process_frame
	
	for other_card in board_card_nodes:
		if other_card and other_card.is_on_board:
			other_card._check_visibility()
			other_card.update_selectability()

func _on_draw_pile_mode_changed(mode: int) -> void:
	_setup_draw_zones()
	_adjust_board_layout()
	
	if board_card_nodes.size() > 0:
		var positions = calculate_mobile_card_positions()
		var scale_factor = _calculate_mobile_card_scale()
		
		for i in range(board_card_nodes.size()):
			var card = board_card_nodes[i]
			if card and card.is_on_board:
				card.position = positions[i]
				card.scale = Vector2(scale_factor, scale_factor)

func _on_draw_pile_clicked() -> void:
	# Force slot update after draw pile action
	if mobile_top_bar and mobile_top_bar.has_method("update_slots"):
		await get_tree().process_frame
		mobile_top_bar.update_slots()
	
	# CRITICAL: Update all cards selectability after drawing
	await get_tree().process_frame
	update_all_cards()

func _apply_board_skin() -> void:
	# First try to load a sprite background
	var sprite_path = "res://Magic-Castle/assets/backgrounds/%s-bg.png" % SettingsSystem.current_board_skin
	
	if ResourceLoader.exists(sprite_path):
		# Use sprite background
		var texture = load(sprite_path)
		
		# Create or update background TextureRect
		var bg_sprite: TextureRect
		if has_node("BackgroundSprite"):
			bg_sprite = get_node("BackgroundSprite")
		else:
			bg_sprite = TextureRect.new()
			bg_sprite.name = "BackgroundSprite"
			add_child(bg_sprite)
			move_child(bg_sprite, 0)  # Put at back
		
		bg_sprite.texture = texture
		bg_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	else:
		# Fall back to color
		var bg_color: Color
		match SettingsSystem.current_board_skin:
			"green":
				bg_color = Color(0.15, 0.4, 0.15)
			"blue":
				bg_color = Color(0.15, 0.25, 0.5)
			"sunset":
				bg_color = Color(0.6, 0.3, 0.15)
			_:
				bg_color = Color(0.2, 0.2, 0.2)
		
		if has_node("Background"):
			var bg = get_node("Background")
			if bg is ColorRect:
				bg.color = bg_color
		else:
			RenderingServer.set_default_clear_color(bg_color)
