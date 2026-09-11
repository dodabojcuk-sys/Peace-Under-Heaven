class_name MacroMarchTheater
extends RefCounted


const DEFINITION_SCRIPT = preload("res://scripts/macro_march/macro_march_theater_definition.gd")
const PLAYABLE_DEFINITION_PATH := "res://resources/macro_march/blackstone_playable_r2.tres"

static var _definition_mode := &"PLAYABLE"
static var _playable_definition: MacroMarchTheaterDefinition
static var _regression_definition: MacroMarchTheaterDefinition = DEFINITION_SCRIPT.new()


static func use_playable_definition() -> void:
	_definition_mode = &"PLAYABLE"


static func use_regression_definition_for_tests() -> void:
	_definition_mode = &"REGRESSION"


static func get_definition_id() -> StringName:
	return &"blackstone_playable_r2" if _definition_mode == &"PLAYABLE" else &"blackstone_regression_r2"


static func _current_definition():
	if _definition_mode == &"REGRESSION":
		return _regression_definition
	if _playable_definition == null:
		# Lazy loading avoids the custom Resource script/preload cycle while still
		# keeping a single immutable definition during normal map rendering.
		_playable_definition = ResourceLoader.load(
			PLAYABLE_DEFINITION_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
		) as MacroMarchTheaterDefinition
	return _playable_definition


static func get_points() -> Dictionary:
	return _current_definition().points.duplicate(true)


static func get_routes() -> Dictionary:
	return _current_definition().routes.duplicate(true)


static func get_water_regions() -> Array[Rect2i]:
	var regions: Array[Rect2i] = []
	var definition = _current_definition()
	# Playable Resources keep all authored spatial regions in one list. This
	# avoids a second water-only layout while legacy regression definitions retain
	# their historical typed water array.
	for terrain_value in Array(definition.terrain_regions):
		var terrain: Dictionary = Dictionary(terrain_value)
		if StringName(terrain.get("kind", &"")) == &"WATER":
			regions.append(Rect2i(terrain.get("rect", Rect2i())))
	if not regions.is_empty():
		return regions
	for region_value in Array(definition.water_regions):
		regions.append(Rect2i(region_value))
	return regions


static func get_world_bounds() -> Rect2:
	return Rect2(_current_definition().world_bounds)


static func get_terrain_regions() -> Array[Dictionary]:
	return _current_definition().terrain_regions.duplicate(true)


static func get_patrol_configs() -> Array[Dictionary]:
	return _current_definition().patrol_configs.duplicate(true)


static func get_theater_name() -> String:
	return _current_definition().theater_name


static func get_scout_visibility_range() -> int:
	return maxi(int(_current_definition().scout_visibility_range), 1)


static func get_watchtower_config() -> Dictionary:
	return _current_definition().watchtower_config.duplicate(true)


static func get_presentation_profile() -> Dictionary:
	return _current_definition().presentation_profile.duplicate(true)


static func route_crosses_water(route_world_points: Array) -> bool:
	for index in range(1, route_world_points.size()):
		var start := Vector2(route_world_points[index - 1])
		var end := Vector2(route_world_points[index])
		var samples := maxi(1, ceili(start.distance_to(end)))
		for sample_index in range(samples + 1):
			var position := Vector2i(start.lerp(end, float(sample_index) / float(samples)))
			for water_region in get_water_regions():
				if water_region.has_point(position):
					return true
	return false


static func get_point(point_id: StringName) -> Dictionary:
	return Dictionary(get_points().get(point_id, {})).duplicate(true)


static func get_route(route_id: StringName) -> Dictionary:
	return Dictionary(get_routes().get(route_id, {})).duplicate(true)


static func get_routes_from(source_point_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var routes := get_routes()
	for route_id in routes:
		var route: Dictionary = routes[route_id]
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
