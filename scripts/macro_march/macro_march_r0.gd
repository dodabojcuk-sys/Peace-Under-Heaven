class_name MacroMarchR0
extends Control


signal return_to_city_requested

const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const ARMY_REGISTRY = preload("res://scripts/army/army_registry.gd")
const MAP_CANVAS = preload("res://scripts/macro_march/macro_march_map_canvas.gd")
const LOW_POLY_PRESENTATION = preload("res://scripts/macro_march/macro_march_low_poly_presentation.gd")

const CAMERA_MIN_ZOOM := 0.48
const CAMERA_MAX_ZOOM := 2.4
const CAMERA_ZOOM_STEP := 1.18
const OBLIQUE_X_SKEW := 0.20
const OBLIQUE_Y_SCALE := 0.72
const DRAW_HOLD_SECONDS := 0.50
const DRAW_HOLD_JITTER_PIXELS := 8.0
const DRAW_HOLD_PROMPT := "按住 %0.1f 秒后拖动规划%s；轻点仅选择。"
const DRAW_ACTIVE_PROMPT := "正在规划%s；松手后查看草稿。"
const ROAD_CHOICE_RADIUS_PIXELS := 12.0
const ENGINEERING_SAMPLE_SPACING_WORLD := 3.0
const DRAW_EDGE_SCROLL_MARGIN := 28.0
const DRAW_EDGE_SCROLL_MAX_PIXELS_PER_SECOND := 360.0

var _dispatch_adapter: V5ArmyDispatchAdapter
var _draft_route: Dictionary = {}
var _engineering_draft: Dictionary = {}
var _engineering_planned_points: Array[Vector2] = []
var _engineering_strokes: Array[Array] = []
var _engineering_live_endpoint := Vector2.INF
var _selected_formation_ids: Array[StringName] = []
var _draw_points: Array[Vector2] = []
var _is_drawing := false
var _draw_hold_pending := false
var _draw_hold_elapsed := 0.0
var _draw_hold_start_screen := Vector2.ZERO
var _draw_cursor_screen := Vector2.ZERO
var _draw_press_screen := Vector2.ZERO
var _draw_previous_screen := Vector2.ZERO
var _draw_source_point_id: StringName = &""
var _selected_route_road_id: StringName = &""
var _draw_preview_route: Dictionary = {}
var _draw_preview_error := ""
var _engineering_mode := false
var _engineering_engineer_id: StringName = &""
var _engineering_source_point_id: StringName = &""
var _scout_target_mode := false
var _selected_scout_id: StringName = &""
var _selected_specialist_id: StringName = &""
var _selected_army_id: StringName = &""
var _selected_damaged_road_id: StringName = &""
var _selected_interrupted_project_id: StringName = &""
var _last_army_hit_position := Vector2.INF
var _army_hit_cycle_index := 0
var _last_specialist_hit_position := Vector2.INF
var _specialist_hit_cycle_index := 0
var _formation_buttons: Array[Button] = []
var _formation_signature := ""
# Start on the authored playable segment (gate, river and forest garrison),
# while retaining the same pan/zoom transform for all command input.
var _camera_center := Vector2(750, 490)
var _camera_zoom := 0.50
var _is_panning := false
var _last_pan_position := Vector2.ZERO

var _title_label := Label.new()
var _map_canvas := MAP_CANVAS.new()
var _low_poly_presentation := LOW_POLY_PRESENTATION.new()
var _low_poly_enabled := true
var _legend_label := Label.new()
var _status_label := Label.new()
var _detail_label := Label.new()
var _specialist_status_label := Label.new()
var _formation_scroll := ScrollContainer.new()
var _formation_list := VBoxContainer.new()
var _confirm_button := Button.new()
var _block_button := Button.new()
var _recover_button := Button.new()
var _retreat_button := Button.new()
var _scout_button := Button.new()
var _engineer_button := Button.new()
var _side_road_button := Button.new()
var _resume_project_button := Button.new()
var _interrupted_project_selector := OptionButton.new()
var _return_button := Button.new()
var _presentation_toggle_button := Button.new()
var _overview_button := Button.new()
var _focus_subject_button := Button.new()
var _restore_default_route_button := Button.new()
var _engineering_undo_button := Button.new()
var _engineering_clear_button := Button.new()
var _interrupted_project_selector_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_build_ui()
	resized.connect(_layout_ui)
	refresh()


func configure(dispatch_adapter: V5ArmyDispatchAdapter) -> bool:
	if dispatch_adapter == null:
		return false
	if _dispatch_adapter != null and _dispatch_adapter != dispatch_adapter:
		return false
	_dispatch_adapter = dispatch_adapter
	refresh()
	return true


func refresh() -> void:
	if not is_node_ready():
		return
	var model := _model()
	var army := _selected_army(model)
	_refresh_formation_controls(Array(model.get("formations", [])), army, Array(model.get("armies", [])))
	_refresh_copy(model, army)
	_layout_ui()
	_sync_low_poly_presentation(model)
	queue_redraw()
	_map_canvas.queue_redraw()


func _process(delta: float) -> void:
	# World time belongs to ConstructionController.  This view is presentation
	# only, so changing map frame rate or observing two armies cannot tick them
	# twice.
	refresh()
	_update_draw_interaction(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_draw_interaction("窗口失去焦点，已取消当前规划。")


func _build_ui() -> void:
	_low_poly_presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_poly_presentation.z_index = 0
	add_child(_low_poly_presentation)
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.clip_contents = true
	_map_canvas.z_index = 1
	_map_canvas.renderer = _draw_map_canvas
	add_child(_map_canvas)
	for label in [_title_label, _status_label, _detail_label, _specialist_status_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("f6e5ba"))
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color("f4f0df"))
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Color("3e3428"))
	_specialist_status_label.add_theme_font_size_override("font_size", 13)
	_specialist_status_label.add_theme_color_override("font_color", Color("31505a"))
	_legend_label.text = "滚轮缩放 · 中键拖动 · 小地图定位 · 金主道/青道路/紫桥/灰受损 · 蓝侦/橙工 · 红巡逻/褐旧情报"
	_legend_label.add_theme_font_size_override("font_size", 12)
	_legend_label.add_theme_color_override("font_color", Color("e3dcc5"))
	_legend_label.clip_text = true
	_legend_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_legend_label)
	_formation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_formation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_formation_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_formation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_scroll.add_child(_formation_list)
	add_child(_formation_scroll)
	for button in [_confirm_button, _block_button, _recover_button, _retreat_button, _scout_button, _engineer_button, _side_road_button, _resume_project_button, _restore_default_route_button, _engineering_undo_button, _engineering_clear_button, _return_button, _presentation_toggle_button, _overview_button, _focus_subject_button]:
		button.focus_mode = Control.FOCUS_ALL
		add_child(button)
	_interrupted_project_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_interrupted_project_selector)
	_confirm_button.text = "确认并锁定军令"
	_block_button.visible = false
	_recover_button.visible = false
	_retreat_button.text = "撤逃并沿原路返回"
	_scout_button.text = "派遣侦察兵（4 粮）"
	_engineer_button.text = "派遣工程师（8 粮）"
	_side_road_button.text = "工程师拖线修路"
	_resume_project_button.text = "补派工程师接续所选工程"
	_restore_default_route_button.text = "恢复默认路线"
	_restore_default_route_button.visible = false
	_engineering_undo_button.text = "撤销上一段施工"
	_engineering_clear_button.text = "清除工程草稿"
	_engineering_undo_button.visible = false
	_engineering_clear_button.visible = false
	_resume_project_button.visible = false
	_interrupted_project_selector.visible = false
	_return_button.text = "返回黑石城"
	_presentation_toggle_button.text = "切换为二维战区"
	_overview_button.text = "全图复位"
	_focus_subject_button.text = "聚焦选中"
	_confirm_button.pressed.connect(_confirm_draft)
	_retreat_button.pressed.connect(_request_retreat)
	_scout_button.pressed.connect(_dispatch_scout)
	_engineer_button.pressed.connect(_dispatch_engineer)
	_side_road_button.pressed.connect(_build_side_road)
	_resume_project_button.pressed.connect(_resume_selected_interrupted_project)
	_interrupted_project_selector.item_selected.connect(_select_interrupted_project)
	_return_button.pressed.connect(func():
		_cancel_draw_interaction("")
		return_to_city_requested.emit()
	)
	_presentation_toggle_button.pressed.connect(_toggle_low_poly_presentation)
	_overview_button.pressed.connect(_reset_camera_overview)
	_focus_subject_button.pressed.connect(_focus_selected_subject)
	_restore_default_route_button.pressed.connect(_restore_default_route)
	_engineering_undo_button.pressed.connect(_undo_engineering_draft)
	_engineering_clear_button.pressed.connect(_clear_engineering_draft)


func _layout_ui() -> void:
	var panel_rect := _side_panel_rect()
	var action_height := 34.0
	var action_gap := 4.0
	var action_buttons: Array[Button] = [_confirm_button, _restore_default_route_button, _engineering_undo_button, _engineering_clear_button, _retreat_button, _scout_button, _engineer_button, _side_road_button, _resume_project_button, _return_button]
	var visible_action_buttons: Array[Button] = []
	for button in action_buttons:
		if button.visible:
			visible_action_buttons.append(button)
	var action_count := maxi(visible_action_buttons.size(), 1)
	var action_top := maxf(panel_rect.position.y + 276.0, size.y - 16.0 - action_height * action_count - action_gap * (action_count - 1))
	var panel_inner := Rect2(panel_rect.position + Vector2(14, 12), panel_rect.size - Vector2(28, 24))
	var map_rect := _map_rect()
	_map_canvas.position = map_rect.position
	_map_canvas.size = map_rect.size
	_low_poly_presentation.position = map_rect.position
	_low_poly_presentation.size = map_rect.size
	_presentation_toggle_button.position = map_rect.position + Vector2(12.0, map_rect.size.y - 42.0)
	_presentation_toggle_button.size = Vector2(132.0, 30.0)
	_presentation_toggle_button.visible = _low_poly_available()
	_overview_button.position = _presentation_toggle_button.position + Vector2(140.0, 0.0)
	_overview_button.size = Vector2(92.0, 30.0)
	_focus_subject_button.position = _overview_button.position + Vector2(100.0, 0.0)
	_focus_subject_button.size = Vector2(96.0, 30.0)
	_focus_subject_button.visible = not _selected_army(_model()).is_empty() or _selected_specialist_id != &""
	_legend_label.position = Vector2(map_rect.position.x, map_rect.end.y + 2.0)
	_legend_label.size = Vector2(map_rect.size.x, 20.0)
	_title_label.position = Vector2(22, 12)
	_title_label.size = Vector2(size.x - 44, 34)
	_status_label.position = Vector2(22, 48)
	_status_label.size = Vector2(size.x - 44, 36)
	_detail_label.position = panel_inner.position
	_detail_label.size = Vector2(panel_inner.size.x, 132)
	_specialist_status_label.position = panel_inner.position + Vector2(0, 136)
	_specialist_status_label.size = Vector2(panel_inner.size.x, 38)
	_formation_scroll.position = panel_inner.position + Vector2(0, 178)
	_formation_scroll.size = Vector2(panel_inner.size.x, maxf(68.0, action_top - _formation_scroll.position.y - 42.0))
	_interrupted_project_selector.position = Vector2(panel_inner.position.x, action_top - 36.0)
	_interrupted_project_selector.size = Vector2(panel_inner.size.x, 30.0)
	for button in _formation_buttons:
		button.custom_minimum_size = Vector2(panel_inner.size.x - 10.0, 38)
	for index in visible_action_buttons.size():
		var button := visible_action_buttons[index]
		button.position = Vector2(panel_inner.position.x, action_top + index * (action_height + action_gap))
		button.size = Vector2(panel_inner.size.x, action_height)
	_block_button.position = Vector2(panel_inner.position.x, action_top)
	_block_button.size = Vector2(panel_inner.size.x, action_height)
	_recover_button.position = Vector2(panel_inner.position.x, action_top + action_height + action_gap)
	_recover_button.size = Vector2(panel_inner.size.x, action_height)


func _refresh_formation_controls(formations: Array, army: Dictionary, armies: Array) -> void:
	var signature_parts: Array[String] = [str(not army.is_empty()), str(bool(_model().get("can_issue_from_city", false)))]
	var deployed_members := _deployed_members_by_formation(armies)
	for formation_value in formations:
		var formation: Dictionary = formation_value
		var formation_id := StringName(formation.get("formation_id", &""))
		signature_parts.append("%s:%d:%d" % [String(formation_id), int(formation.get("member_count", 0)), int(deployed_members.get(formation_id, 0))])
	var next_signature := "|".join(signature_parts)
	if next_signature == _formation_signature:
		for button in _formation_buttons:
			var formation_id := StringName(button.get_meta("formation_id", &""))
			button.button_pressed = formation_id in _selected_formation_ids
		return
	for button in _formation_buttons:
		button.queue_free()
	_formation_buttons.clear()
	_formation_signature = next_signature
	if not army.is_empty() and not bool(_model().get("can_issue_from_city", false)):
		return
	for formation_value in formations:
		var formation: Dictionary = formation_value
		var formation_id := StringName(formation.formation_id)
		var button := Button.new()
		var deployed_count := int(deployed_members.get(formation_id, 0))
		button.text = "%s · 已出征（当前 %d 人）" % [str(formation.display_name), deployed_count] if deployed_count > 0 else "%s · %d 人" % [str(formation.display_name), int(formation.member_count)]
		button.disabled = int(formation.member_count) <= 0
		button.toggle_mode = true
		button.button_pressed = formation_id in _selected_formation_ids
		button.set_meta("formation_id", formation_id)
		button.pressed.connect(_toggle_formation.bind(formation_id))
		_formation_list.add_child(button)
		_formation_buttons.append(button)


func _deployed_members_by_formation(armies: Array) -> Dictionary:
	var deployed: Dictionary = {}
	for army_value in armies:
		var macro: Dictionary = Dictionary(Dictionary(army_value).get("macro_march", {}))
		for formation_value in Array(macro.get("formation_snapshots", [])):
			var formation: Dictionary = Dictionary(formation_value)
			var formation_id := StringName(formation.get("formation_id", &""))
			if formation_id != &"":
				deployed[formation_id] = int(deployed.get(formation_id, 0)) + int(formation.get("member_count", 0))
	return deployed


