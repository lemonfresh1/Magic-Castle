# LeavePopup.gd - Confirm leaving game lobby
# Location: res://Pyramids/scripts/ui/popups/LeavePopup.gd
# Last Updated: Created with stay/leave options

extends PopupBase
class_name LeavePopup

# Display elements
var message_label: Label
var stay_button: StyledButton
var leave_button: StyledButton

func _ready():
	super._ready()
	set_popup_size(Vector2(350, 250))
	_create_content()

func _create_content():
	# Add some spacing at top
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 20
	content_container.add_child(top_spacer)
	
	# Message
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
	message_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
	content_container.add_child(message_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 40
	content_container.add_child(spacer)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 16)
	content_container.add_child(button_container)
	
	# Stay button (green - safe option)
	stay_button = StyledButton.new()
	stay_button.text = "Stay"
	stay_button.button_style = "success"  # Green
	stay_button.button_size = "medium"
	stay_button.custom_minimum_size.x = 100
	stay_button.pressed.connect(_on_stay_pressed)
	button_container.add_child(stay_button)
	
	# Leave button (red - destructive)
	leave_button = StyledButton.new()
	leave_button.text = "Leave"
	leave_button.button_style = "danger"  # Red
	leave_button.button_size = "medium"
	leave_button.custom_minimum_size.x = 100
	leave_button.pressed.connect(_on_leave_pressed)
	button_container.add_child(leave_button)

func setup(title: String, message: String):
	set_title(title)
	message_label.text = message

func _on_stay_pressed():
	cancelled.emit()  # Staying = cancelling the leave action
	close()

func _on_leave_pressed():
	confirmed.emit()  # Leaving = confirming the action
	close()
