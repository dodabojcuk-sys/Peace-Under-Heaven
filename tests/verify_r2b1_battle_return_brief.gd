extends SceneTree

## R2B-1：战役归来简报与永久主城经营回流。
## 分段多进程（--stage=），每个阶段真实冷启动走正式 load_latest 恢复链；
## 隔离存档门禁强制开启；全部状态变化只经正式命令与时间推进。
## 覆盖：回执与事务（WITHDRAW/DEFEAT/VICTORY/保存失败/重复确认）、
## 显示边界（暂离/结算页停留/主城恰一次/刷新×10/经营往返/冷启动/下一场）、
## 数据守恒（UI 开关不改事实）、双分辨率布局、经营路由与回退。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var stage := ""
var save_dir := ""
var facts_dir := ""
var model: Dictionary = {}
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView
var shell: Node
var _budget_ms := 240000
var _started_ms := 0
var _finished := false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	process_frame.connect(_watchdog)
	call_deferred("_run")


## 看门狗：任何未预期的脚本错误会让 _run 协程中断、永远不再 quit()。
## 没有它，卡死的无头实例会一直占着 CPU 和存档目录。
func _watchdog() -> void:
	if _finished:
		return
	if Time.get_ticks_msec() - _started_ms > _budget_ms:
		push_error("R2B1 看门狗超时：stage=%s 未在 %d ms 内完成" % [stage, _budget_ms])
		failures.append("看门狗超时（stage 未完成）")
		_finish()


## 视图在 show_regular_campaign 时才创建；冷启动 _wait_boot 取到的是 null。
## 未判空直接 view._command() 会中断协程，把未跑完的断言伪装成通过。
func _require_view(label: String) -> bool:
	if view != null and is_instance_valid(view):
		return true
	view = city.get("_regular_campaign_view")
	if view == null or not is_instance_valid(view):
		city.call("show_regular_campaign")
		view = city.get("_regular_campaign_view")
	if view == null or not is_instance_valid(view):
		_expect(false, label + "：战役视图未装载")
		return false
	return true


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


func _save_sequence() -> int:
	var value: Variant = city.get("save_sequence")
	return int(value) if value != null else -1


func _conservation_snapshot() -> Dictionary:
	return {
		"home_food": int(city.food),
		"home_wood": int(city.wood),
		"garrison_total": _garrison_members(),
		"recovery_wounded": int(_dict(city.call("get_population_recovery_read_model")).get("wounded", 0)),
		"recovery_fallen": int(_dict(city.call("get_population_recovery_read_model")).get("fallen", 0)),
		"save_sequence": _save_sequence(),
		"armies": Array(runtime.data.army_ids).map(func(id): return str(id)),
	}


func _garrison_members() -> int:
	var total := 0
	for formation_value in city._garrison_state.get_formations():
		total += int(_dict(formation_value).get("member_count", 0))
	return total


func _brief_panel() -> Node:
	return shell.find_child("CampaignReturnBrief", false, false)


func _brief_title_text() -> String:
	var label := shell.find_child("CampaignReturnTitle", true, false)
	return str(label.get("text")) if label != null else ""


