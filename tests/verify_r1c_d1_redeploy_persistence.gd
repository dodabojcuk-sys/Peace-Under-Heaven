extends SceneTree

## R1C-D1：撤军/战败 → 确认损益 → 领取暂存 → 再次出征 → 持久化闭环。
## 分段多进程执行（--stage=），每个阶段都是一次真实冷启动：
## 全新进程 + 同一隔离沙盒目录，boot 走正式 load_latest 恢复链。
## 所有状态变化只经正式命令与时间推进；禁止注水/改 data/绕过 persist。
##
## 路径 A（WITHDRAW、尚未交战）沙盒：A_{deploy1,withdrawn,claimed,deploy2,verify}
## 路径 B（DEFEAT、含合法时间消耗）沙盒：B_{deploy1,outcome,claim_redeploy,verify}
## facts JSON 落在各沙盒目录，供下一阶段冷启动比对。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var stage := ""
var save_dir := ""
var facts_dir := ""
var model: Dictionary = {}
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error(label)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _read_facts(name: String) -> Dictionary:
	var file := FileAccess.open(facts_dir.path_join(name), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return _dict(parsed)


func _write_facts(name: String, facts: Dictionary) -> void:
	var file := FileAccess.open(facts_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		push_error("无法写 facts：" + name)
		failures.append("写 facts " + name)
		return
	file.store_line(JSON.stringify(facts))
	file.close()


func _snapshot_facts() -> Dictionary:
	model = runtime.get_read_model()
	var scope := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	var formations: Array = []
	for formation_value in _dict(_dict(model.get("home", {})).get("formations", [])):
		var formation: Dictionary = formation_value
		var count := int(formation.get("member_count", formation.get("count", 0)))
		if count > 0:
			formations.append({
				"id": str(formation.get("id", formation.get("formation_id", ""))),
				"count": count,
			})
	return {
		"phase": str(model.get("phase", "")),
		"attempt_sequence": int(runtime.data.attempt_sequence),
		"settlement_id": str(runtime.data.settlement_id),
		"fallen_home": int(runtime.data.fallen_home),
		"army_ids": Array(runtime.data.army_ids).map(func(id): return str(id)),
		"scope_food": int(scope.get("food", 0)),
		"scope_wood": int(scope.get("wood", 0)),
		"home_food": int(city.food),
		"home_wood": int(city.wood),
		"totals": _dict(model.get("totals", {})).duplicate(true),
		"formations": formations,
		"summary_kind": str(_dict(model.get("summary", {})).get("kind", "")),
		"view_surface": str(_dict(model.get("view_context", {})).get("surface", "")),
	}


func _wait_boot() -> bool:
	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in range(12):
		await process_frame
	city = scene.get_node_or_null("ConstructionController")
	if city == null:
		failures.append("城市场景未装载")
		return false
	runtime = city.get("_regular_campaign")
	view = city.get("_regular_campaign_view")
	return true


func _new_campaign() -> bool:
	_expect(city.call("initialize_regular_campaign"), "常规候选战役初始化")
	runtime = city.get("_regular_campaign")
	_expect(runtime != null and runtime.enabled(), "战役运行时已启用")
	return runtime != null and runtime.enabled()


func _formations_chosen() -> Array:
	var chosen: Array = []
	var formations: Array = Array(_dict(runtime.get_read_model().get("home", {})).get("formations", []))
	for formation_value in formations:
		var formation: Dictionary = _dict(formation_value)
		if int(formation.get("member_count", formation.get("count", 0))) > 0:
			chosen.append(StringName(formation.get("formation_id", formation.get("id", ""))))
	return chosen


func _wait_armies_home() -> void:
	var deadline_ms := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline_ms and int(runtime._base_members()) < 2:
		runtime.advance(1.0)
	_expect(int(runtime._base_members()) >= 2, "出征编队抵达驻地")


func _run() -> void:
	var has_isolated_save := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--txwzs-require-isolated-save":
			has_isolated_save = true
		elif arg.begins_with("--txwzs-v5-save-dir="):
			save_dir = arg.trim_prefix("--txwzs-v5-save-dir=")
		elif arg.begins_with("--stage="):
			stage = arg.trim_prefix("--stage=")
		elif arg.begins_with("--facts-dir="):
			facts_dir = arg.trim_prefix("--facts-dir=")
	if not has_isolated_save or save_dir.is_empty() or stage.is_empty() or facts_dir.is_empty():
		push_error("D1：需要 --txwzs-require-isolated-save、--txwzs-v5-save-dir、--stage、--facts-dir")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(facts_dir)

	if not await _wait_boot():
		_finish()
		return

	match stage:
		"A_deploy1":
			await _stage_deploy1("facts-a-depart1.json")
		"A_withdrawn":
			await _stage_withdrawn("facts-a-depart1.json", "facts-a-withdrawn.json")
		"A_claimed":
			await _stage_claim("facts-a-withdrawn.json", "facts-a-claimed.json")
		"A_deploy2":
			await _stage_deploy2("facts-a-claimed.json", "facts-a-depart2.json")
		"A_verify":
			await _stage_verify("facts-a-depart2.json")
		"A_deploy2_diag":
			await _stage_deploy2_diag()
		"B_deploy1":
			await _stage_deploy1("facts-b-depart1.json")
		"B_outcome":
			await _stage_outcome_b("facts-b-depart1.json", "facts-b-withdrawn.json")
		"B_claim_redeploy":
			await _stage_claim("facts-b-withdrawn.json", "facts-b-claimed.json")
			if failures.is_empty():
				await _stage_deploy2("facts-b-claimed.json", "facts-b-depart2.json")
		"B_verify":
			await _stage_verify("facts-b-depart2.json")
		_:
			push_error("未知 stage：" + stage)
			quit(2)
			return
	_finish()


func _stage_deploy2_diag() -> void:
	# 诊断模式：绕过 persist 包装器直接调正式 _depart，导出被拒候选快照供 diff。
	var chosen := _formations_chosen()
	print("D1_DEBUG diag chosen=", chosen)
	var result: Dictionary = runtime._depart({"formation_ids": chosen, "food": 30, "wood": 55})
	print("D1_DEBUG diag depart success=", bool(result.get("success", false)), " msg=", str(result.get("error", result.get("message", ""))))
	if not bool(result.get("success", false)):
		_finish()
		return
	var payload: Dictionary = city.export_v5_campaign_snapshot()
	print("D1_DEBUG export_empty=", payload.is_empty(),
		" active_city=", str(city.get("_active_city_id")),
		" battle_res=", str(city.get("_active_battle_reservation")).left(60),
		" dispatch_res=", str(city.get("_active_army_dispatch_reservation")).left(60),
		" encounter=", str(city.get("_active_army_encounter")).left(60))
	# 逐条 bisect entry 子规则（诊断输出，仅定位用）。
	var entry: Dictionary = runtime.data.entry
	print("D1_BISECT size5=", entry.size() == 5, " keys=", entry.keys())
	var ledger: Dictionary = _dict(runtime.data.departure_ledger)
	var resources: Dictionary = _dict(entry.get("resources", {}))
	print("D1_BISECT ledger=", ledger, " resources=", resources,
		" res_match=", int(resources.get("food", -1)) == int(ledger.get("food", -2)) and int(resources.get("wood", -1)) == int(ledger.get("wood", -2)))
	var entry_formations: Array = Array(entry.get("formations", []))
	print("D1_BISECT formations_eq_ledger=", entry_formations == Array(ledger.get("formations", [])), " n=", entry_formations.size())
	var probe_registry_valid: Dictionary = ArmyRegistry.validate_snapshot(_dict(entry.get("army_registry", {})), RegularCampaignRuntime._snapshot_unit_definition_ids(_dict(entry.get("army_registry", {}))), false)
	print("D1_BISECT registry_valid=", bool(probe_registry_valid.get("valid", false)), " ", str(probe_registry_valid.get("error", "")))
	var war_probe: WarLoopState = WarLoopState.new()
	print("D1_BISECT warloop_restore=", war_probe.restore_snapshot(_dict(entry.get("war_loop", {}))))
	var state: Dictionary = _dict(entry.get("state", {}))
	print("D1_BISECT state_entry_empty=", _dict(state.get("entry", {})).is_empty(),
		" ledger_match=", _dict(state.get("departure_ledger", {})) == ledger,
		" attempt0=", int(state.get("attempt_elapsed_ms", -1)) == 0,
		" buildings0=", Array(state.get("buildings", [])).is_empty(),
		" project0=", _dict(state.get("project", {})).is_empty(),
		" summary0=", _dict(state.get("summary", {})).is_empty(),
		" settlement0=", str(state.get("settlement_id", "")) == "",
		" fallen0=", int(state.get("fallen_home", -1)) == 0 and int(state.get("fallen_local", -1)) == 0,
		" losses0=", int(state.get("combat_losses_total", -1)),
		" joined0=", int(state.get("local_joined", -1)),
		" starvation=", int(state.get("starvation_cycles", -1)),
		" enemy_growth=", int(state.get("enemy_growth_events", -1)),
		" enemy_reserve=", int(state.get("enemy_reserve", -1)),
		" state_army_ids=", Array(state.get("army_ids", [])),
		" payload_army_ids=", Array(runtime.data.army_ids).map(func(id): return str(id)))
	var state_totals: Dictionary = _dict(state.get("totals", {}))
	print("D1_BISECT state_totals=", state_totals, " ledger_food=", int(ledger.get("food", -1)), " ledger_wood=", int(ledger.get("wood", -1)))
	var recursive: Dictionary = RegularCampaignRuntime.validate_snapshot(state, {runtime.SCOPE: resources}, _dict(entry.get("army_registry", {})), true, 0)
	print("D1_BISECT recursive_valid=", bool(recursive.get("valid", false)), " ", str(recursive.get("error", "")))
	var entry_valid: bool = RegularCampaignRuntime._valid_entry_snapshot(entry, runtime.get_read_model())
	print("D1_BISECT entry_valid_vs_readmodel=", entry_valid)
	var file := FileAccess.open(facts_dir.path_join("invalid-depart2-payload.json"), FileAccess.WRITE)
	if file != null:
		file.store_line(JSON.stringify(payload, "  "))
		file.close()
		print("D1_DEBUG payload dumped")
	var verdict: Dictionary = city.validate_v5_campaign_snapshot(payload)
	print("D1_DEBUG validate=", str(verdict))


func _stage_deploy1(facts_name: String) -> void:
	# 全新沙盒：无 generation，boot 不恢复，需要正式初始化。
	_expect(runtime == null, "新沙盒无残留战役（冷启动干净）")
	if not await _new_campaign():
		_finish()
		return
	_expect(city.call("show_regular_campaign"), "打开备战表单")
	await process_frame
	var chosen_debug := _formations_chosen()
	print("D1_DEBUG chosen=", chosen_debug, " raw_formations=", city._garrison_state.get_formations())
	var depart_receipt: Dictionary = runtime.command(&"depart", {"formation_ids": chosen_debug, "food": 30, "wood": 55})
	if not bool(depart_receipt.get("success", false)):
		print("DEPART1_ERROR=", str(depart_receipt.get("error", "")))
	_expect(bool(depart_receipt.get("success", false)), "第一次正式 depart 成功")
	model = runtime.get_read_model()
	_expect(StringName(model.get("phase", &"")) == &"ACTIVE", "第一次出征后 ACTIVE")
	var facts := _snapshot_facts()
	_write_facts(facts_name, facts)
	_expect(int(facts.get("attempt_sequence")) == 1, "首次出征 attempt_sequence=1")
	_expect(Array(facts.get("army_ids")).size() == chosen_debug.size(), "每编队一支军队")


func _stage_withdrawn(previous_facts: String, facts_name: String) -> void:
	var previous := _read_facts(previous_facts)
	_expect(not previous.is_empty(), "读取上一阶段 facts")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复到 ACTIVE（boot 正式恢复链）")
	_expect(Array(runtime.data.army_ids).map(func(id): return str(id)) == Array(previous.get("army_ids")), "军队身份冷启动一致")
	_expect(int(runtime.data.attempt_sequence) == int(previous.get("attempt_sequence")), "attempt_sequence 冷启动一致")
	var scope_before := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	_expect(int(scope_before.get("food", 0)) == int(previous.get("scope_food")), "前线粮冷启动一致")
	_wait_armies_home()
	var withdraw_receipt: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	if not bool(withdraw_receipt.get("success", false)):
		print("WITHDRAW_ERROR=", str(withdraw_receipt.get("error", "")))
	_expect(bool(withdraw_receipt.get("success", false)), "正式 WITHDRAW 成功")
	var confirm_receipt: Dictionary = runtime.command(&"confirm")
	if not bool(confirm_receipt.get("success", false)):
		print("CONFIRM_ERROR=", str(confirm_receipt.get("error", "")))
	_expect(bool(confirm_receipt.get("success", false)), "确认损益（正式事务）成功")
	model = runtime.get_read_model()
	_expect(StringName(model.get("phase", &"")) == &"PREPARATION", "非胜利结算回到 PREPARATION")
	var facts := _snapshot_facts()
	_write_facts(facts_name, facts)
	_expect(int(facts.get("fallen_home")) == 0, "未交战撤军无阵亡")
	_expect(str(facts.get("settlement_id")) == "", "非胜利结算不出具结算身份")


func _stage_outcome_b(previous_facts: String, facts_name: String) -> void:
	var previous := _read_facts(previous_facts)
	_expect(not previous.is_empty(), "读取上一阶段 facts")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复到 ACTIVE（路径 B）")
	var scope_before := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	_expect(int(scope_before.get("food", 0)) == int(previous.get("scope_food")), "路径 B：前线粮冷启动一致")
	_wait_armies_home()
	# 合法的少量时间消耗：驻扎军队口粮按真实规则扣减（推进模拟时钟）。
	var scope_before_idle := int(scope_before.get("food", 0))
	for _i in range(45):
		runtime.advance(1.0)
	var scope_after_idle := int(_dict(city.get_nation_state().get_scope(runtime.SCOPE)).get("food", 0))
	print("D1_B_IDLE food %d -> %d" % [scope_before_idle, scope_after_idle])
	var outcome_receipt: Dictionary = runtime.command(&"outcome", {"kind": &"DEFEAT"})
	if not bool(outcome_receipt.get("success", false)):
		print("OUTCOME_ERROR=", str(outcome_receipt.get("error", "")))
	_expect(bool(outcome_receipt.get("success", false)), "正式 DEFEAT 成功")
	var confirm_receipt: Dictionary = runtime.command(&"confirm")
	if not bool(confirm_receipt.get("success", false)):
		print("CONFIRM_ERROR=", str(confirm_receipt.get("error", "")))
	_expect(bool(confirm_receipt.get("success", false)), "路径 B 确认损益成功")
	var facts := _snapshot_facts()
	_write_facts(facts_name, facts)
	_expect(StringName(model.get("phase", &"")) == &"PREPARATION", "路径 B 回到 PREPARATION")


func _stage_claim(previous_facts: String, facts_name: String) -> void:
	var previous := _read_facts(previous_facts)
	_expect(not previous.is_empty(), "读取上一阶段 facts")
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "冷启动恢复到 PREPARATION")
	_expect(str(runtime.data.settlement_id) == str(previous.get("settlement_id")), "settlement 身份冷启动一致")
	var scope := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	var scope_food := int(scope.get("food", 0))
	var scope_wood := int(scope.get("wood", 0))
	if scope_food <= 0 and scope_wood <= 0:
		# 合法流程下主城容量充足：确认时已全额归还，无暂存可领（按设计跳过 claim）。
		print("D1_CLAIM_SKIPPED 无暂存（scope粮 %d 木 %d）" % [scope_food, scope_wood])
		_write_facts(facts_name, _snapshot_facts())
		return
	var home_before := {"food": int(city.food), "wood": int(city.wood)}
	var claim_receipt: Dictionary = runtime.command(&"claim")
	if not bool(claim_receipt.get("success", false)):
		print("CLAIM_ERROR=", str(claim_receipt.get("error", "")))
	_expect(bool(claim_receipt.get("success", false)), "领取暂存（正式事务）成功")
	var scope_after := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	var food_moved := int(city.food) - int(home_before.food)
	var wood_moved := int(city.wood) - int(home_before.wood)
	_expect(food_moved == scope_food - int(scope_after.get("food", 0)), "粮食守恒（%d+%d=%d）" % [food_moved, int(scope_after.get("food", 0)), scope_food])
	_expect(wood_moved == scope_wood - int(scope_after.get("wood", 0)), "木材守恒（%d+%d=%d）" % [wood_moved, int(scope_after.get("wood", 0)), scope_wood])
	if int(scope_after.get("food", 0)) + int(scope_after.get("wood", 0)) == 0:
		var re_claim: Dictionary = runtime.command(&"claim")
		_expect(not bool(re_claim.get("success", true)) and str(re_claim.get("error", "")).contains("暂无可领取"), "重复领取被拒绝，不增发")
	var facts := _snapshot_facts()
	_write_facts(facts_name, facts)


func _stage_deploy2(previous_facts: String, facts_name: String) -> void:
	var previous := _read_facts(previous_facts)
	_expect(not previous.is_empty(), "读取上一阶段 facts")
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "再次出征前为 PREPARATION")
	var chosen := _formations_chosen()
	var total_members := 0
	for formation_value in Array(_dict(runtime.get_read_model().get("home", {})).get("formations", [])):
		var formation: Dictionary = _dict(formation_value)
		for saved in Array(previous.get("formations", [])):
			if str(saved.get("id", "")) == str(formation.get("id", formation.get("formation_id", ""))):
				_expect(int(formation.get("member_count", formation.get("count", 0))) == int(saved.get("count", -1)), "编队 %s 人数与撤军前一致" % str(saved.get("id", "")))
		total_members += int(formation.get("member_count", formation.get("count", 0)))
	print("D1_DEBUG deploy2 chosen=", chosen, " total_members=", total_members, " raw=", city._garrison_state.get_formations(), " unit_count=", city._garrison_state.get_unit_count(&"unit_role.infantry_basic"))
	_expect(not chosen.is_empty() and total_members > 0, "归队士兵重建出可投入编队")
	var depart_receipt: Dictionary = runtime.command(&"depart", {"formation_ids": chosen, "food": 30, "wood": 55})
	if not bool(depart_receipt.get("success", false)):
		print("DEPART2_ERROR=", str(depart_receipt.get("error", "")))
	_expect(bool(depart_receipt.get("success", false)) and not str(depart_receipt.get("error", "")).contains("保存未完成"), "第二次 depart 成功且无保存回滚")
	model = runtime.get_read_model()
	_expect(StringName(model.get("phase", &"")) == &"ACTIVE", "第二次出征后 ACTIVE")
	var facts := _snapshot_facts()
	var army_ids: Array = facts.get("army_ids", [])
	_expect(army_ids.size() == chosen.size(), "第二次出征每编队一支军队（%d 支）" % chosen.size())
	_expect(int(facts.get("scope_food")) == 30 and int(facts.get("scope_wood")) == 55, "前线兵粮与确认内容一致（30/55）")
	_expect(str(facts.get("settlement_id")) == "" and int(facts.get("attempt_sequence")) == int(previous.get("attempt_sequence")) + 1, "第二次出征 attempt_sequence 恰好 +1 且无重复 settlement")
	_write_facts(facts_name, facts)


