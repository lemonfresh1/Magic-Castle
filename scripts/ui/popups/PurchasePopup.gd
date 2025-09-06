# PurchasePopup.gd - Purchase confirmation popup (REDESIGNED UI)
# Location: res://Pyramids/scripts/ui/popups/PurchasePopup.gd
# Last Updated: Simplified UI with single price button

extends PopupBase
class_name PurchasePopup

var price: int = 0
var currency_type: String = "stars"

func setup(title: String, message: String, item_price: int, currency: String = "stars"):
	"""Basic purchase setup - backward compatibility"""
	self.price = item_price
	self.currency_type = currency
	
	setup_basic(title if title != "" else "Purchase", message, true)
	
	# Price button with icon
	var currency_symbol = "⭐" if currency == "stars" else currency
	set_confirm_button_text("%s %d" % [currency_symbol, item_price])
	show_cancel_button("Cancel")
	
	# Green price button, secondary cancel
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")
	if cancel_button:
		cancel_button.set_button_style("secondary", "medium")

func setup_with_item(title: String, item: UnifiedItemData, item_price: int, currency: String = "stars"):
	"""Setup purchase popup with item - redesigned version"""
	self.price = item_price
	self.currency_type = currency
	
	# Simple title
	set_title("Purchase")
	
	# Add item card only
	if ItemManager:
		var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
		var card = card_scene.instantiate()
		card.custom_minimum_size = Vector2(120, 120)
		card.setup(item, UnifiedItemCard.DisplayMode.SHOP)
		add_to_asset_container(card)
	
	# Hide message to reduce redundancy
	hide_message()
	
	# Price button with icon
	var currency_symbol = "⭐" if currency == "stars" else currency
	set_confirm_button_text("%s %d" % [currency_symbol, item_price])
	show_cancel_button("Cancel")
	
	# Defer button styling
	call_deferred("_apply_purchase_button_styles")

func setup_with_icon(title: String, description: String, icon_path: String, item_price: int, currency: String = "stars"):
	"""Setup purchase popup with icon (e.g., Battle Pass)"""
	self.price = item_price
	self.currency_type = currency
	
	# Simple title
	set_title("Purchase")
	
	# Add icon
	if icon_path != "":
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(icon_path)
		texture_rect.custom_minimum_size = Vector2(80, 80)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_to_asset_container(texture_rect)
	
	# Show description only
	show_message(description)
	
	# Price button with icon
	var currency_symbol = "⭐" if currency == "stars" else currency
	set_confirm_button_text("%s %d" % [currency_symbol, item_price])
	show_cancel_button("Cancel")
	
	# Defer button styling
	call_deferred("_apply_purchase_button_styles")

func _apply_purchase_button_styles():
	"""Apply button styles after initialization"""
	if confirm_button:
		confirm_button.set_button_style("primary", "medium")  # Green price button
	if cancel_button:
		cancel_button.set_button_style("danger", "medium")  # Red cancel button
