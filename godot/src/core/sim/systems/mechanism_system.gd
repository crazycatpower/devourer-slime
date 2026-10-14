class_name MechanismSystem
extends RefCounted
## Grid mechanisms, with separate wire topology and deterministic tick timing.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const RAIL_TICKS: int = 12
const FALL_TICKS: int = 6
const SLIDE_TICKS: int = 4
const TNT_FUSE_TICKS: int = 24
const BLAST_RADIUS: float = Tile.SIZE * 2.5
const KILL_RADIUS: float = Tile.SIZE * 1.5


static func initialize(sim: GameSim) -> void:
	sim.mechanisms_enabled = not sim.level.wires.is_empty() or not sim.level.sensors.is_empty() or not sim.level.rails.is_empty()
	for row: int in sim.level.rows:
		for col: int in sim.level.cols:
			if sim.level.get_cell(row, col) in [Tile.SENSOR, Tile.RAIL_LEFT, Tile.RAIL_RIGHT, Tile.SAND, Tile.ICE, Tile.TNT]:
				sim.mechanisms_enabled = true
				return


static func is_connector(level: LevelGrid, cell: Vector2i) -> bool:
	var type: int = level.get_cell(cell.y, cell.x)
	return level.wires.has(cell) or level.sensors.has(cell) or level.rails.has(cell) or type == Tile.TNT


static func update(sim: GameSim) -> void:
	if not sim.mechanisms_enabled:
		return
	_update_signals(sim)
	if _detonate_powered_tnt(sim):
		_update_signals(sim)
	if sim.player.dead:
		return
	if sim.tick_count % SLIDE_TICKS == 0:
		_update_sliding(sim)
	if sim.tick_count % FALL_TICKS == 0:
		_update_sand(sim)
	if sim.tick_count % RAIL_TICKS == 0:
		_update_rails(sim)
	# Moving onto a detector must activate receivers immediately in this tick.
	_update_signals(sim)
	if _detonate_powered_tnt(sim):
		_update_signals(sim)


static func _detonate_powered_tnt(sim: GameSim) -> bool:
	var armed: Array[Vector2i] = []
	for cell: Vector2i in sim.level.tnt_cells:
		if sim.powered_cells.has(cell):
			armed.append(cell)
	for cell: Vector2i in armed:
		if sim.level.get_cell(cell.y, cell.x) == Tile.TNT:
			detonate_cell(sim, cell)
	return not armed.is_empty()


static func _update_signals(sim: GameSim) -> void:
	var queue: Array[Vector2i] = []
	if sim.signal_grid != sim.level or sim.signal_revision != sim.level.signal_revision:
		sim.signal_detectors.clear()
		for cell: Vector2i in sim.level.sensors:
			sim.signal_detectors.append(cell)
		# Stable row order preserves transport behavior regardless of import order.
		# Source coverage changes every tick; detector ordering only changes with topology.
		sim.signal_detectors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
	for cell: Vector2i in sim.signal_detectors:
		if _sensor_covered(sim, cell):
			queue.append(cell)
	if sim.signal_grid == sim.level and sim.signal_revision == sim.level.signal_revision and sim.signal_sources == queue:
		return
	sim.signal_grid = sim.level
	sim.signal_revision = sim.level.signal_revision
	sim.signal_sources = queue.duplicate()
	sim.powered_cells.clear()
	for cell: Vector2i in queue:
		sim.powered_cells[cell] = true
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = cell + direction
			if sim.level.in_bounds(next.y, next.x) and not sim.powered_cells.has(next) and is_connector(sim.level, next):
				sim.powered_cells[next] = true
				queue.append(next)


static func _sensor_covered(sim: GameSim, cell: Vector2i) -> bool:
	if Tile.is_solid(sim.level.get_cell(cell.y, cell.x)):
		return true
	if sim.projectiles.is_empty() and sim.falling_blocks.is_empty():
		return false
	var region: Rect2 = Rect2(Vector2(cell) * Tile.SIZE, Vector2.ONE * Tile.SIZE)
	for block: SimProjectile in sim.projectiles:
		if not block.dead and region.intersects(Rect2(block.x, block.y, block.w, block.h)):
			return true
	for block: SimFallingBlock in sim.falling_blocks:
		if block.delay <= 0 and region.intersects(Rect2(block.x - Tile.SIZE * 0.5, block.y - Tile.SIZE * 0.5, Tile.SIZE, Tile.SIZE)):
			return true
	return false


