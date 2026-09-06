class_name PlacementGridR1
extends Node2D


var footprint := Vector2i.ONE
var cell_size := 40.0


func configure_grid(next_footprint: Vector2i, next_cell_size: float) -> void:
	footprint = next_footprint
	cell_size = next_cell_size
	queue_redraw()


func _draw() -> void:
	var draw_size := Vector2(footprint) * cell_size
	for x in range(footprint.x + 1):
		var position := Vector2(float(x) * cell_size, 0.0)
		draw_line(position, position + Vector2(0.0, draw_size.y), Color(0.74, 0.89, 0.82, 0.7), 1.5)
	for y in range(footprint.y + 1):
		var position := Vector2(0.0, float(y) * cell_size)
		draw_line(position, position + Vector2(draw_size.x, 0.0), Color(0.74, 0.89, 0.82, 0.7), 1.5)
