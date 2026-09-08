extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可加载")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var theater: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	city.set_process(false)
	var definition_id: StringName = city.INFANTRY_ROLE.role_id
	var adapter: V5ArmyDispatchAdapter = (
		city.get_v5_army_dispatch_adapter()
	)
	var read_model := adapter.get_dispatch_read_model()
	_check(
		read_model.city_id == &"blackstone_city"
			and read_model.unit_definition_id == definition_id
			and read_model.garrison_count == 20
			and read_model.dispatchable_count == 20,
		"V4 窄适配层只读真实城市驻军和权威可派数"
	)
	_check(
		theater != null and theater.visible == false,
		"旧黑石堡原型入口已由只读投影的宏观军令界面替换"
	)

	city.recruitment_cap = 10
	var rejected_before := _world_truth(city)
	_check(
		adapter.reserve_dispatch(
			12,
			&"blackstone_fortress",
			&"route.blackstone_fortress",
			6000
		).is_empty()
			and _world_truth(city) == rejected_before,
		"权威可派 10 人时适配层拒绝预留 12 人且零写入"
	)
	city.recruitment_cap = 50
	var reservation := adapter.reserve_dispatch(
		10,
		&"blackstone_fortress",
		&"route.blackstone_fortress",
		6000
	)
	_check(
		reservation.transaction_id == &"dispatch.blackstone.000001"
			and reservation.committed_count == 10
			and city.infantry_count == 20
			and city.get_dispatchable_infantry_count() == 10,
		"预留分配稳定事务 ID，不提前扣驻军且减少可派投影"
	)
	var reserved_truth := _world_truth(city)
	_check(
		not adapter.cancel_dispatch(&"dispatch.wrong")
			and _world_truth(city) == reserved_truth,
		"错误事务不能取消或改写派遣预留"
	)
	_check(
		adapter.cancel_dispatch(StringName(reservation.transaction_id))
			and city.infantry_count == 20
			and city.get_dispatchable_infantry_count() == 20
			and city.get_active_army_dispatch_reservation().is_empty(),
		"正式取消只释放预留，驻军总数保持不变"
	)

	var failure_reservation := adapter.reserve_dispatch(
		10,
		&"blackstone_fortress",
		&"route.blackstone_fortress",
		6000
	)
	city.infantry_count = 5
	var registry_before_failure: Dictionary = (
		city.get_army_registry_snapshot()
	)
	var failed_confirm := adapter.confirm_dispatch(
		StringName(failure_reservation.transaction_id)
	)
	_check(
		failed_confirm.is_empty()
			and city.infantry_count == 5
			and city.get_army_registry_snapshot()
				== registry_before_failure
			and city.get_active_army_dispatch_reservation()
				== failure_reservation,
		"确认期驻军故障回滚 registry 序列且保留可取消预留"
	)
	_check(
		adapter.cancel_dispatch(
			StringName(failure_reservation.transaction_id)
		),
		"故障回滚后的预留仍可通过正式事务取消"
	)

	city.infantry_count = 20
	var committed_reservation := adapter.reserve_dispatch(
		10,
		&"blackstone_fortress",
		&"route.blackstone_fortress",
		6000
	)
	var army := adapter.confirm_dispatch(
		StringName(committed_reservation.transaction_id)
	)
	_check(
		army.army_id == &"army.player.000001"
			and army.phase == ArmyRegistry.PHASE_MARCHING
			and army.transaction_id
				== committed_reservation.transaction_id
			and army.units_by_definition_id[definition_id] == 10,
		"确认命令创建稳定 ArmyState 并原子进入 MARCHING"
	)
	_check(
		city.infantry_count == 10
			and city.get_committed_world_infantry_total() == 20
			and city.get_active_armies().size() == 1,
		"驻军只扣一次且城市加 active army 保持总兵力守恒"
	)
	var committed_truth := _world_truth(city)
	_check(
		adapter.confirm_dispatch(
			StringName(committed_reservation.transaction_id)
		).is_empty()
			and _world_truth(city) == committed_truth,
		"重复确认不能二次扣兵或创建第二支军队"
	)
	_check(
		adapter.reserve_dispatch(
			1,
			&"north_slope",
			&"route.blackstone_north_slope",
			1000
		).is_empty()
			and _world_truth(city) == committed_truth,
		"V5 单 active 政策拒绝第二支活动军队且零写入"
	)

	var registry_snapshot: Dictionary = city.get_army_registry_snapshot()
	_check(
		registry_snapshot.schema_version == ArmyRegistry.SCHEMA_VERSION
			and registry_snapshot.next_army_sequence == 2
			and registry_snapshot.next_macro_order_sequence == 1
			and registry_snapshot.armies_by_id.size() == 1
			and not registry_snapshot.has("active_army"),
		"权威持久模型是 armies_by_id 集合，不固化 singleton"
	)
	_check(
		not _contains_forbidden_persistence_value(registry_snapshot)
			and not _contains_forbidden_persistence_key(
				registry_snapshot
			),
		"ArmyState 不持久 Node、像素坐标、UI 或表现状态"
	)
	var projection := adapter.get_army_projection(
		StringName(army.army_id)
	)
	_check(
		projection.unique_id == army.army_id
			and projection.total_count == 10
			and projection.progress == 0.0
			and not projection.has("source_position")
			and not projection.has("target_position"),
		"V4 表现投影只从 stable route/node ID 和整数进度派生"
	)
	projection.troop_counts[definition_id] = 999
	_check(
		city.get_army_state(
			StringName(army.army_id)
		).units_by_definition_id[definition_id] == 10,
		"表现投影深拷贝，不能旁路修改 ArmyState"
	)

	var registry_reentry := ArmyRegistry.new()
	_check(
		registry_reentry.restore_snapshot(
			registry_snapshot,
			[definition_id]
		)
			and registry_reentry.get_army(
				StringName(army.army_id)
			) == city.get_army_state(StringName(army.army_id)),
		"场景重进适配器可从同一持久集合重建相同 ArmyState"
	)

	var partial: Dictionary = city.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		0,
		2500
	)
	_check(
		partial.success
			and not partial.arrived
			and partial.army.progress_milliseconds == 2500
			and partial.army.phase == ArmyRegistry.PHASE_MARCHING,
		"城市战略时间按整数毫秒推进在途军队"
	)
	var partial_truth := _world_truth(city)
	_check(
		city.advance_army_strategic_time(
			StringName(army.army_id),
			StringName(army.transaction_id),
			0,
			2500
		).is_empty()
			and _world_truth(city) == partial_truth,
		"相同 expected progress 的重复帧被防重入且零写入"
	)
	var arrival: Dictionary = city.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		2500,
		9000
	)
	_check(
		arrival.success
			and arrival.arrived
			and arrival.army.progress_milliseconds == 6000
			and arrival.army.phase == ArmyRegistry.PHASE_ARRIVED,
		"抵达由整数进度触发一次 ARRIVED 状态转换"
	)
	var arrival_truth := _world_truth(city)
	_check(
		city.advance_army_strategic_time(
			StringName(army.army_id),
			StringName(army.transaction_id),
			6000,
			1
		).is_empty()
			and _world_truth(city) == arrival_truth,
		"重复 frame、信号或重进不能二次抵达"
	)
	_check(
		city.mark_army_settlement_pending(
			StringName(army.army_id),
			StringName(army.transaction_id)
		)
			and not city.mark_army_settlement_pending(
				StringName(army.army_id),
				StringName(army.transaction_id)
			),
		"抵达只可一次进入 SETTLEMENT_PENDING"
	)
	_check(
		city.get_committed_world_infantry_total() == 20,
		"到达和等待结算期间总兵力仍守恒"
	)

	var closed_registry := ArmyRegistry.new()
	var closed_one := closed_registry.create_reserved(
		&"player",
		&"blackstone_city",
		&"blackstone_city",
		&"node.a",
		&"route.a",
		{definition_id: 1},
		1000,
		&"txn.closed.1"
	)
	_check(
		closed_registry.transition(
			StringName(closed_one.army_id),
			&"txn.closed.1",
			ArmyRegistry.PHASE_RESERVED,
			ArmyRegistry.PHASE_CLOSED
		),
		"首个已取消记录可保留为 CLOSED 审计事实"
	)
	var closed_two := closed_registry.create_reserved(
		&"player",
		&"blackstone_city",
		&"blackstone_city",
		&"node.b",
		&"route.b",
		{definition_id: 2},
		1000,
		&"txn.closed.2"
	)
	_check(
		closed_registry.transition(
			StringName(closed_two.army_id),
			&"txn.closed.2",
			ArmyRegistry.PHASE_RESERVED,
			ArmyRegistry.PHASE_CLOSED
		)
			and closed_registry.get_snapshot().armies_by_id.size() == 2,
		"集合可保留多个 CLOSED 记录，不退化为 singleton"
	)

	var lifted_candidate: Dictionary = registry_snapshot.duplicate(true)
	var second_active: Dictionary = (
		lifted_candidate.armies_by_id[army.army_id].duplicate(true)
	)
	second_active.army_id = &"army.player.000002"
	second_active.transaction_id = &"dispatch.blackstone.000002"
	lifted_candidate.armies_by_id[second_active.army_id] = second_active
	lifted_candidate.next_army_sequence = 3
	var enforced := ArmyRegistry.validate_snapshot(
		lifted_candidate,
		[definition_id],
		true
	)
	var lifted := ArmyRegistry.validate_snapshot(
		lifted_candidate,
		[definition_id],
		false
	)
	_check(
		not enforced.valid
			and enforced.error_id == &"V5_ACTIVE_ARMY_LIMIT"
			and lifted.valid
			and lifted.snapshot.schema_version == ArmyRegistry.SCHEMA_VERSION,
		"解除 V5 policy 后同一 schema 可容纳两支 active army"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _world_truth(city: Node) -> Dictionary:
	return {
		"garrison": city.infantry_count,
		"reservation": city.get_active_army_dispatch_reservation(),
		"registry": city.get_army_registry_snapshot(),
		"world_total": city.get_committed_world_infantry_total(),
	}


func _contains_forbidden_persistence_key(value) -> bool:
	if value is Dictionary:
		for key in value:
			var key_text := String(key).to_lower()
			if (
				"position" in key_text
				or "pixel" in key_text
				or "camera" in key_text
				or "selected" in key_text
				or "ui_" in key_text
			):
				return true
			if _contains_forbidden_persistence_key(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_persistence_key(item):
				return true
	return false


func _contains_forbidden_persistence_value(value) -> bool:
	if value is Node or value is Resource or value is Callable:
		return true
	if value is Dictionary:
		for nested in value.values():
			if _contains_forbidden_persistence_value(nested):
				return true
	elif value is Array:
		for nested in value:
			if _contains_forbidden_persistence_value(nested):
				return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("V5_ARMY_STATE_SMOKE PASS")
		quit(0)
		return
	print("V5_ARMY_STATE_SMOKE FAIL: %s" % [failures])
	quit(1)
