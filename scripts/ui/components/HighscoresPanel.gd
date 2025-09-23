# HighscoresPanel.gd - Flexible highscores display system
# Location: res://Pyramids/scripts/ui/components/HighscoresPanel.gd
# Last Updated: Added support for image icons in action buttons

extends PanelContainer

signal filter_changed(filter_name: String)
signal action_triggered(action: String, score_data: Dictionary)

# Configuration exports
@export_group("Display")
@export var panel_title: String = "Highscores"
@export var max_rows: int = 5
@export var show_filters: bool = true
@export var show_title: bool = true
@export var compact_mode: bool = false

@export_group("Layout")
@export var filter_position: String = "right"  # "right", "top", "bottom"
@export var content_margins: Vector4 = Vector4(20, 16, 20, 16)  # left, top, right, bottom

# Column configuration
var column_config: Array[Dictionary] = [
	{"key": "rank", "label": "#", "width": 40, "align": "left", "format": "rank"},
	{"key": "score", "label": "Score", "width": 100, "align": "center", "format": "number"},
	{"key": "date", "label": "Date", "width": 60, "align": "right", "format": "date"}
]

# Filter configuration  
var filter_config: Array[Dictionary] = [
	{"id": "all", "label": "All", "default": true},
	{"id": "day", "label": "Day"},
	{"id": "week", "label": "Week"},
	{"id": "month", "label": "Month"},
	{"id": "year", "label": "Year"}
]

# Action buttons configuration
var row_actions: Array[String] = []  # ["watch", "copy_seed", "join", "play"]
var global_actions: Array[String] = []  # ["refresh", "export"]

# State
var current_filter: String = "all"
var current_context: Dictionary = {}
var data_provider: Callable
var scores_data: Array = []
var selected_row_index: int = -1

# UI References (created dynamically)
var main_container: Control
var title_label: Label
var scores_container: Control
var filters_container: Control
var header_row: Control

func _ready():
	# Apply base panel style
	UIStyleManager.apply_panel_style(self, "highscores")
	
	# Enable clipping to prevent overflow
	#clip_contents = true
	
	# Build initial UI
	_build_ui()

func setup(config: Dictionary) -> void:
	"""Configure the panel with custom settings"""
	# Handle typed arrays properly
	if config.has("columns"):
		column_config.clear()
		for col in config.columns:
			column_config.append(col)
	
	if config.has("filters"):
		filter_config.clear()
		for filter in config.filters:
			filter_config.append(filter)
	
	if config.has("row_actions"):
		row_actions.clear()
		for action in config.row_actions:
			row_actions.append(action)
	
	if config.has("global_actions"):
		global_actions.clear()
		for action in config.global_actions:
			global_actions.append(action)
	
	# Handle simple value assignments
	if config.has("title"):
		panel_title = config.title
	
	if config.has("max_rows"):
		max_rows = config.max_rows
	
	if config.has("show_filters"):
		show_filters = config.show_filters
	
	if config.has("show_title"):
		show_title = config.show_title
	
	if config.has("filter_position"):
		filter_position = config.filter_position
	
	if config.has("data_provider"):
		data_provider = config.data_provider
	
	if config.has("compact_mode"):
		compact_mode = config.compact_mode
	
	# Find default filter
	for filter in filter_config:
		if filter.get("default", false):
			current_filter = filter.id
			break
	
	# Rebuild UI with new config
	_rebuild_ui()

func load_scores(context: Dictionary) -> void:
	"""Load scores for given context"""
	current_context = context
	_fetch_and_display_scores()

func refresh() -> void:
	"""Refresh current scores"""
	_fetch_and_display_scores()

func set_filter(filter_id: String) -> void:
	"""Set active filter programmatically"""
	if current_filter != filter_id:
		current_filter = filter_id
		_update_filter_buttons()
		_fetch_and_display_scores()
		filter_changed.emit(filter_id)

# === UI BUILDING ===

func _build_ui() -> void:
	"""Build the initial UI structure"""
	# Clear existing
	for child in get_children():
		child.queue_free()
	
	# Create margin container
	var margin_cont = MarginContainer.new()
	margin_cont.name = "MarginContainer"
	margin_cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin_cont)
	
	# Apply margins
	margin_cont.add_theme_constant_override("margin_left", int(content_margins.x))
	margin_cont.add_theme_constant_override("margin_top", int(content_margins.y))
	margin_cont.add_theme_constant_override("margin_right", int(content_margins.z))
	margin_cont.add_theme_constant_override("margin_bottom", int(content_margins.w))
	
	# Build layout based on filter position
	match filter_position:
		"right":
			_build_horizontal_layout(margin_cont)
		"top":
			_build_vertical_layout(margin_cont, true)
		"bottom":
			_build_vertical_layout(margin_cont, false)
		_:
			_build_horizontal_layout(margin_cont)

