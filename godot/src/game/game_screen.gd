class_name GameScreen
extends Control
## Plays one level: owns the [GameSim], feeds it input at a fixed 60 ticks
## per second of game time, and shows it through a [WorldView].
##
## The simulation is stepped from `_physics_process` (always 60 Hz) and drawn
## from `_process` with interpolation, so the game runs at the same speed on
## every display. Game speed and bullet time only change how many ticks are
## run per physics frame.

## The player beat the level and asked to move on.
signal completed(slot: int)
signal menu_requested
signal editor_requested
signal toast_requested(text: String)

enum Mode {
	## Playing through the game: clearing a level leads to the next slot.
	OFFICIAL,
	## Trying out a level from the editor: clearing it returns there.
	TEST,
}

## Time runs at this fraction while the shoot button is held.
const BULLET_TIME_SCALE: float = 0.25
const TIME_SCALE_EASING: float = 0.15
## Chance per frame of a crumb flying off a block that is being swallowed.
const EAT_CRUMB_CHANCE: float = 0.3

var _slot: int = 1
var _mode: Mode = Mode.OFFICIAL
var _level: LevelData
var _sim: GameSim = GameSim.new()
var _input: PlayerInput = PlayerInput.new()
## Fraction of a tick carried over between physics frames.
var _accumulator: float = 0.0
## Eases between 1 and [constant BULLET_TIME_SCALE].
var _time_scale: float = 1.0
var _ticks_per_frame: float = 1.0
var _bullet_time: BulletTimeGauge = BulletTimeGauge.new()
var _win_recorded: bool = false

@onready var _view: WorldView = %WorldView
@onready var _overlay: GameOverlay = %GameOverlay
@onready var _level_label: Label = %LevelLabel
@onready var _pause_button: Button = %PauseButton
@onready var _pause_menu: SettingsDialog = %PauseMenu
@onready var _backdrop: MenuBackdrop = %Backdrop


## Must be called before the screen enters the tree. [param level] overrides
## what the slot would normally load (used to test unsaved editor work).
func setup(slot: int, mode: Mode, level: LevelData = null) -> void:
	_slot = slot
	_mode = mode
	_level = level


func _ready() -> void:
	if _level == null:
		_level = LevelStore.get_level(_slot)
	_sim.sfx_requested.connect(AudioDirector.play_sfx)
	_sim.level_reset.connect(_bullet_time.refill)
	_sim.bullet_time_enabled = Settings.bullet_time_enabled
	_sim.load_level(_slot, _level, LevelLibrary.boss_kind_for_slot(_slot))

	_view.sim = _sim
	_view.gui_input.connect(_on_view_gui_input)
	_overlay.sim = _sim
	_backdrop.glow_color = WorldCatalog.fill(GameConstants.world_of_slot(_slot))

	var world: int = GameConstants.world_of_slot(_slot)
	_level_label.text = "WORLD %d · LEVEL %02d" % [world, GameConstants.level_in_world(_slot)]
	if _mode == Mode.TEST:
		_level_label.text += "　測試中"
	_level_label.add_theme_color_override(&"font_color", WorldCatalog.accent(world))
	var subtitle: String = ""
	if _mode == Mode.TEST:
		subtitle = "測試遊玩"
	elif _sim.boss_kind != BossState.Kind.NONE:
		subtitle = "首領挑戰"
	_overlay.show_title_card(
		"WORLD %d · LEVEL %02d" % [world, GameConstants.level_in_world(_slot)], subtitle,
		WorldCatalog.accent(world)
	)

	_pause_button.pressed.connect(_open_pause_menu)
	_pause_menu.closed.connect(_on_pause_menu_closed)
	_pause_menu.menu_requested.connect(_leave.bind(menu_requested))
	_pause_menu.editor_requested.connect(_leave.bind(editor_requested))
	Settings.bindings_changed.connect(_refresh_hints)
	_refresh_hints()
	AudioDirector.set_music_playing(true)


