# ArcticAuroraBoard.gd - Procedurally generated Arctic Aurora board with animated ribbons
# Location: res://Pyramids/scripts/items/boards/procedural/uncommon/ArcticAuroraBoard.gd
# Last Updated: Created Arctic Aurora board design [Date]

extends ProceduralBoard

# Arctic Aurora color palette
const COLOR_ICE_BLUE = Color("#AEE4FF")
const COLOR_EMERALD = Color("#2ECC71")
const COLOR_MAGENTA = Color("#D946EF")
const COLOR_SNOW_WHITE = Color("#F8F9FA")
const COLOR_FROST = Color("#E3F2FD")

func _init():
	theme_name = "Arctic Aurora"
	item_id = "arctic_aurora_board"
	display_name = "Arctic Aurora Board"
	item_rarity = UnifiedItemData.Rarity.UNCOMMON
	is_animated = true
	animation_duration = 6.0
	animation_elements = ["aurora_ribbons", "sparkles", "snow_drift"]

func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Base gradient background (dark night sky at top, lighter frost at bottom)
	var gradient_colors = [
		Color(0.05, 0.1, 0.2),  # Dark night blue
		Color(0.1, 0.15, 0.25),  # Mid night
		COLOR_ICE_BLUE * 0.3,    # Faint ice blue
		COLOR_FROST * 0.5        # Frost at bottom
	]
	
	# Draw gradient background
	var step_height = size.y / gradient_colors.size()
	for i in range(gradient_colors.size() - 1):
		var rect = Rect2(0, i * step_height, size.x, step_height * 1.5)
		var from_color = gradient_colors[i]
		var to_color = gradient_colors[i + 1]
		
		# Draw gradient steps
		for j in range(10):
			var t = j / 10.0
			var color = from_color.lerp(to_color, t)
			var sub_rect = Rect2(0, rect.position.y + (rect.size.y * j / 10), size.x, rect.size.y / 10)
			canvas.draw_rect(sub_rect, color)
	
	# Draw aurora ribbons
	_draw_aurora_ribbons(canvas, size)
	
	# Draw snow/frost texture
	_draw_frost_texture(canvas, size)
	
	# Draw sparkles
	_draw_sparkles(canvas, size)
	
	# Subtle vignette effect
	_draw_vignette(canvas, size)

func _draw_aurora_ribbons(canvas: CanvasItem, size: Vector2) -> void:
	# Create 3 layers of aurora ribbons
	var aurora_configs = [
		{"color": COLOR_EMERALD, "opacity": 0.3, "offset": 0.0, "amplitude": 40},
		{"color": COLOR_MAGENTA, "opacity": 0.25, "offset": 0.3, "amplitude": 30},
		{"color": COLOR_ICE_BLUE, "opacity": 0.35, "offset": 0.6, "amplitude": 35}
	]
	
	for config in aurora_configs:
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		
		# Create wavy ribbon path
		var steps = 50
		for i in range(steps + 1):
			var x = (i / float(steps)) * size.x
			var base_y = size.y * 0.3  # Aurora appears in upper third
			
			# Create wave with animation
			var wave = sin((x / size.x) * TAU * 2 + animation_phase * TAU + config.offset * TAU)
			var y = base_y + wave * config.amplitude
			
			points.append(Vector2(x, y))
			
			# Fade edges
			var edge_fade = 1.0
			if i < 5:
				edge_fade = i / 5.0
			elif i > steps - 5:
				edge_fade = (steps - i) / 5.0
			
			var color = config.color
			color.a = config.opacity * edge_fade
			colors.append(color)
		
		# Add bottom points to close the ribbon
		for i in range(steps, -1, -1):
			var x = (i / float(steps)) * size.x
			points.append(Vector2(x, size.y * 0.5))
			colors.append(Color(config.color.r, config.color.g, config.color.b, 0))
		
		# Draw the ribbon
		canvas.draw_colored_polygon(points, config.color * Color(1, 1, 1, config.opacity * 0.5))
		
		# Add glow effect with lines
		for i in range(steps):
			var start = points[i]
			var end = points[i + 1]
			var color = colors[i]
			color.a *= 0.5
			canvas.draw_line(start, end, color, 2.0)

