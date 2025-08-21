# ClassicBoard.gd - Classic green felt board with gradient
# Location: res://Pyramids/scripts/items/boards/procedural/common/ClassicBoard.gd
# Last Updated: Created classic board

extends ProceduralBoard

func _init():
	theme_name = "Classic"
	item_id = "classic_board"
	display_name = "Classic Green Board"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = false

func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Draw gradient background - dark forest green to lighter sage green
	_draw_gradient_background(canvas, size)
	
	# Add subtle felt texture pattern
	_draw_felt_texture(canvas, size)
	
	# Draw border
	_draw_border(canvas, size)

func _draw_gradient_background(canvas: CanvasItem, size: Vector2) -> void:
	# Gradient from dark forest green to lighter sage green
	var color_top = Color(0.1, 0.25, 0.15)  # Dark forest green
	var color_bottom = Color(0.25, 0.45, 0.3)  # Lighter sage green
	
	# Draw gradient in steps
	var steps = 20
	for i in range(steps):
		var t = i / float(steps)
		var color = color_top.lerp(color_bottom, t)
		var rect = Rect2(
			0, 
			size.y * i / steps,
			size.x,
			size.y / steps + 1  # +1 to avoid gaps
		)
		canvas.draw_rect(rect, color)

func _draw_felt_texture(canvas: CanvasItem, size: Vector2) -> void:
	# Add subtle noise pattern to simulate felt texture
	var pattern_color = Color(0, 0, 0, 0.05)  # Very subtle darker overlay
	
	# Create a crosshatch pattern for texture
	var spacing = 3
	
	# Horizontal lines
	for y in range(0, int(size.y), spacing * 2):
		canvas.draw_line(
			Vector2(0, y),
			Vector2(size.x, y),
			pattern_color,
			1.0
		)
	
	# Vertical lines
	for x in range(0, int(size.x), spacing * 2):
		canvas.draw_line(
			Vector2(x, 0),
			Vector2(x, size.y),
			pattern_color,
			1.0
		)
	
	# Add some random dots for additional texture
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent pattern
	
	for i in range(100):
		var x = rng.randf() * size.x
		var y = rng.randf() * size.y
		var dot_size = rng.randf_range(0.5, 1.5)
		var dot_alpha = rng.randf_range(0.02, 0.08)
		canvas.draw_circle(
			Vector2(x, y),
			dot_size,
			Color(0, 0, 0, dot_alpha)
		)

func _draw_border(canvas: CanvasItem, size: Vector2) -> void:
	# Draw a subtle darker border around the edges
	var border_color = Color(0.05, 0.15, 0.08, 0.5)
	var border_width = 4
	
	# Top edge gradient
	for i in range(border_width):
		var alpha = (1.0 - i / float(border_width)) * 0.5
		canvas.draw_line(
			Vector2(0, i),
			Vector2(size.x, i),
			Color(0, 0, 0, alpha),
			1.0
		)
	
	# Bottom edge gradient
	for i in range(border_width):
		var alpha = (1.0 - i / float(border_width)) * 0.5
		canvas.draw_line(
			Vector2(0, size.y - i),
			Vector2(size.x, size.y - i),
			Color(0, 0, 0, alpha),
			1.0
		)
	
	# Left edge gradient
	for i in range(border_width):
		var alpha = (1.0 - i / float(border_width)) * 0.5
		canvas.draw_line(
			Vector2(i, 0),
			Vector2(i, size.y),
			Color(0, 0, 0, alpha),
			1.0
		)
	
	# Right edge gradient
	for i in range(border_width):
		var alpha = (1.0 - i / float(border_width)) * 0.5
		canvas.draw_line(
			Vector2(size.x - i, 0),
			Vector2(size.x - i, size.y),
			Color(0, 0, 0, alpha),
			1.0
		)
	
	# Inner highlight for depth
	var highlight_rect = Rect2(
		Vector2(border_width, border_width),
		size - Vector2(border_width * 2, border_width * 2)
	)
	canvas.draw_rect(highlight_rect, Color(1, 1, 1, 0.05), false, 1.0)
