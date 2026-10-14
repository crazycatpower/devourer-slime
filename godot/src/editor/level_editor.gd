class_name LevelEditor
extends RefCounted
## The level editor's document: a working copy of a level, the current
## brush, a clipboard and an undo history.
##
## It knows nothing about nodes or input devices. The editor screen
## translates mouse gestures into the calls below, and the editor reports
## back through its signals.

## The level's tiles or start cell changed.
signal changed
signal brush_changed
## Undo/redo availability or the unsaved flag changed.
signal history_changed

enum Brush { DIRT, BOUNCY, STEEL, GLASS, VOID, SPIKES, GOAL, PLAYER, COPY, PASTE, ERASER, SENSOR, RAIL_RIGHT, RAIL_LEFT, SAND, ICE, TNT, WIRE, RAIL_UP, RAIL_DOWN }
enum SpikeDirection { UP, RIGHT, DOWN, LEFT }

const MAX_HISTORY: int = 100
const NO_CELL: Vector2i = Vector2i(-1, -1)

## The level being edited. Replaced (not just modified) by undo and resize.
var level: LevelData = LevelData.new()
var brush: Brush = Brush.DIRT
var spike_direction: SpikeDirection = SpikeDirection.UP
## Dragged tracks follow the gesture; single clicks retain the selected arrow.
var rail_auto_turn: bool = true
var _batching_changes: bool = false
var _batch_changed: bool = false
## Tiles captured by the copy brush; null until something has been copied.
var clipboard: LevelGrid
## Corners of the copy selection being dragged, or [constant NO_CELL].
var selection_start: Vector2i = NO_CELL
var selection_end: Vector2i = NO_CELL

var _undo: Array[LevelData] = []
var _redo: Array[LevelData] = []
var _dirty: bool = false
var _stroke_snapshot: LevelData
var _stroke_changed: bool = false
var _last_cell: Vector2i = NO_CELL
var _saved_level: LevelData


## Starts editing [param data] with a clean history.
func open(data: LevelData) -> void:
	level = data.duplicate_level()
	_saved_level = level.duplicate_level()
	_undo.clear()
	_redo.clear()
	_dirty = false
	_stroke_snapshot = null
	selection_start = NO_CELL
	selection_end = NO_CELL
	_notify_changed()
	history_changed.emit()


func is_dirty() -> bool:
	return not level.equals(_saved_level) if _saved_level != null else _dirty


## Call after the level has been written to disk.
func mark_saved() -> void:
	end_stroke()
	_saved_level = level.duplicate_level()
	_dirty = false
	history_changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func set_brush(value: Brush) -> void:
	end_stroke()
	if value == brush:
		return
	brush = value
	selection_start = NO_CELL
	selection_end = NO_CELL
	brush_changed.emit()


func rotate_rail() -> void:
	var directions: Array[Brush] = [Brush.RAIL_RIGHT, Brush.RAIL_DOWN, Brush.RAIL_LEFT, Brush.RAIL_UP]
	set_brush(directions[(directions.find(brush) + 1) % 4])


func set_spike_direction(value: SpikeDirection) -> void:
	if value == spike_direction and brush == Brush.SPIKES:
		return
	spike_direction = value
	brush = Brush.SPIKES
	brush_changed.emit()


## Tile the current brush paints, or -1 for brushes that do not paint tiles.
func brush_tile() -> int:
	match brush:
		Brush.SENSOR:
			return Tile.SENSOR
		Brush.RAIL_RIGHT:
			return Tile.RAIL_RIGHT
		Brush.RAIL_LEFT:
			return Tile.RAIL_LEFT
		Brush.RAIL_UP:
			return Tile.RAIL_UP
		Brush.RAIL_DOWN:
			return Tile.RAIL_DOWN
		Brush.SAND:
			return Tile.SAND
		Brush.ICE:
			return Tile.ICE
		Brush.TNT:
			return Tile.TNT
		Brush.DIRT:
			return Tile.DIRT
		Brush.BOUNCY:
			return Tile.BOUNCY
		Brush.STEEL:
			return Tile.STEEL
		Brush.GLASS:
			return Tile.GLASS
		Brush.VOID:
			return Tile.VOID
		Brush.GOAL:
			return Tile.GOAL
		Brush.ERASER:
			return Tile.AIR
		Brush.SPIKES:
			return spike_tile(spike_direction)
	return -1


