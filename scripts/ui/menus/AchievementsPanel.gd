# AchievementsPanel.gd
# res://Pyramids/scripts/ui/menus/AchievementsPanel.gd
extends Control

@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/Header/BackButton
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var achievements_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Achievements/ScrollContainer/AchievementsList
@onready var highscores_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Highscores/ScoresContainer

signal achievements_closed

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_achievements()
	_load_highscores()

func _load_achievements() -> void:
	# Placeholder achievements
	var achievements = [
		{"name": "First Win", "description": "Complete your first round", "unlocked": true},
		{"name": "Peak Master", "description": "Clear all peaks in one round", "unlocked": true},
		{"name": "Speed Demon", "description": "Complete a round in under 30 seconds", "unlocked": false},
		{"name": "Combo King", "description": "Achieve a 20+ combo", "unlocked": false}
	]
	
	for achievement in achievements:
		var item = preload("res://Pyramids/scenes/ui/components/AchievementItem.tscn").instantiate()
		item.setup(achievement)
		achievements_list.add_child(item)

func _load_highscores() -> void:
	# Load from save data (placeholder for now)
	var scores = {
		"top_combo": {"value": 15, "date": "2024-01-15"},
		"best_round": {"value": 5280, "date": "2024-01-14"},
		"best_run": {"value": 48750, "date": "2024-01-13"}
	}
	
	# Create score displays
	_add_score_entry("Top Combo", scores.top_combo)
	_add_score_entry("Best Round", scores.best_round)
	_add_score_entry("Best Run", scores.best_run)

func _add_score_entry(title: String, data: Dictionary) -> void:
	var container = HBoxContainer.new()
	
	var title_label = Label.new()
	title_label.text = title + ":"
	title_label.custom_minimum_size.x = 150
	
	var value_label = Label.new()
	value_label.text = str(data.value)
	value_label.custom_minimum_size.x = 100
	
	var date_label = Label.new()
	date_label.text = data.date
	date_label.modulate = Color(0.7, 0.7, 0.7)
	
	container.add_child(title_label)
	container.add_child(value_label)
	container.add_child(date_label)
	
	highscores_container.add_child(container)

func _on_back_pressed() -> void:
	achievements_closed.emit()