func _refresh_copy(model: Dictionary, army: Dictionary) -> void:
	_title_label.text = "%s · 军令与攻城" % THEATER.get_theater_name()
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	var specialists: Dictionary = field.get("specialists_by_id", {})
	var projects: Dictionary = field.get("projects_by_id", {})
	var visible_patrols: Dictionary = field.get("visible_patrols_by_id", {})
	var has_selected_damage := _selected_damaged_road_id != &"" and StringName(Dictionary(field.get("roads_by_id", {})).get(_selected_damaged_road_id, {}).get("state", &"")) == FieldTacticsState.ROAD_DAMAGED
	_refresh_interrupted_project_selector(model, projects)
	_refresh_selected_specialist_status(specialists, model)
	_configure_scout_action(specialists)
	_engineer_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_ENGINEER) < 1
	_side_road_button.visible = not specialists.is_empty()
	_side_road_button.disabled = not _has_idle_engineer(specialists)
	_side_road_button.text = "安排工程师维修受损道路（3 粮）" if has_selected_damage else "工程师拖线修路"
	_resume_project_button.visible = not _first_interrupted_project(projects).is_empty()
	_resume_project_button.disabled = not _has_idle_engineer(specialists)
	_restore_default_route_button.visible = not _engineering_mode and _selected_route_road_id != &""
	_restore_default_route_button.disabled = _selected_route_road_id == &""
	_engineering_undo_button.visible = not _engineering_draft.is_empty() and _engineering_planned_points.size() > 2
	_engineering_clear_button.visible = not _engineering_draft.is_empty()
	if _scout_target_mode:
		_confirm_button.visible = false
		_block_button.visible = false
		_recover_button.visible = false
		_retreat_button.visible = false
		_engineer_button.visible = false
		_side_road_button.visible = false
		_resume_project_button.visible = false
		_interrupted_project_selector.visible = false
		_scout_button.visible = true
		_scout_button.disabled = false
		_scout_button.text = "取消侦察目标选择"
		_status_label.text = "侦察目标模式：单击地图上的城池或驻点；右键或按钮取消。"
		var scout := Dictionary(specialists.get(_selected_scout_id, {}))
		_detail_label.text = "侦察兵待命\n当前位置：%s\n尚未下达移动命令；取消不会产生新的资源事务。" % _point_display_name(
			model, StringName(scout.get("current_point_id", &"")), "野外"
		)
		return
	var selected_specialist := Dictionary(specialists.get(_selected_specialist_id, {}))
	# Replanning keeps the last valid draft as a safe fallback until mouse-up,
	# but its confirmation cannot remain actionable while the live gesture is
	# resolving a replacement route. The live preview owns both map and panel.
	if _is_drawing and not _engineering_mode:
		_confirm_button.visible = false
		_block_button.visible = false
		_recover_button.visible = false
		_retreat_button.visible = false
		var live_source_id := _source_point_id(model, army)
		var live_source := _point_from_model(model, live_source_id)
		var live_target_id := StringName(_draw_preview_route.get("target_point_id", &""))
		var live_target_label := _point_display_name(model, live_target_id, "沿道路选择目标")
		_status_label.text = "正在重规划行军；松手后以当前道路草稿替换待确认路线。"
		_detail_label.text = "正在重规划军令\n起点：%s\n候选目标：%s\n当前待确认的旧路线不会在拖动中提交。" % [
			str(live_source.get("display_name", live_source_id)), live_target_label,
		]
		return
	# A selected specialist remains the current world subject while the player
	# plans an action.  The action itself owns the side panel, though: otherwise
	# its confirm button is hidden behind the specialist detail after mouse-up.
	var has_pending_command := _engineering_mode \
		or not _engineering_draft.is_empty() \
		or not _selected_formation_ids.is_empty()
	if not has_pending_command and not selected_specialist.is_empty() and bool(selected_specialist.get("alive", false)):
		_confirm_button.visible = false
		_block_button.visible = false
		_recover_button.visible = false
		_retreat_button.visible = false
		var specialist_role := _specialist_role_label(selected_specialist)
		var specialist_phase := _specialist_phase_label(selected_specialist)
		var current_name := _point_display_name(model, StringName(selected_specialist.get("current_point_id", &"")), "野外")
		var target_name := _point_display_name(model, StringName(selected_specialist.get("target_point_id", &"")), current_name)
		_status_label.text = "已选%s：%s" % [specialist_role, specialist_phase]
		_detail_label.text = "当前选择：%s\n状态：%s\n当前位置：%s\n任务目标：%s" % [specialist_role, specialist_phase, current_name, target_name]
		return
	var source_id := _source_point_id(model, army)
	var source := _point_from_model(model, source_id)
	var draft_text := "未画路线"
	if not _draft_route.is_empty():
		draft_text = "%s → %s" % [
		str(source.get("display_name", source_id)),
		str(_point_from_model(model, StringName(_draft_route.get("target_point_id", &""))).get("display_name", _draft_route.get("target_point_id", &""))),
		]
	if _engineering_mode or not _engineering_draft.is_empty():
		var draft_kind := StringName(_engineering_draft.get("road_kind", FieldTacticsState.ROAD_NORMAL))
		var draft_contains_bridge := bool(_engineering_draft.get("contains_bridge", false))
		var draft_kind_label := ("加固路" if draft_kind == FieldTacticsState.ROAD_REINFORCED else "普通路") + ("（含桥梁）" if draft_contains_bridge else "")
		var draft_cost := int(_engineering_draft.get("food_cost", 0))
		var draft_seconds := float(_engineering_draft.get("required_milliseconds", 0)) / 1000.0
		var travel_seconds := float(_engineering_draft.get("travel_milliseconds", 0)) / 1000.0
		var source_label := _point_display_name(model, StringName(_engineering_source_point_id), "待选择")
		var target_label := "新建工程驻点" if bool(_engineering_draft.get("build_camp", false)) else _point_display_name(
			model, StringName(_engineering_draft.get("target_point_id", &"")), "待选择"
		)
		_confirm_button.visible = true
		_confirm_button.text = "确认施工"
		_confirm_button.disabled = _engineering_draft.is_empty()
		_block_button.visible = false
		_recover_button.visible = false
		_retreat_button.visible = false
		_status_label.text = "工程草稿待确认；右键取消不会扣除资源。" if not _engineering_draft.is_empty() else ("工程规划：从%s直接拖动到已有驻点或新驻点位置。" % source_label if _engineering_source_point_id != &"" else "工程模式：从友方地点拖动开始规划施工。")
		var segment_summary := _engineering_segment_summary(_engineering_draft)
		_detail_label.text = "工程师施工计划\n%s → %s\n%s · %s\n到场 %0.1f 秒 · 施工 %0.1f 秒 · 粮食 %d；确认后才会扣除。" % [
			source_label, target_label, segment_summary, draft_kind_label, travel_seconds, draft_seconds, draft_cost,
		]
		return
	# An explicit city formation selection starts a new city command even when
	# another deployed army is selected for inspection.  Its draft therefore
	# must use the city-command panel rather than inheriting that army's disabled
	# confirmation state.
	if army.is_empty() or not _selected_formation_ids.is_empty():
		_status_label.text = "工程规划：从%s拖到可施工位置，确认后工程师前往施工。" % str(source.get("display_name", source_id)) if _engineering_mode else "已选部队：点击目标生成最短路线，或从出发点拖过道路点指定路线。"
		var draft_duration := _runtime_draft_duration() if not _draft_route.is_empty() else 0
		var preview := _dispatch_adapter.get_macro_march_command_preview(_selected_formation_ids) if _dispatch_adapter != null else {}
		var selected_members := int(preview.get("committed_total", _selected_formation_member_count(Array(model.get("formations", [])))))
		var estimated_food := int(preview.get("food_cost", 0))
		var food_line := "预计粮食：%d" % estimated_food
		var food_shortage := int(preview.get("food_shortage", maxi(0, estimated_food - int(model.food))))
		if food_shortage > 0:
			food_line += "（缺少 %d）" % food_shortage
		_detail_label.text = "出发点：%s\n路线：%s\n编队：%d / %d 人\n预计时长：%0.1f 秒\n%s\n已见敌情：%d · 施工：%d" % [
			str(source.get("display_name", source_id)), draft_text, _selected_formation_ids.size(), selected_members,
			float(draft_duration) / 1000.0, food_line, visible_patrols.size(), projects.size(),
		]
	else:
		var macro: Dictionary = army.macro_march
		# An active order keeps its original departure point for reporting.  The
		# target only becomes the source after arrival, when a new order may start.
		var order_source_id := StringName(macro.get("source_point_id", source_id))
		if StringName(army.get("phase", &"")) == ARMY_REGISTRY.PHASE_STATIONED:
			order_source_id = source_id
		var order_source := _point_from_model(model, order_source_id)
		var target := _point_from_model(model, StringName(macro.target_point_id))
		var phase_text := "行军中"
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
			var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
			match StringName(transfer.get("phase", &"")):
				&"TO_CAMP":
					phase_text = "受阻，正转移至驻点"
				&"TO_CAMP_BLOCKED":
					phase_text = "转移路线再次受阻"
				&"WAITING":
					phase_text = "驻点待维修"
				&"TO_RESUME":
					phase_text = "道路已修复，正返回原路线"
				&"TO_RESUME_BLOCKED":
					phase_text = "返回路线再次受阻"
				_:
					phase_text = "受阻等待"
		elif StringName(army.phase) == ARMY_REGISTRY.PHASE_STATIONED:
			phase_text = "已抵达驻扎点"
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			phase_text = "自动攻城中"
		elif StringName(army.phase) == ARMY_REGISTRY.PHASE_RETREATING:
			phase_text = "有损撤逃中"
		_status_label.text = "%s：%s → %s" % [phase_text, str(order_source.get("display_name", order_source_id)), str(target.get("display_name", macro.target_point_id))]
		var war: Dictionary = model.get("war_loop", {})
		var siege := _siege_for_army(war, StringName(army.get("army_id", &"")))
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			_detail_label.text = "城门耐久：%d\n守军：%d\n我军可战：%d\n自动先行招降，未降则攻门并清剿守军。" % [int(siege.get("gate_hp", 0)), ceili(float(int(siege.get("defender_total_hp", 0))) / maxf(float(int(siege.get("defender_hp_per_member", 1))), 1.0)), ceili(float(int(siege.get("attacker_total_hp", 0))) / maxf(float(int(siege.get("attacker_hp_per_member", 1))), 1.0))]
		else:
			var blocked_detail := ""
			if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
				var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
				var transfer_target := _point_from_model(model, StringName(transfer.get("target_point_id", &"")))
				blocked_detail = "\n受阻路段：%d；当前处置：%s%s" % [int(macro.get("blocked_segment_index", -1)) + 1, _blocked_transfer_label(StringName(transfer.get("phase", &""))), (" → %s" % str(transfer_target.get("display_name", "友方驻点"))) if StringName(transfer.get("target_point_id", &"")) != &"" else ""]
			var current_members := _army_member_count(army)
			var encounter_copy := _latest_encounter_copy(field, StringName(army.get("army_id", &"")))
			var battle_line := "最近战报：暂无"
			if not encounter_copy.is_empty():
				battle_line = "最近战报：遭遇%s，损失 %d 人，剩余 %d 人" % [str(encounter_copy.get("patrol_name", "巡逻")), int(encounter_copy.get("losses", 0)), current_members]
			_detail_label.text = "当前军队：%d 人\n原军令进度：%d%%\n粮食已扣：%d\n%s\n%s%s" % [current_members, roundi(float(macro.progress_millis) / maxf(float(macro.total_millis), 1.0) * 100.0), int(macro.food_cost), battle_line, ("工程师维修后会沿实际道路接续原军令，不再扣粮。" if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED else "到达后可从驻扎点发出下一道军令。"), blocked_detail]
		_confirm_button.disabled = true
		_block_button.visible = false
		_recover_button.visible = false
		_retreat_button.visible = StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_STATIONED:
			_confirm_button.disabled = _draft_route.is_empty()
			_confirm_button.text = "确认下一段军令"
		else:
			_confirm_button.text = "确认并锁定军令"
		return
	_confirm_button.visible = true
	_block_button.visible = false
	_recover_button.visible = false
	_retreat_button.visible = false
	# Do not use historical specialist entries here: lost specialists remain in
	# the save for evidence, but must not block a replacement dispatch.
	_configure_scout_action(specialists)
	_engineer_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_ENGINEER) < 1
	_side_road_button.visible = _has_idle_engineer(specialists)
	_confirm_button.text = "确认施工" if not _engineering_draft.is_empty() else "确认并锁定军令"
	_confirm_button.disabled = (_engineering_draft.is_empty() and (_draft_route.is_empty() or _selected_formation_ids.is_empty()))


func _toggle_formation(formation_id: StringName) -> void:
	if formation_id in _selected_formation_ids:
		_selected_formation_ids.erase(formation_id)
	else:
		_selected_formation_ids.append(formation_id)
	# A formation button is an explicit intent to command city troops.  Clear
	# only the view selection so it cannot obscure the route draft; the
	# specialist's actual field task and position stay in FieldTacticsState.
	if not _selected_formation_ids.is_empty():
		_selected_specialist_id = &""
		_selected_scout_id = &""
	_reset_march_draft()
	refresh()


func _selected_formation_member_count(formations: Array) -> int:
	var total := 0
	for formation_value in formations:
		var formation: Dictionary = formation_value
		if StringName(formation.get("formation_id", &"")) in _selected_formation_ids:
			total += int(formation.get("member_count", 0))
	return total


func _army_member_count(army: Dictionary) -> int:
	var total := 0
	for formation_value in Array(Dictionary(army.get("macro_march", {})).get("formation_snapshots", [])):
		total += int(Dictionary(formation_value).get("member_count", 0))
	return total


func _latest_encounter_copy(field: Dictionary, army_id: StringName) -> Dictionary:
	var latest: Dictionary = {}
	for patrol_value in Dictionary(field.get("visible_patrols_by_id", {})).values():
		var patrol: Dictionary = Dictionary(patrol_value)
		var encounter: Dictionary = Dictionary(patrol.get("last_engagement", {}))
		if encounter.is_empty() or army_id not in Array(encounter.get("army_ids", [])):
			continue
		var losses := 0
		var losses_by_army: Dictionary = Dictionary(encounter.get("formation_losses_by_army", {}))
		var formation_losses: Dictionary = Dictionary(losses_by_army.get(army_id, {}))
		for formation_loss in formation_losses.values():
			losses += int(formation_loss)
		if latest.is_empty() or int(encounter.get("world_milliseconds", 0)) > int(latest.get("world_milliseconds", -1)):
			latest = {
				"world_milliseconds": int(encounter.get("world_milliseconds", 0)),
				"losses": losses,
				"patrol_name": str(patrol.get("display_name", "巡逻")),
			}
	return latest


func _count_available_specialists(specialists: Dictionary, role: StringName) -> int:
	var count := 0
	for specialist_value in specialists.values():
		var specialist: Dictionary = specialist_value
		if StringName(specialist.get("role", &"")) == role and bool(specialist.get("alive", false)):
			count += 1
	return count


func _has_idle_engineer(specialists: Dictionary) -> bool:
	for specialist_value in specialists.values():
		var specialist: Dictionary = specialist_value
		if (
			StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_ENGINEER
			and bool(specialist.get("alive", false))
			and StringName(specialist.get("project_id", &"")) == &""
		):
			return true
	return false


func _idle_specialist_id(specialists: Dictionary, role: StringName) -> StringName:
	var ids: Array = specialists.keys()
	ids.sort()
	for specialist_id_value in ids:
		var specialist: Dictionary = Dictionary(specialists[specialist_id_value])
		if (
			StringName(specialist.get("role", &"")) == role
			and bool(specialist.get("alive", false))
			and StringName(specialist.get("phase", &"")) == FieldTacticsState.SPECIALIST_IDLE
			and StringName(specialist.get("project_id", &"")) == &""
		):
			return StringName(specialist_id_value)
	return &""


func _configure_scout_action(specialists: Dictionary) -> void:
	var idle_scout_id := _idle_specialist_id(specialists, FieldTacticsState.SPECIALIST_SCOUT)
	var alive_scout_count := _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_SCOUT)
	_scout_button.visible = idle_scout_id != &"" or alive_scout_count == 0
	_scout_button.disabled = false
	_scout_button.text = "安排侦察目标" if idle_scout_id != &"" else "派遣侦察兵（4 粮）"


