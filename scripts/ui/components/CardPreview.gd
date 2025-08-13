# CardPreview.gd - A lightweight card display for menus
# Path: res://Pyramids/scripts/ui/components/CardPreview.gd
# Last Updated: Updated to use EquipmentManager instead of CardSkinManager [Date]

extends Control

@onready var card_sprite: TextureRect = $CardSprite if has_node("CardSprite") else null
@onready var rank_label: Label = $RankLabel if has_node("RankLabel") else null
@onready var suit_label: Label = $SuitLabel if has_node("SuitLabel") else null

var current_rank: int = 1
var current_suit: int = CardData.Suit.HEARTS
var current_skin_name: String = "classic"
var is_high_contrast: bool = false

# Background panel reference
var bg_panel: Panel

# Scale factor for preview cards (they're smaller than regular cards)
const PREVIEW_SCALE_FACTOR: float = 0.5

func _ready() -> void:
	custom_minimum_size = Vector2(60, 84)
	
	# Create nodes if they don't exist in the scene
	if not card_sprite:
		card_sprite = TextureRect.new()
		card_sprite.name = "CardSprite"
		card_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		card_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_sprite.visible = false
		add_child(card_sprite)
	
	if not rank_label:
		rank_label = Label.new()
		rank_label.name = "RankLabel"
		rank_label.position = Vector2(5, 5)  # Smaller offset for preview
		rank_label.add_theme_font_size_override("font_size", 16)
		add_child(rank_label)
	
	if not suit_label:
		suit_label = Label.new()
		suit_label.name = "SuitLabel"
		suit_label.position = Vector2(25, 25)  # Centered for preview
		suit_label.add_theme_font_size_override("font_size", 18)
		add_child(suit_label)
	
	# Add white background panel
	bg_panel = Panel.new()
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
	if is_inside_tree():
		_update_display()

func set_skin(skin_name: String, high_contrast: bool = false) -> void:
	current_skin_name = skin_name
	is_high_contrast = high_contrast
	if is_inside_tree():
		_update_display()

func _update_display() -> void:
	if not rank_label or not suit_label:
		return
	
	# Simple display based on current settings
	_update_card_appearance()

func _update_card_appearance() -> void:
	# Update background style
	if bg_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = Color.BLACK
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		bg_panel.add_theme_stylebox_override("panel", style)
	
	# Update rank text
	var rank_text = _get_rank_text(current_rank)
	rank_label.text = rank_text
	rank_label.add_theme_font_size_override("font_size", 16)
	
	# Update suit text
	var suit_text = _get_suit_symbol(current_suit)
	suit_label.text = suit_text
	suit_label.add_theme_font_size_override("font_size", 18)
	
	# Get color based on suit
	var card_color = _get_suit_color(current_suit)
	rank_label.modulate = card_color
	suit_label.modulate = card_color
	
	# Position labels
	rank_label.position = Vector2(5, 5)
	# Center the suit symbol
	var suit_x = (size.x - 10) / 2
	var suit_y = (size.y - 18) / 2 - 12
	suit_label.position = Vector2(suit_x, suit_y)
	
	# Handle sprite-based skins
	if SettingsSystem.current_card_skin == "sprites":
		_show_sprite_card()
	else:
		_show_programmatic_card()

func _show_sprite_card() -> void:
	# Hide programmatic elements
	rank_label.visible = false
	suit_label.visible = false
	
	# Build texture path
	var rank_name = _get_rank_name_for_sprite(current_rank)
	var suit_name = _get_suit_name(current_suit)
	var texture_path = "res://Pyramids/assets/cards/%s_of_%s.png" % [rank_name, suit_name]
	
	var texture = load(texture_path) if ResourceLoader.exists(texture_path) else null
	if texture:
		card_sprite.texture = texture
		card_sprite.visible = true
		card_sprite.modulate = Color.WHITE
	else:
		# Fallback to programmatic display if sprite not found
		_show_programmatic_card()

func _show_programmatic_card() -> void:
	# Hide sprite
	if card_sprite:
		card_sprite.visible = false
		card_sprite.texture = null
	
	# Show labels
	rank_label.visible = true
	suit_label.visible = true

func _get_rank_text(rank: int) -> String:
	match rank:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank)

func _get_suit_symbol(suit: int) -> String:
	match suit:
		CardData.Suit.HEARTS: return "♥"
		CardData.Suit.DIAMONDS: return "♦"
		CardData.Suit.CLUBS: return "♣"
		CardData.Suit.SPADES: return "♠"
		_: return "?"

func _get_suit_color(suit: int) -> Color:
	match suit:
		CardData.Suit.HEARTS, CardData.Suit.DIAMONDS:
			if is_high_contrast:
				return Color(0.92, 0.28, 0.28) if suit == CardData.Suit.HEARTS else Color(0.56, 0.82, 0.52)
			else:
				return Color.RED
		CardData.Suit.CLUBS, CardData.Suit.SPADES:
			if is_high_contrast:
				return Color(0.28, 0.55, 0.75) if suit == CardData.Suit.CLUBS else Color(0.2, 0.2, 0.2)
			else:
				return Color.BLACK
		_:
			return Color.BLACK

func _get_rank_name_for_sprite(rank: int) -> String:
	match rank:
		1: return "ace"
		11: return "jack"
		12: return "queen"
		13: return "king"
		_: return str(rank)

func _get_suit_name(suit: int) -> String:
	match suit:
		CardData.Suit.HEARTS: return "hearts"
		CardData.Suit.SPADES: return "spades"
		CardData.Suit.DIAMONDS: return "diamonds"
		CardData.Suit.CLUBS: return "clubs"
		_: return "unknown"
