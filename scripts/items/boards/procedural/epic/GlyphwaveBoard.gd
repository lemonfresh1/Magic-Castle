# GlyphwaveBoard.gd - Procedural 3D scene with neon pyramids and drifting glyphs
# Location: res://Pyramids/scripts/items/boards/procedural/GlyphwaveBoard.gd
# Last Updated: Created Glyphwave board with animated pyramids and glyphs [Date]

extends ProceduralBoard

# Color palette
const DEEP_PURPLE = Color("#6A0DAD")
const GOLD = Color("#FFD700")
const OBSIDIAN_BLACK = Color("#000000")
const NEON_PURPLE = Color("#9933FF")
const SOFT_GOLD = Color("#FFD70066")

# Glyph characters (Egyptian-inspired symbols)
const GLYPHS = ["☥", "𓂀", "𓅱", "𓆣", "𓉴", "⚛", "◈", "◉", "❂", "✦", "⬟", "⬢"]

# Animation tracking
var glyph_particles = []
var pyramid_pulse = 0.0

func _init():
	item_id = "glyphwave_board"
	theme_name = "Glyphwave"
	display_name = "Glyphwave Board"
	item_rarity = UnifiedItemData.Rarity.EPIC
	is_animated = true
	animation_duration = 2.5
	board_bg_color = OBSIDIAN_BLACK
	
	# Initialize particle system
	_initialize_particles()

func _initialize_particles():
	# Create 8-12 drifting glyph particles
	for i in range(10):
		glyph_particles.append({
			"glyph": GLYPHS[randi() % GLYPHS.size()],
			"position": Vector2(randf() * BOARD_WIDTH, randf() * BOARD_HEIGHT),
			"velocity": Vector2(randf_range(-15, 15), randf_range(-10, -5)),
			"rotation": randf() * TAU,
			"rotation_speed": randf_range(-0.5, 0.5),
			"scale": randf_range(0.8, 1.2),
			"alpha": randf_range(0.3, 0.7),
			"pulse_offset": randf() * TAU
		})

func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Draw obsidian black background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), OBSIDIAN_BLACK)
	
	# Draw distant pyramid silhouettes (3D perspective effect)
	_draw_pyramid_scene(canvas, size)
	
	# Draw ornate border with geometric patterns
	_draw_ornate_border(canvas, size)
	
	# Draw drifting glyphs
	if is_animated:
		_update_and_draw_glyphs(canvas, size)
	
	# Draw gold shimmer effect
	if is_animated and animation_phase > 0:
		_draw_gold_shimmer(canvas, size)

func _draw_pyramid_scene(canvas: CanvasItem, size: Vector2) -> void:
	# Draw 3 pyramids with perspective
	var pyramids = [
		{"x": size.x * 0.2, "scale": 0.6, "depth": 0},
		{"x": size.x * 0.5, "scale": 1.0, "depth": 1},
		{"x": size.x * 0.8, "scale": 0.7, "depth": 0}
	]
	
	var horizon_y = size.y * 0.6
	
	for pyramid in pyramids:
		var base_width = 80 * pyramid.scale
		var height = 70 * pyramid.scale
		var x = pyramid.x
		var y = horizon_y
		
		# Calculate pyramid points
		var peak = Vector2(x, y - height)
		var left = Vector2(x - base_width/2, y)
		var right = Vector2(x + base_width/2, y)
		
		# Draw pyramid fill (darker for depth)
		var fill_color = DEEP_PURPLE
		fill_color = fill_color.darkened(0.3 * (1 - pyramid.depth))
		fill_color.a = 0.4
		canvas.draw_colored_polygon(PackedVector2Array([peak, left, right]), fill_color)
		
		# Draw neon edges
		var edge_color = NEON_PURPLE
		edge_color.a = 0.8 + (pyramid.depth * 0.2)
		
		if is_animated:
			# Pulse effect
			var pulse = sin(animation_phase * TAU / animation_duration + pyramid.x)
			edge_color.a *= (0.8 + pulse * 0.2)
		
		canvas.draw_line(peak, left, edge_color, 2.0)
		canvas.draw_line(peak, right, edge_color, 2.0)
		canvas.draw_line(left, right, edge_color, 1.0)
		
		# Draw vertical energy beam from peak
		if pyramid.depth == 1:  # Main pyramid
			var beam_color = GOLD
			beam_color.a = 0.3
			if is_animated:
				beam_color.a *= (0.7 + sin(animation_phase * TAU / animation_duration) * 0.3)
			canvas.draw_line(peak, Vector2(x, 0), beam_color, 3.0)

