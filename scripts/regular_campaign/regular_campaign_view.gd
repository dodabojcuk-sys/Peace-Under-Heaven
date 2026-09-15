class_name RegularCampaignView
extends Control

## Projection and input surface for the R1 regular campaign.  The runtime is
## deliberately the only source of campaign facts: this view keeps only local
## selection/focus so that repainting cannot advance time, spend resources, or
## manufacture a second campaign state.

signal campaign_closed

const SURFACE := Color("09151d")
const SURFACE_RAISED := Color("102631")
const SURFACE_SOFT := Color("153542")
const BORDER := Color("3d7180")
const TEXT := Color("e9f0e8")
const MUTED := Color("9eb6b5")
const ACCENT := Color("79d7c7")
const GOLD := Color("e8bd63")
const WARNING := Color("edb765")
const DANGER := Color("db8678")
const MAP_WORLD := Rect2(0.0, 0.0, 1500.0, 980.0)
const PRESENTATION_BRIDGE = preload("res://scripts/regular_campaign/regular_campaign_presentation_bridge.gd")

var _runtime: RefCounted
var _city: Node
var _model: Dictionary = {}
var _active_tab := &"OVERVIEW"
var _surface_mode := &"CITY"
var _inner_city_point_id := &""
var _selected_army_id := &""
var _selected_point_id := &"blackstone_city"
var _selected_building_id := &""
var _selected_plot := -1
var _pressure_details_expanded := false
var _selected_formation_ids: Array[StringName] = []
var _feedback_override := ""
var _sidebar_scroll_reset_pending := false
var _departure_food_draft := 30
var _departure_wood_draft := 55
var _departure_food_spin: SpinBox
var _departure_wood_spin: SpinBox
var _last_refresh_msec := 0
var _last_runtime_feedback := ""
var _ui_ready := false

var _top_bar: PanelContainer
var _title_label: Label
var _phase_label: Label
var _resource_label: Label
var _time_label: Label
var _speed_label: Label
var _message_label: Label
var _map_frame: PanelContainer
var _map: CampaignMapSurface
var _map_caption: Label
var _sidebar: ScrollContainer
var _sidebar_content: VBoxContainer
var _tab_row: HBoxContainer
var _city_surface_button: Button
var _theater_surface_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_ui_ready = true
	refresh()


## The controller calls this once after inserting the full-screen CanvasLayer.
## It is intentionally narrow: commands return their own `{ success, error }`
## receipt and all displayed values come back through `get_read_model()`.
func configure(runtime: RefCounted, city: Node) -> void:
	_runtime = runtime
	_city = city
	if is_node_ready():
		refresh()


func show_campaign() -> void:
	visible = true
	refresh()


func refresh(force_sidebar := false) -> void:
	if not _ui_ready or _runtime == null:
		return
	if not _runtime.has_method("get_read_model"):
		_feedback_override = "战役数据暂不可用。"
		_update_chrome()
		return
	var next_model: Variant = _runtime.call("get_read_model")
	_model = next_model.duplicate(true) if next_model is Dictionary else {}
	var runtime_feedback := str(_model.get("feedback", ""))
	if not runtime_feedback.is_empty() and runtime_feedback != _last_runtime_feedback:
		# A new authoritative outcome (for example surrender or combat closure)
		# supersedes an older local click receipt without becoming view-owned state.
		_feedback_override = ""
	_last_runtime_feedback = runtime_feedback
	_apply_persisted_view_context()
	_ensure_selection_is_valid()
	_update_chrome()
	# Keep a partially edited departure amount intact.  The simulation can refresh
	# while the player types, but it must not replace the focused SpinBox.
	if force_sidebar or not _is_editing_departure_supply():
		_rebuild_sidebar()
	_last_refresh_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	# Simulation is not driven here.  Periodic redraw is only a read model pull;
	# keeping it below 1 Hz also avoids disrupting focused spin boxes.
	if visible and _runtime != null and Time.get_ticks_msec() - _last_refresh_msec > 900:
		refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _ui_ready:
		_layout()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = SURFACE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_top_bar = PanelContainer.new()
	_top_bar.add_theme_stylebox_override("panel", _panel_style(SURFACE_RAISED, BORDER, 10))
	add_child(_top_bar)
	var top_margin := _margin(14, 8, 14, 8)
	top_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(top_margin)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_margin.add_child(top)
	var headline := HBoxContainer.new()
	headline.add_theme_constant_override("separation", 12)
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(headline)
	_title_label = _label("常规战役 · 前线指挥", 21, TEXT)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_child(_title_label)
	_phase_label = _label("准备中", 14, ACCENT)
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_phase_label.custom_minimum_size.x = 250
	headline.add_child(_phase_label)
	_resource_label = _label("", 15, TEXT)
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resource_label.custom_minimum_size.x = 365
	headline.add_child(_resource_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(controls)
	_time_label = _label("", 15, MUTED)
	_time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_time_label)
	_speed_label = _label("", 14, MUTED)
	_speed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speed_label.custom_minimum_size.x = 72
	controls.add_child(_speed_label)
	for value in [1.0, 2.0, 4.0]:
		var speed := _button("%d×" % int(value), func(): _set_speed(value), false)
		speed.custom_minimum_size = Vector2(48, 32)
		controls.add_child(speed)
	var pause := _button("暂停", _toggle_pause, false)
	pause.custom_minimum_size = Vector2(62, 32)
	controls.add_child(pause)
	var leave := _button("暂离关卡 · 返回永久主城", _hide_campaign, false)
	leave.custom_minimum_size = Vector2(96, 32)
	controls.add_child(leave)

	_map_frame = PanelContainer.new()
	_map_frame.clip_contents = true
	_map_frame.add_theme_stylebox_override("panel", _panel_style(SURFACE, BORDER, 10))
	add_child(_map_frame)
	var map_margin := _margin(10, 10, 10, 10)
	_map_frame.add_child(map_margin)
	var map_stack := VBoxContainer.new()
	map_stack.add_theme_constant_override("separation", 5)
	map_margin.add_child(map_stack)
	var surface_row := HBoxContainer.new()
	surface_row.add_theme_constant_override("separation", 6)
	_city_surface_button = _button("进入选中城市内城", _enter_selected_city, true)
	_theater_surface_button = _button("返回本关战区", _return_to_theater, false)
	surface_row.add_child(_city_surface_button)
	surface_row.add_child(_theater_surface_button)
	var surface_hint := _label("城内操作真实设施；总览用于调兵", 13, MUTED)
	surface_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	surface_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_row.add_child(surface_hint)
	map_stack.add_child(surface_row)
	_map = CampaignMapSurface.new()
	_map.custom_minimum_size = Vector2(400, 300)
	_map.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_map.world_clicked.connect(_on_world_clicked)
	_map.army_clicked.connect(_on_army_clicked)
	_map.plot_clicked.connect(_on_plot_clicked)
	_map.building_clicked.connect(_on_building_clicked)
	map_stack.add_child(_map)
	_map_caption = _label("", 14, MUTED)
	_map_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_caption.custom_minimum_size.y = 36
	_map_caption.max_lines_visible = 2
	_map_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_map_caption.clip_text = true
	map_stack.add_child(_map_caption)

	_sidebar = ScrollContainer.new()
	_sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar.add_theme_stylebox_override("panel", _panel_style(SURFACE_RAISED, BORDER, 10))
	add_child(_sidebar)
	var side_margin := _margin(14, 12, 14, 14)
	side_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(side_margin)
	_sidebar_content = VBoxContainer.new()
	_sidebar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_content.custom_minimum_size.x = 1
	_sidebar_content.add_theme_constant_override("separation", 9)
	side_margin.add_child(_sidebar_content)
	_layout()


func _layout() -> void:
	var viewport := size
	var edge := clampf(viewport.x * 0.014, 12.0, 26.0)
	var top_height := clampf(viewport.y * 0.105, 82.0, 94.0)
	var side_width := clampf(viewport.x * 0.30, 330.0, 410.0)
	_top_bar.position = Vector2(edge, edge)
	_top_bar.size = Vector2(maxf(300.0, viewport.x - edge * 2.0), top_height)
	_map_frame.position = Vector2(edge, edge + top_height + 10.0)
	var map_frame_height := maxf(250.0, viewport.y - top_height - edge * 2.0 - 10.0)
	_map.custom_minimum_size.y = maxf(300.0, map_frame_height - 92.0)
	_map_frame.size = Vector2(
		maxf(310.0, viewport.x - side_width - edge * 3.0),
		map_frame_height
	)
	_sidebar.position = Vector2(viewport.x - side_width - edge, edge + top_height + 10.0)
	_sidebar.size = Vector2(side_width, maxf(250.0, viewport.y - top_height - edge * 2.0 - 10.0))


