class_name MacroMarchTheater
extends RefCounted


static var _definition: MacroMarchTheaterDefinition = preload(
	"res://resources/macro_march/blackstone_outer_city_r0.tres"
)


static func get_points() -> Dictionary:
	return _definition.points.duplicate(true)


static func get_routes() -> Dictionary:
	return _definition.routes.duplicate(true)


static func get_point(point_id: StringName) -> Dictionary:
	return Dictionary(_definition.points.get(point_id, {})).duplicate(true)


static func get_route(route_id: StringName) -> Dictionary:
	return Dictionary(_definition.routes.get(route_id, {})).duplicate(true)


static func get_routes_from(source_point_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route_id in _definition.routes:
		var route: Dictionary = _definition.routes[route_id]
		if StringName(route.source_point_id) == source_point_id:
			result.append(route.duplicate(true))
	return result


static func route_length(route_id: StringName) -> float:
	var route := get_route(route_id)
	var route_points: Array = route.get("points", [])
	var length := 0.0
	for index in range(1, route_points.size()):
		length += Vector2(route_points[index - 1]).distance_to(
			Vector2(route_points[index])
		)
	return length


static func duration_milliseconds(route_id: StringName) -> int:
	# The R0 pace is intentionally visible in a short greybox recording.
	return maxi(6000, ceili(route_length(route_id) * 20.0))


static func route_points_for_persistence(route_id: StringName) -> Array:
	var route := get_route(route_id)
	return Array(route.get("points", [])).duplicate()


static func validate_route(
	source_point_id: StringName,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array
) -> Dictionary:
	var route := get_route(route_id)
	if route.is_empty():
		return _failure(&"UNKNOWN_ROAD", "该道路不存在")
	if (
		StringName(route.source_point_id) != source_point_id
		or StringName(route.target_point_id) != target_point_id
		or source_point_id == target_point_id
	):
		return _failure(&"ILLEGAL_ENDPOINT", "路线并不连接当前驻点与目标驻点")
	if route_world_points != Array(route.points):
		return _failure(&"ROUTE_MISMATCH", "路线草稿没有保留所画道路")
	return {"valid": true, "error_id": &"", "error": "", "route": route}


static func choose_route_from_draw(
	source_point_id: StringName,
	target_point_id: StringName,
	draw_world_points: Array
) -> Dictionary:
	if draw_world_points.size() < 2:
		return _failure(&"DRAW_TOO_SHORT", "请沿道路画出到目标驻点的路线")
	var best_route: Dictionary = {}
	var best_score := INF
	for candidate in get_routes_from(source_point_id):
		if StringName(candidate.target_point_id) != target_point_id:
			continue
		var score := _draw_distance_score(draw_world_points, Array(candidate.points))
		if score < best_score:
			best_score = score
			best_route = candidate
	if best_route.is_empty() or best_score > 105.0:
		return _failure(&"OFF_ROAD", "路线偏离道路；请从驻点沿道路画到友方驻点")
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"route": best_route.duplicate(true),
	}


static func _draw_distance_score(draw_world_points: Array, route_points: Array) -> float:
	var total := 0.0
	for point_value in draw_world_points:
		var point := Vector2(point_value)
		var nearest := INF
		for index in range(1, route_points.size()):
			nearest = minf(nearest, _distance_to_segment(
				point,
				Vector2(route_points[index - 1]),
				Vector2(route_points[index])
			))
		total += nearest
	var source_distance := Vector2(draw_world_points.front()).distance_to(
		Vector2(route_points.front())
	)
	var target_distance := Vector2(draw_world_points.back()).distance_to(
		Vector2(route_points.back())
	)
	return total / float(draw_world_points.size()) + source_distance + target_distance


static func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var squared := segment.length_squared()
	if squared <= 0.0001:
		return point.distance_to(start)
	var factor := clampf((point - start).dot(segment) / squared, 0.0, 1.0)
	return point.distance_to(start + segment * factor)


static func _failure(error_id: StringName, error: String) -> Dictionary:
	return {"valid": false, "error_id": error_id, "error": error, "route": {}}
