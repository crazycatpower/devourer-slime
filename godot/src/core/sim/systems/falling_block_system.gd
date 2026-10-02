class_name FallingBlockSystem
extends RefCounted
## Blocks that boss attacks shake loose from the ceiling.
##
## A block waits behind a warning column, falls, kills the player on touch,
## and turns into a random tile where it lands.

const HALF: float = Tile.SIZE / 2.0
const FALL_ACCELERATION: float = 0.3


static func update(sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	var player: PlayerState = sim.player
	for i: int in range(sim.falling_blocks.size() - 1, -1, -1):
		var fb: SimFallingBlock = sim.falling_blocks[i]
		if fb.delay > 0:
			fb.delay -= 1
			continue
		fb.vy += FALL_ACCELERATION
		fb.y += fb.vy

		var col: int = floori(fb.x / Tile.SIZE)
		var row: int = floori(fb.y / Tile.SIZE)

		var overlaps_player: bool = not (
			player.x + player.w <= fb.x - HALF or player.x >= fb.x + HALF
			or player.y + player.h <= fb.y - HALF or player.y >= fb.y + HALF
		)
		if overlaps_player and sim.kill_player():
			sim.spawn_particles(player.center_x(), player.center_y(), Palette.BLACK, 40, 8.0)
			sim.spawn_particles(player.center_x(), player.center_y(), Palette.RED_500, 20, 6.0)
			sim.play(Sfx.Id.HURT)

		if row >= 1 and row < level.rows and col >= 0 and col < level.cols:
			var current_cell: int = level.get_cell(row, col)
			var rand_type: int = _roll_landing_type(sim)

			# A block that drops into a void trap plugs it.
			if current_cell == Tile.VOID:
				var plug: int = Tile.DIRT_EATEN_2
				if rand_type == Tile.BOUNCY:
					plug = Tile.BOUNCY_EATEN_2
				elif rand_type == Tile.GLASS:
					plug = Tile.GLASS
				level.set_cell(row, col, plug)
				sim.spawn_particles(
					float(col) * Tile.SIZE + HALF, float(row) * Tile.SIZE + HALF,
					_landing_color(rand_type, false), 25, 5.5
				)
				sim.play(Sfx.Id.BOUNCE)
				sim.falling_blocks.remove_at(i)
				continue

			if Tile.is_solid(current_cell):
				var land_row: int = row - 1
				if land_row >= 1 and level.get_cell(land_row, col) == Tile.AIR:
					level.set_cell(land_row, col, rand_type)
					sim.spawn_particles(
						float(col) * Tile.SIZE + 20.0, float(land_row) * Tile.SIZE + 20.0,
						_landing_color(rand_type, true), 20, 5.0
					)
					sim.play(Sfx.Id.LAND)
				sim.falling_blocks.remove_at(i)
		elif row >= level.rows:
			sim.falling_blocks.remove_at(i)


## Queues a block above column [param col].
static func spawn(sim: GameSim, col: int, type: int, delay: int, warning_color: Color) -> void:
	var fb: SimFallingBlock = SimFallingBlock.new()
	fb.x = float(col) * Tile.SIZE + HALF
	fb.y = -40.0
	fb.prev_x = fb.x
	fb.prev_y = fb.y
	fb.vy = 2.0
	fb.type = type
	fb.delay = delay
	fb.warning_color = warning_color
	sim.falling_blocks.append(fb)


## The tile a block becomes on landing gets nastier as the boss fills up.
static func _roll_landing_type(sim: GameSim) -> int:
	var roll: float = sim.rng.next_float()
	var filled: int = sim.boss.filled_count()
	if filled >= 7:
		if roll < 0.60:
			return Tile.VOID
		if roll < 0.75:
			return Tile.BOUNCY
		if roll < 0.80:
			return Tile.GLASS
		return Tile.DIRT
	if filled >= 4:
		if roll < 0.25:
			return Tile.VOID
		if roll < 0.50:
			return Tile.BOUNCY
		if roll < 0.65:
			return Tile.GLASS
		return Tile.DIRT
	if roll < 0.15:
		return Tile.BOUNCY
	if roll < 0.20:
		return Tile.GLASS
	if roll < 0.28:
		return Tile.VOID
	return Tile.DIRT


static func _landing_color(type: int, void_is_purple: bool) -> Color:
	if type == Tile.VOID and void_is_purple:
		return Palette.PURPLE_500
	if type == Tile.BOUNCY:
		return Palette.PINK_500
	if type == Tile.GLASS:
		return Palette.CYAN_500
	return Palette.AMBER_600
