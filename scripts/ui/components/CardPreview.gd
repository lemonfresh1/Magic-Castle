# CardPreview.gd - A lightweight card display for menus
# Path: res://Magic-Castle/scripts/ui/components/CardPreview.gd
extends Control

@onready var card_sprite: TextureRect = $CardSprite
@onready var rank_label: Label = $RankLabel
@onready var suit_label: Label = $SuitLabel

var current_rank: int = 1
var current_suit: int = CardData.Suit.HEARTS
var current_skin: String = "default"
var is_high_contrast: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(60, 84)
	_update_display()

func set_card(rank: int, suit: int) -> void:
	current_rank = rank
	current_suit = suit
	_update_display()

func set_skin(skin_name: String, high_contrast: bool = false) -> void:
	current_skin = skin_name
	is_high_contrast = high_contrast
	_update_display()

func _update_display() -> void:
	# Update rank label
	var rank_text = ""
	match current_rank:
		1: rank_text = "A"
		11: rank_text = "J"
		12: rank_text = "Q"
		13: rank_text = "K"
		_: rank_text = str(current_rank)
	rank_label.text = rank_text
	
	# Update suit label and colors
	var suit_text = ""
	var card_color = Color.BLACK
	match current_suit:
		CardData.Suit.HEARTS:
			suit_text = "♥"
			card_color = Color.RED
		CardData.Suit.DIAMONDS:
			suit_text = "♦"
			card_color = Color.RED
		CardData.Suit.CLUBS:
			suit_text = "♣"
			card_color = Color.BLACK
		CardData.Suit.SPADES:
			suit_text = "♠"
			card_color = Color.BLACK
	
	suit_label.text = suit_text
	rank_label.modulate = card_color
	suit_label.modulate = card_color
	
	# Apply skin-specific styling
	_apply_skin_style()

func _apply_skin_style() -> void:
	match current_skin:
		"default":
			card_sprite.modulate = Color.WHITE
			rank_label.add_theme_font_size_override("font_size", 24)
			suit_label.add_theme_font_size_override("font_size", 20)
		"modern":
			card_sprite.modulate = Color(0.95, 0.95, 1.0)
			rank_label.add_theme_font_size_override("font_size", 28)
			suit_label.add_theme_font_size_override("font_size", 24)
		"retro":
			card_sprite.modulate = Color(1.0, 0.98, 0.9)
			rank_label.add_theme_font_size_override("font_size", 22)
			suit_label.add_theme_font_size_override("font_size", 18)
	
	# Apply high contrast if enabled
	if is_high_contrast and _skin_supports_contrast(current_skin):
		rank_label.add_theme_color_override("font_color", Color.BLACK)
		suit_label.add_theme_color_override("font_color", Color.BLACK if current_suit in [CardData.Suit.CLUBS, CardData.Suit.SPADES] else Color.RED)
		# Only add font override if the font resource exists
		# rank_label.add_theme_font_override("font", preload("res://Magic-Castle/fonts/bold_font.tres"))

func _skin_supports_contrast(skin_name: String) -> bool:
	return skin_name in ["default", "retro"]
