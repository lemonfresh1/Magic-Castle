# ErrorPopup.gd - Error notification popup (FIXED TITLE COLOR)
# Location: res://Pyramids/scripts/ui/popups/ErrorPopup.gd
# Last Updated: Added red title color for errors

extends PopupBase
class_name ErrorPopup

func _ready():
	super._ready()
	# Override title color for errors
	call_deferred("_apply_error_title_style")

func _apply_error_title_style():
	"""Apply error-specific title styling"""
	if title_label and ThemeConstants:
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.error)

func setup(title: String, message: String, button_text: String = "OK"):
	"""Basic error setup"""
	setup_basic(title if title != "" else "Error", message, false)
	
	# Single acknowledge button
	set_confirm_button_text(button_text)
	hide_cancel_button()
	
	# Defer button styling
	call_deferred("_apply_error_button_styles")

func setup_insufficient_funds(required: int, current: int, currency: String = "stars"):
	"""Specific setup for insufficient funds error"""
	set_title("Insufficient Funds")
	
	var currency_symbol = "⭐" if currency == "stars" else currency
	var message = "You don't have enough %s!\n\nRequired: %d %s\nYou have: %d %s" % [
		currency, required, currency_symbol, current, currency_symbol
	]
	show_message(message)
	
	set_confirm_button_text("OK")
	hide_cancel_button()
	
	# Defer button styling
	call_deferred("_apply_error_button_styles")

func _apply_error_button_styles():
	"""Apply button styles after initialization"""
	if confirm_button:
		confirm_button.set_button_style("danger", "medium")  # Red button for error
