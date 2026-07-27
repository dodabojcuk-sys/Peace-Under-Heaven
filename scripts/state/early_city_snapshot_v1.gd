class_name EarlyCitySnapshotV1
extends RefCounted


const SCHEMA_VERSION := 1
const SNAPSHOT_KIND := &"early_city_authoritative"
const CITY_ID := "blackstone_city"
const ROOT_KEYS := [
	"schema_version",
	"snapshot_kind",
	"city_id",
	"city",
	"placements",
	"next_placement_id",
]
const CITY_KEYS := [
	"current_day",
	"day_elapsed_seconds",
	"wood",
	"food",
	"tech_points",
	"infantry_count",
	"recruitment_cap",
	"selected_general_id",
	"training_queued_count",
	"training_complete_day",
	"last_training_order_day",
	"researched_tech_ids",
	"supply_shortage",
	"emergency_mobilization_used",
	"city_time_paused",
	"city_time_speed",
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
const ALLOWED_LIFECYCLE_STATES := [&"constructing", &"running"]


static func validate_structure(snapshot: Dictionary) -> Dictionary:
	if not _has_exact_keys(snapshot, ROOT_KEYS):
		return _failure("快照根字段不完整或包含未知字段")
	if (
		typeof(snapshot.schema_version) != TYPE_INT
		or int(snapshot.schema_version) != SCHEMA_VERSION
	):
		return _failure("不支持的内存快照版本")
	if (
		typeof(snapshot.snapshot_kind) != TYPE_STRING_NAME
		or StringName(snapshot.snapshot_kind) != SNAPSHOT_KIND
	):
		return _failure("快照类型不匹配")
	if (
		typeof(snapshot.city_id) != TYPE_STRING
		or str(snapshot.city_id).is_empty()
	):
		return _failure("city_id 必须是非空 String")
	if typeof(snapshot.city) != TYPE_DICTIONARY:
		return _failure("city 必须是 Dictionary")
	if typeof(snapshot.placements) != TYPE_ARRAY:
		return _failure("placements 必须是 Array")
	if typeof(snapshot.next_placement_id) != TYPE_INT:
		return _failure("next_placement_id 必须是 int")

	var city: Dictionary = snapshot.city
	if not _has_exact_keys(city, CITY_KEYS):
		return _failure("city 字段不完整或包含未知字段")
	var city_result := _validate_city(city)
	if not bool(city_result.valid):
		return city_result

	var placement_ids: Dictionary = {}
	var previous_placement_id := 0
	for index in range(snapshot.placements.size()):
		var placement_value = snapshot.placements[index]
		if typeof(placement_value) != TYPE_DICTIONARY:
			return _failure("placement %d 必须是 Dictionary" % index)
		var placement: Dictionary = placement_value
		var placement_result := _validate_placement(placement, index)
		if not bool(placement_result.valid):
			return placement_result
		var placement_id := int(placement.placement_id)
		if placement_ids.has(placement_id):
			return _failure("placement_id %d 重复" % placement_id)
		if placement_id <= previous_placement_id:
			return _failure("placements 必须按 placement_id 严格递增")
		placement_ids[placement_id] = true
		previous_placement_id = placement_id

	var next_placement_id := int(snapshot.next_placement_id)
	if next_placement_id <= 0:
		return _failure("next_placement_id 必须为正数")
	if (
		not placement_ids.is_empty()
		and next_placement_id <= previous_placement_id
	):
		return _failure("next_placement_id 必须大于所有运行时 placement_id")
	return {
		"valid": true,
		"error": "",
		"snapshot": snapshot.duplicate(true),
	}


static func validate_with_context(
	snapshot: Dictionary,
	context: Dictionary
) -> Dictionary:
	var structural := validate_structure(snapshot)
	if not bool(structural.valid):
		return structural
	var normalized: Dictionary = structural.snapshot
	var city: Dictionary = normalized.city
	var generals: Dictionary = context.generals_by_id
	var techs: Dictionary = context.tech_by_id
	var definitions: Dictionary = context.definitions_by_id
	if str(normalized.city_id) != str(context.city_id):
		return _failure("快照城市身份不匹配")
	var selected_general := StringName(city.selected_general_id)
	if selected_general != &"" and not generals.has(selected_general):
		return _failure("快照引用未知将领")
	var researched_ids: Array = city.researched_tech_ids
	for tech_id_value in researched_ids:
		var tech_id := StringName(tech_id_value)
		var tech := techs.get(tech_id) as TechNode
		if tech == null:
			return _failure("快照引用未知科技")
		for prerequisite_id in tech.prerequisite_ids:
			if prerequisite_id not in researched_ids:
				return _failure(
					"科技 %s 缺少前置 %s" % [tech_id, prerequisite_id]
				)
	if bool(city.emergency_mobilization_used):
		return _failure("早期城市快照不得包含紧急动员结果")
	var city_context_error := _validate_city_context(city, context)
	if not city_context_error.is_empty():
		return _failure(city_context_error)

	var candidate_occupied: Dictionary = (
		context.fixed_occupied_cells.duplicate()
	)
	var fixed_placement_ids: Dictionary = context.fixed_placement_ids
	var map_grid_size := Vector2i(context.map_grid_size)
	var max_placement_id := int(context.max_fixed_placement_id)
	var wood_capacity := int(context.base_resource_capacity)
	var food_capacity := int(context.base_resource_capacity)
	var road_cells: Dictionary = {}
	var definitions_by_placement: Dictionary = {}
	var placements_by_id: Dictionary = {}
	for placement_value in normalized.placements:
		var placement: Dictionary = placement_value
		var placement_id := int(placement.placement_id)
		if fixed_placement_ids.has(placement_id):
			return _failure("运行时 placement_id 与固定建筑冲突")
		var definition := definitions.get(
			StringName(placement.definition_id)
		) as BuildingDefinition
		if (
			definition == null
			or definition.placement_kind not in [&"placed", &"road"]
		):
			return _failure("快照引用未知建筑定义")
		var origin_cell := Vector2i(placement.origin_cell)
		if not _footprint_is_inside_map(
			origin_cell,
			definition.footprint,
			map_grid_size
		):
			return _failure("快照建筑超出地图")
		for cell in _get_footprint_cells(
			origin_cell,
			definition.footprint
		):
			if candidate_occupied.has(cell):
				return _failure("快照建筑占用格冲突")
			candidate_occupied[cell] = placement_id
		var placement_error := _validate_placement_dates(
			placement,
			definition,
			int(city.current_day)
		)
		if not placement_error.is_empty():
			return _failure(placement_error)
		placements_by_id[placement_id] = placement
		definitions_by_placement[placement_id] = definition
		if definition.placement_kind == &"road":
			for road_cell in _get_footprint_cells(
				origin_cell,
				definition.footprint
			):
				road_cells[road_cell] = true
		if StringName(placement.lifecycle_state) == &"running":
			var storage := definition.get_capability(&"storage")
			if storage != null:
				if storage.resource_id in [&"wood", &"wood_food"]:
					wood_capacity += storage.amount
				if storage.resource_id in [&"food", &"wood_food"]:
					food_capacity += storage.amount
		max_placement_id = maxi(max_placement_id, placement_id)

	if int(normalized.next_placement_id) <= max_placement_id:
		return _failure(
			"next_placement_id 未超过全部固定和运行时记录"
		)
	if int(city.wood) > wood_capacity or int(city.food) > food_capacity:
		return _failure("资源数量超过快照建筑可派生的容量")
	var connected_roads := _derive_connected_roads(
		road_cells,
		context.road_root_cells
	)
	var operational_by_id: Dictionary = {}
	var derived_wood_capacity := int(context.base_resource_capacity)
	var derived_food_capacity := int(context.base_resource_capacity)
	for placement_id in placements_by_id:
		var placement: Dictionary = placements_by_id[placement_id]
		var definition: BuildingDefinition = definitions_by_placement[
			placement_id
		]
		var operational := _is_placement_operational(
			placement,
			definition,
			int(city.current_day),
			connected_roads
		)
		operational_by_id[placement_id] = operational
		if operational:
			var storage := definition.get_capability(&"storage")
			if storage != null:
				if storage.resource_id in [&"wood", &"wood_food"]:
					derived_wood_capacity += storage.amount
				if storage.resource_id in [&"food", &"wood_food"]:
					derived_food_capacity += storage.amount
	return {
		"valid": true,
		"error": "",
		"snapshot": normalized.duplicate(true),
		"derived": {
			"occupied_cells": candidate_occupied.duplicate(true),
			"connected_road_cells": connected_roads.duplicate(true),
			"operational_by_id": operational_by_id.duplicate(true),
			"wood_capacity": derived_wood_capacity,
			"food_capacity": derived_food_capacity,
		},
	}


static func _validate_city(city: Dictionary) -> Dictionary:
	for key in [
		"current_day",
		"wood",
		"food",
		"tech_points",
		"infantry_count",
		"recruitment_cap",
		"training_queued_count",
		"training_complete_day",
		"last_training_order_day",
	]:
		if typeof(city[key]) != TYPE_INT:
			return _failure("city.%s 必须是 int" % key)
	if typeof(city.day_elapsed_seconds) != TYPE_FLOAT:
		return _failure("city.day_elapsed_seconds 必须是 float")
	if typeof(city.selected_general_id) != TYPE_STRING_NAME:
		return _failure("city.selected_general_id 必须是 StringName")
	if typeof(city.researched_tech_ids) != TYPE_ARRAY:
		return _failure("city.researched_tech_ids 必须是 Array")
	for key in [
		"supply_shortage",
		"emergency_mobilization_used",
		"city_time_paused",
	]:
		if typeof(city[key]) != TYPE_BOOL:
			return _failure("city.%s 必须是 bool" % key)
	if typeof(city.city_time_speed) != TYPE_FLOAT:
		return _failure("city.city_time_speed 必须是 float")

	var current_day := int(city.current_day)
	if current_day < 1 or current_day >= 7:
		return _failure("S1A.1 只接受第 1 至第 6 日的早期城市状态")
	var elapsed := float(city.day_elapsed_seconds)
	if not is_finite(elapsed):
		return _failure("日内进度必须是有限数值")
	for key in ["wood", "food", "tech_points", "infantry_count"]:
		if int(city[key]) < 0:
			return _failure("city.%s 不得为负数" % key)
	if int(city.recruitment_cap) <= 0:
		return _failure("recruitment_cap 必须为正数")
	if int(city.infantry_count) > int(city.recruitment_cap):
		return _failure("infantry_count 不得超过 recruitment_cap")
	var queued_count := int(city.training_queued_count)
	var complete_day := int(city.training_complete_day)
	var last_order_day := int(city.last_training_order_day)
	if queued_count < 0 or complete_day < 0 or last_order_day < 0:
		return _failure("征募队列日期和数量不得为负数")
	if queued_count == 0 and complete_day != 0:
		return _failure("空闲征募队列的完成日必须为 0")
	if last_order_day > current_day:
		return _failure("last_training_order_day 不得晚于当前日期")

	var seen_tech_ids: Dictionary = {}
	for tech_id_value in city.researched_tech_ids:
		if (
			typeof(tech_id_value) != TYPE_STRING_NAME
			or StringName(tech_id_value) == &""
		):
			return _failure("科技 ID 必须是非空 StringName")
		var tech_id := StringName(tech_id_value)
		if seen_tech_ids.has(tech_id):
			return _failure("科技 ID %s 重复" % tech_id)
		seen_tech_ids[tech_id] = true
	return {"valid": true, "error": ""}


static func _validate_city_context(
	city: Dictionary,
	context: Dictionary
) -> String:
	var current_day := int(city.current_day)
	var elapsed := float(city.day_elapsed_seconds)
	var seconds_per_day := float(context.seconds_per_day)
	if elapsed < 0.0 or elapsed >= seconds_per_day:
		return "日内进度必须位于 [0, %s)" % seconds_per_day
	var speed := float(city.city_time_speed)
	if not is_finite(speed) or speed not in context.allowed_time_speeds:
		return "city_time_speed 不在允许范围"
	var queued_count := int(city.training_queued_count)
	if queued_count <= 0:
		if int(city.last_training_order_day) >= current_day:
			return "空闲征募队列的最近下单日必须早于当前日"
		return ""
	if queued_count not in context.allowed_training_batches:
		return "征募队列数量与当前权威批量不一致"
	if int(city.training_complete_day) != current_day + 1:
		return "活动征募队列必须在下一日完成"
	if int(city.last_training_order_day) != current_day:
		return "活动征募队列的下单日必须是当前日"
	if int(city.infantry_count) + queued_count > int(city.recruitment_cap):
		return "征募完成后步兵数将超过征募上限"
	return ""


static func _validate_placement(
	placement: Dictionary,
	index: int
) -> Dictionary:
	if not _has_exact_keys(placement, PLACEMENT_KEYS):
		return _failure("placement %d 字段不完整或包含未知字段" % index)
	for key in [
		"placement_id",
		"built_day",
		"disabled_until_day",
		"construction_started_day",
		"construction_complete_day",
	]:
		if typeof(placement[key]) != TYPE_INT:
			return _failure("placement %d.%s 必须是 int" % [index, key])
	if typeof(placement.definition_id) != TYPE_STRING_NAME:
		return _failure("placement %d.definition_id 必须是 StringName" % index)
	if typeof(placement.origin_cell) != TYPE_VECTOR2I:
		return _failure("placement %d.origin_cell 必须是 Vector2i" % index)
	if typeof(placement.lifecycle_state) != TYPE_STRING_NAME:
		return _failure(
			"placement %d.lifecycle_state 必须是 StringName" % index
		)
	if int(placement.placement_id) <= 0:
		return _failure("placement %d 的 ID 必须为正数" % index)
	if StringName(placement.definition_id) == &"":
		return _failure("placement %d 的 definition_id 不能为空" % index)
	if (
		StringName(placement.lifecycle_state)
		not in ALLOWED_LIFECYCLE_STATES
	):
		return _failure("placement %d 的生命周期非法" % index)
	for key in [
		"built_day",
		"disabled_until_day",
		"construction_started_day",
		"construction_complete_day",
	]:
		if int(placement[key]) < 0:
			return _failure("placement %d.%s 不得为负数" % [index, key])
	return {"valid": true, "error": ""}


static func _validate_placement_dates(
	placement: Dictionary,
	definition: BuildingDefinition,
	snapshot_day: int
) -> String:
	var built_day := int(placement.built_day)
	var started_day := int(placement.construction_started_day)
	var complete_day := int(placement.construction_complete_day)
	var lifecycle := StringName(placement.lifecycle_state)
	if built_day < 1 or built_day > snapshot_day:
		return "建筑 built_day 与快照日期不一致"
	if started_day != built_day:
		return "施工开始日必须等于建造日"
	if complete_day != started_day + definition.build_days:
		return "施工完成日与建筑定义不一致"
	if definition.build_days <= 0 and lifecycle != &"running":
		return "即时建筑必须处于运行状态"
	if lifecycle == &"constructing" and complete_day <= snapshot_day:
		return "已到完成日的建筑不能仍处于施工状态"
	if lifecycle == &"running" and complete_day > snapshot_day:
		return "未到完成日的建筑不能提前运行"
	return ""


static func _derive_connected_roads(
	road_cells: Dictionary,
	root_cells: Array
) -> Dictionary:
	var connected: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for root_value in root_cells:
		var root_cell := Vector2i(root_value)
		if road_cells.has(root_cell):
			connected[root_cell] = true
			frontier.append(root_cell)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]:
			var neighbor: Vector2i = current + Vector2i(direction)
			if road_cells.has(neighbor) and not connected.has(neighbor):
				connected[neighbor] = true
				frontier.append(neighbor)
	return connected


