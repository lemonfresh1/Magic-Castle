# SpriteCardSkin.gd - Sprite-based card skin
# Path: res://Pyramids/scripts/items/card_skins/SpriteCardSkin.gd
class_name SpriteCardSkin
extends CardSkinBase

func _init():
	skin_name = "sprites"
	display_name = "Classic"
	supports_high_contrast = false

func apply_to_card(card_panel: Panel, rank: String, suit: int) -> void:
	# This skin uses sprites, not programmatic drawing
	pass

func get_card_texture_path(rank: int, suit: int, face_up: bool) -> String:
	if not face_up:
		return "res://Pyramids/assets/cards/pink_backing.png"
	
	# Convert rank to name
	var rank_name = ""
	match rank:
		1: rank_name = "ace"
		2: rank_name = "two"
		3: rank_name = "three"
		4: rank_name = "four"
		5: rank_name = "five"
		6: rank_name = "six"
		7: rank_name = "seven"
		8: rank_name = "eight"
		9: rank_name = "nine"
		10: rank_name = "ten"
		11: rank_name = "jack"
		12: rank_name = "queen"
		13: rank_name = "king"
	
	# Convert suit to name
	var suit_name = ""
	match suit:
		CardData.Suit.SPADES: suit_name = "spades"
		CardData.Suit.HEARTS: suit_name = "hearts"
		CardData.Suit.CLUBS: suit_name = "clubs"
		CardData.Suit.DIAMONDS: suit_name = "diamonds"
	
	return "res://Pyramids/assets/cards/%s_of_%s.png" % [rank_name, suit_name]

func uses_sprites() -> bool:
	return true
