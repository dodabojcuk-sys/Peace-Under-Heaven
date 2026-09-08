class_name FieldTacticsState
extends RefCounted


## Persistent R2 outer-city state.  It intentionally contains only data and
## deterministic simulation: ConstructionController remains the authority for
## resource commits and V5 remains the only disk publisher.
const SCHEMA_VERSION := 1
const ROAD_MAIN := &"MAIN"
const ROAD_NORMAL := &"NORMAL"
const ROAD_REINFORCED := &"REINFORCED"
const ROAD_BRIDGE := &"BRIDGE"
const ROAD_OPEN := &"OPEN"
const ROAD_DAMAGED := &"DAMAGED"
const SPECIALIST_SCOUT := &"SCOUT"
const SPECIALIST_ENGINEER := &"ENGINEER"
const SPECIALIST_IDLE := &"IDLE"
const SPECIALIST_MOVING := &"MOVING"
const SPECIALIST_BUILDING := &"BUILDING"
const SPECIALIST_REPAIRING := &"REPAIRING"
const SPECIALIST_LOST := &"LOST"
const FOG_UNOBSERVED := &"UNOBSERVED"
const FOG_OBSERVED := &"OBSERVED"
const FOG_VISIBLE := &"VISIBLE"
const PATH_PREFIX := "path."
const INVALID_WORLD_POSITION := Vector2i(-999999, -999999)

var roads_by_id: Dictionary = {}
var camps_by_id: Dictionary = {}
var specialists_by_id: Dictionary = {}
var projects_by_id: Dictionary = {}
var patrols_by_id: Dictionary = {}
var intel_by_subject_id: Dictionary = {}
var point_positions_by_id: Dictionary = {}
var water_regions: Array[Rect2i] = []
var world_milliseconds := 0
var next_specialist_sequence := 1
var next_project_sequence := 1
var next_camp_sequence := 1


func initialize_from_theater(points: Dictionary, routes: Dictionary, water_regions_value: Array[Rect2i] = []) -> void:
	water_regions = water_regions_value.duplicate()
	for point_id_value in points:
		var point: Dictionary = Dictionary(points[point_id_value])
		point_positions_by_id[StringName(point_id_value)] = Vector2i(point.get("world_position", Vector2i.ZERO))
	if not roads_by_id.is_empty():
		return
	for route_id_value in routes:
		var route: Dictionary = Dictionary(routes[route_id_value])
		var route_id := StringName(route_id_value)
		roads_by_id[route_id] = {
			"road_id": route_id,
			"source_point_id": StringName(route.get("source_point_id", &"")),
			"target_point_id": StringName(route.get("target_point_id", &"")),
			"route_world_points": Array(route.get("points", [])).duplicate(true),
			"road_kind": ROAD_MAIN,
			"state": ROAD_OPEN,
			"durability": 999999,
			"max_durability": 999999,
			"built": true,
			"project_id": &"",
		}
	# A finite patrol is a real persistent participant, not a UI warning.  It
	# begins hidden until a player observer sees its node or current road.
	if patrols_by_id.is_empty() and points.has(&"northwatch_garrison"):
		patrols_by_id[&"patrol.ridge.001"] = {
			"patrol_id": &"patrol.ridge.001",
			"current_point_id": &"northwatch_garrison",
			"strength": 5,
			"phase": &"PATROL",
			"route_point_ids": [&"northwatch_garrison", &"reedbank_garrison"],
			"target_route_index": 1,
			"wait_remaining_milliseconds": 2400,
			"move_total_milliseconds": 4000,
			"move_elapsed_milliseconds": 0,
			"move_start_position": _point_position(&"northwatch_garrison"),
			"last_known_target_id": &"",
			"last_known_at_milliseconds": 0,
			"world_position": _point_position(&"northwatch_garrison"),
		}


func dispatch_specialist(role: StringName, source_point_id: StringName) -> Dictionary:
	if role not in [SPECIALIST_SCOUT, SPECIALIST_ENGINEER] or source_point_id == &"":
		return {}
	var specialist_id := StringName("%s.%06d" % [String(role).to_lower(), next_specialist_sequence])
	next_specialist_sequence += 1
	var specialist := {
		"specialist_id": specialist_id,
		"role": role,
		"current_point_id": source_point_id,
		"target_point_id": source_point_id,
		"phase": SPECIALIST_IDLE,
		"move_remaining_milliseconds": 0,
		"move_total_milliseconds": 0,
		"move_elapsed_milliseconds": 0,
		"move_start_position": _point_position(source_point_id),
		"move_route_world_points": [_point_position(source_point_id)],
		"world_position": _point_position(source_point_id),
		"target_world_position": _point_position(source_point_id),
		"visibility_range": 2 if role == SPECIALIST_SCOUT else 1,
		"project_id": &"",
		"alive": true,
	}
	specialists_by_id[specialist_id] = specialist
	_refresh_intel()
	return specialist.duplicate(true)


func order_specialist_move(specialist_id: StringName, target_point_id: StringName) -> Dictionary:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if specialist.is_empty() or not bool(specialist.get("alive", false)) or target_point_id == &"":
		return {}
	if StringName(specialist.get("project_id", &"")) != &"":
		return {}
	if StringName(specialist.get("current_point_id", &"")) == target_point_id:
		return specialist.duplicate(true)
	specialist.target_point_id = target_point_id
	var start_position := Vector2(specialist.get("world_position", _point_position(StringName(specialist.get("current_point_id", &"")))))
	var target_position := _point_position(target_point_id)
	if target_position == INVALID_WORLD_POSITION:
		return {}
	var movement_plan := _plan_specialist_land_path(start_position, target_position)
	if movement_plan.is_empty():
		return {}
	var duration := maxi(1800, int(movement_plan.get("duration_milliseconds", 0)))
	specialist.move_start_position = Vector2i(start_position)
	specialist.world_position = Vector2i(start_position)
	specialist.target_world_position = target_position
	specialist.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
	specialist.move_total_milliseconds = duration
	specialist.move_elapsed_milliseconds = 0
	specialist.move_remaining_milliseconds = duration
	specialist.phase = SPECIALIST_MOVING
	specialists_by_id[specialist_id] = specialist
	return specialist.duplicate(true)


