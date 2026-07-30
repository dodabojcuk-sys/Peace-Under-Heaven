class_name V5CampaignSnapshot
extends RefCounted


const SCHEMA_VERSION := 2
const SNAPSHOT_KIND := &"campaign_authoritative"
const CITY_ID := "blackstone_city"
const ROOT_KEYS := [
	"schema_version",
	"snapshot_kind",
	"city_id",
	"city",
	"placements",
	"next_placement_id",
	"garrison",
	"training_queue",
	"army_registry",
	"settlement_ledger",
]
const CITY_KEYS := [
	"current_day",
	"day_elapsed_milliseconds",
	"wood",
	"food",
	"tech_points",
	"recruitment_cap",
	"selected_general_id",
	"researched_tech_ids",
	"supply_shortage",
	"emergency_mobilization_used",
	"city_time_paused",
	"city_time_speed_id",
]
const GARRISON_KEYS := [
	"schema_version",
	"city_id",
	"unit_counts_by_definition_id",
]
const PLACEMENT_KEYS := [
	"placement_id",
	"definition_id",
	"origin_cell",
	"lifecycle_state",
	"built_day",
	"disabled_until_day",
	"construction_started_day",
	"construction_complete_day",
]
const LEDGER_KEYS := [
	"committed_results_by_id",
	"closed_transactions_by_id",
	"first_clear_keys",
	"completed_noticeboard_mission_ids",
	"next_battle_transaction_sequence",
	"next_army_dispatch_transaction_sequence",
]


static func validate_structure(
	snapshot: Dictionary,
	allowed_unit_definition_ids: Array
) -> Dictionary:
	if (
		typeof(snapshot.get("schema_version", null)) == TYPE_INT
		and int(snapshot.schema_version) > SCHEMA_VERSION
	):
		return _failure(
			&"FUTURE_SCHEMA_VERSION",
			"未知未来 CampaignSnapshot schema"
		)
	if not _has_exact_keys(snapshot, ROOT_KEYS):
		return _failure(&"INVALID_ROOT", "V2 根字段不完整或含未知字段")
	if (
		typeof(snapshot.schema_version) != TYPE_INT
		or int(snapshot.schema_version) != SCHEMA_VERSION
		or typeof(snapshot.snapshot_kind) != TYPE_STRING_NAME
		or StringName(snapshot.snapshot_kind) != SNAPSHOT_KIND
		or typeof(snapshot.city_id) != TYPE_STRING
		or str(snapshot.city_id) != CITY_ID
		or typeof(snapshot.city) != TYPE_DICTIONARY
		or typeof(snapshot.placements) != TYPE_ARRAY
		or typeof(snapshot.next_placement_id) != TYPE_INT
		or typeof(snapshot.garrison) != TYPE_DICTIONARY
		or typeof(snapshot.training_queue) != TYPE_DICTIONARY
		or typeof(snapshot.army_registry) != TYPE_DICTIONARY
		or typeof(snapshot.settlement_ledger) != TYPE_DICTIONARY
	):
		return _failure(&"INVALID_ROOT", "V2 根字段类型或身份错误")
	if not _is_persistence_value(snapshot):
		return _failure(
			&"FORBIDDEN_PERSISTENCE_VALUE",
			"V2 不得包含运行时或表现对象"
		)
	var city_result := _validate_city(snapshot.city)
	if not bool(city_result.valid):
		return city_result
	var placement_result := _validate_placements(
		snapshot.placements,
		int(snapshot.next_placement_id),
		int(snapshot.city.current_day)
	)
	if not bool(placement_result.valid):
		return placement_result
	var garrison_result := _validate_garrison(
		snapshot.garrison,
		allowed_unit_definition_ids
	)
	if not bool(garrison_result.valid):
		return garrison_result
	var queue_result := TrainingQueue.validate_snapshot(
		snapshot.training_queue
	)
	if not bool(queue_result.valid):
		return _failure(
			StringName(queue_result.error_id),
			"TrainingQueue 校验失败"
		)
	var army_result := ArmyRegistry.validate_snapshot(
		snapshot.army_registry,
		allowed_unit_definition_ids,
		true
	)
	if not bool(army_result.valid):
		return _failure(
			StringName(army_result.error_id),
			"ArmyRegistry 校验失败"
		)
	var ledger_result := _validate_ledger(snapshot.settlement_ledger)
	if not bool(ledger_result.valid):
		return ledger_result
	var garrison_total := 0
	for count in Dictionary(
		snapshot.garrison.unit_counts_by_definition_id
	).values():
		garrison_total += int(count)
	var queued_total := 0
	for order in Dictionary(
		snapshot.training_queue.orders_by_id
	).values():
		if StringName(order.phase) == TrainingQueue.PHASE_QUEUED:
			queued_total += int(order.quantity)
	if (
		garrison_total + queued_total
			> int(snapshot.city.recruitment_cap)
	):
		return _failure(
			&"CAPACITY_CONSERVATION",
			"驻军与训练队列超过征募容量"
		)
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": snapshot.duplicate(true),
	}


