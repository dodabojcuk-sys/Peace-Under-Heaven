class_name PlacementDebugOverlayR0A
extends Node2D


var construction_controller: Node
var selected_placement_id := -1
var conflict_cells: Array[Vector2i] = []
var grid_size := 40.0


func configure(
	controller: Node,
	placement_id := -1,
	conflicts: Array[Vector2i] = []
) -> void:
	construction_controller = controller
	selected_placement_id = placement_id
	conflict_cells = conflicts.duplicate()
	visible = OS.is_debug_build()
	queue_redraw()


func _draw() -> void:
	if construction_controller == null or not visible:
		return
	for cell_value in construction_controller.get_all_road_cells():
		var road_cell := Vector2i(cell_value)
		var road_rect := Rect2(Vector2(road_cell) * grid_size, Vector2.ONE * grid_size)
		draw_rect(road_rect.grow(-3.0), Color(0.88, 0.68, 0.22, 0.28), true)
		draw_rect(road_rect.grow(-3.0), Color(0.7, 0.46, 0.08, 0.92), false, 2.0)
	for placement_id in construction_controller.get_placement_ids():
		var record: Dictionary = construction_controller.get_building_record(placement_id)
		if record.is_empty() or StringName(record.placement_kind) == &"road":
			continue
		for cell_value in record.occupied_footprint_cells:
			var cell := Vector2i(cell_value)
			var rect := Rect2(Vector2(cell) * grid_size, Vector2.ONE * grid_size)
			var fill := Color(0.13, 0.72, 0.76, 0.2)
			var outline := Color(0.07, 0.45, 0.5, 0.9)
			if placement_id == selected_placement_id:
				fill = Color(0.2, 0.82, 0.48, 0.3)
				outline = Color(0.06, 0.48, 0.24, 1.0)
			draw_rect(rect.grow(-2.0), fill, true)
			draw_rect(rect.grow(-2.0), outline, false, 2.0)
		var entrance: Dictionary = construction_controller.get_building_entrance_info(placement_id)
		if bool(entrance.get("valid", false)) and bool(entrance.get("required", false)):
			var entrance_cell := Vector2i(entrance.entrance_cell) + Vector2i(record.origin_cell)
			var facing := Vector2i(entrance.entrance_facing)
			var center := (Vector2(entrance_cell) + Vector2(0.5, 0.5)) * grid_size
			draw_line(center, center + Vector2(facing) * 24.0, Color(0.95, 0.95, 0.35), 4.0)
	for cell in conflict_cells:
		var rect := Rect2(Vector2(cell) * grid_size, Vector2.ONE * grid_size).grow(-5.0)
		draw_rect(rect, Color(0.78, 0.12, 0.12, 0.32), true)
		draw_line(rect.position, rect.end, Color(0.72, 0.06, 0.06), 4.0)
		draw_line(
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y),
			Color(0.72, 0.06, 0.06),
			4.0
		)
