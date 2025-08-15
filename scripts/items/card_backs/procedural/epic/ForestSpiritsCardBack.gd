# ForestSpiritsCardBack.gd - Carved stone frame, sharp corners, single central glowing rune
extends ProceduralCardBack

const EMERALD := Color("#1f7a5a")
const MOSS := Color("#556b2f")
const SILVER := Color("#c0c0c0")
var STONE: Color = Color(0,0,0) # set in _init
const SOFT_SILVER := Color(0.75, 0.75, 0.75, 0.18)

var CENTER_RUNE_GLOW_INTENSITY := 0.55
var CENTER_RUNE_PULSE_SPEED := 0.32
var MOTE_DENSITY := 0.25
var MOTE_DRIFT_SPEED := 0.22
var FRAME_SHIMMER_RATE := 0.18

var _motes: Array = []

func _init() -> void:
	item_id = "forest_spirits_back"
	theme_name = "Forest Spirits"
	display_name = "Forest Spirits"
	item_rarity = UnifiedItemData.Rarity.EPIC
	is_animated = true
	animation_duration = 2.8
	card_bg_color = EMERALD.darkened(0.25)
	STONE = MOSS.darkened(0.15)
	card_border_color = STONE
	_init_motes()

func _init_motes() -> void:
	var count: int = int(10 + 20 * MOTE_DENSITY)
	for i in range(count):
		_motes.append({
			"p": Vector2(randf()*CARD_WIDTH, randf()*CARD_HEIGHT),
			"v": Vector2(randf_range(-8, 8), randf_range(-12, -5)) * MOTE_DRIFT_SPEED,
			"r": randf_range(0.8, 1.8),
			"a": randf_range(0.12, 0.28),
			"ph": randf() * TAU
		})

func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	_draw_bg_gradient(canvas, size)
	_draw_carved_frame(canvas, size)
	_draw_center_rune(canvas, size)
	if is_animated:
		_update_and_draw_motes(canvas, size)
		_draw_frame_shimmer(canvas, size)

func _draw_bg_gradient(canvas: CanvasItem, size: Vector2) -> void:
	for y in range(int(size.y)):
		var t: float = float(y) / max(1.0, size.y - 1.0)
		var c: Color = EMERALD.lerp(MOSS, t).darkened(0.02)
		canvas.draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)

func _draw_carved_frame(canvas: CanvasItem, size: Vector2) -> void:
	var w: float = 10.0
	# Simple carved frame with sharp corners (no rounding)
	var face: Color = STONE
	canvas.draw_rect(Rect2(0, 0, size.x, w), face)
	canvas.draw_rect(Rect2(0, size.y - w, size.x, w), face)
	canvas.draw_rect(Rect2(0, 0, w, size.y), face)
	canvas.draw_rect(Rect2(size.x - w, 0, w, size.y), face)
	# Carved grooves inside the frame
	var groove: Color = SILVER
	groove.a = 0.22
	canvas.draw_rect(Rect2(w+2, w+2, size.x - (w+2)*2, 1), groove)
	canvas.draw_rect(Rect2(w+2, size.y - w - 3, size.x - (w+2)*2, 1), groove)
	canvas.draw_rect(Rect2(w+2, w+2, 1, size.y - (w+2)*2), groove)
	canvas.draw_rect(Rect2(size.x - w - 3, w+2, 1, size.y - (w+2)*2), groove)

func _draw_center_rune(canvas: CanvasItem, size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var center: Vector2 = size / 2.0
	var rune := "ᚱ" # single central rune
	# Stone medallion
	var plate: Color = STONE.lightened(0.05)
	canvas.draw_circle(center + Vector2(2, 3), 20, Color(0,0,0,0.2))
	canvas.draw_circle(center, 20, plate)
	# Glow pulse
	var glow: Color = SILVER
	if is_animated:
		var p: float = (sin(animation_phase * TAU * CENTER_RUNE_PULSE_SPEED) + 1.0) * 0.5
		glow.a = CENTER_RUNE_GLOW_INTENSITY * (0.45 + 0.55 * p)
	else:
		glow.a = CENTER_RUNE_GLOW_INTENSITY * 0.6
	# Glow rings
	for i in range(3):
		var rr: float = 20 + i * 6
		var c: Color = glow
		c.a *= (0.5 - i * 0.15)
		canvas.draw_circle(center, rr, c)
	# Rune itself
	canvas.draw_string(font, center - Vector2(7, -8), rune, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, glow.lightened(0.1))

func _update_and_draw_motes(canvas: CanvasItem, size: Vector2) -> void:
	for m in _motes:
		m.p += m.v * (1.0/60.0)
		if m.p.x < -8: m.p.x = size.x + 8
		if m.p.x > size.x + 8: m.p.x = -8
		if m.p.y < -8:
			m.p.y = size.y + 8
			m.v = Vector2(randf_range(-8, 8), randf_range(-12, -5)) * MOTE_DRIFT_SPEED
		var a: float = m.a * (0.6 + 0.4 * sin(animation_phase + m.ph))
		var c: Color = SOFT_SILVER; c.a = a
		canvas.draw_circle(m.p, m.r, c)

func _draw_frame_shimmer(canvas: CanvasItem, size: Vector2) -> void:
	var t: float = (sin(animation_phase * TAU * FRAME_SHIMMER_RATE) + 1.0) * 0.5
	if t > 0.55:
		var c: Color = SILVER; c.a = (t - 0.55) * 0.5
		var inset: float = 2.0
		canvas.draw_rect(Rect2(inset, inset, size.x - inset*2.0, size.y - inset*2.0), c, false, 1.5)
