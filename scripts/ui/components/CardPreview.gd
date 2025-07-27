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
	
	# Add white background panel
	var bg_panel = Panel.new()
	bg_panel.name = "BackgroundPanel"
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.BLACK
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	bg_panel.add_theme_stylebox_override("panel", style)
	
	add_child(bg_panel)
	move_child(bg_panel, 0)  # Behind everything
	
	_update_display()

func set_card(rank: int, suit: int) -> void:
	current_rank = rank
	current_suit = suit
	_update_display()

func set_skin(skin_name: String, high_contrast: bool = false) -> void:
	current_skin = skin_name
	is_high_contrast = high_contrast
	_update_display()  # This should trigger the visual update
	
	# Debug
	print("Card preview updated - skin: %s, high_contrast: %s" % [skin_name, high_contrast])

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
			if is_high_contrast and _skin_supports_contrast(current_skin):
				card_color = Color(0.92, 0.28, 0.28)  # Nice red
			else:
				card_color = Color.RED
		CardData.Suit.DIAMONDS:
			suit_text = "♦"
			if is_high_contrast and _skin_supports_contrast(current_skin):
				card_color = Color(0.56, 0.82, 0.52)  # Godot-style green
			else:
				card_color = Color.RED
		CardData.Suit.CLUBS:
			suit_text = "♣"
			if is_high_contrast and _skin_supports_contrast(current_skin):
				card_color = Color(0.28, 0.55, 0.75)  # Godot-style blue
			else:
				card_color = Color.BLACK
		CardData.Suit.SPADES:
			suit_text = "♠"
			if is_high_contrast and _skin_supports_contrast(current_skin):
				card_color = Color(0.2, 0.2, 0.2)  # Dark gray
			else:
				card_color = Color.BLACK
	
	suit_label.text = suit_text
	rank_label.modulate = card_color
	suit_label.modulate = card_color
	
	# Apply skin-specific styling
	_apply_skin_style()

func _apply_skin_style() -> void:
	match current_skin:
		"sprites":
			# Hide programmatic elements
			rank_label.visible = false
			suit_label.visible = false
			
			# Always reload the texture when switching to sprites
			var sample_path = "res://Magic-Castle/assets/cards/"
			var rank_name = ""
			match current_rank:
				1: rank_name = "ace"
				11: rank_name = "jack"
				12: rank_name = "queen"
				13: rank_name = "king"
				_: rank_name = "two"  # Default for number cards
			
			var suit_name = ""
			match current_suit:
				CardData.Suit.HEARTS: suit_name = "hearts"
				CardData.Suit.SPADES: suit_name = "spades"
				CardData.Suit.DIAMONDS: suit_name = "diamonds"
				CardData.Suit.CLUBS: suit_name = "clubs"
			
			sample_path += rank_name + "_of_" + suit_name + ".png"
			
			var texture = load(sample_path)
			if texture:
				card_sprite.texture = texture
				card_sprite.visible = true
				card_sprite.modulate = Color.WHITE
			
		"classic":
			# Hide sprite, show programmatic elements
			if card_sprite:
				card_sprite.visible = false
				card_sprite.texture = null  # Clear texture
			rank_label.visible = true
			suit_label.visible = true
			rank_label.add_theme_font_size_override("font_size", 24)
			suit_label.add_theme_font_size_override("font_size", 20)
			
		"modern":
			if card_sprite:
				card_sprite.visible = false
				card_sprite.texture = null  # Clear texture
			rank_label.visible = true
			suit_label.visible = true
			rank_label.add_theme_font_size_override("font_size", 28)
			suit_label.add_theme_font_size_override("font_size", 24)
			
		"retro":
			if card_sprite:
				card_sprite.visible = false
				card_sprite.texture = null  # Clear texture
			rank_label.visible = true
			suit_label.visible = true
			rank_label.add_theme_font_size_override("font_size", 22)
			suit_label.add_theme_font_size_override("font_size", 18)
	
	# Apply high contrast if enabled and supported
	if is_high_contrast and _skin_supports_contrast(current_skin):
		# High contrast colors already applied in _update_display()
		pass

func _skin_supports_contrast(skin_name: String) -> bool:
	return skin_name in ["default", "retro"]
