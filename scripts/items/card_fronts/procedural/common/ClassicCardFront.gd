# ClassicCardFront.gd - Classic card front with rank and suit display
# Location: res://Pyramids/scripts/items/card_fronts/procedural/common/ClassicCardFront.gd
# Last Updated: Fixed function signatures to match parent

extends ProceduralCardFront

func _init():
	theme_name = "Classic"
	item_id = "classic_card_front"
	display_name = "Classic Card Front"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = false

func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	# Draw white background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	
	# Draw border
	var border_color = Color(0.2, 0.2, 0.2)
	var border_width = 2.0
	canvas.draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
	
	# Get suit color and symbol
	var suit_color = _get_suit_color(suit)
	var suit_symbol = _get_suit_symbol(suit)
	
	# Font settings
	var rank_font_size = int(size.y * 0.15)
	var suit_font_size = int(size.y * 0.18)
	
	# Draw rank and suit in corners
	_draw_corner_labels(canvas, size, rank, suit_symbol, suit_color)
	
	# Draw center suit symbol(s)
	_draw_center_pattern(canvas, size, rank, suit_symbol, suit_color)

func _get_suit_color(suit: int) -> Color:
	match suit:
		0, 2:  # Spades, Clubs
			return Color.BLACK
		1, 3:  # Hearts, Diamonds
			return Color(0.8, 0, 0)  # Classic red
		_:
			return Color.BLACK

func _get_suit_symbol(suit: int) -> String:
	match suit:
		0: return "♠"
		1: return "♥"
		2: return "♣"
		3: return "♦"
		_: return "?"

func _draw_corner_labels(canvas: CanvasItem, size: Vector2, rank: String, suit: String, color: Color) -> void:
	var offset = Vector2(8, 8)
	var font_size = 24
	
	# Top-left rank
	_draw_text(canvas, rank, Vector2(offset.x, offset.y + font_size), font_size, color)
	
	# Top-left suit (below rank)
	_draw_text(canvas, suit, Vector2(offset.x, offset.y + font_size * 2), font_size, color)
	
	# Bottom-right rank (rotated)
	_draw_text_rotated(canvas, rank, Vector2(size.x - offset.x, size.y - offset.y), font_size, color, PI)
	
	# Bottom-right suit (rotated, above rank)
	_draw_text_rotated(canvas, suit, Vector2(size.x - offset.x, size.y - offset.y - font_size), font_size, color, PI)

func _draw_center_pattern(canvas: CanvasItem, size: Vector2, rank: String, suit: String, color: Color) -> void:
	var center = size / 2
	
	# Special handling for face cards
	if rank in ["J", "Q", "K"]:
		# Large center suit symbol for face cards
		_draw_text(canvas, suit, center, int(size.y * 0.4), color)
	elif rank == "A":
		# Large single suit for Ace
		_draw_text(canvas, suit, center, int(size.y * 0.5), color)
	else:
		# Number cards - draw suit pattern
		var num = _rank_to_number(rank)
		if num > 0:
			_draw_suit_pattern(canvas, size, suit, color, num)

func _draw_suit_pattern(canvas: CanvasItem, size: Vector2, suit: String, color: Color, count: int) -> void:
	# Simplified pip patterns for number cards
	var positions = _get_pip_positions(size, count)
	var pip_size = int(size.y * 0.12)
	
	for pos in positions:
		_draw_text(canvas, suit, pos, pip_size, color)

func _get_pip_positions(size: Vector2, count: int) -> Array:
	var positions = []
	var cx = size.x / 2
	var cy = size.y / 2
	var wx = size.x * 0.25  # Width spacing
	var hy = size.y * 0.25  # Height spacing
	
	# Simple pip layouts for cards 2-10
	match count:
		2:
			positions = [Vector2(cx, cy - hy), Vector2(cx, cy + hy)]
		3:
			positions = [Vector2(cx, cy - hy), Vector2(cx, cy), Vector2(cx, cy + hy)]
		4:
			positions = [Vector2(cx - wx/2, cy - hy), Vector2(cx + wx/2, cy - hy),
						Vector2(cx - wx/2, cy + hy), Vector2(cx + wx/2, cy + hy)]
		5:
			positions = [Vector2(cx - wx/2, cy - hy), Vector2(cx + wx/2, cy - hy),
						Vector2(cx, cy),
						Vector2(cx - wx/2, cy + hy), Vector2(cx + wx/2, cy + hy)]
		6:
			positions = [Vector2(cx - wx/2, cy - hy), Vector2(cx + wx/2, cy - hy),
						Vector2(cx - wx/2, cy), Vector2(cx + wx/2, cy),
						Vector2(cx - wx/2, cy + hy), Vector2(cx + wx/2, cy + hy)]
		7:
			positions = _get_pip_positions(size, 6)
			positions.append(Vector2(cx, cy - hy/2))
		8:
			positions = _get_pip_positions(size, 6)
			positions.append(Vector2(cx, cy - hy/2))
			positions.append(Vector2(cx, cy + hy/2))
		9:
			positions = _get_pip_positions(size, 8)
			positions.append(Vector2(cx, cy))
		10:
			positions = _get_pip_positions(size, 8)
			positions.append(Vector2(cx, cy - hy * 0.5))
			positions.append(Vector2(cx, cy + hy * 0.5))
		_:
			positions = [Vector2(cx, cy)]
	
	return positions

func _rank_to_number(rank: String) -> int:
	if rank.is_valid_int():
		return rank.to_int()
	return 0

# Fixed signatures to match parent class
func _draw_text(canvas: CanvasItem, text: String, pos: Vector2, size: int, color: Color) -> void:
	# This would use the parent's implementation or override with custom drawing
	var font = ThemeDB.fallback_font
	if font:
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var draw_pos = pos - text_size / 2  # Center by default
		canvas.draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_text_rotated(canvas: CanvasItem, text: String, pos: Vector2, size: int, color: Color, rotation: float) -> void:
	# For now, just draw without rotation (proper implementation would use transforms)
	_draw_text(canvas, text, pos, size, color)
