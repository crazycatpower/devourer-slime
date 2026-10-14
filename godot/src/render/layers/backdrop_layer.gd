class_name BackdropLayer
extends WorldLayer
## Quiet background walls and distinct grounded halls for all five boss slots.

var cache_enabled: bool = true
var _last_key: Array = []
var redraw_count: int = 0
var paint_usec: int = 0


func request_redraw() -> void:
	if view == null or view.sim == null:
		return
	var key: Array = [view.camera_position, view.size, view.world_scale, view.sim.slot,
		view.sim.level.pixel_height(), view.editor != null]
	if not cache_enabled or key != _last_key:
		_last_key = key
		queue_redraw()

func _paint(p: Painter, sim: GameSim) -> void:
	var started: int = Time.get_ticks_usec()
	_paint_background(p, sim)
	redraw_count += 1
	paint_usec += Time.get_ticks_usec() - started


func _paint_background(p: Painter, sim: GameSim) -> void:
	var world: int = clampi(GameConstants.world_of_slot(sim.slot) - 1, 0, BackdropTheme.PALETTES.size() - 1)
	var colors: PackedColorArray = BackdropTheme.PALETTES[world]
	var visible: Rect2 = Rect2(view.camera_position, view.size / maxf(view.world_scale, 0.001))
	var depth_pilot: bool = LevelLibrary.is_boss_slot(sim.slot) and view.editor == null
	if depth_pilot:
		if world == 0:
			_draw_depth(p, visible, sim.level.pixel_height() - Tile.SIZE)
		else:
			_draw_boss_hall(p, visible, sim.level.pixel_height() - Tile.SIZE, world, colors)
	var first_col: int = floori(visible.position.x / Tile.SIZE)
	var last_col: int = ceili(visible.end.x / Tile.SIZE)
	var first_row: int = floori(visible.position.y / Tile.SIZE)
	var last_row: int = ceili(visible.end.y / Tile.SIZE)
	for r: int in range(first_row, last_row):
		for c: int in range(first_col, last_col):
			if depth_pilot and posmod(c, 32) >= 5 and posmod(c, 32) < 29:
				continue
			_draw_wall_tile(p, float(c) * Tile.SIZE, float(r) * Tile.SIZE, world, colors, r, c)
	if depth_pilot:
		for bay: int in range(floori(visible.position.x / 1280.0) - 1, ceili(visible.end.x / 1280.0) + 1):
			var x: float = float(bay) * 1280.0 + 200.0
			# Only vertical jambs: the bay continues into the ceiling and floor.
			p.fill_rect(x, visible.position.y, 6.0, visible.size.y, colors[0].darkened(0.3))
			p.fill_rect(x + 954.0, visible.position.y, 6.0, visible.size.y, colors[2])


