class_name WartimeFacilityPlan
extends RefCounted


## Battle-only preparation facts.  These records are deliberately data-only:
## regular-city buildings and field projects retain their existing owners.
const SCHEMA_VERSION := 1
const KIND_WATCH_PLATFORM := &"WATCH_PLATFORM"
const KIND_SIEGE_RAM := &"SIEGE_RAM"
const KIND_ARROW_TOWER := &"ARROW_TOWER"
const KIND_BARRICADE := &"BARRICADE"
const FACILITY_KEYS := ["facility_id", "kind", "route_id"]
const SNAPSHOT_KEYS := ["schema_version", "facilities"]

const FACILITY_COSTS := {
	KIND_WATCH_PLATFORM: {&"wood": 6},
	KIND_SIEGE_RAM: {&"wood": 8},
	KIND_ARROW_TOWER: {&"wood": 10},
	KIND_BARRICADE: {&"wood": 5},
}
const FACILITY_REPAIR_COSTS := {
	KIND_WATCH_PLATFORM: {&"wood": 2},
	KIND_SIEGE_RAM: {&"wood": 3},
	KIND_ARROW_TOWER: {&"wood": 3},
	KIND_BARRICADE: {&"wood": 2},
}


static func empty_snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "facilities": []}


static func make_facility(kind: StringName, route_id: StringName) -> Dictionary:
	return {
		"facility_id": StringName("%s-%s" % [kind.to_lower(), route_id.to_lower()]),
		"kind": kind,
		"route_id": route_id,
	}


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _has_exact_keys(snapshot, SNAPSHOT_KEYS):
		return _failure("战时工事计划字段不完整")
	if (
		typeof(snapshot.schema_version) != TYPE_INT
		or int(snapshot.schema_version) != SCHEMA_VERSION
		or typeof(snapshot.facilities) != TYPE_ARRAY
	):
		return _failure("战时工事计划类型非法")
	var normalized: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var seen_kinds: Dictionary = {}
	for facility_value in snapshot.facilities:
		if not facility_value is Dictionary:
			return _failure("战时工事记录非法")
		var facility: Dictionary = facility_value
		if not _has_exact_keys(facility, FACILITY_KEYS):
			return _failure("战时工事字段不完整")
		var facility_id := StringName(facility.get("facility_id", &""))
		var kind := StringName(facility.get("kind", &""))
		var route_id := StringName(facility.get("route_id", &""))
		if (
			typeof(facility.facility_id) != TYPE_STRING_NAME
			or facility_id == &""
			or seen_ids.has(facility_id)
			or typeof(facility.kind) != TYPE_STRING_NAME
			or not FACILITY_COSTS.has(kind)
			or seen_kinds.has(kind)
			or typeof(facility.route_id) != TYPE_STRING_NAME
			or route_id not in [&"FRONT_GATE", &"SIDE_GATE"]
			or facility_id != StringName("%s-%s" % [kind.to_lower(), route_id.to_lower()])
		):
			return _failure("战时工事身份或位置非法")
		seen_ids[facility_id] = true
		seen_kinds[kind] = true
		normalized.append(facility.duplicate(true))
	return {"valid": true, "error": "", "snapshot": {
		"schema_version": SCHEMA_VERSION,
		"facilities": normalized,
	}}


static func get_costs(snapshot: Dictionary) -> Dictionary:
	var result := validate_snapshot(snapshot)
	if not bool(result.get("valid", false)):
		return {}
	var costs: Dictionary = {}
	for facility_value in Array(Dictionary(result.snapshot).facilities):
		var facility: Dictionary = facility_value
		for resource_id in Dictionary(FACILITY_COSTS[facility.kind]):
			costs[resource_id] = int(costs.get(resource_id, 0)) + int(
				FACILITY_COSTS[facility.kind][resource_id]
			)
	return costs


static func get_repair_costs(kind: StringName) -> Dictionary:
	return Dictionary(FACILITY_REPAIR_COSTS.get(kind, {})).duplicate(true)


static func has_kind(snapshot: Dictionary, kind: StringName) -> bool:
	for facility_value in Array(snapshot.get("facilities", [])):
		if facility_value is Dictionary and StringName(facility_value.get("kind", &"")) == kind:
			return true
	return false


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _failure(error: String) -> Dictionary:
	return {"valid": false, "error": error, "snapshot": {}}
