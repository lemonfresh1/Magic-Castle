# SwipePlayButton.gd - Works with existing ButtonLayout structure
extends Button

# Child nodes from ButtonLayout structure
var main_panel: PanelContainer
var margin_container: MarginContainer
var label: Label
var icon_node: TextureRect

# Additional elements we'll add
var hint_arrow: Label

# Swipe detection
var swipe_start_x: float = 0
var is_swiping: bool = false
var current_mode_index: int = 1  # Start with Solo (middle option)
var modes: Array = ["Multiplayer", "Solo", "Tournament"]

# Visual states
var swipe_threshold: float = 30.0
var is_pressed: bool = false

# Store styles
var mode_styles: Dictionary = {}

signal play_pressed(mode: String)
signal mode_changed(mode: String)

func _ready():
	# Get the existing ButtonLayout nodes
	main_panel = get_node_or_null("MainPanel")
	if main_panel:
		margin_container = main_panel.get_node_or_null("MarginContainer")
		if margin_container:
			icon_node = margin_container.get_node_or_null("Icon")
			label = margin_container.get_node_or_null("Label")
	
	# Add our custom elements TO THE EXISTING STRUCTURE
	_add_hint_arrow_to_panel()
	
	# Cache styles
	_cache_styles()
	
	# Set initial mode
	_update_mode_display()
	
	# Start hint animation
	_animate_hint_arrow()

func _add_hint_arrow_to_panel():
	"""Add the arrow INSIDE the existing MarginContainer"""
	if not main_panel:
		return
	
	if not margin_container:
		return
	
	# Create arrow as a sibling to Icon and Label
	hint_arrow = Label.new()
	hint_arrow.name = "HintArrow"
	hint_arrow.text = "→"
	hint_arrow.add_theme_font_size_override("font_size", 28)
	hint_arrow.add_theme_color_override("font_color", Color.WHITE)
	hint_arrow.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	hint_arrow.add_theme_constant_override("shadow_offset_x", 1)
	hint_arrow.add_theme_constant_override("shadow_offset_y", 1)
	hint_arrow.modulate.a = 0.6
	
	# Add to the existing MarginContainer
	margin_container.add_child(hint_arrow)

	# Use full rect with right alignment
	hint_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_arrow.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _cache_styles():
	"""Create styles for each mode - just store colors, not full styles"""
	for i in range(modes.size()):
		match modes[i]:
			"Multiplayer":
				mode_styles[modes[i]] = {
					"bg_color": Color("#E53935"),  # Red
					"border_color": Color("#C62828")
				}
			"Solo":
				mode_styles[modes[i]] = {
					"bg_color": UIStyleManager.get_color("primary") if UIStyleManager else Color("#10b981"),
					"border_color": UIStyleManager.get_color("primary_dark") if UIStyleManager else Color("#059669")
				}
			"Tournament":
				mode_styles[modes[i]] = {
					"bg_color": Color("#FFB300"),  # Gold
					"border_color": Color("#F57C00")
				}

func _animate_hint_arrow():
	"""Subtle pulsing animation for the arrow - keeps running forever"""
	if not hint_arrow:
		return
	
	var tween = create_tween()
	tween.set_loops()  # Infinite loop
	tween.tween_property(hint_arrow, "modulate:a", 0.8, 1.0)
	tween.tween_property(hint_arrow, "modulate:a", 0.4, 1.0)
	
	# Don't store the tween - let it run forever

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				swipe_start_x = event.position.x
				is_swiping = false
				is_pressed = true  # Changed: button_pressed -> is_pressed
				_on_press_start()
			else:
				if is_pressed:  # Changed: button_pressed -> is_pressed
					is_pressed = false  # Changed: button_pressed -> is_pressed
					if not is_swiping:
						_on_play_tapped()
					else:
						_snap_to_mode()
					is_swiping = false
	
	elif event is InputEventMouseMotion and is_pressed:  # Changed: button_pressed -> is_pressed
		var delta = event.position.x - swipe_start_x
		if abs(delta) > swipe_threshold:
			is_swiping = true
			_handle_swipe(delta)

