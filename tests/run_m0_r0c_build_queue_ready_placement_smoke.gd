extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"

var _failures := 0
var _assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_real_input_queue_to_ready_placement()
	await _check_refund_and_road_independence()
	await _check_state_persistence_and_pressure()
	await _check_schema_five_and_legacy_bridge()
	if _failures == 0:
		print("M0_R0C_BUILD_QUEUE_READY_PLACEMENT_SMOKE: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("M0_R0C_BUILD_QUEUE_READY_PLACEMENT_SMOKE: FAIL (%d failures)" % _failures)
		quit(1)


func _check_real_input_queue_to_ready_placement() -> void:
	var context := await _new_city()
	var scene: Node = context.scene
	var controller: Node = context.controller
	var build_button: Button = scene.get_node(
		"UI/Shell/GovernanceWorkspace/GovernanceMargin/GovernanceContent/GovernanceCatalogButton"
	)
	var camp_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)
	var primary_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotPrimaryButton"
	)
	var rotate_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/RotateButton"
	)
	controller.wood = 0
	var initial_count: int = controller.get_building_count()
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())
	var waiting: Dictionary = controller.get_build_slot_snapshot()
	_check(
		StringName(waiting.state) == controller.BUILD_SLOT_WAITING_MATERIAL
		and int(waiting.progress_milliseconds) == 0
		and int(waiting.paid_costs.wood) == 0,
		"actual catalog click registers a zero-resource unstarted project"
	)
	_check(
		controller.get_building_count() == initial_count,
		"zero-resource project creates no map foundation or occupancy"
	)
	var second: Dictionary = controller.start_build_project(LOGGING_CAMP_ID)
	_check(
		not second.success and second.reason_code == &"BUILD_SLOT_OCCUPIED",
		"single city slot rejects a second project"
	)
	controller.set_city_time_paused(true)
	controller.wood = 10
	controller.advance_city_time_for_test(20.0)
	_check(
		int(controller.get_build_slot_snapshot().progress_milliseconds) == 0
		and controller.wood == 10,
		"global pause prevents both progress and payment"
	)
	controller.set_city_time_paused(false)
	controller.advance_city_time_for_test(45.0)
	var partial: Dictionary = controller.get_build_slot_snapshot()
	_check(
		StringName(partial.state) == controller.BUILD_SLOT_PRODUCING
		and int(partial.progress_milliseconds) == 45000
		and int(partial.paid_costs.wood) == 10
		and controller.wood == 0,
		"queue progress and incremental payment share one paid tick"
	)
	controller.advance_city_time_for_test(1.0)
	var blocked: Dictionary = controller.get_build_slot_snapshot()
	_check(
		StringName(blocked.state) == controller.BUILD_SLOT_WAITING_MATERIAL
		and int(blocked.progress_milliseconds) == 45000,
		"partial project stops at its last paid progress"
	)
	controller.wood = 30
	controller.advance_city_time_for_test(135.0)
	var ready: Dictionary = controller.get_build_slot_snapshot()
	_check(
		StringName(ready.state) == controller.BUILD_SLOT_READY_TO_PLACE
		and int(ready.progress_milliseconds) == int(ready.required_milliseconds)
		and int(ready.paid_costs.wood) == 40
		and controller.wood == 0,
		"refill auto-resumes to one exactly paid ready token"
	)
	_check(
		controller.get_building_count() == initial_count,
		"ready state still has no world building or foundation"
	)
	controller.advance_city_time_for_test(30.0)
	_check(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE
			and int(controller.get_build_slot_snapshot().paid_costs.wood) == 40,
		"continued time neither duplicates nor recharges the ready token"
	)
	# BuildSlotContent is a real VBoxContainer; wait for its queued child sort
	# before deriving a pointer coordinate from its resized primary control.
	await process_frame
	await _click(primary_button.get_global_rect().get_center())
	_check(controller.is_placing(), "actual ready button enters placement mode")
	var road_screen := await _move_to_cell(controller, Vector2i(18, 13))
	var before_invalid: Dictionary = controller.export_v5_campaign_snapshot()
	await _click(road_screen)
	_check(
		controller.get_build_slot_state() == controller.BUILD_SLOT_PLACEMENT_ACTIVE
		and controller.get_placement_feedback_text() == "无法放置：与道路重叠"
		and controller.get_building_count() == initial_count,
		"actual invalid map click names road overlap and retains the token"
	)
	_check(
		int(controller.export_v5_campaign_snapshot().build_slot.paid_costs.wood)
		== int(before_invalid.build_slot.paid_costs.wood),
		"invalid placement does not mutate paid resources"
	)
	await _right_click(road_screen)
	_check(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE
		and not controller.is_placing(),
		"right click returns the same token to ready state"
	)
	await _click(primary_button.get_global_rect().get_center())
	await _key(KEY_ESCAPE)
	_check(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE,
		"Escape returns the same token to ready state"
	)
	await _click(primary_button.get_global_rect().get_center())
	var legal_screen := await _move_to_cell(controller, Vector2i(18, 15))
	var before_ui_click: int = controller.get_building_count()
	await _click(rotate_button.get_global_rect().get_center())
	_check(
		controller.get_building_count() == before_ui_click
		and controller.get_preview_orientation() == 1,
		"actual UI rotation does not click through to the map"
	)
	legal_screen = await _move_to_cell(controller, Vector2i(18, 15))
	var wood_before_place: int = controller.wood
	await _click(legal_screen)
	_check(
		controller.get_building_count() == initial_count + 1
		and controller.get_build_slot_state() == controller.BUILD_SLOT_IDLE
		and not controller.is_placing(),
		"legal map click creates exactly one completed building and frees the slot"
	)
	var placed_id: int = controller.get_placement_ids().back()
	var placed: Dictionary = controller.get_building_record(placed_id)
	_check(
		StringName(placed.lifecycle_state) == &"running"
		and StringName(placed.construction_state) == &"COMPLETED"
		and controller.wood == wood_before_place,
		"ready placement creates no foundation and performs no second payment"
	)
	await _click(legal_screen)
	_check(
		controller.get_building_count() == initial_count + 1,
		"post-success second click cannot duplicate the building"
	)
	await _drop_city(scene)


