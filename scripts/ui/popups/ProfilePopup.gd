# ProfilePopup.gd - Player profile placeholder popup
# Location: res://Pyramids/scripts/ui/popups/ProfilePopup.gd
# Last Updated: Initial placeholder implementation

extends PopupBase
class_name ProfilePopup

var player_data: Dictionary = {}

func setup(player_name: String, score_data: Dictionary = {}):
	"""Setup profile popup with player data"""
	self.player_data = score_data
	
	# Simple coming soon message
	set_title("Coming Soon")
	
	# Optional: Add player name to message
	if player_name != "":
		show_message("Player profile for %s will be available soon!" % player_name)
	else:
		show_message("Player profiles will be available soon!")
	
	# Single button
	set_confirm_button_text("Okay!")
	hide_cancel_button()
	
	# Apply normal button style after initialization
	call_deferred("_apply_button_style")

func _apply_button_style():
	"""Apply button styling after initialization"""
	if confirm_button:
		confirm_button.set_button_style("normal", "medium")
