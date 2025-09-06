# KickPopup.gd - Kick confirmation popup (FIXED BUTTON POSITIONING)
# Location: res://Pyramids/scripts/ui/popups/KickPopup.gd
# Last Updated: Fixed button positioning - Kick left (red), Cancel right (green)

extends PopupBase
class_name KickPopup

var player_name: String = ""

func _ready():
	super._ready()
	# Override button order in _ready
	call_deferred("_reorder_buttons")

func _reorder_buttons():
	"""Ensure Kick is on left, Cancel on right"""
	if button_container and confirm_button and cancel_button:
		# Move confirm button (Kick) to first position
		button_container.move_child(confirm_button, 0)
		button_container.move_child(cancel_button, 1)

func setup(title: String, message: String = "", player_name_val: String = ""):
	"""Setup kick popup with player name"""
	self.player_name = player_name_val
	
	# Use base class setup
	setup_basic(title if title != "" else "Kick Player", "", true)
	
	# Customize message
	if player_name_val != "":
		show_message("Are you sure you want to kick %s from the lobby?" % player_name_val)
	elif message != "":
		show_message(message)
	
	# Customize button text and styles
	set_confirm_button_text("Kick")
	show_cancel_button("Cancel")
	
	# Kick gets danger style (red), Cancel gets primary (green)
	if confirm_button:
		confirm_button.set_button_style("danger", "medium")
	if cancel_button:
		cancel_button.set_button_style("primary", "medium")
