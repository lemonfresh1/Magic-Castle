# CosmeticManager.gd - Autoload for cosmetic management
# Path: res://Pyramids/scripts/autoloads/CosmeticManager.gd
extends Node

# Cosmetic definitions
var card_skins: Dictionary = {
	"default": {"name": "Classic", "unlocked": true, "price": 0},
	"modern": {"name": "Modern", "unlocked": false, "price": 500},
	"retro": {"name": "Retro", "unlocked": false, "price": 300},
	"neon": {"name": "Neon", "unlocked": false, "price": 1000}
}

var board_skins: Dictionary = {
	"green": {"name": "Classic Green", "unlocked": true, "price": 0},
	"blue": {"name": "Ocean Blue", "unlocked": false, "price": 400},
	"sunset": {"name": "Sunset", "unlocked": false, "price": 600}
}

var avatars: Dictionary = {
	"default": {"name": "Player", "unlocked": true, "price": 0},
	"knight": {"name": "Knight", "unlocked": false, "price": 800},
	"wizard": {"name": "Wizard", "unlocked": false, "price": 800}
}

var frames: Dictionary = {
	"basic": {"name": "Basic", "unlocked": true, "price": 0},
	"silver": {"name": "Silver", "unlocked": false, "price": 1000},
	"gold": {"name": "Gold", "unlocked": false, "price": 2000}
}

signal cosmetic_unlocked(type: String, id: String)

func is_unlocked(type: String, id: String) -> bool:
	var collection = _get_collection(type)
	if collection.has(id):
		return collection[id].unlocked
	return false

func unlock_cosmetic(type: String, id: String) -> bool:
	var collection = _get_collection(type)
	if collection.has(id) and not collection[id].unlocked:
		collection[id].unlocked = true
		cosmetic_unlocked.emit(type, id)
		_save_unlocks()
		return true
	return false

func get_price(type: String, id: String) -> int:
	var collection = _get_collection(type)
	if collection.has(id):
		return collection[id].price
	return -1

func _get_collection(type: String) -> Dictionary:
	match type:
		"card_skin": return card_skins
		"board_skin": return board_skins
		"avatar": return avatars
		"frame": return frames
		_: return {}

func _save_unlocks() -> void:
	var config = ConfigFile.new()
	
	for type in ["card_skin", "board_skin", "avatar", "frame"]:
		var collection = _get_collection(type)
		for id in collection:
			if collection[id].unlocked:
				config.set_value(type, id, true)
	
	config.save("user://cosmetics.cfg")

func load_unlocks() -> void:
	var config = ConfigFile.new()
	if config.load("user://cosmetics.cfg") != OK:
		return
	
	for type in ["card_skin", "board_skin", "avatar", "frame"]:
		var collection = _get_collection(type)
		for id in collection:
			if config.has_section_key(type, id):
				collection[id].unlocked = config.get_value(type, id, false)
