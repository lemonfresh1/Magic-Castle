# TestScene.gd - Minimal test harness
extends Control

func _ready():
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Create the swipe button
	var button = Control.new()
	button.set_script(load("res://SwipePlayButton.gd"))  # Adjust path to your script
	center.add_child(button)
	
	# Connect signals to see output
	button.play_pressed.connect(func(mode): print("PLAY: " + mode))
	button.mode_changed.connect(func(mode): print("MODE: " + mode))
