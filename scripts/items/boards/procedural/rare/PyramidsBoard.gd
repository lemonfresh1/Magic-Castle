# PyramidsBoard.gd - Procedurally generated Pyramids desert board
# Location: res://Pyramids/scripts/items/boards/procedural/common/PyramidsBoard.gd
# Last Updated: Fixed positioning, shadows, and seamless clouds

extends ProceduralBoard

# Colors
const SKY_TOP = Color(0.5, 0.7, 0.9)
const SKY_BOTTOM = Color(0.9, 0.8, 0.6)
const DESERT_BACK = Color(0.75, 0.55, 0.35)
const DESERT_FRONT = Color(0.65, 0.45, 0.25)

# Cloud settings - SLOW
const CLOUD_SPEEDS = [1.875, 3.125, 4.375, 5.625]  # Divided by 8 for slow movement
var cloud_textures: Array = []

func _init():
	theme_name = "Pyramids"
	item_id = "pyramids_board"
	display_name = "Pyramids Board"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = true
	animation_duration = 20.0  # Slower for clouds
	animation_elements = ["clouds"]
	
	# Load cloud textures once
	_load_cloud_textures()

func _load_cloud_textures():
	"""Load cloud textures directly without scene"""
	for i in range(1, 5):
		var path = "res://Pyramids/scenes/items/boards/1_pyramids/clouds_%d.png" % i
		if ResourceLoader.exists(path):
			cloud_textures.append(load(path))

func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Draw sky gradient
	_draw_sky_gradient(canvas, size)
	
	# Draw clouds BEFORE pyramids (behind them)
	_draw_seamless_clouds(canvas, size)
	
	# Draw desert back layer
	_draw_desert_layer(canvas, size, 0.7, DESERT_BACK)
	
	# Draw pyramids in correct order
	_draw_pyramids(canvas, size)
	
	# Draw front desert layer
	_draw_desert_layer(canvas, size, 0.85, DESERT_FRONT)

func _draw_sky_gradient(canvas: CanvasItem, size: Vector2) -> void:
	"""Draw sky gradient background"""
	var steps = 20
	for i in range(steps):
		var t = i / float(steps)
		var color = SKY_TOP.lerp(SKY_BOTTOM, t)
		var rect = Rect2(0, size.y * t, size.x, size.y / steps + 1)
		canvas.draw_rect(rect, color)

func _draw_desert_layer(canvas: CanvasItem, size: Vector2, y_start: float, color: Color) -> void:
	"""Draw a desert sand layer"""
	var desert_rect = Rect2(0, size.y * y_start, size.x, size.y * (1.0 - y_start))
	
	# Gradient for the sand
	var steps = 10
	for i in range(steps):
		var t = i / float(steps)
		var fade_color = color.lerp(color.darkened(0.3), t)
		var rect = Rect2(
			0, 
			desert_rect.position.y + (desert_rect.size.y * t),
			size.x,
			desert_rect.size.y / steps + 1
		)
		canvas.draw_rect(rect, fade_color)

func _draw_pyramids(canvas: CanvasItem, size: Vector2) -> void:
	"""Draw the three pyramids with correct positioning and shadows"""
	# Scale to board size
	var scale_x = size.x / 1200.0
	var scale_y = size.y / 540.0
	
	# PYRAMID LEFT (background)
	var left_pyramid = {
		"points": PackedVector2Array([
			Vector2(215 * scale_x, 500 * scale_y),  # Bottom left
			Vector2(397 * scale_x, 247 * scale_y),  # Peak
			Vector2(552 * scale_x, 500 * scale_y)   # Bottom right
		]),
		"color": Color(0.65, 0.55, 0.35),  # Lighter (background)
		"shadow_color": Color(0.55, 0.45, 0.25)
	}
	
	# PYRAMID RIGHT (background)  
	var right_pyramid = {
		"points": PackedVector2Array([
			Vector2(648 * scale_x, 500 * scale_y),   # Bottom left
			Vector2(810 * scale_x, 247 * scale_y),   # Peak
			Vector2(999 * scale_x, 500 * scale_y)    # Bottom right (was first in your data)
		]),
		"color": Color(0.65, 0.55, 0.35),  # Same as left (both background)
		"shadow_color": Color(0.55, 0.45, 0.25)
	}
	
	# PYRAMID CENTER (foreground - draw last)
	var center_pyramid = {
		"points": PackedVector2Array([
			Vector2(357 * scale_x, 500 * scale_y),   # Bottom left
			Vector2(598 * scale_x, 160 * scale_y),   # Peak (highest)
			Vector2(852 * scale_x, 500 * scale_y)    # Bottom right
		]),
		"color": Color(0.6, 0.5, 0.3),  # Main pyramid color
		"shadow_color": Color(0.45, 0.35, 0.2)
	}
	
	# Draw background pyramids first
	_draw_single_pyramid(canvas, left_pyramid)
	_draw_single_pyramid(canvas, right_pyramid)
	
	# Draw center pyramid last (on top)
	_draw_single_pyramid(canvas, center_pyramid)

func _draw_single_pyramid(canvas: CanvasItem, pyramid_data: Dictionary) -> void:
	"""Draw a single pyramid with its shadow"""
	var points = pyramid_data.points
	
	# Draw main pyramid shape
	canvas.draw_colored_polygon(points, pyramid_data.color)
	
	# Draw shadow (right face darker)
	if points.size() >= 3:
		# Find peak (lowest Y value)
		var peak_idx = 1  # Usually middle point is peak
		var peak = points[peak_idx]
		
		# Shadow is the right face (peak to right bottom)
		var shadow_points = PackedVector2Array([
			peak,  # Peak
			points[2],  # Bottom right
			Vector2(peak.x, points[2].y)  # Vertical down from peak
		])
		
		canvas.draw_colored_polygon(shadow_points, pyramid_data.shadow_color)

func _draw_seamless_clouds(canvas: CanvasItem, size: Vector2) -> void:
	"""Draw seamlessly scrolling clouds - always continuous"""
	if cloud_textures.is_empty():
		return
	
	for i in range(cloud_textures.size()):
		var texture = cloud_textures[i]
		if not texture:
			continue
		
		# Cloud properties
		var cloud_size = texture.get_size() * 0.4
		var speed = CLOUD_SPEEDS[i]
		
		# Y position and transparency
		var y_position = 50 + (i * 40) * (size.y / 500.0)
		var alpha = 0.7 - (i * 0.15)
		
		# Calculate seamless scrolling position
		# The key is to use modulo to wrap and always draw enough copies
		var scroll_offset = fmod(animation_phase * speed * 100, cloud_size.x)
		
		# We need to draw enough clouds to cover screen width + 1 extra for scrolling
		var clouds_needed = int(ceil(size.x / cloud_size.x)) + 2
		
		# Draw multiple cloud instances to ensure full coverage
		for j in range(clouds_needed):
			var x_pos = (j * cloud_size.x) - scroll_offset - cloud_size.x
			var cloud_rect = Rect2(x_pos, y_position, cloud_size.x, cloud_size.y)
			
			# Draw the cloud
			canvas.draw_texture_rect(
				texture,
				cloud_rect,
				false,
				Color(1, 1, 1, alpha)
			)