func _update_chrome() -> void:
	var phase := String(_model.get("phase", "PREPARATION"))
	var local_model := _dict(_model.get("local", {}))
	var pressure := _dict(_model.get("pressure", {}))
	var location := str(_point(_inner_city_point_id).get("display_name", _inner_city_point_id)) if _surface_mode == &"CITY" else "本关战区"
	_city_surface_button.visible = _surface_mode != &"CITY"
	_theater_surface_button.visible = _surface_mode == &"CITY"
	_title_label.text = "%s / %s%s" % [str(_model.get("title", "常规关卡")), location, " · 战时内城" if _surface_mode == &"CITY" else ""]
	_phase_label.text = "目标：%s" % str(_dict(_model.get("summary", {})).get("objective", "清除前线威胁并确认归队"))
	var risk := _risk_name(str(_dict(local_model.get("forecast", {})).get("risk_id", "STABLE")))
	_resource_label.text = "前线  粮食 %d · 木材 %d  |  %s" % [
		int(local_model.get("food", 0)), int(local_model.get("wood", 0)), risk,
	]
	_time_label.text = "主线 %s · 本次 %s · 压力 %s" % [
		_time_text(int(_model.get("mainline_elapsed_ms", 0))),
		_time_text(int(_model.get("attempt_elapsed_ms", 0))),
		_pressure_name(pressure),
	]
	var paused := false
	var speed := 1.0
	if _city != null:
		paused = bool(_city.call("is_city_time_paused")) if _city.has_method("is_city_time_paused") else bool(_city.get("city_time_paused"))
		speed = float(_city.call("get_city_time_speed")) if _city.has_method("get_city_time_speed") else float(_city.get("city_time_speed"))
	var speed_text := "%.1f" % speed
	_speed_label.text = "暂停 / 当前×%s" % speed_text if paused else "当前×%s" % speed_text
	var message := _feedback_override
	if message.is_empty():
		message = str(_model.get("feedback", ""))
	if message.is_empty():
		message = "点击地块或建筑操作真实内城设施。" if _surface_mode == &"CITY" else "选择一支军队，再点击地点下达调动。"
	_map_caption.text = message
	_map.set_model(_model, _selected_army_id, _selected_point_id, _selected_building_id, _selected_plot, _surface_mode)


func _rebuild_sidebar() -> void:
	# 侧栏会随 900ms 周期刷新整体重建；不保留滚动位置的话，确认按钮这类
	# 折叠线以下的内容会被不断弹回顶部（R1B 首批投入不可达的根因之一）。
	var preserved_scroll := _sidebar.scroll_vertical
	for child in _sidebar_content.get_children():
		child.queue_free()
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 5)
	_sidebar_content.add_child(_tab_row)
	for item in [[&"OVERVIEW", "概览"], [&"BUILD", "建设"], [&"ARMIES", "部队"], [&"RESULT", "结算"]]:
		var tab_id: StringName = item[0]
		var tab := _button(str(item[1]), func(): _set_tab(tab_id), tab_id == _active_tab)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 38
		_tab_row.add_child(tab)
	match _active_tab:
		&"BUILD":
			_build_build_tab()
		&"ARMIES":
			_build_armies_tab()
		&"RESULT":
			_build_result_tab()
		_:
			_build_overview_tab()
	_restore_sidebar_scroll.call_deferred(preserved_scroll)


func _restore_sidebar_scroll(scroll: int) -> void:
	# queue_free 的旧内容要等帧末才移除；等一帧让布局稳定后再恢复滚动位置。
	await get_tree().process_frame
	if not is_instance_valid(_sidebar):
		return
	if _sidebar_scroll_reset_pending:
		_sidebar_scroll_reset_pending = false
		return
	_sidebar.scroll_vertical = scroll


func _build_overview_tab() -> void:
	var phase := String(_model.get("phase", "PREPARATION"))
	_add_heading("战役态势")
	if phase == "PREPARATION":
		# R1B.2：开局身份说明在整个备战阶段常显（备战结束自动消失）。
		_add_readout(
			"开局说明",
			"你已就任青原前线城指挥官：先在下方「首批投入」勾选编队并确认，即可进入本关战区。"
			+ "永久主城在后方，可用「暂离关卡 · 返回永久主城」随时往返经营。",
			ACCENT
		)
	var forecast := (
		_dict(_dict(_model.get("home", {})).get("food_forecast", {}))
		if phase == "PREPARATION"
		else _dict(_dict(_model.get("local", {})).get("forecast", {}))
	)
	_add_readout("供给预报", _forecast_text(forecast), _forecast_color(forecast))
	var pressure := _dict(_model.get("pressure", {}))
	var pressure_button := _button(
		("收起推进压力详情" if _pressure_details_expanded else "展开推进压力详情 · %s" % _pressure_name(pressure)),
		_toggle_pressure_details,
		false
	)
	_sidebar_content.add_child(pressure_button)
	if _pressure_details_expanded:
		_add_readout("推进压力", _pressure_text(pressure), WARNING if not pressure.is_empty() else MUTED)
	if phase != "PREPARATION":
		_add_readout("敌军整备", "第 10 分钟起，每 6 分钟各未占领敌城增加 1 名后备守军；每三轮提高攻击。已整备 %d 轮。攻占来源后停止当地整备，已受损城门不会修复。" % int(_model.get("enemy_growth_events", 0)), MUTED)
	_add_readout("当前地点", _point_text(_selected_point_id), TEXT)
	if phase == "PREPARATION":
		_build_departure_form()
	elif phase == "PENDING":
		_add_readout("待确认", "本次损益已冻结；确认前不会写回永久主城。请在“结算”页核对。", WARNING)
	elif phase == "COMPLETED":
		_add_readout("战役完成", "本次战役已经完成。返回永久主城继续经营，伤员可以继续接受治疗。", ACCENT)
	else:
		_add_heading("常用行动")
		var scout := _button("侦察选中地点", func(): _command(&"scout", {"point_id": _selected_point_id}), false)
		scout.disabled = _selected_point_id.is_empty()
		_sidebar_content.add_child(scout)
		_sidebar_content.add_child(_button("治疗伤员", func(): _command(&"treat"), false))
		var train := _button("训练选中军队", func(): _command(&"train", {"army_id": _selected_army_id}), false)
		train.disabled = _selected_army_id.is_empty()
		_sidebar_content.add_child(train)
		var supply := _button("领取溪渡有限粮食", func(): _command(&"supply", {"army_id": _selected_army_id}), false)
		supply.disabled = _selected_army_id.is_empty()
		_sidebar_content.add_child(supply)
		var withdraw := _button("申请撤军结算", func(): _command(&"outcome", {"kind": &"WITHDRAW"}), false)
		withdraw.add_theme_color_override("font_color", WARNING)
		_sidebar_content.add_child(withdraw)
	_add_feedback_block()


func _build_departure_form() -> void:
	_add_heading("首批投入")
	_add_readout("规则", "只可从真实主城资产投入一次。进入战役后可在关内改令，但不能再次从主城追加兵粮。", MUTED)
	var home := _dict(_model.get("home", {}))
	var formations := _array(home.get("formations", []))
	if formations.is_empty():
		_add_readout("可用编队", "主城还没有可投入的编队。回到永久主城，用左上军事区的「征募」补充士兵后，编队会自动出现在这里。", WARNING)
	else:
		for formation_value in formations:
			var formation := _dict(formation_value)
			var formation_id := StringName(formation.get("id", formation.get("formation_id", "")))
			var count := int(formation.get("member_count", formation.get("count", 0)))
			var check := CheckButton.new()
			check.text = "%s · %d 人" % [str(formation.get("display_name", formation_id)), count]
			check.button_pressed = formation_id in _selected_formation_ids
			check.disabled = count <= 0
			check.add_theme_font_size_override("font_size", 16)
			check.toggled.connect(func(on: bool): _toggle_formation(formation_id, on))
			_sidebar_content.add_child(check)
	# R1B.2：一支军队 = 一个被勾选的编队（create_regular_force 每编队一支，军队名沿用编队名）。
	# 这里把"玩家勾了什么"白纸黑字列出来，避免勾选与出征结果对不上号的困惑。
	var committed_summaries: Array[String] = []
	for formation_value in formations:
		var formation := _dict(formation_value)
		var summary_id := StringName(formation.get("id", formation.get("formation_id", "")))
		var summary_count := int(formation.get("member_count", formation.get("count", 0)))
		if summary_id in _selected_formation_ids and summary_count > 0:
			committed_summaries.append("%s %d 人" % [str(formation.get("display_name", summary_id)), summary_count])
	_add_readout(
		"本次投入",
		"、".join(committed_summaries) if not committed_summaries.is_empty() else "尚未选择编队；勾选上方编队后，这里会显示出征名单。",
		ACCENT if not committed_summaries.is_empty() else MUTED
	)
	var food := _spin("携带粮食", 0, maxi(int(home.get("food", 0)), 300), _departure_food_draft)
	var wood := _spin("携带木材", 0, maxi(int(home.get("wood", 0)), 300), _departure_wood_draft)
	_departure_food_spin = food.get("spin") as SpinBox
	_departure_wood_spin = wood.get("spin") as SpinBox
	_departure_food_spin.value_changed.connect(func(value: float): _departure_food_draft = roundi(value))
	_departure_wood_spin.value_changed.connect(func(value: float): _departure_wood_draft = roundi(value))
	_sidebar_content.add_child(food.get("row"))
	_sidebar_content.add_child(wood.get("row"))
	var depart := _button("确认首批投入 · 进入战役", func(): _command(&"depart", {
		"formation_ids": _selected_formation_ids.duplicate(),
		"food": int((food.get("spin") as SpinBox).value),
		"wood": int((wood.get("spin") as SpinBox).value),
	}), true)
	depart.disabled = _selected_formation_ids.is_empty()
	_sidebar_content.add_child(depart)
	if _selected_formation_ids.is_empty():
		_add_readout(
			"下一步",
			"勾选上方至少一个编队，「确认首批投入 · 进入战役」才会解锁；兵粮会从主城一次性带入本关。",
			WARNING
		)


