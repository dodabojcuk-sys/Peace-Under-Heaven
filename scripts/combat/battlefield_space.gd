class_name BattlefieldSpace
extends RefCounted

## Integer coordinates are battle facts. This module has no clock or HP store.
const SCALE := 16
const XS := [0, 20, 40, 60, 76, 84, 100, 120]
const YS := [24, 64]
const MELEE := 10 * SCALE
const TOWER_RANGE := 36 * SCALE
const PARAPET_RANGE := 28 * SCALE
const WORK_RANGE := 8 * SCALE
const MEDICAL_RANGE := 36 * SCALE

static func defense(s: BattleSession) -> bool:
	return s.request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE

static func enabled(s: BattleSession) -> bool:
	return not s.spatial_state.is_empty()

static func point(x: int, y: int) -> Array:
	return [x * SCALE, y * SCALE]

static func route_y(route: StringName) -> int:
	return 24 if route == CommittedForceSnapshot.FRONT_ROUTE else 64

static func route_at(p: Array) -> StringName:
	return CommittedForceSnapshot.FRONT_ROUTE if int(p[1]) < 44 * SCALE else CommittedForceSnapshot.SIDE_ROUTE

static func distance(a: Array, b: Array) -> int:
	return absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1]))

static func nodes() -> Array:
	var out: Array = []
	for y in YS:
		for x in XS:
			out.append(point(x, y))
	return out

static func gate_open(s: BattleSession, route: StringName) -> bool:
	if defense(s):
		return int(s.mission_objective_state.get("protect_target_hp", 0)) <= 0
	return int(s.routes[route].gate_hp) <= 0

static func visible(s: BattleSession, a: Array, b: Array, over_wall := false) -> bool:
	if (int(a[0]) <= 80 * SCALE) == (int(b[0]) <= 80 * SCALE):
		return true
	return over_wall or (route_at(a) == route_at(b) and gate_open(s, route_at(a)))

static func linked(s: BattleSession, a: Array, b: Array) -> bool:
	if int(a[1]) == int(b[1]):
		var ai := XS.find(int(a[0]) / SCALE)
		var bi := XS.find(int(b[0]) / SCALE)
		return absi(ai - bi) == 1 and visible(s, a, b)
	return int(a[0]) == int(b[0]) and int(a[0]) in [20 * SCALE, 60 * SCALE, 100 * SCALE]

static func path(s: BattleSession, start: Array, goal: Array) -> Array:
	var all := nodes()
	if goal not in all:
		return []
	# A moving squad can connect only to endpoints on its current segment.
	var costs: Dictionary = {}
	var paths: Dictionary = {}
	var todo: Array = []
	for i in all.size():
		var p: Array = all[i]
		var aligned := int(start[1]) == int(p[1]) or (int(start[0]) == int(p[0]) and int(p[0]) in [20 * SCALE, 60 * SCALE, 100 * SCALE])
		if aligned and visible(s, start, p):
			costs[i] = distance(start, p)
			paths[i] = [p]
			todo.append(i)
	while not todo.is_empty():
		var best := int(todo[0])
		for value in todo:
			if int(costs[value]) < int(costs[best]):
				best = int(value)
		todo.erase(best)
		if all[best] == goal:
			return paths[best]
		for j in all.size():
			if not linked(s, all[best], all[j]):
				continue
			var cost := int(costs[best]) + distance(all[best], all[j])
			if not costs.has(j) or cost < int(costs[j]):
				costs[j] = cost
				paths[j] = Array(paths[best]).duplicate(true)
				paths[j].append(all[j])
				if j not in todo:
					todo.append(j)
	return []