func _stage_verify(facts_name: String) -> void:
	var previous := _read_facts(facts_name)
	_expect(not previous.is_empty(), "读取第二次出征 facts")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复第二次出征（ACTIVE）")
	_expect(Array(runtime.data.army_ids).map(func(id): return str(id)) == Array(previous.get("army_ids")), "第二次出征军队身份冷启动一致")
	_expect(str(runtime.data.settlement_id) == str(previous.get("settlement_id")), "settlement 身份不变（无重复结算）")
	_expect(int(runtime.data.attempt_sequence) == int(previous.get("attempt_sequence")), "attempt_sequence 不重复推进")
	_expect(int(runtime.data.fallen_home) == int(previous.get("fallen_home")), "阵亡写入不重复")
	var scope := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	_expect(int(scope.get("food", 0)) == int(previous.get("scope_food")), "前线粮冷启动一致")
	_expect(int(scope.get("wood", 0)) == int(previous.get("scope_wood")), "前线木冷启动一致")
	var totals_before: Dictionary = _dict(previous.get("totals", {}))
	var totals_now: Dictionary = _dict(_dict(runtime.get_read_model().get("totals", {})))
	_expect(totals_before.is_empty() or totals_now.get("food_in", -1) == totals_before.get("food_in", -2), "totals.food_in 冷启动一致（不重复入账）")
	# 空转两秒后身份字段仍不漂移（资源消耗允许继续）。
	await _hold_seconds(2.0)
	_expect(str(runtime.data.settlement_id) == str(previous.get("settlement_id")), "空转后 settlement 仍不变")
	_expect(int(runtime.data.attempt_sequence) == int(previous.get("attempt_sequence")), "空转后 attempt_sequence 仍不变")
	_expect(Array(runtime.data.army_ids).map(func(id): return str(id)) == Array(previous.get("army_ids")), "空转后军队身份仍一致")


func _hold_seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _finish() -> void:
	if failures.is_empty():
		print("R1C_D1 stage=%s PASS all" % stage)
		quit(0)
	else:
		print("R1C_D1 stage=%s FAIL failures=%s" % [stage, failures])
		quit(1)
