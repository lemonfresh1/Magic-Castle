# UnifiedAchievementCard.gd - Universal achievement display component
# Location: res://Pyramids/scripts/ui/achievements/UnifiedAchievementCard.gd
# Last Updated: Fixed all 8 issues [2025-08-28]

extends Control
class_name UnifiedAchievementCard

signal clicked(achievement_base_id: String)
signal claim_requested(achievement_base_id: String, tier: int)
signal tier_selected(achievement_base_id: String, tier: int)

# Display modes
enum DisplayMode {
	FULL,      # Main AchievementUI display (400x100)
	POSTGAME,  # Compact PostGameSummary display
	MINI       # Icon-only for MiniProfileCard
}

# Node references from your scene structure
@onready var unified_achievement_card: Control = $"."
@onready var panel_container: PanelContainer = $PanelContainer
@onready var margin_container: MarginContainer = $PanelContainer/MarginContainer
@onready var h_box_container: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer
@onready var left_section: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/LeftSection
@onready var icon_container: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/IconContainer
@onready var icon_texture: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/IconContainer/IconTexture
@onready var stars_container: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/StarsContainer
@onready var button_star_1: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/StarsContainer/ButtonStar1
@onready var button_star_2: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/StarsContainer/ButtonStar2
@onready var button_star_3: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/StarsContainer/ButtonStar3
@onready var button_star_4: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/StarsContainer/ButtonStar4
@onready var button_star_5: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftSection/StarsContainer/ButtonStar5
@onready var center_section: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/CenterSection
@onready var name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/CenterSection/NameLabel
@onready var description_label: Label = $PanelContainer/MarginContainer/HBoxContainer/CenterSection/DescriptionLabel
@onready var progress_bar: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/CenterSection/ProgressBar
@onready var progress_label: Label = $PanelContainer/MarginContainer/HBoxContainer/CenterSection/ProgressBar/ProgressLabel
@onready var right_section: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RightSection
@onready var star_h_box: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RightSection/StarHBox
@onready var star_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RightSection/StarHBox/StarLabel
@onready var star_icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/RightSection/StarHBox/StarIcon
@onready var xph_box: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RightSection/XPHBox
@onready var xp_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RightSection/XPHBox/XPLabel
@onready var xp_icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/RightSection/XPHBox/XPIcon
@onready var date_h_box: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RightSection/DateHBox
@onready var date_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RightSection/DateHBox/DateLabel
@onready var date_icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/RightSection/DateHBox/DateIcon
@onready var category_h_box: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RightSection/CategoryHBox
@onready var category_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RightSection/CategoryHBox/CategoryLabel
@onready var category_icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/RightSection/CategoryHBox/CategoryIcon
@onready var new_badge: PanelContainer = $NewBadge
@onready var new_label: Label = $NewBadge/NewLabel

# Star textures
const STAR_FULL_TEXTURE = "res://Pyramids/assets/ui/bp_star.png"
const STAR_EMPTY_TEXTURE = "res://Pyramids/assets/ui/bp_star_empty.png"

# Data
var achievement_base_id: String = ""
var current_tier: int = 1  # Currently viewing tier (1-5)
var unlocked_tier: int = 0  # Highest unlocked tier (0-5)
var claimed_tier: int = 0  # Highest claimed tier (0-5)
var display_mode: DisplayMode = DisplayMode.FULL
var star_buttons: Array[Button] = []

# For sorting
var has_claimable: bool = false
var progress_percent: float = 0.0

func _ready():
	# Store star buttons in array for easy access
	star_buttons = [button_star_1, button_star_2, button_star_3, button_star_4, button_star_5]
	
	# Connect star button signals
	for i in range(5):
		if star_buttons[i]:
			star_buttons[i].pressed.connect(_on_star_button_pressed.bind(i + 1))
			star_buttons[i].toggle_mode = true  # Enable toggle mode
			star_buttons[i].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Connect panel click for claiming
	if panel_container:
		panel_container.gui_input.connect(_on_panel_clicked)
		panel_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(base_id: String, mode: DisplayMode = DisplayMode.FULL):
	achievement_base_id = base_id
	display_mode = mode
	
	# Wait for nodes to be ready
	if not is_node_ready():
		await ready
	
	# Now safe to proceed
	unlocked_tier = AchievementManager.get_unlocked_tier(base_id)
	claimed_tier = AchievementManager.get_claimed_tier(base_id)
	
	# Auto-select current working tier (next unclaimed or highest unlocked)
	if claimed_tier < unlocked_tier:
		current_tier = claimed_tier + 1  # Next claimable
	else:
		current_tier = min(unlocked_tier + 1, 5)  # Next to unlock
	
	# Calculate if has claimable for sorting
	has_claimable = claimed_tier < unlocked_tier
	
	_apply_display_mode()
	
	# Setup all elements
	_setup_icon()
	_setup_star_buttons()
	_setup_text()
	_setup_progress()
	_setup_rewards()
	_setup_new_badge()
	_setup_category()
	
	# Apply styling
	_apply_styling()

