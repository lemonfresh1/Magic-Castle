# ForestSpiritsCardFront.gd - Standard indices + subtle corner runes, stone/vine accents, silver edge glints
# Location: res://Pyramids/scripts/items/card_fronts/procedural/ForestSpiritsCardFront.gd

extends ProceduralCardFront

# --- Palette (all literals so they're valid consts) ---
const EMERALD: Color = Color("#1f7a5a")
const MOSS: Color = Color("#556b2f")
const SILVER: Color = Color("#c0c0c0")
var STONE: Color = Color.BLACK # set in _init() using non-const ops

# --- Animation/style knobs (from your metadata) ---
var RUNE_GLOW_INTENSITY: float = 0.4
var RUNE_PULSE_SPEED: float = 0.30
var MOTE_DENSITY: float = 0.20
var MOTE_DRIFT_SPEED: float = 0.20
var READABILITY_BIAS: float = 0.85 # keep indices crisp

# Subtle corner runes & motes
var _corner_runes: Array = ["ᚠ","ᚨ","ᚱ","ᚲ"]
var _motes: Array = []  # each = {p:Vector2, v:Vector2, r:float, a:float, ph:float}

func _init() -> void:
	item_id = "forest_spirits_front"
	theme_name = "Forest Spirits"
	display_name = "Forest Spirits"
	item_rarity = UnifiedItemData.Rarity.EPIC
	is_animated = true
	animation_duration = 2.6

	# Non-const color math goes here
	STONE = MOSS.darkened(0.20)

	# Base look
	card_bg_color = EMERALD.darkened(0.22)
	card_border_color = STONE
	card_border_width = 2
	card_corner_radius = 6
	rank_font_size = 26
	suit_font_size = 30
	rank_position_offset = Vector2(8, 10)
	suit_position_offset = Vector2(8, 36)

	_init_motes()

func _init_motes() -> void:
	var count: int = int(8 + 18.0 * MOTE_DENSITY)
	_motes.clear()
	for i in count:
		_motes.append({
			"p": Vector2(randf() * CARD_WIDTH, randf() * CARD_HEIGHT),
			"v": Vector2(randf_range(-7.0, 7.0), randf_range(-10.0, -4.0)) * MOTE_DRIFT_SPEED,
			"r": randf_range(0.6, 1.4),
			"a": randf_range(0.10, 0.24),
			"ph": randf() * TAU
		})

func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	# Background (emerald→moss)
	_draw_bg(canvas, size)
	# Simple border (sharp corners)
	_draw_simple_border(canvas, size)
	# Minimal vine filigree accents
	_draw_vine_accents(canvas, size)
	# Subtle silver corner runes
	_draw_corner_runes(canvas, size)
	# Edge glints (cool silver)
	_draw_edge_glints(canvas, size)
	# Floating motes
	if is_animated:
		_update_and_draw_motes(canvas, size)
	# Standard readable indices (with soft silver back-glow)
	_draw_rank_and_suit_readable(canvas, size, rank, suit)

# --- Drawing helpers ---

func _draw_bg(canvas: CanvasItem, size: Vector2) -> void:
	var h: int = int(size.y)
	for y in h:
		var t: float = float(y) / max(1.0, float(h - 1))
		var c: Color = EMERALD.lerp(MOSS, t).darkened(0.03)
		canvas.draw_line(Vector2(0, float(y)), Vector2(size.x, float(y)), c, 1.0)

func _draw_simple_border(canvas: CanvasItem, size: Vector2) -> void:
	var c: Color = STONE
	canvas.draw_rect(Rect2(0, 0, size.x, 1), c)
	canvas.draw_rect(Rect2(0, size.y - 1, size.x, 1), c)
	canvas.draw_rect(Rect2(0, 0, 1, size.y), c)
	canvas.draw_rect(Rect2(size.x - 1, 0, 1, size.y), c)

func _draw_vine_accents(canvas: CanvasItem, size: Vector2) -> void:
	var vine: Color = EMERALD.lightened(0.05)
	vine.a = 0.6
	# two minimal curls on left/right
	_draw_vine_curve(canvas, Vector2(10, size.y * 0.25), Vector2(size.x * 0.20, size.y * 0.35), Vector2(18, -26), vine)
	_draw_vine_curve(canvas, Vector2(size.x - 10, size.y * 0.70), Vector2(size.x * 0.80, size.y * 0.60), Vector2(-18, 22), vine)
	# tiny silver leaf glints
	var s: Color = SILVER
	s.a = 0.25
	for i in 6:
		if randf() < 0.35:
			var p: Vector2 = Vector2(randf() * size.x, randf() * size.y)
			canvas.draw_line(p - Vector2(0.8, 0), p + Vector2(0.8, 0), s, 1.0)