func _build_build_tab() -> void:
	_add_heading("战时内城建设")
	if _surface_mode != &"CITY":
		_sidebar_content.add_child(_button("进入选中城市内城", _enter_selected_city, true))
	var point := _point(_selected_point_id)
	if point.is_empty():
		_add_readout("选择地点", "在地图上选择地点以查看建设权限。", WARNING)
		return
	_add_readout(str(point.get("display_name", _selected_point_id)), _point_build_message(point), ACCENT if bool(point.get("allows_build", false)) else MUTED)
	var local_model := _dict(_model.get("local", {}))
	var project := _dict(local_model.get("project", {}))
	if not project.is_empty():
		_add_readout("正在施工 · 建设区 %d" % (int(project.get("plot", -1)) + 1), "%s · 进度 %d%%" % [_building_name(StringName(project.get("kind", ""))), roundi(float(_project_progress_permille(project)) / 10.0)], GOLD)
		_sidebar_content.add_child(_button("取消当前施工", func(): _command(&"cancel_build"), false))
	if bool(point.get("allows_build", false)):
		if project.is_empty() and _array(local_model.get("buildings", [])).is_empty():
			_add_readout(
				"第一次建设？",
				"城内带数字的虚线框（1–6）就是可建设空地：直接点击虚线框选中地块，再选下方设施并「开工」。",
				ACCENT
			)
		var occupied := _building_for_plot(_selected_plot)
		if not occupied.is_empty():
			_selected_building_id = StringName(occupied.get("id", ""))
			_add_selected_building_card(occupied)
		elif _selected_plot >= 0:
			_add_readout("已选建设空间", "地块 %d · 当前为空。选择设施后由正式战役命令开工。" % (_selected_plot + 1), ACCENT)
		else:
			_add_readout("选择建设空间", "请直接点击城内有编号的空地。六个地块是本关候选数据，不代表最终城建容量规则。", WARNING)
		var kind := OptionButton.new()
		kind.add_theme_font_size_override("font_size", 16)
		for item in [["FARM", "农田 · 提高本地有效粮食"], ["LOGGING", "伐木场 · 提供建设材料"], ["WAREHOUSE", "仓储 · 提高本地容量"], ["CLINIC", "医疗点 · 恢复伤员"]]:
			kind.add_item(str(item[1]))
			kind.set_item_metadata(kind.item_count - 1, StringName(item[0]))
		_sidebar_content.add_child(kind)
		var start_build := _button("在城内选中地块开工", func(): _command(&"build", {
			"point_id": _selected_point_id,
			"kind": kind.get_selected_metadata(),
			"plot": _selected_plot,
		}), true)
		start_build.disabled = _selected_plot < 0 or not _building_for_plot(_selected_plot).is_empty() or not project.is_empty()
		_sidebar_content.add_child(start_build)
	else:
		_add_readout("不可建设", "该普通节点可驻军、过路和有限补给，但没有战时内城建设许可。", WARNING)
	_add_heading("工人安排")
	var buildings := _array(local_model.get("buildings", []))
	if buildings.is_empty():
		_add_readout("尚无设施", "开工并完成建筑后，可把同一批驻守士兵分配为工人。行军、作战与工位互斥。", MUTED)
	else:
		for building_value in buildings:
			var building := _dict(building_value)
			var id := StringName(building.get("id", ""))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 5)
			var label := _label("%s · %d 人" % [_building_name(StringName(building.get("kind", id))), int(building.get("workers", 0))], 15, TEXT)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			for target in [1, 2, 3, 4]:
				var assign := _button(str(target), func(): _command(&"workers", {"building_id": id, "count": target}), false)
				assign.custom_minimum_size = Vector2(32, 30)
				row.add_child(assign)
			_sidebar_content.add_child(row)
			# R1B.2：建成不派工就不产出——这是新人最容易误判为 bug 的断点。
			if int(building.get("workers", 0)) == 0:
				_add_readout(
					"尚未派工",
					"%s已建成但没有工人，不会产出。安排驻守士兵后才开始生产。" % _building_name(StringName(building.get("kind", id))),
					WARNING
				)
				var quick_staff := _button("立即安排 4 名工人", func(): _command(&"workers", {"building_id": id, "count": 4}), false)
				_sidebar_content.add_child(quick_staff)
			if not bool(building.get("connected", false)):
				_sidebar_content.add_child(_button("连接%s" % _building_name(StringName(building.get("kind", id))), func(): _command(&"connect", {"building_id": id}), false))
	_add_readout("可用工人", "本地可分配 %d。工人来自同一批驻守士兵，不能同时行军或作战。" % int(local_model.get("workers_available", 0)), MUTED)
	_add_feedback_block()


func _build_armies_tab() -> void:
	_add_heading("关内调兵")
	_add_readout("操作方式", "先点选军队，再点击地图节点或从下面选目标。道路、阶段和工位占用会在下令时核验。", MUTED)
	var armies := _array(_model.get("armies", []))
	if armies.is_empty():
		_add_readout("暂无出征军队", "在准备页确认首批投入后，军队会出现在连续地图。", WARNING)
	else:
		for army_value in armies:
			var army := _dict(army_value)
			var id := StringName(army.get("army_id", army.get("id", "")))
			var army_button := _button(_army_text(army), func(): _select_army(id), id == _selected_army_id)
			_sidebar_content.add_child(army_button)
		var target := OptionButton.new()
		target.add_theme_font_size_override("font_size", 16)
		for point_id_value in _dict(_model.get("points", {})).keys():
			var point_id := StringName(point_id_value)
			var point := _point(point_id)
			target.add_item(str(point.get("display_name", point_id)))
			target.set_item_metadata(target.item_count - 1, point_id)
		_sidebar_content.add_child(target)
		var move := _button("向选中地点行军", func(): _command(&"move", {"army_id": _selected_army_id, "target_id": target.get_selected_metadata()}), true)
		move.disabled = _selected_army_id.is_empty()
		_sidebar_content.add_child(move)
	var local_pool := int(_dict(_model.get("local", {})).get("local_pool", 0))
	_add_readout("本地人员来源", "可用本地人员 %d。训练消费的是明确的本地有限来源，结算时仍留在当地。" % local_pool, MUTED)
	_add_feedback_block()


func _build_result_tab() -> void:
	_add_heading("损益与结算")
	var phase := String(_model.get("phase", "PREPARATION"))
	var summary := _dict(_model.get("summary", {}))
	if phase == "PENDING":
		_add_readout("待确认结果", _pending_text(summary), GOLD)
		_sidebar_content.add_child(_button("确认损益并归队", func(): _command(&"confirm"), true))
		_sidebar_content.add_child(_button("按本次初态重试", func(): _command(&"retry"), false))
	elif phase == "ACTIVE":
		_add_readout("尚未结算", "攻城或撤军会生成一份待确认损益。确认前，永久主城不会获得返还或写入阵亡。", MUTED)
		# R1B.2：未接战时的唯一动作不再用红色「记录败退结果」警示玩家。
		_add_readout("提前结束", "尚未接战就想离场时，可用下面按钮放弃本关，并按当前损益生成待确认结果。", MUTED)
		_sidebar_content.add_child(_button("放弃本关 · 记录结算", func(): _command(&"outcome", {"kind": &"DEFEAT"}), false))
	else:
		_add_readout("结算状态", "当前阶段：%s。仅待确认结果会执行结算写入。" % _phase_name(phase), MUTED)
		if phase in ["COMPLETED", "PREPARATION"]:
			var local: Dictionary = _model.get("local", {})
			_add_readout("结算暂存", "粮 %d · 木 %d。主城满仓时保留于原资源账，腾出容量后领取。" % [int(local.get("food", 0)), int(local.get("wood", 0))], MUTED)
			_sidebar_content.add_child(_button("领取结算暂存物资", func(): _command(&"claim"), false))
		if phase == "COMPLETED":
			_sidebar_content.add_child(_button("返回永久主城", _hide_campaign, false))
	_add_feedback_block()


func _set_tab(tab: StringName) -> void:
	_active_tab = tab
	_rebuild_sidebar()


func _set_surface_mode(mode: StringName) -> void:
	_surface_mode = mode
	_style_surface_button(_city_surface_button, mode == &"CITY")
	_style_surface_button(_theater_surface_button, mode == &"THEATER")
	_feedback_override = "已进入前线内城；点击真实建筑或空地操作。" if mode == &"CITY" else "已切换战区总览；这里用于查看线路与调兵。"
	_update_chrome()
	_rebuild_sidebar()

func _apply_persisted_view_context() -> void:
	var context := _dict(_model.get("view_context", {}))
	var phase := StringName(_model.get("phase", &"PREPARATION"))
	var surface := StringName(context.get("surface", &"THEATER" if phase != &"PREPARATION" else &"CITY"))
	if surface == &"CITY":
		_inner_city_point_id = StringName(context.get("city_id", &"blackstone_city"))
		_surface_mode = &"CITY"
	elif phase != &"PREPARATION":
		_inner_city_point_id = &""
		_surface_mode = &"THEATER"

func _enter_selected_city() -> void:
	if _selected_army_id != &"":
		_feedback_override = "当前正在选择军令目标；请先取消选中军队，再进入城市。"
		_update_chrome()
		return
	var point := _point(_selected_point_id)
	if not bool(point.get("allows_build", false)):
		_feedback_override = "%s没有本关战时内城建设权限。" % str(point.get("display_name", _selected_point_id))
		_update_chrome()
		return
	_inner_city_point_id = _selected_point_id
	_command(&"view", {"surface": &"CITY", "city_id": _selected_point_id})

func _return_to_theater() -> void:
	_command(&"view", {"surface": &"THEATER"})


func _toggle_pressure_details() -> void:
	_pressure_details_expanded = not _pressure_details_expanded
	_rebuild_sidebar()


func _on_plot_clicked(plot: int) -> void:
	_selected_plot = plot
	var building := _building_for_plot(plot)
	_selected_building_id = StringName(building.get("id", ""))
	_active_tab = &"BUILD"
	_feedback_override = "已选中地块 %d%s。" % [plot + 1, "及其真实设施" if not building.is_empty() else ""]
	_update_chrome()
	_rebuild_sidebar()