func _first_interrupted_project(projects: Dictionary) -> Dictionary:
	var selected_id := &""
	for project_id_value in projects:
		var project: Dictionary = Dictionary(projects[project_id_value])
		if StringName(project.get("phase", &"")) != &"INTERRUPTED":
			continue
		var project_id := StringName(project_id_value)
		if selected_id == &"" or String(project_id) < String(selected_id):
			selected_id = project_id
	return Dictionary(projects.get(selected_id, {}))


func _refresh_interrupted_project_selector(model: Dictionary, projects: Dictionary) -> void:
	var project_ids: Array[StringName] = []
	for project_id_value in projects:
		var project: Dictionary = Dictionary(projects[project_id_value])
		if StringName(project.get("phase", &"")) == &"INTERRUPTED":
			project_ids.append(StringName(project_id_value))
	project_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	_interrupted_project_selector.visible = not project_ids.is_empty()
	if project_ids.is_empty():
		_selected_interrupted_project_id = &""
		_interrupted_project_selector_signature = ""
		_interrupted_project_selector.clear()
		return
	if _selected_interrupted_project_id not in project_ids:
		_selected_interrupted_project_id = project_ids.front()
	var items: Array[Dictionary] = []
	var signature_parts: Array[String] = []
	for project_id in project_ids:
		var project: Dictionary = Dictionary(projects[project_id])
		var progress := int(project.get("progress_milliseconds", 0))
		var required := maxi(int(project.get("required_milliseconds", 1)), 1)
		var source := _point_from_model(model, StringName(project.get("source_point_id", &"")))
		var target := _point_from_model(model, StringName(project.get("target_point_id", &"")))
		var label := "%s → %s · 中断 · %d%%" % [
			str(source.get("display_name", "施工现场")),
			str(target.get("display_name", "施工前沿")),
			roundi(float(progress) * 100.0 / float(required)),
		]
		items.append({"project_id": project_id, "label": label})
		signature_parts.append("%s:%s" % [String(project_id), label])
	var signature := "|".join(signature_parts)
	if signature != _interrupted_project_selector_signature:
		_interrupted_project_selector.clear()
		for item in items:
			_interrupted_project_selector.add_item(str(item.label))
			_interrupted_project_selector.set_item_metadata(_interrupted_project_selector.item_count - 1, item.project_id)
		_interrupted_project_selector_signature = signature
	for item_index in _interrupted_project_selector.item_count:
		if StringName(_interrupted_project_selector.get_item_metadata(item_index)) == _selected_interrupted_project_id:
			if _interrupted_project_selector.selected != item_index:
				_interrupted_project_selector.select(item_index)
			break


