class_name MacroMarchR0
extends Control


signal return_to_city_requested

const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const ARMY_REGISTRY = preload("res://scripts/army/army_registry.gd")

const CAMERA_MIN_ZOOM := 0.62
const CAMERA_MAX_ZOOM := 2.4
const CAMERA_ZOOM_STEP := 1.18

var _dispatch_adapter: V5ArmyDispatchAdapter
var _draft_route: Dictionary = {}
var _engineering_draft: Dictionary = {}
var _selected_formation_ids: Array[StringName] = []
var _draw_points: Array[Vector2] = []
var _is_drawing := false
var _engineering_mode := false
var _engineering_engineer_id: StringName = &""
var _selected_army_id: StringName = &""
var _selected_damaged_road_id: StringName = &""
var _selected_interrupted_project_id: StringName = &""
var _last_army_hit_position := Vector2.INF
var _army_hit_cycle_index := 0
var _formation_buttons: Array[Button] = []
var _formation_signature := ""
var _camera_center := Vector2(500, 325)
var _camera_zoom := 1.0
var _is_panning := false
var _last_pan_position := Vector2.ZERO

var _title_label := Label.new()
var _status_label := Label.new()
var _detail_label := Label.new()
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
	_refresh_formation_controls(Array(model.get("formations", [])), army)
	_refresh_copy(model, army)
	_layout_ui()
	queue_redraw()


func _process(delta: float) -> void:
	# World time belongs to ConstructionController.  This view is presentation
	# only, so changing map frame rate or observing two armies cannot tick them
	# twice.
	refresh()


func _build_ui() -> void:
	for label in [_title_label, _status_label, _detail_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("f6e5ba"))
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color("f4f0df"))
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Color("3e3428"))
	_formation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_formation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_formation_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_formation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_scroll.add_child(_formation_list)
	add_child(_formation_scroll)
	for button in [_confirm_button, _block_button, _recover_button, _retreat_button, _scout_button, _engineer_button, _side_road_button, _resume_project_button, _return_button]:
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
	_resume_project_button.visible = false
	_interrupted_project_selector.visible = false
	_return_button.text = "返回黑石城"
	_confirm_button.pressed.connect(_confirm_draft)
	_retreat_button.pressed.connect(_request_retreat)
	_scout_button.pressed.connect(_dispatch_scout)
	_engineer_button.pressed.connect(_dispatch_engineer)
	_side_road_button.pressed.connect(_build_side_road)
	_resume_project_button.pressed.connect(_resume_selected_interrupted_project)
	_interrupted_project_selector.item_selected.connect(_select_interrupted_project)
	_return_button.pressed.connect(func(): return_to_city_requested.emit())


func _layout_ui() -> void:
	var panel_rect := _side_panel_rect()
	var action_height := 34.0
	var action_gap := 4.0
	var action_count := 7
	# Seven explicit actions (new construction, repair, and resume are separate)
	# must remain inside the 648 px review window without covering the selector.
	var action_top := maxf(panel_rect.position.y + 276.0, size.y - 16.0 - action_height * action_count - action_gap * (action_count - 1))
	var panel_inner := Rect2(panel_rect.position + Vector2(14, 12), panel_rect.size - Vector2(28, 24))
	_title_label.position = Vector2(22, 12)
	_title_label.size = Vector2(size.x - 44, 34)
	_status_label.position = Vector2(22, 48)
	_status_label.size = Vector2(size.x - 44, 36)
	_detail_label.position = panel_inner.position
	_detail_label.size = Vector2(panel_inner.size.x, 106)
	_formation_scroll.position = panel_inner.position + Vector2(0, 148)
	_formation_scroll.size = Vector2(panel_inner.size.x, maxf(68.0, action_top - _formation_scroll.position.y - 42.0))
	_interrupted_project_selector.position = Vector2(panel_inner.position.x, action_top - 36.0)
	_interrupted_project_selector.size = Vector2(panel_inner.size.x, 30.0)
	for button in _formation_buttons:
		button.custom_minimum_size = Vector2(panel_inner.size.x - 10.0, 38)
	var action_buttons: Array[Button] = [_confirm_button, _retreat_button, _scout_button, _engineer_button, _side_road_button, _resume_project_button, _return_button]
	for index in action_buttons.size():
		var button := action_buttons[index]
		button.position = Vector2(panel_inner.position.x, action_top + index * (action_height + action_gap))
		button.size = Vector2(panel_inner.size.x, action_height)
	_block_button.position = Vector2(panel_inner.position.x, action_top)
	_block_button.size = Vector2(panel_inner.size.x, action_height)
	_recover_button.position = Vector2(panel_inner.position.x, action_top + action_height + action_gap)
	_recover_button.size = Vector2(panel_inner.size.x, action_height)


