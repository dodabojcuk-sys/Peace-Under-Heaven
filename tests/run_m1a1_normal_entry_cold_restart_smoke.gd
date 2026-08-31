extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"
const TARGET_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]

var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_normal_twenty_entry_authority()
	await _check_empty_force_feedback()
	await _check_cold_restore_build_slot_geometry()
	if failures == 0:
		print("M1A1_NORMAL_ENTRY_COLD_RESTART_SMOKE: PASS (%d assertions)" % assertions)
		quit(0)
	else:
		push_error("M1A1_NORMAL_ENTRY_COLD_RESTART_SMOKE: FAIL (%d failures)" % failures)
		quit(1)


func _check_normal_twenty_entry_authority() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var shell: Control = scene.get_node("UI/Shell")
	var entry: Button = shell.get_node("TopStatusBar/CurrentMainlineButton")
	var force: Dictionary = city.get_first_war_force_breakdown()
	var garrison: Dictionary = city.get_garrison_snapshot()
	_check(
		city.current_day == 1
			and city.get_first_war_state_id() == &"PREPARATION"
			and int(force.total_garrison_count) == 20
			and int(force.city_defense_occupied_count) == 0
			and int(force.battle_reserved_count) == 0
			and int(force.dispatch_reserved_count) == 0
			and int(force.already_dispatched_count) == 0
			and int(force.injured_or_unavailable_count) == 0
			and int(force.dispatchable_count) == 20
			and int(garrison.reserved_count) == 0,
		"normal new city derives 20 dispatchable infantry from the sole garrison authority"
	)
	_check(
		entry.visible
			and not entry.disabled
			and entry.text == "进入当前主线"
			and city.can_enter_first_war(),
		"a normal non-empty preparation force exposes an actionable current-mainline entry"
	)
	await _click(entry.get_global_rect().get_center())
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null
			and battle.request != null
			and battle.request.formal_city_entry
			and battle.request.committed_force.get_committed_total() == 20
			and int(city.get_active_battle_reservation().committed_count) == 20,
		"top-bar input transfers the real 20-person snapshot into one formal battle reservation"
	)
	await _click(entry.get_global_rect().get_center())
	_check(
		battle != null
			and city.get_formal_battle_scene() == battle
			and int(city.get_active_battle_reservation().committed_count) == 20,
		"a repeated entry click cannot duplicate the 20-person reservation"
	)
	if battle != null:
		for squad in battle.request.committed_force.squads:
			battle.set_squad_route(
				int(squad.squad_id),
				CommittedForceSnapshot.FRONT_ROUTE
			)
		_check(
			battle.start_battle(true)
				and battle.coordinator.active_session.accepted_orders.size()
					== battle.coordinator.active_session.squads.size(),
			"the concentrated normal force starts as one synchronized front assault"
		)
		battle.tick_timer.stop()
		for squad in battle.coordinator.active_session.squads:
			battle.issue_squad_order(
				int(squad.squad_id),
				BattleOrder.Command.ADVANCE
			)
		var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
		_check(
			result != null and result.outcome == BattleOutcome.Value.VICTORY,
			"the normal 20-person force has a real winning route through the C0 simulation"
		)
		if result != null:
			var summary: Dictionary = battle.confirm_pending_result()
			var contract := battle.coordinator.request_return_to_city()
			_check(
				not summary.is_empty()
					and contract != null
					and battle.complete_return_for_test(contract.city_input_restore_frame),
				"the 20-person victory settles once and returns through the existing contract"
			)
	await process_frame
	scene.queue_free()
	await process_frame


func _check_empty_force_feedback() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var shell: Control = scene.get_node("UI/Shell")
	var entry: Button = shell.get_node("TopStatusBar/CurrentMainlineButton")
	var reservation: Dictionary = city.reserve_army_dispatch(
		20,
		&"node.feedback",
		&"route.feedback",
		6000
	)
	await process_frame
	_check(
		not reservation.is_empty()
			and not city.can_enter_first_war()
			and entry.text == "无法出征：没有可派编队"
			and entry.tooltip_text.contains("可派兵力 0；城防占用 0；受伤 0"),
		"an empty legal force keeps a precise visible entry reason instead of a hidden 50-person gate"
	)
	await _click(entry.get_global_rect().get_center())
	var feedback: Label = shell.get_node("PlacementFeedback")
	_check(
		feedback.visible
			and feedback.text.contains("无法出征：没有可派编队")
			and city.get_formal_battle_scene() == null,
		"an empty-force entry click shows transient failure feedback without creating a battle"
	)
	_check(
		city.cancel_army_dispatch(StringName(reservation.transaction_id)),
		"empty-force feedback setup releases its one in-flight dispatch reservation"
	)
	scene.queue_free()
	await process_frame


func _check_cold_restore_build_slot_geometry() -> void:
	for target_size in TARGET_SIZES:
		root.size = target_size
		var source_scene := CITY_SCENE.instantiate() as Node2D
		root.add_child(source_scene)
		await process_frame
		await process_frame
		var source: Node = source_scene.get_node("ConstructionController")
		source.set_process(false)
		source.wood = 40
		_check(
			bool(source.start_build_project(LOGGING_CAMP_ID).success),
			"%dx%d creates a normal logging-camp build slot before save" % [target_size.x, target_size.y]
		)
		source.advance_city_time_for_test(180.0)
		var snapshot: Dictionary = source.export_v5_campaign_snapshot()
		var restored_scene := CITY_SCENE.instantiate() as Node2D
		root.add_child(restored_scene)
		await process_frame
		var restored: Node = restored_scene.get_node("ConstructionController")
		restored.set_process(false)
		var restore_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
		await process_frame
		await process_frame
		var shell: Control = restored_scene.get_node("UI/Shell")
		var panel: Panel = shell.get_node("ConstructionEntryPanel")
		var minimap: Panel = shell.get_node("MinimapPlaceholder")
		var top_bar: Panel = shell.get_node("TopStatusBar")
		var child_rects: Dictionary = shell.get_visible_construction_child_rects()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(target_size))
		_check(
			bool(restore_result.success)
				and restored.get_build_slot_state() == restored.BUILD_SLOT_READY_TO_PLACE
				and child_rects.has("BuildSlotDetail")
				and child_rects.has("BuildSlotPrimaryButton")
				and child_rects.has("BuildSlotCancelButton"),
			"%dx%d cold restore reconstructs the ready build-slot controls" % [target_size.x, target_size.y]
		)
		for child_name in child_rects:
			var child_rect: Rect2 = child_rects[child_name]
			_check(
				_is_inside(child_rect, panel.get_global_rect())
					and _is_inside(child_rect, viewport_rect)
					and not child_rect.intersects(top_bar.get_global_rect())
					and not child_rect.intersects(minimap.get_global_rect()),
				"%dx%d restored %s stays inside its panel and outside top/minimap rails" % [target_size.x, target_size.y, child_name]
			)
		var primary: Button = restored_scene.get_node(
			"UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotPrimaryButton"
		)
		await _click(primary.get_global_rect().get_center())
		_check(
			restored.is_placing(),
			"%dx%d restored build-slot primary control captures input without map click-through" % [target_size.x, target_size.y]
		)
		restored.cancel_placing()
		source_scene.queue_free()
		restored_scene.queue_free()
		await process_frame


func _click(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame


func _is_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.1
		and inner.position.y >= outer.position.y - 0.1
		and inner.end.x <= outer.end.x + 0.1
		and inner.end.y <= outer.end.y + 0.1
	)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		push_error("FAIL: %s" % description)
