# NeonNightBoard.gd - Tron-style angled neon grid with pulse glow
# Location: res://Pyramids/scripts/items/boards/procedural/NeonNightBoard.gd
# Last Updated: Created Neon Night board with animated grid [Date]

extends ProceduralBoard

# Color palette
const NEON_BLUE = Color("#00AEEF")
const NEON_PINK = Color("#FF2BAC")
const MATTE_BLACK = Color("#0A0A0A")
const GRID_COLOR = Color("#00AEEF33")  # Semi-transparent blue
const PULSE_COLOR = Color("#FF2BAC66")  # Semi-transparent pink

func _init():
	item_id = "neon_night_board"
	theme_name = "Neon Night"
	display_name = "Neon Night Board"
	item_rarity = UnifiedItemData.Rarity.COMMON
	is_animated = true
	animation_duration = 2.5
	board_bg_color = MATTE_BLACK

func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Draw matte black background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), MATTE_BLACK)
	
	# Calculate grid parameters
	var grid_size = 30.0  # Size of each grid cell
	var angle = deg_to_rad(15)  # 15-degree angle for the grid
	
	# Draw angled grid lines
	_draw_angled_grid(canvas, size, grid_size, angle)
	
	# Draw corner joints (Tron-style corners)
	_draw_corner_joints(canvas, size)
	
	# Draw animated pulse if enabled
	if is_animated and animation_phase > 0:
		_draw_pulse_effect(canvas, size)

func _draw_angled_grid(canvas: CanvasItem, size: Vector2, grid_size: float, angle: float) -> void:
	var line_width = 1.0
	
	# Calculate the diagonal length to ensure full coverage
	var diagonal = sqrt(size.x * size.x + size.y * size.y)
	
	# Draw angled vertical lines
	var num_lines = int(diagonal / grid_size) * 2
	for i in range(-num_lines, num_lines):
		var x_offset = i * grid_size
		var start_x = x_offset - size.y * tan(angle)
		var end_x = x_offset + size.y * tan(angle)
		
		var start = Vector2(start_x, 0)
		var end = Vector2(end_x, size.y)
		
		# Clip to canvas bounds
		if _line_intersects_rect(start, end, Rect2(Vector2.ZERO, size)):
			canvas.draw_line(start, end, GRID_COLOR, line_width)
	
	# Draw horizontal lines with slight angle
	for i in range(int(size.y / grid_size) + 2):
		var y = i * grid_size
		var start = Vector2(0, y - size.x * tan(angle * 0.3))
		var end = Vector2(size.x, y + size.x * tan(angle * 0.3))
		
		if y >= -grid_size and y <= size.y + grid_size:
			canvas.draw_line(start, end, GRID_COLOR, line_width)

func _draw_corner_joints(canvas: CanvasItem, size: Vector2) -> void:
	var corner_size = 20.0
	var line_width = 2.0
	var corner_color = NEON_BLUE
	
	# Top-left corner
	canvas.draw_line(Vector2(0, corner_size), Vector2(0, 0), corner_color, line_width)
	canvas.draw_line(Vector2(0, 0), Vector2(corner_size, 0), corner_color, line_width)
	
	# Top-right corner
	canvas.draw_line(Vector2(size.x - corner_size, 0), Vector2(size.x, 0), corner_color, line_width)
	canvas.draw_line(Vector2(size.x, 0), Vector2(size.x, corner_size), corner_color, line_width)
	
	# Bottom-left corner
	canvas.draw_line(Vector2(0, size.y - corner_size), Vector2(0, size.y), corner_color, line_width)
	canvas.draw_line(Vector2(0, size.y), Vector2(corner_size, size.y), corner_color, line_width)
	
	# Bottom-right corner
	canvas.draw_line(Vector2(size.x - corner_size, size.y), Vector2(size.x, size.y), corner_color, line_width)
	canvas.draw_line(Vector2(size.x, size.y), Vector2(size.x, size.y - corner_size), corner_color, line_width)

func _draw_pulse_effect(canvas: CanvasItem, size: Vector2) -> void:
	# Create occasional pulse effect
	var pulse_intensity = sin(animation_phase * TAU / animation_duration)
	
	# Only pulse occasionally (when sine wave peaks)
	if pulse_intensity > 0.8:
		var alpha = (pulse_intensity - 0.8) * 1.5  # Scale 0.8-1.0 to 0-0.3
		var pulse_color = NEON_PINK
		pulse_color.a = alpha * 0.3
		
		# Draw glowing border
		var border_width = 4.0
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, border_width)), pulse_color)
		canvas.draw_rect(Rect2(Vector2(0, size.y - border_width), Vector2(size.x, border_width)), pulse_color)
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(border_width, size.y)), pulse_color)
		canvas.draw_rect(Rect2(Vector2(size.x - border_width, 0), Vector2(border_width, size.y)), pulse_color)
		
		# Add some glow lines across the grid
		var glow_lines = 3
		for i in range(glow_lines):
			var progress = fmod(animation_phase * 0.2 + i * 0.3, 1.0)
			var y = size.y * progress
			var line_color = pulse_color
			line_color.a *= (1.0 - abs(progress - 0.5) * 2.0)  # Fade at edges
			canvas.draw_line(Vector2(0, y), Vector2(size.x, y), line_color, 2.0)

func _line_intersects_rect(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	# Simple check if line might be visible
	return (start.x >= 0 or end.x >= 0) and (start.x <= rect.size.x or end.x <= rect.size.x)
