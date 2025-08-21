# ClassicPyramidsGold.gd - Epic tier procedural card back with animated golden pyramid
# Location: res://Pyramids/scripts/items/card_backs/procedural/epic/ClassicPyramidsGold.gd
# Last Updated: Created Classic Pyramids Gold epic design [Date]

class_name ClassicPyramidsGold
extends ProceduralCardBack

func _init():
	# Single identifier
	item_id = "pyramids_back"
	
	# Display properties
	display_name = "Pyramids"
	theme_name = "Pyramids"
	item_rarity = UnifiedItemData.Rarity.EPIC
	
	# Sync with parent's skin_name
	skin_name = item_id
	
	# Animation properties
	is_animated = true
	animation_duration = 2.5
	animation_elements = ["pyramid_glow", "floating_hieroglyphs", "gold_shimmer"]
	
	# High contrast support
	supports_high_contrast = false
	
	# Card styling
	card_bg_color = UIStyleManager.get_card_color("pyramid_papyrus")
	card_border_color = UIStyleManager.get_card_color("pyramid_gold")
	card_border_width = 3
	card_corner_radius = 12

# Main drawing function
func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Background with subtle papyrus texture
	_draw_background(canvas, size)
	
	# Central golden pyramid
	_draw_golden_pyramid(canvas, size)
	
	# Floating hieroglyphs (animation elements)
	_draw_floating_hieroglyphs(canvas, size)
	
	# Gold border with corner details
	_draw_decorative_border(canvas, size)

func _draw_background(canvas: CanvasItem, size: Vector2) -> void:
	# Base papyrus color fills entire card
	var bg_color = UIStyleManager.get_card_color("pyramid_papyrus")
	canvas.draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	
	# Subtle texture with gradient
	var gradient_color = UIStyleManager.get_card_color("pyramid_sand")
	gradient_color.a = 0.2
	
	# Radial gradient from center
	var center = size / 2
	var max_radius = size.length() / 2
	
	for i in range(20):
		var radius = (i / 20.0) * max_radius
		var alpha = 0.1 * (1.0 - i / 20.0)
		var color = gradient_color
		color.a = alpha
		canvas.draw_circle(center, radius, color)

func _draw_golden_pyramid(canvas: CanvasItem, size: Vector2) -> void:
	var center = size / 2
	var pyramid_size = min(size.x, size.y) * 0.3
	
	# Pyramid points
	var top = Vector2(center.x, center.y - pyramid_size * 0.8)
	var left = Vector2(center.x - pyramid_size * 0.6, center.y + pyramid_size * 0.4)
	var right = Vector2(center.x + pyramid_size * 0.6, center.y + pyramid_size * 0.4)
	
	var pyramid_points = PackedVector2Array([top, left, right])
	
	# Main pyramid fill
	var gold_color = UIStyleManager.get_card_color("pyramid_gold")
	canvas.draw_colored_polygon(pyramid_points, gold_color)
	
	# Pyramid outline with glow effect
	var glow_intensity = 1.0
	if is_animated:
		# Animate glow intensity
		glow_intensity = 0.7 + 0.3 * sin(animation_phase * PI * 2)
	
	# Multiple outline passes for glow
	for i in range(3):
		var outline_color = UIStyleManager.get_card_color("pyramid_gold_light")
		outline_color.a = (0.8 - i * 0.2) * glow_intensity
		var line_width = 3 - i
		
		canvas.draw_polyline(pyramid_points + PackedVector2Array([top]), outline_color, line_width)
	
	# Inner pyramid details
	_draw_pyramid_details(canvas, center, pyramid_size)

func _draw_pyramid_details(canvas: CanvasItem, center: Vector2, pyramid_size: float) -> void:
	# Central vertical line
	var top_center = Vector2(center.x, center.y - pyramid_size * 0.8)
	var bottom_center = Vector2(center.x, center.y + pyramid_size * 0.2)
	
	var detail_color = UIStyleManager.get_card_color("pyramid_gold_dark")
	detail_color.a = 0.6
	canvas.draw_line(top_center, bottom_center, detail_color, 2)
	
	# Horizontal segments
	for i in range(3):
		var y_offset = (i + 1) * pyramid_size * 0.15
		var segment_width = pyramid_size * (0.5 - i * 0.1)
		
		var left_point = Vector2(center.x - segment_width, center.y - pyramid_size * 0.8 + y_offset)
		var right_point = Vector2(center.x + segment_width, center.y - pyramid_size * 0.8 + y_offset)
		
		canvas.draw_line(left_point, right_point, detail_color, 1)