func _select_interrupted_project(index: int) -> void:
	_selected_interrupted_project_id = StringName(_interrupted_project_selector.get_item_metadata(index))
	_status_label.text = "已选中中断工程；选择空闲工程师后可接续。"


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_panning = event.pressed
		_last_pan_position = event.position
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _map_rect().has_point(event.position):
			var zoom_factor := CAMERA_ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / CAMERA_ZOOM_STEP
			_zoom_at_screen_position(event.position, _camera_zoom * zoom_factor)
			accept_event()
		return
	if event is InputEventMouseMotion:
		if _is_panning:
			_pan_by_screen_delta(event.position - _last_pan_position)
			_last_pan_position = event.position
			accept_event()
			return
		if _draw_hold_pending:
			_draw_cursor_screen = event.position
			_draw_previous_screen = event.position
			if event.position.distance_to(_draw_press_screen) >= DRAW_HOLD_JITTER_PIXELS:
				_cancel_draw_interaction(_draw_hold_prompt() + "移动过早已取消本次操作。")
			accept_event()
			return
		if _is_drawing:
			if not _engineering_mode:
				_update_selected_road_from_sweep(_draw_previous_screen, event.position)
			_append_draw_point(event.position)
			_draw_cursor_screen = event.position
			_draw_previous_screen = event.position
			_update_march_draw_preview()
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _draw_hold_pending or _is_drawing or _scout_target_mode or not _draft_route.is_empty() or not _engineering_draft.is_empty() or not _draw_points.is_empty() or _selected_damaged_road_id != &"" or _selected_specialist_id != &"":
			var had_specialist_selection := _selected_specialist_id != &""
			var had_scout_target_mode := _scout_target_mode
			_cancel_draw_interaction("")
			_scout_target_mode = false
			if had_specialist_selection or had_scout_target_mode:
				_selected_specialist_id = &""
				_selected_scout_id = &""
			_draft_route = {}
			_engineering_draft = {}
			_engineering_mode = false
			_engineering_engineer_id = &""
			_engineering_source_point_id = &""
			_engineering_planned_points.clear()
			_engineering_strokes.clear()
			_selected_damaged_road_id = &""
			_selected_route_road_id = &""
			_status_label.text = "已取消当前专员选择；没有资源、编队或军令写入。" if had_specialist_selection else "路线草稿已取消；没有资源、编队或军令写入。"
			refresh()
			accept_event()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var map_rect := _map_rect()
	if event.pressed:
		if not map_rect.has_point(event.position):
			return
		if _minimap_rect().has_point(event.position):
			_center_camera_from_minimap(event.position)
			accept_event()
			return
		if _scout_target_mode:
			var target_id := _point_id_at_screen(event.position)
			if target_id == &"":
				_status_label.text = "请选择地图上的城池或驻点作为侦察目标。"
				return
			var scout_result := _dispatch_adapter.order_field_specialist_move(_selected_scout_id, target_id)
			if not bool(scout_result.get("success", false)):
				_status_label.text = str(scout_result.get("error", "侦察目标无法到达"))
				return
			_scout_target_mode = false
			_status_label.text = "侦察目标已确认；侦察兵正在移动。"
			refresh()
			accept_event()
			return
		if _engineering_mode and _engineering_source_point_id == &"":
			var engineering_source := _point_id_at_screen(event.position)
			if not _is_legal_engineering_source(engineering_source):
				_status_label.text = "请选择友方城池或已建驻点作为施工起点。"
				return
			_engineering_source_point_id = engineering_source
			_begin_draw_interaction(event.position, engineering_source)
			accept_event()
			return
		if _engineering_mode:
			# A confirmed endpoint can itself be a legal camp. Prefer continuing the
			# existing project at that visible endpoint before treating the same click
			# as a request to replace the project source.
			if not _engineering_draft.is_empty():
				var existing_points: Array = Array(_engineering_draft.get("route_world_points", []))
				if not existing_points.is_empty() and event.position.distance_to(_world_to_screen(Vector2(existing_points.back()))) <= 52.0:
					_begin_draw_interaction(event.position, _engineering_source_point_id)
					_draw_points = [Vector2(existing_points.back())]
					_engineering_live_endpoint = Vector2(existing_points.back())
					accept_event()
					return
			var clicked_engineering_source := _point_id_at_screen(event.position)
			if _is_legal_engineering_source(clicked_engineering_source) and clicked_engineering_source != _engineering_source_point_id:
				_engineering_source_point_id = clicked_engineering_source
				_engineering_draft = {}
				_engineering_planned_points.clear()
				_engineering_strokes.clear()
				_begin_draw_interaction(event.position, clicked_engineering_source)
				accept_event()
				return
			var engineering_source := _point_from_model(_model(), _engineering_source_point_id)
			var engineering_source_position := _world_to_screen(Vector2(engineering_source.get("world_position", Vector2.ZERO)))
			if event.position.distance_to(engineering_source_position) > 52.0:
				_status_label.text = "请从施工起点开始规划。"
				return
			_begin_draw_interaction(event.position, _engineering_source_point_id)
			accept_event()
			return
		var command_army := _selected_army(_model())
		var has_explicit_command_subject := _has_explicit_command_subject(_model(), command_army)
		# A specialist at a city or camp stays selectable even when a stationed
		# army at the same anchor is eligible to begin a route draft. An explicit
		# formation selection is already an intentional city-command mode, so it
		# remains the one case that starts the confirmed formation's route instead.
		var specialist_id := _specialist_id_at_screen(_dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}, event.position)
		if not _selected_formation_ids.is_empty():
			specialist_id = &""
		if specialist_id != &"" and specialist_id != _selected_specialist_id:
			var selected_specialist := Dictionary(_dispatch_adapter.get_field_tactics_read_model().get("specialists_by_id", {}).get(specialist_id, {}))
			# Changing to a specialist changes only the command view. Keep their
			# field task intact, but discard an unconfirmed stationed-army draft so
			# its route and confirm button cannot survive into this new operation.
			_reset_march_draft()
			_selected_army_id = &""
			_selected_specialist_id = specialist_id
			_selected_formation_ids.clear()
			if StringName(selected_specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT:
				_selected_scout_id = specialist_id
			else:
				_selected_scout_id = &""
			_status_label.text = "已选中%s；右栏操作将优先作用于该专家。" % ("侦察兵" if StringName(selected_specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else "工程师")
			refresh()
			accept_event()
			return
		if has_explicit_command_subject:
			var command_source_id := _source_point_id(_model(), command_army)
			var direct_target_id := _point_id_at_screen(event.position)
			if direct_target_id != &"" and direct_target_id != command_source_id:
				_create_march_draft_with_constraint(command_source_id, direct_target_id, &"")
				accept_event()
				return
		if has_explicit_command_subject:
			var command_source := _point_from_model(_model(), _source_point_id(_model(), command_army))
			var command_source_position := _world_to_screen(Vector2(command_source.get("world_position", Vector2.ZERO)))
			if event.position.distance_to(command_source_position) <= 52.0:
				_begin_draw_interaction(event.position, _source_point_id(_model(), command_army))
				accept_event()
				return
		var damaged_road_id := _damaged_road_id_at_screen(_dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}, event.position)
		if damaged_road_id != &"":
			_selected_damaged_road_id = damaged_road_id
			_status_label.text = "已选中受损道路；可安排空闲工程师前往维修。"
			refresh()
			accept_event()
			return
		var selected_id := _army_id_at_screen(_model(), event.position)
		if selected_id != &"":
			_reset_march_draft()
			_selected_army_id = selected_id
			_selected_specialist_id = &""
			_selected_formation_ids.clear()
			_status_label.text = "已选中该军队；续令、撤逃与路线草稿只作用于它。"
			refresh()
			accept_event()
			return
		if not _can_draw_route():
			_status_label.text = "请先在右栏选择城内编队或驻扎军队。"
			return
	else:
		if _draw_hold_pending:
			_cancel_draw_interaction("已保持当前选择；拖动超过 8 像素即可开始规划。")
			accept_event()
			return
		if not _is_drawing:
			return
		_is_drawing = false
		_append_draw_point(event.position)
		_draw_preview_route = {}
		_draw_preview_error = ""
		_finish_draw()
		accept_event()


func _append_draw_point(screen_position: Vector2) -> void:
	var world := _screen_to_world(screen_position)
	if not _engineering_mode:
		if _draw_points.is_empty():
			_draw_points = [world]
		elif _draw_points.size() == 1:
			_draw_points.append(world)
		else:
			_draw_points[_draw_points.size() - 1] = world
		queue_redraw()
		_map_canvas.queue_redraw()
		return
	# An engineering stroke has two distinct facts: committed bend samples and a
	# live endpoint. Replacing the last committed sample on every tiny movement
	# used to erase slow turns (and occasionally the source itself).
	_engineering_live_endpoint = world
	if _draw_points.is_empty() or _draw_points.back().distance_to(world) >= ENGINEERING_SAMPLE_SPACING_WORLD:
		_draw_points.append(world)
	queue_redraw()
	_map_canvas.queue_redraw()


func _begin_draw_interaction(screen_position: Vector2, source_point_id: StringName) -> void:
	_cancel_draw_interaction("")
	_draw_hold_pending = true
	_draw_hold_elapsed = 0.0
	_draw_hold_start_screen = screen_position
	_draw_press_screen = screen_position
	_draw_previous_screen = screen_position
	_draw_cursor_screen = screen_position
	_draw_source_point_id = source_point_id
	var source := _point_from_model(_model(), source_point_id)
	_draw_points = [Vector2(source.get("world_position", _screen_to_world(screen_position)))]
	_engineering_live_endpoint = Vector2(_draw_points.front())
	_status_label.text = _draw_hold_prompt()
	queue_redraw()
	_map_canvas.queue_redraw()


func _update_draw_interaction(delta: float) -> void:
	if _draw_hold_pending:
		_draw_hold_elapsed += maxf(delta, 0.0)
		if _draw_hold_elapsed >= DRAW_HOLD_SECONDS:
			_draw_hold_pending = false
			_is_drawing = true
			_append_draw_point(_draw_cursor_screen)
			if not _engineering_mode:
				_update_march_draw_preview()
			_status_label.text = _draw_active_prompt()
			queue_redraw()
			_map_canvas.queue_redraw()
	if _is_drawing:
		_pan_while_drawing(_draw_cursor_screen, delta)


func _cancel_draw_interaction(message: String) -> void:
	var had_interaction := _draw_hold_pending or _is_drawing or not _draw_points.is_empty()
	_draw_hold_pending = false
	_draw_hold_elapsed = 0.0
	_draw_hold_start_screen = Vector2.ZERO
	_draw_press_screen = Vector2.ZERO
	_draw_previous_screen = Vector2.ZERO
	_draw_cursor_screen = Vector2.ZERO
	_draw_source_point_id = &""
	_is_drawing = false
	_draw_points.clear()
	_draw_preview_route = {}
	_draw_preview_error = ""
	_engineering_live_endpoint = Vector2.INF
	if had_interaction and not message.is_empty():
		_status_label.text = message
	queue_redraw()
	_map_canvas.queue_redraw()


func _draw_plan_label() -> String:
	return "施工" if _engineering_mode else "行军"


func _draw_hold_prompt() -> String:
	return DRAW_HOLD_PROMPT % [DRAW_HOLD_SECONDS, _draw_plan_label()]


func _draw_active_prompt() -> String:
	return DRAW_ACTIVE_PROMPT % _draw_plan_label()


func _update_march_draw_preview() -> void:
	_draw_preview_route = {}
	_draw_preview_error = ""
	if _engineering_mode:
		_update_engineering_draw_preview()
		return
	var model := _model()
	var source_id := _draw_source_point_id
	var target_id := _nearest_target_at_draw_end(source_id)
	if target_id == &"":
		_draw_preview_error = "请选择城池或已建驻点"
		return
	var decision := _choose_runtime_route(model, source_id, target_id)
	if bool(decision.get("valid", false)):
		_draw_preview_route = _ui_route_draft(Dictionary(decision.get("route", {})))
	else:
		_draw_preview_error = str(decision.get("error", "路线不可用"))


func _update_engineering_draw_preview() -> void:
	if _engineering_engineer_id == &"" or _engineering_source_point_id == &"" or _draw_points.size() < 2:
		return
	var model := _model()
	var source_id := _engineering_source_point_id
	var live_end := _engineering_live_endpoint if _engineering_live_endpoint != Vector2.INF else Vector2(_draw_points.back())
	var target_id := _nearest_engineering_target_for_world(live_end, source_id)
	var route_points := _engineering_route_points_with_live_stroke()
	if route_points.size() < 2:
		return
	route_points[0] = Vector2(_point_from_model(model, source_id).get("world_position", route_points[0]))
	if target_id != &"":
		route_points[route_points.size() - 1] = Vector2(_point_from_model(model, target_id).get("world_position", route_points.back()))
	var preview := _dispatch_adapter.preview_field_road_project(
		_engineering_engineer_id, source_id, target_id, route_points, FieldTacticsState.ROAD_NORMAL, target_id == &""
	)
	if bool(preview.get("valid", false)):
		_draw_preview_route = preview.duplicate(true)
		_draw_preview_route.requested_target_point_id = target_id
	else:
		_draw_preview_error = str(preview.get("error", "工程路线无法施工"))


func _is_near_open_road(screen_position: Vector2) -> bool:
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	for road_value in Dictionary(field.get("roads_by_id", {})).values():
		var road: Dictionary = Dictionary(road_value)
		if StringName(road.get("state", &"")) != FieldTacticsState.ROAD_OPEN:
			continue
		var points: Array = Array(road.get("route_world_points", []))
		for index in range(1, points.size()):
			if _distance_to_segment(screen_position, _world_to_screen(Vector2(points[index - 1])), _world_to_screen(Vector2(points[index]))) <= 28.0:
				return true
	return false


func _zoom_at_screen_position(screen_position: Vector2, requested_zoom: float) -> void:
	var anchor_world := _screen_to_world(screen_position)
	_camera_zoom = clampf(requested_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	var projected_center := _project_world(anchor_world) - (screen_position - _map_rect().get_center()) / _camera_zoom
	_camera_center = _unproject_world(projected_center)
	_clamp_camera()
	queue_redraw()


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	_camera_center = _unproject_world(_project_world(_camera_center) - screen_delta / _camera_zoom)
	_clamp_camera()
	queue_redraw()


func _reset_camera_overview() -> void:
	_camera_center = THEATER.get_world_bounds().get_center()
	_camera_zoom = CAMERA_MIN_ZOOM
	_clamp_camera()
	_status_label.text = "已复位为战区概览；可用小地图、滚轮和中键查看局部。"
	refresh()


func _focus_selected_subject() -> void:
	var model := _model()
	if _selected_specialist_id != &"":
		var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
		var specialist := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(_selected_specialist_id, {}))
		if specialist.is_empty():
			return
		_camera_center = Vector2(specialist.get("world_position", _camera_center))
	else:
		var army := _selected_army(model)
		if army.is_empty():
			return
		var display_route := _display_route_for_army(army)
		_camera_center = _point_along_route(
			Array(display_route.get("points", [])),
			float(display_route.get("progress_millis", 0)) / maxf(float(display_route.get("total_millis", 1)), 1.0)
		)
	_camera_zoom = maxf(_camera_zoom, 0.9)
	_clamp_camera()
	_status_label.text = "镜头已聚焦选中对象；可继续绘线或用全图复位返回概览。"
	refresh()


func _pan_while_drawing(screen_position: Vector2, delta_seconds: float) -> void:
	var rect := _map_rect()
	var edge := DRAW_EDGE_SCROLL_MARGIN
	var delta := Vector2.ZERO
	if screen_position.x <= rect.position.x + edge:
		delta.x = -_edge_scroll_speed(rect.position.x + edge - screen_position.x, edge, delta_seconds)
	elif screen_position.x >= rect.end.x - edge:
		delta.x = _edge_scroll_speed(screen_position.x - (rect.end.x - edge), edge, delta_seconds)
	if screen_position.y <= rect.position.y + edge:
		delta.y = -_edge_scroll_speed(rect.position.y + edge - screen_position.y, edge, delta_seconds)
	elif screen_position.y >= rect.end.y - edge:
		delta.y = _edge_scroll_speed(screen_position.y - (rect.end.y - edge), edge, delta_seconds)
	if not delta.is_zero_approx():
		_camera_center = _unproject_world(_project_world(_camera_center) + delta / _camera_zoom)
		_clamp_camera()
		queue_redraw()
		_map_canvas.queue_redraw()


func _edge_scroll_speed(depth: float, edge: float, delta_seconds: float) -> float:
	var normalized := clampf(depth / maxf(edge, 1.0), 0.0, 1.0)
	# Smooth quadratic acceleration prevents event-rate-dependent camera jumps.
	return DRAW_EDGE_SCROLL_MAX_PIXELS_PER_SECOND * normalized * normalized * maxf(delta_seconds, 0.0)


func _finish_draw() -> void:
	var model := _model()
	var source_id := _draw_source_point_id
	if source_id == &"":
		source_id = _source_point_id(model, _selected_army(model))
	if _engineering_mode:
		_finish_engineering_draw(model, source_id)
		return
	var target_id := _nearest_target_at_draw_end(source_id)
	if target_id == &"":
		_draft_route = {}
		_draw_points.clear()
		_status_label.text = "终点必须是另一处驻扎点或可进攻的敌城。"
		queue_redraw()
		return
	_create_march_draft(source_id, target_id)


func _create_march_draft(source_id: StringName, target_id: StringName) -> void:
	_create_march_draft_with_constraint(source_id, target_id, _selected_route_road_id)


func _create_march_draft_with_constraint(source_id: StringName, target_id: StringName, required_road_id: StringName) -> void:
	var model := _model()
	if source_id == &"" or target_id == &"" or source_id == target_id:
		_status_label.text = "终点必须是另一处驻扎点或可进攻的敌城。"
		return
	_selected_route_road_id = required_road_id
	var decision := _choose_runtime_route(model, source_id, target_id)
	if not bool(decision.get("valid", false)):
		_selected_route_road_id = &""
		_draft_route = {}
		_draw_points.clear()
		_status_label.text = str(decision.get("error", "路线不可用"))
		queue_redraw()
		return
	_draft_route = _ui_route_draft(Dictionary(decision.get("route", {})))
	_draft_route.source_point_id = source_id
	_draft_route.required_road_id = required_road_id
	var preview := _dispatch_adapter.get_macro_march_command_preview(
		_selected_formation_ids, StringName(_selected_army(model).get("army_id", &"")) if _selected_formation_ids.is_empty() else &""
	) if _dispatch_adapter != null else {}
	_draft_route.food_cost = int(preview.get("food_cost", 0))
	_draw_points.clear()
	_status_label.text = "路线草稿：%s；确认后军令和粮食将锁定。" % str(_point_from_model(model, StringName(_draft_route.get("target_point_id", &""))).get("display_name", _draft_route.get("target_point_id", &"")))
	refresh()


func _finish_engineering_draw(model: Dictionary, source_id: StringName) -> void:
	if _engineering_engineer_id == &"" or _draw_points.size() < 2:
		_draw_points.clear()
		_status_label.text = "工程路线至少需要两个位置。"
		queue_redraw()
		return
	var live_end := _engineering_live_endpoint if _engineering_live_endpoint != Vector2.INF else Vector2(_draw_points.back())
	var target_id := _nearest_engineering_target_for_world(live_end, source_id)
	# Water crossing is an attribute of the physical segment plan, not the
	# player's selected land material. FieldTacticsState turns only the water
	# spans into bridges when the confirmed project is built.
	var road_kind := FieldTacticsState.ROAD_NORMAL
	var route_points := _engineering_route_points_with_live_stroke()
	if route_points.size() < 2:
		_draw_points.clear()
		_status_label.text = "工程路线至少需要两个位置。"
		return
	route_points[0] = Vector2(_point_from_model(model, source_id).get("world_position", route_points[0]))
	if target_id != &"":
		route_points[route_points.size() - 1] = Vector2(_point_from_model(model, target_id).get("world_position", route_points.back()))
	var build_camp := target_id == &""
	var preview := _dispatch_adapter.preview_field_road_project(
		_engineering_engineer_id, source_id, target_id, route_points, road_kind, build_camp
	)
	if not bool(preview.get("valid", false)):
		_draw_points.clear()
		_engineering_live_endpoint = Vector2.INF
		_status_label.text = str(preview.get("error", "工程路线无法施工"))
		refresh()
		return
	_engineering_draft = preview.duplicate(true)
	_engineering_draft.requested_target_point_id = target_id
	_record_engineering_stroke(route_points)
	_draw_points.clear()
	_engineering_live_endpoint = Vector2.INF
	_status_label.text = "工程草稿已生成：%s；确认施工才会扣除资源并派工程师前往。" % ("连接已有驻点" if not build_camp else "新建工程驻点")
	refresh()


func _engineering_route_points_with_live_stroke() -> Array[Vector2]:
	var stroke := _engineering_live_stroke_points()
	var result: Array[Vector2] = _engineering_planned_points.duplicate(true)
	for point_value in stroke:
		var point := Vector2(point_value)
		if result.is_empty() or result.back().distance_to(point) > 0.01:
			result.append(point)
	return result


func _engineering_live_stroke_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point_value in _draw_points:
		var point := Vector2(point_value)
		if result.is_empty() or result.back().distance_to(point) > 0.01:
			result.append(point)
	if _engineering_live_endpoint != Vector2.INF and (result.is_empty() or result.back().distance_to(_engineering_live_endpoint) > 0.01):
		result.append(_engineering_live_endpoint)
	return result


func _record_engineering_stroke(route_points: Array) -> void:
	var start_index := maxi(_engineering_planned_points.size() - 1, 0)
	var stroke: Array = []
	for index in range(start_index, route_points.size()):
		var point := Vector2(route_points[index])
		if stroke.is_empty() or stroke.back().distance_to(point) > 0.01:
			stroke.append(point)
	if stroke.size() >= 2:
		_engineering_strokes.append(stroke)
	_engineering_planned_points.clear()
	for point_value in route_points:
		var point := Vector2(point_value)
		if _engineering_planned_points.is_empty() or _engineering_planned_points.back().distance_to(point) > 0.01:
			_engineering_planned_points.append(point)


func _engineering_segment_summary(draft: Dictionary) -> String:
	var land_segments := 0
	var bridge_segments := 0
	for plan_value in Array(draft.get("segment_plans", [])):
		if StringName(Dictionary(plan_value).get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE:
			bridge_segments += 1
		else:
			land_segments += 1
	if bridge_segments > 0:
		return "%d 段陆路 + %d 段桥梁" % [land_segments, bridge_segments]
	return "%d 段陆路施工" % land_segments


func _confirm_draft() -> void:
	if _dispatch_adapter == null:
		return
	if not _engineering_draft.is_empty():
		var engineering := _engineering_draft.duplicate(true)
		var engineering_result := _dispatch_adapter.begin_field_road_project(
			StringName(engineering.engineer_id), StringName(engineering.source_point_id),
			StringName(engineering.get("requested_target_point_id", engineering.target_point_id)), Array(engineering.route_world_points),
			StringName(engineering.road_kind), bool(engineering.build_camp)
		)
		if not bool(engineering_result.get("success", false)):
			_status_label.text = str(engineering_result.get("error", "工程施工失败"))
			return
		_engineering_draft = {}
		_engineering_planned_points.clear()
		_engineering_strokes.clear()
		_engineering_mode = false
		_engineering_engineer_id = &""
		_engineering_source_point_id = &""
		_status_label.text = "工程军令已锁定；道路和驻点将在施工完成后开放通军。"
		refresh()
		return
	if _draft_route.is_empty():
		return
	var model := _model()
	var army := _selected_army(model)
	var result: Dictionary = {}
	if not _selected_formation_ids.is_empty() or army.is_empty():
		result = _dispatch_adapter.commit_macro_march_from_city(
			_selected_formation_ids, StringName(_draft_route.get("target_point_id", &"")),
			StringName(_draft_route.get("route_id", &"")), Array(_draft_route.get("points", []))
		)
	else:
		result = _dispatch_adapter.commit_macro_march_from_station(
			StringName(army.army_id), StringName(_draft_route.get("target_point_id", &"")),
			StringName(_draft_route.get("route_id", &"")), Array(_draft_route.get("points", []))
		)
	if not bool(result.get("success", false)):
		_status_label.text = str(result.get("error", "军令确认失败"))
		return
	_selected_army_id = StringName(Dictionary(result.get("army", {})).get("army_id", &""))
	_selected_formation_ids.clear()
	_draw_points.clear()
	_reset_march_draft()
	refresh()


func _block_branch() -> void:
	return


func _recover_branch() -> void:
	return


func _request_retreat() -> void:
	if _dispatch_adapter == null:
		return
	var army := _selected_army(_model())
	var result := _dispatch_adapter.request_macro_siege_retreat(StringName(Dictionary(army.get("macro_march", {})).get("target_point_id", &"")))
	if not bool(result.get("success", false)):
		_status_label.text = str(result.get("error", "撤逃军令失败"))
	refresh()


func _dispatch_scout() -> void:
	if _dispatch_adapter == null:
		return
	if _scout_target_mode:
		_scout_target_mode = false
		_selected_scout_id = &""
		_status_label.text = "已取消侦察目标选择；没有新增移动命令。"
		refresh()
		return
	var field := _dispatch_adapter.get_field_tactics_read_model()
	var scout_id := _idle_specialist_id(Dictionary(field.get("specialists_by_id", {})), FieldTacticsState.SPECIALIST_SCOUT)
	if scout_id == &"":
		var result := _dispatch_adapter.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
		if not bool(result.get("success", false)):
			_status_label.text = str(result.get("error", "侦察兵派遣失败"))
			refresh()
			return
		scout_id = StringName(Dictionary(result.get("specialist", {})).get("specialist_id", &""))
	_scout_target_mode = scout_id != &""
	_selected_scout_id = scout_id
	_status_label.text = "侦察兵已待命；请选择实际侦察目标。" if _scout_target_mode else "没有可安排的侦察兵。"
	refresh()


func _refresh_selected_specialist_status(specialists: Dictionary, model: Dictionary) -> void:
	var specialist_id := _selected_specialist_id if _selected_specialist_id != &"" else _selected_scout_id
	if specialist_id == &"":
		_specialist_status_label.text = "专员：未选择"
		return
	var specialist := Dictionary(specialists.get(specialist_id, {}))
	if specialist.is_empty() or not bool(specialist.get("alive", false)):
		_specialist_status_label.text = "专员：%s 已阵亡或失联，可从城市重新派遣。" % String(specialist_id)
		return
	var role_label := _specialist_role_label(specialist)
	var phase := StringName(specialist.get("phase", &""))
	var current := _point_from_model(model, StringName(specialist.get("current_point_id", &"")))
	var target := _point_from_model(model, StringName(specialist.get("target_point_id", &"")))
	if _scout_target_mode and StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT:
		_specialist_status_label.text = "%s：待命于%s，等待地图目标。" % [role_label, str(current.get("display_name", "当前位置"))]
	elif phase == FieldTacticsState.SPECIALIST_MOVING:
		_specialist_status_label.text = "%s：在途 → %s" % [role_label, str(target.get("display_name", specialist.get("target_point_id", "目标")))]
	else:
		_specialist_status_label.text = "%s：%s · %s" % [role_label, _specialist_phase_label(specialist), str(current.get("display_name", specialist.get("current_point_id", "当前位置")))]


func _specialist_role_label(specialist: Dictionary) -> String:
	return "侦察兵" if StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else "工程师"


func _specialist_phase_label(specialist: Dictionary) -> String:
	match StringName(specialist.get("phase", &"")):
		FieldTacticsState.SPECIALIST_MOVING:
			return "在途"
		FieldTacticsState.SPECIALIST_BUILDING:
			return "施工中"
		FieldTacticsState.SPECIALIST_REPAIRING:
			return "维修中"
		FieldTacticsState.SPECIALIST_BLOCKED:
			return "受阻等待"
		FieldTacticsState.SPECIALIST_LOST:
			return "已失联"
		_:
			return "待命"


func _dispatch_engineer() -> void:
	if _dispatch_adapter == null:
		return
	var result := _dispatch_adapter.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	_status_label.text = "工程师已从黑石城出发。" if bool(result.get("success", false)) else str(result.get("error", "工程师派遣失败"))
	refresh()


func _build_side_road() -> void:
	if _dispatch_adapter == null:
		return
	var field := _dispatch_adapter.get_field_tactics_read_model()
	if _selected_damaged_road_id != &"":
		for specialist_value in Dictionary(field.get("specialists_by_id", {})).values():
			var repair_engineer: Dictionary = specialist_value
			if (
				StringName(repair_engineer.get("role", &"")) == FieldTacticsState.SPECIALIST_ENGINEER
				and bool(repair_engineer.get("alive", false))
				and StringName(repair_engineer.get("project_id", &"")) == &""
			):
				var repair_result := _dispatch_adapter.begin_field_road_repair(StringName(repair_engineer.get("specialist_id", &"")), _selected_damaged_road_id)
				_status_label.text = "工程师已出发前往受损道路。" if bool(repair_result.get("success", false)) else str(repair_result.get("error", "道路维修无法安排"))
				if bool(repair_result.get("success", false)):
					_selected_damaged_road_id = &""
				refresh()
				return
		_status_label.text = "需要一名空闲且存活的工程师前往维修。"
		return
	var specialists: Dictionary = Dictionary(field.get("specialists_by_id", {}))
	var ordered_specialist_ids: Array = specialists.keys()
	ordered_specialist_ids.sort()
	if _selected_specialist_id in ordered_specialist_ids:
		ordered_specialist_ids.erase(_selected_specialist_id)
		ordered_specialist_ids.push_front(_selected_specialist_id)
	for specialist_id_value in ordered_specialist_ids:
		var specialist_value = specialists[specialist_id_value]
		var specialist: Dictionary = specialist_value
		if (
			StringName(specialist.get("role", &"")) != FieldTacticsState.SPECIALIST_ENGINEER
			or not bool(specialist.get("alive", false))
			or StringName(specialist.get("project_id", &"")) != &""
		):
			continue
		_engineering_mode = true
		_engineering_engineer_id = StringName(specialist.get("specialist_id", &""))
		var candidate_source := StringName(specialist.get("current_point_id", &""))
		_engineering_source_point_id = candidate_source if _is_legal_engineering_source(candidate_source) else &""
		_draw_points.clear()
		_engineering_planned_points.clear()
		_draft_route = {}
		_status_label.text = "工程师已选中：从%s拖动规划施工；也可从另一友方地点直接开始。" % _point_display_name(_model(), _engineering_source_point_id, "合法施工点")
		queue_redraw()
		return
	_status_label.text = "需要一名空闲且存活的工程师。"


func _resume_selected_interrupted_project() -> void:
	if _dispatch_adapter == null:
		return
	var field := _dispatch_adapter.get_field_tactics_read_model()
	var interrupted_project := Dictionary(Dictionary(field.get("projects_by_id", {})).get(_selected_interrupted_project_id, {}))
	if interrupted_project.is_empty():
		_status_label.text = "请选择一项中断工程后再补派。"
		return
	var resume_failure := ""
	for specialist_value in Dictionary(field.get("specialists_by_id", {})).values():
		var replacement_engineer: Dictionary = specialist_value
		if (
			StringName(replacement_engineer.get("role", &"")) != FieldTacticsState.SPECIALIST_ENGINEER
			or not bool(replacement_engineer.get("alive", false))
			or StringName(replacement_engineer.get("project_id", &"")) != &""
		):
			continue
		var resume_result := _dispatch_adapter.resume_interrupted_field_project(
			StringName(replacement_engineer.get("specialist_id", &"")), StringName(interrupted_project.get("project_id", &""))
		)
		if bool(resume_result.get("success", false)):
			_status_label.text = "工程师已出发接续所选中断工程。"
			refresh()
			return
		resume_failure = str(resume_result.get("error", "该工程师无法到达现场"))
	_status_label.text = resume_failure if not resume_failure.is_empty() else "需要一名空闲且存活的工程师接续所选工程。"
	refresh()


func _damaged_road_id_at_screen(field: Dictionary, screen_position: Vector2) -> StringName:
	for route_value in Dictionary(field.get("roads_by_id", {})).values():
		var route: Dictionary = route_value
		if StringName(route.get("state", &"")) != FieldTacticsState.ROAD_DAMAGED:
			continue
		var points: Array = route.get("route_world_points", [])
		for index in range(1, points.size()):
			if _distance_to_segment(screen_position, _world_to_screen(Vector2(points[index - 1])), _world_to_screen(Vector2(points[index]))) <= 14.0:
				return StringName(route.get("road_id", &""))
	return &""


func _specialist_id_at_screen(field: Dictionary, screen_position: Vector2) -> StringName:
	var specialist_ids: Array = Dictionary(field.get("specialists_by_id", {})).keys()
	specialist_ids.sort()
	var hits: Array[StringName] = []
	for specialist_id_value in specialist_ids:
		var specialist: Dictionary = Dictionary(field.specialists_by_id[specialist_id_value])
		if not bool(specialist.get("alive", false)):
			continue
		if _world_to_screen(Vector2(specialist.get("world_position", Vector2.ZERO))).distance_to(screen_position) <= 18.0:
			hits.append(StringName(specialist_id_value))
	if hits.is_empty():
		_last_specialist_hit_position = Vector2.INF
		_specialist_hit_cycle_index = 0
		return &""
	if screen_position.distance_to(_last_specialist_hit_position) <= 6.0:
		# Reserve one step after every specialist for the army beneath them.  A
		# city may contain an army, a scout, and an engineer at the same anchor;
		# none should become unreachable through normal map input.
		_specialist_hit_cycle_index = posmod(_specialist_hit_cycle_index + 1, hits.size() + 1)
	else:
		_last_specialist_hit_position = screen_position
		_specialist_hit_cycle_index = 0
	if _specialist_hit_cycle_index >= hits.size():
		return &""
	return hits[_specialist_hit_cycle_index]


func _can_draw_route() -> bool:
	var army := _selected_army(_model())
	return (
		_engineering_mode
		or
		not _selected_formation_ids.is_empty()
		or _has_explicit_command_subject(_model(), army)
	)


func _source_point_id(model: Dictionary, army: Dictionary) -> StringName:
	if _engineering_mode:
		return _engineering_source_point_id
	return (
		StringName(model.get("source_point_id", &"blackstone_city"))
		if not _selected_formation_ids.is_empty() or army.is_empty()
		else StringName(army.target_node_id)
	)


func _selected_army(model: Dictionary) -> Dictionary:
	for army_value in Array(model.get("armies", [])):
		var army: Dictionary = army_value
		if StringName(army.get("army_id", &"")) == _selected_army_id:
			return army.duplicate(true)
	var armies: Array = model.get("armies", [])
	if armies.is_empty():
		return {}
	# The first army is a read-only default for overview copy. It is not a player
	# command selection: assigning its ID here made an inspected army steal the
	# next specialist or engineering interaction.
	return Dictionary(armies.front()).duplicate(true)


func _siege_for_army(war: Dictionary, army_id: StringName) -> Dictionary:
	for siege_value in Array(war.get("sieges", [])):
		var candidate: Dictionary = siege_value
		if StringName(candidate.get("army_id", &"")) == army_id:
			return candidate.duplicate(true)
	return {}


func _army_id_at_screen(model: Dictionary, screen_position: Vector2) -> StringName:
	var hits: Array[StringName] = []
	for army_value in Array(model.get("armies", [])):
		var army: Dictionary = army_value
		var macro: Dictionary = army.get("macro_march", {})
		var display_route := _display_route_for_army(army)
		var points: Array = Array(display_route.get("points", []))
		if points.is_empty():
			continue
		var progress := float(display_route.get("progress_millis", 0)) / maxf(float(display_route.get("total_millis", 1)), 1.0)
		if _world_to_screen(_point_along_route(points, progress)).distance_to(screen_position) <= 24.0:
			hits.append(StringName(army.get("army_id", &"")))
	if hits.is_empty():
		_last_army_hit_position = Vector2.INF
		_army_hit_cycle_index = 0
		return &""
	if screen_position.distance_to(_last_army_hit_position) <= 6.0:
		_army_hit_cycle_index = posmod(_army_hit_cycle_index + 1, hits.size())
	else:
		_last_army_hit_position = screen_position
		_army_hit_cycle_index = 0
	return hits[_army_hit_cycle_index]


func _nearest_target_at_draw_end(source_id: StringName) -> StringName:
	var point_id := _point_id_at_screen(_draw_cursor_screen)
	if point_id != &"":
		return point_id if point_id != source_id else &""
	# Programmatic fixtures may exercise the same draft builder without a live
	# pointer event. Runtime input always resolves by screen hit radius above.
	if _draw_points.is_empty():
		return &""
	var end := Vector2(_draw_points.back())
	for candidate_id_value in _all_points(_model()):
		var candidate_id := StringName(candidate_id_value)
		var candidate := _point_from_model(_model(), candidate_id)
		if candidate_id != source_id and end.distance_to(Vector2(candidate.get("world_position", Vector2.ZERO))) <= 65.0:
			return candidate_id
	return &""


func _nearest_engineering_target_at_draw_end(source_id: StringName) -> StringName:
	if _draw_points.is_empty():
		return &""
	return _nearest_engineering_target_for_world(Vector2(_draw_points.back()), source_id)


func _nearest_engineering_target_for_world(end: Vector2, source_id: StringName) -> StringName:
	var nearest_id: StringName = &""
	var nearest_distance := 65.0
	for point_id_value in _all_points(_model()):
		var point_id := StringName(point_id_value)
		var point := _point_from_model(_model(), point_id)
		if point_id == source_id or StringName(point.get("point_kind", &"")) == &"ENEMY_CITY":
			continue
		var distance := end.distance_to(Vector2(point.get("world_position", Vector2.ZERO)))
		if distance <= nearest_distance:
			nearest_id = point_id
			nearest_distance = distance
	return nearest_id


func _point_id_at_screen(screen_position: Vector2) -> StringName:
	var nearest_id := &""
	var nearest_distance := 34.0
	for point_id_value in _all_points(_model()):
		var point_id := StringName(point_id_value)
		var point := _point_from_model(_model(), point_id)
		var distance := _world_to_screen(Vector2(point.get("world_position", Vector2.ZERO))).distance_to(screen_position)
		if distance <= nearest_distance:
			nearest_id = point_id
			nearest_distance = distance
	return nearest_id


func _all_points(model: Dictionary) -> Dictionary:
	var points := THEATER.get_points()
	for point_id_value in Dictionary(model.get("runtime_points", {})):
		points[StringName(point_id_value)] = Dictionary(model.runtime_points[point_id_value]).duplicate(true)
	var cities := Dictionary(Dictionary(model.get("war_loop", {})).get("cities_by_id", {}))
	for city_id_value in cities:
		var city_id := StringName(city_id_value)
		if not points.has(city_id):
			continue
		var point := Dictionary(points[city_id])
		point.military_controller_faction_id = StringName(Dictionary(cities[city_id]).get("military_controller_faction_id", &"enemy"))
		points[city_id] = point
	return points


func _blocked_transfer_label(phase: StringName) -> String:
	match phase:
		&"TO_CAMP": return "转移至驻点"
		&"TO_CAMP_BLOCKED": return "转移路线受阻"
		&"WAITING": return "驻点等待维修"
		&"TO_RESUME": return "返回原路线"
		&"TO_RESUME_BLOCKED": return "返回路线受阻"
		_: return "原地等待"


func _point_from_model(model: Dictionary, point_id: StringName) -> Dictionary:
	return Dictionary(_all_points(model).get(point_id, {})).duplicate(true)


func _choose_runtime_route(model: Dictionary, source_id: StringName, target_id: StringName) -> Dictionary:
	if _dispatch_adapter == null:
		return {"valid": false, "error": "军令服务尚未就绪"}
	var planned := _dispatch_adapter.plan_field_path(source_id, target_id, [], _selected_route_road_id)
	if not bool(planned.get("valid", false)) or Array(planned.get("points", [])).size() < 2:
		return {"valid": false, "error": str(planned.get("error", "没有连通的已完工道路路径"))}
	return {"valid": true, "route": {
		"road_id": StringName(planned.get("route_id", &"")),
		"target_point_id": target_id,
		"route_world_points": Array(planned.get("points", [])).duplicate(true),
		"segment_ids": Array(planned.get("segments", [])).duplicate(true),
		"duration_milliseconds": int(planned.get("duration_milliseconds", 0)),
	}}


func _has_explicit_command_subject(model: Dictionary, army: Dictionary) -> bool:
	return not _selected_formation_ids.is_empty() or (
		not army.is_empty()
		and StringName(army.get("army_id", &"")) == _selected_army_id
		and StringName(army.get("phase", &"")) == ARMY_REGISTRY.PHASE_STATIONED
	)


func _is_legal_engineering_source(point_id: StringName) -> bool:
	if point_id == &"":
		return false
	var point := _point_from_model(_model(), point_id)
	return not point.is_empty() and StringName(point.get("point_kind", &"")) != &"ENEMY_CITY"


func _update_selected_road_from_sweep(start_screen: Vector2, end_screen: Vector2) -> void:
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	var best_road_id: StringName = &""
	var best_distance := INF
	for choice in _road_choice_markers(Dictionary(field.get("roads_by_id", {}))):
		var marker := Vector2(choice.screen_position)
		var distance := _distance_to_segment(marker, start_screen, end_screen)
		var road_id := StringName(choice.road_id)
		if distance <= ROAD_CHOICE_RADIUS_PIXELS and (distance < best_distance - 0.01 or (is_equal_approx(distance, best_distance) and String(road_id) < String(best_road_id))):
			best_distance = distance
			best_road_id = road_id
	if best_road_id != &"" and best_road_id != _selected_route_road_id:
		_selected_route_road_id = best_road_id
		_status_label.text = "已选择道路：%s；拖到目标后会强制经过它。" % String(best_road_id)


func _screen_segment_distance(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a_start, a_end, b_start, b_end) != null:
		return 0.0
	return minf(minf(_distance_to_segment(a_start, b_start, b_end), _distance_to_segment(a_end, b_start, b_end)), minf(_distance_to_segment(b_start, a_start, a_end), _distance_to_segment(b_end, a_start, a_end)))


func _reset_march_draft() -> void:
	_draft_route = {}
	_draw_preview_route = {}
	_draw_preview_error = ""
	_selected_route_road_id = &""


func _restore_default_route() -> void:
	_selected_route_road_id = &""
	if not _draft_route.is_empty():
		_create_march_draft(_source_point_id(_model(), _selected_army(_model())), StringName(_draft_route.get("target_point_id", &"")))
	elif _is_drawing:
		_update_march_draw_preview()
	_status_label.text = "已恢复默认最短可通行路线。"
	refresh()


func _undo_engineering_draft() -> void:
	if _engineering_strokes.is_empty():
		_status_label.text = "工程草稿没有可撤销的上一段。"
		return
	_engineering_strokes.pop_back()
	_engineering_planned_points.clear()
	for stroke_value in _engineering_strokes:
		for point_value in Array(stroke_value):
			var point := Vector2(point_value)
			if _engineering_planned_points.is_empty() or _engineering_planned_points.back().distance_to(point) > 0.01:
				_engineering_planned_points.append(point)
	_rebuild_engineering_draft_from_planned_points()


func _clear_engineering_draft() -> void:
	_engineering_draft = {}
	_engineering_planned_points.clear()
	_engineering_strokes.clear()
	_draw_points.clear()
	_engineering_live_endpoint = Vector2.INF
	_status_label.text = "工程草稿已清除；尚未扣除资源。"
	refresh()


func _rebuild_engineering_draft_from_planned_points() -> void:
	if _engineering_planned_points.size() < 2 or _engineering_engineer_id == &"" or _engineering_source_point_id == &"":
		_clear_engineering_draft()
		return
	var target_id := _nearest_engineering_target_for_world(Vector2(_engineering_planned_points.back()), _engineering_source_point_id)
	var preview := _dispatch_adapter.preview_field_road_project(
		_engineering_engineer_id, _engineering_source_point_id, target_id, _engineering_planned_points, FieldTacticsState.ROAD_NORMAL, target_id == &""
	)
	if not bool(preview.get("valid", false)):
		_status_label.text = str(preview.get("error", "撤销后的工程路线无效"))
		return
	_engineering_draft = preview.duplicate(true)
	_engineering_draft.requested_target_point_id = target_id
	_status_label.text = "已撤销上一段施工；工程草稿仍未提交。"
	refresh()


func _ui_route_draft(route: Dictionary) -> Dictionary:
	# Map drafts deliberately use their own stable UI contract.  Runtime roads
	# use road_id/route_world_points, while authored roads formerly used
	# route_id/points; normalizing here prevents display code from silently
	# depending on either persistence representation.
	return {
		"route_id": StringName(route.get("road_id", route.get("route_id", &""))),
		"target_point_id": StringName(route.get("target_point_id", &"")),
		"points": Array(route.get("route_world_points", route.get("points", []))).duplicate(true),
		"duration_milliseconds": int(route.get("duration_milliseconds", 0)),
	}


func _runtime_draft_duration() -> int:
	if _dispatch_adapter == null:
		return 0
	return int(_draft_route.get("duration_milliseconds", 0))


func _draw_route_score(drawn: Array, route: Array) -> float:
	var total := 0.0
	for point_value in drawn:
		var nearest := INF
		for index in range(1, route.size()):
			nearest = minf(nearest, _distance_to_segment(Vector2(point_value), Vector2(route[index - 1]), Vector2(route[index])))
		total += nearest
	return total / maxf(float(drawn.size()), 1.0) + Vector2(drawn.front()).distance_to(Vector2(route.front())) + Vector2(drawn.back()).distance_to(Vector2(route.back()))


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var squared := segment.length_squared()
	if squared <= 0.0001:
		return point.distance_to(start)
	return point.distance_to(start + segment * clampf((point - start).dot(segment) / squared, 0.0, 1.0))


func _should_stop_before_blocked_segment(macro: Dictionary) -> bool:
	if int(macro.blocked_segment_index) >= 1:
		return false
	var route := THEATER.get_route(StringName(macro.route_id))
	var blocked_segment := int(route.blockable_segment_index)
	if blocked_segment < 1:
		return false
	macro.blocked_segment_index = blocked_segment
	return int(macro.progress_millis) >= _progress_before_segment(macro, blocked_segment)


func _progress_before_segment(macro: Dictionary, segment_index: int) -> int:
	var points: Array = macro.route_world_points
	var total_length := 0.0
	var before_length := 0.0
	for index in range(1, points.size()):
		var segment_length := Vector2(points[index - 1]).distance_to(Vector2(points[index]))
		total_length += segment_length
		if index < segment_index:
			before_length += segment_length
	return roundi(float(macro.total_millis) * before_length / maxf(total_length, 1.0))


func _model() -> Dictionary:
	return _dispatch_adapter.get_macro_march_read_model() if _dispatch_adapter != null else {"army": {}, "formations": [], "food": 0}


func _low_poly_available() -> bool:
	return DisplayServer.get_name() != "headless" and THEATER.get_definition_id() == &"blackstone_playable_r2"


func _sync_low_poly_presentation(model: Dictionary) -> void:
	var enabled := _low_poly_enabled and _low_poly_available()
	_low_poly_presentation.visible = enabled
	_presentation_toggle_button.text = "切换为二维战区" if enabled else "切换为低模战区"
	if not enabled:
		return
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	# A map interaction has one current subject. Do not retain an army's 3D
	# command pennant while a specialist is selected at the same gate or camp.
	var presentation_army_id := &"" if _selected_specialist_id != &"" else _selected_army_id
	_low_poly_presentation.sync(THEATER, model, field, _camera_center, _camera_zoom, presentation_army_id, _selected_specialist_id)


func _toggle_low_poly_presentation() -> void:
	if not _low_poly_available():
		return
	_low_poly_enabled = not _low_poly_enabled
	_status_label.text = "已切换为%s；军令、施工、战斗和存档仍使用同一战区状态。" % ("低模战区表现" if _low_poly_enabled else "二维战区基线")
	refresh()


func _map_rect() -> Rect2:
	var panel_width := clampf(size.x * 0.28, 272.0, 340.0)
	return Rect2(Vector2(22, 96), Vector2(maxf(size.x - panel_width - 44.0, 400.0), maxf(size.y - 122.0, 360.0)))


func _side_panel_rect() -> Rect2:
	var panel_width := clampf(size.x * 0.28, 272.0, 340.0)
	return Rect2(Vector2(size.x - panel_width - 14.0, 94), Vector2(panel_width, maxf(size.y - 108.0, 360.0)))


func _minimap_rect() -> Rect2:
	var map_rect := _map_rect()
	var minimap_size := Vector2(minf(156.0, map_rect.size.x * 0.25), minf(104.0, map_rect.size.y * 0.22))
	# Keep the overview away from Silverford and its approach at the lower-right
	# edge of the default camera. This upper corner has no command destination.
	return Rect2(Vector2(map_rect.end.x - minimap_size.x - 14.0, map_rect.position.y + 14.0), minimap_size)


func _visible_world_rect() -> Rect2:
	var half_screen := _map_rect().size / _camera_zoom * 0.5
	var projected_center := _project_world(_camera_center)
	var corners := [
		_unproject_world(projected_center - half_screen),
		_unproject_world(projected_center + Vector2(half_screen.x, -half_screen.y)),
		_unproject_world(projected_center + Vector2(-half_screen.x, half_screen.y)),
		_unproject_world(projected_center + half_screen),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _clamp_camera() -> void:
	var projected_bounds := _projected_world_bounds()
	var half_view := _map_rect().size / _camera_zoom * 0.5
	var projected_center := _project_world(_camera_center)
	for axis in 2:
		var minimum_center: float = projected_bounds.position[axis] + half_view[axis]
		var maximum_center: float = projected_bounds.end[axis] - half_view[axis]
		projected_center[axis] = projected_bounds.get_center()[axis] if minimum_center > maximum_center else clampf(projected_center[axis], minimum_center, maximum_center)
	_camera_center = _unproject_world(projected_center)


func _center_camera_from_minimap(screen_position: Vector2) -> void:
	var minimap := _minimap_rect()
	var normalized := (screen_position - minimap.position) / minimap.size
	_camera_center = THEATER.get_world_bounds().position + THEATER.get_world_bounds().size * normalized
	_clamp_camera()
	queue_redraw()


func _world_to_screen(world: Vector2) -> Vector2:
	return _map_rect().get_center() + (_project_world(world) - _project_world(_camera_center)) * _camera_zoom


func _screen_to_world(screen: Vector2) -> Vector2:
	return _unproject_world(_project_world(_camera_center) + (screen - _map_rect().get_center()) / _camera_zoom)


func _project_world(world: Vector2) -> Vector2:
	return Vector2(world.x + world.y * OBLIQUE_X_SKEW, world.y * OBLIQUE_Y_SCALE)


func _unproject_world(projected: Vector2) -> Vector2:
	var world_y := projected.y / OBLIQUE_Y_SCALE
	return Vector2(projected.x - world_y * OBLIQUE_X_SKEW, world_y)


func _projected_world_bounds() -> Rect2:
	var bounds := THEATER.get_world_bounds()
	var projected_corners := [
		_project_world(bounds.position), _project_world(Vector2(bounds.end.x, bounds.position.y)),
		_project_world(Vector2(bounds.position.x, bounds.end.y)), _project_world(bounds.end),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in projected_corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _point_display_name(model: Dictionary, point_id: StringName, fallback: String) -> String:
	if point_id == &"":
		return fallback
	return str(_point_from_model(model, point_id).get("display_name", fallback))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("19211e"))
	draw_rect(_side_panel_rect(), Color("eee4cc"))


func _draw_map_canvas(canvas: Control) -> void:
	var rect := _map_rect()
	var palette := THEATER.get_presentation_profile()
	# World drawing keeps the parent's screen-space transform, while the child
	# canvas clips every primitive to the actual map viewport.
	canvas.draw_set_transform(-rect.position)
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	if _low_poly_enabled and _low_poly_available():
		_draw_low_poly_overlays(canvas, rect, field)
		return
	canvas.draw_rect(rect, Color(palette.get("ground_color", Color("728b67"))))
	_draw_terrain(canvas, rect)
	for water_region in THEATER.get_water_regions():
		_draw_water_region(canvas, water_region, palette)
	for route_value in Dictionary(field.get("roads_by_id", {})).values():
		var route: Dictionary = route_value
		var points := PackedVector2Array()
		for point in Array(route.get("route_world_points", [])):
			points.append(_world_to_screen(Vector2(point)))
		if points.size() < 2:
			continue
		var kind := StringName(route.get("road_kind", &""))
		var damaged := StringName(route.get("state", &"")) == FieldTacticsState.ROAD_DAMAGED
		var color := Color("66535c") if damaged else (Color("68b8a7") if kind == FieldTacticsState.ROAD_NORMAL else (Color("8f62b7") if kind == FieldTacticsState.ROAD_BRIDGE else Color("b89257")))
		var width := 15.0 if kind == FieldTacticsState.ROAD_MAIN else (12.0 if kind == FieldTacticsState.ROAD_BRIDGE else 10.0)
		canvas.draw_polyline(points, color, width, true)
		canvas.draw_polyline(points, Color("4b3927"), 2.0, true)
		if kind == FieldTacticsState.ROAD_BRIDGE:
			_draw_bridge_deck(canvas, points, damaged)
		elif damaged:
			_draw_road_damage(canvas, Array(points))
	if not _engineering_mode and _has_explicit_command_subject(_model(), _selected_army(_model())):
		_draw_road_choice_points(canvas, Dictionary(field.get("roads_by_id", {})))
	_draw_engineering_draft_overlay(canvas, rect)
	_draw_project_construction_overlays(canvas, Dictionary(field.get("projects_by_id", {})))
	_draw_march_draft_or_live_preview(canvas)
	for army_value in Array(_model().get("armies", [])):
		_draw_army_marker(canvas, Dictionary(army_value))
	for camp_value in Dictionary(field.get("camps_by_id", {})).values():
		var camp: Dictionary = camp_value
		var camp_center := _world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO)))
		_draw_camp_marker(canvas, camp_center)
	for specialist_value in Dictionary(field.get("specialists_by_id", {})).values():
		var specialist: Dictionary = specialist_value
		if not bool(specialist.get("alive", false)):
			continue
		var specialist_color := Color("73d7ed") if StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else Color("f2b86e")
		var specialist_position := _world_to_screen(Vector2(specialist.get("world_position", Vector2.ZERO)))
		canvas.draw_circle(specialist_position, 10.0, specialist_color)
		canvas.draw_string(ThemeDB.fallback_font, specialist_position + Vector2(-5, 5), "侦" if StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else "工", HORIZONTAL_ALIGNMENT_CENTER, 12, 12, Color("1d2a30"))
	for project_value in Dictionary(field.get("projects_by_id", {})).values():
		var project: Dictionary = project_value
		var project_phase := StringName(project.get("phase", &""))
		if project_phase == &"COMPLETE":
			continue
		var engineer := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(StringName(project.get("engineer_id", &"")), {}))
		var project_points: Array = Array(project.get("route_world_points", []))
		var project_fallback_position := Vector2(project_points.front()) if not project_points.is_empty() else Vector2.ZERO
		var project_position := _world_to_screen(Vector2(engineer.get("world_position", project_fallback_position)))
		var progress := float(project.get("progress_milliseconds", 0)) / maxf(float(project.get("required_milliseconds", 1)), 1.0)
		var progress_rect := Rect2(project_position + Vector2(-24, 15), Vector2(48, 6))
		canvas.draw_rect(progress_rect, Color("2d3531"), true)
		canvas.draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * clampf(progress, 0.0, 1.0), progress_rect.size.y)), Color("f2b86e") if project_phase != &"INTERRUPTED" else Color("cf5b52"), true)
		var phase_label := "赴工" if project_phase == &"TRAVELING" else ("中断·待补派" if project_phase == &"INTERRUPTED" else ("维修" if StringName(project.get("project_kind", &"")) == &"REPAIR" else "施工"))
		canvas.draw_string(ThemeDB.fallback_font, project_position + Vector2(-30, 34), phase_label, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color("fff0c5"))
	for patrol_value in Dictionary(field.get("visible_patrols_by_id", {})).values():
		var patrol: Dictionary = patrol_value
		var patrol_position := _world_to_screen(Vector2(patrol.get("last_known_world_position", Vector2.ZERO)))
		var is_live := StringName(patrol.get("fog_state", &"")) == FieldTacticsState.FOG_VISIBLE
		var patrol_color := Color("e26452") if is_live else Color("b98e7b")
		var diamond := PackedVector2Array([
			patrol_position + Vector2(0, -13), patrol_position + Vector2(13, 0),
			patrol_position + Vector2(0, 13), patrol_position + Vector2(-13, 0),
		])
		canvas.draw_colored_polygon(diamond, Color(patrol_color, 0.85 if is_live else 0.5))
		canvas.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("4b2925"), 2.0, true)
		var patrol_label := "巡逻·实时" if is_live else "巡逻·旧情报"
		if bool(patrol.get("exposed", false)):
			patrol_label += "·已暴露"
		canvas.draw_string(ThemeDB.fallback_font, patrol_position + Vector2(-42, 31), patrol_label, HORIZONTAL_ALIGNMENT_CENTER, 84, 12, Color("fff0c5"))
		if not Dictionary(patrol.get("last_engagement", {})).is_empty():
			canvas.draw_arc(patrol_position, 19.0, 0.0, TAU, 24, Color("ffd166"), 2.0, true)
	for point_value in _all_points(_model()).values():
		var point: Dictionary = point_value
		var center := _world_to_screen(Vector2(point.world_position))
		var enemy := StringName(point.get("point_kind", &"")) == &"ENEMY_CITY" and StringName(point.get("military_controller_faction_id", &"enemy")) != &"player"
		if StringName(point.get("point_kind", &"")) in [&"ENEMY_CITY", &""] and StringName(point.get("point_id", &"")) in [&"blackstone_city", &"redcliff_city", &"silverford_city"]:
			_draw_city_marker(canvas, center, enemy, palette)
		else:
			_draw_garrison_marker(canvas, center)
		_draw_point_label(canvas, rect, center, str(point.display_name), 80, Color.WHITE)
	_draw_minimap(canvas)
	_draw_draw_hold_feedback(canvas)


