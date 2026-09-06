class_name MacroMarchR0
extends Control


signal return_to_city_requested

const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const ARMY_REGISTRY = preload("res://scripts/army/army_registry.gd")

var _dispatch_adapter: V5ArmyDispatchAdapter
var _draft_route: Dictionary = {}
var _selected_formation_ids: Array[StringName] = []
var _draw_points: Array[Vector2] = []
var _is_drawing := false
var _branch_blocked := false
var _formation_buttons: Array[Button] = []

var _title_label := Label.new()
var _status_label := Label.new()
var _detail_label := Label.new()
var _confirm_button := Button.new()
var _block_button := Button.new()
var _recover_button := Button.new()
var _retreat_button := Button.new()
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
	var army: Dictionary = model.get("army", {})
	_branch_blocked = not army.is_empty() and StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED
	_refresh_formation_controls(Array(model.get("formations", [])), army)
	_refresh_copy(model, army)
	_layout_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if _dispatch_adapter == null:
		return
	var army: Dictionary = _model().get("army", {})
	if army.is_empty():
		return
	if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
		_dispatch_adapter.advance_war_loop_time(roundi(delta * 1000.0))
		refresh()
		return
	if StringName(army.phase) not in [ARMY_REGISTRY.PHASE_MARCHING, ARMY_REGISTRY.PHASE_RETREATING]:
		return
	var macro: Dictionary = army.macro_march
	if _branch_blocked and _should_stop_before_blocked_segment(macro):
		var before := _progress_before_segment(macro, int(macro.blocked_segment_index))
		_dispatch_adapter.block_macro_march_at_segment(
			StringName(army.army_id), StringName(macro.order_id),
			int(macro.blocked_segment_index), before, &"临时路旁驻扎点"
		)
		_status_label.text = "支路中断：部队已在可达位置临时驻扎，原军令保持锁定。"
		refresh()
		return
	_dispatch_adapter.advance_macro_march_time(
		StringName(army.army_id), StringName(macro.order_id),
		int(macro.progress_millis), roundi(delta * 1000.0)
	)
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
	for button in [_confirm_button, _block_button, _recover_button, _retreat_button, _return_button]:
		button.focus_mode = Control.FOCUS_ALL
		add_child(button)
	_confirm_button.text = "确认并锁定军令"
	_block_button.text = "演示：中断南洼支路"
	_recover_button.text = "恢复支路并继续原军令"
	_retreat_button.text = "撤逃并沿原路返回"
	_return_button.text = "返回黑石城"
	_confirm_button.pressed.connect(_confirm_draft)
	_block_button.pressed.connect(_block_branch)
	_recover_button.pressed.connect(_recover_branch)
	_retreat_button.pressed.connect(_request_retreat)
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
	_return_button.position = Vector2(panel_left + 16, size.y - 58)
	_return_button.size = Vector2(274, 38)


func _refresh_formation_controls(formations: Array, army: Dictionary) -> void:
	for button in _formation_buttons:
		button.queue_free()
	_formation_buttons.clear()
	if not army.is_empty():
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
	var source_id := _source_point_id(model, army)
	var source := THEATER.get_point(source_id)
	var draft_text := "未画路线"
	if not _draft_route.is_empty():
		draft_text = "%s → %s" % [
			str(source.display_name),
			str(THEATER.get_point(StringName(_draft_route.target_point_id)).display_name),
		]
	if army.is_empty():
		_status_label.text = "从%s按住左键沿道路画到驻扎点或敌城；草稿可取消，确认后不可改道。" % str(source.display_name)
		_detail_label.text = "驻点：%s\n路线草稿：%s\n选择编队：%d\n粮食：%d\n当前公式：ceil(兵力 / %d)" % [
			str(source.display_name), draft_text, _selected_formation_ids.size(), int(model.food),
			int(model.get("maintenance_units_per_food", 1)),
		]
	else:
		var macro: Dictionary = army.macro_march
		var target := THEATER.get_point(StringName(macro.target_point_id))
		var phase_text := "行军中"
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED:
			phase_text = "受阻临时驻扎"
		elif StringName(army.phase) == ARMY_REGISTRY.PHASE_STATIONED:
			phase_text = "已抵达驻扎点"
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			phase_text = "自动攻城中"
		elif StringName(army.phase) == ARMY_REGISTRY.PHASE_RETREATING:
			phase_text = "有损撤逃中"
		_status_label.text = "%s：%s → %s" % [phase_text, str(source.display_name), str(target.display_name)]
		var war: Dictionary = model.get("war_loop", {})
		var siege: Dictionary = war.get("active_siege", {})
		if StringName(army.phase) == ARMY_REGISTRY.PHASE_SIEGING:
			_detail_label.text = "城门耐久：%d\n守军：%d\n我军可战：%d\n自动先行招降，未降则攻门并清剿守军。" % [int(siege.get("gate_hp", 0)), ceili(float(int(siege.get("defender_total_hp", 0))) / maxf(float(int(siege.get("defender_hp_per_member", 1))), 1.0)), ceili(float(int(siege.get("attacker_total_hp", 0))) / maxf(float(int(siege.get("attacker_hp_per_member", 1))), 1.0))]
		else:
			_detail_label.text = "进度：%d / %d ms\n粮食已扣：%d\n%s" % [int(macro.progress_millis), int(macro.total_millis), int(macro.food_cost), ("道路恢复后会继续原军令，不再扣粮。" if StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED else "到达后可从驻扎点发出下一道军令。")]
		_confirm_button.disabled = true
		_block_button.visible = StringName(army.phase) == ARMY_REGISTRY.PHASE_MARCHING and StringName(macro.route_id) == &"road.blackstone.northwatch.lowland"
		_recover_button.visible = StringName(army.phase) == ARMY_REGISTRY.PHASE_BLOCKED
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
	_confirm_button.disabled = _draft_route.is_empty() or _selected_formation_ids.is_empty()