func _draw_ornate_border(canvas: CanvasItem, size: Vector2) -> void:
	var border_width = 15.0
	var corner_size = 25.0
	
	# Draw main border frame
	var border_color = DEEP_PURPLE
	border_color.a = 0.6
	
	# Top and bottom borders with geometric pattern
	for x in range(0, int(size.x), 20):
		var rect_top = Rect2(x, 0, 15, border_width)
		var rect_bottom = Rect2(x, size.y - border_width, 15, border_width)
		
		var pattern_color = DEEP_PURPLE if (x / 20) % 2 == 0 else GOLD
		pattern_color.a = 0.4
		
		canvas.draw_rect(rect_top, pattern_color)
		canvas.draw_rect(rect_bottom, pattern_color)
	
	# Left and right borders
	for y in range(0, int(size.y), 20):
		var rect_left = Rect2(0, y, border_width, 15)
		var rect_right = Rect2(size.x - border_width, y, border_width, 15)
		
		var pattern_color = DEEP_PURPLE if (y / 20) % 2 == 0 else GOLD
		pattern_color.a = 0.4
		
		canvas.draw_rect(rect_left, pattern_color)
		canvas.draw_rect(rect_right, pattern_color)
	
	# Draw ornate corners
	_draw_corner_ornament(canvas, Vector2(0, 0), 0)  # Top-left
	_draw_corner_ornament(canvas, Vector2(size.x, 0), PI/2)  # Top-right
	_draw_corner_ornament(canvas, Vector2(size.x, size.y), PI)  # Bottom-right
	_draw_corner_ornament(canvas, Vector2(0, size.y), -PI/2)  # Bottom-left

func _draw_corner_ornament(canvas: CanvasItem, pos: Vector2, rotation: float) -> void:
	canvas.draw_set_transform(pos, rotation, Vector2.ONE)
	
	# Draw triangular corner design
	var points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(30, 0),
		Vector2(30, 10),
		Vector2(10, 10),
		Vector2(10, 30),
		Vector2(0, 30)
	])
	
	canvas.draw_colored_polygon(points, GOLD)
	
	# Add detail lines
	canvas.draw_line(Vector2(5, 5), Vector2(25, 5), DEEP_PURPLE, 1.0)
	canvas.draw_line(Vector2(5, 5), Vector2(5, 25), DEEP_PURPLE, 1.0)
	
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _update_and_draw_glyphs(canvas: CanvasItem, size: Vector2) -> void:
	var font = ThemeDB.fallback_font
	
	for particle in glyph_particles:
		# Update position
		particle.position += particle.velocity * (1.0 / 60.0)  # Assume 60 FPS
		particle.rotation += particle.rotation_speed * (1.0 / 60.0)
		
		# Wrap around screen
		if particle.position.x < -20:
			particle.position.x = size.x + 20
		elif particle.position.x > size.x + 20:
			particle.position.x = -20
			
		if particle.position.y < -20:
			particle.position.y = size.y + 20
			particle.velocity.y = randf_range(-10, -5)  # Reset upward drift
		
		# Calculate glow alpha with pulse
		var glow_alpha = particle.alpha
		if is_animated:
			var pulse = sin(animation_phase * TAU / animation_duration + particle.pulse_offset)
			glow_alpha *= (0.7 + pulse * 0.3)
		
		# Draw glyph with glow
		var glyph_color = GOLD
		glyph_color.a = glow_alpha
		
		canvas.draw_set_transform(particle.position, particle.rotation, Vector2.ONE * particle.scale)
		
		# Draw glow layers
		for i in range(3):
			var layer_color = glyph_color
			layer_color.a *= (1.0 - i * 0.3)
			var offset = Vector2(0, 0)
			canvas.draw_string(font, offset, particle.glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 20 + i * 2, layer_color)
		
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_gold_shimmer(canvas: CanvasItem, size: Vector2) -> void:
	# Edge shimmer effect
	var shimmer_intensity = (sin(animation_phase * TAU / animation_duration) + 1.0) * 0.5
	
	if shimmer_intensity > 0.6:
		var shimmer_color = GOLD
		shimmer_color.a = (shimmer_intensity - 0.6) * 0.5
		
		# Draw shimmer on edges
		var shimmer_width = 3.0
		
		# Top edge
		var top_gradient = Rect2(0, 0, size.x, shimmer_width)
		canvas.draw_rect(top_gradient, shimmer_color)
		
		# Bottom edge
		var bottom_gradient = Rect2(0, size.y - shimmer_width, size.x, shimmer_width)
		canvas.draw_rect(bottom_gradient, shimmer_color)
		
		# Left edge
		var left_gradient = Rect2(0, 0, shimmer_width, size.y)
		canvas.draw_rect(left_gradient, shimmer_color)
		
		# Right edge
		var right_gradient = Rect2(size.x - shimmer_width, 0, shimmer_width, size.y)
		canvas.draw_rect(right_gradient, shimmer_color)
