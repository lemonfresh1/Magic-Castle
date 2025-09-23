# ReplayDialog.gd - Replay viewer dialog
# Location: res://Pyramids/scripts/ui/popups/ReplayDialog.gd
# Last Updated: Initial implementation with placeholder actions

extends ColorRect

@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var play_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/PlayButton  # Actually "Watch" button
@onready var leave_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/LeaveButton

signal confirmed
signal watch_pressed(replay_data: Dictionary)

var replay_data: Dictionary = {}

func setup(score_data: Dictionary = {}):
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	replay_data = score_data
	
	# Set title
	if title_label:
		title_label.text = "Replay"

func _ready():
	# Enable input on the backdrop
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_backdrop_input)

	# Update button text if needed
	if play_button:
		play_button.text = "Watch"
		play_button.pressed.connect(_on_watch_pressed)
	
	if leave_button:
		leave_button.pressed.connect(func():
			queue_free()
		)

func _on_watch_pressed():
	"""Handle watch button - placeholder for now"""
	print("[ReplayDialog] Watch pressed for replay")
	# TODO: Implement replay viewer functionality
	watch_pressed.emit(replay_data)
	# Don't close - replay viewer would open

func _on_backdrop_input(event: InputEvent):
	"""Handle clicks on backdrop to close"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click was on backdrop (not on panel)
		var panel = $StyledPanel
		if panel:
			var panel_rect = panel.get_global_rect()
			if not panel_rect.has_point(event.global_position):
				queue_free()
