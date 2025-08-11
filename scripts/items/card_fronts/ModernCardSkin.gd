# ModernCardSkin.gd - Modern card skin
# Path: res://Pyramids/scripts/items/card_skins/ModernCardSkin.gd
class_name ModernCardSkin
extends CardSkinBase

func _init():
	skin_name = "modern"
	display_name = "Modern"
	supports_high_contrast = false
	
	# Modern appearance
	card_bg_color = Color(0.95, 0.95, 0.95)
	card_border_color = Color(0.3, 0.3, 0.3)
	card_border_width = 1
	card_corner_radius = 5
	
	# Modern font settings
	rank_font_size = 36
	suit_font_size = 40
	rank_position_offset = Vector2(8, 8)
	suit_position_offset = Vector2(40, 8)
