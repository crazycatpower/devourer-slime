class_name BossState
extends RefCounted
## Mutable state of a boss inside a [GameSim].
##
## Every boss owns a square grid of tile ids: the blocks it is made of or has
## been fed. The mud golem uses a large grid that grows as the boss absorbs dirt;
## the other bosses use a 3x3 grid around a goal core.

enum Kind { NONE, MUD_GOLEM, BOUNCY_SLIME, GLASS_SLIME, VOID_SLIME, STEEL_CHASE }
enum State { SUSPENDED, INTRO, FALLING, ACTIVE, JUMPING, CHARGING, PRE_JUMP, STUNNED }
enum JumpType { NORMAL, BIG, SMALL, PRECISION, COMBO, MEGA }

## Column the boss hangs above before it is triggered.
const SPAWN_COLUMN: int = 24
const SPAWN_Y: float = -150.0
const BODY_SIZE: float = 120.0
const MUD_GOLEM_GRID_SIZE: int = 21
const MUD_GOLEM_CENTER: int = 10
const MAX_DURABILITY: int = 3
const SHIELD_ORBIT_RADIUS: float = 85.0

var kind: Kind = Kind.NONE
var x: float = 0.0
var y: float = 0.0
var prev_x: float = 0.0
var prev_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var w: float = BODY_SIZE
var h: float = BODY_SIZE
var active: bool = false
var dead: bool = false
var triggered: bool = false
var state: State = State.SUSPENDED
var grounded: bool = false
var scale_x: float = 1.0
var scale_y: float = 1.0
var damage_flash: float = 0.0

var grid_size: int = 3
## Row-major tile ids, [member grid_size] squared entries.
var grid: PackedInt32Array = PackedInt32Array()
## Bounding box of the occupied cells and the core cell (the mud golem keeps these
## up to date as the body changes shape).
var min_r: int = 0
var min_c: int = 0
var max_r: int = 2
var max_c: int = 2
var center_r: int = 1
var center_c: int = 1

var cooldown: int = 120
var max_cooldown: int = 120
var intro_timer: int = 0
var intro_duration: int = 0
## The player is held in place during the entrance that opens the fight, but
## not when a boss comes back in the middle of it.
var intro_freezes_player: bool = true
## Set while a boss drops back in after falling out: that landing is gentle
## and leaves the floor as it is.
var soft_landing: bool = false
var action_count: int = 0
var combo_count: int = 0
var jump_type: JumpType = JumpType.NORMAL
var jump_count: int = 0
var charge_timer: int = 0
var max_charge_timer: int = 0
var pre_jump_timer: int = 0
var max_pre_jump_timer: int = 0
var target_vx: float = 0.0
var target_vy: float = 0.0
## 0..1 progress of the player devouring the fully fed void slime.
var eating_progress: float = 0.0

# Mud golem: body rearrangement.
var reorg_timer: int = 0
var reorg_cells: Array[ReorgAnimCell] = []
var has_initial_reorg: bool = false
var has_initialized_reorg_grid: bool = false

# Bouncy and glass slimes: hit points; bouncy slime: bounces left in the current leap.
var has_durability: bool = false
var durability: int = MAX_DURABILITY
var bounces_remaining: int = 0

# Glass slime: orbiting glass shields, the move in hand and the bombs in play.
var shields: Array[ShieldState] = []
## The [enum BossGlassSlime.Move] being announced or carried out.
var current_move: int = 0
## Slam: left edge of the marked column and the Y it comes to rest on.
## Swoop: left edge of the arc's low point and the Y of the body's underside there.
var dive_x: float = 0.0
var dive_floor_y: float = 0.0
## Top-left of the body at each end of the swoop, and how far along it is, 0..1.
var swoop_from: Vector2 = Vector2.ZERO
var swoop_to: Vector2 = Vector2.ZERO
var swoop_progress: float = 0.0
var bombs: Array[GlassBomb] = []
## Short core recovery after a hit; queued shots cannot skip damage phases.
var glass_hit_recovery: int = 0
## Dedicated arena stream: extending terrain cannot change attack randomness.
var glass_arena_rng: SimRandom = null
## First row of the arena's fill; everything above it is open.
var arena_fill_row: int = 0


