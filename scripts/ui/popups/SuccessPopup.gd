# SuccessPopup.gd - Success notification popup (FIXED ICON SIZING)
# Location: res://Pyramids/scripts/ui/popups/SuccessPopup.gd
# Last Updated: Fixed icon sizing for battlepass

extends PopupBase
class_name SuccessPopup

func setup(title: String, message: String, button_text: String = "Great!"):
	"""Basic success setup"""
	setup_basic(title if title != "" else "Success!", message, false)
	
	# Single positive button
	set_confirm_button_text(button_text)
	hide_cancel_button()
	
	# Use primary style for success
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")

func setup_with_item(title: String, message: String, item: UnifiedItemData, button_text: String = "Awesome!"):
	"""Setup with item display"""
	set_title(title if title != "" else "Success!")
	show_message(message)
	
	# Add item card
	if ItemManager:
		var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
		var card = card_scene.instantiate()
		card.custom_minimum_size = Vector2(80, 80)
		card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		add_to_asset_container(card)
	
	set_confirm_button_text(button_text)
	hide_cancel_button()
	
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")

func setup_with_icon(title: String, message: String, icon_path: String, button_text: String = "Great!"):
	"""Setup with icon display"""
	set_title(title if title != "" else "Success!")
	show_message(message)
	
	# Add icon with proper sizing
	if icon_path != "":
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(icon_path)
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL  # This keeps aspect ratio
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_to_asset_container(texture_rect)
	
	set_confirm_button_text(button_text)
	hide_cancel_button()
	
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")
