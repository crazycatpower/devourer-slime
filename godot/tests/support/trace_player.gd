class_name TracePlayer
extends RefCounted
## Replays a reference trace (see `tools/parity/make_reference.mjs`) through a
## [GameSim], one tick at a time.

const BIT_LEFT: int = 1
const BIT_RIGHT: int = 2
const BIT_JUMP: int = 4
const BIT_EAT: int = 8
const BIT_SHOOT: int = 16

var sim: GameSim = GameSim.new()
var trace_name: String = ""
var tick: int = 0
var tick_total: int = 0
## Sound ids requested during the most recent tick, as a digit string.
var heard: String = ""
var fields: Array = []
var states: Array = []
var sounds: Array = []

var _inputs: Array = []
var _interventions: Array = []
var _immortal: bool = false
var _prev_bits: int = 0


## Loads the gzip-compressed trace at [param path]. Returns false on failure.
func load_trace(path: String) -> bool:
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if packed.is_empty():
		return false
	var raw: PackedByteArray = packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary:
		return false
	var trace: Dictionary = parsed
	trace_name = trace["name"]
	fields = trace["fields"]
	states = trace["states"]
	sounds = trace["sfx"]
	_inputs = trace["inputs"]
	_interventions = trace["interventions"]
	_immortal = trace["immortal"]
	tick_total = _inputs.size()

	var slot: int = _to_int(trace["slot"])
	sim.rng.set_seed(_to_int(trace["seed"]))
	sim.sfx_requested.connect(_on_sfx_requested)
	sim.load_level(slot, LevelLibrary.built_in_level(slot), LevelLibrary.boss_kind_for_slot(slot))
	return true


func is_finished() -> bool:
	return tick >= tick_total


## Simulates the next tick exactly as the reference harness did.
func advance() -> void:
	var tick_number: int = tick + 1
	heard = ""
	for item: Dictionary in _interventions:
		if _to_int(item["tick"]) == tick_number:
			var op: String = item["op"]
			_intervene(op, _to_int(item["value"]))

	var entry: Array = _inputs[tick]
	var bits: int = _to_int(entry[0])
	var inp: SimInput = SimInput.new()
	inp.left = bits & BIT_LEFT != 0
	inp.right = bits & BIT_RIGHT != 0
	inp.jump = bits & BIT_JUMP != 0
	inp.eat = bits & BIT_EAT != 0
	inp.shoot = bits & BIT_SHOOT != 0
	inp.jump_pressed = inp.jump and _prev_bits & BIT_JUMP == 0
	inp.shoot_released = not inp.shoot and _prev_bits & BIT_SHOOT != 0
	inp.mouse_x = entry[1]
	inp.mouse_y = entry[2]
	_prev_bits = bits

	sim.step(inp)
	sim.update_camera()
	if _immortal:
		_revive()
	tick = tick_number


## The same values, in the same order, as `snapshot()` in the reference harness.
func snapshot() -> PackedFloat64Array:
	var p: PlayerState = sim.player
	var b: BossState = sim.boss
	var out: PackedFloat64Array = PackedFloat64Array()
	out.append(p.x)
	out.append(p.y)
	out.append(p.vx)
	out.append(p.vy)
	out.append(float(
		(1 if p.grounded else 0) | (2 if p.dead else 0) | (4 if p.won else 0)
		| (8 if p.has_block else 0) | (16 if p.in_bullet_time else 0)
		| (32 if p.is_jumping else 0) | (64 if p.waiting_for_shoot_release else 0)
		| (128 if p.facing > 0 else 0)
	))
	out.append(float(p.carried_block_type * 10 + p.carried_block_eaten_count))
	out.append(p.eating_progress)
	out.append(p.fall_start_y)
	out.append(float(p.coyote_timer + 100 * p.jump_buffer + 10000 * p.wall_bounce_timer))
	out.append(p.scale_x)
	out.append(p.scale_y)

	if sim.boss_kind == BossState.Kind.NONE:
		for _i: int in 15:
			out.append(0.0)
	else:
		out.append(float(
			(1 if b.active else 0) | (2 if b.dead else 0) | (4 if b.grounded else 0)
		))
		out.append(b.x)
		out.append(b.y)
		out.append(b.vx)
		out.append(b.vy)
		out.append(b.w)
		out.append(b.h)
		out.append(float(b.state))
		out.append(float(b.cooldown))
		out.append(float(b.grid_checksum()))
		out.append(b.eating_progress)
		out.append(float(b.durability))
		out.append(b.scale_x)
		out.append(b.scale_y)
		out.append(b.damage_flash)

	out.append(float(sim.level.checksum()))
	var projectile_sum: float = 0.0
	for q: SimProjectile in sim.projectiles:
		projectile_sum += q.x + q.y + q.vx + q.vy
	out.append(float(sim.projectiles.size()))
	out.append(projectile_sum)
	var particle_sum: float = 0.0
	for q: SimParticle in sim.particles:
		particle_sum += q.x + q.y
	out.append(float(sim.particles.size()))
	out.append(particle_sum)
	var falling_sum: float = 0.0
	for q: SimFallingBlock in sim.falling_blocks:
		falling_sum += q.x + q.y + float(q.delay)
	out.append(float(sim.falling_blocks.size()))
	out.append(falling_sum)
	out.append(sim.camera.x)
	out.append(sim.camera.y)
	out.append(sim.camera.shake)
	out.append(float(sim.death_timer))
	return out


## Mirrors `revive()` in the reference harness.
func _revive() -> void:
	var player: PlayerState = sim.player
	if player.dead:
		player.dead = false
		sim.death_timer = 0
	if player.y > sim.level.pixel_height():
		player.x = Tile.SIZE * 2.0 + 3.0
		player.y = Tile.SIZE * 2.0 + 3.0
		player.vx = 0.0
		player.vy = 0.0
		player.recoil_vx = 0.0
		player.fall_start_y = player.y


## Test-only state edits; each mirrors `intervene()` in the reference harness.
func _intervene(op: String, value: int) -> void:
	var player: PlayerState = sim.player
	var boss: BossState = sim.boss
	match op:
		"give_block":
			if not player.has_block:
				player.has_block = true
				player.carried_block_type = value
				player.carried_block_eaten_count = 1
				player.waiting_for_shoot_release = false
		"boss_durability":
			boss.durability = value
		"boss_eating_progress":
			boss.eating_progress = float(value) / 100.0
		"boss_fill":
			for r: int in 3:
				for c: int in 3:
					if r == 1 and c == 1:
						continue
					if boss.filled_count() >= value:
						return
					if boss.cell(r, c) == 0:
						boss.set_cell(r, c, Tile.DIRT_EATEN_2)
		"boss_strip":
			for i: int in boss.grid.size():
				if boss.grid[i] != Tile.GOAL:
					boss.grid[i] = Tile.AIR
			BossWorld1.update_bounds(sim)
		_:
			push_error("TracePlayer: unknown intervention '%s'" % op)


func _on_sfx_requested(id: Sfx.Id, _param: float, _delay_sec: float) -> void:
	heard += str(int(id))


## JSON numbers arrive as floats.
static func _to_int(value: Variant) -> int:
	var number: float = value
	return int(number)
