class_name GameOverlay
extends Control
## Full-view overlays drawn over the world: the level's title card, the
## bullet-time vignette, the boss entrance warning, the death flash and the
## "wasted" / "level cleared" screens.
##
## Drawn in the web version's 960x540 canvas units, scaled to the view. The
## animations here are presentation only and run on real time.

const CANVAS_WIDTH: float = GameConstants.CANVAS_WIDTH
const CANVAS_HEIGHT: float = GameConstants.CANVAS_HEIGHT
const BAND_HEIGHT: float = 40.0
## Ticks the screen flashes white when the player dies.
const DEATH_FLASH_TICKS: int = 5

## The result screens darken the view over this long, their title lands
## over [constant TITLE_LAND_SEC], and each further line follows a beat later.
const DIM_SEC: float = 0.25
const TITLE_LAND_SEC: float = 0.32
const TITLE_FROM_SCALE: float = 1.7
const LINE_DELAY_SEC: float = 0.28
const LINE_STAGGER_SEC: float = 0.12
const LINE_FADE_SEC: float = 0.2

## The title card fades in, holds and fades out when a level starts.
const CARD_IN_SEC: float = 0.25
const CARD_HOLD_SEC: float = 1.3
const CARD_OUT_SEC: float = 0.5
const CARD_Y: float = 150.0

const VIGNETTE_COLOR: Color = Palette.SKY_400
const VIGNETTE_DEPTH: float = 150.0
const VIGNETTE_STRENGTH: float = 0.2

var sim: GameSim
## Lines shown under "level cleared", e.g. how to continue.
var win_lines: PackedStringArray = PackedStringArray()
## Line shown under "wasted".
var retry_line: String = ""
## 0 at normal speed, 1 in full bullet time.
var slow_amount: float = 0.0

var _card_title: String = ""
var _card_subtitle: String = ""
var _card_color: Color = Palette.WHITE
var _card_age: float = INF
## Seconds the current result screen has been up.
var _won_age: float = 0.0
var _dead_age: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Announces the level: [param title] with [param subtitle] under it.
func show_title_card(title: String, subtitle: String, color: Color) -> void:
	_card_title = title
	_card_subtitle = subtitle
	_card_color = color
	_card_age = 0.0


func _process(delta: float) -> void:
	if sim != null:
		_won_age = _won_age + delta if sim.player.won else 0.0
		_dead_age = _dead_age + delta if sim.player.dead else 0.0
	_card_age += delta
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var s: float = size.x / CANVAS_WIDTH
	var p: Painter = Painter.new(self, s)
	p.scale(s, s)
	var t: float = float(Time.get_ticks_msec())

	if slow_amount > 0.01:
		_draw_vignette(p)

	# Only the entrance that opens the fight gets the full-screen warning.
	var boss_entrance: bool = (
		sim.boss.active and sim.boss.state == BossState.State.INTRO
		and sim.boss.intro_freezes_player
	)
	if boss_entrance:
		_draw_boss_intro(p, t)

	var player: PlayerState = sim.player
	if player.won:
		_draw_result(p, _won_age, "LEVEL CLEARED!", Palette.EMERALD_500, Color(0.0, 0.0, 0.0, 0.7), win_lines)
	elif player.dead:
		if sim.death_timer < DEATH_FLASH_TICKS:
			p.fill_rect(0.0, 0.0, CANVAS_WIDTH, CANVAS_HEIGHT, Color(1.0, 1.0, 1.0, 0.85))
		else:
			_draw_result(
				p, _dead_age - float(DEATH_FLASH_TICKS) / float(GameConstants.TICKS_PER_SECOND),
				"WASTED", Palette.RED_500, Color(Palette.SLATE_900, 0.4),
				PackedStringArray([retry_line])
			)
	elif not boss_entrance:
		_draw_title_card(p)


## A result screen: the view dims, the title lands, the lines follow.
func _draw_result(
	p: Painter, age: float, title: String, title_color: Color, dim: Color, lines: PackedStringArray
) -> void:
	var dim_k: float = clampf(age / DIM_SEC, 0.0, 1.0)
	p.fill_rect(0.0, 0.0, CANVAS_WIDTH, CANVAS_HEIGHT, Color(dim, dim.a * dim_k))

	var land: float = clampf(age / TITLE_LAND_SEC, 0.0, 1.0)
	var title_scale: float = lerpf(TITLE_FROM_SCALE, 1.0, ease(land, 0.25))
	p.push()
	p.translate(CANVAS_WIDTH / 2.0, CANVAS_HEIGHT / 2.0)
	p.scale(title_scale, title_scale)
	p.text(title, 0.0, 0.0, 56.0, Color(title_color, land), true)
	p.pop()

	for i: int in lines.size():
		var line_age: float = age - LINE_DELAY_SEC - float(i) * LINE_STAGGER_SEC
		var shown: float = clampf(line_age / LINE_FADE_SEC, 0.0, 1.0)
		if shown <= 0.0:
			continue
		p.text(
			lines[i], CANVAS_WIDTH / 2.0,
			CANVAS_HEIGHT / 2.0 + 47.0 + float(i) * 38.0 + (1.0 - shown) * 8.0, 24.0,
			Color(Palette.SLATE_400, shown)
		)


