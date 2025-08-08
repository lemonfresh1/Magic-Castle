# MissionCard.gd - Individual mission card display with claim overlay
# Location: res://Magic-Castle/scripts/ui/missions/MissionCard.gd
# Last Updated: Added claim overlay functionality [Date]

extends PanelContainer
class_name MissionCard

signal mission_claimed(mission_id: String)

# UI references matching your scene structure
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Details/Name
@onready var goal_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Details/Goal
@onready var progress_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/Progress/ProgressBar
@onready var progress_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Progress/ProgressBar/ProgressLabel
@onready var rewards_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/Progress/Rewards

# Claim overlay references
@onready var claim_overlay: Panel = $ClaimOverlay
@onready var claim_label: Label = $ClaimOverlay/ClaimLabel
@onready var completed_label: Label = $ClaimOverlay/CompletedLabel

# Add claim button if it exists in your scene
@onready var claim_button: Button = $MarginContainer/HBoxContainer/ClaimButton if has_node("MarginContainer/HBoxContainer/ClaimButton") else null

var mission_data: Dictionary = {}
var mission_theme: String = ""

func _ready():
	# Initially hide the overlay
	if claim_overlay:
		claim_overlay.visible = false
		claim_overlay.gui_input.connect(_on_overlay_input)
	
	# Hide both labels initially
	if claim_label:
		claim_label.visible = false
	if completed_label:
		completed_label.visible = false

func setup(data: Dictionary, theme: String = ""):
	mission_data = data
	mission_theme = theme
	
	# Update all UI elements
	_update_display()
	
	# Apply theme styling ONCE at the end
	_apply_theme_styling()
	
	# Update claim overlay state
	_update_claim_state()

func _update_display():
	"""Update all UI elements with current mission data"""
	# Update name
	if name_label:
		name_label.text = mission_data.get("display_name", "Mission")
	
	# Update goal/description
	if goal_label:
		var current = mission_data.get("current_value", 0)
		var target = mission_data.get("target_value", 1)
		var desc = mission_data.get("description", "")
		goal_label.text = "%s %d/%d" % [desc, current, target]
	
	# Update progress bar
	var current_value = mission_data.get("current_value", 0)
	var target_value = mission_data.get("target_value", 1)
	if progress_bar:
		progress_bar.max_value = target_value
		progress_bar.value = current_value
		
		# Update progress label
		if progress_label:
			progress_label.text = "%d/%d" % [current_value, target_value]
	
	# Update rewards
	var rewards = mission_data.get("rewards", {})
	var reward_text = ""
	
	for reward_type in rewards:
		var amount = rewards[reward_type]
		match reward_type:
			"stars":
				reward_text = "⭐ %d" % amount
			"xp":
				reward_text = "✨ %d XP" % amount
			"sp":
				reward_text = "🎯 %d SP" % amount
			"hp":
				reward_text = "❄️ %d HP" % amount
			_:
				reward_text = "%d %s" % [amount, reward_type.to_upper()]
	
	if rewards_label:
		rewards_label.text = reward_text

func update_progress(new_current: int, new_target: int):
	"""Called when mission progress updates"""
	mission_data["current_value"] = new_current
	mission_data["target_value"] = new_target
	
	# Check if completed
	if new_current >= new_target:
		mission_data["is_completed"] = true
	
	# Update display
	_update_display()
	
	# Update claim state
	_update_claim_state()

func _update_claim_state():
	"""Update the claim overlay based on mission state"""
	if not claim_overlay:
		return
	
	var is_completed = mission_data.get("is_completed", false)
	var is_claimed = mission_data.get("is_claimed", false)
	
	if is_claimed:
		# Mission is claimed - show completed state
		claim_overlay.visible = true
		claim_label.visible = false
		completed_label.visible = true
		# Gray out the card
		modulate = Color(0.7, 0.7, 0.7)
	elif is_completed:
		# Mission is ready to claim
		claim_overlay.visible = true
		claim_label.visible = true
		completed_label.visible = false
		# Normal color
		modulate = Color.WHITE
	else:
		# Mission is still in progress
		claim_overlay.visible = false
		claim_label.visible = false
		completed_label.visible = false
		# Normal color
		modulate = Color.WHITE

func _on_overlay_input(event: InputEvent):
	"""Handle clicking on the claim overlay"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var is_completed = mission_data.get("is_completed", false)
		var is_claimed = mission_data.get("is_claimed", false)
		
		if is_completed and not is_claimed:
			# Emit signal to claim the mission
			mission_claimed.emit(mission_data.get("id", ""))
			
			# Immediately update visual state
			mission_data["is_claimed"] = true
			_update_claim_state()

func _apply_theme_styling():
	"""Apply visual theme based on mission type"""
	var theme_color = Color.WHITE
	
	match mission_theme:
		"daily":
			theme_color = Color("#5ABFFF")  # Blue
		"weekly":
			theme_color = Color("#9B5AFF")  # Purple
		"season":
			theme_color = Color("#FFB75A")  # Orange
		"holiday":
			theme_color = Color("#FF5A5A")  # Red
	
	# Style the progress bar
	if progress_bar:
		# Create background style with low alpha for light appearance
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.2)  # 20% opacity
		bg_style.set_corner_radius_all(4)
		progress_bar.add_theme_stylebox_override("background", bg_style)
		
		# Create fill style (bright theme color, full opacity)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = theme_color
		fill_style.set_corner_radius_all(4)
		progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Style the panel border - duplicate the existing style
	var panel_style = get_theme_stylebox("panel")
	if panel_style and panel_style is StyleBoxFlat:
		var new_style = panel_style.duplicate()
		new_style.border_color = theme_color
		add_theme_stylebox_override("panel", new_style)

func _on_claim_pressed():
	mission_claimed.emit(mission_data.get("id", ""))
	
	# Immediately update visual state
	if claim_button:
		claim_button.text = "Claimed"
		claim_button.disabled = true
		claim_button.modulate = Color(0.5, 0.5, 0.5)

func get_mission_id() -> String:
	return mission_data.get("id", "")
