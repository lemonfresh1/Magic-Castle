# LeavePopup.gd - Leave confirmation popup (FIXED BUTTON POSITIONING)
# Location: res://Pyramids/scripts/ui/popups/LeavePopup.gd
# Last Updated: Fixed button positioning - Leave left (red), Stay right (green)

extends PopupBase
class_name LeavePopup

func _ready():
	super._ready()
	# Override button order in _ready
	call_deferred("_reorder_buttons")

func _reorder_buttons():
	"""Ensure Leave is on left, Stay on right"""
	if button_container and confirm_button and cancel_button:
		# Move confirm button (Leave) to first position
		button_container.move_child(confirm_button, 0)
		button_container.move_child(cancel_button, 1)

func setup(title: String, message: String):
	"""Setup leave confirmation popup"""
	setup_basic(
		title if title != "" else "Leave Lobby?",
		message if message != "" else "Are you sure you want to leave the current lobby?",
		true
	)
	
	# Customize buttons
	set_confirm_button_text("Leave")
	show_cancel_button("Stay")
	
	# Leave button gets danger style (red), Stay gets primary (green)
	if confirm_button:
		confirm_button.set_button_style("danger", "medium")
	if cancel_button:
		cancel_button.set_button_style("primary", "medium")
