# MissionProgress.gd - Displays mission progress with animation
# Path: res://Pyramids/scripts/ui/components/MissionProgress.gd
# Shows mission title, description, and animated progress
extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label: Label = $MarginContainer/VBoxContainer/ProgressLabel

var mission_data: Dictionary = {}
var old_progress: int = 0
var new_progress: int = 0
var pending_setup: bool = false

func _ready() -> void:
	# If setup was called before _ready, apply it now
	if pending_setup:
		_apply_setup()

func setup(mission: Dictionary, old_value: int, new_value: int) -> void:
	mission_data = mission
	old_progress = old_value
	new_progress = new_value
	
	# Check if nodes are ready
	if not is_node_ready():
		pending_setup = true
		return
	
	_apply_setup()

func _apply_setup() -> void:
	# Update UI
	if title_label:
		title_label.text = mission_data.title
	if progress_bar:
		progress_bar.max_value = mission_data.target
		progress_bar.value = old_progress
	if progress_label:
		progress_label.text = "%s %d/%d" % [mission_data.description, old_progress, mission_data.target]
	
	pending_setup = false

func animate_progress() -> void:
	if not progress_bar or not progress_label:
		return
		
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", new_progress, 0.8)
	tween.parallel().tween_method(_update_progress_label, old_progress, new_progress, 0.8)

func _update_progress_label(value: int) -> void:
	if progress_label:
		progress_label.text = "%s %d/%d" % [mission_data.get("description", ""), value, mission_data.get("target", 0)]
