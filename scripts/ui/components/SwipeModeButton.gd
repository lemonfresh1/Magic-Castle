# SwipeModeButton.gd - Swipeable mode selector for multiplayer
# Location: res://Pyramids/scripts/ui/components/SwipeModeButton.gd
# Last Updated: Changed modes to Classic, Rush, Test [Date]

extends Button

# Available modes for multiplayer (matching single player options)
var modes: Array = ["Classic", "Rush", "Test"]  # Display names
var mode_ids: Array = ["classic", "timed_rush", "test"]  # Actual IDs for colors and GameModeManager
var current_mode_index: int = 0

# Child nodes (created programmatically)
var main_panel: PanelContainer
var label: Label

# Swipe detection
var swipe_start_x: float = 0
var is_swiping: bool = false
var swipe_threshold: float = 30.0
var is_pressed: bool = false

signal mode_changed(mode: String)
signal mode_id_changed(mode_id: String)  # New signal with actual ID

func _ready():
	# Create button structure programmatically
	focus_mode = Control.FOCUS_NONE 
	_create_button_structure()
	
	# Load saved preference if any (check MultiplayerManager first)
	var saved_mode = "Classic"
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		var saved_mode_id = mp_manager.get_selected_mode()
		var idx = mode_ids.find(saved_mode_id)
		if idx != -1:
			current_mode_index = idx
			saved_mode = modes[idx]
	else:
		current_mode_index = modes.find(saved_mode)
		if current_mode_index == -1:
			current_mode_index = 0
	
	# Add dots
	_add_mode_dots()
	
	# Set initial display
	_update_mode_display()

func _create_button_structure():
	"""Create the button's internal structure programmatically"""
	# Clear any existing children first
	for child in get_children():
		child.queue_free()
	
	# Set button properties
	flat = true  # Make button flat so panel shows through
	custom_minimum_size = Vector2(200, 60)  # Match other button heights
	
	# Main panel
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_panel)
	
	# Apply panel style - use mode color for initial mode
	var panel_style = StyleBoxFlat.new()
	var initial_color = UIStyleManager.get_mode_color(mode_ids[0], "primary") if UIStyleManager else Color(0.4, 0.7, 0.9)
	panel_style.bg_color = initial_color
	panel_style.border_color = initial_color.darkened(0.2)
	panel_style.set_border_width_all(UIStyleManager.borders.width_thin if UIStyleManager else 2)
	panel_style.set_corner_radius_all(12)  # Match the rounded buttons below
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Margin container
	var margin_container = MarginContainer.new()
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	main_panel.add_child(margin_container)
	
	# Label
	label = Label.new()
	label.name = "Label"
	label.text = "Mode: " + modes[0]
	label.add_theme_color_override("font_color", Color.WHITE)  # White text on colored background
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_child(label)

func _add_mode_dots():
	"""Add indicator dots at bottom - auto-centered for any number"""
	var dots_container = HBoxContainer.new()
	dots_container.name = "DotsContainer"
	dots_container.add_theme_constant_override("separation", 6)
	dots_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots_container.alignment = BoxContainer.ALIGNMENT_CENTER  # Auto-center!
	add_child(dots_container)
	
	# Create dots
	for i in modes.size():
		var dot = Label.new()
		dot.text = "•"
		dot.add_theme_font_size_override("font_size", 16)
		dot.add_theme_color_override("font_color", UIStyleManager.colors.gray_600 if UIStyleManager else Color.WHITE)
		dot.modulate.a = 0.4 if i != current_mode_index else 1.0
		dots_container.add_child(dot)
	
	# Position at bottom center - container handles X centering automatically
	dots_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dots_container.anchor_left = 0.5
	dots_container.anchor_right = 0.5
	dots_container.position.y = 37  # Negative to go up from bottom anchor
	dots_container.position.x = -10  # No X offset needed - anchors handle it
	dots_container.z_index = 10
	
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
						# Simple tap - cycle mode
						_cycle_mode()
					else:
						_snap_to_mode()
					is_swiping = false
	
	elif event is InputEventMouseMotion and is_pressed:
		var delta = event.position.x - swipe_start_x
		if abs(delta) > swipe_threshold:
			is_swiping = true
			_handle_swipe(delta)

