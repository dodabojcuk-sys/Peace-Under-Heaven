class_name CityGovernanceState
extends RefCounted


const SCHEMA_VERSION := 2
const EVENT_IDLE := &"IDLE"
const EVENT_ACTIVE := &"ACTIVE"
const REFUGEE_PENDING := &"PENDING"
const REFUGEE_DEFERRED := &"DEFERRED"
const REFUGEE_WAITING_HOUSING := &"WAITING_HOUSING"
const REFUGEE_SETTLED := &"SETTLED"
const REFUGEE_REJECTED := &"REJECTED"

var health_permille := 1000
var consecutive_food_shortage_days := 0
var consecutive_housing_pressure_days := 0
var pressure_points := 0
var last_applied_day := 0
var next_event_sequence := 1
var active_event := empty_event()
var resolved_event_ids: Dictionary = {}
var refugee_cases_by_id: Dictionary = {}


static func empty_event() -> Dictionary:
	return {
		"event_id": &"", "phase": EVENT_IDLE, "kind": &"",
		"started_day": 0, "stage_started_day": 0, "stage_index": 0,
		"target_kind": &"", "target_id": &"",
		"consequence_applied": false, "cause": &"",
	}


func initialize_fresh(rules: CityGovernanceRules) -> bool:
	if rules == null or not rules.is_valid():
		return false
	health_permille = rules.initial_health_permille
	consecutive_food_shortage_days = 0
	consecutive_housing_pressure_days = 0
	pressure_points = 0
	last_applied_day = 0
	next_event_sequence = 1
	active_event = empty_event()
	resolved_event_ids = {}
	refugee_cases_by_id = {}
	return true


func apply_day(day: int, food_shortfall: int, housing_shortfall: int, vulnerable_people: int, resident_sick: int, medical_capacity_for_sick: int, security: int, rules: CityGovernanceRules) -> Dictionary:
	if day <= last_applied_day or food_shortfall < 0 or housing_shortfall < 0 or vulnerable_people < 0 or resident_sick < 0 or medical_capacity_for_sick < 0 or rules == null or not rules.is_valid():
		return {}
	consecutive_food_shortage_days = consecutive_food_shortage_days + 1 if food_shortfall > 0 else 0
	consecutive_housing_pressure_days = consecutive_housing_pressure_days + 1 if housing_shortfall > 0 else 0
	var recovered := mini(resident_sick, medical_capacity_for_sick)
	var new_cases := 0
	if consecutive_food_shortage_days >= rules.disease_trigger_days or consecutive_housing_pressure_days >= rules.disease_trigger_days:
		new_cases = mini(rules.disease_cases_per_day, maxi(vulnerable_people - resident_sick, 0))
	var health_delta := rules.passive_health_recovery_permille
	if food_shortfall > 0:
		health_delta -= rules.shortage_health_loss_permille
	if housing_shortfall > 0:
		health_delta -= rules.housing_health_loss_permille
	health_permille = clampi(health_permille + health_delta, 250, 1000)
	var under_pressure := food_shortfall > 0 or housing_shortfall > 0 or security < rules.disorder_threshold
	pressure_points = mini(100, pressure_points + rules.pressure_per_shortage_day) if under_pressure else maxi(0, pressure_points - rules.pressure_recovery_per_stable_day)
	var resource_pressure := food_shortfall > 0 or housing_shortfall > 0
	var security_delta := -2 if resource_pressure else (1 if pressure_points == 0 else 0)
	var event_changed := _advance_event(day, rules, food_shortfall > 0, housing_shortfall > 0)
	_register_due_refugees(day, rules)
	last_applied_day = day
	return {
		"new_cases": new_cases, "recovered": recovered,
		"security_delta": security_delta, "event_changed": event_changed,
		"event_needs_consequence": StringName(active_event.phase) == EVENT_ACTIVE and not bool(active_event.consequence_applied),
	}


