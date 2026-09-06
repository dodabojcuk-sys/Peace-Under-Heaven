extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"
const TARGET_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]

var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_layout_contract()
	await _check_victory_settlement_return_and_cold_save()
	await _check_retreat_retry_preserves_mainline()
	await _check_defeat_does_not_clear_mainline()
	if failures == 0:
		print("M1A_CURRENT_MAINLINE_RETURN_SMOKE: PASS (%d assertions)" % assertions)
		quit(0)
	else:
		push_error("M1A_CURRENT_MAINLINE_RETURN_SMOKE: FAIL (%d failures)" % failures)
		quit(1)


func _check_layout_contract() -> void:
	for target_size in TARGET_SIZES:
		root.size = target_size
		var setup := await _make_pending_city(50, true)
		var scene: Node2D = setup.scene
		var shell: Control = scene.get_node("UI/Shell")
		var top_bar: Control = shell.get_node("TopStatusBar")
		var entry: Button = top_bar.get_node("CurrentMainlineButton")
		var regions: Dictionary = shell.get_top_status_region_rects()
		_check(
			entry.visible
				and not entry.disabled
				and entry.text == "进入当前主线"
				and entry.mouse_filter == Control.MOUSE_FILTER_STOP,
			"%dx%d current-mainline action is readable and captures pointer input"
			% [target_size.x, target_size.y]
		)
		_check(
			_is_inside(entry.get_global_rect(), regions.deadline_and_pressure)
				and _is_inside(regions.deadline_and_pressure, top_bar.get_global_rect())
				and not (regions.deadline_and_pressure as Rect2).intersects(
					regions.date_and_settlement as Rect2
				)
				and not (regions.deadline_and_pressure as Rect2).intersects(
					regions.speed_and_pause as Rect2
				),
			"%dx%d action remains bounded by the deadline/pressure region"
			% [target_size.x, target_size.y]
		)
		scene.queue_free()
		await process_frame


func _check_victory_settlement_return_and_cold_save() -> void:
	root.size = Vector2i(1152, 648)
	var setup := await _make_pending_city(50, true)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var entry: Button = scene.get_node("UI/Shell/TopStatusBar/CurrentMainlineButton")
	var build_before: Dictionary = city.get_build_slot_snapshot()
	city.recruitment_cap = 100
	_check(
		StringName(build_before.state) == city.BUILD_SLOT_READY_TO_PLACE
			and city.queue_training(),
		"ready build token and real training queue exist before the battle trip"
	)
	var queue_before: Dictionary = city.get_training_queue_snapshot()
	var queue_id := StringName(queue_before.active_order_id)
	var map_building_count: int = city.get_building_count()
	entry.emit_signal("pressed")
	await process_frame
	_check(
		scene.get_node("UI/Shell/ExpeditionPreparationPanel").visible
			and city.get_formal_battle_scene() == null
			and city.get_building_count() == map_building_count,
		"top-bar click opens 出征准备 without map click-through or implicit battle entry"
	)
	var selected_ids: Array[StringName] = []
	for formation in city.get_formation_roster():
		if int(formation.member_count) > 0:
			selected_ids.append(StringName(formation.formation_id))
	var departure: Dictionary = city.commit_expedition_attempt(selected_ids)
	_check(bool(departure.success), "出征准备确认建立一次已付费 immutable 编队快照")
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null:
		_check(city.enter_first_war_battle(), "已确认出征可以进入正式 C0")
		battle = city.get_formal_battle_scene()
	_check(
		battle != null
			and battle.formal_city_mode
			and battle.city_scene == scene
			and battle.request != null
			and battle.request.formal_city_entry,
		"确认后的唯一正式城市战场复用已保存快照"
	)
	var first_request_id := battle.request.transaction_id if battle != null else &""
	entry.emit_signal("pressed")
	_check(
		city.get_formal_battle_scene() == battle
			and battle != null
			and battle.request.transaction_id == first_request_id,
		"repeat entry click cannot create a second active attempt"
	)
	if battle == null:
		scene.queue_free()
		return
	_check(battle.start_battle(), "formal current-mainline attempt starts the existing C0 battle")
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	var preview_state: Dictionary = city.get_city_state()
	_check(
		result != null
			and result.outcome == BattleOutcome.Value.VICTORY
			and battle.result_input_blocker.visible
			and battle.result_panel.visible
			and "确认后写回城市" in battle.result_label.text
			and city.get_city_state() == preview_state,
		"terminal preview is input-blocked and has zero persistent mutation before confirm"
	)
	_check(
		battle.coordinator.confirm_result(BattleResult.new()).is_empty()
			and battle.coordinator.last_result_error_id == &"RESULT_PAYLOAD_CONFLICT"
			and city.get_city_state() == preview_state,
		"conflicting settlement payload rejects atomically with zero city writes"
	)
	var summary := battle.confirm_pending_result()
	var after_confirm: Dictionary = city.get_city_state()
	_check(
		not summary.is_empty()
			and bool(summary.mainline_cleared)
			and bool(city.get_mainline_pressure_state().cleared)
			and city.get_pressure_modifier_permille(&"construction") == 1000
			and city.get_pressure_modifier_permille(&"production") == 1000,
		"one successful victory confirm clears current mainline and stops pressure modifiers"
	)
	_check(
		battle.confirm_pending_result() == summary
			and city.get_city_state() == after_confirm,
		"same result confirmation is idempotent with no duplicate writeback"
	)
	var return_contract := battle.coordinator.request_return_to_city()
	_check(return_contract != null, "confirmed current-mainline result creates the existing return contract")
	if return_contract != null:
		_check(
			battle.complete_return_for_test(return_contract.city_input_restore_frame),
			"input-guarded return restores the same permanent city"
		)
	await process_frame
	var losses_before: Dictionary = city.get_mainline_pressure_state().permanent_losses
	_check(
		city.get_formal_battle_scene() == null
			and scene.visible
			and StringName(city.get_build_slot_snapshot().state)
				== city.BUILD_SLOT_READY_TO_PLACE
			and int(city.get_build_slot_snapshot().paid_costs.wood)
				== int(build_before.paid_costs.wood)
			and Dictionary(city.get_training_queue_snapshot().orders_by_id).has(queue_id),
		"return preserves the ready build token and training order history"
	)
	_check(
		city.acknowledge_first_war_result()
			and city.advance_one_day_for_test()
			and city.get_mainline_pressure_state().permanent_losses == losses_before,
		"cleared current mainline stops future pressure without undoing permanent losses"
	)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var reload_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(reload_scene)
	await process_frame
	var reloaded: Node = reload_scene.get_node("ConstructionController")
	reloaded.set_process(false)
	var restored: Dictionary = reloaded.restore_v5_campaign_snapshot(snapshot)
	_check(
		not snapshot.is_empty()
			and bool(restored.success)
			and reloaded.export_v5_campaign_snapshot() == snapshot,
		"post-return city state cold-restores mainline, ledger, build slot, and training exactly"
	)
	scene.queue_free()
	reload_scene.queue_free()
	await process_frame


