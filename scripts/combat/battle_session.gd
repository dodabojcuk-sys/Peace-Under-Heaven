class_name BattleSession
extends RefCounted


signal terminal_completed(result_payload: BattleResult, terminal_record: Dictionary)


const TICK_MILLISECONDS := 250
const ATTACK_INTERVAL_TICKS := 4
const MAX_BATTLE_TICKS := 720
const DISTANCE_SCALE := 16
const FRONT_DISTANCE_FIXED := 80 * DISTANCE_SCALE
const SIDE_DISTANCE_FIXED := 120 * DISTANCE_SCALE
const BASIS_POINTS := 10000
const HOLD_ATTACK_BASIS_POINTS := 8500
const HOLD_INCOMING_BASIS_POINTS := 7500
const RETREAT_INCOMING_BASIS_POINTS := 11500
const RETREAT_SPEED_NUMERATOR := 5
const RETREAT_SPEED_DENOMINATOR := 4
const FIRST_CLEAR_KEY := &"first_map.main_assault.v0"
const SIEGE_RAM_GATE_DAMAGE := 160
const SNAPSHOT_SCHEMA_VERSION := 1
const SNAPSHOT_KEYS := [
	"schema_version", "current_tick", "next_order_id", "squads", "routes",
	"pending_orders", "accepted_orders", "retreat_was_ordered",
	"forced_retreat_requested", "mission_objective_state",
]

var request: BattleRequest
var session_id: StringName
var current_tick := 0
var next_order_id := 1
var squads: Array[Dictionary] = []
var routes: Dictionary = {}
var pending_orders: Array[BattleOrder] = []
var accepted_orders: Array[BattleOrder] = []
var retreat_was_ordered := false
var forced_retreat_requested := false
var completed := false
var result: BattleResult
var _terminal_authority_record: Dictionary = {}
var mission_definition: MissionDefinition
var mission_objective_state: Dictionary = {}
var wartime_facility_state: Dictionary = {}


func _init(request_value: BattleRequest = null) -> void:
	if request_value != null:
		initialize(request_value)


func initialize(request_value: BattleRequest) -> bool:
	if (
		request_value == null
		or not request_value.is_valid()
		or request_value.phase != BattleRequest.PHASE_ACTIVE
	):
		return false
	request = request_value
	session_id = StringName("%s-session" % request.transaction_id)
	current_tick = 0
	next_order_id = 1
	squads.clear()
	routes.clear()
	pending_orders.clear()
	accepted_orders.clear()
	retreat_was_ordered = false
	forced_retreat_requested = false
	completed = false
	result = null
	_terminal_authority_record = {}
	mission_definition = request.mission_definition
	mission_objective_state = {}
	wartime_facility_state = {}
	for squad_snapshot in request.committed_force.squads:
		var initial_members := int(squad_snapshot.initial_members)
		squads.append({
			"squad_id": int(squad_snapshot.squad_id),
			"formation_id": StringName(squad_snapshot.formation_id),
			"display_name": str(squad_snapshot.display_name),
			"initial_members": initial_members,
			"total_hp": (
				initial_members * request.committed_force.hp_per_member
			),
			"route_id": StringName(squad_snapshot.route_id),
			"position_fixed": 0,
			"active_order": BattleOrder.Command.HOLD,
			"exited": false,
		})
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var enemy_route: Dictionary = (
			request.enemy_force.route_states[route_id]
		)
		routes[route_id] = {
			"enemy_initial_members": int(enemy_route.enemy_members),
			"enemy_total_hp": (
				int(enemy_route.enemy_members)
				* request.committed_force.hp_per_member
			),
			"gate_initial_hp": int(enemy_route.gate_hp),
			"gate_hp": int(enemy_route.gate_hp),
			"distance_fixed": _get_initial_route_distance_fixed(route_id),
		}
	_apply_wartime_facilities()
	_initialize_mission_objective_state()
	return true


func issue_order(
	squad_id: int,
	command: BattleOrder.Command
) -> BattleOrder:
	if completed or not _has_commandable_squad(squad_id):
		return null
	for pending_order in pending_orders:
		if (
			pending_order.squad_id == squad_id
			and pending_order.issued_tick == current_tick
		):
			return null
	var order := BattleOrder.new(
		next_order_id,
		session_id,
		squad_id,
		current_tick,
		command
	)
	next_order_id += 1
	pending_orders.append(order)
	accepted_orders.append(order)
	if command == BattleOrder.Command.RETREAT:
		retreat_was_ordered = true
	return order


