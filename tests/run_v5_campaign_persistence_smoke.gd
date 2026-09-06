extends SceneTree


const COLD_WORKER_PATH := "res://tests/v5_campaign_save_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_root := "%s/txwzs-v5-save-%d-%d" % [
		OS.get_temp_dir(),
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	_remove_tree(test_root)
	_check(
		DirAccess.make_dir_recursive_absolute(test_root) == OK,
		"创建隔离 V5 存档目录"
	)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可加载")
	if packed_scene == null:
		_finish(test_root)
		return
	var source_scene := packed_scene.instantiate()
	root.add_child(source_scene)
	await process_frame
	await process_frame
	var source: Node = source_scene.get_node("ConstructionController")
	source.set_process(false)
	source.day_elapsed_seconds = 37.5
	source.set_city_time_paused(true)
	_check(source.queue_training(), "V1 源建立活动训练队列")
	var v1_active: Dictionary = source.export_early_city_snapshot()
	var v1_source_text := var_to_str(v1_active)
	var migrated: Dictionary = source.migrate_v1_snapshot_to_v5(v1_active)
	_check(
		migrated.success
			and migrated.snapshot.schema_version == 6
			and migrated.snapshot.snapshot_kind
				== &"campaign_authoritative",
		"有效 V1 只读输入确定性迁移为 schema 6、默认北向并补齐永久 roster"
	)
	var v2_active: Dictionary = migrated.snapshot
	_check(
		not v2_active.city.has("infantry_count")
			and not v2_active.city.has("training_queued_count")
			and v2_active.garrison.unit_counts_by_definition_id[
				source.INFANTRY_ROLE.role_id
			] == 20
			and Array(v2_active.garrison.formation_order).size() == 3
			and Dictionary(v2_active.garrison.formations_by_id).size() == 3
			and _roster_total(v2_active.garrison) == 20
			and v2_active.training_queue.active_order_id
				== &"training.blackstone_city.000001",
		"V1 步兵与训练三字段只迁移到唯一 Garrison roster/TrainingQueue 源"
	)
	_check(
		v2_active.army_registry.armies_by_id.is_empty()
			and v2_active.settlement_ledger
				.committed_results_by_id.is_empty()
			and v2_active.city.day_elapsed_milliseconds == 37500,
		"V1 迁移产生空军队/结算集合并保留精确时间"
	)
	var stale_training_sequence := v2_active.duplicate(true)
	stale_training_sequence.training_queue.next_order_sequence = 1
	_check(
		not source.validate_v5_campaign_snapshot(
			stale_training_sequence
		).valid,
		"V2 拒绝会在恢复后复用既有训练 order ID 的倒退序列"
	)
	var migrated_again: Dictionary = (
		source.migrate_v1_snapshot_to_v5(v1_active)
	)
	_check(
		migrated_again.success
			and migrated_again.snapshot == v2_active
			and var_to_str(v1_active) == v1_source_text,
		"重复迁移幂等且不修改 V1 输入"
	)
	var invalid_v1 := v1_active.duplicate(true)
	invalid_v1.schema_version = 99
	var live_before_invalid: Dictionary = (
		source.export_v5_campaign_snapshot()
	)
	var invalid_migration: Dictionary = (
		source.migrate_v1_snapshot_to_v5(invalid_v1)
	)
	_check(
		not invalid_migration.success
			and invalid_migration.error_id == &"INVALID_V1_SOURCE"
			and source.export_v5_campaign_snapshot()
				== live_before_invalid,
		"未知 V1 schema 拒绝且不污染 live authority"
	)
	var forbidden_v2 := v2_active.duplicate(true)
	forbidden_v2.settlement_ledger.committed_results_by_id[
		&"forbidden.node"
	] = source
	var forbidden_before: Dictionary = (
		source.export_v5_campaign_snapshot()
	)
	var forbidden_restore: Dictionary = (
		source.restore_v5_campaign_snapshot(forbidden_v2)
	)
	_check(
		not forbidden_restore.success
			and forbidden_restore.error_id
				== &"FORBIDDEN_PERSISTENCE_VALUE"
			and source.export_v5_campaign_snapshot() == forbidden_before,
		"Node 注入在首次写入前拒绝且 live authority 零写入"
	)

	var empty_scene := packed_scene.instantiate()
	root.add_child(empty_scene)
	await process_frame
	await process_frame
	var empty_source: Node = empty_scene.get_node("ConstructionController")
	empty_source.set_process(false)
	var v1_empty: Dictionary = empty_source.export_early_city_snapshot()
	var empty_migration: Dictionary = (
		empty_source.migrate_v1_snapshot_to_v5(v1_empty)
	)
	_check(
		empty_migration.success
			and empty_migration.snapshot.training_queue
				.active_order_id == &""
			and empty_migration.snapshot.training_queue
				.orders_by_id.is_empty(),
		"空训练 V1 确定性迁移为空 TrainingQueue 集合"
	)
	var v1_empty_with_history := v1_empty.duplicate(true)
	v1_empty_with_history.city.current_day = 2
	v1_empty_with_history.city.last_training_order_day = 1
	var historical_v1_text := var_to_str(v1_empty_with_history)
	var empty_live_before: Dictionary = (
		empty_source.export_v5_campaign_snapshot()
	)
	var historical_empty_migration: Dictionary = (
		empty_source.migrate_v1_snapshot_to_v5(
			v1_empty_with_history
		)
	)
	_check(
		historical_empty_migration.success
			and historical_empty_migration.snapshot.training_queue
				.orders_by_id.is_empty()
			and historical_empty_migration.snapshot.training_queue
				.last_order_day == 1
			and var_to_str(v1_empty_with_history) == historical_v1_text
			and empty_source.export_v5_campaign_snapshot()
				== empty_live_before,
		"无 active order 但保留训练历史日的合法 V1 只读迁移成功"
	)

	for invalid_sequence in ["2", 2.7, 9223372036854775807]:
		var malformed_training := v2_active.duplicate(true)
		malformed_training.training_queue.next_order_sequence = (
			invalid_sequence
		)
		var training_before: Dictionary = (
			source.export_v5_campaign_snapshot()
		)
		var malformed_training_restore: Dictionary = (
			source.restore_v5_campaign_snapshot(malformed_training)
		)
		_check(
			not malformed_training_restore.success
				and source.export_v5_campaign_snapshot()
					== training_before,
			"训练 sequence 非整数或不可安全持久化时结构化拒绝且零写入"
		)
		var malformed_army := v2_active.duplicate(true)
		malformed_army.army_registry.next_army_sequence = (
			invalid_sequence
		)
		var army_before: Dictionary = source.export_v5_campaign_snapshot()
		var malformed_army_restore: Dictionary = (
			source.restore_v5_campaign_snapshot(malformed_army)
		)
		_check(
			not malformed_army_restore.success
				and source.export_v5_campaign_snapshot() == army_before,
			"军队 sequence 非整数或不可安全持久化时结构化拒绝且零写入"
		)

	var validator := Callable(source, "validate_v5_campaign_snapshot")
	var encoded := V5CampaignSaveCodec.encode_snapshot(
		v2_active,
		1,
		validator
	)
	var decoded := V5CampaignSaveCodec.decode_storage_text(
		str(encoded.storage_text),
		validator
	)
	_check(
		encoded.success
			and decoded.success
			and decoded.snapshot == v2_active
			and decoded.payload_sha256
				== V5CampaignSaveCodec.calculate_sha256(
					decoded.payload_json
				),
		"V2 规范 envelope/checksum/类型 DTO 内存 roundtrip 精确"
	)
	var tampered_envelope: Dictionary = JSON.parse_string(
		str(encoded.storage_text)
	)
	tampered_envelope.payload_sha256 = "0".repeat(64)
	var tampered_text := JSON.stringify(
		tampered_envelope,
		"",
		true,
		true
	)
	var tampered := V5CampaignSaveCodec.decode_storage_text(
		tampered_text,
		validator
	)
	_check(
		not tampered.success
			and tampered.error_id == &"CHECKSUM_FAILED",
		"checksum 篡改在领域恢复前拒绝"
	)

	var store := V5CampaignSaveStore.new(test_root)
	var first_save := store.save_snapshot(v2_active, validator)
	_check(
		first_save.success
			and first_save.save_sequence == 1
			and FileAccess.file_exists(first_save.path),
		"第一代 V2 经写入、flush、复读、发布和终读成功"
	)
	_check(
		not FileAccess.file_exists(
			"%s/.pending_%012d_%d.tmp"
			% [test_root, 1, OS.get_process_id()]
		),
		"成功发布不残留可加载临时文件"
	)

	var completed_training := v2_active.duplicate(true)
	var historical_order_id := StringName(
		completed_training.training_queue.active_order_id
	)
	completed_training.city.current_day = 2
	_set_roster_total(
		completed_training.garrison,
		source.INFANTRY_ROLE.role_id,
		25
	)
	completed_training.training_queue.active_order_id = &""
	completed_training.training_queue.orders_by_id[
		historical_order_id
	].phase = TrainingQueue.PHASE_COMPLETED
	completed_training.training_queue.orders_by_id[
		historical_order_id
	].completed_day = int(
		completed_training.training_queue.orders_by_id[
			historical_order_id
		].complete_day
	)
	var near_limit_queue_snapshot: Dictionary = (
		completed_training.training_queue.duplicate(true)
	)
	near_limit_queue_snapshot.next_order_sequence = (
		TrainingQueue.MAX_EXACT_PERSISTED_SEQUENCE - 1
	)
	var near_limit_queue := TrainingQueue.new(&"blackstone_city")
	var near_limit_queue_restored := near_limit_queue.restore_snapshot(
		near_limit_queue_snapshot
	)
	var near_limit_order: Dictionary = near_limit_queue.enqueue(
		source.INFANTRY_ROLE.role_id,
		5,
		3,
		4,
		5
	)
	var exhausted_queue_snapshot: Dictionary = (
		near_limit_queue.get_snapshot()
	)
	var exhausted_queue_validation: Dictionary = (
		TrainingQueue.validate_snapshot(
		exhausted_queue_snapshot
		)
	)
	var near_limit_order_id := StringName(
		near_limit_order.get("order_id", &"")
	)
	var near_limit_completed := near_limit_queue.mark_completed(
		near_limit_order_id,
		4
	)
	var exhausted_queue_before: Dictionary = (
		near_limit_queue.get_snapshot()
	)
	var exhausted_order: Dictionary = near_limit_queue.enqueue(
		source.INFANTRY_ROLE.role_id,
		5,
		5,
		6,
		5
	)
	_check(
		near_limit_queue_restored
			and near_limit_order_id
				== StringName(
					"training.blackstone_city.%d"
					% (
						TrainingQueue
						.MAX_EXACT_PERSISTED_SEQUENCE - 1
					)
				)
			and exhausted_queue_validation.valid
			and exhausted_queue_snapshot.next_order_sequence
				== TrainingQueue.MAX_EXACT_PERSISTED_SEQUENCE
			and near_limit_completed
			and exhausted_order.is_empty()
			and near_limit_queue.get_snapshot()
				== exhausted_queue_before,
		"训练 MAX-1 restore→create 产生可持久化 exhausted sentinel，后续创建零写入"
	)
	var exhausted_training_authority := completed_training.duplicate(true)
	exhausted_training_authority.training_queue.next_order_sequence = (
		TrainingQueue.MAX_EXACT_PERSISTED_SEQUENCE
	)
	var exhausted_training_scene := packed_scene.instantiate()
	root.add_child(exhausted_training_scene)
	await process_frame
	await process_frame
	var exhausted_training_controller: Node = (
		exhausted_training_scene.get_node("ConstructionController")
	)
	exhausted_training_controller.set_process(false)
	var exhausted_training_restore: Dictionary = (
		exhausted_training_controller.restore_v5_campaign_snapshot(
			exhausted_training_authority
		)
	)
	var exhausted_training_before: Dictionary = (
		exhausted_training_controller.export_v5_campaign_snapshot()
	)
	var exhausted_training_request: Dictionary = (
		exhausted_training_controller.request_training()
	)
	_check(
		exhausted_training_restore.success
			and not exhausted_training_request.success
			and exhausted_training_request.error_id
				== &"TRAINING_QUEUE_COMMIT"
			and exhausted_training_controller
				.export_v5_campaign_snapshot()
				== exhausted_training_before,
		"训练 exhausted sentinel 经正式创建入口结构化失败且全部 authority 零写入"
	)
	var stale_training_disk := completed_training.duplicate(true)
	stale_training_disk.training_queue.next_order_sequence = 1
	var stale_training_root := test_root.path_join("stale_training")
	var stale_training_store := V5CampaignSaveStore.new(
		stale_training_root
	)
	_check(
		DirAccess.make_dir_recursive_absolute(stale_training_root) == OK
			and _write_counterexample_generation(
				stale_training_store,
				stale_training_disk
			),
		"正式 codec 生成 checksum 合法但训练领域非法的隔离代次"
	)
	var stale_training_scene := packed_scene.instantiate()
	root.add_child(stale_training_scene)
	await process_frame
	await process_frame
	var stale_training_controller: Node = (
		stale_training_scene.get_node("ConstructionController")
	)
	stale_training_controller.set_process(false)
	var stale_training_before: Dictionary = (
		stale_training_controller.export_v5_campaign_snapshot()
	)
	var stale_training_load: Dictionary = (
		stale_training_store.load_and_restore(
			stale_training_controller
		)
	)
	var stale_training_reused := false
	if bool(stale_training_load.get("success", false)):
		stale_training_controller.queue_training()
		var loaded_training: Dictionary = (
			stale_training_controller.export_v5_campaign_snapshot()
		)
		stale_training_reused = (
			loaded_training.training_queue.orders_by_id.size() == 1
			and loaded_training.training_queue.orders_by_id.has(
				historical_order_id
			)
		)
	print(
		"V5_STALE_TRAINING_COUNTEREXAMPLE load=%s reused=%s old=%s"
		% [
			stale_training_load.get("success", false),
			stale_training_reused,
			historical_order_id,
		]
	)
	_check(
		not bool(stale_training_load.get("success", false))
			and stale_training_controller.export_v5_campaign_snapshot()
				== stale_training_before,
		"checksum 合法的训练 sequence rollback 经正式 load/restore 边界拒绝且零写入"
	)

	var legal_training_root := test_root.path_join("legal_training")
	var legal_training_store := V5CampaignSaveStore.new(
		legal_training_root
	)
	var legal_training_save := legal_training_store.save_snapshot(
		completed_training,
		validator
	)
	var legal_training_scene := packed_scene.instantiate()
	root.add_child(legal_training_scene)
	await process_frame
	await process_frame
	var legal_training_controller: Node = (
		legal_training_scene.get_node("ConstructionController")
	)
	legal_training_controller.set_process(false)
	var legal_training_load := legal_training_store.load_and_restore(
		legal_training_controller
	)
	legal_training_controller.food = 0
	var training_resource_before: Dictionary = (
		legal_training_controller.export_v5_campaign_snapshot()
	)
	var training_resource_failure: Dictionary = (
		legal_training_controller.request_training()
	)
	var training_resource_zero_write: bool = (
		not training_resource_failure.success
		and training_resource_failure.error_id == &"INSUFFICIENT_FOOD"
		and legal_training_controller.export_v5_campaign_snapshot()
			== training_resource_before
	)
	legal_training_controller.restore_v5_campaign_snapshot(
		completed_training
	)
	legal_training_controller.recruitment_cap = 25
	var training_capacity_before: Dictionary = (
		legal_training_controller.export_v5_campaign_snapshot()
	)
	var training_capacity_failure: Dictionary = (
		legal_training_controller.request_training()
	)
	var training_capacity_zero_write: bool = (
		not training_capacity_failure.success
		and training_capacity_failure.error_id
			== &"RECRUITMENT_CAPACITY"
		and legal_training_controller.export_v5_campaign_snapshot()
			== training_capacity_before
	)
	legal_training_controller.restore_v5_campaign_snapshot(
		completed_training
	)
	var legal_training_create: bool = (
		legal_training_controller.queue_training()
	)
	var legal_training_after: Dictionary = (
		legal_training_controller.export_v5_campaign_snapshot()
	)
	_check(
		legal_training_save.success
			and legal_training_load.success
			and training_resource_zero_write
			and training_capacity_zero_write
			and legal_training_create
			and legal_training_after.training_queue.orders_by_id.has(
				&"training.blackstone_city.000001"
			)
			and legal_training_after.training_queue.orders_by_id.has(
				&"training.blackstone_city.000002"
			),
		"合法高水位恢复后资源/容量失败零写入，首次成功训练为唯一 .000002"
	)

	var restore_scene := packed_scene.instantiate()
	root.add_child(restore_scene)
	await process_frame
	await process_frame
	var restored: Node = restore_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restore_result := store.load_and_restore(restored)
	_check(
		restore_result.success
			and restored.export_v5_campaign_snapshot() == v2_active,
		"新控制器从磁盘恢复活动训练 stable ID 与精确状态"
	)
	_check(
		restored.advance_one_day_for_test()
			and restored.infantry_count == 25
			and restored.training_queued_count == 0,
		"恢复后的活动训练仍只在正式日边界完成一次"
	)

	var reservation: Dictionary = restored.reserve_army_dispatch(
		10,
		&"node.persistence",
		&"route.persistence",
		6000
	)
	var army: Dictionary = restored.confirm_army_dispatch(
		StringName(reservation.transaction_id)
	)
	var progress: Dictionary = restored.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		0,
		2500
	)
	var in_transit: Dictionary = restored.export_v5_campaign_snapshot()
	_check(
		progress.success
			and in_transit.army_registry.armies_by_id[
				army.army_id
			].progress_milliseconds == 2500
			and in_transit.army_registry.armies_by_id[
				army.army_id
			].route_id == &"route.persistence",
		"V2 保存点包含 active Army stable ID、route/node 和整数进度"
	)
	var historical_army_id := StringName(army.army_id)
	var closed_army := in_transit.duplicate(true)
	closed_army.army_registry.armies_by_id[
		historical_army_id
	].phase = ArmyRegistry.PHASE_CLOSED
	closed_army.army_registry.armies_by_id[
		historical_army_id
	].units_by_definition_id = {}
	var near_limit_registry_snapshot: Dictionary = (
		closed_army.army_registry.duplicate(true)
	)
	near_limit_registry_snapshot.next_army_sequence = (
		ArmyRegistry.MAX_EXACT_PERSISTED_SEQUENCE - 1
	)
	var near_limit_registry := ArmyRegistry.new()
	var near_limit_registry_restored := (
		near_limit_registry.restore_snapshot(
			near_limit_registry_snapshot,
			[source.INFANTRY_ROLE.role_id],
			true
		)
	)
	var near_limit_army: Dictionary = (
		near_limit_registry.create_reserved(
			&"player",
			&"blackstone_city",
			&"blackstone_city",
			&"node.limit",
			&"route.limit",
			{source.INFANTRY_ROLE.role_id: 5},
			1000,
			&"dispatch.limit"
		)
	)
	var near_limit_army_id := StringName(
		near_limit_army.get("army_id", &"")
	)
	var exhausted_registry_snapshot: Dictionary = (
		near_limit_registry.get_snapshot()
	)
	var exhausted_registry_validation: Dictionary = (
		ArmyRegistry.validate_snapshot(
			exhausted_registry_snapshot,
			[source.INFANTRY_ROLE.role_id],
			true
		)
	)
	exhausted_registry_snapshot.armies_by_id[
		near_limit_army_id
	].phase = ArmyRegistry.PHASE_CLOSED
	exhausted_registry_snapshot.armies_by_id[
		near_limit_army_id
	].units_by_definition_id = {}
	var exhausted_registry := ArmyRegistry.new()
	var exhausted_registry_restored := (
		exhausted_registry.restore_snapshot(
			exhausted_registry_snapshot,
			[source.INFANTRY_ROLE.role_id],
			true
		)
	)
	var exhausted_registry_before: Dictionary = (
		exhausted_registry.get_snapshot()
	)
	var exhausted_army: Dictionary = exhausted_registry.create_reserved(
		&"player",
		&"blackstone_city",
		&"blackstone_city",
		&"node.exhausted",
		&"route.exhausted",
		{source.INFANTRY_ROLE.role_id: 5},
		1000,
		&"dispatch.exhausted"
	)
	_check(
		near_limit_registry_restored
			and near_limit_army_id
				== StringName(
					"army.player.%d"
					% (
						ArmyRegistry
						.MAX_EXACT_PERSISTED_SEQUENCE - 1
					)
				)
			and exhausted_registry_validation.valid
			and exhausted_registry_snapshot.next_army_sequence
				== ArmyRegistry.MAX_EXACT_PERSISTED_SEQUENCE
			and exhausted_registry_restored
			and exhausted_army.is_empty()
			and exhausted_registry.get_snapshot()
				== exhausted_registry_before,
		"军队 MAX-1 restore→create 产生可持久化 exhausted sentinel，后续创建零写入"
	)
	var exhausted_army_authority := closed_army.duplicate(true)
	exhausted_army_authority.army_registry.next_army_sequence = (
		ArmyRegistry.MAX_EXACT_PERSISTED_SEQUENCE
	)
	var exhausted_army_scene := packed_scene.instantiate()
	root.add_child(exhausted_army_scene)
	await process_frame
	await process_frame
	var exhausted_army_controller: Node = (
		exhausted_army_scene.get_node("ConstructionController")
	)
	exhausted_army_controller.set_process(false)
	var exhausted_army_restore: Dictionary = (
		exhausted_army_controller.restore_v5_campaign_snapshot(
			exhausted_army_authority
		)
	)
	var exhausted_army_before: Dictionary = (
		exhausted_army_controller.export_v5_campaign_snapshot()
	)
	var exhausted_army_reservation: Dictionary = (
		exhausted_army_controller.reserve_army_dispatch(
			5,
			&"node.exhausted",
			&"route.exhausted",
			1000
		)
	)
	_check(
		exhausted_army_restore.success
			and exhausted_army_reservation.is_empty()
			and exhausted_army_controller
				.get_active_army_dispatch_reservation()
				.is_empty()
			and exhausted_army_controller
				.export_v5_campaign_snapshot()
				== exhausted_army_before,
		"军队 exhausted sentinel 在 reservation 前失败且 transaction/authority 零写入"
	)
	var stale_army_disk := closed_army.duplicate(true)
	stale_army_disk.army_registry.next_army_sequence = 1
	var stale_army_root := test_root.path_join("stale_army")
	var stale_army_store := V5CampaignSaveStore.new(stale_army_root)
	_check(
		DirAccess.make_dir_recursive_absolute(stale_army_root) == OK
			and _write_counterexample_generation(
				stale_army_store,
				stale_army_disk
			),
		"正式 codec 生成 checksum 合法但军队领域非法的隔离代次"
	)
	var stale_army_scene := packed_scene.instantiate()
	root.add_child(stale_army_scene)
	await process_frame
	await process_frame
	var stale_army_controller: Node = (
		stale_army_scene.get_node("ConstructionController")
	)
	stale_army_controller.set_process(false)
	var stale_army_before: Dictionary = (
		stale_army_controller.export_v5_campaign_snapshot()
	)
	var stale_army_load: Dictionary = stale_army_store.load_and_restore(
		stale_army_controller
	)
	var stale_army_reused := false
	if bool(stale_army_load.get("success", false)):
		var stale_reservation: Dictionary = (
			stale_army_controller.reserve_army_dispatch(
				5,
				&"node.stale",
				&"route.stale",
				1000
			)
		)
		var stale_created: Dictionary = (
			stale_army_controller.confirm_army_dispatch(
				StringName(stale_reservation.get(
					"transaction_id",
					&""
				))
			)
		)
		stale_army_reused = (
			StringName(stale_created.get("army_id", &""))
			== historical_army_id
		)
	print(
		"V5_STALE_ARMY_COUNTEREXAMPLE load=%s reused=%s old=%s"
		% [
			stale_army_load.get("success", false),
			stale_army_reused,
			historical_army_id,
		]
	)
	_check(
		not bool(stale_army_load.get("success", false))
			and stale_army_controller.export_v5_campaign_snapshot()
				== stale_army_before,
		"checksum 合法的军队 sequence rollback 经正式 load/restore 边界拒绝且零写入"
	)

	var legal_army_root := test_root.path_join("legal_army")
	var legal_army_store := V5CampaignSaveStore.new(legal_army_root)
	var legal_army_save := legal_army_store.save_snapshot(
		closed_army,
		Callable(restored, "validate_v5_campaign_snapshot")
	)
	var legal_army_scene := packed_scene.instantiate()
	root.add_child(legal_army_scene)
	await process_frame
	await process_frame
	var legal_army_controller: Node = (
		legal_army_scene.get_node("ConstructionController")
	)
	legal_army_controller.set_process(false)
	var legal_army_load := legal_army_store.load_and_restore(
		legal_army_controller
	)
	var army_capacity_before: Dictionary = (
		legal_army_controller.export_v5_campaign_snapshot()
	)
	var army_capacity_failure: Dictionary = (
		legal_army_controller.reserve_army_dispatch(
			999,
			&"node.capacity",
			&"route.capacity",
			1000
		)
	)
	var army_capacity_zero_write: bool = (
		army_capacity_failure.is_empty()
		and legal_army_controller.export_v5_campaign_snapshot()
			== army_capacity_before
	)
	var legal_reservation: Dictionary = (
		legal_army_controller.reserve_army_dispatch(
			5,
			&"node.legal",
			&"route.legal",
			1000
		)
	)
	var legal_army_create: Dictionary = (
		legal_army_controller.confirm_army_dispatch(
			StringName(legal_reservation.get("transaction_id", &""))
		)
	)
	var legal_army_after: Dictionary = (
		legal_army_controller.export_v5_campaign_snapshot()
	)
	var active_army_before: Dictionary = legal_army_after.duplicate(true)
	var active_army_failure: Dictionary = (
		legal_army_controller.reserve_army_dispatch(
			1,
			&"node.active_block",
			&"route.active_block",
			1000
		)
	)
	_check(
		legal_army_save.success
			and legal_army_load.success
			and army_capacity_zero_write
			and StringName(legal_army_create.get("army_id", &""))
				== &"army.player.000002"
			and legal_army_after.army_registry.armies_by_id.has(
				&"army.player.000001"
			)
			and legal_army_after.army_registry.armies_by_id.has(
				&"army.player.000002"
			)
			and active_army_failure.is_empty()
			and legal_army_controller.export_v5_campaign_snapshot()
				== active_army_before,
		"合法高水位恢复后容量/单 active 失败零写入，首次成功军队为唯一 .000002"
	)
	var stale_army_sequence := in_transit.duplicate(true)
	stale_army_sequence.army_registry.next_army_sequence = 1
	_check(
		not restored.validate_v5_campaign_snapshot(
			stale_army_sequence
		).valid,
		"V2 拒绝会在恢复后复用既有 army ID 的倒退序列"
	)
	var second_save := store.save_snapshot(
		in_transit,
		Callable(restored, "validate_v5_campaign_snapshot")
	)
	_check(
		second_save.success
			and second_save.save_sequence == 2
			and FileAccess.file_exists(first_save.path),
		"第二代不可变发布且第一代仍保留"
	)

	var reload_scene := packed_scene.instantiate()
	root.add_child(reload_scene)
	await process_frame
	await process_frame
	var reloaded: Node = reload_scene.get_node("ConstructionController")
	reloaded.set_process(false)
	var reload_result := store.load_and_restore(reloaded)
	_check(
		reload_result.success
			and reload_result.save_sequence == 2
			and reloaded.export_v5_campaign_snapshot() == in_transit,
		"保存退出后新运行时精确重载在途 ArmyState"
	)
	var loaded_army: Dictionary = reloaded.get_army_state(
		StringName(army.army_id)
	)
	_check(
		loaded_army.progress_milliseconds == 2500
			and loaded_army.transaction_id == army.transaction_id
			and loaded_army.units_by_definition_id
				== army.units_by_definition_id,
		"跨运行时重载保持 Army ID、事务、组成和进度"
	)

	_check(
		not store.save_snapshot(
			in_transit,
			Callable(reloaded, "validate_v5_campaign_snapshot"),
			{"write_failed": true}
		).success
			and not FileAccess.file_exists(store.get_generation_path(3)),
		"注入写入失败不发布新代次"
	)
	_check(
		not store.save_snapshot(
			in_transit,
			Callable(reloaded, "validate_v5_campaign_snapshot"),
			{"publish_failed": true}
		).success
			and not FileAccess.file_exists(store.get_generation_path(3)),
		"注入发布失败保留旧代次且不留下目标"
	)
	DirAccess.make_dir_absolute(store.get_writer_lock_path())
	var lock_failure := store.save_snapshot(
		in_transit,
		Callable(reloaded, "validate_v5_campaign_snapshot")
	)
	_check(
		not lock_failure.success
			and lock_failure.error_id == &"WRITER_LOCKED"
			and not FileAccess.file_exists(store.get_generation_path(3)),
		"writer lock 不能被偷取或静默删除"
	)
	DirAccess.remove_absolute(store.get_writer_lock_path())

	var third_save := store.save_snapshot(
		in_transit,
		Callable(reloaded, "validate_v5_campaign_snapshot")
	)
	_check(third_save.success and third_save.save_sequence == 3, "建立第三个有效代次")
	_write_text(third_save.path, "{\"corrupt\":")
	var recovered := store.load_latest(
		Callable(reloaded, "validate_v5_campaign_snapshot")
	)
	_check(
		recovered.success
			and recovered.recovered
			and recovered.save_sequence == 2
			and recovered.snapshot == in_transit,
		"最新坏档明确回退到上一有效代次"
	)

	var future_envelope: Dictionary = JSON.parse_string(
		_read_text(second_save.path)
	)
	future_envelope.storage_version = 2
	_write_text(
		store.get_generation_path(4),
		JSON.stringify(future_envelope, "", true, true)
	)
	var future_load := store.load_latest(
		Callable(reloaded, "validate_v5_campaign_snapshot")
	)
	_check(
		not future_load.success
			and future_load.error_id == &"FUTURE_STORAGE_VERSION",
		"未来 storage version 阻断，不降级跳过"
	)
	DirAccess.remove_absolute(store.get_generation_path(4))

	var before_apply_failure: Dictionary = (
		reloaded.export_v5_campaign_snapshot()
	)
	reloaded.set_v5_restore_failure_after_city_install_for_test(true)
	var apply_failure: Dictionary = (
		reloaded.restore_v5_campaign_snapshot(v2_active)
	)
	reloaded.set_v5_restore_failure_after_city_install_for_test(false)
	_check(
		not apply_failure.success
			and apply_failure.error_id == &"APPLY_FAILED"
			and reloaded.export_v5_campaign_snapshot()
				== before_apply_failure,
		"live apply 中途失败恢复完整 pre-apply authority"
	)

	var final_failure := store.save_snapshot(
		in_transit,
		Callable(reloaded, "validate_v5_campaign_snapshot"),
		{"corrupt_final": true}
	)
	var final_recovery := store.load_latest(
		Callable(reloaded, "validate_v5_campaign_snapshot")
	)
	_check(
		not final_failure.success
			and final_failure.error_id == &"FINAL_REREAD_FAILED"
			and final_recovery.success
			and final_recovery.save_sequence == 2,
		"终读失败不删除旧代次，加载跳过多个损坏代次恢复"
	)

	_check(
		not _contains_forbidden_key_or_value(in_transit),
		"完整 V2 snapshot 不含 Node、像素、camera、UI 或 selection"
	)
	var cold_root := test_root.path_join("cold_process")
	_check(
		DirAccess.make_dir_recursive_absolute(cold_root) == OK,
		"建立独立冷进程存档目录"
	)
	var worker_a := _run_cold_worker("A", cold_root)
	var worker_b := _run_cold_worker("B", cold_root)
	var worker_c := _run_cold_worker("C", cold_root)
	_check(
		int(worker_a.exit_code) == 0
			and int(worker_b.exit_code) == 0
			and int(worker_c.exit_code) == 0,
		"三个独立 Godot 进程完成保存、恢复、推进和再恢复"
	)
	_check(
		str(worker_a.output).contains("progress=2500 phase=MARCHING")
			and str(worker_b.output).contains(
				"progress=6000 phase=ARRIVED"
			)
			and str(worker_c.output).contains(
				"progress=6000 phase=ARRIVED"
			),
		"冷进程输出证明 Army 进度只由进程 B 推进一次"
	)
	print(
		"V5_COLD_PROCESS_EXITS A=%d B=%d C=%d"
		% [
			int(worker_a.exit_code),
			int(worker_b.exit_code),
			int(worker_c.exit_code),
		]
	)
	_finish(test_root)