static func spike_tile(direction: SpikeDirection) -> int:
	match direction:
		SpikeDirection.RIGHT:
			return Tile.SPIKE_RIGHT
		SpikeDirection.DOWN:
			return Tile.SPIKE_DOWN
		SpikeDirection.LEFT:
			return Tile.SPIKE_LEFT
	return Tile.SPIKE_UP


# --- Painting ---------------------------------------------------------------------

## Opens a stroke: every change until [method end_stroke] undoes as one step.
func begin_stroke() -> void:
	end_stroke()
	_stroke_snapshot = level.duplicate_level()
	_stroke_changed = false
	_last_cell = NO_CELL


## Extends the stroke to [param cell], painting every cell on the way from
## the previous one so that fast mouse movement leaves no gaps.
## [param erase] paints air whatever the brush is.
func stroke_to(cell: Vector2i, erase: bool) -> void:
	if _stroke_snapshot == null:
		begin_stroke()
	_batching_changes = true
	_batch_changed = false
	if _last_cell == NO_CELL:
		_apply(cell, erase)
	elif cell != _last_cell:
		var previous: Vector2i = _last_cell
		var rail: bool = Tile.is_rail(brush_tile())
		for step: Vector2i in _line(_last_cell, cell).slice(1):
			if (brush == Brush.WIRE or rail) and step.x != previous.x and step.y != previous.y:
				var bridge: Vector2i = Vector2i(step.x, previous.y)
				_path_step(previous, bridge, erase)
				previous = bridge
			_path_step(previous, step, erase)
			previous = step
	_last_cell = cell
	_batching_changes = false
	if _batch_changed:
		_notify_changed()


func _path_step(from: Vector2i, to: Vector2i, erase: bool) -> void:
	if not erase and rail_auto_turn and Tile.is_rail(brush_tile()) and level.grid.in_bounds(from.y, from.x) and level.grid.in_bounds(to.y, to.x):
		var type: int = Tile.RAIL_RIGHT
		match to - from:
			Vector2i.LEFT: type = Tile.RAIL_LEFT
			Vector2i.UP: type = Tile.RAIL_UP
			Vector2i.DOWN: type = Tile.RAIL_DOWN
		_set_rail(from, type)
		# Preserve an existing endpoint, including the start when closing a loop.
		if not level.grid.rails.has(to):
			_set_rail(to, type)
	else:
		_apply(to, erase)


func end_stroke() -> void:
	if _stroke_snapshot != null and _stroke_changed:
		var snapshot: LevelData = _stroke_snapshot
		_stroke_snapshot = null
		_stroke_changed = false
		_last_cell = NO_CELL
		_commit(snapshot)
		return
	_stroke_snapshot = null
	_stroke_changed = false
	_last_cell = NO_CELL


## Stamps the clipboard with its top-left corner at [param cell].
func paste_at(cell: Vector2i) -> void:
	if clipboard == null:
		return
	var before: LevelData = level.duplicate_level()
	var grid: LevelGrid = level.grid
	for r: int in clipboard.rows:
		for c: int in clipboard.cols:
			var target: Vector2i = Vector2i(cell.x + c, cell.y + r)
			if grid.in_bounds(target.y, target.x):
				if target != level.start_cell:
					grid.set_cell(target.y, target.x, clipboard.get_cell(r, c))
				grid.set_wire(target, clipboard.wires.has(Vector2i(c, r)))
				grid.set_sensor(target, clipboard.sensors.has(Vector2i(c, r)))
				grid.set_rail(target, clipboard.rails.get(Vector2i(c, r), Tile.AIR) as int)
	if not level.equals(before):
		_commit(before)
		_notify_changed()


# --- Copy selection -----------------------------------------------------------------

func begin_selection(cell: Vector2i) -> void:
	selection_start = _clamped(cell)
	selection_end = selection_start


func update_selection(cell: Vector2i) -> void:
	if selection_start != NO_CELL:
		selection_end = _clamped(cell)


## Copies the selected cells and switches to the paste brush.
func finish_selection() -> void:
	if selection_start == NO_CELL:
		return
	var area: Rect2i = selection_rect()
	clipboard = LevelGrid.new(area.size.x, area.size.y)
	for r: int in area.size.y:
		for c: int in area.size.x:
			clipboard.set_cell(r, c, level.grid.get_cell(area.position.y + r, area.position.x + c))
			clipboard.set_wire(Vector2i(c, r), level.grid.wires.has(area.position + Vector2i(c, r)))
			clipboard.set_sensor(Vector2i(c, r), level.grid.sensors.has(area.position + Vector2i(c, r)))
			clipboard.set_rail(Vector2i(c, r), level.grid.rails.get(area.position + Vector2i(c, r), Tile.AIR) as int)
	selection_start = NO_CELL
	selection_end = NO_CELL
	brush = Brush.PASTE
	brush_changed.emit()