func begin_road_project(
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	road_kind: StringName,
	build_camp: bool = false
) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var resolved_road_kind := road_kind_for_route(route_world_points, road_kind)
	var resolved_target_point_id := target_point_id
	# A camp identity is reserved when the command is confirmed, rather than
	# when work finishes.  Two engineers can therefore build concurrently
	# without both targeting the next not-yet-created camp site.
	var reserved_camp_id: StringName = &""
	if build_camp:
		var camp_sequence := next_camp_sequence
		reserved_camp_id = StringName("camp.%06d" % camp_sequence)
		if resolved_target_point_id == &"":
			resolved_target_point_id = StringName("camp.site.%06d" % camp_sequence)
	if (
		engineer.is_empty() or not bool(engineer.get("alive", false))
		or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or StringName(engineer.get("phase", &"")) == SPECIALIST_BUILDING
		or StringName(engineer.get("project_id", &"")) != &""
		or resolved_target_point_id == &"" or resolved_target_point_id == source_point_id
		or route_world_points.size() < 2
		or road_kind not in [ROAD_NORMAL, ROAD_REINFORCED, ROAD_BRIDGE]
	):
		return {}
	if build_camp:
		next_camp_sequence += 1
	var project_id := StringName("project.%06d" % next_project_sequence)
	next_project_sequence += 1
	var road_sequence := next_project_sequence
	var segment_plans := _build_construction_segment_plans(
		project_id, source_point_id, resolved_target_point_id, route_world_points, road_kind, road_sequence
	)
	if segment_plans.is_empty():
		return {}
	var road_id := StringName(Dictionary(segment_plans.back()).get("road_id", &""))
	var max_durability := int(Dictionary(segment_plans.back()).get("max_durability", 0))
	var required_milliseconds := 0
	for segment_value in segment_plans:
		required_milliseconds += int(Dictionary(segment_value).get("required_milliseconds", 0))
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var construction_start_position := _point_position(source_point_id)
	if construction_start_position == INVALID_WORLD_POSITION:
		return {}
	var movement_plan := _plan_specialist_land_path(start_position, construction_start_position)
	if movement_plan.is_empty():
		return {}
	var travel_milliseconds := int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(construction_start_position) > 0.01 else 0
	var project := {
		"project_id": project_id,
		"project_kind": &"CONSTRUCTION",
		"engineer_id": engineer_id,
		"road_id": road_id,
		"source_point_id": source_point_id,
		"target_point_id": resolved_target_point_id,
		"route_world_points": route_world_points.duplicate(true),
		"road_kind": resolved_road_kind,
		"progress_milliseconds": 0,
		"travel_milliseconds": travel_milliseconds,
		"required_milliseconds": required_milliseconds,
		"max_durability": max_durability,
		"segment_plans": segment_plans,
		"build_camp": build_camp,
		"camp_id": reserved_camp_id,
		"phase": &"TRAVELING" if travel_milliseconds > 0 else &"BUILDING",
	}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	if travel_milliseconds > 0:
		engineer.target_point_id = source_point_id
		engineer.move_start_position = Vector2i(start_position)
		engineer.target_world_position = construction_start_position
		engineer.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
		engineer.world_position = Vector2i(start_position)
		engineer.move_total_milliseconds = travel_milliseconds
		engineer.move_elapsed_milliseconds = 0
		engineer.move_remaining_milliseconds = travel_milliseconds
		engineer.phase = SPECIALIST_MOVING
	else:
		engineer.current_point_id = source_point_id
		engineer.target_point_id = source_point_id
		engineer.world_position = construction_start_position
		engineer.phase = SPECIALIST_BUILDING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func road_kind_for_route(route_world_points: Array, requested_road_kind: StringName) -> StringName:
	if requested_road_kind == ROAD_BRIDGE or _route_crosses_water(route_world_points):
		return ROAD_BRIDGE
	return requested_road_kind


func _build_construction_segment_plans(
	project_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	requested_road_kind: StringName,
	road_sequence: int
) -> Array:
	if requested_road_kind != ROAD_BRIDGE and not _route_crosses_water(route_world_points):
		var max_durability := 150 if requested_road_kind == ROAD_REINFORCED else 70
		return [{
			"road_id": StringName("road.built.%06d" % road_sequence),
			"source_point_id": source_point_id,
			"target_point_id": target_point_id,
			"route_world_points": route_world_points.duplicate(true),
			"road_kind": requested_road_kind,
			"required_milliseconds": 9000 if requested_road_kind == ROAD_REINFORCED else 5000,
			"max_durability": max_durability,
		}]
	var sections: Array = []
	for point_index in range(1, route_world_points.size()):
		var start := Vector2(route_world_points[point_index - 1])
		var end := Vector2(route_world_points[point_index])
		var samples := maxi(1, ceili(start.distance_to(end) / 16.0))
		for sample_index in range(1, samples + 1):
			var part_start := start.lerp(end, float(sample_index - 1) / float(samples))
			var part_end := start.lerp(end, float(sample_index) / float(samples))
			var part_kind := requested_road_kind
			if requested_road_kind != ROAD_BRIDGE and _point_is_in_water(Vector2i((part_start + part_end) * 0.5)):
				part_kind = ROAD_BRIDGE
			if sections.is_empty() or StringName(Dictionary(sections.back()).get("road_kind", &"")) != part_kind:
				sections.append({"road_kind": part_kind, "route_world_points": [Vector2i(part_start), Vector2i(part_end)]})
			else:
				Array(Dictionary(sections.back()).route_world_points).append(Vector2i(part_end))
	var plans: Array = []
	for section_index in range(sections.size()):
		var section: Dictionary = Dictionary(sections[section_index])
		var is_first := section_index == 0
		var is_last := section_index == sections.size() - 1
		var section_kind := StringName(section.get("road_kind", ROAD_NORMAL))
		var section_id := StringName("road.built.%06d" % road_sequence) if sections.size() == 1 else StringName("road.built.%06d.%02d" % [road_sequence, section_index + 1])
		plans.append({
			"road_id": section_id,
			"source_point_id": source_point_id if is_first else StringName("junction.%s.%02d" % [String(project_id), section_index]),
			"target_point_id": target_point_id if is_last else StringName("junction.%s.%02d" % [String(project_id), section_index + 1]),
			"route_world_points": Array(section.get("route_world_points", [])).duplicate(true),
			"road_kind": section_kind,
			"required_milliseconds": 11000 if section_kind == ROAD_BRIDGE else (9000 if section_kind == ROAD_REINFORCED else 5000),
			"max_durability": 100 if section_kind == ROAD_BRIDGE else (150 if section_kind == ROAD_REINFORCED else 70),
		})
	return plans


func _point_is_in_water(position: Vector2i) -> bool:
	for water_region in water_regions:
		if water_region.has_point(position):
			return true
	return false


func _route_crosses_water(route_world_points: Array) -> bool:
	for index in range(1, route_world_points.size()):
		var start := Vector2(route_world_points[index - 1])
		var end := Vector2(route_world_points[index])
		var samples := maxi(1, ceili(start.distance_to(end) / 16.0))
		for sample_index in range(samples + 1):
			var position := Vector2i(start.lerp(end, float(sample_index) / float(samples)))
			for water_region in water_regions:
				if water_region.has_point(position):
					return true
	return false


