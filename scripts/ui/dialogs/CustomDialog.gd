# CustomDialog.gd - Reusable styled dialog popup
# Location: res://Pyramids/scripts/ui/dialogs/CustomDialog.gd
# Last Updated: Created for consistent dialog styling [Date]

class_name CustomDialog
extends Control

signal confirmed
signal canceled
signal closed

@export var title_text: String = "Dialog Title"
@export var body_text: String = "Dialog body text"
@export var confirm_text: String = "Confirm"
@export var cancel_text: String = "Cancel"
@export var show_cancel: bool = true
@export var icon_texture: Texture2D = null

var panel: Panel
var title_label: Label
var body_label: Label
var icon_rect: TextureRect
var confirm_button: Button
var cancel_button: Button
var backdrop: ColorRect

func _ready():
	# Create UI structure
	_create_ui()
	
	# Apply styling
	_apply_styling()
	
	# Position centered
	_center_dialog()
	
	# Start hidden
	visible = false

func _create_ui():
	# Create semi-transparent backdrop
	backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	
	# Create main panel
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 250)
	add_child(panel)
	
	# Create VBox for content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	
	# Add margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(margin)
	
	var inner_vbox = VBoxContainer.new()
	margin.add_child(inner_vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(title_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = UIStyleManager.spacing.space_3
	inner_vbox.add_child(spacer1)
	
	# Icon (if provided) - FIXED SIZE
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.size = Vector2(64, 64)  # Force max size
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL  # Keep aspect ratio
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner_vbox.add_child(icon_rect)
	
	# Body text
	body_label = Label.new()
	body_label.text = body_text
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner_vbox.add_child(body_label)
	
	# Flexible spacer
	var flex_spacer = Control.new()
	flex_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(flex_spacer)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_child(button_container)
	
	# Cancel button
	if show_cancel:
		cancel_button = Button.new()
		cancel_button.text = cancel_text
		cancel_button.custom_minimum_size.x = 120
		cancel_button.pressed.connect(_on_cancel)
		button_container.add_child(cancel_button)
	
	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = confirm_text
	confirm_button.custom_minimum_size.x = 120
	confirm_button.pressed.connect(_on_confirm)
	button_container.add_child(confirm_button)

func _apply_styling():
	# Style panel
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = UIStyleManager.colors.white
		style.bg_color.a = 1.0  # Fully opaque
		style.border_color = UIStyleManager.colors.gray_200
		style.set_border_width_all(UIStyleManager.borders.width_thin)
		style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_large)
		
		# Shadow
		style.shadow_size = UIStyleManager.shadows.size_xl
		style.shadow_offset = UIStyleManager.shadows.offset_large
		style.shadow_color = UIStyleManager.shadows.color_large
		
		panel.add_theme_stylebox_override("panel", style)
	
	# Style labels
	if title_label:
		title_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_h3)
		title_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
	
	if body_label:
		body_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_body)
		body_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_700)
	
	# Style buttons
	if confirm_button:
		UIStyleManager.apply_button_style(confirm_button, "primary", "medium")
	
	if cancel_button:
		UIStyleManager.apply_button_style(cancel_button, "secondary", "medium")
	
	# Apply margins
	var margin_container = panel.get_child(0).get_child(0) as MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", UIStyleManager.spacing.space_8)
		margin_container.add_theme_constant_override("margin_right", UIStyleManager.spacing.space_8)
		margin_container.add_theme_constant_override("margin_top", UIStyleManager.spacing.space_6)
		margin_container.add_theme_constant_override("margin_bottom", UIStyleManager.spacing.space_6)
	
	# Apply spacing
	var vbox = margin_container.get_child(0) as VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", UIStyleManager.spacing.space_3)
	
	# Button container spacing
	var button_container = confirm_button.get_parent() as HBoxContainer
	if button_container:
		button_container.add_theme_constant_override("separation", UIStyleManager.spacing.space_4)

func _center_dialog():
	# Make this Control fill the entire viewport
	anchor_left = 0
	anchor_right = 1
	anchor_top = 0
	anchor_bottom = 1
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	
	# Now center the panel within this full-screen Control
	var viewport_size = get_viewport().get_visible_rect().size
	panel.size = Vector2(400, 250)
	panel.position = (viewport_size - panel.size) / 2
	
	# High z-index
	z_index = 1000

func setup(title: String, body: String, icon: Texture2D = null, confirm_btn_text: String = "Confirm", show_cancel_btn: bool = true):
	title_text = title
	body_text = body
	icon_texture = icon
	confirm_text = confirm_btn_text
	show_cancel = show_cancel_btn
	
	# Update UI
	if title_label:
		title_label.text = title_text
	if body_label:
		body_label.text = body_text
	if confirm_button:
		confirm_button.text = confirm_text
	if icon_rect:
		if icon_texture:
			icon_rect.texture = icon_texture
			icon_rect.visible = true
		else:
			icon_rect.visible = false
	if cancel_button:
		cancel_button.visible = show_cancel

func popup():
	visible = true
	# Fade in
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func close():
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)

func _on_confirm():
	confirmed.emit()
	close()

func _on_cancel():
	canceled.emit()
	close()

func _on_backdrop_input(event: InputEvent):
	# Close on backdrop click
	if event is InputEventMouseButton and event.pressed:
		_on_cancel()
