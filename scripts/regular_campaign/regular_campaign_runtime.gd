class_name RegularCampaignRuntime
extends RefCounted

const Rules = preload("res://scripts/regular_campaign/regular_campaign_rules.gd")
const SCOPE := &"regular.qingyuan.r1"
const BASE := &"blackstone_city"
const STEP_MS := 250
const CYCLE_MS := 180000
const BUILD_KINDS := [&"FARM", &"LOGGING", &"WAREHOUSE", &"CLINIC"]
const DEFINITIONS := {&"FARM": "res://resources/definitions/buildings/farm.tres", &"LOGGING": "res://resources/definitions/buildings/logging_camp.tres", &"WAREHOUSE": "res://resources/definitions/buildings/warehouse.tres", &"CLINIC": "res://resources/definitions/buildings/clinic.tres"}

var city: Node
var data: Dictionary = {}
var feedback := ""
var _frame_fraction := 0.0
var _view: Control
var _failure_point := &""
var _last_checkpoint: Dictionary = {}

func _init(controller: Node) -> void:
	city = controller

func enabled() -> bool:
	return not data.is_empty()

func active() -> bool:
	return enabled() and data.phase in [&"ACTIVE", &"PENDING"]

func initialize_new() -> void:
	MacroMarchTheater.use_regular_definition()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	data = {"version": 1, "campaign_id": SCOPE, "phase": &"PREPARATION", "view_context": {"surface": &"PREPARATION", "city_id": &""}, "mainline_elapsed_ms": 0, "attempt_elapsed_ms": 0, "step_remainder_ms": 0, "pressure": {}, "history": [], "attempt_sequence": 0, "entry": {}, "departure_ledger": {}, "army_ids": [], "local_by_army": {}, "wounded_by_army": {}, "fallen_home": 0, "fallen_local": 0, "combat_losses_total": 0, "buildings": [], "project": {}, "next_building_id": 1, "training": {}, "treatment": {}, "starvation_cycles": 0, "enemy_growth_events": 0, "enemy_reserve": 120, "local_joined": 0, "scouted": {}, "summary": {}, "settlement_id": &"", "totals": {"food_in": 0, "wood_in": 0, "food_produced": 0, "wood_produced": 0, "food_used": 0, "wood_used": 0}}
	_assess()

func get_snapshot() -> Dictionary:
	return data.duplicate(true)

func restore(snapshot: Dictionary) -> void:
	data = snapshot.duplicate(true)
	if not data.has("view_context"):
		data.view_context = {"surface": &"THEATER" if data.get("phase", &"PREPARATION") != &"PREPARATION" else &"PREPARATION", "city_id": &""}
	_frame_fraction = 0.0
	if enabled():
		MacroMarchTheater.use_regular_definition()

func population_offset() -> int:
	if not active():
		return 0
	var pending := int(data.fallen_home)
	for pair in data.wounded_by_army.values():
		pending += int(pair.home)
	for count in data.local_by_army.values():
		pending -= int(count)
	return pending

func command(action: StringName, args: Dictionary = {}) -> Dictionary:
	if not enabled():
		return _error("常规关卡未启用")
	var before: Dictionary = city.export_v5_campaign_snapshot()
	if before.is_empty():
		return _error("无法建立安全事务快照")
	var result: Dictionary
	match action:
		&"depart": result = _depart(args)
		&"move": result = _move(args)
		&"build": result = _build(args)
		&"workers": result = _workers(args)
		&"connect": result = _connect(args)
		&"cancel_build": result = _cancel_build()
		&"train": result = _train(args)
		&"supply": result = _supply(args)
		&"treat": result = _treat()
		&"scout": result = _scout(args)
		&"retry": result = _retry()
		&"outcome": result = _outcome(StringName(args.get("kind", &"WITHDRAW")))
		&"confirm": result = _confirm()
		&"claim": result = _claim()
		&"view": result = _set_view_context(args)
		_: result = _error("未知行动")
	if bool(result.get("success", false)):
		_assess()
		if _failure_point == action or not bool(city._persist_macro_march_checkpoint().get("success", false)):
			result = _error("保存未完成，行动已回滚，请重试")
	if not bool(result.get("success", false)):
		city._apply_validated_v5_campaign_snapshot(before, false)
	if bool(result.get("success", false)):
		_last_checkpoint = city.export_v5_campaign_snapshot()
	feedback = str(result.get("error", result.get("message", "行动已确认")))
	city._refresh_city_ui()
	city.city_state_changed.emit()
	return result

func _depart(args: Dictionary) -> Dictionary:
	if data.phase != &"PREPARATION":
		return _error("本关已出征，不开放永久主城后援")
	if int(_stock().get(&"food", 0)) > 0 or int(_stock().get(&"wood", 0)) > 0:
		return _error("请先领取上次结算暂存物资后重新出征")
	var chosen: Array = args.get("formation_ids", [])
	var formations: Array = []
	for formation in city._garrison_state.get_formations():
		if formation.formation_id in chosen and int(formation.member_count) > 0:
			formations.append(formation)
	var food_amount := int(args.get("food", 30))
	var wood_amount := int(args.get("wood", 55))
	if formations.is_empty() or food_amount < 8 or wood_amount < 0 or food_amount > 80 or wood_amount > 80:
		return _error("请选择真实编队，携粮 8–80、木材 0–80")
	if not _transfer([{ "scope_id": &"", "resource_id": &"food", "delta": -food_amount}, {"scope_id": SCOPE, "resource_id": &"food", "delta": food_amount}, {"scope_id": &"", "resource_id": &"wood", "delta": -wood_amount}, {"scope_id": SCOPE, "resource_id": &"wood", "delta": wood_amount}], &"regular_departure"):
		return _error("主城物资不足")
	if not city._garrison_state.try_extract_selected_formations(formations):
		return _error("编队已被占用")
	var strategy: Dictionary = city._get_macro_order_strategy_snapshot()
	for formation in formations:
		var army: Dictionary = city._army_registry.create_regular_force(formation, Vector2i(110, 650), Vector2i(135, 650), strategy)
		if army.is_empty():
			return _error("军队身份分配失败")
		data.army_ids.append(army.army_id)
		data.local_by_army[army.army_id] = 0
		data.wounded_by_army[army.army_id] = {"home": 0, "local": 0}
	data.departure_ledger = {"food": food_amount, "wood": wood_amount, "formations": formations.duplicate(true)}
	data.phase = &"ACTIVE"
	data.view_context = {"surface": &"THEATER", "city_id": &""}
	data.attempt_sequence = int(data.attempt_sequence) + 1
	data.totals.food_in = food_amount
	data.totals.wood_in = wood_amount
	data.entry = {"army_registry": city._army_registry.get_snapshot(), "war_loop": city._war_loop_state.get_snapshot(), "resources": _stock(), "formations": formations.duplicate(true), "state": {}}
	var initial := data.duplicate(true)
	initial.entry = {}
	initial.pressure = {}
	initial.history = []
	data.entry.state = initial
	return _ok("首批兵粮已转入本关；家中不再供给关内军令")

func _set_view_context(args: Dictionary) -> Dictionary:
	var surface := StringName(args.get("surface", &"THEATER"))
	var city_id := StringName(args.get("city_id", &""))
	if surface == &"CITY":
		# R1C phase-UI：拒绝原因按真实阶段拆分，不再把"阶段未到"与"地点无资格"混成一句。
		if data.phase == &"PREPARATION":
			return _error("尚未确认首批兵粮：请先在永久主城完成备战，确认后经战区进入许可城市。")
		if city_id != BASE:
			return _error("此处仅支持休整与有限补给，没有战时内城建设许可。")
		if data.phase not in [&"ACTIVE", &"PENDING"]:
			return _error("本关已结算，战时内城不再开放建设入口。")
		data.view_context = {"surface": &"CITY", "city_id": city_id}
		return _ok("已进入本关城市的战时内城")
	if surface == &"THEATER" and data.phase != &"PREPARATION":
		data.view_context = {"surface": &"THEATER", "city_id": &""}
		return _ok("已返回本关战区")
	if surface == &"THEATER" and data.phase == &"PREPARATION":
		return _error("首批投入尚未确认：先在准备页勾选编队并点击「确认首批投入 · 进入战役」，之后才能进入战区。")
	return _error("当前状态无法切换场景：请先完成本页操作后再试。")

func advance(real_seconds: float) -> void:
	if not enabled() or city.city_time_paused or real_seconds <= 0:
		return
	var exact: float = real_seconds * city.city_time_speed * 1000.0 + _frame_fraction
	var elapsed := floori(exact + 0.000001)
	_frame_fraction = maxf(exact - elapsed, 0.0)
	var budget := int(data.step_remainder_ms) + elapsed
	data.step_remainder_ms = budget % STEP_MS
	for index in range(budget / STEP_MS):
		if city.city_time_paused:
			break
		_tick()