func _build_horizontal_layout(parent: Control) -> void:
	"""Build layout with filters on the side"""
	var hbox = HBoxContainer.new()
	hbox.name = "MainHBox"
	hbox.add_theme_constant_override("separation", 30 if not compact_mode else 15)
	parent.add_child(hbox)
	
	# Left side - scores
	var left_vbox = VBoxContainer.new()
	left_vbox.name = "ScoresSection"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 2.5
	hbox.add_child(left_vbox)
	
	# Add title if enabled
	if show_title:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = panel_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyleManager.apply_label_style(title_label, "title")
		left_vbox.add_child(title_label)
		
		# Add separator
		var sep = HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		left_vbox.add_child(sep)
	
	# Create scores container
	_create_scores_container(left_vbox)
	
	# Right side - filters
	if show_filters:
		filters_container = VBoxContainer.new()
		filters_container.name = "FiltersSection"
		filters_container.add_theme_constant_override("separation", 4)
		filters_container.custom_minimum_size.x = 100 if not compact_mode else 80
		hbox.add_child(filters_container)
		
		_create_filter_buttons()

func _build_vertical_layout(parent: Control, filters_on_top: bool) -> void:
	"""Build layout with filters above or below"""
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 15)
	parent.add_child(vbox)
	
	# Title
	if show_title:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = panel_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyleManager.apply_label_style(title_label, "title")
		vbox.add_child(title_label)
	
	# Filters (if on top)
	if show_filters and filters_on_top:
		filters_container = HBoxContainer.new()
		filters_container.name = "FiltersSection"
		filters_container.alignment = BoxContainer.ALIGNMENT_CENTER
		filters_container.add_theme_constant_override("separation", 8)
		vbox.add_child(filters_container)
		_create_filter_buttons()
		
		# Separator
		vbox.add_child(HSeparator.new())
	
	# Scores
	_create_scores_container(vbox)
	
	# Filters (if on bottom)
	if show_filters and not filters_on_top:
		# Separator
		vbox.add_child(HSeparator.new())
		
		filters_container = HBoxContainer.new()
		filters_container.name = "FiltersSection"
		filters_container.alignment = BoxContainer.ALIGNMENT_CENTER
		filters_container.add_theme_constant_override("separation", 8)
		vbox.add_child(filters_container)
		_create_filter_buttons()

func _create_scores_container(parent: Control) -> void:
	"""Create the container for score rows with scrolling"""
	# Create a scroll container
	var scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	
	# Don't set a fixed height - let it fill available space
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Clip content to prevent overflow
	scroll_container.clip_contents = true
	
	# Hide horizontal scroll, show vertical only when needed
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	parent.add_child(scroll_container)
	
	# Create the actual scores container inside the scroll
	scores_container = VBoxContainer.new()
	scores_container.name = "ScoresContainer"
	scores_container.add_theme_constant_override("separation", 4 if compact_mode else 6)
	scores_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(scores_container)
	
	# Create header row OUTSIDE the scroll (so it stays fixed)
	_create_header_row_outside_scroll(parent)

func _create_header_row_outside_scroll(parent: Control) -> void:
	"""Create column headers outside the scroll container"""
	# Insert header BEFORE the scroll container
	var scroll_index = parent.get_child_count() - 1
	
	header_row = HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	
	# Add column headers
	for col in column_config:
		var header_label = Label.new()
		header_label.text = col.label
		header_label.custom_minimum_size.x = col.width
		header_label.horizontal_alignment = _get_alignment(col.align)
		header_label.add_theme_font_size_override("font_size", 14)
		header_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_600)
		header_row.add_child(header_label)
	
	# Add space for actions if present
	if not row_actions.is_empty():
		var actions_spacer = Control.new()
		actions_spacer.custom_minimum_size.x = 30 * row_actions.size()
		header_row.add_child(actions_spacer)
	
	parent.add_child(header_row)
	parent.move_child(header_row, scroll_index)  # Put header before scroll
	
	# Add separator between header and scroll
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	parent.add_child(sep)
	parent.move_child(sep, scroll_index + 1)

func _create_header_row() -> void:
	"""Create column headers"""
	header_row = HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	
	# Add column headers
	for col in column_config:
		var header_label = Label.new()
		header_label.text = col.label
		header_label.custom_minimum_size.x = col.width
		header_label.horizontal_alignment = _get_alignment(col.align)
		header_label.add_theme_font_size_override("font_size", 14)
		header_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_600)
		header_label.add_theme_font_override("font", ThemeDB.fallback_font)
		header_label.set("font_weight", 700)  # Bold if supported
		header_row.add_child(header_label)
	
	# Add space for actions if present
	if not row_actions.is_empty():
		var actions_spacer = Control.new()
		actions_spacer.custom_minimum_size.x = 30 * row_actions.size()
		header_row.add_child(actions_spacer)
	
	scores_container.add_child(header_row)
	
	# Add small separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	scores_container.add_child(sep)