func _draw_boss_hall(p: Painter, visible: Rect2, ground: float, world: int, colors: PackedColorArray) -> void:
	var dark: Color = colors[0].darkened(0.35)
	var body: Color = colors[1]
	var edge: Color = colors[2]
	p.fill_rect(visible.position.x, visible.position.y, visible.size.x, visible.size.y, dark)
	_draw_rear_structure(p, visible, ground, colors)
	# A continuous rear foundation supports every machine and structural foot.
	p.fill_rect(visible.position.x, ground - 12.0, visible.size.x, 12.0, body)
	p.fill_rect(visible.position.x, ground - 12.0, visible.size.x, 2.0, edge)
	p.push()
	p.translate(floorf(view.camera_position.x * 0.82), 0.0)
	var left: float = view.camera_position.x * 0.18
	for bay: int in range(floori(left / 960.0) - 1, ceili((left + visible.size.x) / 960.0) + 1):
		var variant: int = BackdropTheme.variant(bay, world)
		var x: float = float(bay) * 960.0 + 290.0 + float(variant) * 18.0
		var base: float = ground - 12.0
		match world:
			1: # Recycling press: two load-bearing posts and grounded platen.
				p.fill_rect(x - 10.0, base - 12.0, 196.0, 12.0, edge)
				for dx: float in [0.0, 156.0]:
					p.fill_rect(x + dx, base - 264.0, 20.0, 252.0, body)
					p.fill_rect(x + dx + 3.0, base - 260.0, 2.0, 244.0, edge)
				p.fill_rect(x, base - 272.0, 176.0, 28.0, body)
				p.fill_rect(x + 75.0, base - 244.0, 26.0, 105.0, edge)
				p.fill_rect(x + 35.0, base - 139.0, 106.0, 18.0, body)
				p.fill_rect(x + 28.0, base - 45.0, 120.0, 33.0, body)
			2: # Polymer works: broad mixer anchored to feet and service pipes.
				p.fill_rect(x, base - 18.0, 190.0, 18.0, edge)
				for dx: float in [22.0, 146.0]:
					p.fill_rect(x + dx, base - 60.0, 16.0, 42.0, body)
				p.fill_rect(x + 8.0, base - 175.0, 174.0, 115.0, body)
				p.fill_rect(x + 20.0, base - 185.0, 150.0, 10.0, edge)
				p.fill_rect(x + 82.0, 0.0, 18.0, base - 185.0, body)
				for dx: float in [30.0, 140.0]:
					p.fill_rect(x + dx, base - 170.0, 4.0, 104.0, edge)
				p.fill_rect(x + 65.0, base - 147.0, 60.0, 55.0, dark)
				p.fill_rect(x + 70.0, base - 119.0, 50.0, 22.0, colors[3])
			3: # Coolant station: unequal finned towers with joined headers.
				p.fill_rect(x - 8.0, base - 12.0, 192.0, 12.0, edge)
				for tower: int in 2:
					var tx: float = x + float(tower) * 102.0
					var h: float = 248.0 - float(tower) * 56.0
					p.fill_rect(tx, base - h, 72.0, h - 12.0, body)
					p.fill_rect(tx + 8.0, base - h + 12.0, 56.0, h - 34.0, dark)
					for fin: int in 6:
						p.fill_rect(tx + 12.0, base - h + 24.0 + float(fin) * 23.0, 48.0, 4.0, body)
				p.fill_rect(x + 30.0, 0.0, 10.0, base - 248.0, body)
				p.fill_rect(x + 72.0, base - 73.0, 30.0, 8.0, edge)
			4: # Containment exit: floor-mounted bulkhead with a locking spine.
				p.fill_rect(x - 8.0, base - 8.0, 202.0, 8.0, edge)
				p.fill_rect(x, base - 302.0, 186.0, 294.0, body)
				p.fill_rect(x + 12.0, base - 288.0, 162.0, 272.0, dark)
				p.fill_rect(x + 20.0, base - 280.0, 68.0, 256.0, colors[3])
				p.fill_rect(x + 98.0, base - 280.0, 68.0, 256.0, colors[3])
				for lock: int in 3:
					p.fill_rect(x + 72.0, base - 230.0 + float(lock) * 73.0, 42.0, 10.0, body)
		_machine_details(p, x, base, world, colors)
		if world >= 5:
			# Material factory: equipment and conduits are decorative, never terrain.
			var accent: Color = Color(WorldCatalog.accent(world + 1), 0.24)
			p.fill_rect(x, base - 20.0, 180.0, 20.0, edge)
			p.fill_rect(x + 12.0, base - 220.0, 156.0, 200.0, body)
			p.stroke_round_rect(x + 24.0, base - 205.0, 132.0, 105.0, 6.0, accent, 2.0)
			for line: int in 4:
				p.fill_rect(x + 30.0, base - 88.0 + float(line) * 13.0, 115.0, 3.0, dark)
			TilePainter.draw(p, WorldCatalog.icon_tile(world + 1), x + 70.0, base - 180.0, 0.0)
			p.line(x + 90.0, base - 100.0, x + 90.0, base - 25.0, accent, 3.0)
		_draw_support_set(p, x, base, world, colors, variant)
	p.pop()
	# Midground utility rack: mounted equipment stays attached during parallax.
	p.push()
	p.translate(floorf(view.camera_position.x * 0.55), 0.0)
	left = view.camera_position.x * 0.45
	for bay: int in range(floori(left / 700.0) - 1, ceili((left + visible.size.x) / 700.0) + 1):
		var x: float = float(bay) * 700.0 + 690.0
		p.fill_rect(x, 0.0, 12.0, ground - 6.0, body)
		p.fill_rect(x - 5.0, ground - 6.0, 22.0, 6.0, edge)
		p.fill_rect(x - 14.0, ground - 124.0, 40.0, 54.0, body)
		for vent: int in 3:
			p.fill_rect(x - 8.0, ground - 114.0 + float(vent) * 9.0, 28.0, 3.0, dark)
	p.pop()