func damage_road(road_id: StringName, amount: int) -> bool:
	var road := Dictionary(roads_by_id.get(road_id, {}))
	if road.is_empty() or StringName(road.get("road_kind", &"")) == ROAD_MAIN or amount <= 0:
		return false
	road.durability = maxi(int(road.get("durability", 0)) - amount, 0)
	if int(road.durability) == 0:
		road.state = ROAD_DAMAGED
	roads_by_id[road_id] = road
	return true


func repair_road(engineer_id: StringName, road_id: StringName) -> bool:
	return not begin_road_repair(engineer_id, road_id).is_empty()


func begin_road_repair(engineer_id: StringName, road_id: StringName) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var road := Dictionary(roads_by_id.get(road_id, {}))
	if (
		engineer.is_empty() or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or not bool(engineer.get("alive", false)) or road.is_empty()
		or StringName(road.get("road_kind", &"")) == ROAD_MAIN
		or StringName(road.get("state", &"")) != ROAD_DAMAGED
		or StringName(engineer.get("project_id", &"")) != &""
	):
		return {}
	var repair_target := _reachable_repair_endpoint(engineer, road)
	if repair_target.is_empty():
		return {}
	var project_id := StringName("repair.%06d" % next_project_sequence)
	next_project_sequence += 1
	var target_point_id := StringName(repair_target.get("point_id", &""))
	var target_position := Vector2(repair_target.get("world_position", Vector2.ZERO))
	if Vector2i(target_position) == INVALID_WORLD_POSITION:
		return {}
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var movement_plan := _plan_specialist_land_path(start_position, target_position)
	if movement_plan.is_empty():
		return {}
	var travel_milliseconds := int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(target_position) > 0.01 else 0
	var project := {
		"project_id": project_id,
		"project_kind": &"REPAIR",
		"engineer_id": engineer_id,
		"road_id": road_id,
		"source_point_id": StringName(engineer.get("current_point_id", &"")),
		"target_point_id": target_point_id,
		"route_world_points": [],
		"road_kind": StringName(road.get("road_kind", &"")),
		"progress_milliseconds": 0,
		"required_milliseconds": 2500,
		"max_durability": int(road.get("max_durability", 0)),
		"build_camp": false,
		"camp_id": &"",
		"phase": &"TRAVELING" if travel_milliseconds > 0 else &"BUILDING",
	}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	if travel_milliseconds > 0:
		engineer.target_point_id = target_point_id
		engineer.move_start_position = Vector2i(start_position)
		engineer.target_world_position = Vector2i(target_position)
		engineer.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
		engineer.world_position = Vector2i(start_position)
		engineer.move_total_milliseconds = travel_milliseconds
		engineer.move_elapsed_milliseconds = 0
		engineer.move_remaining_milliseconds = travel_milliseconds
		engineer.phase = SPECIALIST_MOVING
	else:
		engineer.phase = SPECIALIST_REPAIRING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func _reachable_repair_endpoint(engineer: Dictionary, road: Dictionary) -> Dictionary:
	var source_point_id := StringName(engineer.get("current_point_id", &""))
	if source_point_id == &"":
		return {}
	var best: Dictionary = {}
	for endpoint_id_value in [road.get("source_point_id", &""), road.get("target_point_id", &"")]:
		var endpoint_id := StringName(endpoint_id_value)
		if endpoint_id == &"":
			continue
		var duration := 0
		if endpoint_id != source_point_id:
			var path := plan_runtime_path(source_point_id, endpoint_id)
			if not bool(path.get("valid", false)):
				continue
			duration = int(path.get("duration_milliseconds", 0))
		if best.is_empty() or duration < int(best.get("duration_milliseconds", 0)):
			best = {
				"point_id": endpoint_id,
				"world_position": _point_position(endpoint_id),
				"duration_milliseconds": duration,
			}
	return best


static func _has_valid_references(roads: Dictionary, camps: Dictionary, specialists: Dictionary, projects: Dictionary, patrols: Dictionary, intel: Dictionary) -> bool:
	for road_id_value in roads:
		var road: Dictionary = Dictionary(roads[road_id_value])
		if StringName(road_id_value) == &"" or StringName(road.get("road_id", &"")) != StringName(road_id_value) or StringName(road.get("state", &"")) not in [ROAD_OPEN, ROAD_DAMAGED]:
			return false
	for specialist_id_value in specialists:
		var specialist: Dictionary = Dictionary(specialists[specialist_id_value])
		if StringName(specialist_id_value) == &"" or StringName(specialist.get("specialist_id", &"")) != StringName(specialist_id_value) or StringName(specialist.get("role", &"")) not in [SPECIALIST_SCOUT, SPECIALIST_ENGINEER]:
			return false
		var project_id := StringName(specialist.get("project_id", &""))
		if project_id != &"" and not projects.has(project_id):
			return false
	for project_id_value in projects:
		var project: Dictionary = Dictionary(projects[project_id_value])
		if StringName(project_id_value) == &"" or StringName(project.get("project_id", &"")) != StringName(project_id_value) or not specialists.has(StringName(project.get("engineer_id", &""))) or StringName(project.get("road_id", &"")) == &"":
			return false
	for camp_id_value in camps:
		var camp: Dictionary = Dictionary(camps[camp_id_value])
		if StringName(camp_id_value) == &"" or StringName(camp.get("camp_id", &"")) != StringName(camp_id_value) or not roads.has(StringName(camp.get("road_id", &""))):
			return false
	for patrol_id_value in patrols:
		if StringName(patrol_id_value) == &"" or not patrols[patrol_id_value] is Dictionary:
			return false
	for subject_id_value in intel:
		if StringName(subject_id_value) == &"" or not intel[subject_id_value] is Dictionary:
			return false
	return true


func is_route_open(route_id: StringName) -> bool:
	if String(route_id).begins_with(PATH_PREFIX):
		for segment in _path_segments(route_id):
			if not is_route_open(StringName(segment.get("road_id", &""))):
				return false
		return not _path_segments(route_id).is_empty()
	var road := Dictionary(roads_by_id.get(route_id, {}))
	return not road.is_empty() and bool(road.get("built", false)) and StringName(road.get("state", &"")) == ROAD_OPEN