static func _update_sand(sim: GameSim) -> void:
	# Snapshot and bottom-first order: every grain moves at most once.
	var grains: Array[Vector2i] = []
	for cell: Vector2i in sim.level.sand_cells:
		grains.append(cell)
	grains.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y or (a.y == b.y and a.x < b.x)
	)
	for cell: Vector2i in grains:
		if not sim.level.rails.has(cell):
			_move(sim, cell, Vector2i.DOWN, FALL_TICKS)


static func start_slide(sim: GameSim, cell: Vector2i, velocity: float, ceiling: bool = false) -> void:
	if absf(velocity) < 0.1 or not Tile.is_movable(sim.level.get_cell(cell.y, cell.x)):
		return
	sim.mechanisms_enabled = true
	sim.sliding_cells[cell] = int(signf(velocity))
	if sim.level.get_cell(cell.y, cell.x) == Tile.ICE and (
		ceiling or (Tile.is_solid(sim.level.get_cell(cell.y - 1, cell.x)) and not Tile.is_solid(sim.level.get_cell(cell.y + 1, cell.x)))
	):
		sim.ceiling_slides[cell] = true
	else:
		sim.ceiling_slides.erase(cell)


static func _update_sliding(sim: GameSim) -> void:
	var previous: Dictionary[Vector2i, int] = sim.sliding_cells.duplicate()
	var ceilings: Dictionary[Vector2i, bool] = sim.ceiling_slides.duplicate()
	sim.sliding_cells.clear()
	sim.ceiling_slides.clear()
	var moved: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in previous:
		if moved.has(cell):
			continue
		var type: int = sim.level.get_cell(cell.y, cell.x)
		if not Tile.is_movable(type):
			continue
		if sim.level.rails.has(cell):
			continue
		var direction: int = previous[cell]
		var support: int = sim.level.get_cell(cell.y + 1, cell.x)
		# Ice keeps its own momentum on ordinary floors too.
		if type != Tile.ICE and support != Tile.ICE:
			continue
		var next: Vector2i = cell + Vector2i(direction, 0)
		if _move(sim, cell, Vector2i(direction, 0), SLIDE_TICKS):
			moved[next] = true
			if sim.level.get_cell(next.y, next.x) != type:
				continue  # Shattered on spikes or left the level.
			var on_ceiling: bool = type == Tile.ICE and ceilings.has(cell) and Tile.is_solid(sim.level.get_cell(cell.y - 1, cell.x)) and Tile.is_solid(sim.level.get_cell(next.y - 1, next.x))
			if not on_ceiling and not Tile.is_solid(sim.level.get_cell(next.y + 1, next.x)):
				if _move(sim, next, Vector2i.DOWN, SLIDE_TICKS):
					next += Vector2i.DOWN
			if sim.level.in_bounds(next.y, next.x) and sim.level.get_cell(next.y, next.x) == type:
				sim.sliding_cells[next] = direction
				if on_ceiling:
					sim.ceiling_slides[next] = true


static func _update_rails(sim: GameSim) -> void:
	if sim.level.rails.is_empty():
		return
	# Cells a block has moved into this step. They count as taken, and their
	# block is not moved again: one cell per block per step.
	var arrived: Dictionary[Vector2i, bool] = {}
	# Snapshot avoids transporting the same block repeatedly across a rail row.
	var origins: Array[Vector2i] = []
	for cell: Vector2i in sim.powered_cells:
		if sim.level.rails.has(cell):
			origins.append(cell)
	for rail: Vector2i in origins:
		_advance_on_rail(sim, rail, arrived, {})