func _refresh_formation_controls(formations: Array, army: Dictionary) -> void:
	var signature_parts: Array[String] = [str(not army.is_empty()), str(bool(_model().get("can_issue_from_city", false)))]
	for formation_value in formations:
		var formation: Dictionary = formation_value
		signature_parts.append("%s:%d" % [String(formation.get("formation_id", &"")), int(formation.get("member_count", 0))])
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
		button.text = "%s · %d 人" % [str(formation.display_name), int(formation.member_count)]
		button.disabled = int(formation.member_count) <= 0
		button.toggle_mode = true
		button.button_pressed = formation_id in _selected_formation_ids
		button.set_meta("formation_id", formation_id)
		button.pressed.connect(_toggle_formation.bind(formation_id))
		_formation_list.add_child(button)
		_formation_buttons.append(button)


func _refresh_copy(model: Dictionary, army: Dictionary) -> void:
	_title_label.text = "黑石外城战区 · 军令与攻城"
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	var specialists: Dictionary = field.get("specialists_by_id", {})
	var projects: Dictionary = field.get("projects_by_id", {})
	var visible_patrols: Dictionary = field.get("visible_patrols_by_id", {})
	var has_selected_damage := _selected_damaged_road_id != &"" and StringName(Dictionary(field.get("roads_by_id", {})).get(_selected_damaged_road_id, {}).get("state", &"")) == FieldTacticsState.ROAD_DAMAGED
	_refresh_interrupted_project_selector(model, projects)
	_scout_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_SCOUT) < 1
	_engineer_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_ENGINEER) < 1
	_side_road_button.visible = not specialists.is_empty()
	_side_road_button.disabled = not _has_idle_engineer(specialists)
	_side_road_button.text = "安排工程师维修受损道路（3 粮）" if has_selected_damage else "工程师拖线修路"
	_resume_project_button.visible = not _first_interrupted_project(projects).is_empty()
	_resume_project_button.disabled = not _has_idle_engineer(specialists)
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
		var draft_contains_bridge := THEATER.route_crosses_water(Array(_engineering_draft.get("route_world_points", _draw_points)))
		var draft_kind_label := ("加固路" if draft_kind == FieldTacticsState.ROAD_REINFORCED else "普通路") + ("（含桥梁）" if draft_contains_bridge else "")
		var draft_cost := 12 if draft_contains_bridge else (10 if draft_kind == FieldTacticsState.ROAD_REINFORCED else 5)
		_confirm_button.visible = true
		_confirm_button.text = "确认施工"
		_confirm_button.disabled = _engineering_draft.is_empty()
		_block_button.visible = false
		_recover_button.visible = false
		_retreat_button.visible = false
		_status_label.text = "工程草稿待确认；右键取消不会扣除资源。" if not _engineering_draft.is_empty() else "工程绘线：从工程师所在位置拖出道路。"
		_detail_label.text = "工程师：%s\n路径点：%d\n路线类型：%s\n预计粮食：%d；确认后才会扣除。" % [
			String(_engineering_engineer_id), Array(_engineering_draft.get("route_world_points", _draw_points)).size(), draft_kind_label, draft_cost,
		]
		return
	if army.is_empty():
		_status_label.text = ("工程绘线：从%s拖到可施工位置，确认后工程师前往施工。" if _engineering_mode else "从%s按住左键沿道路画到驻扎点或敌城；草稿可取消，确认后不可改道。") % str(source.get("display_name", source_id))
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
		_status_label.text = "%s：%s → %s" % [phase_text, str(source.get("display_name", source_id)), str(target.get("display_name", macro.target_point_id))]
		var war: Dictionary = model.get("war_loop", {})
		var siege := _siege_for_army(war, StringName(army.get("army_id", &"")))
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			_detail_label.text = "城门耐久：%d\n守军：%d\n我军可战：%d\n自动先行招降，未降则攻门并清剿守军。" % [int(siege.get("gate_hp", 0)), ceili(float(int(siege.get("defender_total_hp", 0))) / maxf(float(int(siege.get("defender_hp_per_member", 1))), 1.0)), ceili(float(int(siege.get("attacker_total_hp", 0))) / maxf(float(int(siege.get("attacker_hp_per_member", 1))), 1.0))]
		else:
			var blocked_detail := ""
			if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
				var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
				var transfer_target := _point_from_model(model, StringName(transfer.get("target_point_id", &"")))
				blocked_detail = "\n受阻路段：%d；临时状态：%s%s" % [int(macro.get("blocked_segment_index", -1)) + 1, String(transfer.get("phase", "NONE")), (" → %s" % str(transfer_target.get("display_name", transfer.get("target_point_id", "")))) if StringName(transfer.get("target_point_id", &"")) != &"" else ""]
			_detail_label.text = "原军令进度：%d%%\n粮食已扣：%d\n%s%s" % [roundi(float(macro.progress_millis) / maxf(float(macro.total_millis), 1.0) * 100.0), int(macro.food_cost), ("工程师维修后会沿实际道路接续原军令，不再扣粮。" if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED else "到达后可从驻扎点发出下一道军令。"), blocked_detail]
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
	_scout_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_SCOUT) < 1
	_engineer_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_ENGINEER) < 1
	_side_road_button.visible = _has_idle_engineer(specialists)
	_confirm_button.text = "确认施工" if not _engineering_draft.is_empty() else "确认并锁定军令"
	_confirm_button.disabled = (_engineering_draft.is_empty() and (_draft_route.is_empty() or _selected_formation_ids.is_empty()))