## Boss in its pre-fight state for [param p_kind]. [constant Kind.NONE]
## yields an inactive boss.
static func create(p_kind: Kind) -> BossState:
	var boss: BossState = BossState.new()
	boss.kind = p_kind
	if p_kind == Kind.NONE:
		boss.active = false
		boss.dead = true
		boss.grid.resize(9)
		return boss

	boss.active = true
	boss.x = float(SPAWN_COLUMN) * Tile.SIZE
	boss.y = SPAWN_Y
	boss.prev_x = boss.x
	boss.prev_y = boss.y

	if p_kind == Kind.MUD_GOLEM:
		boss.w = Tile.SIZE
		boss.h = Tile.SIZE
		boss.grid_size = MUD_GOLEM_GRID_SIZE
		boss.grid.resize(MUD_GOLEM_GRID_SIZE * MUD_GOLEM_GRID_SIZE)
		boss.min_r = MUD_GOLEM_CENTER
		boss.min_c = MUD_GOLEM_CENTER
		boss.max_r = MUD_GOLEM_CENTER
		boss.max_c = MUD_GOLEM_CENTER
		boss.center_r = MUD_GOLEM_CENTER
		boss.center_c = MUD_GOLEM_CENTER
	else:
		boss.grid.resize(9)
		if p_kind == Kind.BOUNCY_SLIME:
			boss.grid.fill(Tile.BOUNCY)
	boss.set_cell(boss.center_r, boss.center_c, Tile.GOAL)

	if p_kind == Kind.BOUNCY_SLIME or p_kind == Kind.GLASS_SLIME:
		boss.has_durability = true
	if p_kind == Kind.GLASS_SLIME:
		boss.shields = make_shield_ring(4)
	return boss


## Ring of [param count] evenly spaced orbiting shields.
static func make_shield_ring(count: int) -> Array[ShieldState]:
	var ring: Array[ShieldState] = []
	for idx: int in count:
		var shield: ShieldState = ShieldState.new()
		shield.angle_offset = (float(idx) * 2.0 * PI) / float(count)
		ring.append(shield)
	return ring


func cell(r: int, c: int) -> int:
	if r < 0 or r >= grid_size or c < 0 or c >= grid_size:
		return Tile.AIR
	return grid[r * grid_size + c]


func set_cell(r: int, c: int, tile: int) -> void:
	if r < 0 or r >= grid_size or c < 0 or c >= grid_size:
		return
	grid[r * grid_size + c] = tile


func center_x() -> float:
	return x + w / 2.0


func center_y() -> float:
	return y + h / 2.0


## World x of the left edge of grid column [param c].
func cell_x(c: int) -> float:
	return x + float(c - min_c) * Tile.SIZE


## World y of the top edge of grid row [param r].
func cell_y(r: int) -> float:
	return y + float(r - min_r) * Tile.SIZE


## True when [param r], [param c] touches an occupied cell on any side.
func has_occupied_neighbor(r: int, c: int) -> bool:
	return cell(r - 1, c) > 0 or cell(r + 1, c) > 0 or cell(r, c - 1) > 0 or cell(r, c + 1) > 0


## Number of occupied cells, core included.
func count_blocks() -> int:
	var count: int = 0
	for value: int in grid:
		if value > 0:
			count += 1
	return count


## Number of occupied cells, core excluded. Zero while the boss is inactive.
func filled_count() -> int:
	if not active:
		return 0
	var count: int = 0
	for r: int in grid_size:
		for c: int in grid_size:
			if r == center_r and c == center_c:
				continue
			if grid[r * grid_size + c] != 0:
				count += 1
	return count


## True once every cell around the core of a 3x3 boss holds a block.
func is_filled() -> bool:
	if not active or dead:
		return false
	for r: int in 3:
		for c: int in 3:
			if r == 1 and c == 1:
				continue
			if cell(r, c) == 0:
				return false
	return true


## Order-sensitive checksum of the grid contents, used by tests.
func grid_checksum() -> int:
	var hash_value: int = 7
	for value: int in grid:
		hash_value = (hash_value * 31 + value) % 1000000007
	return hash_value
