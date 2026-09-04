extends SceneTree


## R1E keeps the city roster, food transaction, immutable battle request and
## settlement roster as one causal chain.  This runner deliberately uses the
## public controller/C0 contract; it never mutates a prepared request or a
## saved attempt fixture in place.
const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const TARGET_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_preparation_modal_layout()
	await _check_selection_validation_and_idempotence()
	await _check_active_attempt_cold_restore()
	await _check_retreat_roster_writeback_once()
	await _check_victory_and_defeat_roster_writeback_once()
	await _check_cross_day_training_and_applied_integrity()
	await _check_v5_envelope_migrates_to_v6_roster()
	_check(
		load("res://tests/run_city_governance_interaction_smoke.gd") != null,
		"道路治理仍由既有治理 runner 覆盖，R1E 不复制第二套路网算法"
	)
	_finish()


func _check_preparation_modal_layout() -> void:
	for target_size in TARGET_SIZES:
		root.size = target_size
		var context := await _new_city(20, 80)
		var scene: Node2D = context.scene
		var city: Node = context.city
		var shell: Control = scene.get_node("UI/Shell")
		var entry: Button = shell.get_node("TopStatusBar/CurrentMainlineButton")
		var modal: ExpeditionPreparationPanel = shell.get_node(
			"ExpeditionPreparationPanel"
		)
		entry.emit_signal("pressed")
		await process_frame
		await process_frame
		var card_rect := modal.get_card_rect()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(target_size))
		var cancel_rect := modal.cancel_button.get_global_rect()
		var confirm_rect := modal.confirm_button.get_global_rect()
		var legacy_retreat: Button = shell.get_node(
			"BuildingDetailPanel/FirstWarActions/OrderRetreatButton"
		)
		_check(
			modal.visible
				and modal.mouse_filter == Control.MOUSE_FILTER_STOP
				and _inside(card_rect, viewport_rect)
				and _inside(cancel_rect, card_rect)
				and _inside(confirm_rect, card_rect)
				and cancel_rect.size.y >= 44.0
				and confirm_rect.size.y >= 44.0,
			"%dx%d 出征准备使用容器边界、完整按钮命中区和模态输入捕获"
			% [target_size.x, target_size.y]
		)
		_check(
			modal.formation_list.get_child_count() == 3
				and modal.validation_message.text.contains("请选择至少一支")
				and modal.confirm_button.disabled,
			"%dx%d 三支永久编队、空选原因和禁用确认一致"
			% [target_size.x, target_size.y]
		)
		_check(
			not legacy_retreat.visible and legacy_retreat.disabled,
			"%dx%d 城市旧战前撤退旁路保持隐藏禁用，撤退只从正式 C0 结算"
			% [target_size.x, target_size.y]
		)
		city.close_expedition_preparation()
		await _drop_scene(scene)


