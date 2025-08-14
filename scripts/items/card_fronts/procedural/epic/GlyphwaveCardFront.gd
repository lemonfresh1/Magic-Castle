# GlyphwaveCardFront.gd - Standard ranks with central neon pyramid and glyph halo
# Location: res://Pyramids/scripts/items/card_fronts/procedural/GlyphwaveCardFront.gd
# Last Updated: Created Glyphwave card front with animated pyramid [Date]

extends ProceduralCardFront

# Color palette
const DEEP_PURPLE = Color("#6A0DAD")
const GOLD = Color("#FFD700")
const OBSIDIAN_BLACK = Color("#000000")
const NEON_PURPLE = Color("#9933FF")
const SOFT_GOLD = Color("#FFD70044")

# Glyphs for subtle halo
const GLYPHS = ["☥", "𓂀", "⚛", "◈", "❂", "✦"]

func _init():
	item_id = "glyphwave_card_front"
	theme_name = "Glyphwave"
	display_name = "Glyphwave Card Front"
	item_rarity = UnifiedItemData.Rarity.EPIC
	is_animated = true
	animation_duration = 2.5
	
	# Override base colors
	card_bg_color = OBSIDIAN_BLACK
	card_border_color = DEEP_PURPLE
	rank_font_size = 26
	suit_font_size = 30

func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	# Draw glossy black obsidian background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), OBSIDIAN_BLACK)
	
	# Draw subtle gradient overlay for glossy effect
	_draw_glossy_overlay(canvas, size)
	
	# Draw central neon pyramid
	_draw_central_pyramid(canvas, size, suit)
	
	# Draw subtle glyph halo
	if is_animated:
		_draw_glyph_halo(canvas, size)
	
	# Draw rank and suit with gold/purple colors
	_draw_egyptian_rank_and_suit(canvas, size, rank, suit)
	
	# Draw soft pulsing glow on edges
	if is_animated and animation_phase > 0:
		_draw_edge_glow(canvas, size)

func _draw_glossy_overlay(canvas: CanvasItem, size: Vector2) -> void:
	# Create glossy effect with gradient
	var gradient_height = size.y * 0.3
	for i in range(int(gradient_height)):
		var alpha = (1.0 - float(i) / gradient_height) * 0.15
		var gradient_color = Color.WHITE
		gradient_color.a = alpha
		canvas.draw_line(Vector2(0, i), Vector2(size.x, i), gradient_color, 1.0)

func _draw_central_pyramid(canvas: CanvasItem, size: Vector2, suit: int) -> void:
	var center = size / 2
	var pyramid_size = 40.0
	
	# Calculate pyramid points
	var peak = center + Vector2(0, -pyramid_size * 0.6)
	var left = center + Vector2(-pyramid_size * 0.5, pyramid_size * 0.4)
	var right = center + Vector2(pyramid_size * 0.5, pyramid_size * 0.4)
	
	# Fill with semi-transparent purple
	var fill_color = DEEP_PURPLE
	fill_color.a = 0.2
	canvas.draw_colored_polygon(PackedVector2Array([peak, left, right]), fill_color)
	
	# Draw neon edges with suit-based color
	var edge_color = _get_suit_glow_color(suit)
	
	if is_animated:
		var pulse = sin(animation_phase * TAU / animation_duration)
		edge_color.a = 0.6 + pulse * 0.4
	else:
		edge_color.a = 0.8
	
	# Draw pyramid edges with glow
	for width in [3.0, 2.0, 1.0]:
		var glow_color = edge_color
		glow_color.a *= (1.0 / width)
		canvas.draw_line(peak, left, glow_color, width)
		canvas.draw_line(peak, right, glow_color, width)
		canvas.draw_line(left, right, glow_color, width * 0.7)
	
	# Draw energy beam from peak
	if is_animated:
		var beam_color = GOLD
		beam_color.a = 0.2 + sin(animation_phase * TAU / animation_duration) * 0.1
		canvas.draw_line(peak, Vector2(center.x, peak.y - 20), beam_color, 2.0)
	
	# Draw Eye of Horus or suit symbol at center
	_draw_pyramid_center_symbol(canvas, center, suit)

