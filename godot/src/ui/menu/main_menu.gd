class_name MainMenu
extends Control
## The title screen and level select: worlds of ten slots each, in two tabs,
## one for playing and one for building. The play tab only lists worlds that
## have levels; the build tab lists every world, so new ones can be started.

signal play_requested(slot: int)
signal edit_requested(slot: int)
signal test_requested(slot: int)

const LEVEL_CARD: PackedScene = preload("res://src/ui/menu/level_card.tscn")
## Slots shown in the grid; the tenth slot of a world is the wide boss card.
const GRID_SLOTS: int = GameConstants.LEVELS_PER_WORLD - 1
## World buttons per row: worlds one to five above the levels, six to ten
## below them.
const WORLDS_PER_ROW: int = 5
## Delay between one level card appearing and the next.
const CARD_STAGGER_SEC: float = 0.022

var _world: int = WorldCatalog.ORDER[0]
var _custom_tab: bool = false
var _cards: Array[LevelCard] = []
var _world_buttons: Array[Button] = []
var _world_captions: Array[Label] = []
## The second row of world buttons, created below the level cards.
var _lower_world_tabs: HBoxContainer

@onready var _backdrop: MenuBackdrop = %Backdrop
@onready var _logo: SlimeIcon = %Logo
@onready var _subtitle: Label = %Subtitle
@onready var _mute_button: Button = %MuteButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _official_tab: Button = %OfficialTab
@onready var _custom_tab_button: Button = %CustomTab
@onready var _world_tabs: HBoxContainer = %WorldTabs
@onready var _section_title: Label = %SectionTitle
@onready var _progress_label: Label = %ProgressLabel
@onready var _grid: GridContainer = %Grid
@onready var _boss_card: LevelCard = %BossCard
@onready var _settings_dialog: SettingsDialog = %SettingsDialog
@onready var _version_label: Label = %VersionLabel


## Restores the tab and world the player was last looking at. Call before
## the menu enters the tree.
func setup(world: int, custom_tab: bool) -> void:
	_world = clampi(world, 1, GameConstants.WORLD_COUNT)
	_custom_tab = custom_tab


func selected_world() -> int:
	return _world


func is_custom_tab() -> bool:
	return _custom_tab


func _ready() -> void:
	_lower_world_tabs = HBoxContainer.new()
	_lower_world_tabs.name = "LowerWorldTabs"
	_lower_world_tabs.add_theme_constant_override(&"separation", _world_tabs.get_theme_constant(&"separation"))
	# Under the levels: the second group of worlds sits below the boss card.
	_boss_card.add_sibling(_lower_world_tabs)
	for i: int in WorldCatalog.ORDER.size():
		var row: HBoxContainer = _world_tabs if i < WORLDS_PER_ROW else _lower_world_tabs
		row.add_child(_make_world_button(WorldCatalog.ORDER[i]))
	for _i: int in GRID_SLOTS:
		var card: LevelCard = LEVEL_CARD.instantiate()
		_grid.add_child(card)
		_connect_card(card)
		_cards.append(card)
	_connect_card(_boss_card)

	_official_tab.pressed.connect(_select_tab.bind(false))
	_custom_tab_button.pressed.connect(_select_tab.bind(true))
	_settings_button.pressed.connect(
		func() -> void: _settings_dialog.open(SettingsDialog.Context.MAIN_MENU)
	)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_quit_button.visible = not OS.has_feature("web")
	_mute_button.pressed.connect(func() -> void: Settings.set_muted(not Settings.muted))
	_volume_slider.value_changed.connect(_on_volume_slider_changed)
	_version_label.text = "DEVOURER SLIME  v%s" % ProjectSettings.get_setting("application/config/version")

	Settings.audio_changed.connect(_refresh_volume)
	LevelStore.custom_levels_changed.connect(_refresh)
	Progress.changed.connect(_refresh)
	_refresh_volume()
	_refresh()
	_backdrop.drifting = true
	_logo.animated = true
	_animate_cards()


func _make_world_button(world: int) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"ChipButton"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_world.bind(world))

	# The world's tile next to its name, laid out inside the button.
	var content: HBoxContainer = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 14)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon: TileIcon = TileIcon.new()
	icon.tile = WorldCatalog.icon_tile(world)
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var caption: Label = Label.new()
	caption.text = "WORLD %02d" % WorldCatalog.display_world(world)
	if world >= 6:
		caption.text += "\n" + WorldCatalog.name_for(world)
	caption.theme_type_variation = &"HeadingLabel"
	caption.add_theme_font_size_override(&"font_size", 18 if world >= 6 else 21)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	button.add_child(content)

	_world_buttons.append(button)
	_world_captions.append(caption)
	return button


