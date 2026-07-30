extends SceneTree


var failures: Array[String] = []
var scene: Node
var city: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可加载")
	if packed_scene == null:
		_finish()
		return
	scene = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	city.set_process(false)

	var food_before: int = city.food
	var accepted: Dictionary = city.request_training()
	var accepted_order: Dictionary = accepted.order
	_check(
		accepted.success
			and accepted.error_id == &""
			and accepted_order.order_id
				== &"training.blackstone_city.000001"
			and accepted_order.phase == &"QUEUED",
		"正式入口建立稳定 ID 的唯一 QUEUED 训练单"
	)
	_check(
		city.food == food_before - 15
			and accepted_order.food_cost_committed == 15,
		"成功下单只从城市粮食真值扣除一次完整成本"
	)
	var queue_snapshot: Dictionary = city.get_training_queue_snapshot()
	_check(
		queue_snapshot.schema_version == 1
			and queue_snapshot.city_id == &"blackstone_city"
			and queue_snapshot.active_order_id
				== accepted_order.order_id
			and queue_snapshot.orders_by_id.size() == 1
			and city.training_queued_count == 5
			and city.training_complete_day == 2
			and city.last_training_order_day == 1,
		"队列源状态与三个兼容读投影一致"
	)
	queue_snapshot.orders_by_id[accepted_order.order_id].quantity = 999
	_check(
		city.training_queued_count == 5,
		"训练队列读模型深拷贝，调用者不能旁路改写"
	)

	var duplicate_food: int = city.food
	var duplicate_before: Dictionary = city.get_training_queue_snapshot()
	var duplicate: Dictionary = city.request_training()
	_check(
		not duplicate.success
			and duplicate.error_id == &"TRAINING_QUEUE_BUSY",
		"已有活动单时结构化拒绝重复训练"
	)
	_check(
		city.food == duplicate_food
			and city.get_training_queue_snapshot() == duplicate_before,
		"重复训练失败保持粮食、序列和订单零写入"
	)

	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 0.001
	city.set_city_time_paused(true)
	var paused_before: Dictionary = city.get_city_state()
	_check(
		city.advance_city_frame_for_test(10.0) == 0
			and city.current_day == paused_before.day
			and city.training_queued_count == 5
			and city.infantry_count == 20,
		"暂停在边界前一毫秒仍冻结战略时间和训练"
	)
	city.set_city_time_paused(false)
	_check(
		city.advance_city_frame_for_test(0.001) == 1
			and city.current_day == 2
			and city.infantry_count == 25
			and city.training_queued_count == 0,
		"1x 只通过正式战略日边界完成训练并写入驻军"
	)
	var completed_queue: Dictionary = city.get_training_queue_snapshot()
	_check(
		completed_queue.active_order_id == &""
			and completed_queue.orders_by_id[
				accepted_order.order_id
			].phase == &"COMPLETED"
			and completed_queue.orders_by_id[
				accepted_order.order_id
			].completed_day == 2,
		"完成单保留事实记录并清除派生活动订单"
	)
	var completed_garrison: int = city.infantry_count
	_check(
		city.advance_one_day_for_test()
			and city.infantry_count == completed_garrison,
		"后续日边界重放不会重复增加已完成训练"
	)

	_check(city.restart_first_map(), "2x 用例重置正式城市状态")
	city.set_process(false)
	_check(city.queue_training(), "2x 用例可下达训练")
	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 1.0
	_check(
		city.set_city_time_speed(2.0)
			and city.advance_city_frame_for_test(0.5) == 1
			and city.infantry_count == 25,
		"2x 在相同战略边界只完成一次训练"
	)

	_check(city.restart_first_map(), "4x 用例重置正式城市状态")
	city.set_process(false)
	_check(city.queue_training(), "4x 用例可下达训练")
	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 1.0
	_check(
		city.set_city_time_speed(4.0)
			and city.advance_city_frame_for_test(0.25) == 1
			and city.infantry_count == 25,
		"4x 在相同战略边界只完成一次训练"
	)

	_check(city.restart_first_map(), "战争阻断用例重置状态")
	city.set_process(false)
	_check(city.queue_training(), "战争阻断前可建立合格训练单")
	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 0.001
	city.first_war_state = city.FirstWarState.PENDING
	var blocked_queue: Dictionary = city.get_training_queue_snapshot()
	_check(
		city.advance_city_time_for_test(1000.0) == 0
			and city.current_day == 1
			and city.infantry_count == 20
			and city.get_training_queue_snapshot() == blocked_queue,
		"战争待决阻断期间战略时间和训练源状态完全冻结"
	)
	city.first_war_state = city.FirstWarState.PREPARATION
	_check(
		city.advance_city_time_for_test(0.001) == 1
			and city.infantry_count == 25,
		"战争阻断解除后不补算墙钟时间，只消费新授权时间"
	)

	_check(city.restart_first_map(), "场景切换用例重置状态")
	city.set_process(false)
	_check(city.queue_training(), "场景切换前可建立训练单")
	var switch_before: Dictionary = city.get_city_state()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	city.set_process(false)
	_check(
		city.current_day == switch_before.day
			and city.training_queued_count
				== switch_before.training_queued_count
			and city.infantry_count == switch_before.infantry_count,
		"城市到展示场景再返回不会合成时间或丢失训练单"
	)

	_check(city.restart_first_map(), "失败矩阵重置状态")
	city.set_process(false)
	var invalid_before := _training_truth()
	var unknown: Dictionary = city.request_training(&"unit.unknown", 5)
	_check(
		not unknown.success
			and unknown.error_id == &"UNKNOWN_UNIT_DEFINITION"
			and _training_truth() == invalid_before,
		"未知兵种结构化拒绝且零写入"
	)
	var wrong_quantity: Dictionary = city.request_training(
		city.INFANTRY_ROLE.role_id,
		4
	)
	_check(
		not wrong_quantity.success
			and wrong_quantity.error_id == &"INVALID_TRAINING_QUANTITY"
			and _training_truth() == invalid_before,
		"非权威批量结构化拒绝且零写入"
	)
	city.food = 14
	var no_food_before := _training_truth()
	var no_food: Dictionary = city.request_training()
	_check(
		not no_food.success
			and no_food.error_id == &"INSUFFICIENT_FOOD"
			and _training_truth() == no_food_before,
		"粮食不足结构化拒绝且不创建第二资源账本"
	)
	city.food = 80
	city.infantry_count = 48
	var cap_before := _training_truth()
	var cap_result: Dictionary = city.request_training()
	_check(
		not cap_result.success
			and cap_result.error_id == &"RECRUITMENT_CAPACITY"
			and _training_truth() == cap_before,
		"征募容量不足结构化拒绝且零写入"
	)
	city.infantry_count = 39
	_check(city.select_general(&"general.vanguard"), "指挥上限用例选择先锋将领")
	var command_before := _training_truth()
	var command_result: Dictionary = city.request_training()
	_check(
		not command_result.success
			and command_result.error_id == &"COMMAND_LIMIT"
			and _training_truth() == command_before,
		"有效指挥上限不足结构化拒绝且零写入"
	)
	city.select_general(&"")
	city.infantry_count = 20
	city.supply_shortage = true
	var supply_before := _training_truth()
	var supply_result: Dictionary = city.request_training()
	_check(
		not supply_result.success
			and supply_result.error_id == &"SUPPLY_SHORTAGE"
			and _training_truth() == supply_before,
		"补给短缺结构化拒绝且零写入"
	)
	city._refresh_city_ui()
	var ui_block: Dictionary = city.get_training_blocked_reason()
	_check(
		ui_block.error_id == &"SUPPLY_SHORTAGE"
			and city.army_status.text.contains("征募阻断：供给不足"),
		"结构化阻断原因通过既有军队 UI 读模型向玩家呈现"
	)

	_check(city.restart_first_map(), "完成失败注入重置状态")
	city.set_process(false)
	_check(city.queue_training(), "失败注入前建立合格训练单")
	city.recruitment_cap = 20
	var boundary_before := _training_truth()
	var boundary_day: int = city.current_day
	var boundary_food: int = city.food
	_check(
		not city.advance_one_day_for_test()
			and city.current_day == boundary_day
			and city.food == boundary_food
			and _training_truth() == boundary_before
			and city.get_last_training_failure_id()
				== &"TRAINING_COMPLETION_CAPACITY",
		"完成容量失败在日边界前预检，城市与队列整体零写入"
	)
	city.recruitment_cap = 50
	_check(
		city.advance_one_day_for_test()
			and city.infantry_count == 25
			and city.training_queued_count == 0,
		"失败条件解除后同一训练单可完成且只完成一次"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _training_truth() -> Dictionary:
	return {
		"food": city.food,
		"infantry_count": city.infantry_count,
		"queue": city.get_training_queue_snapshot(),
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("V5_TRAINING_QUEUE_SMOKE PASS")
		quit(0)
		return
	print("V5_TRAINING_QUEUE_SMOKE FAIL: %s" % failures)
	quit(1)
