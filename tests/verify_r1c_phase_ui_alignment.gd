extends SceneTree

## R1C phase-UI 对齐定向短测（程序级）。
## 覆盖：PREPARATION 拒绝话术按阶段拆分、备战表单表现（PREP 模式）、
## 确认投入经既有事务进入战区、ACTIVE 全屏内城编号地块的显示门槛。
## 约束：不改选择算法、不放宽建设权限；直接调用正式命令属于程序级权限测试，
## 不作为 GUI 可用性证明（GUI 取证另行真人点击执行）。

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
	var title_text := str(view.get("_title_label").text)
	_expect(title_text.contains("永久主城 · 备战"), "标题标注永久主城备战（%s）" % title_text)
	_expect(not title_text.contains("战时内城"), "标题不再出现战时内城")
	var resource_text := str(view.get("_resource_label").text)
	_expect(resource_text.begins_with("主城"), "资源读数取主城口径（%s）" % resource_text)

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
	# 程序级测试：推进模拟时钟让出征编队走到驻地（真实 GUI 中由时间自然推进）。
	var deadline_ms := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline_ms and int(runtime._base_members()) < 2:
		runtime.advance(1.0)
	_expect(int(runtime._base_members()) >= 2, "出征编队抵达驻地，满足施工队人数")
	view.refresh()
	_expect(view.get("_surface_mode") == &"THEATER", "视图随权威状态切到战区表现")
	_expect(view.get("_map_frame").visible, "战区态恢复地图画布")
	_expect(view.get("_tab_host").visible, "战区态恢复 tab 导航")
	_expect(not view.get("_prep_action_bar").visible, "战区态收起固定投入操作区")

	# ---- B：ACTIVE 下拒绝原因与建设标记门槛 ----
	var wrong_point_receipt: Dictionary = runtime.command(&"build", {"point_id": &"silverford", "kind": &"FARM", "plot": 0})
	_expect(not bool(wrong_point_receipt.get("success", true)) and str(wrong_point_receipt.get("error", "")).contains("此处仅支持休整"), "普通驻点开工拒绝并说明地点无资格")
	var enter_receipt: Dictionary = runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"})
	_expect(bool(enter_receipt.get("success", false)), "ACTIVE 经既有命令进入许可城市内城")
	_expect(city.call("show_regular_campaign_city"), "全屏内城呈现（原 MapWorld 城市外壳）")
	var host: Node = city.get("_regular_campaign_city_host")
	_expect(host != null and bool(host.get("_buildable_plots_visible")), "ACTIVE 空内城显示编号可建设地块")
	var selected: bool = city.call("select_regular_campaign_plot", 0)
	_expect(selected, "全屏内城选中 1 号地块（正式选择入口）")
	var start_result: Dictionary = city.call("_regular_campaign_start_build", &"FARM")
	if not bool(start_result.get("success", false)):
		print("START_BUILD_ERROR=", str(start_result.get("error", "")))
	_expect(bool(start_result.get("success", false)), "全屏内城真实开工（正式命令）")
	_expect(host != null and not bool(host.get("_buildable_plots_visible")), "开工后收起编号地块标记（施工反馈态）")
	var cancel_receipt: Dictionary = runtime.command(&"cancel_build")
	_expect(bool(cancel_receipt.get("success", false)), "取消施工并退还投入")
	_expect(Dictionary(_dict(runtime.get_read_model().get("local", {})).get("project", {})).is_empty(), "取消后工程队列为空")
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
