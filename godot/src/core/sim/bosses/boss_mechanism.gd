class_name BossMechanism
extends RefCounted
## Five material-specific encounters in the unchanged standard boss room.
## Each encounter has its own objective, material rules and announced hazards.

const INTRO_TICKS: int = 90
const HIT_RECOVERY: int = 30


static func is_kind(kind: BossState.Kind) -> bool:
	return kind in [BossState.Kind.SENSOR_SENTINEL, BossState.Kind.ICE_SKATER, BossState.Kind.SAND_COLOSSUS, BossState.Kind.RAIL_CARRIER, BossState.Kind.TNT_FURNACE]


static func world_for(kind: BossState.Kind) -> int:
	return 6 + int(kind) - int(BossState.Kind.SENSOR_SENTINEL)


static func material(kind: BossState.Kind) -> int:
	match kind:
		BossState.Kind.SENSOR_SENTINEL: return Tile.SENSOR
		BossState.Kind.ICE_SKATER: return Tile.ICE
		BossState.Kind.SAND_COLOSSUS: return Tile.SAND
		BossState.Kind.RAIL_CARRIER: return Tile.RAIL_RIGHT
	return Tile.TNT


static func name_for(kind: BossState.Kind) -> String:
	match kind:
		BossState.Kind.SENSOR_SENTINEL: return "感測監督者"
		BossState.Kind.ICE_SKATER: return "冰霜滑行者"
		BossState.Kind.SAND_COLOSSUS: return "流砂巨像"
		BossState.Kind.RAIL_CARRIER: return "軌道運輸者"
	return "TNT 熔爐"


static func phase(boss: BossState) -> int:
	if boss.kind == BossState.Kind.SENSOR_SENTINEL:
		return mini(2, boss.mechanism.covered_ports.size())
	if boss.kind in [BossState.Kind.ICE_SKATER, BossState.Kind.RAIL_CARRIER]:
		return mini(2, boss.mechanism.progress)
	if boss.kind == BossState.Kind.SAND_COLOSSUS:
		return 2 if boss.mechanism.core_stolen else 0
	return clampi(BossState.MAX_DURABILITY - boss.durability, 0, 2)


static func charge_ticks(boss: BossState) -> int:
	return 90 - phase(boss) * 12


static func rest_ticks(boss: BossState) -> int:
	return 100 - phase(boss) * 20


static func hint(kind: BossState.Kind) -> String:
	match kind:
		BossState.Kind.SENSOR_SENTINEL: return "同時覆蓋左、上、右三個感測端，保持通電使電路過載"
		BossState.Kind.ICE_SKATER: return "射擊推動冰壺；反向射擊先煞停，在亮起的冷卻站停穩"
		BossState.Kind.SAND_COLOSSUS: return "吞下左下沙核並帶回左側入口；吐出會把沙核送回"
		BossState.Kind.RAIL_CARRIER: return "吞下車頂補給，射擊頭頂感測器發車，搭車走完三站"
	return "靠近點燃 TNT 按住吞噬拆彈；拉開距離，吐回熔爐引爆三次"