## Moves the block on the powered rail at [param cell] one cell along it. When
## the next cell holds another block that the rail is about to carry on too,
## that one goes first, so blocks standing in an unbroken row travel together
## instead of waiting for a gap. [param waiting] holds the cells already asked
## in this chain; a closed ring of blocks with no free cell cannot start.
static func _advance_on_rail(
	sim: GameSim, cell: Vector2i, arrived: Dictionary[Vector2i, bool], waiting: Dictionary[Vector2i, bool]
) -> bool:
	if arrived.has(cell) or waiting.has(cell):
		return false
	if not sim.powered_cells.has(cell) or not sim.level.rails.has(cell):
		return false
	if not Tile.is_movable(sim.level.get_cell(cell.y, cell.x)):
		return false
	var direction: Vector2i = Tile.rail_direction(sim.level.rails[cell])
	var next: Vector2i = cell + direction
	if not sim.level.rails.has(next):
		return false
	if sim.level.get_cell(cell.y, cell.x) in [Tile.ICE, Tile.SAND] and sharp_spike(sim.level.get_cell(next.y, next.x)):
		return _move(sim, cell, direction, RAIL_TICKS)
	if sim.level.in_bounds(next.y, next.x) and sim.level.get_cell(next.y, next.x) != Tile.AIR:
		# Something is in the way. If it is a block riding on, let it move off first.
		waiting[cell] = true
		if not _advance_on_rail(sim, next, arrived, waiting):
			return false
	if not _move(sim, cell, direction, RAIL_TICKS):
		return false
	arrived[next] = true
	return true

## Never overwrite a device, wall, goal or another block. The player never
## holds a block up: standing where it is going, they are pushed out of the
## way, and a rider with no room to go along is left behind. The block travels
## to its new cell over [param duration] ticks, and is solid where it has got
## to rather than where it is going; [method carry_player] moves whoever
## stands on it.
static func _move(sim: GameSim, from: Vector2i, direction: Vector2i, duration: int = RAIL_TICKS) -> bool:
	var to: Vector2i = from + direction
	var type: int = sim.level.get_cell(from.y, from.x)
	if not sim.level.in_bounds(to.y, to.x):
		if to.y >= sim.level.rows:
			sim.level.set_cell(from.y, from.x, Tile.AIR)
			sim.sliding_cells.erase(from)
			sim.ceiling_slides.erase(from)
			return true
		return false
	if sim.level.get_cell(to.y, to.x) != Tile.AIR:
		if type in [Tile.ICE, Tile.SAND] and sharp_spike(sim.level.get_cell(to.y, to.x)):
			shatter_block(sim, from)
			return true
		return false
	var player: PlayerState = sim.player
	var carrying: bool = player.grounded and absf(player.y + player.h - float(from.y) * Tile.SIZE) < 1.0 and player.x + player.w > float(from.x) * Tile.SIZE and player.x < float(from.x + 1) * Tile.SIZE
	var offset: Vector2 = Vector2(direction) * Tile.SIZE
	sim.level.set_cell(from.y, from.x, Tile.AIR)
	sim.level.set_cell(to.y, to.x, type)
	sim.animate_tile_move(from, to, duration)
	if sim.sliding_cells.has(from):
		sim.sliding_cells[to] = sim.sliding_cells[from]
		sim.sliding_cells.erase(from)
	if sim.ceiling_slides.has(from):
		sim.ceiling_slides.erase(from)
		sim.ceiling_slides[to] = true
	if carrying and not player.dead:
		# The block has already made the first step of its trip this tick.
		_ride(sim, offset / float(maxi(1, duration)))
	if player.has_eating_target and not player.eating_target_is_boss_cell and Vector2i(player.eating_target_c, player.eating_target_r) == from:
		# The bite stays on the block as it moves on. Swallowing takes longer
		# than one step of a rail, so starting over each step would never finish.
		player.set_eating_target(to.y, to.x, false)
	return true


static func sharp_spike(type: int) -> bool:
	return type != Tile.VOID and Tile.is_spike(type)


## Full block coverage, so a flying ice/sand corner touching a spike counts.
## A void is a different mechanic and still accepts blocks as plugs.
static func fragile_hits_spikes(level: LevelGrid, box: Rect2) -> bool:
	var first: Vector2i = Vector2i(floori(box.position.x / Tile.SIZE), floori(box.position.y / Tile.SIZE))
	var last: Vector2i = Vector2i(floori((box.end.x - Collision.SKIN) / Tile.SIZE), floori((box.end.y - Collision.SKIN) / Tile.SIZE))
	for row: int in range(maxi(0, first.y), mini(level.rows - 1, last.y) + 1):
		for col: int in range(maxi(0, first.x), mini(level.cols - 1, last.x) + 1):
			var type: int = level.get_cell(row, col)
			if sharp_spike(type) and Tile.hazard_hits(box.position.x, box.position.y, box.size.x, box.size.y, row, col, type):
				return true
	return false


