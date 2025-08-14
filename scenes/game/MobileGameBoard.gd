# MobileGameBoard.gd - Mobile-optimized game board
# Path: res://Pyramids/scenes/game/MobileGameBoard.gd
# Last Updated: Removed draw zone labels and debug output [Date]

extends Control

# === SCENE REFERENCES ===
@onready var board_area: Control = $BoardArea  
@onready var cards_container: Control = $BoardArea/CardsContainer
@onready var left_draw_zone: Control = $BoardArea/LeftDrawZone
@onready var right_draw_zone: Control = $BoardArea/RightDrawZone

# === PRELOADS ===
var card_scene = preload("res://Pyramids/scenes/game/Card.tscn")
var mobile_topbar_scene = preload("res://Pyramids/scenes/ui/game_ui/MobileTopBar.tscn")

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
	set_process(true)
	GameState.start_new_game("single")
	_apply_board_skin()
	SignalBus.board_skin_changed.connect(_apply_board_skin)
	board_area.clip_contents = false
	cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	# Update draw zone availability
	if CardManager:
		var cards_available = CardManager.draw_pile.size() > 0 and CardManager.cards_drawn < GameModeManager.get_draw_pile_limit(GameState.current_round)
		
		if left_draw_zone.visible:
			_update_draw_zone_state(left_draw_zone, cards_available)
		if right_draw_zone.visible:
			_update_draw_zone_state(right_draw_zone, cards_available)

func _update_draw_zone_state(zone: Control, available: bool) -> void:
	# Update background opacity based on availability
	var background = zone.get_node_or_null("Background")
	if background:
		if available:
			background.modulate.a = UIStyleManager.game_style.draw_zone_pulse_alpha_max
		else:
			background.modulate.a = 0.2

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
	# Get screen-proportional width from UIStyleManager
	var zone_width = UIStyleManager.get_game_dimension("draw_zone_width")
	
	# Configure draw zones based on settings
	left_draw_zone.visible = SettingsSystem.is_left_draw_enabled()
	right_draw_zone.visible = SettingsSystem.is_right_draw_enabled()

	# Ensure zones can receive mouse input
	left_draw_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	right_draw_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if left_draw_zone.visible:
		# Set size using proportional width
		left_draw_zone.custom_minimum_size.x = zone_width
		left_draw_zone.size.x = zone_width
		
		# Proper anchoring for left side
		left_draw_zone.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		left_draw_zone.position.x = 0
		left_draw_zone.size.x = zone_width
		left_draw_zone.size.y = board_area.size.y
		
		if not left_draw_zone.gui_input.is_connected(_on_left_draw_zone_input):
			left_draw_zone.gui_input.connect(_on_left_draw_zone_input)
			left_draw_zone.z_index = 5
		_setup_draw_zone_visual(left_draw_zone)
	
	if right_draw_zone.visible:
		# Set size using proportional width
		right_draw_zone.custom_minimum_size.x = zone_width
		right_draw_zone.size.x = zone_width
		
		# Proper anchoring for right side
		right_draw_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		right_draw_zone.position.x = board_area.size.x - zone_width
		right_draw_zone.size.x = zone_width
		right_draw_zone.size.y = board_area.size.y
		
		if not right_draw_zone.gui_input.is_connected(_on_right_draw_zone_input):
			right_draw_zone.gui_input.connect(_on_right_draw_zone_input)
			right_draw_zone.z_index = 5
		_setup_draw_zone_visual(right_draw_zone)

func _setup_draw_zone_visual(zone: Control) -> void:
	# Clear existing children first
	for child in zone.get_children():
		child.queue_free()
	
	# Add background panel with UIStyleManager styling
	var background = Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Apply draw zone style from UIStyleManager
	var style = UIStyleManager.apply_draw_zone_style(zone)
	background.add_theme_stylebox_override("panel", style)
	
	zone.add_child(background)
	
	# Add pulse animation if cards available
	var cards_available = CardManager.draw_pile.size() > 0 and CardManager.cards_drawn < GameModeManager.get_draw_pile_limit(GameState.current_round)
	
	if cards_available:
		# Create pulse animation
		var tween = zone.create_tween()
		tween.set_loops()
		tween.tween_property(background, "modulate:a", UIStyleManager.game_style.draw_zone_pulse_alpha_max, UIStyleManager.game_style.draw_zone_pulse_duration / 2)
		tween.tween_property(background, "modulate:a", UIStyleManager.game_style.draw_zone_pulse_alpha_min, UIStyleManager.game_style.draw_zone_pulse_duration / 2)

func _on_left_draw_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		UIStyleManager.animate_draw_zone_click(left_draw_zone)
		_trigger_draw_pile()

func _on_right_draw_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		UIStyleManager.animate_draw_zone_click(right_draw_zone)
		_trigger_draw_pile()

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
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	SignalBus.draw_pile_mode_changed.connect(_on_draw_pile_mode_changed)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_trigger_draw_pile()
			get_viewport().set_input_as_handled()

func _trigger_draw_pile() -> void:
	SignalBus.draw_pile_clicked.emit()
	
	# Force slot update after drawing
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
	
	_debug_card_sizes()


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
	
	# Update all cards selectability after drawing
	await get_tree().process_frame
	update_all_cards()

