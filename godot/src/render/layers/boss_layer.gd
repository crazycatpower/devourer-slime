class_name BossLayer
extends WorldLayer
## Draws the boss: its telegraphed leap, its body and the blocks inside it,
## its face, the status read-outs above it, and the devour beam.

const _T: float = Tile.SIZE
const FLASH_COLOR: Color = Palette.YELLOW_200
const EDGE_SPIKE_LENGTH: float = 14.0
## Longest leap the telegraph simulates, in ticks.
const PREVIEW_TICKS: int = 350
const BLINK_PERIOD_MS: float = 3500.0
const BLINK_LENGTH_MS: float = 150.0


func _paint(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if not boss.active or boss.dead:
		return
	var pos: Vector2 = view.tween_position(boss.prev_x, boss.prev_y, boss.x, boss.y)
	var kind: BossState.Kind = sim.boss_kind
	var is_world_1: bool = kind == BossState.Kind.WORLD_1

	if boss.state == BossState.State.CHARGING:
		_paint_leap_preview(p, sim, pos)

	p.push()
	# Squash and stretch pivot on the feet. The block body of World 1 stays rigid.
	p.translate(pos.x + boss.w / 2.0, pos.y + boss.h)
	if not is_world_1:
		p.scale(boss.scale_x, boss.scale_y)

	if is_world_1:
		_paint_world_1_phase_aura(p, sim)
		_paint_block_body(p, sim)
	else:
		_paint_slime_body(p, sim)
		if kind != BossState.Kind.WORLD_3:
			_paint_cells(p, sim)
	_paint_face(p, sim, pos)
	_paint_status(p, sim)
	p.pop()

	if kind == BossState.Kind.WORLD_3:
		_paint_shields(p, sim)
	_paint_devour_beam(p, sim, pos)


func _paint_world_1_phase_aura(p: Painter, sim: GameSim) -> void:
	var phase: int = BossWorld1.phase_profile(sim)["phase"] as int
	if phase == 0:
		return
	var boss: BossState = sim.boss
	var pulse: float = 0.5 + sin(view.time_ms / 180.0) * 0.15
	var color: Color = Palette.AMBER_400 if phase == 1 else Palette.RED_400
	var alpha: float = pulse if phase == 1 else pulse + 0.2
	p.stroke_round_rect(
		-boss.w / 2.0 - 6.0, -boss.h - 6.0, boss.w + 12.0, boss.h + 12.0,
		28.0, Color(color, alpha), 3.0 if phase == 1 else 4.5
	)


# --- Body ---------------------------------------------------------------------

func _paint_slime_body(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var kind: BossState.Kind = sim.boss_kind
	var t: float = view.time_ms
	var half_w: float = boss.w / 2.0
	var filled: int = boss.filled_count()
	var is_filled: bool = boss.is_filled()

	var fill: Color
	var outline: Color
	var outline_width: float
	if kind == BossState.Kind.WORLD_2:
		fill = Color(Palette.PINK_500, 0.22)
		outline = Palette.PINK_600
		outline_width = 4.0 + sin(t / 60.0) * 1.5
	elif kind == BossState.Kind.WORLD_3:
		fill = Color(Palette.CYAN_500, 0.18)
		outline = Palette.CYAN_500
		outline_width = 4.5 + sin(t / 60.0) * 1.5
	elif is_filled:
		fill = Color(Palette.PURPLE_500, 0.35)
		outline = Palette.PURPLE_500
		outline_width = 5.0 + sin(t / 80.0) * 2.0
	elif filled >= BossWorld4.PHASE_3_FILLED:
		fill = Color(Palette.RED_500, 0.28 + sin(t / 65.0) * 0.12)
		outline = Palette.RED_500
		outline_width = 4.5 + sin(t / 45.0) * 2.0
	elif filled >= BossWorld4.PHASE_2_FILLED:
		fill = Color(Palette.AMBER_500, 0.18 + sin(t / 120.0) * 0.05)
		outline = Palette.AMBER_500
		outline_width = 3.5 + sin(t / 90.0)
	else:
		fill = Color(Palette.EMERALD_500, 0.15)
		outline = Palette.EMERALD_500
		outline_width = 3.0
	if kind == BossState.Kind.WORLD_4 and boss.damage_flash > 0.0:
		fill = Color(FLASH_COLOR, clampf(0.4 + boss.damage_flash * 0.5, 0.0, 1.0))

	p.fill_round_rect(-half_w, -boss.h, boss.w, boss.h, 24.0, fill)

	if kind == BossState.Kind.WORLD_3:
		# A big glass block: a cross inside and two glints.
		var cross: Color = Color(Palette.CYAN_500, 0.55)
		p.line(-half_w + 14.0, -boss.h + 14.0, half_w - 14.0, -14.0, cross, 4.0)
		p.line(half_w - 14.0, -boss.h + 14.0, -half_w + 14.0, -14.0, cross, 4.0)
		var glint: Color = Color(Palette.WHITE, 0.55)
		p.line(-half_w + 24.0, -boss.h + 24.0, -half_w + 55.0, -boss.h + 55.0, glint, 4.5)
		p.line(half_w - 55.0, -55.0, half_w - 24.0, -24.0, glint, 4.5)

	p.stroke_round_rect(-half_w, -boss.h, boss.w, boss.h, 24.0, outline, outline_width)

	if kind == BossState.Kind.WORLD_2:
		# The bubble shield that makes it immune to being eaten.
		var radius: float = Vector2(boss.w, boss.h).length() / 2.0 + 18.0 + sin(t / 100.0) * 2.0
		var cy: float = -boss.h / 2.0
		p.fill_circle(0.0, cy, radius, Color(Palette.FUCHSIA_400, 0.07))
		p.stroke_circle(0.0, cy, radius, Color(Palette.FUCHSIA_500, 0.25), 9.0)
		p.stroke_circle(0.0, cy, radius, Palette.FUCHSIA_400, 3.5 + sin(t / 50.0))
		p.stroke_circle(0.0, cy, radius - 6.0, Color(Palette.FUCHSIA_500, 0.5), 1.5)

	if kind == BossState.Kind.WORLD_4 and filled >= BossWorld4.PHASE_3_FILLED and fmod(t, 350.0) < 160.0:
		# Phase 3: sparks arc between random cells.
		var from: Vector2 = _cell_center(randi() % 3, randi() % 3, half_w, boss.h)
		var to: Vector2 = _cell_center(randi() % 3, randi() % 3, half_w, boss.h)
		var mid: Vector2 = (from + to) / 2.0 + Vector2(randf() - 0.5, randf() - 0.5) * 25.0
		p.polyline(PackedVector2Array([from, mid, to]), Color(Palette.RED_400, 0.85), 2.5)


func _cell_center(r: int, c: int, half_w: float, height: float) -> Vector2:
	return Vector2(-half_w + (float(c) + 0.5) * _T, -height + (float(r) + 0.5) * _T)


## The 3x3 cells of Worlds 2 and 4: blocks, or lethal void where empty.
func _paint_cells(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	for r: int in 3:
		for c: int in 3:
			var x: float = -boss.w / 2.0 + float(c) * _T
			var y: float = -boss.h + float(r) * _T
			var val: int = boss.cell(r, c)
			if val != 0:
				TilePainter.draw(p, val, x, y, view.time_ms)
				continue
			p.fill_rect(x + 2.0, y + 2.0, _T - 4.0, _T - 4.0, Palette.SLATE_900)
			p.dashed_rect(x + 3.5, y + 3.5, _T - 7.0, _T - 7.0, Palette.PURPLE_500, 2.0, 4.0)
			p.fill_rect(x + 11.0, y + 11.0, _T - 22.0, _T - 22.0, Color(Palette.PURPLE_500, 0.35))


## World 1: the body is nothing but the blocks it has absorbed.
func _paint_block_body(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var n: int = boss.grid_size
	var left: float = -boss.w / 2.0
	var top: float = -boss.h
	var flash: Color = Color(FLASH_COLOR, clampf(0.4 + boss.damage_flash * 0.4, 0.0, 1.0))

	if boss.reorg_timer > 0 and not boss.reorg_cells.is_empty():
		# Blocks slide to their new places one after another.
		var total: int = boss.reorg_cells[-1].end_frame
		var elapsed: float = float(total - boss.reorg_timer) + view.tick_alpha - 1.0
		for anim: ReorgAnimCell in boss.reorg_cells:
			var f: float = clampf(
				(elapsed - float(anim.start_frame)) / float(anim.end_frame - anim.start_frame), 0.0, 1.0
			)
			f = 1.0 - pow(1.0 - f, 3.0)
			var x: float = left + (lerpf(float(anim.from_c), float(anim.to_c), f) - float(boss.min_c)) * _T
			var y: float = top + (lerpf(float(anim.from_r), float(anim.to_r), f) - float(boss.min_r)) * _T
			TilePainter.draw(p, anim.val, x, y, view.time_ms)
			if boss.damage_flash > 0.0:
				p.fill_rect(x, y, _T, _T, flash)
		if boss.cell(boss.center_r, boss.center_c) == Tile.GOAL:
			TilePainter.draw(
				p, Tile.GOAL, left + float(boss.center_c - boss.min_c) * _T,
				top + float(boss.center_r - boss.min_r) * _T, view.time_ms
			)
		return

	var airborne: bool = boss.state == BossState.State.JUMPING or not boss.grounded
	for r: int in range(boss.min_r, boss.max_r + 1):
		for c: int in range(boss.min_c, boss.max_c + 1):
			var val: int = boss.grid[r * n + c]
			if val == 0:
				continue
			var x: float = left + float(c - boss.min_c) * _T
			var y: float = top + float(r - boss.min_r) * _T
			TilePainter.draw(p, val, x, y, view.time_ms)
			if boss.damage_flash > 0.0:
				p.fill_rect(x, y, _T, _T, flash)
			# Spikes sprout from the outer faces while it is in the air: a
			# leaping boss kills on touch.
			if airborne:
				if boss.cell(r - 1, c) == 0:
					TilePainter.draw_spikes(p, Tile.SPIKE_UP, x, y - _T, EDGE_SPIKE_LENGTH)
				if boss.cell(r + 1, c) == 0:
					TilePainter.draw_spikes(p, Tile.SPIKE_DOWN, x, y + _T, EDGE_SPIKE_LENGTH)
				if boss.cell(r, c - 1) == 0:
					TilePainter.draw_spikes(p, Tile.SPIKE_LEFT, x - _T, y, EDGE_SPIKE_LENGTH)
				if boss.cell(r, c + 1) == 0:
					TilePainter.draw_spikes(p, Tile.SPIKE_RIGHT, x + _T, y, EDGE_SPIKE_LENGTH)


# --- Face -----------------------------------------------------------------------

func _paint_face(p: Painter, sim: GameSim, pos: Vector2) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var is_world_1: bool = sim.boss_kind == BossState.Kind.WORLD_1
	# The face sits on the core cell of World 1 and in the upper middle of
	# the slime bosses.
	var face_x: float = 0.0
	var face_y: float = -boss.h / 1.7
	var look_from: Vector2 = pos + Vector2(boss.w / 2.0, boss.h / 2.0)
	if is_world_1:
		face_x = -boss.w / 2.0 + (float(boss.center_c - boss.min_c) + 0.5) * _T
		face_y = -boss.h + (float(boss.center_r - boss.min_r) + 0.5) * _T
		look_from = pos + Vector2(boss.w / 2.0 + face_x, boss.h + face_y)

	var to_player: Vector2 = Vector2(player.center_x(), player.center_y()) - look_from
	var look: Vector2 = to_player.normalized() if to_player.length() > 0.0 else Vector2.ZERO
	var eye_x: float = look.x * 12.0
	var eye_y: float = look.y * 8.0
	var hungry: bool = boss.is_filled() or boss.eating_progress > 0.0

	p.push()
	p.translate(face_x, face_y)
	if fmod(view.time_ms, BLINK_PERIOD_MS) < BLINK_LENGTH_MS:
		p.fill_rect(eye_x - 28.0, eye_y, 15.0, 3.0, Palette.SLATE_900)
		p.fill_rect(eye_x + 13.0, eye_y, 15.0, 3.0, Palette.SLATE_900)
	else:
		p.fill_circle(eye_x - 22.0, eye_y, 12.0, Palette.WHITE)
		p.fill_circle(eye_x + 22.0, eye_y, 12.0, Palette.WHITE)
		var pupil: Color = Palette.RED_500
		if sim.boss_kind == BossState.Kind.WORLD_3:
			pupil = Palette.CYAN_500
		elif hungry:
			pupil = Palette.PURPLE_500
		p.fill_circle(eye_x - 22.0 + look.x * 3.0, eye_y + look.y * 2.0, 5.0, pupil)
		p.fill_circle(eye_x + 22.0 + look.x * 3.0, eye_y + look.y * 2.0, 5.0, pupil)
	if hungry:
		p.stroke_circle(0.0, eye_y + 18.0, 7.0, Palette.SLATE_900, 3.5)
	else:
		p.arc(0.0, eye_y + 12.0, 10.0, 0.1 * PI, 0.9 * PI, Palette.SLATE_900, 3.5)
	p.pop()


# --- Status read-outs -------------------------------------------------------------

func _paint_status(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var kind: BossState.Kind = sim.boss_kind
	var t: float = view.time_ms

	if kind == BossState.Kind.WORLD_2 or kind == BossState.Kind.WORLD_3:
		_paint_durability(p, sim)
		return

	if boss.state == BossState.State.CHARGING:
		var bar_y: float = -boss.h - 25.0
		var progress: float = _charge_progress(boss)
		p.fill_rect(-70.0, bar_y, 140.0, 12.0, Color(Palette.SLATE_900, 0.9))
		var color: Color = Palette.PURPLE_500 if fmod(t, 150.0) < 75.0 else Palette.PINK_500
		p.fill_rect(-68.0, bar_y + 2.0, 136.0 * progress, 8.0, color)
		p.stroke_rect(-70.0, bar_y, 140.0, 12.0, Palette.PURPLE_400, 1.5)
		p.text("大招蓄力中…", 0.0, bar_y - 8.0, 11.0, Palette.PURPLE_100, true)
	elif boss.eating_progress > 0.0:
		var bar_y: float = -boss.h - 25.0
		p.fill_rect(-40.0, bar_y, 80.0, 8.0, Color(Palette.SLATE_900, 0.8))
		p.fill_rect(-40.0, bar_y, 80.0 * minf(boss.eating_progress, 1.0), 8.0, Palette.PURPLE_500)
		p.stroke_rect(-40.0, bar_y, 80.0, 8.0, Palette.PURPLE_400, 1.0)
		p.text("吞噬首領！", 0.0, bar_y - 6.0, 10.0, Palette.PURPLE_100, true)
	elif boss.is_filled():
		p.text("瞄準首領按住吞噬！", 0.0, -boss.h - 18.0, 11.0, Palette.PURPLE_100, true)
	elif boss.state != BossState.State.SUSPENDED and boss.grounded and (
		boss.state == BossState.State.ACTIVE or boss.state == BossState.State.PRE_JUMP
	):
		# How close the next jump is.
		var bar_y: float = -boss.h - 38.0
		var progress: float = 0.0
		if boss.state == BossState.State.PRE_JUMP and boss.max_pre_jump_timer > 0:
			progress = 1.0 - float(boss.pre_jump_timer) / float(boss.max_pre_jump_timer)
		elif boss.max_cooldown > 0:
			progress = float(boss.max_cooldown - boss.cooldown) / float(boss.max_cooldown)
		progress = clampf(progress, 0.0, 1.0)
		var ready: bool = progress >= 0.9
		p.fill_round_rect(-60.0, bar_y, 120.0, 6.0, 3.0, Color(Palette.SLATE_900, 0.85))
		p.gradient_rect(
			-60.0, bar_y, 120.0 * progress, 6.0, Palette.ORANGE_600,
			Palette.ORANGE_600.lerp(Palette.RED_500, progress)
		)
		p.stroke_round_rect(
			-60.0, bar_y, 120.0, 6.0, 3.0, Palette.RED_300 if ready else Palette.ZINC_600, 1.0
		)
		var label: String = "即將跳躍！" if ready else "跳躍蓄力 %d%%" % roundi(progress * 100.0)
		p.text(label, 0.0, bar_y - 6.0, 9.0, Palette.AMBER_400 if ready else Palette.ZINC_200, true)


## Hit points of Worlds 2 and 3, and how soon the next attack comes.
func _paint_durability(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var is_world_3: bool = sim.boss_kind == BossState.Kind.WORLD_3
	var t: float = view.time_ms
	var icons_y: float = -boss.h - 52.0
	var text_color: Color = Palette.SKY_100 if is_world_3 else Palette.PINK_100
	p.text("核心穩定度" if is_world_3 else "護盾耐久", 0.0, icons_y - 14.0, 11.0, text_color, true)
	for i: int in BossState.MAX_DURABILITY:
		var x: float = float(i - 1) * 22.0
		var alive: bool = i < boss.durability
		if is_world_3:
			p.icon_gem(x, icons_y, 16.0, Palette.CYAN_400 if alive else Palette.SLATE_700)
		else:
			p.icon_heart(x, icons_y, 16.0, Palette.PINK_500 if alive else Palette.SLATE_700)

	if boss.state != BossState.State.CHARGING and boss.state != BossState.State.ACTIVE:
		return
	var bar_y: float = -boss.h - 22.0
	var progress: float = 0.0
	if boss.state == BossState.State.CHARGING:
		progress = _charge_progress(boss)
	elif boss.max_cooldown > 0:
		progress = float(boss.max_cooldown - boss.cooldown) / float(boss.max_cooldown)
	progress = clampf(progress, 0.0, 1.0)
	var ready: bool = boss.state == BossState.State.CHARGING and progress >= 0.95
	p.fill_rect(-65.0, bar_y, 130.0, 8.0, Color(Palette.SLATE_900, 0.85))
	var bar_color: Color = Palette.CYAN_500 if is_world_3 else Palette.PINK_600
	if ready:
		bar_color = Palette.PINK_400 if fmod(t, 160.0) < 80.0 else Palette.PINK_500
	p.fill_rect(-63.5, bar_y + 1.5, 127.0 * progress, 5.0, bar_color)
	p.stroke_rect(-65.0, bar_y, 130.0, 8.0, Palette.CYAN_200 if is_world_3 else Palette.PINK_200, 1.0)
	var label: String
	if ready:
		label = "即將衝撞！"
	elif is_world_3:
		label = "下一次攻擊 %d%%" % roundi(progress * 100.0)
	elif boss.state == BossState.State.CHARGING:
		label = "蓄力中 %d%%" % roundi(progress * 100.0)
	else:
		label = "休息中 %d%%" % roundi(progress * 100.0)
	p.text(label, 0.0, bar_y - 6.0, 9.0, text_color, true)


func _charge_progress(boss: BossState) -> float:
	if boss.max_charge_timer <= 0:
		return 1.0
	return clampf(1.0 - float(boss.charge_timer) / float(boss.max_charge_timer), 0.0, 1.0)


# --- World 3 shields ----------------------------------------------------------------

func _paint_shields(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var count: int = boss.shields.size()
	for i: int in count:
		var shield: ShieldState = boss.shields[i]
		if not shield.active:
			continue
		var detaching: bool = shield.mode == ShieldState.Mode.DETACHING
		var spin: float = 8.0 if detaching else 1.5
		p.push()
		p.translate(shield.cx, shield.cy)
		p.rotate(view.time_ms / 1500.0 * spin + float(i) * TAU / float(count) + PI / 4.0)
		if detaching:
			# A shield about to be fired glows.
			var glow: float = 26.0 + sin(view.time_ms / 30.0) * 3.0
			p.fill_round_rect(-glow, -glow, glow * 2.0, glow * 2.0, 10.0, Color(Palette.CYAN_400, 0.25))
		p.fill_round_rect(-20.0, -20.0, 40.0, 40.0, 6.0, Color(Palette.CYAN_200, 0.95 if detaching else 0.65))
		p.stroke_round_rect(
			-20.0, -20.0, 40.0, 40.0, 6.0, Palette.WHITE if detaching else Palette.CYAN_400,
			3.5 if detaching else 2.5
		)
		p.line(-10.0, -10.0, 10.0, 10.0, Color(Palette.WHITE, 0.85), 1.5)
		p.pop()


# --- Leap telegraph -------------------------------------------------------------------

## While a boss charges, the path it is about to take is swept out as a
## band of faint boxes ending in an outlined landing box.
func _paint_leap_preview(p: Painter, sim: GameSim, pos: Vector2) -> void:
	var boss: BossState = sim.boss
	var start: Vector2 = pos + Vector2(boss.w / 2.0, boss.h / 2.0)
	var points: PackedVector2Array
	var color: Color
	if sim.boss_kind == BossState.Kind.WORLD_2:
		points = _simulate_bouncing_leap(sim, start)
		color = Palette.PINK_600
	elif sim.boss_kind == BossState.Kind.WORLD_4:
		points = _simulate_smashing_leap(sim, start)
		color = Palette.PURPLE_500
	else:
		return

	var progress: float = _charge_progress(boss)
	# The band shoots out to its full length early in the charge.
	var shown: int = maxi(2, floori(float(points.size()) * minf(1.0, progress * 3.5)))
	shown = mini(shown, points.size())
	# Many overlapping boxes make up the band, so each one is very faint;
	# a centre line keeps the path readable where the band folds over itself.
	var band: Color = Color(color, 0.012 + 0.02 * progress)
	for i: int in range(0, shown, 2):
		p.fill_rect(points[i].x - boss.w / 2.0, points[i].y - boss.h / 2.0, boss.w, boss.h, band)
	p.dashed_polyline(points.slice(0, shown), Color(color.lightened(0.35), 0.35 + 0.4 * progress), 3.0, 10.0)
	var landing: Vector2 = points[shown - 1]
	p.fill_rect(
		landing.x - boss.w / 2.0, landing.y - boss.h / 2.0, boss.w, boss.h,
		Color(color, 0.25 + 0.35 * progress)
	)
	p.stroke_rect(
		landing.x - boss.w / 2.0, landing.y - boss.h / 2.0, boss.w, boss.h,
		Color(Palette.WHITE, 0.5 + 0.4 * progress), 2.5
	)


## World 2's leap: rebounds off blocks, walls and the ceiling, and bounces on
## the floor a number of times. Mirrors [BossWorld2].
func _simulate_bouncing_leap(sim: GameSim, start: Vector2) -> PackedVector2Array:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var half_w: float = boss.w / 2.0
	var half_h: float = boss.h / 2.0
	var x: float = start.x
	var y: float = start.y
	var vx: float = BossWorld2.leap_vx(BossSystem.player_dx(sim))
	var vy: float = -BossWorld2.LEAP_SPEED
	var bounces: int = BossWorld2.bounces_for(boss.durability)
	var points: PackedVector2Array = PackedVector2Array([start])

	for _step: int in PREVIEW_TICKS:
		vy += BossWorld2.GRAVITY_LEAPING
		x += vx
		var hit_col: int = _first_solid_column(level, x, y, half_w, half_h)
		if hit_col >= 0:
			if vx > 0.0:
				x = float(hit_col) * _T - half_w - 0.1
			elif vx < 0.0:
				x = float(hit_col + 1) * _T + half_w + 0.1
			vx = -vx * BossWorld2.BOUNCE_RESTITUTION
		y += vy

		var right_limit: float = level.pixel_width() - _T - half_w
		if x < _T + half_w:
			x = _T + half_w
			vx = -vx * BossWorld2.BOUNCE_RESTITUTION
		elif x > right_limit:
			x = right_limit
			vx = -vx * BossWorld2.BOUNCE_RESTITUTION
		if y < _T + half_h:
			y = _T + half_h
			vy = -vy * BossWorld2.BOUNCE_RESTITUTION
		points.append(Vector2(x, y))

		var r_floor: int = floori((y + half_h) / _T)
		if vy >= 0.0 and _floor_under(sim, x, half_w, r_floor, false):
			y = float(r_floor) * _T - half_h
			if bounces <= 0:
				break
			bounces -= 1
			vy = -BossWorld2.LEAP_SPEED
			if absf(vx) < 5.0:
				vx = (1.0 if vx >= 0.0 else -1.0) * 6.0
			else:
				vx *= BossWorld2.BOUNCE_RESTITUTION
	return points


## World 4's ultimate: stops dead at the side walls, ploughs through every
## breakable block and only lands on steel. Mirrors [BossWorld4].
func _simulate_smashing_leap(sim: GameSim, start: Vector2) -> PackedVector2Array:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var half_w: float = boss.w / 2.0
	var half_h: float = boss.h / 2.0
	var x: float = start.x
	var y: float = start.y
	var vx: float = BossWorld4.mega_leap_vx(BossSystem.player_dx(sim))
	var vy: float = -BossWorld4.MEGA_JUMP_SPEED
	var points: PackedVector2Array = PackedVector2Array([start])

	for _step: int in PREVIEW_TICKS:
		vy += BossWorld4.GRAVITY
		y += vy
		if y < _T + half_h:
			y = _T + half_h
			vy = maxf(vy, 0.0)
		var r_floor: int = floori((y + half_h) / _T)
		if vy >= 0.0 and _floor_under(sim, x, half_w, r_floor, true):
			points.append(Vector2(x, float(r_floor) * _T - half_h))
			break
		x += vx
		if x - half_w < _T:
			x = _T + 1.0 + half_w
			vx = 0.0
		elif x + half_w > level.pixel_width() - _T:
			x = level.pixel_width() - _T - 1.0 - half_w
			vx = 0.0
		points.append(Vector2(x, y))
	return points


## Column of the first solid tile overlapping a box centred on (x, y), or -1.
func _first_solid_column(level: LevelGrid, x: float, y: float, half_w: float, half_h: float) -> int:
	var col_start: int = maxi(0, floori((x - half_w) / _T))
	var col_end: int = mini(level.cols - 1, floori((x + half_w - 1.0) / _T))
	var row_start: int = maxi(0, floori((y - half_h) / _T))
	var row_end: int = mini(level.rows - 1, floori((y + half_h - 1.0) / _T))
	for r: int in range(row_start, row_end + 1):
		for c: int in range(col_start, col_end + 1):
			if Tile.is_solid(level.get_cell(r, c)):
				return c
	return -1


## True when floor row [param r_floor] can carry a box centred on x.
## [param steel_only] ignores breakable blocks.
func _floor_under(sim: GameSim, x: float, half_w: float, r_floor: int, steel_only: bool) -> bool:
	if r_floor < 1:
		return false
	var first: int = floori((x - half_w) / _T)
	var last: int = floori((x + half_w - 0.001) / _T)
	for col: int in range(first, last + 1):
		if not sim.is_solid_or_boundary(r_floor, col):
			continue
		if steel_only:
			var t: int = sim.level.get_cell(r_floor, col)
			if t != Tile.STEEL and Tile.is_solid(t):
				continue
		return true
	return false


# --- Devour beam -----------------------------------------------------------------------

## The stream of energy between the player and a boss being devoured.
func _paint_devour_beam(p: Painter, sim: GameSim, pos: Vector2) -> void:
	var boss: BossState = sim.boss
	if sim.boss_kind != BossState.Kind.WORLD_4:
		return
	if not (boss.is_filled() or boss.eating_progress > 0.0):
		return
	if not view.eat_held or sim.player.has_block or not BossWorld4.is_player_aiming_at_boss(sim):
		return
	var player: PlayerState = sim.player
	var from: Vector2 = view.tween_position(player.prev_x, player.prev_y, player.x, player.y)
	from += Vector2(player.w / 2.0, player.h / 2.0)
	var to: Vector2 = pos + Vector2(boss.w / 2.0, boss.h / 2.0)
	var t: float = view.time_ms
	var control: Vector2 = (from + to) / 2.0 + Vector2(sin(t / 150.0), cos(t / 150.0)) * 40.0

	var curve: PackedVector2Array = PackedVector2Array()
	for i: int in 25:
		var f: float = float(i) / 24.0
		curve.append(from.lerp(control, f).lerp(control.lerp(to, f), f))
	p.dashed_polyline(curve, Color(Palette.PURPLE_500, 0.75), 6.0 + sin(t / 30.0) * 3.0, 9.0)
	p.polyline(curve, Color(Palette.PURPLE_100, 0.9), 2.0)
