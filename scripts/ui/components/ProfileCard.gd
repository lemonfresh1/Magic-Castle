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
var ui_buttons = []

func _ready() -> void:
	# Connect to XPManager signals
	XPManager.level_up.connect(_on_level_up)
	
	# Update initial display
	_update_display()
	
	# Connect button signals
	_connect_buttons()
	
	# Store button references for easier management
	ui_buttons = [
		profile_button,
		inventory_button,
		inbox_button,
		achievements_button,
		stats_button,
		clan_button,
		followers_button,
		referral_button
	]
	
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
	profile_button.toggled.connect(func(pressed): _on_ui_button_toggled("profile", profile_button, pressed))
	inventory_button.toggled.connect(func(pressed): _on_ui_button_toggled("inventory", inventory_button, pressed))
	inbox_button.toggled.connect(func(pressed): _on_ui_button_toggled("inbox", inbox_button, pressed))
	achievements_button.toggled.connect(func(pressed): _on_ui_button_toggled("achievements", achievements_button, pressed))
	stats_button.toggled.connect(func(pressed): _on_ui_button_toggled("stats", stats_button, pressed))
	clan_button.toggled.connect(func(pressed): _on_ui_button_toggled("clan", clan_button, pressed))
	followers_button.toggled.connect(func(pressed): _on_ui_button_toggled("followers", followers_button, pressed))
	referral_button.toggled.connect(func(pressed): _on_ui_button_toggled("referral", referral_button, pressed))

func _on_button_pressed(section: String, button: Button) -> void:
	section_selected.emit(section)
	
	var ui_manager = get_node_or_null("/root/UIManager")
	
	# Handle navigation based on section
	match section:
		"profile":
			# This changes scene, so close any open panels first
			if ui_manager:
				ui_manager.close_current_panel()
			get_tree().change_scene_to_file("res://Magic-Castle/scenes/ui/menus/MenuProfile.tscn")
		"achievements":
			# This changes scene, so close any open panels first
			if ui_manager:
				ui_manager.close_current_panel()
			get_tree().change_scene_to_file("res://Magic-Castle/scenes/ui/menus/AchievementsScreen.tscn")
		"inventory":
			# Don't change scene, just emit signal for MainMenu to handle with UIManager
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
		
func _on_ui_button_toggled(section: String, button: Button, pressed: bool) -> void:
	print("ProfileCard: Button toggled - ", section, " pressed: ", pressed)
	
	if pressed:
		# Untoggle all other buttons
		for btn in ui_buttons:
			if btn and btn != button and btn.button_pressed:
				btn.button_pressed = false
		
		# Emit signal for MainMenu to handle
		section_selected.emit(section)
	else:
		# Button was untoggled, close the panel
		var ui_manager = get_node_or_null("/root/UIManager")
		if ui_manager:
			ui_manager.close_current_panel()

func untoggle_all_buttons():
	for btn in ui_buttons:
		if btn and btn.button_pressed:
			btn.button_pressed = false
