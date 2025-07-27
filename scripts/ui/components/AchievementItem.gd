# AchievementItem.gd
extends Panel

@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $HBoxContainer/VBoxContainer/DescriptionLabel
@onready var locked_overlay: ColorRect = $LockedOverlay

var achievement_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	achievement_data = data
	name_label.text = data.name
	description_label.text = data.description
	
	if data.unlocked:
		locked_overlay.visible = false
		modulate = Color.WHITE
	else:
		locked_overlay.visible = true
		modulate = Color(0.5, 0.5, 0.5)
	
	# Set icon based on achievement type
	# icon.texture = load("res://path/to/icon.png")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if achievement_data.unlocked:
			# Show achievement details
			print("Achievement: %s - %s" % [achievement_data.name, achievement_data.description])
