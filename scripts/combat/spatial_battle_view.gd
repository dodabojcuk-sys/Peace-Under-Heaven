class_name SpatialBattleView
extends Control

var battle: C0BattleGraybox
var inspector: VBoxContainer
var sidebar: ScrollContainer
var detail: Label
var feedback: Label
var roster: VBoxContainer
var start: Button
var confirm_plan: Button
var support: MenuButton
var facility_buttons: Dictionary = {}
var draft: Dictionary = {}
var message := "点击编队选中；点击路标部署或移动；点击敌军/城门攻击；点击工位建设或维修"
var selected_route: StringName = &""
var last_selected := -1
var last_combat_notice := ""

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	sidebar = ScrollContainer.new()
	sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sidebar)
	inspector = VBoxContainer.new()
	inspector.add_theme_constant_override("separation", 7)
	sidebar.add_child(inspector)
	inspector.custom_minimum_size.x = 284
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(detail)
	roster = VBoxContainer.new()
	inspector.add_child(roster)
	for squad in battle.request.committed_force.squads:
		var id := int(squad.squad_id)
		add_button(str(squad.display_name), func(): battle.select_squad(id), roster)
	start = add_button("完成部署 · 开始战斗", func(): battle.start_battle(false))
	var commands := HBoxContainer.new()
	inspector.add_child(commands)
	add_button("坚守", func(): send("HOLD", [], selected_route), commands)
	add_button("撤退", func(): send("RETREAT", [], selected_route), commands)
	add_button("进攻", func(): send("ATTACK", [], selected_route), commands)
	support = MenuButton.new()
	support.text = "文官支援 · 消耗共享能量"
	inspector.add_child(support)
	for i in battle.official_support_button.get_popup().item_count:
		support.get_popup().add_item(battle.official_support_button.get_popup().get_item_text(i), i)
	support.get_popup().id_pressed.connect(func(id: int): battle._on_official_support_selected(id); refresh())
	for kind in [WartimeFacilityPlan.KIND_WATCH_PLATFORM, WartimeFacilityPlan.KIND_ARROW_TOWER, WartimeFacilityPlan.KIND_BARRICADE, WartimeFacilityPlan.KIND_SPIKE_TRAP, WartimeFacilityPlan.KIND_SIEGE_RAM]:
		if WartimeFacilityPlan.is_available_for_source(kind, battle.request.source_id):
			facility_buttons[kind] = add_button(battle._get_facility_name(kind), func(): battle._toggle_wartime_facility(kind); refresh())
	confirm_plan = add_button("确认工事方案 · 按原价扣木材", func(): battle._confirm_wartime_facility_plan(); refresh())
	add_button("维修选中工事", func(): battle._repair_damaged_wartime_facility(); refresh())
	add_button("维修黑石城门", func(): battle._repair_protect_target(); refresh()).visible = battle.request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 13)
	inspector.add_child(feedback)
	refresh()

