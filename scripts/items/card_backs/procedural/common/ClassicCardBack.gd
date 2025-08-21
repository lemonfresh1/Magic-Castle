# ClassicCardBack.gd - Classic card back with traditional design
# Location: res://Pyramids/scripts/items/card_backs/procedural/common/ClassicCardBack.gd
# Last Updated: Created classic card back

extends ProceduralCardBack

const CARD_BACK_TEXTURE = preload("res://Pyramids/assets/cards/card_back.png")

func _init():
	theme_name = "Classic"
	item_id = "classic_card_back"
	display_name = "Classic Card Back"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = false  # No animation

func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Draw background color (dark blue classic feel)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.2, 0.4))
	
	# Draw the card back texture if it exists
	if CARD_BACK_TEXTURE:
		# Scale texture to fit card size
		var texture_size = CARD_BACK_TEXTURE.get_size()
		var scale_x = size.x / texture_size.x
		var scale_y = size.y / texture_size.y
		
		# Draw texture centered and scaled
		var dest_rect = Rect2(Vector2.ZERO, size)
		canvas.draw_texture_rect(CARD_BACK_TEXTURE, dest_rect, false)
	else:
		# Fallback pattern if texture not found
		_draw_fallback_pattern(canvas, size)
	
	# Draw border
	_draw_border(canvas, size)

func _draw_fallback_pattern(canvas: CanvasItem, size: Vector2) -> void:
	"""Draw a simple pattern if texture is missing"""
	# Classic crosshatch pattern
	var pattern_color = Color(0.2, 0.3, 0.5)
	var line_spacing = 15
	
	# Diagonal lines going right
	for i in range(-int(size.y / line_spacing), int(size.x / line_spacing) + int(size.y / line_spacing)):
		var x1 = i * line_spacing
		var y1 = 0.0
		var x2 = i * line_spacing + size.y
		var y2 = size.y
		
		# Clamp to card bounds
		if x1 < 0:
			y1 = -x1
			x1 = 0
		if x2 > size.x:
			y2 = size.y - (x2 - size.x)
			x2 = size.x
		
		if x1 <= size.x and x2 >= 0:
			canvas.draw_line(Vector2(x1, y1), Vector2(x2, y2), pattern_color, 1.0)
	
	# Diagonal lines going left
	for i in range(0, int(size.x / line_spacing) + int(size.y / line_spacing)):
		var x1 = i * line_spacing
		var y1 = size.y
		var x2 = i * line_spacing - size.y
		var y2 = 0.0
		
		# Clamp to card bounds
		if x2 < 0:
			y2 = size.y + x2
			x2 = 0
		if x1 > size.x:
			y1 = size.y - (x1 - size.x)
			x1 = size.x
		
		if x1 >= 0 and x2 <= size.x:
			canvas.draw_line(Vector2(x1, y1), Vector2(x2, y2), pattern_color, 1.0)
	
	# Center circle decoration
	var center = size / 2
	var radius = min(size.x, size.y) * 0.3
	canvas.draw_arc(center, radius, 0, TAU, 64, pattern_color, 2.0)
	canvas.draw_arc(center, radius * 0.7, 0, TAU, 64, pattern_color, 1.5)
	canvas.draw_arc(center, radius * 0.4, 0, TAU, 64, pattern_color, 1.0)

func _draw_border(canvas: CanvasItem, size: Vector2) -> void:
	"""Draw a simple border around the card"""
	var border_color = Color(0.05, 0.1, 0.2)
	var border_width = 3.0
	
	# Top
	canvas.draw_line(Vector2(0, 0), Vector2(size.x, 0), border_color, border_width)
	# Right
	canvas.draw_line(Vector2(size.x, 0), Vector2(size.x, size.y), border_color, border_width)
	# Bottom
	canvas.draw_line(Vector2(size.x, size.y), Vector2(0, size.y), border_color, border_width)
	# Left
	canvas.draw_line(Vector2(0, size.y), Vector2(0, 0), border_color, border_width)
	
	# Inner border for elegance
	var inner_offset = 5
	var inner_rect = Rect2(
		Vector2(inner_offset, inner_offset),
		size - Vector2(inner_offset * 2, inner_offset * 2)
	)
	canvas.draw_rect(inner_rect, border_color, false, 1.0)