func _apply_display_mode():
	"""Configure visibility based on display mode"""
	match display_mode:
		DisplayMode.FULL:
			custom_minimum_size = Vector2(550, 119)
			left_section.visible = true
			center_section.visible = true
			right_section.visible = true
			stars_container.visible = true
			
		DisplayMode.POSTGAME:
	# Match MiniMission exactly - 68px height
			custom_minimum_size = Vector2(0, 68)
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			left_section.visible = true
			center_section.visible = true
			right_section.visible = false
			stars_container.visible = false
			description_label.visible = false
			progress_bar.visible = false
			new_badge.visible = false  # Never show in POSTGAME
			
		DisplayMode.MINI:
			custom_minimum_size = Vector2(44, 44)
			left_section.visible = true
			center_section.visible = false
			right_section.visible = false
			stars_container.visible = false
			new_badge.visible = false
			icon_container.custom_minimum_size = Vector2(40, 40)

func _setup_icon():
	if not icon_texture:
		return
	
	var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
	if not AchievementManager.achievement_definitions.has(achievement_id):
		return
	
	var achievement = AchievementManager.achievement_definitions[achievement_id]
	
	# Configure icon container size based on display mode
	if icon_container:
		if display_mode == DisplayMode.POSTGAME:
			icon_container.custom_minimum_size = Vector2(44, 44)
			icon_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif display_mode == DisplayMode.MINI:
			icon_container.custom_minimum_size = Vector2(40, 40)
		else:
			icon_container.custom_minimum_size = Vector2(60, 60)

	# Configure TextureRect with fallback system
	if icon_texture:
		var icon_path = "res://Pyramids/assets/icons/achievements/white_icons_cut/" + achievement.icon
		var texture_to_use: Texture2D = null
		
		# Try to load the tier-specific icon
		if ResourceLoader.exists(icon_path):
			texture_to_use = load(icon_path)
		else:
			# Fallback 1: Try to use tier 1 icon of same achievement
			var fallback_icon = "%s_ach_t1.png" % achievement_base_id
			var fallback_path = "res://Pyramids/assets/icons/achievements/white_icons_cut/" + fallback_icon
			if ResourceLoader.exists(fallback_path):
				texture_to_use = load(fallback_path)
				print("Using tier 1 icon as fallback for %s" % achievement.icon)
			else:
				# Fallback 2: Try a generic placeholder icon
				var placeholder_path = "res://Pyramids/assets/icons/achievements/placeholder.png"
				if ResourceLoader.exists(placeholder_path):
					texture_to_use = load(placeholder_path)
					print("Using placeholder for missing icon: %s" % achievement.icon)
				else:
					# Fallback 3: Keep existing texture if any
					print("Warning: No icon found for %s, keeping existing texture" % achievement.icon)
		
		# Apply the texture if we found one
		if texture_to_use:
			icon_texture.texture = texture_to_use
			# Make icon fill the container better - reduced padding
			icon_texture.custom_minimum_size = icon_container.custom_minimum_size - Vector2(4, 4)
			# Change to FIT_HEIGHT to ensure it fills vertically
			icon_texture.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
			icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Ensure it expands to fill available space
			icon_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Apply tier border color to icon container
	if icon_container:
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color.WHITE
		border_style.border_color = achievement.tier_color
		border_style.set_border_width_all(3)
		border_style.set_corner_radius_all(8)
		# Add small padding inside the border
		border_style.content_margin_left = 2
		border_style.content_margin_right = 2
		border_style.content_margin_top = 2
		border_style.content_margin_bottom = 2
		icon_container.add_theme_stylebox_override("panel", border_style)