func _snapshot_facts() -> Dictionary:
	var scope := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	return {
		"phase": str(runtime.data.get("phase", "")),
		"attempt_sequence": int(runtime.data.get("attempt_sequence", 0)),
		"settlement_id": str(runtime.data.get("settlement_id", "")),
		"fallen_home": int(runtime.data.get("fallen_home", 0)),
		"army_ids": Array(runtime.data.get("army_ids", [])).map(func(id): return str(id)),
		"scope_food": int(scope.get("food", 0)),
		"scope_wood": int(scope.get("wood", 0)),
		"home_food": int(city.food),
		"home_wood": int(city.wood),
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
	shell = current_scene.get_node_or_null("UI/Shell")
	_expect(shell != null and shell.has_method("show_campaign_return_brief"), "InnerCityUIR0 外壳已装载")
	return city != null


func _new_campaign() -> bool:
	_expect(city.call("initialize_regular_campaign"), "常规候选战役初始化")
	runtime = city.get("_regular_campaign")
	_expect(runtime != null and runtime.enabled(), "战役运行时已启用")
	return runtime != null and runtime.enabled()


func _formations_chosen() -> Array:
	var chosen: Array = []
	for formation_value in Array(_dict(runtime.get_read_model().get("home", {})).get("formations", [])):
		var formation: Dictionary = _dict(formation_value)
		if int(formation.get("member_count", formation.get("count", 0))) > 0:
			chosen.append(StringName(formation.get("formation_id", formation.get("id", ""))))
	return chosen


func _deploy() -> bool:
	var chosen := _formations_chosen()
	var depart: Dictionary = runtime.command(&"depart", {"formation_ids": chosen, "food": 30, "wood": 55})
	if not bool(depart.get("success", false)):
		print("DEPART_ERROR=", str(depart.get("error", "")))
	_expect(bool(depart.get("success", false)), "正式 depart 成功")
	return bool(depart.get("success", false))


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
		push_error("R2B1：需要 --txwzs-require-isolated-save、--txwzs-v5-save-dir、--stage、--facts-dir")
		_finished = true
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(facts_dir)
	if not await _wait_boot():
		_finish()
		return
	match stage:
		"W_deploy":
			if await _new_campaign():
				await _deploy()
				_write_facts("facts-w-deploy.json", _snapshot_facts())
		"W_flow":
			await _stage_withdraw_flow()
		"W_cold":
			await _stage_cold_no_replay()
		"W_second":
			await _stage_second_campaign()
		"D_deploy":
			if await _new_campaign():
				await _deploy()
				_write_facts("facts-d-deploy.json", _snapshot_facts())
		"D_flow":
			await _stage_defeat_flow()
		"S_deploy":
			if await _new_campaign():
				await _deploy()
				_write_facts("facts-s-deploy.json", _snapshot_facts())
		"S_flow":
			await _stage_save_failure()
		"V_deploy":
			if await _new_campaign():
				await _deploy()
				_write_facts("facts-v-deploy.json", _snapshot_facts())
		"V_flow":
			await _stage_victory_flow()
		"U_advice":
			await _stage_advice_unit()
		_:
			push_error("未知 stage：" + stage)
			_finished = true
			quit(2)
			return
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if failures.is_empty():
		print("R2B1 stage=%s PASS all" % stage)
		quit(0)
	else:
		print("R2B1 stage=%s FAIL failures=%s" % [stage, failures])
		quit(1)


## 场景 6+7：ACTIVE 暂离回主城不显示；PENDING 停留在结算页不显示但回执保留。
func _stage_expect_no_brief_while_away_and_pending() -> bool:
	if not _require_view("暂离/结算页边界"):
		return false
	_expect(runtime.has_settlement_receipt() == false, "ACTIVE 暂离前无回执")
	view.visible = false
	city._on_regular_campaign_view_closed()
	await process_frame
	_expect(_brief_panel() == null, "ACTIVE 暂离回主城：不显示归来简报")
	_expect(city.get("_pending_campaign_return_brief") == {} or _dict(city.get("_pending_campaign_return_brief")).is_empty(), "ACTIVE 暂离：无暂存回执")
	city.call("show_regular_campaign")
	await process_frame
	_expect(_require_view("重新打开覆盖层后") and view.visible, "重新打开战役覆盖层（备战/结算侧栏）")
	return _require_view("暂离/结算页边界收尾")


func _stage_withdraw_flow() -> void:
	var previous := _read_facts("facts-w-deploy.json")
	_expect(not previous.is_empty(), "读取 deploy facts")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复 ACTIVE")
	var boundaries := await _stage_expect_no_brief_while_away_and_pending()
	if not boundaries or not failures.is_empty():
		_finish()
		return
	if not _require_view("撤军确认"):
		_finish()
		return
	var outcome: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	_expect(bool(outcome.get("success", false)), "正式 WITHDRAW 成功")
	_expect(_brief_panel() == null, "结算/战区停留期间不显示简报")
	_expect(runtime.has_settlement_receipt() == false, "outcome 阶段尚未生成回执")
	var before_confirm := _conservation_snapshot()
	view._command(&"confirm", {})
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "确认损益（正式事务）成功")
	# 场景 1：回执内容与事务边界
	_expect(_dict(city.get("_pending_campaign_return_brief")).is_empty() == false, "视图路径已把回执转交控制器（runtime 侧一次性领取）")
	var staged: Dictionary = _dict(city.get("_pending_campaign_return_brief"))
	_expect(not staged.is_empty(), "控制器已暂存回执（等待主城可见）")
	_expect(str(staged.get("kind", "")) == "WITHDRAW", "回执 kind=WITHDRAW")
	_expect(str(staged.get("settlement_id", "")).begins_with("regular.settlement."), "回执保留本次结算身份（非胜利清理后仍在）")
	_expect(str(staged.get("result_key", "")) == "regular.settlement.%d.WITHDRAW" % int(staged.get("attempt_sequence", -1)), "result_key 稳定区分结算")
	_expect(int(staged.get("survivors", -1)) == _garrison_members(), "回执幸存者=驻城编队总量")
	_expect(int(staged.get("retained_food", -1)) >= 0 and int(staged.get("retained_wood", -1)) >= 0, "回执暂存量非负")
	_expect(runtime.has_settlement_receipt() == false, "领取后 runtime 不再持有回执")
	_expect(runtime.data.get("totals", {}) == staged.get("totals", {}), "回执 totals 与权威快照一致（深拷贝投影）")
	_expect(_dict(runtime.data.get("summary", {})).is_empty(), "非胜利 runtime.summary 已清（回执独立保留）")
	# 场景 5：重复 confirm 失败且不产生第二张简报
	view._command(&"confirm", {})
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "重复 confirm 失败（阶段不变）")
	_expect(runtime.has_settlement_receipt() == false, "重复 confirm 不生成回执")
	# 场景 8：返回永久主城 → 恰好显示一次
	var after_confirm := _conservation_snapshot()
	_expect(after_confirm.home_food >= before_confirm.home_food and after_confirm.home_wood >= before_confirm.home_wood, "确认事务后主城资源只增（返还写入）")
	view.visible = false
	city._on_regular_campaign_view_closed()
	await process_frame
	await process_frame
	var panel := _brief_panel()
	_expect(panel != null, "返回永久主城：显示归来简报")
	_expect(_brief_title_text() == "青原战役 · 部队归城", "撤军标题「青原战役 · 部队归城」")
	# 场景 9：UI refresh ×10 不重复
	for _i in range(10):
		city._refresh_city_ui()
	await process_frame
	var found: Array[Node] = []
	var stack: Array[Node] = [shell]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == "CampaignReturnBrief":
			found.append(node)
		stack.append_array(node.get_children())
	_expect(found.size() == 1 and found[0] == panel and panel.visible, "UI 刷新×10 后简报仍只有一份")
	# 场景 10：城市经营开合往返不重复
	shell.call("_toggle_governance_workspace")
	await process_frame
	shell.call("_toggle_governance_workspace")
	await process_frame
	_expect(_brief_panel() == panel, "经营开合往返后简报不重复")
	# 场景 13：简报开着不改事实
	var during := _conservation_snapshot()
	_expect(during.home_food == after_confirm.home_food and during.home_wood == after_confirm.home_wood and during.garrison_total == after_confirm.garrison_total and during.recovery_wounded == after_confirm.recovery_wounded and during.recovery_fallen == after_confirm.recovery_fallen and during.save_sequence == after_confirm.save_sequence and during.armies == after_confirm.armies, "简报打开期间资源/人口/军队/存档序号不变")
	# 场景 14/15：查看城市影响只路由不改事实 + 分辨率检查
	_assert_brief_layout_fits("1280x720")
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	_assert_brief_layout_fits("1152x648")
	root.size = Vector2i(1280, 720)
	await process_frame
	var advice := _expected_advice(staged)
	var facts := {"receipt": staged, "advice": advice, "conservation": after_confirm}
	_write_facts("facts-w-flow.json", facts)
	if str(advice.get("priority", "")) == "retained":
		var route_button := panel.find_child("CampaignReturnRouteButton", true, false) as Button
		_expect(route_button != null, "路由按钮在场")
		if route_button != null:
			route_button.pressed.emit()
			await process_frame
			await process_frame
			_expect(view.visible, "暂存优先：路由到战役侧栏领取入口")
	else:
		# 稳定/伤员/粮食路由：分组打开，事实不变
		var route_button := panel.find_child("CampaignReturnRouteButton", true, false) as Button
		if route_button != null:
			route_button.pressed.emit()
		# 分组状态在路由调用内同步生效；周期刷新会按默认规则重置，不做跨帧断言。
		var expected_group: String = str(advice.get("group", "概况"))
		var groups: Dictionary = shell.get("_governance_groups")
		var opened := false
		for group_key in groups:
			var entry: Dictionary = groups[group_key]
			if String(group_key) == expected_group and bool(entry.get("open", false)):
				opened = true
		_expect(opened, "路由后打开分组「%s」" % expected_group)
		await process_frame
		await process_frame
		var after_route := _conservation_snapshot()
		_expect(after_route.home_food == during.home_food and after_route.home_wood == during.home_wood and after_route.garrison_total == during.garrison_total and after_route.save_sequence == during.save_sequence, "路由只切 UI：事实不变")
	# 场景 12 前半：dismiss 后不再出现
	var dismiss_button := shell.find_child("CampaignReturnDismissButton", true, false) as Button
	if dismiss_button == null:
		# 路由可能已关闭简报（open_governance_group 不关简报；retained 路由关）
		shell.call("hide_campaign_return_brief")
		await process_frame
	else:
		dismiss_button.pressed.emit()
		await process_frame
	_expect(_brief_panel() == null, "关闭简报后主城干净（07 场景）")
	_expect(_dict(city.get("_pending_campaign_return_brief")).is_empty(), "回执已消费，不再重现")