func _draw_low_poly_overlays(canvas: Control, rect: Rect2, field: Dictionary) -> void:
	# The low-poly layer renders terrain and units through an orthographic
	# SubViewport.  This transparent canvas retains only interaction affordances
	# using the same 2D projection that receives input.
	_draw_march_draft_or_live_preview(canvas)
	_draw_engineering_draft_overlay(canvas, rect)
	_draw_project_construction_overlays(canvas, Dictionary(field.get("projects_by_id", {})))
	if not _engineering_mode and _has_explicit_command_subject(_model(), _selected_army(_model())):
		_draw_road_choice_points(canvas, Dictionary(field.get("roads_by_id", {})))
	for army_value in Array(_model().get("armies", [])):
		var army: Dictionary = Dictionary(army_value)
		var display_route := _display_route_for_army(army)
		var points: Array = Array(display_route.get("points", []))
		if points.is_empty():
			continue
		var progress := float(display_route.get("progress_millis", 0)) / maxf(float(display_route.get("total_millis", 1)), 1.0)
		var screen := _world_to_screen(_point_along_route(points, progress))
		var selected := _selected_specialist_id == &"" and StringName(army.get("army_id", &"")) == _selected_army_id
		canvas.draw_arc(screen, 20.0 if selected else 16.0, 0.0, TAU, 24, Color("fff2bf") if selected else Color("342b27", 0.72), 2.0, true)
		if selected:
			# The 3D pennant remains visible through occluding scenery; this overlay
			# keeps the player-facing count tied to the same authoritative army.
			canvas.draw_string(ThemeDB.fallback_font, screen + Vector2(-34, -31), "已选 · %d 人" % _army_member_count(army), HORIZONTAL_ALIGNMENT_CENTER, 68, 12, Color("fff4c4"))
		else:
			canvas.draw_string(ThemeDB.fallback_font, screen + Vector2(-24, 31), "%d 人" % _army_member_count(army), HORIZONTAL_ALIGNMENT_CENTER, 48, 12, Color("fff0c5"))
	_draw_selected_specialist_overlay(canvas, field)
	for project_value in Dictionary(field.get("projects_by_id", {})).values():
		var project: Dictionary = Dictionary(project_value)
		if StringName(project.get("phase", &"")) == &"COMPLETE":
			continue
		var engineer := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(StringName(project.get("engineer_id", &"")), {}))
		var project_points: Array = Array(project.get("route_world_points", []))
		var fallback := Vector2(project_points.front()) if not project_points.is_empty() else Vector2.ZERO
		var screen := _world_to_screen(Vector2(engineer.get("world_position", fallback)))
		var progress := float(project.get("progress_milliseconds", 0)) / maxf(float(project.get("required_milliseconds", 1)), 1.0)
		var progress_rect := Rect2(screen + Vector2(-25, 17), Vector2(50, 6))
		canvas.draw_rect(progress_rect, Color("20302c", 0.88), true)
		canvas.draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * clampf(progress, 0.0, 1.0), progress_rect.size.y)), Color("f2b86e"), true)
		canvas.draw_string(ThemeDB.fallback_font, screen + Vector2(-32, 38), "施工中" if StringName(project.get("phase", &"")) == &"BUILDING" else "赴工中", HORIZONTAL_ALIGNMENT_CENTER, 64, 12, Color("fff0c5"))
	for patrol_value in Dictionary(field.get("visible_patrols_by_id", {})).values():
		var patrol: Dictionary = Dictionary(patrol_value)
		var patrol_screen := _world_to_screen(Vector2(patrol.get("last_known_world_position", Vector2.ZERO)))
		canvas.draw_arc(patrol_screen, 19.0, 0.0, TAU, 24, Color("ffd166"), 2.0, true)
		if not Dictionary(patrol.get("last_engagement", {})).is_empty():
			canvas.draw_string(ThemeDB.fallback_font, patrol_screen + Vector2(-40, 30), "遭遇已结算", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color("fff0c5"))
	for point_value in _all_points(_model()).values():
		var point: Dictionary = point_value
		var center := _world_to_screen(Vector2(point.get("world_position", Vector2.ZERO)))
		_draw_point_label(canvas, rect, center, str(point.get("display_name", "据点")), 92, Color("fff4d3"))
	canvas.draw_rect(rect, Color("e7d7a8", 0.92), false, 2.0)
	_draw_minimap(canvas)
	_draw_draw_hold_feedback(canvas)


