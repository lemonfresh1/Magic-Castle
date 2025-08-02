# ProfileCard.gd - Minimal script for ProfileCard UI interaction
# Path: res://Magic-Castle/scripts/ui/components/ProfileCard.gd
# Handles displaying player info and navigation buttons
extends PanelContainer

signal section_selected(section_name: String)

@onready var level_label: Label = $MarginContainer/HeaderContainer/PanelContainer/LevelLabel
@onready var clan_label: Label = $MarginContainer/HeaderContainer/ClanLabel
@onready var player_name_label: Label = $MarginContainer/HeaderContainer/PlayerNameLabel



# Button references
@onready var profile_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/ProfileButton
@onready var inventory_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/InventoryButton
@onready var inbox_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/InboxButton
@onready var achievements_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/AchievementsButton
@onready var stats_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/StatsButton
@onready var clan_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/ClanButton
@onready var followers_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/FollowersButton
@onready var referral_button: Button = $MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/ReferralButton

func _ready() -> void:
	# Connect to XPManager signals
	XPManager.level_up.connect(_on_level_up)
	
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
		player_name_label.text = "Stefan"
	
	# Update level text
	level_label.text = "%s" % XPManager.get_display_level()
	
	# Update level color based on prestige
	var prestige_color = XPManager.get_prestige_color()
	if prestige_color != Color.WHITE:
		level_label.modulate = prestige_color

func _connect_buttons() -> void:
	profile_button.pressed.connect(func(): _on_button_pressed("profile"))
	inventory_button.pressed.connect(func(): _on_button_pressed("inventory"))
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
		"inventory":
			# Don't change scene, just emit signal for MainMenu to handle
			pass
		# Other sections will emit signal for expandable content later

func _on_level_up(new_level: int, rewards: Dictionary) -> void:
	print("ProfileCard: Level up detected, updating display")
	_update_display()

# For when player joins a clan
func set_clan_symbol(clan_symbol: String) -> void:
	if clan_symbol.length() > 0:
		clan_label.text = "[%s]" % clan_symbol.substr(0, 4)  # Max 4 chars
		clan_label.visible = true
	else:
		clan_label.visible = false
