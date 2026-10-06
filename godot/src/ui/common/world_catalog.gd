class_name WorldCatalog
extends RefCounted
## Look of each of the five worlds in the menus: its accent colours and the
## tile that stands for it.


## Presentation order of worlds: World 1 through World 5 in natural sequence.
const ORDER: Array[int] = [1, 2, 3, 4, 5]


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
	return Palette.SLATE_600


## The tile each world is themed around.
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
	return Tile.STEEL


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
