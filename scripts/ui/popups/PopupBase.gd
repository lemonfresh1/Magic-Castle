# PopupBase.gd - Base class for all popups, works WITH UIStyleManager
# Location: res://Pyramids/scripts/ui/popups/PopupBase.gd

extends Control
class_name PopupBase

signal closed
signal confirmed
signal cancelled

# UI Structure
var backdrop: ColorRect
var panel: PanelContainer
var content_container: VBoxContainer
var title_label: Label
var close_button: Button

# Configuration
@export var show_backdrop: bool = true
@export var close_on_backdrop_click: bool = true
@export var close_on_esc: bool = true
@export var popup_size: Vector2 = Vector2(400, 300)

func _ready():
	# Create UI structure
	_create_backdrop()
	_create_panel()
	_create_close_button()
	
	# Position and size
	_center_popup()
	
	# Start hidden
	visible = false
	
	# Handle input
	set_process_unhandled_input(true)

func _create_backdrop():
	backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, ThemeConstants.opacity.get("backdrop", 0.5))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	
	if close_on_backdrop_click:
		backdrop.gui_input.connect(_on_backdrop_input)
	
	backdrop.visible = show_backdrop

func _create_panel():
	panel = PanelContainer.new()
	panel.custom_minimum_size = popup_size
	panel.size = popup_size
	add_child(panel)
	
	# Apply styling using UIStyleManager
	UIStyleManager.apply_panel_style(panel)
	
	# Create margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	# Create content container
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 15)
	margin.add_child(content_container)
	
	# Create title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_900"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(title_label)

func _create_close_button():
	close_button = Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(30, 30)
	panel.add_child(close_button)
	
	# Position in top-right corner
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.position = Vector2(-35, 5)
	
	# Style
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override("font_color", UIStyleManager.get_color("gray_400"))
	
	close_button.pressed.connect(close)

func _center_popup():
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2

func _unhandled_input(event: InputEvent):
	if close_on_esc and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		close()

func set_title(text: String):
	if title_label:
		title_label.text = text

func set_popup_size(new_size: Vector2):
	popup_size = new_size
	if panel:
		panel.custom_minimum_size = new_size
		panel.size = new_size
		_center_popup()

func show_popup():
	PopupQueue.show_popup(self)

func display():
	"""Called by PopupQueue when it's this popup's turn"""
	visible = true
	_center_popup()
	
	# Fade in animation
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func close():
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		closed.emit()
		PopupQueue.popup_closed(self)
		queue_free()
	)
