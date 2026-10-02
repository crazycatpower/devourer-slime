class_name WorldLayer
extends Node2D
## Base class of the layers a [WorldView] is drawn from. A layer draws one
## kind of thing, in world coordinates, by overriding [method _paint].

var view: WorldView


func _draw() -> void:
	if view == null or view.sim == null:
		return
	_paint(Painter.new(self, view.world_scale), view.sim)


## Draws this layer. [param p] works in world units.
func _paint(_p: Painter, _sim: GameSim) -> void:
	pass
