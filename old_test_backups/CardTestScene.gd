### Script where I automatically create a card
extends Control

const CARD_WIDTH := 90
const CARD_HEIGHT := 126
const CARD_MARGIN := 10

const SUITS := ["♠", "♣", "♦", "♥"]
const SUIT_NAMES := ["spades", "clubs", "diamonds", "hearts"]
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

var allow_high_contrast: bool = true

func _ready():
	_draw()
	var start_x = 10
	var start_y = 10

	for row in SUITS.size():
		var suit = SUITS[row]
		for col in RANKS.size():
			var rank = RANKS[col]
			var card = create_card(suit, rank)
			add_child(card)
			card.position = Vector2(start_x + col * (CARD_WIDTH + CARD_MARGIN), start_y + row * (CARD_HEIGHT + CARD_MARGIN))

func get_suit_color(suit: String) -> Color:
	if allow_high_contrast and SettingsSystem.high_contrast:
		match suit:
			"♠": return Color.BLACK
			"♣": return Color.DODGER_BLUE
			"♦": return Color.FOREST_GREEN
			"♥": return Color.RED
	else:
		match suit:
			"♠", "♣": return Color.BLACK
			"♦", "♥": return Color.RED
	return Color.BLACK

func create_card(suit: String, rank: String) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	# Background style (light yellow for debugging)
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.BLACK
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)

	# Rank Label (Top Left)
	var rank_label = Label.new()
	rank_label.text = rank
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	rank_label.position = Vector2(10, 10)
	rank_label.set_custom_minimum_size(Vector2(25, 25))
	rank_label.add_theme_color_override("font_color", get_suit_color(suit))
	rank_label.add_theme_font_size_override("font_size", 32)
	card.add_child(rank_label)

	# Suit Label (Top Right, moved slightly left)
	var suit_label = Label.new()
	suit_label.text = suit
	suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	suit_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	suit_label.position = Vector2(CARD_WIDTH - 45, 10)
	suit_label.set_custom_minimum_size(Vector2(35, 35))
	suit_label.add_theme_color_override("font_color", get_suit_color(suit))
	suit_label.add_theme_font_size_override("font_size", 36)
	card.add_child(suit_label)

	# Rank Label (Bottom Right, flipped)
	var rank_mirror = rank_label.duplicate()
	rank_mirror.position = Vector2(CARD_WIDTH - 10, CARD_HEIGHT - 10)
	rank_mirror.scale = Vector2(-1, -1)
	card.add_child(rank_mirror)

	# Suit Label (Bottom Left, flipped)
	var suit_mirror = suit_label.duplicate()
	suit_mirror.position = Vector2(45, CARD_HEIGHT - 10)
	suit_mirror.scale = Vector2(-1, -1)
	card.add_child(suit_mirror)

	return card


func _draw():
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1, 1, 0.8), true)

func update_card_colors():
	for card in get_children():
		if card is Panel:
			var suit_char: String = ""

			# First pass: find the suit symbol from any label
			for label in card.get_children():
				if label is Label and label.text in SUITS:
					suit_char = label.text
					break

			# Second pass: apply the correct color to all labels
			if suit_char != "":
				var color = get_suit_color(suit_char)
				for label in card.get_children():
					if label is Label:
						label.add_theme_color_override("font_color", color)

# For CLAUDE
# I have created a layout for cards. Make sure it fits with what we typically do. This is supposed to be the base skin and loaded via script. I want to use both sprites and code designed cards and enable a slider in the to be created settings menu. This specific layout allows for high_contrast to be toggled on. I've added this also in the settingssystem and it should be a checkbox that is shown below the card display (always display A, K, Q, J of the four different suits). Klicking the toggle button will change the settings to true/false and also update the visual to show the new color. if var allow_high_contrast: bool = true is set to false on the card skin script, it should not show the toggle button in the options. Refactor this script considering our card, cardmanager, mobilegameboard, mobiletopbar, and systemsettings and also consider adding signals if needed to the signal hub. In this script i've made it so all cards would show on the screen for me too see how it looks like. the visuals need to disappear as this should be used to instantiate a card in the game. I also think we need to define a class_name, mode_name, and potentially a class (card_skin?) to reference these in the settingssystem. IDeally, it's only used there and sets it for the whole game. i don't intend to allow players to change skins in the game, so we need no update functions for the skins in the game. Any questions?
