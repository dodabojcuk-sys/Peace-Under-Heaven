class_name CityGridRules
extends RefCounted


const MASK_NORTH := 1
const MASK_EAST := 2
const MASK_SOUTH := 4
const MASK_WEST := 8

static func get_rotated_footprint(
	footprint_size: Vector2i,
	orientation_quarters: int
) -> Dictionary:
	var error := _validate_footprint_and_orientation(
		footprint_size,
		orientation_quarters
	)
	if error != &"":
		return _invalid_result(error)
	return {
		"valid": true,
		"error": &"",
		"footprint": (
			footprint_size
			if orientation_quarters % 2 == 0
			else Vector2i(footprint_size.y, footprint_size.x)
		),
	}


static func resolve_entrance(
	origin_cell: Vector2i,
	footprint_size: Vector2i,
	entrance_cell: Vector2i,
	entrance_facing: Vector2i,
	orientation_quarters: int
) -> Dictionary:
	var error := _validate_footprint_and_orientation(
		footprint_size,
		orientation_quarters
	)
	if error != &"":
		return _invalid_result(error)
	if not _cell_is_inside_footprint(entrance_cell, footprint_size):
		return _invalid_result(&"entrance_cell_outside_footprint")
	if not _is_cardinal_direction(entrance_facing):
		return _invalid_result(&"entrance_facing_not_cardinal")
	if not _entrance_faces_outward(
		entrance_cell,
		entrance_facing,
		footprint_size
	):
		return _invalid_result(&"entrance_facing_not_outward")

	var rotated_footprint_result := get_rotated_footprint(
		footprint_size,
		orientation_quarters
	)
	var rotated_cell := _rotate_cell(
		entrance_cell,
		footprint_size,
		orientation_quarters
	)
	var rotated_facing := _rotate_direction(
		entrance_facing,
		orientation_quarters
	)
	return {
		"valid": true,
		"error": &"",
		"footprint": Vector2i(rotated_footprint_result.footprint),
		"entrance_cell": rotated_cell,
		"entrance_facing": rotated_facing,
		"road_contact_cell": origin_cell + rotated_cell + rotated_facing,
	}


static func get_definition_entrance_adapter(
	footprint_size: Vector2i,
	road_anchor_offsets: Array[Vector2i]
) -> Dictionary:
	# Building definitions store the exterior road-contact cells.  Resolve one
	# deterministic perimeter adapter in compass order so all consumers use the
	# same entrance semantics without treating every possible anchor as a second
	# entrance or a second state owner.
	var edge_specs := [
		{"edge": Vector2i.UP, "predicate": &"top"},
		{"edge": Vector2i.RIGHT, "predicate": &"right"},
		{"edge": Vector2i.DOWN, "predicate": &"bottom"},
		{"edge": Vector2i.LEFT, "predicate": &"left"},
	]
	for edge_spec in edge_specs:
		var edge: Vector2i = edge_spec.edge
		for offset_value in road_anchor_offsets:
			var offset := Vector2i(offset_value)
			if edge_spec.predicate == &"top" and offset.y == -1 and offset.x >= 0 and offset.x < footprint_size.x:
				return {
					"entrance_cell": Vector2i(offset.x, 0),
					"entrance_facing": edge,
				}
			if edge_spec.predicate == &"right" and offset.x == footprint_size.x and offset.y >= 0 and offset.y < footprint_size.y:
				return {
					"entrance_cell": Vector2i(footprint_size.x - 1, offset.y),
					"entrance_facing": edge,
				}
			if edge_spec.predicate == &"bottom" and offset.y == footprint_size.y and offset.x >= 0 and offset.x < footprint_size.x:
				return {
					"entrance_cell": Vector2i(offset.x, footprint_size.y - 1),
					"entrance_facing": edge,
				}
			if edge_spec.predicate == &"left" and offset.x == -1 and offset.y >= 0 and offset.y < footprint_size.y:
				return {
					"entrance_cell": Vector2i(0, offset.y),
					"entrance_facing": edge,
				}
	return {
		"entrance_cell": Vector2i.ZERO,
		"entrance_facing": Vector2i.UP,
	}