func _draw_floating_hieroglyphs(canvas: CanvasItem, size: Vector2) -> void:
	if not is_animated:
		return
	
	var symbol_color = UIStyleManager.get_card_color("pyramid_gold")
	symbol_color.a = 0.4 + 0.3 * sin(animation_phase * PI * 3)
	
	# Position hieroglyphs around the pyramid
	var positions = [
		Vector2(size.x * 0.2, size.y * 0.3),
		Vector2(size.x * 0.8, size.y * 0.25),
		Vector2(size.x * 0.15, size.y * 0.7),
		Vector2(size.x * 0.85, size.y * 0.75)
	]
	
	for i in range(positions.size()):
		var pos = positions[i]
		
		# Floating animation
		var float_offset = sin(animation_phase * PI * 2 + i * PI * 0.5) * 3
		pos.y += float_offset
		
		# Draw hieroglyph (simplified as geometric shapes for now)
		_draw_hieroglyph_symbol(canvas, pos, symbol_color, i)

func _draw_hieroglyph_symbol(canvas: CanvasItem, pos: Vector2, color: Color, symbol_type: int) -> void:
	# Simplified geometric representations of hieroglyphs
	match symbol_type:
		0: # Eye symbol
			canvas.draw_circle(pos, 8, color)
			canvas.draw_circle(pos + Vector2(3, 0), 3, UIStyleManager.get_card_color("pyramid_obsidian"))
		1: # Bird symbol
			var wing_points = PackedVector2Array([
				pos + Vector2(-6, -3),
				pos + Vector2(6, -3),
				pos + Vector2(4, 3),
				pos + Vector2(-4, 3)
			])
			canvas.draw_colored_polygon(wing_points, color)
		2: # Ankh symbol
			canvas.draw_circle(pos + Vector2(0, -4), 3, color)
			canvas.draw_line(pos + Vector2(0, -1), pos + Vector2(0, 6), color, 2)
			canvas.draw_line(pos + Vector2(-3, 2), pos + Vector2(3, 2), color, 2)
		3: # Scarab symbol
			var scarab_points = PackedVector2Array([
				pos + Vector2(-4, -2),
				pos + Vector2(4, -2),
				pos + Vector2(6, 2),
				pos + Vector2(-6, 2)
			])
			canvas.draw_colored_polygon(scarab_points, color)

func _draw_decorative_border(canvas: CanvasItem, size: Vector2) -> void:
	var border_color = UIStyleManager.get_card_color("pyramid_gold")
	var border_width = 3.0
	
	# Draw 4 separate border lines
	# Top
	canvas.draw_line(Vector2(0, 0), Vector2(size.x, 0), border_color, border_width)
	# Right  
	canvas.draw_line(Vector2(size.x, 0), Vector2(size.x, size.y), border_color, border_width)
	# Bottom
	canvas.draw_line(Vector2(size.x, size.y), Vector2(0, size.y), border_color, border_width)
	# Left
	canvas.draw_line(Vector2(0, size.y), Vector2(0, 0), border_color, border_width)
	
	# Add corner triangles for decoration
	var corner_size = 12
	var corners = [
		Vector2(5, 5),                           # Top-left
		Vector2(size.x - 17, 5),                 # Top-right  
		Vector2(5, size.y - 17),                 # Bottom-left
		Vector2(size.x - 17, size.y - 17)       # Bottom-right
	]
	
	for corner in corners:
		_draw_corner_decoration(canvas, corner, corner_size, border_color)

func _draw_corner_decoration(canvas: CanvasItem, pos: Vector2, size: float, color: Color) -> void:
	# Simple pyramid corner decoration
	var center = pos + Vector2(size/2, size/2)
	var triangle_points = PackedVector2Array([
		center + Vector2(0, -size*0.3),
		center + Vector2(-size*0.3, size*0.2),
		center + Vector2(size*0.3, size*0.2)
	])
	
	canvas.draw_colored_polygon(triangle_points, color)
