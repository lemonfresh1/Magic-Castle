# CardSkinPreview.gd
extends Control

var current_skin: String = "default"
var card_scene = preload("res://Magic-Castle/scenes/game/Card.tscn")

func _ready() -> void:
	_create_preview_cards()

func _create_preview_cards() -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	
	# Create preview cards: A♥ K♠ Q♦ J♣
	var preview_cards = [
		{"rank": 1, "suit": CardData.Suit.HEARTS},
		{"rank": 13, "suit": CardData.Suit.SPADES},
		{"rank": 12, "suit": CardData.Suit.DIAMONDS},
		{"rank": 11, "suit": CardData.Suit.CLUBS}
	]
	
	for i in range(preview_cards.size()):
		var card_data = CardData.new()
		card_data.rank = preview_cards[i].rank
		card_data.suit = preview_cards[i].suit
		
		var card = card_scene.instantiate()
		add_child(card)
		card.setup(card_data, -1)
		card.position.x = i * 60
		card.scale = Vector2(0.5, 0.5)

func set_skin(skin_name: String) -> void:
	current_skin = skin_name
	# Update all preview cards with new skin
	# This would call into your card skin system
