# SimplifiedSettingsMenu.gd - Just for testing
extends Control

@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/BackButton

signal settings_closed

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Add a simple test label
	var label = Label.new()
	label.text = "Settings Menu - Work in Progress"
	$Panel/MarginContainer/VBoxContainer.add_child(label)

func _on_back_pressed() -> void:
	settings_closed.emit()
