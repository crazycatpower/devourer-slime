class_name BackdropLayer
extends WorldLayer
## Drifting spores behind the level, with a little parallax.

const STAR_COUNT: int = 60
const FIELD_WIDTH: float = 5000.0
const FIELD_HEIGHT: float = 2000.0
const COLORS: Array[Color] = [
	Palette.SLATE_800, Palette.SLATE_700, Palette.SLATE_600, Palette.SKY_400, Palette.EMERALD_400,
]


class Star:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var size: float = 2.0
	var speed: float = 0.1
	var color: Color = Color.WHITE


var _stars: Array[Star] = []
var _last_time_ms: float = -1.0


func _ready() -> void:
	for _i: int in STAR_COUNT:
		var star: Star = Star.new()
		star.x = randf() * FIELD_WIDTH
		star.y = randf() * FIELD_HEIGHT
		star.size = randf() * 3.0 + 1.2
		star.speed = randf() * 0.15 + 0.05
		star.color = Color(COLORS[randi() % COLORS.size()], 0.47)
		_stars.append(star)


func _paint(p: Painter, sim: GameSim) -> void:
	# Drift at a fixed speed whatever the frame rate.
	var frames: float = 0.0
	if _last_time_ms >= 0.0:
		frames = clampf((view.time_ms - _last_time_ms) * 0.06, 0.0, 6.0)
	_last_time_ms = view.time_ms

	var wrap_w: float = sim.level.pixel_width() + 400.0
	var wrap_h: float = sim.level.pixel_height() + 400.0
	var camera: Vector2 = view.camera_position
	for star: Star in _stars:
		star.x = fposmod(star.x - star.speed * frames, FIELD_WIDTH)
		var px: float = fmod(star.x - camera.x * (star.size * 0.12), wrap_w)
		if px < -50.0:
			px += wrap_w
		var py: float = fmod(star.y - camera.y * (star.size * 0.08), wrap_h)
		if py < -50.0:
			py += wrap_h
		p.fill_rect(px, py, star.size, star.size, star.color)
