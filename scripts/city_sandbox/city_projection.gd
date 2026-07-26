class_name CityProjection
extends RefCounted


const SINGULAR_EPSILON := 0.000001


static func is_basis_invertible(
	basis_x: Vector2,
	basis_y: Vector2
) -> bool:
	return absf(_determinant(basis_x, basis_y)) > SINGULAR_EPSILON


static func grid_to_visual(
	grid_position: Vector2,
	visual_origin: Vector2,
	basis_x: Vector2,
	basis_y: Vector2
) -> Dictionary:
	if not is_basis_invertible(basis_x, basis_y):
		return _invalid_result(&"singular_basis")
	return {
		"valid": true,
		"error": &"",
		"position": (
			visual_origin
			- basis_x * grid_position.x
			- basis_y * grid_position.y
		),
	}


static func visual_to_grid(
	visual_position: Vector2,
	visual_origin: Vector2,
	basis_x: Vector2,
	basis_y: Vector2
) -> Dictionary:
	var determinant := _determinant(basis_x, basis_y)
	if absf(determinant) <= SINGULAR_EPSILON:
		return _invalid_result(&"singular_basis")

	var displacement := visual_origin - visual_position
	return {
		"valid": true,
		"error": &"",
		"grid_position": Vector2(
			(
				displacement.x * basis_y.y
				- displacement.y * basis_y.x
			) / determinant,
			(
				basis_x.x * displacement.y
				- basis_x.y * displacement.x
			) / determinant
		),
	}


static func visual_to_nearest_cell(
	visual_position: Vector2,
	visual_origin: Vector2,
	basis_x: Vector2,
	basis_y: Vector2,
	cell_anchor := Vector2(0.5, 0.5)
) -> Dictionary:
	var grid_result := visual_to_grid(
		visual_position,
		visual_origin,
		basis_x,
		basis_y
	)
	if not bool(grid_result.valid):
		return grid_result
	var unanchored := Vector2(grid_result.grid_position) - cell_anchor
	return {
		"valid": true,
		"error": &"",
		"cell": Vector2i(roundi(unanchored.x), roundi(unanchored.y)),
	}


static func _determinant(basis_x: Vector2, basis_y: Vector2) -> float:
	return basis_x.x * basis_y.y - basis_x.y * basis_y.x


static func _invalid_result(error: StringName) -> Dictionary:
	return {
		"valid": false,
		"error": error,
	}
