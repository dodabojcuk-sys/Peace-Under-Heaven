extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const ReadModel := preload("res://scripts/state/persistent_nation_state_v1.gd")
const V5Adapter := preload(
	"res://scripts/state/v5_national_resource_adapter.gd"
)
const V5Codec := preload("res://scripts/state/v5_campaign_save_codec.gd")
const V5Snapshot := preload("res://scripts/state/v5_campaign_snapshot.gd")

var failures: Array[String] = []
var resource_event_count := 0
var local_event_count := 0
var city_state_event_count := 0
var last_resource_transaction: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var nation: NationState = city.get_nation_state()
	nation.resource_transaction_committed.connect(
		_on_resource_transaction_committed
	)
	nation.city_local_state_changed.connect(_on_city_local_state_changed)
	city.city_state_changed.connect(_on_city_state_changed)

	_check(
		nation != null
			and city.get_nation_state() == nation
			and nation.get_city_ids() == [
				&"blackstone_city",
				&"riverbend_city",
			],
		"生产组合入口只暴露同一个 NationState 和两个稳定城市"
	)
	_check_city_views_and_local_isolation(nation)
	_check_atomic_resource_contract(city, nation)
	_check_production_resource_paths(city, nation)
	_check_p0_01_and_v5_compatibility(city, nation)

	scene.queue_free()
	await process_frame
	_finish()


func _check_city_views_and_local_isolation(nation: NationState) -> void:
	var blackstone := nation.get_city_resource_view(&"blackstone_city")
	var riverbend := nation.get_city_resource_view(&"riverbend_city")
	_check(
		bool(blackstone.success)
			and bool(riverbend.success)
			and blackstone.resources == riverbend.resources,
		"两座城市读取同一国家共享余额"
	)
	blackstone.resources.food = 999999
	_check(
		nation.get_resource(&"food") != 999999,
		"城市资源视图是深度隔离快照"
	)
	var blackstone_local := nation.replace_city_local_state(
		&"blackstone_city",
		{"runtime_note": "blackstone"}
	)
	var riverbend_local := nation.replace_city_local_state(
		&"riverbend_city",
		{"runtime_note": "riverbend"}
	)
	_check(
		bool(blackstone_local.success)
			and bool(riverbend_local.success)
			and local_event_count == 2
			and nation.get_city_state(&"blackstone_city").city.local_state.runtime_note
				== "blackstone"
			and nation.get_city_state(&"riverbend_city").city.local_state.runtime_note
				== "riverbend",
		"blackstone 与 riverbend 的可写局部状态实例双向隔离"
	)
	var detached := nation.get_city_state(&"riverbend_city")
	detached.city.local_state.runtime_note = "mutated"
	_check(
		nation.get_city_state(&"riverbend_city").city.local_state.runtime_note
			== "riverbend",
		"城市局部状态查询不暴露可写引用"
	)
	var forbidden := nation.replace_city_local_state(
		&"riverbend_city",
		{"garrison": {"count": 99}}
	)
	_check(
		not bool(forbidden.success)
			and forbidden.error_id == &"FORBIDDEN_DUPLICATE_AUTHORITY"
			and local_event_count == 2,
		"NationState 拒绝复制现有驻军 authority"
	)


