class_name V5NationalResourceAdapter
extends RefCounted


const RESOURCE_IDS: Array[StringName] = [
	&"food",
	&"tech_points",
	&"wood",
]


## Extracts the legacy blackstone city fields as a detached hydration DTO.
static func extract_legacy_city_resources(city: Dictionary) -> Dictionary:
	var resources: Dictionary = {}
	for resource_id in RESOURCE_IDS:
		if not city.has(resource_id) or typeof(city[resource_id]) != TYPE_INT:
			return {}
		resources[resource_id] = int(city[resource_id])
	return resources.duplicate(true)


## Projects the national authority back into the unchanged V5 city carrier.
static func project_into_legacy_city(
	city: Dictionary,
	nation_state: NationState
) -> Dictionary:
	if nation_state == null:
		return {}
	var projected := city.duplicate(true)
	var resources := nation_state.get_shared_resources()
	for resource_id in RESOURCE_IDS:
		if not resources.has(resource_id):
			return {}
		projected[resource_id] = int(resources[resource_id])
	return projected