func _expected_advice(receipt: Dictionary) -> Dictionary:
	return city.call("_campaign_return_advice", receipt) as Dictionary


func _assert_brief_layout_fits(tag: String) -> void:
	var panel := _brief_panel()
	_expect(panel != null, "简报在场（%s）" % tag)
	if panel == null:
		return
	var control := panel as Control
	var viewport: Vector2 = shell.get_viewport_rect().size
	var rect := control.get_global_rect()
	_expect(
		rect.position.x >= 0.0 and rect.position.y >= -1.0
		and rect.end.x <= viewport.x + 1.0 and rect.end.y <= viewport.y + 1.0,
		"简报完整可见不出屏（%s rect=%s viewport=%s)" % [tag, rect, viewport],
	)
	var dismiss := panel.find_child("CampaignReturnDismissButton", true, false) as Control
	var route := panel.find_child("CampaignReturnRouteButton", true, false) as Control
	_expect(dismiss != null and dismiss.is_visible_in_tree(), "关闭按钮可达（%s）" % tag)
	_expect(route != null and route.is_visible_in_tree(), "主按钮可达（%s）" % tag)


## 场景 11：冷启动不重放旧简报。
func _stage_cold_no_replay() -> void:
	await process_frame
	_expect(_brief_panel() == null, "冷启动不重放简报")
	_expect(_dict(city.get("_pending_campaign_return_brief")).is_empty(), "冷启动控制器无暂存回执")
	_expect(runtime == null or runtime.has_settlement_receipt() == false, "冷启动 runtime 无回执")


