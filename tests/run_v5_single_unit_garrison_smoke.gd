extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式主场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var definition_id := &"unit_role.infantry_basic"

	_check(
		city.get_unit_definition_ids() == [definition_id],
		"V5 当前只公开一个稳定步兵 definition ID"
	)
	var definition: UnitRole = city.get_unit_definition(definition_id)
	_check(
		definition == city.INFANTRY_ROLE
			and definition.role_id == definition_id
			and definition.display_name == "步兵",
		"V5 查询复用既有 UnitRole，不复制兵种数值"
	)
	_check(
		city.get_unit_definition(&"unit_role.unknown") == null,
		"未知兵种 ID 不产生空定义或伪造选项"
	)

	var initial: Dictionary = city.get_garrison_snapshot()
	var initial_formations: Array = initial.formations
	_check(
		initial.schema_version == 2
			and initial.city_id == &"blackstone_city"
			and initial.definition_id == definition_id
			and initial_formations.size() == 3
			and StringName(initial_formations[0].formation_id)
				== &"formation.blackstone.1"
			and StringName(initial_formations[1].formation_id)
				== &"formation.blackstone.2"
			and StringName(initial_formations[2].formation_id)
				== &"formation.blackstone.3",
		"驻军读模型包含稳定 roster 版本、城市、兵种及三个永久编队身份"
	)
	var initial_counts: Dictionary = initial.unit_counts
	_check(
		initial_counts.get(definition_id, -1) == 20
			and initial.total_count == 20
			and int(initial_formations[0].member_count) == 7
			and int(initial_formations[1].member_count) == 7
			and int(initial_formations[2].member_count) == 6
			and initial.reserved_count == 0
			and initial.unreserved_count == 20
			and initial.dispatchable_count == 20,
		"初始 roster 投影总数、预留、未预留和可派数一致"
	)
	initial_counts[definition_id] = 999
	_check(
		city.infantry_count == 20
			and Dictionary(
				city.get_garrison_snapshot().unit_counts
			).get(definition_id, -1) == 20,
		"驻军读模型深拷贝，调用者不能改写城市真值"
	)

	city.infantry_count = 37
	_check(
		Dictionary(
			city.get_garrison_snapshot().unit_counts
		).get(definition_id, -1) == 37,
		"旧 infantry_count 写入口兼容到唯一驻军源"
	)
	city.infantry_count = -1
	_check(
		city.infantry_count == 37,
		"负数兼容写入被拒绝且不产生部分变化"
	)

	var standalone := GarrisonState.new(&"test_city")
	_check(
		standalone.set_unit_count(definition_id, 5),
		"驻军源可以建立合法兵种数量"
	)
	_check(
		standalone.try_add_units(definition_id, 3, 10)
			and standalone.get_unit_count(definition_id) == 8,
		"驻军返回／补充在容量内原子增加"
	)
	_check(
		not standalone.try_add_units(definition_id, 3, 10)
			and standalone.get_unit_count(definition_id) == 8,
		"驻军增加超过容量时零写入"
	)
	_check(
		standalone.try_remove_units(definition_id, 4)
			and standalone.get_unit_count(definition_id) == 4,
		"驻军扣损在现有数量内原子减少"
	)
	_check(
		not standalone.try_remove_units(definition_id, 5)
			and standalone.get_unit_count(definition_id) == 4,
		"驻军过量扣损被拒绝且零写入"
	)

	city.infantry_count = 50
	_check(
		city.select_general(&"general.vanguard")
			and city.get_effective_command_limit() == 40
			and city.get_dispatchable_infantry_count() == 40,
		"可派查询同时服从驻军总数、容量和将领指挥上限"
	)
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	_check(coordinator.configure(city), "战斗协调器绑定唯一城市权威")
	city.recruitment_cap = 10
	var rejected_request := coordinator.create_request(12)
	_check(
		rejected_request == null,
		"战斗预留不能超过容量约束后的权威可派数量"
	)
	_check(
		city.get_active_battle_reservation().is_empty()
			and city.infantry_count == 50
			and city.get_dispatchable_infantry_count() == 10,
		"容量阻断失败不产生预留或驻军部分写入"
	)
	city.recruitment_cap = 50
	var request := coordinator.create_request(12)
	_check(request != null and request.is_valid(), "可以从驻军预留 12 人")
	var reserved: Dictionary = city.get_garrison_snapshot()
	_check(
		reserved.total_count == 50
			and reserved.reserved_count == 12
			and reserved.unreserved_count == 38
			and reserved.dispatchable_count == 38,
		"预留不扣总驻军，只减少未预留和可派数量"
	)
	_check(
		city.infantry_count == 50,
		"战斗预留没有复制或提前扣除驻军"
	)
	_check(coordinator.cancel_request(), "战前取消释放驻军预留")
	var released: Dictionary = city.get_garrison_snapshot()
	_check(
		released.total_count == 50
			and released.reserved_count == 0
			and released.unreserved_count == 50
			and released.dispatchable_count == 40,
		"取消后总驻军不变，可派数恢复到指挥上限"
	)

	_check(
		city.army_status.text.contains("驻军 50")
			and city.army_status.text.contains("可派 40/40"),
		"城市侧栏真实显示驻军与可派上限"
	)
	city.select_general(&"")
	city.infantry_count = 20
	_check(city.queue_training(), "现有征募流程仍可下达一批步兵")
	_check(city.advance_one_day_for_test(), "城市战略日结算完成训练")
	_check(
		city.infantry_count == 25
			and city.get_garrison_snapshot().total_count == 25
			and city.get_last_daily_breakdown().training_completed == 5,
		"训练完成写回同一驻军源，不复制 infantry_count"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("V5_SINGLE_UNIT_GARRISON_SMOKE PASS")
		quit(0)
		return
	print("V5_SINGLE_UNIT_GARRISON_SMOKE FAIL: %s" % failures)
	quit(1)
