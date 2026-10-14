class_name WorldView
extends Control
## Draws a [GameSim]: the window onto the level that both the game and the
## level editor show.
##
## The view is always [constant GameConstants.VIEW_WIDTH] world units wide,
## however large it is on screen. It owns a stack of [WorldLayer] children
## that each draw one thing (tiles, player, boss, ...) in a fixed order, and it
## only ever reads the simulation.

## The simulation to draw. Set before the view enters the tree, or any time.
var sim: GameSim
## Position between the previous tick (0) and the current one (1).
var tick_alpha: float = 1.0
## Position between the camera's previous frame (0) and the current one (1).
var camera_alpha: float = 1.0
## Camera shake displacement for this frame, in world units.
var shake_offset: Vector2 = Vector2.ZERO
## State of the shoot and eat buttons, for the aiming aids.
var shoot_held: bool = false
var eat_held: bool = false
## Historical presentation during death; gameplay keeps its normal retry timer.
var rewinding: bool = false
## How much bullet time is left, 0..1; a gauge is shown while it is not full.
var bullet_time_energy: float = 1.0
## When set, the editor's grid and brush preview are drawn on top.
var editor: LevelEditor
var editor_zoom: float = 1.0
var editor_erasing: bool = false
var editor_show_grid: bool = true
var editor_show_devices: bool = true

## Screen pixels per world unit.
var world_scale: float = 1.0
## Top-left of the visible area this frame, in world units.
var camera_position: Vector2 = Vector2.ZERO
## Wall-clock milliseconds, for animation that is purely cosmetic.
var time_ms: float = 0.0
var exit_vortex: GoalVortex = GoalVortex.new()

var _world: Node2D
var _layers: Array[WorldLayer] = []


func _ready() -> void:
	clip_contents = true
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	# Keep the world below any overlay controls placed inside the view.
	move_child(_world, 0)
	_add_layer(BackdropLayer.new(), "Backdrop")
	_add_layer(TileLayer.new(), "Tiles")
	_add_layer(MechanismLayer.new(), "Mechanisms")
	_add_layer(MovingTileLayer.new(), "MovingTiles")
	_add_layer(AimLayer.new(), "Aim")
	_add_layer(ProjectileLayer.new(), "Projectiles")
	_add_layer(PlayerLayer.new(), "Player")
	_add_layer(DevourEffectLayer.new(), "DevourEffects")
	_add_layer(ParticleLayer.new(), "Particles")
	_add_layer(FallingBlockLayer.new(), "FallingBlocks")
	_add_layer(BossLayer.new(), "Boss")
	_add_layer(HintLayer.new(), "Hints")
	_add_layer(EditorOverlayLayer.new(), "EditorOverlay")


func _process(delta: float) -> void:
	if sim == null:
		return
	exit_vortex.advance(delta, sim)
	time_ms = sim.clock_ms() if rewinding else float(Time.get_ticks_msec())
	world_scale = size.x / GameConstants.VIEW_WIDTH * (editor_zoom if editor != null else 1.0)
	var camera: SimCamera = sim.camera
	camera_position = Vector2(
		lerpf(camera.prev_x, camera.x, camera_alpha), lerpf(camera.prev_y, camera.y, camera_alpha)
	)
	_world.scale = Vector2(world_scale, world_scale)
	# Whole pixels: the tiles are kept drawings aligned to the pixel grid, and
	# moving them by a fraction would blur their edges unevenly.
	_world.position = ((shake_offset - camera_position) * world_scale).round()
	queue_redraw()
	for layer: WorldLayer in _layers:
		layer.request_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.SLATE_900)


## Mouse position relative to the view's top-left corner, in world units.
func mouse_in_view() -> Vector2:
	return get_local_mouse_position() / maxf(world_scale, 0.001)


## Mouse position in world coordinates.
func mouse_in_world() -> Vector2:
	if sim == null:
		return Vector2.ZERO
	return mouse_in_view() + Vector2(sim.camera.x, sim.camera.y)


## Interpolated position of something that moved from prev to current this tick.
func tween_position(prev_x: float, prev_y: float, x: float, y: float) -> Vector2:
	return Vector2(lerpf(prev_x, x, tick_alpha), lerpf(prev_y, y, tick_alpha))


## Visible part of the world, for culling.
func visible_world_rect() -> Rect2:
	if editor != null:
		return Rect2(camera_position, size / maxf(world_scale, 0.001))
	return Rect2(camera_position, Vector2(GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT))


func _add_layer(layer: WorldLayer, layer_name: String) -> void:
	layer.name = layer_name
	layer.view = self
	_world.add_child(layer)
	_layers.append(layer)


func player_position() -> Vector2:
	var player: PlayerState = sim.player
	return tween_position(player.prev_x, player.prev_y, player.x, player.y)


func tile_position(cell: Vector2i) -> Vector2:
	if sim.tile_motions.has(cell):
		return sim.tile_motions[cell].position_at(float(sim.tick_count - 1) + tick_alpha)
	return Vector2(cell) * Tile.SIZE
