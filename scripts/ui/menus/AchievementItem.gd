# AchievementItem.gd - Individual achievement display item
# Path: res://Magic-Castle/scripts/ui/menus/AchievementItem.gd
# Fixed function naming (*on*gui_input → _on_gui_input), added progress visibility logic, uses actual star values from achievement data
extends Panel

@onready var icon = $MarginContainer/VBoxContainer/IconContainer/Icon
@onready var name_label = $MarginContainer/VBoxContainer/Name
@onready var progress_bar = $MarginContainer/VBoxContainer/ProgressBar
@onready var star_label = $MarginContainer/VBoxContainer/StarReward

var achievement_id: String
var achievement_data: Dictionary

func setup(id: String):
	achievement_id = id
	achievement_data = AchievementManager.achievements[id]
	
	# Set icon
	var icon_path = "res://Magic-Castle/assets/icons/achievements/" + achievement_data.icon
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	# Set name
	name_label.text = achievement_data.name
	
	# Set progress
	var progress = AchievementManager.get_achievement_progress(id)
	progress_bar.value = progress * 100
	
	# Set star reward from achievement data
	star_label.text = "⭐ %d" % achievement_data.stars
	
	# Handle locked state
	if not AchievementManager.is_unlocked(id):
		modulate.a = 0.5  # Greyed out
		
		# Show progress even when locked
		if progress > 0 and progress < 1.0:
			progress_bar.visible = true
		else:
			progress_bar.visible = false
	else:
		modulate.a = 1.0
		progress_bar.visible = true
	
	# Make clickable
	gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		# TODO: Show detailed achievement info in a proper dialog
		print("Achievement: %s - %s" % [achievement_data.name, achievement_data.description])
	#	print("Progress: %.1f%%" % (AchievementManager.get_achievement_progress(id) * 100))
		print("Reward: %d stars" % achievement_data.stars)