func _draw_road_choice_points(canvas: Control, roads_by_id: Dictionary) -> void:
	for marker_value in _road_choice_markers(roads_by_id):
		var marker: Dictionary = marker_value
		var road_id := StringName(marker.road_id)
		var screen := Vector2(marker.screen_position)
		var selected := road_id == _selected_route_road_id
		canvas.draw_circle(screen, 6.0 if selected else 4.0, Color("fff2bf") if selected else Color("77f0ef", 0.70))
		canvas.draw_arc(screen, 9.0 if selected else 7.0, 0.0, TAU, 16, Color("fff2bf", 0.95) if selected else Color("20302c", 0.72), 1.5, true)


func _road_choice_markers(roads_by_id: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var road_ids: Array = roads_by_id.keys()
	road_ids.sort()
	for road_id_value in road_ids:
		var road_id := StringName(road_id_value)
		var road := Dictionary(roads_by_id.get(road_id, {}))
		if StringName(road.get("state", &"")) != FieldTacticsState.ROAD_OPEN:
			continue
		var points: Array = Array(road.get("route_world_points", []))
		if points.size() < 2:
			continue
		result.append({
			"road_id": road_id,
			"screen_position": _world_to_screen(_point_along_route(points, 0.5)),
		})
	return result


func _draw_march_draft_or_live_preview(canvas: Control) -> void:
	# A previous draft remains available if the new drag is cancelled, but while
	# a replacement gesture is active its live path is the only player-facing
	# route. Rendering it first prevents the old bright path from appearing to
	# win over the pointer's current plan.
	if _is_drawing and not _engineering_mode:
		if not _draw_preview_route.is_empty():
			_draw_route_preview(canvas, Array(_draw_preview_route.get("points", [])), Color("77f0ef", 0.42), 2.0, false)
			_draw_pointer_command_arrow(canvas)
			var live_target := _point_from_model(_model(), StringName(_draw_preview_route.get("target_point_id", &"")))
			var live_target_screen := _world_to_screen(Vector2(live_target.get("world_position", Vector2.ZERO)))
			canvas.draw_arc(live_target_screen, 17.0, 0.0, TAU, 24, Color("fff2bf"), 2.5, true)
			return
		if not _draw_preview_error.is_empty():
			_draw_pointer_command_arrow(canvas, Color("e26452", 0.76))
			canvas.draw_circle(_draw_cursor_screen, 7.0, Color("e26452", 0.9))
			canvas.draw_string(ThemeDB.fallback_font, _draw_cursor_screen + Vector2(12, -12), _draw_preview_error, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff2bf"))
			return
		_draw_pointer_command_arrow(canvas)
		return
	if not _draft_route.is_empty():
		var draft_points: Array = Array(_draft_route.get("points", []))
		_draw_route_preview(canvas, draft_points, Color("54d7df"), 3.0, true)
		var source_id := StringName(_draft_route.get("source_point_id", _draw_source_point_id))
		var target_id := StringName(_draft_route.get("target_point_id", &""))
		var target := _point_from_model(_model(), target_id)
		var target_screen := _world_to_screen(Vector2(target.get("world_position", Vector2.ZERO)))
		_draw_command_arrow(canvas, source_id, target_screen)
		canvas.draw_arc(target_screen, 17.0, 0.0, TAU, 24, Color("fff2bf"), 2.5, true)
		var target_name := str(target.get("display_name", target_id))
		var duration_seconds := float(_draft_route.get("duration_milliseconds", 0)) / 1000.0
		var food_cost := int(_draft_route.get("food_cost", 0))
		canvas.draw_string(ThemeDB.fallback_font, target_screen + Vector2(-84, -28), "%s · %0.1f 秒 · 粮 %d" % [target_name, duration_seconds, food_cost], HORIZONTAL_ALIGNMENT_CENTER, 168, 12, Color("fff4d3"))
		return
	if _is_drawing and _engineering_mode and not _draw_preview_route.is_empty():
		_draw_engineering_preview_overlay(canvas, _draw_preview_route)
		return
	if _is_drawing and _engineering_mode and _draw_points.size() >= 2:
		var raw_points := PackedVector2Array()
		for point in _draw_points:
			raw_points.append(_world_to_screen(point))
		if _engineering_live_endpoint != Vector2.INF and (raw_points.is_empty() or raw_points[raw_points.size() - 1].distance_to(_world_to_screen(_engineering_live_endpoint)) > 0.01):
			raw_points.append(_world_to_screen(_engineering_live_endpoint))
		for index in range(1, raw_points.size()):
			canvas.draw_dashed_line(raw_points[index - 1], raw_points[index], Color("f2b86e"), 4.0, 8.0, true)
		return
	if _is_drawing and not _draw_preview_error.is_empty():
		canvas.draw_circle(_draw_cursor_screen, 7.0, Color("e26452", 0.9))
		canvas.draw_string(ThemeDB.fallback_font, _draw_cursor_screen + Vector2(12, -12), _draw_preview_error, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff2bf"))


func _draw_pointer_command_arrow(canvas: Control, color: Color = Color("77f0ef")) -> void:
	_draw_command_arrow(canvas, _draw_source_point_id, _draw_cursor_screen, color)


func _draw_command_arrow(canvas: Control, source_point_id: StringName, end: Vector2, color: Color = Color("77f0ef")) -> void:
	if source_point_id == &"":
		return
	var source := _point_from_model(_model(), source_point_id)
	var start := _world_to_screen(Vector2(source.get("world_position", Vector2.ZERO)))
	if start.distance_to(end) < 2.0:
		return
	canvas.draw_dashed_line(start, end, color, 3.0, 9.0, true)
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	canvas.draw_colored_polygon(PackedVector2Array([end, end - direction * 12.0 + normal * 5.0, end - direction * 12.0 - normal * 5.0]), color)


func _draw_route_preview(canvas: Control, world_points: Array, color: Color, width: float, committed: bool) -> void:
	if world_points.size() < 2:
		return
	var points := PackedVector2Array()
	for point in world_points:
		points.append(_world_to_screen(Vector2(point)))
	canvas.draw_polyline(points, Color(color, 0.54 if committed else 0.82), width, true)
	for index in range(1, points.size()):
		var start := points[index - 1]
		var end := points[index]
		var direction := (end - start).normalized()
		if direction.length_squared() <= 0.001:
			continue
		var center := start.lerp(end, 0.58)
		var normal := Vector2(-direction.y, direction.x)
		canvas.draw_colored_polygon(PackedVector2Array([
			center + direction * 8.0,
			center - direction * 5.0 + normal * 4.0,
			center - direction * 5.0 - normal * 4.0,
		]), Color("fff2bf"))


func _draw_draw_hold_feedback(canvas: Control) -> void:
	if _draw_hold_pending:
		var progress := clampf(_draw_hold_elapsed / DRAW_HOLD_SECONDS, 0.0, 1.0)
		canvas.draw_arc(_draw_press_screen, 14.0, -PI * 0.5, TAU * progress - PI * 0.5, 20, Color("f2b86e", 0.92), 2.5, true)
		canvas.draw_string(ThemeDB.fallback_font, _draw_press_screen + Vector2(-54, -24), "按住 %0.1f 秒" % DRAW_HOLD_SECONDS, HORIZONTAL_ALIGNMENT_CENTER, 108, 12, Color("fff4d3"))
	elif _is_drawing:
		canvas.draw_circle(_draw_cursor_screen, 5.0, Color("f2b86e") if _engineering_mode else Color("77f0ef"))


func _draw_selected_specialist_overlay(canvas: Control, field: Dictionary) -> void:
	if _selected_specialist_id == &"":
		return
	var specialist := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(_selected_specialist_id, {}))
	if specialist.is_empty() or not bool(specialist.get("alive", false)):
		return
	var screen := _world_to_screen(Vector2(specialist.get("world_position", Vector2.ZERO)))
	var scout := StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT
	var accent := Color("73d7ed") if scout else Color("f2b86e")
	canvas.draw_arc(screen, 19.0, 0.0, TAU, 28, accent, 3.0, true)
	canvas.draw_arc(screen, 23.0, 0.0, TAU, 28, Color("fff4d3", 0.88), 1.5, true)
	var label := "已选·%s·%s" % [_specialist_role_label(specialist), _specialist_phase_label(specialist)]
	canvas.draw_string(ThemeDB.fallback_font, screen + Vector2(-58, -31), label, HORIZONTAL_ALIGNMENT_CENTER, 116, 12, Color("fff4d3"))


func _draw_engineering_draft_overlay(canvas: Control, rect: Rect2) -> void:
	# Engineering persists after mouse release in _engineering_draft.  It must be
	# drawn from Field's authoritative segment plan, not the transient pointer list.
	if _engineering_draft.is_empty():
		return
	_draw_engineering_preview_overlay(canvas, _engineering_draft)


func _draw_engineering_preview_overlay(canvas: Control, draft: Dictionary) -> void:
	for segment in _engineering_overlay_segments(draft):
		_draw_engineering_segment(canvas, Array(segment.get("points", [])), StringName(segment.get("road_kind", &"")), Color("80e8e0"), 0.92, false)
	var route_points: Array = Array(draft.get("route_world_points", []))
	var source := Vector2(route_points.front()) if not route_points.is_empty() else Vector2.ZERO
	source = Vector2(draft.get("source_world_position", source))
	var target := Vector2(route_points.back()) if not route_points.is_empty() else source
	var source_screen := _world_to_screen(source)
	var target_screen := _world_to_screen(target)
	canvas.draw_circle(source_screen, 9.0, Color("fff2bf"))
	canvas.draw_circle(target_screen, 9.0, Color("80e8e0"))
	canvas.draw_string(ThemeDB.fallback_font, source_screen + Vector2(-30, -14), "施工起点", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color("fff4d3"))
	canvas.draw_string(ThemeDB.fallback_font, target_screen + Vector2(-30, -14), "施工目标", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color("fff4d3"))


func _draw_project_construction_overlays(canvas: Control, projects: Dictionary) -> void:
	for project_value in projects.values():
		var project: Dictionary = Dictionary(project_value)
		if StringName(project.get("phase", &"")) == &"COMPLETE":
			continue
		var elapsed := int(project.get("progress_milliseconds", 0))
		for plan_value in Array(project.get("segment_plans", [])):
			var plan: Dictionary = Dictionary(plan_value)
			var points: Array = Array(plan.get("route_world_points", []))
			var duration := maxi(int(plan.get("required_milliseconds", 0)), 1)
			var kind := StringName(plan.get("road_kind", &""))
			if elapsed >= duration:
				elapsed -= duration
				continue
			# The complete physical part is shown by roads_by_id.  This translucent
			# remainder is a plan hint, while the solid clipped part shows actual work.
			_draw_engineering_segment(canvas, points, kind, Color("f0bc70"), 0.34, true)
			if elapsed > 0:
				_draw_engineering_segment(canvas, _partial_world_points(points, float(elapsed) / float(duration)), kind, Color("f5d18b"), 0.94, false)
			break


func _engineering_overlay_segments(draft: Dictionary) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for plan_value in Array(draft.get("segment_plans", [])):
		var plan: Dictionary = Dictionary(plan_value)
		segments.append({
			"points": Array(plan.get("route_world_points", [])).duplicate(true),
			"road_kind": StringName(plan.get("road_kind", FieldTacticsState.ROAD_NORMAL)),
		})
	if segments.is_empty() and Array(draft.get("route_world_points", [])).size() >= 2:
		segments.append({
			"points": Array(draft.get("route_world_points", [])).duplicate(true),
			"road_kind": StringName(draft.get("road_kind", FieldTacticsState.ROAD_NORMAL)),
		})
	return segments


func _draw_engineering_segment(canvas: Control, world_points: Array, road_kind: StringName, color: Color, opacity: float, planned: bool) -> void:
	if world_points.size() < 2:
		return
	var points := PackedVector2Array()
	for point in world_points:
		points.append(_world_to_screen(Vector2(point)))
	var bridge := road_kind == FieldTacticsState.ROAD_BRIDGE
	var width := 12.0 if bridge else 9.0
	var tint := Color(color, opacity)
	if planned:
		for index in range(1, points.size()):
			canvas.draw_dashed_line(points[index - 1], points[index], tint, width, 10.0, true)
	else:
		canvas.draw_polyline(points, tint, width, true)
		canvas.draw_polyline(points, Color("3c3024", opacity), 1.5, true)
	if bridge:
		_draw_bridge_deck(canvas, points, false)


func _partial_world_points(points: Array, fraction: float) -> Array:
	if points.size() < 2:
		return []
	var total_length := 0.0
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	var target_length := total_length * clampf(fraction, 0.0, 1.0)
	var result: Array = [Vector2(points.front())]
	var consumed := 0.0
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var length := start.distance_to(end)
		if consumed + length <= target_length:
			result.append(end)
			consumed += length
			continue
		if target_length > consumed:
			result.append(start.lerp(end, (target_length - consumed) / maxf(length, 0.0001)))
		break
	return result


func _draw_point_label(canvas: Control, rect: Rect2, center: Vector2, label: String, width: float, color: Color) -> void:
	var label_rect := Rect2(center + Vector2(-width * 0.5, 31.0), Vector2(width, 18.0))
	# Do not clamp an off-screen city name into the map edge: it falsely suggests
	# that the location is underneath that edge label. The minimap still locates it.
	if not rect.grow(-12.0).encloses(label_rect):
		return
	canvas.draw_string(ThemeDB.fallback_font, label_rect.position, label, HORIZONTAL_ALIGNMENT_CENTER, width, 14, color)


func _draw_terrain(canvas: Control, rect: Rect2) -> void:
	# The Resource-owned terrain regions are shared with FieldTacticsState for
	# ambush rules; this method only projects those same facts to screen space.
	for terrain_value in THEATER.get_terrain_regions():
		var terrain: Dictionary = terrain_value
		if StringName(terrain.get("kind", &"")) == &"WATER":
			continue
		var forest := Rect2(terrain.get("rect", Rect2i()))
		var terrain_polygon := _world_rect_screen_polygon(forest)
		if StringName(terrain.get("kind", &"")) == &"ROCKS":
			canvas.draw_colored_polygon(terrain_polygon, Color("6b715f", 0.12))
			for rock_offset in [Vector2(24, 48), Vector2(60, 27), Vector2(93, 66), Vector2(126, 38)]:
				if rock_offset.x >= forest.size.x or rock_offset.y >= forest.size.y:
					continue
				_draw_rock(canvas, _world_to_screen(forest.position + rock_offset), 7.0 + fmod(rock_offset.x, 5.0))
			continue
		if StringName(terrain.get("kind", &"")) != &"FOREST":
			continue
		canvas.draw_colored_polygon(terrain_polygon, Color("38533b", 0.24))
		var tree_offsets := [
			Vector2(18, 24), Vector2(48, 46), Vector2(77, 20), Vector2(108, 48),
			Vector2(138, 25), Vector2(30, 88), Vector2(65, 105), Vector2(102, 82),
			Vector2(145, 96),
		]
		for offset in tree_offsets:
			if offset.x >= forest.size.x - 5 or offset.y >= forest.size.y - 5:
				continue
			_draw_tree(canvas, _world_to_screen(forest.position + offset), maxf(0.72, _camera_zoom))
	canvas.draw_rect(rect, Color("d9cfaa"), false, 2.0)


func _draw_water_region(canvas: Control, water_region: Rect2i, palette: Dictionary) -> void:
	var water_rect := Rect2(water_region)
	var bank := _world_rect_screen_polygon(water_rect)
	canvas.draw_colored_polygon(bank, Color(palette.get("water_color", Color("4c95b5"))))
	canvas.draw_polyline(PackedVector2Array([bank[0], bank[1]]), Color("d5d09d"), 4.0, true)
	canvas.draw_polyline(PackedVector2Array([bank[3], bank[2]]), Color("d5d09d"), 4.0, true)
	for ratio in [0.22, 0.52, 0.78]:
		var left := _world_to_screen(Vector2(water_rect.position.x, lerpf(water_rect.position.y, water_rect.end.y, float(ratio))))
		var right := _world_to_screen(Vector2(water_rect.end.x, lerpf(water_rect.position.y, water_rect.end.y, float(ratio))))
		canvas.draw_line(left.lerp(right, 0.08), left.lerp(right, 0.88), Color(palette.get("water_highlight_color", Color("8bcbd0")), 0.7), 2.0)


func _world_rect_screen_polygon(world_rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		_world_to_screen(world_rect.position),
		_world_to_screen(Vector2(world_rect.end.x, world_rect.position.y)),
		_world_to_screen(world_rect.end),
		_world_to_screen(Vector2(world_rect.position.x, world_rect.end.y)),
	])


func _draw_tree(canvas: Control, base: Vector2, scale: float) -> void:
	canvas.draw_circle(base + Vector2(5, 9) * scale, 7.0 * scale, Color("23362b", 0.28))
	canvas.draw_line(base + Vector2(0, 1) * scale, base + Vector2(0, 13) * scale, Color("59442d"), 3.0 * scale)
	canvas.draw_circle(base + Vector2(0, -5) * scale, 10.0 * scale, Color("315a3b"))
	canvas.draw_circle(base + Vector2(-4, -9) * scale, 6.5 * scale, Color("5f8249"))
	canvas.draw_circle(base + Vector2(5, -8) * scale, 5.5 * scale, Color("789a55"))


func _draw_rock(canvas: Control, center: Vector2, radius: float) -> void:
	var rock := PackedVector2Array([
		center + Vector2(-radius, radius * 0.45), center + Vector2(-radius * 0.55, -radius * 0.65),
		center + Vector2(radius * 0.2, -radius), center + Vector2(radius, -radius * 0.1),
		center + Vector2(radius * 0.65, radius * 0.65),
	])
	canvas.draw_colored_polygon(rock, Color("817b68"))
	canvas.draw_polyline(PackedVector2Array([rock[0], rock[1], rock[2], rock[3], rock[4], rock[0]]), Color("4d4b43"), 1.5, true)


func _draw_bridge_deck(canvas: Control, points: PackedVector2Array, damaged: bool) -> void:
	for index in range(1, points.size()):
		var start := points[index - 1]
		var end := points[index]
		var length := start.distance_to(end)
		var normal := (end - start).normalized().orthogonal()
		var plank_count := maxi(2, floori(length / 10.0))
		for plank_index in range(plank_count + 1):
			var center := start.lerp(end, float(plank_index) / float(plank_count))
			canvas.draw_line(center - normal * 6.0, center + normal * 6.0, Color("d6b06b"), 2.0)
	if damaged:
		_draw_road_damage(canvas, Array(points))


func _draw_road_damage(canvas: Control, screen_points: Array) -> void:
	if screen_points.size() < 2:
		return
	var center := _point_along_route(screen_points, 0.5)
	canvas.draw_line(center + Vector2(-9, -9), center + Vector2(9, 9), Color("ffdf9a"), 4.0)
	canvas.draw_line(center + Vector2(-9, 9), center + Vector2(9, -9), Color("7c2525"), 4.0)


func _draw_city_marker(canvas: Control, center: Vector2, enemy: bool, palette: Dictionary) -> void:
	var wall_color := Color("633631") if enemy else Color("354845")
	var banner_color := Color(palette.get("enemy_color" if enemy else "friendly_color", Color("c65a42") if enemy else Color("d7b465")))
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-28, 19), center + Vector2(31, 19), center + Vector2(39, 27), center + Vector2(-18, 29)]), Color("1f2b27", 0.34))
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-25, -13), center + Vector2(24, -13), center + Vector2(30, -5), center + Vector2(-19, -5)]), Color("9c7a56"))
	canvas.draw_rect(Rect2(center + Vector2(-19, -5), Vector2(49, 27)), wall_color, true)
	for tower_offset in [Vector2(-19, -8), Vector2(27, -8)]:
		canvas.draw_rect(Rect2(center + tower_offset - Vector2(6, 9), Vector2(12, 25)), Color("806248"), true)
		canvas.draw_colored_polygon(PackedVector2Array([center + tower_offset + Vector2(-9, -9), center + tower_offset + Vector2(0, -17), center + tower_offset + Vector2(9, -9)]), Color("3f4b48" if not enemy else "6b3d35"))
	canvas.draw_rect(Rect2(center + Vector2(-13, -3), Vector2(27, 17)), banner_color, true)
	canvas.draw_rect(Rect2(center + Vector2(-5, 8), Vector2(11, 14)), Color("241f1c"), true)
	canvas.draw_line(center + Vector2(4, -29), center + Vector2(4, -8), Color("2d2924"), 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(5, -28), center + Vector2(20, -23), center + Vector2(5, -17)]), banner_color)
	if not enemy:
		canvas.draw_arc(center, 36.0, PI * 0.1, PI * 0.9, 18, Color("f4d477", 0.5), 2.0, true)


