extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"

var _failures := 0
var _assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node = scene.get_node("ConstructionController")
	var build_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildEntryButton"
	)
	var camp_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)
	var status: Label = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildModeStatus"
	)
	_check(
		not scene.has_node("UI/Shell/ConstructionEntryPanel/ConfirmPlacementButton"),
		"scene tree has no separate building confirm button"
	)

	await _click(build_button.get_global_rect().get_center())
	_check(controller.is_choosing_template(), "real UI click opens catalog")
	await _click(camp_button.get_global_rect().get_center())
	_check(controller.is_placing(), "real UI click selects lumber camp")

	var legal_cell := Vector2i(18, 15)
	var legal_screen: Vector2 = await _move_to_cell(controller, legal_cell)
	_check(controller.preview_valid, "1152x648 real motion reaches a legal preview")
	_check(status.text.contains("可建造：左键放置"), "legal status explains direct click")
	var before_count: int = controller.get_building_count()
	await _click(legal_screen)
	_check(controller.get_building_count() == before_count + 1, "one real map click creates one order")
	_check(not controller.is_placing(), "successful click exits placement mode")
	await _click(legal_screen)
	_check(controller.get_building_count() == before_count + 1, "post-success click cannot duplicate")
	await _key(KEY_ESCAPE)

	await _select_camp(build_button, camp_button)
	var road_cell := Vector2i(18, 13)
	var road_screen: Vector2 = await _move_to_cell(controller, road_cell)
	_check(not controller.preview_valid, "road overlap preview is invalid")
	_check(status.text.contains("无法建造：与道路重叠"), "persistent status names road overlap")
	var before_rejected: Dictionary = controller.export_v5_campaign_snapshot()
	await _click(road_screen)
	_check(
		controller.get_placement_feedback_text() == "无法建造：与道路重叠",
		"real invalid click shows transient exact road reason"
	)
	_check(
		controller.export_v5_campaign_snapshot() == before_rejected,
		"rejected real click makes no save-state mutation"
	)

	await _key(KEY_R)
	_check(controller.get_preview_orientation() == 1, "real R input rotates preview")
	await _right_click(road_screen)
	_check(not controller.is_placing(), "real right click cancels without commit")

	await _select_camp(build_button, camp_button)
	var overlap_screen: Vector2 = await _move_to_cell(controller, legal_cell)
	_check(
		status.text.contains("无法建造：与其他建筑重叠"),
		"building overlap status names the blocking object class"
	)
	var overlap_count: int = controller.get_building_count()
	await _click(overlap_screen)
	_check(
		controller.get_building_count() == overlap_count
			and controller.get_placement_feedback_text() == "无法建造：与其他建筑重叠",
		"real building-overlap click is atomic and explicit"
	)
	await _key(KEY_ESCAPE)
	_check(not controller.is_placing(), "real Escape cancels without commit")

	controller.wood = 0
	controller.food = 0
	await _select_camp(build_button, camp_button)
	var shortage_screen: Vector2 = await _move_to_cell(controller, Vector2i(20, 15))
	_check(
		status.text.contains("材料不足：缺木材 40；下单后将等待材料"),
		"timed order shows exact shortage and remains orderable"
	)
	var shortage_count: int = controller.get_building_count()
	await _click(shortage_screen)
	_check(controller.get_building_count() == shortage_count + 1, "shortage still creates timed order")
	_check(controller.wood == 0 and controller.food == 0, "order does not prepay timed construction")
	_check(
		controller._player_failure_message({"reason_code": &"OUT_OF_BOUNDS"})
			== "无法建造：超出可建区域",
		"out-of-bounds reason has stable exact copy"
	)
	_check(
		controller._player_failure_message({
			"reason_code": &"INSUFFICIENT_RESOURCE",
			"shortages": [
				{"display_name": "木材", "missing": 7},
				{"display_name": "粮食", "missing": 2},
			],
		}) == "无法建造：缺少木材 7、粮食 2",
		"multiple shortages are complete and stable-order"
	)
	_check(
		controller._player_failure_message({"reason_code": &"UNKNOWN_COMMIT_FAILURE"})
			== "建造失败，请重试（R0B-UNKNOWN）",
		"unknown commit failure is never silent"
	)

	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var entry: Control = scene.get_node("UI/Shell/ConstructionEntryPanel")
		_check(
			entry.get_global_rect().end.x <= float(viewport_size.x)
				and entry.get_global_rect().end.y <= float(viewport_size.y),
			"%dx%d placement rail remains inside viewport" % [viewport_size.x, viewport_size.y]
		)
	await create_timer(2.6).timeout
	_check(controller.get_placement_feedback_text().is_empty(), "transient feedback clears without stacking")

	scene.queue_free()
	await process_frame
	if _failures == 0:
		print("M0_R0B_DIRECT_CLICK_FAILURE_FEEDBACK_SMOKE: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("M0_R0B_DIRECT_CLICK_FAILURE_FEEDBACK_SMOKE: FAIL (%d failures)" % _failures)
		quit(1)


func _select_camp(build_button: Button, camp_button: Button) -> void:
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())


func _cell_center(controller: Node, cell: Vector2i) -> Vector2:
	return controller.map_local_to_screen(
		controller.cell_to_map_local(cell) + Vector2(40.0, 40.0)
	)


func _move_to_cell(controller: Node, target: Vector2i) -> Vector2:
	var pointer := _cell_center(controller, target)
	for _attempt in range(6):
		await _move(pointer)
		if controller.preview_origin_cell == target:
			return pointer
		var current: Vector2i = controller.preview_origin_cell
		var correction := (
			_cell_center(controller, target) - _cell_center(controller, current)
		)
		pointer += correction
	return pointer


func _move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _click(position: Vector2) -> void:
	await _move(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame


func _right_click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