func _setup_star_buttons():
	"""Setup the 5 star buttons with auto-select"""
	if stars_container and not stars_container.visible:
		return
	
	var star_full = load(STAR_FULL_TEXTURE)
	var star_empty = load(STAR_EMPTY_TEXTURE)
	
	for i in range(5):
		if not star_buttons[i]:
			continue
		
		var button = star_buttons[i]
		var tier_num = i + 1
		
		# Set icon based on claimed/unlocked status
		if tier_num <= claimed_tier:
			# Claimed - gold star
			button.icon = star_full
			button.modulate = Color("#FFD700")  # Gold
		elif tier_num <= unlocked_tier:
			# Unlocked but not claimed - white star
			button.icon = star_full
		else:
			# Not unlocked - empty star
			button.icon = star_empty
			button.modulate = Color(0.5, 0.5, 0.5, 0.5)
		
		# Set tooltip
		button.tooltip_text = "Tier %d: %s" % [tier_num, AchievementManager.TIER_NAMES[i]]
		
		# Enable/disable based on unlock status
		button.disabled = tier_num > unlocked_tier +1
		
		# Auto-select current tier button
		button.set_pressed_no_signal(tier_num == current_tier)

func _setup_text():
	"""Setup name and description for current tier - ALL TEXT BLACK"""
	var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
	if not AchievementManager.achievement_definitions.has(achievement_id):
		return
	
	var achievement = AchievementManager.achievement_definitions[achievement_id]
	
	if name_label:
		if display_mode == DisplayMode.POSTGAME:
			# Remove tier prefix for PostGame
			var full_name = achievement.name
			for tier_name in AchievementManager.TIER_NAMES:
				full_name = full_name.replace(tier_name + " ", "")
			name_label.text = full_name
			
			# Match MiniMission exactly
			name_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_body)
			name_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_label.add_theme_constant_override("line_spacing", -2)
		else:
			name_label.text = achievement.name
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", Color.BLACK)
	
	if description_label and description_label.visible:
		description_label.text = achievement.description
		description_label.add_theme_color_override("font_color", Color.BLACK)
		description_label.add_theme_font_size_override("font_size", 14)  # Increased from 12

func _setup_progress():
	"""Setup progress bar for current tier - FIXED color and inverse logic"""
	if not progress_bar or not progress_bar.visible:
		return
	
	var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
	var achievement = AchievementManager.achievement_definitions[achievement_id]
	var requirement = achievement.requirement
	
	# Get current stat value
	var stats = StatsManager.get_total_stats()
	var current_value = AchievementManager._get_stat_value(requirement.type, stats, {})
	
	# Calculate progress with FIXED inverse logic
	var progress = 0.0
	if requirement.get("inverse", false):
		# For inverse achievements (like speed demon): lower is better
		# If current is 37 and goal is 45, you've achieved it!
		if current_value <= requirement.value and current_value > 0:
			progress = 1.0  # Achieved!
		else:
			# Show how close you are (closer to goal = higher progress)
			if requirement.value > 0:
				progress = float(requirement.value) / float(max(current_value, 1))
				progress = min(progress, 1.0)  # Cap at 100%
	else:
		# Normal achievements: higher is better
		progress = float(current_value) / float(requirement.value)
		progress = min(progress, 1.0)  # Cap at 100%
	
	# Store for sorting
	progress_percent = progress

	progress_bar.value = progress * 100
	progress_bar.show_percentage = false
	
	# Style progress bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.3)
	bg_style.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	
	# FIXED: Check if achievement is unlocked, not just progress
	if current_tier <= unlocked_tier:
		fill_style.bg_color = Color("#10B981")  # Green for unlocked
	elif progress >= 1.0:
		fill_style.bg_color = Color("#F59E0B")  # Orange for complete but not unlocked
	else:
		fill_style.bg_color = Color("#F59E0B")  # Orange for in-progress
		
	fill_style.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Progress label with consistent font size
	if progress_label:
		if current_tier <= unlocked_tier:
			if current_tier <= claimed_tier:
				progress_label.text = "Claimed!"
			else:
				progress_label.text = "Click to claim!"
		elif progress >= 1.0:
			progress_label.text = "Complete!"
		else:
			# Show progress text
			if requirement.get("inverse", false):
				progress_label.text = "Best: %d / Goal: %d" % [current_value, requirement.value]
			else:
				progress_label.text = "%d / %d" % [current_value, requirement.value]
		
		progress_label.add_theme_font_size_override("font_size", 14)  # Increased from 12
		progress_label.add_theme_color_override("font_color", Color.WHITE)