static func migrate_v1(
	v1_snapshot: Dictionary,
	v1_validator: Callable,
	v2_validator: Callable,
	unit_definition_id: StringName,
	recruit_food_per_unit: int
) -> Dictionary:
	if not v1_validator.is_valid() or not v2_validator.is_valid():
		return _failure(&"INVALID_VALIDATOR", "迁移校验入口无效")
	var source_result = v1_validator.call(v1_snapshot.duplicate(true))
	if (
		typeof(source_result) != TYPE_DICTIONARY
		or not bool(source_result.get("valid", false))
	):
		return _failure(
			&"INVALID_V1_SOURCE",
			"V1 源快照未通过原始校验"
		)
	var source: Dictionary = source_result.snapshot
	var queue := TrainingQueue.new(StringName(source.city_id))
	if not queue.restore_legacy_state(
		int(source.city.training_queued_count),
		int(source.city.training_complete_day),
		int(source.city.last_training_order_day),
		unit_definition_id,
		int(source.city.training_queued_count) * recruit_food_per_unit
	):
		return _failure(&"MIGRATION_MAPPING_FAILED", "训练队列映射失败")
	var candidate := {
		"schema_version": SCHEMA_VERSION,
		"snapshot_kind": SNAPSHOT_KIND,
		"city_id": str(source.city_id),
		"city": {
			"current_day": int(source.city.current_day),
			"day_elapsed_milliseconds": roundi(
				float(source.city.day_elapsed_seconds) * 1000.0
			),
			"wood": int(source.city.wood),
			"food": int(source.city.food),
			"tech_points": int(source.city.tech_points),
			"recruitment_cap": int(source.city.recruitment_cap),
			"selected_general_id": StringName(
				source.city.selected_general_id
			),
			"researched_tech_ids": (
				source.city.researched_tech_ids.duplicate()
			),
			"supply_shortage": bool(source.city.supply_shortage),
			"emergency_mobilization_used": bool(
				source.city.emergency_mobilization_used
			),
			"city_time_paused": bool(source.city.city_time_paused),
			"city_time_speed_id": StringName(
				"%dx" % roundi(float(source.city.city_time_speed))
			),
		},
		"placements": source.placements.duplicate(true),
		"next_placement_id": int(source.next_placement_id),
		"garrison": {
			"schema_version": GarrisonState.SCHEMA_VERSION,
			"city_id": StringName(source.city_id),
			"unit_counts_by_definition_id": {
				unit_definition_id: int(source.city.infantry_count),
			},
		},
		"training_queue": queue.get_snapshot(),
		"army_registry": ArmyRegistry.new().get_snapshot(),
		"settlement_ledger": empty_settlement_ledger(),
	}
	var candidate_result = v2_validator.call(candidate.duplicate(true))
	if (
		typeof(candidate_result) != TYPE_DICTIONARY
		or not bool(candidate_result.get("valid", false))
	):
		return _failure(
			&"INVALID_V2_CANDIDATE",
			"迁移候选未通过 V2 完整校验"
		)
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"snapshot": Dictionary(candidate_result.snapshot).duplicate(true),
	}


static func empty_settlement_ledger() -> Dictionary:
	return {
		"committed_results_by_id": {},
		"closed_transactions_by_id": {},
		"first_clear_keys": {},
		"completed_noticeboard_mission_ids": {},
		"next_battle_transaction_sequence": 1,
		"next_army_dispatch_transaction_sequence": 1,
	}


static func _validate_city(city: Dictionary) -> Dictionary:
	if not _has_exact_keys(city, CITY_KEYS):
		return _failure(&"INVALID_CITY", "V2 city 字段不完整")
	for key in [
		"current_day",
		"day_elapsed_milliseconds",
		"wood",
		"food",
		"tech_points",
		"recruitment_cap",
	]:
		if typeof(city[key]) != TYPE_INT:
			return _failure(&"INVALID_CITY", "V2 city 整数字段错误")
	if (
		int(city.current_day) <= 0
		or int(city.day_elapsed_milliseconds) < 0
		or int(city.day_elapsed_milliseconds) >= 180000
		or int(city.wood) < 0
		or int(city.food) < 0
		or int(city.tech_points) < 0
		or int(city.recruitment_cap) <= 0
		or typeof(city.selected_general_id) != TYPE_STRING_NAME
		or typeof(city.researched_tech_ids) != TYPE_ARRAY
		or typeof(city.supply_shortage) != TYPE_BOOL
		or typeof(city.emergency_mobilization_used) != TYPE_BOOL
		or typeof(city.city_time_paused) != TYPE_BOOL
		or typeof(city.city_time_speed_id) != TYPE_STRING_NAME
		or StringName(city.city_time_speed_id)
			not in [&"1x", &"2x", &"4x"]
	):
		return _failure(&"INVALID_CITY", "V2 city 领域值错误")
	var seen: Dictionary = {}
	for tech_id_value in city.researched_tech_ids:
		var tech_id := StringName(tech_id_value)
		if tech_id == &"" or seen.has(tech_id):
			return _failure(&"INVALID_CITY", "科技 ID 非法或重复")
		seen[tech_id] = true
	return {"valid": true}


