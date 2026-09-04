class_name GarrisonState
extends RefCounted


const SCHEMA_VERSION := 2
const FORMATION_IDS: Array[StringName] = [
	&"formation.blackstone.1",
	&"formation.blackstone.2",
	&"formation.blackstone.3",
]
const FORMATION_NAMES := {
	&"formation.blackstone.1": "北门先锋",
	&"formation.blackstone.2": "山道卫队",
	&"formation.blackstone.3": "城门后备",
}
const DEFAULT_FORMATION_MAX_MEMBERS := 20

var city_id: StringName
var _formations_by_id: Dictionary = {}
var _unit_definition_id: StringName = &""


func _init(
	city_id_value := &"blackstone_city",
	initial_definition_id := &"",
	initial_count := 0
) -> void:
	city_id = StringName(city_id_value)
	if StringName(initial_definition_id) != &"":
		_seed_roster(StringName(initial_definition_id), initial_count)


func get_unit_count(definition_id: StringName) -> int:
	if definition_id == &"" or definition_id != _unit_definition_id:
		return 0
	var total := 0
	for formation_id in FORMATION_IDS:
		total += int(Dictionary(_formations_by_id.get(formation_id, {})).get(
			"member_count", 0
		))
	return total


func set_unit_count(definition_id: StringName, count: int) -> bool:
	if definition_id == &"" or count < 0:
		return false
	if not _ensure_roster(definition_id):
		return false
	if count > FORMATION_IDS.size() * DEFAULT_FORMATION_MAX_MEMBERS:
		return false
	var base_count := count / FORMATION_IDS.size()
	var remainder := count % FORMATION_IDS.size()
	for index in range(FORMATION_IDS.size()):
		var formation_id := FORMATION_IDS[index]
		var formation: Dictionary = _formations_by_id[formation_id]
		formation.member_count = base_count + (1 if index < remainder else 0)
		_formations_by_id[formation_id] = formation
	return true


func try_add_units(
	definition_id: StringName,
	count: int,
	capacity := -1
) -> bool:
	if definition_id == &"" or count <= 0:
		return false
	if not _ensure_roster(definition_id):
		return false
	var current_total := get_unit_count(definition_id)
	var next_total := current_total + count
	if capacity >= 0 and next_total > capacity:
		return false
	if next_total > FORMATION_IDS.size() * DEFAULT_FORMATION_MAX_MEMBERS:
		return false
	var remaining := count
	for formation_id in FORMATION_IDS:
		var formation: Dictionary = _formations_by_id[formation_id]
		var available := int(formation.max_members) - int(formation.member_count)
		var accepted := mini(remaining, maxi(available, 0))
		formation.member_count = int(formation.member_count) + accepted
		_formations_by_id[formation_id] = formation
		remaining -= accepted
		if remaining == 0:
			break
	return remaining == 0


func try_remove_units(
	definition_id: StringName,
	count: int
) -> bool:
	if (
		definition_id == &""
		or count <= 0
		or definition_id != _unit_definition_id
		or count > get_unit_count(definition_id)
	):
		return false
	var remaining := count
	for index in range(FORMATION_IDS.size() - 1, -1, -1):
		var formation_id := FORMATION_IDS[index]
		var formation: Dictionary = _formations_by_id[formation_id]
		var removed := mini(remaining, int(formation.member_count))
		formation.member_count = int(formation.member_count) - removed
		_formations_by_id[formation_id] = formation
		remaining -= removed
		if remaining == 0:
			break
	return remaining == 0


func get_total_count() -> int:
	return get_unit_count(_unit_definition_id)


func get_unit_counts() -> Dictionary:
	if _unit_definition_id == &"":
		return {}
	return {_unit_definition_id: get_unit_count(_unit_definition_id)}


func get_formation_ids() -> Array[StringName]:
	return FORMATION_IDS.duplicate()


func get_formations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for formation_id in FORMATION_IDS:
		if _formations_by_id.has(formation_id):
			result.append(Dictionary(_formations_by_id[formation_id]).duplicate(true))
	return result


