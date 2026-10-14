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

var _motion: BossMotion = BossMotion.new()


func _process(delta: float) -> void:
	if view != null and view.sim != null:
		_motion.advance(delta, view.sim)


func _paint(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if not boss.active or boss.dead:
		return
	if sim.boss_kind == BossState.Kind.STEEL_CHASE:
		_paint_steel_chase(p, sim)
		return
	if BossMechanism.is_kind(sim.boss_kind):
		_paint_mechanism(p, sim)
		return
	var pos: Vector2 = view.tween_position(boss.prev_x, boss.prev_y, boss.x, boss.y)
	var kind: BossState.Kind = sim.boss_kind
	var is_mud_golem: bool = kind == BossState.Kind.MUD_GOLEM

	var is_glass_slime: bool = kind == BossState.Kind.GLASS_SLIME
	_paint_impact(p, sim, pos)
	if is_glass_slime:
		_paint_glass_warning(p, sim)
	elif boss.state == BossState.State.CHARGING:
		_paint_leap_preview(p, sim, pos)

	p.push()
	# Squash and stretch pivot on the feet. The block body of the mud golem stays rigid.
	p.translate(pos.x + boss.w / 2.0, pos.y + boss.h)
	if kind in [BossState.Kind.BOUNCY_SLIME, BossState.Kind.VOID_SLIME]:
		p.shear_x(_motion.lean)
		p.scale(_motion.body_scale.x, _motion.body_scale.y)

	if is_mud_golem:
		_paint_mud_golem_phase_aura(p, sim)
		_paint_block_body(p, sim)
	elif is_glass_slime:
		_paint_glass_body(p, sim)
	else:
		_paint_slime_body(p, sim)
		_paint_cells(p, sim)
	_paint_face(p, sim, pos)
	p.pop()
	# Status stays level and legible while the body compresses or stretches.
	p.push()
	p.translate(pos.x + boss.w / 2.0, pos.y + boss.h)
	_paint_status(p, sim)
	p.pop()

	if is_glass_slime:
		_paint_shields(p, sim)
		_paint_bombs(p, sim)
	_paint_devour_beam(p, sim, pos)


func _paint_steel_chase(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.state == BossState.State.SUSPENDED:
		return
	var pos: Vector2 = view.tween_position(boss.prev_x, boss.prev_y, boss.x, boss.y)
	var face: float = pos.x + boss.w
	var pulse: float = 0.3 + 0.15 * sin(view.time_ms / 180.0)
	p.fill_rect(face - 4.0, pos.y, 4.0, boss.h, Color(Palette.RED_400, pulse))
	for row: int in ceili(boss.h / Tile.SIZE):
		var y: float = float(row) * Tile.SIZE
		for col: int in ceili(boss.w / Tile.SIZE):
			TilePainter.draw(p, Tile.STEEL, pos.x + float(col) * Tile.SIZE, y, view.time_ms)
		TilePainter.draw(p, Tile.SPIKE_RIGHT, face, y, view.time_ms)
	p.push()
	p.translate(pos.x + boss.w / 2.0, pos.y + boss.h)
	_paint_face(p, sim, pos)
	p.pop()


func _paint_impact(p: Painter, sim: GameSim, pos: Vector2) -> void:
	if _motion.impact <= 0.0:
		return
	var boss: BossState = sim.boss
	var spread: float = (1.0 - _motion.impact) * 30.0
	var color: Color = Palette.AMBER_400
	if sim.boss_kind == BossState.Kind.BOUNCY_SLIME:
		color = Palette.PINK_400
	elif sim.boss_kind == BossState.Kind.VOID_SLIME:
		color = Palette.PURPLE_400
	p.stroke_round_rect(pos.x - spread, pos.y + boss.h - 4.0, boss.w + spread * 2.0, 8.0, 4.0, Color(color, _motion.impact * 0.5), 2.0)


func _paint_mud_golem_phase_aura(p: Painter, sim: GameSim) -> void:
	var phase: int = BossMudGolem.phase_profile(sim)["phase"] as int
	if phase == 0:
		return
	var boss: BossState = sim.boss
	var pulse: float = 0.5 + sin(view.time_ms / 180.0) * 0.15
	var color: Color = Palette.AMBER_400 if phase == 1 else Palette.RED_400
	var alpha: float = pulse if phase == 1 else pulse + 0.2
	p.stroke_round_rect(
		-boss.w / 2.0 - 6.0, -boss.h - 6.0, boss.w + 12.0, boss.h + 12.0,
		6.0, Color(color, alpha), 3.0 if phase == 1 else 4.5
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
	if kind == BossState.Kind.BOUNCY_SLIME:
		var rage: float = float(BossBouncySlime.phase_for(boss.durability)) / 2.0
		fill = Color(Palette.PINK_500.lerp(Palette.RED_500, rage), 0.22 + 0.08 * rage)
		outline = Palette.PINK_600.lerp(Palette.RED_500, rage)
		outline_width = 4.0 + sin(t / lerpf(110.0, 65.0, rage)) * 0.7
	elif is_filled:
		fill = Color(Palette.PURPLE_500, 0.35)
		outline = Palette.PURPLE_500
		outline_width = 5.0 + sin(t / 80.0) * 2.0
	elif filled >= BossVoidSlime.PHASE_3_FILLED:
		fill = Color(Palette.RED_500, 0.28 + sin(t / 65.0) * 0.12)
		outline = Palette.RED_500
		outline_width = 4.5 + sin(t / 45.0) * 2.0
	elif filled >= BossVoidSlime.PHASE_2_FILLED:
		fill = Color(Palette.AMBER_500, 0.18 + sin(t / 120.0) * 0.05)
		outline = Palette.AMBER_500
		outline_width = 3.5 + sin(t / 90.0)
	else:
		fill = Color(Palette.EMERALD_500, 0.15)
		outline = Palette.EMERALD_500
		outline_width = 3.0
	if kind == BossState.Kind.VOID_SLIME and boss.damage_flash > 0.0:
		fill = Color(FLASH_COLOR, clampf(0.4 + boss.damage_flash * 0.5, 0.0, 1.0))

	p.fill_round_rect(-half_w, -boss.h, boss.w, boss.h, 6.0, fill)
	# Square layers and corner glints give the large jelly body a material.
	p.stroke_round_rect(-half_w + 5.0, -boss.h + 5.0, boss.w - 10.0, boss.h - 10.0, 3.0, Color(outline.lightened(0.3), 0.32), 2.0)
	for side: float in [-1.0, 1.0]:
		var gx: float = side * (half_w - 15.0) - 3.0
		p.fill_rect(gx, -boss.h + 10.0, 6.0, 6.0, Color(Palette.WHITE, 0.45))
	p.fill_rect(-half_w + 10.0, -boss.h + 8.0, boss.w - 20.0, 3.0, Color(Palette.WHITE, 0.18))
	p.fill_rect(-half_w + 8.0, -9.0, boss.w - 16.0, 5.0, Color(outline.darkened(0.5), 0.5))

	p.stroke_round_rect(-half_w, -boss.h, boss.w, boss.h, 6.0, outline, outline_width)

	if kind == BossState.Kind.BOUNCY_SLIME:
		var gap: float = 14.0 + sin(t / 180.0) * 2.0
		var aura: Color = Palette.FUCHSIA_400.lerp(Palette.RED_400, float(BossBouncySlime.phase_for(boss.durability)) / 2.0)
		p.fill_round_rect(-half_w - gap, -boss.h - gap, boss.w + gap * 2.0, boss.h + gap * 2.0, 8.0, Color(aura, 0.07))
		p.stroke_round_rect(-half_w - gap, -boss.h - gap, boss.w + gap * 2.0, boss.h + gap * 2.0, 8.0, Color(aura, 0.18), 7.0)
		p.stroke_round_rect(-half_w - gap, -boss.h - gap, boss.w + gap * 2.0, boss.h + gap * 2.0, 8.0, aura, 2.0)

	if kind == BossState.Kind.VOID_SLIME and filled >= BossVoidSlime.PHASE_3_FILLED and fmod(t, 350.0) < 160.0:
		# Phase 3: sparks arc between random cells.
		var beat: int = floori(t / 350.0)
		var from: Vector2 = _cell_center(beat % 3, (beat + 1) % 3, half_w, boss.h)
		var to: Vector2 = _cell_center((beat + 2) % 3, beat % 3, half_w, boss.h)
		var mid: Vector2 = (from + to) / 2.0 + Vector2(sin(t / 70.0), cos(t / 90.0)) * 12.0
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
				if not (sim.player.has_eating_target and sim.player.eating_target_is_boss_cell and sim.player.eating_target_r == r and sim.player.eating_target_c == c):
					TilePainter.draw(p, val, x, y, view.time_ms)
				continue
			if boss.eating_progress > 0.0:
				p.stroke_rect(x + 3.5, y + 3.5, _T - 7.0, _T - 7.0, Color(Palette.EMERALD_400, 0.35), 1.0)
				continue
			p.fill_rect(x + 2.0, y + 2.0, _T - 4.0, _T - 4.0, Palette.SLATE_900)
			p.dashed_rect(x + 3.5, y + 3.5, _T - 7.0, _T - 7.0, Palette.PURPLE_500, 2.0, 4.0)
			# The whole cell is lethal, so the whole cell glows.
			var pulse: float = 0.3 + sin(view.time_ms / 150.0) * 0.1
			p.fill_rect(x + 2.0, y + 2.0, _T - 4.0, _T - 4.0, Color(Palette.PURPLE_500, pulse))


## Mud golem: the body is nothing but the blocks it has absorbed.
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
			if boss.cell(anim.to_r, anim.to_c) == Tile.AIR:
				continue
			# Physics already uses the destination grid during the rearrangement.
			var dest_x: float = left + float(anim.to_c - boss.min_c) * _T
			var dest_y: float = top + float(anim.to_r - boss.min_r) * _T
			p.fill_rect(dest_x, dest_y, _T, _T, Color(Palette.AMBER_600, 0.12))
			p.stroke_rect(dest_x + 0.5, dest_y + 0.5, _T - 1.0, _T - 1.0, Color(Palette.AMBER_400, 0.45), 1.0)
			var f: float = clampf(
				(elapsed - float(anim.start_frame)) / float(anim.end_frame - anim.start_frame), 0.0, 1.0
			)
			f = smoothstep(0.0, 1.0, f)
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

	var airborne: bool = boss.state == BossState.State.JUMPING
	for r: int in range(boss.min_r, boss.max_r + 1):
		for c: int in range(boss.min_c, boss.max_c + 1):
			var val: int = boss.grid[r * n + c]
			if val == 0:
				continue
			var x: float = left + float(c - boss.min_c) * _T
			var y: float = top + float(r - boss.min_r) * _T
			if not (sim.player.has_eating_target and sim.player.eating_target_is_boss_cell and sim.player.eating_target_r == r and sim.player.eating_target_c == c):
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

func _paint_face(p: Painter, sim: GameSim, _pos: Vector2) -> void:
	var boss: BossState = sim.boss
	var is_mud_golem: bool = sim.boss_kind == BossState.Kind.MUD_GOLEM
	# The face sits on the core cell of the mud golem and in the upper middle of
	# the slime bosses.
	var face_x: float = 0.0
	var face_y: float = -boss.h / 1.7
	if is_mud_golem:
		face_x = -boss.w / 2.0 + (float(boss.center_c - boss.min_c) + 0.5) * _T
		face_y = -boss.h + (float(boss.center_r - boss.min_r) + 0.5) * _T

	var look: Vector2 = _motion.look
	var eye_x: float = look.x * 10.0
	var eye_y: float = look.y * 7.0
	var hungry: bool = boss.is_filled() or boss.eating_progress > 0.0

	p.push()
	p.translate(face_x, face_y)
	if boss.state == BossState.State.STUNNED or fmod(view.time_ms, BLINK_PERIOD_MS) < BLINK_LENGTH_MS:
		p.fill_round_rect(eye_x - 28.0, eye_y - 0.5, 15.0, 4.0, 2.0, Palette.SLATE_900)
		p.fill_round_rect(eye_x + 13.0, eye_y - 0.5, 15.0, 4.0, 2.0, Palette.SLATE_900)
	else:
		var spacing: float = lerpf(16.0, 13.0, absf(look.x))
		# Rounded like the player's eyes, so the bosses belong to the same world.
		p.fill_round_rect(eye_x - spacing - 7.0, eye_y - 14.0, 14.0, 26.0, 6.0, Palette.WHITE)
		p.fill_round_rect(eye_x + spacing - 7.0, eye_y - 14.0, 14.0, 26.0, 6.0, Palette.WHITE)
		var pupil: Color = Palette.RED_500
		if sim.boss_kind == BossState.Kind.GLASS_SLIME:
			pupil = Palette.CYAN_500
		elif hungry and sim.boss_kind != BossState.Kind.STEEL_CHASE:
			pupil = Palette.PURPLE_500
		p.fill_round_rect(eye_x - spacing - 3.0 + look.x * 2.0, eye_y - 7.0 + look.y * 2.0, 6.0, 14.0, 3.0, pupil)
		p.fill_round_rect(eye_x + spacing - 3.0 + look.x * 2.0, eye_y - 7.0 + look.y * 2.0, 6.0, 14.0, 3.0, pupil)
		var anger: float = _motion.tension
		if sim.boss_kind == BossState.Kind.BOUNCY_SLIME:
			anger = maxf(anger, float(BossBouncySlime.phase_for(boss.durability)) * 0.3)
		if anger > 0.05:
			p.line(eye_x - 30.0, eye_y - 20.0 - anger * 3.0, eye_x - 9.0, eye_y - 18.0 + anger * 4.0, Palette.SLATE_900, 3.0)
			p.line(eye_x + 9.0, eye_y - 18.0 + anger * 4.0, eye_x + 30.0, eye_y - 20.0 - anger * 3.0, Palette.SLATE_900, 3.0)
	p.pop()


# --- Status read-outs -------------------------------------------------------------

func _paint_status(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var kind: BossState.Kind = sim.boss_kind
	var t: float = view.time_ms

	if kind == BossState.Kind.GLASS_SLIME:
		# Its core shows the durability and its moves announce themselves.
		var winding: bool = false
		for shield: ShieldState in boss.shields:
			winding = winding or shield.winding_up
		if winding or not boss.bombs.is_empty():
			p.text("意圖：投擲玻璃" if winding else "玻璃投擲中", 0.0, -boss.h - 92.0, 11.0, Palette.CYAN_400, true)
		return
	if kind == BossState.Kind.BOUNCY_SLIME:
		_paint_durability(p, sim)
		return

	if boss.state == BossState.State.CHARGING:
		var bar_y: float = -boss.h - 25.0
		var progress: float = _charge_progress(boss)
		p.fill_round_rect(-70.0, bar_y, 140.0, 12.0, 6.0, Palette.PURPLE_400)
		p.fill_round_rect(-68.5, bar_y + 1.5, 137.0, 9.0, 4.5, Palette.SLATE_900)
		var color: Color = Palette.PURPLE_500 if fmod(t, 150.0) < 75.0 else Palette.PINK_500
		p.fill_round_rect(-68.0, bar_y + 2.0, 136.0 * progress, 8.0, 4.0, color)
		p.text("大招蓄力中…", 0.0, bar_y - 8.0, 11.0, Palette.PURPLE_100, true)
	elif boss.eating_progress > 0.0:
		var bar_y: float = -boss.h - 25.0
		p.fill_round_rect(-41.0, bar_y - 1.0, 82.0, 10.0, 5.0, Palette.PURPLE_400)
		p.fill_round_rect(-40.0, bar_y, 80.0, 8.0, 4.0, Palette.SLATE_900)
		p.fill_round_rect(-40.0, bar_y, 80.0 * minf(boss.eating_progress, 1.0), 8.0, 4.0, Palette.PURPLE_500)
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


## Hit points of the bouncy slime, and how soon its next leap comes.
func _paint_durability(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var t: float = view.time_ms
	var icons_y: float = -boss.h - 52.0
	var text_color: Color = Palette.PINK_100
	var phase: int = BossBouncySlime.phase_for(boss.durability)
	var label: String = ["護盾耐久", "狂怒・速度提升", "暴走・高速連彈"][phase]
	p.text(label, 0.0, icons_y - 14.0, 11.0, text_color, true)
	for i: int in BossState.MAX_DURABILITY:
		var x: float = float(i - 1) * 22.0
		p.icon_heart(x, icons_y, 16.0, Palette.PINK_500 if i < boss.durability else Palette.SLATE_700)

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
	p.fill_round_rect(-65.0, bar_y, 130.0, 8.0, 4.0, Palette.PINK_200)
	p.fill_round_rect(-64.0, bar_y + 1.0, 128.0, 6.0, 3.0, Palette.SLATE_900)
	var bar_color: Color = Palette.PINK_600
	if ready:
		bar_color = Palette.PINK_400 if fmod(t, 160.0) < 80.0 else Palette.PINK_500
	p.fill_round_rect(-63.5, bar_y + 1.5, 127.0 * progress, 5.0, 2.5, bar_color)
	var action_label: String
	if ready:
		action_label = "即將衝撞！"
	elif boss.state == BossState.State.CHARGING:
		action_label = "蓄力中 %d%%" % roundi(progress * 100.0)
	else:
		action_label = "休息中 %d%%" % roundi(progress * 100.0)
	p.text(action_label, 0.0, bar_y - 6.0, 9.0, text_color, true)

func _charge_progress(boss: BossState) -> float:
	if boss.max_charge_timer <= 0:
		return 1.0
	return clampf(1.0 - float(boss.charge_timer) / float(boss.max_charge_timer), 0.0, 1.0)


# --- Glass slime shields -------------------------------------------------------------

func _paint_shields(p: Painter, sim: GameSim) -> void:
	for shield: ShieldState in sim.boss.shields:
		if not shield.active:
			continue
		# Each shield is a glass tile.
		var at: Vector2 = view.tween_position(shield.prev_cx, shield.prev_cy, shield.cx, shield.cy)
		TilePainter.draw(p, Tile.GLASS, at.x - _T / 2.0, at.y - _T / 2.0, view.time_ms)
		if shield.winding_up:
			# The one about to be thrown flashes, faster as the throw nears.
			var left: float = clampf(float(shield.windup_timer) / float(ShieldState.WINDUP_TICKS), 0.0, 1.0)
			var flash: float = 0.45 + sin(view.time_ms / lerpf(22.0, 70.0, left)) * 0.4
			p.fill_round_rect(at.x - _T / 2.0, at.y - _T / 2.0, _T, _T, 9.0, Color(Palette.WHITE, flash))


## Thrown glass remains visible in flight and shatters at first contact.
func _paint_bombs(p: Painter, sim: GameSim) -> void:
	for bomb: GlassBomb in sim.boss.bombs:
		var at: Vector2 = view.tween_position(bomb.prev_x, bomb.prev_y, bomb.x, bomb.y)
		var size: float = BossGlassSlime.BOMB_RADIUS * 2.0
		var tail: Vector2 = at - Vector2(bomb.vx, bomb.vy).normalized() * 20.0
		p.line(tail.x, tail.y, at.x, at.y, Color(Palette.CYAN_400, 0.45), 3.0)
		p.push()
		p.translate(at.x - size / 2.0, at.y - size / 2.0)
		p.scale(size / _T, size / _T)
		TilePainter.draw(p, Tile.GLASS, 0.0, 0.0, view.time_ms)
		p.pop()

## The glass slime is a glass tile three cells across: the very same drawing,
## enlarged. Damage shows as a mirrored pair of cracks per point lost, and as
## the pips above it.
func _paint_glass_body(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var half_w: float = boss.w / 2.0
	p.push()
	p.translate(-half_w, -boss.h)
	p.scale(boss.w / _T, boss.h / _T)
	TilePainter.draw(p, Tile.GLASS, 0.0, 0.0, view.time_ms)
	p.pop()
	if boss.damage_flash > 0.0:
		p.fill_round_rect(-half_w, -boss.h, boss.w, boss.h, 27.0, Color(FLASH_COLOR, clampf(boss.damage_flash, 0.0, 1.0) * 0.6))

	var lost: int = BossState.MAX_DURABILITY - boss.durability
	var crack: Color = Color("1a8298")
	for side: float in [-1.0, 1.0]:
		if lost >= 1:
			p.polyline(PackedVector2Array([
				Vector2(side * 51.0, -boss.h + 24.0), Vector2(side * 38.0, -boss.h + 36.0), Vector2(side * 51.0, -boss.h + 50.0),
			]), crack, 4.0)
		if lost >= 2:
			p.polyline(PackedVector2Array([
				Vector2(side * 51.0, -24.0), Vector2(side * 38.0, -36.0), Vector2(side * 51.0, -50.0),
			]), crack, 4.0)

	# Durability pips, above the ring of shields.
	var stunned: bool = boss.state == BossState.State.STUNNED
	if stunned:
		for star: int in 3:
			var angle: float = view.time_ms / 450.0 + float(star) * TAU / 3.0
			var at: Vector2 = Vector2(cos(angle) * 35.0, -boss.h - 24.0 + sin(angle) * 7.0)
			p.fill_rect(at.x - 3.0, at.y - 1.0, 6.0, 2.0, Palette.YELLOW_200)
			p.fill_rect(at.x - 1.0, at.y - 3.0, 2.0, 6.0, Palette.YELLOW_200)
	for i: int in BossState.MAX_DURABILITY:
		var lit: bool = i < boss.durability
		var pip: Color = Palette.CYAN_400 if lit else Color("0f3a47")
		if lit and stunned and fmod(view.time_ms, 240.0) < 120.0:
			pip = Palette.WHITE
		p.fill_round_rect(float(i - 1) * 20.0 - 8.0, -boss.h - 62.0, 16.0, 10.0, 4.0, Color("1a8298"))
		p.fill_round_rect(float(i - 1) * 20.0 - 5.5, -boss.h - 59.5, 11.0, 5.0, 2.0, pip)

## The glass slime's coming slam or swoop, drawn in the arena. Amber while
## the mark still follows the player, red once it is committed.
func _paint_glass_warning(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.state != BossState.State.CHARGING and boss.state != BossState.State.JUMPING:
		return
	var progress: float = 1.0 if boss.state == BossState.State.JUMPING else _charge_progress(boss)
	if boss.current_move == BossGlassSlime.Move.REPAIR:
		var glow: Color = Color(Palette.CYAN_400, 0.3 + 0.5 * progress)
		p.stroke_circle(boss.center_x(), boss.center_y(), BossState.SHIELD_ORBIT_RADIUS + 24.0, glow, 2.5)
		p.text("意圖：修復護盾 +%d" % BossGlassSlime.repair_amount(boss), boss.center_x(), boss.y - 85.0, 14.0, Palette.CYAN_400, true)
		return
	var locked: bool = progress >= BossGlassSlime.TRACKING_SHARE
	var color: Color = Palette.RED_400 if locked else Palette.AMBER_400
	var blink: float = 0.55 + sin(view.time_ms / (40.0 if locked else 90.0)) * 0.25
	var lane: Color = Color(color, 0.07 + 0.09 * progress)
	if boss.current_move == BossGlassSlime.Move.SWOOP:
		# The arc, as the body swept along it, and an outline at its low point.
		var from: float = boss.swoop_progress if boss.state == BossState.State.JUMPING else 0.0
		var previous: Vector2 = BossGlassSlime.swoop_point(boss, from)
		var half: Vector2 = Vector2(boss.w, boss.h) / 2.0
		for i: int in range(1, 25):
			var t: float = lerpf(from, 1.0, float(i) / 24.0)
			var point: Vector2 = BossGlassSlime.swoop_point(boss, t)
			if previous.distance_to(point) > 0.5:
				p.line(previous.x + half.x, previous.y + half.y, point.x + half.x, point.y + half.y, lane, boss.h)
			previous = point
		var low: Vector2 = Vector2(boss.dive_x, boss.dive_floor_y - boss.h)
		p.stroke_round_rect(low.x, low.y, boss.w, boss.h, 27.0, Color(color, blink * 0.8), 2.5)
		return
	# The slam: the column under the body and the mark where it will rest.
	var x: float = boss.dive_x
	var floor_y: float = boss.dive_floor_y
	var top: float = boss.y + boss.h
	if floor_y > top:
		p.fill_rect(x, top, boss.w, floor_y - top, lane)
	p.fill_round_rect(x - 6.0, floor_y - 6.0, boss.w + 12.0, 6.0, 3.0, Color(color, blink))

# --- Leap telegraph -------------------------------------------------------------------

## While a boss charges, the path it is about to take is swept out as a
## band of faint boxes ending in an outlined landing box.
func _paint_leap_preview(p: Painter, sim: GameSim, pos: Vector2) -> void:
	var boss: BossState = sim.boss
	var start: Vector2 = pos + Vector2(boss.w / 2.0, boss.h / 2.0)
	var points: PackedVector2Array
	var color: Color
	if sim.boss_kind == BossState.Kind.BOUNCY_SLIME:
		# Show the upcoming motion, rather than overlapping an entire long
		# pinball combo across the screen and burying the player in warnings.
		points = _simulate_bouncing_leap(sim, start).slice(0, 90)
		color = Palette.PINK_600.lerp(Palette.RED_400, float(BossBouncySlime.phase_for(boss.durability)) / 2.0)
	elif sim.boss_kind == BossState.Kind.VOID_SLIME:
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
	if sim.boss_kind == BossState.Kind.BOUNCY_SLIME:
		# This is the end of the short preview, not necessarily a landing.
		p.stroke_circle(landing.x, landing.y, 7.0, Color(color.lightened(0.3), 0.75), 2.0)
		return
	p.fill_rect(
		landing.x - boss.w / 2.0, landing.y - boss.h / 2.0, boss.w, boss.h,
		Color(color, 0.25 + 0.35 * progress)
	)
	p.stroke_rect(
		landing.x - boss.w / 2.0, landing.y - boss.h / 2.0, boss.w, boss.h,
		Color(Palette.WHITE, 0.5 + 0.4 * progress), 2.5
	)


## The bouncy slime's leap: rebounds off blocks, walls and the ceiling, and bounces on
## the floor a number of times. Mirrors [BossBouncySlime].
func _simulate_bouncing_leap(sim: GameSim, start: Vector2) -> PackedVector2Array:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var half_w: float = boss.w / 2.0
	var half_h: float = boss.h / 2.0
	var x: float = start.x
	var y: float = start.y
	var vx: float = BossBouncySlime.leap_vx(BossSystem.player_dx(sim), boss.durability)
	var vy: float = -BossBouncySlime.leap_speed_for(boss.durability)
	var restitution: float = BossBouncySlime.restitution_for(boss.durability)
	var horizontal_limit: float = BossBouncySlime.horizontal_limit_for(boss.durability)
	var vertical_limit: float = BossBouncySlime.vertical_limit_for(boss.durability)
	var bounces: int = BossBouncySlime.bounces_for(boss.durability)
	var points: PackedVector2Array = PackedVector2Array([start])

	for _step: int in PREVIEW_TICKS:
		vy += BossBouncySlime.GRAVITY_LEAPING
		x += vx
		var hit_col: int = BossBouncySlime.wall_contact_column(level, x - half_w, y - half_h, boss.w, boss.h, vx)
		if hit_col >= 0:
			if vx > 0.0:
				x = float(hit_col) * _T - half_w - 0.1
			elif vx < 0.0:
				x = float(hit_col + 1) * _T + half_w + 0.1
			vx = -vx * restitution
		y += vy

		var right_limit: float = level.pixel_width() - _T - half_w
		if x < _T + half_w:
			x = _T + half_w
			vx = -vx * restitution
		elif x > right_limit:
			x = right_limit
			vx = -vx * restitution
		if y < _T + half_h:
			y = _T + half_h
			vy = -vy * restitution
		points.append(Vector2(x, y))

		var r_floor: int = floori((y + half_h) / _T)
		if vy >= 0.0 and _floor_under(sim, x, half_w, r_floor, false):
			y = float(r_floor) * _T - half_h
			if bounces <= 0:
				break
			bounces -= 1
			vy = -BossBouncySlime.leap_speed_for(boss.durability)
			if absf(vx) < 5.0:
				vx = (1.0 if vx >= 0.0 else -1.0) * (6.0 + BossBouncySlime.phase_for(boss.durability))
			else:
				vx *= restitution
		vx = clampf(vx, -horizontal_limit, horizontal_limit)
		vy = clampf(vy, -vertical_limit, vertical_limit)
	return points


## The void slime's ultimate: stops dead at the side walls, ploughs through every
## breakable block and only lands on steel. Mirrors [BossVoidSlime].
func _simulate_smashing_leap(sim: GameSim, start: Vector2) -> PackedVector2Array:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var half_w: float = boss.w / 2.0
	var half_h: float = boss.h / 2.0
	var x: float = start.x
	var y: float = start.y
	var vx: float = BossVoidSlime.mega_leap_vx(BossSystem.player_dx(sim))
	var vy: float = -BossVoidSlime.MEGA_JUMP_SPEED
	var points: PackedVector2Array = PackedVector2Array([start])

	for _step: int in PREVIEW_TICKS:
		vy += BossVoidSlime.GRAVITY
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
	if sim.boss_kind != BossState.Kind.VOID_SLIME:
		return
	if not (boss.is_filled() or boss.eating_progress > 0.0):
		return
	if not view.eat_held or sim.player.has_block or not BossVoidSlime.is_player_aiming_at_boss(sim):
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


func _paint_mechanism(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.state == BossState.State.SUSPENDED:
		return
	var data: BossState.MechanismData = boss.mechanism
	var color: Color = WorldCatalog.accent(BossMechanism.world_for(boss.kind))
	var pos: Vector2 = view.tween_position(boss.prev_x, boss.prev_y, boss.x, boss.y)
	if boss.kind == BossState.Kind.ICE_SKATER:
		var station: Vector2 = BossMechanism.cooling_station(sim)
		var in_station: bool = absf(boss.center_x() - station.x) <= 45.0
		var docked: bool = in_station and absf(boss.vx) < 0.5
		var station_color: Color = Palette.LIME_400 if docked else color
		p.fill_rect(station.x - 60.0, data.floor_y - 8.0, 120.0, 8.0, Color(station_color, 0.5))
		p.fill_rect(station.x - 60.0, data.floor_y - boss.h - 7.0, 120.0, 4.0, Palette.SLATE_900)
		p.fill_rect(station.x - 60.0, data.floor_y - boss.h - 7.0, 120.0 * float(data.dock_timer) / 60.0, 4.0, Palette.LIME_400)
		var status: String = "保持停穩" if docked else ("反向射擊煞停" if in_station else "推入冷卻站")
		p.text(status, station.x, data.floor_y - boss.h - 30.0, 10.0, station_color, true)
		p.stroke_round_rect(station.x - 60.0, data.floor_y - boss.h, 120.0, boss.h, 8.0, Color(color, 0.4), 2.0)
		p.text("冷卻站 %d · 低速停穩" % (data.progress + 1), station.x, data.floor_y - boss.h - 12.0, 11.0, color, true)
	elif boss.kind == BossState.Kind.SAND_COLOSSUS:
		p.stroke_round_rect(80.0, data.floor_y - 80.0, 80.0, 80.0, 8.0, Color(Palette.LIME_400, 0.5), 2.0)
		p.text("← 帶回沙核", 120.0, data.floor_y - 92.0, 12.0, Palette.LIME_400, true)
	elif boss.kind == BossState.Kind.RAIL_CARRIER:
		var route: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in data.path:
			route.append(point + Vector2(boss.w, boss.h) * 0.5)
		p.polyline(route, Color(color, 0.35), 5.0)
		for index: int in range(1, route.size()):
			var point: Vector2 = route[index]
			p.stroke_circle(point.x, point.y, 10.0, color, 2.0)
			p.text("站 %d" % index, point.x, point.y - 18.0, 11.0, color, true)
	if boss.state in [BossState.State.CHARGING, BossState.State.JUMPING]:
		for zone: Rect2 in data.zones:
			var active: bool = boss.state == BossState.State.JUMPING
			p.fill_rect(zone.position.x, zone.position.y, zone.size.x, zone.size.y, Color(color, 0.45 if active else 0.10))
			p.stroke_round_rect(zone.position.x, zone.position.y, zone.size.x, zone.size.y, 3.0, Color(color, 0.65), 2.0)
			p.icon_warning(zone.get_center().x, data.floor_y - 20.0, 20.0, color)
	p.stroke_round_rect(pos.x - 4.0, pos.y - 4.0, boss.w + 8.0, boss.h + 8.0, 12.0, Color(color, 0.55), 2.0)
	p.fill_round_rect(pos.x, pos.y, boss.w, boss.h, 9.0, WorldCatalog.fill(BossMechanism.world_for(boss.kind)).darkened(0.5))
	for row: int in 3:
		for col: int in 3:
			var type: int = BossMechanism.material(boss.kind)
			if row == 1 and col == 1:
				type = Tile.STEEL
			if boss.kind == BossState.Kind.SENSOR_SENTINEL:
				type = Tile.STEEL
			elif boss.kind == BossState.Kind.RAIL_CARRIER:
				type = boss.cell(row, col)
			elif boss.kind == BossState.Kind.SAND_COLOSSUS and row == boss.center_r and col == boss.center_c:
				type = Tile.AIR if data.core_stolen else Tile.SAND
			TilePainter.draw(p, type, pos.x + float(col) * _T, pos.y + float(row) * _T, view.time_ms)
	if boss.kind == BossState.Kind.SENSOR_SENTINEL:
		for cell: Vector2i in BossMechanism.sensor_ports():
			var rect: Rect2 = BossMechanism.port_rect(boss, cell)
			var at: Vector2 = rect.position + pos - Vector2(boss.x, boss.y)
			TilePainter.draw(p, boss.cell(cell.y, cell.x) if data.covered_ports.has(cell) else Tile.SENSOR, at.x, at.y, view.time_ms)
			p.line(at.x + 20.0, at.y + 20.0, pos.x + 60.0, pos.y + 60.0, Palette.LIME_400 if data.covered_ports.has(cell) else Color(color, 0.3), 3.0)
	elif boss.kind == BossState.Kind.RAIL_CARRIER:
		TilePainter.draw(p, Tile.SENSOR, pos.x + 40.0, pos.y - 20.0, view.time_ms)
		p.text("車頂補給", pos.x + 60.0, pos.y + boss.h + 16.0, 10.0, color, true)
	elif boss.kind == BossState.Kind.SAND_COLOSSUS and not data.core_stolen:
		p.stroke_circle(pos.x + 20.0, pos.y + 100.0, 23.0, Palette.YELLOW_200, 3.0)
		p.text("沙核", pos.x + 20.0, pos.y + 78.0, 10.0, Palette.YELLOW_200, true)
	if boss.damage_flash > 0.0:
		p.fill_round_rect(pos.x, pos.y, boss.w, boss.h, 9.0, Color(Palette.WHITE, boss.damage_flash * 0.5))
	p.push()
	p.translate(pos.x + boss.w * 0.5, pos.y + boss.h)
	_paint_face(p, sim, pos)
	p.pop()
	if boss.kind == BossState.Kind.ICE_SKATER:
		if absf(boss.vx) > 0.1:
			var direction: float = signf(boss.vx)
			var from: Vector2 = pos + Vector2(boss.w * 0.5, boss.h * 0.8)
			var tip: Vector2 = from + Vector2(direction * (24.0 + absf(boss.vx) * 7.0), 0.0)
			p.line(from.x, from.y, tip.x, tip.y, Color(color, 0.7), 3.0)
			p.line(tip.x, tip.y, tip.x - direction * 9.0, tip.y - 5.0, color, 2.0)
			p.line(tip.x, tip.y, tip.x - direction * 9.0, tip.y + 5.0, color, 2.0)
	var x: float = pos.x + boss.w * 0.5
	var y: float = pos.y - 72.0
	p.text(BossMechanism.name_for(boss.kind), x, y - 18.0, 13.0, color, true)
	var label: String = ""
	var progress: float = 0.0
	match boss.kind:
		BossState.Kind.SENSOR_SENTINEL:
			label = "感測端 %d / 3 · 同時覆蓋" % data.covered_ports.size()
			progress = float(data.dock_timer) / 90.0
			if data.covered_ports.size() == 3:
				label = "電路過載中！"
		BossState.Kind.ICE_SKATER:
			label = "冰壺冷卻 %d / 3 · 速度 %.1f" % [data.progress, absf(boss.vx)]
			progress = float(data.dock_timer) / 60.0
		BossState.Kind.SAND_COLOSSUS:
			label = "沙核已奪取 · 帶回左側入口" if data.core_stolen else "吞下左下方沙核"
			progress = clampf(1.0 - sim.player.x / maxf(1.0, data.origin.x), 0.0, 1.0) if data.core_stolen else 0.0
		BossState.Kind.RAIL_CARRIER:
			label = "運輸 %d / 3 · " % data.progress + ("訊號已收到" if data.signal_ready else "搭上車並送信號")
			if data.age >= 90 and not BossMechanism.riding(sim):
				label = "接回乘客 · 降回地面"
			progress = float(data.progress) / 3.0
		BossState.Kind.TNT_FURNACE:
			label = "拆彈回投 %d / 3" % (3 - boss.durability)
			progress = float(3 - boss.durability) / 3.0
	if boss.state == BossState.State.INTRO:
		label = "首領進場"
	p.text(label, x, y + 4.0, 11.0, color, true)
	p.fill_round_rect(x - 60.0, y + 12.0, 120.0, 5.0, 2.0, Palette.SLATE_900)
	p.fill_round_rect(x - 60.0, y + 12.0, 120.0 * clampf(progress, 0.0, 1.0), 5.0, 2.0, color)
	if boss.state == BossState.State.CHARGING and boss.kind != BossState.Kind.RAIL_CARRIER:
		p.text("招式預告 · %d%%" % roundi(_charge_progress(boss) * 100.0), x, y + 34.0, 10.0, color, true)