func _on_building_clicked(id: StringName) -> void:
	_selected_building_id = id
	var selected_name := "设施"
	for value in _array(_dict(_model.get("local", {})).get("buildings", [])):
		var building := _dict(value)
		if StringName(building.get("id", "")) == id:
			_selected_plot = int(building.get("plot", -1))
			selected_name = _building_name(StringName(building.get("kind", &"")))
			break
	_active_tab = &"BUILD"
	_feedback_override = "已选中%s。" % selected_name
	_update_chrome()
	_rebuild_sidebar()


func _toggle_formation(id: StringName, on: bool) -> void:
	if on and id not in _selected_formation_ids:
		_selected_formation_ids.append(id)
	elif not on:
		_selected_formation_ids.erase(id)


func _select_army(id: StringName) -> void:
	_selected_army_id = &"" if _selected_army_id == id else id
	_feedback_override = "已退出发令状态；现在可以点城进入。" if _selected_army_id.is_empty() else "已选中军队；点击地图地点下达关内调动。"
	_update_chrome()
	_rebuild_sidebar()


func _on_army_clicked(id: StringName) -> void:
	_select_army(id)


func _on_world_clicked(point_id: StringName) -> void:
	_selected_point_id = point_id
	if not _selected_army_id.is_empty() and String(_model.get("phase", "")) == "ACTIVE":
		_command(&"move", {"army_id": _selected_army_id, "target_id": point_id})
		return
	if bool(_point(point_id).get("allows_build", false)) and String(_model.get("phase", "")) == "ACTIVE":
		_enter_selected_city()
		return
	_feedback_override = "%s 已选中。" % str(_point(point_id).get("display_name", point_id))
	_update_chrome()
	_rebuild_sidebar()


func _command(action: StringName, args: Dictionary = {}) -> void:
	if _runtime == null or not _runtime.has_method("command"):
		_feedback_override = "战役数据暂不可用，命令未提交。"
		_update_chrome()
		return
	var receipt: Variant = _runtime.call("command", action, args)
	var result := _dict(receipt)
	if bool(result.get("success", false)):
		_feedback_override = str(result.get("message", "命令已提交。"))
	else:
		_feedback_override = str(result.get("error", "命令未被接受。请核对道路、资源、工位或当前阶段。"))
	refresh(true)
	if (
		bool(result.get("success", false))
		and action == &"view"
		and StringName(args.get("surface", &"")) == &"CITY"
		and _city != null
		and _city.has_method("show_regular_campaign_city")
	):
		_city.call("show_regular_campaign_city")
	if bool(result.get("success", false)) and action in [&"depart", &"confirm", &"retry"]:
		call_deferred("_reset_sidebar_scroll")


func _reset_sidebar_scroll() -> void:
	if is_instance_valid(_sidebar):
		_sidebar_scroll_reset_pending = true
		_sidebar.scroll_vertical = 0


func _toggle_pause() -> void:
	if _city != null and _city.has_method("toggle_city_time_paused"):
		_city.call("toggle_city_time_paused")
		_feedback_override = "已切换游戏内时间暂停；暂停不会推进生产、口粮或敌方整备。"
	else:
		_feedback_override = "当前主城未提供时间暂停接口。"
	_update_chrome()


func _set_speed(value: float) -> void:
	if _city != null and _city.has_method("set_city_time_speed"):
		if bool(_city.call("set_city_time_speed", value)):
			_feedback_override = "已设置 %d× 游戏内时间。" % int(value)
		else:
			_feedback_override = "当前状态不能切换该时间速度。"
	else:
		_feedback_override = "当前主城未提供时间速度接口。"
	_update_chrome()


func _hide_campaign() -> void:
	visible = false
	if _city != null and _city.has_method("deactivate_regular_campaign_city"):
		_city.call("deactivate_regular_campaign_city")
	campaign_closed.emit()


func _ensure_selection_is_valid() -> void:
	var points := _dict(_model.get("points", {}))
	if not points.has(_selected_point_id):
		_selected_point_id = StringName(points.keys()[0]) if not points.is_empty() else &""
	var armies := _array(_model.get("armies", []))
	var army_ids: Array[StringName] = []
	for value in armies:
		var army := _dict(value)
		army_ids.append(StringName(army.get("army_id", army.get("id", ""))))
	if not _selected_army_id.is_empty() and _selected_army_id not in army_ids:
		_selected_army_id = &""
	if String(_model.get("phase", "")) == "PREPARATION" and _selected_formation_ids.is_empty():
		for value in _array(_dict(_model.get("home", {})).get("formations", [])):
			var formation := _dict(value)
			var id := StringName(formation.get("id", formation.get("formation_id", "")))
			if int(formation.get("member_count", formation.get("count", 0))) > 0:
				_selected_formation_ids.append(id)
	if _selected_plot >= 0:
		var building := _building_for_plot(_selected_plot)
		_selected_building_id = StringName(building.get("id", ""))


func _building_for_plot(plot: int) -> Dictionary:
	if plot < 0:
		return {}
	for value in _array(_dict(_model.get("local", {})).get("buildings", [])):
		var building := _dict(value)
		if int(building.get("plot", -1)) == plot:
			return building
	return {}


func _add_selected_building_card(building: Dictionary) -> void:
	var kind := StringName(building.get("kind", &""))
	var connected := bool(building.get("connected", false))
	var workers := int(building.get("workers", 0))
	var output := "尚无有效产出"
	if connected and workers > 0:
		match kind:
			&"FARM": output = "每 3 分钟最多产粮 22；当前岗位 %d/4" % workers
			&"LOGGING": output = "每 3 分钟最多产木 18；当前岗位 %d/4" % workers
			&"WAREHOUSE": output = "本地仓储容量提高 120"
			&"CLINIC": output = "可处理真实伤员；当前岗位 %d/4" % workers
	_add_readout(
		_building_name(kind),
		"建设区 %d · 已建成 · 道路%s · 人员 %d/4\n%s" % [
			int(building.get("plot", -1)) + 1,
			"已接通" if connected else "未接通",
			workers,
			output,
		],
		ACCENT
	)


func _add_heading(value: String) -> void:
	var heading := _label(value, 19, ACCENT)
	heading.add_theme_constant_override("outline_size", 1)
	_sidebar_content.add_child(heading)