func _tick() -> void:
	if _last_checkpoint.is_empty():
		_last_checkpoint = city.export_v5_campaign_snapshot()
	data.mainline_elapsed_ms = mini(int(data.mainline_elapsed_ms) + STEP_MS, 1000000000)
	city.advance_city_time(float(STEP_MS) / 1000.0)
	if data.phase == &"ACTIVE":
		data.attempt_elapsed_ms += STEP_MS
		city._war_loop_state.field_tactics.world_milliseconds += STEP_MS
		_advance_projects()
		if int(data.attempt_elapsed_ms) % CYCLE_MS == 0:
			_local_cycle()
		_advance_armies()
		if int(data.attempt_elapsed_ms) % 1000 == 0:
			_update_scouting()
		_grow_enemy()
		if city._war_loop_state.is_level_cleared():
			command(&"outcome", {"kind": &"VICTORY"})
	if int(data.mainline_elapsed_ms) % 15000 == 0:
		_assess()
		var saved: Dictionary = {"success": false} if _failure_point == &"tick" else city._persist_macro_march_checkpoint()
		if not bool(saved.get("success", false)):
			if not _last_checkpoint.is_empty():
				city._apply_validated_v5_campaign_snapshot(_last_checkpoint, false)
			city.city_time_paused = true
			feedback = "自动保存失败，已恢复上次检查点并暂停；请重试保存后继续"
		else:
			_last_checkpoint = city.export_v5_campaign_snapshot()
	city.city_state_changed.emit()

func _move(args: Dictionary) -> Dictionary:
	if data.phase != &"ACTIVE":
		return _error("当前不能下达关内军令")
	var id := StringName(args.get("army_id", &""))
	var target := StringName(args.get("target_id", &""))
	var army: Dictionary = city._army_registry.get_army(id)
	if id not in data.army_ids or army.is_empty() or army.phase == ArmyRegistry.PHASE_CLOSED:
		return _error("请先选择本关军队")
	if data.training.get("army_id", &"") == id or data.treatment.get("army_id", &"") == id:
		return _error("本队正在训练或治疗，请完成后再行军")
	if _assigned_workers() > 0 and army.target_node_id == BASE and army.phase == ArmyRegistry.PHASE_STATIONED:
		if _base_members() - _members(army) < _assigned_workers():
			return _error("请先释放本队承担的生产/施工岗位，再调动军队")
	if army.phase == ArmyRegistry.PHASE_SIEGING:
		var siege: Dictionary = city._war_loop_state.get_siege(army.target_node_id)
		if not siege.is_empty():
			city._war_loop_state.mark_retreat_at(army.target_node_id, city.WAR_LOOP_RULES)
			_finish_siege(city._war_loop_state.get_siege(army.target_node_id))
		army = city._army_registry.get_army(id)
	if army.phase == ArmyRegistry.PHASE_CLOSED:
		return _error("该队已无可用兵力")
	var route := _route_from_army(army, target)
	if route.is_empty():
		return _error("没有可用道路，不能穿越地形瞬移")
	var result: Dictionary = city._army_registry.redirect_regular_force(id, target, route.points, maxi(1000, roundi(_path_length(route.points) * 85.0)), route.segments)
	return _ok("关内军令已更新，兵员身份与本地供粮保持不变") if not result.is_empty() else _error("军令未能提交")

func _advance_armies() -> void:
	for id in data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		if army.phase == ArmyRegistry.PHASE_MARCHING:
			city._army_registry.advance_macro_march(id, army.macro_march.order_id, int(army.progress_milliseconds), STEP_MS)
			army = city._army_registry.get_army(id)
		if army.phase == ArmyRegistry.PHASE_STATIONED and city._war_loop_state.is_enemy_city(army.target_node_id):
			if city._war_loop_state.get_siege(army.target_node_id).is_empty():
				var strategy: Dictionary = army.macro_march.get("strategy_snapshot", {})
				var attack := maxi(1, roundi(float(city.INFANTRY_ROLE.attack) * int(strategy.get("attack_basis_points", 10000)) / 10000.0))
				var armor := maxi(0, int(city.INFANTRY_ROLE.armor) + roundi((int(strategy.get("defense_basis_points", 10000)) - 10000) / 1000.0))
				var siege: Dictionary = city._war_loop_state.begin_siege(id, army.macro_march.order_id, army.target_node_id, _members(army), city.INFANTRY_ROLE.hp, attack, armor, 10000, city.WAR_LOOP_RULES)
				if not siege.is_empty():
					city._army_registry.begin_macro_siege(id, army.macro_march.order_id)
					_reveal_point(army.target_node_id)
					var target_name := str(MacroMarchTheater.get_point(StringName(army.target_node_id)).get("display_name", "目标据点"))
					var attacking_formations: Array = Array(army.macro_march.get("formation_snapshots", []))
					var attacker_name := str(Dictionary(attacking_formations[0]).get("display_name", "部队")) if not attacking_formations.is_empty() else "部队"
					feedback = "%s招降成功：守军已归顺，未发生战斗" % target_name if StringName(siege.get("resolution", &"")) == WarLoopState.RESOLUTION_SURRENDER else "%s拒绝招降：%s开始进攻" % [target_name, attacker_name]
	for siege in city._war_loop_state.get_active_sieges():
		var site := StringName(siege.city_id)
		city._war_loop_state.advance_siege_elapsed(site, STEP_MS, city.WAR_LOOP_RULES)
		var after: Dictionary = city._war_loop_state.get_siege(site)
		if not after.is_empty() and after.phase in [WarLoopState.PHASE_OCCUPIED, WarLoopState.PHASE_FAILED]:
			_finish_siege(after)

func _finish_siege(siege: Dictionary) -> void:
	var id := StringName(siege.army_id)
	var army: Dictionary = city._army_registry.get_army(id)
	var survivors := ceili(float(siege.attacker_total_hp) / float(siege.attacker_hp_per_member))
	_apply_losses(id, maxi(0, _members(army) - survivors), &"COMBAT")
	var resolution := StringName("regular.%d.%s" % [int(data.attempt_sequence), siege.siege_id])
	if siege.phase == WarLoopState.PHASE_OCCUPIED:
		city._war_loop_state.occupy_siege(siege.city_id, resolution)
	else:
		city._war_loop_state.close_failed_siege_at(siege.city_id, resolution)
	army = city._army_registry.get_army(id)
	if army.phase != ArmyRegistry.PHASE_CLOSED:
		city._army_registry.complete_macro_siege(id, army.macro_march.order_id)
	var surrendered := StringName(siege.get("resolution", &"")) == WarLoopState.RESOLUTION_SURRENDER or (
		bool(siege.get("surrender_checked_at_arrival", false))
		and int(siege.get("tick", 0)) == 0
		and StringName(siege.get("phase", &"")) == WarLoopState.PHASE_OCCUPIED
	)
	if surrendered:
		feedback = "%s招降成功：守军已归顺，未发生战斗" % str(MacroMarchTheater.get_point(StringName(siege.get("city_id", &""))).get("display_name", "目标据点"))
	else:
		feedback = "交战已结束：伤亡留在本次尝试，最终确认后统一归队"

func _apply_losses(id: StringName, losses: int, cause: StringName) -> void:
	if losses <= 0:
		return
	var army: Dictionary = city._army_registry.get_army(id)
	losses = mini(losses, _members(army))
	if cause == &"STARVATION" and army.phase == ArmyRegistry.PHASE_SIEGING:
		var site := StringName(army.target_node_id)
		var siege: Dictionary = city._war_loop_state.get_siege(site)
		if not siege.is_empty():
			siege.attacker_total_hp = maxi(0, int(siege.attacker_total_hp) - losses * int(siege.attacker_hp_per_member))
			if city._war_loop_state.active_siege.get("city_id", &"") == site:
				city._war_loop_state.active_siege = siege
			else:
				city._war_loop_state.parallel_sieges_by_city[site] = siege
	var local_losses := mini(int(data.local_by_army[id]), losses)
	var home_losses := losses - local_losses
	var home_wounded := home_losses / 2 if cause == &"COMBAT" else 0
	var local_wounded := local_losses / 2 if cause == &"COMBAT" else 0
	data.wounded_by_army[id].home += home_wounded
	data.wounded_by_army[id].local += local_wounded
	data.local_by_army[id] -= local_losses
	data.fallen_home += home_losses - home_wounded
	data.fallen_local += local_losses - local_wounded
	if cause == &"COMBAT":
		data.combat_losses_total += home_losses
	city._army_registry.replace_macro_composition(id, army.macro_march.order_id, _members(army) - losses)
	if _members(army) == losses:
		city._army_registry.close_regular_force(id)
		_cancel_orders_for(id)
	_trim_workers()

func _apply_wounded_starvation(losses: int) -> int:
	var remaining := maxi(losses, 0)
	var applied := 0
	for id in data.army_ids:
		if remaining <= 0:
			break
		var pair: Dictionary = data.wounded_by_army[id]
		for origin in ["home", "local"]:
			var deaths := mini(remaining, int(pair.get(origin, 0)))
			if deaths <= 0:
				continue
			pair[origin] = int(pair[origin]) - deaths
			if origin == "home":
				data.fallen_home += deaths
			else:
				data.fallen_local += deaths
			remaining -= deaths
			applied += deaths
		data.wounded_by_army[id] = pair
		# A closed force cannot carry an unfinished treatment order; consumed
		# treatment supplies remain spent, as with any other cancelled order.
		if _members(city._army_registry.get_army(id)) <= 0 and data.treatment.get("army_id", &"") == id:
			_cancel_orders_for(id)
	return applied


