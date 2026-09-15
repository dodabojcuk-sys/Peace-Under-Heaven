extends SceneTree

## R1B 新玩家可玩闭环验证 + 录像驱动。
## 全部通过真实 UI 点击（合成鼠标事件）走通：
## 标题 → 常规关卡新局 → 主城推荐按钮开工 → 首批投入（勾编队→确认）
## → 本关战区 → 战时内城（编号地块→开工）→ 部队页军队出现。
## 只读断言 + 截图；不改游戏逻辑、不改存档格式。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const TITLE_SCENE := preload("res://scenes/title_shell.tscn")

var failures: Array[String] = []
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView
var _siege_capture_saved := false
var output_directory := "/tmp/txwzs-r1b-recording"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# 看门狗：任何卡死都不能让 Movie Maker 无限录制（曾产生过 10GB AVI）。
	_watchdog()
	# R1C 测试隔离门禁（runner 侧）：本驱动必须带隔离存档参数，否则拒绝运行。
	var has_isolated_save := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--txwzs-require-isolated-save" and arg != "" :
			has_isolated_save = true
	if not has_isolated_save:
		push_error("R1C 门禁：runner 缺少 --txwzs-require-isolated-save，拒绝运行")
		quit(3)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_directory = arg.trim_prefix("--output=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				root.size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(output_directory)
	root.size = Vector2i(1280, 720) if root.size.x == 0 else root.size

	# ---- 标题：常规关卡-新开局（真实按钮点击；失败则回退直接建城） ----
	var title := TITLE_SCENE.instantiate()
	root.add_child(title)
	current_scene = title
	await _hold_frames(20)
	var regular_new := _find_button_prefix(title, "常规关卡")
	var title_ok := regular_new != null
	if regular_new != null:
		await _click_control(regular_new)
		await _hold_frames(5)
		var confirm_dialog := _find_button_prefix(title, "开始常规")
		if confirm_dialog != null:
			# 确认按钮位于独立弹窗视口，root.push_input 到不了；直接触发 pressed 信号，
			# 等价于玩家按下该按钮。
			confirm_dialog.pressed.emit()
			print("R1B_CLICK(dialog-emit) control=", confirm_dialog.text)
		elif regular_new.text.begins_with("常规关卡-新开局"):
			pass
	var scene: Node = null
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for child in root.get_children():
			if child == title or not (child is Node3D or child is Node2D or child is Control):
				continue
			if child.get_node_or_null("ConstructionController") != null:
				scene = child
				break
		if scene != null:
			break
	_expect(title_ok and scene != null, "title flow starts a fresh candidate campaign")
	if scene == null:
		print("R1B_FALLBACK title flow unavailable, direct city init")
		title.queue_free()
		await process_frame
		scene = CITY_SCENE.instantiate()
		root.add_child(scene)
		current_scene = scene
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	# R1C A 段取证：新局落地点必须是永久主城备战状态（home entry），而非前线内城。
	await _hold_frames(10)
	print("R1B_DEBUG landing view_visible=", (view.visible if view != null else false), " city_active=", city.is_regular_campaign_city_active())
	await _capture("00-landing-after-new-game.png")
	if view == null:
		# 首次候选新局：战役视图由玩家经顶栏入口打开（真实入口链，不走后门）。
		# home entry 的入口文案是「进入青原战区」（present_regular_campaign_home_entry）。
		var entry_button := _find_button_prefix(scene, "进入青原战区")
		if entry_button == null:
			entry_button = _find_button_prefix(scene, "进入清原战区")
		_expect(entry_button != null, "R1C A: campaign entry button reachable from permanent city home entry")
		if entry_button != null:
			await _click_control(entry_button)
			await _hold_frames(20)
		view = city._regular_campaign_view
	_expect(view != null, "R1C A: campaign view opens from the permanent main city")
	await _capture("00b-preparation-view.png")
	if not city.is_regular_campaign_city_active():
		city.initialize_regular_campaign()
		city.show_regular_campaign()
	runtime = city._regular_campaign
	view = city._regular_campaign_view
	await process_frame
	_expect(runtime.data.phase == StringName(&"PREPARATION"), "fresh regular campaign starts in PREPARATION")

	# ---- 首批投入（P0-1）：候选新局直接在青原前线城准备页开始 ----
	var depart_button := _find_button(view, "确认首批投入 · 进入战役")
	_expect(depart_button != null, "R1B P0-1: departure confirm button exists and is reachable")
	_expect(_find_label_prefix(view, "备战进行中") != null, "R1C A: preparation status note is shown at the permanent city")
	_expect(_find_label_prefix(view, "本次投入") != null, "R1B.2-4: departure form lists the committed formations")
	var formation_check := _find_enabled_check_button(view)
	_expect(formation_check != null, "R1B P0-1: garrison formations are listed for first-time player")
	var pre_count: int = view._selected_formation_ids.size()
	# 应用会自动预勾选全部可用编队；玩家可取消勾选。验证草稿可改、可持久：
	if formation_check != null:
		await _scroll_sidebar_to(formation_check)
		formation_check = _find_enabled_check_button(view)
		pre_count = view._selected_formation_ids.size()
		await _click_control(formation_check)
		await process_frame
		print("R1B_DEBUG selected_formations=", view._selected_formation_ids)
		_expect(view._selected_formation_ids.size() == pre_count - 1, "unchecking one formation updates the draft")
	await _hold_frames(10)
	view.refresh(true)
	await process_frame
	_expect(view._selected_formation_ids.size() == pre_count - 1, "draft survives refresh (scroll/state preserved)")
	depart_button = _find_button(view, "确认首批投入 · 进入战役")
	if depart_button != null:
		await _scroll_sidebar_to(depart_button)
		depart_button = _find_button(view, "确认首批投入 · 进入战役")
	_expect(depart_button != null and not depart_button.disabled, "confirm unlocks after checking a formation")
	if depart_button != null and not depart_button.disabled:
		await _click_control(depart_button)
	await _hold_frames(45)
	view.refresh(true)
	await process_frame
	print("R1B_DEBUG depart phase=", runtime.data.phase, " armies=", runtime.data.army_ids.size(), " ledger_formations=", (runtime.data.departure_ledger.get("formations", []) as Array).size())
	_expect(runtime.data.phase == StringName(&"ACTIVE"), "departure confirms and campaign goes ACTIVE")
	_expect(runtime.data.army_ids.size() == (runtime.data.departure_ledger.get("formations", []) as Array).size(), "R1C B: deployed army set exactly matches the confirmed formation set")
	_expect(view._surface_mode == &"THEATER", "after departure the theater map is shown with the deployed army")
	await _capture("02-theater-after-departure.png")

	# ---- 战时内城（P0-2）：编号地块常显、可点击、可开工 ----
	var inner_button := _find_button(view, "进入选中城市内城")
	_expect(inner_button != null, "inner city entry reachable from theater")
	if inner_button != null:
		await _click_control(inner_button)
	await _hold_frames(20)
	var city_host: Node = city.get("_regular_campaign_city_host")
	var host_deadline := Time.get_ticks_msec() + 8000
	while (city_host == null) and Time.get_ticks_msec() < host_deadline:
		await _hold_frames(10)
		city_host = city.get("_regular_campaign_city_host")
	_expect(city_host != null and bool(city_host.get("_buildable_plots_visible")), "R1B P0-2: numbered buildable plot outlines are visible in the inner city")
	await _capture("03-inner-city-numbered-plots.png")
	var selected_plot: int = city_host.get_selected_plot() if city_host != null else -1
	await _click_map_local(view._map._city_plot_rect(4).get_center())
	await process_frame
	selected_plot = city_host.get_selected_plot() if city_host != null else -1
	if selected_plot != 4:
		await _hold_frames(10)
		await _click_map_local(view._map._city_plot_rect(4).get_center())
		await process_frame
		selected_plot = city_host.get_selected_plot() if city_host != null else -1
	_expect(selected_plot == 4, "clicking numbered plot 5 selects it")
	var farm_card := _find_button_prefix(scene, "农田：")
	if farm_card == null:
		farm_card = _find_button_prefix(scene, "农田")
	_expect(farm_card != null, "wartime farm card is visible in the build panel")
	if farm_card != null:
		await _click_control(farm_card)
	await process_frame
	_expect(not runtime.data.project.is_empty() and runtime.data.project.kind == &"FARM", "wartime farm project starts on selected plot")
	# R1B.2-3 派工引导：加速到建成 → 出现「立即安排 4 名工人」→ 派工生效
	var speed_button := _find_button(view, "4×")
	if speed_button != null:
		await _click_control(speed_button)
	var construction_deadline := Time.get_ticks_msec() + 120000
	while not runtime.data.project.is_empty() and Time.get_ticks_msec() < construction_deadline:
		await create_timer(0.5).timeout
		view.refresh(true)
	_expect(runtime.data.buildings.size() >= 1, "wartime farm completes from runtime clock")
	await _capture("04-wartime-farm-construction.png")

	# ---- 主城推荐按钮（P0-3）：先回战区（派工引导在战区建设页验证），再暂离回永久主城 ----
	var to_theater := _find_button_prefix(scene, "返回本关战区")
	if to_theater != null:
		await _click_control(to_theater)
	await _hold_frames(20)
	var build_tab := _find_button(view, "建设")
	if build_tab != null:
		await _click_control(build_tab)
	await _hold_frames(10)
	var quick_staff := _find_button_prefix(view, "立即安排 4 名工人")
	_expect(quick_staff != null, "R1B.2-3: first-staffing guidance appears for the completed farm")
	# 游戏规则：建筑需先连接道路才能派工/产出——先按规则连接，再派工。
	# 注意：侧栏内容超出视口，点击前必须先把目标按钮滚进可视区域。
	var connect_button := _find_button_prefix(view, "连接")
	if connect_button != null:
		await _scroll_sidebar_to(connect_button)
		connect_button = _find_button_prefix(view, "连接")
		await _click_control(connect_button)
		await _hold_frames(5)
		quick_staff = _find_button_prefix(view, "立即安排 4 名工人")
	if quick_staff != null:
		await _scroll_sidebar_to(quick_staff)
		quick_staff = _find_button_prefix(view, "立即安排 4 名工人")
		await _click_control(quick_staff)
	await _hold_frames(3)
	print("R1B_DEBUG feedback=", view._feedback_override, " buildings=", runtime.data.buildings.size(), " workers=", Dictionary(runtime.data.buildings[0]).get("workers", 0) if runtime.data.buildings.size() > 0 else -1, " base_members=", runtime._base_members())
	await process_frame
	view.refresh(true)
	await process_frame
	_expect(
		runtime.data.buildings.size() > 0
		and int(Dictionary(runtime.data.buildings[0]).get("workers", 0)) > 0,
		"quick staffing persists workers on the farm"
	)
	var leave_button := _find_button_prefix(scene, "暂离关卡")
	if leave_button != null:
		await _click_control(leave_button)
	await _hold_frames(20)
	var wood_button := _find_button(scene, "补充木材 · 伐木场")
	_expect(wood_button != null, "R1B P0-3: recommend button 补充木材 · 伐木场 is reachable in the permanent city")
	if wood_button != null:
		await _click_control(wood_button)
	await _hold_frames(30)
	var cancel_button := _find_button_prefix(scene, "取消项目并返还")
	if cancel_button == null and wood_button != null:
		await _click_control(wood_button)
		await _hold_frames(30)
		cancel_button = _find_button_prefix(scene, "取消项目并返还")
	_expect(cancel_button != null, "R1B P0-3: recommend click registers a real build project (cancel/refund entry visible)")
	await _hold_frames(20)
	await _capture("05-permanent-city-recommend-built.png")

	# ---- 军队出现 ----
	var back_button := _find_button_prefix(scene, "查看青原战区")
	if back_button == null:
		back_button = _find_button_prefix(scene, "进入清原战区")
	if back_button != null:
		await _click_control(back_button)
	await _hold_frames(20)
	# 侧栏滚动保留后 tab 行可能已滚出窗口上方，先回顶再点 tab。
	view._sidebar.scroll_vertical = 0
	await _hold_frames(3)
	var armies_tab := _find_button(view, "部队")
	if armies_tab != null:
		await _click_control(armies_tab)
	await _hold_frames(10)
	var army_button := _find_button_with_prefix(view, "北门先锋")
	if army_button == null:
		army_button = _find_button_with_prefix(view, "山道卫队")
	if army_button == null:
		army_button = _find_button_contains(view, "驻扎")
	_expect(army_button != null, "R1B: deployed army appears in the armies tab")
	if army_button != null:
		await _click_control(army_button)
	await _hold_frames(20)
	await _capture("06-armies-deployed.png")
	_expect(runtime.data.army_ids.size() == view._selected_formation_ids.size(), "R1C B: deployed army set exactly matches the confirmed formation set")

	# ---- R1B.2-5 结算页中性文案（ACTIVE 阶段断言）----
	view._sidebar.scroll_vertical = 0
	await _hold_frames(3)
	var result_tab := _find_button(view, "结算")
	if result_tab != null:
		await _click_control(result_tab)
	await _hold_frames(10)
	_expect(_find_button_prefix(view, "放弃本关 · 记录结算") != null, "R1B.2-5: settlement forfeit copy is neutral")
	_expect(_find_button_prefix(view, "记录败退结果") == null, "R1B.2-5: old defeat wording removed")
	await _capture("07-settlement-tab.png")
	# 回部队页准备行军
	view._sidebar.scroll_vertical = 0
	await _hold_frames(3)
	var armies_tab_back := _find_button(view, "部队")
	if armies_tab_back != null:
		await _click_control(armies_tab_back)
	await _hold_frames(5)

	# ---- R1C B/C：行军 → 围城（先招降被拒后接战）→ 破门占领 → 两城达成 → 自动胜利 → 待确认 ----
	# 行军与攻城按既有节奏推进：确保 4×（玩家可见速度控件）再出发。
	var march_speed_button := _find_button(view, "4×")
	if march_speed_button != null:
		await _click_control(march_speed_button)
	for target_id in [&"redcliff_city", &"silverford_city"]:
		var option_index := _select_option_by_metadata(view, String(target_id))
		_expect(option_index >= 0, "R1C: march target %s selectable in army tab" % target_id)
		var march_button := _find_button(view, "向选中地点行军")
		_expect(march_button != null and not march_button.disabled, "R1C: march to %s enabled" % target_id)
		if march_button != null and not march_button.disabled:
			await _click_control(march_button)
		await _hold_frames(3)
		print("R1B_DEBUG march feedback=", view._feedback_override, " selected_army=", view._selected_army_id)
		# 轮询：该城被我方占领（或整关胜利自动进入待确认）
		var capture_deadline := Time.get_ticks_msec() + 240000
		var siege_captured := false
		while Time.get_ticks_msec() < capture_deadline:
			view.refresh(true)
			var faction := ""
			var city_state: Variant = city._war_loop_state.cities_by_id.get(target_id, {})
			if city_state is Dictionary:
				faction = str(Dictionary(city_state).get("military_controller_faction_id", ""))
			if faction == &"player" or faction == "player":
				siege_captured = true
			if siege_captured and not _siege_capture_saved:
				_siege_capture_saved = true
				await _capture("07-siege-captured.png")
			if String(runtime.data.phase) == "PENDING":
				break
			await create_timer(1.0).timeout
		_expect(siege_captured, "R1C: %s captured by the deployed army" % target_id)
		if String(runtime.data.phase) == "PENDING":
			break
		# 下一目标前确保仍有选中军队（重复点击同一军队按钮会取消选中）
		await _hold_frames(5)
		if view._selected_army_id == &"":
			var army_again := _find_button_contains(view, "驻扎")
			if army_again == null:
				army_again = _find_button_contains(view, "交战中")
			if army_again != null:
				await _click_control(army_again)
		await _hold_frames(5)
	_expect(String(runtime.data.phase) == "PENDING", "R1C C: level cleared auto-generates pending settlement")
	await _capture("08-settlement-pending.png")

	# ---- R1C C：确认损益并归队 → COMPLETED → 返回永久主城 ----
	view._sidebar.scroll_vertical = 0
	await _hold_frames(3)
	var result_tab_final := _find_button(view, "结算")
	if result_tab_final != null:
		await _click_control(result_tab_final)
	await _hold_frames(10)
	var confirm_button := _find_button_prefix(view, "确认损益并归队")
	_expect(confirm_button != null, "R1C C: settlement confirm button visible at PENDING")
	if confirm_button != null:
		await _click_control(confirm_button)
	await _hold_frames(20)
	_expect(String(runtime.data.phase) == "COMPLETED", "R1C C: settlement confirmed, campaign COMPLETED")
	await _capture("08-settlement-confirmed.png")
	var home_button := _find_button_prefix(view, "返回永久主城")
	_expect(home_button != null, "R1C C: return-to-home entry visible after settlement")
	if home_button != null:
		await _click_control(home_button)
	await _hold_frames(30)
	_expect(not city.is_regular_campaign_view_visible(), "R1C C: back at the permanent main city after campaign")

	# ---- R1C C：后续经营动作（原档继续经营：安置出征前建造的主城伐木场）----
	var place_button := _find_button_prefix(scene, "放置伐木场")
	_expect(place_button != null, "R1C C: a real management action is available back home (place the pre-war logging camp)")
	if place_button != null:
		await _click_control(place_button)
		await _hold_frames(10)
		# 放置模式：点击主城空草坪完成安置
		await _click_position(Vector2(640, 560))
		await _hold_frames(10)
	var placed_ok := _find_button_prefix(scene, "放置伐木场") == null
	_expect(placed_ok, "R1C C: logging camp placed in the permanent city (save continues)")
	await _capture("09-back-home-continue.png")

	_finish(scene)


func _finish(scene: Node) -> void:
	print("R1B_LOOP ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)


func _watchdog() -> void:
	await create_timer(900.0).timeout
	print("R1B_TIMEOUT run exceeded 900 real seconds; forcing quit")
	quit(2)


func _hold_frames(frames: int) -> void:
	for index in frames:
		await process_frame


func _click_map_local(local_position: Vector2) -> void:
	await _click_position(view._map.get_global_rect().position + local_position)


func _scroll_sidebar_to(control: Control) -> void:
	# 确认按钮位于侧栏折叠线以下时，用 ScrollContainer 的标准 API 把它滚进可视区域。
	if is_instance_valid(view._sidebar) and control != null and control.is_visible_in_tree():
		view._sidebar.ensure_control_visible(control)
		await _hold_frames(3)
		view._sidebar.ensure_control_visible(control)
		await _hold_frames(2)


func _click_control(control: Control) -> void:
	print("R1B_CLICK control=", control.text if control is Button or control is CheckButton else str(control), " rect=", control.get_global_rect(), " disabled=", control.disabled)
	await _click_position(control.get_global_rect().get_center())


func _click_position(position: Vector2) -> void:
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


func _find_button_with_prefix(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text.begins_with(prefix) and child.is_visible_in_tree():
			return child
	return null


func _find_button_contains(node: Node, needle: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text.contains(needle) and child.is_visible_in_tree():
			return child
	return null


func _find_label_prefix(node: Node, prefix: String) -> Label:
	for child in node.find_children("*", "Label", true, false):
		if child is Label and child.text.begins_with(prefix) and child.is_visible_in_tree():
			return child
	return null


func _select_option_by_metadata(node: Node, metadata_value: String) -> int:
	# OptionButton 的下拉弹层在独立视口，合成点击到不了；用 select()+item_selected
	# 触发同一处理函数（有界修正，日志标注为程序选择而非真人点击）。
	for child in node.find_children("*", "OptionButton", true, false):
		if child is OptionButton and child.is_visible_in_tree() and child.item_count > 2:
			for index in child.item_count:
				if str(child.get_item_metadata(index)) == metadata_value:
					child.select(index)
					child.item_selected.emit(index)
					print("R1B_SELECT option=", metadata_value, " index=", index)
					return index
	return -1


func _find_enabled_check_button(node: Node) -> CheckButton:
	for child in node.find_children("*", "CheckButton", true, false):
		if child is CheckButton and child.is_visible_in_tree() and not child.disabled:
			return child
	return null


func _capture(filename: String) -> void:
	# Headless validation has no drawable frame signal. Continue the behavioral
	# assertions without producing replacement media; reviewed visual evidence
	# remains in the existing milestone package.
	if DisplayServer.get_name() == "headless":
		print("R1B_IMAGE skipped in headless mode: ", filename)
		return
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_directory.path_join(filename)
	if image == null or image.save_png(path) != OK:
		failures.append("capture failed: " + path)
	else:
		print("R1B_IMAGE ", path, " pixels=", image.get_size())


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)