func _setup_rewards():
	"""Setup reward display for current tier"""
	if not right_section or not right_section.visible:
		return
	
	var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
	var achievement = AchievementManager.achievement_definitions[achievement_id]
	
	# Stars reward
	if star_label:
		star_label.text = str(achievement.star_reward)
		star_label.add_theme_color_override("font_color", Color.BLACK)
		star_label.add_theme_font_size_override("font_size", 14)  # Increased from 12
	
	# XP reward
	if xp_label:
		xp_label.text = str(achievement.xp_reward)
		xp_label.add_theme_color_override("font_color", Color.BLACK)
		xp_label.add_theme_font_size_override("font_size", 14)  # Increased from 12
	
	# Date - show achievement date
	if date_label:
		# Get unlock date from save data or stats
		var unlock_date = _get_achievement_unlock_date(achievement_base_id, current_tier)
		if unlock_date != "":
			date_label.text = unlock_date
		else:
			date_label.text = ""  # Empty if not achieved
		date_label.add_theme_color_override("font_color", Color.BLACK)
		date_label.add_theme_font_size_override("font_size", 14)  # Increased from 12

func _get_achievement_unlock_date(base_id: String, tier: int) -> String:
	"""Get the date when achievement tier was unlocked"""
	# Check if this tier is unlocked
	if AchievementManager.get_unlocked_tier(base_id) < tier:
		return ""  # Not achieved yet
	
	# Try to get from save data if we store timestamps
	# For now, return current date if unlocked (you'll need to implement proper date tracking)
	if AchievementManager.unlocked_tiers.has(base_id):
		var date = Time.get_datetime_dict_from_system()
		return "%02d.%02d.%04d" % [date.day, date.month, date.year]
	
	return ""

func _setup_category():
	"""Setup category display"""
	if not category_h_box or not category_h_box.visible:
		return
	
	# Determine category from achievement base_id
	var category = _get_achievement_category(achievement_base_id)
	
	if category_label:
		category_label.text = category
		category_label.add_theme_color_override("font_color", Color.BLACK)
		category_label.add_theme_font_size_override("font_size", 14)  # Increased from 12
	
	if category_icon:
		# Load category icon
		var icon_path = "res://Pyramids/assets/icons/categories/%s.png" % category.to_lower()
		if ResourceLoader.exists(icon_path):
			category_icon.texture = load(icon_path)

func _get_achievement_category(base_id: String) -> String:
	"""Get achievement category - only 3 categories"""
	# Core gameplay achievements
	if base_id in ["games_played", "score_hunter", "highscore_master", "speed_demon"]:
		return "Core"
	# Skill achievements
	elif base_id in ["combo_master", "perfect_player", "peak_crusher", "efficiency_expert", "suit_specialist"]:
		return "Skill"
	# Multiplayer achievements
	elif base_id in ["mp_champion", "mp_participant", "win_streak", "daily_dedication", "collection_master"]:
		return "Multiplayer"
	else:
		return "Core"  # Default

func _setup_new_badge():
	if not new_badge:
		return
	
	# Never show in POSTGAME mode
	if display_mode == DisplayMode.POSTGAME:
		new_badge.visible = false
		return
	
	# Check if any unclaimed tier is new
	var has_new = false
	for tier in range(1, unlocked_tier + 1):
		if tier > claimed_tier:
			var achievement_id = "%s_tier_%d" % [achievement_base_id, tier]
			if AchievementManager.is_achievement_new(achievement_id):
				has_new = true
				break
	
	new_badge.visible = has_new
	
	if has_new:
		# Style the badge panel
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color("#EF4444")  # Red
		badge_style.set_corner_radius_all(4)
		new_badge.add_theme_stylebox_override("panel", badge_style)
		
		# Style the label
		if new_label:
			new_label.text = "NEW"
			new_label.add_theme_color_override("font_color", Color.WHITE)
			new_label.add_theme_font_size_override("font_size", 10)

func _apply_styling():
	if not panel_container:
		return
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIStyleManager.colors.white if UIStyleManager else Color.WHITE
	panel_style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_medium if UIStyleManager else 8)
	
	# Match MiniMission border exactly
	if display_mode == DisplayMode.POSTGAME:
		panel_style.border_color = UIStyleManager.colors.gray_700
		panel_style.set_border_width_all(1)
		panel_style.content_margin_left = 6
		panel_style.content_margin_right = 6
	else:
		panel_style.border_color = Color(0.2, 0.2, 0.2, 0.2)
		panel_style.set_border_width_all(1)
	
	panel_container.add_theme_stylebox_override("panel", panel_style)

func _on_star_button_pressed(tier: int):
	"""Handle star button clicks - switch viewing tier"""
	if tier <= unlocked_tier + 1:  # Can view unlocked tiers and the next one
		current_tier = tier
		# Refresh all displays for new tier
		_setup_icon()
		_setup_star_buttons()
		_setup_text()
		_setup_progress()
		_setup_rewards()
		_setup_category()
		_apply_styling()
		
		tier_selected.emit(achievement_base_id, tier)

