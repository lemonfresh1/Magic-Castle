# MiniMission.gd - Compact mission display for post-game summary
# Location: res://Magic-Castle/scripts/ui/components/MiniMission.gd
# Last Updated: Cleaned debug output while maintaining functionality [Date]

extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label: Label = $MarginContainer/VBoxContainer/ProgressBar/ProgressBarLabel

# Short descriptions for common mission types
const SHORT_DESCRIPTIONS = {
	"games_played": "Play games",
	"games_won": "Win games",
	"high_score": "Score 30k+",
	"combo_10": "10+ combo",
	"total_score": "Earn points",
	"perfect_clears": "Clear peaks"
}

# Theme colors based on mission system
const THEME_COLORS = {
	"standard": Color("#5ABFFF"),  # Blue
	"season_pass": Color("#FFB75A"), # Orange
	"holiday": Color("#FF5A5A")      # Red
}

var mission_data: Dictionary = {}
var old_progress: int = 0
var new_progress: int = 0
var pending_setup: bool = false

func _ready() -> void:
	# Verify all nodes are found
	var nodes_found = true
	
	if not title_label:
		push_error("[MiniMission] title_label not found!")
		nodes_found = false
		
	if not description_label:
		push_error("[MiniMission] description_label not found!")
		nodes_found = false
		
	if not progress_bar:
		push_error("[MiniMission] progress_bar not found!")
		nodes_found = false
		
	if not progress_label:
		push_error("[MiniMission] progress_label not found!")
		nodes_found = false
	
	# If setup was called before ready, apply it now
	if pending_setup and nodes_found:
		_apply_setup()
		pending_setup = false

func setup(mission: Dictionary, old_value: int, new_value: int) -> void:
	mission_data = mission
	old_progress = old_value
	new_progress = new_value
	
	# Check if nodes are ready
	if is_node_ready():
		_apply_setup()
	else:
		pending_setup = true

func _apply_setup() -> void:
	"""Actually apply the setup data to the UI"""
	
	# Set title
	if title_label:
		title_label.text = mission_data.get("display_name", "Mission")
	
	# Set short description
	if description_label:
		var mission_id = mission_data.get("id", "")
		var short_desc = _get_short_description(mission_id)
		description_label.text = short_desc
		
		# Make description slightly transparent for visual hierarchy
		description_label.modulate = Color(0.8, 0.8, 0.8, 0.8)
	
	# Setup progress bar
	if progress_bar:
		var target = mission_data.get("target_value", 1)
		progress_bar.max_value = target
		progress_bar.value = new_progress
		
		# Apply theme color to progress bar
		var system = mission_data.get("system", "standard")
		if system in THEME_COLORS:
			var theme_color = THEME_COLORS[system]
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = theme_color
			fill_style.set_corner_radius_all(4)
			progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Set progress label
	if progress_label:
		var target = mission_data.get("target_value", 1)
		progress_label.text = "%d/%d" % [new_progress, target]
		
		# Show progress change if there was an increase
		if new_progress > old_progress:
			var increase = new_progress - old_progress
			progress_label.text += " (+%d)" % increase
	
	# Apply border color based on system
	_apply_system_theme()
	
	# Animate progress increase
	if old_progress < new_progress:
		_animate_progress()

func _get_short_description(mission_id: String) -> String:
	"""Get a short description based on mission ID"""
	# Extract the track type from mission ID
	# E.g., "daily_play_3" -> check for "play"
	
	# First check if mission has a track field from UnifiedMissionManager
	var track_type = ""
	
	# Try to find the track type by matching mission ID with templates
	if "play" in mission_id:
		track_type = "games_played"
	elif "win" in mission_id:
		track_type = "games_won"
	elif "score_30k" in mission_id or "high_score" in mission_id:
		track_type = "high_score"
	elif "combo" in mission_id:
		track_type = "combo_10"
	elif "score_200k" in mission_id or "score_" in mission_id:
		track_type = "total_score"
	elif "perfect" in mission_id:
		track_type = "perfect_clears"
	
	if track_type in SHORT_DESCRIPTIONS:
		return SHORT_DESCRIPTIONS[track_type]
	
	# Fallback to extracting from full description
	var full_desc = mission_data.get("description", "")
	
	# Try to shorten common patterns
	if "Play" in full_desc:
		return "Play games"
	elif "Win" in full_desc:
		return "Win games"
	elif "Score" in full_desc and "points" in full_desc:
		return "Earn points"
	elif "Score" in full_desc and "000" in full_desc:
		return "High score"
	elif "combo" in full_desc.to_lower():
		return "Score combos"
	elif "clear" in full_desc.to_lower():
		return "Clear boards"
	
	# If we can't determine, use first part of description
	var parts = full_desc.split(" ")
	if parts.size() >= 2:
		return parts[0] + " " + parts[1]
	
	return full_desc

func _apply_system_theme() -> void:
	"""Apply border color based on mission system"""
	# Determine system from mission data
	var system = mission_data.get("system", "standard")
	
	# Apply border color
	if system in THEME_COLORS:
		var theme_color = THEME_COLORS[system]
		var panel_style = get_theme_stylebox("panel")
		if panel_style and panel_style is StyleBoxFlat:
			var new_style = panel_style.duplicate()
			new_style.border_color = theme_color
			add_theme_stylebox_override("panel", new_style)

func _animate_progress() -> void:
	"""Animate the progress bar increase"""
	if not progress_bar:
		return
	
	# Start from old value and animate to new
	progress_bar.value = old_progress
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(progress_bar, "value", new_progress, 0.5)
	
	# Optional: Add a slight scale pop on the progress label
	if progress_label:
		var original_scale = progress_label.scale
		tween.parallel().tween_property(progress_label, "scale", original_scale * 1.2, 0.2)
		tween.tween_property(progress_label, "scale", original_scale, 0.2)
