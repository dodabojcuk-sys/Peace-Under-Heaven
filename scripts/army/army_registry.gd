class_name ArmyRegistry
extends RefCounted


const SCHEMA_VERSION := 3
const MAX_EXACT_PERSISTED_SEQUENCE := 9007199254740991
const PHASE_RESERVED := &"RESERVED"
const PHASE_MARCHING := &"MARCHING"
const PHASE_ARRIVED := &"ARRIVED"
const PHASE_RETURNING := &"RETURNING"
const PHASE_SETTLEMENT_PENDING := &"SETTLEMENT_PENDING"
const PHASE_BLOCKED := &"BLOCKED"
const PHASE_STATIONED := &"STATIONED"
const PHASE_SIEGING := &"SIEGING"
const PHASE_RETREATING := &"RETREATING"
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
	PHASE_BLOCKED,
	PHASE_SIEGING,
	PHASE_RETREATING,
]
const ALL_PHASES := [
	PHASE_RESERVED,
	PHASE_MARCHING,
	PHASE_ARRIVED,
	PHASE_RETURNING,
	PHASE_SETTLEMENT_PENDING,
	PHASE_BLOCKED,
	PHASE_STATIONED,
	PHASE_SIEGING,
	PHASE_RETREATING,
	PHASE_CLOSED,
]

var _next_army_sequence := 1
var _next_macro_order_sequence := 1
var _armies_by_id: Dictionary = {}


func has_active_army() -> bool:
	return not get_active_armies().is_empty()


