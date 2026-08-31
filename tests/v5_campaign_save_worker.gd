extends SceneTree


const SAVE_STORE = preload(
	"res://scripts/state/v5_campaign_save_store.gd"
)
const LOGGING_CAMP_ID := &"building.logging_camp.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	var mode := str(arguments.get("mode", ""))
	var save_directory := str(arguments.get("save_dir", ""))
	_require(mode in ["A", "B", "C"], "worker mode 必须是 A、B 或 C")
	_require(not save_directory.is_empty(), "worker 必须收到隔离存档目录")
	if not failures.is_empty():
		_finish(mode)
		return
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_require(packed_scene != null, "worker 可以加载正式城市场景")
	if packed_scene == null:
		_finish(mode)
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node = scene.get_node("ConstructionController")
	controller.set_process(false)
	var store := SAVE_STORE.new(save_directory)
	match mode:
		"A":
			_run_process_a(controller, store)
		"B":
			_run_process_b(controller, store)
		"C":
			_run_process_c(controller, store)
	scene.queue_free()
	await process_frame
	_finish(mode)


func _run_process_a(controller: Node, store: RefCounted) -> void:
	controller.set_city_time_paused(true)
	_require(controller.queue_training(), "进程 A 建立 TrainingQueue")
	_require(controller.advance_one_day_for_test(), "进程 A 完成训练")
	var reservation: Dictionary = controller.reserve_army_dispatch(
		10,
		&"node.cold_process",
		&"route.cold_process",
		6000
	)
	_require(not reservation.is_empty(), "进程 A 预留出征")
	if reservation.is_empty():
		return
	var army: Dictionary = controller.confirm_army_dispatch(
		StringName(reservation.transaction_id)
	)
	_require(not army.is_empty(), "进程 A 建立 ArmyState")
	if army.is_empty():
		return
	var progress: Dictionary = controller.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		0,
		2500
	)
	_require(
		bool(progress.success)
			and int(progress.army.progress_milliseconds) == 2500,
		"进程 A 推进 Army 到 2500ms"
	)
	controller.set_city_time_paused(false)
	controller.wood = 40
	_require(
		bool(controller.start_build_project(LOGGING_CAMP_ID).success),
		"进程 A 建立 R0C 建造位项目"
	)
	for _tick in range(180):
		controller._advance_build_slot_tick()
	controller.set_city_time_paused(true)
	_require(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE
		and int(controller.get_build_slot_snapshot().paid_costs.wood) == 40,
		"进程 A 保存一枚已付款 ready token"
	)
	var snapshot: Dictionary = controller.export_v5_campaign_snapshot()
	var save_result: Dictionary = store.save_snapshot(
		snapshot,
		Callable(controller, "validate_v5_campaign_snapshot")
	)
	_require(
		bool(save_result.success)
			and int(save_result.save_sequence) == 1,
		"进程 A 写入第一代 V2"
	)
	if bool(save_result.success):
		print(
			"V5_COLD_A day=%d army=%s progress=%d phase=%s"
			% [
				int(snapshot.city.current_day),
				String(army.army_id),
				int(progress.army.progress_milliseconds),
				String(progress.army.phase),
			]
		)


func _run_process_b(controller: Node, store: RefCounted) -> void:
	var load_result: Dictionary = store.load_and_restore(controller)
	_require(
		bool(load_result.success)
			and int(load_result.save_sequence) == 1,
		"进程 B 冷启动恢复第一代"
	)
	if not bool(load_result.success):
		return
	var snapshot: Dictionary = controller.export_v5_campaign_snapshot()
	var armies: Dictionary = snapshot.army_registry.armies_by_id
	_require(armies.size() == 1, "进程 B 恢复一支 active Army")
	_require(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE
		and int(snapshot.build_slot.paid_costs.wood) == 40,
		"进程 B 冷启动精确恢复 ready token"
	)
	if armies.size() != 1:
		return
	var army_id := StringName(armies.keys()[0])
	var army: Dictionary = armies[army_id]
	_require(
		int(army.progress_milliseconds) == 2500
			and StringName(army.phase) == &"MARCHING"
			and controller.infantry_count == 15,
		"进程 B 精确恢复进程 A 的 Army 和驻军"
	)
	var progress: Dictionary = controller.advance_army_strategic_time(
		army_id,
		StringName(army.transaction_id),
		2500,
		3500
	)
	_require(
		bool(progress.success)
			and int(progress.army.progress_milliseconds) == 6000
			and StringName(progress.army.phase) == &"ARRIVED",
		"进程 B 只推进剩余 3500ms 并到达"
	)
	var advanced: Dictionary = controller.export_v5_campaign_snapshot()
	var save_result: Dictionary = store.save_snapshot(
		advanced,
		Callable(controller, "validate_v5_campaign_snapshot")
	)
	_require(
		bool(save_result.success)
			and int(save_result.save_sequence) == 2,
		"进程 B 写入第二代 V2"
	)
	if bool(save_result.success):
		print(
			"V5_COLD_B day=%d army=%s progress=%d phase=%s"
			% [
				int(advanced.city.current_day),
				String(army_id),
				int(progress.army.progress_milliseconds),
				String(progress.army.phase),
			]
		)


func _run_process_c(controller: Node, store: RefCounted) -> void:
	var load_result: Dictionary = store.load_and_restore(controller)
	_require(
		bool(load_result.success)
			and int(load_result.save_sequence) == 2,
		"进程 C 冷启动恢复第二代"
	)
	if not bool(load_result.success):
		return
	var snapshot: Dictionary = controller.export_v5_campaign_snapshot()
	var armies: Dictionary = snapshot.army_registry.armies_by_id
	_require(armies.size() == 1, "进程 C 仍只看见一支 Army")
	_require(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE
		and int(snapshot.build_slot.paid_costs.wood) == 40,
		"进程 C 第三次冷启动仍只有同一枚 ready token"
	)
	if armies.size() != 1:
		return
	var army: Dictionary = armies.values()[0]
	_require(
		int(snapshot.city.current_day) == 2
			and int(army.progress_milliseconds) == 6000
			and StringName(army.phase) == &"ARRIVED"
			and controller.infantry_count == 15,
		"进程 C 看见进程 B 的精确到达状态且未重复推进"
	)
	print(
		"V5_COLD_C day=%d army=%s progress=%d phase=%s"
		% [
			int(snapshot.city.current_day),
			String(army.army_id),
			int(army.progress_milliseconds),
			String(army.phase),
		]
	)


func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in arguments:
		if argument.begins_with("--mode="):
			parsed.mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--save-dir="):
			parsed.save_dir = argument.trim_prefix("--save-dir=")
	return parsed


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("V5_COLD_WORKER_FAIL: %s" % description)


func _finish(mode: String) -> void:
	if failures.is_empty():
		print("V5_COLD_WORKER_%s PASS" % mode)
		quit(0)
		return
	print("V5_COLD_WORKER_%s FAIL: %s" % [mode, failures])
	quit(1)
