class_name FallingBlockLayer
extends WorldLayer
## Blocks dropping from the ceiling in boss fights: a pulsing warning column
## first, then a black block that kills on touch.

const HALF: float = Tile.SIZE / 2.0


func _paint(p: Painter, sim: GameSim) -> void:
	var level_height: float = sim.level.pixel_height()
	for block: SimFallingBlock in sim.falling_blocks:
		if block.delay > 0:
			var pulse: float = 0.2 + 0.25 * absf(sin(float(block.delay) * 0.25))
			p.fill_rect(block.x - HALF, 0.0, Tile.SIZE, level_height, Color(Palette.RED_500, pulse))
			var edge: Color = Color(Palette.RED_500, minf(1.0, pulse * 1.8))
			p.line(block.x - HALF, 0.0, block.x - HALF, level_height, edge, 2.5)
			p.line(block.x + HALF, 0.0, block.x + HALF, level_height, edge, 2.5)
			p.icon_warning(block.x, Tile.SIZE + 18.0, 22.0, Palette.RED_500)
			continue

		var pos: Vector2 = view.tween_position(block.prev_x, block.prev_y, block.x, block.y)
		# A faint shaft below shows where it will land.
		p.fill_rect(pos.x - HALF, pos.y + HALF, Tile.SIZE, 600.0, Color(Palette.RED_500, 0.12))
		p.fill_rect(pos.x - HALF, pos.y - HALF, Tile.SIZE, Tile.SIZE, Palette.BLACK)
		p.stroke_rect(
			pos.x - HALF + 1.5, pos.y - HALF + 1.5, Tile.SIZE - 3.0, Tile.SIZE - 3.0,
			Palette.RED_500, 3.0
		)
		p.icon_skull(pos.x, pos.y, 20.0, Palette.RED_500)