static func initialize(s: BattleSession, legacy := false) -> Dictionary:
	var state := {"version": 1, "units": {}, "enemies": {}, "tasks": {}, "orders": [], "gate_crew": 0, "deployed": false}
	for squad in s.squads:
		var id := str(squad.squad_id)
		var y := route_y(StringName(squad.route_id))
		var x := 84 if defense(s) else 0
		if legacy:
			var progress := int(squad.position_fixed)
			var length := int(s.routes[squad.route_id].distance_fixed)
			x = (84 + int(36 * (length - progress) / maxi(length, 1))) if defense(s) else int(76 * progress / maxi(length, 1))
		state.units[id] = point(x, y)
		state.tasks[id] = {"kind": "AUTO" if int(squad.active_order) == BattleOrder.Command.ADVANCE else "HOLD", "target": point(x, y), "route": StringName(squad.route_id), "path": []}
	for route in s.routes:
		var x := 0 if defense(s) else 84
		if legacy and defense(s):
			x = int(76 * int(s.routes[route].enemy_position_fixed) / maxi(int(s.routes[route].distance_fixed), 1))
		state.enemies[str(route)] = point(x, route_y(route))
	state.deployed = legacy or s.current_tick > 0
	return state

static func valid(s: BattleSession, state: Dictionary, accepted: Array = []) -> bool:
	if state.is_empty():
		return s.request.source_id not in [BattleRequest.SOURCE_MACRO_SIEGE, BattleRequest.SOURCE_WARTIME_DEFENSE]
	if state.size() != 7 or state.get("version") != 1 or typeof(state.get("units")) != TYPE_DICTIONARY or typeof(state.get("enemies")) != TYPE_DICTIONARY or typeof(state.get("tasks")) != TYPE_DICTIONARY or typeof(state.get("orders")) != TYPE_ARRAY or typeof(state.get("gate_crew")) != TYPE_INT or typeof(state.get("deployed")) != TYPE_BOOL:
		return false
	if state.units.size() != s.squads.size() or state.tasks.size() != s.squads.size() or state.enemies.size() != 2:
		return false
	for squad in s.squads:
		var id := str(squad.squad_id)
		if not valid_point(state.units.get(id)) or typeof(state.tasks.get(id)) != TYPE_DICTIONARY:
			return false
		var task: Dictionary = state.tasks[id]
		if task.size() != 4 or task.get("kind") not in ["AUTO", "HOLD", "MOVE", "ATTACK", "RETREAT", "WORK"] or not valid_point(task.get("target")) or typeof(task.get("path")) != TYPE_ARRAY or task.get("route") not in s.routes:
			return false
		for p in task.path:
			if not valid_point(p):
				return false
	for route in s.routes:
		if not valid_point(state.enemies.get(str(route))):
			return false
	var seen := {}
	for order in state.orders:
		if not order is Dictionary or order.size() != 6 or typeof(order.get("id")) != TYPE_INT or int(order.id) <= 0 or seen.has(order.id) or typeof(order.get("squad")) != TYPE_INT or not state.units.has(str(order.squad)) or order.get("kind") not in ["MOVE", "ATTACK", "HOLD", "RETREAT"] or not valid_point(order.get("target")) or typeof(order.get("tick")) != TYPE_INT or int(order.tick) < 0 or order.get("route") not in s.routes:
			return false
		var matches := false
		for receipt in accepted:
			if receipt is Dictionary and receipt.get("order_id") == order.id and receipt.get("squad_id") == order.squad and receipt.get("issued_tick") == order.tick:
				matches = true
		if not matches:
			return false
		seen[order.id] = true
	return state.gate_crew == 0 or state.units.has(str(state.gate_crew))

static func valid_point(p: Variant) -> bool:
	if not p is Array or p.size() != 2 or typeof(p[0]) != TYPE_INT or typeof(p[1]) != TYPE_INT:
		return false
	if p[0] < 0 or p[0] > 120 * SCALE or p[1] < 24 * SCALE or p[1] > 64 * SCALE:
		return false
	return p[1] in [24 * SCALE, 64 * SCALE] or p[0] in [20 * SCALE, 60 * SCALE, 100 * SCALE]