func get_formation(formation_id: StringName) -> Dictionary:
	return Dictionary(_formations_by_id.get(formation_id, {})).duplicate(true)


func get_selected_formations(formation_ids: Array) -> Array[Dictionary]:
	if formation_ids.is_empty() or formation_ids.size() > FORMATION_IDS.size():
		return []
	var seen: Dictionary = {}
	var result: Array[Dictionary] = []
	for formation_id_value in formation_ids:
		var formation_id := StringName(formation_id_value)
		var formation: Dictionary = _formations_by_id.get(formation_id, {})
		if (
			formation.is_empty()
			or seen.has(formation_id)
			or int(formation.member_count) <= 0
		):
			return []
		seen[formation_id] = true
		result.append(formation.duplicate(true))
	return result


func selection_matches(formation_snapshots: Array) -> bool:
	if formation_snapshots.is_empty() or formation_snapshots.size() > FORMATION_IDS.size():
		return false
	var seen: Dictionary = {}
	for snapshot_value in formation_snapshots:
		if not snapshot_value is Dictionary:
			return false
		var snapshot: Dictionary = snapshot_value
		var formation_id := StringName(snapshot.get("formation_id", &""))
		var current: Dictionary = _formations_by_id.get(formation_id, {})
		if (
			current.is_empty()
			or seen.has(formation_id)
			or StringName(snapshot.get("definition_id", &""))
				!= StringName(current.definition_id)
			or int(snapshot.get("member_count", -1)) != int(current.member_count)
		):
			return false
		seen[formation_id] = true
	return true


func apply_formation_survivors(
	departure_snapshots: Array,
	survivors_by_formation_id: Dictionary
) -> bool:
	if not selection_matches(departure_snapshots):
		return false
	if survivors_by_formation_id.size() != departure_snapshots.size():
		return false
	var next_counts: Dictionary = {}
	for departure_value in departure_snapshots:
		var departure: Dictionary = departure_value
		var formation_id := StringName(departure.formation_id)
		if not survivors_by_formation_id.has(formation_id):
			return false
		var survivor_value = survivors_by_formation_id[formation_id]
		if (
			typeof(survivor_value) != TYPE_INT
			or int(survivor_value) < 0
			or int(survivor_value) > int(departure.member_count)
		):
			return false
		next_counts[formation_id] = int(survivor_value)
	for formation_id in next_counts:
		var formation: Dictionary = _formations_by_id[formation_id]
		formation.member_count = int(next_counts[formation_id])
		_formations_by_id[formation_id] = formation
	return true


func get_persistence_snapshot() -> Dictionary:
	var formations_by_id: Dictionary = {}
	for formation_id in FORMATION_IDS:
		if _formations_by_id.has(formation_id):
			formations_by_id[formation_id] = Dictionary(
				_formations_by_id[formation_id]
			).duplicate(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"city_id": city_id,
		"formation_order": FORMATION_IDS.duplicate(),
		"formations_by_id": formations_by_id,
		# Compatibility projection, strictly validated against the roster.
		"unit_counts_by_definition_id": get_unit_counts(),
	}


func restore_persistence_snapshot(snapshot: Dictionary) -> bool:
	var allowed_ids: Array[StringName] = []
	if _unit_definition_id != &"":
		allowed_ids.append(_unit_definition_id)
	else:
		var formations: Dictionary = snapshot.get("formations_by_id", {})
		if formations.has(FORMATION_IDS[0]):
			allowed_ids.append(StringName(
				Dictionary(formations[FORMATION_IDS[0]]).get("definition_id", &"")
			))
	var validated := validate_persistence_snapshot(snapshot, city_id, allowed_ids)
	if not bool(validated.get("valid", false)):
		return false
	var normalized: Dictionary = validated.snapshot
	_unit_definition_id = StringName(
		Dictionary(normalized.formations_by_id)[FORMATION_IDS[0]].definition_id
	)
	_formations_by_id = Dictionary(normalized.formations_by_id).duplicate(true)
	return true


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"city_id": city_id,
		"unit_counts": get_unit_counts(),
		"total_count": get_total_count(),
		"formations": get_formations(),
	}