func _add_readout(title: String, body: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(SURFACE_SOFT, BORDER.darkened(0.18), 7))
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	content.add_child(_label(title, 14, color))
	var detail := _label(body, 16, TEXT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	_sidebar_content.add_child(card)


func _add_feedback_block() -> void:
	var feedback := _feedback_override if not _feedback_override.is_empty() else str(_model.get("feedback", ""))
	if not feedback.is_empty():
		_add_readout("战役反馈", feedback, WARNING)


func _is_editing_departure_supply() -> bool:
	if _active_tab != &"OVERVIEW" or String(_model.get("phase", "")) != "PREPARATION":
		return false
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	for spin in [_departure_food_spin, _departure_wood_spin]:
		if is_instance_valid(spin) and (
			focus_owner == spin or focus_owner == spin.get_line_edit()
		):
			return true
	return false


func _spin(title: String, minimum: int, maximum: int, initial: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _label(title, 16, TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = clampi(initial, minimum, maximum)
	spin.step = 1
	spin.allow_greater = false
	spin.custom_minimum_size = Vector2(100, 34)
	spin.add_theme_font_size_override("font_size", 16)
	row.add_child(spin)
	return {"row": row, "spin": spin}


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(value: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = 36
	button.add_theme_stylebox_override("normal", _button_style(GOLD if primary else SURFACE_SOFT, GOLD if primary else BORDER, primary))
	button.add_theme_stylebox_override("hover", _button_style((GOLD.lightened(0.10)) if primary else SURFACE_SOFT.lightened(0.12), ACCENT, primary))
	button.add_theme_stylebox_override("pressed", _button_style(GOLD.darkened(0.18) if primary else SURFACE, ACCENT, primary))
	button.add_theme_color_override("font_color", SURFACE if primary else TEXT)
	button.pressed.connect(callback)
	return button


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _panel_style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _button_style(color: Color, border: Color, primary: bool) -> StyleBoxFlat:
	var style := _panel_style(color, border, 6)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if primary:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
		style.shadow_size = 2
	return style


func _style_surface_button(button: Button, selected: bool) -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_stylebox_override("normal", _button_style(GOLD if selected else SURFACE_SOFT, GOLD if selected else BORDER, selected))
	button.add_theme_color_override("font_color", SURFACE if selected else TEXT)


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _point(id: StringName) -> Dictionary:
	return _dict(_dict(_model.get("points", {})).get(id, {}))


func _point_text(id: StringName) -> String:
	var point := _point(id)
	return "%s · %s" % [str(point.get("display_name", id)), "可建设战时内城" if bool(point.get("allows_build", false)) else "普通驻军/补给节点"]


func _point_build_message(point: Dictionary) -> String:
	if bool(point.get("allows_build", false)):
		return "此地具备战时内城许可。农田、伐木、仓储和医疗都消耗真实本地材料、工人和时间。"
	return "此地没有建设许可；普通节点仍能作为通行、驻军与有限补给位置。"


func _army_text(army: Dictionary) -> String:
	var presentation := _dict(army.get("presentation", {}))
	var current := _army_current_count(army)
	var entry := int(presentation.get("entry_count", current))
	if StringName(presentation.get("state", army.get("phase", &""))) == &"ENGAGING":
		return "%s · 交战中 · 当前可战 %d 人（入战 %d）" % [_army_name(army), current, entry]
	return "%s · %s · %d 人" % [_army_name(army), _army_phase_name(StringName(army.get("phase", ""))), current]


func _army_current_count(army: Dictionary) -> int:
	var presentation := _dict(army.get("presentation", {}))
	if typeof(presentation.get("current_count", null)) == TYPE_INT:
		return maxi(0, int(presentation.current_count))
	var total := 0
	for count in _dict(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _forecast_text(forecast: Dictionary) -> String:
	if forecast.is_empty():
		return "尚无供给预测。"
	var risk := str(forecast.get("risk_id", "STABLE"))
	var deficit := int(forecast.get("deficit_ms", 0))
	var reasons := _array(forecast.get("reasons", []))
	var reason_text := "；".join(reasons.map(func(reason: Variant): return _forecast_reason(StringName(reason))))
	var runway := "当前条件下未见近期缺口" if deficit <= 0 else "预计 %s 后出现缺口" % _time_text(deficit)
	return "%s · 产出 %d / 消耗 %d / 净值 %+d\n%s%s" % [_risk_name(risk), int(forecast.get("yield", 0)), int(forecast.get("consumption", 0)), int(forecast.get("net", 0)), runway, "\n" + reason_text if not reason_text.is_empty() else ""]


func _forecast_color(forecast: Dictionary) -> Color:
	var risk := str(forecast.get("risk_id", ""))
	return DANGER if risk in ["SHORTAGE", "HUNGER", "DEFICIT", "CRITICAL"] else (WARNING if risk in ["TIGHT", "WARNING"] else ACCENT)


func _pressure_text(pressure: Dictionary) -> String:
	if _model.get("phase", "") == &"COMPLETED":
		return "本关目标已完成，主线压力已解除。主城可继续经营与治疗，日常供粮仍按实际状态计算。"
	if pressure.is_empty():
		return "压力将随战役时间、兵力和供给变化。"
	var stage := _pressure_name(pressure)
	var construction := int(pressure.get("nonessential_construction_permille", 1000))
	var training := int(pressure.get("basic_training_permille", 1000))
	var growth := int(pressure.get("growth_permille", 1000))
	var window := _time_text(int(pressure.get("promised_window_ms", 1800000)))
	var recovery := _time_text(int(pressure.get("recovery_credit_balance_ms", 0)))
	return "阶段 %s · 扩建 %d%% · 训练 %d%% · 增长 %d%%\n可战兵力 %d · 备战窗口 %s\n战损缓冲余量 %s；重试不重置主线历时。长期迟延将停扩建，仍保留有限的必要恢复。" % [stage, construction / 10, training / 10, growth / 10, int(pressure.get("total_military", 0)), window, recovery]


func _building_name(kind: StringName) -> String:
	return {
		&"FARM": "农田",
		&"LOGGING": "伐木场",
		&"WAREHOUSE": "仓储",
		&"CLINIC": "医疗点",
	}.get(kind, "设施")


func _army_name(army: Dictionary) -> String:
	var name := str(army.get("display_name", ""))
	return "部队" if name.is_empty() or name.begins_with("army.") else name


func _army_phase_name(phase: StringName) -> String:
	return {
		&"MARCHING": "行军中",
		&"STATIONED": "驻扎",
		&"SIEGING": "交战中",
		&"RETREATING": "撤退中",
		&"CLOSED": "已失去战力",
	}.get(phase, "待命")


func _risk_name(risk: String) -> String:
	return {
		"STABLE": "供给稳定",
		"WARNING": "供给预警",
		"SHORTAGE": "实际缺粮",
		"TIGHT": "供给紧张",
		"DEFICIT": "供给不足",
		"HUNGER": "断粮风险",
		"CRITICAL": "高风险",
	}.get(risk, "供给评估")


func _forecast_reason(reason: StringName) -> String:
	return {
		&"MEAL_BEFORE_HARVEST_DEFICIT": "预测到收获前的口粮缺口",
		&"HARVEST_CAPACITY_LIMIT": "仓储空间限制收获",
		&"NO_EFFECTIVE_FOOD_YIELD": "尚未安排有效粮食生产",
		&"NEGATIVE_FOOD_NET": "粮食收支为负",
		&"FORECAST_DEFICIT": "预计将出现粮食缺口",
		&"NEGATIVE_NET_SHORT_RUNWAY": "现有粮食难以维持",
		&"HARVEST_GAP_RISK": "收获间隔存在缺粮风险",
		&"LOW_STOCK_BEFORE_NEXT_MEAL": "下次口粮前库存偏低",
	}.get(reason, "供给条件变化")


func _pending_text(summary: Dictionary) -> String:
	return "归队 %d · 伤员 %d · 阵亡 %d\n本地人员 %d · 返还粮食 %d · 返还木材 %d\n确认后执行一次永久结算；超出主城容量的物资原账暂存。重试保留主线已用时间。" % [int(summary.get("survivors", 0)), int(summary.get("wounded", 0)), int(summary.get("fallen", 0)), int(summary.get("local_people", 0)), int(summary.get("food_return", 0)), int(summary.get("wood_return", 0))]


func _project_progress_permille(project: Dictionary) -> int:
	if project.has("progress_permille"):
		return clampi(int(project.get("progress_permille", 0)), 0, 1000)
	var required := int(project.get("required_ms", 0))
	if required <= 0:
		return 0
	return clampi(int(round(float(project.get("progress_ms", 0)) * 1000.0 / required)), 0, 1000)


func _time_text(milliseconds: int) -> String:
	var total_seconds := maxi(milliseconds / 1000, 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _phase_name(phase: String) -> String:
	return {"PREPARATION": "备战", "ACTIVE": "关内行动", "PENDING": "待确认", "COMPLETED": "战役完成"}.get(phase, phase)


func _pressure_name(pressure: Dictionary) -> String:
	return str(pressure.get("stage", pressure.get("stage_id", "评估中")))


class CampaignMapSurface extends Control:
	signal world_clicked(point_id: StringName)
	signal army_clicked(army_id: StringName)
	signal plot_clicked(plot: int)
	signal building_clicked(building_id: StringName)

	const MAP_WORLD := Rect2(0.0, 0.0, 1500.0, 980.0)
	var model: Dictionary = {}
	var selected_army_id := &""
	var selected_point_id := &""
	var selected_building_id := &""
	var selected_plot := -1
	var surface_mode := &"CITY"
	var font: Font
	var _press_position := Vector2.ZERO
	var _tracking_click := false
	var _dragged := false
	var _presentation: RegularCampaignPresentationBridge
	var _presentation_overlay: PresentationOverlay

	class PresentationOverlay extends Control:
		var host: Control

		func _label_position(anchor: Vector2, text: String, font_size: int, occupied: Array[Rect2]) -> Vector2:
			var text_size: Vector2 = host.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline := Vector2(
				clampf(anchor.x, 6.0, maxf(6.0, size.x - text_size.x - 6.0)),
				clampf(anchor.y, float(font_size + 6), maxf(float(font_size + 6), size.y - 6.0))
			)
			var rect := Rect2(Vector2(baseline.x, baseline.y - font_size), Vector2(text_size.x, font_size + 4.0))
			for attempt in range(occupied.size() + 1):
				var collision := Rect2()
				for prior in occupied:
					if rect.intersects(prior):
						collision = prior
						break
				if collision.size == Vector2.ZERO:
					break
				baseline.y = clampf(collision.end.y + font_size + 3.0, float(font_size + 6), maxf(float(font_size + 6), size.y - 6.0))
				rect.position.y = baseline.y - font_size
			occupied.append(rect)
			return baseline

		func _engagement_card_rect(anchor: Vector2, occupied: Array[Rect2]) -> Rect2:
			var card_size := Vector2(252.0, 76.0)
			var position := Vector2(
				clampf(anchor.x, 8.0, maxf(8.0, size.x - card_size.x - 8.0)),
				clampf(anchor.y, 8.0, maxf(8.0, size.y - card_size.y - 8.0))
			)
			var card := Rect2(position, card_size)
			for attempt in range(occupied.size() + 1):
				var collision := Rect2()
				for prior in occupied:
					if card.intersects(prior.grow(4.0)):
						collision = prior
						break
				if collision.size == Vector2.ZERO:
					break
				card.position.y = clampf(collision.end.y + 8.0, 8.0, maxf(8.0, size.y - card.size.y - 8.0))
			occupied.append(card)
			return card

		func _draw() -> void:
			if not is_instance_valid(host) or not is_instance_valid(host._presentation):
				return
			if host.surface_mode == &"CITY":
				for plot in 6:
					if not host._building_at_plot(plot).is_empty():
						continue
					var rect: Rect2 = host._city_plot_rect(plot)
					if plot == host.selected_plot:
						draw_rect(rect.grow(5.0), Color("e8bd63"), false, 3.0)
						draw_string(host.font, rect.position + Vector2(4, -7), "建设空间", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8bd63"))
			elif host._presentation.is_low_poly_theater_visible():
				var occupied_labels: Array[Rect2] = []
				for point_id_value in host._dict(host.model.get("points", {})).keys():
					var id := StringName(point_id_value)
					var point: Dictionary = host._point(id)
					var pos: Vector2 = host._screen(host._vec(point.get("world_position", Vector2i.ZERO)))
					if id == host.selected_point_id:
						draw_arc(pos, 34.0, 0.0, TAU, 32, Color("e8bd63"), 4.0, true)
					var label := str(point.get("display_name", id))
					if bool(point.get("allows_build", false)):
						label += " · 可进入内城"
					elif not bool(point.get("known", true)):
						label += " · 未侦察"
					var label_position := _label_position(pos + Vector2(25, -24), label, 15, occupied_labels)
					draw_string(host.font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2ead5"))
				var stacked: Dictionary = {}
				var army_positions: Dictionary = {}
				for army_value in host._array(host.model.get("armies", [])):
					var army: Dictionary = host._dict(army_value)
					var army_pos: Vector2 = host._army_marker_position(army, stacked)
					var army_id := StringName(army.get("army_id", army.get("id", &"")))
					army_positions[army_id] = army_pos
					var state := StringName(host._dict(army.get("presentation", {})).get("state", army.get("phase", &"")))
					var ring_color := Color("f0a45f") if state == &"ENGAGING" else (Color("e8bd63") if army_id == host.selected_army_id else Color("cfe9df"))
					draw_arc(army_pos, 17.0 if army_id == host.selected_army_id else 14.0, 0.0, TAU, 24, ring_color, 2.5, true)
					var army_label: String = str(host._army_label(army))
					var army_label_position := _label_position(army_pos + Vector2(15, 4), army_label, 14, occupied_labels)
					draw_string(host.font, army_label_position, army_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4d476"))
				for siege_value in host._array(host.model.get("sieges", [])):
					var siege: Dictionary = host._dict(siege_value)
					var point: Dictionary = host._point(StringName(siege.get("city_id", &"")))
					if point.is_empty():
						continue
					var city_position: Vector2 = host._screen(host._vec(point.get("world_position", Vector2i.ZERO)))
					var attacker_position: Vector2 = Vector2(army_positions.get(StringName(siege.get("army_id", &"")), city_position + Vector2(-36, -30)))
					var relation_color := Color("ef9e55") if not bool(siege.get("gate_breached", false)) else Color("db8678")
					draw_line(attacker_position, city_position, Color(0.08, 0.04, 0.03, 0.86), 7.0, true)
					draw_line(attacker_position, city_position, relation_color, 3.0, true)
					var direction := attacker_position.direction_to(city_position)
					var arrow_tip := city_position - direction * 22.0
					var side := Vector2(-direction.y, direction.x)
					draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_tip - direction * 13.0 + side * 7.0, arrow_tip - direction * 13.0 - side * 7.0]), relation_color)
					var box := _engagement_card_rect(city_position + Vector2(-126, 48), occupied_labels)
					draw_rect(box, Color(0.03, 0.07, 0.09, 0.92), true)
					draw_rect(box, Color("db8678"), false, 2.0)
					var gate_text := "攻门 · 城门 %d/%d" % [int(siege.get("gate_hp", 0)), int(siege.get("gate_max_hp", siege.get("gate_hp", 0)))] if not bool(siege.get("gate_breached", false)) else "城门已破 · 仍在交战"
					draw_string(host.font, box.position + Vector2(9, 21), "%s → %s" % [str(siege.get("attacker_display_name", "部队")), str(point.get("display_name", "目标城"))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4d476"))
					draw_string(host.font, box.position + Vector2(9, 44), gate_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, relation_color)
					draw_string(host.font, box.position + Vector2(9, 66), "当前可战 %d · 入战 %d · 守军当前 %d" % [int(siege.get("attacker_count", 0)), int(siege.get("attacker_entry_count", siege.get("attacker_count", 0))), int(siege.get("defender_count", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e9f0e8"))

	func _ready() -> void:
		font = ThemeDB.fallback_font
		mouse_filter = Control.MOUSE_FILTER_STOP
		_presentation = PRESENTATION_BRIDGE.new()
		_presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_presentation)
		_presentation_overlay = PresentationOverlay.new()
		_presentation_overlay.host = self
		_presentation_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_presentation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_presentation_overlay)

	func set_model(value: Dictionary, selected_army: StringName, selected_point: StringName, selected_building: StringName, plot: int, mode: StringName) -> void:
		model = value.duplicate(true)
		selected_army_id = selected_army
		selected_point_id = selected_point
		selected_building_id = selected_building
		selected_plot = plot
		surface_mode = mode
		if is_instance_valid(_presentation):
			_presentation.set_projection(model, mode, selected_army, selected_building, plot)
		if is_instance_valid(_presentation_overlay):
			_presentation_overlay.queue_redraw()
		queue_redraw()

	func _draw() -> void:
		if surface_mode == &"CITY":
			if not is_instance_valid(_presentation):
				_draw_component_unavailable("原城市表现组件未载入")
			return
		if is_instance_valid(_presentation) and _presentation.is_low_poly_theater_visible():
			return
		_draw_component_unavailable("原战区表现组件或资源未载入")

	func _draw_component_unavailable(message: String) -> void:
		var rect := _map_rect()
		draw_style_box(_ground_style(), rect)
		draw_string(font, rect.get_center() + Vector2(-110.0, 4.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("edb765"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and _tracking_click:
			if event.position.distance_to(_press_position) > 8.0:
				_dragged = true
				if is_instance_valid(_presentation):
					_presentation.pan_surface(event.relative)
					queue_redraw()
			return
		if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
			if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and is_instance_valid(_presentation):
				_presentation.zoom_surface(1.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.18, event.position)
				queue_redraw()
				accept_event()
			return
		if event.pressed:
			_press_position = event.position
			_tracking_click = true
			_dragged = false
			accept_event()
			return
		var should_activate: bool = _tracking_click and not _dragged and event.position.distance_to(_press_position) <= 8.0
		_tracking_click = false
		if not should_activate:
			return
		_activate_at(event.position)
		accept_event()

	func _activate_at(local: Vector2) -> void:
		if surface_mode == &"CITY":
			for building_value in _array(_dict(model.get("local", {})).get("buildings", [])):
				var building := _dict(building_value)
				var plot := int(building.get("plot", -1))
				if _city_plot_rect(plot).has_point(local):
					building_clicked.emit(StringName(building.get("id", "")))
					return
			for plot in 6:
				if _city_plot_rect(plot).has_point(local):
					plot_clicked.emit(plot)
					return
			return
		var stacked: Dictionary = {}
		for army_value in _array(model.get("armies", [])):
			var army := _dict(army_value)
			var pos := _army_marker_position(army, stacked)
			if local.distance_to(pos) < 18.0:
					army_clicked.emit(StringName(army.get("army_id", army.get("id", ""))))
					return
		for point_id_value in _dict(model.get("points", {})).keys():
			var point_id := StringName(point_id_value)
			var point := _point(point_id)
			if local.distance_to(_screen(_vec(point.get("world_position", Vector2i.ZERO)))) < 28.0:
				world_clicked.emit(point_id)
				return

	func _draw_city() -> void:
		var rect := _city_rect()
		draw_rect(rect, Color("13282b"), true)
		var wall := rect.grow(-16.0)
		# Reuse the old city's layered ground language: an earth field, irregular
		# work patches and broad roads underneath actual building silhouettes.
		draw_rect(wall, Color("34433b"), true)
		for patch in [
			Rect2(wall.position + Vector2(28, 58), Vector2(wall.size.x * 0.30, wall.size.y * 0.28)),
			Rect2(wall.position + Vector2(wall.size.x * 0.58, 52), Vector2(wall.size.x * 0.34, wall.size.y * 0.25)),
			Rect2(wall.position + Vector2(46, wall.size.y * 0.62), Vector2(wall.size.x * 0.34, wall.size.y * 0.25)),
		]:
			draw_rect(patch, Color(0.20, 0.29, 0.23, 0.48), true)
		draw_rect(wall, Color("7f8878"), false, 7.0)
		for x in range(0, 9):
			var px := lerpf(wall.position.x + 10.0, wall.end.x - 10.0, float(x) / 8.0)
			draw_rect(Rect2(Vector2(px - 5.0, wall.position.y - 5.0), Vector2(10.0, 11.0)), Color("9b9a83"), true)
		var gate_width := minf(92.0, wall.size.x * 0.16)
		var gate := Rect2(Vector2(wall.get_center().x - gate_width * 0.5, wall.end.y - 10.0), Vector2(gate_width, 22.0))
		draw_rect(gate, Color("09151d"), true)
		draw_rect(gate.grow(-3.0), Color("a3784f"), true)
		var road_color := Color("8d8066")
		draw_line(Vector2(gate.get_center().x, gate.position.y), Vector2(gate.get_center().x, wall.position.y + 42.0), Color("58584b"), 24.0, true)
		draw_line(Vector2(gate.get_center().x, gate.position.y), Vector2(gate.get_center().x, wall.position.y + 42.0), road_color, 16.0, true)
		draw_line(Vector2(wall.position.x + 34.0, wall.get_center().y), Vector2(wall.end.x - 34.0, wall.get_center().y), Color("58584b"), 21.0, true)
		draw_line(Vector2(wall.position.x + 34.0, wall.get_center().y), Vector2(wall.end.x - 34.0, wall.get_center().y), road_color, 13.0, true)
		draw_line(Vector2(gate.get_center().x, gate.position.y), Vector2(gate.get_center().x, rect.end.y), Color("5b594e"), 14.0, true)
		_draw_city_ambience(wall)
		_draw_city_center(wall)
		for plot in 6:
			_draw_city_plot(plot)
		var project := _dict(_dict(model.get("local", {})).get("project", {}))
		if not project.is_empty():
			_draw_project(project)
		draw_string(font, wall.position + Vector2(18.0, 28.0), "青原前线内城", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e9f0e8"))

	func _draw_city_ambience(wall: Rect2) -> void:
		# Small unlabeled dwellings, yard fences and a well restore the old city's
		# inhabited scale. They are deliberately outside all six hit regions and
		# expose no status, selection or claimed capability.
		var huts := [
			Vector2(0.07, 0.39), Vector2(0.29, 0.39), Vector2(0.71, 0.39), Vector2(0.93, 0.39),
			Vector2(0.07, 0.61), Vector2(0.29, 0.61), Vector2(0.71, 0.61), Vector2(0.93, 0.61),
		]
		for ratio in huts:
			var center: Vector2 = wall.position + wall.size * Vector2(ratio)
			var hut := Rect2(center - Vector2(15, 10), Vector2(30, 20))
			draw_rect(Rect2(hut.position + Vector2(4, 5), hut.size), Color(0.03, 0.06, 0.06, 0.34), true)
			draw_rect(hut, Color("665743"), true)
			draw_polygon(PackedVector2Array([hut.position + Vector2(-4, 3), hut.position + Vector2(hut.size.x + 4, 3), hut.position + Vector2(hut.size.x * 0.5, -8)]), PackedColorArray([Color("896049")]))
		var well := wall.get_center() + Vector2(wall.size.x * 0.23, 0)
		draw_circle(well, 11.0, Color("3c4b48"))
		draw_arc(well, 11.0, 0.0, TAU, 20, Color("a39472"), 3.0, true)

	func _draw_city_center(wall: Rect2) -> void:
		var center := wall.get_center()
		var command := Rect2(center - Vector2(43.0, 28.0), Vector2(86.0, 56.0))
		draw_rect(Rect2(command.position + Vector2(6, 7), command.size), Color(0.04, 0.08, 0.08, 0.45), true)
		draw_rect(command, Color("785b43"), true)
		draw_polygon(PackedVector2Array([command.position + Vector2(-10, 5), command.position + Vector2(command.size.x + 10, 5), command.position + Vector2(command.size.x * 0.5, -18)]), PackedColorArray([Color("a65f48")]))
		draw_rect(Rect2(command.get_center() + Vector2(-8, 7), Vector2(16, 21)), Color("302b27"), true)
		draw_string(font, command.position + Vector2(15.0, 49.0), "军议所", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2dec0"))

	func _draw_city_plot(plot: int) -> void:
		var rect := _city_plot_rect(plot)
		var building := _building_at_plot(plot)
		var occupied := not building.is_empty()
		var selected := selected_plot == plot
		# Plot rectangles remain hit areas only.  The normal city view shows terrain;
		# legal bounds appear when the player selects a site or when work is active.
		if selected:
			draw_rect(rect.grow(3.0), Color(0.91, 0.74, 0.39, 0.10), true)
			draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), GOLD, 2.0, 7.0)
			draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, GOLD, 2.0, 7.0)
			draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), GOLD, 2.0, 7.0)
			draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, GOLD, 2.0, 7.0)
		if occupied:
			_draw_building_connection(building, rect, plot)
			_draw_building(building, rect)
		elif selected:
			draw_string(font, rect.get_center() + Vector2(-27, 5), "可建设", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)

	func _draw_building_connection(building: Dictionary, rect: Rect2, plot: int) -> void:
		var connected := bool(building.get("connected", false))
		var road_y := _city_rect().get_center().y
		var entrance := Vector2(rect.get_center().x, rect.end.y - 7.0 if plot < 3 else rect.position.y + 7.0)
		var road_end := Vector2(entrance.x, road_y)
		var direction := 1.0 if plot < 3 else -1.0
		if connected:
			draw_line(entrance, road_end, Color("555548"), 13.0, true)
			draw_line(entrance, road_end, Color("aa9973"), 7.0, true)
		else:
			var gap_end := entrance + Vector2(0, 18.0 * direction)
			draw_dashed_line(gap_end, road_end, Color("756d5a"), 5.0, 8.0)
			draw_line(entrance + Vector2(-8, 7 * direction), entrance + Vector2(8, 7 * direction), Color("d88962"), 4.0, true)

	func _draw_building(building: Dictionary, rect: Rect2) -> void:
		var kind := StringName(building.get("kind", &""))
		var connected := bool(building.get("connected", false))
		var workers := int(building.get("workers", 0))
		var c := Color("79d7c7") if connected else Color("bc925d")
		var body := rect.grow(-18.0)
		draw_rect(Rect2(body.position + Vector2(7, 8), body.size), Color(0.03, 0.07, 0.07, 0.46), true)
		match kind:
			&"FARM":
				draw_polygon(PackedVector2Array([body.position + Vector2(3, 12), body.position + Vector2(body.size.x - 2, 3), body.end - Vector2(4, 8), body.position + Vector2(0, body.size.y - 2)]), PackedColorArray([Color("4f6a3d")]))
				for row in 5:
					var y := body.position.y + 13.0 + row * maxf(8.0, (body.size.y - 22.0) / 5.0)
					draw_line(Vector2(body.position.x + 8, y), Vector2(body.end.x - 8, y - 5), Color("91b55e"), 5.0)
			&"LOGGING":
				for index in 4:
					var p := body.position + Vector2(14.0 + index * body.size.x / 4.7, 30.0 + (index % 2) * 10.0)
					draw_rect(Rect2(p, Vector2(7.0, 27.0)), Color("76553d"), true)
					draw_circle(p + Vector2(3.0, -5.0), 16.0, Color("4e805d"))
				draw_line(body.position + Vector2(12, body.size.y - 8), body.end - Vector2(10, 8), Color("b1885c"), 7.0)
			&"WAREHOUSE":
				draw_rect(body, Color("806b50"), true)
				draw_polygon(PackedVector2Array([body.position + Vector2(-5, 13), body.position + Vector2(body.size.x + 5, 13), body.position + Vector2(body.size.x * 0.5, -9)]), PackedColorArray([Color("a65f48")]))
				for index in 3:
					draw_rect(Rect2(body.position + Vector2(12.0 + index * body.size.x / 3.5, body.size.y - 28.0), Vector2(18.0, 22.0)), Color("b79a68"), true)
			&"CLINIC":
				draw_rect(body, Color("d8ded4"), true)
				draw_polygon(PackedVector2Array([body.position + Vector2(-5, 13), body.position + Vector2(body.size.x + 5, 13), body.position + Vector2(body.size.x * 0.5, -8)]), PackedColorArray([Color("718487")]))
				var mid := body.get_center()
				draw_rect(Rect2(mid - Vector2(5, 17), Vector2(10, 34)), Color("b85d55"), true)
				draw_rect(Rect2(mid - Vector2(17, 5), Vector2(34, 10)), Color("b85d55"), true)
		var title := "%s · %d人" % [_building_label(kind), workers]
		draw_string(font, body.position + Vector2(0, -7.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)

	func _draw_project(project: Dictionary) -> void:
		var plot := int(project.get("plot", -1))
		if plot < 0:
			return
		var rect := _city_plot_rect(plot).grow(-8.0)
		var required := maxi(1, int(project.get("required_ms", 1)))
		var ratio := clampf(float(project.get("progress_ms", 0)) / float(required), 0.0, 1.0)
		draw_rect(rect, Color(0.7, 0.55, 0.3, 0.18), true)
		for index in 4:
			draw_line(rect.position + Vector2(index * rect.size.x / 3.0, 0), rect.end - Vector2((3 - index) * rect.size.x / 3.0, 0), Color("c99d55"), 3.0)
		draw_rect(Rect2(rect.position + Vector2(5.0, rect.size.y - 14.0), Vector2((rect.size.x - 10.0) * ratio, 7.0)), GOLD, true)
		draw_string(font, rect.position + Vector2(8.0, 19.0), "施工 %d%%" % roundi(ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)

	func _city_rect() -> Rect2:
		return Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))

	func _city_plot_rect(plot: int) -> Rect2:
		if is_instance_valid(_presentation):
			return _presentation.city_plot_rect(plot)
		var wall := _city_rect().grow(-18.0)
		var cell := Vector2(
			clampf(wall.size.x * 0.205, 116.0, 166.0),
			clampf(wall.size.y * 0.245, 86.0, 116.0)
		)
		var columns := [wall.position.x + wall.size.x * 0.18, wall.position.x + wall.size.x * 0.50, wall.position.x + wall.size.x * 0.82]
		var rows := [wall.position.y + wall.size.y * 0.28, wall.position.y + wall.size.y * 0.72]
		return Rect2(Vector2(columns[plot % 3], rows[plot / 3]) - cell * 0.5, cell)

	func _building_at_plot(plot: int) -> Dictionary:
		for value in _array(_dict(model.get("local", {})).get("buildings", [])):
			var building := _dict(value)
			if int(building.get("plot", -1)) == plot:
				return building
		return {}

	func _draw_grid(rect: Rect2) -> void:
		for x in range(1, 8):
			var px := rect.position.x + rect.size.x * float(x) / 8.0
			draw_line(Vector2(px, rect.position.y), Vector2(px, rect.end.y), Color(0.23, 0.42, 0.45, 0.18), 1)
		for y in range(1, 5):
			var py := rect.position.y + rect.size.y * float(y) / 5.0
			draw_line(Vector2(rect.position.x, py), Vector2(rect.end.x, py), Color(0.23, 0.42, 0.45, 0.18), 1)

	func _draw_theater_geography(rect: Rect2) -> void:
		# This is the existing world-map visual language adapted to the current
		# campaign projection: layered land, river, mountains and forests. No
		# static legacy ownership or enemy intelligence is copied here.
		var land := PackedVector2Array([
			rect.position + Vector2(rect.size.x * 0.03, rect.size.y * 0.09),
			rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.06),
			rect.position + Vector2(rect.size.x * 0.96, rect.size.y * 0.55),
			rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.94),
			rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.91),
		])
		draw_colored_polygon(land, Color("72765f"))
		var river := PackedVector2Array()
		for world_point in [Vector2(0, 530), Vector2(430, 500), Vector2(820, 620), Vector2(1160, 670), Vector2(1490, 625), Vector2(1780, 520), Vector2(2070, 560), Vector2(2400, 720)]:
			river.append(_screen(world_point))
		draw_polyline(river, Color("54868c"), 40.0, true)
		draw_polyline(river, Color("83adb0"), 22.0, true)
		for world_point in [Vector2(300, 250), Vector2(650, 275), Vector2(1050, 250), Vector2(1900, 350)]:
			var peak := _screen(world_point)
			draw_colored_polygon(PackedVector2Array([peak + Vector2(-28, 22), peak + Vector2(0, -30), peak + Vector2(30, 22)]), Color("565a50"))
		for world_point in [Vector2(240, 720), Vector2(360, 760), Vector2(1800, 1120), Vector2(2010, 1080)]:
			draw_circle(_screen(world_point), 16.0, Color("456650"))

	func _draw_roads(rect: Rect2) -> void:
		for route_value in _dict(model.get("routes", {})).values():
			var route := _dict(route_value)
			var points := PackedVector2Array()
			for value in _array(route.get("world_points", [])):
				points.append(_screen(_vec(value)))
			if points.size() >= 2:
				draw_polyline(points, Color("173f48"), 12.0, true)
				draw_polyline(points, Color("79a49b"), 4.0, true)

	func _draw_points(rect: Rect2) -> void:
		for point_id_value in _dict(model.get("points", {})).keys():
			var id := StringName(point_id_value)
			var point := _point(id)
			var pos := _screen(_vec(point.get("world_position", Vector2i.ZERO)))
			var known := bool(point.get("known", true))
			var controlled := bool(point.get("controlled", false))
			var buildable := bool(point.get("allows_build", false))
			var color := Color("78908b") if known else Color("66737a")
			if controlled:
				color = Color("78c7bb")
			elif known and int(point.get("defender_count", 0)) > 0:
				color = Color("c87968")
			draw_circle(pos, 14.0 if buildable else 11.0, Color("071218"))
			if String(point.get("kind", "")).ends_with("CITY") or buildable:
				_draw_theater_city(pos, color, buildable)
			else:
				draw_circle(pos, 10.0 if buildable else 7.0, color)
			if id == selected_point_id:
				draw_arc(pos, 19.0, 0.0, TAU, 28, Color("e8bd63"), 2.0, true)
			var label := str(point.get("display_name", id))
			if buildable:
				label += " · 内城"
			elif not known:
				label += " · 未侦察"
			var label_position := pos + Vector2(16, -10)
			var alignment := HORIZONTAL_ALIGNMENT_LEFT
			if label_position.x + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > rect.end.x - 6.0:
				label_position = pos + Vector2(-16 - font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, -10)
			draw_string(font, label_position, label, alignment, -1, 15, Color("e9f0e8"))

	func _draw_theater_city(pos: Vector2, color: Color, buildable: bool) -> void:
		var body := Rect2(pos - Vector2(13, 10), Vector2(26, 20))
		draw_rect(body, color, true)
		for offset in [-10.0, 0.0, 10.0]:
			draw_rect(Rect2(pos + Vector2(offset - 4, -18), Vector2(8, 10)), color.lightened(0.12), true)
		draw_rect(Rect2(pos + Vector2(-4, 2), Vector2(8, 8)), Color("152326"), true)
		if buildable:
			draw_arc(pos, 23.0, 0.0, TAU, 28, Color("e8bd63"), 3.0, true)

	func _draw_armies(rect: Rect2) -> void:
		var stacked: Dictionary = {}
		for army_value in _array(model.get("armies", [])):
			var army := _dict(army_value)
			var id := StringName(army.get("army_id", army.get("id", "")))
			var pos := _army_marker_position(army, stacked)
			var color := Color("e8bd63") if id == selected_army_id else Color("70c4d0")
			draw_circle(pos, 11.0, Color("061116"))
			draw_circle(pos, 8.0, color)
			draw_line(pos + Vector2(-5, 0), pos + Vector2(5, 0), SURFACE, 2)
			draw_line(pos + Vector2(0, -5), pos + Vector2(0, 5), SURFACE, 2)
			var label := _army_label(army)
			var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var label_position := pos + Vector2(12, 4)
			if label_position.x + label_width > rect.end.x - 8:
				label_position.x = pos.x - 12 - label_width
			draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

	func _army_marker_position(army: Dictionary, stacked: Dictionary) -> Vector2:
		# Drawing and hit testing share the same separated marker positions.
		var base_position := _screen(_army_position(army))
		var key := "%d:%d" % [roundi(base_position.x), roundi(base_position.y)]
		var index := int(stacked.get(key, 0))
		stacked[key] = index + 1
		return base_position + Vector2(28, -42 - index * 28)

	func _draw_build_sites() -> void:
		# Six bounded plots make the finite build-site rule visible before the
		# player opens the side panel.  Completed structures use the runtime's
		# stable world position; this layer does not infer construction progress.
		var base := _point(&"blackstone_city")
		if not base.is_empty() and bool(base.get("allows_build", false)):
			var center := _screen(_vec(base.get("world_position", Vector2i.ZERO)))
			for index in 6:
				var offset := Vector2(-30.0 + float(index % 3) * 30.0, 32.0 + float(index / 3) * 25.0)
				draw_rect(Rect2(center + offset - Vector2(8, 6), Vector2(16, 12)), Color("2a535c"), false, 1.5)
		for building_value in _array(_dict(model.get("local", {})).get("buildings", [])):
			var building := _dict(building_value)
			var pos := _screen(_vec(building.get("world_position", Vector2i.ZERO)))
			var color := Color("7cc6a9") if bool(building.get("connected", false)) else Color("bc925d")
			draw_rect(Rect2(pos - Vector2(8, 7), Vector2(16, 14)), Color("071218"), true)
			draw_rect(Rect2(pos - Vector2(6, 5), Vector2(12, 10)), color, true)
			draw_string(font, pos + Vector2(10, 4), _building_label(StringName(building.get("kind", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

	func _army_label(army: Dictionary) -> String:
		var name := str(army.get("display_name", ""))
		if name.is_empty() or name.begins_with("army."):
			name = "部队"
		var presentation := _dict(army.get("presentation", {}))
		var total := 0
		if typeof(presentation.get("current_count", null)) == TYPE_INT:
			total = maxi(0, int(presentation.current_count))
		else:
			for count in _dict(army.get("units_by_definition_id", {})).values():
				total += int(count)
		var state := StringName(presentation.get("state", army.get("phase", &"")))
		return "%s · %s%d人" % [name, "当前可战 " if state == &"ENGAGING" else "", total]

	func _building_label(kind: StringName) -> String:
		return {&"FARM": "农田", &"LOGGING": "伐木", &"WAREHOUSE": "仓储", &"CLINIC": "医疗"}.get(kind, "设施")

	func _army_position(army: Dictionary) -> Vector2:
		var macro := _dict(army.get("macro_march", {}))
		var path := _array(macro.get("route_world_points", army.get("route_world_points", [])))
		if path.is_empty():
			var target := StringName(army.get("target_id", ""))
			return _vec(_point(target).get("world_position", Vector2i.ZERO))
		var ratio := 1.0
		var duration := int(army.get("duration_milliseconds", macro.get("duration_milliseconds", macro.get("total_millis", 0))))
		var progress := int(army.get("progress_milliseconds", macro.get("progress_milliseconds", macro.get("progress_millis", 0))))
		if duration > 0:
			ratio = clampf(float(progress) / float(duration), 0.0, 1.0)
		return _point_on_path(path, ratio)

	func _point_on_path(path: Array, ratio: float) -> Vector2:
		if path.size() == 1:
			return _vec(path[0])
		var lengths: Array[float] = []
		var total := 0.0
		for index in range(path.size() - 1):
			var length := _vec(path[index]).distance_to(_vec(path[index + 1]))
			lengths.append(length)
			total += length
		if total <= 0.0:
			return _vec(path[0])
		var remaining := total * ratio
		for index in lengths.size():
			if remaining <= lengths[index]:
				return _vec(path[index]).lerp(_vec(path[index + 1]), remaining / lengths[index]) if lengths[index] > 0.0 else _vec(path[index])
			remaining -= lengths[index]
		return _vec(path[path.size() - 1])

	func _map_rect() -> Rect2:
		var padding := 8.0
		var available := Rect2(Vector2(padding, padding), size - Vector2(padding * 2.0, padding * 2.0))
		var scale := minf(available.size.x / MAP_WORLD.size.x, available.size.y / MAP_WORLD.size.y)
		var map_size := MAP_WORLD.size * scale
		return Rect2(available.position + (available.size - map_size) * 0.5, map_size)

	func _screen(world: Vector2) -> Vector2:
		if is_instance_valid(_presentation) and _presentation.is_low_poly_theater_visible():
			return _presentation.theater_world_to_local(world)
		var rect := _map_rect()
		return rect.position + (world - MAP_WORLD.position) / MAP_WORLD.size * rect.size

	func _ground_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0c2028")
		style.border_color = Color("295461")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		return style

	func _dict(value: Variant) -> Dictionary:
		return value if value is Dictionary else {}

	func _array(value: Variant) -> Array:
		return value if value is Array else []

	func _point(id: StringName) -> Dictionary:
		return _dict(_dict(model.get("points", {})).get(id, {}))

	func _vec(value: Variant) -> Vector2:
		if value is Vector2:
			return value
		if value is Vector2i:
			return Vector2(value)
		if value is Array and value.size() >= 2:
			return Vector2(float(value[0]), float(value[1]))
		if value is Dictionary:
			return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
		return Vector2.ZERO