func _cancel_orders_for(id: StringName) -> void:
	if data.training.get("army_id", &"") == id:
		var count := int(data.training.count)
		var field: FieldTacticsState = city._war_loop_state.field_tactics
		field.stationed_reinforcements_by_point_id[&"silverford_city"] = field.get_stationed_reinforcements(&"silverford_city") + count
		var refund := count * int(city.INFANTRY_ROLE.recruit_food_per_unit)
		_spend(-refund, 0, &"regular_cancel_training")
		data.totals.food_used -= refund
		data.training = {}
	if data.treatment.get("army_id", &"") == id:
		# Treatment supplies already used are not recovered; the living wounded
		# remain assigned to their original army until the final home handover.
		data.treatment = {}

func _build(args: Dictionary) -> Dictionary:
	var point := StringName(args.get("point_id", BASE))
	var kind := StringName(args.get("kind", &""))
	# R1C phase-UI：阶段未满足与地点无资格分开表达；资格、费用与人数检查保持原样。
	if data.phase == &"PREPARATION":
		return _error("尚未确认首批兵粮：请先完成备战，确认后经战区进入许可城市开工。")
	if data.phase == &"PENDING":
		return _error("本关损益待确认，暂停新建设；请先在结算页确认本次损益。")
	if data.phase != &"ACTIVE":
		return _error("本关已结束，战时内城不再开放新建设。")
	if point != BASE:
		return _error("此处仅支持休整与有限补给，没有战时内城建设许可。")
	if kind not in BUILD_KINDS or not data.project.is_empty() or data.buildings.size() >= 6:
		return _error("建造位忙碌或已达本关六块可用地上限")
	if _base_members() - _assigned_workers() < 2:
		return _error("需要两名驻地军人组成施工队；请调回军队或释放岗位")
	if construction_modifier(kind) <= 0:
		return _error("主线迟延限制非必要建设；恢复许可仅用于实际口粮/医疗缺口")
	var plot := int(args.get("plot", data.buildings.size()))
	if plot < 0 or plot >= 6:
		return _error("请选择驻地内有效地块")
	for building in data.buildings:
		if int(building.plot) == plot:
			return _error("该地块已有建筑")
	var definition: BuildingDefinition = load(DEFINITIONS[kind])
	data.project = {"id": StringName("regular.building.%06d" % int(data.next_building_id)), "kind": kind, "plot": plot, "progress_ms": 0, "required_ms": 90000, "paid_wood": 0, "paid_food": 0, "wood_cost": definition.wood_cost, "food_cost": definition.food_cost}
	data.next_building_id += 1
	return _ok("已登记本关建设；材料按进度投入，缺料时保留进度")

func _cancel_build() -> Dictionary:
	if data.project.is_empty():
		return _error("没有可取消工程")
	var p: Dictionary = data.project
	_spend(-int(p.paid_food), -int(p.paid_wood), &"regular_build_refund")
	data.totals.food_used -= int(p.paid_food)
	data.totals.wood_used -= int(p.paid_wood)
	data.project = {}
	return _ok("已退还本工程实际投入，未生成建筑")

func _workers(args: Dictionary) -> Dictionary:
	var id := StringName(args.get("building_id", &""))
	var count := int(args.get("count", 0))
	for b in data.buildings:
		if b.id == id:
			if count < 0 or count > 4 or _assigned_workers() - int(b.workers) + count > _base_members():
				return _error("可用驻地军人不足；一人不能同时生产和出战")
			b.workers = count
			return _ok("已调整驻地岗位")
	return _error("建筑不存在")

func _connect(args: Dictionary) -> Dictionary:
	for b in data.buildings:
		if b.id == StringName(args.get("building_id", &"")):
			if bool(b.connected):
				return _error("该建筑已接入驻地道路")
			if not _spend(0, 2, &"regular_connect"):
				return _error("连接驻地道路需要 2 木材")
			b.connected = true
			data.totals.wood_used += 2
			return _ok("道路已接通；安排岗位后开始有效生产")
	return _error("建筑不存在")

func _advance_projects() -> void:
	if not data.project.is_empty():
		var p: Dictionary = data.project
		if _base_members() >= _assigned_workers():
			var progress := mini(int(p.required_ms), int(p.progress_ms) + STEP_MS * construction_modifier(p.kind) / 1000)
			var wood_due := ceili(float(int(p.wood_cost) * progress) / float(p.required_ms)) - int(p.paid_wood)
			var food_due := ceili(float(int(p.food_cost) * progress) / float(p.required_ms)) - int(p.paid_food)
			if _spend(food_due, wood_due, &"regular_construction"):
				p.progress_ms = progress
				p.paid_wood += wood_due
				p.paid_food += food_due
				data.totals.wood_used += wood_due
				data.totals.food_used += food_due
				if progress == int(p.required_ms):
					data.buildings.append({"id": p.id, "kind": p.kind, "plot": p.plot, "world_position": Vector2i(80 + int(p.plot) % 3 * 72, 715 + int(p.plot) / 3 * 75), "phase": &"ACTIVE", "progress_permille": 1000, "workers": 0, "connected": false, "durability": 100})
					data.project = {}
					feedback = "战时建筑已完成；请接通道路并安排驻地岗位"
	if not data.training.is_empty():
		var training_rate := mini(int(_forecast().training_permille), int(data.pressure.get("basic_training_permille", 1000)))
		data.training.progress_ms += STEP_MS * training_rate / 1000
		if int(data.training.progress_ms) >= int(data.training.required_ms):
			var train: Dictionary = data.training
			var army: Dictionary = city._army_registry.get_army(train.army_id)
			if army.phase == ArmyRegistry.PHASE_STATIONED and army.target_node_id == &"silverford_city":
				var preview: Dictionary = city._army_registry.preview_stationed_reinforcement(train.army_id, &"silverford_city", int(train.count))
				if bool(preview.get("valid", false)):
					var added: Dictionary = city._army_registry.replenish_stationed_army(train.army_id, &"silverford_city", preview.allocation)
					if not added.is_empty():
						data.local_by_army[train.army_id] += int(train.count)
						data.local_joined += int(train.count)
						data.training = {}
	if not data.treatment.is_empty() and _medical_capacity() > 0:
		data.treatment.progress_ms += STEP_MS
		if int(data.treatment.progress_ms) >= int(data.treatment.required_ms):
			var order: Dictionary = data.treatment
			var army: Dictionary = city._army_registry.get_army(order.army_id)
			if army.phase == ArmyRegistry.PHASE_STATIONED and army.target_node_id == BASE:
				var preview: Dictionary = city._army_registry.preview_stationed_reinforcement(order.army_id, BASE, int(order.home) + int(order.local))
				if bool(preview.get("valid", false)):
					var healed: Dictionary = city._army_registry.replenish_stationed_army(order.army_id, BASE, preview.allocation)
					if not healed.is_empty():
						data.wounded_by_army[order.army_id].home -= int(order.home)
						data.wounded_by_army[order.army_id].local -= int(order.local)
						data.local_by_army[order.army_id] += int(order.local)
						data.treatment = {}

func _train(args: Dictionary) -> Dictionary:
	var id := StringName(args.get("army_id", &""))
	var army: Dictionary = city._army_registry.get_army(id)
	if data.phase != &"ACTIVE" or id not in data.army_ids or not data.training.is_empty() or army.is_empty() or army.phase != ArmyRegistry.PHASE_STATIONED or army.target_node_id != &"silverford_city" or city._war_loop_state.is_enemy_city(&"silverford_city"):
		return _error("须控制溪渡，并选择驻扎于该城的本关军队")
	var count := mini(2, city._war_loop_state.field_tactics.get_stationed_reinforcements(&"silverford_city"))
	var preview: Dictionary = city._army_registry.preview_stationed_reinforcement(id, &"silverford_city", count)
	count = int(preview.get("amount", 0))
	if count <= 0 or not bool(preview.get("valid", false)):
		return _error("当地有限兵源已用尽或编队没有容量")
	if not _spend(count * int(city.INFANTRY_ROLE.recruit_food_per_unit), 0, &"regular_train"):
		return _error("本地粮食不足以训练")
	data.totals.food_used += count * int(city.INFANTRY_ROLE.recruit_food_per_unit)
	if not city._war_loop_state.field_tactics.consume_stationed_reinforcements(&"silverford_city", count):
		return _error("有限兵源已被占用")
	data.training = {"army_id": id, "count": count, "progress_ms": 0, "required_ms": 90000}
	return _ok("当地预备人员开始训练；本关结束后按来源留当地")

func _treat() -> Dictionary:
	if data.phase != &"ACTIVE" or not data.treatment.is_empty() or _medical_capacity() <= 0:
		return _error("需要已接路、有人工作的医舍及空闲治疗位")
	for id in data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		var pair: Dictionary = data.wounded_by_army[id]
		if army.phase == ArmyRegistry.PHASE_STATIONED and army.target_node_id == BASE and int(pair.home) + int(pair.local) > 0:
			var home := mini(int(pair.home), _medical_capacity())
			var local := mini(int(pair.local), _medical_capacity() - home)
			if not _spend(home + local, 0, &"regular_treatment"):
				return _error("治疗需要实际粮食")
			data.totals.food_used += home + local
			data.treatment = {"army_id": id, "home": home, "local": local, "progress_ms": 0, "required_ms": 90000}
			return _ok("伤员接受治疗；阵亡者不会复活")
	return _error("请让有伤员的原编队回驻地接受治疗")