## The selection as (column, row, width, height) in cells.
func selection_rect() -> Rect2i:
	var left: int = mini(selection_start.x, selection_end.x)
	var top: int = mini(selection_start.y, selection_end.y)
	return Rect2i(
		left, top, absi(selection_end.x - selection_start.x) + 1,
		absi(selection_end.y - selection_start.y) + 1
	)


# --- Whole-level operations -----------------------------------------------------------

## Changes the level size, keeping what fits. Out-of-range sizes are clamped.
func resize(cols: int, rows: int) -> void:
	var new_cols: int = clampi(cols, GameConstants.MIN_LEVEL_COLS, GameConstants.MAX_LEVEL_COLS)
	var new_rows: int = clampi(rows, GameConstants.MIN_LEVEL_ROWS, GameConstants.MAX_LEVEL_ROWS)
	if new_cols == level.grid.cols and new_rows == level.grid.rows:
		return
	var before: LevelData = level.duplicate_level()
	level.grid = level.grid.resized(new_cols, new_rows)
	if not level.grid.is_interior(level.start_cell.y, level.start_cell.x):
		level.start_cell = LevelCodec.find_free_cell(level.grid)
	level.grid.set_cell(level.start_cell.y, level.start_cell.x, Tile.AIR)
	_commit(before)
	_notify_changed()


## Empties the level, leaving only the steel border.
func clear() -> void:
	var before: LevelData = level.duplicate_level()
	level.grid = LevelGrid.new(level.grid.cols, level.grid.rows)
	level.grid.fill_border(Tile.STEEL)
	if not level.grid.is_interior(level.start_cell.y, level.start_cell.x):
		level.start_cell = Vector2i(1, 1)
	if not level.equals(before):
		_commit(before)
		_notify_changed()


func undo() -> void:
	end_stroke()
	if _undo.is_empty():
		return
	_redo.append(level)
	level = _undo.pop_back()
	_dirty = true
	_notify_changed()
	history_changed.emit()


func redo() -> void:
	end_stroke()
	if _redo.is_empty():
		return
	_undo.append(level)
	level = _redo.pop_back()
	_dirty = true
	_notify_changed()
	history_changed.emit()


# --- Internals -------------------------------------------------------------------------


## Pick the material under the pointer without changing the document.
func pick_brush(cell: Vector2i) -> void:
	if not level.grid.in_bounds(cell.y, cell.x):
		return
	if cell == level.start_cell:
		set_brush(Brush.PLAYER)
		return
	if brush == Brush.SENSOR and level.grid.sensors.has(cell):
		return
	if brush == Brush.WIRE and level.grid.wires.has(cell):
		return
	var tile: int = level.grid.get_cell(cell.y, cell.x)
	if Tile.is_rail(brush_tile()) and level.grid.rails.has(cell):
		tile = level.grid.rails[cell]
	if tile == Tile.AIR and level.grid.sensors.has(cell):
		set_brush(Brush.SENSOR)
		return
	if tile == Tile.AIR and level.grid.wires.has(cell):
		set_brush(Brush.WIRE)
		return
	if tile == Tile.AIR and level.grid.rails.has(cell):
		tile = level.grid.rails[cell]
	if Tile.is_spike(tile):
		for direction: int in 4:
			if spike_tile(direction as SpikeDirection) == tile:
				set_brush(Brush.SPIKES)
				set_spike_direction(direction as SpikeDirection)
				return
	var mapping: Dictionary[int, int] = {
		Tile.AIR: Brush.ERASER, Tile.DIRT: Brush.DIRT, Tile.DIRT_EATEN_1: Brush.DIRT,
		Tile.DIRT_EATEN_2: Brush.DIRT, Tile.STEEL: Brush.STEEL, Tile.BOUNCY: Brush.BOUNCY,
		Tile.BOUNCY_EATEN_1: Brush.BOUNCY, Tile.BOUNCY_EATEN_2: Brush.BOUNCY,
		Tile.GLASS: Brush.GLASS, Tile.VOID: Brush.VOID, Tile.GOAL: Brush.GOAL,
		Tile.SENSOR: Brush.SENSOR, Tile.RAIL_RIGHT: Brush.RAIL_RIGHT, Tile.RAIL_LEFT: Brush.RAIL_LEFT,
		Tile.RAIL_UP: Brush.RAIL_UP, Tile.RAIL_DOWN: Brush.RAIL_DOWN,
		Tile.SAND: Brush.SAND, Tile.ICE: Brush.ICE, Tile.TNT: Brush.TNT,
	}
	if mapping.has(tile):
		set_brush(mapping[tile] as Brush)

