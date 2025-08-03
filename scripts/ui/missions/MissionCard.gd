# MissionCard.gd - Reusable mission display card for all mission types
# Location: res://Magic-Castle/scripts/ui/missions/MissionCard.gd
# Last Updated: Created universal mission card component [Date]

extends PanelContainer

# UI References
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Details/Name
@onready var goal_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Details/Goal
@onready var progress_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/Progress/ProgressBar
@onready var progress_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Progress/ProgressBar/ProgressLabel
@onready var rewards_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Progress/Rewards

# Mission data
var mission_id: String = ""
var mission_type: String = ""  # "daily", "weekly", "season", "holiday"
var mission_data: Dictionary = {}

# Color themes for different mission types
const MISSION_COLORS = {
	"daily": Color("#5ABFFF"),      # Light blue
	"weekly": Color("#9B5AFF"),     # Purple
	"season": Color("#FFB75A"),     # Orange
	"holiday": Color("#FF5A8A"),    # Pink/Red
	"special": Color("#5AFF7F")     # Green
}

func _ready() -> void:
	# Verify all nodes exist
	if not name_label or not goal_label or not progress_bar or not progress_label or not rewards_label:
		push_error("MissionCard: Missing required UI nodes")
		return
	
	# Set default appearance
	_apply_theme_color("daily")

func setup(mission: Dictionary, type: String = "daily") -> void:
	"""
	Sets up the mission card with data
	mission: Dictionary containing mission data (from MissionManager.Mission)
	type: String indicating mission type for theming
	"""
	mission_type = type
	mission_data = mission
	mission_id = mission.get("id", "")
	
	# Update display
	_update_display()
	_apply_theme_color(type)

func setup_from_mission_object(mission: Object, type: String = "daily") -> void:
	"""
	Alternative setup method for Mission objects from MissionManager
	"""
	if not mission:
		return
	
	mission_type = type
	mission_id = mission.id
	
	# Convert Mission object to dictionary
	mission_data = {
		"id": mission.id,
		"display_name": mission.display_name,
		"description": mission.description,
		"current_value": mission.current_value,
		"target_value": mission.target_value,
		"rewards": mission.rewards,
		"is_completed": mission.is_completed,
		"is_claimed": mission.is_claimed
	}
	
	_update_display()
	_apply_theme_color(type)

func _update_display() -> void:
	# Update name
	name_label.text = mission_data.get("display_name", "Unknown Mission")
	
	# Update goal/description
	goal_label.text = mission_data.get("description", "")
	
	# Update progress
	var current = mission_data.get("current_value", 0)
	var target = mission_data.get("target_value", 1)
	
	if target > 0:
		progress_bar.value = (float(current) / float(target)) * 100.0
		progress_label.text = "%d / %d" % [current, target]
	else:
		progress_bar.value = 0
		progress_label.text = "0 / 0"
	
	# Update rewards text
	var rewards_text = _format_rewards(mission_data.get("rewards", {}))
	rewards_label.text = rewards_text
	
	# Visual state for completed missions
	if mission_data.get("is_completed", false):
		modulate.a = 0.8  # Slightly fade completed missions
		if not mission_data.get("is_claimed", false):
			# Add completion glow effect
			_add_completion_effect()

func _format_rewards(rewards: Dictionary) -> String:
	var reward_parts = []
	
	# Handle different reward types
	if rewards.has("xp") and rewards.xp > 0:
		reward_parts.append("+%d XP" % rewards.xp)
	
	if rewards.has("stars") and rewards.stars > 0:
		reward_parts.append("+%d ⭐" % rewards.stars)
	
	if rewards.has("sp") and rewards.sp > 0:
		reward_parts.append("+%d SP" % rewards.sp)
	
	if rewards.has("holiday_points") and rewards.holiday_points > 0:
		reward_parts.append("+%d 🎁" % rewards.holiday_points)
	
	if rewards.has("cosmetic_id"):
		reward_parts.append("🎨 Cosmetic")
	
	if rewards.has("card_back_id"):
		reward_parts.append("🃏 Card Back")
	
	return "Rewards: " + ", ".join(reward_parts) if reward_parts else "Rewards: None"

func _apply_theme_color(type: String) -> void:
	var color = MISSION_COLORS.get(type, MISSION_COLORS.daily)
	
	# Apply color to progress bar
	if progress_bar:
		var progress_style = StyleBoxFlat.new()
		progress_style.bg_color = color
		progress_style.corner_radius_top_left = 4
		progress_style.corner_radius_top_right = 4
		progress_style.corner_radius_bottom_left = 4
		progress_style.corner_radius_bottom_right = 4
		progress_bar.add_theme_stylebox_override("fill", progress_style)
		
		# Background style
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = color.darkened(0.7)
		bg_style.corner_radius_top_left = 4
		bg_style.corner_radius_top_right = 4
		bg_style.corner_radius_bottom_left = 4
		bg_style.corner_radius_bottom_right = 4
		progress_bar.add_theme_stylebox_override("background", bg_style)

func _add_completion_effect() -> void:
	# Add a subtle animation or visual effect for completed missions
	# This could be a glow, pulse, or border highlight
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(self, "modulate:a", 0.8, 0.5)

func update_progress(current: int, target: int) -> void:
	"""Called when mission progress updates"""
	mission_data.current_value = current
	mission_data.target_value = target
	
	if target > 0:
		progress_bar.value = (float(current) / float(target)) * 100.0
		progress_label.text = "%d / %d" % [current, target]
		
		# Check if just completed
		if current >= target and not mission_data.get("is_completed", false):
			mission_data.is_completed = true
			_add_completion_effect()

func mark_completed() -> void:
	"""Mark mission as completed with visual feedback"""
	mission_data.is_completed = true
	modulate.a = 0.8
	_add_completion_effect()

func get_mission_id() -> String:
	return mission_id

func get_mission_type() -> String:
	return mission_type

func is_completed() -> bool:
	return mission_data.get("is_completed", false)

func get_rewards() -> Dictionary:
	return mission_data.get("rewards", {})
