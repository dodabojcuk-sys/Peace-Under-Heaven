class_name MacroMarchR0
extends Control


signal return_to_city_requested

const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const ARMY_REGISTRY = preload("res://scripts/army/army_registry.gd")

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
var _last_army_hit_position := Vector2.INF
var _army_hit_cycle_index := 0
var _formation_buttons: Array[Button] = []

var _title_label := Label.new()
var _status_label := Label.new()
var _detail_label := Label.new()
var _confirm_button := Button.new()
var _block_button := Button.new()
var _recover_button := Button.new()
var _retreat_button := Button.new()
var _scout_button := Button.new()
var _engineer_button := Button.new()
var _side_road_button := Button.new()
var _return_button := Button.new()


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
	for button in [_confirm_button, _block_button, _recover_button, _retreat_button, _scout_button, _engineer_button, _side_road_button, _return_button]:
		button.focus_mode = Control.FOCUS_ALL
		add_child(button)
	_confirm_button.text = "确认并锁定军令"
	_block_button.visible = false
	_recover_button.visible = false
	_retreat_button.text = "撤逃并沿原路返回"
	_scout_button.text = "派遣侦察兵（4 粮）"
	_engineer_button.text = "派遣工程师（8 粮）"
	_side_road_button.text = "工程师拖线修路"
	_return_button.text = "返回黑石城"
	_confirm_button.pressed.connect(_confirm_draft)
	_retreat_button.pressed.connect(_request_retreat)
	_scout_button.pressed.connect(_dispatch_scout)
	_engineer_button.pressed.connect(_dispatch_engineer)
	_side_road_button.pressed.connect(_build_side_road)
	_return_button.pressed.connect(func(): return_to_city_requested.emit())


func _layout_ui() -> void:
	var panel_left := size.x - 306.0
	_title_label.position = Vector2(22, 12)
	_title_label.size = Vector2(size.x - 44, 34)
	_status_label.position = Vector2(22, 48)
	_status_label.size = Vector2(size.x - 44, 36)
	_detail_label.position = Vector2(panel_left + 18, 108)
	_detail_label.size = Vector2(270, 180)
	var y := 302.0
	for button in _formation_buttons:
		button.position = Vector2(panel_left + 16, y)
		button.size = Vector2(274, 42)
		y += 48.0
	_confirm_button.position = Vector2(panel_left + 16, y + 6)
	_confirm_button.size = Vector2(274, 42)
	_block_button.position = Vector2(panel_left + 16, y + 56)
	_block_button.size = Vector2(274, 38)
	_recover_button.position = Vector2(panel_left + 16, y + 100)
	_recover_button.size = Vector2(274, 38)
	_retreat_button.position = Vector2(panel_left + 16, y + 144)
	_retreat_button.size = Vector2(274, 38)
	_scout_button.position = Vector2(panel_left + 16, y + 188)
	_scout_button.size = Vector2(274, 36)
	_engineer_button.position = Vector2(panel_left + 16, y + 230)
	_engineer_button.size = Vector2(274, 36)
	_side_road_button.position = Vector2(panel_left + 16, y + 272)
	_side_road_button.size = Vector2(274, 36)
	_return_button.position = Vector2(panel_left + 16, size.y - 58)
	_return_button.size = Vector2(274, 38)


func _refresh_formation_controls(formations: Array, army: Dictionary) -> void:
	for button in _formation_buttons:
		button.queue_free()
	_formation_buttons.clear()
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
		button.pressed.connect(_toggle_formation.bind(formation_id))
		add_child(button)
		_formation_buttons.append(button)


func _refresh_copy(model: Dictionary, army: Dictionary) -> void:
	_title_label.text = "黑石外城战区 · 军令与攻城"
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	var specialists: Dictionary = field.get("specialists_by_id", {})
	var projects: Dictionary = field.get("projects_by_id", {})
	var visible_patrols: Dictionary = field.get("visible_patrols_by_id", {})
	var has_selected_damage := _selected_damaged_road_id != &"" and StringName(Dictionary(field.get("roads_by_id", {})).get(_selected_damaged_road_id, {}).get("state", &"")) == FieldTacticsState.ROAD_DAMAGED
	_scout_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_SCOUT) < 1
	_engineer_button.visible = _count_available_specialists(specialists, FieldTacticsState.SPECIALIST_ENGINEER) < 1
	_side_road_button.visible = not specialists.is_empty()
	_side_road_button.disabled = not _has_idle_engineer(specialists)
	_side_road_button.text = "安排工程师维修受损道路（3 粮）" if has_selected_damage else "工程师拖线修路"
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
		var draft_kind_label := "桥梁" if draft_kind == FieldTacticsState.ROAD_BRIDGE else "普通路"
		var draft_cost := 12 if draft_kind == FieldTacticsState.ROAD_BRIDGE else 5
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
		_detail_label.text = "驻点：%s\n路线草稿：%s\n选择编队：%d\n粮食：%d\n侦察情报：%d\n工程：%d" % [
			str(source.get("display_name", source_id)), draft_text, _selected_formation_ids.size(), int(model.food),
			visible_patrols.size(), projects.size(),
		]
	else:
		var macro: Dictionary = army.macro_march
		var target := _point_from_model(model, StringName(macro.target_point_id))
		var phase_text := "行军中"
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
			phase_text = "受阻临时驻扎"
		elif StringName(army.phase) == ARMY_REGISTRY.PHASE_STATIONED:
			phase_text = "已抵达驻扎点"
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			phase_text = "自动攻城中"
		elif StringName(army.phase) == ARMY_REGISTRY.PHASE_RETREATING:
			phase_text = "有损撤逃中"
		_status_label.text = "%s：%s → %s" % [phase_text, str(source.get("display_name", source_id)), str(target.get("display_name", macro.target_point_id))]
		var war: Dictionary = model.get("war_loop", {})
		var siege: Dictionary = war.get("active_siege", {})
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			_detail_label.text = "城门耐久：%d\n守军：%d\n我军可战：%d\n自动先行招降，未降则攻门并清剿守军。" % [int(siege.get("gate_hp", 0)), ceili(float(int(siege.get("defender_total_hp", 0))) / maxf(float(int(siege.get("defender_hp_per_member", 1))), 1.0)), ceili(float(int(siege.get("attacker_total_hp", 0))) / maxf(float(int(siege.get("attacker_hp_per_member", 1))), 1.0))]
		else:
			_detail_label.text = "行军进度：%d%%\n粮食已扣：%d\n%s" % [roundi(float(macro.progress_millis) / maxf(float(macro.total_millis), 1.0) * 100.0), int(macro.food_cost), ("道路恢复后会继续原军令，不再扣粮。" if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED else "到达后可从驻扎点发出下一道军令。")]
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
			and StringName(specialist.get("phase", &"")) != FieldTacticsState.SPECIALIST_BUILDING
		):
			return true
	return false


