# KickedDialog.gd - Notification when kicked from lobby
# Location: res://Pyramids/scripts/ui/popups/KickedDialog.gd
# Last Updated: Refactored to title-only, no message label

extends ColorRect

signal confirmed

@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var confirm_button = $StyledPanel/MarginContainer/VBoxContainer/ConfirmButton

func _ready():
	# Connect button
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Style button
	if UIStyleManager:
		UIStyleManager.apply_button_style(confirm_button, "primary", "medium")

func setup():
	"""Setup kicked notification popup"""
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	# Set title
	if title_label:
		title_label.text = "You've been kicked"

func _on_confirm_pressed():
	"""User acknowledged being kicked"""
	confirmed.emit()
	queue_free()
