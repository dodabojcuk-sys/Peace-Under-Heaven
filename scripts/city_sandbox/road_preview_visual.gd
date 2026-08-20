class_name RoadPreviewVisual
extends Node2D


const MASK_NORTH := 1
const MASK_EAST := 2
const MASK_SOUTH := 4
const MASK_WEST := 8

var _cells: Array[Vector2i] = []
var _status: StringName = &"invalid"
var _grid_size := 40.0


func set_preview(
	cells: Array[Vector2i],
	status: StringName,
	grid_size: float
) -> void:
	_cells = cells.duplicate()
	_status = status
	_grid_size = maxf(grid_size, 1.0)
	visible = not _cells.is_empty()
	queue_redraw()


func clear_preview() -> void:
	_cells.clear()
	visible = false
	queue_redraw()


func _draw() -> void:
	if _cells.is_empty():
		return
	var cell_set: Dictionary = {}
	for cell in _cells:
		cell_set[cell] = true
	var fill := Color("b64f49")
	var outline := Color("6f2425")
	match _status:
		&"connected":
			fill = Color("4eaa80")
			outline = Color("1f6049")
		&"isolated":
			fill = Color("d09a3c")
			outline = Color("7d5415")
	for cell in _cells:
		var rect := Rect2(Vector2(cell) * _grid_size, Vector2.ONE * _grid_size)
		var center := rect.get_center()
		var mask := _get_mask(cell, cell_set)
		draw_rect(rect.grow(-2.0), fill.lightened(0.1), true)
		draw_rect(rect.grow(-2.0), outline, false, 2.0)
		draw_circle(center, _grid_size * 0.18, fill.darkened(0.1))
		if mask & MASK_NORTH:
			draw_line(center, Vector2(center.x, rect.position.y), fill.darkened(0.1), _grid_size * 0.18)
		if mask & MASK_EAST:
			draw_line(center, Vector2(rect.end.x, center.y), fill.darkened(0.1), _grid_size * 0.18)
		if mask & MASK_SOUTH:
			draw_line(center, Vector2(center.x, rect.end.y), fill.darkened(0.1), _grid_size * 0.18)
		if mask & MASK_WEST:
			draw_line(center, Vector2(rect.position.x, center.y), fill.darkened(0.1), _grid_size * 0.18)


func _get_mask(cell: Vector2i, cell_set: Dictionary) -> int:
	var mask := 0
	if cell_set.has(cell + Vector2i.UP):
		mask |= MASK_NORTH
	if cell_set.has(cell + Vector2i.RIGHT):
		mask |= MASK_EAST
	if cell_set.has(cell + Vector2i.DOWN):
		mask |= MASK_SOUTH
	if cell_set.has(cell + Vector2i.LEFT):
		mask |= MASK_WEST
	return mask
