# MiniMission.gd - Compact mission display for post-game summary
# Location: res://Pyramids/scripts/ui/components/MiniMission.gd
# Last Updated: Redesigned for better mobile readability [Date]

extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/ProgressBar/DescriptionLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar

# Short descriptions for common mission types
const SHORT_DESCRIPTIONS = {
	"games_played": "Play games",
	"games_won": "Win games",
	"high_score": "Score 30k+",
	"combo_10": "10+ combo",
	"total_score": "Earn points",
	"perfect_clears": "Clear peaks"
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
	
	# Set minimum height to match AchievementUnlocked (68px)
	custom_minimum_size.y = 68.0
	
	# Apply normal white panel styling with dark grey border
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIStyleManager.colors.white
	panel_style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_medium)
	# Add 1px dark grey border
	panel_style.border_color = UIStyleManager.colors.gray_700
	panel_style.set_border_width_all(1)
	# Add left and right margins of 6
	panel_style.content_margin_left = 6
	panel_style.content_margin_right = 6
	add_theme_stylebox_override("panel", panel_style)
	
	# Set title with same size as description
	if title_label:
		title_label.text = mission_data.get("display_name", "Mission")
		title_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_body)  # Same as description
		title_label.add_theme_color_override("font_color", UIStyleManager.colors.gray_900)
	
	# Set short description with outline for readability
	if description_label:
		var mission_id = mission_data.get("id", "")
		var short_desc = _get_short_description(mission_id)
		description_label.text = short_desc
		
		# Standard body text size with outline for readability over colored progress bar
		description_label.add_theme_font_size_override("font_size", UIStyleManager.typography.size_body)
		description_label.add_theme_color_override("font_color", UIStyleManager.colors.white)
		
		# Add outline for better readability
		description_label.add_theme_color_override("font_outline_color", UIStyleManager.colors.gray_900)
		description_label.add_theme_constant_override("outline_size", 2)
		
		# Center alignment (you'll set anchors in inspector)
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Setup progress bar with moderate height and theme colors
	if progress_bar:
		var target = mission_data.get("target_value", 1)
		progress_bar.max_value = target
		progress_bar.value = new_progress
		
		# Moderate height for progress bar
		progress_bar.custom_minimum_size.y = 30
		
		# Apply standard progress bar background style
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = UIStyleManager.colors.gray_200
		bg_style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_small)
		progress_bar.add_theme_stylebox_override("background", bg_style)
		
		# Apply themed fill color based on mission system
		var fill_style = StyleBoxFlat.new()
		fill_style.set_corner_radius_all(UIStyleManager.dimensions.corner_radius_small)
		
		# Determine fill color from mission system using existing UIStyleManager colors
		var system = mission_data.get("system", "standard")
		match system:
			"standard", "daily":
				# Use info color for standard/daily missions (blue)
				fill_style.bg_color = UIStyleManager.colors.info
			"season_pass":
				# Use warning color for season pass (orange)
				fill_style.bg_color = UIStyleManager.colors.warning
			"holiday":
				# Use error color for holiday events (red)
				fill_style.bg_color = UIStyleManager.colors.error
			_:
				# Default to primary color
				fill_style.bg_color = UIStyleManager.colors.primary
		
		progress_bar.add_theme_stylebox_override("fill", fill_style)
		
		# Hide the value text on progress bar
		progress_bar.show_percentage = false
	
	# Animate progress increase if there was one
	if old_progress < new_progress:
		_animate_progress()

func _get_short_description(mission_id: String) -> String:
	"""Get a short description based on mission ID"""
	# Extract the track type from mission ID
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
	
	# Optional: Add a slight scale pop on the description label for emphasis
	if description_label:
		var original_scale = description_label.scale
		tween.parallel().tween_property(description_label, "scale", original_scale * 1.1, 0.2)
		tween.tween_property(description_label, "scale", original_scale, 0.2)
