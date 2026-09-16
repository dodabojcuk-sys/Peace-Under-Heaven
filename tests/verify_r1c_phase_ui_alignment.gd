extends SceneTree

## R1C phase-UI 对齐定向短测（程序级）。
## 覆盖：PREPARATION 拒绝话术按阶段拆分、备战表单表现（PREP 模式）、
## 确认投入经既有事务进入战区、编号地块跟随建设菜单状态（正反成对）、
## 撤军结算后"领取暂存"入口回归与守恒、再次出征解锁。
## 约束：不改选择算法、不放宽建设权限；直接调用正式命令与引擎状态注水
## 属于程序级夹具（明确标注），不作为 GUI 可用性证明。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
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


func _find_button_exact(node: Node, text: String) -> Button:
	if node is Button and str(node.text) == text:
		return node
	for child in node.get_children():
		var found := _find_button_exact(child, text)
		if found != null:
			return found
	return null


func _run() -> void:
	var has_isolated_save := false
	var save_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--txwzs-require-isolated-save":
			has_isolated_save = true
		elif arg.begins_with("--txwzs-v5-save-dir="):
			save_dir = arg.trim_prefix("--txwzs-v5-save-dir=")
	if not has_isolated_save or save_dir.is_empty():
		push_error("R1C 门禁：缺少隔离存档参数，拒绝运行")
		quit(3)
		return
	root.size = Vector2i(1280, 720)

	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in range(12):
		await process_frame
	city = scene.get_node_or_null("ConstructionController")
	_expect(city != null, "城市场景装载并找到 ConstructionController")
	if city == null:
		_finish()
		return
	_expect(city.call("initialize_regular_campaign"), "常规候选战役初始化")
	runtime = city.get("_regular_campaign")
	_expect(runtime != null and runtime.enabled(), "战役运行时已启用")

	# ---- A：PREPARATION 必须呈现备战表单，而不是前线内城 ----
	_expect(city.call("show_regular_campaign"), "从既有入口链打开战役视图")
	await process_frame
	await process_frame
	view = city.get("_regular_campaign_view")
	_expect(view != null, "战役视图已创建")
	if view == null:
		_finish()
		return
	var model: Dictionary = runtime.get_read_model()
	_expect(StringName(model.get("phase", &"")) == &"PREPARATION", "读回阶段为 PREPARATION（权威状态）")
	_expect(view.get("_surface_mode") == &"PREP", "备战阶段呈现 PREP 模式（不再伪装 CITY 内城）")
	_expect(not view.get("_map_frame").visible, "备战态隐藏前线城市画布")
	_expect(not view.get("_tab_host").visible, "备战态隐藏四个长页 tab")
	_expect(view.get("_prep_action_bar").visible, "备战态显示固定投入操作区")
	var backdrop: ColorRect = view.get("_backdrop")
	_expect(backdrop != null and backdrop.color.a < 1.0, "备战底板为半透明遮罩（原主城可见）")
	var title_text := str(view.get("_title_label").text)
	_expect(title_text.contains("永久主城 · 备战"), "标题标注永久主城备战（%s）" % title_text)
	_expect(not title_text.contains("战时内城"), "标题不再出现战时内城")
	var resource_text := str(view.get("_resource_label").text)
	_expect(resource_text.begins_with("主城"), "资源读数取主城口径（%s）" % resource_text)
	# 无暂存的新局不出现领取卡片。
	_expect(_find_button_exact(view, "领取结算暂存物资") == null, "无暂存的新局不出现领取卡片")

	# ---- A/B：PREPARATION 下建设与场景切换按阶段拒绝，话术与阶段对应 ----
	var build_receipt: Dictionary = runtime.command(&"build", {"point_id": &"blackstone_city", "kind": &"FARM", "plot": 0})
	_expect(not bool(build_receipt.get("success", true)) and str(build_receipt.get("error", "")).contains("尚未确认首批兵粮"), "备战期开工拒绝并说明阶段未满足")
	var city_receipt: Dictionary = runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"})
	_expect(not bool(city_receipt.get("success", true)) and str(city_receipt.get("error", "")).contains("尚未确认首批兵粮"), "备战期进内城拒绝并说明阶段未满足")
	var theater_receipt: Dictionary = runtime.command(&"view", {"surface": &"THEATER"})
	_expect(not bool(theater_receipt.get("success", true)) and str(theater_receipt.get("error", "")).contains("首批投入尚未确认"), "备战期进战区拒绝并提示先确认投入")

	# ---- 正式确认投入（既有事务），进入战区 ----
	var formations: Array = Array(_dict(model.get("home", {})).get("formations", []))
	var chosen: Array = []
	for formation_value in formations:
		var formation: Dictionary = formation_value
		if int(formation.get("member_count", formation.get("count", 0))) > 0:
			chosen.append(StringName(formation.get("id", formation.get("formation_id", ""))))
	_expect(not chosen.is_empty(), "主城存在可投入编队")
	var depart_receipt: Dictionary = runtime.command(&"depart", {"formation_ids": chosen, "food": 30, "wood": 55})
	_expect(bool(depart_receipt.get("success", false)), "确认首批投入（正式事务）成功")
	model = runtime.get_read_model()
	_expect(StringName(model.get("phase", &"")) == &"ACTIVE", "确认后阶段为 ACTIVE")
	_expect(StringName(_dict(model.get("view_context", {})).get("surface", &"")) == &"THEATER", "确认后进入既有战区（surface=THEATER）")
	view.refresh()
	_expect(view.get("_surface_mode") == &"THEATER", "视图随权威状态切到战区表现")
	_expect(view.get("_map_frame").visible, "战区态恢复地图画布")
	_expect(view.get("_tab_host").visible, "战区态恢复 tab 导航")
	_expect(not view.get("_prep_action_bar").visible, "战区态收起固定投入操作区")
	# 程序级测试：推进模拟时钟让出征编队走到驻地（真实 GUI 中由时间自然推进）。
	var deadline_ms := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline_ms and int(runtime._base_members()) < 2:
		runtime.advance(1.0)
	_expect(int(runtime._base_members()) >= 2, "出征编队抵达驻地，满足施工队人数")

	# ---- B：ACTIVE 下拒绝原因与建设标记跟随建设菜单状态（正反成对） ----
	var wrong_point_receipt: Dictionary = runtime.command(&"build", {"point_id": &"silverford", "kind": &"FARM", "plot": 0})
	_expect(not bool(wrong_point_receipt.get("success", true)) and str(wrong_point_receipt.get("error", "")).contains("此处仅支持休整"), "普通驻点开工拒绝并说明地点无资格")
	var enter_receipt: Dictionary = runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"})
	_expect(bool(enter_receipt.get("success", false)), "ACTIVE 经既有命令进入许可城市内城")
	_expect(city.call("show_regular_campaign_city"), "全屏内城呈现（原 MapWorld 城市外壳）")
	var host: Node = city.get("_regular_campaign_city_host")
	_expect(host != null, "全屏内城城市宿主就绪")
	_expect(host != null and not bool(host.get("_buildable_plots_visible")), "正常查看城市不铺编号框（默认态）")
	var selected: bool = city.call("select_regular_campaign_plot", 0)
	_expect(selected, "打开建设并选中 1 号地块（正式选择入口）")
	_expect(host != null and bool(host.get("_buildable_plots_visible")), "建设菜单打开后显示可建设位置")
	var start_result: Dictionary = city.call("_regular_campaign_start_build", &"FARM")
	if not bool(start_result.get("success", false)):
		print("START_BUILD_ERROR=", str(start_result.get("error", "")))
	_expect(bool(start_result.get("success", false)), "全屏内城真实开工（正式命令）")
	_expect(host != null and not bool(host.get("_buildable_plots_visible")), "开工后收起编号地块标记（仅保留施工反馈）")
	var cancel_receipt: Dictionary = runtime.command(&"cancel_build")
	_expect(bool(cancel_receipt.get("success", false)), "取消施工并退还投入")
	_expect(Dictionary(_dict(runtime.get_read_model().get("local", {})).get("project", {})).is_empty(), "取消后工程队列为空")
	_expect(host != null and not bool(host.get("_buildable_plots_visible")), "取消后标记保持收起")

	# ---- §2 领取暂存回归：正式撤军→确认→PREPARATION+暂存→领取→再次出征 ----
	var withdraw_receipt: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	_expect(bool(withdraw_receipt.get("success", false)), "正式撤军生成待确认损益")
	_expect(StringName(runtime.get_read_model().get("phase", &"")) == &"PENDING", "撤军后进入 PENDING")
	var confirm_receipt: Dictionary = runtime.command(&"confirm")
	_expect(bool(confirm_receipt.get("success", false)), "确认损益（正式事务）")
	model = runtime.get_read_model()
	_expect(StringName(model.get("phase", &"")) == &"PREPARATION", "非胜利结算回到 PREPARATION")
	# 程序级夹具（非玩家操作）：用引擎自身的状态注水 API 构造"主城容量不足→
	# 暂存留前线"，等价于真实战斗消耗把主城粮仓抬满后的结算残留。
	var nation: Object = city.get_nation_state()
	var scopes: Dictionary = nation.get_scoped_resources()
	scopes[runtime.SCOPE] = {"food": 40, "wood": 20}
	_expect(nation.hydrate_scoped_resources(scopes), "夹具：前线暂存注水（粮 40 · 木 20）")
	_expect(city.call("show_regular_campaign"), "PREPARATION 残留 CITY 上下文回落备战表单")
	_expect(not city.is_regular_campaign_city_active(), "备战态不打开全屏前线内城")
	await process_frame
	var claim_button: Button = _find_button_exact(view, "领取结算暂存物资")
	_expect(claim_button != null, "备战表单出现领取暂存入口（回归修复）")
	var home_before: Dictionary = _dict(runtime.get_read_model().get("home", {}))
	var claim_receipt: Dictionary = runtime.command(&"claim")
	if not bool(claim_receipt.get("success", false)):
		print("CLAIM_ERROR=", str(claim_receipt.get("error", "")))
	_expect(bool(claim_receipt.get("success", false)), "领取暂存（正式事务）成功")
	var home_after: Dictionary = _dict(runtime.get_read_model().get("home", {}))
	var scope_after: Dictionary = nation.get_scope(runtime.SCOPE)
	var food_moved := int(home_after.get("food", 0)) - int(home_before.get("food", 0))
	var wood_moved := int(home_after.get("wood", 0)) - int(home_before.get("wood", 0))
	_expect(food_moved == 40 - int(scope_after.get("food", 0)), "粮食守恒：主城增量+剩余暂存=40（%d+%d）" % [food_moved, int(scope_after.get("food", 0))])
	_expect(wood_moved == 20 - int(scope_after.get("wood", 0)), "木材守恒：主城增量+剩余暂存=20（%d+%d）" % [wood_moved, int(scope_after.get("wood", 0))])
	var re_claim: Dictionary = runtime.command(&"claim")
	_expect(not bool(re_claim.get("success", true)) and str(re_claim.get("error", "")).contains("暂无可领取"), "重复领取被拒绝，不增发物资")
	view.refresh()
	# 重建用 queue_free：旧按钮要等帧末才离开树，立即搜索会命中将死节点。
	await process_frame
	_expect(_find_button_exact(view, "领取结算暂存物资") == null, "暂存领完后入口收起")
	var re_formations: Array = Array(_dict(runtime.get_read_model().get("home", {})).get("formations", []))
	var re_chosen: Array = []
	for formation_value in re_formations:
		var formation: Dictionary = formation_value
		if int(formation.get("member_count", formation.get("count", 0))) > 0:
			re_chosen.append(StringName(formation.get("id", formation.get("formation_id", ""))))
	if re_chosen.is_empty():
		print("REDEPART_SKIP=归队后无可投入编队（编队重建为空）")
	var redepart: Dictionary = runtime.command(&"depart", {"formation_ids": re_chosen, "food": 30, "wood": 55})
	# 本轮边界：出征不再被"请先领取上次结算暂存"阻塞（错误不再来自暂存检查）。
	_expect(not str(redepart.get("error", "")).contains("请先领取上次结算暂存"), "再次出征不再被暂存检查阻塞")
	if not bool(redepart.get("success", false)):
		# 已知开放（不属本轮）：撤军→确认→再出征的深层 V5 持久化回滚
		# （INVALID_REGULAR_CAMPAIGN / EMPTY_SNAPSHOT），保留日志单独定位。
		print("REDEPART_PERSIST_OPEN=", str(redepart.get("error", "")))
	_finish()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _finish() -> void:
	if failures.is_empty():
		print("R1C_PHASE_UI PASS all")
		quit(0)
	else:
		print("R1C_PHASE_UI FAIL failures=", failures)
		quit(1)