func _scout(args: Dictionary) -> Dictionary:
	var point := StringName(args.get("point_id", &""))
	var target: Dictionary = MacroMarchTheater.get_points().get(point, {})
	if target.is_empty():
		return _error("没有该侦察地点")
	for id in data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		if army.phase != ArmyRegistry.PHASE_CLOSED and _army_world_position(army).distance_to(Vector2(target.world_position)) <= MacroMarchTheater.get_scout_visibility_range():
			_reveal_point(point)
			return _ok("已侦察本队视野内的据点；离开视野后只保留上次观察")
	return _error("请先沿道路接近目标；超出视野不能获知精确兵力")

func _reveal_point(point: StringName) -> void:
	var defender: Dictionary = city._war_loop_state.get_city(point)
	data.scouted[point] = {"defender_count": int(defender.get("defender_count", 0)), "observed_ms": int(data.attempt_elapsed_ms)}

func _update_scouting() -> void:
	var points := MacroMarchTheater.get_points()
	for id in data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		if army.phase == ArmyRegistry.PHASE_CLOSED:
			continue
		var position := _army_world_position(army)
		for point in points:
			if position.distance_to(Vector2(points[point].world_position)) <= MacroMarchTheater.get_scout_visibility_range():
				_reveal_point(point)

func _army_world_position(army: Dictionary) -> Vector2:
	var points: Array = army.macro_march.route_world_points
	var remaining := _path_length(points) * float(army.progress_milliseconds) / maxi(1, int(army.duration_milliseconds))
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var distance := start.distance_to(end)
		if remaining <= distance:
			return start.lerp(end, remaining / maxf(1.0, distance))
		remaining -= distance
	return Vector2(points.back())

func _local_cycle() -> void:
	var need := _ration_need()
	var paid := mini(int(_stock().get(&"food", 0)), need)
	_spend(paid, 0, &"regular_rations")
	data.totals.food_used += paid
	data.starvation_cycles = int(data.starvation_cycles) + 1 if paid < need else 0
	if int(data.starvation_cycles) >= 2:
		var starvation_loss := maxi(1, need - paid)
		var applied_to_living := false
		for id in data.army_ids:
			var army: Dictionary = city._army_registry.get_army(id)
			if _members(army) > 0:
				_apply_losses(id, mini(starvation_loss, _members(army)), &"STARVATION")
				applied_to_living = true
				break
		if not applied_to_living and _apply_wounded_starvation(starvation_loss) > 0:
			feedback = "已连续实际断粮，失去行动能力的伤员也未能存活"
		elif applied_to_living:
			feedback = "已连续实际断粮，发生饥饿伤亡；预警没有替代口粮"
	var output := _effective_yields()
	var capacity := _capacity()
	var food_gain := mini(int(output.food), maxi(0, capacity - int(_stock().get(&"food", 0))))
	var wood_gain := mini(int(output.wood), maxi(0, capacity - int(_stock().get(&"wood", 0))))
	_spend(-food_gain, -wood_gain, &"regular_harvest")
	data.totals.food_produced += food_gain
	data.totals.wood_produced += wood_gain

func _grow_enemy() -> void:
	var due := maxi(0, (int(data.attempt_elapsed_ms) - 600000) / 360000 + 1) if int(data.attempt_elapsed_ms) >= 600000 else 0
	while int(data.enemy_growth_events) < due and int(data.enemy_growth_events) < 120:
		data.enemy_growth_events += 1
		for site in [&"redcliff_city", &"silverford_city"]:
			if city._war_loop_state.is_enemy_city(site) and city._war_loop_state.get_siege(site).is_empty() and int(data.enemy_reserve) > 0:
				var count := mini(1, int(data.enemy_reserve))
				city._war_loop_state.cities_by_id[site].defender_count += count
				data.enemy_reserve -= count
				# Finite reserve supplies actual defenders. It never repairs gates.
				city._war_loop_state.cities_by_id[site].defender_attack_per_member = mini(18, int(city._war_loop_state.cities_by_id[site].defender_attack_per_member) + (1 if int(data.enemy_growth_events) % 3 == 0 else 0))

func _outcome(kind: StringName) -> Dictionary:
	if data.phase != &"ACTIVE" or kind not in [&"VICTORY", &"WITHDRAW", &"DEFEAT"]:
		return _error("当前没有待结束的战役")
	if kind == &"VICTORY" and not city._war_loop_state.is_level_cleared():
		return _error("关卡目标尚未完成")
	# Close live sieges through their normal failed-result path, preserving damage.
	for siege in city._war_loop_state.get_active_sieges():
		city._war_loop_state.mark_retreat_at(siege.city_id, city.WAR_LOOP_RULES)
		_finish_siege(city._war_loop_state.get_siege(siege.city_id))
	for id in data.army_ids:
		_cancel_orders_for(id)
	data.phase = &"PENDING"
	data.summary = {"kind": kind, "survivors": _home_alive(), "wounded": _wounded(true), "fallen": int(data.fallen_home), "local_people": int(data.local_joined), "food_return": int(_stock().get(&"food", 0)), "wood_return": int(_stock().get(&"wood", 0)), "handover": "确认结算时完成归队交接；并非路线运输", "totals": data.totals.duplicate(true)}
	return _ok("战果待确认；暂离与普通保存不会提交永久损失")

func _retry() -> Dictionary:
	if not active() or data.entry.is_empty():
		return _error("没有可恢复的入关快照")
	var entry: Dictionary = data.entry.duplicate(true)
	var elapsed := int(data.mainline_elapsed_ms)
	var pressure: Dictionary = data.pressure.duplicate(true)
	var history: Array = data.history.duplicate(true)
	var home_training: Dictionary = Dictionary(data.get("home_training_progress", {})).duplicate(true)
	var sequence := int(data.attempt_sequence) + 1
	var combat_losses := int(data.combat_losses_total)
	if not city._army_registry.restore_snapshot(entry.army_registry, city.get_unit_definition_ids()) or not city._war_loop_state.restore_snapshot(entry.war_loop):
		return _error("入关权威快照无法恢复")
	var scopes: Dictionary = city.get_nation_state().get_scoped_resources()
	scopes[SCOPE] = entry.resources.duplicate(true)
	if not city.get_nation_state().hydrate_scoped_resources(scopes):
		return _error("入关补给快照非法")
	data = entry.state.duplicate(true)
	data.entry = entry
	data.mainline_elapsed_ms = elapsed
	data.pressure = pressure
	data.history = history
	data.home_training_progress = home_training
	data.attempt_sequence = sequence
	data.combat_losses_total = combat_losses
	return _ok("已恢复本次入关初态；主城进展、主线历时和已用缓冲保持")

func _confirm() -> Dictionary:
	if data.phase != &"PENDING" or data.settlement_id != &"":
		return _error("没有未确认战果，不能重复结算")
	var living := _home_alive()
	var wounded := _wounded(true)
	var fallen := int(data.fallen_home)
	if living > 0 and not city._garrison_state.try_add_units(city.INFANTRY_ROLE.role_id, living):
		return _error("归队容量不足，请保留待确认战果")
	if fallen > 0 and not city._population_recovery.record_fallen(fallen):
		return _error("阵亡人员来源不一致")
	if wounded > 0 and city._population_recovery.record_casualties(wounded, 1000).is_empty():
		return _error("伤员来源不一致")
	for id in data.army_ids:
		if city._army_registry.get_army(id).phase != ArmyRegistry.PHASE_CLOSED:
			city._army_registry.close_regular_force(id)
	var stock := _stock()
	var food_return := mini(int(stock.get(&"food", 0)), maxi(0, city.get_resource_capacity(&"food") - city.food))
	var wood_return := mini(int(stock.get(&"wood", 0)), maxi(0, city.get_resource_capacity(&"wood") - city.wood))
	if not _transfer([{"scope_id": SCOPE, "resource_id": &"food", "delta": -food_return}, {"scope_id": &"", "resource_id": &"food", "delta": food_return}, {"scope_id": SCOPE, "resource_id": &"wood", "delta": -wood_return}, {"scope_id": &"", "resource_id": &"wood", "delta": wood_return}], &"regular_settlement"):
		return _error("归还物资事务失败")
	data.summary.food_return_actual = food_return
	data.summary.wood_return_actual = wood_return
	data.summary.retained_food = int(stock.get(&"food", 0)) - food_return
	data.summary.retained_wood = int(stock.get(&"wood", 0)) - wood_return

	data.settlement_id = StringName("regular.settlement.%d" % int(data.attempt_sequence))
	var won: bool = data.summary.kind == &"VICTORY"
	if won:
		data.history.append({"confirmed": true, "settlement_id": data.settlement_id, "elapsed_ms": int(data.mainline_elapsed_ms), "baseline_ms": 1800000})
		data.phase = &"COMPLETED"
	else:
		data.phase = &"PREPARATION"
		data.army_ids = []
		data.local_by_army = {}
		data.wounded_by_army = {}
		data.entry = {}
		data.departure_ledger = {}
		data.settlement_id = &""
		data.buildings = []
		data.project = {}
		data.training = {}
		data.treatment = {}
		data.fallen_home = 0
		data.fallen_local = 0
		data.local_joined = 0
		data.enemy_growth_events = 0
		data.enemy_reserve = 120
		data.attempt_elapsed_ms = 0
		city._war_loop_state = WarLoopState.new()
		city._ensure_war_loop_initialized()
	return _ok("损益已确认，合法幸存者完成归队；当地人员留在当地")

