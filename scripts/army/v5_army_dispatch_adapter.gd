class_name V5ArmyDispatchAdapter
extends RefCounted


var _city_ref: WeakRef


func configure(city_authority: Node) -> bool:
	if city_authority == null:
		return false
	if _city_ref != null and _city_ref.get_ref() != city_authority:
		return false
	_city_ref = weakref(city_authority)
	return true


func get_dispatch_read_model() -> Dictionary:
	var city := _get_city()
	if city == null:
		return {}
	return {
		"city_id": &"blackstone_city",
		"unit_definition_id": city.INFANTRY_ROLE.role_id,
		"garrison_count": city.infantry_count,
		"dispatchable_count": city.get_dispatchable_infantry_count(),
		"active_reservation": (
			city.get_active_army_dispatch_reservation()
		),
		"active_armies": city.get_active_armies(),
	}


func reserve_dispatch(
	quantity: int,
	target_node_id: StringName,
	route_id: StringName,
	duration_milliseconds: int
) -> Dictionary:
	var city := _get_city()
	if city == null:
		return {}
	return city.reserve_army_dispatch(
		quantity,
		target_node_id,
		route_id,
		duration_milliseconds
	)


func confirm_dispatch(transaction_id: StringName) -> Dictionary:
	var city := _get_city()
	if city == null:
		return {}
	return city.confirm_army_dispatch(transaction_id)


func cancel_dispatch(transaction_id: StringName) -> bool:
	var city := _get_city()
	return (
		city != null
		and city.cancel_army_dispatch(transaction_id)
	)


func get_army_projection(army_id: StringName) -> Dictionary:
	var city := _get_city()
	if city == null:
		return {}
	var army: Dictionary = city.get_army_state(army_id)
	if army.is_empty():
		return {}
	var units: Dictionary = army.units_by_definition_id
	var total_count := 0
	for count in units.values():
		total_count += int(count)
	return {
		"unique_id": army.army_id,
		"source_node_id": army.source_node_id,
		"target_node_id": army.target_node_id,
		"route_id": army.route_id,
		"troop_counts": units.duplicate(true),
		"total_count": total_count,
		"progress": (
			float(army.progress_milliseconds)
			/ float(army.duration_milliseconds)
		),
		"travel_duration": (
			float(army.duration_milliseconds) / 1000.0
		),
		"status": army.phase,
		"resolved": StringName(army.phase) == &"CLOSED",
	}


# Macro March is intentionally exposed through this narrow adapter as well.
# The modal may render a projection and request commands, but only
# ConstructionController may mutate garrison, army, food, or persistence state.
func get_macro_march_read_model() -> Dictionary:
	var city := _get_city()
	return city.get_macro_march_read_model() if city != null else {}


func get_macro_march_command_preview(
	formation_ids: Array,
	army_id: StringName = &""
) -> Dictionary:
	var city := _get_city()
	return city.get_macro_march_command_preview(formation_ids, army_id) if city != null else {}


func get_field_tactics_read_model() -> Dictionary:
	var city := _get_city()
	return city.get_field_tactics_read_model() if city != null else {}


func plan_field_path(source_point_id: StringName, target_point_id: StringName, preferred_world_points: Array = []) -> Dictionary:
	var city := _get_city()
	return city.plan_field_path(source_point_id, target_point_id, preferred_world_points) if city != null else {}


func dispatch_field_specialist(role: StringName) -> Dictionary:
	var city := _get_city()
	return city.dispatch_field_specialist(role) if city != null else {}


func order_field_specialist_move(specialist_id: StringName, target_point_id: StringName) -> Dictionary:
	var city := _get_city()
	return city.order_field_specialist_move(specialist_id, target_point_id) if city != null else {}


func begin_field_road_project(
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	road_kind: StringName,
	build_camp := false
) -> Dictionary:
	var city := _get_city()
	return city.begin_field_road_project(
		engineer_id, source_point_id, target_point_id, route_world_points, road_kind, build_camp
	) if city != null else {}


func begin_field_road_repair(engineer_id: StringName, road_id: StringName) -> Dictionary:
	var city := _get_city()
	return city.begin_field_road_repair(engineer_id, road_id) if city != null else {}


func resume_interrupted_field_project(engineer_id: StringName, project_id: StringName) -> Dictionary:
	var city := _get_city()
	return city.resume_interrupted_field_project(engineer_id, project_id) if city != null else {}


func commit_macro_march_from_city(
	formation_ids: Array,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array
) -> Dictionary:
	var city := _get_city()
	return (
		city.commit_macro_march_from_city(
			formation_ids, target_point_id, route_id, route_world_points
		)
		if city != null else {}
	)


func commit_macro_march_from_station(
	army_id: StringName,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array
) -> Dictionary:
	var city := _get_city()
	return (
		city.commit_macro_march_from_station(
			army_id, target_point_id, route_id, route_world_points
		)
		if city != null else {}
	)


func advance_macro_march_time(
	army_id: StringName,
	order_id: StringName,
	expected_progress_milliseconds: int,
	delta_milliseconds: int
) -> Dictionary:
	var city := _get_city()
	return (
		city.advance_macro_march_time(
			army_id, order_id, expected_progress_milliseconds, delta_milliseconds
		)
		if city != null else {}
	)


func advance_macro_march_time_seconds(
	army_id: StringName,
	order_id: StringName,
	expected_progress_milliseconds: int,
	delta_seconds: float
) -> Dictionary:
	var city := _get_city()
	return (
		city.advance_macro_march_time_seconds(
			army_id, order_id, expected_progress_milliseconds, delta_seconds
		)
		if city != null else {}
	)


func advance_war_loop_time(delta_milliseconds: int) -> Dictionary:
	var city := _get_city()
	return city.advance_war_loop_time(delta_milliseconds) if city != null else {}


func request_macro_siege_retreat(city_id: StringName = &"") -> Dictionary:
	var city := _get_city()
	return city.request_macro_siege_retreat(city_id) if city != null else {}


func block_macro_march_at_segment(
	army_id: StringName,
	order_id: StringName,
	segment_index: int,
	progress_before_segment_millis: int,
	temporary_station_point: StringName
) -> Dictionary:
	var city := _get_city()
	return (
		city.block_macro_march_at_segment(
			army_id, order_id, segment_index, progress_before_segment_millis,
			temporary_station_point
		)
		if city != null else {}
	)


func resume_blocked_macro_march(army_id: StringName, order_id: StringName) -> Dictionary:
	var city := _get_city()
	return city.resume_blocked_macro_march(army_id, order_id) if city != null else {}


func set_macro_march_route_blocked_for_scenario(route_id: StringName, blocked: bool) -> bool:
	var city := _get_city()
	return city.set_macro_march_route_blocked_for_scenario(route_id, blocked) if city != null else false


func _get_city() -> Node:
	return _city_ref.get_ref() if _city_ref != null else null
