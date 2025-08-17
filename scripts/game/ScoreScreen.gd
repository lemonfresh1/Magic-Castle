# ScoreScreen.gd - Round completion score display
# Path: res://Pyramids/scripts/game/ScoreScreen.gd
# Last Updated: Applied UIStyleManager styling [Date]

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
	
	# Apply UIStyleManager styling
	_apply_ui_styling()
	
	# Position at center of screen with proper sizing
	_setup_panel_position()
	
	# Hide on start
	visible = false

func _apply_ui_styling() -> void:
	# Apply panel styling with transparency
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = UIStyleManager.colors.white
		style.bg_color.a = 0.95  # Slight transparency as requested
		style.border_color = UIStyleManager.colors.gray_200
		style.set_border_width_all(UIStyleManager.borders.width_thin)
		style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_large)
		
		# Add shadow for depth
		style.shadow_size = UIStyleManager.shadows.size_large
		style.shadow_offset = UIStyleManager.shadows.offset_large
		style.shadow_color = UIStyleManager.shadows.color_medium
		
		panel.add_theme_stylebox_override("panel", style)

	# Round score - larger and primary color
	if round_score_label:
		round_score_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_h3)
		round_score_label.add_theme_color_override("font_color", UIStyleManager.colors.primary)
		round_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Total score - same size as round but different color
	if total_score_label:
		total_score_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_h3)
		total_score_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
		total_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Style continue button
	if continue_button:
		UIStyleManager.apply_button_style(continue_button, "primary", "large")
		continue_button.custom_minimum_size.x = 200
		
		# Center the button in its container
		var parent = continue_button.get_parent()
		if parent is VBoxContainer:
			continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Apply margins to the container - FURTHER REDUCED BOTTOM
	var margin_container = $Panel/MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", UIStyleManager.spacing.space_8)
		margin_container.add_theme_constant_override("margin_right", UIStyleManager.spacing.space_8)
		margin_container.add_theme_constant_override("margin_top", UIStyleManager.spacing.space_12)  # 48px top margin
		margin_container.add_theme_constant_override("margin_bottom", UIStyleManager.spacing.space_1)  # 4px bottom margin only
	
	# Apply spacing to VBoxContainer
	var vbox = $Panel/MarginContainer/VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", UIStyleManager.spacing.space_4)
	
	# Apply typography styling
	if title_label:
		title_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_title)
		title_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Subscore labels - smaller size and INDENTED
	var subscore_labels = [score_label_base, score_label_cards, score_label_time, score_label_clear]
	for label in subscore_labels:
		if label:
			label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_body_small)
			label.add_theme_color_override("font_color", UIStyleManager.colors.gray_600)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			# Add left margin to indent the text
			if label.get_parent() is VBoxContainer:
				# Create a margin container for each label to add indentation
				var parent = label.get_parent()
				var index = label.get_index()
				parent.remove_child(label)
				
				var indent_container = MarginContainer.new()
				indent_container.add_theme_constant_override("margin_left", 30)  # 30px indent as requested
				parent.add_child(indent_container)
				parent.move_child(indent_container, index)
				indent_container.add_child(label)

func _setup_panel_position() -> void:
	# Center the entire Control
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	
	# Set panel size - increased height by 15px
	if panel:
		panel.custom_minimum_size = Vector2(420, 415)  # Increased from 400 to 415
		panel.size = Vector2(420, 415)
		
		# Properly center it using anchors and margins
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		
		# Use negative margins to center (half of the size)
		panel.offset_left = -210
		panel.offset_right = 210
		panel.offset_top = -207.5  # Half of 415
		panel.offset_bottom = 207.5

func show_round_complete(round_num: int, scores: Dictionary) -> void:
	# Force to front
	move_to_front()
	z_index = 1000
	
	# Make sure we're visible and on top
	visible = true
	
	# Store the round score for continue logic
	current_round_score = scores.round_total
	
	# Set title with new format
	title_label.text = "Round %d: Score Summary" % round_num
	
	# Display scores from the dictionary
	score_label_base.text = "Base Score: %d" % scores.base
	score_label_cards.text = "Card Bonus: %d" % scores.cards
	score_label_time.text = "Time Bonus: %d" % scores.time
	score_label_clear.text = "Peak Bonus: %d" % scores.clear
	
	# Make all score labels visible for round screen
	score_label_base.visible = true
	score_label_cards.visible = true
	score_label_time.visible = true
	score_label_clear.visible = true
	
	if round_score_label:
		round_score_label.text = "Round Score: %d" % scores.round_total
		round_score_label.visible = true
	
	# Total is what we had before + this round
	total_score_label.text = "Total Score: %d" % (GameState.total_score + scores.round_total)
	
	# Update button text based on game state
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
		
		# CRITICAL: Call _continue_to_next_round which will update total_score AND call _end_game
		GameState._continue_to_next_round()
		
		# Show post-game summary
		var summary_scene = preload("res://Pyramids/scenes/ui/game_ui/PostGameSummary.tscn")
		var summary = summary_scene.instantiate()
		summary.add_to_group("post_game_summary")
		get_tree().root.add_child(summary)
		
		# GameState.total_score is now correctly calculated
		summary.show_summary(GameState.total_score, GameState.round_stats)
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
	summary_text += "Game Mode: %s" % GameModeManager.get_mode_display_name()
	
	# Use the base score label to show summary (it's multiline capable)
	score_label_base.text = summary_text
	score_label_base.visible = true
	score_label_base.add_theme_font_size_override("font_size", UIStyleManager.typography.size_caption)
	
	# Hide other score breakdowns
	score_label_cards.visible = false
	score_label_time.visible = false
	score_label_clear.visible = false
	round_score_label.visible = false
	
	# Show final score prominently - USE THE CORRECTED TOTAL
	total_score_label.text = "Final Score: %d" % final_total
	total_score_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_h1)
	
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