func _assess() -> void:
	if not enabled():
		return
	var state: Dictionary = data.pressure.duplicate(true)
	state.mainline_elapsed_ms = int(data.mainline_elapsed_ms)
	state.history = data.history.duplicate(true)
	var home_forecast := home_food_forecast()
	var forecast := _forecast() if active() else home_forecast
	# Pending casualty occupancy exists for population conservation, not combat
	# strength. Remove that offset so actual local recruits count and dead or
	# wounded people are not presented as deployable soldiers.
	var actual_military: int = city._current_military_population() - population_offset()
	data.pressure = Rules.evaluate(state, {"total_military": actual_military, "wounded": _wounded(true) + _wounded(false) + city._population_recovery.wounded, "new_combat_losses": int(data.combat_losses_total), "food_forecast": forecast, "effective_food_yield": int(forecast.get("yield", 0)), "food_required": int(forecast.get("consumption", 0)), "food_stock": int(_stock().get(&"food", 0)) if active() else city.food})
	if data.phase == &"COMPLETED":
		data.pressure.stage = 0
		data.pressure.pressure_stage = 0
		data.pressure.construction_permille = 1000
		data.pressure.nonessential_construction_permille = 1000
		data.pressure.growth_permille = int(home_forecast.growth_permille)
		data.pressure.basic_training_permille = int(home_forecast.training_permille)

func home_food_forecast() -> Dictionary:
	var output := 0
	for id in city._placement_order:
		var record: Dictionary = city._building_records_by_id[id]
		if not city.is_building_operational(id):
			continue
		var definition: BuildingDefinition = city.get_definition(record.definition_id)
		var capability: BuildingCapability = definition.get_capability(&"production") if definition != null else null
		if capability != null and capability.resource_id == &"food":
			output += city._get_production_amount(definition, capability)
	var until := maxi(1, city.MILLISECONDS_PER_DAY - city.get_day_elapsed_milliseconds())
	return Rules.forecast(city.food, city.get_resource_capacity(&"food"), output, city.get_maintenance_food_cost(), until, until, city.MILLISECONDS_PER_DAY)

func _forecast() -> Dictionary:
	var until := CYCLE_MS - int(data.attempt_elapsed_ms) % CYCLE_MS
	return Rules.forecast(int(_stock().get(&"food", 0)), _capacity(), int(_effective_yields().food), _ration_need(), until, until, CYCLE_MS)

func construction_modifier(kind: StringName) -> int:
	var modifier := int(data.pressure.get("nonessential_construction_permille", 1000))
	if modifier > 0:
		return modifier
	# This exception is bounded by actual need and by two physical farms/one clinic.
	var count := 0
	for b in data.buildings:
		if b.kind == kind:
			count += 1
	if kind == &"FARM" and count < 2 and int(_effective_yields().food) < _ration_need():
		return 350
	if kind == &"CLINIC" and count < 1 and _wounded(true) + _wounded(false) > 0:
		return 350
	if kind == &"LOGGING" and count < 1 and int(_stock().get(&"wood", 0)) < 45:
		return 350
	return 0

func _effective_yields() -> Dictionary:
	var result := {"food": 0, "wood": 0}
	for b in data.buildings:
		if not bool(b.connected) or int(b.workers) <= 0 or int(b.durability) <= 0:
			continue
		var definition: BuildingDefinition = load(DEFINITIONS[b.kind])
		var capability: BuildingCapability = definition.get_capability(&"production")
		if capability == null:
			continue
		var amount := int(capability.amount) * mini(4, int(b.workers)) / 4
		amount = amount * int(b.durability) / 100
		if int(data.starvation_cycles) >= 2:
			amount = amount * 750 / 1000
		result[String(capability.resource_id)] += amount
	return result

func _capacity() -> int:
	var capacity := 80
	for b in data.buildings:
		if b.kind == &"WAREHOUSE" and bool(b.connected) and int(b.durability) > 0:
			capacity += 120
	return capacity

func _medical_capacity() -> int:
	var capacity := 0
	for b in data.buildings:
		if b.kind == &"CLINIC" and bool(b.connected) and int(b.durability) > 0:
			capacity += mini(4, int(b.workers))
	return capacity

func _assigned_workers() -> int:
	var count := 2 if not data.project.is_empty() else 0
	for b in data.buildings:
		count += int(b.workers)
	return count

func _base_members() -> int:
	var count := 0
	for id in data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		if army.phase == ArmyRegistry.PHASE_STATIONED and army.target_node_id == BASE:
			count += _members(army)
	return count

func _trim_workers() -> void:
	var available := maxi(0, _base_members() - (2 if not data.project.is_empty() else 0))
	for b in data.buildings:
		b.workers = mini(available, int(b.workers))
		available -= int(b.workers)

func _members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total

func _home_alive() -> int:
	var total := 0
	for id in data.army_ids:
		total += _members(city._army_registry.get_army(id)) - int(data.local_by_army.get(id, 0))
	return total

## Home-origin living members return at confirmation. Home-origin wounded are
## recorded in PopulationRecoveryState at confirmation and later join the same
## garrison only after treatment. Reserve both groups while the attempt exists
## so ordinary home training cannot make either handoff impossible.
func home_return_capacity_reservation() -> int:
	if not enabled() or data.phase not in [&"ACTIVE", &"PENDING"]:
		return 0
	return _home_alive() + _wounded(true)


func _wounded(home: bool) -> int:
	var total := 0
	for pair in data.get("wounded_by_army", {}).values():
		total += int(pair.get("home" if home else "local", 0))
	return total

func _ration_need() -> int:
	var people := _wounded(true) + _wounded(false)
	for id in data.army_ids:
		people += _members(city._army_registry.get_army(id))
	if not data.training.is_empty():
		people += int(data.training.count)
	return ceili(float(people) / float(city.INFANTRY_ROLE.maintenance_units_per_food))

func _stock() -> Dictionary:
	return city.get_nation_state().get_scope(SCOPE)

func _spend(food: int, wood: int, reason: StringName) -> bool:
	if food == 0 and wood == 0:
		return true
	return _transfer([{"scope_id": SCOPE, "resource_id": &"food", "delta": -food}, {"scope_id": SCOPE, "resource_id": &"wood", "delta": -wood}], reason)

func _transfer(entries: Array[Dictionary], reason: StringName) -> bool:
	return bool(city.get_nation_state().commit_scoped_transaction(entries, reason).get("success", false))

func _route_from_army(army: Dictionary, target: StringName) -> Dictionary:
	if not MacroMarchTheater.get_points().has(target):
		return {}
	var plan: Dictionary
	if army.phase == ArmyRegistry.PHASE_MARCHING:
		plan = city._war_loop_state.field_tactics.plan_runtime_path_from_progress(army.macro_march.get("route_segments", []), int(army.duration_milliseconds), int(army.progress_milliseconds), target)
	else:
		plan = city._war_loop_state.field_tactics.plan_runtime_path(army.target_node_id, target)
	return plan if bool(plan.get("valid", false)) else {}

