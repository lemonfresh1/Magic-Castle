# ErrorPopup.gd - Error message popup
# Location: res://Pyramids/scripts/ui/popups/ErrorPopup.gd
# Last Updated: Created with consistent sizing

extends PopupBase
class_name ErrorPopup

# Display elements
var icon_container: CenterContainer
var icon_texture: TextureRect
var message_label: Label
var confirm_button: StyledButton

func _ready():
	super._ready()
	set_popup_size(Vector2(350, 250))
	_create_content()

func _create_content():
	# Icon container
	icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(300, 60)
	content_container.add_child(icon_container)
	
	# Warning icon (placeholder for now)
	icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(48, 48)
	icon_texture.size = Vector2(48, 48)
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.add_child(icon_texture)
	
	# Try to load warning icon if exists
	var warning_icon_path = "res://Pyramids/assets/ui/warning_icon.png"
	if ResourceLoader.exists(warning_icon_path):
		icon_texture.texture = load(warning_icon_path)
	else:
		# Create simple colored rect as placeholder
		icon_texture.modulate = ThemeConstants.colors.error
	
	# Message
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
	message_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
	content_container.add_child(message_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	content_container.add_child(spacer)
	
	# Button (green for confirmation)
	var button_container = CenterContainer.new()
	content_container.add_child(button_container)
	
	confirm_button = StyledButton.new()
	confirm_button.text = "OK"
	confirm_button.button_style = "success"  # Green
	confirm_button.button_size = "medium"
	confirm_button.custom_minimum_size.x = 100
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_container.add_child(confirm_button)

func setup(title: String = "Error", message: String = ""):
	set_title(title)  # Always "Error" as title
	message_label.text = message  # The actual error description

func _on_confirm_pressed():
	confirmed.emit()
	close()
