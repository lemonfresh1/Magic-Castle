# ScoreScreen.gd
extends Control

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var score_label_base: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabelBase
@onready var score_label_cards: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabelCards
@onready var score_label_time: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabelTime
@onready var score_label_clear: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabelClear
@onready var round_score_label: Label = $Panel/MarginContainer/VBoxContainer/RoundScoreLabel
@onready var total_score_label: Label = $Panel/MarginContainer/VBoxContainer/TotalScoreLabel
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/ContinueButton

var current_round_score: int = 0

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.visible = true  # Ensure it's visible
	
	# CRITICAL: Set very high z-index to appear above all cards
	z_index = 1000
	
	# Also set the panel to high z-index
	if panel:
		panel.z_index = 1001
	
	# Set as top level to ensure it's always on top
	set_as_top_level(true)
	
	# Position at center of screen
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	
	# Hide on start
	visible = false
	
	print("ScoreScreen initialized with z_index: %d" % z_index)

func show_round_complete(round_num: int, scores: Dictionary) -> void:
	# Force to front
	move_to_front()
	z_index = 1000
	
	# Make sure we're visible and on top
	visible = true
	
	# Store the round score for continue logic
	current_round_score = scores.round_total
	
	# Set title
	if GameState.board_cleared:
		title_label.text = "Round %d Complete!" % round_num
	else:
		title_label.text = "Round %d Failed!" % round_num
	
	# Display scores from the dictionary
	score_label_base.text = "Base Score: %d" % scores.base
	score_label_cards.text = "Cards Bonus: %d" % scores.cards
	score_label_time.text = "Time Bonus: %d" % scores.time
	score_label_clear.text = "Peak Bonus: %d" % scores.clear
	
	if round_score_label:
		round_score_label.text = "Round Score: %d" % scores.round_total
		round_score_label.add_theme_font_size_override("font_size", 32)
	
	# Total is what we had before + this round
	total_score_label.text = "Total Score: %d" % (GameState.total_score + scores.round_total)
	total_score_label.add_theme_font_size_override("font_size", 28)
	
	# Update button text based on game state
	if round_num >= GameConstants.MAX_ROUNDS:
		continue_button.text = "Play Again"
	else:
		continue_button.text = "Continue"
	
	# Ensure button is visible and enabled
	continue_button.visible = true
	continue_button.disabled = false
	
	# Animate score counting
	_animate_scores()
	
	print("Score screen shown with z_index: %d" % z_index)

func _animate_scores() -> void:
	# Ensure we're on top
	z_index = 1000
	move_to_front()
	
	# Fade in
	modulate.a = 0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Scale panel
	panel.scale = Vector2(0.8, 0.8)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_continue_pressed() -> void:
	print("Continue button pressed!")
	
	# Check if game is over
	if GameState.current_round >= GameConstants.MAX_ROUNDS:
		_show_game_over()
	else:
		# Hide score screen
		visible = false
		
		# Continue to next round directly through GameState
		GameState._continue_to_next_round()

func _show_game_over() -> void:
	print("Game Over! Final Score: %d" % GameState.total_score)
	
	# Update UI for game over
	title_label.text = "Game Complete!"
	
	# Hide score breakdown, show final score
	score_label_base.visible = false
	score_label_cards.visible = false
	score_label_time.visible = false
	score_label_clear.visible = false
	round_score_label.visible = false
	
	total_score_label.text = "Final Score: %d" % GameState.total_score
	total_score_label.add_theme_font_size_override("font_size", 40)
	
	continue_button.text = "Play Again"
	continue_button.visible = true
	continue_button.disabled = false
	
	# Disconnect old signal and connect new one
	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	continue_button.pressed.connect(_on_play_again_pressed)

func _on_play_again_pressed() -> void:
	# Reset game state
	GameState.current_round = 1
	GameState.total_score = 0
	GameState.round_scores.clear()
	
	# Hide score screen
	visible = false
	
	# Start new game
	GameState.start_new_game("single")

# Override to ensure we stay on top
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		z_index = 1000
		move_to_front()
	elif what == NOTIFICATION_READY:
		z_index = 1000
