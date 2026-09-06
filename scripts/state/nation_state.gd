class_name NationState
extends RefCounted


signal resource_transaction_committed(transaction: Dictionary)
signal city_local_state_changed(city_id: StringName, state: Dictionary)

const NATION_ID := &"nation.txwzs2"
const BLACKSTONE_CITY_ID := &"blackstone_city"
const RIVERBEND_CITY_ID := &"riverbend_city"
const CITY_IDS: Array[StringName] = [
	BLACKSTONE_CITY_ID,
	RIVERBEND_CITY_ID,
]
const RESOURCE_IDS: Array[StringName] = [
	&"food",
	&"tech_points",
	&"wood",
]
const RESOURCE_OPERATION_ADD := &"ADD"
const RESOURCE_OPERATION_SPEND := &"SPEND"
const MAX_EXACT_INTEGER := 9007199254740991
const DEFAULT_SHARED_RESOURCES := {
	&"food": 80,
	&"tech_points": 0,
	&"wood": 100,
}
const FORBIDDEN_LOCAL_STATE_KEYS: Array[StringName] = [
	&"army_registry",
	&"garrison",
	&"training_queue",
]


class CityRuntimeState extends RefCounted:
	var city_id: StringName
	var _local_state: Dictionary = {}


	func _init(city_id_value: StringName) -> void:
		city_id = city_id_value


	func get_snapshot() -> Dictionary:
		return {
			"city_id": city_id,
			"local_state": _local_state.duplicate(true),
		}


	func replace_local_state(value: Dictionary) -> void:
		_local_state = value.duplicate(true)


var _shared_resources: Dictionary = DEFAULT_SHARED_RESOURCES.duplicate(true)
var _city_states: Dictionary = {}
var _next_transaction_sequence := 1


func _init() -> void:
	for city_id in CITY_IDS:
		_city_states[city_id] = CityRuntimeState.new(city_id)


func get_city_ids() -> Array[StringName]:
	return CITY_IDS.duplicate()


func has_city(city_id: StringName) -> bool:
	return _city_states.has(city_id)


func get_city_state(city_id: StringName) -> Dictionary:
	if not has_city(city_id):
		return _failure(&"UNKNOWN_CITY", "未知城市身份")
	var city_state = _city_states[city_id]
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"city": city_state.get_snapshot().duplicate(true),
	}


func replace_city_local_state(
	city_id: StringName,
	local_state: Dictionary
) -> Dictionary:
	if not has_city(city_id):
		return _failure(&"UNKNOWN_CITY", "未知城市身份")
	for key in local_state.keys():
		if StringName(key) in FORBIDDEN_LOCAL_STATE_KEYS:
			return _failure(
				&"FORBIDDEN_DUPLICATE_AUTHORITY",
				"城市局部状态不得复制驻军、训练或军队 authority"
			)
	var city_state = _city_states[city_id]
	city_state.replace_local_state(local_state.duplicate(true))
	var detached: Dictionary = city_state.get_snapshot().duplicate(true)
	city_local_state_changed.emit(city_id, detached.duplicate(true))
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"city": detached,
	}


func get_shared_resources() -> Dictionary:
	return _shared_resources.duplicate(true)


func get_resource(resource_id: StringName) -> int:
	if resource_id not in RESOURCE_IDS:
		return 0
	return int(_shared_resources[resource_id])


func get_city_resource_view(city_id: StringName) -> Dictionary:
	if not has_city(city_id):
		return _failure(&"UNKNOWN_CITY", "未知城市身份")
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"city_id": city_id,
		"resources": get_shared_resources(),
	}