## 场景 12：下一场 confirm 可以显示新简报（且 result_key 区分）。
func _stage_second_campaign() -> void:
	city.call("show_regular_campaign")
	await process_frame
	if not _require_view("第二次确认"):
		_finish()
		return
	var claim: Dictionary = runtime.command(&"claim")
	print("SECOND_CLAIM=", str(claim.get("message", claim.get("error", ""))))
	var chosen := _formations_chosen()
	var depart: Dictionary = runtime.command(&"depart", {"formation_ids": chosen, "food": 30, "wood": 55})
	_expect(bool(depart.get("success", false)), "第二次正式 depart 成功")
	var outcome: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	_expect(bool(outcome.get("success", false)), "第二次 WITHDRAW 成功")
	view._command(&"confirm", {})
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "第二次确认成功")
	_expect(int(_dict(city.get("_pending_campaign_return_brief")).get("attempt_sequence", -1)) == 2, "第二张回执 attempt_sequence=2（result_key 区分）")
	view.visible = false
	city._on_regular_campaign_view_closed()
	await process_frame
	_expect(_brief_panel() != null, "下一场确认后简报可以再次显示（恰一次）")
	shell.call("hide_campaign_return_brief")


## 场景 2：DEFEAT 确认与战损标题。
func _stage_defeat_flow() -> void:
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复 ACTIVE（D 路径）")
	if not _require_view("DEFEAT 确认"):
		_finish()
		return
	for _i in range(45):
		runtime.advance(1.0)
	var outcome: Dictionary = runtime.command(&"outcome", {"kind": &"DEFEAT"})
	_expect(bool(outcome.get("success", false)), "正式 DEFEAT 成功")
	if not bool(outcome.get("success", false)):
		# 不带着上一次遗留的 PENDING 结果继续跑，否则后续断言会确认到错误的 summary。
		print("DEFEAT_ERROR=", str(outcome.get("error", "")))
		_finish()
		return
	view._command(&"confirm", {})
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "路径 B 确认损益成功")
	var staged: Dictionary = _dict(city.get("_pending_campaign_return_brief"))
	_expect(str(staged.get("kind", "")) == "DEFEAT", "回执 kind=DEFEAT")
	view.visible = false
	city._on_regular_campaign_view_closed()
	await process_frame
	_expect(_brief_panel() != null, "DEFEAT：主城显示归来简报")
	_expect(_brief_title_text() == "青原战役 · 战损归城", "失败标题「青原战役 · 战损归城」")
	shell.call("hide_campaign_return_brief")


