# MissionCard.gd - Individual mission card display
# Location: res://Magic-Castle/scripts/ui/missions/MissionCard.gd
# Last Updated: Created basic mission card implementation [Date]

extends PanelContainer
class_name MissionCard

signal mission_claimed(mission_id: String)

# UI references (adjust based on your scene structure)
@onready var name_label: Label = $VBox/NameLabel
@onready var description_label: Label = $VBox/DescriptionLabel
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var reward_label: Label = $VBox/RewardLabel
@onready var claim_button: Button = $VBox/ClaimButton

var mission_data: Dictionary = {}
var mission_type: String = ""

func setup(data: Dictionary, type: String = ""):
	mission_data = data
	mission_type = type
	
	# Update UI
	if name_label:
		name_label.text = data.get("display_name", "Mission")
	
	if description_label:
		description_label.text = data.get("description", "")
	
	# Progress
	var current = data.get("current_value", 0)
	var target = data.get("target_value", 1)
	if progress_bar:
		progress_bar.max_value = target
		progress_bar.value = current
	
	# Rewards
	var rewards = data.get("rewards", {})
	var reward_text = ""
	for reward_type in rewards:
		var amount = rewards[reward_type]
		if reward_text != "":
			reward_text += ", "
		reward_text += "+%d %s" % [amount, reward_type.to_upper()]
	
	if reward_label:
		reward_label.text = reward_text
	
	# Claim button
	var is_completed = data.get("is_completed", false)
	var is_claimed = data.get("is_claimed", false)
	
	if claim_button:
		claim_button.visible = is_completed and not is_claimed
		claim_button.disabled = is_claimed
		claim_button.text = "Claim" if not is_claimed else "Claimed"
		
		if not claim_button.pressed.is_connected(_on_claim_pressed):
			claim_button.pressed.connect(_on_claim_pressed)

func _on_claim_pressed():
	mission_claimed.emit(mission_data.get("id", ""))
