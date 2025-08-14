# NeonNightCardBack.gd - Minimal neon diagonals with pulse animation
# Location: res://Pyramids/scripts/items/card_backs/procedural/NeonNightCardBack.gd
# Last Updated: Created Neon Night card back with diagonal pulse [Date]

extends ProceduralCardBack

# Color palette
const MATTE_BLACK = Color("#0A0A0A")
const NEON_BLUE = Color("#00AEEF")
const NEON_PINK = Color("#FF2BAC")
const WHITE = Color("#FFFFFF")

func _init():
	item_id = "neon_night_back"
	theme_name = "Neon Night"
	display_name = "Neon Night Card Back"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = true
	animation_duration = 2.5
	card_bg_color = MATTE_BLACK

func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Draw matte black background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), MATTE_BLACK)
	
	# Draw parallel diagonal lines
	_draw_diagonal_pattern(canvas, size)
	
	# Draw center logo/symbol
	_draw_center_design(canvas, size)
	
	# Draw animated pulse if enabled
	if is_animated and animation_phase > 0:
		_draw_diagonal_pulse(canvas, size)
	
	# Draw subtle border
	canvas.draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color(0.2, 0.2, 0.2), false, 1.0)

func _draw_diagonal_pattern(canvas: CanvasItem, size: Vector2) -> void:
	var line_spacing = 20.0
	var line_width = 2.0
	var num_lines = int((size.x + size.y) / line_spacing)
	
	# Draw diagonal lines from top-left to bottom-right
	for i in range(num_lines):
		var offset = i * line_spacing
		var start = Vector2(max(0, offset - size.y), max(0, size.y - offset))
		var end = Vector2(min(size.x, offset), min(size.y, size.x + size.y - offset))
		
		# Alternate between blue and pink lines
		var line_color = NEON_BLUE if i % 2 == 0 else NEON_PINK
		line_color.a = 0.3  # Make lines subtle
		
		canvas.draw_line(start, end, line_color, line_width)

func _draw_center_design(canvas: CanvasItem, size: Vector2) -> void:
	var center = size / 2
	
	# Draw a geometric diamond shape in the center
	var diamond_size = 30.0
	var points = PackedVector2Array([
		center + Vector2(0, -diamond_size),  # Top
		center + Vector2(diamond_size, 0),   # Right
		center + Vector2(0, diamond_size),   # Bottom
		center + Vector2(-diamond_size, 0)    # Left
	])
	
	# Fill with semi-transparent black
	var fill_color = MATTE_BLACK
	fill_color.a = 0.8
	canvas.draw_colored_polygon(points, fill_color)
	
	# Draw neon outline
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		canvas.draw_line(points[i], points[next_i], NEON_PINK, 2.0)
	
	# Draw inner lines for extra detail
	canvas.draw_line(center + Vector2(-diamond_size * 0.5, 0), center + Vector2(diamond_size * 0.5, 0), NEON_BLUE, 1.0)
	canvas.draw_line(center + Vector2(0, -diamond_size * 0.5), center + Vector2(0, diamond_size * 0.5), NEON_BLUE, 1.0)
	
	# Add a small glow dot in the center
	var glow_color = WHITE
	glow_color.a = 0.6
	_draw_circle_glow(canvas, center, 3.0, glow_color)

func _draw_diagonal_pulse(canvas: CanvasItem, size: Vector2) -> void:
	# Create pulse that travels from top-left to bottom-right
	var pulse_intensity = sin(animation_phase * TAU / animation_duration)
	
	# Only pulse occasionally (when sine wave peaks)
	if pulse_intensity > 0.7:
		var alpha = (pulse_intensity - 0.7) * 1.0  # Scale 0.7-1.0 to 0-0.3
		var pulse_progress = fmod(animation_phase * 0.4, 1.0)
		
		# Calculate pulse position along diagonal
		var total_distance = size.x + size.y
		var current_distance = total_distance * pulse_progress
		
		# Draw multiple pulse lines for wave effect
		for i in range(3):
			var offset = current_distance - (i * 15)
			if offset > 0 and offset < total_distance:
				var start = Vector2(max(0, offset - size.y), max(0, size.y - offset))
				var end = Vector2(min(size.x, offset), min(size.y, size.x + size.y - offset))
				
				var pulse_color = NEON_PINK
				pulse_color.a = alpha * 0.3 * (1.0 - i * 0.3)  # Fade subsequent lines
				
				canvas.draw_line(start, end, pulse_color, 4.0 - i)
		
		# Add corner glow during pulse
		if pulse_intensity > 0.9:
			var corner_alpha = (pulse_intensity - 0.9) * 3.0
			_draw_corner_glows(canvas, size, corner_alpha * 0.2)

func _draw_circle_glow(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	# Draw multiple circles with decreasing alpha for glow effect
	var layers = 5
	for i in range(layers):
		var layer_radius = radius * (1.0 + i * 0.3)
		var layer_color = color
		layer_color.a *= (1.0 - i * 0.2)
		
		# Draw circle outline
		var points = PackedVector2Array()
		var segments = 16
		for j in range(segments + 1):
			var angle = j * TAU / segments
			points.append(center + Vector2(cos(angle), sin(angle)) * layer_radius)
		
		for j in range(segments):
			canvas.draw_line(points[j], points[j + 1], layer_color, 1.0)

func _draw_corner_glows(canvas: CanvasItem, size: Vector2, alpha: float) -> void:
	var glow_color = NEON_BLUE
	glow_color.a = alpha
	var glow_size = 20.0
	
	# Top-left corner glow
	var gradient_rect = Rect2(0, 0, glow_size, glow_size)
	for i in range(10):
		var rect_color = glow_color
		rect_color.a *= (1.0 - i * 0.1)
		var rect = Rect2(i, i, glow_size - i * 2, glow_size - i * 2)
		canvas.draw_rect(rect, rect_color, false, 1.0)
	
	# Top-right corner glow
	for i in range(10):
		var rect_color = glow_color
		rect_color.a *= (1.0 - i * 0.1)
		var rect = Rect2(size.x - glow_size + i, i, glow_size - i * 2, glow_size - i * 2)
		canvas.draw_rect(rect, rect_color, false, 1.0)
	
	# Bottom-left corner glow
	for i in range(10):
		var rect_color = glow_color
		rect_color.a *= (1.0 - i * 0.1)
		var rect = Rect2(i, size.y - glow_size + i, glow_size - i * 2, glow_size - i * 2)
		canvas.draw_rect(rect, rect_color, false, 1.0)
	
	# Bottom-right corner glow
	for i in range(10):
		var rect_color = glow_color
		rect_color.a *= (1.0 - i * 0.1)
		var rect = Rect2(size.x - glow_size + i, size.y - glow_size + i, glow_size - i * 2, glow_size - i * 2)
		canvas.draw_rect(rect, rect_color, false, 1.0)
