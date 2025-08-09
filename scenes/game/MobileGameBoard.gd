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
	set_process(true)  # ADD THIS - Enable process for animations
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
	# Update the label to show availability
	var label = zone.get_node_or_null("Label")
	if label:
		if available:
			label.modulate.a = 1.0
		else:
			label.modulate.a = 0.3
	
	# Update background opacity
	var background = zone.get_node_or_null("Background")
	if background and not available:
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
		left_draw_zone.size.x = zone_width  # Force width after anchoring
		left_draw_zone.size.y = board_area.size.y
		
		if not left_draw_zone.gui_input.is_connected(_on_left_draw_zone_input):
			left_draw_zone.gui_input.connect(_on_left_draw_zone_input)
			left_draw_zone.z_index = 5  # ADD THIS - Above background, below cards
		_setup_draw_zone_visual(left_draw_zone, "⬅ TAP TO DRAW")
	
	if right_draw_zone.visible:
		# Set size using proportional width
		right_draw_zone.custom_minimum_size.x = zone_width
		right_draw_zone.size.x = zone_width
		
		# Proper anchoring for right side
		right_draw_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		right_draw_zone.position.x = board_area.size.x - zone_width
		right_draw_zone.size.x = zone_width  # Force width after anchoring
		right_draw_zone.size.y = board_area.size.y
		
		if not right_draw_zone.gui_input.is_connected(_on_right_draw_zone_input):
			right_draw_zone.gui_input.connect(_on_right_draw_zone_input)
			right_draw_zone.z_index = 5  # ADD THIS - Above background, below cards
		_setup_draw_zone_visual(right_draw_zone, "TAP TO DRAW ➡")

func _setup_draw_zone_visual(zone: Control, text: String) -> void:
	# Clear existing children first
	for child in zone.get_children():
		child.queue_free()
	
	# Add background panel with UIStyleManager styling
	var background = Panel.new()
	background.name = "Background"  # ADD NAME
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Apply draw zone style from UIStyleManager
	var style = UIStyleManager.apply_draw_zone_style(zone)
	background.add_theme_stylebox_override("panel", style)
	
	zone.add_child(background)
	
	# Add instructional label with UIStyleManager colors
	var label = Label.new()
	label.name = "Label"  # ADD NAME
	label.text = text
	label.rotation = PI / 2
	label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_caption"))
	label.add_theme_color_override("font_color", UIStyleManager.game_style.draw_zone_text_color)
	label.add_theme_color_override("font_shadow_color", UIStyleManager.get_color("gray_900"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(label)
	
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
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)  # ADD THIS
	SignalBus.draw_pile_mode_changed.connect(_on_draw_pile_mode_changed)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_trigger_draw_pile()
			get_viewport().set_input_as_handled()


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
	print("\n=== APPLYING BOARD SKIN ===")
	
	# Clear existing background
	if has_node("BackgroundNode"):
		print("  Removing existing background")
		get_node("BackgroundNode").queue_free()
		await get_tree().process_frame
	
	# Get the current equipped board from ItemManager
	var board_id = ItemManager.get_equipped_item(ItemData.Category.BOARD)
	print("  Equipped board ID: ", board_id)
	
	var board_item = ItemManager.get_item(board_id) if board_id else null
	
	# If no board equipped, use default
	if not board_item:
		print("  No board item found, using default")
		board_item = ItemManager.get_item("board_green")
	
	if board_item and board_item is ItemData:
		print("  Found board item: ", board_item.display_name)
		print("  - Background type: ", board_item.background_type)
		print("  - Scene path: ", board_item.background_scene_path)
		_apply_item_background(board_item)
	else:
		print("  Falling back to legacy system")
		# Fallback to legacy system
		_apply_legacy_background()

func _apply_item_background(item: ItemData) -> void:
	print("  _apply_item_background called")
	var bg_node: Node
	
	# Check for background type - it's a direct field, not in metadata!
	var bg_type = item.background_type  # Direct field access
	print("  Background type: ", bg_type)
	
	match bg_type:
		"scene":
			# Load animated scene from direct field
			var scene_path = item.background_scene_path  # Direct field access
			print("  Loading background scene from: ", scene_path)
			
			if scene_path and ResourceLoader.exists(scene_path):
				print("  Scene exists, loading...")
				var scene = load(scene_path)
				bg_node = scene.instantiate()
				print("  Successfully instantiated background scene!")
			else:
				print("  ERROR: Scene path not found or empty: ", scene_path)
				bg_node = _create_color_background(item)
				
		"sprite":
			print("  Loading sprite background")
			# Static sprite using texture_path
			if item.texture_path and ResourceLoader.exists(item.texture_path):
				var texture = load(item.texture_path)
				var rect = TextureRect.new()
				rect.texture = texture
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				bg_node = rect
			else:
				bg_node = _create_color_background(item)
				
		_:  # "color" or default
			print("  Using color background")
			bg_node = _create_color_background(item)
	
	if bg_node:
		print("  Adding background node to scene")
		bg_node.name = "BackgroundNode"
		add_child(bg_node)
		move_child(bg_node, 0)
		if bg_node is Control:
			bg_node.z_index = -10  # Ensure background is behind everything
			# If it's the pyramid scene, make sure it fills the screen
			if bg_node.has_method("set_anchors_and_offsets_preset"):
				bg_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		print("  Background added successfully!")
	else:
		print("  ERROR: No background node created!")
	
	print("========================\n")

func _create_color_background(item: ItemData) -> ColorRect:
	var rect = ColorRect.new()
	# Use the color from item's colors dictionary, or fall back to green
	var color = item.colors.get("primary", Color(0.15, 0.4, 0.15))
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

func _apply_legacy_background() -> void:
	# Your existing fallback code for backwards compatibility
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
	rect.z_index = -10  # ADD THIS - Ensure background is behind everything
	add_child(rect)
	move_child(rect, 0)