static func deploy(s: BattleSession, id: int, target: Array) -> String:
	if s.current_tick != 0 or s.completed or not s._has_commandable_squad(id):
		return "战斗已经推进，不能重新部署"
	if target not in nodes() or (int(target[0]) not in ([60 * SCALE, 84 * SCALE, 100 * SCALE, 120 * SCALE] if defense(s) else [0, 20 * SCALE])):
		return "只能部署在标出的集结区或守城前沿"
	s.spatial_state.units[str(id)] = target.duplicate()
	s.spatial_state.tasks[str(id)].target = target.duplicate()
	s.spatial_state.deployed = true
	return ""

static func command(s: BattleSession, id: int, kind: String, target: Array, route: StringName) -> String:
	if s.completed or not s._has_commandable_squad(id):
		return "编队已阵亡或撤离"
	if kind not in ["MOVE", "ATTACK", "HOLD", "RETREAT"]:
		return "未知命令"
	var p: Array = s.spatial_state.units[str(id)]
	var goal := target.duplicate()
	if kind == "HOLD":
		goal = p.duplicate()
	elif kind == "RETREAT":
		goal = point(120 if int(p[0]) > 80 * SCALE else 0, route_y(route_at(p)))
	elif kind == "ATTACK":
		if route not in s.routes or (int(s.routes[route].enemy_total_hp) <= 0 and (defense(s) or int(s.routes[route].gate_hp) <= 0)):
			return "目标已失效"
		goal = attack_goal(s, p, route)
	if kind != "HOLD" and path(s, p, goal).is_empty():
		return "目标不可达：城墙或未突破的城门阻挡"
	var order := s.issue_order(id, BattleOrder.Command.RETREAT if kind == "RETREAT" else (BattleOrder.Command.HOLD if kind == "HOLD" else BattleOrder.Command.ADVANCE))
	if order == null:
		return "本战斗刻已有命令，请等待下一刻"
	interrupt_work(s, id)
	s.spatial_state.tasks[str(id)] = {"kind": kind, "target": goal, "route": route if route in s.routes else route_at(goal), "path": path(s, p, goal)}
	s.spatial_state.orders.append({"id": order.order_id, "squad": id, "kind": kind, "target": goal, "route": route if route in s.routes else route_at(goal), "tick": s.current_tick})
	return ""

static func attack_goal(s: BattleSession, p: Array, route: StringName) -> Array:
	if defense(s):
		return point(84 if int(p[0]) > 80 * SCALE else 60, route_y(route))
	return point(76 if not gate_open(s, route) else 84, route_y(route))

static func facility_point(record: Dictionary) -> Array:
	var x := 84
	match StringName(record.kind):
		WartimeFacilityPlan.KIND_SIEGE_RAM, WartimeFacilityPlan.KIND_BARRICADE: x = 76
		WartimeFacilityPlan.KIND_SPIKE_TRAP: x = 60
		WartimeFacilityPlan.KIND_WATCH_PLATFORM: x = 100
		WartimeFacilityPlan.KIND_ARROW_TOWER: x = 84
	return point(x, route_y(StringName(record.route_id)))

static func work_point(s: BattleSession, record: Dictionary) -> Array:
	var p := facility_point(record)
	if not defense(s) and record.kind == WartimeFacilityPlan.KIND_ARROW_TOWER:
		p[0] = 60 * SCALE
	return p

static func interrupt_work(s: BattleSession, id: int) -> void:
	for record in s.wartime_facility_state.get("facilities", []):
		if int(record.construction_squad_id) == id and record.phase in [s.FACILITY_PHASE_CONSTRUCTING, s.FACILITY_PHASE_REPAIRING]:
			record.phase = s.FACILITY_PHASE_INTERRUPTED
	if int(s.spatial_state.gate_crew) == id:
		cancel_gate_work(s)