func can_allocate_stable_id() -> bool:
	return _next_army_sequence < MAX_EXACT_PERSISTED_SEQUENCE


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
		or not can_allocate_stable_id()
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
		if StringName(army.phase) == PHASE_STATIONED:
			total += int(Dictionary(army.units_by_definition_id).get(
				definition_id,
				0
			))
		elif (
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
		"next_macro_order_sequence": _next_macro_order_sequence,
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
	_next_macro_order_sequence = int(candidate.next_macro_order_sequence)
	_armies_by_id = Dictionary(candidate.armies_by_id).duplicate(true)
	return true


static func validate_snapshot(
	snapshot: Dictionary,
	allowed_unit_definition_ids: Array,
	enforce_single_active := true
) -> Dictionary:
	var source_schema_version := int(snapshot.get("schema_version", 0))
	if (
		source_schema_version not in [1, 2, SCHEMA_VERSION]
		or typeof(snapshot.get("next_army_sequence", null)) != TYPE_INT
		or int(snapshot.get("next_army_sequence", 0)) <= 0
		or int(snapshot.get("next_army_sequence", 0))
			> MAX_EXACT_PERSISTED_SEQUENCE
		or not snapshot.get("armies_by_id", null) is Dictionary
		or (
			source_schema_version == SCHEMA_VERSION
			and typeof(snapshot.get("next_macro_order_sequence", null)) != TYPE_INT
		)
	):
		return {"valid": false, "error_id": &"INVALID_ARMY_REGISTRY"}
	var normalized := snapshot.duplicate(true)
	if source_schema_version in [1, 2]:
		normalized["schema_version"] = SCHEMA_VERSION
		if source_schema_version == 1:
			normalized["next_macro_order_sequence"] = 1
	if (
		int(normalized.next_macro_order_sequence) <= 0
		or int(normalized.next_macro_order_sequence)
			> MAX_EXACT_PERSISTED_SEQUENCE
	):
		return {"valid": false, "error_id": &"INVALID_MACRO_ORDER_SEQUENCE"}
	var active_count := 0
	var maximum_army_sequence := 0
	var maximum_macro_order_sequence := 0
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
		var macro_validation := _validate_macro_march(army)
		if not bool(macro_validation.valid):
			return macro_validation
		if not Dictionary(army.get("macro_march", {})).is_empty():
			maximum_macro_order_sequence = maxi(
				maximum_macro_order_sequence,
				_parse_macro_order_sequence(StringName(
					Dictionary(army.macro_march).order_id
				))
			)
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
	if int(normalized.next_macro_order_sequence) <= maximum_macro_order_sequence:
		return {"valid": false, "error_id": &"MACRO_ORDER_SEQUENCE_MISMATCH"}
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


func create_macro_march(
	owner_faction_id: StringName,
	home_city_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array,
	units_by_definition_id: Dictionary,
	formation_snapshots: Array,
	food_cost: int,
	duration_milliseconds: int
) -> Dictionary:
	if (
		has_active_army()
		or owner_faction_id == &""
		or home_city_id == &""
		or source_point_id == &""
		or target_point_id == &""
		or source_point_id == target_point_id
		or route_id == &""
		or route_world_points.size() < 2
		or food_cost <= 0
		or duration_milliseconds <= 0
		or not _has_valid_composition(units_by_definition_id)
		or not _has_valid_macro_formations(formation_snapshots, units_by_definition_id)
		or not can_allocate_stable_id()
		or _next_macro_order_sequence >= MAX_EXACT_PERSISTED_SEQUENCE
	):
		return {}
	var army_id := StringName("army.%s.%06d" % [
		String(owner_faction_id), _next_army_sequence,
	])
	var order_id := _allocate_macro_order_id()
	_next_army_sequence += 1
	var macro_march := _build_macro_march(
		order_id, source_point_id, target_point_id, route_id, route_world_points,
		formation_snapshots, food_cost, duration_milliseconds
	)
	var army := {
		"army_id": army_id,
		"owner_faction_id": owner_faction_id,
		"home_city_id": home_city_id,
		"source_node_id": source_point_id,
		"target_node_id": target_point_id,
		"route_id": route_id,
		"units_by_definition_id": units_by_definition_id.duplicate(true),
		"progress_milliseconds": 0,
		"duration_milliseconds": duration_milliseconds,
		"phase": PHASE_MARCHING,
		"transaction_id": order_id,
		"last_applied_result_id": &"",
		"macro_march": macro_march,
	}
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func issue_stationed_macro_march(
	army_id: StringName,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array,
	food_cost: int,
	duration_milliseconds: int
) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	if (
		army.is_empty()
		or StringName(army.phase) != PHASE_STATIONED
		or has_active_army()
		or target_point_id == &""
		or target_point_id == StringName(army.target_node_id)
		or route_id == &""
		or route_world_points.size() < 2
		or food_cost <= 0
		or duration_milliseconds <= 0
		or _next_macro_order_sequence >= MAX_EXACT_PERSISTED_SEQUENCE
	):
		return {}
	var prior_macro: Dictionary = army.get("macro_march", {})
	if prior_macro.is_empty():
		return {}
	var source_point_id := StringName(army.target_node_id)
	var order_id := _allocate_macro_order_id()
	army.source_node_id = source_point_id
	army.target_node_id = target_point_id
	army.route_id = route_id
	army.progress_milliseconds = 0
	army.duration_milliseconds = duration_milliseconds
	army.transaction_id = order_id
	army.phase = PHASE_MARCHING
	army.macro_march = _build_macro_march(
		order_id, source_point_id, target_point_id, route_id, route_world_points,
		Array(prior_macro.formation_snapshots), food_cost, duration_milliseconds
	)
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func advance_macro_march(
	army_id: StringName,
	order_id: StringName,
	expected_progress_milliseconds: int,
	delta_milliseconds: int
) -> Dictionary:
	if delta_milliseconds <= 0 or expected_progress_milliseconds < 0:
		return {}
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if (
		army.is_empty()
		or macro.is_empty()
		or StringName(army.phase) not in [PHASE_MARCHING, PHASE_RETREATING]
		or StringName(macro.order_id) != order_id
		or int(macro.progress_millis) != expected_progress_milliseconds
	):
		return {}
	var next_progress := mini(
		expected_progress_milliseconds + delta_milliseconds,
		int(macro.total_millis)
	)
	macro.progress_millis = next_progress
	army.progress_milliseconds = next_progress
	var arrived := next_progress == int(macro.total_millis)
	if arrived:
		macro.phase = PHASE_STATIONED
		army.phase = PHASE_STATIONED
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return {"success": true, "arrived": arrived, "army": army.duplicate(true)}


func begin_macro_siege(army_id: StringName, order_id: StringName) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if army.is_empty() or macro.is_empty() or StringName(army.phase) != PHASE_STATIONED or StringName(macro.order_id) != order_id:
		return {}
	army.phase = PHASE_SIEGING
	macro.phase = PHASE_SIEGING
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func complete_macro_siege(army_id: StringName, order_id: StringName) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if army.is_empty() or macro.is_empty() or StringName(army.phase) != PHASE_SIEGING or StringName(macro.order_id) != order_id:
		return {}
	army.phase = PHASE_STATIONED
	macro.phase = PHASE_STATIONED
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func replace_macro_composition(army_id: StringName, order_id: StringName, surviving_count: int) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if army.is_empty() or macro.is_empty() or StringName(macro.order_id) != order_id or surviving_count < 0:
		return {}
	var units: Dictionary = army.units_by_definition_id
	if units.size() != 1:
		return {}
	var current_total := 0
	for formation_value in Array(macro.formation_snapshots):
		current_total += int(Dictionary(formation_value).member_count)
	if surviving_count > current_total:
		return {}
	var definition_id = units.keys()[0]
	units[definition_id] = surviving_count
	army.units_by_definition_id = units
	var formations: Array = macro.formation_snapshots
	var losses_remaining := current_total - surviving_count
	# Deterministic rear-first attrition preserves every formation identity and
	# never reallocates survivors into an earlier formation.
	for index in range(formations.size() - 1, -1, -1):
		var formation: Dictionary = formations[index]
		var loss := mini(losses_remaining, int(formation.member_count))
		formation.member_count = int(formation.member_count) - loss
		formations[index] = formation
		losses_remaining -= loss
	macro.formation_snapshots = formations
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func begin_macro_retreat(army_id: StringName, order_id: StringName) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if army.is_empty() or macro.is_empty() or StringName(army.phase) != PHASE_SIEGING or StringName(macro.order_id) != order_id:
		return {}
	var points: Array = Array(macro.route_world_points).duplicate()
	points.reverse()
	var old_source := StringName(macro.source_point_id)
	macro.source_point_id = StringName(macro.target_point_id)
	macro.target_point_id = old_source
	macro.route_world_points = points
	macro.progress_millis = 0
	macro.phase = PHASE_RETREATING
	army.source_node_id = StringName(macro.source_point_id)
	army.target_node_id = StringName(macro.target_point_id)
	army.progress_milliseconds = 0
	army.phase = PHASE_RETREATING
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func block_macro_march(
	army_id: StringName,
	order_id: StringName,
	segment_index: int,
	progress_before_segment_millis: int,
	temporary_station_point: StringName
) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if (
		army.is_empty()
		or macro.is_empty()
		or StringName(army.phase) != PHASE_MARCHING
		or StringName(macro.order_id) != order_id
		or segment_index < 1
		or temporary_station_point == &""
		or progress_before_segment_millis < int(macro.progress_millis)
		or progress_before_segment_millis > int(macro.total_millis)
	):
		return {}
	macro.progress_millis = progress_before_segment_millis
	macro.blocked_segment_index = segment_index
	macro.temporary_station_point = temporary_station_point
	macro.phase = PHASE_BLOCKED
	army.progress_milliseconds = progress_before_segment_millis
	army.phase = PHASE_BLOCKED
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func resume_blocked_macro_march(
	army_id: StringName,
	order_id: StringName
) -> Dictionary:
	var army: Dictionary = _armies_by_id.get(army_id, {})
	var macro: Dictionary = army.get("macro_march", {})
	if (
		army.is_empty()
		or macro.is_empty()
		or StringName(army.phase) != PHASE_BLOCKED
		or StringName(macro.order_id) != order_id
	):
		return {}
	macro.blocked_segment_index = -1
	macro.temporary_station_point = &""
	macro.phase = PHASE_MARCHING
	army.phase = PHASE_MARCHING
	army.macro_march = macro
	_armies_by_id[army_id] = army
	return army.duplicate(true)


func _allocate_macro_order_id() -> StringName:
	var result := StringName("macro.order.%06d" % _next_macro_order_sequence)
	_next_macro_order_sequence += 1
	return result


func _build_macro_march(
	order_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array,
	formation_snapshots: Array,
	food_cost: int,
	duration_milliseconds: int
) -> Dictionary:
	return {
		"order_id": order_id,
		"source_point_id": source_point_id,
		"target_point_id": target_point_id,
		"route_id": route_id,
		"route_world_points": route_world_points.duplicate(),
		"formation_snapshots": formation_snapshots.duplicate(true),
		"food_cost": food_cost,
		"progress_millis": 0,
		"total_millis": duration_milliseconds,
		"blocked_segment_index": -1,
		"temporary_station_point": &"",
		"phase": PHASE_MARCHING,
	}


static func _has_valid_macro_formations(
	formation_snapshots: Array,
	units_by_definition_id: Dictionary
) -> bool:
	if formation_snapshots.is_empty():
		return false
	var total := 0
	var seen: Dictionary = {}
	for value in formation_snapshots:
		if not value is Dictionary:
			return false
		var formation: Dictionary = value
		var formation_id := StringName(formation.get("formation_id", &""))
		if (
			formation_id == &""
			or seen.has(formation_id)
			or StringName(formation.get("definition_id", &"")) == &""
			or typeof(formation.get("display_name", null)) != TYPE_STRING
			or typeof(formation.get("member_count", null)) != TYPE_INT
			or typeof(formation.get("max_members", null)) != TYPE_INT
			or int(formation.member_count) < 0
			or int(formation.max_members) < int(formation.member_count)
		):
			return false
		seen[formation_id] = true
		total += int(formation.member_count)
	var composition_total := 0
	for count in units_by_definition_id.values():
		composition_total += int(count)
	return total == composition_total


static func _validate_macro_march(army: Dictionary) -> Dictionary:
	var has_macro := army.has("macro_march")
	if not has_macro:
		return {"valid": true}
	var macro_value = army.get("macro_march", null)
	if not macro_value is Dictionary:
		return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	var macro: Dictionary = macro_value
	var expected_keys := [
		"order_id", "source_point_id", "target_point_id", "route_id",
		"route_world_points", "formation_snapshots", "food_cost",
		"progress_millis", "total_millis", "blocked_segment_index",
		"temporary_station_point", "phase",
	]
	if macro.size() != expected_keys.size():
		return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	for key in expected_keys:
		if not macro.has(key):
			return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	if (
		_parse_macro_order_sequence(StringName(macro.order_id)) <= 0
		or StringName(army.transaction_id) != StringName(macro.order_id)
		or StringName(army.source_node_id) != StringName(macro.source_point_id)
		or StringName(army.target_node_id) != StringName(macro.target_point_id)
		or StringName(army.route_id) != StringName(macro.route_id)
		or not macro.route_world_points is Array
		or Array(macro.route_world_points).size() < 2
		or typeof(macro.food_cost) != TYPE_INT
		or int(macro.food_cost) <= 0
		or typeof(macro.progress_millis) != TYPE_INT
		or typeof(macro.total_millis) != TYPE_INT
		or int(macro.progress_millis) < 0
		or int(macro.total_millis) <= 0
		or int(macro.progress_millis) > int(macro.total_millis)
		or int(army.progress_milliseconds) != int(macro.progress_millis)
		or int(army.duration_milliseconds) != int(macro.total_millis)
		or typeof(macro.blocked_segment_index) != TYPE_INT
		or typeof(macro.temporary_station_point) != TYPE_STRING_NAME
		or StringName(macro.phase) not in [PHASE_MARCHING, PHASE_BLOCKED, PHASE_STATIONED, PHASE_SIEGING, PHASE_RETREATING]
		or StringName(army.phase) != StringName(macro.phase)
		or not _has_valid_macro_formations(
			Array(macro.formation_snapshots), Dictionary(army.units_by_definition_id)
		)
	):
		return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	for point in macro.route_world_points:
		if typeof(point) != TYPE_VECTOR2I:
			return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	if (
		StringName(macro.phase) == PHASE_BLOCKED
		and (int(macro.blocked_segment_index) < 1 or StringName(macro.temporary_station_point) == &"")
	):
		return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	if (
		StringName(macro.phase) != PHASE_BLOCKED
		and (int(macro.blocked_segment_index) != -1 or StringName(macro.temporary_station_point) != &"")
	):
		return {"valid": false, "error_id": &"INVALID_MACRO_MARCH"}
	return {"valid": true}


static func _parse_macro_order_sequence(order_id: StringName) -> int:
	var text := String(order_id)
	var prefix := "macro.order."
	if not text.begins_with(prefix):
		return 0
	var digits := text.trim_prefix(prefix)
	if not digits.is_valid_int():
		return 0
	var sequence := int(digits)
	return sequence if sequence > 0 and text == "%s%06d" % [prefix, sequence] else 0
