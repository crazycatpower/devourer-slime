class_name ConfirmDialog
extends Control
## A modal question with up to three answers.
##
## Usage:
## [codeblock]
## dialog.ask("Discard changes?", ["Discard", "Cancel"])
## if await dialog.chosen == 0:
##     ...
## [/codeblock]
## By convention the last option is the safe one; Escape picks it.

signal chosen(index: int)

var _option_count: int = 0

@onready var _message: Label = %Message
@onready var _buttons: HBoxContainer = %Buttons
@onready var _panel: PanelContainer = %Panel
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Shows the dialog. [param danger_index] marks a destructive option.
func ask(message: String, options: PackedStringArray, danger_index: int = -1) -> void:
	_message.text = message
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_option_count = options.size()
	for i: int in _option_count:
		var button: Button = Button.new()
		button.text = options[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == danger_index:
			button.theme_type_variation = &"DangerButton"
		elif i == 0:
			button.theme_type_variation = &"AccentButton"
		button.pressed.connect(_choose.bind(i))
		_buttons.add_child(button)
	visible = true
	UiMotion.pop_in(_panel, _dim)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_choose(_option_count - 1)


func _choose(index: int) -> void:
	visible = false
	chosen.emit(index)
