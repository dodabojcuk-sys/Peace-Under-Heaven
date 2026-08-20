class_name CityRoadDraft
extends RefCounted


const AXIS_PRIORITY := &"x_then_y"


static func interpolate_segment(
	start_cell: Vector2i,
	end_cell: Vector2i
) -> Array[Vector2i]:
	if start_cell.x != end_cell.x and start_cell.y != end_cell.y:
		return []
	var cells: Array[Vector2i] = [start_cell]
	var current := start_cell
	while current.x != end_cell.x:
		current.x += 1 if end_cell.x > current.x else -1
		cells.append(current)
	while current.y != end_cell.y:
		current.y += 1 if end_cell.y > current.y else -1
		cells.append(current)
	return cells


static func build_ordered_cells(
	sampled_cells: Array[Vector2i]
) -> Array[Vector2i]:
	var ordered: Array[Vector2i] = []
	if sampled_cells.is_empty():
		return ordered
	ordered.append(sampled_cells[0])
	for sample_index in range(1, sampled_cells.size()):
		var segment := interpolate_segment(
			sampled_cells[sample_index - 1],
			sampled_cells[sample_index]
		)
		if segment.is_empty():
			return []
		for segment_index in range(1, segment.size()):
			ordered.append(segment[segment_index])
	return ordered


static func get_unique_cells(
	ordered_cells: Array[Vector2i]
) -> Array[Vector2i]:
	var unique: Array[Vector2i] = []
	var seen: Dictionary = {}
	for cell in ordered_cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		unique.append(cell)
	return unique


static func build_draft(
	sampled_cells: Array[Vector2i]
) -> Dictionary:
	var ordered := build_ordered_cells(sampled_cells)
	var valid := not sampled_cells.is_empty() and not ordered.is_empty()
	var error := &""
	if not valid:
		error = &"road_path_must_be_axis_aligned"
	return {
		"valid": valid,
		"error": error,
		"axis_priority": AXIS_PRIORITY,
		"ordered_cells": ordered,
		"unique_cells": get_unique_cells(ordered),
	}
