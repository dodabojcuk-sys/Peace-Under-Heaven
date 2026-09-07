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
	var duration := maxi(1800, ceili(start_position.distance_to(target_position) * 2.5))
	specialist.move_start_position = Vector2i(start_position)
	specialist.world_position = Vector2i(start_position)
	specialist.target_world_position = target_position
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
		or StringName(engineer.get("current_point_id", &"")) != source_point_id
		or resolved_target_point_id == &"" or resolved_target_point_id == source_point_id
		or route_world_points.size() < 2
		or road_kind not in [ROAD_NORMAL, ROAD_REINFORCED, ROAD_BRIDGE]
	):
		return {}
	if build_camp:
		next_camp_sequence += 1
	var project_id := StringName("project.%06d" % next_project_sequence)
	next_project_sequence += 1
	var road_id := StringName("road.built.%06d" % next_project_sequence)
	var max_durability := 70 if resolved_road_kind == ROAD_NORMAL else 150
	if resolved_road_kind == ROAD_BRIDGE:
		max_durability = 100
	var required_milliseconds := 5000 if resolved_road_kind == ROAD_NORMAL else 9000
	if resolved_road_kind == ROAD_BRIDGE:
		required_milliseconds = 11000
	var project := {
		"project_id": project_id,
		"engineer_id": engineer_id,
		"road_id": road_id,
		"source_point_id": source_point_id,
		"target_point_id": resolved_target_point_id,
		"route_world_points": route_world_points.duplicate(true),
		"road_kind": resolved_road_kind,
		"progress_milliseconds": 0,
		"required_milliseconds": required_milliseconds,
		"max_durability": max_durability,
		"build_camp": build_camp,
		"camp_id": reserved_camp_id,
		"phase": &"BUILDING",
	}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	engineer.phase = SPECIALIST_BUILDING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func road_kind_for_route(route_world_points: Array, requested_road_kind: StringName) -> StringName:
	if requested_road_kind == ROAD_BRIDGE or _route_crosses_water(route_world_points):
		return ROAD_BRIDGE
	return requested_road_kind


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
	var project_id := StringName("repair.%06d" % next_project_sequence)
	next_project_sequence += 1
	var target_point_id := StringName(road.get("target_point_id", &""))
	var target_position := _road_endpoint_position(road_id)
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var travel_milliseconds := maxi(0, ceili(start_position.distance_to(target_position) * 2.5))
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
		engineer.world_position = Vector2i(start_position)
		engineer.move_total_milliseconds = travel_milliseconds
		engineer.move_elapsed_milliseconds = 0
		engineer.move_remaining_milliseconds = travel_milliseconds
		engineer.phase = SPECIALIST_MOVING
	else:
		engineer.phase = SPECIALIST_REPAIRING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


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
	var road := Dictionary(roads_by_id.get(route_id, {}))
	return not road.is_empty() and bool(road.get("built", false)) and StringName(road.get("state", &"")) == ROAD_OPEN


func validate_runtime_route(source_point_id: StringName, target_point_id: StringName, route_id: StringName, route_world_points: Array) -> Dictionary:
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
	return {"valid": true, "error_id": &"", "error": "", "route": traversed}