func _handle_swipe(delta: float):
	# DON'T stop the animation or change opacity - let it keep pulsing
	# Just remove this entire block that was stopping the animation
	
	var swipe_progress = clamp(delta / 150.0, -1.0, 1.0)
	
	# Rest of the function stays the same...
	if icon_node:
		icon_node.rotation = swipe_progress * 0.15
	
	if main_panel:
		main_panel.scale.x = 1.0 + abs(swipe_progress) * 0.03
	
	if abs(swipe_progress) > 0.3:
		var preview_mode = current_mode_index
		if swipe_progress > 0:
			preview_mode = (current_mode_index + 1) % modes.size()
		else:
			preview_mode = (current_mode_index - 1) % modes.size()
			if preview_mode < 0:
				preview_mode = modes.size() - 1
		
		if label:
			label.text = modes[preview_mode]
			label.modulate.a = abs(swipe_progress)

func _snap_to_mode():
	var delta = icon_node.rotation / 0.15 if icon_node else 0
	
	if delta > 0.3:
		current_mode_index = (current_mode_index + 1) % modes.size()
		_animate_mode_change(1)
	elif delta < -0.3:
		current_mode_index = (current_mode_index - 1) % modes.size()
		if current_mode_index < 0:
			current_mode_index = modes.size() - 1
		_animate_mode_change(-1)
	else:
		_animate_snap_back()
	
	_update_mode_display()

func _animate_mode_change(direction: int):
	var tween = create_tween()
	tween.set_parallel(true)
	
	if icon_node:
		tween.tween_property(icon_node, "rotation", 0, 0.3)
	
	if main_panel:
		tween.tween_property(main_panel, "modulate", Color.WHITE * 1.3, 0.1)
		tween.chain().tween_property(main_panel, "modulate", Color.WHITE, 0.2)
	
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	
	if SettingsSystem and SettingsSystem.haptic_enabled:
		Input.vibrate_handheld(20)
	
	mode_changed.emit(modes[current_mode_index])

func _animate_snap_back():
	var tween = create_tween()
	tween.set_parallel(true)
	
	if icon_node:
		tween.tween_property(icon_node, "rotation", 0, 0.2)
	if main_panel:
		tween.tween_property(main_panel, "scale", Vector2.ONE, 0.2)
		tween.tween_property(main_panel, "modulate", Color.WHITE, 0.2)

func _update_mode_display():
	if label:
		label.text = modes[current_mode_index]
		label.modulate.a = 1.0
	
	# Update colors of EXISTING style, don't replace it
	if main_panel and mode_styles.has(modes[current_mode_index]):
		var existing_style = main_panel.get_theme_stylebox("panel")
		if existing_style and existing_style is StyleBoxFlat:
			var style = existing_style.duplicate() as StyleBoxFlat
			var colors = mode_styles[modes[current_mode_index]]
			style.bg_color = colors["bg_color"]
			style.border_color = colors["border_color"]
			# Keep all other properties (corner radius, shadows, etc) from original
			main_panel.add_theme_stylebox_override("panel", style)

func _on_play_tapped():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	play_pressed.emit(modes[current_mode_index])
	
	# Handle the actual game start
	match modes[current_mode_index]:
		"Solo":
			GameState.reset_game_completely()
			GameModeManager._load_current_mode()
			get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")
		"Multiplayer":
			print("TODO: Start Multiplayer")
		"Tournament":
			print("TODO: Start Tournament")

func _on_press_start():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.1)

func _input(event: InputEvent):
	# Keyboard controls for testing
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				print("Left key pressed")
				_simulate_swipe(-1)
			KEY_RIGHT:
				print("Right key pressed")
				_simulate_swipe(1)

func _simulate_swipe(direction: int):
	current_mode_index = (current_mode_index + direction) % modes.size()
	if current_mode_index < 0:
		current_mode_index = modes.size() - 1
	
	_animate_mode_change(direction)
	_update_mode_display()
	print("Simulated swipe to: " + modes[current_mode_index])
