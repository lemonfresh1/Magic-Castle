# ScoreScreen.gd
# Path: res://Magic-Castle/scripts/game/ScoreScreen.gd
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

signal continue_pressed

var current_round_score: int = 0

func _ready() -> void:
	if continue_button:
		# Disconnect any existing connections first
		if continue_button.pressed.is_connected(_on_play_again_pressed):
			continue_button.pressed.disconnect(_on_play_again_pressed)
		if continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.disconnect(_on_continue_pressed)
			
		# Connect to the default handler
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.visible = true
	
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
	
	# Make all score labels visible for round screen
	score_label_base.visible = true
	score_label_cards.visible = true
	score_label_time.visible = true
	score_label_clear.visible = true
	
	if round_score_label:
		round_score_label.text = "Round Score: %d" % scores.round_total
		round_score_label.add_theme_font_size_override("font_size", 32)
		round_score_label.visible = true
	
	# Total is what we had before + this round
	total_score_label.text = "Total Score: %d" % (GameState.total_score + scores.round_total)
	total_score_label.add_theme_font_size_override("font_size", 28)
	
	# Update button text based on game state - FIXED to use GameModeManager
	var max_rounds = GameModeManager.get_max_rounds()
	if round_num >= max_rounds:
		continue_button.text = "View Results"  # Show game over screen next
	else:
		continue_button.text = "Continue"
	
	# Ensure button is visible and enabled
	continue_button.visible = true
	continue_button.disabled = false
	
	# Animate score counting
	_animate_scores()

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
	# Check if game is over based on current mode's max rounds
	var max_rounds = GameModeManager.get_max_rounds()
	if GameState.current_round >= max_rounds:
		# Hide score screen
		visible = false
		
		# Show post-game summary
		var summary_scene = preload("res://Magic-Castle/scenes/ui/game_ui/PostGameSummary.tscn")
		var summary = summary_scene.instantiate()
		summary.add_to_group("post_game_summary")
		get_tree().root.add_child(summary)
		
		# Calculate final total including current round
		var final_total = GameState.total_score + current_round_score
		summary.show_summary(final_total, GameState.round_stats)
	else:
		# Hide score screen and continue to next round
		visible = false
		GameState._continue_to_next_round()

func _show_game_over() -> void:
	# Update UI for game over
	title_label.text = "Game Complete!"
	
	# CRITICAL FIX: Add the current round score to total before displaying
	var final_total = GameState.total_score + current_round_score
	
	# Create round summary
	var summary_text = "=== ROUND SUMMARY ===\n\n"
	var best_round = 0
	var best_score = 0
	
	for stat in GameState.round_stats:
		summary_text += "Round %d: %d pts %s" % [
			stat.round, 
			stat.score, 
			"✓" if stat.cleared else "✗"
		]
		if stat.time_left > 0:
			summary_text += " (%ds left)" % stat.time_left
		summary_text += "\n"
		
		# Track best round
		if stat.score > best_score:
			best_score = stat.score
			best_round = stat.round
	
	# Add statistics
	summary_text += "\n=== STATISTICS ===\n"
	summary_text += "Total Rounds: %d\n" % GameState.round_stats.size()
	summary_text += "Rounds Cleared: %d\n" % GameState.round_stats.filter(func(s): return s.cleared).size()
	summary_text += "Best Round: #%d (%d pts)\n" % [best_round, best_score]
	summary_text += "Game Mode: %s" % GameModeManager.get_current_mode().display_name
	
	# Use the base score label to show summary (it's multiline capable)
	score_label_base.text = summary_text
	score_label_base.visible = true
	score_label_base.add_theme_font_size_override("font_size", 14)
	
	# Hide other score breakdowns
	score_label_cards.visible = false
	score_label_time.visible = false
	score_label_clear.visible = false
	round_score_label.visible = false
	
	# Show final score prominently - USE THE CORRECTED TOTAL
	total_score_label.text = "Final Score: %d" % final_total
	total_score_label.add_theme_font_size_override("font_size", 40)
	
	# Also update GameState so it's correct if needed elsewhere
	GameState.total_score = final_total
	
	continue_button.text = "Return to Menu"
	continue_button.visible = true
	continue_button.disabled = false
	
	# Disconnect old signal and connect new one
	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	continue_button.pressed.connect(_on_play_again_pressed)

func _on_play_again_pressed() -> void:
	visible = false
	GameState._return_to_menu()

# Override to ensure we stay on top
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		z_index = 1000
		move_to_front()
	elif what == NOTIFICATION_READY:
		z_index = 1000