func _draw_depth(p: Painter, visible: Rect2, ground: float) -> void:
	p.fill_rect(visible.position.x, visible.position.y, visible.size.x, visible.size.y, Color("#0b141d"))
	_draw_rear_structure(p, visible, ground, BackdropTheme.PALETTES[0])
	# Ground elevation is shared by all layers. Only horizontal motion has
	# parallax, so supports never detach from their floor when the camera moves.
	p.fill_rect(visible.position.x, ground - 12.0, visible.size.x, 12.0, Color("#14232c"))
	p.fill_rect(visible.position.x, ground - 12.0, visible.size.x, 2.0, Color("#192a32"))
	p.push()
	p.translate(floorf(view.camera_position.x * 0.82), 0.0)
	var far_left: float = view.camera_position.x * 0.18
	for i: int in range(floori(far_left / 920.0) - 1, ceili((far_left + visible.size.x) / 920.0) + 1):
		var x: float = float(i) * 920.0
		# Different sizes, uneven gaps; all hardware rests on the rear floor.
		var variant: int = BackdropTheme.variant(i, 0)
		_grounded_tank(p, x + 350.0, ground - 12.0, 86.0 + float(variant) * 6.0, 196.0 + float(variant) * 12.0)
		_draw_support_set(p, x + 350.0, ground - 12.0, 0, BackdropTheme.PALETTES[0], variant)
	p.pop()
	p.push()
	p.translate(floorf(view.camera_position.x * 0.55), 0.0)
	var mid_left: float = view.camera_position.x * 0.45
	for i: int in range(floori(mid_left / 620.0) - 1, ceili((mid_left + visible.size.x) / 620.0) + 1):
		var x: float = float(i) * 620.0 + 560.0
		# Structural column runs from ceiling into its anchored foot.
		p.fill_rect(x, 0.0, 14.0, ground - 6.0, Color("#152630"))
		p.fill_rect(x + 2.0, 0.0, 2.0, ground - 6.0, Color("#1c2d36"))
		p.fill_rect(x - 6.0, ground - 8.0, 26.0, 8.0, Color("#1e3038"))
		# Small wall-mounted junction box and conduit fixed to that column.
		p.fill_rect(x - 7.0, ground - 146.0, 28.0, 32.0, Color("#1a2c35"))
		p.fill_rect(x - 4.0, ground - 143.0, 22.0, 26.0, Color("#13242d"))
		p.fill_rect(x + 6.0, ground - 114.0, 4.0, 106.0, Color("#1f323a"))
	p.pop()


func _grounded_tank(p: Painter, x: float, floor_y: float, width: float, height: float) -> void:
	var top: float = floor_y - height - 20.0
	# Supply pipe physically meets the vessel cap, in the same parallax layer.
	p.fill_rect(x + width * 0.5 - 4.0, 0.0, 8.0, top + 4.0, Color("#15262e"))
	p.fill_rect(x + width * 0.5 - 7.0, top - 6.0, 14.0, 6.0, Color("#1b2e35"))
	p.fill_rect(x + 6.0, top, width - 12.0, 8.0, Color("#1a2d34"))
	p.fill_rect(x, top + 8.0, width, height - 8.0, Color("#14262e"))
	p.fill_rect(x + 7.0, top + 16.0, width - 14.0, height - 26.0, Color("#102029"))
	p.fill_rect(x + 10.0, top + 21.0, 2.0, height - 37.0, Color("#1a3036"))
	p.fill_rect(x + 7.0, floor_y - 59.0, width - 14.0, 29.0, Color("#14282f"))
	p.fill_rect(x, floor_y - 28.0, width, 8.0, Color("#1a2c34"))
	# Feet meet a continuous plinth; plinth meets the rear floor.
	p.fill_rect(x + 8.0, floor_y - 20.0, 9.0, 14.0, Color("#1b2d35"))
	p.fill_rect(x + width - 17.0, floor_y - 20.0, 9.0, 14.0, Color("#1b2d35"))
	p.fill_rect(x - 6.0, floor_y - 6.0, width + 12.0, 6.0, Color("#21313a"))
	# Collar bolts, volume marks and an attached return line describe the vessel.
	for dx: float in [10.0, width - 14.0]:
		p.fill_rect(x + dx, top + 3.0, 3.0, 3.0, Color("#25383e"))
		p.fill_rect(x + dx, floor_y - 25.0, 3.0, 3.0, Color("#24363d"))
	for mark: int in 4:
		p.fill_rect(x + width - 19.0, top + 35.0 + float(mark) * 23.0, 7.0, 2.0, Color("#1b3036"))
	p.fill_rect(x + width, floor_y - 52.0, 14.0, 6.0, Color("#182c34"))
	p.fill_rect(x + width + 10.0, floor_y - 52.0, 4.0, 46.0, Color("#182c34"))
	p.fill_rect(x + width + 7.0, floor_y - 30.0, 10.0, 4.0, Color("#23363d"))
	p.fill_rect(x - 4.0, floor_y - 2.0, width + 8.0, 2.0, Color("#0c1921"))


