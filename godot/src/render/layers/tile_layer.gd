class_name TileLayer
extends WorldLayer
## The level's tiles, kept as objects instead of being painted every frame.
##
## The level is split into chunks of [constant CHUNK] by [constant CHUNK]
## cells. Each chunk is a node that keeps its drawing until one of its cells
## changes, so a still level costs nothing and moving the camera only moves
## the nodes. The layer itself draws just the few things that animate: the
## pulse of bouncy, void and goal tiles, and the block being eaten.
##
## In the editor nothing animates, so the chunks hold everything.

const CHUNK: int = 16
const NO_CELL: Vector2i = Vector2i(-1, -1)


## One block of cells. It asks the layer to paint it, and only when told to.
class Chunk:
	extends Node2D

	var layer: TileLayer
	var first_row: int = 0
	var first_col: int = 0
	## What the chunk showed when it was last painted.
	var content: int = 0

	func _draw() -> void:
		layer.paint_chunk(self)


var _chunks: Array[Chunk] = []
var _level: LevelGrid
var _cols: int = 0
var _rows: int = 0
var _scale: float = 0.0
var _editing: bool = false
var _level_hash: int = 0
## Cell left out of its chunk while the layer animates it being eaten.
var _hidden: Vector2i = NO_CELL


func request_redraw() -> void:
	if view == null or view.sim == null:
		return
	_sync_chunks()
	# Only the animated parts are painted per frame, and never in the editor.
	if not _editing:
		queue_redraw()


## Brings the chunks in line with the level: rebuilt when the level itself is
## replaced or resized, repainted where cells changed.
func _sync_chunks() -> void:
	var level: LevelGrid = view.sim.level
	var editing: bool = view.editor != null
	var repaint_all: bool = false
	if level != _level or level.cols != _cols or level.rows != _rows:
		_rebuild(level)
		repaint_all = true
	if not is_equal_approx(view.world_scale, _scale) or editing != _editing:
		_scale = view.world_scale
		_editing = editing
		repaint_all = true
		# Clears what the layer itself drew when the editor takes over.
		queue_redraw()

	var hidden: Vector2i = _eaten_cell()
	var level_hash: int = hash([level.content_hash(), view.sim.tile_motions.keys()])
	if not repaint_all and level_hash == _level_hash and hidden == _hidden:
		return
	_level_hash = level_hash
	_hidden = hidden
	for chunk: Chunk in _chunks:
		var content: int = _chunk_content(level, chunk)
		if repaint_all or content != chunk.content:
			chunk.content = content
			chunk.queue_redraw()


func _rebuild(level: LevelGrid) -> void:
	for chunk: Chunk in _chunks:
		chunk.queue_free()
	_chunks.clear()
	_level = level
	_cols = level.cols
	_rows = level.rows
	for first_row: int in range(0, level.rows, CHUNK):
		for first_col: int in range(0, level.cols, CHUNK):
			var chunk: Chunk = Chunk.new()
			chunk.layer = self
			chunk.first_row = first_row
			chunk.first_col = first_col
			# The layer's own animated drawing goes on top of the chunks.
			chunk.show_behind_parent = true
			add_child(chunk)
			_chunks.append(chunk)


## Everything a chunk's picture depends on: its cells, the ring around them
## (neighbours decide which corners are rounded) and a hidden cell inside it.
func _chunk_content(level: LevelGrid, chunk: Chunk) -> int:
	var content: int = level.region_hash(
		chunk.first_row - 1, chunk.first_col - 1,
		chunk.first_row + CHUNK + 1, chunk.first_col + CHUNK + 1
	)
	if not _editing:
		for cell: Vector2i in view.sim.tile_motions:
			if _in_chunk(chunk, cell):
				content = hash([content, cell])
	if _in_chunk(chunk, _hidden):
		content = hash([content, _hidden])
	return content


func _in_chunk(chunk: Chunk, cell: Vector2i) -> bool:
	return (
		cell.x >= chunk.first_col and cell.x < chunk.first_col + CHUNK
		and cell.y >= chunk.first_row and cell.y < chunk.first_row + CHUNK
	)