func _draw_frost_texture(canvas: CanvasItem, size: Vector2) -> void:
	# Create frost pattern at bottom of board
	var frost_height = size.y * 0.3
	var frost_rect = Rect2(0, size.y - frost_height, size.x, frost_height)
	
	# Gradient frost overlay
	for i in range(10):
		var t = i / 10.0
		var opacity = (1.0 - t) * 0.15
		var y = frost_rect.position.y + (frost_rect.size.y * t)
		var rect = Rect2(0, y, size.x, frost_rect.size.y / 10)
		canvas.draw_rect(rect, COLOR_FROST * Color(1, 1, 1, opacity))
	
	# Add crystalline texture dots
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent pattern
	
	for i in range(50):
		var x = rng.randf() * size.x
		var y = size.y - frost_height + rng.randf() * frost_height
		var crystal_size = rng.randf_range(1, 3)
		var opacity = rng.randf_range(0.1, 0.3)
		
		canvas.draw_circle(Vector2(x, y), crystal_size, COLOR_SNOW_WHITE * Color(1, 1, 1, opacity))

func _draw_sparkles(canvas: CanvasItem, size: Vector2) -> void:
	# Animated sparkles
	var sparkle_count = 30
	var rng = RandomNumberGenerator.new()
	
	for i in range(sparkle_count):
		rng.seed = i * 100
		var x = rng.randf() * size.x
		var y = rng.randf() * size.y * 0.6  # Concentrate in upper area
		
		# Animate sparkle brightness
		var sparkle_phase = fmod(animation_phase * 3 + rng.randf(), 1.0)
		var brightness = sin(sparkle_phase * PI) * 0.8
		
		if brightness > 0.1:
			var sparkle_size = rng.randf_range(1, 2)
			canvas.draw_circle(Vector2(x, y), sparkle_size, COLOR_SNOW_WHITE * Color(1, 1, 1, brightness))
			
			# Draw cross for larger sparkles
			if sparkle_size > 1.5:
				var cross_size = sparkle_size * 2
				canvas.draw_line(
					Vector2(x - cross_size, y),
					Vector2(x + cross_size, y),
					COLOR_SNOW_WHITE * Color(1, 1, 1, brightness * 0.5),
					1.0
				)
				canvas.draw_line(
					Vector2(x, y - cross_size),
					Vector2(x, y + cross_size),
					COLOR_SNOW_WHITE * Color(1, 1, 1, brightness * 0.5),
					1.0
				)

func _draw_vignette(canvas: CanvasItem, size: Vector2) -> void:
	# Draw vignette effect around edges
	var vignette_width = 20
	var vignette_color = Color(0, 0, 0, 0.2)
	
	# Top
	for i in range(vignette_width):
		var opacity = (1.0 - (i / float(vignette_width))) * 0.2
		canvas.draw_rect(Rect2(0, i, size.x, 1), Color(0, 0, 0, opacity))
	
	# Bottom
	for i in range(vignette_width):
		var opacity = (1.0 - (i / float(vignette_width))) * 0.2
		canvas.draw_rect(Rect2(0, size.y - i - 1, size.x, 1), Color(0, 0, 0, opacity))
	
	# Left
	for i in range(vignette_width):
		var opacity = (1.0 - (i / float(vignette_width))) * 0.2
		canvas.draw_rect(Rect2(i, 0, 1, size.y), Color(0, 0, 0, opacity))
	
	# Right
	for i in range(vignette_width):
		var opacity = (1.0 - (i / float(vignette_width))) * 0.2
		canvas.draw_rect(Rect2(size.x - i - 1, 0, 1, size.y), Color(0, 0, 0, opacity))
