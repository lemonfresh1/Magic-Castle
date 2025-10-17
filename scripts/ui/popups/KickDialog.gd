# KickDialog.gd - Confirmation popup for kicking a player
# Location: res://Pyramids/scripts/ui/popups/KickDialog.gd
# Last Updated: Refactored to title-only, no message label

extends ColorRect

signal confirmed
signal cancelled

@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var button_hbox = $StyledPanel/MarginContainer/VBoxContainer/ButtonHBox
@onready var kick_button = $StyledPanel/MarginContainer/VBoxContainer/ButtonHBox/KickButton
@onready var cancel_button = $StyledPanel/MarginContainer/VBoxContainer/ButtonHBox/CancelButton

var player_name: String = ""

func _ready():
	# Connect buttons
	kick_button.pressed.connect(_on_kick_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Style buttons
	if UIStyleManager:
		UIStyleManager.apply_button_style(kick_button, "danger", "medium")
		UIStyleManager.apply_button_style(cancel_button, "primary", "medium")

func setup(player_name_val: String):
	"""Setup kick confirmation popup"""
	player_name = player_name_val
	
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	# Set title
	if title_label:
		title_label.text = "Kick player %s?" % player_name

func _on_kick_pressed():
	"""User confirmed kick"""
	confirmed.emit()
	queue_free()

func _on_cancel_pressed():
	"""User cancelled kick"""
	cancelled.emit()
	queue_free()