## The cell the player is swallowing, which the layer draws flying instead.
func _eaten_cell() -> Vector2i:
	var player: PlayerState = view.sim.player
	if view.editor != null or not player.has_eating_target or player.eating_target_is_boss_cell:
		return NO_CELL
	return Vector2i(player.eating_target_c, player.eating_target_r)


## Called by a chunk when it has to be painted again.
func paint_chunk(chunk: Chunk) -> void:
	if view == null or view.sim == null:
		return
	var level: LevelGrid = view.sim.level
	var p: Painter = Painter.new(chunk, view.world_scale)
	for r: int in range(chunk.first_row, mini(chunk.first_row + CHUNK, level.rows)):
		for c: int in range(chunk.first_col, mini(chunk.first_col + CHUNK, level.cols)):
			var t: int = level.get_cell(r, c)
			if t == Tile.AIR or Vector2i(c, r) == _hidden or (not _editing and view.sim.tile_motions.has(Vector2i(c, r))):
				continue
			var x: float = float(c) * Tile.SIZE
			var y: float = float(r) * Tile.SIZE
			TilePainter.draw_static(p, t, x, y, _free_corners(level, r, c))
			if _editing:
				TilePainter.draw_live(p, t, x, y, 0.0)


## The animated parts of the visible tiles.
func _paint(p: Painter, sim: GameSim) -> void:
	if _editing:
		return
	var level: LevelGrid = sim.level
	var visible_rect: Rect2 = view.visible_world_rect()
	var first_row: int = maxi(0, floori(visible_rect.position.y / Tile.SIZE) - 1)
	var last_row: int = mini(level.rows - 1, ceili(visible_rect.end.y / Tile.SIZE) + 1)
	var first_col: int = maxi(0, floori(visible_rect.position.x / Tile.SIZE) - 1)
	var last_col: int = mini(level.cols - 1, ceili(visible_rect.end.x / Tile.SIZE) + 1)
	for r: int in range(first_row, last_row + 1):
		for c: int in range(first_col, last_col + 1):
			var t: int = level.get_cell(r, c)
			if TilePainter.is_animated(t) and Vector2i(c, r) != _hidden and not sim.tile_motions.has(Vector2i(c, r)):
				TilePainter.draw_live(p, t, float(c) * Tile.SIZE, float(r) * Tile.SIZE, view.time_ms)
	if _hidden != NO_CELL and level.in_bounds(_hidden.y, _hidden.x):
		_paint_eaten(p, sim, level.get_cell(_hidden.y, _hidden.x))


## The block being swallowed slides into the slime and shrinks.
func _paint_eaten(p: Painter, sim: GameSim, t: int) -> void:
	if t == Tile.AIR:
		return
	var player: PlayerState = sim.player
	var progress: float = clampf(player.eating_progress, 0.0, 1.0)
	var center: Vector2 = view.tile_position(_hidden) + Vector2.ONE * Tile.SIZE * 0.5
	var body: Vector2 = view.player_position() + Vector2(player.w, player.h) * 0.5
	var pull: float = progress * progress * (3.0 - 2.0 * progress)
	var visual: Vector2 = center.lerp(body, pull)
	p.push()
	p.translate(visual.x, visual.y)
	p.rotate(sin(progress * PI) * 0.08)
	var shrink: float = lerpf(1.0, 0.5, pull)
	p.scale(shrink, shrink)
	TilePainter.draw(p, t, -Tile.SIZE * 0.5, -Tile.SIZE * 0.5, view.time_ms)
	p.pop()


## Corners of the cell that touch nothing, as [method Painter.fill_round_rect]
## bits. A corner is free when both cells beside it are empty.
func _free_corners(level: LevelGrid, r: int, c: int) -> int:
	var up: bool = _is_open(level, r - 1, c)
	var down: bool = _is_open(level, r + 1, c)
	var left: bool = _is_open(level, r, c - 1)
	var right: bool = _is_open(level, r, c + 1)
	var corners: int = 0
	if up and right:
		corners |= 1
	if down and right:
		corners |= 2
	if down and left:
		corners |= 4
	if up and left:
		corners |= 8
	return corners


func _is_open(level: LevelGrid, r: int, c: int) -> bool:
	if not level.in_bounds(r, c):
		return false
	var t: int = level.get_cell(r, c)
	return t == Tile.AIR or t == Tile.GOAL