func _create_filter_buttons() -> void:
	"""Create filter buttons based on configuration"""
	if not filters_container:
		return
	
	# Clear existing
	for child in filters_container.get_children():
		child.queue_free()
	
	# Create buttons
	for filter in filter_config:
		var btn = Button.new()
		btn.name = filter.id.capitalize() + "Filter"
		btn.text = filter.label
		btn.toggle_mode = true
		
		# Size based on layout
		if filter_position == "right":
			btn.custom_minimum_size = Vector2(80 if not compact_mode else 60, 36)
		else:
			btn.custom_minimum_size = Vector2(70, 32)
		
		btn.pressed.connect(_on_filter_pressed.bind(filter.id))
		
		# Apply style
		_apply_filter_button_style(btn, filter.id == current_filter)
		
		filters_container.add_child(btn)

func _apply_filter_button_style(button: Button, is_selected: bool) -> void:
	"""Apply consistent filter button styling"""
	var style_normal = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	
	if is_selected:
		style_normal.bg_color = UIStyleManager.colors.primary
		style_pressed.bg_color = UIStyleManager.colors.primary
		button.add_theme_color_override("font_color", UIStyleManager.colors.white)
		button.button_pressed = true
	else:
		style_normal.bg_color = UIStyleManager.colors.white
		style_pressed.bg_color = UIStyleManager.colors.white
		style_normal.border_color = UIStyleManager.colors.gray_300
		style_normal.set_border_width_all(UIStyleManager.borders.width_thin)
		style_pressed.border_color = UIStyleManager.colors.gray_300
		style_pressed.set_border_width_all(UIStyleManager.borders.width_thin)
		button.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
		button.button_pressed = false
	
	# Apply corner radius
	var radius = UIStyleManager.dimensions.corner_radius_small
	style_normal.set_corner_radius_all(radius)
	style_pressed.set_corner_radius_all(radius)
	
	# Apply margins
	for style in [style_normal, style_pressed]:
		style.content_margin_left = 12 if not compact_mode else 8
		style.content_margin_right = 12 if not compact_mode else 8
		style.content_margin_top = 6 if not compact_mode else 4
		style.content_margin_bottom = 6 if not compact_mode else 4
	
	# Apply styles
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_normal)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	button.add_theme_font_size_override("font_size", 14 if compact_mode else 16)

func _rebuild_ui() -> void:
	"""Rebuild entire UI with new configuration"""
	_build_ui()
	if scores_data.size() > 0:
		_display_scores()

# === DATA HANDLING ===

func _fetch_and_display_scores() -> void:
	"""Fetch scores using data provider and display them"""
	if not data_provider:
		push_warning("HighscoresPanel: No data provider set")
		_display_empty_state("No data provider configured")
		return
	
	# Call data provider with current context and filter
	var fetch_context = current_context.duplicate()
	fetch_context["filter"] = current_filter
	
	scores_data = data_provider.call(fetch_context)
	_display_scores()

func _display_scores() -> void:
	"""Display the fetched scores"""
	# Clear existing score rows (keep header)
	for child in scores_container.get_children():
		if child.name != "HeaderRow" and not child is HSeparator:
			child.queue_free()
	
	if scores_data.is_empty():
		_display_empty_state("No scores yet")
		return
	
	# Add score rows
	var rows_to_show = min(max_rows, scores_data.size())
	for i in range(rows_to_show):
		var score_row = _create_score_row(scores_data[i], i)
		scores_container.add_child(score_row)

func _create_score_row(score_data: Dictionary, index: int) -> Control:
	"""Create a single score row with proper icon support"""
	var hbox = HBoxContainer.new()
	hbox.name = "ScoreRow" + str(index)
	hbox.add_theme_constant_override("separation", 8)
	
	# Don't make the whole row clickable - we have action buttons for that
	# Removed: hbox.gui_input.connect and mouse_default_cursor_shape
	
	# Add data columns
	for col in column_config:
		var label = Label.new()
		var value = score_data.get(col.key, "")
		
		# Format value based on type
		label.text = _format_value(value, col.get("format", "text"), col.key, index)
		label.custom_minimum_size.x = col.width
		label.horizontal_alignment = _get_alignment(col.align)
		
		# Apply styling - check both "player" and "player_name" keys
		if (col.key == "player" or col.key == "player_name") and score_data.get("is_current_player", false):
			label.add_theme_color_override("font_color", UIStyleManager.colors.primary)
		else:
			label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
		
		label.add_theme_font_size_override("font_size", 14 if compact_mode else 16)
		
		hbox.add_child(label)
	
	# Add action buttons
	if not row_actions.is_empty():
		var actions_container = HBoxContainer.new()
		actions_container.add_theme_constant_override("separation", 2)
		
		for action in row_actions:
			var btn = Button.new()
			btn.tooltip_text = _get_action_tooltip(action)
			btn.custom_minimum_size = Vector2(28, 28)
			btn.flat = true
			
			# Get the icon string/path
			var icon_value = _get_action_icon(action)
			
			# Check if it's a file path to an image
			if icon_value.begins_with("res://") and ResourceLoader.exists(icon_value):
				# Load as image icon
				var icon_texture = load(icon_value) as Texture2D
				if icon_texture:
					btn.icon = icon_texture
					btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
					btn.expand_icon = true
					
					# Don't modulate the button - let the icon show its natural colors
					# Could add different hover effect here if needed (like scale or glow)
			else:
				# Use as text (emoji or symbol)
				btn.text = icon_value
				btn.add_theme_font_size_override("font_size", 16)
			
			btn.pressed.connect(func(): action_triggered.emit(action, score_data))
			
			actions_container.add_child(btn)
		
		hbox.add_child(actions_container)
	
	return hbox