func _advance_event(day: int, rules: CityGovernanceRules, food_pressure: bool, housing_pressure: bool) -> bool:
	var desired_stage := 0
	if pressure_points >= rules.pressure_unrest_threshold:
		desired_stage = 3
	elif pressure_points >= rules.pressure_bandit_threshold:
		desired_stage = 2
	elif pressure_points >= rules.pressure_event_threshold:
		desired_stage = 1
	if desired_stage == 0:
		return false
	var cause := &"FOOD" if food_pressure else (&"HOUSING" if housing_pressure else &"LOW_SECURITY")
	if StringName(active_event.phase) == EVENT_IDLE:
		active_event = _make_event(day, desired_stage, cause)
		next_event_sequence += 1
		return true
	if desired_stage > int(active_event.stage_index) and day - int(active_event.stage_started_day) >= rules.event_escalation_days:
		active_event.kind = _event_kind(desired_stage)
		active_event.stage_index = desired_stage
		active_event.stage_started_day = day
		active_event.target_kind = _event_target_kind(desired_stage)
		active_event.target_id = _event_target_id(desired_stage)
		active_event.consequence_applied = false
		return true
	return false


func _make_event(day: int, stage: int, cause: StringName) -> Dictionary:
	return {
		"event_id": StringName("governance.blackstone.%06d" % next_event_sequence),
		"phase": EVENT_ACTIVE, "kind": _event_kind(stage),
		"started_day": day, "stage_started_day": day, "stage_index": stage,
		"target_kind": _event_target_kind(stage), "target_id": _event_target_id(stage),
		"consequence_applied": false, "cause": cause,
	}


static func _event_kind(stage: int) -> StringName:
	return [&"", &"PETTY_THEFT", &"BANDIT_DISRUPTION", &"LOCAL_UNREST"][clampi(stage, 0, 3)]


static func _event_target_kind(stage: int) -> StringName:
	return &"INVENTORY" if stage == 1 else (&"PRODUCTION" if stage == 2 else &"CITY_WORK")


static func _event_target_id(stage: int) -> StringName:
	return &"food" if stage == 1 else (&"regular_city_production" if stage == 2 else &"regular_city_workforce")


func mark_active_event_consequence_applied() -> bool:
	if StringName(active_event.phase) != EVENT_ACTIVE or bool(active_event.consequence_applied):
		return false
	active_event.consequence_applied = true
	return true


func resolve_active_event(pressure_relief: int) -> Dictionary:
	if StringName(active_event.phase) != EVENT_ACTIVE or pressure_relief <= 0:
		return {}
	var resolved := active_event.duplicate(true)
	resolved_event_ids[StringName(active_event.event_id)] = true
	active_event = empty_event()
	pressure_points = maxi(pressure_points - pressure_relief, 0)
	return resolved


func _register_due_refugees(day: int, rules: CityGovernanceRules) -> void:
	for source_value in rules.refugee_sources:
		var source: Dictionary = source_value
		var case_id := StringName(source.case_id)
		if int(source.arrival_day) > day or refugee_cases_by_id.has(case_id):
			continue
		refugee_cases_by_id[case_id] = {
			"case_id": case_id, "source_event_id": StringName(source.source_event_id),
			"display_name": str(source.display_name), "arrival_day": int(source.arrival_day),
			"phase": REFUGEE_PENDING, "count": int(source.count),
			"medical_burden": int(source.medical_burden),
			"accepted_day": 0, "settled_day": 0,
		}


