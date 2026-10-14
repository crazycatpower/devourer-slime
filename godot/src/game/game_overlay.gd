class_name GameOverlay
extends Control
## Full-view overlays drawn over the world: the level's title card, the
## bullet-time vignette, boss entrance warning, rewind and level clear screens.
##
## Drawn in 960x540 canvas units, scaled to the view. The
## animations here are presentation only and run on real time.

const CANVAS_WIDTH: float = GameConstants.CANVAS_WIDTH
const CANVAS_HEIGHT: float = GameConstants.CANVAS_HEIGHT
const BAND_HEIGHT: float = 40.0

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
## Shortcut shown during the rewind.
var retry_line: String = ""
## Authored stage instruction; kept visible after the entrance card.
var stage_hint: String = ""
## 0 at normal speed, 1 in full bullet time.
var slow_amount: float = 0.0

var _card_title: String = ""
var _card_subtitle: String = ""
var _card_color: Color = Palette.WHITE
var _card_age: float = INF
## Seconds the current result screen has been up.
var exit_in_progress: bool = false
var _won_age: float = 0.0


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
		not sim.player.dead and not sim.player.won and sim.boss.active and sim.boss.state == BossState.State.INTRO
		and (sim.boss.intro_freezes_player or sim.boss_kind == BossState.Kind.STEEL_CHASE)
	)
	if boss_entrance:
		_draw_boss_intro(p, t)

	var player: PlayerState = sim.player
	if player.won:
		if exit_in_progress:
			var fade: float = clampf((_won_age - GoalVortex.DURATION + 0.25) / 0.25, 0.0, 1.0)
			p.fill_rect(0.0, 0.0, CANVAS_WIDTH, CANVAS_HEIGHT, Color(Palette.SLATE_950, fade))
			return
		_draw_result(p, _won_age, "LEVEL CLEARED!", Palette.EMERALD_500, Color(0.0, 0.0, 0.0, 0.7), win_lines)
	elif player.dead:
		_draw_rewind(p)
	elif not boss_entrance:
		_draw_title_card(p)
		if sim.boss.active and BossMechanism.is_kind(sim.boss_kind):
			var color: Color = WorldCatalog.accent(BossMechanism.world_for(sim.boss_kind))
			p.fill_round_rect(246.0, CANVAS_HEIGHT - 38.0, 700.0, 26.0, 6.0, Color(Palette.SLATE_950, 0.8))
			p.text(BossMechanism.hint(sim.boss_kind), 596.0, CANVAS_HEIGHT - 20.0, 12.0, color, true)
			_draw_mechanism_navigation(p, color)
		if not sim.boss.active and not stage_hint.is_empty():
			var color: Color = WorldCatalog.accent(GameConstants.world_of_slot(sim.slot))
			p.fill_round_rect(246.0, CANVAS_HEIGHT - 38.0, 700.0, 26.0, 6.0, Color(Palette.SLATE_950, 0.8))
			p.text(stage_hint, 596.0, CANVAS_HEIGHT - 20.0, 12.0, color, true)
		if not player.ability_label().is_empty():
			p.fill_round_rect(14.0, CANVAS_HEIGHT - 38.0, 216.0, 26.0, 6.0, Color(Palette.SLATE_950, 0.8))
			p.text(player.ability_label(), 25.0, CANVAS_HEIGHT - 20.0, 14.0, player.ability_color(), false, Painter.Align.LEFT)


## Quiet rewind indicator; the world itself plays backwards behind it.
func _draw_rewind(p: Painter) -> void:
	var progress: float = clampf(float(sim.death_timer) / float(GameSim.DEATH_RESTART_TICKS), 0.0, 1.0)
	var edge: Color = Color(Palette.CYAN_400, sin(progress * PI) * 0.12)
	p.gradient_rect(0.0, 0.0, 90.0, CANVAS_HEIGHT, edge, Color(edge, 0.0))
	p.gradient_rect(CANVAS_WIDTH - 90.0, 0.0, 90.0, CANVAS_HEIGHT, Color(edge, 0.0), edge)
	p.fill_round_rect(366.0, 24.0, 228.0, 42.0, 10.0, Color(Palette.SLATE_950, 0.8))
	for x: float in [385.0, 397.0]:
		p.triangle(Vector2(x + 8.0, 36.0), Vector2(x, 44.0), Vector2(x + 8.0, 52.0), Palette.CYAN_200)
	p.text("安全位置" if progress >= 0.92 else "時光倒流", 490.0, 49.0, 21.0, Palette.CYAN_200, true)
	p.fill_round_rect(376.0, 59.0, 208.0 * (1.0 - progress), 3.0, 1.5, Palette.CYAN_400)
	p.text(retry_line, CANVAS_WIDTH * 0.5, 84.0, 13.0, Palette.CYAN_200, true)


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


## Keep objectives discoverable when the next station or exit is off camera.
func _draw_mechanism_navigation(p: Painter, color: Color) -> void:
	if sim.boss.dead:
		return
	var at: float = 0.0
	var label: String = ""
	if sim.boss_kind == BossState.Kind.ICE_SKATER:
		at = BossMechanism.cooling_station(sim).x
		label = "冷卻站 %d" % (sim.boss.mechanism.progress + 1)
	elif sim.boss_kind == BossState.Kind.SAND_COLOSSUS and sim.player.has_sand_core:
		at = 120.0
		label = "帶回入口"
	else:
		return
	if at >= sim.camera.x + 40.0 and at <= sim.camera.x + GameConstants.VIEW_WIDTH - 40.0:
		return
	var arrow: String = "←" if at < sim.player.center_x() else "→"
	var tiles: int = ceili(absf(at - sim.player.center_x()) / Tile.SIZE)
	p.fill_round_rect(342.0, 62.0, 276.0, 30.0, 6.0, Color(Palette.SLATE_950, 0.8))
	p.text("%s %s · 約 %d 格" % [arrow, label, tiles], CANVAS_WIDTH * 0.5, 82.0, 14.0, color, true)