func _display_empty_state(message: String) -> void:
	"""Display empty state message"""
	# Clear existing score rows (keep header)
	for child in scores_container.get_children():
		if child.name != "HeaderRow" and not child is HSeparator:
			child.queue_free()
	
	var empty_label = Label.new()
	empty_label.text = message
	empty_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_500)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 14 if compact_mode else 16)
	scores_container.add_child(empty_label)

# === UTILITY FUNCTIONS ===

func _format_value(value, format_type: String, key: String, index: int) -> String:
	"""Format a value based on its type"""
	match format_type:
		"rank":
			return "%d." % (index + 1)
		"number":
			return _format_number_with_commas(int(value))
		"date":
			if value is float or value is int:
				var datetime = Time.get_datetime_dict_from_unix_time(int(value))
				return "%02d/%02d" % [datetime.month, datetime.day]
			return str(value)
		"time":
			if value is float or value is int:
				return _format_time(int(value))
			return str(value)
		"player":
			var name = str(value)
			if name.length() > 12 and compact_mode:
				return name.substr(0, 10) + ".."
			return name
		_:
			return str(value)

func _format_number_with_commas(num: int) -> String:
	"""Format number with thousand separators"""
	var num_str = str(num)
	var result = ""
	var counter = 0
	
	for i in range(num_str.length() - 1, -1, -1):
		if counter == 3:
			result = "," + result
			counter = 0
		result = num_str[i] + result
		counter += 1
	
	return result

func _format_time(seconds: int) -> String:
	"""Format time in MM:SS"""
	var minutes = seconds / 60
	var secs = seconds % 60
	return "%02d:%02d" % [minutes, secs]

func _get_alignment(align_str: String) -> HorizontalAlignment:
	"""Convert string alignment to enum"""
	match align_str:
		"left": return HORIZONTAL_ALIGNMENT_LEFT
		"center": return HORIZONTAL_ALIGNMENT_CENTER
		"right": return HORIZONTAL_ALIGNMENT_RIGHT
		_: return HORIZONTAL_ALIGNMENT_LEFT

func _get_action_icon(action: String) -> String:
	"""Get icon for action button - can return emoji or file path"""
	match action:
		"watch": return "👁"
		"copy_seed": return "📋"
		"join": return "➡️"
		"play": return "▶️"
		"challenge": return "⚔️"
		"friend": return "👤"
		"refresh": return "🔄"
		"export": return "💾"
		_: return "?"

func _get_action_tooltip(action: String) -> String:
	"""Get tooltip for action button"""
	match action:
		"watch": return "Watch Replay"
		"copy_seed": return "Copy Seed"
		"join": return "Join Lobby"
		"play": return "Play Now"
		"challenge": return "Challenge Player"
		"friend": return "Add Friend"
		"refresh": return "Refresh Scores"
		"export": return "Export Scores"
		_: return action.capitalize()

# === EVENT HANDLERS ===

func _on_filter_pressed(filter_id: String) -> void:
	"""Handle filter button press"""
	if current_filter != filter_id:
		current_filter = filter_id
		_update_filter_buttons()
		_fetch_and_display_scores()
		filter_changed.emit(filter_id)

func _update_filter_buttons() -> void:
	"""Update visual state of filter buttons"""
	if not filters_container:
		return
	
	for child in filters_container.get_children():
		if child is Button:
			var filter_id = child.name.replace("Filter", "").to_lower()
			_apply_filter_button_style(child, filter_id == current_filter)

func _on_row_input(event: InputEvent, index: int) -> void:
	"""Handle row selection/interaction - minimal functionality now that we have action buttons"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected_row_index = index
			# Row selection is now just for tracking, actions are handled by buttons
