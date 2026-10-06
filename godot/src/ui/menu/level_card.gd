class_name LevelCard
extends PanelContainer
## One slot in the level select: its number, status badges, and the buttons
## to play it or (in the custom tab) edit and test it.

signal play_requested(slot: int)
signal edit_requested(slot: int)
signal test_requested(slot: int)

var _slot: int = 1

@onready var _number: Label = %Number
@onready var _title: Label = %Title
@onready var _badges: HBoxContainer = %Badges
@onready var _play_button: Button = %PlayButton
@onready var _edit_button: Button = %EditButton
@onready var _test_button: Button = %TestButton
@onready var _icon: TileIcon = %Icon


func _ready() -> void:
	_play_button.pressed.connect(func() -> void: play_requested.emit(_slot))
	_edit_button.pressed.connect(func() -> void: edit_requested.emit(_slot))
	_test_button.pressed.connect(func() -> void: test_requested.emit(_slot))
	UiMotion.add_hover_lift(self)


## Shows [param slot]. [param custom_tab] selects the edit/test buttons
## instead of the play button.
func show_slot(slot: int, custom_tab: bool) -> void:
	_slot = slot
	var world: int = GameConstants.world_of_slot(slot)
	var index: int = GameConstants.level_in_world(slot)
	var has_boss: bool = LevelLibrary.is_boss_slot(slot)
	var is_boss_stage: bool = has_boss or (index == GameConstants.LEVELS_PER_WORLD and LevelLibrary.is_placeholder(slot))
	var has_custom: bool = LevelStore.has_custom(slot)
	var accent: Color = WorldCatalog.accent(world)
	tooltip_text = ""

	_number.text = "%02d" % index
	_number.add_theme_color_override(
		&"font_color", Color(Palette.INDIGO_400, 0.85) if custom_tab else Color(accent, 0.75)
	)
	_icon.tile = WorldCatalog.icon_tile(world)
	_icon.visible = is_boss_stage

	if is_boss_stage:
		_title.text = "WORLD %d · LEVEL %02d" % [WorldCatalog.display_world(world), index]
		_title.add_theme_color_override(&"font_color", Palette.RED_300)
	else:
		_title.text = "WORLD %d · LEVEL %02d" % [WorldCatalog.display_world(world), index]
		_title.add_theme_color_override(&"font_color", Palette.SLATE_300)

	for child: Node in _badges.get_children():
		child.queue_free()
	if not has_custom:
		if is_boss_stage and not has_boss:
			_add_badge("首領尚未製作", Palette.SLATE_500)
		elif LevelLibrary.is_placeholder(slot):
			_add_badge("空白關卡", Palette.SLATE_500)
	if not custom_tab and Progress.is_cleared(slot):
		_add_badge("已通關", Palette.EMERALD_400)

	_play_button.visible = not custom_tab
	_edit_button.visible = custom_tab
	_test_button.visible = custom_tab
	_play_button.text = "挑戰世界首領" if is_boss_stage and has_boss else "PLAY"
	WorldCatalog.tint_button(_play_button, Palette.RED_600 if is_boss_stage and has_boss else WorldCatalog.fill(world))


func _add_badge(text: String, color: Color) -> void:
	var badge: Label = Label.new()
	badge.theme_type_variation = &"BadgeLabel"
	badge.text = text
	badge.add_theme_color_override(&"font_color", color)
	_badges.add_child(badge)