static func shatter_block(sim: GameSim, cell: Vector2i) -> void:
	var type: int = sim.level.get_cell(cell.y, cell.x)
	var position: Vector2 = Vector2(cell) * Tile.SIZE
	if sim.tile_motions.has(cell):
		position = sim.tile_motions[cell].position_at(sim.tick_count)
	sim.level.set_cell(cell.y, cell.x, Tile.AIR)
	sim.sliding_cells.erase(cell)
	sim.ceiling_slides.erase(cell)
	sim.tile_motions.erase(cell)
	if sim.player.has_eating_target and not sim.player.eating_target_is_boss_cell and Vector2i(sim.player.eating_target_c, sim.player.eating_target_r) == cell:
		sim.player.clear_eating()
	sim.spawn_particles(position.x + Tile.SIZE / 2.0, position.y + Tile.SIZE / 2.0, GameSim.debris_color(type), 16, 4.5)
	sim.play(Sfx.Id.LAND)


## Moves the player along with the blocks in transit, once per tick and before
## the player moves on their own: a player standing on such a block rides it,
## and one who is in its way is pushed ahead of it. Being pushed into a wall
## is left to the crush check.
static func carry_player(sim: GameSim) -> void:
	if sim.tile_motions.is_empty():
		return
	var player: PlayerState = sim.player
	if player.dead or player.won:
		return
	var now: float = float(sim.tick_count)
	var riding: bool = false
	for cell: Vector2i in sim.tile_motions:
		var motion: GameSim.TileMotion = sim.tile_motions[cell]
		if not motion.transport or sim.level.get_cell(cell.y, cell.x) != motion.type or not Tile.is_solid(motion.type):
			continue
		var before: Vector2 = motion.position_at(now - 1.0)
		var at: Vector2 = motion.position_at(now)
		var step: Vector2 = at - before
		if step.is_zero_approx():
			continue
		var on_top: bool = (
			player.grounded and absf(player.y + player.h - before.y) < 1.5
			and player.x + player.w > before.x and player.x < before.x + Tile.SIZE
		)
		if on_top:
			# Standing across two moving blocks still means one ride.
			if not riding:
				_ride(sim, step)
				riding = true
			continue
		var in_the_way: bool = (
			player.x < at.x + Tile.SIZE and player.x + player.w > at.x
			and player.y < at.y + Tile.SIZE and player.y + player.h > at.y
		)
		if not in_the_way:
			continue
		if step.x > 0.0:
			player.x = at.x + Tile.SIZE + Collision.SKIN
		elif step.x < 0.0:
			player.x = at.x - player.w - Collision.SKIN
		elif step.y > 0.0:
			player.y = at.y + Tile.SIZE + Collision.SKIN
		else:
			player.y = at.y - player.h - Collision.SKIN
			player.vy = minf(player.vy, 0.0)
			player.grounded = true


## Takes the player [param step] along with the block under them, unless
## something solid is in the way: then they stay put and the block goes on
## without them.
static func _ride(sim: GameSim, step: Vector2) -> void:
	var player: PlayerState = sim.player
	if not sim.solid_boxes(player.x + step.x, player.y + step.y, player.w, player.h).is_empty():
		return
	player.x += step.x
	player.y += step.y


## Consume the carried charge before its chain reaction, so a second axis
## collision cannot detonate it again in the same tick.
static func detonate_carried_tnt(sim: GameSim) -> bool:
	var player: PlayerState = sim.player
	if player.dead or player.won or player.ability_type() != Tile.TNT:
		return false
	player.has_block = false
	player.carried_block_type = Tile.AIR
	player.carried_block_eaten_count = 0
	player.in_bullet_time = false
	player.waiting_for_shoot_release = false
	player.clear_eating()
	arm_tnt(sim, Vector2(player.center_x(), player.center_y()), TNT_FUSE_TICKS, false, player.has_furnace_charge)
	player.has_furnace_charge = false
	return true


