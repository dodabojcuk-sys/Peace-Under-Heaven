class_name BattlePresentationModel
extends RefCounted


const ROUTE_IDS: Array[StringName] = [
	CommittedForceSnapshot.FRONT_ROUTE,
	CommittedForceSnapshot.SIDE_ROUTE,
]


static func build_snapshot(
	request: BattleRequest,
	session: BattleSession,
	mission: MissionDefinition,
	selected_squad_id := -1
) -> Dictionary:
	if request == null or request.committed_force == null:
		return {}
	# Prepared formal entries persist their mission on the request.  The C0
	# scene does not own that durable fact, so use it when a transient scene
	# configuration did not supply a mission explicitly.
	var effective_mission := mission if mission != null else request.mission_definition

	var routes: Array[Dictionary] = []
	for route_id in ROUTE_IDS:
		routes.append(
			_build_route(request, session, effective_mission, route_id)
		)

	var squads: Array[Dictionary] = []
	for squad_snapshot in request.committed_force.squads:
		squads.append(
			_build_squad(
				request,
				session,
				routes,
				squad_snapshot,
				selected_squad_id
			)
		)

	return {
		"title": effective_mission.title if effective_mission != null else "北坡防御战",
		"objective_text": (
			effective_mission.objective_text
			if effective_mission != null
			else "突破两处城门并击溃守军"
		),
		"phase_text": _phase_text(request.phase),
		"tick": session.current_tick if session != null else 0,
		"elapsed_seconds": (
			float(session.current_tick * BattleSession.TICK_MILLISECONDS)
				/ 1000.0
			if session != null
			else 0.0
		),
		"routes": routes,
		"squads": squads,
		"selected_squad_id": selected_squad_id,
		"objective": _build_objective(request, session, effective_mission, routes),
	}


static func _build_route(
	request: BattleRequest,
	session: BattleSession,
	mission: MissionDefinition,
	route_id: StringName
) -> Dictionary:
	var initial: Dictionary = request.enemy_force.route_states.get(route_id, {})
	var distance_fixed := _initial_distance_fixed(mission, route_id)
	var enemy_hp := (
		int(initial.get("enemy_members", 0))
			* request.committed_force.hp_per_member
	)
	var gate_hp := int(initial.get("gate_hp", 0))
	var gate_max_hp := gate_hp
	var enemy_position_fixed := 0
	if session != null:
		var state := session.get_route_state(route_id)
		distance_fixed = int(state.get("distance_fixed", distance_fixed))
		enemy_hp = int(state.get("enemy_total_hp", enemy_hp))
		gate_hp = int(state.get("gate_hp", gate_hp))
		gate_max_hp = int(state.get("gate_initial_hp", gate_max_hp))
		enemy_position_fixed = int(state.get("enemy_position_fixed", 0))
	var enemy_count := _alive_members(
		enemy_hp,
		request.committed_force.hp_per_member
	)
	# Protection routes are visible threats, but their exact strength is a
	# battle fact revealed by the completed watch platform on that route. The
	# presentation consumes this projection only; it never changes enemy HP or
	# gives C0 a second source of intelligence.
	var enemy_count_known := not (
		mission != null
		and mission.objective_type == MissionDefinition.OBJECTIVE_PROTECT
	)
	if session != null and not enemy_count_known:
		var facilities := session.get_wartime_facility_state()
		enemy_count_known = (
			bool(facilities.get("enemy_observation_ready", false))
			and StringName(facilities.get("watch_route_id", &"")) == route_id
		)
	var route_name := _route_name(mission, route_id)
	var engaged_squads: Array[int] = []
	if session != null:
		for squad in session.squads:
			if (
				StringName(squad.route_id) == route_id
				and int(squad.total_hp) > 0
				and not bool(squad.exited)
				and int(squad.position_fixed) >= distance_fixed
			):
				engaged_squads.append(int(squad.squad_id))
	var enemy_status := "已肃清"
	if enemy_count > 0 and not engaged_squads.is_empty():
		enemy_status = "正在与%s接战" % _join_squad_names(engaged_squads)
	elif enemy_count > 0:
		enemy_status = (
			"正在逼近城门"
			if mission != null and mission.objective_type == MissionDefinition.OBJECTIVE_PROTECT
			else "据守路线尽头"
		)
	return {
		"route_id": route_id,
		"name": route_name,
		"distance_fixed": distance_fixed,
		"enemy_count": enemy_count,
		"enemy_count_known": enemy_count_known,
		"enemy_initial_count": int(initial.get("enemy_members", 0)),
		"enemy_status": enemy_status,
		"engaged_squad_ids": engaged_squads,
		"gate_hp": gate_hp,
		"gate_max_hp": gate_max_hp,
		"has_obstacle": gate_max_hp > 0,
		"enemy_position_ratio": (
			clampf(float(enemy_position_fixed) / float(maxi(distance_fixed, 1)), 0.0, 1.0)
			if mission != null and mission.objective_type == MissionDefinition.OBJECTIVE_PROTECT
			else 1.0
		),
		"enemy_direction_text": "敌军来向 ←",
	}


