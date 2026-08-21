class_name CityMinimapR1
extends Control


const MAP_SIZE := Vector2(2200.0, 1400.0)
const INSET := 14.0

var _camera_position := MAP_SIZE * 0.5
var _camera_zoom := 1.0
var _safe_rect := Rect2(Vector2.ZERO, Vector2(1.0, 1.0))
var _player_road_cells: Dictionary = {}
var _layout_profile_id: StringName = &"REGULAR_IMPERIAL"
var _formal_road_cells: Dictionary = {}
var _reserved_cells: Dictionary = {}


func update_world_view(
	camera_position: Vector2,
	camera_zoom: float,
	safe_rect: Rect2
) -> void:
	_camera_position = camera_position
	_camera_zoom = maxf(camera_zoom, 0.01)
	_safe_rect = safe_rect
	queue_redraw()


func set_player_road_cells(cells: Dictionary) -> void:
	_player_road_cells = cells.duplicate(true)
	queue_redraw()


func set_layout_profile(
	profile_id: StringName,
	formal_road_cells: Dictionary,
	reserved_cells: Dictionary
) -> void:
	_layout_profile_id = profile_id
	_formal_road_cells = formal_road_cells.duplicate(true)
	_reserved_cells = reserved_cells.duplicate(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2(INSET, 30.0), Vector2(size.x - INSET * 2.0, size.y - 42.0))
	if map_rect.size.x <= 1.0 or map_rect.size.y <= 1.0:
		return
	draw_rect(map_rect, Color("172422"), true)
	draw_rect(map_rect, Color("5d918a"), false, 1.5)
	var cell_size := Vector2(
		map_rect.size.x / 55.0,
		map_rect.size.y / 35.0
	)
	var road_color := (
		Color("7f9f84")
		if _layout_profile_id == &"ORGANIC_GARDEN"
		else Color("958665")
	)
	for cell in _formal_road_cells:
		var formal_rect := Rect2(
			map_rect.position + Vector2(Vector2i(cell)) * cell_size,
			cell_size
		)
		draw_rect(formal_rect.grow(-0.25), road_color, true)
	for cell in _reserved_cells:
		var reserve_rect := Rect2(
			map_rect.position + Vector2(Vector2i(cell)) * cell_size,
			cell_size
		)
		draw_rect(
			reserve_rect.grow(-0.25),
			Color("719b72") if _layout_profile_id == &"ORGANIC_GARDEN" else Color("bc9659"),
			true
		)
	for cell in _player_road_cells:
		var typed_cell := Vector2i(cell)
		var road_rect := Rect2(
			map_rect.position + Vector2(typed_cell) * cell_size,
			cell_size
		)
		draw_rect(road_rect.grow(-0.5), Color("b7a476"), true)
	var visible_world_size := _safe_rect.size / _camera_zoom
	var viewport_world := Rect2(_camera_position - visible_world_size * 0.5, visible_world_size)
	var viewport_rect := _map_rect_to_minimap(map_rect, viewport_world)
	draw_rect(viewport_rect, Color("73d4c5"), false, 2.0)


func _draw_map_rect(target: Rect2, world_rect: Rect2, color: Color) -> void:
	draw_rect(_map_rect_to_minimap(target, world_rect), color, true)


func _map_rect_to_minimap(target: Rect2, world_rect: Rect2) -> Rect2:
	var scale := Vector2(target.size.x / MAP_SIZE.x, target.size.y / MAP_SIZE.y)
	return Rect2(target.position + world_rect.position * scale, world_rect.size * scale)
