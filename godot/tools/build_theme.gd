extends SceneTree
## Generates the project's UI theme, `res://src/ui/theme/game_theme.tres`.
##
## The theme is defined here in code and saved as a resource, so the look of
## every control lives in one reviewable place and the editor still shows
## themed scenes. Re-run after changing this file:
##
##   godot --headless --path godot -s res://tools/build_theme.gd

const OUT_PATH: String = "res://src/ui/theme/game_theme.tres"
const FONT_PATH: String = "res://assets/fonts/NotoSansTC-VariableFont_wght.ttf"

const TEXT: Color = Color("f1f5f9")
const TEXT_MUTED: Color = Palette.SLATE_400
const SURFACE: Color = Color("0d1226")
const SURFACE_RAISED: Color = Palette.SLATE_800
const SURFACE_SUNKEN: Color = Palette.SLATE_950
const OUTLINE: Color = Palette.SLATE_700
const ACCENT: Color = Palette.EMERALD_500
const ACCENT_DARK: Color = Palette.EMERALD_600
const DANGER: Color = Palette.RED_600
const INDIGO: Color = Palette.INDIGO_500

var _theme: Theme = Theme.new()


func _initialize() -> void:
	var base_font: FontFile = load(FONT_PATH) as FontFile
	if base_font == null:
		push_error("build_theme: cannot load %s (run --import first)" % FONT_PATH)
		quit(1)
		return
	var regular: FontVariation = _weight(base_font, 500)
	var bold: FontVariation = _weight(base_font, 800)
	var black: FontVariation = _weight(base_font, 900)

	_theme.default_font = regular
	_theme.default_font_size = 26

	_build_labels(bold, black)
	_build_buttons(bold)
	_build_panels()
	_build_inputs()
	_build_sliders()
	_build_scrollbars()

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var error: Error = ResourceSaver.save(_theme, OUT_PATH)
	if error != OK:
		push_error("build_theme: cannot save %s (%s)" % [OUT_PATH, error_string(error)])
		quit(1)
		return
	print("Wrote %s" % OUT_PATH)
	quit(0)


func _weight(base: FontFile, weight: int) -> FontVariation:
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	variation.variation_opentype = {tag: weight}
	return variation


func _box(
	fill: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 14,
	pad_x: int = 24, pad_y: int = 12
) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	return box


func _build_labels(bold: Font, black: Font) -> void:
	_theme.set_color(&"font_color", &"Label", TEXT)

	_variation(&"TitleLabel", &"Label")
	_theme.set_font(&"font", &"TitleLabel", black)
	_theme.set_font_size(&"font_size", &"TitleLabel", 54)

	_variation(&"HeadingLabel", &"Label")
	_theme.set_font(&"font", &"HeadingLabel", bold)
	_theme.set_font_size(&"font_size", &"HeadingLabel", 30)

	_variation(&"CaptionLabel", &"Label")
	_theme.set_font(&"font", &"CaptionLabel", bold)
	_theme.set_font_size(&"font_size", &"CaptionLabel", 19)
	_theme.set_color(&"font_color", &"CaptionLabel", TEXT_MUTED)

	_variation(&"NumberLabel", &"Label")
	_theme.set_font(&"font", &"NumberLabel", black)
	_theme.set_font_size(&"font_size", &"NumberLabel", 84)

	_variation(&"OverlayTitleLabel", &"Label")
	_theme.set_font(&"font", &"OverlayTitleLabel", black)
	_theme.set_font_size(&"font_size", &"OverlayTitleLabel", 112)

	_variation(&"BadgeLabel", &"Label")
	_theme.set_font(&"font", &"BadgeLabel", bold)
	_theme.set_font_size(&"font_size", &"BadgeLabel", 17)
	_theme.set_stylebox(&"normal", &"BadgeLabel", _box(SURFACE_SUNKEN, OUTLINE, 1, 8, 12, 4))