func _check_atomic_resource_contract(
	city: Node,
	nation: NationState
) -> void:
	var spend_entries: Array[Dictionary] = [{
		"resource_id": &"food",
		"operation": NationState.RESOURCE_OPERATION_SPEND,
		"amount": 7,
	}]
	var spent := nation.commit_resource_transaction(
		&"blackstone_city",
		spend_entries,
		&"focused_blackstone_spend"
	)
	_check(
		bool(spent.success)
			and nation.get_city_resource_view(&"blackstone_city").resources.food
				== nation.get_city_resource_view(&"riverbend_city").resources.food
			and resource_event_count == 1,
		"blackstone 消费后 riverbend 立即看到同一余额"
	)
	var add_entries: Array[Dictionary] = [{
		"resource_id": &"wood",
		"operation": NationState.RESOURCE_OPERATION_ADD,
		"amount": 5,
	}]
	var added := nation.commit_resource_transaction(
		&"riverbend_city",
		add_entries,
		&"focused_riverbend_add"
	)
	_check(
		bool(added.success)
			and nation.get_city_resource_view(&"blackstone_city").resources.wood
				== nation.get_city_resource_view(&"riverbend_city").resources.wood
			and resource_event_count == 2,
		"riverbend 变更后 blackstone 立即看到同一余额"
	)

	_check_rejection(
		nation,
		&"missing_city",
		_make_entry(&"food", NationState.RESOURCE_OPERATION_SPEND, 1),
		&"UNKNOWN_CITY",
		"无效 city ID 原子拒绝"
	)
	_check_rejection(
		nation,
		&"blackstone_city",
		_make_entry(&"gold", NationState.RESOURCE_OPERATION_SPEND, 1),
		&"UNKNOWN_RESOURCE",
		"无效 resource ID 原子拒绝"
	)
	_check_rejection(
		nation,
		&"blackstone_city",
		_make_entry(&"food", NationState.RESOURCE_OPERATION_SPEND, 0),
		&"INVALID_AMOUNT",
		"零数量原子拒绝"
	)
	_check_rejection(
		nation,
		&"blackstone_city",
		_make_entry(&"food", NationState.RESOURCE_OPERATION_SPEND, -1),
		&"INVALID_AMOUNT",
		"负数量原子拒绝"
	)
	var non_integer: Array[Dictionary] = [{
		"resource_id": &"food",
		"operation": NationState.RESOURCE_OPERATION_SPEND,
		"amount": 1.5,
	}]
	_check_rejection(
		nation,
		&"blackstone_city",
		non_integer,
		&"INVALID_AMOUNT",
		"非整数数量原子拒绝"
	)
	_check_rejection(
		nation,
		&"blackstone_city",
		_make_entry(
			&"food",
			NationState.RESOURCE_OPERATION_SPEND,
			nation.get_resource(&"food") + 1
		),
		&"INSUFFICIENT_RESOURCE",
		"余额不足原子拒绝"
	)
	var resources_before_local_rejection := nation.get_shared_resources()
	var queue_before_local_rejection: Dictionary = (
		city.get_training_queue_snapshot()
	)
	var resource_events_before_local_rejection := resource_event_count
	var city_events_before_local_rejection := city_state_event_count
	var local_commit_entries := _make_entry(
		&"food",
		NationState.RESOURCE_OPERATION_SPEND,
		1
	)
	var local_rejection := nation.commit_resource_transaction(
		&"blackstone_city",
		local_commit_entries,
		&"focused_local_commit_rejection",
		Callable(self, "_reject_local_commit")
	)
	_check(
		not bool(local_rejection.success)
			and local_rejection.error_id == &"LOCAL_COMMIT_REJECTED"
			and nation.get_shared_resources()
				== resources_before_local_rejection
			and city.get_training_queue_snapshot()
				== queue_before_local_rejection
			and resource_event_count
				== resource_events_before_local_rejection
			and city_state_event_count == city_events_before_local_rejection,
		"局部提交拒绝时资源、队列和全部事件保持零部分写入"
	)


func _check_production_resource_paths(
	city: Node,
	nation: NationState
) -> void:
	city.wood = 200
	city.food = 100
	for cell in [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
	]:
		city.place_definition_at_cell(&"building.road.t1", cell, false)
	var wood_before := nation.get_resource(&"wood")
	var logging_id: int = city.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7),
		true
	)
	_check(
		logging_id > 0
			and nation.get_resource(&"wood") < wood_before
			and last_resource_transaction.reason == &"construction_placement",
		"建造消费经 NationState 事务入口"
	)
	var tech_before := nation.get_resource(&"tech_points")
	_check(
		city.advance_one_day_for_test()
			and nation.get_resource(&"tech_points") == tech_before + 1
			and last_resource_transaction.reason == &"day_end_settlement",
		"日结增减经 NationState 原子事务入口"
	)
	city.food = 100
	var food_before_training := nation.get_resource(&"food")
	var training: Dictionary = city.request_training()
	_check(
		bool(training.success)
			and nation.get_resource(&"food") < food_before_training
			and last_resource_transaction.reason == &"training_order",
		"训练消费经 NationState 事务入口"
	)
	city.tech_points = 10
	var tech_before_research := nation.get_resource(&"tech_points")
	_check(
		city.research_tech(&"tech.stone_tools")
			and nation.get_resource(&"tech_points") < tech_before_research
			and last_resource_transaction.reason == &"technology_research",
		"科研消费经 NationState 事务入口"
	)