func _path_length(points: Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += Vector2(points[i - 1]).distance_to(Vector2(points[i]))
	return length

func get_read_model() -> Dictionary:
	if not enabled():
		return {"enabled": false}
	var points := MacroMarchTheater.get_points()
	for id in points:
		var p: Dictionary = points[id]
		p.allows_build = id == BASE
		p.kind = p.get("point_kind", &"GARRISON")
		p.controlled = not city._war_loop_state.is_enemy_city(id)
		p.known = data.scouted.has(id) or bool(p.controlled)
		for key in ["defender_count", "defender_attack_per_member", "defender_hp_per_member", "defender_armor", "gate_hp", "initial_supply_food", "initial_stationed_reinforcements"]:
			p.erase(key)
		if p.known and city._war_loop_state.cities_by_id.has(id):
			p.defender_count = 0 if p.controlled else int(Dictionary(data.scouted.get(id, {})).get("defender_count", 0))
			p.observed_ms = int(Dictionary(data.scouted.get(id, {})).get("observed_ms", 0))
	var routes := MacroMarchTheater.get_routes()
	for route in routes.values():
		route.world_points = route.get("points", [])
	var active_sieges: Array[Dictionary] = city._war_loop_state.get_active_sieges()
	var sieges_by_army: Dictionary = {}
	for siege_value in active_sieges:
		var indexed_siege := Dictionary(siege_value)
		sieges_by_army[StringName(indexed_siege.get("army_id", &""))] = indexed_siege
	var armies: Array = []
	for id in data.army_ids:
		var army: Dictionary = city._army_registry.get_army(id)
		var formations: Array = army.macro_march.formation_snapshots
		army.display_name = str(formations[0].get("display_name", "部队")) if not formations.is_empty() else "部队"
		var active_army_siege := Dictionary(sieges_by_army.get(id, {}))
		var current_count := _members(army)
		var entry_count := current_count
		var presentation_state := StringName(army.get("phase", &"STATIONED"))
		var engagement_city_id := &""
		if not active_army_siege.is_empty():
			current_count = ceili(float(int(active_army_siege.get("attacker_total_hp", 0))) / float(maxi(1, int(active_army_siege.get("attacker_hp_per_member", 1)))))
			entry_count = int(active_army_siege.get("attacker_initial_count", current_count))
			presentation_state = &"ENGAGING"
			engagement_city_id = StringName(active_army_siege.get("city_id", &""))
		army.presentation = {
			"current_count": current_count,
			"entry_count": entry_count,
			"state": presentation_state,
			"engagement_city_id": engagement_city_id,
			"separate_stacked_actor": true,
		}
		armies.append(army)
	var sieges: Array = []
	for siege_value in active_sieges:
		var siege := Dictionary(siege_value).duplicate(true)
		var siege_army: Dictionary = city._army_registry.get_army(StringName(siege.get("army_id", &"")))
		var siege_formations: Array = Array(Dictionary(siege_army.get("macro_march", {})).get("formation_snapshots", []))
		siege.attacker_display_name = str(Dictionary(siege_formations[0]).get("display_name", "部队")) if not siege_formations.is_empty() else "部队"
		siege.attacker_count = ceili(float(int(siege.get("attacker_total_hp", 0))) / float(maxi(1, int(siege.get("attacker_hp_per_member", 1)))))
		siege.attacker_entry_count = int(siege.get("attacker_initial_count", siege.attacker_count))
		siege.defender_count = ceili(float(int(siege.get("defender_total_hp", 0))) / float(maxi(1, int(siege.get("defender_hp_per_member", 1)))))
		# The city record retains the gate value at this siege's start until the
		# existing terminal writeback. It is therefore the truthful comparison
		# point even after a prior failed assault, unlike the authored maximum.
		var siege_city: Dictionary = city._war_loop_state.get_city(StringName(siege.get("city_id", &"")))
		siege.gate_max_hp = maxi(int(siege.get("gate_hp", 0)), int(siege_city.get("gate_hp", siege.get("gate_hp", 0))))
		siege.presentation_grain = &"AGGREGATE"
		sieges.append(siege)
	var local := _stock()
	local.capacity = _capacity()
	local.forecast = _forecast()
	local.buildings = data.buildings.duplicate(true)
	local.project = _project_read_model()
	local.workers_available = maxi(0, _base_members() - _assigned_workers())
	local.wounded = _wounded(true) + _wounded(false)
	local.local_pool = city._war_loop_state.field_tactics.get_stationed_reinforcements(&"silverford_city")
	return {"enabled": true, "phase": data.phase, "title": "青原战役 · 常规关卡 R1", "view_context": Dictionary(data.get("view_context", {})).duplicate(true), "mainline_elapsed_ms": int(data.mainline_elapsed_ms), "attempt_elapsed_ms": int(data.attempt_elapsed_ms), "pressure": data.pressure.duplicate(true), "home": {"food": city.food, "wood": city.wood, "food_forecast": home_food_forecast(), "formations": city._garrison_state.get_formations()}, "local": local, "points": points, "routes": routes, "armies": armies, "sieges": sieges, "summary": data.summary.duplicate(true), "feedback": feedback, "enemy_growth_events": int(data.enemy_growth_events), "totals": Dictionary(data.totals).duplicate(true), "paused": bool(city.city_time_paused)}


func _project_read_model() -> Dictionary:
	if data.project.is_empty():
		return {}
	var project := Dictionary(data.project).duplicate(true)
	var modifier := construction_modifier(StringName(project.kind))
	var next_progress := mini(
		int(project.required_ms),
		int(project.progress_ms) + STEP_MS * modifier / 1000
	)
	var wood_due := ceili(float(int(project.wood_cost) * next_progress) / float(project.required_ms)) - int(project.paid_wood)
	var food_due := ceili(float(int(project.food_cost) * next_progress) / float(project.required_ms)) - int(project.paid_food)
	var stock := _stock()
	project.advancing = (
		next_progress > int(project.progress_ms)
		and _base_members() >= _assigned_workers()
		and int(stock.get(&"wood", 0)) >= wood_due
		and int(stock.get(&"food", 0)) >= food_due
	)
	return project

func _ok(message: String) -> Dictionary:
	return {"success": true, "message": message}

func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}

func _supply(args: Dictionary) -> Dictionary:
	var army: Dictionary = city._army_registry.get_army(StringName(args.get("army_id", &"")))
	var point := &"silverford_city"
	if data.phase != &"ACTIVE" or army.is_empty() or army.army_id not in data.army_ids or army.phase != ArmyRegistry.PHASE_STATIONED or army.target_node_id != point or city._war_loop_state.is_enemy_city(point):
		return _error("须由本关军队在已控制的溪渡领取当地有限库存")
	var inventory: Dictionary = city._war_loop_state.field_tactics.supply_inventory_by_point_id
	var amount := mini(int(inventory.get(point, 0)), maxi(0, _capacity() - int(_stock().get(&"food", 0))))
	if amount <= 0 or not _spend(-amount, 0, &"regular_local_stock"):
		return _error("当地库存已用尽或前线仓储已满")
	inventory[point] = int(inventory.get(point, 0)) - amount
	data.totals.food_in += amount
	return _ok("已领取当地有限粮食 %d；库存不会刷新" % amount)

static func snapshot_population_offset(payload: Dictionary) -> int:
	if payload.is_empty() or payload.get("phase", &"") not in [&"ACTIVE", &"PENDING"]:
		return 0
	var offset := int(payload.get("fallen_home", 0))
	for pair in Dictionary(payload.get("wounded_by_army", {})).values():
		offset += int(pair.get("home", 0))
	for count in Dictionary(payload.get("local_by_army", {})).values():
		offset -= int(count)
	return offset

