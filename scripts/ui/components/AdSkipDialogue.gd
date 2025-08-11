# AdSkipDialog.gd
# Path: res://Pyramids/scripts/ui/components/AdSkipDialog.gd
extends Control

@onready var info_label: Label = $Panel/VBoxContainer/Info
@onready var skip_button: Button = $Panel/VBoxContainer/Buttons/SkipButton
@onready var watch_button: Button = $Panel/VBoxContainer/Buttons/WatchButton

signal skip_pressed
signal watch_pressed

func _ready() -> void:
	var skips = SettingsSystem.get_ad_skips()
	info_label.text = "You have %d skips remaining" % skips
	
	skip_button.pressed.connect(func(): skip_pressed.emit())
	watch_button.pressed.connect(func(): watch_pressed.emit())
	
	# Close on background click
	$Background.gui_input.connect(_on_background_input)

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()
