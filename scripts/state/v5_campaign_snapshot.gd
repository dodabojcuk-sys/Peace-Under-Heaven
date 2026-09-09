class_name V5CampaignSnapshot
extends RefCounted


const MACRO_MARCH_THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const SCHEMA_VERSION := 7
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
	"mainline_level",
	"build_slot",
	"expedition_attempt",
	"war_loop",
]
const V6_ROOT_KEYS := [
	"schema_version", "snapshot_kind", "city_id", "city", "placements",
	"next_placement_id", "garrison", "training_queue", "army_registry",
	"settlement_ledger", "mainline_level", "build_slot", "expedition_attempt",
]
const V5_ROOT_KEYS := [
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
	"mainline_level",
	"build_slot",
]
const V4_ROOT_KEYS := [
	"schema_version", "snapshot_kind", "city_id", "city", "placements",
	"next_placement_id", "garrison", "training_queue", "army_registry",
	"settlement_ledger", "mainline_level",
]
const V3_ROOT_KEYS := [
	"schema_version", "snapshot_kind", "city_id", "city", "placements",
	"next_placement_id", "garrison", "training_queue", "army_registry",
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
	"security",
]
const V3_CITY_KEYS := [
	"current_day", "day_elapsed_milliseconds", "wood", "food",
	"tech_points", "recruitment_cap", "selected_general_id",
	"researched_tech_ids", "supply_shortage", "emergency_mobilization_used",
	"city_time_paused", "city_time_speed_id",
]
const V5_GARRISON_KEYS := [
	"schema_version",
	"city_id",
	"unit_counts_by_definition_id",
]
const EXPEDITION_ATTEMPT_KEYS := [
	"attempt_id",
	"mainline_id",
	"phase",
	"created_day",
	"created_day_elapsed_milliseconds",
	"food_cost",
	"food_before",
	"food_after",
	"committed_total",
	"selected_formations",
	"committed_force_snapshot",
	"enemy_force_snapshot",
	"city_defense_snapshot",
	"first_clear_key",
	"reward_wood",
	"reward_food",
	"settled",
	"result_id",
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
	"orientation",
	"construction_state",
	"construction_progress_milliseconds",
	"construction_required_milliseconds",
	"construction_total_costs",
	"construction_paid_costs",
	"construction_priority",
	"construction_missing_resource_ids",
]
const V3_PLACEMENT_KEYS := [
	"placement_id", "definition_id", "origin_cell", "lifecycle_state",
	"built_day", "disabled_until_day", "construction_started_day",
	"construction_complete_day", "orientation",
]
const V2_PLACEMENT_KEYS := [
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
const BUILD_SLOT_KEYS := [
	"state",
	"definition_id",
	"progress_milliseconds",
	"required_milliseconds",
	"total_costs",
	"paid_costs",
	"missing_resource_ids",
	"orientation",
	"completion_notified",
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
	var source_version := int(snapshot.get("schema_version", 0))
	if (
		(source_version == SCHEMA_VERSION and not _has_exact_keys(snapshot, ROOT_KEYS))
		or (source_version == 6 and not _has_exact_keys(snapshot, V6_ROOT_KEYS))
		or (source_version == 5 and not _has_exact_keys(snapshot, V5_ROOT_KEYS))
		or (source_version == 4 and not _has_exact_keys(snapshot, V4_ROOT_KEYS))
		or (source_version in [2, 3] and not _has_exact_keys(snapshot, V3_ROOT_KEYS))
	):
		return _failure(&"INVALID_ROOT", "CampaignSnapshot 根字段不完整或含未知字段")
	if (
		typeof(snapshot.schema_version) != TYPE_INT
		or int(snapshot.schema_version) not in [2, 3, 4, 5, 6, SCHEMA_VERSION]
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
		return _failure(&"INVALID_ROOT", "CampaignSnapshot 根字段类型或身份错误")
	if not _is_persistence_value(snapshot):
		return _failure(
			&"FORBIDDEN_PERSISTENCE_VALUE",
			"CampaignSnapshot 不得包含运行时或表现对象"
		)
	var normalized := snapshot.duplicate(true)
	if int(normalized.schema_version) == 2:
		var migration := _migrate_v2_orientation_defaults(normalized)
		if not bool(migration.valid):
			return migration
		normalized = migration.snapshot
	if int(normalized.schema_version) == 3:
		var migration := _migrate_v3_m0_defaults(normalized)
		if not bool(migration.valid):
			return migration
		normalized = migration.snapshot
	if int(normalized.schema_version) == 4:
		var migration := _migrate_v4_build_slot(normalized)
		if not bool(migration.valid):
			return migration
		normalized = migration.snapshot
	if int(normalized.schema_version) == 5:
		var migration := _migrate_v5_expedition(
			normalized,
			allowed_unit_definition_ids
		)
		if not bool(migration.valid):
			return migration
		normalized = migration.snapshot
	if int(normalized.schema_version) == 6:
		var migration := _migrate_v6_war_loop(normalized)
		if not bool(migration.valid):
			return migration
		normalized = migration.snapshot
	if typeof(normalized.get("war_loop", null)) != TYPE_DICTIONARY:
		return _failure(&"INVALID_WAR_LOOP", "WarLoop 快照字段非法")
	# WarLoop owns its nested R1 -> R2 migration.  Normalize it here so the
	# controller's exact restore postcondition compares one canonical snapshot
	# rather than a valid legacy input against a newer exported representation.
	var normalized_war_loop := WarLoopState.new()
	if not normalized_war_loop.restore_snapshot(Dictionary(normalized.war_loop)):
		return _failure(&"INVALID_WAR_LOOP", "WarLoop 快照字段非法")
	# Route migration for specialists needs the same Resource-owned terrain facts
	# as the real restore.  Canonicalizing with those facts keeps the controller's
	# exact postcondition check strict without comparing pre- and post-migration
	# representations of a legacy save.
	normalized_war_loop.initialize_from_theater(
		MACRO_MARCH_THEATER.get_points(),
		MACRO_MARCH_THEATER.get_routes(),
		MACRO_MARCH_THEATER.get_water_regions(),
		Rect2i(MACRO_MARCH_THEATER.get_world_bounds()),
		MACRO_MARCH_THEATER.get_terrain_regions(),
		MACRO_MARCH_THEATER.get_patrol_configs(),
		MACRO_MARCH_THEATER.get_scout_visibility_range()
	)
	normalized.war_loop = normalized_war_loop.get_snapshot()
	var city_result := _validate_city(normalized.city)
	if not bool(city_result.valid):
		return city_result
	var placement_result := _validate_placements(
		normalized.placements,
		int(normalized.next_placement_id),
		int(normalized.city.current_day)
	)
	if not bool(placement_result.valid):
		return placement_result
	var build_slot_result := _validate_build_slot(normalized.build_slot)
	if not bool(build_slot_result.valid):
		return build_slot_result
	if (
		StringName(normalized.build_slot.state) != &"IDLE"
		and _has_constructing_placement(normalized.placements)
	):
		return _failure(
			&"LEGACY_BUILD_SLOT_CONFLICT",
			"旧地图施工存在时不得同时恢复新建造位"
		)
	var garrison_result := _validate_garrison(
		normalized.garrison,
		allowed_unit_definition_ids
	)
	if not bool(garrison_result.valid):
		return garrison_result
	var queue_result := TrainingQueue.validate_snapshot(
		normalized.training_queue
	)
	if not bool(queue_result.valid):
		return _failure(
			StringName(queue_result.error_id),
			"TrainingQueue 校验失败"
		)
	var army_result := ArmyRegistry.validate_snapshot(
		normalized.army_registry,
		allowed_unit_definition_ids,
		true
	)
	if not bool(army_result.valid):
		return _failure(
			StringName(army_result.error_id),
			"ArmyRegistry 校验失败"
		)
	# ArmyRegistry owns its own schema migration.  Persist the normalized
	# registry so a restored schema-1 army snapshot cannot fail the controller's
	# exact postcondition after the macro-march extension writes schema 2.
	normalized.army_registry = Dictionary(army_result.snapshot).duplicate(true)
	var ledger_result := _validate_ledger(normalized.settlement_ledger)
	if not bool(ledger_result.valid):
		return ledger_result
	if not CurrentMainlineLevel.validate_snapshot(normalized.mainline_level):
		return _failure(&"INVALID_MAINLINE_LEVEL", "主线压力快照非法")
	var expedition_result := _validate_expedition_attempt(
		normalized.expedition_attempt,
		allowed_unit_definition_ids
	)
	if not bool(expedition_result.valid):
		return expedition_result
	if not Dictionary(normalized.expedition_attempt).is_empty():
		var attempt: Dictionary = normalized.expedition_attempt
		var attempt_id := StringName(attempt.attempt_id)
		var phase := StringName(attempt.phase)
		if StringName(attempt.mainline_id) != StringName(normalized.mainline_level.level_id):
			return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征尝试与主线身份不一致")
		if phase in [&"RESERVED", &"ACTIVE"]:
			var transaction_already_settled := false
			for summary_value in Dictionary(
				normalized.settlement_ledger.committed_results_by_id
			).values():
				if (
					summary_value is Dictionary
					and StringName(summary_value.get("transaction_id", &""))
						== attempt_id
				):
					transaction_already_settled = true
					break
			if (
				int(normalized.city.food) != int(attempt.food_after)
				or int(normalized.city.current_day) != int(attempt.created_day)
				or int(normalized.city.day_elapsed_milliseconds)
					!= int(attempt.created_day_elapsed_milliseconds)
				or bool(normalized.mainline_level.cleared)
				or transaction_already_settled
				or Dictionary(normalized.settlement_ledger.closed_transactions_by_id).has(attempt_id)
			):
				return _failure(&"INVALID_EXPEDITION_ATTEMPT", "活动出征尝试与城市账本不一致")
			var roster: Dictionary = normalized.garrison.formations_by_id
			for selected_value in attempt.selected_formations:
				var selected: Dictionary = selected_value
				var current: Dictionary = roster.get(StringName(selected.formation_id), {})
				if current.is_empty() or int(current.member_count) != int(selected.member_count):
					return _failure(&"INVALID_EXPEDITION_ATTEMPT", "活动出征编队已偏离出发快照")
		elif phase == &"APPLIED":
			var results: Dictionary = normalized.settlement_ledger.committed_results_by_id
			var closed: Dictionary = normalized.settlement_ledger.closed_transactions_by_id
			var result_id := StringName(attempt.result_id)
			var summary: Dictionary = results.get(result_id, {})
			if (
				summary.is_empty()
				or result_id != StringName("%s-result-001" % String(attempt_id))
				or StringName(summary.get("result_id", &"")) != result_id
				or StringName(summary.get("transaction_id", &"")) != attempt_id
				or StringName(closed.get(attempt_id, &"")) != &"APPLIED"
			):
				return _failure(&"INVALID_EXPEDITION_ATTEMPT", "已结算出征尝试缺少唯一 ledger 记录")
	var garrison_total := 0
	for count in Dictionary(
		normalized.garrison.unit_counts_by_definition_id
	).values():
		garrison_total += int(count)
	var queued_total := 0
	for order in Dictionary(
		normalized.training_queue.orders_by_id
	).values():
		if StringName(order.phase) == TrainingQueue.PHASE_QUEUED:
			queued_total += int(order.quantity)
	if (
		garrison_total + queued_total
			> int(normalized.city.recruitment_cap)
	):
		return _failure(
			&"CAPACITY_CONSERVATION",
			"驻军与训练队列超过征募容量"
		)
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": normalized,
	}


static func _migrate_v2_orientation_defaults(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	for index in range(normalized.placements.size()):
		var placement_value = normalized.placements[index]
		if not placement_value is Dictionary:
			return _failure(&"INVALID_PLACEMENTS", "V2 placement 必须为字典")
		var placement: Dictionary = placement_value
		if not _has_exact_keys(placement, V2_PLACEMENT_KEYS):
			return _failure(&"INVALID_PLACEMENTS", "V2 placement 字段不完整")
		placement.orientation = 0
		normalized.placements[index] = placement
	normalized.schema_version = 3
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": normalized,
	}


static func _migrate_v3_m0_defaults(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	if not _has_exact_keys(normalized.city, V3_CITY_KEYS):
		return _failure(&"INVALID_CITY", "V3 city 字段不完整")
	normalized.city.security = 50
	for index in range(normalized.placements.size()):
		var placement_value = normalized.placements[index]
		if not placement_value is Dictionary:
			return _failure(&"INVALID_PLACEMENTS", "V3 placement 必须为字典")
		var placement: Dictionary = placement_value
		if not _has_exact_keys(placement, V3_PLACEMENT_KEYS):
			return _failure(&"INVALID_PLACEMENTS", "V3 placement 字段不完整")
		var required := maxi(
			(int(placement.construction_complete_day) - int(placement.construction_started_day)) * 180000,
			0
		)
		var completed := StringName(placement.lifecycle_state) == &"running"
		placement.construction_state = &"COMPLETED" if completed else &"ACTIVE"
		placement.construction_progress_milliseconds = required if completed else clampi(
			(int(normalized.city.current_day) - int(placement.construction_started_day)) * 180000,
			0,
			required
		)
		placement.construction_required_milliseconds = required
		# V3 paid atomically before placement. Empty totals preserve that payment
		# and prevent a migrated construction from being charged a second time.
		placement.construction_total_costs = {}
		placement.construction_paid_costs = {}
		placement.construction_priority = 1
		placement.construction_missing_resource_ids = []
		normalized.placements[index] = placement
	normalized.mainline_level = {
		"level_id": &"first_map.main_assault.v0",
		"activated_day": 1,
		"deadline_day": 7,
		"pressure_stage_id": StringName(
			"PRESSURE_%d" % _m0_stage_index(int(normalized.city.current_day))
		),
		"cleared": false,
		"cleared_day": 0,
		"applied_event_ids": {},
		"permanent_losses": {"wood": 0, "food": 0, "city_defense_damage": 0},
	}
	normalized.schema_version = 4
	return {"valid": true, "error_id": &"", "error": "", "snapshot": normalized}


static func _migrate_v4_build_slot(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	if not _has_exact_keys(normalized, V4_ROOT_KEYS):
		return _failure(&"INVALID_ROOT", "V4 CampaignSnapshot 根字段非法")
	normalized.build_slot = empty_build_slot()
	normalized.schema_version = 5
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": normalized,
	}


static func _migrate_v5_expedition(
	snapshot: Dictionary,
	allowed_unit_definition_ids: Array
) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	if not _has_exact_keys(normalized, V5_ROOT_KEYS):
		return _failure(&"INVALID_ROOT", "V5 CampaignSnapshot 根字段非法")
	var legacy_garrison: Dictionary = normalized.garrison
	if (
		not _has_exact_keys(legacy_garrison, V5_GARRISON_KEYS)
		or typeof(legacy_garrison.schema_version) != TYPE_INT
		or int(legacy_garrison.schema_version) != 1
		or typeof(legacy_garrison.city_id) != TYPE_STRING_NAME
		or StringName(legacy_garrison.city_id) != StringName(normalized.city_id)
		or typeof(legacy_garrison.unit_counts_by_definition_id) != TYPE_DICTIONARY
	):
		return _failure(&"INVALID_GARRISON", "V5 驻军字段非法")
	var counts: Dictionary = legacy_garrison.unit_counts_by_definition_id
	if counts.size() > 1 or allowed_unit_definition_ids.is_empty():
		return _failure(&"INVALID_GARRISON", "V5 驻军无法确定性迁移为编队")
	var definition_id := StringName(allowed_unit_definition_ids[0])
	var total_count := 0
	if not counts.is_empty():
		var definition_id_value = counts.keys()[0]
		if (
			typeof(definition_id_value) != TYPE_STRING_NAME
			or StringName(definition_id_value) not in allowed_unit_definition_ids
			or typeof(counts[definition_id_value]) != TYPE_INT
			or int(counts[definition_id_value]) < 0
			or int(counts[definition_id_value])
				> GarrisonState.FORMATION_IDS.size()
					* GarrisonState.DEFAULT_FORMATION_MAX_MEMBERS
		):
			return _failure(&"INVALID_GARRISON", "V5 驻军数量非法")
		definition_id = StringName(definition_id_value)
		total_count = int(counts[definition_id_value])
	normalized.garrison = GarrisonState.build_migrated_persistence_snapshot(
		StringName(normalized.city_id),
		definition_id,
		total_count
	)
	normalized.expedition_attempt = empty_expedition_attempt()
	normalized.schema_version = 6
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": normalized,
}


static func _migrate_v6_war_loop(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	if not _has_exact_keys(normalized, V6_ROOT_KEYS):
		return _failure(&"INVALID_ROOT", "V6 CampaignSnapshot 根字段非法")
	normalized.war_loop = {
		"schema_version": 1,
		"cities_by_id": {},
		"required_city_ids": {},
		"active_siege": {},
		"completed_resolution_ids": {},
		"next_siege_sequence": 1,
	}
	normalized.schema_version = SCHEMA_VERSION
	return {"valid": true, "error_id": &"", "error": "", "snapshot": normalized}


static func empty_build_slot() -> Dictionary:
	return {
		"state": &"IDLE",
		"definition_id": &"",
		"progress_milliseconds": 0,
		"required_milliseconds": 0,
		"total_costs": {},
		"paid_costs": {},
		"missing_resource_ids": [],
		"orientation": 0,
		"completion_notified": false,
	}


static func empty_expedition_attempt() -> Dictionary:
	return {}


static func _m0_stage_index(current_day: int) -> int:
	var overdue := maxi(current_day - 7, 0)
	if overdue >= 7:
		return 4
	if overdue >= 5:
		return 3
	if overdue >= 3:
		return 2
	if overdue >= 1:
		return 1
	return 0


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
		"schema_version": 5,
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
			"security": 50,
		},
		"placements": _migrate_v1_placements(source.placements),
		"next_placement_id": int(source.next_placement_id),
		"garrison": {
			"schema_version": 1,
			"city_id": StringName(source.city_id),
			"unit_counts_by_definition_id": {
				unit_definition_id: int(source.city.infantry_count),
			},
		},
		"training_queue": queue.get_snapshot(),
		"army_registry": ArmyRegistry.new().get_snapshot(),
		"settlement_ledger": empty_settlement_ledger(),
		"build_slot": empty_build_slot(),
		"mainline_level": {
			"level_id": &"first_map.main_assault.v0",
			"activated_day": 1,
			"deadline_day": 7,
			"pressure_stage_id": StringName(
				"PRESSURE_%d" % _m0_stage_index(int(source.city.current_day))
			),
			"cleared": false,
			"cleared_day": 0,
			"applied_event_ids": {},
			"permanent_losses": {"wood": 0, "food": 0, "city_defense_damage": 0},
		},
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


static func _migrate_v1_placements(placements: Array) -> Array[Dictionary]:
	var migrated: Array[Dictionary] = []
	for placement_value in placements:
		var placement: Dictionary = Dictionary(placement_value).duplicate(true)
		placement.orientation = 0
		var required := maxi(
			(int(placement.construction_complete_day) - int(placement.construction_started_day)) * 180000,
			0
		)
		var completed := StringName(placement.lifecycle_state) == &"running"
		placement.construction_state = &"COMPLETED" if completed else &"ACTIVE"
		placement.construction_progress_milliseconds = required if completed else 0
		placement.construction_required_milliseconds = required
		placement.construction_total_costs = {}
		placement.construction_paid_costs = {}
		placement.construction_priority = 1
		placement.construction_missing_resource_ids = []
		migrated.append(placement)
	return migrated


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
		"security",
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
		or int(city.security) < 0
		or int(city.security) > 100
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
			or typeof(placement.orientation) != TYPE_INT
			or int(placement.orientation) < 0
			or int(placement.orientation) > 3
			or typeof(placement.construction_state) != TYPE_STRING_NAME
			or StringName(placement.construction_state) not in [&"ACTIVE", &"BLOCKED_RESOURCES", &"COMPLETED"]
			or typeof(placement.construction_progress_milliseconds) != TYPE_INT
			or typeof(placement.construction_required_milliseconds) != TYPE_INT
			or int(placement.construction_progress_milliseconds) < 0
			or int(placement.construction_required_milliseconds) < 0
			or int(placement.construction_progress_milliseconds) > int(placement.construction_required_milliseconds)
			or typeof(placement.construction_total_costs) != TYPE_DICTIONARY
			or typeof(placement.construction_paid_costs) != TYPE_DICTIONARY
			or typeof(placement.construction_priority) != TYPE_INT
			or int(placement.construction_priority) not in [0, 1, 2]
			or typeof(placement.construction_missing_resource_ids) != TYPE_ARRAY
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
		if (
			Dictionary(placement.construction_total_costs).size()
				!= Dictionary(placement.construction_paid_costs).size()
			or (
				StringName(placement.lifecycle_state) == &"running"
				and StringName(placement.construction_state) != &"COMPLETED"
			)
			or (
				StringName(placement.lifecycle_state) == &"constructing"
				and StringName(placement.construction_state) == &"COMPLETED"
			)
		):
			return _failure(&"INVALID_PLACEMENTS", "placement 施工状态不一致")
		for resource_id in placement.construction_total_costs:
			if (
				StringName(resource_id) not in [&"wood", &"food"]
				or typeof(placement.construction_total_costs[resource_id]) != TYPE_INT
				or int(placement.construction_total_costs[resource_id]) < 0
				or typeof(placement.construction_paid_costs.get(resource_id, null)) != TYPE_INT
				or int(placement.construction_paid_costs[resource_id]) < 0
				or int(placement.construction_paid_costs[resource_id]) > int(placement.construction_total_costs[resource_id])
			):
				return _failure(&"INVALID_PLACEMENTS", "placement 施工扣料非法")
		for missing_id in placement.construction_missing_resource_ids:
			if (
				typeof(missing_id) != TYPE_STRING_NAME
				or StringName(missing_id) not in [&"wood", &"food"]
			):
				return _failure(&"INVALID_PLACEMENTS", "placement 缺料身份非法")
		maximum_id = maxi(maximum_id, int(placement.placement_id))
	if next_placement_id <= maximum_id:
		return _failure(&"INVALID_PLACEMENTS", "next placement 未单调")
	return {"valid": true}


static func _validate_build_slot(build_slot: Dictionary) -> Dictionary:
	if not _has_exact_keys(build_slot, BUILD_SLOT_KEYS):
		return _failure(&"INVALID_BUILD_SLOT", "建造位字段不完整或含未知字段")
	if (
		typeof(build_slot.state) != TYPE_STRING_NAME
		or StringName(build_slot.state) not in [
			&"IDLE",
			&"PRODUCING",
			&"WAITING_MATERIAL",
			&"READY_TO_PLACE",
		]
		or typeof(build_slot.definition_id) != TYPE_STRING_NAME
		or typeof(build_slot.progress_milliseconds) != TYPE_INT
		or typeof(build_slot.required_milliseconds) != TYPE_INT
		or typeof(build_slot.total_costs) != TYPE_DICTIONARY
		or typeof(build_slot.paid_costs) != TYPE_DICTIONARY
		or typeof(build_slot.missing_resource_ids) != TYPE_ARRAY
		or typeof(build_slot.orientation) != TYPE_INT
		or int(build_slot.orientation) < 0
		or int(build_slot.orientation) > 3
		or typeof(build_slot.completion_notified) != TYPE_BOOL
	):
		return _failure(&"INVALID_BUILD_SLOT", "建造位字段类型或状态非法")
	var state := StringName(build_slot.state)
	if state == &"IDLE":
		if (
			StringName(build_slot.definition_id) != &""
			or int(build_slot.progress_milliseconds) != 0
			or int(build_slot.required_milliseconds) != 0
			or not Dictionary(build_slot.total_costs).is_empty()
			or not Dictionary(build_slot.paid_costs).is_empty()
			or not Array(build_slot.missing_resource_ids).is_empty()
			or bool(build_slot.completion_notified)
		):
			return _failure(&"INVALID_BUILD_SLOT", "空闲建造位含项目数据")
		return {"valid": true}
	if (
		StringName(build_slot.definition_id) == &""
		or int(build_slot.required_milliseconds) <= 0
		or int(build_slot.progress_milliseconds) < 0
		or int(build_slot.progress_milliseconds) > int(build_slot.required_milliseconds)
		or Dictionary(build_slot.total_costs).size()
			!= Dictionary(build_slot.paid_costs).size()
	):
		return _failure(&"INVALID_BUILD_SLOT", "建造位项目进度或成本拓扑非法")
	for resource_id_value in build_slot.total_costs:
		var resource_id := StringName(resource_id_value)
		if (
			resource_id not in [&"wood", &"food"]
			or typeof(build_slot.total_costs[resource_id_value]) != TYPE_INT
			or int(build_slot.total_costs[resource_id_value]) <= 0
			or typeof(build_slot.paid_costs.get(resource_id_value, null)) != TYPE_INT
			or int(build_slot.paid_costs[resource_id_value]) < 0
			or int(build_slot.paid_costs[resource_id_value])
				> int(build_slot.total_costs[resource_id_value])
		):
			return _failure(&"INVALID_BUILD_SLOT", "建造位资源投入非法")
	for missing_id in build_slot.missing_resource_ids:
		if (
			typeof(missing_id) != TYPE_STRING_NAME
			or StringName(missing_id) not in [&"wood", &"food"]
		):
			return _failure(&"INVALID_BUILD_SLOT", "建造位缺料身份非法")
	if state == &"READY_TO_PLACE":
		if int(build_slot.progress_milliseconds) != int(build_slot.required_milliseconds):
			return _failure(&"INVALID_BUILD_SLOT", "待放置成品进度未完成")
		for resource_id in build_slot.total_costs:
			if int(build_slot.paid_costs[resource_id]) != int(build_slot.total_costs[resource_id]):
				return _failure(&"INVALID_BUILD_SLOT", "待放置成品未精确付清")
		if not Array(build_slot.missing_resource_ids).is_empty():
			return _failure(&"INVALID_BUILD_SLOT", "待放置成品仍含缺料")
	elif int(build_slot.progress_milliseconds) >= int(build_slot.required_milliseconds):
		return _failure(&"INVALID_BUILD_SLOT", "未完成状态却已达到完整进度")
	if state == &"PRODUCING" and not Array(build_slot.missing_resource_ids).is_empty():
		return _failure(&"INVALID_BUILD_SLOT", "生产状态不得含缺料")
	if state == &"WAITING_MATERIAL" and Array(build_slot.missing_resource_ids).is_empty():
		return _failure(&"INVALID_BUILD_SLOT", "缺料状态必须列出资源")
	return {"valid": true}


static func _has_constructing_placement(placements: Array) -> bool:
	for placement_value in placements:
		if (
			placement_value is Dictionary
			and StringName(placement_value.lifecycle_state) == &"constructing"
		):
			return true
	return false


static func _validate_garrison(
	garrison: Dictionary,
	allowed_unit_definition_ids: Array
) -> Dictionary:
	var result := GarrisonState.validate_persistence_snapshot(
		garrison,
		StringName(CITY_ID),
		allowed_unit_definition_ids
	)
	if not bool(result.get("valid", false)):
		return _failure(
			StringName(result.get("error_id", &"INVALID_GARRISON")),
			str(result.get("error", "编队 roster 非法"))
		)
	return {"valid": true}


static func _validate_expedition_attempt(
	attempt: Dictionary,
	allowed_unit_definition_ids: Array
) -> Dictionary:
	if attempt.is_empty():
		return {"valid": true}
	if not _has_exact_keys(attempt, EXPEDITION_ATTEMPT_KEYS):
		return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征尝试字段不完整")
	if (
		typeof(attempt.attempt_id) != TYPE_STRING_NAME
		or StringName(attempt.attempt_id) == &""
		or typeof(attempt.mainline_id) != TYPE_STRING_NAME
		or StringName(attempt.mainline_id) == &""
		or typeof(attempt.phase) != TYPE_STRING_NAME
		or StringName(attempt.phase) not in [
			&"RESERVED", &"ACTIVE", &"APPLIED",
		]
		or typeof(attempt.created_day) != TYPE_INT
		or int(attempt.created_day) <= 0
		or typeof(attempt.created_day_elapsed_milliseconds) != TYPE_INT
		or int(attempt.created_day_elapsed_milliseconds) < 0
		or int(attempt.created_day_elapsed_milliseconds) >= 180000
		or typeof(attempt.food_cost) != TYPE_INT
		or int(attempt.food_cost) <= 0
		or typeof(attempt.food_before) != TYPE_INT
		or typeof(attempt.food_after) != TYPE_INT
		or int(attempt.food_before) < int(attempt.food_cost)
		or int(attempt.food_after) != int(attempt.food_before) - int(attempt.food_cost)
		or typeof(attempt.committed_total) != TYPE_INT
		or int(attempt.committed_total) <= 0
		or typeof(attempt.selected_formations) != TYPE_ARRAY
		or Array(attempt.selected_formations).is_empty()
		or Array(attempt.selected_formations).size() > 3
		or typeof(attempt.committed_force_snapshot) != TYPE_DICTIONARY
		or Dictionary(attempt.committed_force_snapshot).is_empty()
		or typeof(attempt.enemy_force_snapshot) != TYPE_DICTIONARY
		or Dictionary(attempt.enemy_force_snapshot).is_empty()
		or typeof(attempt.city_defense_snapshot) != TYPE_INT
		or int(attempt.city_defense_snapshot) < 0
		or typeof(attempt.first_clear_key) != TYPE_STRING_NAME
		or StringName(attempt.first_clear_key) == &""
		or typeof(attempt.reward_wood) != TYPE_INT
		or typeof(attempt.reward_food) != TYPE_INT
		or int(attempt.reward_wood) < 0
		or int(attempt.reward_food) < 0
		or typeof(attempt.settled) != TYPE_BOOL
		or typeof(attempt.result_id) != TYPE_STRING_NAME
	):
		return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征尝试领域值非法")
	if (
		bool(attempt.settled)
		!= (StringName(attempt.phase) == &"APPLIED")
		or (
			bool(attempt.settled)
			and StringName(attempt.result_id) == &""
		)
		or (
			not bool(attempt.settled)
			and StringName(attempt.result_id) != &""
		)
	):
		return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征尝试结算状态非法")
	var seen_formations: Dictionary = {}
	var seen_squads: Dictionary = {}
	var total := 0
	for formation_value in attempt.selected_formations:
		if not formation_value is Dictionary:
			return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征编队记录非法")
		var formation: Dictionary = formation_value
		if not _has_exact_keys(formation, [
			"formation_id", "display_name", "definition_id",
			"member_count", "max_members", "squad_id", "route_id",
		]):
			return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征编队字段不完整")
		var formation_id := StringName(formation.get("formation_id", &""))
		var definition_id := StringName(formation.get("definition_id", &""))
		var squad_id := int(formation.get("squad_id", 0))
		if (
			formation_id == &""
			or seen_formations.has(formation_id)
			or definition_id not in allowed_unit_definition_ids
			or typeof(formation.display_name) != TYPE_STRING
			or str(formation.display_name).is_empty()
			or typeof(formation.member_count) != TYPE_INT
			or int(formation.member_count) <= 0
			or typeof(formation.max_members) != TYPE_INT
			or int(formation.max_members) < int(formation.member_count)
			or typeof(formation.squad_id) != TYPE_INT
			or squad_id <= 0
			or seen_squads.has(squad_id)
			or typeof(formation.route_id) != TYPE_STRING_NAME
			or StringName(formation.route_id) not in [&"FRONT_GATE", &"SIDE_GATE"]
		):
			return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征编队领域值非法")
		seen_formations[formation_id] = true
		seen_squads[squad_id] = true
		total += int(formation.member_count)
	if total != int(attempt.committed_total):
		return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征编队总数不一致")
	var committed := CommittedForceSnapshot.from_dictionary(
		Dictionary(attempt.committed_force_snapshot)
	)
	var enemy := EnemyForceSnapshot.from_dictionary(
		Dictionary(attempt.enemy_force_snapshot)
	)
	if (
		committed == null
		or enemy == null
		or committed.transaction_id != StringName(attempt.attempt_id)
		or enemy.transaction_id != StringName(attempt.attempt_id)
		or enemy.snapshot_day != int(attempt.created_day)
		or committed.get_committed_total() != int(attempt.committed_total)
		or committed.unit_role_id not in allowed_unit_definition_ids
		or committed.squads.size() != Array(attempt.selected_formations).size()
	):
		return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征战斗快照非法")
	for index in range(committed.squads.size()):
		var squad: Dictionary = committed.squads[index]
		var selected: Dictionary = attempt.selected_formations[index]
		if (
			StringName(squad.formation_id) != StringName(selected.formation_id)
			or str(squad.display_name) != str(selected.display_name)
			or int(squad.squad_id) != int(selected.squad_id)
			or int(squad.initial_members) != int(selected.member_count)
			or StringName(squad.route_id) != StringName(selected.route_id)
		):
			return _failure(&"INVALID_EXPEDITION_ATTEMPT", "出征编队与战斗快照不一致")
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
