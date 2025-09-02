# KickPopup.gd - Confirm kicking player from lobby
# Location: res://Pyramids/scripts/ui/popups/KickPopup.gd
# Last Updated: Created with placeholder for multiplayer

extends PopupBase
class_name KickPopup

# Display elements
var message_label: Label
var cancel_button: StyledButton
var kick_button: StyledButton

# Data
var player_name: String = ""

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
	
	# Cancel button (green - safe option)
	cancel_button = StyledButton.new()
	cancel_button.text = "Cancel"
	cancel_button.button_style = "success"  # Green
	cancel_button.button_size = "medium"
	cancel_button.custom_minimum_size.x = 100
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)
	
	# Kick button (red - destructive)
	kick_button = StyledButton.new()
	kick_button.text = "Kick"
	kick_button.button_style = "danger"  # Red
	kick_button.button_size = "medium"
	kick_button.custom_minimum_size.x = 100
	kick_button.pressed.connect(_on_kick_pressed)
	button_container.add_child(kick_button)

func setup(title: String, message: String, player_name_param: String = "Player"):
	set_title(title)
	player_name = player_name_param
	message_label.text = "Are you sure you want to kick %s from the lobby?" % player_name

func _on_cancel_pressed():
	cancelled.emit()
	close()

func _on_kick_pressed():
	confirmed.emit()
	close()