static func _build_squad(
	request: BattleRequest,
	session: BattleSession,
	routes: Array[Dictionary],
	snapshot: Dictionary,
	selected_squad_id: int
) -> Dictionary:
	var squad_id := int(snapshot.squad_id)
	var route_id := StringName(snapshot.route_id)
	var initial_members := int(snapshot.initial_members)
	var total_hp := initial_members * request.committed_force.hp_per_member
	var position_fixed := 0
	var command := BattleOrder.Command.HOLD
	var exited := false
	if session != null:
		var state := session.get_squad_state(squad_id)
		route_id = StringName(state.route_id)
		total_hp = int(state.total_hp)
		position_fixed = int(state.position_fixed)
		command = int(state.active_order) as BattleOrder.Command
		exited = bool(state.exited)
	var alive_members := _alive_members(
		total_hp,
		request.committed_force.hp_per_member
	)
	var route := _find_route(routes, route_id)
	var distance_fixed := maxi(int(route.get("distance_fixed", 1)), 1)
	var enemy_count := int(route.get("enemy_count", 0))
	var state_text := "待命"
	if alive_members <= 0:
		state_text = "失去战斗能力"
	elif exited:
		state_text = "已撤离"
	elif session == null:
		state_text = "等待部署"
	elif command == BattleOrder.Command.RETREAT:
		state_text = "撤退中"
	elif position_fixed >= distance_fixed and enemy_count > 0:
		state_text = "接敌中"
	elif command == BattleOrder.Command.ADVANCE:
		state_text = "前进中"
	else:
		state_text = "坚守"
	return {
		"squad_id": squad_id,
		"formation_id": StringName(snapshot.get("formation_id", &"")),
		"name": str(snapshot.get("display_name", squad_name(squad_id))),
		"route_id": route_id,
		"route_name": str(route.get("name", "未知路线")),
		"initial_members": initial_members,
		"alive_members": alive_members,
		"total_hp": total_hp,
		"max_hp": initial_members * request.committed_force.hp_per_member,
		"position_fixed": position_fixed,
		"position_ratio": clampf(
			float(position_fixed) / float(distance_fixed),
			0.0,
			1.0
		),
		"command_text": command_text(command),
		"state_text": state_text,
		"selected": squad_id == selected_squad_id,
		"command_enabled": (
			request.phase == BattleRequest.PHASE_ACTIVE
			and alive_members > 0
			and not exited
		),
	}


static func _build_objective(
	request: BattleRequest,
	session: BattleSession,
	mission: MissionDefinition,
	routes: Array[Dictionary]
) -> Dictionary:
	if mission == null:
		var remaining_text := _remaining_enemy_text(routes)
		return {
			"type": MissionDefinition.OBJECTIVE_ELIMINATE,
			"progress_text": remaining_text,
			"show_wagon": false,
			"show_search": false,
			"completed": _remaining_enemy_count(routes) == 0,
			"failed": false,
		}
	var state := (
		session.get_mission_objective_state()
		if session != null
		else {}
	)
	var objective := {
		"type": mission.objective_type,
		"progress_text": _remaining_enemy_text(routes),
		"show_wagon": false,
		"show_search": false,
		"completed": false,
		"failed": false,
	}
	if mission.objective_type == MissionDefinition.OBJECTIVE_PROTECT:
		var hp := int(
			state.get("protect_target_hp", mission.protect_target_hp)
		)
		var max_hp := int(
			state.get("protect_target_max_hp", mission.protect_target_hp)
		)
		var attacking_routes: Array[String] = []
		if session != null:
			for route in routes:
				if (
					int(route.enemy_count) > 0
					and float(route.get("enemy_position_ratio", 0.0)) >= 1.0
					and Array(route.engaged_squad_ids).is_empty()
				):
					attacking_routes.append(str(route.name))
		objective.merge({
			"show_wagon": true,
			"wagon_name": mission.protect_target_name,
			"wagon_hp": hp,
			"wagon_max_hp": max_hp,
			"wagon_danger": hp < max_hp or not attacking_routes.is_empty(),
			"attacking_routes": attacking_routes,
			"completed": hp > 0 and _remaining_enemy_count(routes) == 0,
			"failed": hp <= 0,
			"progress_text": "%s %d/%d｜%s" % [
				mission.protect_target_name,
				hp,
				max_hp,
				_remaining_enemy_text(routes),
			],
		}, true)
	elif mission.objective_type == MissionDefinition.OBJECTIVE_SCOUT:
		var found := bool(state.get("scout_found", false))
		var extracted := bool(state.get("extraction_reached", false))
		objective.merge({
			"show_search": true,
			"scout_found": found,
			"extraction_reached": extracted,
			"completed": found and extracted,
			"failed": false,
			"revealed_route_id": (
				mission.scout_route_id if found else StringName()
			),
			"search_zones": [
				{
					"route_id": CommittedForceSnapshot.FRONT_ROUTE,
					"label": (
						"已搜索"
						if found
							and mission.scout_route_id
								== CommittedForceSnapshot.FRONT_ROUTE
						else "搜索区？"
					),
				},
				{
					"route_id": CommittedForceSnapshot.SIDE_ROUTE,
					"label": (
						"已找到斥候"
						if found
							and mission.scout_route_id
								== CommittedForceSnapshot.SIDE_ROUTE
						else "搜索区？"
					),
				},
			],
			"progress_text": "%s｜%s" % [
				"斥候已找到" if found else "斥候位置未知",
				"已安全撤离" if extracted else "需返回左侧撤离区",
			],
		}, true)
	else:
		objective.completed = _remaining_enemy_count(routes) == 0
	return objective