static func build_migrated_persistence_snapshot(
	city_id_value: StringName,
	definition_id: StringName,
	total_count: int
) -> Dictionary:
	var roster := GarrisonState.new(city_id_value, definition_id, total_count)
	return roster.get_persistence_snapshot()


static func validate_persistence_snapshot(
	snapshot: Dictionary,
	expected_city_id: StringName,
	allowed_unit_definition_ids: Array
) -> Dictionary:
	var expected_keys := [
		"schema_version",
		"city_id",
		"formation_order",
		"formations_by_id",
		"unit_counts_by_definition_id",
	]
	if not _has_exact_keys(snapshot, expected_keys):
		return _failure(&"INVALID_GARRISON", "编队 roster 字段不完整")
	if (
		typeof(snapshot.schema_version) != TYPE_INT
		or int(snapshot.schema_version) != SCHEMA_VERSION
		or typeof(snapshot.city_id) != TYPE_STRING_NAME
		or StringName(snapshot.city_id) != expected_city_id
		or typeof(snapshot.formation_order) != TYPE_ARRAY
		or typeof(snapshot.formations_by_id) != TYPE_DICTIONARY
		or typeof(snapshot.unit_counts_by_definition_id) != TYPE_DICTIONARY
		or Array(snapshot.formation_order) != FORMATION_IDS
	):
		return _failure(&"INVALID_GARRISON", "编队 roster 身份非法")
	var formations: Dictionary = snapshot.formations_by_id
	if formations.size() != FORMATION_IDS.size():
		return _failure(&"INVALID_GARRISON", "编队 roster 数量必须为三")
	var derived_counts: Dictionary = {}
	for formation_id in FORMATION_IDS:
		var formation_value = formations.get(formation_id)
		if not formation_value is Dictionary:
			return _failure(&"INVALID_GARRISON", "编队记录缺失")
		var formation: Dictionary = formation_value
		if (
			not _has_exact_keys(formation, [
				"formation_id", "display_name", "definition_id",
				"member_count", "max_members",
			])
			or typeof(formation.formation_id) != TYPE_STRING_NAME
			or StringName(formation.formation_id) != formation_id
			or typeof(formation.display_name) != TYPE_STRING
			or str(formation.display_name) != str(FORMATION_NAMES[formation_id])
			or typeof(formation.definition_id) != TYPE_STRING_NAME
			or StringName(formation.definition_id) not in allowed_unit_definition_ids
			or typeof(formation.member_count) != TYPE_INT
			or typeof(formation.max_members) != TYPE_INT
			or int(formation.member_count) < 0
			or int(formation.max_members) != DEFAULT_FORMATION_MAX_MEMBERS
			or int(formation.member_count) > int(formation.max_members)
		):
			return _failure(&"INVALID_GARRISON", "编队记录非法")
		var definition_id := StringName(formation.definition_id)
		derived_counts[definition_id] = int(derived_counts.get(definition_id, 0)) + int(formation.member_count)
	if Dictionary(snapshot.unit_counts_by_definition_id) != derived_counts:
		return _failure(&"INVALID_GARRISON", "驻军汇总与编队 roster 不一致")
	return {"valid": true, "snapshot": snapshot.duplicate(true)}


func _seed_roster(definition_id: StringName, initial_count: int) -> void:
	_unit_definition_id = definition_id
	for formation_id in FORMATION_IDS:
		_formations_by_id[formation_id] = {
			"formation_id": formation_id,
			"display_name": str(FORMATION_NAMES[formation_id]),
			"definition_id": definition_id,
			"member_count": 0,
			"max_members": DEFAULT_FORMATION_MAX_MEMBERS,
		}
	set_unit_count(definition_id, maxi(initial_count, 0))


func _ensure_roster(definition_id: StringName) -> bool:
	if _unit_definition_id == &"":
		_seed_roster(definition_id, 0)
	return _unit_definition_id == definition_id


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _failure(error_id: StringName, error: String) -> Dictionary:
	return {
		"valid": false,
		"error_id": error_id,
		"error": error,
		"snapshot": {},
	}
