class_name BattleSession
extends RefCounted


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

var request: BattleRequest
var session_id: StringName
var current_tick := 0
var next_order_id := 1
var squads: Array[Dictionary] = []
var routes: Dictionary = {}
var pending_orders: Array[BattleOrder] = []
var accepted_orders: Array[BattleOrder] = []
var retreat_was_ordered := false
var completed := false
var result: BattleResult


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
	completed = false
	result = null
	for squad_snapshot in request.committed_force.squads:
		var initial_members := int(squad_snapshot.initial_members)
		squads.append({
			"squad_id": int(squad_snapshot.squad_id),
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
		}
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
	parts.append(get_orders_digest())
	return "|".join(parts)


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


func _check_outcome() -> void:
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
	completed = true
	var survivors := _get_survivor_count()
	var enemy_survivors := 0
	for route_id in routes:
		enemy_survivors += _alive_members(
			int(routes[route_id].enemy_total_hp)
		)
	result = BattleResult.new()
	result.result_id = StringName("%s-result-001" % request.transaction_id)
	result.transaction_id = request.transaction_id
	result.session_id = session_id
	result.level_id = request.level_id
	result.outcome = outcome
	result.started_day = request.created_day
	result.finished_tick = current_tick
	result.committed_count = request.committed_force.get_committed_total()
	result.survivor_count = survivors
	result.casualty_count = result.committed_count - survivors
	result.enemy_casualties = (
		request.enemy_force.enemy_count - enemy_survivors
	)
	result.breached_route = breached_route
	result.orders_digest = get_orders_digest()
	result.player_snapshot_digest = (
		request.committed_force.get_digest()
	)
	result.enemy_snapshot_digest = request.enemy_force.get_digest()
	result.first_clear_key = FIRST_CLEAR_KEY


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
	return (
		FRONT_DISTANCE_FIXED
		if route_id == CommittedForceSnapshot.FRONT_ROUTE
		else SIDE_DISTANCE_FIXED
	)


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