## 场景 4：保存失败 → 无回执、无简报、事务回滚。
func _stage_save_failure() -> void:
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复 ACTIVE（S 路径）")
	if not _require_view("保存失败回滚"):
		_finish()
		return
	var outcome: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	_expect(bool(outcome.get("success", false)), "WITHDRAW 进入 PENDING")
	if not bool(outcome.get("success", false)):
		print("S_WITHDRAW_ERROR=", str(outcome.get("error", "")))
		_finish()
		return
	var before := _conservation_snapshot()
	var scope_before := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	runtime.set("_failure_point", &"confirm")
	view._command(&"confirm", {})
	runtime.set("_failure_point", &"")
	_expect(StringName(runtime.data.phase) == &"PENDING", "checkpoint 失败 → confirm 被回滚报错（停在待确认）")
	_expect(runtime.has_settlement_receipt() == false, "保存失败：无回执")
	_expect(_dict(city.get("_pending_campaign_return_brief")).is_empty(), "保存失败：控制器无暂存")
	view.visible = false
	city._on_regular_campaign_view_closed()
	await process_frame
	_expect(_brief_panel() == null, "保存失败：不显示归来简报")
	var after := _conservation_snapshot()
	_expect(after == before, "回滚后资源/人口/军队/存档序号保持回滚前状态")
	var scope_after := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	_expect(int(scope_after.get("food", 0)) == int(scope_before.get("food", 0)) and int(scope_after.get("wood", 0)) == int(scope_before.get("wood", 0)), "前线暂存在回滚后不变")