## The only runtime mutation entry for national shared resources.
## Each entry requires a positive integer amount and an explicit ADD/SPEND mode.
func commit_resource_transaction(
	city_id: StringName,
	entries: Array[Dictionary],
	reason: StringName,
	local_commit: Callable = Callable()
) -> Dictionary:
	if not has_city(city_id):
		return _failure(&"UNKNOWN_CITY", "未知城市身份")
	if entries.is_empty():
		return _failure(&"EMPTY_TRANSACTION", "资源事务不能为空")
	if reason == &"":
		return _failure(&"MISSING_REASON", "资源事务必须提供原因")
	var next_resources := _shared_resources.duplicate(true)
	var normalized_entries: Array[Dictionary] = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			return _failure(&"INVALID_ENTRY", "资源事务条目类型非法")
		var entry: Dictionary = entry_value
		var resource_id := StringName(entry.get("resource_id", &""))
		var operation := StringName(entry.get("operation", &""))
		var amount_value = entry.get("amount", null)
		if resource_id not in RESOURCE_IDS:
			return _failure(&"UNKNOWN_RESOURCE", "未知国家资源")
		if operation not in [RESOURCE_OPERATION_ADD, RESOURCE_OPERATION_SPEND]:
			return _failure(&"INVALID_OPERATION", "资源事务操作非法")
		if (
			typeof(amount_value) != TYPE_INT
			or int(amount_value) <= 0
			or int(amount_value) > MAX_EXACT_INTEGER
		):
			return _failure(&"INVALID_AMOUNT", "资源数量必须是正整数")
		var amount := int(amount_value)
		var before := int(next_resources[resource_id])
		var after := (
			before + amount
			if operation == RESOURCE_OPERATION_ADD
			else before - amount
		)
		if after < 0:
			return _failure(&"INSUFFICIENT_RESOURCE", "国家资源余额不足")
		if after > MAX_EXACT_INTEGER:
			return _failure(&"RESOURCE_OVERFLOW", "国家资源超出精确整数范围")
		next_resources[resource_id] = after
		normalized_entries.append({
			"resource_id": resource_id,
			"operation": operation,
			"amount": amount,
		})
	var local_commit_result: Dictionary = {}
	if local_commit.is_valid():
		var raw_commit_result = local_commit.call()
		if typeof(raw_commit_result) == TYPE_BOOL:
			if not bool(raw_commit_result):
				return _failure(
					&"LOCAL_COMMIT_REJECTED",
					"资源事务的局部状态提交被拒绝"
				)
			local_commit_result = {"success": true}
		elif typeof(raw_commit_result) == TYPE_DICTIONARY:
			local_commit_result = Dictionary(raw_commit_result).duplicate(true)
			if local_commit_result.is_empty() or (
				local_commit_result.has("success")
				and not bool(local_commit_result.success)
			):
				return _failure(
					&"LOCAL_COMMIT_REJECTED",
					"资源事务的局部状态提交被拒绝"
				)
		else:
			return _failure(
				&"INVALID_LOCAL_COMMIT_RESULT",
				"资源事务的局部提交结果非法"
			)
	var before_resources := _shared_resources.duplicate(true)
	_shared_resources = next_resources.duplicate(true)
	var transaction := {
		"transaction_sequence": _next_transaction_sequence,
		"city_id": city_id,
		"reason": reason,
		"entries": normalized_entries.duplicate(true),
		"before": before_resources,
		"after": _shared_resources.duplicate(true),
	}
	_next_transaction_sequence += 1
	resource_transaction_committed.emit(transaction.duplicate(true))
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"transaction": transaction.duplicate(true),
		"local_commit_result": local_commit_result.duplicate(true),
	}


## Controlled initialization/hydration seam. It never retains the caller DTO.
func hydrate_shared_resources(
	resources: Dictionary,
	source: StringName
) -> Dictionary:
	if source == &"":
		return _failure(&"MISSING_SOURCE", "资源水合必须标记来源")
	if resources.size() != RESOURCE_IDS.size():
		return _failure(&"INVALID_RESOURCE_TOPOLOGY", "国家资源字段不完整")
	var normalized: Dictionary = {}
	for resource_id in RESOURCE_IDS:
		if not resources.has(resource_id):
			return _failure(&"INVALID_RESOURCE_TOPOLOGY", "国家资源字段不完整")
		var value = resources[resource_id]
		if (
			typeof(value) != TYPE_INT
			or int(value) < 0
			or int(value) > MAX_EXACT_INTEGER
		):
			return _failure(&"INVALID_RESOURCE_BALANCE", "国家资源余额非法")
		normalized[resource_id] = int(value)
	_shared_resources = normalized.duplicate(true)
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"source": source,
		"resources": get_shared_resources(),
	}


func replace_resource_balance_compatibility(
	city_id: StringName,
	resource_id: StringName,
	value: int,
	reason: StringName
) -> Dictionary:
	if value < 0 or value > MAX_EXACT_INTEGER:
		return _failure(&"INVALID_RESOURCE_BALANCE", "国家资源余额非法")
	var before := get_resource(resource_id)
	if resource_id not in RESOURCE_IDS:
		return _failure(&"UNKNOWN_RESOURCE", "未知国家资源")
	if value == before:
		return {
			"success": true,
			"error_id": &"",
			"error": "",
			"transaction": {},
		}
	return commit_resource_transaction(
		city_id,
		[{
			"resource_id": resource_id,
			"operation": (
				RESOURCE_OPERATION_ADD
				if value > before
				else RESOURCE_OPERATION_SPEND
			),
			"amount": absi(value - before),
		}],
		reason
	)


func _failure(error_id: StringName, error: String) -> Dictionary:
	return {
		"success": false,
		"error_id": error_id,
		"error": error,
	}