func _draw_rear_structure(p: Painter, visible: Rect2, ground: float, colors: PackedColorArray) -> void:
	# Very distant wall ribs and a supported overhead beam. No bright horizon.
	var shade: Color = colors[0].darkened(0.18)
	p.push()
	p.translate(floorf(view.camera_position.x * 0.92), 0.0)
	var left: float = view.camera_position.x * 0.08
	for rib: int in range(floori(left / 310.0) - 1, ceili((left + visible.size.x) / 310.0) + 1):
		var x: float = float(rib) * 310.0 + 80.0
		p.fill_rect(x, 0.0, 18.0, ground - 12.0, shade)
		p.fill_rect(x + 18.0, 90.0, 292.0, 12.0, shade)
		p.fill_rect(x + 18.0, 102.0, 22.0, 8.0, shade)
		p.fill_rect(x + 18.0, 110.0, 12.0, 10.0, shade)
	p.pop()


func _machine_details(p: Painter, x: float, base: float, world: int, colors: PackedColorArray) -> void:
	var edge: Color = colors[2]
	var shade: Color = colors[0].darkened(0.25)
	var trim: Color = colors[1].lerp(edge, 0.6)
	match world:
		1:
			# Guide rails seat the press head; a mounted hydraulic pack feeds it.
			for dx: float in [24.0, 146.0]:
				p.fill_rect(x + dx, base - 240.0, 5.0, 190.0, trim)
			p.fill_rect(x + 37.0, base - 135.0, 102.0, 3.0, edge)
			p.fill_rect(x + 78.0, base - 239.0, 4.0, 95.0, trim)
			p.fill_rect(x + 4.0, base - 98.0, 30.0, 45.0, trim)
			p.fill_rect(x + 9.0, base - 92.0, 20.0, 18.0, shade)
			p.fill_rect(x + 13.0, base - 88.0, 3.0, 9.0, colors[1])
			p.fill_rect(x + 7.0, base - 208.0, 4.0, 110.0, edge)
			p.fill_rect(x + 7.0, base - 208.0, 69.0, 4.0, edge)
			for groove: int in 5:
				p.fill_rect(x + 38.0 + groove * 21.0, base - 40.0, 2.0, 17.0, shade)
		2:
			# Sight-window seal, fixed agitator axle and an outlet reaching the slab.
			p.stroke_rect(x + 62.0, base - 150.0, 66.0, 61.0, trim, 2.0)
			p.fill_rect(x + 89.0, base - 145.0, 4.0, 45.0, colors[1])
			p.fill_rect(x + 80.0, base - 112.0, 22.0, 4.0, colors[1])
			p.fill_rect(x + 179.0, base - 90.0, 22.0, 7.0, trim)
			p.fill_rect(x + 196.0, base - 90.0, 5.0, 90.0, trim)
			p.fill_rect(x + 191.0, base - 61.0, 15.0, 5.0, edge)
			for dx: float in [26.0, 154.0]:
				p.fill_rect(x + dx, base - 181.0, 4.0, 3.0, shade)
				p.fill_rect(x + dx, base - 73.0, 4.0, 3.0, shade)
		3:
			# Side rails, inspection caps and a second manifold joining both towers.
			for tower: int in 2:
				var tx: float = x + float(tower) * 102.0
				var h: float = 248.0 - float(tower) * 56.0
				p.fill_rect(tx + 3.0, base - h + 5.0, 2.0, h - 22.0, trim)
				p.fill_rect(tx + 14.0, base - 35.0, 44.0, 14.0, colors[3])
				p.fill_rect(tx + 18.0, base - 31.0, 4.0, 3.0, edge)
				p.fill_rect(tx + 50.0, base - 31.0, 4.0, 3.0, edge)
			p.fill_rect(x + 72.0, base - 146.0, 30.0, 7.0, trim)
			for dx: float in [75.0, 95.0]:
				p.fill_rect(x + dx, base - 149.0, 4.0, 13.0, edge)
		4:
			# Door tracks, locking sockets and an attached reader, all inert.
			for dx: float in [6.0, 178.0]:
				p.fill_rect(x + dx, base - 287.0, 2.0, 273.0, trim)
			for lock: int in 3:
				var y: float = base - 234.0 + float(lock) * 73.0
				p.fill_rect(x + 66.0, y, 9.0, 18.0, trim)
				p.fill_rect(x + 113.0, y, 9.0, 18.0, trim)
			p.fill_rect(x + 186.0, base - 180.0, 24.0, 45.0, trim)
			p.fill_rect(x + 191.0, base - 174.0, 14.0, 18.0, shade)
			p.fill_rect(x + 195.0, base - 135.0, 4.0, 127.0, colors[1])
			p.fill_rect(x + 30.0, base - 272.0, 47.0, 2.0, trim)
			p.fill_rect(x + 108.0, base - 272.0, 47.0, 2.0, trim)
	# A few anchor bolts and a contact shadow give weight without particles.
	for dx: float in [2.0, 166.0]:
		p.fill_rect(x + dx, base - 6.0, 4.0, 3.0, shade)
	p.fill_rect(x - 5.0, base - 2.0, 187.0, 2.0, shade)

