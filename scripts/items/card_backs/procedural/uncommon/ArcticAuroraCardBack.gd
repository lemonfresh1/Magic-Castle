# ArcticAuroraCardBack.gd - Frost edge card back with aurora tint and snowflake motif
# Location: res://Pyramids/scripts/items/card_backs/procedural/uncommon/ArcticAuroraCardBack.gd
# Last Updated: Created Arctic Aurora card back [Date]

extends ProceduralCardBack

# Arctic Aurora color palette
const COLOR_ICE_BLUE = Color("#AEE4FF")
const COLOR_EMERALD = Color("#2ECC71")
const COLOR_MAGENTA = Color("#D946EF")
const COLOR_SNOW_WHITE = Color("#F8F9FA")
const COLOR_FROST = Color("#E3F2FD")

func _init():
	theme_name = "Arctic Aurora"
	item_id = "arctic_aurora_back"
	display_name = "Arctic Aurora Card Back"
	item_rarity = UnifiedItemData.Rarity.UNCOMMON
	is_animated = true
	animation_duration = 4.0
	animation_elements = ["edge_shimmer", "snowflake_rotation"]

func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Background with aurora gradient
	_draw_background(canvas, size)
	
	# Central snowflake motif
	_draw_central_snowflake(canvas, size)
	
	# Decorative corner snowflakes
	_draw_corner_snowflakes(canvas, size)
	
	# Frost edge border with shimmer
	_draw_frost_border(canvas, size)

func _draw_background(canvas: CanvasItem, size: Vector2) -> void:
	# Base gradient from ice blue to frost
	for i in range(10):
		var t = i / 10.0
		var y = size.y * i / 10
		var h = size.y / 10
		
		# Interpolate from darker edges to lighter center
		var edge_factor = abs(0.5 - t) * 2  # 0 at center, 1 at edges
		var base_color = COLOR_ICE_BLUE.lerp(COLOR_FROST, 1.0 - edge_factor * 0.5)
		
		# Add aurora tint
		if t < 0.3:
			base_color = base_color.lerp(COLOR_EMERALD, 0.15)
		elif t > 0.7:
			base_color = base_color.lerp(COLOR_MAGENTA, 0.15)
		
		canvas.draw_rect(Rect2(0, y, size.x, h), base_color)
	
	# Subtle radial gradient overlay
	var center = size / 2
	var max_radius = min(size.x, size.y) * 0.7
	
	for i in range(5):
		var radius = max_radius * (1.0 - i / 5.0)
		var opacity = 0.05 * (i / 5.0)
		var glow_color = COLOR_SNOW_WHITE * Color(1, 1, 1, opacity)
		
		# Draw concentric circles for glow effect
		for angle in range(0, 360, 10):
			var rad = deg_to_rad(angle)
			var pos = center + Vector2(cos(rad), sin(rad)) * radius
			canvas.draw_circle(pos, radius * 0.1, glow_color)

func _draw_central_snowflake(canvas: CanvasItem, size: Vector2) -> void:
	var center = size / 2
	var snowflake_size = min(size.x, size.y) * 0.35
	
	# Rotating snowflake
	var rotation = animation_phase * 0.2
	
	# Main snowflake color with shimmer
	var shimmer = 0.7 + sin(animation_phase * TAU * 2) * 0.3
	var snowflake_color = COLOR_SNOW_WHITE.lerp(COLOR_MAGENTA, 0.2) * Color(1, 1, 1, shimmer)
	
	# Draw 6 main branches
	for i in range(6):
		var angle = (i * PI / 3) + rotation
		var end_point = center + Vector2(cos(angle), sin(angle)) * snowflake_size
		
		# Main branch with gradient
		for j in range(10):
			var t = j / 10.0
			var pos = center.lerp(end_point, t)
			var thickness = 3.0 * (1.0 - t * 0.5)
			var color = snowflake_color * Color(1, 1, 1, 1.0 - t * 0.3)
			
			if j < 9:
				var next_pos = center.lerp(end_point, (j + 1) / 10.0)
				canvas.draw_line(pos, next_pos, color, thickness)
		
		# Decorative branches
		for j in range(1, 4):
			var branch_pos = center.lerp(end_point, j / 4.0)
			var branch_length = snowflake_size * 0.25 * (1.0 - j / 4.0)
			
			for side in [-1, 1]:
				var branch_angle = angle + side * PI / 4
				var branch_end = branch_pos + Vector2(cos(branch_angle), sin(branch_angle)) * branch_length
				canvas.draw_line(branch_pos, branch_end, snowflake_color * 0.8, 1.5)
				
				# Small decorative crystals at branch ends
				canvas.draw_circle(branch_end, 2, snowflake_color)
	
	# Central crystal
	canvas.draw_circle(center, 8, snowflake_color)
	canvas.draw_circle(center, 6, COLOR_FROST)
	canvas.draw_circle(center, 4, snowflake_color)