static func _is_placement_operational(
	placement: Dictionary,
	definition: BuildingDefinition,
	current_day: int,
	connected_roads: Dictionary
) -> bool:
	var origin_cell := Vector2i(placement.origin_cell)
	if definition.placement_kind == &"road":
		return connected_roads.has(origin_cell)
	if StringName(placement.lifecycle_state) != &"running":
		return false
	if int(placement.disabled_until_day) >= current_day:
		return false
	if not definition.requires_road:
		return true
	for offset in definition.road_anchor_offsets:
		if connected_roads.has(origin_cell + Vector2i(offset)):
			return true
	return false


static func get_expected_threat(
	day: int,
	threat_schedule: ThreatSchedule
) -> Dictionary:
	var result := {
		"enemy_count": 32,
		"enemy_fortification": 0,
	}
	var latest_day := 0
	for threat_event in threat_schedule.events:
		if threat_event.day <= day and threat_event.day >= latest_day:
			result.enemy_count = threat_event.enemy_count
			result.enemy_fortification = threat_event.fortification_level
			latest_day = threat_event.day
	return result


static func _footprint_is_inside_map(
	origin_cell: Vector2i,
	footprint: Vector2i,
	map_grid_size: Vector2i
) -> bool:
	return (
		origin_cell.x >= 0
		and origin_cell.y >= 0
		and origin_cell.x + footprint.x <= map_grid_size.x
		and origin_cell.y + footprint.y <= map_grid_size.y
	)


static func _get_footprint_cells(
	origin_cell: Vector2i,
	footprint: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(footprint.y):
		for x in range(footprint.x):
			cells.append(origin_cell + Vector2i(x, y))
	return cells


static func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(key):
			return false
	return true


static func _failure(error: String) -> Dictionary:
	return {
		"valid": false,
		"error": error,
		"snapshot": {},
	}
