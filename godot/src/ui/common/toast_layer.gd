class_name ToastLayer
extends Control
## Short status messages that slide in at the top of the screen and fade
## away. A new message replaces the one on screen.

const VISIBLE_SEC: float = 2.6
const FADE_SEC: float = 0.25

var _panel: PanelContainer
var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ToastPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.theme_type_variation = &"HeadingLabel"
	_label.add_theme_font_size_override(&"font_size", 24)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false


func show_message(text: String) -> void:
	if text.is_empty():
		return
	_label.text = text
	_panel.visible = true
	_panel.reset_size()
	_panel.position = Vector2((size.x - _panel.size.x) / 2.0, 8.0)
	_panel.modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", 28.0, FADE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "modulate:a", 1.0, FADE_SEC)
	_tween.tween_interval(VISIBLE_SEC)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(_panel.hide)