static func cancel_gate_work(s: BattleSession) -> void:
	s.spatial_state.gate_crew = 0
	s.mission_objective_state.protect_target_repair_phase = s.PROTECT_TARGET_REPAIR_IDLE
	s.mission_objective_state.protect_target_repair_progress_ticks = 0
	s.mission_objective_state.protect_target_repair_required_ticks = 0
	s.mission_objective_state.protect_target_repair_amount = 0

static func job(s: BattleSession, id: int) -> Dictionary:
	if int(s.spatial_state.gate_crew) == id and s.mission_objective_state.get("protect_target_repair_phase") == s.PROTECT_TARGET_REPAIRING:
		return {"target": point(84, route_y(route_at(s.spatial_state.units[str(id)]))), "id": "gate"}
	for record in s.wartime_facility_state.get("facilities", []):
		if int(record.construction_squad_id) == id and record.phase in [s.FACILITY_PHASE_CONSTRUCTING, s.FACILITY_PHASE_REPAIRING]:
			return {"target": work_point(s, record), "id": str(record.facility_id)}
	return {}

static func work_reachable(s: BattleSession, id: int, target: Array) -> bool:
	if not s._has_commandable_squad(id):
		return false
	var p: Array = s.spatial_state.units[str(id)]
	if distance(p, target) <= WORK_RANGE:
		return true
	for candidate in nodes():
		if distance(candidate, target) <= WORK_RANGE and not path(s, p, candidate).is_empty():
			return true
	return false

static func work_ready(s: BattleSession, record: Dictionary) -> bool:
	var id := int(record.construction_squad_id)
	var task := job(s, id)
	return not task.is_empty() and task.id == str(record.facility_id) and distance(s.spatial_state.units[str(id)], work_point(s, record)) <= WORK_RANGE

static func travel(s: BattleSession, p: Array, goal: Array, speed: int, stop_range := 0) -> Array:
	if distance(p, goal) <= stop_range:
		return p
	var way := path(s, p, goal)
	if way.is_empty() and stop_range > 0:
		var closest: Array = []
		var best := 1000000
		for candidate in nodes():
			if distance(candidate, goal) <= stop_range and not path(s, p, candidate).is_empty() and distance(p, candidate) < best:
				closest = candidate
				best = distance(p, candidate)
		if not closest.is_empty():
			way = path(s, p, closest)
	var current := p.duplicate()
	for next in way:
		if distance(current, goal) <= stop_range or speed <= 0:
			break
		var step := mini(speed, distance(current, next))
		if int(current[0]) != int(next[0]):
			current[0] = int(current[0]) + signi(int(next[0]) - int(current[0])) * step
		else:
			current[1] = int(current[1]) + signi(int(next[1]) - int(current[1])) * step
		speed -= step
	return current