func _apply_board_skin() -> void:
	# Clear existing background
	if has_node("BackgroundNode"):
		get_node("BackgroundNode").queue_free()
		await get_tree().process_frame
	
	# NEW: Get equipped board from EquipmentManager
	var board_id = ""
	if EquipmentManager:
		var equipped = EquipmentManager.get_equipped_items()
		board_id = equipped.get("board", "board_green")  # Default to green
	
	# Get item data from ItemManager
	var board_item = ItemManager.get_item(board_id) if ItemManager else null
	
	if board_item and board_item is UnifiedItemData:
		_apply_item_background(board_item)
	else:
		# Fallback to legacy system
		_apply_legacy_background()

func _apply_item_background(item: UnifiedItemData) -> void:
	var bg_node: Node
	
	# Check for scene-based backgrounds FIRST (like Desert Pyramids)
	if item.background_scene_path and item.background_scene_path != "":
		if ResourceLoader.exists(item.background_scene_path):
			var scene = load(item.background_scene_path)
			bg_node = scene.instantiate()
		else:
			# Fallback to procedural if scene not found
			if item.is_procedural and ItemManager:
				var instance = ItemManager.get_procedural_instance(item.id)
				if instance and instance.has_method("draw_board_background"):
					bg_node = _create_procedural_board_background(item, instance)
				else:
					bg_node = _create_color_background(item)
			else:
				bg_node = _create_color_background(item)
	
	# Check for procedural backgrounds (like Arctic Aurora)
	elif item.is_procedural and ItemManager:
		var instance = ItemManager.get_procedural_instance(item.id)
		if instance and instance.has_method("draw_board_background"):
			bg_node = _create_procedural_board_background(item, instance)
		else:
			bg_node = _create_color_background(item)
	
	# Check for static texture backgrounds
	elif item.texture_path and item.texture_path != "":
		if ResourceLoader.exists(item.texture_path):
			var texture = load(item.texture_path)
			var rect = TextureRect.new()
			rect.texture = texture
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg_node = rect
		else:
			bg_node = _create_color_background(item)
	
	# Default to color background
	else:
		bg_node = _create_color_background(item)
	
	if bg_node:
		bg_node.name = "BackgroundNode"
		add_child(bg_node)
		move_child(bg_node, 0)
		if bg_node is Control:
			bg_node.z_index = -10
			if bg_node.has_method("set_anchors_and_offsets_preset"):
				bg_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _create_procedural_board_background(item: UnifiedItemData, instance) -> Control:
	"""Create a procedural board background"""
	var canvas = Control.new()
	canvas.name = "ProceduralBoardBG"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Store the instance
	canvas.set_meta("board_instance", instance)
	
	# Setup animation if needed
	if instance.get("is_animated"):
		var tween = create_tween()
		tween.set_loops()
		
		var duration = instance.get("animation_duration") if instance.get("animation_duration") else 6.0
		
		tween.tween_method(
			func(phase: float):
				instance.animation_phase = phase
				canvas.queue_redraw(),
			0.0,
			1.0,
			duration
		)
	
	# Connect draw callback
	canvas.draw.connect(func():
		if instance.has_method("draw_board_background"):
			instance.draw_board_background(canvas, canvas.size)
	)
	
	canvas.queue_redraw()
	return canvas

func _create_color_background(item: UnifiedItemData) -> ColorRect:
	var rect = ColorRect.new()
	# Use the color from item's colors dictionary, or fall back to green
	var color = item.colors.get("primary", Color(0.15, 0.4, 0.15))
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

func _apply_legacy_background() -> void:
	# Fallback for backwards compatibility
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
	
	var rect = ColorRect.new()
	rect.name = "BackgroundNode"
	rect.color = bg_color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.z_index = -10
	add_child(rect)
	move_child(rect, 0)

func _debug_card_sizes() -> void:
	print("=== CARD SIZE DEBUG ===")
	
	var scale_factor = _calculate_mobile_card_scale()
	print("Scale Factor: ", scale_factor)
	
	var container_size = cards_container.size
	print("Container: ", container_size.x, "x", container_size.y, "px")
	
	# Debug card #0 (first card)
	if board_card_nodes.size() > 0 and board_card_nodes[0]:
		var card_0 = board_card_nodes[0]
		var actual_size_0 = card_0.get_rect().size
		print("Card #0: ", actual_size_0.x, "x", actual_size_0.y, "px (base: ", MOBILE_CARD_WIDTH, "x", MOBILE_CARD_HEIGHT, "px)")
	else:
		print("Card #0: Not available")
	
	# Debug card #4 (fifth card)
	if board_card_nodes.size() > 4 and board_card_nodes[4]:
		var card_4 = board_card_nodes[4]
		var actual_size_4 = card_4.get_rect().size
		print("Card #4: ", actual_size_4.x, "x", actual_size_4.y, "px (base: ", MOBILE_CARD_WIDTH, "x", MOBILE_CARD_HEIGHT, "px)")
	else:
		print("Card #4: Not available")
	
	print("=== END CARD DEBUG ===")
