class_name MacroMarchMapCanvas
extends Control


var renderer: Callable


func _draw() -> void:
	if renderer.is_valid():
		renderer.call(self)