static func move(s: BattleSession) -> void:
	for squad in s.squads:
		var id := int(squad.squad_id)
		if not s._has_commandable_squad(id):
			continue
		var key := str(id)
		var p: Array = s.spatial_state.units[key]
		var task: Dictionary = s.spatial_state.tasks[key]
		var work := job(s, id)
		var goal: Array = task.target
		var stop := 0
		if not work.is_empty():
			goal = work.target
			stop = WORK_RANGE
		elif int(squad.active_order) == BattleOrder.Command.RETREAT:
			goal = point(120 if int(p[0]) > 80 * SCALE else 0, route_y(route_at(p)))
		elif int(squad.active_order) == BattleOrder.Command.HOLD:
			continue
		elif task.kind in ["AUTO", "ATTACK", "HOLD"]:
			goal = attack_goal(s, p, StringName(task.route))
		var speed := maxi(int(s.request.committed_force.move_speed_fixed / 4), 1)
		speed = maxi(int(speed * s._support_basis_points(s.SUPPORT_MOVE, id, route_at(p)) / s.BASIS_POINTS), 1)
		if int(squad.active_order) == BattleOrder.Command.RETREAT:
			speed = int(speed * 5 / 4)
		var moved := travel(s, p, goal, speed, stop)
		s.spatial_state.units[key] = moved
		task.target = goal
		task.path = path(s, moved, goal)
		# Historical scalar is a projection only, retained for old result contracts.
		var length := int(s.routes[squad.route_id].distance_fixed)
		squad.position_fixed = clampi(int((120 * SCALE - int(moved[0]) if defense(s) else int(moved[0])) * length / (76 * SCALE)), 0, length)
		if int(squad.active_order) == BattleOrder.Command.RETREAT and moved == goal:
			squad.exited = true
		if work.is_empty() and task.kind == "MOVE" and moved == goal:
			squad.active_order = BattleOrder.Command.HOLD
	if not defense(s):
		return
	for route in s.routes:
		if int(s.routes[route].enemy_total_hp) <= 0:
			continue
		var p: Array = s.spatial_state.enemies[str(route)]
		var speed := maxi(int(s.request.committed_force.move_speed_fixed / 4), 1)
		var goal := point(76, route_y(route))
		for record in s.wartime_facility_state.get("facilities", []):
			if record.kind == WartimeFacilityPlan.KIND_BARRICADE and record.route_id == route and record.phase in [s.FACILITY_PHASE_ACTIVE, s.FACILITY_PHASE_DAMAGED] and int(record.durability) > 0:
				goal = point(60, route_y(route))
		var engaged := false
		for squad in s.squads:
			if s._has_commandable_squad(int(squad.squad_id)) and distance(p, s.spatial_state.units[str(squad.squad_id)]) <= MELEE and visible(s, p, s.spatial_state.units[str(squad.squad_id)]):
				engaged = true
		if int(p[0]) > int(goal[0]):
			goal = p
		if not engaged:
			s.spatial_state.enemies[str(route)] = travel(s, p, goal, speed)
		s.routes[route].enemy_position_fixed = int(int(s.spatial_state.enemies[str(route)][0]) * int(s.routes[route].distance_fixed) / (76 * SCALE))

static func can_hit(s: BattleSession, squad: Dictionary, route: StringName) -> bool:
	if not s._has_commandable_squad(int(squad.squad_id)) or not job(s, int(squad.squad_id)).is_empty():
		return false
	var p: Array = s.spatial_state.units[str(squad.squad_id)]
	var enemy: Array = s.spatial_state.enemies[str(route)]
	var parapet := defense(s) and int(p[0]) >= 84 * SCALE
	return distance(p, enemy) <= (PARAPET_RANGE if parapet else MELEE) and visible(s, p, enemy, parapet)

