# ProfileCard.gd - Minimal script for ProfileCard UI interaction
# Path: res://Magic-Castle/scripts/ui/components/ProfileCard.gd
# Handles displaying player info and navigation buttons
extends PanelContainer

signal section_selected(section_name: String)

@onready var clan_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/ClanLabel
@onready var player_name_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/NameLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/LevelLabel

# XP display nodes
@onready var xp_progress_bar: ProgressBar = $MarginContainer/VBoxContainer/HeaderContainer/XPProgressBar
@onready var xp_required_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/XPRequiredLabel

# Button references
@onready var profile_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/ProfileButton
@onready var inbox_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/InboxButton
@onready var achievements_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/AchievementsButton
@onready var stats_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/StatsButton
@onready var clan_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/ClanButton
@onready var followers_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/FollowersButton
@onready var referral_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HBoxContainer/ReferralButton

func _ready() -> void:
	# Connect to XPManager signals
	XPManager.level_up.connect(_on_level_up)
	if not XPManager.xp_gained.is_connected(_on_xp_gained):
		XPManager.xp_gained.connect(_on_xp_gained)
	
	# Update initial display
	_update_display()
	
	# Connect button signals
	_connect_buttons()
	
	# Hide clan label until player joins a clan
	clan_label.visible = false

func _update_display() -> void:
	# Update player name (from SettingsSystem if available)
	if SettingsSystem:
		player_name_label.text = SettingsSystem.player_name
	else:
		player_name_label.text = "Player"
	
	# Update level text
	level_label.text = "Level %s" % XPManager.get_display_level()
	
	# Update level color based on prestige
	var prestige_color = XPManager.get_prestige_color()
	if prestige_color != Color.WHITE:
		level_label.modulate = prestige_color
	
	# Update XP progress
	_update_xp_display()

func _update_xp_display() -> void:
	if not xp_progress_bar or not xp_required_label:
		return
		
	var current_xp = XPManager.current_xp
	var required_xp = XPManager.get_xp_for_next_level()
	
	print("Updating XP display: %d / %d" % [current_xp, required_xp])
	
	# Update progress bar
	xp_progress_bar.max_value = required_xp
	xp_progress_bar.value = current_xp
	
	# Update label
	xp_required_label.text = "%d/%d" % [current_xp, required_xp]
	
	# Apply prestige color to progress bar if applicable
	if XPManager.current_prestige > 0:
		var prestige_color = XPManager.get_prestige_color()
		xp_progress_bar.modulate = prestige_color

func _connect_buttons() -> void:
	profile_button.pressed.connect(func(): _on_button_pressed("profile"))
	inbox_button.pressed.connect(func(): _on_button_pressed("inbox"))
	achievements_button.pressed.connect(func(): _on_button_pressed("achievements"))
	stats_button.pressed.connect(func(): _on_button_pressed("stats"))
	clan_button.pressed.connect(func(): _on_button_pressed("clan"))
	followers_button.pressed.connect(func(): _on_button_pressed("followers"))
	referral_button.pressed.connect(func(): _on_button_pressed("referral"))

func _on_button_pressed(section: String) -> void:
	section_selected.emit(section)
	
	# Handle navigation based on section
	match section:
		"profile":
			get_tree().change_scene_to_file("res://Magic-Castle/scenes/ui/menus/MenuProfile.tscn")
		"achievements":
			get_tree().change_scene_to_file("res://Magic-Castle/scenes/ui/menus/AchievementsScreen.tscn")
		# Other sections will emit signal for expandable content later

func _on_level_up(new_level: int, rewards: Dictionary) -> void:
	print("ProfileCard: Level up detected, updating display")
	_update_display()

func _on_xp_gained(amount: int, source: String) -> void:
	print("ProfileCard: XP gained (%d from %s), updating XP display" % [amount, source])
	_update_xp_display()

# For when player joins a clan
func set_clan_symbol(clan_symbol: String) -> void:
	if clan_symbol.length() > 0:
		clan_label.text = "[%s]" % clan_symbol.substr(0, 4)  # Max 4 chars
		clan_label.visible = true
	else:
		clan_label.visible = false