func runtime_route_duration_milliseconds(route_id: StringName) -> int:
	var road := Dictionary(roads_by_id.get(route_id, {}))
	var points: Array = road.get("route_world_points", [])
	var length := 0.0
	for index in range(1, points.size()):
		length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	return maxi(6000, ceili(length * 20.0))


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
	var engagements: Array[Dictionary] = []
	# A repair may begin in the middle of this world step. Keep the unused part
	# of the step for its work progress so one long advance and split advances
	# produce identical durable state.
	var repair_arrival_work_milliseconds: Dictionary = {}
	for specialist_id_value in specialists_by_id.keys():
		var moving_id := StringName(specialist_id_value)
		var moving := Dictionary(specialists_by_id[moving_id])
		if not bool(moving.get("alive", false)) or StringName(moving.get("phase", &"")) != SPECIALIST_MOVING:
			continue
		var move_remaining_before := int(moving.get("move_remaining_milliseconds", 0))
		moving.move_elapsed_milliseconds = mini(int(moving.get("move_elapsed_milliseconds", 0)) + delta_milliseconds, int(moving.get("move_total_milliseconds", 0)))
		moving.move_remaining_milliseconds = maxi(int(moving.get("move_total_milliseconds", 0)) - int(moving.get("move_elapsed_milliseconds", 0)), 0)
		var move_progress := float(moving.get("move_elapsed_milliseconds", 0)) / maxf(float(moving.get("move_total_milliseconds", 1)), 1.0)
		moving.world_position = Vector2i(Vector2(moving.get("move_start_position", Vector2i.ZERO)).lerp(Vector2(moving.get("target_world_position", Vector2i.ZERO)), move_progress))
		if int(moving.move_remaining_milliseconds) == 0:
			moving.current_point_id = StringName(moving.target_point_id)
			moving.world_position = Vector2i(moving.get("target_world_position", Vector2i.ZERO))
			var active_project_id := StringName(moving.get("project_id", &""))
			var active_project := Dictionary(projects_by_id.get(active_project_id, {}))
			if StringName(active_project.get("project_kind", &"")) == &"REPAIR" and StringName(active_project.get("phase", &"")) == &"TRAVELING":
				active_project.phase = &"BUILDING"
				projects_by_id[active_project_id] = active_project
				repair_arrival_work_milliseconds[active_project_id] = maxi(delta_milliseconds - move_remaining_before, 0)
				moving.phase = SPECIALIST_REPAIRING
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
		var project_delta_milliseconds := int(repair_arrival_work_milliseconds.get(project_id, delta_milliseconds))
		if project_delta_milliseconds <= 0:
			continue
		project.progress_milliseconds = mini(
			int(project.progress_milliseconds) + project_delta_milliseconds,
			int(project.required_milliseconds)
		)
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
				roads_by_id[StringName(project.road_id)] = {
					"road_id": StringName(project.road_id),
					"source_point_id": StringName(project.source_point_id),
					"target_point_id": StringName(project.target_point_id),
					"route_world_points": Array(project.route_world_points).duplicate(true),
					"road_kind": StringName(project.road_kind),
					"state": ROAD_OPEN,
					"durability": int(project.max_durability),
					"max_durability": int(project.max_durability),
					"built": true,
					"project_id": project_id,
				}
			engineer.phase = SPECIALIST_IDLE
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
		for specialist_id_value in specialists_by_id.keys():
			var specialist_id := StringName(specialist_id_value)
			var specialist := Dictionary(specialists_by_id[specialist_id])
			if (
				bool(specialist.get("alive", false))
				and StringName(specialist.get("current_point_id", &"")) == StringName(patrol.get("current_point_id", &""))
				and StringName(specialist.get("phase", &"")) != SPECIALIST_MOVING
			):
				# Contact grants one last report before the observer is removed;
				# _refresh_intel then downgrades it to historical knowledge.
				intel_by_subject_id[patrol_id] = {
					"subject_id": patrol_id,
					"fog_state": FOG_VISIBLE,
					"last_known_point_id": StringName(patrol.current_point_id),
					"last_observed_milliseconds": world_milliseconds,
					"known_strength": int(patrol.strength),
				}
				specialist.alive = false
				specialist.phase = SPECIALIST_LOST
				specialists_by_id[specialist_id] = specialist
				engagements.append({"patrol_id": patrol_id, "specialist_id": specialist_id, "point_id": patrol.current_point_id})
	_refresh_intel()
	return {"success": true, "completed_project_ids": completed, "engagements": engagements, "world_milliseconds": world_milliseconds}


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
	return Vector2i.ZERO


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
			"last_observed_milliseconds": world_milliseconds if visible else int(previous.get("last_observed_milliseconds", 0)),
			"known_strength": int(patrol.get("strength", 0)) if visible else int(previous.get("known_strength", 0)),
		}
