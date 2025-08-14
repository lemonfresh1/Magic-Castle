# NeonNightCardFront.gd - Minimal darkmode front with neon watermarks
# Location: res://Pyramids/scripts/items/card_fronts/procedural/NeonNightCardFront.gd
# Last Updated: Created Neon Night card front with suit watermarks [Date]

extends ProceduralCardFront

# Color palette
const MATTE_BLACK = Color("#0A0A0A")
const WHITE = Color("#FFFFFF")
const NEON_PINK = Color("#FF2BAC")
const NEON_BLUE = Color("#00AEEF")
const WATERMARK_OPACITY = 0.15

func _init():
	item_id = "neon_night_front"
	theme_name = "Neon Night"
	display_name = "Neon Night Card Front"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = false
	
	# Override base colors
	card_bg_color = MATTE_BLACK
	card_border_color = Color(0.2, 0.2, 0.2)  # Dark gray border
	rank_font_size = 28
	suit_font_size = 32

func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	# Draw matte black background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), MATTE_BLACK)
	
	# Draw subtle border
	var border_rect = Rect2(1, 1, size.x - 2, size.y - 2)
	canvas.draw_rect(border_rect, Color(0.2, 0.2, 0.2), false, 1.0)
	
	# Draw center watermark based on suit
	_draw_suit_watermark(canvas, size, suit)
	
	# Draw rank and suit with appropriate colors
	_draw_minimal_rank_and_suit(canvas, size, rank, suit)

func _draw_suit_watermark(canvas: CanvasItem, size: Vector2, suit: int) -> void:
	var suit_symbol = _get_suit_symbol(suit)
	var watermark_color = _get_watermark_color(suit)
	watermark_color.a = WATERMARK_OPACITY
	
	# Large centered watermark
	var font = ThemeDB.fallback_font
	var watermark_size = 80
	
	# Calculate center position
	var text_size = font.get_string_size(suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, watermark_size)
	var center_pos = Vector2(
		(size.x - text_size.x) / 2 + text_size.x / 2,
		(size.y + text_size.y) / 2 - 10
	)
	
	# Draw the watermark
	canvas.draw_string(font, center_pos, suit_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, watermark_size, watermark_color)

func _get_watermark_color(suit: int) -> Color:
	# Spades and Clubs get blue, Hearts and Diamonds get pink
	match suit:
		0, 2:  # Spades, Clubs
			return NEON_BLUE
		1, 3:  # Hearts, Diamonds
			return NEON_PINK
		_:
			return NEON_BLUE