static func detonate_cell(sim: GameSim, cell: Vector2i) -> void:
	if sim.level.get_cell(cell.y, cell.x) != Tile.TNT:
		return
	sim.level.set_cell(cell.y, cell.x, Tile.AIR)
	sim.sliding_cells.erase(cell)
	sim.ceiling_slides.erase(cell)
	var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE
	if sim.tile_motions.has(cell):
		center = sim.tile_motions[cell].position_at(sim.tick_count) + Vector2.ONE * Tile.SIZE * 0.5
	sim.tile_motions.erase(cell)
	arm_tnt(sim, center)


## Arming consumes the source once; repeated signals cannot restart its fuse.
static func arm_tnt(sim: GameSim, center: Vector2, ticks: int = TNT_FUSE_TICKS, boss_owned: bool = false, returned_charge: bool = false) -> void:
	var charge: GameSim.TntCharge = GameSim.TntCharge.new()
	charge.center = center
	charge.boss_owned = boss_owned
	charge.returned_charge = returned_charge
	charge.explode_tick = sim.tick_count + maxi(1, ticks)
	sim.tnt_charges.append(charge)


static func update_tnt(sim: GameSim) -> void:
	# Snapshot prevents a newly primed chain charge from expiring in this pass.
	for charge: GameSim.TntCharge in sim.tnt_charges.duplicate():
		if sim.tick_count >= charge.explode_tick:
			sim.tnt_charges.erase(charge)
			explode(sim, charge.center, not charge.boss_owned, charge.returned_charge)


## Apply one blast; nearby TNT gets its own 0.4-second warning.
static func explode(sim: GameSim, center: Vector2, affect_boss: bool = true, returned_charge: bool = false) -> void:
	if affect_boss:
		BossMechanism.hit_by_blast(sim, center, returned_charge)
	var col: int = Tile.cell_of(center.x)
	var row: int = Tile.cell_of(center.y)
	for r: int in range(maxi(0, row - 3), mini(sim.level.rows, row + 4)):
		for c: int in range(maxi(0, col - 3), mini(sim.level.cols, col + 4)):
			var target: Vector2 = (Vector2(c, r) + Vector2.ONE * 0.5) * Tile.SIZE
			if target.distance_squared_to(center) > BLAST_RADIUS * BLAST_RADIUS:
				continue
			var type: int = sim.level.get_cell(r, c)
			if type == Tile.TNT:
				detonate_cell(sim, Vector2i(c, r))
			elif Tile.is_movable(type):
				sim.level.set_cell(r, c, Tile.AIR)
				sim.sliding_cells.erase(Vector2i(c, r))
				sim.ceiling_slides.erase(Vector2i(c, r))
			# Wires are vulnerable but steel and fixed devices survive.
			sim.level.set_wire(Vector2i(c, r), false)
	for projectile: SimProjectile in sim.projectiles:
		if projectile.type == Tile.TNT and not projectile.dead and Vector2(projectile.x + projectile.w * 0.5, projectile.y + projectile.h * 0.5).distance_squared_to(center) <= BLAST_RADIUS * BLAST_RADIUS:
			projectile.dead = true
			arm_tnt(sim, Vector2(projectile.x + projectile.w * 0.5, projectile.y + projectile.h * 0.5), projectile.fuse_ticks if projectile.fuse_ticks > 0 else TNT_FUSE_TICKS, false, projectile.returned_charge)
	var player: PlayerState = sim.player
	var nearest: Vector2 = Vector2(clampf(center.x, player.x, player.x + player.w), clampf(center.y, player.y, player.y + player.h))
	var kill_radius: float = KILL_RADIUS
	if nearest.distance_squared_to(center) <= kill_radius * kill_radius and sim.kill_player():
		sim.play(Sfx.Id.HURT)
	sim.spawn_particles(center.x, center.y, Palette.RED_400, 20, 6.0)
	sim.spawn_particles(center.x, center.y, Palette.AMBER_400, 12, 4.0)
	sim.add_shake(16.0)
	sim.play(Sfx.Id.BOUNCE)
