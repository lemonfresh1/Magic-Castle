# EditableWrapper.gd - Add to res://Pyramids/scripts/ui/components/
extends PanelContainer

signal edit_requested

func wrap_content(content: Control, edit_text: String = "✏"):
	# Add the content
	add_child(content)
	
	# Connect to content's signals if they exist
	if content.has_signal("display_item_clicked"):
		content.display_item_clicked.connect(func(item_id): edit_requested.emit())
	
	# Add edit indicator
	var edit_label = Label.new()
	edit_label.text = edit_text
	edit_label.add_theme_font_size_override("font_size", 14)
	edit_label.modulate = Color(0.6, 0.8, 1.0, 0.8)
	edit_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	edit_label.position = Vector2(-24, 2)
	edit_label.mouse_filter = Control.MOUSE_FILTER_PASS
	edit_label.gui_input.connect(_on_edit_clicked)
	add_child(edit_label)
	
	# Subtle border
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(0.3, 0.7, 1.0, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

func _on_edit_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		edit_requested.emit()