## 场景 3：VICTORY 合法清关链 + 回执与正式 summary 一致。
func _stage_victory_flow() -> void:
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "冷启动恢复 ACTIVE（V 路径）")
	if not _require_view("胜利确认"):
		_finish()
		return
	await _wait_armies_stationed()
	var moved := await _capture_until_pending()
	if not moved:
		_expect(false, "合法清关链未能在预算内完成（不伪造胜利）")
		_finish()
		return
	_expect(StringName(runtime.data.phase) == &"PENDING", "双城占领自动进入 PENDING")
	view._command(&"confirm", {})
	_expect(StringName(runtime.data.phase) == &"COMPLETED", "胜利进入 COMPLETED")
	var staged: Dictionary = _dict(city.get("_pending_campaign_return_brief"))
	var summary := _dict(runtime.data.get("summary", {}))
	_expect(str(staged.get("kind", "")) == "VICTORY", "回执 kind=VICTORY")
	_expect(int(staged.get("survivors", -1)) == int(summary.get("survivors", -2)), "回执幸存者与正式 summary 一致")
	_expect(int(staged.get("wounded", -1)) == int(summary.get("wounded", -2)), "回执伤员与正式 summary 一致")
	_expect(int(staged.get("fallen", -1)) == int(summary.get("fallen", -2)), "回执阵亡与正式 summary 一致")
	_expect(str(staged.get("settlement_id", "")) == str(runtime.data.get("settlement_id", "x")), "胜利回执 settlement_id 与权威一致")
	view.visible = false
	city._on_regular_campaign_view_closed()
	await process_frame
	_expect(_brief_panel() != null, "VICTORY：主城显示归来简报")
	_expect(_brief_title_text() == "青原战役 · 凯旋归城", "胜利标题「青原战役 · 凯旋归城」")
	shell.call("hide_campaign_return_brief")


func _wait_armies_stationed() -> void:
	var deadline_ms := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline_ms:
		var stationed := true
		for id in runtime.data.army_ids:
			var army: Dictionary = city._army_registry.get_army(id)
			if army.is_empty() or StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_STATIONED:
				stationed = false
		if stationed and not runtime.data.army_ids.is_empty():
			break
		runtime.advance(2.0)
	_expect(not runtime.data.army_ids.is_empty(), "出征军队在场")


func _capture_until_pending() -> bool:
	var targets: Array = [&"redcliff_city", &"silverford_city"]
	for target in targets:
		var army_id := &""
		for id in runtime.data.army_ids:
			var army: Dictionary = city._army_registry.get_army(id)
			if not army.is_empty() and StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_CLOSED:
				army_id = id
				break
		if army_id == &"":
			print("VICTORY_DEBUG no available army")
			return false
		var move: Dictionary = {}
		var move_deadline_ms := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < move_deadline_ms:
			move = runtime.command(&"move", {"army_id": army_id, "target_id": target})
			if bool(move.get("success", false)):
				break
			runtime.advance(2.0)
		print("VICTORY move ", target, " -> ", str(move.get("message", move.get("error", ""))))
		if not bool(move.get("success", false)):
			return false
		var deadline_ms := Time.get_ticks_msec() + 90000
		var captured := false
		while Time.get_ticks_msec() < deadline_ms:
			runtime.advance(2.0)
			var state: Variant = city._war_loop_state.cities_by_id.get(target, {})
			var faction := str(_dict(state).get("military_controller_faction_id", ""))
			if faction == "player" or StringName(runtime.data.phase) == &"PENDING":
				captured = true
				break
		if not captured:
			print("VICTORY_DEBUG capture timeout at ", target)
			return false
	var deadline_pending := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline_pending and StringName(runtime.data.phase) != &"PENDING":
		runtime.advance(2.0)
	return StringName(runtime.data.phase) == &"PENDING"


