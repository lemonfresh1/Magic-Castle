# GlyphwaveCardBack.gd - Ornate geometric border with rotating hieroglyph halo
# Location: res://Pyramids/scripts/items/card_backs/procedural/GlyphwaveCardBack.gd
# Last Updated: Created Glyphwave card back with rotating glyphs [Date]

extends ProceduralCardBack

# Color palette
const DEEP_PURPLE = Color("#6A0DAD")
const GOLD = Color("#FFD700")
const OBSIDIAN_BLACK = Color("#000000")
const NEON_PURPLE = Color("#9933FF")
const SOFT_GOLD = Color("#FFD70044")

# Egyptian hieroglyphs and symbols
const HIEROGLYPHS = ["☥", "𓂀", "𓅱", "𓆣", "𓉴", "𓊖", "⚛", "◈", "◉", "❂", "✦", "⬟"]

func _init():
	item_id = "glyphwave_card_back"
	theme_name = "Glyphwave"
	display_name = "Glyphwave Card Back"
	item_rarity = UnifiedItemData.Rarity.EPIC
	is_animated = true
	animation_duration = 2.5
	card_bg_color = OBSIDIAN_BLACK

func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Draw glossy black obsidian background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), OBSIDIAN_BLACK)
	
	# Draw glossy overlay effect
	_draw_glossy_effect(canvas, size)
	
	# Draw ornate geometric border
	_draw_ornate_geometric_border(canvas, size)
	
	# Draw central neon pyramid
	_draw_central_pyramid_design(canvas, size)
	
	# Draw rotating hieroglyph halo
	if is_animated:
		_draw_rotating_hieroglyph_halo(canvas, size)
	
	# Draw gold shimmer on edges
	if is_animated and animation_phase > 0:
		_draw_gold_edge_shimmer(canvas, size)

func _draw_glossy_effect(canvas: CanvasItem, size: Vector2) -> void:
	# Top highlight for glossy look
	var gradient_height = size.y * 0.4
	for i in range(int(gradient_height)):
		var alpha = (1.0 - float(i) / gradient_height) * 0.12
		var gradient_color = Color.WHITE
		gradient_color.a = alpha
		canvas.draw_line(Vector2(0, i), Vector2(size.x, i), gradient_color, 1.0)

func _draw_ornate_geometric_border(canvas: CanvasItem, size: Vector2) -> void:
	var border_width = 12.0
	var pattern_size = 8.0
	
	# Draw main border frame
	_draw_egyptian_pattern_border(canvas, Rect2(0, 0, size.x, border_width), true)  # Top
	_draw_egyptian_pattern_border(canvas, Rect2(0, size.y - border_width, size.x, border_width), true)  # Bottom
	_draw_egyptian_pattern_border(canvas, Rect2(0, border_width, border_width, size.y - border_width * 2), false)  # Left
	_draw_egyptian_pattern_border(canvas, Rect2(size.x - border_width, border_width, border_width, size.y - border_width * 2), false)  # Right
	
	# Draw corner ornaments
	_draw_corner_pyramid(canvas, Vector2(0, 0), 0)  # Top-left
	_draw_corner_pyramid(canvas, Vector2(size.x, 0), PI/2)  # Top-right
	_draw_corner_pyramid(canvas, Vector2(size.x, size.y), PI)  # Bottom-right
	_draw_corner_pyramid(canvas, Vector2(0, size.y), -PI/2)  # Bottom-left

func _draw_egyptian_pattern_border(canvas: CanvasItem, rect: Rect2, horizontal: bool) -> void:
	# Create alternating geometric pattern
	var pattern_count = int(rect.size.x / 8) if horizontal else int(rect.size.y / 8)
	
	for i in range(pattern_count):
		var color = DEEP_PURPLE if i % 2 == 0 else GOLD
		color.a = 0.6
		
		if horizontal:
			var pattern_rect = Rect2(rect.position.x + i * 8, rect.position.y, 8, rect.size.y)
			canvas.draw_rect(pattern_rect, color)
			
			# Add detail lines
			if i % 2 == 0:
				var line_color = GOLD
				line_color.a = 0.3
				canvas.draw_line(
					Vector2(pattern_rect.position.x + 4, pattern_rect.position.y),
					Vector2(pattern_rect.position.x + 4, pattern_rect.position.y + pattern_rect.size.y),
					line_color, 1.0
				)
		else:
			var pattern_rect = Rect2(rect.position.x, rect.position.y + i * 8, rect.size.x, 8)
			canvas.draw_rect(pattern_rect, color)
			
			# Add detail lines
			if i % 2 == 0:
				var line_color = GOLD
				line_color.a = 0.3
				canvas.draw_line(
					Vector2(pattern_rect.position.x, pattern_rect.position.y + 4),
					Vector2(pattern_rect.position.x + pattern_rect.size.x, pattern_rect.position.y + 4),
					line_color, 1.0
				)

