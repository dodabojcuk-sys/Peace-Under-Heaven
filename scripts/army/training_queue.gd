class_name TrainingQueue
extends RefCounted


const SCHEMA_VERSION := 1
const PHASE_QUEUED := &"QUEUED"
const PHASE_COMPLETED := &"COMPLETED"
const MAX_EXACT_PERSISTED_SEQUENCE := 9007199254740991

var city_id: StringName
var _next_order_sequence := 1
var _last_order_day := 0
var _orders_by_id: Dictionary = {}
var _active_order_id: StringName = &""


func _init(city_id_value := &"blackstone_city") -> void:
	city_id = StringName(city_id_value)


func has_active_order() -> bool:
	return _active_order_id != &""


func get_active_order() -> Dictionary:
	return get_order(_active_order_id)


func get_order(order_id: StringName) -> Dictionary:
	var order: Dictionary = _orders_by_id.get(order_id, {})
	return order.duplicate(true)


func get_last_order_day() -> int:
	return _last_order_day


func enqueue(
	unit_definition_id: StringName,
	quantity: int,
	ordered_day: int,
	complete_day: int,
	food_cost_committed: int
) -> Dictionary:
	if (
		city_id == &""
		or unit_definition_id == &""
		or quantity <= 0
		or ordered_day <= 0
		or complete_day <= ordered_day
		or food_cost_committed < 0
		or has_active_order()
		or _last_order_day == ordered_day
		or _next_order_sequence >= MAX_EXACT_PERSISTED_SEQUENCE
	):
		return {}
	var order_id := StringName(
		"training.%s.%06d" % [String(city_id), _next_order_sequence]
	)
	_next_order_sequence += 1
	var order := {
		"schema_version": SCHEMA_VERSION,
		"order_id": order_id,
		"city_id": city_id,
		"unit_definition_id": unit_definition_id,
		"quantity": quantity,
		"ordered_day": ordered_day,
		"complete_day": complete_day,
		"food_cost_committed": food_cost_committed,
		"phase": PHASE_QUEUED,
		"completed_day": 0,
	}
	_orders_by_id[order_id] = order
	_active_order_id = order_id
	_last_order_day = ordered_day
	return order.duplicate(true)


func get_due_order(current_day: int) -> Dictionary:
	var order := get_active_order()
	if (
		order.is_empty()
		or StringName(order.phase) != PHASE_QUEUED
		or int(order.complete_day) > current_day
	):
		return {}
	return order


func mark_completed(order_id: StringName, completed_day: int) -> bool:
	if order_id == &"" or order_id != _active_order_id:
		return false
	var order: Dictionary = _orders_by_id.get(order_id, {})
	if (
		order.is_empty()
		or StringName(order.phase) != PHASE_QUEUED
		or completed_day < int(order.complete_day)
	):
		return false
	order.phase = PHASE_COMPLETED
	order.completed_day = completed_day
	_orders_by_id[order_id] = order
	_active_order_id = &""
	return true


func restore_legacy_state(
	quantity: int,
	complete_day: int,
	last_order_day: int,
	unit_definition_id: StringName,
	food_cost_committed := 0
) -> bool:
	if (
		quantity < 0
		or complete_day < 0
		or last_order_day < 0
		or unit_definition_id == &""
		or food_cost_committed < 0
		or (quantity == 0 and complete_day != 0)
		or (quantity > 0 and complete_day <= last_order_day)
	):
		return false
	_orders_by_id.clear()
	_active_order_id = &""
	_next_order_sequence = 1
	_last_order_day = last_order_day
	if quantity == 0:
		return true
	var order_id := StringName(
		"training.%s.%06d" % [String(city_id), _next_order_sequence]
	)
	_next_order_sequence += 1
	_orders_by_id[order_id] = {
		"schema_version": SCHEMA_VERSION,
		"order_id": order_id,
		"city_id": city_id,
		"unit_definition_id": unit_definition_id,
		"quantity": quantity,
		"ordered_day": last_order_day,
		"complete_day": complete_day,
		"food_cost_committed": food_cost_committed,
		"phase": PHASE_QUEUED,
		"completed_day": 0,
	}
	_active_order_id = order_id
	return true


func clear() -> void:
	_next_order_sequence = 1
	_last_order_day = 0
	_orders_by_id.clear()
	_active_order_id = &""