func first_unavailable_route_segment(
	route_id: StringName,
	route_segments: Array,
	route_world_points: Array,
	progress_milliseconds: int,
	total_milliseconds: int
) -> int:
	var resolved_segments := route_segments.duplicate(true)
	if resolved_segments.is_empty():
		resolved_segments = _path_segments(route_id)
	if resolved_segments.is_empty() and route_id != &"":
		resolved_segments = [{"road_id": route_id, "forward": true}]
	if resolved_segments.is_empty():
		return 0
	var total_length := 0.0
	for point_index in range(1, route_world_points.size()):
		total_length += Vector2(route_world_points[point_index - 1]).distance_to(Vector2(route_world_points[point_index]))
	var progressed_length := total_length * clampf(
		float(progress_milliseconds) / float(maxi(total_milliseconds, 1)), 0.0, 1.0
	)
	var current_segment_index := 0
	var consumed_length := 0.0
	for segment_index in range(resolved_segments.size()):
		var segment: Dictionary = Dictionary(resolved_segments[segment_index])
		var segment_points: Array = Array(Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {})).get("route_world_points", [])).duplicate(true)
		if not bool(segment.get("forward", false)):
			segment_points.reverse()
		var segment_length := 0.0
		for point_index in range(1, segment_points.size()):
			segment_length += Vector2(segment_points[point_index - 1]).distance_to(Vector2(segment_points[point_index]))
		consumed_length += segment_length
		if progressed_length < consumed_length - 0.0001:
			current_segment_index = segment_index
			break
		current_segment_index = mini(segment_index + 1, resolved_segments.size() - 1)
	for segment_index in range(current_segment_index, resolved_segments.size()):
		if not is_route_open(StringName(Dictionary(resolved_segments[segment_index]).get("road_id", &""))):
			return segment_index
	return -1


func validate_runtime_route(source_point_id: StringName, target_point_id: StringName, route_id: StringName, route_world_points: Array) -> Dictionary:
	if String(route_id).begins_with(PATH_PREFIX):
		return _validate_runtime_path(source_point_id, target_point_id, route_id, route_world_points)
	var road := Dictionary(roads_by_id.get(route_id, {}))
	if road.is_empty():
		return {"valid": false, "error_id": &"UNKNOWN_ROAD", "error": "该道路不存在"}
	if not is_route_open(route_id):
		return {"valid": false, "error_id": &"ROAD_DAMAGED", "error": "该道路尚未完工或已损坏"}
	if source_point_id == target_point_id:
		return {"valid": false, "error_id": &"ILLEGAL_ENDPOINT", "error": "道路不连接当前驻点与目标驻点"}
	var forward := (
		StringName(road.get("source_point_id", &"")) == source_point_id
		and StringName(road.get("target_point_id", &"")) == target_point_id
		and route_world_points == Array(road.get("route_world_points", []))
	)
	var reverse_points := Array(road.get("route_world_points", [])).duplicate(true)
	reverse_points.reverse()
	var reverse := (
		StringName(road.get("target_point_id", &"")) == source_point_id
		and StringName(road.get("source_point_id", &"")) == target_point_id
		and route_world_points == reverse_points
	)
	if not forward and not reverse:
		return {"valid": false, "error_id": &"ILLEGAL_ENDPOINT", "error": "道路不连接当前驻点与目标驻点"}
	var traversed := road.duplicate(true)
	if reverse:
		traversed.source_point_id = source_point_id
		traversed.target_point_id = target_point_id
		traversed.route_world_points = reverse_points
	traversed.segment_ids = [{"road_id": route_id, "forward": not reverse}]
	return {"valid": true, "error_id": &"", "error": "", "route": traversed}


func runtime_route_duration_milliseconds(route_id: StringName) -> int:
	if String(route_id).begins_with(PATH_PREFIX):
		return _path_duration_milliseconds(_path_world_points(route_id))
	var road := Dictionary(roads_by_id.get(route_id, {}))
	var points: Array = road.get("route_world_points", [])
	var length := 0.0
	for index in range(1, points.size()):
		length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	return maxi(6000, ceili(length * 20.0))


func plan_runtime_path(source_point_id: StringName, target_point_id: StringName, preferred_world_points: Array = []) -> Dictionary:
	if source_point_id == &"" or target_point_id == &"" or source_point_id == target_point_id:
		return {"valid": false, "error": "起点和目标必须是不同的合法据点"}
	var frontier: Array[Dictionary] = [{"point_id": source_point_id, "segments": [], "cost": 0.0}]
	var best_cost_by_point: Dictionary = {source_point_id: 0.0}
	while not frontier.is_empty():
		var cheapest_index := 0
		for frontier_index in range(1, frontier.size()):
			if float(frontier[frontier_index].get("cost", INF)) < float(frontier[cheapest_index].get("cost", INF)):
				cheapest_index = frontier_index
		var current: Dictionary = frontier.pop_at(cheapest_index)
		var current_point := StringName(current.get("point_id", &""))
		var current_cost := float(current.get("cost", INF))
		if current_cost > float(best_cost_by_point.get(current_point, INF)) + 0.0001:
			continue
		if current_point == target_point_id:
			var segments: Array = current.get("segments", [])
			var route_id := _path_id(segments)
			var points := _path_world_points_from_segments(segments)
			return {"valid": true, "route_id": route_id, "segments": segments, "points": points, "duration_milliseconds": _path_duration_milliseconds(points)}
		for road_value in roads_by_id.values():
			var road: Dictionary = road_value
			if not bool(road.get("built", false)) or StringName(road.get("state", &"")) != ROAD_OPEN:
				continue
			var next_point := &""
			var forward := true
			if StringName(road.get("source_point_id", &"")) == current_point:
				next_point = StringName(road.get("target_point_id", &""))
			elif StringName(road.get("target_point_id", &"")) == current_point:
				next_point = StringName(road.get("source_point_id", &""))
				forward = false
			if next_point == &"":
				continue
			var next_cost := current_cost + _road_traversal_cost(road, forward, preferred_world_points)
			if next_cost >= float(best_cost_by_point.get(next_point, INF)) - 0.0001:
				continue
			var next_segments: Array = Array(current.get("segments", [])).duplicate(true)
			next_segments.append({"road_id": StringName(road.get("road_id", &"")), "forward": forward})
			best_cost_by_point[next_point] = next_cost
			frontier.append({"point_id": next_point, "segments": next_segments, "cost": next_cost})
	return {"valid": false, "error": "没有连通的已完工道路路径"}


func _road_traversal_cost(road: Dictionary, forward: bool, preferred_world_points: Array) -> float:
	var points: Array = Array(road.get("route_world_points", [])).duplicate(true)
	if not forward:
		points.reverse()
	var length := 0.0
	for point_index in range(1, points.size()):
		length += Vector2(points[point_index - 1]).distance_to(Vector2(points[point_index]))
	if preferred_world_points.size() < 2:
		return length
	var draw_penalty := 0.0
	for point in points:
		var nearest := INF
		for draw_index in range(1, preferred_world_points.size()):
			nearest = minf(nearest, _distance_to_segment(Vector2(point), Vector2(preferred_world_points[draw_index - 1]), Vector2(preferred_world_points[draw_index])))
		draw_penalty += nearest
	return length + draw_penalty * 12.0 / float(maxi(points.size(), 1))


