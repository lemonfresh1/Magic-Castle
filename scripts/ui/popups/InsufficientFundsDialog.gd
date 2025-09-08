extends ColorRect

# Make sure these match EXACTLY what's in your scene
@onready var required_label = $StyledPanel/MarginContainer/VBoxContainer/RequiredLabel
@onready var current_label = $StyledPanel/MarginContainer/VBoxContainer/CurrentLabel  
@onready var shortage_label = $StyledPanel/MarginContainer/VBoxContainer/ShortageLabel
@onready var close_button = $StyledPanel/MarginContainer/VBoxContainer/CloseButton

func setup(required: int, current: int):
	# Wait for ready if needed
	if not is_node_ready():
		await ready
		
	# Debug check
	if not required_label:
		push_error("RequiredLabel not found!")
		print("VBox children: ", $StyledPanel/MarginContainer/VBoxContainer.get_children())
		return
	
	required_label.text = "Required: %d" % required
	current_label.text = "You have: %d" % current
	shortage_label.text = "Need %d more" % (required - current)

func _ready():
	close_button.pressed.connect(func():
		queue_free()
	)
