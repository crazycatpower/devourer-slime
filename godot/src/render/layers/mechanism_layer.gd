class_name MechanismLayer
extends WorldLayer
## Wire layer, rails, and device power indicators, also visible in the editor.

const RAIL_SPACING: float = 8.5


func _paint(p: Painter, sim: GameSim) -> void:
	if view.editor != null and not view.editor_show_devices:
		return
	var level: LevelGrid = sim.level
	var visible: Rect2 = view.visible_world_rect().grow(Tile.SIZE)
	for cell: Vector2i in level.sensors:
		var at: Vector2 = Vector2(cell) * Tile.SIZE
		if not visible.has_point(at + Vector2.ONE * Tile.SIZE * 0.5):
			continue
		TilePainter.draw(p, Tile.SENSOR, at.x, at.y, view.time_ms)
		if view.editor == null and sim.powered_cells.has(cell):
			p.stroke_round_rect(at.x + 3.0, at.y + 3.0, Tile.SIZE - 6.0, Tile.SIZE - 6.0, 6.0, Palette.LIME_400, 3.0)
			p.fill_circle(at.x + 20.0, at.y + 20.0, 3.5, Palette.LIME_400)
	for cell: Vector2i in level.wires:
		var at: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE
		if not visible.has_point(at):
			continue
		draw_wire(p, level, cell, view.editor == null and sim.powered_cells.has(cell), Vector2.ZERO, view.time_ms)
	for cell: Vector2i in level.rails:
		var at: Vector2 = Vector2(cell) * Tile.SIZE
		if not visible.has_point(at + Vector2.ONE * Tile.SIZE * 0.5):
			continue
		draw_rail(p, level, cell, view.editor == null and sim.powered_cells.has(cell), Vector2.ZERO, view.time_ms)


## A soft cable with one clear powered/unpowered color, without moving sparks.
static func draw_wire(
	p: Painter, grid: LevelGrid, cell: Vector2i, powered: bool = false, offset: Vector2 = Vector2.ZERO, _time_ms: float = 0.0
) -> void:
	var at: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE + offset
	var border: Color = Color("354957")
	var core: Color = Palette.LIME_400 if powered else Color("899b9d")
	for direction: Vector2i in MechanismSystem.DIRECTIONS:
		if not MechanismSystem.is_connector(grid, cell + direction):
			continue
		var end: Vector2 = at + Vector2(direction) * Tile.SIZE * 0.5
		p.line(at.x, at.y, end.x, end.y, border, 7.0)
		p.line(at.x, at.y, end.x, end.y, core, 3.5)
	p.fill_circle(at.x, at.y, 5.0, border)
	p.fill_circle(at.x, at.y, 2.8, core)


## The same toy-track drawing used by the editor icons, with connected bends.
static func draw_rail(
	p: Painter, grid: LevelGrid, cell: Vector2i, powered: bool = false, offset: Vector2 = Vector2.ZERO, _time_ms: float = 0.0
) -> void:
	var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE + offset
	var outgoing: Vector2i = Tile.rail_direction(grid.rails[cell])
	var connected: Array[Vector2i] = []
	for direction: Vector2i in MechanismSystem.DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		var incoming: bool = grid.rails.has(neighbor) and Tile.rail_direction(grid.rails[neighbor]) == -direction
		if direction == outgoing or incoming:
			connected.append(direction)
	TilePainter.draw_track(p, center, outgoing, connected, powered)