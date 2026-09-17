extends SceneTree

## R2A.1 定向短测：城市经营入口只属于永久主城 + 强制收起同步 + 推荐聚焦。
## 程序级断言（GUI 真人点击另行取证）。所有状态经正式命令与既有服务产生。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var city: Node
var ui: Node
var runtime: RegularCampaignRuntime


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
	for arg in OS.get_cmdline_user_args():
		if arg == "--txwzs-require-isolated-save":
			has_isolated_save = true
	if not has_isolated_save:
		push_error("R2A.1 门禁：缺少 --txwzs-require-isolated-save")
		quit(3)
		return
	root.size = Vector2i(1280, 720)
	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in range(12):
		await process_frame
	city = scene.get_node_or_null("ConstructionController")
	ui = scene.get_node_or_null("InnerCityUIR0")
	if ui == null:
		for child in scene.get_children():
			if child.get_node_or_null("GovernanceWorkspace") != null or child.name == "UI":
				break
		ui = scene.get_node_or_null("UI/Shell")
	if ui == null or not ui.has_method("_sync_governance_chrome"):
		# InnerCityUIR0 脚本挂在 UI/Shell 节点上
		var shell := scene.get_node_or_null("UI/Shell")
		if shell != null and shell.get_script() != null:
			ui = shell
	_expect(city != null and ui != null, "场景装载（ConstructionController + InnerCityUIR0）")
	if city == null or ui == null:
		_finish()
		return
	var toggle: Button = ui.get("governance_toggle_button")
	var workspace: PanelContainer = ui.get("governance_workspace")
	_expect(toggle != null and workspace != null, "总览开关与面板节点存在")
	if toggle == null or workspace == null:
		_finish()
		return

	_expect(city.call("initialize_regular_campaign"), "常规候选战役初始化")
	runtime = city.get("_regular_campaign")
	await process_frame
	await process_frame

	# ---- 验收 1：默认全屏、经营面板关闭 ----
	_expect(not workspace.visible, "默认经营面板关闭")
	_expect(toggle.visible, "永久主城显示城市经营开关")
	_expect(str(toggle.text) == "城市经营", "默认按钮文案为「城市经营」")

	# ---- 验收 2：打开面板，按钮变「收起经营」 ----
	ui.call("_toggle_governance_workspace")
	await process_frame
	_expect(workspace.visible, "开关打开经营面板")
	_expect(str(toggle.text) == "收起经营", "面板打开时按钮文案为「收起经营」")

	# ---- 验收 3：建筑详情强制关闭并同步按钮 ----
	var records: Dictionary = city.get("_building_records_by_id")
	var some_id := -1
	for id_value in records:
		some_id = int(id_value)
		break
	_expect(some_id >= 0, "城市存在可选中的既有建筑")
	var selection: Node = city.get("building_selection_controller")
	if selection == null:
		selection = scene.get_node_or_null("BuildingSelectionController")
	_expect(selection != null, "BuildingSelectionController 可用")
	if selection != null and some_id >= 0:
		selection.call("select_placement", some_id)
		ui.call("_refresh_read_model")
		await process_frame
		await process_frame
		var detail: Panel = ui.get("detail_panel")
		_expect(detail != null and detail.visible, "建筑详情抽屉打开")
		_expect(not workspace.visible, "详情打开时经营面板强制关闭")
		_expect(not bool(ui.get("_governance_open")), "强制关闭时 _governance_open=false")
		_expect(str(toggle.text) == "城市经营", "强制关闭后按钮立即恢复「城市经营」")
		selection.call("clear_selection")
		ui.call("_refresh_read_model")
		await process_frame
		_expect(not workspace.visible, "关闭详情后面板保持关闭（不自动重开）")
		_expect(str(toggle.text) == "城市经营", "关闭详情后按钮仍为「城市经营」")

	# ---- 验收 4：建设目录/放置状态同样强制关闭并同步 ----
	ui.call("_toggle_governance_workspace")
	await process_frame
	_expect(workspace.visible, "重新打开经营面板（供目录状态测试）")
	city.call("open_construction_menu")
	await process_frame
	var menu: Panel = ui.get("construction_menu")
	_expect(menu != null and menu.visible, "建设目录打开")
	_expect(not workspace.visible, "目录打开时经营面板强制关闭")
	_expect(str(toggle.text) == "城市经营", "目录打开后按钮恢复「城市经营」")
	city.call("cancel_build_interaction")
	await process_frame

	# ---- 验收 7/8/9：推荐聚焦与不静默开工 ----
	var nation: Object = city.get_nation_state()
	var wood_before := int(nation.get_resource(&"wood"))
	var food_before := int(nation.get_resource(&"food"))
	ui.call("_start_governance_definition", &"building.logging_camp.t1")
	await process_frame
	await process_frame
	_expect(menu.visible, "伐木场推荐打开建设目录")
	var logging_button: Button = ui.get("catalog_logging_button")
	_expect(
		logging_button != null and logging_button.modulate != Color.WHITE,
		"伐木场推荐强调 LoggingCampButton",
	)
	var hint_label: Label = ui.get("governance_hint_label")
	_expect(
		hint_label != null and str(hint_label.text).contains("推荐伐木场用于补充木材"),
		"伐木场推荐显示对应提示",
	)
	_expect(int(nation.get_resource(&"wood")) == wood_before, "伐木场推荐未扣木材")
	_expect(not city.call("has_build_project"), "伐木场推荐未开始工程")
	ui.call("_start_governance_definition", &"building.farm.t1")
	await process_frame
	await process_frame
	var farm_button: Button = ui.get("catalog_farm_button")
	_expect(
		farm_button != null and farm_button.modulate != Color.WHITE,
		"农田推荐强调 FarmButton",
	)
	_expect(
		hint_label != null and str(hint_label.text).contains("推荐农田用于稳定粮食"),
		"农田推荐显示对应提示",
	)
	_expect(int(nation.get_resource(&"food")) == food_before, "农田推荐未扣粮食")
	_expect(not city.call("has_build_project"), "农田推荐未开始工程")
	# 关闭目录清除聚焦
	city.call("cancel_build_interaction")
	await process_frame
	_expect(root.gui_get_focus_owner() == null or root.gui_get_focus_owner().name != &"LoggingCampButton", "关闭目录后高亮清除")

	# ---- 验收 5：战时内城不显示城市经营开关 ----
	var depart_receipt: Dictionary = runtime.command(&"depart", {"formation_ids": _formations_chosen(), "food": 30, "wood": 55})
	_expect(bool(depart_receipt.get("success", false)), "正式出征（进入 ACTIVE）")
	if not bool(depart_receipt.get("success", false)):
		_finish()
		return
	var deadline_ms := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline_ms and int(runtime._base_members()) < 2:
		runtime.advance(1.0)
	runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"})
	_expect(city.call("show_regular_campaign_city"), "进入战时内城")
	await process_frame
	await process_frame
	_expect(city.call("is_regular_campaign_city_active"), "战时内城激活")
	_expect(not toggle.visible, "战时内城不显示城市经营开关")
	_expect(not workspace.visible, "战时内城不显示经营面板")
	_expect(not bool(ui.get("_governance_open")), "内城不残留 _governance_open")

	# ---- 验收 6：返回永久主城默认关闭、文案正确 ----
	city.call("deactivate_regular_campaign_city")
	await process_frame
	await process_frame
	_expect(not city.call("is_regular_campaign_city_active"), "返回永久主城")
	_expect(toggle.visible, "返回后城市经营开关恢复显示")
	_expect(str(toggle.text) == "城市经营", "返回后按钮文案为「城市经营」（无残留展开态）")
	_expect(not workspace.visible, "返回后经营面板默认关闭")
	_expect(not bool(ui.get("_governance_open")), "返回后无 _governance_open 残留")
	_finish()


func _formations_chosen() -> Array:
	var chosen: Array = []
	var home_model: Dictionary = _dict(runtime.get_read_model().get("home", {}))
	var formations: Array = []
	for fv in home_model.get("formations", []):
		formations.append(fv)
	for formation_value in formations:
		var formation: Dictionary = formation_value
		if int(formation.get("member_count", formation.get("count", 0))) > 0:
			chosen.append(StringName(formation.get("formation_id", formation.get("id", ""))))
	return chosen


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _finish() -> void:
	if failures.is_empty():
		print("R2A1 PASS all")
		quit(0)
	else:
		print("R2A1 FAIL failures=", failures)
		quit(1)
