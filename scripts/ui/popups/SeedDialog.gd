# SeedDialog.gd - Seed display and action dialog
# Location: res://Pyramids/scripts/ui/popups/SeedDialog.gd
# Last Updated: Initial implementation with placeholder actions

extends ColorRect

@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var play_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/PlayButton
@onready var copy_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/CopyButton
@onready var leave_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/LeaveButton

signal confirmed
signal play_pressed(seed: int)
signal copy_pressed(seed: int)

var seed_value: int = 0

func setup(seed: int, player_name: String = ""):
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	seed_value = seed
	
	# Set title with seed number
	if title_label:
		title_label.text = "Seed: %d" % seed

func _ready():
	# Enable input on the backdrop
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_backdrop_input)
	
	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	
	if copy_button:
		copy_button.pressed.connect(_on_copy_pressed)
	
	if leave_button:
		leave_button.pressed.connect(func():
			queue_free()
		)

func _on_play_pressed():
	"""Handle play button - placeholder for now"""
	print("[SeedDialog] Play pressed with seed: %d" % seed_value)
	# TODO: Implement play with seed functionality
	play_pressed.emit(seed_value)
	# Don't close yet - would need game start logic

func _on_copy_pressed():
	"""Handle copy button - actually copies to clipboard"""
	print("[SeedDialog] Copy pressed - seed: %d" % seed_value)
	DisplayServer.clipboard_set(str(seed_value))
	copy_pressed.emit(seed_value)
	# Could show feedback here

func _on_backdrop_input(event: InputEvent):
	"""Handle clicks on backdrop to close"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click was on backdrop (not on panel)
		var panel = $StyledPanel
		if panel:
			var panel_rect = panel.get_global_rect()
			if not panel_rect.has_point(event.global_position):
				queue_free()
