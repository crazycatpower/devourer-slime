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
## How much bullet time is left, 0..1; a gauge is shown while it is not full.
var bullet_time_energy: float = 1.0
## When set, the editor's grid and brush preview are drawn on top.
var editor: LevelEditor

## Screen pixels per world unit.
var world_scale: float = 1.0
## Top-left of the visible area this frame, in world units.
var camera_position: Vector2 = Vector2.ZERO
## Wall-clock milliseconds, for animation that is purely cosmetic.
var time_ms: float = 0.0

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
	_add_layer(AimLayer.new(), "Aim")
	_add_layer(ProjectileLayer.new(), "Projectiles")
	_add_layer(PlayerLayer.new(), "Player")
	_add_layer(ParticleLayer.new(), "Particles")
	_add_layer(FallingBlockLayer.new(), "FallingBlocks")
	_add_layer(BossLayer.new(), "Boss")
	_add_layer(HintLayer.new(), "Hints")
	_add_layer(EditorOverlayLayer.new(), "EditorOverlay")


func _process(_delta: float) -> void:
	if sim == null:
		return
	time_ms = float(Time.get_ticks_msec())
	world_scale = size.x / GameConstants.VIEW_WIDTH
	var camera: SimCamera = sim.camera
	camera_position = Vector2(
		lerpf(camera.prev_x, camera.x, camera_alpha), lerpf(camera.prev_y, camera.y, camera_alpha)
	)
	_world.scale = Vector2(world_scale, world_scale)
	_world.position = (shake_offset - camera_position) * world_scale
	queue_redraw()
	for layer: WorldLayer in _layers:
		layer.queue_redraw()


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
	return Rect2(camera_position, Vector2(GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT))


func _add_layer(layer: WorldLayer, layer_name: String) -> void:
	layer.name = layer_name
	layer.view = self
	_world.add_child(layer)
	_layers.append(layer)
