extends SceneTree

## R2B-1 可见操作取证驱动：真实窗口 + 合成鼠标事件（push_input），
## 与既有 input journey 同口径；不宣称真人试玩。
## 产出：TXWZS_R2B1_DELIVERY/ 下的 10 张证据图（按用户指令命名）。
##
## 每个 --case 是独立进程 + 独立隔离存档目录：战役 3 走完 VICTORY 后本关进入
## COMPLETED，同一存档链里再开新局无法回到备战页，共用目录会让后面的用例继承脏阶段。
## 跑批入口：tests/run_r2b1_evidence_matrix.sh
##
## 取证口径（EVIDENCE_MODE）：
##   playthrough  = 真实点击走完 confirm → 回城 → 简报 → 路由；
##   ui_render    = 只证明呈现层排布的合成回执渲染（事务事实由 verify 断言覆盖）。
## 全程隔离存档；不伪造胜利（VICTORY 走双城占领合法链，时间用 advance 加速）。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var case_id := ""
var out_dir := ""
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView
var shell: Node
var _budget_ms := 420000
var _started_ms := 0
var _finished := false

func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	process_frame.connect(_watchdog)
	call_deferred("_run")

## 看门狗：未预期的脚本错误会中断 _run 协程，让无头实例永远不退出。
func _watchdog() -> void:
	if _finished:
		return
	if Time.get_ticks_msec() - _started_ms > _budget_ms:
		push_error("R2B1 取证看门狗超时 case=%s 已失败项=%s" % [case_id, failures])
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if failures.is_empty():
		print("R2B1_EVIDENCE case=%s PASS all" % case_id)
		quit(0)
	else:
		print("R2B1_EVIDENCE case=%s FAIL failures=%s" % [case_id, failures])
		quit(1)

func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}