func _toggle_formation(formation_id: StringName) -> void:
	if formation_id in _selected_formation_ids:
		_selected_formation_ids.erase(formation_id)
	else:
		_selected_formation_ids.append(formation_id)
	refresh()


func _selected_formation_member_count(formations: Array) -> int:
	var total := 0
	for formation_value in formations:
		var formation: Dictionary = formation_value
		if StringName(formation.get("formation_id", &"")) in _selected_formation_ids:
			total += int(formation.get("member_count", 0))
	return total


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
		if _is_drawing:
			_append_draw_point(event.position)
			_pan_while_drawing(event.position)
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not _draft_route.is_empty() or not _engineering_draft.is_empty() or not _draw_points.is_empty() or _selected_damaged_road_id != &"":
			_draft_route = {}
			_engineering_draft = {}
			_engineering_mode = false
			_engineering_engineer_id = &""
			_selected_damaged_road_id = &""
			_draw_points.clear()
			_status_label.text = "路线草稿已取消；没有资源、编队或军令写入。"
			queue_redraw()
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
		var selected_id := _army_id_at_screen(_model(), event.position)
		if selected_id != &"":
			_selected_army_id = selected_id
			_selected_formation_ids.clear()
			_status_label.text = "已选中该军队；续令、撤逃与路线草稿只作用于它。"
			refresh()
			accept_event()
			return
		var damaged_road_id := _damaged_road_id_at_screen(_dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}, event.position)
		if damaged_road_id != &"":
			_selected_damaged_road_id = damaged_road_id
			_status_label.text = "已选中受损道路；可安排空闲工程师前往维修。"
			refresh()
			accept_event()
			return
		if not _can_draw_route():
			return
		var model := _model()
		var source := _point_from_model(model, _source_point_id(model, _selected_army(model)))
		var source_position := _world_to_screen(Vector2(source.get("world_position", Vector2.ZERO)))
		if event.position.distance_to(source_position) > 52.0:
			_status_label.text = "请从当前驻点开始画线。"
			return
		_is_drawing = true
		_draw_points = [_screen_to_world(event.position)]
		accept_event()
	else:
		if not _is_drawing:
			return
		_is_drawing = false
		_append_draw_point(event.position)
		_finish_draw()
		accept_event()


func _append_draw_point(screen_position: Vector2) -> void:
	var world := _screen_to_world(screen_position)
	if _draw_points.is_empty() or _draw_points.back().distance_to(world) >= 12.0:
		_draw_points.append(world)
		queue_redraw()


