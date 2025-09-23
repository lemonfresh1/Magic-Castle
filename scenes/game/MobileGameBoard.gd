# MobileGameBoard.gd - Mobile-optimized game board (refactored)
# Path: res://Pyramids/scenes/game/MobileGameBoard.gd
# Last Updated: Refactored to use BoardLayoutManager for positioning

extends Control

# === SCENE REFERENCES ===
@onready var board_area: Control = $BoardArea  
@onready var cards_container: Control = $BoardArea/CardsContainer
@onready var left_draw_zone: Control = $BoardArea/LeftDrawZone
@onready var right_draw_zone: Control = $BoardArea/RightDrawZone

# === PRELOADS ===
var card_scene = preload("res://Pyramids/scenes/game/Card.tscn")
var mobile_topbar_scene = preload("res://Pyramids/scenes/ui/game_ui/MobileTopBar.tscn")

# === GAME STATE ===
var board_card_nodes: Array[Control] = []
var mobile_top_bar: Control = null

func _ready() -> void:
	_setup_mobile_layout()
	_setup_draw_zones()
	_connect_signals()
	CardManager.set_game_board(self)
	set_process_unhandled_key_input(true)
	set_process(true)
	
	# Setup BoardRenderer
	BoardRenderer.set_parent(self)
	BoardRenderer.apply_background()
	
	# DON'T auto-start anymore - wait for proper mode selection
	# GameState.start_new_game("single")  # REMOVED
	
	board_area.clip_contents = false
	cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Start game with selected mode
	_start_with_selected_mode()

func _start_with_selected_mode():
	var mode = GameModeManager.get_current_mode()
	
	if not mode or mode == "":
		print("Warning: No mode selected, defaulting to classic")
		GameModeManager.set_game_mode("classic", {})
	
	print("Starting game with mode: %s" % mode)
	
	# Check if this is multiplayer or solo
	var game_type = "single"
	if GameState and GameState.game_mode == "multi":
		game_type = "multi"
	elif MultiplayerManager and MultiplayerManager.game_in_progress:
		game_type = "multi"
	
	GameState.start_new_game(game_type)  # Pass correct type

func _process(_delta: float) -> void:
	# Let DrawZoneManager handle availability updates
	DrawZoneManager.update_availability()

func _setup_mobile_layout() -> void:
	# Create and add mobile top bar
	mobile_top_bar = mobile_topbar_scene.instantiate()
	add_child(mobile_top_bar)
	move_child(mobile_top_bar, 0)
	
	var screen_size = UIStyleManager.get_screen_size()
	
	# Use UIStyleManager dimensions for layout
	var top_bar_height = UIStyleManager.get_game_dimension("top_bar_height")
	
	# No gap between top bar and board area
	board_area.position = Vector2(0, top_bar_height)
	board_area.size = Vector2(screen_size.x, screen_size.y - top_bar_height)
	
	# Adjust cards container with proper spacing
	var margin = UIStyleManager.get_spacing("space_3")
	cards_container.position = Vector2(margin, margin)
	cards_container.size = Vector2(screen_size.x - margin * 2, board_area.size.y - margin * 2)
	
	# Ensure board area doesn't overlap with top bar
	board_area.z_index = 1
	cards_container.z_index = 2

func _setup_draw_zones() -> void:
	# Get zone positions from DrawZoneManager
	var zone_positions = DrawZoneManager.get_zone_positions(board_area.size)
	var zone_width = DrawZoneManager.get_zone_width()
	
	# Setup left zone
	if zone_positions.has("left"):
		var left_pos = zone_positions["left"]
		left_draw_zone.position = left_pos["position"]
		left_draw_zone.size = left_pos["size"]
		left_draw_zone.custom_minimum_size.x = zone_width
		left_draw_zone.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	
	# Setup right zone
	if zone_positions.has("right"):
		var right_pos = zone_positions["right"]
		right_draw_zone.position = right_pos["position"]
		right_draw_zone.size = right_pos["size"]
		right_draw_zone.custom_minimum_size.x = zone_width
		right_draw_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	
	# Let DrawZoneManager handle the rest
	DrawZoneManager.setup_draw_zones(left_draw_zone, right_draw_zone)

func _connect_signals() -> void:
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	SignalBus.reveal_all_cards.connect(_on_reveal_all_cards)
	
	# Connect to DrawZoneManager signals
	DrawZoneManager.draw_zone_clicked.connect(_on_draw_zone_clicked)
	DrawZoneManager.draw_zones_updated.connect(_on_draw_zones_updated)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			DrawZoneManager.trigger_draw_pile()
			get_viewport().set_input_as_handled()

func _trigger_draw_pile() -> void:
	"""Deprecated - use DrawZoneManager.trigger_draw_pile() instead"""
	DrawZoneManager.trigger_draw_pile()

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
	# Use BoardLayoutManager for positioning
	var positions = BoardLayoutManager.calculate_card_positions(cards_container.size, true)
	var scale_factor = BoardLayoutManager.get_card_scale_factor(cards_container.size, true)
	
	# Create cards
	for i in range(28):
		if i >= CardManager.board_cards.size():
			break
			
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		card.setup(CardManager.board_cards[i], i)
		card.position = positions[i]
		card.scale = Vector2(scale_factor, scale_factor)
		
		# Use BoardLayoutManager for collision setup
		if card.area_2d:
			card.z_index = BoardLayoutManager.get_z_index_for_card(i)
			card.area_2d.collision_layer = BoardLayoutManager.get_collision_layer_for_card(i)
			card.area_2d.collision_mask = BoardLayoutManager.get_collision_mask_for_card(i)
		
		board_card_nodes.append(card)
	
	# Let physics settle
	await get_tree().physics_frame
	await get_tree().physics_frame
	update_all_cards()

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
	
	# Always update slots after card selection
	if mobile_top_bar and mobile_top_bar.has_method("update_slots"):
		mobile_top_bar.update_slots()
	
	# Update remaining cards
	await get_tree().process_frame
	await get_tree().process_frame
	
	for other_card in board_card_nodes:
		if other_card and other_card.is_on_board:
			other_card._check_visibility()
			other_card.update_selectability()

func _on_draw_zone_clicked(zone_side: String) -> void:
	# DrawZoneManager already handles the draw pile trigger
	# Just update UI
	if mobile_top_bar and mobile_top_bar.has_method("update_slots"):
		await get_tree().process_frame
		mobile_top_bar.update_slots()

func _on_draw_zones_updated() -> void:
	# Draw zones configuration changed, update board layout
	_setup_draw_zones()
	
	if board_card_nodes.size() > 0:
		# Recalculate positions with new draw zone configuration
		var positions = BoardLayoutManager.calculate_card_positions(cards_container.size, true)
		var scale_factor = BoardLayoutManager.get_card_scale_factor(cards_container.size, true)
		
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
	
	# Update all cards selectability after drawing
	await get_tree().process_frame
	update_all_cards()

func _on_reveal_all_cards() -> void:
	"""Reveal all remaining cards on the board when score screen shows"""
	for card in board_card_nodes:
		if card and is_instance_valid(card) and card.is_on_board:
			# Only flip cards that are currently face down
			if not card.is_face_up:
				card.set_face_up(true)
