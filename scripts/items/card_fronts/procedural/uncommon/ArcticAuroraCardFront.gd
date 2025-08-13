# ArcticAuroraCardFront.gd - Minimal arctic-themed card front with snowflake emboss
# Location: res://Pyramids/scripts/items/card_fronts/procedural/uncommon/ArcticAuroraCardFront.gd
# Last Updated: Created Arctic Aurora card front [Date]

extends ProceduralCardFront

# Arctic Aurora color palette
const COLOR_ICE_BLUE = Color("#AEE4FF")
const COLOR_EMERALD = Color("#2ECC71")
const COLOR_MAGENTA = Color("#D946EF")
const COLOR_SNOW_WHITE = Color("#F8F9FA")
const COLOR_FROST = Color("#E3F2FD")

func _init():
	theme_name = "Arctic Aurora"
	item_id = "arctic_aurora_front"
	display_name = "Arctic Aurora Card Front"
	item_rarity = UnifiedItemData.Rarity.UNCOMMON
	is_animated = true
	animation_duration = 4.0
	animation_elements = ["aurora_gradient", "shimmer"]

func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:	
	# Quick test - draw a simple colored rect to verify drawing works
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color.RED * 0.2)
# White base with subtle gradient
	_draw_background(canvas, size)
	
	# Faint snowflake watermark in center
	_draw_snowflake_emboss(canvas, size)
	
	# Aurora gradient overlay (very subtle)
	_draw_aurora_tint(canvas, size)
	
	# Clean thin border
	_draw_border(canvas, size)
	
	# Draw rank and suit with aurora colors
	_draw_rank_and_suit(canvas, size, rank, suit)

func _draw_background(canvas: CanvasItem, size: Vector2) -> void:
	# White base with very subtle blue gradient
	var gradient_rect = Rect2(Vector2.ZERO, size)
	
	# Create gradient from white to very light ice blue
	for i in range(10):
		var t = i / 10.0
		var color = COLOR_SNOW_WHITE.lerp(COLOR_ICE_BLUE * 0.15, t * 0.3)
		var rect = Rect2(0, size.y * i / 10, size.x, size.y / 10)
		canvas.draw_rect(rect, color)

func _draw_snowflake_emboss(canvas: CanvasItem, size: Vector2) -> void:
	# Draw a faint snowflake pattern in the center
	var center = size / 2
	var snowflake_size = min(size.x, size.y) * 0.4
	var emboss_color = COLOR_ICE_BLUE * Color(1, 1, 1, 0.08)  # Very faint
	
	# Six-pointed snowflake
	for i in range(6):
		var angle = (i * PI / 3) + (animation_phase * 0.1)  # Subtle rotation
		var end_point = center + Vector2(cos(angle), sin(angle)) * snowflake_size
		
		# Main branch
		canvas.draw_line(center, end_point, emboss_color, 2.0)
		
		# Side branches
		var branch_count = 3
		for j in range(1, branch_count + 1):
			var branch_pos = center.lerp(end_point, j / float(branch_count + 1))
			var branch_length = snowflake_size * 0.2 * (1.0 - j / float(branch_count + 1))
			
			# Two side branches at 45-degree angles
			var branch_angle1 = angle + PI / 6
			var branch_angle2 = angle - PI / 6
			
			var branch_end1 = branch_pos + Vector2(cos(branch_angle1), sin(branch_angle1)) * branch_length
			var branch_end2 = branch_pos + Vector2(cos(branch_angle2), sin(branch_angle2)) * branch_length
			
			canvas.draw_line(branch_pos, branch_end1, emboss_color, 1.0)
			canvas.draw_line(branch_pos, branch_end2, emboss_color, 1.0)
	
	# Central hexagon
	var hex_points = PackedVector2Array()
	for i in range(6):
		var angle = (i * PI / 3) + (animation_phase * 0.1)
		hex_points.append(center + Vector2(cos(angle), sin(angle)) * snowflake_size * 0.15)
	hex_points.append(hex_points[0])  # Close the hexagon
	
	for i in range(hex_points.size() - 1):
		canvas.draw_line(hex_points[i], hex_points[i + 1], emboss_color, 1.5)

func _draw_aurora_tint(canvas: CanvasItem, size: Vector2) -> void:
	# Very subtle aurora gradient overlay
	var wave_height = size.y * 0.3
	var wave_offset = sin(animation_phase * TAU) * 20
	
	# Top aurora band (emerald)
	var top_points = PackedVector2Array()
	for i in range(20):
		var x = (i / 19.0) * size.x
		var y = wave_height + sin((x / size.x) * TAU * 2 + animation_phase * TAU) * 15 + wave_offset
		top_points.append(Vector2(x, y))
	
	# Complete the polygon
	top_points.append(Vector2(size.x, 0))
	top_points.append(Vector2(0, 0))
	
	canvas.draw_colored_polygon(top_points, COLOR_EMERALD * Color(1, 1, 1, 0.03))
	
	# Bottom aurora band (magenta)
	var bottom_points = PackedVector2Array()
	for i in range(20):
		var x = (i / 19.0) * size.x
		var y = size.y - wave_height + sin((x / size.x) * TAU * 2 - animation_phase * TAU) * 15 - wave_offset
		bottom_points.append(Vector2(x, y))
	
	# Complete the polygon
	bottom_points.append(Vector2(size.x, size.y))
	bottom_points.append(Vector2(0, size.y))
	
	canvas.draw_colored_polygon(bottom_points, COLOR_MAGENTA * Color(1, 1, 1, 0.03))

func _draw_border(canvas: CanvasItem, size: Vector2) -> void:
	# Clean thin border with shimmer effect
	var border_color = COLOR_ICE_BLUE.lerp(COLOR_SNOW_WHITE, 0.5 + sin(animation_phase * TAU) * 0.3)
	border_color.a = 0.6
	
	var border_rect = Rect2(Vector2.ONE, size - Vector2.ONE * 2)
	canvas.draw_rect(border_rect, Color.TRANSPARENT, false, 2.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)

func _draw_rank_and_suit(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	var suit_symbol = _get_suit_symbol(suit)
	
	# Use aurora colors for suits
	var suit_color = get_suit_color(suit)
	if suit == 0 or suit == 2:  # Spades and Clubs
		suit_color = COLOR_EMERALD.darkened(0.3)
	else:  # Hearts and Diamonds
		suit_color = COLOR_MAGENTA.darkened(0.2)
	
	var font = ThemeDB.fallback_font
	var rank_size = 36
	var suit_size = 40
	
	# Top-left rank and suit
	canvas.draw_string(font, Vector2(12, 35), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, suit_color)
	canvas.draw_string(font, Vector2(12, 75), suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_size, suit_color)
	
	# Bottom-right (rotated)
	canvas.draw_set_transform(Vector2(size.x - 12, size.y - 35), PI, Vector2.ONE)
	canvas.draw_string(font, Vector2.ZERO, rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, suit_color)
	canvas.draw_set_transform(Vector2(size.x - 12, size.y - 75), PI, Vector2.ONE)
	canvas.draw_string(font, Vector2.ZERO, suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_size, suit_color)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _get_suit_symbol(suit: int) -> String:
	match suit:
		0: return "♠"  # Spades
		1: return "♥"  # Hearts
		2: return "♣"  # Clubs
		3: return "♦"  # Diamonds
		_: return "?"
