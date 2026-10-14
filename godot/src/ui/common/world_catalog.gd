class_name WorldCatalog
extends RefCounted
## Look of each world in the menus: its accent colours and the tile that
## stands for it.


## Presentation order of worlds, by internal world number. Natural sequence;
## one entry per world in [constant GameConstants.WORLD_COUNT].
const ORDER: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]


static func display_world(world: int) -> int:
	return ORDER.find(world) + 1


static func next_slot(slot: int) -> int:
	if GameConstants.level_in_world(slot) < GameConstants.LEVELS_PER_WORLD:
		return slot + 1
	var next_world_index: int = display_world(GameConstants.world_of_slot(slot))
	if next_world_index >= ORDER.size():
		return 0
	return (ORDER[next_world_index] - 1) * GameConstants.LEVELS_PER_WORLD + 1


## Bright colour for text and highlights.
static func accent(world: int) -> Color:
	match world:
		1:
			return Palette.SLATE_400
		2:
			return Palette.AMBER_500
		3:
			return Palette.PINK_400
		4:
			return Palette.CYAN_400
		5:
			return Palette.PURPLE_400
		6:
			return Palette.LIME_400
		7:
			return Palette.SKY_400
		8:
			return Palette.AMBER_400
		9:
			return Palette.FUCHSIA_400
		10:
			return Palette.RED_400
	return Palette.SLATE_400


## Deeper colour for filled buttons.
static func fill(world: int) -> Color:
	match world:
		1:
			return Palette.SLATE_600
		2:
			return Palette.AMBER_600
		3:
			return Palette.PINK_600
		4:
			return Palette.CYAN_600
		5:
			return Palette.PURPLE_600
		6:
			return Palette.GREEN_600
		7:
			return Palette.BLUE_500
		8:
			return Palette.AMBER_600
		9:
			return Palette.FUCHSIA_500
		10:
			return Palette.RED_600
	return Palette.SLATE_600


## The material each world is themed around.
static func icon_tile(world: int) -> int:
	match world:
		1:
			return Tile.STEEL
		2:
			return Tile.DIRT
		3:
			return Tile.BOUNCY
		4:
			return Tile.GLASS
		5:
			return Tile.VOID
		6: return Tile.SENSOR
		7: return Tile.ICE
		8: return Tile.SAND
		9: return Tile.RAIL_RIGHT
		10: return Tile.TNT
	return Tile.STEEL


static func name_for(world: int) -> String:
	return ["鋼鐵", "泥土", "彈力", "玻璃", "虛空", "感測器", "冰", "沙子", "軌道", "TNT"][clampi(world - 1, 0, 9)]


static func lesson(world: int, index: int) -> String:
	var authored: String = LevelLibrary.stage_hint((world - 1) * GameConstants.LEVELS_PER_WORLD + index)
	if not authored.is_empty():
		return authored
	var lessons: Array[String] = []
	match world:
		6: lessons = ["感測器可以穿過；方塊覆蓋時通電", "拉線可傳遞信號，切線便停止", "感測器可被覆蓋，吞下覆蓋方塊便斷電"]
		7: lessons = ["冰面摩擦低，提早煞車與轉向", "吐出的冰會持續滑到牆壁，也能沿天花板滑行", "吞下冰後，普通地面也會降低摩擦"]
		8: lessons = ["沙子失去支撐便向下掉落", "下落的沙子能覆蓋感測器", "冰與沙子碰到尖刺會被破壞"]
		9: lessons = ["軌道可被方塊覆蓋，收到信號便運送方塊", "軌道可以轉彎，也能向上或向下", "站在運行的方塊上會被一起運送，小心擠壓"]
		10: lessons = ["TNT 被射中、收到信號或吐出後，0.4 秒爆炸", "吞下 TNT 後，劇烈撞擊會留下點燃的 TNT", "連鎖 TNT 各有倒數，提早離開爆炸範圍"]
	if lessons.is_empty():
		return ""
	return lessons[mini(2, maxi(0, int(float(index - 1) / 3.0)))]


## Gives [param button] a filled look in [param color], for world-coloured
## calls to action.
static func tint_button(button: Button, color: Color) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		var shade: Color = color
		if state == &"hover":
			shade = color.lightened(0.12)
		elif state == &"pressed" or state == &"hover_pressed":
			shade = color.darkened(0.18)
		box.bg_color = shade
		box.border_color = color.lightened(0.25)
		box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		box.content_margin_left = 24.0
		box.content_margin_right = 24.0
		box.content_margin_top = 12.0
		box.content_margin_bottom = 12.0
		box.anti_aliasing = true
		button.add_theme_stylebox_override(state, box)
	for color_name: StringName in [
		&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
		&"font_focus_color",
	]:
		button.add_theme_color_override(color_name, Palette.WHITE)