func _check_refund_and_road_independence() -> void:
	var context := await _new_city()
	var scene: Node = context.scene
	var controller: Node = context.controller
	controller.wood = 200
	var started: Dictionary = controller.start_build_project(LOGGING_CAMP_ID)
	controller.advance_city_time_for_test(45.0)
	var paid := int(controller.get_build_slot_snapshot().paid_costs.wood)
	_check(started.success and paid > 0, "generic slot starts and invests resources")
	var road_started: bool = controller.begin_road_mode(Vector2(400.0, 300.0))
	_check(
		road_started and controller.is_road_placing()
		and controller.get_build_slot_state() == controller.BUILD_SLOT_PRODUCING,
		"road mode stays independent while a building project is active"
	)
	controller.cancel_placing()
	var refund: Dictionary = controller.cancel_build_project()
	_check(
		refund.success and controller.wood == 200
		and controller.get_build_slot_state() == controller.BUILD_SLOT_IDLE,
		"atomic cancellation returns exact investment above visible capacity"
	)
	await _drop_city(scene)


func _check_state_persistence_and_pressure() -> void:
	var context := await _new_city()
	var scene: Node = context.scene
	var controller: Node = context.controller
	await _check_slot_roundtrip(controller, controller.BUILD_SLOT_IDLE, "IDLE")

	controller.wood = 40
	controller.start_build_project(LOGGING_CAMP_ID)
	await _check_slot_roundtrip(controller, controller.BUILD_SLOT_PRODUCING, "PRODUCING")
	controller.cancel_build_project()

	controller.wood = 0
	controller.start_build_project(LOGGING_CAMP_ID)
	await _check_slot_roundtrip(
		controller,
		controller.BUILD_SLOT_WAITING_MATERIAL,
		"zero-progress WAITING_MATERIAL"
	)
	controller.cancel_build_project()

	controller.wood = 10
	controller.start_build_project(LOGGING_CAMP_ID)
	controller.advance_city_time_for_test(45.0)
	controller.advance_city_time_for_test(1.0)
	var mid_waiting: Dictionary = controller.get_build_slot_snapshot()
	await _check_slot_roundtrip(
		controller,
		controller.BUILD_SLOT_WAITING_MATERIAL,
		"mid-progress WAITING_MATERIAL"
	)
	_check(
		int(mid_waiting.progress_milliseconds) > 0
		and int(mid_waiting.progress_milliseconds) < int(mid_waiting.required_milliseconds),
		"mid-progress waiting snapshot remains partial"
	)
	controller.cancel_build_project()

	controller.wood = 40
	controller.start_build_project(LOGGING_CAMP_ID)
	controller.advance_city_time_for_test(180.0)
	await _check_slot_roundtrip(
		controller,
		controller.BUILD_SLOT_READY_TO_PLACE,
		"READY_TO_PLACE"
	)
	controller.cancel_build_project()

	var synthetic: Dictionary = controller.export_v5_campaign_snapshot()
	synthetic.build_slot = {
		"state": controller.BUILD_SLOT_PRODUCING,
		"definition_id": LOGGING_CAMP_ID,
		"progress_milliseconds": 45000,
		"required_milliseconds": 180000,
		"total_costs": {&"wood": 40, &"food": 20},
		"paid_costs": {&"wood": 10, &"food": 5},
		"missing_resource_ids": [],
		"orientation": 0,
		"completion_notified": false,
	}
	var multi_context := await _new_city()
	var multi: Node = multi_context.controller
	var multi_restore: Dictionary = multi.restore_v5_campaign_snapshot(synthetic)
	var wood_before: int = multi.wood
	var food_before: int = multi.food
	var multi_refund: Dictionary = multi.cancel_build_project()
	_check(
		multi_restore.success and multi_refund.success
		and multi.wood == wood_before + 10
		and multi.food == food_before + 5
		and multi.get_build_slot_state() == multi.BUILD_SLOT_IDLE,
		"multi-resource cancellation refunds one atomic ledger transaction"
	)
	await _drop_city(multi_context.scene)

	controller.current_day = 12
	controller.wood = 40
	controller.start_build_project(LOGGING_CAMP_ID)
	var pressure_modifier: int = controller.get_pressure_modifier_permille(&"construction")
	var pressure_eta: String = controller.get_build_slot_presentation().eta_text
	controller.advance_city_time_for_test(10.0)
	var pressured: Dictionary = controller.get_build_slot_snapshot()
	_check(
		pressure_modifier == 450
		and int(pressured.progress_milliseconds) == 4500
		and int(pressured.paid_costs.wood) == 1
		and pressure_eta.begins_with("第 "),
		"pressure modifier slows queue progress and ETA while preserving proportional cost"
	)
	await _drop_city(scene)