func _apply(cell: Vector2i, erase: bool) -> void:
	var grid: LevelGrid = level.grid
	if not grid.in_bounds(cell.y, cell.x):
		return
	if brush == Brush.WIRE:
		_set_wire(cell, not erase)
		return
	if brush == Brush.SENSOR:
		_set_sensor(cell, not erase)
		return
	if Tile.is_rail(brush_tile()):
		_set_rail(cell, Tile.AIR if erase else brush_tile())
		return
	if erase:
		_set_tile(cell, Tile.AIR)
		_set_wire(cell, false)
		_set_sensor(cell, false)
		_set_rail(cell, Tile.AIR)
		return
	match brush:
		Brush.ERASER:
			_set_tile(cell, Tile.AIR)
			_set_wire(cell, false)
			_set_sensor(cell, false)
			_set_rail(cell, Tile.AIR)
		Brush.PLAYER:
			if cell != level.start_cell:
				level.start_cell = cell
				grid.set_cell(cell.y, cell.x, Tile.AIR)
				_stroke_changed = true
				_notify_changed()
		Brush.SPIKES:
			_orient_spikes(cell)
			_set_tile(cell, spike_tile(spike_direction))
		Brush.COPY, Brush.PASTE:
			pass
		_:
			_set_tile(cell, brush_tile())


func _set_rail(cell: Vector2i, type: int) -> void:
	if level.grid.rails.get(cell, Tile.AIR) == type:
		return
	level.grid.set_rail(cell, type)
	_stroke_changed = true
	_notify_changed()


func _set_sensor(cell: Vector2i, present: bool) -> void:
	if level.grid.sensors.has(cell) == present:
		return
	level.grid.set_sensor(cell, present)
	_stroke_changed = true
	_notify_changed()


func _set_wire(cell: Vector2i, present: bool) -> void:
	if level.grid.wires.has(cell) == present:
		return
	level.grid.set_wire(cell, present)
	_stroke_changed = true
	_notify_changed()


func _set_tile(cell: Vector2i, tile: int) -> void:
	# The start cell stays free, so the player can never spawn inside a block.
	if cell == level.start_cell and tile != Tile.AIR:
		return
	if level.grid.get_cell(cell.y, cell.x) == tile:
		return
	level.grid.set_cell(cell.y, cell.x, tile)
	_stroke_changed = true
	_notify_changed()


## Spikes painted next to exactly one solid neighbour turn to grow out of it.
func _orient_spikes(cell: Vector2i) -> void:
	var below: bool = _is_solid_or_outside(cell.y + 1, cell.x)
	var left: bool = _is_solid_or_outside(cell.y, cell.x - 1)
	var above: bool = _is_solid_or_outside(cell.y - 1, cell.x)
	var right: bool = _is_solid_or_outside(cell.y, cell.x + 1)
	if int(below) + int(left) + int(above) + int(right) != 1:
		return
	var direction: SpikeDirection = SpikeDirection.UP
	if left:
		direction = SpikeDirection.RIGHT
	elif above:
		direction = SpikeDirection.DOWN
	elif right:
		direction = SpikeDirection.LEFT
	if direction != spike_direction:
		spike_direction = direction
		brush_changed.emit()


func _is_solid_or_outside(r: int, c: int) -> bool:
	var grid: LevelGrid = level.grid
	if not grid.in_bounds(r, c):
		return true
	return Tile.is_solid(grid.get_cell(r, c))


func _commit(before: LevelData) -> void:
	_undo.append(before)
	if _undo.size() > MAX_HISTORY:
		_undo.pop_front()
	_redo.clear()
	_dirty = true
	history_changed.emit()


func _clamped(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, level.grid.cols - 1), clampi(cell.y, 0, level.grid.rows - 1)
	)


## Cells on the straight line from [param from] to [param to], both included.
static func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dx: int = absi(to.x - from.x)
	var dy: int = -absi(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var error: int = dx + dy
	var current: Vector2i = from
	while true:
		cells.append(current)
		if current == to:
			break
		var doubled: int = 2 * error
		if doubled >= dy:
			error += dy
			current.x += sx
		if doubled <= dx:
			error += dx
			current.y += sy
	return cells


func _notify_changed() -> void:
	if _batching_changes:
		_batch_changed = true
	else:
		changed.emit()
