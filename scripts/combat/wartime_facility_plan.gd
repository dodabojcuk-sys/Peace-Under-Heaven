class_name WartimeFacilityPlan
extends RefCounted


## Battle-only preparation facts.  These records are deliberately data-only:
## regular-city buildings and field projects retain their existing owners.
const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const KIND_WATCH_PLATFORM := &"WATCH_PLATFORM"
const KIND_SIEGE_RAM := &"SIEGE_RAM"
const KIND_ARROW_TOWER := &"ARROW_TOWER"
const KIND_BARRICADE := &"BARRICADE"
const KIND_SPIKE_TRAP := &"SPIKE_TRAP"
const FACILITY_KEYS := ["facility_id", "kind", "route_id", "construction_squad_id"]
const LEGACY_FACILITY_KEYS := ["facility_id", "kind", "route_id"]
const SNAPSHOT_KEYS := ["schema_version", "facilities"]

const FACILITY_COSTS := {
	KIND_WATCH_PLATFORM: {&"wood": 6},
	KIND_SIEGE_RAM: {&"wood": 8},
	KIND_ARROW_TOWER: {&"wood": 10},
	KIND_BARRICADE: {&"wood": 5},
	KIND_SPIKE_TRAP: {&"wood": 4},
}
const FACILITY_REPAIR_COSTS := {
	KIND_WATCH_PLATFORM: {&"wood": 2},
	KIND_SIEGE_RAM: {&"wood": 3},
	KIND_ARROW_TOWER: {&"wood": 3},
	KIND_BARRICADE: {&"wood": 2},
	KIND_SPIKE_TRAP: {&"wood": 2},
}


static func empty_snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "facilities": []}


static func make_facility(
	kind: StringName,
	route_id: StringName,
	construction_squad_id := 0
) -> Dictionary:
	return {
		"facility_id": StringName("%s-%s" % [kind.to_lower(), route_id.to_lower()]),
		"kind": kind,
		"route_id": route_id,
		"construction_squad_id": construction_squad_id,
	}


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _has_exact_keys(snapshot, SNAPSHOT_KEYS):
		return _failure("战时工事计划字段不完整")
	if (
		typeof(snapshot.schema_version) != TYPE_INT
		or int(snapshot.schema_version) not in [LEGACY_SCHEMA_VERSION, SCHEMA_VERSION]
		or typeof(snapshot.facilities) != TYPE_ARRAY
	):
		return _failure("战时工事计划类型非法")
	var normalized: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for facility_value in snapshot.facilities:
		if not facility_value is Dictionary:
			return _failure("战时工事记录非法")
		var facility: Dictionary = facility_value
		var is_legacy := int(snapshot.schema_version) == LEGACY_SCHEMA_VERSION
		if not _has_exact_keys(
			facility, LEGACY_FACILITY_KEYS if is_legacy else FACILITY_KEYS
		):
			return _failure("战时工事字段不完整")
		var facility_id := StringName(facility.get("facility_id", &""))
		var kind := StringName(facility.get("kind", &""))
		var route_id := StringName(facility.get("route_id", &""))
		var construction_squad_id := 0
		if not is_legacy:
			if typeof(facility.get("construction_squad_id", null)) != TYPE_INT:
				return _failure("战时工事施工分队类型非法")
			construction_squad_id = int(facility.get("construction_squad_id", 0))
		if (
			typeof(facility.facility_id) != TYPE_STRING_NAME
			or facility_id == &""
			or seen_ids.has(facility_id)
			or typeof(facility.kind) != TYPE_STRING_NAME
			or not FACILITY_COSTS.has(kind)
			or typeof(facility.route_id) != TYPE_STRING_NAME
			or route_id not in [&"FRONT_GATE", &"SIDE_GATE"]
			or facility_id != StringName("%s-%s" % [kind.to_lower(), route_id.to_lower()])
			or int(construction_squad_id) < 0
		):
			return _failure("战时工事身份或位置非法")
		seen_ids[facility_id] = true
		normalized.append(make_facility(kind, route_id, int(construction_squad_id)))
	return {"valid": true, "error": "", "snapshot": {
		"schema_version": SCHEMA_VERSION,
		"facilities": normalized,
	}}


## New formal plans must bind construction to one frozen participant. The
## legacy zero value is normalized only for saved pre-schema-2 records, then
## BattleSession performs its one-time compatible binding on activation.
static func validate_for_committed_squads(snapshot: Dictionary, squad_records: Array) -> Dictionary:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.get("valid", false)):
		return validation
	for facility_value in Array(Dictionary(validation.get("snapshot", {})).get("facilities", [])):
		var facility: Dictionary = Dictionary(facility_value)
		var construction_squad_id := int(facility.get("construction_squad_id", 0))
		if construction_squad_id <= 0:
			return _failure("请选择实际施工分队")
		var found := false
		for squad_value in squad_records:
			if not squad_value is Dictionary:
				continue
			var squad: Dictionary = squad_value
			if (
				typeof(squad.get("squad_id", null)) == TYPE_INT
				and int(squad.get("squad_id", 0)) == construction_squad_id
			):
				found = true
				break
		if not found:
			return _failure("施工分队不属于本次战斗")
	return validation


## The plan format is shared by assaults and defense missions, but the
## available tools are not. Keeping this check beside the plan shape prevents
## a UI-only restriction from being bypassed through a restored request or a
## direct controller call.
static func validate_for_source(snapshot: Dictionary, source_id: StringName) -> Dictionary:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.get("valid", false)):
		return validation
	if source_id == &"WARTIME_DEFENSE":
		for facility_value in Array(Dictionary(validation.snapshot).facilities):
			var facility: Dictionary = Dictionary(facility_value)
			if StringName(facility.get("kind", &"")) == KIND_SIEGE_RAM:
				return _failure("守城战不能部署攻城槌")
	elif has_kind(Dictionary(validation.get("snapshot", {})), KIND_SPIKE_TRAP):
		return _failure("刺钉陷阱只能用于守城战")
	return validation


static func is_available_for_source(kind: StringName, source_id: StringName) -> bool:
	if not FACILITY_COSTS.has(kind):
		return false
	if kind == KIND_SPIKE_TRAP:
		return source_id == &"WARTIME_DEFENSE"
	return not (
		source_id == &"WARTIME_DEFENSE"
		and kind == KIND_SIEGE_RAM
	)


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


## Facilities are route-bound. A player may defend both legal approaches with
## the same kind, but can never create a second copy of that kind on one route
## because its deterministic ID is already unique in validate_snapshot().
static func has_kind(
	snapshot: Dictionary,
	kind: StringName,
	route_id: StringName = &""
) -> bool:
	for facility_value in Array(snapshot.get("facilities", [])):
		if (
			facility_value is Dictionary
			and StringName(facility_value.get("kind", &"")) == kind
			and (route_id == &"" or StringName(facility_value.get("route_id", &"")) == route_id)
		):
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