func _contains_forbidden_key_or_value(value) -> bool:
	if value is Node or value is Resource or value is Callable:
		return true
	if value is Dictionary:
		for key in value:
			var text := String(key).to_lower()
			if (
				"pixel" in text
				or "camera" in text
				or "selected_ui" in text
				or "panel_visible" in text
				or "marker_position" in text
			):
				return true
			if _contains_forbidden_key_or_value(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_key_or_value(item):
				return true
	return false


func _run_cold_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			COLD_WORKER_PATH,
			"--",
			"--mode=%s" % mode,
			"--save-dir=%s" % save_directory,
		]),
		output,
		true
	)
	return {
		"exit_code": exit_code,
		"output": "\n".join(output),
	}


func _accept_counterexample(snapshot: Dictionary) -> Dictionary:
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": snapshot.duplicate(true),
	}


## The V6 aggregate stays a projection.  Fixtures must update the three
## persistent formation records and their projection together rather than
## mutating the deprecated aggregate in isolation.
func _set_roster_total(
	garrison: Dictionary,
	definition_id: StringName,
	total: int
) -> void:
	var formation_order: Array = garrison.formation_order
	var formations: Dictionary = garrison.formations_by_id
	var base := total / formation_order.size()
	var remainder := total % formation_order.size()
	for index in range(formation_order.size()):
		var formation_id := StringName(formation_order[index])
		var formation: Dictionary = formations[formation_id]
		formation.member_count = base + (1 if index < remainder else 0)
		formations[formation_id] = formation
	garrison.formations_by_id = formations
	garrison.unit_counts_by_definition_id = {definition_id: total}


func _roster_total(garrison: Dictionary) -> int:
	var total := 0
	for formation in Dictionary(garrison.formations_by_id).values():
		total += int(Dictionary(formation).member_count)
	return total


func _write_counterexample_generation(
	store: V5CampaignSaveStore,
	snapshot: Dictionary
) -> bool:
	var encoded := V5CampaignSaveCodec.encode_snapshot(
		snapshot,
		1,
		Callable(self, "_accept_counterexample")
	)
	return (
		bool(encoded.get("success", false))
		and _write_text(
			store.get_generation_path(1),
			str(encoded.get("storage_text", ""))
		)
	)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish(test_root: String) -> void:
	_remove_tree(test_root)
	if failures.is_empty():
		print("V5_CAMPAIGN_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	print("V5_CAMPAIGN_PERSISTENCE_SMOKE FAIL: %s" % [failures])
	quit(1)