func _draw_title_card(p: Painter) -> void:
	if _card_title.is_empty() or _card_age >= CARD_IN_SEC + CARD_HOLD_SEC + CARD_OUT_SEC:
		return
	var alpha: float = clampf(_card_age / CARD_IN_SEC, 0.0, 1.0)
	var out_age: float = _card_age - CARD_IN_SEC - CARD_HOLD_SEC
	if out_age > 0.0:
		alpha = 1.0 - clampf(out_age / CARD_OUT_SEC, 0.0, 1.0)
	var slide: float = (1.0 - ease(clampf(_card_age / CARD_IN_SEC, 0.0, 1.0), 0.3)) * 14.0
	var center_x: float = CANVAS_WIDTH / 2.0

	p.gradient_rect(0.0, CARD_Y - 46.0, center_x, 86.0, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.5 * alpha))
	p.gradient_rect(center_x, CARD_Y - 46.0, center_x, 86.0, Color(0.0, 0.0, 0.0, 0.5 * alpha), Color(0.0, 0.0, 0.0, 0.0))
	p.text(_card_title, center_x, CARD_Y + slide, 40.0, Color(_card_color, alpha), true)
	var rule_half: float = 150.0 * alpha
	p.fill_rect(center_x - rule_half, CARD_Y + 12.0 + slide, rule_half * 2.0, 2.0, Color(_card_color, alpha * 0.7))
	if not _card_subtitle.is_empty():
		p.text(_card_subtitle, center_x, CARD_Y + 34.0 + slide, 18.0, Color(Palette.SLATE_400, alpha))


## Cool-coloured edges that close in while time is slowed.
func _draw_vignette(p: Painter) -> void:
	var edge: Color = Color(VIGNETTE_COLOR, VIGNETTE_STRENGTH * slow_amount)
	var clear: Color = Color(VIGNETTE_COLOR, 0.0)
	p.gradient_rect(0.0, 0.0, VIGNETTE_DEPTH, CANVAS_HEIGHT, edge, clear)
	p.gradient_rect(CANVAS_WIDTH - VIGNETTE_DEPTH, 0.0, VIGNETTE_DEPTH, CANVAS_HEIGHT, clear, edge)
	p.vertical_gradient_rect(0.0, 0.0, CANVAS_WIDTH, VIGNETTE_DEPTH * 0.6, edge, clear)
	p.vertical_gradient_rect(
		0.0, CANVAS_HEIGHT - VIGNETTE_DEPTH * 0.6, CANVAS_WIDTH, VIGNETTE_DEPTH * 0.6, clear, edge
	)


## Hazard-striped bands, a red pulse and a countdown while the boss descends.
func _draw_boss_intro(p: Painter, t: float) -> void:
	var count: int = sim.boss.intro_timer
	var pulse: float = clampf(float(180 - count) / 360.0 * sin(t / 150.0) + 0.15, 0.0, 0.25)
	p.fill_rect(0.0, 0.0, CANVAS_WIDTH, CANVAS_HEIGHT, Color(Palette.RED_500, pulse))

	var offset: float = fmod(t / 15.0, 60.0)
	for band_y: float in [0.0, CANVAS_HEIGHT - BAND_HEIGHT]:
		p.fill_rect(0.0, band_y, CANVAS_WIDTH, BAND_HEIGHT, Palette.BLACK)
		var x: float = -80.0 + offset
		while x < CANVAS_WIDTH + 80.0:
			p.polygon(
				PackedVector2Array([
					Vector2(x - 8.0, band_y), Vector2(x + 8.0, band_y),
					Vector2(x - 12.0, band_y + BAND_HEIGHT), Vector2(x - 28.0, band_y + BAND_HEIGHT),
				]),
				Palette.YELLOW_500
			)
			x += 60.0

	var title_color: Color = Palette.RED_400 if fmod(t, 500.0) < 250.0 else Palette.WHITE
	var title_y: float = CANVAS_HEIGHT / 2.0 - 20.0
	# A soft red halo behind the title.
	for spread: float in [3.0, 2.0, 1.0]:
		p.text("WARNING!", CANVAS_WIDTH / 2.0 + spread, title_y + spread, 44.0, Color(Palette.RED_500, 0.2), true)
		p.text("WARNING!", CANVAS_WIDTH / 2.0 - spread, title_y - spread, 44.0, Color(Palette.RED_500, 0.2), true)
	p.text("WARNING!", CANVAS_WIDTH / 2.0, title_y, 44.0, title_color, true)
	p.text(
		"首領登場：%d 秒" % ceili(float(count) / 60.0), CANVAS_WIDTH / 2.0, CANVAS_HEIGHT / 2.0 + 30.0,
		24.0, Palette.RED_500, true
	)