func _path_id(segments: Array) -> StringName:
	if segments.size() == 1:
		return StringName(Dictionary(segments.front()).get("road_id", &""))
	var tokens: Array[String] = []
	for segment_value in segments:
		var segment: Dictionary = segment_value
		tokens.append("%s:%s" % [String(segment.get("road_id", &"")), "f" if bool(segment.get("forward", false)) else "r"])
	return StringName(PATH_PREFIX + "|".join(tokens))


func _path_segments(route_id: StringName) -> Array[Dictionary]:
	if not String(route_id).begins_with(PATH_PREFIX):
		return []
	var result: Array[Dictionary] = []
	for token in String(route_id).trim_prefix(PATH_PREFIX).split("|", false):
		var parts := token.rsplit(":", true, 1)
		if parts.size() != 2 or not roads_by_id.has(StringName(parts[0])) or parts[1] not in ["f", "r"]:
			return []
		result.append({"road_id": StringName(parts[0]), "forward": parts[1] == "f"})
	return result


func _path_world_points(route_id: StringName) -> Array:
	return _path_world_points_from_segments(_path_segments(route_id))


func _path_world_points_from_segments(segments: Array) -> Array:
	var result: Array = []
	for segment_value in segments:
		var segment: Dictionary = segment_value
		var points: Array = Array(Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {})).get("route_world_points", [])).duplicate(true)
		if not bool(segment.get("forward", false)):
			points.reverse()
		if not result.is_empty() and (points.is_empty() or Vector2(result.back()) != Vector2(points.front())):
			return []
		if not result.is_empty() and not points.is_empty():
			points.pop_front()
		result.append_array(points)
	return result


func _path_duration_milliseconds(points: Array) -> int:
	var length := 0.0
	for index in range(1, points.size()):
		length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	return maxi(6000, ceili(length * 20.0))


func _validate_runtime_path(source_point_id: StringName, target_point_id: StringName, route_id: StringName, route_world_points: Array) -> Dictionary:
	var segments := _path_segments(route_id)
	if segments.size() < 2:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径缺少连续道路段"}
	var expected_point_id := source_point_id
	for segment_value in segments:
		var segment: Dictionary = segment_value
		var road: Dictionary = Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {}))
		var segment_start := StringName(road.get("source_point_id", &"")) if bool(segment.get("forward", false)) else StringName(road.get("target_point_id", &""))
		var segment_end := StringName(road.get("target_point_id", &"")) if bool(segment.get("forward", false)) else StringName(road.get("source_point_id", &""))
		if road.is_empty() or segment_start != expected_point_id:
			return {"valid": false, "error_id": &"PATH_DISCONNECTED", "error": "军令路径包含未连接的道路段"}
		expected_point_id = segment_end
	if expected_point_id != target_point_id:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径没有抵达指定目标"}
	var points := _path_world_points_from_segments(segments)
	if points.is_empty() or points != route_world_points:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径与已确认路段不一致"}
	var first: Dictionary = Dictionary(segments.front())
	var last: Dictionary = Dictionary(segments.back())
	var first_road := Dictionary(roads_by_id.get(StringName(first.road_id), {}))
	var last_road := Dictionary(roads_by_id.get(StringName(last.road_id), {}))
	var actual_source := StringName(first_road.get("source_point_id", &"")) if bool(first.forward) else StringName(first_road.get("target_point_id", &""))
	var actual_target := StringName(last_road.get("target_point_id", &"")) if bool(last.forward) else StringName(last_road.get("source_point_id", &""))
	if actual_source != source_point_id or actual_target != target_point_id:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径端点与命令不一致"}
	if not is_route_open(route_id):
		return {"valid": false, "error_id": &"ROAD_DAMAGED", "error": "路径道路不再可通行"}
	return {"valid": true, "error_id": &"", "error": "", "route": {"route_id": route_id, "route_world_points": points, "segment_ids": segments}}


func _path_draw_score(drawn: Array, path: Array) -> float:
	if drawn.is_empty():
		return 0.0
	if path.size() < 2:
		return INF
	var total := 0.0
	for value in drawn:
		var nearest := INF
		for index in range(1, path.size()):
			nearest = minf(nearest, _distance_to_segment(Vector2(value), Vector2(path[index - 1]), Vector2(path[index])))
		total += nearest
	return total / float(drawn.size()) + Vector2(drawn.front()).distance_to(Vector2(path.front())) + Vector2(drawn.back()).distance_to(Vector2(path.back()))


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var squared := segment.length_squared()
	if squared <= 0.0001:
		return point.distance_to(start)
	return point.distance_to(start + segment * clampf((point - start).dot(segment) / squared, 0.0, 1.0))


func get_runtime_points() -> Dictionary:
	var points: Dictionary = {}
	for camp_value in camps_by_id.values():
		var camp: Dictionary = camp_value
		var point_id := StringName(camp.get("point_id", &""))
		if point_id == &"":
			continue
		points[point_id] = {
			"point_id": point_id,
			"display_name": String(camp.get("display_name", "工程驻点")),
			"world_position": Vector2(camp.get("world_position", _road_endpoint_position(StringName(camp.get("road_id", &""))))),
			"point_kind": &"FRIENDLY_GARRISON",
		}
	return points