static func validate_snapshot(payload: Dictionary, scopes: Dictionary, armies: Dictionary, is_entry := false, home_wounded: int = 0) -> Dictionary:
	var invalid := {"valid": false, "error": "常规战役身份、来源或守恒校验失败"}
	if payload.is_empty():
		return {"valid": scopes.is_empty(), "error": "旧模式不接受前线资源"}
	var required := ["version", "campaign_id", "phase", "mainline_elapsed_ms", "attempt_elapsed_ms", "step_remainder_ms", "pressure", "history", "attempt_sequence", "entry", "departure_ledger", "army_ids", "local_by_army", "wounded_by_army", "fallen_home", "fallen_local", "combat_losses_total", "buildings", "project", "next_building_id", "training", "treatment", "starvation_cycles", "enemy_growth_events", "enemy_reserve", "local_joined", "scouted", "summary", "settlement_id", "totals"]
	for key in required:
		if not payload.has(key):
			return invalid
	for key in payload:
		if key not in required and key not in ["home_training_progress", "view_context"]:
			return invalid
	if typeof(payload.version) != TYPE_INT or payload.version != 1 or payload.campaign_id != SCOPE or typeof(payload.phase) != TYPE_STRING_NAME or payload.phase not in [&"PREPARATION", &"ACTIVE", &"PENDING", &"COMPLETED"]:
		return invalid
	if payload.has("view_context"):
		if not payload.view_context is Dictionary or payload.view_context.size() != 2 or typeof(payload.view_context.get("surface")) != TYPE_STRING_NAME or typeof(payload.view_context.get("city_id")) != TYPE_STRING_NAME:
			return invalid
		var view_surface := StringName(payload.view_context.surface)
		var view_city := StringName(payload.view_context.city_id)
		if view_surface not in [&"PREPARATION", &"THEATER", &"CITY"] or (view_surface == &"CITY" and view_city != BASE) or (view_surface != &"CITY" and view_city != &""):
			return invalid
	for key in ["mainline_elapsed_ms", "attempt_elapsed_ms", "step_remainder_ms", "attempt_sequence", "fallen_home", "fallen_local", "combat_losses_total", "next_building_id", "starvation_cycles", "enemy_growth_events", "enemy_reserve", "local_joined"]:
		if typeof(payload[key]) != TYPE_INT or int(payload[key]) < 0 or int(payload[key]) > 1000000000:
			return invalid
	if payload.step_remainder_ms >= STEP_MS or payload.attempt_elapsed_ms > payload.mainline_elapsed_ms or payload.enemy_reserve > 120 or payload.enemy_growth_events > 120 or payload.local_joined > 4:
		return invalid
	for key in ["pressure", "entry", "departure_ledger", "local_by_army", "wounded_by_army", "project", "training", "treatment", "scouted", "summary", "totals"]:
		if not payload[key] is Dictionary:
			return invalid
	for key in ["history", "army_ids", "buildings"]:
		if not payload[key] is Array:
			return invalid
	if payload.buildings.size() > 6 or payload.army_ids.size() > 3 or not payload.settlement_id is StringName:
		return invalid
	for point_id_value in payload.scouted:
		if typeof(point_id_value) != TYPE_STRING_NAME:
			return invalid
		var point_id := StringName(point_id_value)
		if not payload.scouted[point_id_value] is Dictionary:
			return invalid
		var scout: Dictionary = payload.scouted[point_id_value]
		if point_id not in [&"blackstone_city", &"northwatch_garrison", &"forest_garrison", &"reedbank_garrison", &"ridge_watch", &"silverford_city", &"redcliff_city"] or not scout is Dictionary or scout.size() != 2 or typeof(scout.get("defender_count")) != TYPE_INT or int(scout.defender_count) < 0 or typeof(scout.get("observed_ms")) != TYPE_INT or int(scout.observed_ms) < 0 or int(scout.observed_ms) > int(payload.mainline_elapsed_ms):
			return invalid
	var nation := NationState.new()
	if not nation.hydrate_scoped_resources(scopes) or scopes.size() > 1 or (not scopes.is_empty() and not scopes.has(SCOPE)):
		return invalid
	if payload.phase in [&"ACTIVE", &"PENDING", &"COMPLETED"] and not scopes.has(SCOPE):
		return invalid
	var ids := {}
	var home_alive := 0
	var local_alive := 0
	var wounded_home := 0
	var wounded_local := 0
	var stationed_base := 0
	for id in payload.army_ids:
		if typeof(id) != TYPE_STRING_NAME or ids.has(id) or not Dictionary(armies.get("armies_by_id", {})).has(id) or not payload.local_by_army.has(id) or not payload.wounded_by_army.has(id):
			return invalid
		ids[id] = true
		var army: Dictionary = armies.armies_by_id[id]
		var members := 0
		for count in army.units_by_definition_id.values():
			members += int(count)
		var local_count = payload.local_by_army[id]
		var pair = payload.wounded_by_army[id]
		if typeof(local_count) != TYPE_INT or local_count < 0 or (local_count > members and payload.phase != &"COMPLETED") or not pair is Dictionary or pair.size() != 2:
			return invalid
		for key in ["home", "local"]:
			if typeof(pair.get(key)) != TYPE_INT or int(pair[key]) < 0 or int(pair[key]) > 60:
				return invalid
		home_alive += members - int(local_count)
		local_alive += int(local_count)
		wounded_home += int(pair.home)
		wounded_local += int(pair.local)
		if army.phase == ArmyRegistry.PHASE_STATIONED and army.target_node_id == BASE:
			stationed_base += members
	if payload.local_by_army.size() != ids.size() or payload.wounded_by_army.size() != ids.size():
		return invalid
	var plots := {}
	var building_ids := {}
	var workers := 0
	for building in payload.buildings:
		if not building is Dictionary or not _valid_building(building) or plots.has(building.plot) or building_ids.has(building.id) or not _valid_regular_building_id(building.id, int(payload.next_building_id)):
			return invalid
		plots[building.plot] = true
		building_ids[building.id] = true
		workers += int(building.workers)
	if not payload.project.is_empty():
		var p: Dictionary = payload.project
		if p.size() != 9:
			return invalid
		for key in ["id", "kind", "plot", "progress_ms", "required_ms", "paid_wood", "paid_food", "wood_cost", "food_cost"]:
			if not p.has(key):
				return invalid
		if p.kind not in BUILD_KINDS or typeof(p.id) != TYPE_STRING_NAME or not _valid_regular_building_id(p.id, int(payload.next_building_id)) or typeof(p.plot) != TYPE_INT or p.plot < 0 or p.plot > 5 or plots.has(p.plot) or p.required_ms != 90000:
			return invalid
		for key in ["progress_ms", "paid_wood", "paid_food", "wood_cost", "food_cost"]:
			if typeof(p[key]) != TYPE_INT or p[key] < 0:
				return invalid
		var costs := _snapshot_build_costs(p.kind)
		if p.progress_ms > p.required_ms or p.wood_cost != costs.wood or p.food_cost != costs.food or p.paid_wood != ceili(float(int(p.wood_cost) * int(p.progress_ms)) / float(int(p.required_ms))) or p.paid_food != ceili(float(int(p.food_cost) * int(p.progress_ms)) / float(int(p.required_ms))):
			return invalid
		workers += 2
	if payload.phase == &"ACTIVE" and workers > stationed_base:
		return invalid
	for key in ["training", "treatment"]:
		var order: Dictionary = payload[key]
		if order.is_empty():
			continue
		var expected_order_keys := ["army_id", "count", "progress_ms", "required_ms"] if key == "training" else ["army_id", "home", "local", "progress_ms", "required_ms"]
		if order.size() != expected_order_keys.size() or not ids.has(order.get("army_id")) or typeof(order.get("progress_ms")) != TYPE_INT or order.progress_ms < 0 or order.progress_ms > 90000 or order.get("required_ms") != 90000:
			return invalid
		for order_key in expected_order_keys:
			if not order.has(order_key):
				return invalid
		if key == "training" and (typeof(order.get("count")) != TYPE_INT or order.count < 1 or order.count > 2):
			return invalid
		if key == "treatment":
			var pair: Dictionary = payload.wounded_by_army[order.army_id]
			for origin in ["home", "local"]:
				if typeof(order.get(origin)) != TYPE_INT or order[origin] < 0 or order[origin] > pair[origin]:
					return invalid
	if payload.phase in [&"ACTIVE", &"PENDING"]:
		if local_alive + wounded_local + int(payload.fallen_local) != int(payload.local_joined):
			return invalid
		if not is_entry:
			var entry: Dictionary = payload.entry
			if not _valid_entry_snapshot(entry, payload):
				return invalid
			var initial := 0
			for formation in entry.formations:
				initial += int(formation.member_count)
			if initial != home_alive + wounded_home + int(payload.fallen_home):
				return invalid
	if payload.phase == &"PENDING":
		if payload.summary.get("kind", &"") not in [&"VICTORY", &"WITHDRAW", &"DEFEAT"] or payload.summary.get("survivors", -1) != home_alive or payload.summary.get("wounded", -1) != wounded_home or payload.summary.get("fallen", -1) != payload.fallen_home:
			return invalid
	if payload.phase == &"COMPLETED" and (payload.settlement_id == &"" or home_alive > 0):
		return invalid
	for key in ["food_in", "wood_in", "food_produced", "wood_produced", "food_used", "wood_used"]:
		if typeof(payload.totals.get(key)) != TYPE_INT or payload.totals[key] < 0:
			return invalid
	if not is_entry:
		if payload.phase == &"COMPLETED":
			if not _valid_completed_pressure(payload.pressure):
				return invalid
		elif int(payload.pressure.get("mainline_elapsed_ms", -1)) > int(payload.mainline_elapsed_ms) or not Rules.validate_pressure_schema(payload.pressure, payload.history, int(payload.combat_losses_total), int(payload.pressure.get("mainline_elapsed_ms", -1))):
			return invalid
	if payload.phase in [&"ACTIVE", &"PENDING"]:
		for resource in ["food", "wood"]:
			if int(payload.totals[resource + "_in"]) + int(payload.totals[resource + "_produced"]) - int(payload.totals[resource + "_used"]) != int(scopes[SCOPE][StringName(resource)]):
				return invalid
		# A pressure record is a 15-second assessment cache. Recompute its food
		# facts only at the assessment timestamp; between ticks the strict schema
		# above preserves its derived modifiers without mistaking elapsed stock for
		# a forged same-tick evaluation.
		if not is_entry and int(payload.pressure.last_assessment_ms) == int(payload.mainline_elapsed_ms):
			var food_yield := _snapshot_effective_food_yield(payload.buildings, int(payload.starvation_cycles))
			var food_required := _snapshot_ration_need(payload, armies)
			var until_cycle := CYCLE_MS - int(payload.attempt_elapsed_ms) % CYCLE_MS
			var food_forecast := Rules.forecast(
				int(scopes[SCOPE].get(&"food", 0)),
				_snapshot_food_capacity(payload.buildings),
				food_yield,
				food_required,
				until_cycle,
				until_cycle,
				CYCLE_MS
			)
			if not Rules.validate_pressure_snapshot(payload.pressure, payload.history, int(payload.combat_losses_total), {
				"mainline_elapsed_ms": int(payload.mainline_elapsed_ms),
				"total_military": int(payload.pressure.get("total_military", 0)),
				"wounded": wounded_home + wounded_local + maxi(home_wounded, 0),
				"food_forecast": food_forecast,
				"effective_food_yield": food_yield,
				"food_required": food_required,
				"food_stock": int(scopes[SCOPE].get(&"food", 0)),
			}):
				return invalid
	return {"valid": true, "error": ""}

static func _valid_building(b: Dictionary) -> bool:
	var required := ["id", "kind", "plot", "world_position", "phase", "progress_permille", "workers", "connected", "durability"]
	if b.size() != required.size():
		return false
	for key in required:
		if not b.has(key):
			return false
	return typeof(b.id) == TYPE_STRING_NAME and String(b.id).begins_with("regular.building.") and b.kind in BUILD_KINDS and typeof(b.plot) == TYPE_INT and b.plot >= 0 and b.plot < 6 and b.world_position == Vector2i(80 + int(b.plot) % 3 * 72, 715 + int(b.plot) / 3 * 75) and b.phase == &"ACTIVE" and b.progress_permille == 1000 and typeof(b.workers) == TYPE_INT and b.workers >= 0 and b.workers <= 4 and typeof(b.connected) == TYPE_BOOL and typeof(b.durability) == TYPE_INT and b.durability >= 0 and b.durability <= 100


