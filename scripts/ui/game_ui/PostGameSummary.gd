# PostGameSummary.gd - Comprehensive post-game progression screen
# Path: res://Magic-Castle/scripts/ui/game_ui/PostGameSummary.gd
# Last Updated: Cleaned debug output while maintaining functionality [Date]

extends Control

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/ButtonContainer/TitleLabel

# Progression nodes
@onready var xp_gained_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/XPSection/XPGainedLabel
@onready var level_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/XPSection/XPBarContainer/Label
@onready var xp_progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/Progression/XPSection/XPBarContainer/ProgressBar
@onready var mmr_section: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Progression/MMRSection
@onready var mmr_gained_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/MMRSection/MMRGainedLabel
@onready var mmr_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/MMRSection/MMRLabel
@onready var star_section: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Progression/StarSection
@onready var star_gained_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/StarSection/StarGainedLabel
@onready var star_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/StarSection/StarLabel

# Events nodes
@onready var events_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events
@onready var events_hbox: HBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer
@onready var achievements_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/AchievementsContainer
@onready var mission_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/MissionContainer
@onready var season_pass_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/SeasonPassContainer
@onready var holiday_event_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/HolidayEventContainer

# Button nodes
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/ContinueButton
@onready var rematch_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/RematchButton

# Preload scenes
const AchievementUnlocked = preload("res://Magic-Castle/scenes/ui/components/AchievementUnlocked.tscn")
const MiniMission = preload("res://Magic-Castle/scenes/ui/components/MiniMission.tscn")

# Game data
var starting_xp: int = 0
var starting_level: int = 0
var starting_mmr: int = 0
var starting_stars: int = 0
var xp_gained: int = 0
var levels_gained: int = 0
var mmr_change: int = 0
var stars_gained: int = 0
var achievements_unlocked: Array = []
var missions_progressed: Array = []
var is_custom_lobby: bool = false