func _handle_swipe(delta: float):
	"""Handle swipe gesture with visual feedback"""
	var swipe_progress = clamp(delta / 150.0, -1.0, 1.0)
	
	# Visual feedback on panel
	if main_panel:
		main_panel.scale.x = 1.0 + abs(swipe_progress) * 0.03
		main_panel.set_meta("swipe_progress", swipe_progress)
	
	# Preview next mode
	if abs(swipe_progress) > 0.3:
		var preview_index = current_mode_index
		if swipe_progress > 0:
			preview_index = (current_mode_index + 1) % modes.size()
		else:
			preview_index = (current_mode_index - 1 + modes.size()) % modes.size()
		
		if label:
			label.text = "Mode: " + modes[preview_index]
			label.modulate.a = 0.5 + abs(swipe_progress) * 0.5

func _snap_to_mode():
	"""Complete the swipe action"""
	var swipe_progress = main_panel.get_meta("swipe_progress", 0.0) if main_panel else 0.0
	
	if swipe_progress > 0.3:
		current_mode_index = (current_mode_index + 1) % modes.size()
		_animate_mode_change(1)
	elif swipe_progress < -0.3:
		current_mode_index = (current_mode_index - 1 + modes.size()) % modes.size()
		_animate_mode_change(-1)
	else:
		_animate_snap_back()
	
	_update_mode_display()

func _cycle_mode():
	"""Simple mode cycling on tap"""
	current_mode_index = (current_mode_index + 1) % modes.size()
	_animate_mode_change(1)
	_update_mode_display()

func _animate_mode_change(direction: int):
	"""Animate mode transition with color change"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	if main_panel:
		# Flash white then update color
		tween.tween_property(main_panel, "modulate", Color.WHITE * 1.5, 0.1)
		tween.chain().tween_property(main_panel, "modulate", Color.WHITE, 0.2)
		tween.tween_property(main_panel, "scale", Vector2.ONE, 0.3)
	
	# Update display after flash
	tween.tween_callback(_update_mode_display)
	
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	
	mode_changed.emit(modes[current_mode_index])
	mode_id_changed.emit(mode_ids[current_mode_index])
	
	# Update MultiplayerManager if available
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.select_game_mode(mode_ids[current_mode_index])

func _animate_snap_back():
	"""Return to neutral position"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	if main_panel:
		tween.tween_property(main_panel, "scale", Vector2.ONE, 0.2)
		tween.tween_property(main_panel, "modulate", Color.WHITE, 0.2)
	
	if label:
		tween.tween_property(label, "modulate:a", 1.0, 0.2)

func _update_mode_display():
	"""Update the display for current mode with color change"""
	if label:
		label.text = "Mode: " + modes[current_mode_index]
		label.modulate.a = 1.0
	
	# Update button color based on mode
	if main_panel and UIStyleManager:
		var panel_style = main_panel.get_theme_stylebox("panel")
		if panel_style and panel_style is StyleBoxFlat:
			var style = panel_style.duplicate() as StyleBoxFlat
			
			# Get color for current mode using the ID
			var mode_id = mode_ids[current_mode_index]
			style.bg_color = UIStyleManager.get_mode_color(mode_id, "primary")
			style.border_color = UIStyleManager.get_mode_color(mode_id, "dark")
			
			main_panel.add_theme_stylebox_override("panel", style)
	
	# Reset visual state
	if main_panel:
		main_panel.scale = Vector2.ONE
		main_panel.set_meta("swipe_progress", 0.0)
	
	# Update dots
	if has_meta("dots_container"):
		var dots_container = get_meta("dots_container")
		for i in dots_container.get_child_count():
			var dot = dots_container.get_child(i)
			dot.modulate.a = 0.4 if i != current_mode_index else 1.0

func _on_press_start():
	"""Visual feedback on press"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.1)

func get_current_mode() -> String:
	return modes[current_mode_index]

func get_current_mode_id() -> String:
	"""Get the actual mode ID for GameModeManager"""
	return mode_ids[current_mode_index]

func set_mode_by_id(mode_id: String) -> void:
	"""Set mode by ID (for syncing with MultiplayerManager)"""
	var index = mode_ids.find(mode_id)
	if index != -1 and index != current_mode_index:
		current_mode_index = index
		_update_mode_display()