func set_refugee_phase(case_id: StringName, phase: StringName, day: int) -> bool:
	if not refugee_cases_by_id.has(case_id) or day <= 0:
		return false
	var value: Dictionary = Dictionary(refugee_cases_by_id[case_id])
	var current := StringName(value.phase)
	if phase == REFUGEE_DEFERRED and current in [REFUGEE_PENDING, REFUGEE_DEFERRED]:
		value.phase = phase
	elif phase == REFUGEE_REJECTED and current in [REFUGEE_PENDING, REFUGEE_DEFERRED]:
		value.phase = phase
	elif phase == REFUGEE_WAITING_HOUSING and current in [REFUGEE_PENDING, REFUGEE_DEFERRED]:
		value.phase = phase
		value.accepted_day = day
	elif phase == REFUGEE_SETTLED and current == REFUGEE_WAITING_HOUSING:
		value.phase = phase
		value.settled_day = day
		value.medical_burden = 0
	else:
		return false
	refugee_cases_by_id[case_id] = value
	return true


func apply_refugee_medical_care(capacity: int) -> int:
	if capacity <= 0:
		return 0
	var recovered := 0
	var ids := refugee_cases_by_id.keys()
	ids.sort()
	for case_id_value in ids:
		if recovered >= capacity:
			break
		var value: Dictionary = Dictionary(refugee_cases_by_id[case_id_value])
		if StringName(value.phase) not in [REFUGEE_WAITING_HOUSING, REFUGEE_SETTLED]:
			continue
		var treated := mini(int(value.medical_burden), capacity - recovered)
		value.medical_burden = int(value.medical_burden) - treated
		refugee_cases_by_id[case_id_value] = value
		recovered += treated
	return recovered


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "health_permille": health_permille,
		"consecutive_food_shortage_days": consecutive_food_shortage_days,
		"consecutive_housing_pressure_days": consecutive_housing_pressure_days,
		"pressure_points": pressure_points, "last_applied_day": last_applied_day,
		"next_event_sequence": next_event_sequence, "active_event": active_event.duplicate(true),
		"resolved_event_ids": resolved_event_ids.duplicate(true),
		"refugee_cases_by_id": refugee_cases_by_id.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.get("valid", false)):
		return false
	var value: Dictionary = validation.snapshot
	health_permille = int(value.health_permille)
	consecutive_food_shortage_days = int(value.consecutive_food_shortage_days)
	consecutive_housing_pressure_days = int(value.consecutive_housing_pressure_days)
	pressure_points = int(value.pressure_points)
	last_applied_day = int(value.last_applied_day)
	next_event_sequence = int(value.next_event_sequence)
	active_event = Dictionary(value.active_event).duplicate(true)
	resolved_event_ids = Dictionary(value.resolved_event_ids).duplicate(true)
	refugee_cases_by_id = Dictionary(value.refugee_cases_by_id).duplicate(true)
	return true


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	var keys := ["schema_version", "health_permille", "consecutive_food_shortage_days", "consecutive_housing_pressure_days", "pressure_points", "last_applied_day", "next_event_sequence", "active_event", "resolved_event_ids", "refugee_cases_by_id"]
	if snapshot.size() != keys.size():
		return {"valid": false}
	for key in keys:
		if not snapshot.has(key):
			return {"valid": false}
	for key in ["schema_version", "health_permille", "consecutive_food_shortage_days", "consecutive_housing_pressure_days", "pressure_points", "last_applied_day", "next_event_sequence"]:
		if typeof(snapshot.get(key)) != TYPE_INT:
			return {"valid": false}
	if int(snapshot.schema_version) != SCHEMA_VERSION or int(snapshot.health_permille) < 250 or int(snapshot.health_permille) > 1000 or int(snapshot.consecutive_food_shortage_days) < 0 or int(snapshot.consecutive_housing_pressure_days) < 0 or int(snapshot.pressure_points) < 0 or int(snapshot.pressure_points) > 100 or int(snapshot.last_applied_day) < 0 or int(snapshot.next_event_sequence) <= 0 or typeof(snapshot.active_event) != TYPE_DICTIONARY or typeof(snapshot.resolved_event_ids) != TYPE_DICTIONARY or typeof(snapshot.refugee_cases_by_id) != TYPE_DICTIONARY:
		return {"valid": false}
	var event: Dictionary = snapshot.active_event
	if event.size() != empty_event().size():
		return {"valid": false}
	for key in empty_event():
		if not event.has(key):
			return {"valid": false}
	for key in ["event_id", "phase", "kind", "target_kind", "target_id", "cause"]:
		if typeof(event.get(key)) != TYPE_STRING_NAME:
			return {"valid": false}
	for key in ["started_day", "stage_started_day", "stage_index"]:
		if typeof(event.get(key)) != TYPE_INT:
			return {"valid": false}
	if typeof(event.get("consequence_applied")) != TYPE_BOOL:
		return {"valid": false}
	var phase := StringName(event.get("phase", &""))
	if phase not in [EVENT_IDLE, EVENT_ACTIVE] or (phase == EVENT_IDLE and event != empty_event()):
		return {"valid": false}
	if phase == EVENT_ACTIVE and (StringName(event.event_id) == &"" or int(event.stage_index) not in [1, 2, 3] or StringName(event.kind) != _event_kind(int(event.stage_index)) or int(event.started_day) <= 0 or int(event.stage_started_day) < int(event.started_day) or int(event.stage_started_day) > int(snapshot.last_applied_day) or typeof(event.consequence_applied) != TYPE_BOOL):
		return {"valid": false}
	for event_id_value in snapshot.resolved_event_ids:
		if typeof(event_id_value) != TYPE_STRING_NAME or StringName(event_id_value) == &"" or typeof(snapshot.resolved_event_ids[event_id_value]) != TYPE_BOOL or not bool(snapshot.resolved_event_ids[event_id_value]):
			return {"valid": false}
	if phase == EVENT_ACTIVE and snapshot.resolved_event_ids.has(StringName(event.event_id)):
		return {"valid": false}
	for case_id_value in snapshot.refugee_cases_by_id:
		if typeof(case_id_value) != TYPE_STRING_NAME:
			return {"valid": false}
		var case_value: Dictionary = Dictionary(snapshot.refugee_cases_by_id[case_id_value])
		var case_keys := ["case_id", "source_event_id", "display_name", "arrival_day", "phase", "count", "medical_burden", "accepted_day", "settled_day"]
		if case_value.size() != case_keys.size():
			return {"valid": false}
		for key in case_keys:
			if not case_value.has(key):
				return {"valid": false}
		for key in ["case_id", "source_event_id", "phase"]:
			if typeof(case_value.get(key)) != TYPE_STRING_NAME:
				return {"valid": false}
		if typeof(case_value.display_name) != TYPE_STRING:
			return {"valid": false}
		for key in ["arrival_day", "count", "medical_burden", "accepted_day", "settled_day"]:
			if typeof(case_value.get(key)) != TYPE_INT or int(case_value.get(key)) < 0:
				return {"valid": false}
		var refugee_phase := StringName(case_value.phase)
		if StringName(case_value.case_id) != StringName(case_id_value) or StringName(case_value.source_event_id) == &"" or refugee_phase not in [REFUGEE_PENDING, REFUGEE_DEFERRED, REFUGEE_WAITING_HOUSING, REFUGEE_SETTLED, REFUGEE_REJECTED] or int(case_value.arrival_day) <= 0 or int(case_value.count) <= 0 or int(case_value.medical_burden) > int(case_value.count):
			return {"valid": false}
		if refugee_phase in [REFUGEE_PENDING, REFUGEE_DEFERRED, REFUGEE_REJECTED] and (int(case_value.accepted_day) != 0 or int(case_value.settled_day) != 0):
			return {"valid": false}
		if refugee_phase == REFUGEE_WAITING_HOUSING and (int(case_value.accepted_day) <= 0 or int(case_value.settled_day) != 0):
			return {"valid": false}
		if refugee_phase == REFUGEE_SETTLED and (int(case_value.accepted_day) <= 0 or int(case_value.settled_day) < int(case_value.accepted_day) or int(case_value.medical_burden) != 0):
			return {"valid": false}
	return {"valid": true, "snapshot": snapshot.duplicate(true)}
