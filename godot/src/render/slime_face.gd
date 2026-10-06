class_name SlimeFace
extends RefCounted
## Large pixel eyes shared by the mascot and player. No mouth or blush.

const EYE_WIDTH: float = 7.0
const EYE_HEIGHT: float = 14.0


static func paint(p: Painter, motion: SlimeMotion, look: Vector2) -> void:
	var direction: Vector2 = Vector2(clampf(look.x, -1.0, 1.0), clampf(look.y, -1.0, 1.0))
	var ex: float = direction.x * 5.0
	var ey: float = direction.y * 4.0
	# The pair converges toward the side the slime is looking at.
	var separation: float = lerpf(5.5, 4.15, absf(direction.x))
	if motion.wince > 0.5:
		_paint_squeezed(p, ex, ey, separation)
		return
	var closed: float = maxf(motion.blink, motion.wince * 2.0)
	# Alarm opens the eyes wide; dizziness leaves them heavy-lidded.
	var open_h: float = EYE_HEIGHT + motion.alarm * 2.5 - motion.daze * 3.0
	var pupil_w: float = lerpf(3.0, 2.0, motion.alarm)
	for side: float in [-1.0, 1.0]:
		var eye_x: float = 16.5 + side * separation
		var eye_h: float = lerpf(open_h, 1.5, closed)
		var eye_y: float = 18.0 - eye_h * 0.5 + ey
		p.fill_rect(eye_x + ex, eye_y, EYE_WIDTH, eye_h, Palette.WHITE)
		if closed < 0.8:
			var pupil_h: float = eye_h * lerpf(0.55, 0.3, motion.alarm)
			var pupil_x: float = (EYE_WIDTH - pupil_w) * 0.5 + direction.x * 1.4
			var pupil_y: float = lerpf(eye_h * 0.25, (eye_h - pupil_h) * 0.5, motion.alarm) + direction.y * 1.4
			if motion.daze > 0.0:
				# The pupils circle in opposite directions.
				var swirl: float = motion.daze_age * 9.0 + (PI if side > 0.0 else 0.0)
				pupil_x += cos(swirl) * 1.6 * motion.daze
				pupil_y += sin(swirl) * 2.4 * motion.daze
			pupil_x = clampf(pupil_x, 0.0, EYE_WIDTH - pupil_w)
			pupil_y = clampf(pupil_y, 0.0, eye_h - pupil_h)
			p.fill_rect(eye_x + ex + pupil_x, eye_y + pupil_y, pupil_w, pupil_h, Palette.SLATE_900)
		else:
			p.fill_rect(eye_x + ex, eye_y, EYE_WIDTH, eye_h, Palette.SLATE_900)


## Eyes squeezed shut after an impact: stepped pixel chevrons pointing inward, > <.
static func _paint_squeezed(p: Painter, ex: float, ey: float, separation: float) -> void:
	for side: float in [-1.0, 1.0]:
		var eye_x: float = 16.5 + side * separation + ex
		for row: int in 5:
			var inset: float = float(2 - absi(row - 2)) * 1.75
			var x: float = eye_x + inset if side < 0.0 else eye_x + EYE_WIDTH - 3.5 - inset
			p.fill_rect(x, 12.5 + ey + float(row) * 2.2, 3.5, 2.2, Palette.SLATE_900)