func advance_world(delta_milliseconds: int) -> Dictionary:
	if delta_milliseconds <= 0:
		return {}
	world_milliseconds += delta_milliseconds
	var completed: Array[StringName] = []
	var opened_road_ids: Array[StringName] = []
	var engagements: Array[Dictionary] = []
	# A repair may begin in the middle of this world step. Keep the unused part
	# of the step for its work progress so one long advance and split advances
	# produce identical durable state.
	var project_arrival_work_milliseconds: Dictionary = {}
	for specialist_id_value in specialists_by_id.keys():
		var moving_id := StringName(specialist_id_value)
		var moving := Dictionary(specialists_by_id[moving_id])
		if not bool(moving.get("alive", false)) or StringName(moving.get("phase", &"")) != SPECIALIST_MOVING:
			continue
		var move_remaining_before := int(moving.get("move_remaining_milliseconds", 0))
		moving.move_elapsed_milliseconds = mini(int(moving.get("move_elapsed_milliseconds", 0)) + delta_milliseconds, int(moving.get("move_total_milliseconds", 0)))
		moving.move_remaining_milliseconds = maxi(int(moving.get("move_total_milliseconds", 0)) - int(moving.get("move_elapsed_milliseconds", 0)), 0)
		var move_progress := float(moving.get("move_elapsed_milliseconds", 0)) / maxf(float(moving.get("move_total_milliseconds", 1)), 1.0)
		moving.world_position = Vector2i(_position_along_points(
			Array(moving.get("move_route_world_points", [moving.get("move_start_position", Vector2i.ZERO), moving.get("target_world_position", Vector2i.ZERO)])),
			move_progress
		))
		if int(moving.move_remaining_milliseconds) == 0:
			moving.current_point_id = StringName(moving.target_point_id)
			moving.world_position = Vector2i(moving.get("target_world_position", Vector2i.ZERO))
			var active_project_id := StringName(moving.get("project_id", &""))
			var active_project := Dictionary(projects_by_id.get(active_project_id, {}))
			if StringName(active_project.get("phase", &"")) == &"TRAVELING" and StringName(active_project.get("project_kind", &"")) in [&"REPAIR", &"CONSTRUCTION"]:
				active_project.phase = &"BUILDING"
				projects_by_id[active_project_id] = active_project
				project_arrival_work_milliseconds[active_project_id] = maxi(delta_milliseconds - move_remaining_before, 0)
				moving.phase = SPECIALIST_REPAIRING if StringName(active_project.get("project_kind", &"")) == &"REPAIR" else SPECIALIST_BUILDING
			else:
				moving.phase = SPECIALIST_IDLE
		specialists_by_id[moving_id] = moving
	for project_id_value in projects_by_id.keys():
		var project_id := StringName(project_id_value)
		var project := Dictionary(projects_by_id[project_id])
		if StringName(project.get("phase", &"")) != &"BUILDING":
			continue
		var engineer := Dictionary(specialists_by_id.get(StringName(project.engineer_id), {}))
		if engineer.is_empty() or not bool(engineer.get("alive", false)):
			project.phase = &"INTERRUPTED"
			projects_by_id[project_id] = project
			continue
		var project_delta_milliseconds := int(project_arrival_work_milliseconds.get(project_id, delta_milliseconds))
		if project_delta_milliseconds <= 0:
			continue
		project.progress_milliseconds = mini(
			int(project.progress_milliseconds) + project_delta_milliseconds,
			int(project.required_milliseconds)
		)
		if StringName(project.get("project_kind", &"")) != &"REPAIR":
			_update_engineer_construction_position(engineer, project)
			specialists_by_id[StringName(project.engineer_id)] = engineer
			opened_road_ids.append_array(_open_completed_construction_segments(project_id, project))
		if int(project.progress_milliseconds) == int(project.required_milliseconds):
			project.phase = &"COMPLETE"
			if StringName(project.get("project_kind", &"")) == &"REPAIR":
				var repaired_road := Dictionary(roads_by_id.get(StringName(project.road_id), {}))
				if repaired_road.is_empty():
					project.phase = &"INTERRUPTED"
					projects_by_id[project_id] = project
					continue
				repaired_road.durability = int(repaired_road.max_durability)
				repaired_road.state = ROAD_OPEN
				roads_by_id[StringName(project.road_id)] = repaired_road
			else:
				opened_road_ids.append_array(_open_completed_construction_segments(project_id, project))
			engineer.phase = SPECIALIST_IDLE
			if StringName(project.get("project_kind", &"")) != &"REPAIR":
				engineer.current_point_id = StringName(project.get("target_point_id", &""))
				engineer.target_point_id = StringName(project.get("target_point_id", &""))
				# A new camp does not exist until _create_completed_camp below.  The
				# final physical road endpoint is already authoritative here, whereas
				# resolving the not-yet-created camp would incorrectly place the
				# engineer at the zero vector for one persistence frame.
				engineer.world_position = Vector2i(_road_endpoint_position(StringName(project.get("road_id", &""))))
			engineer.project_id = &""
			specialists_by_id[StringName(project.engineer_id)] = engineer
			if bool(project.build_camp):
				_create_completed_camp(
					StringName(project.target_point_id), StringName(project.road_id),
					StringName(project.get("camp_id", &""))
				)
			completed.append(project_id)
		projects_by_id[project_id] = project
	for patrol_id_value in patrols_by_id.keys():
		var patrol_id := StringName(patrol_id_value)
		var patrol := Dictionary(patrols_by_id[patrol_id])
		if int(patrol.get("strength", 0)) <= 0:
			continue
		# Consume all of this world step across wait→move→arrival transitions.
		# Otherwise a large frame would discard its post-arrival remainder and
		# patrol positions would depend on call partitioning.
		var patrol_remaining_milliseconds := delta_milliseconds
		var patrol_transitions := 0
		while patrol_remaining_milliseconds > 0 and patrol_transitions < 16:
			patrol_transitions += 1
			var patrol_wait := mini(int(patrol.get("wait_remaining_milliseconds", 0)), patrol_remaining_milliseconds)
			if patrol_wait > 0:
				patrol.wait_remaining_milliseconds = int(patrol.get("wait_remaining_milliseconds", 0)) - patrol_wait
				patrol_remaining_milliseconds -= patrol_wait
				if patrol_remaining_milliseconds <= 0:
					break
			var patrol_route: Array = Array(patrol.get("route_point_ids", []))
			if patrol_route.size() < 2:
				break
			var target_index := clampi(int(patrol.get("target_route_index", 0)), 0, patrol_route.size() - 1)
			var target_point_id := StringName(patrol_route[target_index])
			var target_position := _point_position(target_point_id)
			var patrol_total_milliseconds := maxi(int(patrol.get("move_total_milliseconds", 1)), 1)
			var to_arrival_milliseconds := maxi(patrol_total_milliseconds - int(patrol.get("move_elapsed_milliseconds", 0)), 0)
			var patrol_move := mini(patrol_remaining_milliseconds, to_arrival_milliseconds)
			if patrol_move <= 0:
				break
			patrol.move_elapsed_milliseconds = int(patrol.get("move_elapsed_milliseconds", 0)) + patrol_move
			patrol_remaining_milliseconds -= patrol_move
			var patrol_progress := float(patrol.get("move_elapsed_milliseconds", 0)) / float(patrol_total_milliseconds)
			patrol.world_position = Vector2i(Vector2(patrol.get("move_start_position", _point_position(StringName(patrol.get("current_point_id", &""))))).lerp(Vector2(target_position), patrol_progress))
			if int(patrol.get("move_elapsed_milliseconds", 0)) < patrol_total_milliseconds:
				break
			patrol.current_point_id = target_point_id
			patrol.world_position = target_position
			patrol.target_route_index = (target_index + 1) % patrol_route.size()
			patrol.wait_remaining_milliseconds = 1200
			patrol.move_elapsed_milliseconds = 0
			patrol.move_start_position = target_position
		patrols_by_id[patrol_id] = patrol
		for specialist_id_value in specialists_by_id.keys():
			var specialist_id := StringName(specialist_id_value)
			var specialist := Dictionary(specialists_by_id[specialist_id])
			if (
				bool(specialist.get("alive", false))
				and Vector2(specialist.get("world_position", Vector2.ZERO)).distance_to(Vector2(patrol.get("world_position", Vector2.ZERO))) <= 28.0
				and StringName(specialist.get("phase", &"")) != SPECIALIST_MOVING
			):
				# Contact grants one last report before the observer is removed;
				# _refresh_intel then downgrades it to historical knowledge.
				intel_by_subject_id[patrol_id] = {
					"subject_id": patrol_id,
					"fog_state": FOG_VISIBLE,
					"last_known_point_id": StringName(patrol.current_point_id),
					"last_known_world_position": Vector2i(patrol.get("world_position", Vector2i.ZERO)),
					"last_observed_milliseconds": world_milliseconds,
					"known_strength": int(patrol.strength),
				}
				specialist.alive = false
				specialist.phase = SPECIALIST_LOST
				specialists_by_id[specialist_id] = specialist
				engagements.append({"patrol_id": patrol_id, "specialist_id": specialist_id, "point_id": patrol.current_point_id})
	_refresh_intel()
	return {"success": true, "completed_project_ids": completed, "opened_road_ids": opened_road_ids, "engagements": engagements, "world_milliseconds": world_milliseconds}