func _draw_corner_snowflakes(canvas: CanvasItem, size: Vector2) -> void:
	var corners = [
		Vector2(30, 30),
		Vector2(size.x - 30, 30),
		Vector2(30, size.y - 30),
		Vector2(size.x - 30, size.y - 30)
	]
	
	for i in range(corners.size()):
		var pos = corners[i]
		var small_size = 15
		var rotation = animation_phase * 0.5 + i * PI / 4
		
		# Small decorative snowflake
		for j in range(6):
			var angle = (j * PI / 3) + rotation
			var end_point = pos + Vector2(cos(angle), sin(angle)) * small_size
			var color = COLOR_ICE_BLUE * Color(1, 1, 1, 0.4)
			canvas.draw_line(pos, end_point, color, 1.0)
		
		canvas.draw_circle(pos, 2, COLOR_FROST * 0.6)

func _draw_frost_border(canvas: CanvasItem, size: Vector2) -> void:
	# Animated frost edge effect
	var border_width = 8
	var shimmer_intensity = 0.5 + sin(animation_phase * TAU * 1.5) * 0.3
	
	# Create frost pattern along edges
	for side in range(4):
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		
		match side:
			0:  # Top
				for i in range(20):
					var x = (i / 19.0) * size.x
					var frost_depth = border_width + sin((x / size.x) * TAU * 4 + animation_phase) * 3
					points.append(Vector2(x, 0))
					points.append(Vector2(x, frost_depth))
			1:  # Right
				for i in range(20):
					var y = (i / 19.0) * size.y
					var frost_depth = border_width + sin((y / size.y) * TAU * 4 + animation_phase) * 3
					points.append(Vector2(size.x, y))
					points.append(Vector2(size.x - frost_depth, y))
			2:  # Bottom
				for i in range(20):
					var x = (i / 19.0) * size.x
					var frost_depth = border_width + sin((x / size.x) * TAU * 4 - animation_phase) * 3
					points.append(Vector2(x, size.y))
					points.append(Vector2(x, size.y - frost_depth))
			3:  # Left
				for i in range(20):
					var y = (i / 19.0) * size.y
					var frost_depth = border_width + sin((y / size.y) * TAU * 4 - animation_phase) * 3
					points.append(Vector2(0, y))
					points.append(Vector2(frost_depth, y))
		
		# Draw frost edge gradient
		for i in range(0, points.size(), 2):
			if i + 1 < points.size():
				var inner = points[i]
				var outer = points[i + 1]
				var frost_color = COLOR_FROST.lerp(COLOR_MAGENTA, 0.1)
				frost_color.a = shimmer_intensity * 0.6
				canvas.draw_line(inner, outer, frost_color, 2.0)
	
	# Corner crystals
	var corner_size = 15
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var crystal_pos = corner
		if corner.x > 0:
			crystal_pos.x -= corner_size
		else:
			crystal_pos.x += corner_size
		if corner.y > 0:
			crystal_pos.y -= corner_size
		else:
			crystal_pos.y += corner_size
		
		canvas.draw_circle(crystal_pos, 4, COLOR_FROST * shimmer_intensity)
		canvas.draw_circle(crystal_pos, 2, COLOR_SNOW_WHITE * shimmer_intensity)