func step_tick() -> bool:
	if completed or request == null:
		return false
	current_tick += 1
	_apply_orders_for_current_tick()
	_update_positions()
	var damage_intents := _build_damage_intents()
	_apply_damage_intents(damage_intents)
	_check_outcome()
	return true


func run_until_complete(max_ticks := MAX_BATTLE_TICKS) -> BattleResult:
	var remaining := max_ticks
	while not completed and remaining > 0:
		step_tick()
		remaining -= 1
	return result


func get_squad_state(squad_id: int) -> Dictionary:
	for squad in squads:
		if int(squad.squad_id) == squad_id:
			return squad.duplicate(true)
	return {}


func get_route_state(route_id: StringName) -> Dictionary:
	var route: Dictionary = routes.get(route_id, {})
	return route.duplicate(true)


func get_mission_objective_state() -> Dictionary:
	return mission_objective_state.duplicate(true)


func get_wartime_facility_state() -> Dictionary:
	return wartime_facility_state.duplicate(true)


## Only authoritative simulation facts are persisted.  The request itself is
## stored by the city attempt; this snapshot never contains scene nodes,
## animation state or UI selection.
func get_snapshot() -> Dictionary:
	if request == null or completed:
		return {}
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"current_tick": current_tick,
		"next_order_id": next_order_id,
		"squads": squads.duplicate(true),
		"routes": routes.duplicate(true),
		"pending_orders": _orders_to_snapshot(pending_orders),
		"accepted_orders": _orders_to_snapshot(accepted_orders),
		"retreat_was_ordered": retreat_was_ordered,
		"forced_retreat_requested": forced_retreat_requested,
		"mission_objective_state": mission_objective_state.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if request == null or request.phase != BattleRequest.PHASE_ACTIVE:
		return false
	if not _is_valid_snapshot(snapshot):
		return false
	var restored_squads: Array[Dictionary] = []
	var expected_squads: Dictionary = {}
	for original in squads:
		expected_squads[int(original.squad_id)] = original
	for squad_value in Array(snapshot.squads):
		if not squad_value is Dictionary:
			return false
		var squad: Dictionary = squad_value
		var squad_id := int(squad.get("squad_id", 0))
		var original: Dictionary = expected_squads.get(squad_id, {})
		if (
			original.is_empty()
			or StringName(squad.get("formation_id", &"")) != StringName(original.formation_id)
			or StringName(squad.get("route_id", &"")) != StringName(original.route_id)
			or int(squad.get("initial_members", 0)) != int(original.initial_members)
			or int(squad.get("total_hp", -1)) < 0
			or int(squad.get("total_hp", 0)) > int(original.initial_members) * request.committed_force.hp_per_member
			or int(squad.get("position_fixed", -1)) < 0
			or int(squad.get("position_fixed", 0)) > _get_route_distance_fixed(StringName(original.route_id))
			or int(squad.get("active_order", -1)) not in [BattleOrder.Command.ADVANCE, BattleOrder.Command.HOLD, BattleOrder.Command.RETREAT]
			or typeof(squad.get("exited", null)) != TYPE_BOOL
		):
			return false
		restored_squads.append(squad.duplicate(true))
	if restored_squads.size() != squads.size():
		return false
	var restored_routes: Dictionary = Dictionary(snapshot.routes).duplicate(true)
	for route_id in [CommittedForceSnapshot.FRONT_ROUTE, CommittedForceSnapshot.SIDE_ROUTE]:
		var original_route: Dictionary = routes.get(route_id, {})
		var restored_route: Dictionary = restored_routes.get(route_id, {})
		if (
			original_route.is_empty()
			or restored_route.is_empty()
			or int(restored_route.get("enemy_initial_members", -1)) != int(original_route.enemy_initial_members)
			or int(restored_route.get("gate_initial_hp", -1)) != int(original_route.gate_initial_hp)
			or int(restored_route.get("distance_fixed", -1)) != int(original_route.distance_fixed)
			or int(restored_route.get("enemy_total_hp", -1)) < 0
			or int(restored_route.get("gate_hp", -1)) < 0
			or int(restored_route.get("gate_hp", 0)) > int(original_route.gate_initial_hp)
		):
			return false
	var restored_pending: Variant = _orders_from_snapshot(Array(snapshot.pending_orders))
	var restored_accepted: Variant = _orders_from_snapshot(Array(snapshot.accepted_orders))
	if restored_pending == null or restored_accepted == null:
		return false
	var valid_squad_ids: Dictionary = {}
	for squad in restored_squads:
		valid_squad_ids[int(squad.squad_id)] = true
	var accepted_ids: Dictionary = {}
	var highest_order_id := 0
	for order in restored_accepted:
		if (
			order.session_id != session_id
			or not valid_squad_ids.has(order.squad_id)
			or order.issued_tick > int(snapshot.current_tick)
		):
			return false
		accepted_ids[order.order_id] = true
		highest_order_id = maxi(highest_order_id, order.order_id)
	for order in restored_pending:
		if (
			not accepted_ids.has(order.order_id)
			or order.session_id != session_id
			or not valid_squad_ids.has(order.squad_id)
		):
			return false
	if int(snapshot.next_order_id) <= highest_order_id:
		return false
	current_tick = int(snapshot.current_tick)
	next_order_id = int(snapshot.next_order_id)
	squads = restored_squads
	routes = restored_routes
	pending_orders = restored_pending
	accepted_orders = restored_accepted
	retreat_was_ordered = bool(snapshot.retreat_was_ordered)
	forced_retreat_requested = bool(snapshot.forced_retreat_requested)
	mission_objective_state = Dictionary(snapshot.mission_objective_state).duplicate(true)
	return true


