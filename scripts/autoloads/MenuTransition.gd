# MenuTransition.gd - Autoload for smooth menu transitions
# Path: res://Pyramids/scripts/autoloads/MenuTransition.gd
extends Node

var transition_scene = preload("res://Pyramids/scenes/ui/components/TransitionScreen.tscn")
var is_transitioning: bool = false

func change_scene(path: String) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	var transition = transition_scene.instantiate()
	get_tree().root.add_child(transition)
	
	# Fade in
	await transition.fade_in()
	
	# Change scene
	get_tree().change_scene_to_file(path)
	
	# Fade out
	await transition.fade_out()
	transition.queue_free()
	is_transitioning = false

func overlay_scene(scene: PackedScene) -> Node:
	var instance = scene.instantiate()
	get_tree().root.add_child(instance)
	
	# Animate in
	instance.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(instance, "modulate:a", 1.0, 0.3)
	
	return instance
