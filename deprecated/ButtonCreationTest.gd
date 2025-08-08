extends Control

var progress_bar: ProgressBar
var icon_rect: TextureRect
var label: Label
var theme_config: Dictionary

func _ready():
	# Set base button properties
	custom_minimum_size = Vector2(250, 80)
	
	# Create the visual structure programmatically
	_create_structure()

func _create_structure():
	# Main container
	var main_container = MarginContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_container)
	
	# HBox for icon and content
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(hbox)
	
	# Icon container
	var icon_container = MarginContainer.new()
	icon_container.custom_minimum_size = Vector2(50, 50)
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_container)
	
	# Icon
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.add_child(icon_rect)
	
	# Label container
	var label_container = VBoxContainer.new()
	label_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label_container)
	
	# Label
	label = Label.new()
	label.add_theme_font_size_override("font_size", 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_container.add_child(label)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.show_percentage = false
	label_container.add_child(progress_bar)

func setup(config: Dictionary):
	theme_config = config
	
	# Set text
	label.text = config.name
	
	# Set icon
	if config.has("icon"):
		icon_rect.texture = load(config.icon)
	
	# Handle progress bar
	if not config.get("has_progress", true):
		progress_bar.visible = false
		label.add_theme_font_size_override("font_size", 36)
	
	# Apply theme
	if config.has("theme") and config.theme:
		apply_button_theme(config.theme)

func apply_button_theme(theme_name: String):
	# Create custom StyleBox for the button
	var style = StyleBoxFlat.new()
	
	# Get theme colors - for testing, we'll use hardcoded values
	var themes = {
		"Play": {
			"main_bg": Color(0.2, 0.5, 0.2),
			"main_border": Color(0.3, 0.7, 0.3),
			"shadow": Color(0.1, 0.3, 0.1),
			"progress_bg": Color(0.4, 0.7, 0.4),
			"progress_fill": Color(0.5, 0.9, 0.5)
		},
		"Shop": {
			"main_bg": Color(0.6, 0.5, 0.2),
			"main_border": Color(0.8, 0.6, 0.2),
			"shadow": Color(0.4, 0.3, 0.1),
			"progress_bg": Color(0.8, 0.7, 0.4),
			"progress_fill": Color(0.9, 0.7, 0.2)
		},
		"Missions": {
			"main_bg": Color(0.2, 0.4, 0.6),
			"main_border": Color(0.3, 0.5, 0.8),
			"shadow": Color(0.1, 0.2, 0.4),
			"progress_bg": Color(0.4, 0.6, 0.8),
			"progress_fill": Color(0.4, 0.6, 0.9)
		}
	}
	
	var theme = themes.get(theme_name, themes["Play"])
	
	# Apply main button style
	style.bg_color = theme.get("main_bg", Color.WHITE)
	style.border_color = theme.get("main_border", Color.BLACK)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	# Shadow effect
	style.shadow_color = theme.get("shadow", Color.BLACK)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	
	# Apply styles to button
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	
	# Apply progress bar theme
	if progress_bar and progress_bar.visible:
		var pg_bg = StyleBoxFlat.new()
		pg_bg.bg_color = theme.get("progress_bg", Color.GRAY)
		progress_bar.add_theme_stylebox_override("background", pg_bg)
		
		var pg_fill = StyleBoxFlat.new()
		pg_fill.bg_color = theme.get("progress_fill", Color.GREEN)
		progress_bar.add_theme_stylebox_override("fill", pg_fill)

func set_progress(value: float, max_value: float = 100.0):
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = value
