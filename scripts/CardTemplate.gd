# CardTemplate.gd - Refactored for menu use
extends Control

@export var preview_mode: bool = false  # True for menu previews
@export var show_specific_card: bool = false
@export var specific_rank: int = 1
@export var specific_suit: CardData.Suit = CardData.Suit.HEARTS

# Remove the debug card generation
func _ready() -> void:
	if preview_mode and show_specific_card:
		_display_card(specific_rank, specific_suit)
	elif not preview_mode:
		# Normal game behavior
		pass

func _display_card(rank: int, suit: CardData.Suit) -> void:
	# Display logic for the specific card
	pass

func set_skin(skin_name: String) -> void:
	# Apply skin changes
	pass