func _build_buttons(bold: Font) -> void:
	_button_style(&"Button", SURFACE_RAISED, OUTLINE, Palette.SLATE_300)
	_theme.set_font(&"font", &"Button", bold)
	_theme.set_font_size(&"font_size", &"Button", 22)
	_theme.set_constant(&"h_separation", &"Button", 10)

	# The main call to action on a screen.
	_variation(&"AccentButton", &"Button")
	_button_style(&"AccentButton", ACCENT_DARK, Color(ACCENT, 0.6), Palette.WHITE)

	# Something destructive.
	_variation(&"DangerButton", &"Button")
	_button_style(&"DangerButton", Color(DANGER, 0.85), Palette.RED_400, Palette.WHITE)

	# Editor-flavoured actions.
	_variation(&"IndigoButton", &"Button")
	_button_style(&"IndigoButton", Palette.INDIGO_600, Color(Palette.INDIGO_400, 0.5), Palette.WHITE)

	# Small, quiet buttons: tabs, toggles, steppers.
	_variation(&"ChipButton", &"Button")
	_button_style(&"ChipButton", SURFACE_SUNKEN, Palette.SLATE_800, TEXT_MUTED, 10, 16, 8)
	_theme.set_font_size(&"font_size", &"ChipButton", 19)
	# Chips are toggles: the pressed look marks the selected one.
	_theme.set_stylebox(&"pressed", &"ChipButton", _box(Color(ACCENT, 0.2), Color(ACCENT, 0.7), 2, 10, 16, 8))
	_theme.set_stylebox(&"hover_pressed", &"ChipButton", _box(Color(ACCENT, 0.28), ACCENT, 2, 10, 16, 8))
	_theme.set_color(&"font_pressed_color", &"ChipButton", Palette.EMERALD_400)
	_theme.set_color(&"font_hover_pressed_color", &"ChipButton", Palette.EMERALD_400)


func _button_style(
	type: StringName, fill: Color, border: Color, font_color: Color, radius: int = 14,
	pad_x: int = 24, pad_y: int = 12
) -> void:
	_theme.set_stylebox(&"normal", type, _box(fill, border, 2, radius, pad_x, pad_y))
	_theme.set_stylebox(&"hover", type, _box(fill.lightened(0.12), border.lightened(0.2), 2, radius, pad_x, pad_y))
	_theme.set_stylebox(&"pressed", type, _box(fill.darkened(0.2), border, 2, radius, pad_x, pad_y))
	_theme.set_stylebox(&"hover_pressed", type, _box(fill.darkened(0.1), border, 2, radius, pad_x, pad_y))
	_theme.set_stylebox(
		&"disabled", type, _box(Color(fill, fill.a * 0.35), Color(border, border.a * 0.3), 2, radius, pad_x, pad_y)
	)
	var focus: StyleBoxFlat = _box(Color.TRANSPARENT, Palette.EMERALD_400, 2, radius, pad_x, pad_y)
	focus.draw_center = false
	focus.expand_margin_left = 3.0
	focus.expand_margin_right = 3.0
	focus.expand_margin_top = 3.0
	focus.expand_margin_bottom = 3.0
	_theme.set_stylebox(&"focus", type, focus)
	_theme.set_color(&"font_color", type, font_color)
	_theme.set_color(&"font_hover_color", type, Palette.WHITE)
	_theme.set_color(&"font_pressed_color", type, font_color)
	_theme.set_color(&"font_hover_pressed_color", type, font_color)
	_theme.set_color(&"font_focus_color", type, font_color)
	_theme.set_color(&"font_disabled_color", type, Color(font_color, 0.35))
	_theme.set_color(&"icon_normal_color", type, font_color)