func _zoom_at_screen_position(screen_position: Vector2, requested_zoom: float) -> void:
	var anchor_world := _screen_to_world(screen_position)
	_camera_zoom = clampf(requested_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	_camera_center = anchor_world - (screen_position - _map_rect().get_center()) / _camera_zoom
	_clamp_camera()
	queue_redraw()


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	_camera_center -= screen_delta / _camera_zoom
	_clamp_camera()
	queue_redraw()


func _pan_while_drawing(screen_position: Vector2) -> void:
	var rect := _map_rect()
	var edge := 24.0
	var delta := Vector2.ZERO
	if screen_position.x <= rect.position.x + edge:
		delta.x = -12.0
	elif screen_position.x >= rect.end.x - edge:
		delta.x = 12.0
	if screen_position.y <= rect.position.y + edge:
		delta.y = -12.0
	elif screen_position.y >= rect.end.y - edge:
		delta.y = 12.0
	if not delta.is_zero_approx():
		_camera_center += delta / _camera_zoom
		_clamp_camera()
		queue_redraw()


func _finish_draw() -> void:
	var model := _model()
	var army := _selected_army(model)
	var source_id := _source_point_id(model, army)
	if _engineering_mode:
		_finish_engineering_draw(model, source_id)
		return
	var target_id := _nearest_target_at_draw_end(source_id)
	if target_id == &"":
		_draft_route = {}
		_status_label.text = "终点必须是另一处驻扎点或可进攻的敌城。"
		queue_redraw()
		return
	var decision := _choose_runtime_route_from_draw(model, source_id, target_id, _draw_points)
	if not bool(decision.valid):
		_draft_route = {}
		_status_label.text = str(decision.error)
		queue_redraw()
		return
	_draft_route = _ui_route_draft(Dictionary(decision.route))
	_status_label.text = "路线草稿已吸附到%s；确认后军令和粮食将锁定。" % str(_point_from_model(model, StringName(_draft_route.get("target_point_id", &""))).get("display_name", _draft_route.get("target_point_id", &"")))
	refresh()


func _finish_engineering_draw(model: Dictionary, source_id: StringName) -> void:
	if _engineering_engineer_id == &"" or _draw_points.size() < 2:
		_status_label.text = "工程路线至少需要两个位置。"
		return
	var target_id := _nearest_target_at_draw_end(source_id)
	# Water crossing is an attribute of the physical segment plan, not the
	# player's selected land material. FieldTacticsState turns only the water
	# spans into bridges when the confirmed project is built.
	var road_kind := FieldTacticsState.ROAD_NORMAL
	_engineering_draft = {
		"engineer_id": _engineering_engineer_id,
		"source_point_id": source_id,
		"target_point_id": target_id,
		"route_world_points": _draw_points.duplicate(true),
		"road_kind": road_kind,
		"build_camp": true,
	}
	_draw_points.clear()
	_status_label.text = "工程草稿已生成；确认施工才会扣除资源并派工程师前往。"
	refresh()


func _confirm_draft() -> void:
	if _dispatch_adapter == null:
		return
	if not _engineering_draft.is_empty():
		var engineering := _engineering_draft.duplicate(true)
		var engineering_result := _dispatch_adapter.begin_field_road_project(
			StringName(engineering.engineer_id), StringName(engineering.source_point_id),
			StringName(engineering.target_point_id), Array(engineering.route_world_points),
			StringName(engineering.road_kind), bool(engineering.build_camp)
		)
		if not bool(engineering_result.get("success", false)):
			_status_label.text = str(engineering_result.get("error", "工程施工失败"))
			return
		_engineering_draft = {}
		_engineering_mode = false
		_engineering_engineer_id = &""
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
	_selected_formation_ids.clear()
	_draw_points.clear()
	_draft_route = {}
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
	var result := _dispatch_adapter.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	_status_label.text = "侦察兵已从黑石城出发。" if bool(result.get("success", false)) else str(result.get("error", "侦察兵派遣失败"))
	refresh()


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
	for specialist_value in Dictionary(field.get("specialists_by_id", {})).values():
		var specialist: Dictionary = specialist_value
		if (
			StringName(specialist.get("role", &"")) != FieldTacticsState.SPECIALIST_ENGINEER
			or not bool(specialist.get("alive", false))
			or StringName(specialist.get("project_id", &"")) != &""
		):
			continue
		_engineering_mode = true
		_engineering_engineer_id = StringName(specialist.get("specialist_id", &""))
		_draw_points.clear()
		_draft_route = {}
		_status_label.text = "工程师已选中：从其所在位置按住左键拖出道路，终点可新建驻点。"
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


func _can_draw_route() -> bool:
	var army := _selected_army(_model())
	return (
		_engineering_mode
		or
		not _selected_formation_ids.is_empty()
		or army.is_empty()
		or StringName(army.phase) == ARMY_REGISTRY.PHASE_STATIONED
	)


func _source_point_id(model: Dictionary, army: Dictionary) -> StringName:
	if _engineering_mode and _dispatch_adapter != null:
		var specialist := Dictionary(_dispatch_adapter.get_field_tactics_read_model().get("specialists_by_id", {}).get(_engineering_engineer_id, {}))
		return StringName(specialist.get("current_point_id", &""))
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
		_selected_army_id = &""
		return {}
	_selected_army_id = StringName(Dictionary(armies.front()).get("army_id", &""))
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
	if _draw_points.is_empty():
		return &""
	var end: Vector2 = _draw_points.back()
	for point_id in _all_points(_model()):
		var point := _point_from_model(_model(), StringName(point_id))
		if StringName(point_id) != source_id and end.distance_to(Vector2(point.get("world_position", Vector2.ZERO))) <= 65.0:
			return StringName(point_id)
	return &""


func _all_points(model: Dictionary) -> Dictionary:
	var points := THEATER.get_points()
	for point_id_value in Dictionary(model.get("runtime_points", {})):
		points[StringName(point_id_value)] = Dictionary(model.runtime_points[point_id_value]).duplicate(true)
	return points


func _point_from_model(model: Dictionary, point_id: StringName) -> Dictionary:
	return Dictionary(_all_points(model).get(point_id, {})).duplicate(true)


func _choose_runtime_route_from_draw(model: Dictionary, source_id: StringName, target_id: StringName, draw_world_points: Array) -> Dictionary:
	if draw_world_points.size() < 2:
		return {"valid": false, "error": "请沿道路画出到目标驻点的路线"}
	var planned := _dispatch_adapter.plan_field_path(source_id, target_id, draw_world_points) if _dispatch_adapter != null else {}
	if bool(planned.get("valid", false)) and Array(planned.get("points", [])).size() >= 2:
		var planned_score := _draw_route_score(draw_world_points, Array(planned.points))
		if planned_score <= 105.0:
			return {"valid": true, "route": {"road_id": StringName(planned.route_id), "target_point_id": target_id, "route_world_points": Array(planned.points), "segment_ids": Array(planned.segments), "duration_milliseconds": int(planned.duration_milliseconds)}}
	var best_route: Dictionary = {}
	var best_score := INF
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	for route_value in Dictionary(field.get("roads_by_id", {})).values():
		var route: Dictionary = route_value
		if StringName(route.get("state", &"")) != FieldTacticsState.ROAD_OPEN:
			continue
		var route_points: Array = route.get("route_world_points", [])
		var forward := (
			StringName(route.get("source_point_id", &"")) == source_id
			and StringName(route.get("target_point_id", &"")) == target_id
		)
		var reverse := (
			StringName(route.get("target_point_id", &"")) == source_id
			and StringName(route.get("source_point_id", &"")) == target_id
		)
		if not forward and not reverse:
			continue
		var traversed := route.duplicate(true)
		if reverse:
			route_points.reverse()
			traversed.source_point_id = source_id
			traversed.target_point_id = target_id
			traversed.route_world_points = route_points
		var score := _draw_route_score(draw_world_points, route_points)
		if score < best_score:
			best_score = score
			best_route = traversed
	if best_route.is_empty() or best_score > 105.0:
		return {"valid": false, "error": "路线偏离可通行道路，或道路尚未完成。"}
	return {"valid": true, "route": best_route}


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


func _map_rect() -> Rect2:
	var panel_width := clampf(size.x * 0.28, 272.0, 340.0)
	return Rect2(Vector2(22, 96), Vector2(maxf(size.x - panel_width - 44.0, 400.0), maxf(size.y - 122.0, 360.0)))


func _side_panel_rect() -> Rect2:
	var panel_width := clampf(size.x * 0.28, 272.0, 340.0)
	return Rect2(Vector2(size.x - panel_width - 14.0, 94), Vector2(panel_width, maxf(size.y - 108.0, 360.0)))


func _minimap_rect() -> Rect2:
	var map_rect := _map_rect()
	var minimap_size := Vector2(minf(156.0, map_rect.size.x * 0.25), minf(104.0, map_rect.size.y * 0.22))
	return Rect2(map_rect.end - minimap_size - Vector2(14, 14), minimap_size)


func _visible_world_rect() -> Rect2:
	return Rect2(_camera_center - _map_rect().size / _camera_zoom * 0.5, _map_rect().size / _camera_zoom)


func _clamp_camera() -> void:
	var visible_size := _visible_world_rect().size
	var world_bounds := THEATER.get_world_bounds()
	var minimum_center := world_bounds.position + visible_size * 0.5
	var maximum_center := world_bounds.end - visible_size * 0.5
	if minimum_center.x > maximum_center.x:
		_camera_center.x = world_bounds.get_center().x
	else:
		_camera_center.x = clampf(_camera_center.x, minimum_center.x, maximum_center.x)
	if minimum_center.y > maximum_center.y:
		_camera_center.y = world_bounds.get_center().y
	else:
		_camera_center.y = clampf(_camera_center.y, minimum_center.y, maximum_center.y)


func _center_camera_from_minimap(screen_position: Vector2) -> void:
	var minimap := _minimap_rect()
	var normalized := (screen_position - minimap.position) / minimap.size
	_camera_center = THEATER.get_world_bounds().position + THEATER.get_world_bounds().size * normalized
	_clamp_camera()
	queue_redraw()


func _world_to_screen(world: Vector2) -> Vector2:
	return _map_rect().get_center() + (world - _camera_center) * _camera_zoom


func _screen_to_world(screen: Vector2) -> Vector2:
	return _camera_center + (screen - _map_rect().get_center()) / _camera_zoom


func _draw() -> void:
	var rect := _map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("19211e"))
	draw_rect(rect, Color("728b67"))
	_draw_terrain(rect)
	for water_region in THEATER.get_water_regions():
		var water_position := _world_to_screen(Vector2(water_region.position))
		var water_size := Vector2(water_region.size) * _camera_zoom
		draw_rect(Rect2(water_position, water_size), Color("4c95b5"), true)
	draw_rect(_side_panel_rect(), Color("eee4cc"))
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
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
		draw_polyline(points, color, width, true)
		draw_polyline(points, Color("4b3927"), 2.0, true)
	if not _draft_route.is_empty():
		var draft_points := PackedVector2Array()
		for point in _draft_route.points:
			draft_points.append(_world_to_screen(Vector2(point)))
		draw_polyline(draft_points, Color("54d7df"), 5.0, true)
	elif not _draw_points.is_empty():
		var drawn := PackedVector2Array()
		for point in _draw_points:
			drawn.append(_world_to_screen(point))
		draw_polyline(drawn, Color("54d7df"), 4.0, true)
	for army_value in Array(_model().get("armies", [])):
		_draw_army_marker(Dictionary(army_value))
	for camp_value in Dictionary(field.get("camps_by_id", {})).values():
		var camp: Dictionary = camp_value
		var camp_center := _world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO)))
		draw_rect(Rect2(camp_center - Vector2(11, 11), Vector2(22, 22)), Color("f0c46b"), true)
	for specialist_value in Dictionary(field.get("specialists_by_id", {})).values():
		var specialist: Dictionary = specialist_value
		if not bool(specialist.get("alive", false)):
			continue
		var specialist_color := Color("73d7ed") if StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else Color("f2b86e")
		var specialist_position := _world_to_screen(Vector2(specialist.get("world_position", Vector2.ZERO)))
		draw_circle(specialist_position, 10.0, specialist_color)
		draw_string(ThemeDB.fallback_font, specialist_position + Vector2(-5, 5), "侦" if StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else "工", HORIZONTAL_ALIGNMENT_CENTER, 12, 12, Color("1d2a30"))
	for point_value in _all_points(_model()).values():
		var point: Dictionary = point_value
		var center := _world_to_screen(Vector2(point.world_position))
		var enemy := StringName(point.get("point_kind", &"")) == &"ENEMY_CITY"
		draw_circle(center, 25.0, Color("5c2b25") if enemy else Color("273d3c"))
		draw_circle(center, 18.0, Color("c65a42") if enemy else Color("d7b465"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-38, 47), str(point.display_name), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
	_draw_minimap()
	draw_string(ThemeDB.fallback_font, Vector2(30, size.y - 20), "滚轮缩放 · 中键拖动 · 小地图定位 · 金：主道 · 青：道路 · 紫：桥 · 灰：受损 · 蓝侦/橙工", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e3dcc5"))


func _draw_terrain(rect: Rect2) -> void:
	# Greybox terrain is presentational only.  Routes and interactions continue
	# to use world coordinates and FieldTacticsState as their sole authority.
	for terrain_value in THEATER.get_terrain_regions():
		var terrain: Dictionary = terrain_value
		if StringName(terrain.get("kind", &"")) != &"FOREST":
			continue
		var forest := Rect2(terrain.get("rect", Rect2i()))
		var forest_rect := Rect2(_world_to_screen(forest.position), forest.size * _camera_zoom)
		draw_rect(forest_rect, Color("466044"), true)
		for offset in [Vector2(18, 24), Vector2(64, 58), Vector2(118, 30), Vector2(140, 92)]:
			draw_circle(_world_to_screen(forest.position + offset), 9.0 * _camera_zoom, Color("315039"))
	var shore := Rect2(_world_to_screen(Vector2(500, 330)), Vector2(155, 175) * _camera_zoom)
	draw_rect(shore, Color("98a969"), false, 3.0)
	draw_rect(rect, Color("d9cfaa"), false, 2.0)


func _draw_minimap() -> void:
	var minimap := _minimap_rect()
	draw_rect(minimap, Color("25332f"), true)
	for water_region in THEATER.get_water_regions():
		var world_bounds := THEATER.get_world_bounds()
		var normalized_position := (Vector2(water_region.position) - world_bounds.position) / world_bounds.size
		var normalized_size := Vector2(water_region.size) / world_bounds.size
		draw_rect(Rect2(minimap.position + minimap.size * normalized_position, minimap.size * normalized_size), Color("4c95b5"), true)
	for point_value in _all_points(_model()).values():
		var point: Dictionary = point_value
		var world_bounds := THEATER.get_world_bounds()
		var normalized := (Vector2(point.get("world_position", Vector2.ZERO)) - world_bounds.position) / world_bounds.size
		draw_circle(minimap.position + minimap.size * normalized, 3.0, Color("d94d3f") if StringName(point.get("point_kind", &"")) == &"ENEMY_CITY" else Color("f0c46b"))
	var view := _visible_world_rect()
	var world_bounds := THEATER.get_world_bounds()
	var viewport_position := minimap.position + minimap.size * ((view.position - world_bounds.position) / world_bounds.size)
	var viewport_size := minimap.size * (view.size / world_bounds.size)
	draw_rect(Rect2(viewport_position, viewport_size), Color("f6e5ba"), false, 1.5)
	draw_rect(minimap, Color("e3dcc5"), false, 1.0)


func _draw_army_marker(army: Dictionary) -> void:
	var display_route := _display_route_for_army(army)
	var points: Array = Array(display_route.get("points", []))
	var progress := float(display_route.get("progress_millis", 0)) / maxf(float(display_route.get("total_millis", 1)), 1.0)
	var position := _point_along_route(points, progress)
	var screen := _world_to_screen(position)
	draw_circle(screen, 18.0, Color("f8e3a6") if StringName(army.get("army_id", &"")) == _selected_army_id else Color("4b3927"))
	draw_circle(screen, 15.0, Color("d94d3f"))
	draw_circle(screen, 8.0, Color("fff0c5"))
	draw_colored_polygon(PackedVector2Array([screen + Vector2(4, -22), screen + Vector2(4, -6), screen + Vector2(17, -12)]), Color("f7d46b"))
	draw_line(screen + Vector2(4, -24), screen + Vector2(4, 6), Color("342b27"), 2.0)
	for offset in [-7.0, 0.0, 7.0]:
		draw_circle(screen + Vector2(offset, 12), 3.0, Color("f8e3a6"))
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
		draw_string(ThemeDB.fallback_font, screen + Vector2(18, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe8a3"))


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