func _check_selection_validation_and_idempotence() -> void:
	var context := await _new_city(20, 20)
	var scene: Node2D = context.scene
	var city: Node = context.city
	var roster: Array[Dictionary] = city.get_formation_roster()
	var first_id := StringName(roster[0].formation_id)
	var second_id := StringName(roster[1].formation_id)
	var third_id := StringName(roster[2].formation_id)
	var before_empty: Dictionary = city.export_v5_campaign_snapshot()
	var empty: Dictionary = city.commit_expedition_attempt([])
	_check(
		not bool(empty.success)
			and StringName(empty.error_id) == &"EXPEDITION_VALIDATION"
			and city.export_v5_campaign_snapshot() == before_empty,
		"空选被拒绝且粮草、attempt、持久化快照零写入"
	)
	var too_many: Array[StringName] = [first_id, second_id, third_id, &"formation.unknown"]
	var invalid_selection: Dictionary = city.get_expedition_preparation_model(too_many)
	_check(
		not bool(invalid_selection.can_confirm)
			and str(invalid_selection.blocked_reason).contains("已变化"),
		"无效第四项不会绕过 1–3 队选择边界"
	)
	var selected: Array[StringName] = [first_id, second_id]
	var model: Dictionary = city.get_expedition_preparation_model(selected)
	var selected_total := int(roster[0].member_count) + int(roster[1].member_count)
	_check(
		bool(model.can_confirm)
			and int(model.selected_formation_count) == 2
			and int(model.selected_total) == selected_total
			and int(model.food_cost) == ceili(float(selected_total) / 5.0)
			and int(model.food_after) == 20 - int(model.food_cost),
		"两支编队的总兵力、向上取整粮草公式和出征后粮食可追溯"
	)
	city.food = int(model.food_cost) - 1
	var before_shortage: Dictionary = city.export_v5_campaign_snapshot()
	var shortage: Dictionary = city.commit_expedition_attempt(selected)
	_check(
		not bool(shortage.success)
			and city.export_v5_campaign_snapshot() == before_shortage,
		"粮食不足拒绝确认且不创建预留、不扣粮、不启动战场"
	)
	city.food = 20
	var departure: Dictionary = city.commit_expedition_attempt(selected)
	var food_after_departure: int = city.food
	var attempt_after_departure: Dictionary = city.get_expedition_attempt()
	_check(
		bool(departure.success)
			and StringName(attempt_after_departure.phase) == &"RESERVED"
			and int(attempt_after_departure.committed_total) == selected_total
			and food_after_departure == int(model.food_after),
		"确认原子建立 immutable attempt、一次扣粮并保留正式出征快照"
	)
	var duplicate: Dictionary = city.commit_expedition_attempt(selected)
	_check(
		not bool(duplicate.success)
			and city.food == food_after_departure
			and city.get_expedition_attempt() == attempt_after_departure,
		"重复确认幂等：不再扣粮、不重写 attempt、不复制预留"
	)
	_check(city.enter_first_war_battle(), "保存后的正式 attempt 可由唯一城市入口加载到 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null
			and battle.request != null
			and battle.request.committed_force.squads.size() == 2
			and StringName(battle.request.committed_force.squads[0].formation_id) == first_id
			and StringName(battle.request.committed_force.squads[1].formation_id) == second_id,
		"战场只加载确认的两支编队，未选编队不进入快照"
	)
	if battle != null:
		_check(
			not battle.request_exit_or_return()
				and city.food == food_after_departure
				and city.get_expedition_attempt() == attempt_after_departure,
			"已付费 RESERVED 退出明确拒绝，绝不静默退款或取消"
		)
		battle.abort_formal_entry()
	await _drop_scene(scene)


func _check_active_attempt_cold_restore() -> void:
	var source_context := await _new_city(20, 40)
	var source_scene: Node2D = source_context.scene
	var source: Node = source_context.city
	var selected_id := StringName(source.get_formation_roster()[0].formation_id)
	var departure: Dictionary = source.commit_expedition_attempt([selected_id])
	_check(bool(departure.success) and source.enter_first_war_battle(), "ACTIVE 冷恢复前建立真实已付费出征")
	var battle := source.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "ACTIVE 冷恢复取得 C0 场景")
		await _drop_scene(source_scene)
		return
	_check(battle.start_battle(), "已付费请求切换 ACTIVE 时不重建事务")
	battle.tick_timer.stop()
	var food_after_departure: int = source.food
	var attempt_before_reload: Dictionary = source.get_expedition_attempt()
	var snapshot: Dictionary = source.export_v5_campaign_snapshot()
	_check(
		StringName(attempt_before_reload.phase) == &"ACTIVE"
			and not snapshot.is_empty()
			and StringName(snapshot.expedition_attempt.phase) == &"ACTIVE",
		"ACTIVE attempt 被 V6 持久化，而非把战斗会话序列化进城市"
	)
	battle.abort_formal_entry()
	var restored_context := await _new_city(20, 1)
	var restored_scene: Node2D = restored_context.scene
	var restored: Node = restored_context.city
	var restore: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(
		bool(restore.success)
			and restored.food == food_after_departure
			and restored.get_expedition_attempt() == attempt_before_reload,
		"冷恢复保留同一 attempt、同一粮草余额与 immutable 编队快照"
	)
	_check(
		restored.enter_first_war_battle()
			and restored.food == food_after_departure
			and StringName(restored.get_expedition_attempt().attempt_id)
				== StringName(attempt_before_reload.attempt_id),
		"ACTIVE 尝试重载从 tick 0 复建战场，不二次扣粮或新建 attempt"
	)
	var reloaded_battle := restored.get_formal_battle_scene() as C0BattleGraybox
	if reloaded_battle != null:
		reloaded_battle.abort_formal_entry()
	await _drop_scene(source_scene)
	await _drop_scene(restored_scene)


