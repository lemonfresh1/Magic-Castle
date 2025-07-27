# CardSkinBase.gd - Base class for all card skins
# Path: res://Magic-Castle/scripts/card_skins/CardSkinBase.gd
class_name CardSkinBase
extends Resource

@export var skin_name: String = "base"
@export var display_name: String = "Classic"
@export var supports_high_contrast: bool = false

# Card appearance settings
@export var card_bg_color: Color = Color.WHITE
@export var card_border_color: Color = Color.BLACK
@export var card_border_width: int = 2
@export var card_corner_radius: int = 10

# Font settings
@export var rank_font_size: int = 32
@export var suit_font_size: int = 36
@export var rank_position_offset: Vector2 = Vector2(10, 10)
@export var suit_position_offset: Vector2 = Vector2(45, 10)

# Get suit color based on current settings
func get_suit_color(suit: int) -> Color:
	if supports_high_contrast and SettingsSystem.high_contrast:
		return _get_high_contrast_color(suit)
	else:
		return _get_standard_color(suit)

func _get_standard_color(suit: int) -> Color:
	match suit:
		CardData.Suit.SPADES, CardData.Suit.CLUBS:
			return Color.BLACK
		CardData.Suit.HEARTS, CardData.Suit.DIAMONDS:
			return Color.RED
		_:
			return Color.BLACK

func _get_high_contrast_color(suit: int) -> Color:
	match suit:
		CardData.Suit.SPADES:
			return Color.BLACK
		CardData.Suit.CLUBS:
			return Color.DODGER_BLUE
		CardData.Suit.HEARTS:
			return Color.RED
		CardData.Suit.DIAMONDS:
			return Color.FOREST_GREEN
		_:
			return Color.BLACK

# Apply skin to a card panel
func apply_to_card(card_panel: Panel, rank: String, suit: int) -> void:
	# Background style
	var style = StyleBoxFlat.new()
	style.bg_color = card_bg_color
	style.border_color = card_border_color
	style.set_border_width_all(card_border_width)
	style.set_corner_radius_all(card_corner_radius)
	card_panel.add_theme_stylebox_override("panel", style)
	
	# Get suit symbol
	var suit_symbol = _get_suit_symbol(suit)
	var color = get_suit_color(suit)
	
	# Create labels
	_create_card_labels(card_panel, rank, suit_symbol, color)

func _get_suit_symbol(suit: int) -> String:
	match suit:
		CardData.Suit.SPADES: return "♠"
		CardData.Suit.CLUBS: return "♣"
		CardData.Suit.HEARTS: return "♥"
		CardData.Suit.DIAMONDS: return "♦"
		_: return "?"

func _create_card_labels(card_panel: Panel, rank: String, suit: String, color: Color) -> void:
	var card_size = card_panel.custom_minimum_size
	
	# Top-left rank
	var rank_label = Label.new()
	rank_label.text = rank
	rank_label.position = rank_position_offset
	rank_label.add_theme_color_override("font_color", color)
	rank_label.add_theme_font_size_override("font_size", rank_font_size)
	card_panel.add_child(rank_label)
	
	# Top-right suit
	var suit_label = Label.new()
	suit_label.text = suit
	suit_label.position = Vector2(card_size.x - suit_position_offset.x, suit_position_offset.y)
	suit_label.add_theme_color_override("font_color", color)
	suit_label.add_theme_font_size_override("font_size", suit_font_size)
	card_panel.add_child(suit_label)
	
	# Bottom-right rank (flipped)
	var rank_mirror = rank_label.duplicate()
	rank_mirror.position = Vector2(card_size.x - rank_position_offset.x, card_size.y - rank_position_offset.y)
	rank_mirror.scale = Vector2(-1, -1)
	card_panel.add_child(rank_mirror)
	
	# Bottom-left suit (flipped)
	var suit_mirror = suit_label.duplicate()
	suit_mirror.position = Vector2(suit_position_offset.x, card_size.y - suit_position_offset.y)
	suit_mirror.scale = Vector2(-1, -1)
	card_panel.add_child(suit_mirror)