static func _valid_regular_building_id(id: StringName, next_id: int) -> bool:
	var text := String(id)
	var prefix := "regular.building."
	if not text.begins_with(prefix):
		return false
	var suffix := text.trim_prefix(prefix)
	return suffix.length() == 6 and suffix.is_valid_int() and text == "%s%06d" % [prefix, int(suffix)] and int(suffix) > 0 and int(suffix) < next_id


static func _snapshot_build_costs(kind: StringName) -> Dictionary:
	match kind:
		&"FARM": return {"wood": 45, "food": 0}
		&"LOGGING": return {"wood": 40, "food": 0}
		&"WAREHOUSE": return {"wood": 60, "food": 0}
		&"CLINIC": return {"wood": 45, "food": 4}
	return {}


static func _valid_completed_pressure(pressure: Dictionary) -> bool:
	# Completion ends mainline escalation.  Food risk still controls the two
	# economy modifiers, while construction returns to the normal city handoff.
	if pressure.is_empty() or int(pressure.get("stage", -1)) != 0 or int(pressure.get("pressure_stage", -1)) != 0 or int(pressure.get("construction_permille", -1)) != 1000 or int(pressure.get("nonessential_construction_permille", -1)) != 1000:
		return false
	var risk := StringName(pressure.get("food_risk_id", &""))
	return risk in [Rules.RISK_STABLE, Rules.RISK_WARNING, Rules.RISK_SHORTAGE] and int(pressure.get("growth_permille", -1)) == Rules._food_growth_permille(risk) and int(pressure.get("basic_training_permille", -1)) == Rules._food_training_permille(risk)


static func _valid_entry_snapshot(entry: Dictionary, payload: Dictionary) -> bool:
	if (
		entry.size() != 5
		or not entry.get("state") is Dictionary
		or not entry.get("army_registry") is Dictionary
		or not entry.get("resources") is Dictionary
		or not entry.get("war_loop") is Dictionary
		or not entry.get("formations") is Array
		or not _valid_departure_ledger(payload.departure_ledger)
	):
		return false
	var ledger: Dictionary = payload.departure_ledger
	var resources: Dictionary = entry.resources
	if (
		resources.size() != 2
		or typeof(resources.get(&"food")) != TYPE_INT
		or typeof(resources.get(&"wood")) != TYPE_INT
		or int(resources.food) != int(ledger.food)
		or int(resources.wood) != int(ledger.wood)
	):
		return false
	var formations: Array = entry.formations
	if formations != Array(ledger.formations) or formations.is_empty() or formations.size() > 3:
		return false
	var formation_ids: Dictionary = {}
	var initial_members := 0
	for value in formations:
		if not value is Dictionary:
			return false
		var formation: Dictionary = value
		var formation_id := StringName(formation.get("formation_id", &""))
		if (
			formation.size() != 5
			or formation_id == &""
			or formation_ids.has(formation_id)
			or typeof(formation.get("definition_id")) != TYPE_STRING_NAME
			or StringName(formation.definition_id) == &""
			or typeof(formation.get("member_count")) != TYPE_INT
			or int(formation.member_count) < 1
			or int(formation.member_count) > 20
			or typeof(formation.get("max_members")) != TYPE_INT
			or int(formation.max_members) != 20
		):
			return false
		formation_ids[formation_id] = true
		initial_members += int(formation.member_count)
	var allowed_units := _snapshot_unit_definition_ids(entry.army_registry)
	if allowed_units.is_empty() or not bool(ArmyRegistry.validate_snapshot(entry.army_registry, allowed_units, false).get("valid", false)):
		return false
	var war_probe := WarLoopState.new()
	if not war_probe.restore_snapshot(entry.war_loop):
		return false
	var state: Dictionary = entry.state
	if (
		not state.get("entry", {}).is_empty()
		or state.get("departure_ledger", {}) != ledger
		or int(state.get("attempt_elapsed_ms", -1)) != 0
		or not Array(state.get("buildings", [])).is_empty()
		or not Dictionary(state.get("project", {})).is_empty()
		or not Dictionary(state.get("training", {})).is_empty()
		or not Dictionary(state.get("treatment", {})).is_empty()
		or int(state.get("fallen_home", -1)) != 0
		or int(state.get("fallen_local", -1)) != 0
		or int(state.get("combat_losses_total", -1)) != 0
		or int(state.get("local_joined", -1)) != 0
		or int(state.get("starvation_cycles", -1)) != 0
		or int(state.get("enemy_growth_events", -1)) != 0
		or int(state.get("enemy_reserve", -1)) != 120
		or not Dictionary(state.get("summary", {})).is_empty()
		or StringName(state.get("settlement_id", &"")) != &""
		or Array(state.get("army_ids", [])) != Array(payload.get("army_ids", []))
		or not validate_snapshot(state, {SCOPE: resources}, entry.army_registry, true).valid
	):
		return false
	var initial_totals: Dictionary = state.totals
	if (
		int(initial_totals.get("food_in", -1)) != int(ledger.food)
		or int(initial_totals.get("wood_in", -1)) != int(ledger.wood)
		or int(initial_totals.get("food_produced", -1)) != 0
		or int(initial_totals.get("wood_produced", -1)) != 0
		or int(initial_totals.get("food_used", -1)) != 0
		or int(initial_totals.get("wood_used", -1)) != 0
	):
		return false
	var registry_armies: Dictionary = entry.army_registry.armies_by_id
	var registry_members := 0
	for army_id_value in state.army_ids:
		var army_id := StringName(army_id_value)
		var army: Dictionary = Dictionary(registry_armies.get(army_id, {}))
		if army.is_empty() or StringName(army.get("army_id", &"")) != army_id:
			return false
		registry_members += _snapshot_army_members(army)
	if registry_members != initial_members:
		return false
	return true


static func _valid_departure_ledger(ledger: Dictionary) -> bool:
	return (
		ledger.size() == 3
		and typeof(ledger.get("food")) == TYPE_INT
		and typeof(ledger.get("wood")) == TYPE_INT
		and ledger.get("formations") is Array
		and int(ledger.food) >= 8
		and int(ledger.food) <= 80
		and int(ledger.wood) >= 0
		and int(ledger.wood) <= 80
	)


static func _snapshot_unit_definition_ids(registry: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for army_value in Dictionary(registry.get("armies_by_id", {})).values():
		for definition_id_value in Dictionary(Dictionary(army_value).get("units_by_definition_id", {})):
			var definition_id := StringName(definition_id_value)
			if definition_id != &"" and not result.has(definition_id):
				result.append(definition_id)
	return result


static func _snapshot_army_members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		if typeof(count) != TYPE_INT or int(count) < 0:
			return -1
		total += int(count)
	return total


static func _snapshot_effective_food_yield(buildings: Array, starvation_cycles: int) -> int:
	var result := 0
	for value in buildings:
		var building: Dictionary = value
		if StringName(building.get("kind", &"")) != &"FARM" or not bool(building.get("connected", false)) or int(building.get("workers", 0)) <= 0 or int(building.get("durability", 0)) <= 0:
			continue
		var amount := int(22 * mini(4, int(building.workers)) / 4)
		amount = int(amount * int(building.durability) / 100)
		if starvation_cycles >= 2:
			amount = int(amount * 750 / 1000)
		result += amount
	return result


static func _snapshot_food_capacity(buildings: Array) -> int:
	var capacity := 80
	for value in buildings:
		var building: Dictionary = value
		if StringName(building.get("kind", &"")) == &"WAREHOUSE" and bool(building.get("connected", false)) and int(building.get("durability", 0)) > 0:
			capacity += 120
	return capacity


static func _snapshot_ration_need(payload: Dictionary, armies: Dictionary) -> int:
	var people := 0
	for army_id_value in payload.army_ids:
		people += _snapshot_army_members(Dictionary(Dictionary(armies.get("armies_by_id", {})).get(army_id_value, {})))
	for value in Dictionary(payload.wounded_by_army).values():
		var pair: Dictionary = value
		people += int(pair.get("home", 0)) + int(pair.get("local", 0))
	if not Dictionary(payload.training).is_empty():
		people += int(Dictionary(payload.training).get("count", 0))
	return ceili(float(people) / 5.0)

func _claim() -> Dictionary:
	if data.phase not in [&"PREPARATION", &"COMPLETED"]:
		return _error("当前物资仍属于未结算的战役")
	var stock := _stock()
	var food_return := mini(int(stock.get(&"food", 0)), maxi(0, city.get_resource_capacity(&"food") - city.food))
	var wood_return := mini(int(stock.get(&"wood", 0)), maxi(0, city.get_resource_capacity(&"wood") - city.wood))
	if food_return + wood_return <= 0:
		return _error("暂无可领取物资或主城仓储已满；暂存物资不会消失")
	if not _transfer([{"scope_id": SCOPE, "resource_id": &"food", "delta": -food_return}, {"scope_id": &"", "resource_id": &"food", "delta": food_return}, {"scope_id": SCOPE, "resource_id": &"wood", "delta": -wood_return}, {"scope_id": &"", "resource_id": &"wood", "delta": wood_return}], &"regular_claim"):
		return _error("领取暂存物资失败")
	return _ok("已领取粮 %d、木 %d；剩余物资继续原账暂存" % [food_return, wood_return])
