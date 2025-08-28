# AchievementItem.gd - Achievement display with NEW badge and descriptions
# Path: res://Pyramids/scripts/ui/menus/AchievementItem.gd
# Added NEW badge, click-to-show descriptions, rarity borders, progress display
extends Panel

@onready var icon = $MarginContainer/VBoxContainer/IconContainer/Icon
@onready var name_label = $MarginContainer/VBoxContainer/Name
@onready var progress_bar = $MarginContainer/VBoxContainer/ProgressBar
@onready var star_label = $MarginContainer/VBoxContainer/StarReward
@onready var new_badge = $NewBadge  # Top-left corner
@onready var description_popup = $DescriptionPopup  # Hidden by default

var achievement_id: String
var achievement_data: Dictionary
var description_timer: Timer

func _ready():
	# Create NEW badge
	if not has_node("NewBadge"):
		_create_new_badge()
	
	# Create description popup
	if not has_node("DescriptionPopup"):
		_create_description_popup()
	
	# Create auto-hide timer
	description_timer = Timer.new()
	description_timer.wait_time = 5.0
	description_timer.one_shot = true
	description_timer.timeout.connect(_hide_description)
	add_child(description_timer)

func setup(id: String):
	achievement_id = id
	achievement_data = AchievementManager.achievements[id]
	
	# Apply rarity border color
	var rarity = achievement_data.get("rarity", AchievementManager.Rarity.COMMON)
	var border_color = AchievementManager.get_rarity_color(rarity)
	_apply_rarity_border(border_color)
	
	# Set icon
	var icon_path = "res://Pyramids/assets/icons/achievements/" + achievement_data.icon
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	# Hide name initially - will show in description popup
	name_label.visible = false  # Add this line
	
	# Set progress
	var progress = AchievementManager.get_achievement_progress(id)
	progress_bar.value = progress * 100
	
	# Format progress text
	if progress < 1.0 and progress > 0:
		var requirement = achievement_data.requirement
		var current = int(progress * requirement.value)
		progress_bar.modulate = Color.WHITE
		# Add text overlay on progress bar
		if progress_bar.has_node("ProgressText"):
			var text = progress_bar.get_node("ProgressText")
			text.text = "%d/%d" % [current, requirement.value]
	
	# Set star reward
	star_label.text = "⭐ %d" % achievement_data.stars
	
	# Handle locked/unlocked state
	if AchievementManager.is_unlocked(id):
		modulate.a = 1.0
		progress_bar.visible = true
		
		# Show NEW badge if applicable
		if new_badge:
			new_badge.visible = AchievementManager.is_achievement_new(id)
	else:
		modulate.a = 0.5  # Greyed out
		progress_bar.visible = progress > 0  # Show if partially complete
		if new_badge:
			new_badge.visible = false
	
	# Make clickable
	gui_input.connect(_on_gui_input)

func _create_new_badge():
	new_badge = Label.new()
	new_badge.name = "NewBadge"
	new_badge.text = "NEW"
	new_badge.add_theme_color_override("font_color", Color.YELLOW)
	new_badge.add_theme_font_size_override("font_size", 12)
	
	# Position in top-left
	new_badge.position = Vector2(5, 5)
	new_badge.z_index = 10
	
	# Add background
	var bg = Panel.new()
	bg.custom_minimum_size = Vector2(35, 20)
	bg.position = Vector2(3, 3)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", style)
	
	add_child(bg)
	add_child(new_badge)

func _create_description_popup():
	description_popup = Panel.new()
	description_popup.name = "DescriptionPopup"
	description_popup.visible = false
	description_popup.z_index = 100
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.8, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	description_popup.add_theme_stylebox_override("panel", style)
	
	# Position above the achievement
	description_popup.position = Vector2(0, 0)
	description_popup.custom_minimum_size = Vector2(200, 50)
	
	# Add description label
	var desc_label = Label.new()
	desc_label.name = "Description"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_child(desc_label)
	
	description_popup.add_child(margin)
	add_child(description_popup)

func _apply_rarity_border(color: Color):
	# Create or update border stylebox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)  # Dark background
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	
	# Add glow effect for higher rarities
	var rarity = achievement_data.get("rarity", AchievementManager.Rarity.COMMON)
	if rarity >= AchievementManager.Rarity.RARE:
		style.shadow_color = color
		style.shadow_color.a = 0.3
		style.shadow_size = 5
	
	add_theme_stylebox_override("panel", style)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		# If NEW, mark as seen
		if AchievementManager.is_achievement_new(achievement_id):
			AchievementManager.mark_achievement_seen(achievement_id)
			if new_badge:
				new_badge.visible = false
		
		# Toggle description
		if description_popup:
			if description_popup.visible:
				_hide_description()
			else:
				_show_description()

func _show_description():
	if not description_popup:
		return
		
	# Update description text
	var desc_label = description_popup.get_node("MarginContainer/Description")
	if desc_label:
		# Plain text - no BBCode
		desc_label.text = achievement_data.name + "\n" + achievement_data.description
		
		# Add progress info if not completed
		var progress = AchievementManager.get_achievement_progress(achievement_id)
		if progress < 1.0:
			var requirement = achievement_data.requirement
			var current = int(progress * requirement.value)
			desc_label.text += "\nProgress: %d/%d" % [current, requirement.value]
	
	# Show and start timer
	description_popup.visible = true
	description_timer.start()

func _hide_description():
	if description_popup:
		description_popup.visible = false
	description_timer.stop()
