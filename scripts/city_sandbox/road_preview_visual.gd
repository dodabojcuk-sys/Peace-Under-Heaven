class_name RoadPreviewVisual
extends Node2D


const PALETTE := preload(
	"res://resources/visuals/northern_campaign_palette.gd"
)
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
	var fill := PALETTE.HOSTILE_RUST
	var outline := PALETTE.HOSTILE_RUST.darkened(0.38)
	match _status:
		&"connected":
			fill = PALETTE.JADE
			outline = PALETTE.INK_TEAL
		&"isolated":
			fill = PALETTE.COPPER_GOLD
			outline = PALETTE.ROAD_EDGE
	for cell in _cells:
		var rect := Rect2(Vector2(cell) * _grid_size, Vector2.ONE * _grid_size)
		var center := rect.get_center()
		var mask := _get_mask(cell, cell_set)
		# A low-opacity cell plate communicates exact occupied cells while the
		# layered stroke previews the same shoulder/surface language as built roads.
		draw_rect(
			rect.grow(-2.0),
			PALETTE.with_alpha(fill, 0.17),
			true
		)
		draw_rect(rect.grow(-2.0), PALETTE.with_alpha(outline, 0.92), false, 2.0)
		if _status == &"invalid":
			draw_line(
				rect.position + Vector2(8.0, 8.0),
				rect.end - Vector2(8.0, 8.0),
				outline,
				3.0
			)
			draw_line(
				Vector2(rect.end.x - 8.0, rect.position.y + 8.0),
				Vector2(rect.position.x + 8.0, rect.end.y - 8.0),
				outline,
				3.0
			)
		_draw_preview_road_layer(
			rect,
			center,
			mask,
			outline,
			_grid_size * 0.68
		)
		_draw_preview_road_layer(
			rect,
			center,
			mask,
			fill.lightened(0.08),
			_grid_size * 0.46
		)
		if _connection_count(mask) >= 3:
			draw_circle(center, _grid_size * 0.18, fill.lightened(0.18))
			draw_arc(
				center,
				_grid_size * 0.22,
				0.0,
				TAU,
				18,
				outline,
				2.0,
				true
			)


func _draw_preview_road_layer(
	rect: Rect2,
	center: Vector2,
	mask: int,
	color: Color,
	width: float
) -> void:
	draw_circle(center, width * 0.5, color)
	if mask & MASK_NORTH:
		draw_line(center, Vector2(center.x, rect.position.y), color, width)
	if mask & MASK_EAST:
		draw_line(center, Vector2(rect.end.x, center.y), color, width)
	if mask & MASK_SOUTH:
		draw_line(center, Vector2(center.x, rect.end.y), color, width)
	if mask & MASK_WEST:
		draw_line(center, Vector2(rect.position.x, center.y), color, width)


func _connection_count(mask: int) -> int:
	var count := 0
	for direction_mask in [MASK_NORTH, MASK_EAST, MASK_SOUTH, MASK_WEST]:
		if mask & direction_mask:
			count += 1
	return count


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