static func get_covered_cells(
	origin_cell: Vector2i,
	footprint_size: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if footprint_size.x <= 0 or footprint_size.y <= 0:
		return cells
	for y in range(footprint_size.y):
		for x in range(footprint_size.x):
			cells.append(origin_cell + Vector2i(x, y))
	return cells


static func is_footprint_within_bounds(
	origin_cell: Vector2i,
	footprint_size: Vector2i,
	bounds: Rect2i
) -> bool:
	if (
		footprint_size.x <= 0
		or footprint_size.y <= 0
		or bounds.size.x <= 0
		or bounds.size.y <= 0
	):
		return false
	var footprint_end := origin_cell + footprint_size
	return (
		origin_cell.x >= bounds.position.x
		and origin_cell.y >= bounds.position.y
		and footprint_end.x <= bounds.end.x
		and footprint_end.y <= bounds.end.y
	)


static func find_occupied_conflicts(
	cells: Array[Vector2i],
	occupied_cells: Dictionary
) -> Array[Vector2i]:
	var conflicts: Array[Vector2i] = []
	for cell in cells:
		if occupied_cells.has(cell):
			conflicts.append(cell)
	return conflicts


static func get_road_mask(
	cell: Vector2i,
	road_cells: Dictionary
) -> int:
	var mask := 0
	if road_cells.has(cell + Vector2i.UP):
		mask |= MASK_NORTH
	if road_cells.has(cell + Vector2i.RIGHT):
		mask |= MASK_EAST
	if road_cells.has(cell + Vector2i.DOWN):
		mask |= MASK_SOUTH
	if road_cells.has(cell + Vector2i.LEFT):
		mask |= MASK_WEST
	return mask


static func get_connected_road_cells(
	road_cells: Dictionary,
	root_cells: Array[Vector2i]
) -> Dictionary:
	var connected: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for root_cell in root_cells:
		if road_cells.has(root_cell) and not connected.has(root_cell):
			connected[root_cell] = true
			frontier.append(root_cell)

	var frontier_index := 0
	while frontier_index < frontier.size():
		var current := frontier[frontier_index]
		frontier_index += 1
		for direction in _get_cardinal_directions():
			var neighbor := current + direction
			if road_cells.has(neighbor) and not connected.has(neighbor):
				connected[neighbor] = true
				frontier.append(neighbor)
	return connected


static func _validate_footprint_and_orientation(
	footprint_size: Vector2i,
	orientation_quarters: int
) -> StringName:
	if footprint_size.x <= 0 or footprint_size.y <= 0:
		return &"invalid_footprint"
	if orientation_quarters < 0 or orientation_quarters > 3:
		return &"invalid_orientation"
	return &""


static func _cell_is_inside_footprint(
	cell: Vector2i,
	footprint_size: Vector2i
) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < footprint_size.x
		and cell.y < footprint_size.y
	)


static func _is_cardinal_direction(direction: Vector2i) -> bool:
	return (
		direction == Vector2i.UP
		or direction == Vector2i.RIGHT
		or direction == Vector2i.DOWN
		or direction == Vector2i.LEFT
	)


static func _get_cardinal_directions() -> Array[Vector2i]:
	return [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]


static func _entrance_faces_outward(
	entrance_cell: Vector2i,
	entrance_facing: Vector2i,
	footprint_size: Vector2i
) -> bool:
	if entrance_facing == Vector2i.LEFT:
		return entrance_cell.x == 0
	if entrance_facing == Vector2i.RIGHT:
		return entrance_cell.x == footprint_size.x - 1
	if entrance_facing == Vector2i.UP:
		return entrance_cell.y == 0
	if entrance_facing == Vector2i.DOWN:
		return entrance_cell.y == footprint_size.y - 1
	return false


static func _rotate_cell(
	cell: Vector2i,
	footprint_size: Vector2i,
	orientation_quarters: int
) -> Vector2i:
	match orientation_quarters:
		0:
			return cell
		1:
			return Vector2i(footprint_size.y - 1 - cell.y, cell.x)
		2:
			return Vector2i(
				footprint_size.x - 1 - cell.x,
				footprint_size.y - 1 - cell.y
			)
		3:
			return Vector2i(cell.y, footprint_size.x - 1 - cell.x)
	return Vector2i.ZERO


static func _rotate_direction(
	direction: Vector2i,
	orientation_quarters: int
) -> Vector2i:
	var result := direction
	for _quarter in range(orientation_quarters):
		result = Vector2i(-result.y, result.x)
	return result


static func _invalid_result(error: StringName) -> Dictionary:
	return {
		"valid": false,
		"error": error,
	}
