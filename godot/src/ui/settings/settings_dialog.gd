class_name SettingsDialog
extends Control
## A modal dialog around a [SettingsPanel]. As the pause menu it carries
## the buttons for leaving the level; from the main menu it only closes.

signal closed
signal menu_requested
signal editor_requested

## Extra buttons shown next to the close button.
enum Context { MAIN_MENU, PLAYING, TEST_PLAYING }

@onready var _title: Label = %DialogTitle
@onready var _settings: SettingsPanel = %SettingsPanel
@onready var _close_button: Button = %CloseButton
@onready var _menu_button: Button = %MenuButton
@onready var _editor_button: Button = %EditorButton
@onready var _resume_button: Button = %ResumeButton
@onready var _panel: PanelContainer = %Panel
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	# The dialog must keep working while the game behind it is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(close)
	_resume_button.pressed.connect(close)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_editor_button.pressed.connect(func() -> void: editor_requested.emit())
	visible = false


func open(context: Context) -> void:
	var playing: bool = context != Context.MAIN_MENU
	_title.text = "遊戲設定 MENU" if playing else "設定 SETTINGS"
	_menu_button.visible = playing
	_editor_button.visible = context == Context.TEST_PLAYING
	_resume_button.text = "繼續遊戲" if playing else "完成"
	visible = true
	UiMotion.pop_in(_panel, _dim)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel") and not _settings.is_capturing():
		get_viewport().set_input_as_handled()
		close()