func _draw_vine_curve(canvas: CanvasItem, a: Vector2, b: Vector2, ctrl_delta: Vector2, col: Color) -> void:
	var ctrl: Vector2 = (a + b) * 0.5 + ctrl_delta
	var seg: int = 22
	var last: Vector2 = a
	for i in range(1, seg + 1):
		var t: float = float(i) / float(seg)
		var p: Vector2 = (1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * ctrl + t * t * b
		canvas.draw_line(last, p, col, 1.5)
		last = p

func _draw_corner_runes(canvas: CanvasItem, size: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var corners := [
		{"pos": Vector2(6, 6), "rot": 0.0, "idx": 0},
		{"pos": Vector2(size.x - 6, 6), "rot": PI * 0.5, "idx": 1},
		{"pos": Vector2(size.x - 6, size.y - 6), "rot": PI, "idx": 2},
		{"pos": Vector2(6, size.y - 6), "rot": -PI * 0.5, "idx": 3}
	]
	for c in corners:
		var base: Color = SILVER
		var pulse: float = 1.0
		if is_animated:
			pulse = 0.65 + 0.35 * sin(animation_phase * TAU * RUNE_PULSE_SPEED + float(c.idx))
		base.a = RUNE_GLOW_INTENSITY * 0.45 * pulse
		canvas.draw_set_transform(c.pos, c.rot, Vector2.ONE)
		var rune_char: String = String(_corner_runes[c.idx])
		canvas.draw_string(font, Vector2.ZERO, rune_char, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, base.darkened(0.25))
		canvas.draw_string(font, Vector2(-1, 1), rune_char, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, base)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_edge_glints(canvas: CanvasItem, size: Vector2) -> void:
	var t: float = 0.6
	if is_animated:
		t = (sin(animation_phase * TAU * 0.2) + 1.0) * 0.5
	var c: Color = SILVER
	c.a = 0.18 + 0.12 * t
	var inset: float = 2.0
	canvas.draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0), c, false, 1.2)

func _update_and_draw_motes(canvas: CanvasItem, size: Vector2) -> void:
	for m in _motes:
		m.p += m.v * (1.0 / 60.0)
		if m.p.x < -6.0:
			m.p.x = size.x + 6.0
		elif m.p.x > size.x + 6.0:
			m.p.x = -6.0
		if m.p.y < -6.0:
			m.p.y = size.y + 6.0
			m.v = Vector2(randf_range(-7.0, 7.0), randf_range(-10.0, -4.0)) * MOTE_DRIFT_SPEED
		var a: float = m.a * (0.55 + 0.45 * sin(animation_phase + m.ph))
		var c: Color = SILVER
		c.a = a
		canvas.draw_circle(m.p, m.r, c)

func _draw_rank_and_suit_readable(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var suit_symbol: String = _get_suit_symbol(suit)
	var suit_col: Color = get_suit_color(suit)

	# Soft silver back-glow
	var glow: Color = SILVER
	glow.a = 0.28 * READABILITY_BIAS

	# Top-left (glow then text)
	canvas.draw_string(font, Vector2(rank_position_offset.x + 1, rank_position_offset.y + 1), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, glow)
	canvas.draw_string(font, Vector2(suit_position_offset.x + 1, suit_position_offset.y + 1), suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, glow)
	canvas.draw_string(font, rank_position_offset, rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, suit_col)
	canvas.draw_string(font, suit_position_offset, suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, suit_col)

	# Bottom-right (rotated 180°)
	canvas.draw_set_transform(Vector2(size.x - 8, size.y - 8), PI, Vector2.ONE)
	canvas.draw_string(font, Vector2(1, 1), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, glow)
	canvas.draw_string(font, Vector2(1, 25), suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, glow)
	canvas.draw_string(font, Vector2(0, 0), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, suit_col)
	canvas.draw_string(font, Vector2(0, 24), suit_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, suit_col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