func _expect(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures.append(label)

func _expect_phase(expected: StringName, label: String) -> bool:
	var actual := StringName(runtime.data.phase)
	_expect(actual == expected, "%s（实际阶段 %s）" % [label, actual])
	return actual == expected

func _hold_frames(frames: int) -> void:
	for _i in frames:
		await process_frame

func _capture(filename: String) -> void:
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(filename)
	if image == null or image.save_png(path) != OK:
		failures.append("截图失败 " + filename)
		return
	print("SHOT ", filename)

## 侧栏按钮在折叠线以下时，点击坐标落在裁剪区外（点了但没响应）。
## 沿用 R1B 口径：先用 ScrollContainer 标准 API 滚进可视区，再取全局矩形。
func _scroll_sidebar_to(control: Control) -> void:
	if not is_instance_valid(view) or control == null or not control.is_visible_in_tree():
		return
	var sidebar: ScrollContainer = view._sidebar
	if sidebar == null or not is_instance_valid(sidebar) or not sidebar.is_ancestor_of(control):
		return
	for _pass in 2:
		sidebar.ensure_control_visible(control)
		await process_frame
		await process_frame

func _click_control(control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		failures.append("点击目标不可见")
		return
	await _scroll_sidebar_to(control)
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		failures.append("滚动后控件被重建，点击取消")
		return
	var center := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _find_button(node: Node, needle: String) -> Button:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text.contains(needle) and child.is_visible_in_tree():
			return child
	return null

func _new_game_fresh() -> void:
	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _hold_frames(12)
	city = scene.get_node("ConstructionController")
	runtime = city.get("_regular_campaign")
	view = city.get("_regular_campaign_view")
	shell = scene.get_node("UI/Shell")

func _new_campaign() -> bool:
	_expect(city.call("initialize_regular_campaign"), "初始化常规战役")
	runtime = city.get("_regular_campaign")
	city.call("show_regular_campaign")
	await _hold_frames(4)
	view = city.get("_regular_campaign_view")
	return runtime != null and runtime.enabled()

func _deploy_via_view() -> bool:
	var deploy_button := _find_button(view, "确认首批投入")
	if deploy_button == null:
		deploy_button = _find_button(view, "确认")
	_expect(deploy_button != null, "找到确认首批投入按钮")
	if deploy_button == null:
		return false
	await _click_control(deploy_button)
	await _hold_frames(6)
	return StringName(runtime.data.phase) == &"ACTIVE"

func _goto_result_tab() -> void:
	var result_tab := _find_button(view, "结算")
	if result_tab != null:
		await _click_control(result_tab)
	await _hold_frames(3)

func _confirm_via_view() -> void:
	await _goto_result_tab()
	var confirm_button := _find_button(view, "确认损益并归队")
	_expect(confirm_button != null, "确认按钮可见")
	if confirm_button != null:
		await _click_control(confirm_button)
	await _hold_frames(8)

func _return_home_via_view() -> void:
	# 确认成功后视图切回备战表单，同一个按钮文案变成「收起备战表单 · 返回主城」；
	# 按控件引用取，不再靠文案匹配找按钮。
	var back := view._leave_button if is_instance_valid(view) else null
	if back == null or not back.is_visible_in_tree():
		back = _find_button(view, "返回永久主城")
	_expect(back != null, "返回主城按钮可见")
	if back != null:
		await _click_control(back)
	await _hold_frames(8)

func _brief_panel() -> Node:
	return shell.find_child("CampaignReturnBrief", false, false)

func _brief_button(button_name: String) -> Button:
	var panel := _brief_panel()
	if panel == null:
		return null
	return panel.find_child(button_name, true, false) as Button

## 简报不在场时记一条失败并跳过依赖它的截图，而不是对 null 调 find_child。
func _brief_onstage(label: String) -> bool:
	var present := _brief_panel() != null
	_expect(present, label)
	return present

func _log_advice(tag: String) -> void:
	var panel := _brief_panel()
	if panel == null:
		return
	var advice_label := panel.find_child("CampaignReturnAdvice", true, false)
	var advice_text := "" if advice_label == null else str(advice_label.text).replace("\n", " / ")
	print("EVIDENCE_ADVICE ", tag, " group=", str(shell.get("_campaign_return_route_group")),
		" text=", advice_text)

func _available_army_id() -> StringName:
	for id in runtime.data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		if not army.is_empty() and StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_CLOSED:
			return id
	return &""

func _wait_stationed() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var ok: bool = not Array(runtime.data.army_ids).is_empty()
		for id in runtime.data.army_ids:
			var army: Dictionary = city._army_registry.get_army(id)
			if army.is_empty() or StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_STATIONED:
				ok = false
		if ok:
			break
		runtime.advance(2.0)

## 向一个目标行军并推进到占领或明确失败；返回是否占领。
func _march_to(target: StringName, budget_ms: int) -> bool:
	var army_id := _available_army_id()
	if army_id == &"":
		_expect(false, "向 %s 行军：无可用军队" % target)
		return false
	var moved := false
	var move_deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < move_deadline and not moved:
		var move: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": target})
		moved = bool(move.get("success", false))
		if not moved:
			runtime.advance(2.0)
	_expect(moved, "向 %s 行军" % target)
	if not moved:
		return false
	var deadline := Time.get_ticks_msec() + budget_ms
	while Time.get_ticks_msec() < deadline:
		runtime.advance(2.0)
		var state: Variant = city._war_loop_state.cities_by_id.get(target, {})
		if str(_dict(state).get("military_controller_faction_id", "")) == "player":
			return true
		if StringName(runtime.data.phase) == &"PENDING":
			return true
	print("EVIDENCE march_to ", target, " 未在预算内占领 phase=", runtime.data.phase)
	return false

func _render_brief_from_fixture(receipt: Dictionary, tag: String) -> void:
	var advice: Dictionary = city.call("_campaign_return_advice", receipt)
	shell.call("show_campaign_return_brief", receipt, advice)
	await _hold_frames(6)
	if _brief_onstage(tag + " 简报渲染完成（ui_render）"):
		_log_advice(tag + "（ui_render）")

# ── 用例 ──────────────────────────────────────────────────────────────

## A：撤军归来（08 暂离无简报 → 01 简报 1280 → 09 简报 1152 → 10 路由分组）
func _case_withdraw() -> void:
	print("EVIDENCE_MODE playthrough")
	await _new_game_fresh()
	_expect(await _new_campaign(), "战役初始化")
	_expect(await _deploy_via_view(), "确认首批投入（真实点击）")
	var leave := _find_button(view, "暂离关卡")
	_expect(leave != null, "暂离按钮可见")
	if leave != null:
		await _click_control(leave)
	await _hold_frames(6)
	_expect(_brief_panel() == null, "08 前置：ACTIVE 暂离回主城无简报")
	await _capture("08-no-brief-on-temporary-leave.png")
	city.call("show_regular_campaign")
	await _hold_frames(4)
	# 撤军入口在概览页「常用行动」，折叠线以下需先滚进可视区
	var withdraw_button := _find_button(view, "申请撤军结算")
	_expect(withdraw_button != null, "找到撤军入口")
	if withdraw_button != null:
		await _click_control(withdraw_button)
	await _hold_frames(6)
	if not _expect_phase(&"PENDING", "撤军生成待确认结果"):
		return
	await _confirm_via_view()
	_expect_phase(&"PREPARATION", "撤军结算回 PREPARATION")
	await _return_home_via_view()
	await _hold_frames(4)
	if not _brief_onstage("01 战役归来简报出现"):
		return
	_log_advice("01 撤军简报")
	await _capture("01-withdraw-return-brief-1280.png")
	root.size = Vector2i(1152, 648)
	await _hold_frames(8)
	await _capture("09-return-brief-1152.png")
	root.size = Vector2i(1280, 720)
	await _hold_frames(8)
	var route := _brief_button("CampaignReturnRouteButton")
	_expect(route != null, "查看城市影响按钮在场")
	if route != null:
		await _click_control(route)
	await _hold_frames(6)
	await _capture("10-governance-routed-group.png")
	_expect(city.wood > 0 or city.food > 0, "路由后城市事实完好")

## B：前线暂存警示带（04）
## 暂存只在主城仓储剩余容量 < 本关库存时产生。默认新局粮食净额为负，
## 且自由容量 ≥ 单次携出上限，有界合法流程内填不满仓储
## （R1C-D1 同样记录"合法流程下主城容量充足，无暂存可领"）。
## 因此这张图只证明警示带排布：先走真实撤军回城（背景与真归城一致），
## 再用合成回执渲染警示带；暂存事实字段与优先级由
## verify 的 W_flow（回执字段）与 U_advice（优先级顺序）断言覆盖。
func _case_retained() -> void:
	print("EVIDENCE_MODE ui_render（警示带为呈现层渲染；背景状态真实）")
	await _new_game_fresh()
	_expect(await _new_campaign(), "暂存用例战役初始化")
	_expect(await _deploy_via_view(), "暂存用例首批投入")
	await _goto_result_tab()
	var retreat := _find_button(view, "申请撤军结算")
	if retreat == null:
		retreat = _find_button(view, "放弃本关")
	_expect(retreat != null, "暂存用例找到归城入口")
	if retreat != null:
		await _click_control(retreat)
	await _hold_frames(6)
	await _confirm_via_view()
	await _return_home_via_view()
	await _hold_frames(4)
	if not _brief_onstage("暂存用例：真实归城简报在场（背景状态）"):
		return
	var dismiss := _brief_button("CampaignReturnDismissButton")
	if dismiss != null:
		await _click_control(dismiss)
	await _hold_frames(4)
	_expect(_brief_panel() == null, "真实简报已由「知道了」关闭（一次性）")
	var fixture: Dictionary = {
		"receipt_version": 1,
		"result_key": "regular.settlement.1.WITHDRAW",
		"campaign_id": String(runtime.SCOPE),
		"settlement_id": "regular.settlement.1",
		"attempt_sequence": 1,
		"kind": "WITHDRAW",
		"survivors": 20, "wounded": 0, "fallen": 0, "local_people": 0,
		"food_return_actual": 62, "wood_return_actual": 41,
		"retained_food": 18, "retained_wood": 6,
		"elapsed_ms": 1284000, "mainline_elapsed_ms": 1284000,
		"totals": {"food_in": 80, "wood_in": 47, "food_produced": 0, "food_used": 18,
			"wood_produced": 0, "wood_used": 0},
	}
	await _render_brief_from_fixture(fixture, "04 暂存警示")
	var rendered := _brief_panel()
	if rendered == null:
		return
	var advice_label := rendered.find_child("CampaignReturnAdvice", true, false)
	_expect(str(advice_label.text).contains("暂存"), "04 警示优先显示前线暂存")
	await _capture("04-retained-resources-warning.png")
	var dismiss2 := _brief_button("CampaignReturnDismissButton")
	if dismiss2 != null:
		await _click_control(dismiss2)
	await _hold_frames(4)
	_expect(_brief_panel() == null, "04 关闭后主城干净")

## C：胜利凯旋（03 简报 → 07 关闭后主城干净）
func _case_victory() -> void:
	print("EVIDENCE_MODE playthrough")
	await _new_game_fresh()
	_expect(await _new_campaign(), "战役初始化")
	_expect(await _deploy_via_view(), "首批投入")
	await _wait_stationed()
	for target in [&"redcliff_city", &"silverford_city"]:
		var captured := await _march_to(target, 120000)
		print("EVIDENCE target ", target, " captured=", captured, " phase=", runtime.data.phase)
	var pending_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < pending_deadline and StringName(runtime.data.phase) != &"PENDING":
		runtime.advance(2.0)
	if not _expect_phase(&"PENDING", "双城占领自动胜利进入 PENDING"):
		return
	await _confirm_via_view()
	_expect_phase(&"COMPLETED", "胜利确认进入 COMPLETED")
	await _return_home_via_view()
	await _hold_frames(4)
	if not _brief_onstage("03 凯旋简报出现"):
		return
	_log_advice("03 胜利简报")
	await _capture("03-victory-return-brief-1280.png")
	var dismiss := _brief_button("CampaignReturnDismissButton")
	if dismiss != null:
		await _click_control(dismiss)
	await _hold_frames(6)
	_expect(_brief_panel() == null, "07 前置：知道了已关闭简报")
	await _capture("07-brief-dismissed-city-clean.png")

## D：战损归城（02 标题、06 粮食风险路由）+ 05 医疗优先
func _case_defeat() -> void:
	print("EVIDENCE_MODE playthrough")
	await _new_game_fresh()
	_expect(await _new_campaign(), "战损用例初始化")
	_expect(await _deploy_via_view(), "战损用例首批投入")
	await _wait_stationed()
	# 先打一处已知可达目标，制造真实战斗减员（伤员 = 战斗损失的一半）
	await _march_to(&"redcliff_city", 90000)
	var recovery_before := _dict(city.call("get_population_recovery_read_model"))
	print("EVIDENCE combat_losses=", int(runtime.data.combat_losses_total),
		" wounded=", int(recovery_before.get("wounded", 0)))
	await _goto_result_tab()
	var retreat := _find_button(view, "放弃本关")
	_expect(retreat != null, "找到放弃本关入口")
	if retreat != null:
		await _click_control(retreat)
	await _hold_frames(6)
	await _confirm_via_view()
	if not _expect_phase(&"PREPARATION", "战损结算回 PREPARATION"):
		return
	await _return_home_via_view()
	await _hold_frames(4)
	if not _brief_onstage("02 战损简报出现"):
		return
	_log_advice("02 战损标题")
	await _capture("02-defeat-return-brief-1280.png")
	var title := shell.find_child("CampaignReturnTitle", true, false)
	_expect(title != null and str(title.text) == "青原战役 · 战损归城", "02 标题为「青原战役 · 战损归城」")
	var route := _brief_button("CampaignReturnRouteButton")
	if route != null:
		await _click_control(route)
	await _hold_frames(6)
	var opened := bool(shell.get("_governance_open"))
	var wounded := int(_dict(city.call("get_population_recovery_read_model")).get("wounded", 0))
	print("EVIDENCE route opened=", opened, " wounded=", wounded,
		" group=", str(shell.get("_campaign_return_route_group")))
	if wounded > 0:
		# 05：真实伤员 → 医疗与民生分组（含治疗焦点控件）
		print("EVIDENCE_MODE_05 playthrough")
		await _capture("05-medical-priority-action.png")
		var medical_body: VBoxContainer = Dictionary(_dict(shell.get("_governance_groups")).get("医疗与民生", {})).get("body")
		_expect(medical_body != null
			and medical_body.find_child("WoundedTreatmentButton", true, false) != null,
			"05 医疗分组已展开且治疗控件在场")
	else:
		# 本次交战未产生伤员：05 退化为呈现层渲染，医疗路由本身由 U_advice 断言覆盖。
		print("EVIDENCE_MODE_05 ui_render（本局无真实伤员）")
		var fixture: Dictionary = {
			"receipt_version": 1, "result_key": "regular.settlement.1.WITHDRAW",
			"campaign_id": String(runtime.SCOPE), "settlement_id": "regular.settlement.1",
			"attempt_sequence": 1, "kind": "WITHDRAW",
			"survivors": 19, "wounded": 3, "fallen": 1, "local_people": 0,
			"food_return_actual": 30, "wood_return_actual": 55,
			"retained_food": 0, "retained_wood": 0,
			"elapsed_ms": 1284000, "mainline_elapsed_ms": 1284000,
			"totals": {"food_in": 30, "wood_in": 55, "food_produced": 0, "food_used": 0,
				"wood_produced": 0, "wood_used": 0},
		}
		await _render_brief_from_fixture(fixture, "05 医疗优先")
		var route5 := _brief_button("CampaignReturnRouteButton")
		if route5 != null:
			await _click_control(route5)
		await _hold_frames(6)
		await _capture("05-medical-priority-action.png")
	_expect(bool(_dict(shell.get("_governance_groups")).get("医疗与民生", {}).get("open", false)),
		"05 医疗与民生分组展开")

## 06：粮食风险优先建议（默认新局主城粮食净额为负，路由由真实读模型决定）
func _case_food_risk() -> void:
	print("EVIDENCE_MODE playthrough")
	await _new_game_fresh()
	_expect(await _new_campaign(), "粮食风险用例初始化")
	_expect(await _deploy_via_view(), "粮食风险用例首批投入")
	await _goto_result_tab()
	var retreat := _find_button(view, "放弃本关")
	_expect(retreat != null, "找到放弃本关入口")
	if retreat != null:
		await _click_control(retreat)
	await _hold_frames(6)
	await _confirm_via_view()
	if not _expect_phase(&"PREPARATION", "粮食风险用例结算回 PREPARATION"):
		return
	await _return_home_via_view()
	await _hold_frames(4)
	if not _brief_onstage("06 简报出现"):
		return
	_log_advice("06 粮食风险建议")
	await _capture("06-food-risk-priority-action.png")
	var route := _brief_button("CampaignReturnRouteButton")
	if route != null:
		await _click_control(route)
	await _hold_frames(6)
	_expect(bool(_dict(shell.get("_governance_groups")).get("生产与仓储", {}).get("open", false)),
		"06 路由到生产与仓储分组")

func _run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--txwzs-require-isolated-save":
			isolated = true
		elif arg.begins_with("--txwzs-v5-save-dir="):
			DirAccess.make_dir_recursive_absolute(arg.trim_prefix("--txwzs-v5-save-dir="))
		elif arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
		elif arg.begins_with("--case="):
			case_id = arg.trim_prefix("--case=")
	if not isolated or out_dir.is_empty() or case_id.is_empty():
		push_error("R2B1 evidence: 需要 --txwzs-require-isolated-save、--out-dir 与 --case")
		_finished = true
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	await _hold_frames(8)
	match case_id:
		"withdraw":
			await _case_withdraw()
		"retained":
			await _case_retained()
		"victory":
			await _case_victory()
		"defeat":
			await _case_defeat()
		"food_risk":
			await _case_food_risk()
		_:
			push_error("未知取证用例：" + case_id)
			_finished = true
			quit(2)
			return
	_finish()
