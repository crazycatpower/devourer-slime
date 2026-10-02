class_name PlayerLayer
extends WorldLayer
## The player slime: a squashy rounded body, the block it carries, and eyes
## that follow the aim.

const BODY_COLOR: Color = Color(Palette.GREEN_500, 0.9)
const CARRIED_SIZE: float = 20.0
const BLINK_PERIOD_MS: float = 4000.0
const BLINK_LENGTH_MS: float = 150.0
const GAUGE_WIDTH: float = 36.0
const GAUGE_HEIGHT: float = 4.0
## Distance from the top of the slime up to the gauge.
const GAUGE_GAP: float = 12.0
## Below this the gauge turns red.
const GAUGE_LOW: float = 0.25


func _paint(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	if player.dead:
		return
	var pos: Vector2 = view.tween_position(player.prev_x, player.prev_y, player.x, player.y)
	var w: float = player.w
	var h: float = player.h

	p.push()
	# Squash and stretch pivot on the feet.
	p.translate(pos.x + w / 2.0, pos.y + h)
	if player.grounded and absf(player.vx) > 0.5:
		p.rotate(sin(view.time_ms / 60.0) * 0.1)
	p.scale(player.scale_x, player.scale_y)

	var radius: float = 16.0 if player.has_block else 12.0
	p.fill_round_rect(-w / 2.0, -h, w, h, radius, BODY_COLOR)
	p.stroke_round_rect(-w / 2.0, -h, w, h, radius, Palette.GREEN_600, 2.0)

	if player.has_block:
		_paint_carried_block(p, player)
	_paint_eyes(p, sim)
	p.pop()

	if view.bullet_time_energy < 1.0 and view.editor == null:
		_paint_bullet_time_gauge(p, pos.x + w / 2.0, pos.y - GAUGE_GAP)


## A small bar over the slime's head, shown while bullet time is being used
## or is still recharging.
func _paint_bullet_time_gauge(p: Painter, center_x: float, y: float) -> void:
	var left: float = center_x - GAUGE_WIDTH / 2.0
	var energy: float = clampf(view.bullet_time_energy, 0.0, 1.0)
	var color: Color = Palette.SKY_400 if energy > GAUGE_LOW else Palette.RED_400
	p.fill_rect(left - 1.0, y - 1.0, GAUGE_WIDTH + 2.0, GAUGE_HEIGHT + 2.0, Color(Palette.SLATE_900, 0.8))
	p.fill_rect(left, y, GAUGE_WIDTH * energy, GAUGE_HEIGHT, color)


## The swallowed block shows through the body, darker the more it is worn.
func _paint_carried_block(p: Painter, player: PlayerState) -> void:
	var bx: float = -CARRIED_SIZE / 2.0
	var by: float = -player.h / 2.0 - CARRIED_SIZE / 2.0
	var worn: int = player.carried_block_eaten_count
	var fill: Color
	var border: Color
	if player.carried_block_type == Tile.BOUNCY:
		fill = Palette.PINK_900 if worn >= 2 else Palette.PINK_700
		border = Palette.GREEN_500 if worn >= 2 else Palette.PINK_200
	else:
		fill = Palette.AMBER_900 if worn >= 2 else Palette.AMBER_700
		border = Palette.GREEN_500 if worn >= 2 else Palette.AMBER_500
	p.fill_rect(bx, by, CARRIED_SIZE, CARRIED_SIZE, fill)
	p.stroke_rect(bx + 0.5, by + 0.5, CARRIED_SIZE - 1.0, CARRIED_SIZE - 1.0, border, 1.5)
	p.fill_rect(bx + 3.0, by + 3.0, 14.0, 14.0, Color(Palette.GREEN_600, 0.45))


func _paint_eyes(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	var mouse: Vector2 = view.mouse_in_view()
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, mouse.x, mouse.y)
	var look_x: float = aim.x
	var look_y: float = aim.y
	var reach: float = minf(1.0, aim.mag / 150.0)
	if not aim.aiming or view.editor != null:
		look_x = float(player.facing)
		look_y = 0.0
		reach = 0.67
	var ex: float = look_x * 6.0 * reach
	var ey: float = look_y * 6.0 * reach
	var top: float = -player.h

	if fmod(view.time_ms, BLINK_PERIOD_MS) < BLINK_LENGTH_MS:
		p.fill_rect(ex - 6.0, top + 14.0 + ey, 6.0, 2.0, Palette.SLATE_900)
		p.fill_rect(ex, top + 14.0 + ey, 6.0, 2.0, Palette.SLATE_900)
		return
	p.fill_rect(ex - 6.0, top + 10.0 + ey, 6.0, 10.0, Palette.WHITE)
	p.fill_rect(ex, top + 10.0 + ey, 6.0, 10.0, Palette.WHITE)
	var pupil_x: float = look_x * 2.0
	var pupil_y: float = look_y * 2.0
	p.fill_rect(ex - 4.0 + pupil_x, top + 13.0 + ey + pupil_y, 2.0, 4.0, Palette.SLATE_900)
	p.fill_rect(ex + 2.0 + pupil_x, top + 13.0 + ey + pupil_y, 2.0, 4.0, Palette.SLATE_900)
