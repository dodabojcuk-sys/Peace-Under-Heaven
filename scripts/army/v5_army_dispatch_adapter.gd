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


func _get_city() -> Node:
	return _city_ref.get_ref() if _city_ref != null else null