func _draw_garrison_marker(canvas: Control, center: Vector2) -> void:
	canvas.draw_circle(center + Vector2(4, 14), 20.0, Color("26342e", 0.28))
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-20, 13), center, center + Vector2(21, 13)]), Color("d6aa63"))
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 10), center + Vector2(-4, -13), center + Vector2(5, 10)]), Color("efe0b7"))
	canvas.draw_line(center + Vector2(-21, 15), center + Vector2(21, 15), Color("4b3927"), 3.0)
	canvas.draw_line(center + Vector2(11, -13), center + Vector2(11, 10), Color("342b27"), 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(12, -12), center + Vector2(23, -8), center + Vector2(12, -4)]), Color("e5bf58"))


func _draw_camp_marker(canvas: Control, center: Vector2) -> void:
	_draw_garrison_marker(canvas, center)
	canvas.draw_circle(center + Vector2(16, 11), 4.0, Color("ecb959"))


func _draw_minimap(canvas: Control) -> void:
	var minimap := _minimap_rect()
	canvas.draw_rect(minimap, Color("25332f"), true)
	for water_region in THEATER.get_water_regions():
		var world_bounds := THEATER.get_world_bounds()
		var normalized_position := (Vector2(water_region.position) - world_bounds.position) / world_bounds.size
		var normalized_size := Vector2(water_region.size) / world_bounds.size
		canvas.draw_rect(Rect2(minimap.position + minimap.size * normalized_position, minimap.size * normalized_size), Color("4c95b5"), true)
	for point_value in _all_points(_model()).values():
		var point: Dictionary = point_value
		var world_bounds := THEATER.get_world_bounds()
		var normalized := (Vector2(point.get("world_position", Vector2.ZERO)) - world_bounds.position) / world_bounds.size
		canvas.draw_circle(minimap.position + minimap.size * normalized, 3.0, Color("d94d3f") if StringName(point.get("point_kind", &"")) == &"ENEMY_CITY" else Color("f0c46b"))
	var view := _visible_world_rect()
	var world_bounds := THEATER.get_world_bounds()
	var viewport_position := minimap.position + minimap.size * ((view.position - world_bounds.position) / world_bounds.size)
	var viewport_size := minimap.size * (view.size / world_bounds.size)
	canvas.draw_rect(Rect2(viewport_position, viewport_size), Color("f6e5ba"), false, 1.5)
	canvas.draw_rect(minimap, Color("e3dcc5"), false, 1.0)


