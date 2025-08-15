# ForestSpiritsBoard.gd - Procedural altar scene with vines, runes, and glowing motes
extends ProceduralBoard

# Palette (emerald/moss + cool silver)
const EMERALD := Color("#1f7a5a")
const MOSS := Color("#556b2f")
const SILVER := Color("#c0c0c0")
const SHADOW := Color(0, 0, 0, 0.35)

# Rune set (simple angular marks; carved-look)
const RUNES := ["ᚠ","ᚢ","ᚦ","ᚨ","ᚱ","ᚲ","ᚷ","ᚺ","ᚾ","ᛁ","ᛃ","ᛇ"]

# Animation/style knobs from metadata
var RUNE_GLOW_INTENSITY := 0.6
var RUNE_PULSE_SPEED := 0.35
var MOTE_DENSITY := 0.4       # ~40% of BOARD_WIDTH/HEIGHT scaled
var MOTE_DRIFT_SPEED := 0.25
var HIGHLIGHT_SHIMMER_RATE := 0.2

var _motes: Array = []        # {pos, vel, radius, alpha, phase}
var _rune_grid: Array = []    # {pos, char, angle}

func _init() -> void:
	item_id = "forest_spirits_board"
	theme_name = "Forest Spirits"
	display_name = "Spirit Altar Board"
	item_rarity = UnifiedItemData.Rarity.EPIC
	is_animated = true
	animation_duration = 3.0
	board_bg_color = EMERALD.darkened(0.35)
	_init_motes()
	_init_runes()

func _init_motes() -> void:
	var count: int = int(12 + (BOARD_WIDTH * BOARD_HEIGHT) / 48000.0 * MOTE_DENSITY * 40.0)
	for i in range(count):
		_motes.append({
			"pos": Vector2(randf() * BOARD_WIDTH, randf() * BOARD_HEIGHT),
			"vel": Vector2(randf_range(-10, 10), randf_range(-15, -6)) * MOTE_DRIFT_SPEED,
			"radius": randf_range(1.0, 2.2),
			"alpha": randf_range(0.15, 0.35),
			"phase": randf() * TAU
		})

func _init_runes() -> void:
	# Scatter subtle carved runes roughly on the altar platform area
	for y in range(4):
		for x in range(8):
			_rune_grid.append({
				"pos": Vector2(BOARD_WIDTH * (0.22 + x * 0.08 + randf()*0.01),
							   BOARD_HEIGHT * (0.48 + y * 0.045 + randf()*0.01)),
				"char": RUNES[randi() % RUNES.size()],
				"angle": randf_range(-0.25, 0.25)
			})

func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Background: deep forest gradient (emerald→moss)
	_draw_forest_gradient(canvas, size)
	# Subtle ruin fragments
	_draw_ruin_fragments(canvas, size)
	# Central altar platform (stone)
	_draw_altar(canvas, size)
	# Vines creeping from corners/edges
	_draw_vines(canvas, size)
	# Carved runes with pulsing silver glow
	_draw_runes(canvas)
	# Floating motes (glowing dust)
	if is_animated:
		_update_and_draw_motes(canvas, size)
	# Cool silver edge shimmer
	if is_animated:
		_draw_silver_shimmer(canvas, size)

func _draw_forest_gradient(canvas: CanvasItem, size: Vector2) -> void:
	for y in range(int(size.y)):
		var t: float = float(y) / max(1.0, size.y - 1.0)
		var c: Color = EMERALD.lerp(MOSS, t).darkened(0.05)
		canvas.draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)

func _draw_ruin_fragments(canvas: CanvasItem, size: Vector2) -> void:
	var n: int = 20
	for i in range(n):
		var p: Vector2 = Vector2(randf()*size.x, size.y*randf_range(0.62, 0.95))
		var w: float = randf_range(3, 10)
		var h: float = randf_range(2, 6)
		var stone: Color = MOSS.lightened(0.15)
		stone.a = 0.25
		canvas.draw_rect(Rect2(p, Vector2(w, h)), stone)

func _draw_altar(canvas: CanvasItem, size: Vector2) -> void:
	var center: Vector2 = size / 2.0
	var plat_w: float = size.x * 0.64
	var plat_h: float = size.y * 0.18
	# Shadow/ground
	canvas.draw_rect(Rect2(Vector2(center.x - plat_w*0.55, center.y + plat_h*0.35),
		Vector2(plat_w*1.1, plat_h*0.35)), SHADOW)
	# Main stone platform (rounded pill)
	var stone_top: Color = MOSS.lightened(0.05)
	var stone_side: Color = MOSS.darkened(0.2)
	var r: float = 16.0
	# Top slab
	_draw_round_rect(canvas, Rect2(center.x - plat_w/2, center.y - plat_h/2, plat_w, plat_h), r, stone_top)
	# Front face
	var face := Rect2(center.x - plat_w/2, center.y + plat_h/2 - 3, plat_w, plat_h*0.45)
	_draw_round_rect(canvas, face, r*0.6, stone_side)
	# Steps (subtle)
	for s in range(3):
		var w: float = plat_w * (0.86 - s*0.08)
		var h: float = 6.0
		var y: float = center.y + plat_h*0.5 + s*7.0
		var c: Color = stone_side.lightened(0.05 * s)
		canvas.draw_rect(Rect2(Vector2(center.x - w/2, y), Vector2(w, h)), c)