func _check_slot_roundtrip(
	source: Node,
	expected_state: StringName,
	description: String
) -> void:
	var snapshot: Dictionary = source.export_v5_campaign_snapshot()
	var target_context := await _new_city()
	var target: Node = target_context.controller
	var restored: Dictionary = target.restore_v5_campaign_snapshot(snapshot)
	_check(
		restored.success
		and target.get_build_slot_state() == expected_state
		and target.get_build_slot_snapshot() == snapshot.build_slot
		and target.get_building_count() == source.get_building_count(),
		"current campaign schema roundtrip preserves %s" % description
	)
	await _drop_city(target_context.scene)


func _check_schema_five_and_legacy_bridge() -> void:
	var context := await _new_city()
	var scene: Node = context.scene
	var controller: Node = context.controller
	controller.wood = 40
	controller.start_build_project(LOGGING_CAMP_ID)
	controller.advance_city_time_for_test(180.0)
	controller.activate_ready_placement(Vector2(400.0, 300.0))
	var active_save: Dictionary = controller.export_v5_campaign_snapshot()
	_check(
		int(active_save.schema_version) == V5CampaignSnapshot.SCHEMA_VERSION
		and StringName(active_save.build_slot.state) == controller.BUILD_SLOT_READY_TO_PLACE,
		"current campaign schema normalizes placement-active runtime state to ready"
	)
	var restore_context := await _new_city()
	var restored: Node = restore_context.controller
	var restore: Dictionary = restored.restore_v5_campaign_snapshot(active_save)
	_check(
		restore.success
		and restored.get_build_slot_state() == restored.BUILD_SLOT_READY_TO_PLACE
		and not restored.is_placing(),
		"save load restores one ready token without a ghost"
	)
	await _drop_city(restore_context.scene)
	controller.cancel_placing()
	controller.cancel_build_project()
	controller.wood = 40
	var legacy_id: int = controller.place_definition_at_cell(
		LOGGING_CAMP_ID,
		Vector2i(18, 15),
		true,
		false,
		0
	)
	var second_legacy_id: int = controller.place_definition_at_cell(
		LOGGING_CAMP_ID,
		Vector2i(22, 15),
		true,
		false,
		0
	)
	controller.advance_city_time_for_test(45.0)
	var schema4: Dictionary = controller.export_v5_campaign_snapshot()
	schema4.schema_version = 4
	schema4.erase("expedition_attempt")
	schema4.garrison = _legacy_garrison_projection(schema4.garrison)
	schema4.erase("build_slot")
	var migration: Dictionary = controller.validate_v5_campaign_snapshot(schema4)
	_check(
		legacy_id > 0 and second_legacy_id > 0 and migration.valid
		and int(migration.snapshot.schema_version) == V5CampaignSnapshot.SCHEMA_VERSION
		and StringName(migration.snapshot.build_slot.state) == &"IDLE"
		and migration.snapshot.placements.size() == 2
		and int(migration.snapshot.placements[0].construction_progress_milliseconds) == 45000,
		"schema 4 multiple legacy foundations migrate without movement, completion, or repayment"
	)
	var legacy_context := await _new_city()
	var legacy_target: Node = legacy_context.controller
	var legacy_restore: Dictionary = legacy_target.restore_v5_campaign_snapshot(schema4)
	var blocked: Dictionary = legacy_target.start_build_project(LOGGING_CAMP_ID)
	_check(
		legacy_restore.success and not blocked.success
		and blocked.reason_code == &"LEGACY_CONSTRUCTION_LOCK",
		"restored legacy construction locks only the new build slot"
	)
	await _drop_city(legacy_context.scene)
	await _drop_city(scene)


func _legacy_garrison_projection(current: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"city_id": current.city_id,
		"unit_counts_by_definition_id": Dictionary(
			current.unit_counts_by_definition_id
		).duplicate(true),
	}


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node = scene.get_node("ConstructionController")
	controller.set_process(false)
	return {"scene": scene, "controller": controller}


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame


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
		pointer += _cell_center(controller, target) - _cell_center(controller, current)
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
	await _move(position)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
