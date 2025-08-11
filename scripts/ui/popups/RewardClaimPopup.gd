# RewardClaimPopup.gd - Popup for confirming reward claims
# Location: res://Pyramids/scripts/ui/popups/RewardClaimPopup.gd
# Last Updated: Fixed null button reference [Date]

extends PanelContainer
class_name RewardClaimPopup

signal confirmed()
signal cancelled()

var reward_data: Dictionary = {}
var is_premium: bool = false

func _ready():
	# Create the popup structure programmatically since scene might not exist
	_create_popup_structure()
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "reward_popup")
	
	# Set size
	custom_minimum_size = Vector2(UIStyleManager.get_dimension("modal_min_width"), 200)

func _create_popup_structure():
	"""Create the popup UI structure programmatically"""
	# Main margin container
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", UIStyleManager.get_spacing("space_4"))
	margin_container.add_theme_constant_override("margin_right", UIStyleManager.get_spacing("space_4"))
	margin_container.add_theme_constant_override("margin_top", UIStyleManager.get_spacing("space_4"))
	margin_container.add_theme_constant_override("margin_bottom", UIStyleManager.get_spacing("space_4"))
	add_child(margin_container)
	
	# VBox container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_3"))
	margin_container.add_child(vbox)
	
	# Icon container
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(80, 80)
	vbox.add_child(icon_container)
	
	# Reward icon
	var icon = TextureRect.new()
	icon.name = "RewardIcon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.add_child(icon)
	
	# Message label
	var message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	message_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	vbox.add_child(message_label)
	
	# Button container
	var button_container = CenterContainer.new()
	vbox.add_child(button_container)
	
	# Accept button
	var accept_button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Accept"
	accept_button.custom_minimum_size = Vector2(100, 30)
	button_container.add_child(accept_button)
	
	# Style the button AFTER it's added to the tree
	UIStyleManager.apply_button_style(accept_button, "primary", "small")
	
	# Connect button
	accept_button.pressed.connect(_on_accept_pressed)

func setup(rewards: Dictionary, icon_texture: Texture2D):
	"""Setup the popup with reward data"""
	reward_data = rewards
	
	# Find nodes
	var icon = find_child("RewardIcon", true, false) as TextureRect
	var message_label = find_child("MessageLabel", true, false) as Label
	
	# Set icon
	if icon and icon_texture:
		icon.texture = icon_texture
	
	# Build message
	if message_label:
		var reward_name = _get_reward_name(rewards)
		message_label.text = "Hooray! You received %s!" % reward_name
	
	# Center within parent container instead of viewport
	await get_tree().process_frame  # Wait for size to be calculated
	if get_parent():
		var parent_size = get_parent().size
		position = (parent_size - size) / 2
		# Ensure it's visible (clamp to parent bounds)
		position.x = max(10, min(position.x, parent_size.x - size.x - 10))
		position.y = max(10, min(position.y, parent_size.y - size.y - 10))

func _get_reward_name(rewards: Dictionary) -> String:
	"""Get a readable name for the reward"""
	if rewards.has("stars"):
		return "%d Stars" % rewards.stars
	elif rewards.has("cosmetic_type") and rewards.has("cosmetic_id"):
		match rewards.cosmetic_type:
			"emoji":
				return "a new Emoji"
			"card_skin":
				return "a new Card Skin"
			"board_skin":
				return "a new Board Skin"
			"avatar":
				return "a new Avatar"
			"frame":
				return "a new Frame"
			_:
				return "a new Cosmetic"
	elif rewards.has("xp"):
		return "%d XP" % rewards.xp
	else:
		return "a reward"

func _on_accept_pressed():
	confirmed.emit()
	queue_free()