func _check_p0_01_and_v5_compatibility(
	city: Node,
	nation: NationState
) -> void:
	var read_model := ReadModel.read(city)
	_check(
		bool(read_model.success)
			and read_model.state.city_ids == [&"blackstone_city"]
			and read_model.state.shared_resources
				== nation.get_shared_resources(),
		"P0-01 保持一城接口并从 NationState 读取共享资源"
	)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		not snapshot.is_empty()
			and snapshot.schema_version == V5Snapshot.SCHEMA_VERSION
			and V5Snapshot.SCHEMA_VERSION == 2
			and int(snapshot.city.wood) == nation.get_resource(&"wood")
			and int(snapshot.city.food) == nation.get_resource(&"food")
			and int(snapshot.city.tech_points)
				== nation.get_resource(&"tech_points"),
		"V5 blackstone 旧字段只承载 NationState 资源投影"
	)
	var hydration_dto := V5Adapter.extract_legacy_city_resources(
		snapshot.city
	)
	hydration_dto.food = 999999
	_check(
		nation.get_resource(&"food") != 999999,
		"V5 临时 DTO 不会成为运行时第二账本"
	)
	var encoded := V5Codec.encode_snapshot(
		snapshot,
		1,
		Callable(city, "validate_v5_campaign_snapshot")
	)
	var decoded := V5Codec.decode_storage_text(
		str(encoded.get("storage_text", "")),
		Callable(city, "validate_v5_campaign_snapshot")
	)
	city.food = 1
	var restored: Dictionary = city.restore_v5_campaign_snapshot(
		decoded.snapshot
	)
	_check(
		bool(encoded.success)
			and bool(decoded.success)
			and bool(restored.success)
			and nation.get_shared_resources()
				== V5Adapter.extract_legacy_city_resources(snapshot.city)
			and city.export_v5_campaign_snapshot() == snapshot,
		"旧 V5 topology 经 codec save-load 后水合回唯一国家账本"
	)


func _check_rejection(
	nation: NationState,
	city_id: StringName,
	entries: Array[Dictionary],
	expected_error: StringName,
	message: String
) -> void:
	var before := _full_state_fingerprint(nation)
	var events_before := resource_event_count
	var result := nation.commit_resource_transaction(
		city_id,
		entries,
		&"focused_rejection"
	)
	_check(
		not bool(result.success)
			and result.error_id == expected_error
			and _full_state_fingerprint(nation) == before
			and resource_event_count == events_before,
		message
	)


func _make_entry(
	resource_id: StringName,
	operation: StringName,
	amount: int
) -> Array[Dictionary]:
	return [{
		"resource_id": resource_id,
		"operation": operation,
		"amount": amount,
	}]


func _full_state_fingerprint(nation: NationState) -> String:
	return var_to_str({
		"resources": nation.get_shared_resources(),
		"blackstone": nation.get_city_state(&"blackstone_city"),
		"riverbend": nation.get_city_state(&"riverbend_city"),
	})


func _on_resource_transaction_committed(transaction: Dictionary) -> void:
	resource_event_count += 1
	last_resource_transaction = transaction.duplicate(true)


func _on_city_local_state_changed(
	_city_id: StringName,
	_state: Dictionary
) -> void:
	local_event_count += 1


func _on_city_state_changed() -> void:
	city_state_event_count += 1


func _reject_local_commit() -> bool:
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("R2C01_NATIONAL_RESOURCE_CONVERGENCE_SMOKE PASS")
		quit(0)
		return
	print("R2C01_NATIONAL_RESOURCE_CONVERGENCE_SMOKE FAIL: %s" % failures)
	quit(1)