func _check_retreat_roster_writeback_once() -> void:
	var context := await _new_city(20, 50)
	var scene: Node2D = context.scene
	var city: Node = context.city
	var roster_before: Array[Dictionary] = city.get_formation_roster()
	var selected_id := StringName(roster_before[0].formation_id)
	var unselected_id := StringName(roster_before[1].formation_id)
	var unselected_before := int(roster_before[1].member_count)
	_check(
		bool(city.commit_expedition_attempt([selected_id]).success)
			and city.enter_first_war_battle(),
		"逐编队撤退场景创建单一已付费 attempt"
	)
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "逐编队撤退场景取得正式 C0")
		await _drop_scene(scene)
		return
	_check(battle.start_battle(), "逐编队撤退先进入 ACTIVE")
	battle.tick_timer.stop()
	_check(
		battle.open_exit_confirmation() and battle.confirm_exit_as_retreat(),
		"ACTIVE 退出通过既有撤退结算路径，而非删除 attempt"
	)
	var duplicate_rejected := not battle.confirm_exit_as_retreat()
	await process_frame
	await process_frame
	var summary: Dictionary = city.get_city_state().last_battle_result_summary
	var roster_after: Array[Dictionary] = city.get_formation_roster()
	var selected_after := _formation_count(roster_after, selected_id)
	_check(
		StringName(summary.outcome) == &"RETREAT"
			and Array(summary.formation_results).size() == 1
			and _formation_count(roster_after, unselected_id) == unselected_before
			and selected_after <= int(roster_before[0].member_count),
		"撤退只对选中编队写入一次幸存者，未选编队保持不变"
	)
	var state_after_first: Dictionary = city.get_city_state()
	_check(
		duplicate_rejected
			and city.get_city_state() == state_after_first,
		"重复撤退确认被拒绝，逐编队伤亡和资源不会重复应用"
	)
	await _drop_scene(scene)


func _check_victory_and_defeat_roster_writeback_once() -> void:
	# These deliberately vary authoritative city conditions before departure;
	# after confirmation the prepared request remains immutable.
	for expected_outcome in [BattleOutcome.Value.VICTORY, BattleOutcome.Value.DEFEAT]:
		var context := await _new_city(20 if expected_outcome == BattleOutcome.Value.VICTORY else 1, 60)
		var scene: Node2D = context.scene
		var city: Node = context.city
		city.enemy_count = 1 if expected_outcome == BattleOutcome.Value.VICTORY else 100
		var roster_before: Array[Dictionary] = city.get_formation_roster()
		var selected_id := StringName(roster_before[0].formation_id)
		var selected_ids: Array[StringName] = [selected_id]
		if expected_outcome == BattleOutcome.Value.VICTORY:
			selected_ids = []
			for formation in roster_before:
				if int(formation.member_count) > 0:
					selected_ids.append(StringName(formation.formation_id))
		_check(
			bool(city.commit_expedition_attempt(selected_ids).success)
				and city.enter_first_war_battle(),
			"%s 逐编队场景建立真实出征"
			% BattleOutcome.to_id(expected_outcome)
		)
		var battle := city.get_formal_battle_scene() as C0BattleGraybox
		if battle == null:
			_check(false, "%s 场景取得正式 C0" % BattleOutcome.to_id(expected_outcome))
			await _drop_scene(scene)
			continue
		battle.start_battle()
		battle.tick_timer.stop()
		for squad in battle.coordinator.active_session.squads:
			battle.issue_squad_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
		var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
		_check(
			result != null and result.outcome == expected_outcome,
			"%s 从真实 C0 tick 得到预期战果" % BattleOutcome.to_id(expected_outcome)
		)
		if result != null:
			var summary: Dictionary = battle.confirm_pending_result()
			var state_after_first: Dictionary = city.get_city_state()
			_check(
				StringName(summary.outcome) == BattleOutcome.to_id(expected_outcome)
					and Array(summary.formation_results).size() == selected_ids.size()
					and _formation_results_match_roster(summary, city.get_formation_roster())
					and battle.confirm_pending_result() == summary
					and city.get_city_state() == state_after_first,
				"%s 只写入一次对应编队幸存者，重复确认无第二次伤亡或奖励"
				% BattleOutcome.to_id(expected_outcome)
			)
		battle.abort_formal_entry()
		await _drop_scene(scene)