func _on_gui_input(event: InputEvent) -> void:
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
		if event is InputEventMouseMotion and _is_drawing:
			_append_draw_point(event.position)
		return
	var map_rect := _map_rect()
	if event.pressed:
		if not map_rect.has_point(event.position):
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
	var road_kind := FieldTacticsState.ROAD_BRIDGE if THEATER.route_crosses_water(_draw_points) else FieldTacticsState.ROAD_NORMAL
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
			or StringName(specialist.get("phase", &"")) == FieldTacticsState.SPECIALIST_BUILDING
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


func _army_id_at_screen(model: Dictionary, screen_position: Vector2) -> StringName:
	var hits: Array[StringName] = []
	for army_value in Array(model.get("armies", [])):
		var army: Dictionary = army_value
		var macro: Dictionary = army.get("macro_march", {})
		var points: Array = macro.get("route_world_points", [])
		if points.is_empty():
			continue
		var progress := float(macro.get("progress_millis", 0)) / maxf(float(macro.get("total_millis", 1)), 1.0)
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
	}


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
	return Rect2(Vector2(22, 96), Vector2(maxf(size.x - 350.0, 400.0), maxf(size.y - 122.0, 360.0)))


func _world_to_screen(world: Vector2) -> Vector2:
	var rect := _map_rect()
	return rect.position + Vector2(world.x / 1000.0 * rect.size.x, world.y / 650.0 * rect.size.y)


func _screen_to_world(screen: Vector2) -> Vector2:
	var rect := _map_rect()
	return Vector2(
		(screen.x - rect.position.x) / rect.size.x * 1000.0,
		(screen.y - rect.position.y) / rect.size.y * 650.0
	)


func _draw() -> void:
	var rect := _map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("19211e"))
	draw_rect(rect, Color("728b67"))
	for water_region in THEATER.get_water_regions():
		var water_position := _world_to_screen(Vector2(water_region.position))
		var water_size := Vector2(
			float(water_region.size.x) / 1000.0 * rect.size.x,
			float(water_region.size.y) / 650.0 * rect.size.y
		)
		draw_rect(Rect2(water_position, water_size), Color("4c95b5"), true)
	draw_rect(Rect2(Vector2(size.x - 306, 94), Vector2(292, size.y - 108)), Color("eee4cc"))
	var field := _dispatch_adapter.get_field_tactics_read_model() if _dispatch_adapter != null else {}
	for route_value in Dictionary(field.get("roads_by_id", {})).values():
		var route: Dictionary = route_value
		var points := PackedVector2Array()
		for point in Array(route.get("route_world_points", [])):
			points.append(_world_to_screen(Vector2(point)))
		if points.size() < 2:
			continue
		var damaged := StringName(route.get("state", &"")) == FieldTacticsState.ROAD_DAMAGED
		var color := Color("66535c") if damaged else (Color("68b8a7") if StringName(route.get("road_kind", &"")) != FieldTacticsState.ROAD_MAIN else Color("b89257"))
		draw_polyline(points, color, 14.0, true)
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
		draw_circle(_world_to_screen(Vector2(specialist.get("world_position", Vector2.ZERO))), 9.0, specialist_color)
	for point_value in _all_points(_model()).values():
		var point: Dictionary = point_value
		var center := _world_to_screen(Vector2(point.world_position))
		var enemy := StringName(point.get("point_kind", &"")) == &"ENEMY_CITY"
		draw_circle(center, 25.0, Color("5c2b25") if enemy else Color("273d3c"))
		draw_circle(center, 18.0, Color("c65a42") if enemy else Color("d7b465"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-38, 47), str(point.display_name), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(30, size.y - 20), "金色：主道 · 青色：工程道路 · 灰色：受损道路 · 蓝：侦察 · 橙：工程", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e3dcc5"))


func _draw_army_marker(army: Dictionary) -> void:
	var macro: Dictionary = army.macro_march
	var points: Array = macro.route_world_points
	var progress := float(macro.progress_millis) / maxf(float(macro.total_millis), 1.0)
	var position := _point_along_route(points, progress)
	var screen := _world_to_screen(position)
	draw_circle(screen, 18.0, Color("f8e3a6") if StringName(army.get("army_id", &"")) == _selected_army_id else Color("4b3927"))
	draw_circle(screen, 15.0, Color("d94d3f"))
	draw_circle(screen, 8.0, Color("fff0c5"))
	if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
		draw_string(ThemeDB.fallback_font, screen + Vector2(18, -12), "受阻驻扎", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe8a3"))


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
