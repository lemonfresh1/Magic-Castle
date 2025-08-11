# TransitionScreen.gd
# Path: res://Pyramids/scripts/ui/components/TransitionScreen.gd
extends ColorRect

signal fade_complete

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_in(duration: float = 0.3) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished
	fade_complete.emit()

func fade_out(duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_complete.emit()
