# ClassicCardSkin.gd - Classic card skin
# Path: res://Pyramids/scripts/items/card_skins/ClassicCardSkin.gd
class_name ClassicCardSkin
extends CardSkinBase

func _init():
	skin_name = "classic"
	display_name = "Classic"
	supports_high_contrast = true
	
	# Classic appearance
	card_bg_color = Color.WHITE
	card_border_color = Color.BLACK
	card_border_width = 2
	card_corner_radius = 10
	
	# Classic font settings
	rank_font_size = 32
	suit_font_size = 36
	rank_position_offset = Vector2(10, 10)
	suit_position_offset = Vector2(45, 10)