func _draw_corner_pyramid(canvas: CanvasItem, pos: Vector2, rotation: float) -> void:
	canvas.draw_set_transform(pos, rotation, Vector2.ONE)
	
	# Draw triangular pyramid corner
	var pyramid_points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(20, 0),
		Vector2(20, 8),
		Vector2(8, 8),
		Vector2(8, 20),
		Vector2(0, 20)
	])
	
	# Fill
	canvas.draw_colored_polygon(pyramid_points, GOLD)
	
	# Neon edge
	var edge_color = NEON_PURPLE
	edge_color.a = 0.8
	for i in range(pyramid_points.size()):
		var next = (i + 1) % pyramid_points.size()
		canvas.draw_line(pyramid_points[i], pyramid_points[next], edge_color, 1.0)
	
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_central_pyramid_design(canvas: CanvasItem, size: Vector2) -> void:
	var center = size / 2
	var pyramid_size = 50.0
	
	# Main pyramid points
	var peak = center + Vector2(0, -pyramid_size * 0.7)
	var left = center + Vector2(-pyramid_size * 0.6, pyramid_size * 0.5)
	var right = center + Vector2(pyramid_size * 0.6, pyramid_size * 0.5)
	
	# Draw shadow pyramid slightly offset
	var shadow_offset = Vector2(3, 3)
	var shadow_color = Color.BLACK
	shadow_color.a = 0.3
	canvas.draw_colored_polygon(PackedVector2Array([
		peak + shadow_offset,
		left + shadow_offset,
		right + shadow_offset
	]), shadow_color)
	
	# Fill main pyramid
	var fill_color = DEEP_PURPLE
	fill_color.a = 0.3
	canvas.draw_colored_polygon(PackedVector2Array([peak, left, right]), fill_color)
	
	# Draw inner pyramid (smaller)
	var inner_scale = 0.6
	var inner_peak = center + Vector2(0, -pyramid_size * 0.7 * inner_scale)
	var inner_left = center + Vector2(-pyramid_size * 0.6 * inner_scale, pyramid_size * 0.5 * inner_scale)
	var inner_right = center + Vector2(pyramid_size * 0.6 * inner_scale, pyramid_size * 0.5 * inner_scale)
	
	var inner_color = OBSIDIAN_BLACK
	inner_color.a = 0.5
	canvas.draw_colored_polygon(PackedVector2Array([inner_peak, inner_left, inner_right]), inner_color)
	
	# Draw neon edges with glow
	var edge_color = NEON_PURPLE
	if is_animated:
		var pulse = sin(animation_phase * TAU / animation_duration)
		edge_color.a = 0.5 + pulse * 0.5
	else:
		edge_color.a = 0.8
	
	# Multiple passes for glow effect
	for width in [4.0, 2.0, 1.0]:
		var glow_color = edge_color
		glow_color.a *= (1.0 / width)
		
		# Outer pyramid
		canvas.draw_line(peak, left, glow_color, width)
		canvas.draw_line(peak, right, glow_color, width)
		canvas.draw_line(left, right, glow_color, width * 0.7)
		
		# Inner pyramid
		canvas.draw_line(inner_peak, inner_left, GOLD, width * 0.5)
		canvas.draw_line(inner_peak, inner_right, GOLD, width * 0.5)
		canvas.draw_line(inner_left, inner_right, GOLD, width * 0.3)
	
	# Draw Eye of Horus at center
	_draw_eye_of_horus(canvas, center)

func _draw_eye_of_horus(canvas: CanvasItem, center: Vector2) -> void:
	var font = ThemeDB.fallback_font
	var eye_symbol = "☥"  # Ankh as substitute
	var eye_color = GOLD
	
	if is_animated:
		var pulse = sin(animation_phase * TAU / animation_duration * 2)
		eye_color.a = 0.5 + pulse * 0.3
	else:
		eye_color.a = 0.7
	
	# Draw with glow
	for i in range(3):
		var glow_color = eye_color
		glow_color.a *= (1.0 - i * 0.3)
		canvas.draw_string(font, center - Vector2(10, -8) + Vector2(i, i) * 0.5, eye_symbol, 
						  HORIZONTAL_ALIGNMENT_CENTER, -1, 20 - i * 2, glow_color)

func _draw_rotating_hieroglyph_halo(canvas: CanvasItem, size: Vector2) -> void:
	var center = size / 2
	var radius = 70.0
	var num_glyphs = 8
	var font = ThemeDB.fallback_font
	
	# Calculate rotation based on animation phase (very slow clockwise)
	var base_rotation = animation_phase * 0.3  # Slow rotation
	
	for i in range(num_glyphs):
		var angle = (i * TAU / num_glyphs) + base_rotation
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		
		# Select hieroglyph
		var glyph = HIEROGLYPHS[i % HIEROGLYPHS.size()]
		
		# Calculate alpha based on position (fade in/out)
		var fade = (sin(angle * 2 + animation_phase) + 1.0) * 0.5
		var glyph_color = GOLD
		glyph_color.a = 0.2 + fade * 0.3
		
		# Draw hieroglyph with rotation
		canvas.draw_set_transform(pos, angle + PI/2, Vector2.ONE)
		canvas.draw_string(font, Vector2(-8, 6), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, glyph_color)
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Draw inner ring of smaller glyphs
	var inner_radius = 45.0
	for i in range(6):
		var angle = (i * TAU / 6) - base_rotation * 0.5  # Counter-rotate slightly
		var pos = center + Vector2(cos(angle), sin(angle)) * inner_radius
		
		var glyph = HIEROGLYPHS[(i + 6) % HIEROGLYPHS.size()]
		var glyph_color = DEEP_PURPLE
		glyph_color.a = 0.15 + sin(angle * 3 + animation_phase * 2) * 0.1
		
		canvas.draw_string(font, pos - Vector2(6, -6), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, glyph_color)

func _draw_gold_edge_shimmer(canvas: CanvasItem, size: Vector2) -> void:
	var shimmer_intensity = (sin(animation_phase * TAU / animation_duration) + 1.0) * 0.5
	
	if shimmer_intensity > 0.5:
		var shimmer_color = GOLD
		shimmer_color.a = (shimmer_intensity - 0.5) * 0.4
		
		# Draw shimmer on edges with gradient
		for i in range(3):
			var edge_color = shimmer_color
			edge_color.a *= (1.0 - i * 0.3)
			var inset = i * 2.0
			
			# Draw shimmer lines
			var rect = Rect2(inset, inset, size.x - inset * 2, size.y - inset * 2)
			canvas.draw_rect(rect, edge_color, false, 2.0 - i * 0.5)