func _draw_vines(canvas: CanvasItem, size: Vector2) -> void:
	# Four creeping arcs; silver highlights sparkle slightly
	var vine: Color = EMERALD.darkened(0.15)
	vine.a = 0.7
	var accent: Color = SILVER
	var anim_factor: float = (0.5 + 0.5 * sin(animation_phase * TAU * HIGHLIGHT_SHIMMER_RATE)) if is_animated else 0.0
	accent.a = 0.35 + 0.25 * anim_factor
	# Top-left to altar
	_draw_vine_arc(canvas, Vector2(18, 18), Vector2(size.x*0.3, size.y*0.42), vine, 2.2)
	# Top-right to altar
	_draw_vine_arc(canvas, Vector2(size.x-18, 22), Vector2(size.x*0.7, size.y*0.4), vine, 2.2)
	# Bottom-left
	_draw_vine_arc(canvas, Vector2(22, size.y-20), Vector2(size.x*0.34, size.y*0.66), vine, 2.6)
	# Bottom-right
	_draw_vine_arc(canvas, Vector2(size.x-24, size.y-22), Vector2(size.x*0.66, size.y*0.68), vine, 2.6)
	# Little silver glints along vines
	for i in range(14):
		var p := Vector2(randf()*size.x, randf()*size.y)
		if randf() < 0.35:
			canvas.draw_line(p - Vector2(1,0), p + Vector2(1,0), accent, 1.0)

func _draw_vine_arc(canvas: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var segments: int = 32
	var last: Vector2 = a
	var ctrl: Vector2 = Vector2((a.x + b.x)/2.0, min(a.y, b.y) - 40.0)
	for i in range(1, segments + 1):
		var t: float = float(i)/segments
		var p: Vector2 = (1.0 - t)*(1.0 - t)*a + 2.0*(1.0 - t)*t*ctrl + t*t*b
		canvas.draw_line(last, p, col, width)
		last = p

func _draw_runes(canvas: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	for r in _rune_grid:
		var base: Color = SILVER
		var pulse: float = 1.0
		if is_animated:
			pulse = 0.65 + 0.35 * sin(animation_phase * TAU * RUNE_PULSE_SPEED + r.angle)
		base.a = RUNE_GLOW_INTENSITY * 0.35 * pulse
		canvas.draw_set_transform(r.pos, r.angle, Vector2.ONE)
		# faint engraved groove
		canvas.draw_string(font, Vector2.ZERO, r.char, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, base.darkened(0.35))
		# soft glow overlay
		var glow: Color = base.lightened(0.2); glow.a *= 0.7
		canvas.draw_string(font, Vector2(-1,1), r.char, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, glow)
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _update_and_draw_motes(canvas: CanvasItem, size: Vector2) -> void:
	for m in _motes:
		m.pos += m.vel * (1.0/60.0)
		if m.pos.x < -10: m.pos.x = size.x + 10
		if m.pos.x > size.x + 10: m.pos.x = -10
		if m.pos.y < -10:
			m.pos.y = size.y + 10
			m.vel = Vector2(randf_range(-10, 10), randf_range(-15, -6)) * MOTE_DRIFT_SPEED
		var a: float = m.alpha * (0.6 + 0.4 * sin(animation_phase * TAU + m.phase))
		var c: Color = SILVER; c.a = a
		canvas.draw_circle(m.pos, m.radius, c)

func _draw_silver_shimmer(canvas: CanvasItem, size: Vector2) -> void:
	var t: float = (sin(animation_phase * TAU * HIGHLIGHT_SHIMMER_RATE) + 1.0) * 0.5
	if t > 0.55:
		var c: Color = SILVER; c.a = (t - 0.55) * 0.6
		canvas.draw_rect(Rect2(0, 0, size.x, 2), c)
		canvas.draw_rect(Rect2(0, size.y - 2, size.x, 2), c)
		canvas.draw_rect(Rect2(0, 0, 2, size.y), c)
		canvas.draw_rect(Rect2(size.x - 2, 0, 2, size.y), c)

func _draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	# Simple rounded rectangle using two orthogonal cores + 4 quarter circles
	# Horizontal core
	var core_h := Rect2(rect.position + Vector2(radius, 0), rect.size - Vector2(radius*2.0, 0))
	canvas.draw_rect(core_h, color)
	# Vertical core
	var core_v := Rect2(rect.position + Vector2(0, radius), rect.size - Vector2(0, radius*2.0))
	canvas.draw_rect(core_v, color)
	# Corners
	var tl := rect.position + Vector2(radius, radius)
	var tr := rect.position + Vector2(rect.size.x - radius, radius)
	var br := rect.position + Vector2(rect.size.x - radius, rect.size.y - radius)
	var bl := rect.position + Vector2(radius, rect.size.y - radius)
	canvas.draw_circle(tl, radius, color)
	canvas.draw_circle(tr, radius, color)
	canvas.draw_circle(br, radius, color)
	canvas.draw_circle(bl, radius, color)