func _build_panels() -> void:
	_theme.set_stylebox(&"panel", &"PanelContainer", _box(SURFACE, Palette.SLATE_800, 2, 20, 24, 20))
	_theme.set_stylebox(&"panel", &"Panel", _box(SURFACE, Palette.SLATE_800, 2, 20, 0, 0))

	_variation(&"CardPanel", &"PanelContainer")
	_theme.set_stylebox(&"panel", &"CardPanel", _box(Color("0c1024"), Color(Palette.SLATE_700, 0.6), 2, 20, 22, 18))

	_variation(&"ModalPanel", &"PanelContainer")
	var modal: StyleBoxFlat = _box(Palette.SLATE_900, OUTLINE, 2, 22, 0, 0)
	modal.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	modal.shadow_size = 40
	_theme.set_stylebox(&"panel", &"ModalPanel", modal)

	_variation(&"BarPanel", &"PanelContainer")
	_theme.set_stylebox(&"panel", &"BarPanel", _box(Color("0b0f1f"), Palette.SLATE_800, 0, 0, 28, 12))

	_variation(&"InsetPanel", &"PanelContainer")
	_theme.set_stylebox(&"panel", &"InsetPanel", _box(Color(SURFACE_SUNKEN, 0.6), Palette.SLATE_800, 2, 14, 18, 14))

	_variation(&"ToastPanel", &"PanelContainer")
	var toast: StyleBoxFlat = _box(ACCENT_DARK, Color(Palette.EMERALD_400, 0.6), 2, 28, 30, 12)
	toast.shadow_color = Color(Palette.EMERALD_500, 0.35)
	toast.shadow_size = 18
	_theme.set_stylebox(&"panel", &"ToastPanel", toast)

	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = Palette.SLATE_800
	separator.thickness = 2
	_theme.set_stylebox(&"separator", &"HSeparator", separator)
	_theme.set_constant(&"separation", &"HSeparator", 12)

	_theme.set_stylebox(&"panel", &"TooltipPanel", _box(Palette.SLATE_950, OUTLINE, 1, 8, 12, 6))
	_theme.set_color(&"font_color", &"TooltipLabel", TEXT)
	_theme.set_font_size(&"font_size", &"TooltipLabel", 19)


func _build_inputs() -> void:
	for type: StringName in [&"LineEdit", &"TextEdit"]:
		_theme.set_stylebox(&"normal", type, _box(SURFACE_SUNKEN, Palette.SLATE_800, 2, 10, 14, 10))
		_theme.set_stylebox(&"focus", type, _box(SURFACE_SUNKEN, INDIGO, 2, 10, 14, 10))
		_theme.set_stylebox(&"read_only", type, _box(SURFACE_SUNKEN, Palette.SLATE_800, 2, 10, 14, 10))
		_theme.set_color(&"font_color", type, Palette.SLATE_300)
		_theme.set_color(&"font_placeholder_color", type, Palette.SLATE_600)
		_theme.set_color(&"caret_color", type, TEXT)
		_theme.set_color(&"selection_color", type, Color(INDIGO, 0.5))
		_theme.set_font_size(&"font_size", type, 18)
	_theme.set_color(&"background_color", &"TextEdit", Color.TRANSPARENT)


func _build_sliders() -> void:
	var track: StyleBoxFlat = _box(SURFACE_RAISED, Color.TRANSPARENT, 0, 6, 0, 0)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	var fill: StyleBoxFlat = _box(ACCENT, Color.TRANSPARENT, 0, 6, 0, 0)
	_theme.set_stylebox(&"slider", &"HSlider", track)
	_theme.set_stylebox(&"grabber_area", &"HSlider", fill)
	_theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	_theme.set_icon(&"grabber", &"HSlider", _disc(26, Palette.WHITE))
	_theme.set_icon(&"grabber_highlight", &"HSlider", _disc(30, Palette.EMERALD_400))
	_theme.set_icon(&"grabber_disabled", &"HSlider", _disc(26, Palette.SLATE_500))


func _build_scrollbars() -> void:
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		var gutter: StyleBoxFlat = _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 5, 5, 5)
		_theme.set_stylebox(&"scroll", type, gutter)
		_theme.set_stylebox(&"scroll_focus", type, gutter)
		_theme.set_stylebox(&"grabber", type, _box(Palette.SLATE_800, Color.TRANSPARENT, 0, 5, 0, 0))
		_theme.set_stylebox(&"grabber_highlight", type, _box(Palette.SLATE_700, Color.TRANSPARENT, 0, 5, 0, 0))
		_theme.set_stylebox(&"grabber_pressed", type, _box(Palette.SLATE_600, Color.TRANSPARENT, 0, 5, 0, 0))


## Anti-aliased filled circle as a texture.
func _disc(diameter: int, color: Color) -> ImageTexture:
	var image: Image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center: float = float(diameter) / 2.0
	var radius: float = center - 1.0
	for y: int in diameter:
		for x: int in diameter:
			var distance: float = Vector2(float(x) + 0.5 - center, float(y) + 0.5 - center).length()
			image.set_pixel(x, y, Color(color, clampf(radius - distance + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _variation(type: StringName, base: StringName) -> void:
	_theme.set_type_variation(type, base)
