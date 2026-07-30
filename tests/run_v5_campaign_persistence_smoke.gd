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
			and migrated.snapshot.schema_version == 2
			and migrated.snapshot.snapshot_kind
				== &"campaign_authoritative",
		"有效 V1 只读输入确定性迁移为 V2"
	)
	var v2_active: Dictionary = migrated.snapshot
	_check(
		not v2_active.city.has("infantry_count")
			and not v2_active.city.has("training_queued_count")
			and v2_active.garrison.unit_counts_by_definition_id[
				source.INFANTRY_ROLE.role_id
			] == 20
			and v2_active.training_queue.active_order_id
				== &"training.blackstone_city.000001",
		"V1 步兵与训练三字段只迁移到唯一 Garrison/TrainingQueue 源"
	)
	_check(
		v2_active.army_registry.armies_by_id.is_empty()
			and v2_active.settlement_ledger
				.committed_results_by_id.is_empty()
			and v2_active.city.day_elapsed_milliseconds == 37500,
		"V1 迁移产生空军队/结算集合并保留精确时间"
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