func _connect_card(card: LevelCard) -> void:
	card.play_requested.connect(func(slot: int) -> void: play_requested.emit(slot))
	card.edit_requested.connect(func(slot: int) -> void: edit_requested.emit(slot))
	card.test_requested.connect(func(slot: int) -> void: test_requested.emit(slot))


func _select_tab(custom: bool) -> void:
	_custom_tab = custom
	_refresh()
	_animate_cards()


func _select_world(world: int) -> void:
	_world = world
	_refresh()
	_animate_cards()


## The cards arrive one after another when a different set is shown.
func _animate_cards() -> void:
	for i: int in _cards.size():
		UiMotion.rise_in(_cards[i], float(i) * CARD_STAGGER_SEC)
	UiMotion.rise_in(_boss_card, float(_cards.size()) * CARD_STAGGER_SEC)


## True when [param world] is listed in the current tab.
func _is_world_listed(world: int) -> bool:
	return _custom_tab or LevelStore.world_has_levels(world)


## Shows the buttons of the listed worlds. A row with none is hidden; in a
## row with some, the others keep their place as blanks so that every world
## stays in its own column.
func _lay_out_world_rows() -> void:
	for first: int in range(0, _world_buttons.size(), WORLDS_PER_ROW):
		var last: int = mini(first + WORLDS_PER_ROW, _world_buttons.size())
		var any_listed: bool = false
		for i: int in range(first, last):
			any_listed = any_listed or _is_world_listed(WorldCatalog.ORDER[i])
		for i: int in range(first, last):
			var listed: bool = _is_world_listed(WorldCatalog.ORDER[i])
			var button: Button = _world_buttons[i]
			button.visible = any_listed
			button.disabled = not listed
			button.modulate.a = 1.0 if listed else 0.0
			button.mouse_filter = Control.MOUSE_FILTER_STOP if listed else Control.MOUSE_FILTER_IGNORE
			button.focus_mode = Control.FOCUS_ALL if listed else Control.FOCUS_NONE
	_lower_world_tabs.visible = _world_buttons.size() > WORLDS_PER_ROW and _world_buttons[WORLDS_PER_ROW].visible


func _refresh() -> void:
	# A world that is not listed here cannot stay selected.
	if not _is_world_listed(_world):
		for world: int in WorldCatalog.ORDER:
			if _is_world_listed(world):
				_world = world
				break
	_lay_out_world_rows()
	var accent: Color = WorldCatalog.accent(_world)
	_backdrop.glow_color = WorldCatalog.fill(_world)
	_logo.body_color = WorldCatalog.fill(_world)
	_subtitle.add_theme_color_override(&"font_color", accent)

	_official_tab.set_pressed_no_signal(not _custom_tab)
	_custom_tab_button.set_pressed_no_signal(_custom_tab)
	for i: int in _world_buttons.size():
		var selected: bool = WorldCatalog.ORDER[i] == _world
		_world_buttons[i].set_pressed_no_signal(selected)
		_world_captions[i].add_theme_color_override(
			&"font_color", WorldCatalog.accent(WorldCatalog.ORDER[i]) if selected else Palette.SLATE_400
		)

	_section_title.text = "自訂地圖創作 CUSTOM WORKSPACE" if _custom_tab else "冒險挑戰關卡 LEVEL SELECT"
	_section_title.add_theme_color_override(&"font_color", accent)
	if _custom_tab:
		var saved: int = 0
		for slot: int in range(1, GameConstants.SLOT_COUNT + 1):
			if LevelStore.has_custom(slot):
				saved += 1
		_progress_label.text = "已儲存 %d 個自訂關卡" % saved
	else:
		_progress_label.text = "已通關 %d / %d" % [Progress.cleared_count(), LevelStore.level_count()]

	var first_slot: int = (_world - 1) * GameConstants.LEVELS_PER_WORLD + 1
	for i: int in _cards.size():
		_cards[i].show_slot(first_slot + i, _custom_tab)
	_boss_card.show_slot(first_slot + GRID_SLOTS, _custom_tab)


func _refresh_volume() -> void:
	var percent: int = 0 if Settings.muted else roundi(Settings.volume * 100.0)
	_volume_slider.set_value_no_signal(float(percent))
	_volume_value.text = "%d%%" % percent
	_mute_button.text = "已靜音" if Settings.muted else "音量"
	_mute_button.set_pressed_no_signal(Settings.muted)


func _on_volume_slider_changed(value: float) -> void:
	if value > 0.0:
		Settings.set_volume(value / 100.0)
		Settings.set_muted(false)
	else:
		Settings.set_muted(true)
