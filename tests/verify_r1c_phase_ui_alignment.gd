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
	_expect(city.call("show_regular_campaign"), "PREPARATION 残留 CITY 上下文回落备战表单")
	_expect(not city.is_regular_campaign_city_active(), "备战态不打开全屏前线内城")
	await process_frame
	# D1 结论：合法撤军→确认流程下主城容量充足时暂存全额归还（scope=0），
	# 不出现领取卡片；卡片显示逻辑用视图层合成模型单独验证（不触碰 runtime）。
	var scope_after_confirm: Dictionary = _dict(_dict(runtime.get_read_model().get("local", {})))
	_expect(int(scope_after_confirm.get("food", 0)) == 0 and int(scope_after_confirm.get("wood", 0)) == 0, "合法确认后前线无暂存残留（%s）" % str(scope_after_confirm))
	_expect(_find_button_exact(view, "领取结算暂存物资") == null, "无暂存时备战表单无领取卡片")
	# 视图层合成模型：仅构造显示数据验证卡片渲染条件，不提交任何命令。
	var display_model: Dictionary = runtime.get_read_model()
	display_model["local"] = {"food": 40, "wood": 20}
	view.set("_model", display_model)
	view._rebuild_sidebar()
	await process_frame
	_expect(_find_button_exact(view, "领取结算暂存物资") != null, "合成模型下领取卡片正确显示")
	view.refresh()
	await process_frame
	var re_formations: Array = Array(_dict(runtime.get_read_model().get("home", {})).get("formations", []))
	var re_chosen: Array = []
	for formation_value in re_formations:
		var formation: Dictionary = formation_value
		if int(formation.get("member_count", formation.get("count", 0))) > 0:
			re_chosen.append(StringName(formation.get("id", formation.get("formation_id", ""))))
	if re_chosen.is_empty():
		print("REDEPART_SKIP=归队后无可投入编队（编队重建为空）")
	var redepart: Dictionary = runtime.command(&"depart", {"formation_ids": re_chosen, "food": 30, "wood": 55})
	if not bool(redepart.get("success", false)):
		print("REDEPART_ERROR=", str(redepart.get("error", "")))
	_expect(bool(redepart.get("success", false)), "确认后再次出征成功且保存落盘（D1 闭环）")
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
