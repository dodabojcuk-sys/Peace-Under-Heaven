extends SceneTree


const ReadModel := preload("res://scripts/state/persistent_nation_state_v1.gd")


var failures: Array[String] = []
var city_state_changed_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	city.set_process(false)
	city.city_state_changed.connect(_on_city_state_changed)

	var source_before: String = _source_fingerprint(city)
	var first: Dictionary = ReadModel.read(city)
	var source_after_first: String = _source_fingerprint(city)
	_check(
		bool(first.success)
			and source_before == source_after_first
			and city_state_changed_count == 0,
		"读取投影无城市写入、无状态事件且源状态指纹不变"
	)
	var first_state: Dictionary = Dictionary(first.state)
	var city_id := &"blackstone_city"
	_check(
		first_state.schema_version == 1
			and first_state.state_kind == &"one_city_national_read_model"
			and first_state.nation_id == &"nation.txwzs2"
			and first_state.city_id == city_id
			and first_state.city_ids == [city_id]
			and first_state.shared_resource_ids
				== [&"food", &"tech_points", &"wood"]
			and first_state.cities_by_id.has(city_id),
		"一城国家投影包含稳定国家、城市和资源身份"
	)
	var source_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var projected_city: Dictionary = Dictionary(
		first_state.cities_by_id[city_id]
	)
	_check(
		projected_city == source_snapshot
			and int(first_state.shared_resources.food)
				== int(source_snapshot.city.food)
			and int(first_state.shared_resources.tech_points)
				== int(source_snapshot.city.tech_points)
			and int(first_state.shared_resources.wood)
				== int(source_snapshot.city.wood),
		"唯一城市快照精确投影，资源只读取一次"
	)
	var second: Dictionary = ReadModel.read(city)
	_check(
		bool(second.success)
			and Dictionary(second.state) == first_state
			and _source_fingerprint(city) == source_before,
		"相同权威状态重复读取结果稳定且不改变源状态"
	)

	var detached: Dictionary = Dictionary(first.state).duplicate(true)
	detached.shared_resources.food = 999999
	Dictionary(detached.cities_by_id[city_id]).city.food = 888888
	Dictionary(detached.cities_by_id[city_id]).garrison.unit_counts_by_definition_id[
		&"unit_role.infantry_basic"
	] = 777777
	var after_detached_mutation: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		after_detached_mutation == source_snapshot
			and int(Dictionary(ReadModel.read(city).state).shared_resources.food)
				== int(source_snapshot.city.food),
		"调用方修改嵌套投影不能反向改变城市权威"
	)

	var saved_projection: Dictionary = Dictionary(second.state).duplicate(true)
	var food_before_training: int = city.food
	_check(city.request_training().success, "既有城市 writer 可建立训练订单")
	var after_writer: Dictionary = ReadModel.read(city)
	_check(
		bool(after_writer.success)
			and city_state_changed_count == 1
			and int(Dictionary(after_writer.state).shared_resources.food)
				== city.food
			and city.food < food_before_training
			and not Dictionary(after_writer.state).cities_by_id[city_id]
				.training_queue.active_order_id.is_empty()
			and int(saved_projection.shared_resources.food)
				== food_before_training
			and Dictionary(saved_projection.cities_by_id[city_id])
				== source_snapshot,
		"新读取立即反映既有 writer，旧投影仍保持深度隔离"
	)
	_check(
		not bool(ReadModel.read(null).success)
			and ReadModel.read(null).error_id == &"MISSING_CITY_AUTHORITY",
		"缺失城市权威明确失败且不伪造默认城市"
	)
	var unrelated_node := Node.new()
	_check(
		not bool(ReadModel.read(unrelated_node).success)
			and ReadModel.read(unrelated_node).error_id
				== &"UNSUPPORTED_CITY_AUTHORITY",
		"非法城市权威明确失败且不补零"
	)
	unrelated_node.free()

	scene.queue_free()
	await process_frame
	_finish()


func _source_fingerprint(city: Node) -> String:
	return var_to_str(city.export_v5_campaign_snapshot())


func _on_city_state_changed() -> void:
	city_state_changed_count += 1


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("P0_01_NATIONAL_READ_MODEL_SMOKE PASS")
		quit(0)
		return
	print("P0_01_NATIONAL_READ_MODEL_SMOKE FAIL: %s" % failures)
	quit(1)