static func _validate_placements(
	placements: Array,
	next_placement_id: int,
	current_day: int
) -> Dictionary:
	if next_placement_id <= 0:
		return _failure(&"INVALID_PLACEMENTS", "next placement 必须为正")
	var seen: Dictionary = {}
	var maximum_id := 0
	for value in placements:
		if not value is Dictionary:
			return _failure(&"INVALID_PLACEMENTS", "placement 必须为字典")
		var placement: Dictionary = value
		if (
			not _has_exact_keys(placement, PLACEMENT_KEYS)
			or typeof(placement.placement_id) != TYPE_INT
			or int(placement.placement_id) <= 0
			or seen.has(int(placement.placement_id))
			or typeof(placement.definition_id) != TYPE_STRING_NAME
			or StringName(placement.definition_id) == &""
			or typeof(placement.origin_cell) != TYPE_VECTOR2I
			or typeof(placement.lifecycle_state) != TYPE_STRING_NAME
			or StringName(placement.lifecycle_state)
				not in [&"constructing", &"running"]
		):
			return _failure(&"INVALID_PLACEMENTS", "placement 身份非法")
		for day_key in [
			"built_day",
			"disabled_until_day",
			"construction_started_day",
			"construction_complete_day",
		]:
			if (
				typeof(placement[day_key]) != TYPE_INT
				or int(placement[day_key]) < 0
			):
				return _failure(
					&"INVALID_PLACEMENTS",
					"placement 日期非法"
				)
		if int(placement.built_day) > current_day:
			return _failure(&"INVALID_PLACEMENTS", "placement 晚于当前日")
		seen[int(placement.placement_id)] = true
		maximum_id = maxi(maximum_id, int(placement.placement_id))
	if next_placement_id <= maximum_id:
		return _failure(&"INVALID_PLACEMENTS", "next placement 未单调")
	return {"valid": true}


static func _validate_garrison(
	garrison: Dictionary,
	allowed_unit_definition_ids: Array
) -> Dictionary:
	if (
		not _has_exact_keys(garrison, GARRISON_KEYS)
		or typeof(garrison.schema_version) != TYPE_INT
		or int(garrison.schema_version) != GarrisonState.SCHEMA_VERSION
		or typeof(garrison.city_id) != TYPE_STRING_NAME
		or StringName(garrison.city_id) != StringName(CITY_ID)
		or typeof(garrison.unit_counts_by_definition_id) != TYPE_DICTIONARY
	):
		return _failure(&"INVALID_GARRISON", "V2 garrison 字段非法")
	for definition_id_value in garrison.unit_counts_by_definition_id:
		var definition_id := StringName(definition_id_value)
		if (
			definition_id not in allowed_unit_definition_ids
			or typeof(
				garrison.unit_counts_by_definition_id[definition_id_value]
			) != TYPE_INT
			or int(
				garrison.unit_counts_by_definition_id[definition_id_value]
			) < 0
		):
			return _failure(&"INVALID_GARRISON", "V2 驻军组成非法")
	return {"valid": true}


static func _validate_ledger(ledger: Dictionary) -> Dictionary:
	if not _has_exact_keys(ledger, LEDGER_KEYS):
		return _failure(&"INVALID_LEDGER", "结算 ledger 字段非法")
	for key in [
		"committed_results_by_id",
		"closed_transactions_by_id",
		"first_clear_keys",
		"completed_noticeboard_mission_ids",
	]:
		if typeof(ledger[key]) != TYPE_DICTIONARY:
			return _failure(&"INVALID_LEDGER", "结算 ledger 类型非法")
	for key in [
		"next_battle_transaction_sequence",
		"next_army_dispatch_transaction_sequence",
	]:
		if typeof(ledger[key]) != TYPE_INT or int(ledger[key]) <= 0:
			return _failure(&"INVALID_LEDGER", "结算序列非法")
	return {"valid": true}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _is_persistence_value(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2I:
			return true
		TYPE_ARRAY:
			for item in value:
				if not _is_persistence_value(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if (
					not _is_persistence_value(key)
					or not _is_persistence_value(value[key])
				):
					return false
			return true
	return false


static func _failure(error_id: StringName, error: String) -> Dictionary:
	return {
		"success": false,
		"valid": false,
		"error_id": error_id,
		"error": error,
		"snapshot": {},
	}