static func _initial_distance_fixed(
	mission: MissionDefinition,
	route_id: StringName
) -> int:
	if mission != null:
		return (
			mission.front_distance_units
				if route_id == CommittedForceSnapshot.FRONT_ROUTE
				else mission.side_distance_units
		) * BattleSession.DISTANCE_SCALE
	return (
		BattleSession.FRONT_DISTANCE_FIXED
		if route_id == CommittedForceSnapshot.FRONT_ROUTE
		else BattleSession.SIDE_DISTANCE_FIXED
	)


static func _route_name(
	mission: MissionDefinition,
	route_id: StringName
) -> String:
	if mission != null:
		return (
			mission.front_route_name
			if route_id == CommittedForceSnapshot.FRONT_ROUTE
			else mission.side_route_name
		)
	return (
		"正门路线"
		if route_id == CommittedForceSnapshot.FRONT_ROUTE
		else "侧门路线"
	)


static func _phase_text(phase: StringName) -> String:
	if phase == BattleRequest.PHASE_RESERVED:
		return "战前部署"
	if phase == BattleRequest.PHASE_ACTIVE:
		return "战斗进行中"
	if phase == BattleRequest.PHASE_RESULT_PENDING:
		return "战斗结束 · 等待确认战果"
	if phase == BattleRequest.PHASE_APPLIED:
		return "战果已写回"
	if phase == BattleRequest.PHASE_CANCELLED:
		return "已取消出战"
	return "正在返回内城"


static func command_text(command: BattleOrder.Command) -> String:
	if command == BattleOrder.Command.ADVANCE:
		return "推进"
	if command == BattleOrder.Command.RETREAT:
		return "撤退"
	return "坚守"


static func squad_name(squad_id: int) -> String:
	var names := ["一队", "二队", "三队"]
	if squad_id > 0 and squad_id <= names.size():
		return names[squad_id - 1]
	return "%d 队" % squad_id


static func _join_squad_names(squad_ids: Array[int]) -> String:
	var names: Array[String] = []
	for squad_id in squad_ids:
		names.append(squad_name(squad_id))
	return "、".join(names)


static func _find_route(
	routes: Array[Dictionary],
	route_id: StringName
) -> Dictionary:
	for route in routes:
		if StringName(route.route_id) == route_id:
			return route
	return {}


static func _remaining_enemy_text(routes: Array[Dictionary]) -> String:
	for route in routes:
		if not bool(route.get("enemy_count_known", true)):
			return "敌情未明（瞭望台完工后显示兵力）"
	return "剩余敌人 %d" % _remaining_enemy_count(routes)


static func _remaining_enemy_count(routes: Array[Dictionary]) -> int:
	var remaining := 0
	for route in routes:
		remaining += int(route.enemy_count)
	return remaining


static func _alive_members(total_hp: int, hp_per_member: int) -> int:
	if total_hp <= 0 or hp_per_member <= 0:
		return 0
	@warning_ignore("integer_division")
	return (total_hp + hp_per_member - 1) / hp_per_member
