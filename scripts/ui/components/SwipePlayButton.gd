# SwipePlayButton.gd - Works with existing ButtonLayout structure
extends Button

# Child nodes from ButtonLayout structure
var main_panel: PanelContainer
var margin_container: MarginContainer
var label: Label
var icon_node: TextureRect

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
	
	# Load saved preference
	var saved_mode = SettingsSystem.get_preferred_play_mode()
	current_mode_index = modes.find(saved_mode)
	if current_mode_index == -1:
		current_mode_index = 1  # Default to Solo if not found
	
	# Add our custom elements
	_add_mode_dots()
	
	# Cache styles
	_cache_styles()
	
	# IMPORTANT: Apply the correct initial color based on saved mode
	# This needs to happen AFTER the button gets styled by UIStyleManager
	await get_tree().process_frame  # Wait for UIStyleManager to apply initial style
	
	# Set initial mode and apply correct color
	_update_mode_display()

func _cache_styles():
	"""Create styles for each mode - just store colors, not full styles"""
	for i in range(modes.size()):
		match modes[i]:
			"Multiplayer":
				mode_styles[modes[i]] = {
					"bg_color": UIStyleManager.get_color("play_multiplayer"),
					"border_color": UIStyleManager.get_color("play_multiplayer_dark")
				}
			"Solo":
				mode_styles[modes[i]] = {
					"bg_color": UIStyleManager.get_color("play_solo"),
					"border_color": UIStyleManager.get_color("play_solo_dark")
				}
			"Tournament":
				mode_styles[modes[i]] = {
					"bg_color": UIStyleManager.get_color("play_tournament"),
					"border_color": UIStyleManager.get_color("play_tournament_dark")
				}

func _add_mode_dots():
	"""Add dots at the Button level (root), outside MainPanel"""
	# Create container for dots
	var dots_container = HBoxContainer.new()
	dots_container.name = "DotsContainer"
	dots_container.add_theme_constant_override("separation", 6)
	dots_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to self (the Button root), not MainPanel
	add_child(dots_container)
	
	# Set anchors for bottom center
	dots_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	
	# Adjust position - KEEPING YOUR VALUES
	dots_container.position.y = -2  # Move up 2px from bottom anchor
	dots_container.position.x = -7  # Center adjustment for 3 dots
	
	# Make sure it's inside the button bounds
	dots_container.z_index = 1  # Above the panel
	
	# Create dots
	for i in modes.size():
		var dot = Label.new()
		dot.name = "Dot%d" % i
		dot.text = "•"  # Bullet character
		dot.add_theme_font_size_override("font_size", 12)
		dot.add_theme_color_override("font_color", Color.WHITE)
		dot.modulate.a = 0.4 if i != current_mode_index else 1.0
		dots_container.add_child(dot)
	
	# Store reference for updates
	set_meta("dots_container", dots_container)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				swipe_start_x = event.position.x
				is_swiping = false
				is_pressed = true
				_on_press_start()
			else:
				if is_pressed:
					is_pressed = false
					if not is_swiping:
						_on_play_tapped()
					else:
						_snap_to_mode()
					is_swiping = false
	
	elif event is InputEventMouseMotion and is_pressed:
		var delta = event.position.x - swipe_start_x
		if abs(delta) > swipe_threshold:
			is_swiping = true
			_handle_swipe(delta)

func _handle_swipe(delta: float):
	var swipe_progress = clamp(delta / 150.0, -1.0, 1.0)
	
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
	
	# Save the new preference
	SettingsSystem.set_preferred_play_mode(modes[current_mode_index])
	
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
	
	# Update colors of EXISTING style
	if main_panel and mode_styles.has(modes[current_mode_index]):
		var existing_style = main_panel.get_theme_stylebox("panel")
		if existing_style and existing_style is StyleBoxFlat:
			var style = existing_style.duplicate() as StyleBoxFlat
			var colors = mode_styles[modes[current_mode_index]]
			style.bg_color = colors["bg_color"]
			style.border_color = colors["border_color"]
			main_panel.add_theme_stylebox_override("panel", style)
	
	# Update dots
	if has_meta("dots_container"):
		var dots_container = get_meta("dots_container")
		for i in dots_container.get_child_count():
			var dot = dots_container.get_child(i)
			dot.modulate.a = 0.4 if i != current_mode_index else 1.0

func _on_play_tapped():
	# Visual feedback
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Just emit the signal - MainMenu will handle navigation
	play_pressed.emit(modes[current_mode_index])
	
	# Optional: haptic feedback
	if SettingsSystem and SettingsSystem.haptic_enabled:
		Input.vibrate_handheld(20)

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