static func setup(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.x = BossSystem.spawn_x(sim.level, boss.w)
	boss.prev_x = boss.x
	boss.grid.fill(material(boss.kind))
	boss.set_cell(1, 1, Tile.GOAL)
	var floor_y: float = sim.level.pixel_height() - Tile.SIZE
	var col: int = Tile.cell_of(boss.center_x())
	for row: int in range(2, sim.level.rows):
		if Tile.is_solid(sim.level.get_cell(row, col)):
			floor_y = float(row) * Tile.SIZE
			break
	boss.mechanism.floor_y = maxf(Tile.SIZE + boss.h, floor_y)
	boss.mechanism.origin = Vector2(boss.x, boss.mechanism.floor_y - boss.h)
	if boss.kind == BossState.Kind.SAND_COLOSSUS:
		boss.center_r = 2
		boss.center_c = 0
		boss.grid.fill(Tile.SAND)
	if boss.kind == BossState.Kind.RAIL_CARRIER:
		boss.set_cell(0, 0, Tile.DIRT)
		boss.set_cell(0, 2, Tile.DIRT)
		var at: Vector2 = boss.mechanism.origin
		var right: float = minf(sim.level.pixel_width() - Tile.SIZE - boss.w, at.x + 320.0)
		var top: float = maxf(Tile.SIZE, at.y - 150.0)
		boss.mechanism.path = PackedVector2Array([at, Vector2(at.x, top), Vector2(right, top), Vector2(right, at.y)])
		boss.mechanism.path_index = 1
	boss.cooldown = rest_ticks(boss)
	boss.max_cooldown = boss.cooldown
	sim.mechanisms_enabled = true


static func update(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var data: BossState.MechanismData = boss.mechanism
	boss.damage_flash = maxf(0.0, boss.damage_flash - 0.05)
	data.recovery = maxi(0, data.recovery - 1)
	if boss.state == BossState.State.SUSPENDED:
		if BossSystem.player_in_trigger_range(sim):
			BossSystem.begin_intro(sim, INTRO_TICKS)
			boss.intro_duration = boss.intro_timer
			data.origin = Vector2(boss.x, data.floor_y - boss.h)
			sim.play(Sfx.Id.LAND)
		return
	if boss.state == BossState.State.INTRO:
		boss.intro_timer -= 1
		var progress: float = 1.0 - float(boss.intro_timer) / maxf(1.0, boss.intro_duration)
		boss.y = lerpf(BossState.SPAWN_Y, data.origin.y, smoothstep(0.0, 1.0, progress))
		if boss.intro_timer <= 0:
			boss.state = BossState.State.ACTIVE
			boss.grounded = true
			_supply(sim)
			sim.spawn_particles(boss.center_x(), data.floor_y, WorldCatalog.accent(world_for(boss.kind)), 18, 3.0)
			sim.add_shake(6.0)
		return
	if boss.kind == BossState.Kind.SENSOR_SENTINEL and data.covered_ports.size() == 3:
		boss.state = BossState.State.STUNNED
		data.zones.clear()
		data.dock_timer += 1
		if data.dock_timer >= 90:
			_finish(sim, Vector2(boss.center_x(), boss.center_y()))
		return
	data.dock_timer = 0 if boss.kind == BossState.Kind.SENSOR_SENTINEL else data.dock_timer
	if boss.kind == BossState.Kind.SENSOR_SENTINEL and boss.state == BossState.State.STUNNED:
		_rest(sim)
	if boss.kind == BossState.Kind.ICE_SKATER:
		_skate(sim)
		if boss.dead:
			return
	if boss.kind == BossState.Kind.RAIL_CARRIER:
		_ride_route(sim)
		return
	if boss.kind == BossState.Kind.SAND_COLOSSUS and data.core_stolen and sim.player.has_sand_core and sim.player.x < Tile.SIZE * 4.0:
		_finish(sim, Vector2(sim.player.center_x(), sim.player.center_y()))
		return
	match boss.state:
		BossState.State.ACTIVE:
			boss.cooldown -= 1
			if boss.cooldown <= 0:
				_begin_attack(sim)
		BossState.State.CHARGING:
			boss.charge_timer -= 1
			if boss.charge_timer > int(float(boss.max_charge_timer) * 0.45):
				_mark_target(sim)
			if boss.charge_timer <= 0:
				_launch(sim)
		BossState.State.JUMPING:
			_attack(sim)
	data.supply_timer -= 1
	if data.supply_timer <= 0:
		_supply(sim)

static func _rest(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.cooldown = rest_ticks(boss)
	boss.max_cooldown = boss.cooldown
	if boss.kind != BossState.Kind.ICE_SKATER:
		boss.vx = 0.0
	boss.vy = 0.0
	boss.mechanism.zones.clear()


static func _open(sim: GameSim) -> void:
	# Rail signals command transport rather than exposing a damage window.
	sim.boss.mechanism.signal_ready = true
	sim.play(Sfx.Id.LAND)

static func _begin_attack(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.state = BossState.State.CHARGING
	boss.charge_timer = charge_ticks(boss)
	boss.max_charge_timer = boss.charge_timer
	boss.mechanism.origin = Vector2(boss.x, boss.y)
	boss.mechanism.age = 0
	_mark_target(sim)
	_supply(sim)
	sim.play(Sfx.Id.BOUNCE)


static func _mark_target(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var data: BossState.MechanismData = boss.mechanism
	data.target = Vector2(clampf(sim.player.center_x(), Tile.SIZE + 60.0, sim.level.pixel_width() - Tile.SIZE - 60.0), data.floor_y)
	data.zones.clear()
	match boss.kind:
		BossState.Kind.SENSOR_SENTINEL:
			for index: int in 1 + phase(boss):
				var x: float = data.target.x + float(index - phase(boss)) * 110.0
				data.zones.append(Rect2(x - 12.0, Tile.SIZE, 24.0, data.floor_y - Tile.SIZE))
		BossState.Kind.ICE_SKATER:
			data.zones.append(Rect2(floorf(data.target.x / Tile.SIZE) * Tile.SIZE, Tile.SIZE, Tile.SIZE, data.floor_y - Tile.SIZE))
		BossState.Kind.SAND_COLOSSUS, BossState.Kind.TNT_FURNACE:
			for index: int in 1 + phase(boss):
				var col: int = clampi(Tile.cell_of(data.target.x) + (index - phase(boss)) * 3, 1, sim.level.cols - 2)
				data.zones.append(Rect2(float(col) * Tile.SIZE, Tile.SIZE, Tile.SIZE, data.floor_y - Tile.SIZE))
		BossState.Kind.RAIL_CARRIER:
			pass


static func _launch(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var data: BossState.MechanismData = boss.mechanism
	boss.state = BossState.State.JUMPING
	data.age = 0
	match boss.kind:
		BossState.Kind.SAND_COLOSSUS, BossState.Kind.ICE_SKATER:
			var type: int = Tile.SAND if boss.kind == BossState.Kind.SAND_COLOSSUS else Tile.ICE
			for zone: Rect2 in data.zones:
				_drop(sim, Tile.cell_of(zone.position.x), type, 30, true)
			_rest(sim)
		BossState.Kind.TNT_FURNACE:
			for zone: Rect2 in data.zones:
				MechanismSystem.arm_tnt(sim, Vector2(zone.get_center().x, data.floor_y - Tile.SIZE * 0.5), MechanismSystem.TNT_FUSE_TICKS, true)
			_rest(sim)

static func _attack(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.mechanism.age += 1
	if boss.kind == BossState.Kind.SENSOR_SENTINEL:
		var player_box: Rect2 = Rect2(sim.player.x, sim.player.y, sim.player.w, sim.player.h)
		for zone: Rect2 in boss.mechanism.zones:
			if zone.intersects(player_box) and sim.kill_player():
				sim.play(Sfx.Id.HURT)
		if boss.mechanism.age >= 22 + phase(boss) * 6:
			_rest(sim)

static func detector_rect(boss: BossState) -> Rect2:
	return Rect2(boss.center_x() - Tile.SIZE * 0.5, boss.y - Tile.SIZE * 0.5, Tile.SIZE, Tile.SIZE)


static func hit_by_projectile(sim: GameSim, shot: SimProjectile, cx: float, cy: float, preview: bool = false) -> bool:
	var boss: BossState = sim.boss
	if boss.state in [BossState.State.SUSPENDED, BossState.State.INTRO] or boss.dead:
		return false
	var shot_box: Rect2 = Rect2(cx - shot.w * 0.5, cy - shot.h * 0.5, shot.w, shot.h)
	var detector: bool = boss.kind == BossState.Kind.RAIL_CARRIER and detector_rect(boss).intersects(shot_box)
	var port: Vector2i = Vector2i(-1, -1)
	if boss.kind == BossState.Kind.SENSOR_SENTINEL:
		for cell: Vector2i in sensor_ports():
			if port_rect(boss, cell).intersects(shot_box):
				port = cell
				break
	if not detector and port.x < 0 and not Rect2(boss.x, boss.y, boss.w, boss.h).intersects(shot_box):
		return false
	if preview:
		return true
	match boss.kind:
		BossState.Kind.SENSOR_SENTINEL:
			if port.x >= 0 and not boss.mechanism.covered_ports.has(port) and shot.type != Tile.TNT:
				boss.mechanism.covered_ports[port] = true
				boss.set_cell(port.y, port.x, shot.type)
				sim.play(Sfx.Id.LAND)
				sim.spawn_particles(cx, cy, Palette.LIME_400, 12, 2.0)
		BossState.Kind.ICE_SKATER:
			var impulse: float = shot.vx * (0.33 if shot.type == Tile.ICE else 0.25)
			# A braking shot cannot unexpectedly launch the curling stone backwards.
			if boss.vx * impulse < 0.0:
				boss.vx = move_toward(boss.vx, 0.0, absf(impulse))
			else:
				boss.vx = clampf(boss.vx + impulse, -8.0, 8.0)
			boss.mechanism.dock_timer = 0
			sim.spawn_particles(cx, cy, Palette.SKY_400, 8, 2.0)
			sim.play(Sfx.Id.LAND)
		BossState.Kind.RAIL_CARRIER:
			if detector:
				_open(sim)
	return true

static func hit_by_blast(sim: GameSim, center: Vector2, returned_charge: bool = false) -> void:
	var boss: BossState = sim.boss
	if boss.kind != BossState.Kind.TNT_FURNACE or boss.dead or not returned_charge or boss.state in [BossState.State.SUSPENDED, BossState.State.INTRO]:
		return
	var nearest: Vector2 = Vector2(clampf(center.x, boss.x, boss.x + boss.w), clampf(center.y, boss.y, boss.y + boss.h))
	if nearest.distance_squared_to(center) <= MechanismSystem.BLAST_RADIUS * MechanismSystem.BLAST_RADIUS:
		_damage(sim)

static func _damage(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.mechanism.recovery > 0:
		return
	boss.durability -= 1
	boss.mechanism.recovery = HIT_RECOVERY
	boss.damage_flash = 1.0
	sim.add_shake(8.0)
	sim.play(Sfx.Id.HURT)
	sim.spawn_particles(boss.center_x(), boss.center_y(), WorldCatalog.accent(world_for(boss.kind)), 18, 4.0)
	if boss.durability <= 0:
		_finish(sim, Vector2(boss.center_x(), boss.center_y()))



static func _drop(sim: GameSim, col: int, type: int, delay: int, lethal: bool) -> void:
	FallingBlockSystem.spawn(sim, col, type, delay, WorldCatalog.accent(world_for(sim.boss.kind)))
	var block: SimFallingBlock = sim.falling_blocks.back()
	block.fixed_landing_type = true
	block.lethal = lethal
	block.y = maxf(Tile.SIZE + Tile.SIZE * 0.5, sim.boss.y - Tile.SIZE)
	block.prev_y = block.y


static func _supply(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.mechanism.supply_timer = 180
	if boss.kind == BossState.Kind.TNT_FURNACE:
		return
	if boss.kind == BossState.Kind.RAIL_CARRIER:
		boss.set_cell(0, 0, Tile.DIRT)
		boss.set_cell(0, 2, Tile.DIRT)
	var count: int = sim.falling_blocks.size()
	for row: int in sim.level.rows:
		for col: int in sim.level.cols:
			if Tile.is_eatable(sim.level.get_cell(row, col)):
				count += 1
	if count >= 8:
		return
	var type: int = material(boss.kind)
	if not Tile.is_eatable(type):
		type = Tile.DIRT
	# Choose an empty landing column outside the body and the player's feet.
	var candidates: Array[int] = [Tile.cell_of(boss.x) - 4, Tile.cell_of(boss.x) - 6, Tile.cell_of(boss.x + boss.w) + 4, Tile.cell_of(boss.x + boss.w) + 6]
	var row: int = clampi(Tile.cell_of(boss.mechanism.floor_y) - 1, 1, sim.level.rows - 2)
	for candidate: int in candidates:
		var col: int = clampi(candidate, 1, sim.level.cols - 2)
		var landing: Rect2 = Rect2(float(col) * Tile.SIZE, float(row) * Tile.SIZE, Tile.SIZE, Tile.SIZE)
		if sim.level.get_cell(row, col) != Tile.AIR or landing.intersects(Rect2(sim.player.x, sim.player.y, sim.player.w, sim.player.h)):
			continue
		_drop(sim, col, type, 0, false)
		return


static func sensor_ports() -> Array[Vector2i]:
	return [Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 1)]


static func port_rect(boss: BossState, cell: Vector2i) -> Rect2:
	var at: Vector2 = Vector2(boss.cell_x(cell.x), boss.cell_y(cell.y))
	if cell == Vector2i(1, 0):
		at.y -= Tile.SIZE * 0.5
	return Rect2(at, Vector2.ONE * Tile.SIZE)


static func cooling_station(sim: GameSim) -> Vector2:
	var locations: Array[float] = [0.25, 0.75, 0.5]
	var index: int = mini(2, sim.boss.mechanism.progress)
	return Vector2(sim.level.pixel_width() * locations[index], sim.boss.mechanism.floor_y - sim.boss.h * 0.5)


static func _skate(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.x += boss.vx
	boss.vx = move_toward(boss.vx, 0.0, 0.012)
	if boss.x < Tile.SIZE or boss.x > sim.level.pixel_width() - Tile.SIZE - boss.w:
		boss.x = clampf(boss.x, Tile.SIZE, sim.level.pixel_width() - Tile.SIZE - boss.w)
		boss.vx *= -0.65
	var station: Vector2 = cooling_station(sim)
	if absf(boss.center_x() - station.x) <= 45.0 and absf(boss.vx) < 0.5:
		boss.mechanism.dock_timer += 1
		if boss.mechanism.dock_timer >= 60:
			boss.mechanism.progress += 1
			boss.mechanism.dock_timer = 0
			sim.spawn_particles(station.x, boss.center_y(), Palette.SKY_400, 22, 3.0)
			sim.add_shake(3.0)
			if boss.mechanism.progress == 3:
				_finish(sim, Vector2(boss.center_x(), boss.center_y()))
			else:
				_rest(sim)
				boss.cooldown += 60
				boss.max_cooldown = boss.cooldown
				_supply(sim)
				sim.play(Sfx.Id.LAND)
	else:
		boss.mechanism.dock_timer = 0


static func riding(sim: GameSim) -> bool:
	var boss: BossState = sim.boss
	return absf(sim.player.y + sim.player.h - boss.y) <= 6.0 and sim.player.x + sim.player.w > boss.x and sim.player.x < boss.x + boss.w


static func _ride_route(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var data: BossState.MechanismData = boss.mechanism
	# Recover a lost passenger without requiring an unreachable jump.
	data.age = 0 if riding(sim) else data.age + 1
	if data.age >= 90 and boss.y < data.floor_y - boss.h:
		boss.y = move_toward(boss.y, data.floor_y - boss.h, 3.0)
		boss.vx = 0.0
		boss.vy = 3.0
		return
	if not data.signal_ready:
		for cell: Vector2i in sim.powered_cells:
			if detector_rect(boss).grow(Tile.SIZE).has_point((Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE):
				data.signal_ready = true
	if boss.state == BossState.State.ACTIVE:
		data.supply_timer -= 1
		if data.supply_timer <= 0:
			_supply(sim)
		if data.signal_ready and riding(sim):
			boss.state = BossState.State.CHARGING
			boss.charge_timer = 45
			boss.max_charge_timer = 45
		return
	if boss.state == BossState.State.CHARGING:
		boss.charge_timer -= 1
		if boss.charge_timer <= 0:
			boss.state = BossState.State.JUMPING
		return
	if not riding(sim):
		boss.vx = 0.0
		boss.vy = 0.0
		return
	var previous: Vector2 = Vector2(boss.x, boss.y)
	var destination: Vector2 = data.path[data.path_index]
	var next: Vector2 = Vector2(previous.x, destination.y) if absf(previous.y - destination.y) > 0.001 else destination
	var at: Vector2 = previous.move_toward(next, 3.0 + float(data.progress) * 0.6)
	boss.x = at.x
	boss.y = at.y
	boss.vx = at.x - previous.x
	boss.vy = at.y - previous.y
	sim.player.x += boss.vx
	sim.player.y += boss.vy
	if at.is_equal_approx(destination):
		data.progress += 1
		data.path_index += 1
		data.signal_ready = false
		_supply(sim)
		_rest(sim)
		if data.progress >= 3:
			_finish(sim, Vector2(sim.player.center_x(), sim.player.center_y()))


static func take_sand_core(sim: GameSim) -> void:
	sim.player.has_sand_core = true
	sim.boss.mechanism.core_stolen = true
	sim.boss.cooldown = 30
	sim.boss.state = BossState.State.ACTIVE


static func return_sand_core(sim: GameSim) -> void:
	sim.player.has_sand_core = false
	if sim.boss.kind == BossState.Kind.SAND_COLOSSUS and not sim.boss.dead:
		sim.boss.mechanism.core_stolen = false
		sim.boss.set_cell(sim.boss.center_r, sim.boss.center_c, Tile.SAND)


static func eat_charge(sim: GameSim, charge: GameSim.TntCharge) -> void:
	var player: PlayerState = sim.player
	if not sim.tnt_charges.has(charge) or not charge.boss_owned:
		player.clear_eating()
		return
	if player.eating_charge != charge:
		player.clear_eating()
		player.eating_charge = charge
	player.eating_progress += 1.0 / 8.0
	if player.eating_progress < 1.0:
		return
	sim.tnt_charges.erase(charge)
	player.has_block = true
	player.carried_block_type = Tile.TNT
	player.carried_block_eaten_count = 0
	player.has_furnace_charge = true
	player.waiting_for_shoot_release = true
	player.clear_eating()
	sim.play(Sfx.Id.EAT)


static func _finish(sim: GameSim, at: Vector2) -> void:
	var boss: BossState = sim.boss
	BossSystem.defeat(sim)
	boss.mechanism.zones.clear()
	sim.falling_blocks.clear()
	for charge: GameSim.TntCharge in sim.tnt_charges.duplicate():
		if charge.boss_owned:
			sim.tnt_charges.erase(charge)
	var col: int = clampi(Tile.cell_of(at.x), 1, sim.level.cols - 2)
	var row: int = clampi(Tile.cell_of(at.y), 1, sim.level.rows - 2)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if sim.level.is_interior(row + dy, col + dx):
				sim.level.set_cell(row + dy, col + dx, Tile.AIR)
	sim.level.set_cell(row, col, Tile.GOAL)
	sim.play(Sfx.Id.WIN)