func add_button(label: String, callback: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 30
	button.pressed.connect(callback)
	(parent if parent != null else inspector).add_child(button)
	return button

func map_rect() -> Rect2:
	return Rect2(12, 24, maxf(size.x - 344, 300), maxf(size.y - 70, 200))

func screen(p: Array) -> Vector2:
	var r := map_rect()
	return r.position + Vector2(float(p[0]) / (120 * 16), float(p[1] - 8 * 16) / (72 * 16)) * r.size

func current_units() -> Dictionary:
	var session := battle.coordinator.active_session
	if session != null and BattlefieldSpace.enabled(session):
		return session.spatial_state.units
	var units := {}
	for squad in battle.request.committed_force.squads:
		var id := str(squad.squad_id)
		units[id] = draft.get(id, BattlefieldSpace.point(84 if battle.request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE else 0, BattlefieldSpace.route_y(StringName(squad.route_id))))
	return units

func refresh() -> void:
	if not is_node_ready():
		return
	sidebar.position = Vector2(size.x - 310, 10)
	sidebar.size = Vector2(300, size.y - 20)
	inspector.size.x = 284
	var session := battle.coordinator.active_session
	var active := session != null
	start.visible = not active
	confirm_plan.visible = not active
	for button in facility_buttons.values():
		button.visible = not active
	var units := current_units()
	var id := str(battle._selected_squad_id)
	if units.has(id):
		if last_selected != battle._selected_squad_id:
			selected_route = BattlefieldSpace.route_at(units[id])
			last_selected = battle._selected_squad_id
		var p: Array = units[id]
		detail.text = "%s\n位置 (%d, %d) · %s" % [battle._get_committed_squad_name(battle._selected_squad_id), int(p[0]) / 16, int(p[1]) / 16, "正门通道" if BattlefieldSpace.route_at(p) == &"FRONT_GATE" else "侧门通道"]
		if selected_route != BattlefieldSpace.route_at(p):
			detail.text += "\n目标通道：%s" % ("正门" if selected_route == &"FRONT_GATE" else "侧门")
		if active:
			var squad := session.get_squad_state(battle._selected_squad_id)
			var task: Dictionary = session.spatial_state.tasks[id]
			detail.text += "\nHP %d · %s → (%d,%d)" % [int(squad.total_hp), command_name(str(task.kind)), int(task.target[0]) / 16, int(task.target[1]) / 16]
			var job := BattlefieldSpace.job(session, battle._selected_squad_id)
			if not job.is_empty():
				detail.text += "\n%s：%s" % ["作业中" if BattlefieldSpace.distance(p, job.target) <= BattlefieldSpace.WORK_RANGE else "前往工位", work_name(session, str(job.id))]
	support.disabled = not active or battle.official_support_button.disabled
	if active:
		for event in session.last_tick_facility_events:
			if event.kind == &"UNIT_HIT":
				last_combat_notice = "%s进入敌军射程，受到 %d 伤害（第 %d 刻）" % [battle._get_committed_squad_name(int(event.squad_id)), int(event.damage), int(event.tick)]
			elif event.kind == WartimeFacilityPlan.KIND_ARROW_TOWER and event.has("damage"):
				last_combat_notice = "箭塔命中射程内敌军：%d 伤害（第 %d 刻）" % [int(event.damage), int(event.tick)]
	feedback.text = message + "\n" + last_combat_notice + "\n\n" + battle.wartime_facility_status_label.text + "\n" + battle.status_label.text
	queue_redraw()

func send(kind: String, target: Array, route: StringName) -> void:
	var session := battle.coordinator.active_session
	if session == null:
		message = "先选择集结点完成部署，再开始战斗"
		refresh()
		return
	var before := session.get_snapshot()
	message = BattlefieldSpace.command(session, battle._selected_squad_id, kind, target, route)
	if message.is_empty():
		if not battle._checkpoint_active_battle_session():
			session.restore_snapshot(before)
			message = "保存失败，命令未提交"
		else:
			message = "命令已提交：%s；下一战斗刻执行" % command_name(kind)
	battle._refresh_battle_ui()

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var click: Vector2 = event.position
	if click.x > map_rect().end.x + 12:
		return
	accept_event()
	var units := current_units()
	var hit_overlap := {}
	for id in units:
		var key := str(units[id])
		var count := int(hit_overlap.get(key, 0))
		hit_overlap[key] = count + 1
		if click.distance_to(screen(units[id]) + Vector2(0, -count * 16)) < 12:
			battle.select_squad(int(id))
			message = "已选中 %s" % battle._get_committed_squad_name(int(id))
			refresh()
			return
	var session := battle.coordinator.active_session
	if session != null:
		for record in session.wartime_facility_state.get("facilities", []):
			if click.distance_to(screen(BattlefieldSpace.work_point(session, record)) + Vector2(0, 26)) < 15:
				selected_route = record.route_id
				battle._selected_repair_facility_id = record.facility_id
				message = battle._get_wartime_facility_status_text(record)
				refresh()
				return
		for route in session.routes:
			if click.distance_to(screen(session.spatial_state.enemies[str(route)])) < 20 or click.distance_to(screen(BattlefieldSpace.point(80, BattlefieldSpace.route_y(route)))) < 15:
				selected_route = route
				send("ATTACK", [], route)
				return
	if session == null:
		for route in [&"FRONT_GATE", &"SIDE_GATE"]:
			for kind in facility_buttons:
				var record := {"kind": kind, "route_id": route}
				var site := BattlefieldSpace.facility_point(record)
				if battle.request.source_id == BattleRequest.SOURCE_MACRO_SIEGE and kind == WartimeFacilityPlan.KIND_ARROW_TOWER: site[0] = 60 * 16
				if click.distance_to(screen(site) + Vector2(0, 26)) < 15:
					selected_route = route
					message = "已选择%s工位；确认方案后扣除木材" % battle._get_facility_name(kind)
					battle._toggle_wartime_facility(kind)
					refresh()
					return
	var nearest: Array = []
	var nearest_distance := 20.0
	for node in BattlefieldSpace.nodes():
		var d := click.distance_to(screen(node))
		if d < nearest_distance:
			nearest = node
			nearest_distance = d
	if nearest.is_empty():
		if session == null:
			draft.erase(str(battle._selected_squad_id))
		message = "此处没有可通行路标；未提交命令"
		refresh()
		return
	selected_route = BattlefieldSpace.route_at(nearest)
	if session == null:
		var legal_x := [60 * 16, 84 * 16, 100 * 16, 120 * 16] if battle.request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE else [0, 20 * 16]
		if int(nearest[0]) not in legal_x:
			draft.erase(str(battle._selected_squad_id))
			message = "不可部署：请选择绿色集结点"
		else:
			draft[str(battle._selected_squad_id)] = nearest
			message = "部署草稿 (%d,%d)，开始时与原军 HP 一起保存" % [int(nearest[0]) / 16, int(nearest[1]) / 16]
		refresh()
	else:
		send("MOVE", nearest, selected_route)

func _draw() -> void:
	if battle == null or battle.request == null:
		return
	var r := map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("172326"))
	draw_rect(r.grow(8), Color("303e36"))
	var session := battle.coordinator.active_session
	var is_defense := battle.request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE
	for y in BattlefieldSpace.YS:
		draw_line(screen(BattlefieldSpace.point(0, y)), screen(BattlefieldSpace.point(120, y)), Color("657262"), 24)
	for x in [20, 60, 100]:
		draw_line(screen(BattlefieldSpace.point(x, 24)), screen(BattlefieldSpace.point(x, 64)), Color("657262"), 24)
	for y in [8, 32, 72]:
		var end := 16 if y == 8 else (56 if y == 32 else 80)
		draw_line(screen(BattlefieldSpace.point(80, y)), screen(BattlefieldSpace.point(80, end)), Color("a0a69f"), 18)
	for route in [&"FRONT_GATE", &"SIDE_GATE"]:
		var p := screen(BattlefieldSpace.point(80, BattlefieldSpace.route_y(route)))
		var open := session != null and BattlefieldSpace.gate_open(session, route)
		draw_rect(Rect2(p - Vector2(9, 19), Vector2(18, 38)), Color("657262") if open else Color("bc935b"))
		text_at(p + Vector2(-28, -28), ("正门" if route == &"FRONT_GATE" else "侧门") + (" 已破" if open else " 封闭"))
	for node in BattlefieldSpace.nodes():
		var deployable := int(node[0]) in ([60 * 16, 84 * 16, 100 * 16, 120 * 16] if is_defense else [0, 20 * 16])
		draw_circle(screen(node), 5, Color("8ecda0") if deployable and session == null else Color("a0aa94"))
	text_at(r.position + Vector2(0, 0), "敌军接近区" if is_defense else "我方集结 / 医疗 / 撤离")
	text_at(r.position + Vector2(r.size.x * 0.68, 0), "城门内侧 / 医疗 / 撤离" if is_defense else "敌方城门与守军区")
	if session != null:
		for effect in session.official_support_state.get("effects", []):
			if effect.kind == session.SUPPORT_DOMAIN:
				var y := BattlefieldSpace.route_y(StringName(effect.route_id))
				var a := screen(BattlefieldSpace.point(0, y))
				var top := screen(BattlefieldSpace.point(0, y - 8))
				var bottom := screen(BattlefieldSpace.point(120, y + 8))
				draw_rect(Rect2(top, bottom - top), Color(0.4, 0.6, 1, 0.28))
				text_at(a + Vector2(10, -20), "通道领域 · 剩余 %d 刻" % (int(effect.expires_tick) - session.current_tick))
		for route in session.routes:
			if int(session.routes[route].enemy_total_hp) <= 0:
				continue
			var p := screen(session.spatial_state.enemies[str(route)])
			draw_circle(p, 14, Color("c06d55"))
			var observed := not is_defense or session._get_active_watch_platform_id(route) != &""
			text_at(p + Vector2(-24, 30), ("敌军 %d" % session._alive_members(int(session.routes[route].enemy_total_hp))) if observed else "敌军 · 未侦察")
		for record in session.wartime_facility_state.get("facilities", []):
			var p := screen(BattlefieldSpace.work_point(session, record))
			var color := Color("e1c982") if record.phase in [session.FACILITY_PHASE_ACTIVE, session.FACILITY_PHASE_DAMAGED] else Color("93999a")
			draw_rect(Rect2(p + Vector2(-10, 18), Vector2(20, 16)), color)
			text_at(p + Vector2(-24, 50), battle._get_facility_name(StringName(record.kind)))
			if record.kind == WartimeFacilityPlan.KIND_ARROW_TOWER:
				var origin := BattlefieldSpace.work_point(session, record)
				var outline := PackedVector2Array()
				for delta in [[36, 0], [0, 36], [-36, 0], [0, -36], [36, 0]]:
					outline.append(screen([int(origin[0]) + int(delta[0]) * 16, int(origin[1]) + int(delta[1]) * 16]))
				draw_polyline(outline, Color(0.9, 0.8, 0.4, 0.35), 1)
	else:
		for route in [&"FRONT_GATE", &"SIDE_GATE"]:
			for kind in facility_buttons:
				var record := {"kind": kind, "route_id": route}
				var site := BattlefieldSpace.facility_point(record)
				if not is_defense and kind == WartimeFacilityPlan.KIND_ARROW_TOWER: site[0] = 60 * 16
				draw_rect(Rect2(screen(site) + Vector2(-9, 18), Vector2(18, 16)), Color("899586"), false, 1)
				text_at(screen(site) + Vector2(-24, 50), battle._get_facility_name(kind), 12)
		for record in battle._pending_wartime_facility_plan.get("facilities", []):
			var p := BattlefieldSpace.facility_point(record)
			if not is_defense and record.kind == WartimeFacilityPlan.KIND_ARROW_TOWER:
				p[0] = 60 * 16
			draw_rect(Rect2(screen(p) + Vector2(-8, 18), Vector2(16, 16)), Color("e1c982"), false, 2)
			text_at(screen(p) + Vector2(-24, 50), battle._get_facility_name(StringName(record.kind)))
	var units := current_units()
	var overlap := {}
	for id in units:
		var p := screen(units[id])
		var key := str(units[id])
		var count := int(overlap.get(key, 0))
		overlap[key] = count + 1
		p += Vector2(0, -count * 16)
		var selected := int(id) == battle._selected_squad_id
		var squad: Dictionary = session.get_squad_state(int(id)) if session != null else {}
		if squad.get("exited", false):
			continue
		draw_circle(p, 13, Color("6ba6b0") if int(squad.get("total_hp", 1)) > 0 else Color("555555"))
		if selected:
			draw_arc(p, 18, 0, TAU, 32, Color("f4df9c"), 3)
			if session != null:
				var previous := p
				for waypoint in session.spatial_state.tasks[id].path:
					draw_line(previous, screen(waypoint), Color("9bbacb"), 1)
					previous = screen(waypoint)
		text_at(p + Vector2(-4, 5), str(id))
		if session != null:
			var fraction := float(squad.get("total_hp", 0)) / maxf(float(squad.get("initial_members", 1)) * session.request.committed_force.hp_per_member, 1)
			draw_rect(Rect2(p + Vector2(-14, -23), Vector2(28, 3)), Color("563a36"))
			draw_rect(Rect2(p + Vector2(-14, -23), Vector2(28 * fraction, 3)), Color("94c8ab"))
	draw_rect(Rect2(Vector2(size.x - 324, 0), Vector2(324, size.y)), Color("172326"))
	text_at(Vector2(12, size.y - 18), "实线为通道；封闭城门不可穿越。城垛与箭塔允许范围内越门射击；门侧作业距离 8。", 13)

func text_at(p: Vector2, text: String, font_size := 14) -> void:
	draw_string(ThemeDB.fallback_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("e2e4d7"))

func command_name(kind: String) -> String:
	return str({"AUTO": "进攻", "ATTACK": "进攻", "MOVE": "移动", "HOLD": "坚守", "RETREAT": "撤退", "WORK": "作业"}.get(kind, "待命"))

func work_name(session: BattleSession, id: String) -> String:
	if id == "gate": return "城门维修"
	for record in session.wartime_facility_state.get("facilities", []):
		if str(record.facility_id) == id: return battle._get_facility_name(record.kind)
	return "工事"
