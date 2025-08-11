# AchievementItemCard.gd - Achievement display card with flip-to-description functionality
# Location: res://Pyramids/scripts/ui/achievements/AchievementItemCard.gd
# Last Updated: Removed ProgressInfoLabel and cleaned up duplicates [Date]

extends PanelContainer

signal achievement_clicked(achievement_id: String)

# Front side (normal view)
@onready var front_container: VBoxContainer = $MarginContainer/FrontContainer
@onready var icon_texture: TextureRect = $MarginContainer/FrontContainer/IconContainer/IconTexture
@onready var new_badge: PanelContainer = $MarginContainer/FrontContainer/IconContainer/NewBadge
@onready var new_label: Label = $MarginContainer/FrontContainer/IconContainer/NewBadge/Label
@onready var achievement_name: Label = $MarginContainer/FrontContainer/NameContainer/AchievementName
@onready var progress_bar: ProgressBar = $MarginContainer/FrontContainer/ProgressBarContainer/ProgressBar
@onready var progress_label: Label = $MarginContainer/FrontContainer/ProgressBarContainer/ProgressLabel
@onready var star_label: Label = $MarginContainer/FrontContainer/StarContainer/StarLabel

# Back side (description view)
@onready var back_container: VBoxContainer = $BackContainer
@onready var title_label: Label = $BackContainer/TitleLabel
@onready var description_label: Label = $BackContainer/DescriptionLabel


var achievement_id: String
var achievement_data: Dictionary
var is_flipped: bool = false

func setup(id: String):
	achievement_id = id
	achievement_data = AchievementManager.achievements[id]
	
	# Wait for nodes to be ready if needed
	if not is_node_ready():
		await ready
	
	# Setup front side
	_setup_front_side()
	
	# Setup back side
	_setup_back_side()
	
	# Initially show front
	front_container.visible = true
	back_container.visible = false
	
	# Apply rarity styling
	var rarity = achievement_data.get("rarity", AchievementManager.Rarity.COMMON)
	_apply_rarity_style(rarity)

func _setup_front_side():
	# Load icon
	if icon_texture:
		var icon_path = "res://Pyramids/assets/icons/achievements/" + achievement_data.icon
		if FileAccess.file_exists(icon_path):
			icon_texture.texture = load(icon_path)
	
	# Set achievement name
	if achievement_name:
		achievement_name.text = achievement_data.name
		achievement_name.add_theme_font_size_override("font_size", 13)
		achievement_name.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	
	# Set star reward
	if star_label:
		star_label.text = "⭐ %d" % achievement_data.stars
		star_label.add_theme_font_size_override("font_size", 11)
	
	# Update progress bar and label
	var progress = AchievementManager.get_achievement_progress(achievement_id)
	if progress_bar:
		progress_bar.value = progress * 100
		progress_bar.show_percentage = false
		
		# Style the progress bar
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.3, 0.3, 0.3, 0.3)
		bg_style.corner_radius_top_left = 3
		bg_style.corner_radius_top_right = 3
		bg_style.corner_radius_bottom_left = 3
		bg_style.corner_radius_bottom_right = 3
		progress_bar.add_theme_stylebox_override("background", bg_style)
		
		var fill_style = StyleBoxFlat.new()
		if AchievementManager.is_unlocked(achievement_id):
			fill_style.bg_color = Color(0.3, 0.8, 0.3)  # Green for complete
		else:
			fill_style.bg_color = Color(0.8, 0.8, 0.3)  # Yellow for progress
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_left = 3
		fill_style.corner_radius_bottom_right = 3
		progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	if progress_label:
		if AchievementManager.is_unlocked(achievement_id):
			progress_label.text = "Complete!"
			progress_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			var requirement = achievement_data.requirement
			var current = int(progress * requirement.value)
			progress_label.text = "%d/%d" % [current, requirement.value]
			progress_label.add_theme_color_override("font_color", Color.WHITE)
		progress_label.add_theme_font_size_override("font_size", 10)
	
	# Check if new
	if new_badge:
		new_badge.visible = AchievementManager.is_achievement_new(achievement_id)
	if new_label:
		new_label.text = "NEW"
	
	# Apply visual state
	_update_visual_state()

func _setup_back_side():
	# Title
	if title_label:
		title_label.text = achievement_data.name
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Description
	if description_label:
		description_label.text = achievement_data.description
		description_label.add_theme_font_size_override("font_size", 11)
		description_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _update_visual_state():
	# Handle locked/unlocked state
	if AchievementManager.is_unlocked(achievement_id):
		modulate = Color.WHITE
	else:
		modulate = Color(0.85, 0.85, 0.85)  # Slightly dimmed
	
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _apply_rarity_style(rarity):
	# Create border style based on rarity
	var border_style = StyleBoxFlat.new()
	var color = AchievementManager.get_rarity_color(rarity)
	
	border_style.bg_color = Color(1.0, 1.0, 1.0, 0.847)
	border_style.border_color = color
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border_style.corner_radius_top_left = 12
	border_style.corner_radius_top_right = 12
	border_style.corner_radius_bottom_left = 12
	border_style.corner_radius_bottom_right = 12
	
	# Apply glow for higher rarities
	if rarity >= AchievementManager.Rarity.RARE:
		border_style.shadow_color = color
		border_style.shadow_color.a = 0.3
		border_style.shadow_size = 5
		border_style.shadow_offset = Vector2.ZERO
	
	add_theme_stylebox_override("panel", border_style)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Mark as seen if new
			if AchievementManager.is_achievement_new(achievement_id) and not is_flipped:
				AchievementManager.mark_achievement_seen(achievement_id)
				new_badge.visible = false
			
			# Toggle flip
			_toggle_flip()
			
			# Emit signal
			achievement_clicked.emit(achievement_id)

func _toggle_flip():
	is_flipped = !is_flipped
	
	# Simple visibility toggle
	front_container.visible = !is_flipped
	back_container.visible = is_flipped
	
	# Optional: Add a scale animation for polish
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Shrink horizontally
	tween.tween_property(self, "scale:x", 0.0, 0.15)
	# Swap visibility at midpoint
	tween.tween_callback(func():
		front_container.visible = !is_flipped
		back_container.visible = is_flipped
	)
	# Expand back
	tween.tween_property(self, "scale:x", 1.0, 0.15)

func _on_mouse_entered():
	if not is_flipped:  # Only scale on front side
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Set consistent size
	custom_minimum_size = Vector2(120, 150)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