## 经营优先级与回退的单元边界（纯读模型函数，不涉及存档）。
func _stage_advice_unit() -> void:
	if not await _new_campaign():
		_finish()
		return
	var synthetic_retained: Dictionary = {
		"retained_food": 18, "retained_wood": 6, "survivors": 0, "wounded": 0, "fallen": 0,
	}
	var advice: Dictionary = city.call("_campaign_return_advice", synthetic_retained)
	_expect(str(advice.get("priority", "")) == "retained", "优先级 1：前线暂存最优先")
	_expect(str(advice.get("text", "")).contains("18") and str(advice.get("text", "")).contains("6"), "暂存文案带回实际数量")
	# 优先级顺序里可在此证明的两级：暂存 > 粮食风险 > 概况。
	# 伤员一级的判据取自主城权威恢复读模型（不是回执字段），
	# 因此只能用真实交战产生的伤员验证，见 capture 的 defeat 用例。
	var forecast_net := int(_dict(city.call("get_city_food_forecast")).get("net", 0))
	var city_wounded := int(_dict(city.call("get_population_recovery_read_model")).get("wounded", 0))
	var no_retained: Dictionary = city.call("_campaign_return_advice",
		{"retained_food": 0, "retained_wood": 0})
	if city_wounded > 0:
		_expect(str(no_retained.get("priority", "")) == "wounded",
			"优先级 2：有 %d 名真实伤员时伤员优先于粮食风险" % city_wounded)
		_expect(str(no_retained.get("group", "")) == "医疗与民生", "伤员建议路由到医疗与民生")
	elif forecast_net < 0:
		_expect(str(no_retained.get("priority", "")) == "food",
			"优先级 3：无暂存且无伤员（本局伤员 %d）时粮食净额 %+d/日 → 粮食风险" % [city_wounded, forecast_net])
		_expect(str(no_retained.get("group", "")) == "生产与仓储", "粮食风险路由到生产与仓储")
	else:
		_expect(str(no_retained.get("priority", "")) == "stable",
			"优先级 4：主城无紧急风险 → 城市概况")
	_expect(shell.call("open_governance_group", "不存在的分组") == true, "未知分组安全回退")
	_expect(bool(_dict(shell.get("_governance_groups")).get("概况", {}).get("open", false)), "回退打开「概况」")
	_expect(shell.call("open_governance_group", "医疗与民生", "WoundedTreatmentButton") == true, "打开医疗与民生分组")
	var groups: Dictionary = shell.get("_governance_groups")
	_expect(bool(_dict(groups.get("医疗与民生", {})).get("open", false)), "医疗分组展开")
	_expect(not bool(_dict(groups.get("概况", {})).get("open", true)), "其他分组收起（单一目标分组）")
	var focus_target: Control = (shell.get("_governance_groups")["医疗与民生"]["body"] as VBoxContainer).find_child("WoundedTreatmentButton", true, false) as Control
	_expect(focus_target != null, "医疗焦点控件在场（WoundedTreatmentButton）")
	_expect(shell.call("open_governance_group", "生产与仓储", "GovernanceFoodButton") == true, "打开生产与仓储分组")
	_expect(bool(_dict(shell.get("_governance_groups")).get("生产与仓储", {}).get("open", false)), "生产分组展开")
	var food_target: Control = (shell.get("_governance_groups")["生产与仓储"]["body"] as VBoxContainer).find_child("GovernanceFoodButton", true, false) as Control
	_expect(food_target != null, "粮食焦点控件在场（GovernanceFoodButton）")
	# 路由必须活过后续刷新：city_state_changed 直连 _refresh_read_model，
	# 城市每帧推进都可能重排分组开合。
	city.city_state_changed.emit()
	_expect(bool(_dict(shell.get("_governance_groups")).get("生产与仓储", {}).get("open", false)),
		"城市状态刷新后路由分组仍展开")
	_expect(not bool(_dict(shell.get("_governance_groups")).get("概况", {}).get("open", true)),
		"城市状态刷新后不回流到默认「概况」")
	# 玩家自己开合面板 = 交还布局控制权，默认告警规则恢复。
	shell.call("_toggle_governance_workspace")
	shell.call("_toggle_governance_workspace")
	_expect(bool(_dict(shell.get("_governance_groups")).get("概况", {}).get("open", false)),
		"手动开合后恢复默认「概况」展开")
	_expect(not bool(_dict(shell.get("_governance_groups")).get("生产与仓储", {}).get("open", true)),
		"手动开合后清除路由指令")