static func damage(s: BattleSession) -> Dictionary:
	var intents := {"gate_damage": {}, "enemy_damage": {}, "player_damage": {}, "facility_damage": {}, "protect_damage": 0}
	for route in s.routes:
		intents.gate_damage[route] = 0
		intents.enemy_damage[route] = 0
	for record in s.wartime_facility_state.get("facilities", []):
		if record.phase not in [s.FACILITY_PHASE_ACTIVE, s.FACILITY_PHASE_DAMAGED]:
			continue
		var p := work_point(s, record)
		for route in s.routes:
			if int(s.routes[route].enemy_total_hp) <= 0:
				continue
			var enemy: Array = s.spatial_state.enemies[str(route)]
			if record.kind == WartimeFacilityPlan.KIND_SPIKE_TRAP and distance(p, enemy) <= 8 * SCALE:
				s.last_tick_facility_events.append({"kind": record.kind, "route_id": route, "event": &"TRAP_TRIGGERED", "damage": s.SPIKE_TRAP_DAMAGE_ON_TRIGGER, "tick": s.current_tick})
				intents.enemy_damage[route] += s.SPIKE_TRAP_DAMAGE_ON_TRIGGER
				intents.facility_damage[record.facility_id] = int(record.durability)
				break
			if record.kind == WartimeFacilityPlan.KIND_ARROW_TOWER and s.current_tick % 4 == 0 and distance(p, enemy) <= TOWER_RANGE:
				var volley := s._get_arrow_tower_volley_damage(record)
				intents.enemy_damage[route] += volley
				s.last_tick_facility_events.append({"kind": record.kind, "route_id": route, "damage": volley, "tick": s.current_tick})
				break
	if s.current_tick % 4 != 0:
		return intents
	for squad in s.squads:
		var id := int(squad.squad_id)
		if not s._has_commandable_squad(id) or int(squad.active_order) == BattleOrder.Command.RETREAT or not job(s, id).is_empty():
			continue
		var p: Array = s.spatial_state.units[str(id)]
		var attack_multiplier := s._support_basis_points(s.SUPPORT_ATTACK, id, route_at(p))
		if int(squad.active_order) == BattleOrder.Command.HOLD:
			attack_multiplier = int(attack_multiplier * s.HOLD_ATTACK_BASIS_POINTS / s.BASIS_POINTS)
		var amount := s._calculate_player_damage(s._alive_members(int(squad.total_hp)), attack_multiplier)
		for route in s.routes:
			if not defense(s) and int(s.routes[route].gate_hp) > 0 and distance(p, point(80, route_y(route))) <= MELEE:
				intents.gate_damage[route] += amount
				break
			if int(s.routes[route].enemy_total_hp) > 0 and can_hit(s, squad, route):
				intents.enemy_damage[route] += amount
				break
	for route in s.routes:
		if int(s.routes[route].enemy_total_hp) <= 0:
			continue
		var enemy: Array = s.spatial_state.enemies[str(route)]
		var target := 0
		var closest := 100000
		for squad in s.squads:
			var id := int(squad.squad_id)
			if not s._has_commandable_squad(id):
				continue
			var p: Array = s.spatial_state.units[str(id)]
			var d := distance(p, enemy)
			# Gate defenders exchange missiles through the parapet, not movement.
			var ranged := not defense(s) or int(p[0]) >= 84 * SCALE
			if d <= ((12 * SCALE if not defense(s) else PARAPET_RANGE) if ranged else MELEE) and visible(s, p, enemy, ranged) and d < closest:
				target = id
				closest = d
		var amount := s._calculate_enemy_damage(s._alive_members(int(s.routes[route].enemy_total_hp)), s.BASIS_POINTS)
		if target > 0:
			var squad := s.get_squad_state(target)
			amount = int(amount * s._get_incoming_basis_points(int(squad.active_order) as BattleOrder.Command) / s.BASIS_POINTS)
			amount = int(amount * s._support_basis_points(s.SUPPORT_PROTECT, target, route_at(s.spatial_state.units[str(target)])) / s.BASIS_POINTS)
			intents.player_damage[target] = int(intents.player_damage.get(target, 0)) + amount
			s.last_tick_facility_events.append({"kind": &"UNIT_HIT", "route_id": route, "squad_id": target, "damage": amount, "tick": s.current_tick})
			continue
		var hit_work := false
		for record in s.wartime_facility_state.get("facilities", []):
			if int(record.durability) > 0 and (record.phase not in [s.FACILITY_PHASE_CONSTRUCTING, s.FACILITY_PHASE_INTERRUPTED] or int(record.progress_ticks) > 0) and distance(enemy, work_point(s, record)) <= 16 * SCALE:
				intents.facility_damage[record.facility_id] = int(intents.facility_damage.get(record.facility_id, 0)) + amount
				hit_work = true
				break
		if defense(s) and not hit_work and distance(enemy, point(80, route_y(route))) <= MELEE:
			intents.protect_damage += s._alive_members(int(s.routes[route].enemy_total_hp)) * s.mission_definition.protect_damage_per_enemy
	return intents