func _check_cross_day_training_and_applied_integrity() -> void:
	root.size = Vector2i(1152, 648)
	var context := await _new_city(20, 100)
	var scene: Node2D = context.scene
	var city: Node = context.city
	city.recruitment_cap = 50
	_check(city.queue_training(), "跨日战斗前建立正常次日完成的 5 人训练单")
	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 0.1
	var selected_ids: Array[StringName] = _nonempty_formation_ids(city)
	_check(
		selected_ids.size() == 3
			and bool(city.commit_expedition_attempt(selected_ids).success)
			and city.enter_first_war_battle(),
		"跨日用例以三支永久编队建立 immutable departure"
	)
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "跨日用例取得正式 C0")
		await _drop_scene(scene)
		return
	_check(battle.start_battle(), "跨日用例启动正式 BattleSession")
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	_check(
		result != null
			and result.outcome == BattleOutcome.Value.VICTORY
			and result.formation_results.size() == 3,
		"三编队从真实 tick 得到逐编队胜利事实"
	)
	if result == null:
		battle.abort_formal_entry()
		await _drop_scene(scene)
		return
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	var result_panel_rect := battle.result_panel.get_global_rect()
	var result_label_rect := battle.result_label.get_global_rect()
	var confirm_rect := battle.confirm_button.get_global_rect()
	_check(
		battle.result_input_blocker.visible
			and battle.result_panel.visible
			and _inside(result_panel_rect, viewport_rect)
			and _inside(result_label_rect, result_panel_rect)
			and _inside(confirm_rect, result_panel_rect)
			and confirm_rect.size.y >= 44.0
			and battle.result_label.get_visible_line_count()
				>= battle.result_label.get_line_count(),
		"三编队战果弹窗完整包含文本和 44px 确认按钮，无遮挡裁切"
	)
	_check(
		root.gui_get_focus_owner() == battle.confirm_button
			and battle.result_label.text.contains("北门先锋")
			and battle.result_label.text.contains("山道卫队")
			and battle.result_label.text.contains("城门后备"),
		"三编队战果名称可读且键盘焦点落在确认战果"
	)
	var roster_before_confirm := _roster_total_from_city(city)
	var summary: Dictionary = battle.confirm_pending_result()
	var roster_after_confirm := _roster_total_from_city(city)
	var training_completed := int(city.get_last_daily_breakdown().training_completed)
	_check(
		not summary.is_empty()
			and int(summary.city_time_advanced_days) >= 1
			and training_completed == 5
			and roster_after_confirm
				== roster_before_confirm - int(summary.casualty_count) + training_completed
			and int(summary.infantry_after) == roster_after_confirm
			and city.infantry_count == roster_after_confirm,
		"跨训练完成日先应用逐编队伤亡再补员，roster 与 summary 守恒"
	)
	await process_frame
	_check(
		root.gui_get_focus_owner() == battle.return_button
			and battle.return_button.visible
			and battle.return_button.get_global_rect().size.y >= 44.0,
		"结算后焦点切到可见的 44px 返回按钮"
	)
	var applied_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		not applied_snapshot.is_empty()
			and StringName(applied_snapshot.expedition_attempt.phase) == &"APPLIED",
		"结算后的 APPLIED attempt 与终局事实可正常导出"
	)
	var tampered_summary := applied_snapshot.duplicate(true)
	var result_id := StringName(tampered_summary.expedition_attempt.result_id)
	tampered_summary.settlement_ledger.committed_results_by_id[
		result_id
	].survivor_count += 1
	var tampered_fact := applied_snapshot.duplicate(true)
	tampered_fact.settlement_ledger.committed_results_by_id[
		result_id
	].battle_fact_snapshot.survivor_count += 1
	var tampered_result_id := applied_snapshot.duplicate(true)
	tampered_result_id.expedition_attempt.result_id = &"battle-000001-result-999"
	_check(
		not bool(city.validate_v5_campaign_snapshot(tampered_summary).valid)
			and not bool(city.validate_v5_campaign_snapshot(tampered_fact).valid)
			and not bool(city.validate_v5_campaign_snapshot(tampered_result_id).valid),
		"APPLIED summary、battle fact 与 result ID 任一篡改都被领域校验拒绝"
	)
	_check(city.acknowledge_first_war_result(), "APPLIED 后确认城市摘要恢复正常治理")
	_check(city.queue_training(), "APPLIED 后可继续使用同一正常征募入口演进 roster")
	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 0.001
	city.set_city_time_paused(false)
	city.advance_city_frame_for_test(0.001)
	var evolved_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		not evolved_snapshot.is_empty()
			and int(evolved_snapshot.schema_version) == 6
			and _roster_projection_total(evolved_snapshot.garrison)
				== city.infantry_count
			and StringName(evolved_snapshot.expedition_attempt.phase) == &"APPLIED",
		"APPLIED 后正常训练改变 roster 仍可导出 V6，不误判历史终局事实"
	)
	battle.abort_formal_entry()
	await _drop_scene(scene)