func _toggle_formation(formation_id: StringName) -> void:
	if formation_id in _selected_formation_ids:
		_selected_formation_ids.erase(formation_id)
	else:
		_selected_formation_ids.append(formation_id)
	refresh()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not _draft_route.is_empty() or not _draw_points.is_empty():
			_draft_route = {}
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
		if not map_rect.has_point(event.position) or not _can_draw_route():
			return
		var source_position := _world_to_screen(Vector2(THEATER.get_point(_source_point_id(_model(), _model().get("army", {}))).world_position))
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
	var army: Dictionary = model.get("army", {})
	var source_id := _source_point_id(model, army)
	var target_id := _nearest_target_at_draw_end(source_id)
	if target_id == &"":
		_draft_route = {}
		_status_label.text = "终点必须是另一处驻扎点或可进攻的敌城。"
		queue_redraw()
		return
	var decision := THEATER.choose_route_from_draw(source_id, target_id, _draw_points)
	if not bool(decision.valid):
		_draft_route = {}
		_status_label.text = str(decision.error)
		queue_redraw()
		return
	_draft_route = Dictionary(decision.route).duplicate(true)
	_status_label.text = "路线草稿已吸附到%s；确认后军令和粮食将锁定。" % str(_draft_route.display_name)
	refresh()


func _confirm_draft() -> void:
	if _dispatch_adapter == null or _draft_route.is_empty():
		return
	var model := _model()
	var army: Dictionary = model.get("army", {})
	var result: Dictionary = {}
	if not army.is_empty():
		result = _dispatch_adapter.commit_macro_march_from_station(
			StringName(army.army_id), StringName(_draft_route.target_point_id),
			StringName(_draft_route.route_id), Array(_draft_route.points)
		)
	else:
		result = _dispatch_adapter.commit_macro_march_from_city(
			_selected_formation_ids, StringName(_draft_route.target_point_id),
			StringName(_draft_route.route_id), Array(_draft_route.points)
		)
	if not bool(result.get("success", false)):
		_status_label.text = str(result.get("error", "军令确认失败"))
		return
	_selected_formation_ids.clear()
	_draw_points.clear()
	_draft_route = {}
	_branch_blocked = false
	refresh()


func _block_branch() -> void:
	var army: Dictionary = _model().get("army", {})
	if army.is_empty():
		return
	var macro: Dictionary = army.macro_march
	if _dispatch_adapter.set_macro_march_route_blocked_for_scenario(
		StringName(macro.route_id), true
	):
		_branch_blocked = true
		_status_label.text = "南洼支路已中断；部队将在到达该路段前的可达位置停驻。"


func _recover_branch() -> void:
	var army: Dictionary = _model().get("army", {})
	if army.is_empty():
		return
	var macro: Dictionary = army.macro_march
	var resumed := _dispatch_adapter.resume_blocked_macro_march(
		StringName(army.army_id), StringName(macro.order_id)
	)
	if not resumed.is_empty():
		_dispatch_adapter.set_macro_march_route_blocked_for_scenario(StringName(macro.route_id), false)
		_branch_blocked = false
	refresh()


func _request_retreat() -> void:
	if _dispatch_adapter == null:
		return
	var result := _dispatch_adapter.request_macro_siege_retreat()
	if not bool(result.get("success", false)):
		_status_label.text = str(result.get("error", "撤逃军令失败"))
	refresh()


func _can_draw_route() -> bool:
	var army: Dictionary = _model().get("army", {})
	return army.is_empty() or StringName(army.phase) == ARMY_REGISTRY.PHASE_STATIONED


func _source_point_id(model: Dictionary, army: Dictionary) -> StringName:
	return StringName(model.get("source_point_id", &"blackstone_city")) if army.is_empty() else StringName(army.target_node_id)


func _nearest_target_at_draw_end(source_id: StringName) -> StringName:
	if _draw_points.is_empty():
		return &""
	var end: Vector2 = _draw_points.back()
	for point_id in THEATER.get_points():
		if StringName(point_id) != source_id and end.distance_to(Vector2(THEATER.get_point(point_id).world_position)) <= 65.0:
			return StringName(point_id)
	return &""


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
	draw_rect(Rect2(Vector2(size.x - 306, 94), Vector2(292, size.y - 108)), Color("eee4cc"))
	for route_value in THEATER.get_routes().values():
		var route: Dictionary = route_value
		var points := PackedVector2Array()
		for point in route.points:
			points.append(_world_to_screen(Vector2(point)))
		var color := Color("b89257") if int(route.blockable_segment_index) < 1 else Color("a7734b")
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
	var army: Dictionary = _model().get("army", {})
	if not army.is_empty():
		_draw_army_marker(army)
	for point_value in THEATER.get_points().values():
		var point: Dictionary = point_value
		var center := _world_to_screen(Vector2(point.world_position))
		var enemy := StringName(point.get("point_kind", &"")) == &"ENEMY_CITY"
		draw_circle(center, 25.0, Color("5c2b25") if enemy else Color("273d3c"))
		draw_circle(center, 18.0, Color("c65a42") if enemy else Color("d7b465"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-38, 47), str(point.display_name), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(30, size.y - 20), "主道不可破坏 · 南洼支路可中断 · 可向敌城发起攻城军令", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e3dcc5"))


func _draw_army_marker(army: Dictionary) -> void:
	var macro: Dictionary = army.macro_march
	var points: Array = macro.route_world_points
	var progress := float(macro.progress_millis) / maxf(float(macro.total_millis), 1.0)
	var position := _point_along_route(points, progress)
	var screen := _world_to_screen(position)
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