func _draw_minimal_rank_and_suit(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	var suit_symbol = _get_suit_symbol(suit)
	var suit_color = _get_minimal_suit_color(suit)
	var font = ThemeDB.fallback_font
	
	# Top-left rank and suit
	canvas.draw_string(font, Vector2(8, 25), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, suit_color)
	canvas.draw_string(font, Vector2(8, 50), suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, suit_color)
	
	# Bottom-right rank and suit (rotated)
	canvas.draw_set_transform(Vector2(size.x - 8, size.y - 8), PI, Vector2.ONE)
	canvas.draw_string(font, Vector2(0, 25), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, suit_color)
	canvas.draw_string(font, Vector2(0, 50), suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, suit_color)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Draw center pip pattern for number cards
	if rank not in ["A", "J", "Q", "K"]:
		_draw_center_pips(canvas, size, rank, suit_symbol, suit_color)

func _draw_center_pips(canvas: CanvasItem, size: Vector2, rank: String, suit_symbol: String, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var pip_size = 20
	var rank_num = rank.to_int()
	
	if rank_num == 0:
		return
	
	# Calculate pip positions based on rank
	var positions = _get_pip_positions(rank_num, size)
	
	for pos in positions:
		canvas.draw_string(font, pos, suit_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, pip_size, color)

func _get_pip_positions(rank_num: int, card_size: Vector2) -> Array:
	var positions = []
	var center_x = card_size.x / 2
	var center_y = card_size.y / 2
	var spacing_x = 25
	var spacing_y = 30
	
	match rank_num:
		2:
			positions = [
				Vector2(center_x, center_y - spacing_y),
				Vector2(center_x, center_y + spacing_y)
			]
		3:
			positions = [
				Vector2(center_x, center_y - spacing_y),
				Vector2(center_x, center_y),
				Vector2(center_x, center_y + spacing_y)
			]
		4:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y),
				Vector2(center_x + spacing_x/2, center_y - spacing_y),
				Vector2(center_x - spacing_x/2, center_y + spacing_y),
				Vector2(center_x + spacing_x/2, center_y + spacing_y)
			]
		5:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y),
				Vector2(center_x + spacing_x/2, center_y - spacing_y),
				Vector2(center_x, center_y),
				Vector2(center_x - spacing_x/2, center_y + spacing_y),
				Vector2(center_x + spacing_x/2, center_y + spacing_y)
			]
		6:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y),
				Vector2(center_x + spacing_x/2, center_y - spacing_y),
				Vector2(center_x - spacing_x/2, center_y),
				Vector2(center_x + spacing_x/2, center_y),
				Vector2(center_x - spacing_x/2, center_y + spacing_y),
				Vector2(center_x + spacing_x/2, center_y + spacing_y)
			]
		7:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y),
				Vector2(center_x + spacing_x/2, center_y - spacing_y),
				Vector2(center_x, center_y - spacing_y/2),
				Vector2(center_x - spacing_x/2, center_y),
				Vector2(center_x + spacing_x/2, center_y),
				Vector2(center_x - spacing_x/2, center_y + spacing_y),
				Vector2(center_x + spacing_x/2, center_y + spacing_y)
			]
		8:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y),
				Vector2(center_x + spacing_x/2, center_y - spacing_y),
				Vector2(center_x - spacing_x/2, center_y - spacing_y/3),
				Vector2(center_x + spacing_x/2, center_y - spacing_y/3),
				Vector2(center_x - spacing_x/2, center_y + spacing_y/3),
				Vector2(center_x + spacing_x/2, center_y + spacing_y/3),
				Vector2(center_x - spacing_x/2, center_y + spacing_y),
				Vector2(center_x + spacing_x/2, center_y + spacing_y)
			]
		9:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y),
				Vector2(center_x + spacing_x/2, center_y - spacing_y),
				Vector2(center_x - spacing_x/2, center_y - spacing_y/2),
				Vector2(center_x + spacing_x/2, center_y - spacing_y/2),
				Vector2(center_x, center_y),
				Vector2(center_x - spacing_x/2, center_y + spacing_y/2),
				Vector2(center_x + spacing_x/2, center_y + spacing_y/2),
				Vector2(center_x - spacing_x/2, center_y + spacing_y),
				Vector2(center_x + spacing_x/2, center_y + spacing_y)
			]
		10:
			positions = [
				Vector2(center_x - spacing_x/2, center_y - spacing_y * 1.2),
				Vector2(center_x + spacing_x/2, center_y - spacing_y * 1.2),
				Vector2(center_x - spacing_x/2, center_y - spacing_y * 0.6),
				Vector2(center_x + spacing_x/2, center_y - spacing_y * 0.6),
				Vector2(center_x, center_y - spacing_y * 0.3),
				Vector2(center_x, center_y + spacing_y * 0.3),
				Vector2(center_x - spacing_x/2, center_y + spacing_y * 0.6),
				Vector2(center_x + spacing_x/2, center_y + spacing_y * 0.6),
				Vector2(center_x - spacing_x/2, center_y + spacing_y * 1.2),
				Vector2(center_x + spacing_x/2, center_y + spacing_y * 1.2)
			]
	
	return positions

func _get_minimal_suit_color(suit: int) -> Color:
	# White for spades and clubs, pink for hearts and diamonds
	match suit:
		0, 2:  # Spades, Clubs
			return WHITE
		1, 3:  # Hearts, Diamonds
			return NEON_PINK
		_:
			return WHITE