func _check_v5_envelope_migrates_to_v6_roster() -> void:
	var context := await _new_city(20, 80)
	var scene: Node2D = context.scene
	var city: Node = context.city
	var current: Dictionary = city.export_v5_campaign_snapshot()
	var legacy: Dictionary = current.duplicate(true)
	legacy.schema_version = 5
	legacy.erase("expedition_attempt")
	legacy.garrison = {
		"schema_version": 1,
		"city_id": &"blackstone_city",
		"unit_counts_by_definition_id": Dictionary(
			current.garrison.unit_counts_by_definition_id
		).duplicate(true),
	}
	var encoded := V5CampaignSaveCodec.encode_snapshot(
		legacy,
		17,
		Callable(self, "_accept_legacy_snapshot")
	)
	var decoded := V5CampaignSaveCodec.decode_storage_text(
		str(encoded.get("storage_text", "")),
		Callable(city, "validate_v5_campaign_snapshot")
	)
	_check(
		bool(encoded.success)
			and bool(decoded.success)
			and int(decoded.snapshot.schema_version) == 6
			and Dictionary(decoded.snapshot.expedition_attempt).is_empty()
			and Dictionary(decoded.snapshot.garrison.formations_by_id).size() == 3
			and _roster_projection_total(decoded.snapshot.garrison) == 20,
		"真实 canonical V5 envelope 解码后迁移为 V6 roster，保留总兵力且不伪造活跃出征"
	)
	var restored_context := await _new_city(1, 1)
	var restored_scene: Node2D = restored_context.scene
	var restore: Dictionary = restored_context.city.restore_v5_campaign_snapshot(decoded.snapshot)
	_check(
		bool(restore.success)
			and _roster_projection_total(
				restored_context.city.export_v5_campaign_snapshot().garrison
			) == 20,
		"V5→V6 migration 结果可跨进程式冷恢复到同一唯一 roster authority"
	)
	await _drop_scene(scene)
	await _drop_scene(restored_scene)


func _new_city(infantry: int, initial_food: int) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.infantry_count = infantry
	city.food = initial_food
	city._refresh_city_ui()
	return {"scene": scene, "city": city}


func _drop_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	await process_frame


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.1
		and inner.position.y >= outer.position.y - 0.1
		and inner.end.x <= outer.end.x + 0.1
		and inner.end.y <= outer.end.y + 0.1
	)


func _formation_count(roster: Array, formation_id: StringName) -> int:
	for formation_value in roster:
		var formation: Dictionary = formation_value
		if StringName(formation.get("formation_id", &"")) == formation_id:
			return int(formation.get("member_count", 0))
	return -1


func _nonempty_formation_ids(city: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	for formation in city.get_formation_roster():
		if int(formation.member_count) > 0:
			result.append(StringName(formation.formation_id))
	return result


func _roster_total_from_city(city: Node) -> int:
	var total := 0
	for formation in city.get_formation_roster():
		total += int(formation.member_count)
	return total


func _formation_results_match_roster(summary: Dictionary, roster: Array) -> bool:
	for result_value in Array(summary.get("formation_results", [])):
		var result: Dictionary = result_value
		if _formation_count(
			roster,
			StringName(result.get("formation_id", &""))
		) != int(result.get("survivor_count", -1)):
			return false
	return true


func _roster_projection_total(garrison: Dictionary) -> int:
	var total := 0
	for formation_value in Dictionary(garrison.formations_by_id).values():
		total += int(Dictionary(formation_value).member_count)
	return total


func _accept_legacy_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"valid": true,
		"error_id": &"",
		"error": "",
		"snapshot": snapshot.duplicate(true),
	}


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("R1E_EXPEDITION_CAUSALITY_SMOKE: PASS (%d assertions)" % assertions)
		quit(0)
		return
	push_error("R1E_EXPEDITION_CAUSALITY_SMOKE: FAIL %s" % [failures])
	quit(1)
