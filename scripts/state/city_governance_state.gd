class_name CityGovernanceState
extends RefCounted


const SCHEMA_VERSION := 1
const EVENT_IDLE := &"IDLE"
const EVENT_ACTIVE := &"ACTIVE"

var health_permille := 1000
var diseased_count := 0
var consecutive_food_shortage_days := 0
var consecutive_housing_pressure_days := 0
var last_applied_day := 0
var next_event_sequence := 1
var active_event := empty_event()
var resolved_event_ids: Dictionary = {}


static func empty_event() -> Dictionary:
	return {"event_id": &"", "phase": EVENT_IDLE, "kind": &"", "started_day": 0}


func initialize_fresh(rules: CityGovernanceRules) -> bool:
	if rules == null or not rules.is_valid():
		return false
	health_permille = rules.initial_health_permille
	diseased_count = 0
	consecutive_food_shortage_days = 0
	consecutive_housing_pressure_days = 0
	last_applied_day = 0
	next_event_sequence = 1
	active_event = empty_event()
	resolved_event_ids = {}
	return true


func apply_day(day: int, food_shortfall: int, housing_shortfall: int, vulnerable_people: int, medical_capacity: int, medical_workers: int, security: int, rules: CityGovernanceRules) -> Dictionary:
	if day <= last_applied_day or food_shortfall < 0 or housing_shortfall < 0 or vulnerable_people < 0 or medical_capacity < 0 or medical_workers < 0 or rules == null or not rules.is_valid():
		return {}
	consecutive_food_shortage_days = consecutive_food_shortage_days + 1 if food_shortfall > 0 else 0
	consecutive_housing_pressure_days = consecutive_housing_pressure_days + 1 if housing_shortfall > 0 else 0
	var care_rate := mini(medical_capacity, medical_workers)
	var recovered := mini(diseased_count, care_rate)
	diseased_count -= recovered
	var new_cases := 0
	if consecutive_food_shortage_days >= rules.disease_trigger_days or consecutive_housing_pressure_days >= rules.disease_trigger_days:
		new_cases = mini(rules.disease_cases_per_day, maxi(vulnerable_people - diseased_count, 0))
		diseased_count += new_cases
	var health_delta := rules.passive_health_recovery_permille
	if food_shortfall > 0:
		health_delta -= rules.shortage_health_loss_permille
	if housing_shortfall > 0:
		health_delta -= rules.housing_health_loss_permille
	health_permille = clampi(health_permille + health_delta, 250, 1000)
	var security_delta := 0
	if food_shortfall > 0 or housing_shortfall > 0:
		security_delta = -2
	elif medical_workers >= rules.medical_workers_for_full_care:
		security_delta = 1
	if StringName(active_event.phase) == EVENT_IDLE and security + security_delta <= rules.disorder_threshold:
		active_event = {
			"event_id": StringName("governance.blackstone.%06d" % next_event_sequence),
			"phase": EVENT_ACTIVE,
			"kind": &"PETTY_THEFT",
			"started_day": day,
		}
		next_event_sequence += 1
	last_applied_day = day
	return {"new_cases": new_cases, "recovered": recovered, "security_delta": security_delta}


func resolve_active_event() -> Dictionary:
	if StringName(active_event.phase) != EVENT_ACTIVE:
		return {}
	var resolved := active_event.duplicate(true)
	resolved_event_ids[StringName(active_event.event_id)] = true
	active_event = empty_event()
	return resolved


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"health_permille": health_permille,
		"diseased_count": diseased_count,
		"consecutive_food_shortage_days": consecutive_food_shortage_days,
		"consecutive_housing_pressure_days": consecutive_housing_pressure_days,
		"last_applied_day": last_applied_day,
		"next_event_sequence": next_event_sequence,
		"active_event": active_event.duplicate(true),
		"resolved_event_ids": resolved_event_ids.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.get("valid", false)):
		return false
	var value: Dictionary = validation.snapshot
	health_permille = int(value.health_permille)
	diseased_count = int(value.diseased_count)
	consecutive_food_shortage_days = int(value.consecutive_food_shortage_days)
	consecutive_housing_pressure_days = int(value.consecutive_housing_pressure_days)
	last_applied_day = int(value.last_applied_day)
	next_event_sequence = int(value.next_event_sequence)
	active_event = Dictionary(value.active_event).duplicate(true)
	resolved_event_ids = Dictionary(value.resolved_event_ids).duplicate(true)
	return true


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	var keys := ["schema_version", "health_permille", "diseased_count", "consecutive_food_shortage_days", "consecutive_housing_pressure_days", "last_applied_day", "next_event_sequence", "active_event", "resolved_event_ids"]
	if snapshot.size() != keys.size():
		return {"valid": false}
	for key in keys:
		if not snapshot.has(key):
			return {"valid": false}
	for key in ["schema_version", "health_permille", "diseased_count", "consecutive_food_shortage_days", "consecutive_housing_pressure_days", "last_applied_day", "next_event_sequence"]:
		if typeof(snapshot.get(key)) != TYPE_INT:
			return {"valid": false}
	if int(snapshot.schema_version) != SCHEMA_VERSION or int(snapshot.health_permille) < 250 or int(snapshot.health_permille) > 1000 or int(snapshot.diseased_count) < 0 or int(snapshot.consecutive_food_shortage_days) < 0 or int(snapshot.consecutive_housing_pressure_days) < 0 or int(snapshot.last_applied_day) < 0 or int(snapshot.next_event_sequence) <= 0 or typeof(snapshot.active_event) != TYPE_DICTIONARY or typeof(snapshot.resolved_event_ids) != TYPE_DICTIONARY:
		return {"valid": false}
	var event: Dictionary = snapshot.active_event
	if event.size() != 4 or not event.has("event_id") or not event.has("phase") or not event.has("kind") or not event.has("started_day") or typeof(event.event_id) != TYPE_STRING_NAME or typeof(event.phase) != TYPE_STRING_NAME or typeof(event.kind) != TYPE_STRING_NAME or typeof(event.started_day) != TYPE_INT:
		return {"valid": false}
	var phase := StringName(event.phase)
	if phase not in [EVENT_IDLE, EVENT_ACTIVE] or (phase == EVENT_IDLE and (StringName(event.event_id) != &"" or StringName(event.kind) != &"" or int(event.started_day) != 0)) or (phase == EVENT_ACTIVE and (StringName(event.event_id) == &"" or StringName(event.kind) != &"PETTY_THEFT" or int(event.started_day) <= 0 or int(event.started_day) > int(snapshot.last_applied_day))):
		return {"valid": false}
	for event_id_value in snapshot.resolved_event_ids:
		if typeof(event_id_value) != TYPE_STRING_NAME or StringName(event_id_value) == &"" or typeof(snapshot.resolved_event_ids[event_id_value]) != TYPE_BOOL or not bool(snapshot.resolved_event_ids[event_id_value]):
			return {"valid": false}
	if phase == EVENT_ACTIVE and snapshot.resolved_event_ids.has(StringName(event.event_id)):
		return {"valid": false}
	return {"valid": true, "snapshot": snapshot.duplicate(true)}