func _check_retreat_retry_preserves_mainline() -> void:
	var setup := await _make_pending_city(8, false)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var battle: C0BattleGraybox = _enter_and_finish(
		city,
		BattleOrder.Command.RETREAT,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	if battle == null:
		scene.queue_free()
		return
	var summary := battle.confirm_pending_result()
	var contract := battle.coordinator.request_return_to_city()
	if contract != null:
		battle.complete_return_for_test(contract.city_input_restore_frame)
	await process_frame
	_check(
		StringName(summary.outcome) == &"RETREAT"
			and not bool(city.get_mainline_pressure_state().cleared)
			and city.acknowledge_first_war_result(),
		"retreat writes its loss but never clears the current mainline"
	)
	var before_retry: Dictionary = city.get_city_state()
	var entry: Button = scene.get_node("UI/Shell/TopStatusBar/CurrentMainlineButton")
	entry.emit_signal("pressed")
	await process_frame
	var retry_ids: Array[StringName] = []
	for formation in city.get_formation_roster():
		if int(formation.member_count) > 0:
			retry_ids.append(StringName(formation.formation_id))
	var retry_departure: Dictionary = city.commit_expedition_attempt(retry_ids)
	var launch_retry: bool = (
		bool(retry_departure.success) and city.enter_first_war_battle()
	)
	var retry: C0BattleGraybox = city.get_formal_battle_scene()
	_check(
		scene.get_node("UI/Shell/ExpeditionPreparationPanel").visible
			and launch_retry
			and retry != null
			and retry.request != null
			and city.current_day == int(before_retry.day)
			and city.get_mainline_pressure_state().deadline_day
				== int(before_retry.get("mainline_deadline_day", city.get_mainline_pressure_state().deadline_day)),
		"retreat retry creates a new attempt without resetting strategic time or deadline"
	)
	if retry != null:
		retry.abort_formal_entry()
	await process_frame
	scene.queue_free()
	await process_frame


func _check_defeat_does_not_clear_mainline() -> void:
	var setup := await _make_pending_city(1, false)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var battle: C0BattleGraybox = _enter_and_finish(
		city,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	if battle == null:
		scene.queue_free()
		return
	var summary := battle.confirm_pending_result()
	var contract := battle.coordinator.request_return_to_city()
	if contract != null:
		battle.complete_return_for_test(contract.city_input_restore_frame)
	await process_frame
	_check(
		StringName(summary.outcome) == &"DEFEAT"
			and not bool(city.get_mainline_pressure_state().cleared)
			and city.city_fallen,
		"defeat keeps current-mainline pressure unresolved and retains the city-loss state"
	)
	scene.queue_free()
	await process_frame


func _enter_and_finish(
	city: Node,
	command: BattleOrder.Command,
	_route_id: StringName
) -> C0BattleGraybox:
	if not city.enter_first_war_battle():
		_check(false, "formal current-mainline entry setup succeeds")
		return null
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null or not battle.start_battle():
		_check(false, "formal current-mainline battle starts")
		return null
	battle.tick_timer.stop()
	# R1E deployment routes belong to the persisted departure snapshot.  Tests
	# may issue battle orders but must not mutate a prepared force in C0.
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), command)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	_check(result != null, "formal current-mainline battle produces terminal facts")
	return battle


func _make_pending_city(player_count: int, ready_build_token: bool) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.infantry_count = player_count
	city.food = 160
	if ready_build_token:
		city.wood = 40
		city.start_build_project(LOGGING_CAMP_ID)
		city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
		city.advance_city_time_for_test(180.0)
	else:
		city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
	city.infantry_count = player_count
	city.food = 160
	city._refresh_city_ui()
	return {"scene": scene, "city": city}


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
