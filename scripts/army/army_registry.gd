class_name ArmyRegistry
extends RefCounted


const SCHEMA_VERSION := 1
const PHASE_RESERVED := &"RESERVED"
const PHASE_MARCHING := &"MARCHING"
const PHASE_ARRIVED := &"ARRIVED"
const PHASE_RETURNING := &"RETURNING"
const PHASE_SETTLEMENT_PENDING := &"SETTLEMENT_PENDING"
const PHASE_CLOSED := &"CLOSED"
const DISPOSITION_STATIONED_TARGET := &"STATIONED_TARGET"
const DISPOSITION_RETURNING_HOME := &"RETURNING_HOME"
const DISPOSITION_CLOSED_LOST := &"CLOSED_LOST"
const ACTIVE_PHASES := [
	PHASE_RESERVED,
	PHASE_MARCHING,
	PHASE_ARRIVED,
	PHASE_RETURNING,
	PHASE_SETTLEMENT_PENDING,
]
const ALL_PHASES := [
	PHASE_RESERVED,
	PHASE_MARCHING,
	PHASE_ARRIVED,
	PHASE_RETURNING,
	PHASE_SETTLEMENT_PENDING,
	PHASE_CLOSED,
]

var _next_army_sequence := 1
var _armies_by_id: Dictionary = {}


func has_active_army() -> bool:
	return not get_active_armies().is_empty()


func get_army(army_id: StringName) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	return army.duplicate(true)


func get_armies() -> Array[Dictionary]:
	var armies: Array[Dictionary] = []
	var army_ids := _armies_by_id.keys()
	army_ids.sort()
	for army_id in army_ids:
		armies.append(Dictionary(_armies_by_id[army_id]).duplicate(true))
	return armies


func get_active_armies() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for army in get_armies():
		if StringName(army.phase) in ACTIVE_PHASES:
			active.append(army)
	return active


func create_reserved(
	owner_faction_id: StringName,
	home_city_id: StringName,
	source_node_id: StringName,
	target_node_id: StringName,
	route_id: StringName,
	units_by_definition_id: Dictionary,
	duration_milliseconds: int,
	transaction_id: StringName
) -> Dictionary:
	if (
		has_active_army()
		or owner_faction_id == &""
		or home_city_id == &""
		or source_node_id == &""
		or target_node_id == &""
		or source_node_id == target_node_id
		or route_id == &""
		or transaction_id == &""
		or duration_milliseconds <= 0
		or not _has_valid_composition(units_by_definition_id)
	):
		return {}
	var army_id := StringName(
		"army.%s.%06d" % [
			String(owner_faction_id),
			_next_army_sequence,
		]
	)
	_next_army_sequence += 1
	var army := {
		"army_id": army_id,
		"owner_faction_id": owner_faction_id,
		"home_city_id": home_city_id,
		"source_node_id": source_node_id,
		"target_node_id": target_node_id,
		"route_id": route_id,
		"units_by_definition_id": (
			units_by_definition_id.duplicate(true)
		),
		"progress_milliseconds": 0,
		"duration_milliseconds": duration_milliseconds,
		"phase": PHASE_RESERVED,
		"transaction_id": transaction_id,
		"last_applied_result_id": &"",
	}
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func transition(
	army_id: StringName,
	transaction_id: StringName,
	expected_phase: StringName,
	next_phase: StringName
) -> bool:
	if (
		army_id == &""
		or transaction_id == &""
		or expected_phase not in ALL_PHASES
		or next_phase not in ALL_PHASES
	):
		return false
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase) != expected_phase
		or not _is_allowed_transition(expected_phase, next_phase)
	):
		return false
	army.phase = next_phase
	_armies_by_id[army_id] = army
	return true


func advance_progress(
	army_id: StringName,
	transaction_id: StringName,
	expected_progress_milliseconds: int,
	delta_milliseconds: int
) -> Dictionary:
	if delta_milliseconds <= 0 or expected_progress_milliseconds < 0:
		return {}
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase)
			not in [PHASE_MARCHING, PHASE_RETURNING]
		or int(army.progress_milliseconds)
			!= expected_progress_milliseconds
	):
		return {}
	var next_progress := mini(
		expected_progress_milliseconds + delta_milliseconds,
		int(army.duration_milliseconds)
	)
	army.progress_milliseconds = next_progress
	var arrived := next_progress == int(army.duration_milliseconds)
	if arrived:
		army.phase = PHASE_ARRIVED
	_armies_by_id[army_id] = army
	return {
		"success": true,
		"arrived": arrived,
		"army": army.duplicate(true),
	}


