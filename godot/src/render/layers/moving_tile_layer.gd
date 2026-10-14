class_name MovingTileLayer
extends WorldLayer
## Smooth movement for every material transported by rails, sand or ice.


func _paint(p: Painter, sim: GameSim) -> void:
	if view.editor != null:
		return
	var time: float = float(sim.tick_count - 1) + view.tick_alpha
	var visible: Rect2 = view.visible_world_rect().grow(Tile.SIZE)
	for cell: Vector2i in sim.tile_motions:
		var motion: GameSim.TileMotion = sim.tile_motions[cell]
		if sim.level.get_cell(cell.y, cell.x) != motion.type:
			continue
		if sim.player.has_eating_target and not sim.player.eating_target_is_boss_cell and Vector2i(sim.player.eating_target_c, sim.player.eating_target_r) == cell:
			continue
		var at: Vector2 = motion.position_at(time)
		if not visible.intersects(Rect2(at, Vector2.ONE * Tile.SIZE)):
			continue
		# A restrained contact shadow helps the moving block read above the track.
		p.fill_round_rect(at.x + 3.0, at.y + 5.0, Tile.SIZE - 4.0, Tile.SIZE - 3.0, 5.0, Color(Palette.SLATE_950, 0.25))
		var progress: float = clampf((time - motion.start_tick) / maxf(1.0, motion.duration), 0.0, 1.0)
		var travel: Vector2 = Vector2(motion.destination) * Tile.SIZE - motion.origin
		if motion.type == Tile.ICE and absf(travel.x) > 1.0:
			var behind: float = at.x - 4.0 if travel.x > 0.0 else at.x + Tile.SIZE + 4.0
			var tail: float = behind - signf(travel.x) * 10.0 * sin(progress * PI)
			for height: float in [12.0, 25.0]:
				p.line(behind, at.y + height, tail, at.y + height, Color(Palette.CYAN_400, 0.32), 1.5)
		elif motion.type == Tile.SAND and travel.y > 1.0 and progress > 0.05 and progress < 0.95:
			for index: int in 3:
				var grain_x: float = at.x + 8.0 + float(index) * 11.0
				var grain_y: float = at.y - 3.0 - float(index % 2) * 4.0
				p.fill_rect(grain_x, grain_y, 2.0, 2.0, Color(Palette.AMBER_400, 0.5))
		if Tile.is_bouncy(motion.type):
			var squash: float = sin(progress * PI) * 0.03
			p.push()
			p.translate(at.x + Tile.SIZE * 0.5, at.y + Tile.SIZE * 0.5)
			p.scale(1.0 + squash, 1.0 - squash)
			TilePainter.draw(p, motion.type, -Tile.SIZE * 0.5, -Tile.SIZE * 0.5, view.time_ms)
			p.pop()
		else:
			TilePainter.draw(p, motion.type, at.x, at.y, view.time_ms)