func _exit_tree() -> void:
	get_tree().paused = false
	AudioDirector.set_music_playing(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not get_tree().paused:
		_open_pause_menu()


func _physics_process(delta: float) -> void:
	_sim.bullet_time_enabled = Settings.bullet_time_enabled
	var slowed: bool = _bullet_time.spend(_sim.player.in_bullet_time, delta)
	var target_scale: float = BULLET_TIME_SCALE if slowed else 1.0
	_time_scale += (target_scale - _time_scale) * TIME_SCALE_EASING
	_ticks_per_frame = Settings.game_speed * _time_scale
	_accumulator += _ticks_per_frame

	var mouse: Vector2 = _view.mouse_in_view()
	while _accumulator >= 1.0:
		_sim.step(_input.sample(mouse))
		_input.end_tick()
		_accumulator -= 1.0

	_sim.update_camera()
	var shake: float = _sim.camera.shake
	_view.shake_offset = Vector2(randf() - 0.5, randf() - 0.5) * shake
	_spawn_eating_crumbs()

	if _sim.player.won and not _win_recorded:
		_win_recorded = true
		if _mode == Mode.OFFICIAL:
			Progress.mark_cleared(_slot)
	elif not _sim.player.won:
		_win_recorded = false

	var boss: BossState = _sim.boss
	AudioDirector.set_music_context(
		_sim.boss_kind != BossState.Kind.NONE, boss.filled_count() if boss.active else 0
	)
	AudioDirector.set_music_playing(true)


func _process(_delta: float) -> void:
	var fraction: float = Engine.get_physics_interpolation_fraction()
	_view.tick_alpha = clampf(_accumulator + _ticks_per_frame * fraction, 0.0, 1.0)
	_view.camera_alpha = fraction
	_view.shoot_held = _input.is_held(InputBindings.SHOOT)
	_view.eat_held = _input.is_held(InputBindings.EAT)
	_view.bullet_time_energy = _bullet_time.energy
	_overlay.slow_amount = clampf((1.0 - _time_scale) / (1.0 - BULLET_TIME_SCALE), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Handling an event can end the level and take this screen out of the
	# tree, so hold on to the viewport first.
	var viewport: Viewport = get_viewport()
	if event.is_action_pressed(&"ui_cancel"):
		viewport.set_input_as_handled()
		_open_pause_menu()
		return
	if _handle_game_event(event):
		viewport.set_input_as_handled()


func _on_view_gui_input(event: InputEvent) -> void:
	if _handle_game_event(event) and _view.is_inside_tree():
		_view.accept_event()


## Routes an event to the game. Returns true when the game used it.
func _handle_game_event(event: InputEvent) -> bool:
	if _sim.player.won and (
		event.is_action_pressed(InputBindings.JUMP) or event.is_action_pressed(&"ui_accept")
	):
		completed.emit(_slot)
		return true
	if event.is_action_pressed(InputBindings.RESTART):
		_restart()
		return true
	return _input.handle_event(event)


func _restart() -> void:
	_sim.reset()
	_accumulator = 0.0
	_time_scale = 1.0
	toast_requested.emit("關卡已重新開始")


## Crumbs fly off the block the player is swallowing. Cosmetic only, so they
## use the simulation's separate effects stream.
func _spawn_eating_crumbs() -> void:
	var player: PlayerState = _sim.player
	if player.dead or player.won or player.has_block:
		return
	if player.eating_progress <= 0.0 or not player.has_eating_target:
		return
	if _sim.fx_rng.next_float() >= EAT_CRUMB_CHANCE:
		return
	var r: int = player.eating_target_r
	var c: int = player.eating_target_c
	var x: float = float(c) * Tile.SIZE
	var y: float = float(r) * Tile.SIZE
	var type: int = _sim.level.get_cell(r, c)
	if player.eating_target_is_boss_cell:
		x = _sim.boss.cell_x(c)
		y = _sim.boss.cell_y(r)
		type = _sim.boss.cell(r, c)
	_sim.spawn_cosmetic_particles(
		x + Tile.SIZE / 2.0, y + Tile.SIZE / 2.0,
		Palette.PINK_200 if Tile.is_bouncy(type) else Palette.AMBER_500, 1, 2.0
	)


func _open_pause_menu() -> void:
	if _pause_menu.visible:
		return
	_input.release_all()
	get_tree().paused = true
	AudioDirector.set_music_playing(false)
	_pause_menu.open(
		SettingsDialog.Context.TEST_PLAYING if _mode == Mode.TEST else SettingsDialog.Context.PLAYING
	)


func _on_pause_menu_closed() -> void:
	_input.release_all()
	get_tree().paused = false


func _leave(destination: Signal) -> void:
	get_tree().paused = false
	destination.emit()


func _refresh_hints() -> void:
	var jump_key: String = InputBindings.describe(Settings.binding(InputBindings.JUMP))
	var restart_key: String = InputBindings.describe(Settings.binding(InputBindings.RESTART))
	var next_step: String = "返回編輯器"
	if _mode == Mode.OFFICIAL:
		next_step = "前往下一關" if _slot < GameConstants.SLOT_COUNT else "返回選單"
	_overlay.win_lines = PackedStringArray([
		"按 [%s] 或 [Enter] %s" % [jump_key, next_step],
		"按 [%s] 重玩這一關" % restart_key,
	])
	_overlay.retry_line = "按 [%s] 立即重試" % restart_key
	_pause_button.text = "暫停 / 設定 (Esc)"
