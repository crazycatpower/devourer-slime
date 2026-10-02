class_name UiFonts
extends RefCounted
## The project theme's fonts, for code that draws text by hand.

const THEME_PATH: String = "res://src/ui/theme/game_theme.tres"

static var _regular: Font
static var _bold: Font


static func regular() -> Font:
	_ensure_loaded()
	return _regular


static func bold() -> Font:
	_ensure_loaded()
	return _bold


static func _ensure_loaded() -> void:
	if _regular != null:
		return
	_regular = ThemeDB.fallback_font
	_bold = ThemeDB.fallback_font
	if not ResourceLoader.exists(THEME_PATH):
		return
	var theme: Theme = load(THEME_PATH) as Theme
	if theme == null:
		return
	if theme.default_font != null:
		_regular = theme.default_font
		_bold = theme.default_font
	if theme.has_font(&"font", &"HeadingLabel"):
		_bold = theme.get_font(&"font", &"HeadingLabel")
