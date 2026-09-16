extends SceneTree

## R1C 收尾第二组短测：出征草稿状态（程序驱动领域短测，另行计数）。
## 验证：默认预选 → 玩家取消一队 → 取消全部 → 两个刷新周期不被回填 →
## 确认禁用且给出原因 → 重新选两队保持 → 逐 ID/人数与编队对应。
## 两尺寸各跑一遍（--size=1280x720 / 1152x648）。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var city: Node
var view: RegularCampaignView
var runtime: RegularCampaignRuntime
var target_width := 1280
var target_height := 720


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				target_width = int(parts[0])
				target_height = int(parts[1])
	root.size = Vector2i(target_width, target_height)
	await process_frame
	await process_frame
	# 尺寸读回记录（真实窗口大小，不以目录命名代替证据）
	print("R1C_DRAFT size_actual=", root.size, " expected=", Vector2i(target_width, target_height))
	_expect(int(root.size.x) == target_width and int(root.size.y) == target_height, "window size set and read back")

	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	print("STEP1 scene ready")
	# 领域短测：直接初始化常规战役（程序驱动，另行计数，不冒充正式入口链）
	_expect(city.initialize_regular_campaign(), "domain short-test initializes regular campaign")
	print("STEP2 initialized")
	runtime = city._regular_campaign
	print("STEP2b view pre-show=", city._regular_campaign_view)
	city.show_regular_campaign()
	await process_frame
	# PREPARATION 阶段战役视图由玩家经顶栏入口打开（程序点击，同真实控件链）
	var entry := _find_button_prefix(scene, "进入青原战区")
	print("STEP3 entry=", entry != null, " text=", entry.text if entry != null else "nil")
	if entry != null:
		await _click_control(entry)
	await create_timer(0.3).timeout
	view = city._regular_campaign_view
	print("STEP4 view=", view)
	view.refresh(true)
	await process_frame
	print("STEP5 refreshed selected=", view._selected_formation_ids)

	var pre_count: int = view._selected_formation_ids.size()
	_expect(pre_count == 3, "first-time default pre-checks all three formations")

	# ---- 取消一队：草稿更新且一个刷新周期保持 ----
	var check_first := _find_enabled_check_button(view)
	_expect(check_first != null, "checkbox reachable and enabled")
	if check_first != null:
		await _click_control(check_first)
	await process_frame
	view.refresh(true)
	await process_frame
	_expect(view._selected_formation_ids.size() == pre_count - 1, "unchecking one formation keeps draft after one refresh")

	# ---- 取消全部：每个已勾选复选框各点一次（避免重复点击同一复选框乒乓）----
	var checked_buttons: Array[CheckButton] = []
	for child in view.find_children("*", "CheckButton", true, false):
		if child is CheckButton and child.is_visible_in_tree() and child.button_pressed:
			checked_buttons.append(child)
	for check in checked_buttons:
		await _click_control(check)
		await process_frame
	await _hold_refresh_cycles(2)
	_expect(view._selected_formation_ids.is_empty(), "player-cleared selection stays empty after two refresh cycles (auto-refill does not override)")

	# ---- 确认禁用且给出真实原因 ----
	var depart_button := _find_button(view, "确认首批投入 · 进入战役")
	_expect(depart_button != null and depart_button.disabled, "confirm stays disabled with empty selection")
	_expect(_find_label_prefix(view, "本次投入") != null, "committed summary readout marks the empty selection")

	# ---- 重新选两队：两个刷新周期保持 ----
	var recheck_index := 0
	var reselected := 0
	for child in view.find_children("*", "CheckButton", true, false):
		if child is CheckButton and child.is_visible_in_tree() and not child.disabled:
			if reselected < 2:
				await _click_control(child)
				reselected += 1
	await process_frame
	await _hold_refresh_cycles(2)
	_expect(view._selected_formation_ids.size() == 2, "re-selected two formations survive two refresh cycles")

	# ---- 确认出征：逐 ID/人数与编队对应（重复/遗漏/多发检测）----
	depart_button = _find_button(view, "确认首批投入 · 进入战役")
	_expect(depart_button != null and not depart_button.disabled, "confirm unlocks after re-selecting two formations")
	if depart_button != null and not depart_button.disabled:
		await _click_control(depart_button)
	await process_frame
	_expect(runtime.data.phase == StringName(&"ACTIVE"), "departure confirms with the two-formation set")
	_expect(runtime.data.army_ids.size() == 2, "exactly two armies deploy for two formations")
	var deployed_formations: Array[StringName] = []
	for army_id in runtime.data.army_ids:
		var army: Dictionary = city._army_registry.get_army(army_id)
		var snapshots: Array = Array(Dictionary(army.get("macro_march", {})).get("formation_snapshots", []))
		_expect(snapshots.size() == 1, "each deployed army carries exactly one formation")
		for snapshot_value in snapshots:
			var snapshot: Dictionary = Dictionary(snapshot_value)
			var snapshot_id: StringName = StringName(snapshot.get("formation_id", &""))
			deployed_formations.append(snapshot_id)
			_expect(expected_member_counts().has(snapshot_id), "deployed formation %s was checked in the departure form" % snapshot_id)
			_expect(
				int(snapshot.get("member_count", -1)) == int(expected_member_counts().get(snapshot_id, -2)),
				"deployed member count matches the checked formation %s" % snapshot_id
			)
	var expected_ids: Array = expected_member_counts().keys()
	expected_ids.sort()
	var deployed_sorted: Array[StringName] = deployed_formations.duplicate()
	deployed_sorted.sort()
	_expect(
		deployed_sorted.size() == expected_ids.size() and Array(deployed_sorted) == Array(expected_ids),
		"deployed formation set equals the checked set (no duplicates, no omissions, no extras)"
	)

	print("R1C_DRAFT_%dx%d " % [target_width, target_height], "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func expected_member_counts() -> Dictionary:
	var counts: Dictionary = {}
	for formation_value in Array(_dict(_model_home()).get("formations", [])):
		var formation: Dictionary = Dictionary(formation_value)
		var fid: StringName = StringName(formation.get("id", formation.get("formation_id", "")))
		if fid in view._selected_formation_ids:
			counts[fid] = int(formation.get("member_count", formation.get("count", 0)))
	return counts


func _model_home() -> Dictionary:
	return Dictionary(runtime.get_read_model().get("home", {}))


func _dict(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}


func _hold_refresh_cycles(cycles: int) -> void:
	for index in cycles:
		await create_timer(1.0).timeout
		view.refresh(true)
		await process_frame


func _find_enabled_check_button(node: Node) -> CheckButton:
	for child in node.find_children("*", "CheckButton", true, false):
		if child is CheckButton and child.is_visible_in_tree() and not child.disabled:
			return child
	return null


func _find_button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child
	return null


func _find_button_prefix(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text.begins_with(prefix) and child.is_visible_in_tree():
			return child
	return null


func _find_label_prefix(node: Node, prefix: String) -> Label:
	for child in node.find_children("*", "Label", true, false):
		if child is Label and child.text.begins_with(prefix) and child.is_visible_in_tree():
			return child
	return null


func _click_control(control: Control) -> void:
	# 程序驱动点击（领域短测，另行计数；不冒充真人输入证明）
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)