func _open_completed_construction_segments(project_id: StringName, project: Dictionary) -> Array[StringName]:
	var opened: Array[StringName] = []
	var elapsed := int(project.get("progress_milliseconds", 0))
	var accumulated := 0
	var segment_plans: Array = Array(project.get("segment_plans", []))
	if segment_plans.is_empty():
		segment_plans = [{
			"road_id": StringName(project.get("road_id", &"")),
			"source_point_id": StringName(project.get("source_point_id", &"")),
			"target_point_id": StringName(project.get("target_point_id", &"")),
			"route_world_points": Array(project.get("route_world_points", [])).duplicate(true),
			"road_kind": StringName(project.get("road_kind", ROAD_NORMAL)),
			"required_milliseconds": int(project.get("required_milliseconds", 0)),
			"max_durability": int(project.get("max_durability", 0)),
		}]
	for segment_value in segment_plans:
		var segment: Dictionary = Dictionary(segment_value)
		accumulated += int(segment.get("required_milliseconds", 0))
		var road_id := StringName(segment.get("road_id", &""))
		if elapsed < accumulated or road_id == &"" or roads_by_id.has(road_id):
			continue
		roads_by_id[road_id] = {
			"road_id": road_id,
			"source_point_id": StringName(segment.get("source_point_id", &"")),
			"target_point_id": StringName(segment.get("target_point_id", &"")),
			"route_world_points": Array(segment.get("route_world_points", [])).duplicate(true),
			"road_kind": StringName(segment.get("road_kind", ROAD_NORMAL)),
			"state": ROAD_OPEN,
			"durability": int(segment.get("max_durability", 0)),
			"max_durability": int(segment.get("max_durability", 0)),
			"built": true,
			"project_id": project_id,
		}
		opened.append(road_id)
	return opened


