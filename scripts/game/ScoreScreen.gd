# ScoreScreen.gd - Round completion score display with new layout
# Path: res://Pyramids/scripts/game/ScoreScreen.gd
# Last Updated: Manual styling for Panel and Button [Date]

extends Control

@onready var score_screen: Control = $"."
@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var v_box_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer
@onready var h_box_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/HBoxContainer
@onready var left_v_box: VBoxContainer = $Panel/MarginContainer/VBoxContainer/HBoxContainer/LeftVBox
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/LeftVBox/TitleLabel
@onready var round_score_label: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/LeftVBox/RoundScoreLabel
@onready var total_score_label: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/LeftVBox/TotalScoreLabel
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/LeftVBox/ContinueButton
@onready var right_grid_container: GridContainer = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer

# Score breakdown labels (these are the label names, you'll need to add value labels in scene)
@onready var score_label_base: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreLabelBase
@onready var score_label_cards: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreLabelCards
@onready var score_label_time: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreLabelTime
@onready var score_label_clear: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreLabelClear

# You'll need to add these value labels to the GridContainer in the scene
@onready var score_value_base: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreValueBase
@onready var score_value_cards: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreValueCards
@onready var score_value_time: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreValueTime
@onready var score_value_clear: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RightGridContainer/ScoreValueClear

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
	
	# Apply panel styling manually (inspired by StyledPanel)
	_apply_panel_styling()
	
	# Apply button styling manually (inspired by StyledButton)
	_apply_button_styling()
	
	# Apply typography and colors from ThemeConstants
	_apply_theme_styling()
	
	# Setup GridContainer columns - just the spacing, not size
	if right_grid_container:
		right_grid_container.columns = 2
		right_grid_container.add_theme_constant_override("h_separation", ThemeConstants.spacing.space_4)
		right_grid_container.add_theme_constant_override("v_separation", ThemeConstants.spacing.space_2)
	
	# Hide on start
	visible = false

func _apply_panel_styling() -> void:
	# Apply modal-style panel (white bg with shadow, like StyledPanel's "modal" style)
	if panel:
		var style = StyleBoxFlat.new()
		
		# Colors from modal style
		style.bg_color = ThemeConstants.colors.white
		style.bg_color.a = 0.98  # Slight transparency for depth
		style.border_color = ThemeConstants.colors.gray_200
		style.set_border_width_all(ThemeConstants.borders.width_thin)
		
		# Corner radius
		style.set_corner_radius_all(ThemeConstants.dimensions.corner_radius_large)
		
		# Shadow for depth (modal-like)
		style.shadow_size = ThemeConstants.shadows.size_large
		style.shadow_offset = ThemeConstants.shadows.offset_large
		style.shadow_color = ThemeConstants.shadows.color_large
		
		panel.add_theme_stylebox_override("panel", style)

func _apply_button_styling() -> void:
	# Apply primary button style (inspired by StyledButton's primary style)
	if continue_button:
		# Create style boxes for different states
		var style_normal = StyleBoxFlat.new()
		var style_hover = StyleBoxFlat.new()
		var style_pressed = StyleBoxFlat.new()
		var style_disabled = StyleBoxFlat.new()
		
		# Primary button colors
		style_normal.bg_color = ThemeConstants.colors.primary
		style_hover.bg_color = ThemeConstants.colors.primary_dark
		style_pressed.bg_color = ThemeConstants.colors.primary_dark.darkened(0.1)
		style_disabled.bg_color = ThemeConstants.colors.primary.lightened(0.3)
		
		# Corner radius and padding for all states
		for style in [style_normal, style_hover, style_pressed, style_disabled]:
			style.set_corner_radius_all(ThemeConstants.dimensions.corner_radius_medium)
			style.content_margin_left = ThemeConstants.spacing.button_padding_h
			style.content_margin_right = ThemeConstants.spacing.button_padding_h
			style.content_margin_top = ThemeConstants.spacing.button_padding_v
			style.content_margin_bottom = ThemeConstants.spacing.button_padding_v
		
		# Add subtle shadow on hover
		style_hover.shadow_size = ThemeConstants.shadows.size_small
		style_hover.shadow_offset = ThemeConstants.shadows.offset_small
		style_hover.shadow_color = ThemeConstants.shadows.color_default
		
		# Apply styles
		continue_button.add_theme_stylebox_override("normal", style_normal)
		continue_button.add_theme_stylebox_override("hover", style_hover)
		continue_button.add_theme_stylebox_override("pressed", style_pressed)
		continue_button.add_theme_stylebox_override("disabled", style_disabled)
		
		# Remove focus outline
		var empty_style = StyleBoxEmpty.new()
		continue_button.add_theme_stylebox_override("focus", empty_style)
		continue_button.focus_mode = Control.FOCUS_NONE
		
		# Font colors for button
		continue_button.add_theme_color_override("font_color", ThemeConstants.colors.white)
		continue_button.add_theme_color_override("font_hover_color", ThemeConstants.colors.white)
		continue_button.add_theme_color_override("font_pressed_color", ThemeConstants.colors.white)
		continue_button.add_theme_color_override("font_disabled_color", ThemeConstants.colors.white.darkened(0.3))
		
		# Font size - let the scene handle minimum size
		continue_button.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)

