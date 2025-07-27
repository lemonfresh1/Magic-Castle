# CardSkinManager.gd - Autoload for card skin management
# Path: res://Magic-Castle/scripts/autoloads/CardSkinManager.gd
extends Node

var available_skins: Dictionary = {}
var current_skin: CardSkinBase

func _ready() -> void:
	_register_skins()
	_load_current_skin()

func _register_skins() -> void:
	# Register all available skins
	var classic = ClassicCardSkin.new()
	available_skins[classic.skin_name] = classic
	
	var modern = ModernCardSkin.new()
	available_skins[modern.skin_name] = modern
	
	# Add more skins here as you create them
	
	print("Registered %d card skins" % available_skins.size())

func _load_current_skin() -> void:
	var skin_name = SettingsSystem.current_card_skin
	if available_skins.has(skin_name):
		current_skin = available_skins[skin_name]
	else:
		current_skin = available_skins["classic"]
		SettingsSystem.set_card_skin("classic")

func get_current_skin() -> CardSkinBase:
	return current_skin

func get_skin(skin_name: String) -> CardSkinBase:
	if available_skins.has(skin_name):
		return available_skins[skin_name]
	return null

func get_all_skins() -> Array[CardSkinBase]:
	var skins: Array[CardSkinBase] = []
	for skin in available_skins.values():
		skins.append(skin)
	return skins

func set_skin(skin_name: String) -> void:
	if available_skins.has(skin_name):
		current_skin = available_skins[skin_name]
		SettingsSystem.set_card_skin(skin_name)
