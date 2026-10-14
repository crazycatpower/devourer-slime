extends Node2D
## Material comparison sheet; this is a drawing, never a playable/custom map.

const TYPES: Array[int] = [Tile.DIRT, Tile.STEEL, Tile.BOUNCY, Tile.GLASS, Tile.ICE, Tile.SAND, Tile.TNT, Tile.VOID,
	Tile.SPIKE_UP, Tile.SPIKE_RIGHT, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT, Tile.SENSOR, Tile.RAIL_RIGHT, Tile.GOAL, Tile.DIRT_EATEN_1]
const LABELS: Array[String] = ["泥土", "鋼鐵", "彈力", "玻璃", "冰", "沙子", "TNT", "虛空",
	"尖刺・上", "尖刺・右", "尖刺・下", "尖刺・左", "感測器", "軌道", "終點", "吞噬後"]


func _draw() -> void:
	var factor: float = get_viewport_rect().size.x / 1280.0
	var p: Painter = Painter.new(self, factor)
	p.scale(factor, factor)
	p.fill_rect(0, 0, 1280, 720, Color("#101b24"))
	p.text("方塊風格檢查", 40, 42, 24, Palette.WHITE, true, Painter.Align.LEFT)
	p.text("放大輪廓 ／ 遊戲尺寸 ／ 吞吐材質一致性", 40, 72, 13, Palette.SLATE_400, false, Painter.Align.LEFT)
	p.push()
	p.translate(1130.0, 18.0)
	p.scale(1.5, 1.5)
	SlimeFace.paint_body(p)
	SlimeFace.paint(p, SlimeMotion.new(), Vector2.ZERO)
	p.pop()
	for index: int in TYPES.size():
		var x: float = 40.0 + float(index % 8) * 153.0
		var y: float = 110.0 + floorf(float(index) / 8.0) * 260.0
		p.fill_round_rect(x - 9, y - 7, 138, 228, 12, Color("#16252e"))
		p.push()
		p.translate(x, y)
		p.scale(2.8, 2.8)
		TilePainter.draw(p, TYPES[index], 0, 0, 0)
		p.pop()
		p.text(LABELS[index], x + 56, y + 143, 15, Palette.ZINC_200, true)
		TilePainter.draw(p, TYPES[index], x + 10, y + 165, 0)
		if Tile.is_solid(TYPES[index]):
			TilePainter.draw_projectile(p, TYPES[index], x + 79, y + 175, 24, 24)
	p.text("玩家與泥土為基準：圓角、平塗、少量材質符號；危險輪廓保留。", 40, 690, 16, Palette.SLATE_400, false, Painter.Align.LEFT)