func request_forced_retreat() -> bool:
	if completed or request == null:
		return false
	forced_retreat_requested = true
	retreat_was_ordered = true
	return true


func get_orders_digest() -> String:
	var parts: Array[String] = []
	for order in accepted_orders:
		parts.append(
			"%d:%d:%d:%d" % [
				order.order_id,
				order.squad_id,
				order.issued_tick,
				int(order.command),
			]
		)
	return "|".join(parts)


func get_state_digest() -> String:
	var parts: Array[String] = [str(current_tick)]
	for squad in squads:
		parts.append(
			"%d:%d:%d:%d:%d" % [
				int(squad.squad_id),
				int(squad.total_hp),
				int(squad.position_fixed),
				int(squad.active_order),
				1 if bool(squad.exited) else 0,
			]
		)
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = routes[route_id]
		parts.append(
			"%s:%d:%d" % [
				str(route_id),
				int(route.gate_hp),
				int(route.enemy_total_hp),
			]
		)
	if not mission_objective_state.is_empty():
		parts.append(str(mission_objective_state))
	if not wartime_facility_state.is_empty():
		parts.append(str(wartime_facility_state))
	parts.append(get_orders_digest())
	return "|".join(parts)


func _apply_wartime_facilities() -> void:
	var plan: Dictionary = request.wartime_facility_plan
	for facility_value in Array(plan.get("facilities", [])):
		if not facility_value is Dictionary:
			continue
		var facility: Dictionary = facility_value
		var kind := StringName(facility.get("kind", &""))
		var route_id := StringName(facility.get("route_id", &""))
		if kind == WartimeFacilityPlan.KIND_WATCH_PLATFORM:
			wartime_facility_state["enemy_observation_ready"] = true
			wartime_facility_state["watch_route_id"] = route_id
		elif kind == WartimeFacilityPlan.KIND_SIEGE_RAM and routes.has(route_id):
			var route: Dictionary = routes[route_id]
			var damage := mini(SIEGE_RAM_GATE_DAMAGE, int(route.gate_hp))
			route.gate_hp = int(route.gate_hp) - damage
			routes[route_id] = route
			wartime_facility_state["siege_ram_route_id"] = route_id
			wartime_facility_state["siege_ram_gate_damage"] = damage