func _draw_pyramid_center_symbol(canvas: CanvasItem, center: Vector2, suit: int) -> void:
	var font = ThemeDB.fallback_font
	var symbol = _get_suit_symbol(suit)
	var symbol_color = GOLD
	symbol_color.a = 0.4
	
	# Draw symbol with glow
	for i in range(3):
		var layer_color = symbol_color
		layer_color.a *= (1.0 - i * 0.3)
		canvas.draw_string(font, center + Vector2(-8, 5), symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, 16 + i, layer_color)

func _draw_glyph_halo(canvas: CanvasItem, size: Vector2) -> void:
	var center = size / 2
	var radius = 60.0
	var num_glyphs = 6
	var font = ThemeDB.fallback_font
	
	for i in range(num_glyphs):
		var angle = (i * TAU / num_glyphs) + (animation_phase * 0.5)
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		
		var glyph = GLYPHS[i % GLYPHS.size()]
		var glyph_color = GOLD
		
		# Fade based on position
		var fade = (sin(angle + animation_phase) + 1.0) * 0.5
		glyph_color.a = 0.1 + fade * 0.2
		
		canvas.draw_string(font, pos - Vector2(6, -6), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, glyph_color)

func _draw_egyptian_rank_and_suit(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	var suit_symbol = _get_suit_symbol(suit)
	var color = _get_suit_glow_color(suit)
	var font = ThemeDB.fallback_font
	
	# Top-left rank and suit with glow effect
	for i in range(2):
		var glow_color = color if i == 0 else GOLD
		glow_color.a = 0.3 if i == 0 else 1.0
		var offset = Vector2(2, 2) * i
		
		canvas.draw_string(font, Vector2(8, 24) - offset, rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, glow_color)
		canvas.draw_string(font, Vector2(8, 48) - offset, suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, glow_color)
	
	# Bottom-right rank and suit (rotated)
	canvas.draw_set_transform(Vector2(size.x - 8, size.y - 8), PI, Vector2.ONE)
	for i in range(2):
		var glow_color = color if i == 0 else GOLD
		glow_color.a = 0.3 if i == 0 else 1.0
		var offset = Vector2(2, 2) * i
		
		canvas.draw_string(font, Vector2(0, 24) - offset, rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, glow_color)
		canvas.draw_string(font, Vector2(0, 48) - offset, suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, glow_color)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Draw pips for number cards
	if rank not in ["A", "J", "Q", "K"]:
		_draw_egyptian_pips(canvas, size, rank, suit_symbol, color)

func _draw_egyptian_pips(canvas: CanvasItem, size: Vector2, rank: String, suit_symbol: String, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var pip_size = 18
	var rank_num = rank.to_int()
	
	if rank_num == 0:
		return
	
	# Get standard pip positions
	#var positions = _get_pip_positions(rank_num, size)
	#
	## Draw pips with Egyptian styling
	#for pos in positions:
		## Draw pip with mini glow
		#for i in range(2):
			#var pip_color = color
			#pip_color.a = 0.5 if i == 0 else 1.0
			#var pip_offset = Vector2(1, 1) * i
			#canvas.draw_string(font, pos - pip_offset, suit_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, pip_size - i * 2, pip_color)

func _draw_edge_glow(canvas: CanvasItem, size: Vector2) -> void:
	var shimmer_intensity = (sin(animation_phase * TAU / animation_duration) + 1.0) * 0.5
	
	if shimmer_intensity > 0.5:
		var glow_color = GOLD
		glow_color.a = (shimmer_intensity - 0.5) * 0.3
		
		# Draw soft edge glow
		var glow_width = 2.0
		for i in range(3):
			var edge_color = glow_color
			edge_color.a *= (1.0 - i * 0.3)
			var inset = i * 1.0
			var rect = Rect2(inset, inset, size.x - inset * 2, size.y - inset * 2)
			canvas.draw_rect(rect, edge_color, false, glow_width - i * 0.5)

func _get_suit_glow_color(suit: int) -> Color:
	# Purple for spades/clubs, gold for hearts/diamonds
	match suit:
		0, 2:  # Spades, Clubs
			return NEON_PURPLE
		1, 3:  # Hearts, Diamonds
			return GOLD
		_:
			return NEON_PURPLE
