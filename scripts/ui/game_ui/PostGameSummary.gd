# PostGameSummary.gd - Comprehensive post-game progression screen
# Path: res://Pyramids/scripts/ui/game_ui/PostGameSummary.gd
# Last Updated: Cleaned debug output while maintaining functionality [Date]

extends Control

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/ButtonContainer/TitleLabel

# Progression nodes
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/ContinueButton
@onready var rematch_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/RematchButton
@onready var level_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/XPBarContainer/LevelLabel
@onready var xp_progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/Progression/XPBarContainer/ProgressBar
@onready var xp_overlay_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/XPBarContainer/ProgressBar/XPOverlayLabel
@onready var mmr_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/MMRSection/MMRLabel
@onready var star_label: Label = $Panel/MarginContainer/VBoxContainer/Progression/StarSection/StarLabel
@onready var mmr_section: HBoxContainer = $Panel/MarginContainer/VBoxContainer/Progression/MMRSection
@onready var star_section: HBoxContainer = $Panel/MarginContainer/VBoxContainer/Progression/StarSection
@onready var xp_bar_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/Progression/XPBarContainer


# Events nodes
@onready var events_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events
@onready var events_hbox: HBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer
@onready var achievements_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/AchievementsContainer
@onready var mission_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/MissionContainer
@onready var season_pass_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/SeasonPassContainer
@onready var holiday_event_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Events/ScrollContainer/HBoxContainer/HolidayEventContainer

# Preload scenes
const UnifiedAchievementCardScript = preload("res://Pyramids/scripts/ui/achievements/UnifiedAchievementCard.gd")
const UnifiedAchievementCardScene = preload("res://Pyramids/scenes/ui/achievements/UnifiedAchievementCard.tscn")
const MiniMission = preload("res://Pyramids/scenes/ui/components/MiniMission.tscn")

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

# Debug
var debug_enabled: bool = false  # Per-script debug toggle  
var global_debug: bool = true   # Ready for global toggle integration