func get_snapshot() -> Dictionary:
	var orders_by_id: Dictionary = {}
	var order_ids := _orders_by_id.keys()
	order_ids.sort()
	for order_id in order_ids:
		orders_by_id[order_id] = (
			Dictionary(_orders_by_id[order_id]).duplicate(true)
		)
	return {
		"schema_version": SCHEMA_VERSION,
		"city_id": city_id,
		"next_order_sequence": _next_order_sequence,
		"last_order_day": _last_order_day,
		"active_order_id": _active_order_id,
		"orders_by_id": orders_by_id,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.valid):
		return false
	var candidate: Dictionary = validation.snapshot
	city_id = StringName(candidate.city_id)
	_next_order_sequence = int(candidate.next_order_sequence)
	_last_order_day = int(candidate.last_order_day)
	_active_order_id = StringName(candidate.active_order_id)
	_orders_by_id.clear()
	for order_id_value in candidate.orders_by_id:
		var order: Dictionary = candidate.orders_by_id[order_id_value]
		_orders_by_id[StringName(order_id_value)] = order.duplicate(true)
	return true


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if (
		int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION
		or StringName(snapshot.get("city_id", &"")) == &""
		or typeof(snapshot.get("next_order_sequence", null)) != TYPE_INT
		or int(snapshot.get("next_order_sequence", 0)) <= 0
		or int(snapshot.get("next_order_sequence", 0))
			> MAX_EXACT_PERSISTED_SEQUENCE
		or int(snapshot.get("last_order_day", -1)) < 0
		or not snapshot.get("orders_by_id", null) is Dictionary
	):
		return {"valid": false, "error_id": &"INVALID_TRAINING_QUEUE"}
	var normalized := snapshot.duplicate(true)
	var active_order_id := StringName(
		normalized.get("active_order_id", &"")
	)
	var seen: Dictionary = {}
	var queued_count := 0
	var maximum_order_sequence := 0
	var maximum_ordered_day := 0
	for order_id_value in normalized.orders_by_id:
		var order_value = normalized.orders_by_id[order_id_value]
		if not order_value is Dictionary:
			return {"valid": false, "error_id": &"INVALID_TRAINING_ORDER"}
		var order: Dictionary = order_value
		var order_id := StringName(order.get("order_id", &""))
		var phase := StringName(order.get("phase", &""))
		var order_sequence := _parse_order_sequence(
			order_id,
			StringName(normalized.city_id)
		)
		if (
			int(order.get("schema_version", 0)) != SCHEMA_VERSION
			or order_id == &""
			or order_id != StringName(order_id_value)
			or order_sequence <= 0
			or seen.has(order_id)
			or StringName(order.get("city_id", &""))
				!= StringName(normalized.city_id)
			or StringName(order.get("unit_definition_id", &"")) == &""
			or int(order.get("quantity", 0)) <= 0
			or int(order.get("ordered_day", 0)) <= 0
			or int(order.get("complete_day", 0))
				<= int(order.get("ordered_day", 0))
			or int(order.get("food_cost_committed", -1)) < 0
			or phase not in [PHASE_QUEUED, PHASE_COMPLETED]
			or (
				phase == PHASE_QUEUED
				and int(order.get("completed_day", -1)) != 0
			)
			or (
				phase == PHASE_COMPLETED
				and int(order.get("completed_day", 0))
					< int(order.get("complete_day", 0))
			)
		):
			return {"valid": false, "error_id": &"INVALID_TRAINING_ORDER"}
		seen[order_id] = true
		maximum_order_sequence = maxi(
			maximum_order_sequence,
			order_sequence
		)
		maximum_ordered_day = maxi(
			maximum_ordered_day,
			int(order.ordered_day)
		)
		if phase == PHASE_QUEUED:
			queued_count += 1
			if order_id != active_order_id:
				return {
					"valid": false,
					"error_id": &"ACTIVE_TRAINING_ORDER_MISMATCH",
				}
	if queued_count > 1 or (queued_count == 0) != (active_order_id == &""):
		return {
			"valid": false,
			"error_id": &"ACTIVE_TRAINING_ORDER_MISMATCH",
		}
	if (
		int(normalized.next_order_sequence) <= maximum_order_sequence
		or (
			not normalized.orders_by_id.is_empty()
			and int(normalized.last_order_day) != maximum_ordered_day
		)
	):
		return {
			"valid": false,
			"error_id": &"TRAINING_SEQUENCE_MISMATCH",
		}
	return {
		"valid": true,
		"error_id": &"",
		"snapshot": normalized,
	}


static func _parse_order_sequence(
	order_id: StringName,
	expected_city_id: StringName
) -> int:
	var prefix := "training.%s." % String(expected_city_id)
	var text := String(order_id)
	if not text.begins_with(prefix):
		return 0
	var digits := text.trim_prefix(prefix)
	if not digits.is_valid_int():
		return 0
	var sequence := int(digits)
	if sequence <= 0 or text != "%s%06d" % [prefix, sequence]:
		return 0
	return sequence
