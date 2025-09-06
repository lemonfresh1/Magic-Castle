# PurchasePopup.gd - Purchase confirmation popup (FIXED ICON SIZING)
# Location: res://Pyramids/scripts/ui/popups/PurchasePopup.gd
# Last Updated: Fixed icon sizing for battlepass

extends PopupBase
class_name PurchasePopup

var price: int = 0
var currency_type: String = "stars"

func setup_with_item(title: String, item: UnifiedItemData, item_price: int, currency: String = "stars"):
	"""Setup purchase popup with item details"""
	self.price = item_price
	self.currency_type = currency
	
	setup_basic(title if title != "" else "Confirm Purchase", "", true)
	
	# Add item card
	if ItemManager:
		var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
		var card = card_scene.instantiate()
		card.custom_minimum_size = Vector2(80, 80)
		card.setup(item, UnifiedItemCard.DisplayMode.SHOP)
		add_to_asset_container(card)
	
	# Show price message
	var currency_symbol = "⭐" if currency == "stars" else currency
	show_message("Price: %d %s\n\nDo you want to purchase %s?" % [item_price, currency_symbol, item.display_name])
	
	# Customize buttons
	set_confirm_button_text("Buy")
	show_cancel_button("Cancel")
	
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")
	if cancel_button:
		cancel_button.set_button_style("secondary", "medium")

func setup_with_icon(title: String, description: String, icon_path: String, item_price: int, currency: String = "stars"):
	"""Setup purchase popup with icon (e.g., Battle Pass)"""
	self.price = item_price
	self.currency_type = currency
	
	setup_basic(title if title != "" else "Confirm Purchase", "", true)
	
	# Add icon with proper sizing
	if icon_path != "":
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(icon_path)
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL  # This keeps aspect ratio
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_to_asset_container(texture_rect)
	
	# Show description and price
	var currency_symbol = "⭐" if currency == "stars" else currency
	show_message("%s\n\nPrice: %d %s" % [description, item_price, currency_symbol])
	
	# Customize buttons
	set_confirm_button_text("Buy")
	show_cancel_button("Cancel")
	
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")
	if cancel_button:
		cancel_button.set_button_style("secondary", "medium")