func _ready() -> void:
	# Set high z-index
	z_index = 1000
	set_as_top_level(true)
	
	# Connect buttons
	continue_button.pressed.connect(_on_continue_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	
	# Hide rematch by default
	rematch_button.visible = false

func show_summary(final_score: int, rounds_data: Array) -> void:
	visible = true
	
	# Store initial state BEFORE any rewards
	starting_xp = XPManager.current_xp
	starting_level = XPManager.current_level
	starting_stars = StarManager.get_balance()
	starting_mmr = 0
	
	# CRITICAL: Get achievements FIRST before enabling rewards
	_check_achievements()  # This populates achievements_unlocked
	
	# IMPORTANT: Keep rewards DISABLED during calculation
	XPManager.rewards_enabled = false
	StarManager.rewards_enabled = false
	
	# Calculate what we WILL award (including achievements)
	_calculate_progression()
	
	# Update daily games AFTER XP calculation
	XPManager.update_daily_games()
	
	# Check achievements one more time to ensure they're ready
	AchievementManager.check_achievements()
	
	# Calculate total stars we'll award
	stars_gained = 0
	var level_stars = 0
	var achievement_stars = 0

	# Count level stars for DISPLAY
	if levels_gained > 0:
		for i in range(levels_gained):
			var level = starting_level + i + 1
			var level_rewards = XPManager.LEVEL_REWARDS.get(level, {})
			level_stars += level_rewards.get("stars", 50)

	# Count achievement stars
	for achievement_id in achievements_unlocked:
		var achievement = AchievementManager.achievements[achievement_id]
		achievement_stars += achievement.stars

	# Total for display
	stars_gained = level_stars + achievement_stars
	
	# Check missions - NOW ASYNC
	await _check_missions()
	
	# Update UI with what we'll award
	_update_progression_display()
	_update_events_display()
	
	# Update buttons
	rematch_button.visible = is_custom_lobby
	
	# Start animations - THIS is where we actually award everything
	_animate_progression()

func _calculate_progression() -> void:
	# Calculate base game XP
	var xp_breakdown = {
		"base": 50,
		"rounds": GameState.round_stats.size() * 10,
		"peaks": 0,
		"first_win": 0
	}
	
	# Count achievements and bonuses
	for round_stat in GameState.round_stats:
		if round_stat.cleared:
			xp_breakdown.peaks += 5
	
	# Check first win BEFORE updating daily games
	if XPManager.daily_games_played == 0:
		xp_breakdown.first_win = 100
	
	# Apply multiplier
	var subtotal = xp_breakdown.base + xp_breakdown.rounds + xp_breakdown.peaks + xp_breakdown.first_win
	var game_xp = int(subtotal * XPManager.xp_multiplier)
	
	# CRITICAL: Calculate achievement XP that will be awarded
	var achievement_xp_total = 0
	for achievement_id in achievements_unlocked:
		var achievement = AchievementManager.achievements.get(achievement_id, {})
		var rarity = achievement.get("rarity", AchievementManager.Rarity.COMMON)
		var xp = XPManager.XP_ACHIEVEMENT_BASE
		match rarity:
			AchievementManager.Rarity.UNCOMMON:
				xp *= 2
			AchievementManager.Rarity.RARE:
				xp *= 3
			AchievementManager.Rarity.EPIC:
				xp *= 5
			AchievementManager.Rarity.LEGENDARY:
				xp *= 10
		achievement_xp_total += xp
	
	# Total XP that will be gained
	xp_gained = game_xp + achievement_xp_total
	
	# FIXED: Calculate level changes using actual XP requirements
	var temp_xp = starting_xp + xp_gained
	var temp_level = starting_level
	
	while temp_level < 50:
		var xp_needed = XPManager.LEVEL_XP_REQUIREMENTS[temp_level]
		if temp_xp >= xp_needed:
			temp_xp -= xp_needed
			temp_level += 1
		else:
			break
	
	levels_gained = temp_level - starting_level
	
	# TODO: Calculate MMR change when implemented
	mmr_change = 0

func _check_achievements() -> void:
	# Get newly unlocked achievements from this session
	achievements_unlocked = AchievementManager.get_and_clear_session_achievements()
	
	# DON'T update daily games here - do it after XP calculation

func _check_missions() -> void:
	"""Check mission progress from UnifiedMissionManager"""
	missions_progressed = []
	
	# Wait a frame to ensure UnifiedMissionManager has processed the game_over signal
	await get_tree().process_frame
	
	# Get the actual score from this game
	var game_score = 0
	for round_stat in GameState.round_stats:
		game_score += round_stat.score
	
	# Check missions for ALL systems
	for system in ["standard", "season_pass", "holiday"]:
		var missions = UnifiedMissionManager.get_missions_for_system(system)
		
		for mission in missions:
			# Skip already claimed missions
			if mission.is_claimed:
				continue
			
			# Get mission state at game start
			var start_state = MissionStateTracker.get_mission_start_state(system, mission.id)
			
			# Skip if mission was already claimable before this game
			if MissionStateTracker.was_already_claimable(system, mission.id):
				continue
			
			# Check if mission actually progressed
			var current_state = {
				"current_value": mission.current_value,
				"is_completed": mission.is_completed,
				"is_claimed": mission.is_claimed
			}
			
			if not MissionStateTracker.did_mission_progress(system, mission.id, current_state):
				continue
			
			# Mission progressed! Determine old value for animation
			var old_value = start_state.current_value
			var new_value = mission.current_value
			
			# Add system to the mission data itself
			var mission_with_system = mission.duplicate()
			mission_with_system["system"] = system
			
			missions_progressed.append({
				"mission": mission_with_system,
				"system": system,
				"old_value": old_value,
				"new_value": new_value
			})

func _update_progression_display() -> void:
	# XP Section
	xp_gained_label.text = "Experience gained: %d" % xp_gained
	
	# FIXED: Use our calculated final level, not XPManager's current level (which hasn't been updated yet)
	var calculated_final_level = starting_level + levels_gained
	level_label.text = "Level %d%s" % [
		calculated_final_level,
		" (+%d)" % levels_gained if levels_gained > 0 else ""
	]

	# MMR Section
	if starting_mmr > 0 or mmr_change != 0:
		mmr_gained_label.text = "MMR change: %+d" % mmr_change
		mmr_label.text = "New MMR: %d" % (starting_mmr + mmr_change)
		mmr_section.visible = true
	else:
		mmr_section.visible = false
	
	# Stars Section
	var total_stars = starting_stars + stars_gained
	if stars_gained > 0:
		star_gained_label.text = "Stars gained: +%d" % stars_gained
		star_label.text = "Star Count: %d" % total_stars
		star_section.visible = true
	else:
		star_section.visible = false

func _update_events_display() -> void:
	var has_any_events = false
	
	# Achievements
	if achievements_unlocked.size() > 0:
		_populate_achievements()
		achievements_container.visible = true
		has_any_events = true
	else:
		achievements_container.visible = false
	
	# Standard missions
	var standard_missions = missions_progressed.filter(func(m): return m.system == "standard")
	if standard_missions.size() > 0:
		_populate_missions(mission_container, standard_missions)
		mission_container.visible = true
		has_any_events = true
	else:
		mission_container.visible = false
	
	# Season Pass missions
	var season_pass_missions = missions_progressed.filter(func(m): return m.system == "season_pass")
	if season_pass_missions.size() > 0:
		_populate_missions(season_pass_container, season_pass_missions)
		season_pass_container.visible = true
		has_any_events = true
	else:
		season_pass_container.visible = false
	
	# Holiday Event missions
	var holiday_missions = missions_progressed.filter(func(m): return m.system == "holiday")
	if holiday_missions.size() > 0:
		_populate_missions(holiday_event_container, holiday_missions)
		holiday_event_container.visible = true
		has_any_events = true
	else:
		holiday_event_container.visible = false
	
	# Hide entire events section if nothing to show
	events_container.visible = has_any_events

func _populate_achievements() -> void:
	# Clear existing
	for child in achievements_container.get_children():
		if child.name != "TitleLabel":
			child.queue_free()
	
	# Add each unlocked achievement
	for achievement_id in achievements_unlocked:
		var achievement_item = AchievementUnlocked.instantiate()
		achievement_item.setup(achievement_id)
		achievements_container.add_child(achievement_item)

func _populate_missions(container: VBoxContainer, missions: Array) -> void:
	# Clear existing (except title)
	for child in container.get_children():
		if child.name != "TitleLabel":
			child.queue_free()
	
	# Add each mission progress using MiniMission
	for mission_data in missions:
		var mission_item = MiniMission.instantiate()
		# Pass the mission dictionary and progress values
		if mission_item.has_method("setup"):
			mission_item.setup(mission_data.mission, mission_data.old_value, mission_data.new_value)
		container.add_child(mission_item)

func _animate_progression() -> void:
	# Fade in
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_callback(_animate_xp_bar)

func _animate_xp_bar() -> void:
	
	# Set initial progress
	var current_level = starting_level
	var current_xp = starting_xp
	var display_level = starting_level  # Track displayed level separately
	
	# Get the correct XP requirement for starting level
	var old_level = XPManager.current_level
	XPManager.current_level = starting_level
	var max_xp = XPManager.get_xp_for_next_level()
	XPManager.current_level = old_level
	
	xp_progress_bar.max_value = max_xp
	xp_progress_bar.value = current_xp
	

	# Calculate total animation time (minimum 0.3s per level)
	var bars_to_fill = levels_gained if levels_gained > 0 else 1
	var min_time_per_bar = 0.8
	var total_animation_time = bars_to_fill * min_time_per_bar
	
	# If no level gain, just animate the XP increase
	if levels_gained == 0:
		var tween = create_tween()
		var final_xp = starting_xp + xp_gained
		tween.tween_property(xp_progress_bar, "value", final_xp, min_time_per_bar)
		
		# Actually award everything
		tween.tween_callback(func():
			# Enable rewards temporarily
			XPManager.rewards_enabled = true
			StarManager.rewards_enabled = true
			
			# Give all XP at once (includes achievement XP)
			XPManager.add_xp(xp_gained, "game_complete")
			
			if stars_gained > 0:
				StarManager.add_stars(stars_gained, "post_game_total")
			
			# Disable rewards again
			XPManager.rewards_enabled = false
			StarManager.rewards_enabled = false
		)

		return
	
	# Animate through level ups with counting label
	var tween = create_tween()
	var total_xp_remaining = xp_gained
	var xp_used = 0
	
	for i in range(levels_gained):
		# Calculate XP needed to reach next level from current position
		var xp_to_next_level = max_xp - current_xp
		xp_used += xp_to_next_level
		
		# Animate to full bar (always take min_time_per_bar)
		tween.tween_property(xp_progress_bar, "value", max_xp, min_time_per_bar)
		
		# Update level when bar fills
		tween.tween_callback(func():
			display_level += 1  # Increment display level
			current_level += 1  # Increment actual level
			current_xp = 0
			
			# Get next level's XP requirement
			var temp_old_level = XPManager.current_level
			XPManager.current_level = current_level
			max_xp = XPManager.get_xp_for_next_level()
			XPManager.current_level = temp_old_level
			
			xp_progress_bar.max_value = max_xp
			xp_progress_bar.value = 0
		)
		
		# Small pause between level ups for visual clarity
		if i < levels_gained - 1:  # Don't pause after last level
			tween.tween_interval(0.05)
	
	# Calculate remaining XP after all level ups
	var remaining_xp = total_xp_remaining - xp_used
	
	# Final animation to actual XP position
	if remaining_xp > 0:
		tween.tween_property(xp_progress_bar, "value", remaining_xp, min_time_per_bar * 0.5)
	
	# At the end, actually award everything
	tween.tween_callback(func():
		# Enable rewards temporarily for these specific awards
		XPManager.rewards_enabled = true
		StarManager.rewards_enabled = true
		
		# Give all XP at once (this already includes achievement XP from our calculation)
		XPManager.add_xp(xp_gained, "game_complete")
		
		# Award all stars at once
		var achievement_stars = 0
		for achievement_id in achievements_unlocked:
			var achievement = AchievementManager.achievements[achievement_id]
			achievement_stars += achievement.stars

		if achievement_stars > 0:
			StarManager.add_stars(achievement_stars, "achievement_rewards")
		
		# Disable rewards again
		XPManager.rewards_enabled = false
		StarManager.rewards_enabled = false
	)

func _on_continue_pressed() -> void:
	visible = false
	# Clear mission tracker states when returning to menu
	if MissionStateTracker:
		MissionStateTracker.clear_states()
	GameState._return_to_menu()

func _on_rematch_pressed() -> void:
	visible = false
	# TODO: Implement rematch in custom lobby
	GameState.reset_game_completely()
	GameState.start_new_game()