func _on_panel_clicked(event: InputEvent):
	"""Handle clicking the card - claim rewards if available"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Try to claim current tier
			if current_tier <= unlocked_tier and current_tier > claimed_tier:
				_claim_current_tier()
			elif display_mode == DisplayMode.MINI:
				# Show expanded popup for mini mode
				_show_expanded_popup()
			
			# Remove NEW badge
			if new_badge and new_badge.visible:
				var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
				AchievementManager.mark_achievement_viewed(achievement_id)
				new_badge.visible = false
			
			clicked.emit(achievement_base_id)

func _claim_current_tier():
	"""Claim rewards for current viewing tier"""
	var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
	
	# Mark as viewed
	AchievementManager.mark_achievement_viewed(achievement_id)
	
	# Claim rewards
	if AchievementManager.claim_achievement_tier(achievement_base_id, current_tier):
		claimed_tier = current_tier
		has_claimable = claimed_tier < unlocked_tier  # Update for sorting
		
		# DON'T auto-advance tier after claiming
		# Just refresh the current display
		_setup_star_buttons()
		_setup_progress()
		_setup_rewards()
		_setup_new_badge()
		_apply_styling()
		
		# Show claim effect
		_show_claim_effect()
		
		claim_requested.emit(achievement_base_id, current_tier)

func _show_claim_effect():
	"""Visual feedback when claiming"""
	var achievement_id = "%s_tier_%d" % [achievement_base_id, current_tier]
	var achievement = AchievementManager.achievement_definitions[achievement_id]
	
	# Create floating text
	var float_label = Label.new()
	float_label.text = "+%d⭐ +%dXP" % [achievement.star_reward, achievement.xp_reward]
	float_label.add_theme_font_size_override("font_size", 16)
	float_label.add_theme_color_override("font_color", Color("#FFD700"))
	float_label.add_theme_color_override("font_outline_color", Color.BLACK)
	float_label.add_theme_constant_override("outline_size", 2)
	
	add_child(float_label)
	float_label.position = size / 2
	
	# Animate
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(float_label, "position:y", float_label.position.y - 30, 0.8)
	tween.tween_property(float_label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(float_label.queue_free)

func _show_expanded_popup():
	"""Show expanded view for MINI mode"""
	# Create popup container
	var popup = PanelContainer.new()
	popup.custom_minimum_size = Vector2(400, 120)
	
	# Style
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	popup_style.border_color = Color.WHITE
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", popup_style)
	
	# Create achievement card for popup
	var card_scene = load("res://Pyramids/scenes/ui/achievements/UnifiedAchievementCard.tscn")
	if card_scene:
		var card = card_scene.instantiate()
		card.setup(achievement_base_id, DisplayMode.FULL)
		popup.add_child(card)
	
	# Position near mini card
	popup.position = global_position + Vector2(50, -30)
	
	# Add to root
	get_tree().root.add_child(popup)
	popup.z_index = 999
	
	# Auto-close on click outside
	await get_tree().create_timer(0.1).timeout
	var close_handler = func(event):
		if event is InputEventMouseButton and event.pressed:
			popup.queue_free()
	get_viewport().gui_input.connect(close_handler)

# Sorting helper functions
func get_sort_priority() -> int:
	"""Get sort priority for auto-sorting"""
	# Priority: NEW+Claimable > Claimable > Incomplete > Complete
	var has_new = new_badge.visible if new_badge else false
	
	if has_new and has_claimable:
		return 0  # Highest priority
	elif has_claimable:
		return 1
	elif unlocked_tier < 5:
		return 2  # Still progressing
	else:
		return 3  # Fully complete

func get_progress_for_sorting() -> float:
	"""Get progress percentage for sorting"""
	return progress_percent

func get_tier_for_sorting() -> int:
	"""Get highest unlocked tier for sorting"""
	return unlocked_tier

func select_tier(tier: int):
	"""Public method to select a tier - called by AchievementUI"""
	if tier >= 1 and tier <= 5 and tier <= unlocked_tier + 1:
		current_tier = tier
		# Refresh all displays for new tier
		_setup_icon()
		_setup_star_buttons()
		_setup_text()
		_setup_progress()
		_setup_rewards()
		_setup_category()
		tier_selected.emit(achievement_base_id, tier)

func get_claimable_count() -> int:
	"""Get number of claimable tiers"""
	return max(0, unlocked_tier - claimed_tier)