func _ready() -> void:
	# Set high z-index
	z_index = 1000
	set_as_top_level(true)
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(panel, "post_game_summary")
	
	# Apply title label styling
	UIStyleManager.apply_label_style(title_label, "header")
	
	# Apply button styling
	UIStyleManager.apply_button_style(continue_button, "danger", "medium")
	UIStyleManager.apply_button_style(rematch_button, "success", "medium")
	
	# Apply progress bar styling
	UIStyleManager.apply_progress_bar_style(xp_progress_bar, "battle_pass")
	
	# Style the XP overlay label (centered on progress bar)
	UIStyleManager.apply_label_style(xp_overlay_label, "overlay")
	xp_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	xp_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style other labels
	UIStyleManager.apply_label_style(level_label, "body")
	UIStyleManager.apply_label_style(mmr_label, "body")
	UIStyleManager.apply_label_style(star_label, "body")
	
	# Connect buttons
	continue_button.pressed.connect(_on_continue_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	
	# Hide rematch by default
	rematch_button.visible = false

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[POSTGAMESUMMARY] %s" % message)

func show_summary(final_score: int, rounds_data: Array) -> void:
	visible = true
	
	_debug_log("=== POST GAME SUMMARY START ===")
	_debug_log("Final score: %d" % final_score)
	_debug_log("Rounds completed: %d" % rounds_data.size())
	
	# Store initial state BEFORE any rewards
	starting_xp = XPManager.current_xp
	starting_level = XPManager.current_level
	starting_stars = StarManager.get_balance()
	starting_mmr = 0
	
	_debug_log("Starting state - XP: %d, Level: %d, Stars: %d" % [starting_xp, starting_level, starting_stars])
	
	# CRITICAL: Get achievements FIRST before enabling rewards
	_check_achievements()  # This populates achievements_unlocked
	
	# IMPORTANT: Keep rewards DISABLED during calculation
	XPManager.rewards_enabled = false
	StarManager.rewards_enabled = false
	_debug_log("Rewards disabled for calculation phase")
	
	# Calculate what we WILL award (NOT including achievement stars!)
	_calculate_progression()
	
	# Update daily games AFTER XP calculation
	XPManager.update_daily_games()
	
	# Check achievements one more time to ensure they're ready
	AchievementManager.check_achievements()
	
	# Check missions - NOW ASYNC
	await _check_missions()
	
	# Update UI with what we'll award
	_update_progression_display()
	_update_events_display()
	
	# Update buttons
	rematch_button.visible = is_custom_lobby
	
	_debug_log("Starting progression animation...")
	# Start animations - THIS is where we actually award everything
	_animate_progression()
	
	if StatsManager:
		var mode_id = GameModeManager.get_current_mode()
		if mode_id != "":
			_debug_log("Saving score %d for mode %s" % [final_score, mode_id])
			StatsManager.save_score(mode_id, final_score)
			StatsManager.save_stats()
			
	if MultiplayerManager and MultiplayerManager.current_lobby_id != "":
		var placement = 1
		var mp_score = final_score
		var mode = MultiplayerManager.get_selected_mode()
		
		StatsManager.track_multiplayer_game(
			mode,
			placement,
			mp_score,
			10,
			120.5,
			1
		)
		_debug_log("Tracked multiplayer game: Mode=%s, Place=%d, Score=%d" % [mode, placement, mp_score])

func _calculate_progression() -> void:
	_debug_log("Calculating progression rewards...")
	
	# Calculate base game XP ONLY (no achievement XP)
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
	
	_debug_log("XP Breakdown: base=%d, rounds=%d, peaks=%d, first_win=%d" % 
		[xp_breakdown.base, xp_breakdown.rounds, xp_breakdown.peaks, xp_breakdown.first_win])
	
	# Apply multiplier
	var subtotal = xp_breakdown.base + xp_breakdown.rounds + xp_breakdown.peaks + xp_breakdown.first_win
	var game_xp = int(subtotal * XPManager.xp_multiplier)
	
	# Total XP gained (NO achievement XP)
	xp_gained = game_xp
	_debug_log("Total game XP: %d (subtotal: %d × multiplier: %.2f)" % [game_xp, subtotal, XPManager.xp_multiplier])
	
	# Calculate level changes using actual XP requirements
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
	_debug_log("Levels gained: %d (%d → %d)" % [levels_gained, starting_level, temp_level])
	
	# FIX: Calculate stars from levels ONLY (NO achievement stars!)
	stars_gained = 0
	if levels_gained > 0:
		for i in range(levels_gained):
			var level = starting_level + i + 1
			var level_rewards = XPManager.LEVEL_REWARDS.get(level, {})
			var level_stars = level_rewards.get("stars", 50)
			stars_gained += level_stars
			_debug_log("   Level %d stars: %d" % [level, level_stars])
	
	_debug_log("Total stars from levels: %d" % stars_gained)
	_debug_log("Achievements unlocked: %s" % str(achievements_unlocked))
	
	# TODO: Calculate MMR change when implemented
	mmr_change = 0

func _check_achievements() -> void:
	_debug_log("Checking achievements...")
	
	# CRITICAL: Check for new achievement unlocks FIRST
	AchievementManager.check_achievements()
	
	# Get newly unlocked achievements from this session
	achievements_unlocked = AchievementManager.get_and_clear_session_achievements()
	
	_debug_log("Achievements unlocked this game: %s" % str(achievements_unlocked))
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
	# XP Section - Update overlay label and level label
	xp_overlay_label.text = "+%d XP" % xp_gained
	
	# Level label shows current level with change
	var calculated_final_level = starting_level + levels_gained
	if levels_gained > 0:
		level_label.text = "Level %d (+%d)" % [calculated_final_level, levels_gained]
	else:
		level_label.text = "Level %d" % calculated_final_level
	
	# MMR Section - Single line format
	if starting_mmr > 0 or mmr_change != 0:
		var final_mmr = starting_mmr + mmr_change
		if mmr_change != 0:
			mmr_label.text = "MMR: %d (%+d)" % [final_mmr, mmr_change]
		else:
			mmr_label.text = "MMR: %d" % final_mmr
		mmr_section.visible = true
	else:
		mmr_section.visible = false
	
	# Stars Section - Single line format
	var total_stars = starting_stars + stars_gained
	if stars_gained > 0:
		star_label.text = "Stars: %d (+%d)" % [total_stars, stars_gained]
		star_section.visible = true
	else:
		star_label.text = "Stars: %d" % total_stars
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
	# Clear existing (except title)
	for child in achievements_container.get_children():
		if child.name != "TitleLabel":
			child.queue_free()
	
	# Style the title label if it exists
	var title = achievements_container.get_node_or_null("TitleLabel")
	if title:
		UIStyleManager.apply_label_style(title, "body")
		title.text = "Achievements Unlocked"  # Make it clear these are just unlocked
	
	# Add each unlocked achievement tier using new card
	for achievement_id in achievements_unlocked:
		# Extract base_id and tier from achievement_id (format: "base_id_tier_N")
		var parts = achievement_id.rsplit("_tier_", false, 1)
		if parts.size() == 2:
			var base_id = parts[0]
			var achievement_card = UnifiedAchievementCardScene.instantiate()
			achievement_card.setup(base_id, UnifiedAchievementCardScript.DisplayMode.POSTGAME)
			achievements_container.add_child(achievement_card)
			# Move the card after the title label
			if title:
				achievements_container.move_child(achievement_card, -1)

func _populate_missions(container: VBoxContainer, missions: Array) -> void:
	# Clear existing (except title)
	for child in container.get_children():
		if child.name != "TitleLabel":
			child.queue_free()
	
	# Style the title label if it exists
	var title = container.get_node_or_null("TitleLabel")
	if title:
		UIStyleManager.apply_label_style(title, "body")
	
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
	_debug_log("Animating XP bar...")
	
	# Set initial progress
	var current_level = starting_level
	var current_xp = starting_xp
	var display_level = starting_level
	
	# Get the correct XP requirement for starting level
	var old_level = XPManager.current_level
	XPManager.current_level = starting_level
	var max_xp = XPManager.get_xp_for_next_level()
	XPManager.current_level = old_level
	
	xp_progress_bar.max_value = max_xp
	xp_progress_bar.value = current_xp
	
	_debug_log("Starting animation - Current XP: %d/%d" % [current_xp, max_xp])
	
	# Calculate total animation time
	var bars_to_fill = levels_gained if levels_gained > 0 else 1
	var min_time_per_bar = 0.8
	var total_animation_time = bars_to_fill * min_time_per_bar
	
	# If no level gain, just animate the XP increase
	if levels_gained == 0:
		var tween = create_tween()
		var final_xp = starting_xp + xp_gained
		tween.tween_property(xp_progress_bar, "value", final_xp, min_time_per_bar)
		
		# Award game XP only
		tween.tween_callback(func():
			_debug_log("Awarding game XP: %d" % xp_gained)
			XPManager.rewards_enabled = true
			XPManager.add_xp(xp_gained, "game_complete")
			XPManager.rewards_enabled = false
			_debug_log("=== POST GAME SUMMARY END ===")
		)
		return
	
	# Animate through level ups
	var tween = create_tween()
	var total_xp_remaining = xp_gained
	var xp_used = 0
	
	for i in range(levels_gained):
		var xp_to_next_level = max_xp - current_xp
		xp_used += xp_to_next_level
		
		tween.tween_property(xp_progress_bar, "value", max_xp, min_time_per_bar)
		
		tween.tween_callback(func():
			display_level += 1
			current_level += 1
			current_xp = 0
			
			var temp_old_level = XPManager.current_level
			XPManager.current_level = current_level
			max_xp = XPManager.get_xp_for_next_level()
			XPManager.current_level = temp_old_level
			
			xp_progress_bar.max_value = max_xp
			xp_progress_bar.value = 0
		)
		
		if i < levels_gained - 1:
			tween.tween_interval(0.05)
	
	# Final animation to actual XP position
	var remaining_xp = total_xp_remaining - xp_used
	if remaining_xp > 0:
		tween.tween_property(xp_progress_bar, "value", remaining_xp, min_time_per_bar * 0.5)
	
	# Award game XP only (no achievement rewards)
	tween.tween_callback(func():
		_debug_log("Awarding game XP: %d" % xp_gained)
		XPManager.rewards_enabled = true
		XPManager.add_xp(xp_gained, "game_complete")
		XPManager.rewards_enabled = false
		_debug_log("Level-up stars awarded automatically by XPManager")
		_debug_log("=== POST GAME SUMMARY END ===")
	)

func _on_continue_pressed() -> void:
	visible = false
	
	# CRITICAL: Re-enable rewards when returning to menu!
	XPManager.rewards_enabled = true
	StarManager.rewards_enabled = true
	_debug_log("Re-enabled rewards on exit")
	
	# Clear mission tracker states when returning to menu
	if MissionStateTracker:
		MissionStateTracker.clear_states()
	GameState._return_to_menu()

func _on_rematch_pressed() -> void:
	visible = false
	
	# CRITICAL: Re-enable rewards for rematch!
	XPManager.rewards_enabled = true
	StarManager.rewards_enabled = true
	_debug_log("Re-enabled rewards for rematch")
	
	# TODO: Implement rematch in custom lobby
	GameState.reset_game_completely()
	GameState.start_new_game()