func _update_engineer_construction_position(engineer: Dictionary, project: Dictionary) -> void:
	var elapsed := int(project.get("progress_milliseconds", 0))
	var accumulated := 0
	for segment_value in Array(project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		var duration := maxi(int(segment.get("required_milliseconds", 0)), 1)
		var points: Array = Array(segment.get("route_world_points", []))
		if points.is_empty():
			continue
		if elapsed >= accumulated + duration:
			engineer.world_position = Vector2i(points.back())
			accumulated += duration
			continue
		var local_progress := clampf(float(elapsed - accumulated) / float(duration), 0.0, 1.0)
		# A bridge is built from the reachable bank.  The engineer remains at its
		# start until the bridge opens instead of visually crossing water early.
		if StringName(segment.get("road_kind", &"")) == ROAD_BRIDGE:
			engineer.world_position = Vector2i(points.front())
			return
		engineer.world_position = Vector2i(_position_along_points(points, local_progress))
		return


func _position_along_points(points: Array, progress: float) -> Vector2:
	var total_length := 0.0
	for point_index in range(1, points.size()):
		total_length += Vector2(points[point_index - 1]).distance_to(Vector2(points[point_index]))
	if total_length <= 0.0001:
		return Vector2(points.front()) if not points.is_empty() else Vector2.ZERO
	var target_length := total_length * clampf(progress, 0.0, 1.0)
	var consumed := 0.0
	for point_index in range(1, points.size()):
		var start := Vector2(points[point_index - 1])
		var end := Vector2(points[point_index])
		var length := start.distance_to(end)
		if target_length <= consumed + length:
			return start.lerp(end, (target_length - consumed) / maxf(length, 0.0001))
		consumed += length
	return Vector2(points.back())


func _plan_specialist_land_path(start_position: Vector2, target_position: Vector2) -> Dictionary:
	if _point_is_in_water(Vector2i(start_position)) or _point_is_in_water(Vector2i(target_position)):
		return {}
	var nodes: Array[Vector2] = [start_position, target_position]
	# A visibility graph over water bounds is sufficient for the small greybox
	# theatre: specialists may cross open land, but never cut across a water
	# region. Roads remain optional shortcuts rather than a movement requirement.
	for water in water_regions:
		var margin := 2.0
		for corner in [
			Vector2(water.position.x - margin, water.position.y - margin),
			Vector2(water.end.x + margin, water.position.y - margin),
			Vector2(water.position.x - margin, water.end.y + margin),
			Vector2(water.end.x + margin, water.end.y + margin),
		]:
			nodes.append(corner)
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for index in nodes.size():
		costs.append(0.0 if index == 0 else INF)
		previous.append(-1)
		visited.append(false)
	for _step in nodes.size():
		var current := -1
		for index in nodes.size():
			if not visited[index] and (current < 0 or costs[index] < costs[current]):
				current = index
		if current < 0 or is_inf(costs[current]):
			break
		if current == 1:
			break
		visited[current] = true
		for next_index in nodes.size():
			if next_index == current or _route_crosses_water([nodes[current], nodes[next_index]]):
				continue
			var candidate := costs[current] + nodes[current].distance_to(nodes[next_index])
			if candidate < costs[next_index]:
				costs[next_index] = candidate
				previous[next_index] = current
	if is_inf(costs[1]):
		return {}
	var reverse_points: Array = []
	var cursor := 1
	while cursor >= 0:
		reverse_points.append(Vector2i(nodes[cursor]))
		cursor = previous[cursor]
	reverse_points.reverse()
	return {
		"points": reverse_points,
		"duration_milliseconds": maxi(1800, ceili(costs[1] * 2.5)),
	}


func observe_subject(subject_id: StringName) -> Dictionary:
	return Dictionary(intel_by_subject_id.get(subject_id, {
		"subject_id": subject_id,
		"fog_state": FOG_UNOBSERVED,
		"last_known_point_id": &"",
		"last_observed_milliseconds": 0,
		"known_strength": 0,
	})).duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"roads_by_id": roads_by_id.duplicate(true),
		"camps_by_id": camps_by_id.duplicate(true),
		"specialists_by_id": specialists_by_id.duplicate(true),
		"projects_by_id": projects_by_id.duplicate(true),
		"patrols_by_id": patrols_by_id.duplicate(true),
		"intel_by_subject_id": intel_by_subject_id.duplicate(true),
		"world_milliseconds": world_milliseconds,
		"next_specialist_sequence": next_specialist_sequence,
		"next_project_sequence": next_project_sequence,
		"next_camp_sequence": next_camp_sequence,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var required := ["schema_version", "roads_by_id", "camps_by_id", "specialists_by_id", "projects_by_id", "patrols_by_id", "intel_by_subject_id", "world_milliseconds", "next_specialist_sequence", "next_project_sequence", "next_camp_sequence"]
	if snapshot.size() != required.size() or int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	for key in required:
		if not snapshot.has(key):
			return false
	if (
		not snapshot.roads_by_id is Dictionary or not snapshot.camps_by_id is Dictionary
		or not snapshot.specialists_by_id is Dictionary or not snapshot.projects_by_id is Dictionary
		or not snapshot.patrols_by_id is Dictionary or not snapshot.intel_by_subject_id is Dictionary
		or int(snapshot.world_milliseconds) < 0 or int(snapshot.next_specialist_sequence) <= 0
		or int(snapshot.next_project_sequence) <= 0 or int(snapshot.next_camp_sequence) <= 0
	):
		return false
	if not _has_valid_references(
		Dictionary(snapshot.roads_by_id), Dictionary(snapshot.camps_by_id),
		Dictionary(snapshot.specialists_by_id), Dictionary(snapshot.projects_by_id),
		Dictionary(snapshot.patrols_by_id), Dictionary(snapshot.intel_by_subject_id)
	):
		return false
	roads_by_id = Dictionary(snapshot.roads_by_id).duplicate(true)
	camps_by_id = Dictionary(snapshot.camps_by_id).duplicate(true)
	specialists_by_id = Dictionary(snapshot.specialists_by_id).duplicate(true)
	projects_by_id = Dictionary(snapshot.projects_by_id).duplicate(true)
	patrols_by_id = Dictionary(snapshot.patrols_by_id).duplicate(true)
	intel_by_subject_id = Dictionary(snapshot.intel_by_subject_id).duplicate(true)
	world_milliseconds = int(snapshot.world_milliseconds)
	next_specialist_sequence = int(snapshot.next_specialist_sequence)
	next_project_sequence = int(snapshot.next_project_sequence)
	next_camp_sequence = int(snapshot.next_camp_sequence)
	return true


func _create_completed_camp(point_id: StringName, road_id: StringName, reserved_camp_id: StringName = &"") -> void:
	# Old saves predate command-time camp reservations.  Keep their completion
	# path readable, while all new projects use their already persisted ID.
	var camp_id := reserved_camp_id
	if camp_id == &"":
		camp_id = StringName("camp.%06d" % next_camp_sequence)
		next_camp_sequence += 1
	camps_by_id[camp_id] = {
		"camp_id": camp_id,
		"point_id": point_id,
		"road_id": road_id,
		"display_name": "工程驻点 %s" % String(camp_id).trim_prefix("camp."),
		"world_position": Vector2i(_road_endpoint_position(road_id)),
		"durability": 80,
		"connected": true,
	}


func _road_endpoint_position(road_id: StringName) -> Vector2:
	var road: Dictionary = Dictionary(roads_by_id.get(road_id, {}))
	var points: Array = road.get("route_world_points", [])
	return Vector2(points.back()) if not points.is_empty() else Vector2.ZERO


func _point_position(point_id: StringName) -> Vector2i:
	if point_positions_by_id.has(point_id):
		return Vector2i(point_positions_by_id[point_id])
	for camp_value in camps_by_id.values():
		var camp: Dictionary = camp_value
		if StringName(camp.get("point_id", &"")) == point_id:
			return Vector2i(camp.get("world_position", _road_endpoint_position(StringName(camp.get("road_id", &"")))))
	for road_value in roads_by_id.values():
		var road: Dictionary = road_value
		var points: Array = Array(road.get("route_world_points", []))
		if points.is_empty():
			continue
		if StringName(road.get("source_point_id", &"")) == point_id:
			return Vector2i(points.front())
		if StringName(road.get("target_point_id", &"")) == point_id:
			return Vector2i(points.back())
	return INVALID_WORLD_POSITION


func _refresh_intel() -> void:
	var observers: Array[Dictionary] = []
	for specialist_value in specialists_by_id.values():
		var specialist: Dictionary = specialist_value
		if bool(specialist.get("alive", false)):
			observers.append({
				"world_position": Vector2(specialist.get("world_position", _point_position(StringName(specialist.get("current_point_id", &""))))),
				"range": int(specialist.get("visibility_range", 1)) * 180,
			})
	for camp_value in camps_by_id.values():
		observers.append({"world_position": Vector2(Dictionary(camp_value).get("world_position", Vector2.ZERO)), "range": 120})
	for patrol_id_value in patrols_by_id:
		var patrol: Dictionary = Dictionary(patrols_by_id[patrol_id_value])
		var patrol_id := StringName(patrol_id_value)
		var patrol_position := Vector2(patrol.get("world_position", _point_position(StringName(patrol.get("current_point_id", &"")))))
		var visible := false
		for observer_value in observers:
			var observer: Dictionary = observer_value
			if patrol_position.distance_to(Vector2(observer.world_position)) <= float(observer.range):
				visible = true
				break
		var previous := Dictionary(intel_by_subject_id.get(patrol_id, {}))
		var previously_seen := StringName(previous.get("fog_state", FOG_UNOBSERVED)) in [FOG_VISIBLE, FOG_OBSERVED]
		intel_by_subject_id[patrol_id] = {
			"subject_id": patrol_id,
			"fog_state": FOG_VISIBLE if visible else (FOG_OBSERVED if previously_seen else FOG_UNOBSERVED),
			"last_known_point_id": StringName(patrol.get("current_point_id", &"")) if visible else StringName(previous.get("last_known_point_id", &"")),
			"last_known_world_position": Vector2i(patrol_position) if visible else Vector2i(previous.get("last_known_world_position", Vector2i.ZERO)),
			"last_observed_milliseconds": world_milliseconds if visible else int(previous.get("last_observed_milliseconds", 0)),
			"known_strength": int(patrol.get("strength", 0)) if visible else int(previous.get("known_strength", 0)),
		}