## Each hall has its main machine, overhead equipment and three different
## grounded support devices, plus the existing midground utility column.
func _draw_support_set(p: Painter, x: float, base: float, world: int, colors: PackedColorArray, variant: int = 0) -> void:
	var types: Array = BackdropTheme.SUPPORT_TYPES[world]
	# Wall brackets meet a ceiling-mounted rail. No unsupported hanging props.
	var y: float = base - 372.0
	var wx: float = x + 82.0
	var dark: Color = colors[0].darkened(0.2)
	var body: Color = colors[1]
	var edge: Color = colors[2]
	p.fill_rect(wx + 5.0, 0.0, 5.0, y + 48.0, body)
	p.fill_rect(wx + 65.0, 0.0, 5.0, y + 48.0, body)
	p.fill_rect(wx, y, 76.0, 48.0, body)
	p.fill_rect(wx + 4.0, y + 4.0, 68.0, 40.0, dark)
	if world == 0 or world == 3:
		# Extractor grille / cooling ventilation, no rotating distraction.
		for slit: int in 5:
			p.fill_rect(wx + 10.0, y + 9.0 + slit * 6.0, 56.0, 2.0, edge)
	elif world == 1 or world == 2:
		# Twin pressure gauges mounted in a shared manifold panel.
		for gx: float in [22.0, 53.0]:
			p.stroke_circle(wx + gx, y + 24.0, 10.0, edge, 2.0)
			p.line(wx + gx, y + 24.0, wx + gx + 4.0, y + 19.0, edge, 2.0)
	else:
		# Inert monitoring console: three dim screens, not glowing indicators.
		for screen: int in 3:
			p.fill_rect(wx + 9.0 + screen * 21.0, y + 10.0, 16.0, 20.0, body)
			p.fill_rect(wx + 11.0 + screen * 21.0, y + 34.0, 10.0, 2.0, edge)
	for item: int in 3:
		var offset: float = [226.0, 340.0, 486.0][item] + float(posmod(variant + item, 3)) * 12.0
		BackdropProps.draw(p, x + offset, base, types[posmod(item + variant, 3)] as int, colors)


func _draw_wall_tile(p: Painter, x: float, y: float, world: int, colors: PackedColorArray, row: int, col: int) -> void:
	p.fill_rect(x, y, Tile.SIZE, Tile.SIZE, colors[0])
	p.fill_rect(x + 1.0, y + 1.0, Tile.SIZE - 2.0, Tile.SIZE - 2.0, colors[1])
	p.fill_rect(x + 1.0, y + 1.0, Tile.SIZE - 2.0, 1.0, colors[2])
	p.fill_rect(x + 1.0, y + 2.0, 1.0, Tile.SIZE - 3.0, colors[2])
	p.fill_rect(x + 2.0, y + Tile.SIZE - 2.0, Tile.SIZE - 3.0, 1.0, colors[3])
	# Sparse static surface marks, avoiding a second grid or noisy texture.
	if posmod(row * 3 + col, 7) != 0:
		return
	match world:
		1: # Warm pressed panels: a small recessed horizontal seam.
			p.fill_rect(x + 9.0, y + 27.0, 13.0, 1.0, colors[3])
			p.fill_rect(x + 22.0, y + 25.0, 5.0, 1.0, colors[3])
		2: # Muted polymer panels: a tiny paired moulding groove.
			p.fill_rect(x + 11.0, y + 12.0, 1.0, 6.0, colors[3])
			p.fill_rect(x + 14.0, y + 12.0, 1.0, 6.0, colors[3])
		3: # Cool glazed panels: one subdued bevel reflection.
			p.fill_rect(x + 8.0, y + 7.0, 8.0, 1.0, colors[2].lerp(colors[1], 0.5))
		4: # Dark core panels: a recessed small corner joint.
			p.fill_rect(x + 26.0, y + 26.0, 5.0, 1.0, colors[3])
			p.fill_rect(x + 30.0, y + 22.0, 1.0, 4.0, colors[3])
