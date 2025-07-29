# AchievementPopup.gd - Popup notification for achievement unlocks
# Path: res://Magic-Castle/scripts/ui/components/AchievementPopup.gd
# Fixed function names, added achievement queue system, enhanced animation with scale effect, added star display
extends Control

@onready var panel = $Panel
@onready var icon: TextureRect = $Panel/MarginContainer/HBoxContainer/Icon
@onready var achievement_name: Label = $Panel/MarginContainer/HBoxContainer/AchievementName


# Queue for multiple achievements
var achievement_queue: Array[String] = []
var is_showing: bool = false

func _ready():
	visible = false
	z_index = 1100  # Above score screen
	set_as_top_level(true)  # Ensure it renders above everything
	
	# Position at top-center of screen
	anchor_left = 1
	anchor_right = 1
	anchor_top = 0.1
	anchor_bottom = 0.1
	# Offset from right edge
	position.x = -10  # 10 pixels from right border
	
	# Set pivot for scaling animation from right side
	pivot_offset = Vector2(size.x, size.y / 2)  # Changed to scale from right
	
	# Connect to achievement system
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String):
	# Queue the achievement
	achievement_queue.append(achievement_id)
	
	# Show if not already showing
	if not is_showing:
		_show_next_achievement()

func _show_next_achievement():
	if achievement_queue.is_empty():
		is_showing = false
		return
	
	is_showing = true
	var achievement_id = achievement_queue.pop_front()
	var achievement = AchievementManager.achievements[achievement_id]
	
	# Set content
	achievement_name.text = achievement.name
	
	# Set icon
	var icon_path = "res://Magic-Castle/assets/icons/achievements/" + achievement.icon
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	# Play sound
	AudioSystem.play_sound("Success")
	
	# Show popup
	_animate_popup()

func _animate_popup():
	visible = true
	modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	
	# Animate in
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Wait and hide
	tween.set_parallel(false)
	tween.tween_interval(2.5)  # Show for 2.5 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		visible = false
		_show_next_achievement()  # Show next in queue if any
	)