func set_result_link(
	army_id: StringName,
	transaction_id: StringName,
	result_id: StringName
) -> bool:
	if result_id == &"":
		return false
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase) != PHASE_SETTLEMENT_PENDING
		or StringName(army.last_applied_result_id) != &""
	):
		return false
	army.last_applied_result_id = result_id
	_armies_by_id[army_id] = army
	return true


func replace_composition_for_settlement(
	army_id: StringName,
	transaction_id: StringName,
	result_id: StringName,
	units_by_definition_id: Dictionary
) -> bool:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase) != PHASE_SETTLEMENT_PENDING
		or StringName(army.last_applied_result_id) != &""
		or result_id == &""
		or not _has_valid_composition(
			units_by_definition_id,
			true
		)
	):
		return false
	army.units_by_definition_id = units_by_definition_id.duplicate(true)
	army.last_applied_result_id = result_id
	_armies_by_id[army_id] = army
	return true


func apply_settlement(
	army_id: StringName,
	transaction_id: StringName,
	result_id: StringName,
	survivor_units: Dictionary,
	disposition: StringName
) -> bool:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase) != PHASE_SETTLEMENT_PENDING
		or StringName(army.last_applied_result_id) != &""
		or result_id == &""
		or disposition
			not in [
				DISPOSITION_STATIONED_TARGET,
				DISPOSITION_RETURNING_HOME,
				DISPOSITION_CLOSED_LOST,
			]
		or not _has_valid_composition(survivor_units, true)
		or (
			disposition == DISPOSITION_RETURNING_HOME
			and survivor_units.is_empty()
		)
		or (
			disposition == DISPOSITION_CLOSED_LOST
			and not survivor_units.is_empty()
		)
	):
		return false
	army.units_by_definition_id = survivor_units.duplicate(true)
	army.last_applied_result_id = result_id
	if disposition == DISPOSITION_RETURNING_HOME:
		var previous_source := StringName(army.source_node_id)
		army.source_node_id = StringName(army.target_node_id)
		army.target_node_id = previous_source
		army.progress_milliseconds = 0
		army.phase = PHASE_RETURNING
	else:
		army.phase = PHASE_CLOSED
	_armies_by_id[army_id] = army
	return true


func close_return_to_garrison(
	army_id: StringName,
	transaction_id: StringName
) -> bool:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase) != PHASE_ARRIVED
		or StringName(army.last_applied_result_id) == &""
	):
		return false
	army.units_by_definition_id = {}
	army.phase = PHASE_CLOSED
	_armies_by_id[army_id] = army
	return true


func get_total_active_units(definition_id: StringName) -> int:
	var total := 0
	for army in get_active_armies():
		total += int(
			Dictionary(army.units_by_definition_id).get(definition_id, 0)
		)
	return total


func get_total_stationed_units(definition_id: StringName) -> int:
	var total := 0
	for army in get_armies():
		if (
			StringName(army.phase) == PHASE_CLOSED
			and StringName(army.last_applied_result_id) != &""
		):
			total += int(
				Dictionary(army.units_by_definition_id).get(
					definition_id,
					0
				)
			)
	return total


func get_snapshot() -> Dictionary:
	var armies_by_id: Dictionary = {}
	for army in get_armies():
		armies_by_id[StringName(army.army_id)] = army.duplicate(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"next_army_sequence": _next_army_sequence,
		"armies_by_id": armies_by_id,
	}


func restore_snapshot(
	snapshot: Dictionary,
	allowed_unit_definition_ids: Array,
	enforce_single_active := true
) -> bool:
	var validation := validate_snapshot(
		snapshot,
		allowed_unit_definition_ids,
		enforce_single_active
	)
	if not bool(validation.valid):
		return false
	var candidate: Dictionary = validation.snapshot
	_next_army_sequence = int(candidate.next_army_sequence)
	_armies_by_id = Dictionary(candidate.armies_by_id).duplicate(true)
	return true