func _draw_army_marker(canvas: Control, army: Dictionary) -> void:
	var display_route := _display_route_for_army(army)
	var points: Array = Array(display_route.get("points", []))
	var progress := float(display_route.get("progress_millis", 0)) / maxf(float(display_route.get("total_millis", 1)), 1.0)
	var position := _point_along_route(points, progress)
	var screen := _world_to_screen(position)
	canvas.draw_circle(screen, 18.0, Color("f8e3a6") if StringName(army.get("army_id", &"")) == _selected_army_id else Color("4b3927"))
	canvas.draw_circle(screen, 15.0, Color("d94d3f"))
	canvas.draw_circle(screen, 8.0, Color("fff0c5"))
	canvas.draw_colored_polygon(PackedVector2Array([screen + Vector2(4, -22), screen + Vector2(4, -6), screen + Vector2(17, -12)]), Color("f7d46b"))
	canvas.draw_line(screen + Vector2(4, -24), screen + Vector2(4, 6), Color("342b27"), 2.0)
	for offset in [-7.0, 0.0, 7.0]:
		canvas.draw_circle(screen + Vector2(offset, 12), 3.0, Color("f8e3a6"))
	if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
		var transfer: Dictionary = Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
		var label := "受阻等待"
		if StringName(transfer.get("phase", &"")) == &"TO_CAMP":
			label = "转移驻点"
		elif StringName(transfer.get("phase", &"")) == &"TO_CAMP_BLOCKED":
			label = "转移再受阻"
		elif StringName(transfer.get("phase", &"")) == &"WAITING":
			label = "驻点待修"
		elif StringName(transfer.get("phase", &"")) == &"TO_RESUME":
			label = "返回原令"
		elif StringName(transfer.get("phase", &"")) == &"TO_RESUME_BLOCKED":
			label = "返回再受阻"
		canvas.draw_string(ThemeDB.fallback_font, screen + Vector2(18, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe8a3"))


func _display_route_for_army(army: Dictionary) -> Dictionary:
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
	if StringName(army.get("phase", &"")) == ARMY_REGISTRY.PHASE_BLOCKED and StringName(transfer.get("phase", &"")) in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"WAITING", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
		return {
			"points": Array(transfer.get("route_world_points", [])).duplicate(true),
			"progress_millis": int(transfer.get("progress_millis", 0)),
			"total_millis": int(transfer.get("total_millis", 1)),
		}
	return {
		"points": Array(macro.get("route_world_points", [])).duplicate(true),
		"progress_millis": int(macro.get("progress_millis", 0)),
		"total_millis": int(macro.get("total_millis", 1)),
	}


func _point_along_route(points: Array, progress: float) -> Vector2:
	var total := 0.0
	for index in range(1, points.size()):
		total += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	var remaining := total * clampf(progress, 0.0, 1.0)
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var length := start.distance_to(end)
		if remaining <= length:
			return start.lerp(end, remaining / maxf(length, 1.0))
		remaining -= length
	return Vector2(points.back())
