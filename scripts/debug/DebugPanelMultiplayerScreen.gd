# DebugPanelMultiplayerScreen.gd - Debug display for MultiplayerScreen
# Location: res://Pyramids/scripts/ui/debug/DebugPanelMultiplayerScreen.gd
# Last Updated: Simplified to use Label instead of RichTextLabel [Date]

extends ScrollContainer

# UI Elements
var debug_label: Label
var button_container: HBoxContainer
var clear_button: Button
var copy_button: Button

# Message history
var message_history: Array[String] = []
var max_messages: int = 100

func _ready():
	# Set size - already handled by scene
	custom_minimum_size = Vector2(400, 200)
	
	# Set z-index to appear on top
	z_index = 100
	
	# Add a solid background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.modulate = Color(0.1, 0.1, 0.1, 0.95)  # Dark semi-transparent background
	add_child(bg_panel)
	move_child(bg_panel, 0)  # Put background behind content
	
	# Create UI structure inside ScrollContainer
	_setup_ui()
	
	# Initial message
	add_message("Debug panel ready", "info")
	
	# Connect to parent's debug state
	call_deferred("_check_parent_debug_state")

func _setup_ui():
	# Create VBox container for content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)
	
	# Header with buttons
	button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(button_container)
	
	var title = Label.new()
	title.text = "Debug Output"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	button_container.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(spacer)
	
	# Clear button
	clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.custom_minimum_size = Vector2(60, 25)
	clear_button.pressed.connect(_on_clear_pressed)
	button_container.add_child(clear_button)
	
	# Copy button
	copy_button = Button.new()
	copy_button.text = "Copy"
	copy_button.custom_minimum_size = Vector2(60, 25)
	copy_button.pressed.connect(_on_copy_pressed)
	button_container.add_child(copy_button)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Simple Label for debug messages
	debug_label = Label.new()
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_label.add_theme_font_size_override("font_size", 11)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(debug_label)

func _check_parent_debug_state():
	var parent = get_parent()
	while parent and not parent.has_method("debug_log"):
		parent = parent.get_parent()
	
	if parent and parent.has_method("get"):
		var debug_enabled = parent.get("debug_enabled")
		var global_debug = parent.get("global_debug")
		if debug_enabled != null and global_debug != null:
			visible = debug_enabled and global_debug
		else:
			visible = true  # Default to visible if can't find parent settings

func add_message(msg: String, type: String = "info"):
	# Check parent debug state
	var parent = get_parent()
	while parent and not parent.has_method("debug_log"):
		parent = parent.get_parent()
	
	if parent and parent.has_method("get"):
		var debug_enabled = parent.get("debug_enabled")
		var global_debug = parent.get("global_debug")
		if not (debug_enabled and global_debug):
			return
	
	# Add timestamp
	var time = Time.get_time_dict_from_system()
	var timestamp = "[%02d:%02d:%02d]" % [time.hour, time.minute, time.second]
	
	# Choose prefix based on type
	var prefix = ""
	match type:
		"warning":
			prefix = "[WARN] "
		"error":
			prefix = "[ERROR] "
		"success":
			prefix = "[OK] "
		"mode":
			prefix = "[MODE] "
		_:
			prefix = "[INFO] "
	
	# Format message (no color tags for Label)
	var formatted_msg = "%s %s%s" % [timestamp, prefix, msg]
	
	# Add to history
	message_history.append(formatted_msg)
	if message_history.size() > max_messages:
		message_history.pop_front()
	
	# Update display
	_refresh_display()

func _refresh_display():
	if debug_label:
		# Join all messages with line breaks
		debug_label.text = "\n".join(message_history)
		
		# Scroll to bottom after next frame
		await get_tree().process_frame
		var v_scroll = get_v_scroll_bar()
		if v_scroll:
			v_scroll.value = v_scroll.max_value

func _on_clear_pressed():
	message_history.clear()
	if debug_label:
		debug_label.text = ""
	add_message("Debug cleared", "info")

func _on_copy_pressed():
	# Simple copy - already plain text
	var plain_text = "\n".join(message_history)
	DisplayServer.clipboard_set(plain_text)
	add_message("Copied to clipboard", "success")

func set_visibility(show: bool):
	visible = show

# Convenience functions for parent to call
func log_mode_change(mode: String, is_solo: bool):
	var mode_type = "Solo" if is_solo else "Multiplayer"
	add_message("Mode changed: %s (%s)" % [mode, mode_type], "mode")

func log_stats(stats: Dictionary, mode: String):
	add_message("Stats for %s:" % mode, "info")
	for key in stats:
		add_message("  %s: %s" % [key, str(stats[key])], "info")

func log_error(msg: String):
	add_message(msg, "error")

func log_warning(msg: String):
	add_message(msg, "warning")

func log_success(msg: String):
	add_message(msg, "success")