func _apply_theme_styling() -> void:
	# Typography for title - primary color, slightly larger
	if title_label:
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body_large)  # 20px
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Round score - primary color, same size as breakdown
	if round_score_label:
		round_score_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18px
		round_score_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
		round_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Total score - danger/error color for emphasis
	if total_score_label:
		total_score_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18px
		total_score_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
		total_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Left VBox - remove spacing override, let scene handle it
	if left_v_box:
		left_v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# HBox spacing between left and right sections
	if h_box_container:
		h_box_container.add_theme_constant_override("separation", ThemeConstants.spacing.space_12)
	
	# Score breakdown labels - gray900, 18px
	var breakdown_labels = [score_label_base, score_label_cards, score_label_time, score_label_clear]
	for label in breakdown_labels:
		if label:
			label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18px
			label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Score breakdown values - primary color for emphasis, 18px
	var breakdown_values = [score_value_base, score_value_cards, score_value_time, score_value_clear]
	for value_label in breakdown_values:
		if value_label:
			value_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18px
			value_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

# Remove the setup_panel_position function - now handled in scene

func show_round_complete(round_num: int, scores: Dictionary) -> void:
	# NEW LINE: Reveal all cards before showing score
	SignalBus.reveal_all_cards.emit()
	
	# Force to front
	move_to_front()
	z_index = 1000
	
	# Make sure we're visible and on top
	visible = true
	
	# Store the round score for continue logic
	current_round_score = scores.round_total
	
	# Set title
	title_label.text = "Round %d Complete!" % round_num
	
	# Set main scores
	round_score_label.text = "%d" % scores.round_total
	total_score_label.text = "Total: %d" % (GameState.total_score + scores.round_total)
	
	# Set breakdown labels (static text)
	score_label_base.text = "Base Score:"
	score_label_cards.text = "Card Bonus:"
	score_label_time.text = "Time Bonus:"
	score_label_clear.text = "Peak Bonus:"
	
	# Set breakdown values
	if score_value_base:
		score_value_base.text = "%d" % scores.base
	if score_value_cards:
		score_value_cards.text = "%d" % scores.cards
	if score_value_time:
		score_value_time.text = "%d" % scores.time
	if score_value_clear:
		score_value_clear.text = "%d" % scores.clear
	
	# Show all breakdown elements
	_set_breakdown_visibility(true)
	
	# Update button text based on game state
	var max_rounds = GameModeManager.get_max_rounds()
	if round_num >= max_rounds:
		continue_button.text = "View Results"
	else:
		continue_button.text = "Continue"
	
	# Ensure button is visible and enabled
	continue_button.visible = true
	continue_button.disabled = false
	
	# Animate entrance
	_animate_scores()

func _set_breakdown_visibility(show: bool) -> void:
	# Show/hide the entire right grid
	if right_grid_container:
		right_grid_container.visible = show

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
	if panel:
		panel.scale = Vector2(0.8, 0.8)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_continue_pressed() -> void:
	# Check if game is over based on current mode's max rounds
	var max_rounds = GameModeManager.get_max_rounds()
	if GameState.current_round >= max_rounds:
		# Hide score screen
		visible = false
		
		# Update total score and call end game
		GameState._continue_to_next_round()
		
		# Show post-game summary
		var summary_scene = preload("res://Pyramids/scenes/ui/game_ui/PostGameSummary.tscn")
		var summary = summary_scene.instantiate()
		summary.add_to_group("post_game_summary")
		get_tree().root.add_child(summary)
		
		summary.show_summary(GameState.total_score, GameState.round_stats)
	else:
		# Hide score screen and continue to next round
		visible = false
		GameState._continue_to_next_round()

func _show_game_over() -> void:
	# This is for a simplified end screen within this same panel
	# But since PostGameSummary handles the detailed view, we can keep this minimal
	
	title_label.text = "Game Complete!"
	
	var final_total = GameState.total_score + current_round_score
	
	round_score_label.text = "Final: %d" % final_total
	total_score_label.text = "Mode: %s" % GameModeManager.get_mode_display_name()
	
	# Hide the breakdown for game over
	_set_breakdown_visibility(false)
	
	# Update button
	continue_button.text = "Return to Menu"
	continue_button.visible = true
	continue_button.disabled = false
	
	# Disconnect and reconnect for menu return
	if continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	continue_button.pressed.connect(_on_play_again_pressed)
	
	# Update GameState
	GameState.total_score = final_total

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