func _orders_to_snapshot(orders: Array[BattleOrder]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order in orders:
		result.append({
			"order_id": order.order_id,
			"session_id": order.session_id,
			"squad_id": order.squad_id,
			"issued_tick": order.issued_tick,
			"command": int(order.command),
		})
	return result


func _orders_from_snapshot(records: Array):
	var result: Array[BattleOrder] = []
	var seen_ids: Dictionary = {}
	for record_value in records:
		if not record_value is Dictionary:
			return null
		var record: Dictionary = record_value
		if (
			record.size() != 5
			or typeof(record.get("order_id", null)) != TYPE_INT
			or int(record.order_id) <= 0
			or seen_ids.has(int(record.order_id))
			or typeof(record.get("session_id", null)) != TYPE_STRING_NAME
			or typeof(record.get("squad_id", null)) != TYPE_INT
			or int(record.squad_id) <= 0
			or typeof(record.get("issued_tick", null)) != TYPE_INT
			or int(record.issued_tick) < 0
			or typeof(record.get("command", null)) != TYPE_INT
			or int(record.command) not in [BattleOrder.Command.ADVANCE, BattleOrder.Command.HOLD, BattleOrder.Command.RETREAT]
		):
			return null
		seen_ids[int(record.order_id)] = true
		result.append(BattleOrder.new(
			int(record.order_id), StringName(record.session_id), int(record.squad_id),
			int(record.issued_tick), int(record.command) as BattleOrder.Command
		))
	return result


func _is_valid_snapshot(snapshot: Dictionary) -> bool:
	return (
		snapshot.size() == SNAPSHOT_KEYS.size()
		and _has_exact_snapshot_keys(snapshot)
		and typeof(snapshot.get("schema_version", null)) == TYPE_INT
		and int(snapshot.schema_version) == SNAPSHOT_SCHEMA_VERSION
		and typeof(snapshot.get("current_tick", null)) == TYPE_INT
		and int(snapshot.current_tick) >= 0
		and int(snapshot.current_tick) < MAX_BATTLE_TICKS
		and typeof(snapshot.get("next_order_id", null)) == TYPE_INT
		and int(snapshot.next_order_id) > 0
		and typeof(snapshot.get("squads", null)) == TYPE_ARRAY
		and typeof(snapshot.get("routes", null)) == TYPE_DICTIONARY
		and typeof(snapshot.get("pending_orders", null)) == TYPE_ARRAY
		and typeof(snapshot.get("accepted_orders", null)) == TYPE_ARRAY
		and typeof(snapshot.get("retreat_was_ordered", null)) == TYPE_BOOL
		and typeof(snapshot.get("forced_retreat_requested", null)) == TYPE_BOOL
		and typeof(snapshot.get("mission_objective_state", null)) == TYPE_DICTIONARY
	)


func _has_exact_snapshot_keys(snapshot: Dictionary) -> bool:
	for key in SNAPSHOT_KEYS:
		if not snapshot.has(key):
			return false
	return true


func _apply_orders_for_current_tick() -> void:
	var remaining: Array[BattleOrder] = []
	for order in pending_orders:
		if order.issued_tick + 1 == current_tick:
			for squad in squads:
				if int(squad.squad_id) == order.squad_id:
					squad.active_order = order.command
					break
		else:
			remaining.append(order)
	pending_orders = remaining


func _update_positions() -> void:
	var advance_per_tick := _positive_integer_divide(
		request.committed_force.move_speed_fixed,
		4
	)
	var retreat_per_tick := _positive_integer_divide(
		advance_per_tick * RETREAT_SPEED_NUMERATOR,
		RETREAT_SPEED_DENOMINATOR
	)
	for squad in squads:
		if int(squad.total_hp) <= 0 or bool(squad.exited):
			continue
		var command := int(squad.active_order) as BattleOrder.Command
		if command == BattleOrder.Command.ADVANCE:
			squad.position_fixed = mini(
				int(squad.position_fixed) + advance_per_tick,
				_get_route_distance_fixed(StringName(squad.route_id))
			)
		elif command == BattleOrder.Command.RETREAT:
			squad.position_fixed = maxi(
				int(squad.position_fixed) - retreat_per_tick,
				0
			)
			if int(squad.position_fixed) == 0:
				squad.exited = true
	_update_mission_search_progress()


func _build_damage_intents() -> Dictionary:
	var gate_damage := {
		CommittedForceSnapshot.FRONT_ROUTE: 0,
		CommittedForceSnapshot.SIDE_ROUTE: 0,
	}
	var enemy_damage := {
		CommittedForceSnapshot.FRONT_ROUTE: 0,
		CommittedForceSnapshot.SIDE_ROUTE: 0,
	}
	var player_damage: Dictionary = {}
	if current_tick % ATTACK_INTERVAL_TICKS != 0:
		return {
			"gate_damage": gate_damage,
			"enemy_damage": enemy_damage,
			"player_damage": player_damage,
		}

	for squad in squads:
		if not _squad_can_fight(squad):
			continue
		var route_id := StringName(squad.route_id)
		if int(squad.position_fixed) < _get_route_distance_fixed(route_id):
			continue
		var route: Dictionary = routes[route_id]
		var command := int(squad.active_order) as BattleOrder.Command
		var order_basis_points := (
			HOLD_ATTACK_BASIS_POINTS
			if command == BattleOrder.Command.HOLD
			else BASIS_POINTS
		)
		var damage := _calculate_player_damage(
			_alive_members(int(squad.total_hp)),
			order_basis_points
		)
		if int(route.gate_hp) > 0:
			gate_damage[route_id] = int(gate_damage[route_id]) + damage
		elif int(route.enemy_total_hp) > 0:
			enemy_damage[route_id] = int(enemy_damage[route_id]) + damage

	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = routes[route_id]
		if int(route.enemy_total_hp) <= 0:
			continue
		var target := _get_enemy_target(route_id)
		if target.is_empty():
			continue
		var incoming_basis_points := _get_incoming_basis_points(
			int(target.active_order) as BattleOrder.Command
		)
		var damage := _calculate_enemy_damage(
			_alive_members(int(route.enemy_total_hp)),
			incoming_basis_points
		)
		player_damage[int(target.squad_id)] = damage
	return {
		"gate_damage": gate_damage,
		"enemy_damage": enemy_damage,
		"player_damage": player_damage,
	}


func _apply_damage_intents(intents: Dictionary) -> void:
	var gate_damage: Dictionary = intents.gate_damage
	var enemy_damage: Dictionary = intents.enemy_damage
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = routes[route_id]
		route.gate_hp = maxi(
			int(route.gate_hp) - int(gate_damage[route_id]),
			0
		)
		route.enemy_total_hp = maxi(
			int(route.enemy_total_hp) - int(enemy_damage[route_id]),
			0
		)
	var player_damage: Dictionary = intents.player_damage
	for squad in squads:
		var squad_id := int(squad.squad_id)
		if player_damage.has(squad_id):
			squad.total_hp = maxi(
				int(squad.total_hp) - int(player_damage[squad_id]),
				0
			)
	_apply_mission_objective_damage()


func _check_outcome() -> void:
	if mission_definition != null:
		_check_mission_outcome()
		return
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = routes[route_id]
		if (
			int(route.gate_hp) == 0
			and int(route.enemy_total_hp) == 0
			and _has_surviving_squad_on_route(route_id)
		):
			_complete(BattleOutcome.Value.VICTORY, route_id)
			return
	if _get_survivor_count() == 0:
		_complete(BattleOutcome.Value.DEFEAT)
		return
	if retreat_was_ordered and _all_survivors_exited():
		_complete(BattleOutcome.Value.RETREAT)
		return
	if current_tick >= MAX_BATTLE_TICKS:
		_complete(BattleOutcome.Value.DEFEAT)


func _complete(
	outcome: BattleOutcome.Value,
	breached_route: StringName = &""
) -> void:
	var survivors := _get_survivor_count()
	var enemy_survivors := 0
	for route_id in routes:
		enemy_survivors += _alive_members(
			int(routes[route_id].enemy_total_hp)
		)
	var terminal_result := BattleResult.new()
	terminal_result.result_id = StringName("%s-result-001" % request.transaction_id)
	terminal_result.transaction_id = request.transaction_id
	terminal_result.session_id = session_id
	terminal_result.level_id = request.level_id
	terminal_result.outcome = outcome
	terminal_result.started_day = request.created_day
	terminal_result.finished_tick = current_tick
	terminal_result.committed_count = request.committed_force.get_committed_total()
	terminal_result.survivor_count = survivors
	terminal_result.casualty_count = terminal_result.committed_count - survivors
	terminal_result.enemy_casualties = (
		request.enemy_force.enemy_count - enemy_survivors
	)
	terminal_result.breached_route = breached_route
	terminal_result.orders_digest = get_orders_digest()
	terminal_result.player_snapshot_digest = (
		request.committed_force.get_digest()
	)
	terminal_result.enemy_snapshot_digest = request.enemy_force.get_digest()
	terminal_result.first_clear_key = request.first_clear_key
	for squad in squads:
		var formation_survivors := _alive_members(int(squad.total_hp))
		terminal_result.formation_results.append({
			"formation_id": StringName(squad.formation_id),
			"squad_id": int(squad.squad_id),
			"departure_count": int(squad.initial_members),
			"survivor_count": formation_survivors,
			"casualty_count": int(squad.initial_members) - formation_survivors,
		})
	_terminal_authority_record = {
		"result": terminal_result.get_authority_snapshot().duplicate(true),
		"completion": {
			"session_id": session_id,
			"state_digest": get_state_digest(),
			"route_ids": routes.keys().duplicate(),
		},
	}.duplicate(true)
	completed = true
	result = BattleResult.from_authority_snapshot(
		get_terminal_result_snapshot()
	)
	terminal_completed.emit(result, get_terminal_authority_record())


func get_terminal_authority_record() -> Dictionary:
	return _terminal_authority_record.duplicate(true)


func get_terminal_result_snapshot() -> Dictionary:
	var result_snapshot: Dictionary = _terminal_authority_record.get("result", {})
	return result_snapshot.duplicate(true)


func _initialize_mission_objective_state() -> void:
	if mission_definition == null:
		return
	mission_objective_state = {
		"objective_type": mission_definition.objective_type,
		"remaining_enemy_count": request.enemy_force.enemy_count,
		"protect_target_name": mission_definition.protect_target_name,
		"protect_target_hp": mission_definition.protect_target_hp,
		"protect_target_max_hp": mission_definition.protect_target_hp,
		"scout_found": false,
		"extraction_reached": false,
	}


func _update_mission_search_progress() -> void:
	if (
		mission_definition == null
		or mission_definition.objective_type
			!= MissionDefinition.OBJECTIVE_SCOUT
		or bool(mission_objective_state.get("scout_found", false))
	):
		return
	var search_distance := (
		mission_definition.scout_search_distance_units * DISTANCE_SCALE
	)
	for squad in squads:
		if (
			int(squad.total_hp) > 0
			and not bool(squad.exited)
			and StringName(squad.route_id)
				== mission_definition.scout_route_id
			and int(squad.position_fixed) >= search_distance
		):
			mission_objective_state.scout_found = true
			return


func _apply_mission_objective_damage() -> void:
	if mission_definition == null:
		return
	mission_objective_state.remaining_enemy_count = (
		_get_enemy_survivor_count()
	)
	if (
		mission_definition.objective_type
			!= MissionDefinition.OBJECTIVE_PROTECT
		or current_tick % ATTACK_INTERVAL_TICKS != 0
	):
		return
	var damage := 0
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = routes[route_id]
		if (
			int(route.enemy_total_hp) > 0
			and not _has_frontline_squad(route_id)
		):
			damage += (
				_alive_members(int(route.enemy_total_hp))
				* mission_definition.protect_damage_per_enemy
			)
	mission_objective_state.protect_target_hp = maxi(
		int(mission_objective_state.protect_target_hp) - damage,
		0
	)


func _check_mission_outcome() -> void:
	mission_objective_state.remaining_enemy_count = (
		_get_enemy_survivor_count()
	)
	if (
		mission_definition.objective_type
			== MissionDefinition.OBJECTIVE_PROTECT
		and int(mission_objective_state.protect_target_hp) <= 0
	):
		_complete(BattleOutcome.Value.DEFEAT)
		return
	if _get_survivor_count() == 0:
		_complete(BattleOutcome.Value.DEFEAT)
		return
	if forced_retreat_requested and _all_survivors_exited():
		_complete(BattleOutcome.Value.RETREAT)
		return
	if (
		mission_definition.objective_type
			== MissionDefinition.OBJECTIVE_ELIMINATE
		and _get_enemy_survivor_count() == 0
	):
		_complete(BattleOutcome.Value.VICTORY)
		return
	if (
		mission_definition.objective_type
			== MissionDefinition.OBJECTIVE_PROTECT
		and _get_enemy_survivor_count() == 0
		and int(mission_objective_state.protect_target_hp) > 0
	):
		_complete(BattleOutcome.Value.VICTORY)
		return
	if (
		mission_definition.objective_type
			== MissionDefinition.OBJECTIVE_SCOUT
		and bool(mission_objective_state.scout_found)
		and _has_surviving_exited_squad()
	):
		mission_objective_state.extraction_reached = true
		_complete(BattleOutcome.Value.VICTORY)
		return
	if retreat_was_ordered and _all_survivors_exited():
		_complete(BattleOutcome.Value.RETREAT)
		return
	if current_tick >= MAX_BATTLE_TICKS:
		_complete(BattleOutcome.Value.DEFEAT)


func _has_frontline_squad(route_id: StringName) -> bool:
	for squad in squads:
		if (
			_squad_can_fight(squad)
			and StringName(squad.route_id) == route_id
			and int(squad.position_fixed)
				>= _get_route_distance_fixed(route_id)
		):
			return true
	return false


func _has_surviving_exited_squad() -> bool:
	for squad in squads:
		if int(squad.total_hp) > 0 and bool(squad.exited):
			return true
	return false


func _get_enemy_survivor_count() -> int:
	var survivors := 0
	for route_id in routes:
		survivors += _alive_members(
			int(routes[route_id].enemy_total_hp)
		)
	return survivors


func _calculate_player_damage(
	alive_members: int,
	order_basis_points: int
) -> int:
	var numerator := (
		alive_members
		* request.committed_force.attack_per_member
		* request.committed_force.attack_basis_points
		* order_basis_points
		* request.committed_force.supply_basis_points
	)
	var denominator := BASIS_POINTS * BASIS_POINTS * BASIS_POINTS
	return maxi(_positive_integer_divide(numerator, denominator), 1)


func _calculate_enemy_damage(
	alive_members: int,
	incoming_basis_points: int
) -> int:
	var numerator := (
		alive_members
		* request.committed_force.attack_per_member
		* incoming_basis_points
	)
	return maxi(
		_positive_integer_divide(
			numerator,
			request.committed_force.defense_basis_points
		),
		1
	)


func _get_enemy_target(route_id: StringName) -> Dictionary:
	for squad in squads:
		if (
			_squad_can_fight(squad)
			and StringName(squad.route_id) == route_id
			and int(squad.position_fixed) >= _get_route_distance_fixed(route_id)
		):
			return squad
	return {}


func _has_commandable_squad(squad_id: int) -> bool:
	for squad in squads:
		if (
			int(squad.squad_id) == squad_id
			and int(squad.total_hp) > 0
			and not bool(squad.exited)
		):
			return true
	return false


func _squad_can_fight(squad: Dictionary) -> bool:
	return (
		int(squad.total_hp) > 0
		and not bool(squad.exited)
		and int(squad.active_order) != BattleOrder.Command.RETREAT
	)


func _has_surviving_squad_on_route(route_id: StringName) -> bool:
	for squad in squads:
		if (
			StringName(squad.route_id) == route_id
			and int(squad.total_hp) > 0
			and not bool(squad.exited)
		):
			return true
	return false


func _get_survivor_count() -> int:
	var survivors := 0
	for squad in squads:
		survivors += _alive_members(int(squad.total_hp))
	return survivors


func _all_survivors_exited() -> bool:
	for squad in squads:
		if int(squad.total_hp) > 0 and not bool(squad.exited):
			return false
	return true


func _alive_members(total_hp: int) -> int:
	if total_hp <= 0:
		return 0
	return _positive_integer_divide(
		total_hp + request.committed_force.hp_per_member - 1,
		request.committed_force.hp_per_member
	)


func _get_route_distance_fixed(route_id: StringName) -> int:
	return int(routes[route_id].distance_fixed)


func _get_initial_route_distance_fixed(route_id: StringName) -> int:
	if mission_definition == null:
		return (
			FRONT_DISTANCE_FIXED
			if route_id == CommittedForceSnapshot.FRONT_ROUTE
			else SIDE_DISTANCE_FIXED
		)
	return (
		mission_definition.front_distance_units
		if route_id == CommittedForceSnapshot.FRONT_ROUTE
		else mission_definition.side_distance_units
	) * DISTANCE_SCALE


func _get_incoming_basis_points(
	command: BattleOrder.Command
) -> int:
	if command == BattleOrder.Command.HOLD:
		return HOLD_INCOMING_BASIS_POINTS
	if command == BattleOrder.Command.RETREAT:
		return RETREAT_INCOMING_BASIS_POINTS
	return BASIS_POINTS


func _positive_integer_divide(numerator: int, denominator: int) -> int:
	if numerator <= 0 or denominator <= 0:
		return 0
	@warning_ignore("integer_division")
	return numerator / denominator