static func validate_snapshot(
	snapshot: Dictionary,
	allowed_unit_definition_ids: Array,
	enforce_single_active := true
) -> Dictionary:
	if (
		int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION
		or int(snapshot.get("next_army_sequence", 0)) <= 0
		or not snapshot.get("armies_by_id", null) is Dictionary
	):
		return {"valid": false, "error_id": &"INVALID_ARMY_REGISTRY"}
	var normalized := snapshot.duplicate(true)
	var active_count := 0
	var maximum_army_sequence := 0
	for army_id_value in normalized.armies_by_id:
		var army_value = normalized.armies_by_id[army_id_value]
		if not army_value is Dictionary:
			return {"valid": false, "error_id": &"INVALID_ARMY_STATE"}
		var army: Dictionary = army_value
		var army_id := StringName(army.get("army_id", &""))
		var owner_faction_id := StringName(
			army.get("owner_faction_id", &"")
		)
		var army_sequence := _parse_army_sequence(
			army_id,
			owner_faction_id
		)
		var phase := StringName(army.get("phase", &""))
		var units = army.get("units_by_definition_id", null)
		if (
			army_id == &""
			or army_id != StringName(army_id_value)
			or owner_faction_id == &""
			or army_sequence <= 0
			or StringName(army.get("home_city_id", &"")) == &""
			or StringName(army.get("source_node_id", &"")) == &""
			or StringName(army.get("target_node_id", &"")) == &""
			or StringName(army.source_node_id)
				== StringName(army.target_node_id)
			or StringName(army.get("route_id", &"")) == &""
			or StringName(army.get("transaction_id", &"")) == &""
			or not units is Dictionary
			or not _has_valid_snapshot_composition(
				units,
				allowed_unit_definition_ids,
				phase == PHASE_CLOSED
			)
			or int(army.get("progress_milliseconds", -1)) < 0
			or int(army.get("duration_milliseconds", 0)) <= 0
			or int(army.progress_milliseconds)
				> int(army.duration_milliseconds)
			or phase not in ALL_PHASES
			or (
				StringName(
					army.get("last_applied_result_id", &"")
				) != &""
				and phase
					not in [
						PHASE_RETURNING,
						PHASE_ARRIVED,
						PHASE_CLOSED,
					]
			)
		):
			return {"valid": false, "error_id": &"INVALID_ARMY_STATE"}
		maximum_army_sequence = maxi(
			maximum_army_sequence,
			army_sequence
		)
		if phase in ACTIVE_PHASES:
			active_count += 1
	if enforce_single_active and active_count > 1:
		return {"valid": false, "error_id": &"V5_ACTIVE_ARMY_LIMIT"}
	if int(normalized.next_army_sequence) <= maximum_army_sequence:
		return {"valid": false, "error_id": &"ARMY_SEQUENCE_MISMATCH"}
	return {
		"valid": true,
		"error_id": &"",
		"snapshot": normalized,
	}


static func _has_valid_snapshot_composition(
	units: Dictionary,
	allowed_unit_definition_ids: Array,
	allow_empty: bool
) -> bool:
	if units.is_empty():
		return allow_empty
	for definition_id_value in units:
		var definition_id := StringName(definition_id_value)
		if (
			definition_id == &""
			or definition_id not in allowed_unit_definition_ids
			or int(units[definition_id_value]) <= 0
		):
			return false
	return true


static func _parse_army_sequence(
	army_id: StringName,
	owner_faction_id: StringName
) -> int:
	var prefix := "army.%s." % String(owner_faction_id)
	var text := String(army_id)
	if not text.begins_with(prefix):
		return 0
	var digits := text.trim_prefix(prefix)
	if not digits.is_valid_int():
		return 0
	var sequence := int(digits)
	if sequence <= 0 or text != "%s%06d" % [prefix, sequence]:
		return 0
	return sequence


func _has_valid_composition(
	units: Dictionary,
	allow_empty := false
) -> bool:
	if units.is_empty():
		return allow_empty
	for definition_id in units:
		if StringName(definition_id) == &"" or int(units[definition_id]) <= 0:
			return false
	return true


func _is_allowed_transition(
	from_phase: StringName,
	to_phase: StringName
) -> bool:
	return (
		(from_phase == PHASE_RESERVED and to_phase == PHASE_MARCHING)
		or (from_phase == PHASE_RESERVED and to_phase == PHASE_CLOSED)
		or (
			from_phase == PHASE_ARRIVED
			and to_phase == PHASE_SETTLEMENT_PENDING
		)
		or (
			from_phase == PHASE_SETTLEMENT_PENDING
			and to_phase == PHASE_RETURNING
		)
		or (
			from_phase == PHASE_SETTLEMENT_PENDING
			and to_phase == PHASE_CLOSED
		)
		or (
			from_phase == PHASE_ARRIVED
			and to_phase == PHASE_RETURNING
		)
		or (
			from_phase == PHASE_ARRIVED
			and to_phase == PHASE_CLOSED
		)
	)
