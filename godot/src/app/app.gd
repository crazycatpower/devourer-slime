class_name App
extends Control
## The application's root: shows one screen at a time and moves between the
## menu, the game and the level editor.
##
## Screens never reference each other. They announce what the player asked
## for through signals, and this node decides what to show next.

const MAIN_MENU: PackedScene = preload("res://src/ui/menu/main_menu.tscn")
const GAME_SCREEN: PackedScene = preload("res://src/game/game_screen.tscn")
const EDITOR_SCREEN: PackedScene = preload("res://src/editor/editor_screen.tscn")
const FADE_SEC: float = 0.14

## What the level select was showing, restored when the player comes back.
var _menu_world: int = WorldCatalog.ORDER[0]
var _menu_custom_tab: bool = false
var _screen: Control
## The editor, kept alive (hidden) while its level is being test-played.
var _suspended_editor: EditorScreen

@onready var _screens: Control = %Screens
@onready var _toasts: ToastLayer = %Toasts


func _ready() -> void:
	# Closing the window goes through _on_close_requested, so unsaved editor
	# work is never lost without asking.
	get_tree().auto_accept_quit = false
	var window_controller: WindowController = WindowController.new()
	window_controller.name = "WindowController"
	add_child(window_controller)
	show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()


func _on_close_requested() -> void:
	if _suspended_editor != null:
		_resume_editor()
	var editor: EditorScreen = _screen as EditorScreen
	if editor == null:
		get_tree().quit()
	else:
		editor.run_when_changes_settled(get_tree().quit.bind(0))


# --- Navigation ---------------------------------------------------------------------

func show_menu() -> void:
	_discard_suspended_editor()
	var menu: MainMenu = MAIN_MENU.instantiate()
	menu.setup(_menu_world, _menu_custom_tab)
	menu.play_requested.connect(play_official)
	menu.test_requested.connect(play_saved_test)
	menu.edit_requested.connect(edit_slot)
	_show(menu)


## Plays [param slot] as part of the game.
func play_official(slot: int) -> void:
	_remember_menu_state()
	_discard_suspended_editor()
	var game: GameScreen = GAME_SCREEN.instantiate()
	game.setup(slot, GameScreen.Mode.OFFICIAL)
	game.completed.connect(_on_official_level_completed)
	game.menu_requested.connect(show_menu)
	game.toast_requested.connect(_toasts.show_message)
	_show(game)


## Test-plays the level saved in [param slot]; leaving it opens the editor.
func play_saved_test(slot: int) -> void:
	_remember_menu_state()
	_discard_suspended_editor()
	var game: GameScreen = GAME_SCREEN.instantiate()
	game.setup(slot, GameScreen.Mode.TEST)
	game.completed.connect(
		func(done_slot: int) -> void:
			edit_slot(done_slot)
			_toasts.show_message("測試完成！已進入編輯模式")
	)
	game.editor_requested.connect(edit_slot.bind(slot))
	game.menu_requested.connect(show_menu)
	game.toast_requested.connect(_toasts.show_message)
	_show(game)


func edit_slot(slot: int) -> void:
	_remember_menu_state()
	_discard_suspended_editor()
	var editor: EditorScreen = EDITOR_SCREEN.instantiate()
	editor.setup(slot)
	editor.menu_requested.connect(show_menu)
	editor.test_requested.connect(_on_editor_test_requested)
	editor.toast_requested.connect(_toasts.show_message)
	_show(editor)


# --- Flow between screens ------------------------------------------------------------

func _on_official_level_completed(slot: int) -> void:
	var next_slot: int = WorldCatalog.next_slot(slot)
	if next_slot != 0:
		play_official(next_slot)
		_toasts.show_message("挑戰成功！前往下一關")
	else:
		show_menu()
		_toasts.show_message("恭喜通關全部關卡！")


## Test play from the editor runs on top of it: the editor is hidden, not
## closed, so its unsaved work and undo history survive the round trip.
func _on_editor_test_requested(slot: int, level: LevelData) -> void:
	var editor: EditorScreen = _screen as EditorScreen
	if editor == null:
		return
	_suspended_editor = editor
	_screens.remove_child(editor)
	_screen = null

	var game: GameScreen = GAME_SCREEN.instantiate()
	game.setup(slot, GameScreen.Mode.TEST, level)
	game.completed.connect(
		func(_done_slot: int) -> void:
			_resume_editor()
			_toasts.show_message("測試完成！已返回編輯模式")
	)
	game.editor_requested.connect(_resume_editor)
	game.menu_requested.connect(_resume_editor)
	game.toast_requested.connect(_toasts.show_message)
	_show(game)


func _resume_editor() -> void:
	if _suspended_editor == null:
		show_menu()
		return
	var editor: EditorScreen = _suspended_editor
	_suspended_editor = null
	_show(editor)


func _discard_suspended_editor() -> void:
	if _suspended_editor != null:
		_suspended_editor.queue_free()
		_suspended_editor = null


func _remember_menu_state() -> void:
	var menu: MainMenu = _screen as MainMenu
	if menu != null:
		_menu_world = menu.selected_world()
		_menu_custom_tab = menu.is_custom_tab()


## Replaces the current screen with [param screen], with a quick fade in.
func _show(screen: Control) -> void:
	get_tree().paused = false
	if _screen != null:
		_screens.remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	_screens.add_child(screen)
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, FADE_SEC)
