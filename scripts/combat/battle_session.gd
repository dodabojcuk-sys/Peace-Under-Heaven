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
## Each battle route is the defended gate approach.  Arrow towers therefore
## contribute to that route's ordinary enemy-damage intent, never a UI-only
## counter or a second casualty authority.
const ARROW_TOWER_DAMAGE_PER_VOLLEY := 24
const ARROW_TOWER_ATTACK_INTERVAL_TICKS := 4
## Barricades reduce the ordinary route damage intent before the shared squad
## HP writer applies it; they never introduce a parallel casualty system.
const BARRICADE_INCOMING_DAMAGE_BASIS_POINTS := 6500
## A completed barricade also delays invaders on its own defense route. The
## effect weakens with the same persisted durability that governs protection.
const BARRICADE_ENEMY_ADVANCE_BASIS_POINTS := 7500
const FACILITY_PHASE_CONSTRUCTING := &"CONSTRUCTING"
const FACILITY_PHASE_ACTIVE := &"ACTIVE"
const FACILITY_PHASE_DAMAGED := &"DAMAGED"
const FACILITY_PHASE_DESTROYED := &"DESTROYED"
const FACILITY_PHASE_REPAIRING := &"REPAIRING"
const FACILITY_BUILD_TICKS := {
	WartimeFacilityPlan.KIND_WATCH_PLATFORM: 2,
	WartimeFacilityPlan.KIND_SIEGE_RAM: 4,
	WartimeFacilityPlan.KIND_ARROW_TOWER: 4,
	WartimeFacilityPlan.KIND_BARRICADE: 3,
}
const FACILITY_MAX_DURABILITY := {
	WartimeFacilityPlan.KIND_WATCH_PLATFORM: 100,
	WartimeFacilityPlan.KIND_SIEGE_RAM: 140,
	WartimeFacilityPlan.KIND_ARROW_TOWER: 120,
	WartimeFacilityPlan.KIND_BARRICADE: 180,
}
const FACILITY_REPAIR_TICKS := 2
## City-gate repair is a temporary, battle-local construction action.  It
## restores the mission target only after its own saved work ticks complete;
## settlement damage is still written once, when this battle resolves.
const PROTECT_TARGET_REPAIR_WOOD_COST := 4
const PROTECT_TARGET_REPAIR_TICKS := 2
const PROTECT_TARGET_REPAIR_HP := 120
const PROTECT_TARGET_REPAIR_IDLE := &"IDLE"
const PROTECT_TARGET_REPAIRING := &"REPAIRING"
const SNAPSHOT_SCHEMA_VERSION := 5
const SNAPSHOT_KEYS := [
	"schema_version", "current_tick", "next_order_id", "squads", "routes",
	"pending_orders", "accepted_orders", "retreat_was_ordered",
	"forced_retreat_requested", "mission_objective_state", "wartime_facility_state",
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
## Presentation-only facts for the most recently committed simulation tick.
## They are intentionally not saved: route HP is the durable authority, and a
## restored battle must not replay a historical volley as a fresh event.
var last_tick_facility_events: Array[Dictionary] = []


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
	last_tick_facility_events.clear()
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
			## Protection missions advance invaders through this same authoritative
			## route before they may harm the protected target. Assault sessions keep
			## the field at zero and retain their existing gate interaction.
			"enemy_position_fixed": 0,
		}
	_initialize_wartime_facilities()
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
	last_tick_facility_events.clear()
	current_tick += 1
	_apply_orders_for_current_tick()
	_update_positions()
	_advance_mission_enemy_positions()
	_advance_wartime_facilities()
	_advance_protect_target_repair()
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
	var projection := wartime_facility_state.duplicate(true)
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		var phase := StringName(record.get("phase", &""))
		var kind := StringName(record.get("kind", &""))
		var route_id := StringName(record.get("route_id", &""))
		## A damaged barricade remains a route fact because its surviving
		## durability still mitigates a proportional share of the next hit.
		## Other facilities only project their effects once fully active.
		if kind == WartimeFacilityPlan.KIND_BARRICADE:
			if phase not in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]:
				continue
			projection["barricade_route_id"] = route_id
			projection["barricade_incoming_damage_basis_points"] = (
				_get_barricade_incoming_damage_basis_points(record)
			)
			projection["barricade_enemy_advance_basis_points"] = (
				_get_barricade_durability_basis_points(
					record,
					BARRICADE_ENEMY_ADVANCE_BASIS_POINTS
				)
			)
			continue
		if kind == WartimeFacilityPlan.KIND_ARROW_TOWER:
			if phase not in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]:
				continue
			projection["arrow_tower_route_id"] = route_id
			projection["arrow_tower_damage_per_volley"] = (
				_get_arrow_tower_volley_damage(record)
			)
			projection["arrow_tower_attack_interval_ticks"] = ARROW_TOWER_ATTACK_INTERVAL_TICKS
			continue
		if phase != FACILITY_PHASE_ACTIVE:
			continue
		if kind == WartimeFacilityPlan.KIND_WATCH_PLATFORM:
			projection["enemy_observation_ready"] = true
			projection["watch_route_id"] = route_id
		elif kind == WartimeFacilityPlan.KIND_SIEGE_RAM:
			projection["siege_ram_route_id"] = route_id
	return projection


func get_last_tick_facility_events() -> Array[Dictionary]:
	return last_tick_facility_events.duplicate(true)


## A macro siege may arrive with partial HP even though its formation roster is
## still expressed in whole members. Distribute that already-authoritative HP
## over the stable squad order before the first C0 tick; later restores use the
## ordinary live-session snapshot and therefore do not recalculate it.
func apply_macro_siege_start_state(start_state: Dictionary) -> bool:
	if request == null or completed:
		return false
	if (
		typeof(start_state.get("attacker_total_hp", null)) != TYPE_INT
		or typeof(start_state.get("defender_total_hp", null)) != TYPE_INT
		or typeof(start_state.get("gate_hp", null)) != TYPE_INT
		or int(start_state.attacker_total_hp) < 0
		or int(start_state.defender_total_hp) < 0
		or int(start_state.gate_hp) < 0
	):
		return false
	var remaining_attacker := int(start_state.attacker_total_hp)
	for index in squads.size():
		var squad: Dictionary = squads[index]
		var capacity := int(squad.initial_members) * request.committed_force.hp_per_member
		var assigned := mini(capacity, remaining_attacker)
		squad.total_hp = assigned
		squads[index] = squad
		remaining_attacker -= assigned
	if remaining_attacker != 0:
		return false
	var front: Dictionary = Dictionary(routes.get(CommittedForceSnapshot.FRONT_ROUTE, {}))
	if front.is_empty() or int(start_state.gate_hp) > int(front.gate_initial_hp):
		return false
	front.enemy_total_hp = int(start_state.defender_total_hp)
	front.gate_hp = int(start_state.gate_hp)
	routes[CommittedForceSnapshot.FRONT_ROUTE] = front
	return true


## The terminal macro state is separate from rounded member casualties.  It is
## committed beside the terminal result so a retreat preserves partial squad,
## defender and gate damage instead of reconstructing them from head counts.
func get_macro_siege_terminal_state() -> Dictionary:
	if request == null:
		return {}
	var attacker_total_hp := 0
	for squad_value in squads:
		if not squad_value is Dictionary:
			return {}
		var squad: Dictionary = squad_value
		var total_hp = squad.get("total_hp", null)
		if typeof(total_hp) != TYPE_INT or int(total_hp) < 0:
			return {}
		attacker_total_hp += int(total_hp)
	var front: Dictionary = Dictionary(routes.get(CommittedForceSnapshot.FRONT_ROUTE, {}))
	if front.is_empty():
		return {}
	var defender_total_hp = front.get("enemy_total_hp", null)
	var gate_hp = front.get("gate_hp", null)
	if (
		typeof(defender_total_hp) != TYPE_INT or int(defender_total_hp) < 0
		or typeof(gate_hp) != TYPE_INT or int(gate_hp) < 0
	):
		return {}
	return {
		"attacker_total_hp": attacker_total_hp,
		"defender_total_hp": int(defender_total_hp),
		"gate_hp": int(gate_hp),
	}


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
		"wartime_facility_state": wartime_facility_state.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if request == null or request.phase != BattleRequest.PHASE_ACTIVE:
		return false
	if not _is_valid_snapshot(snapshot):
		return false
	var source_schema_version := int(snapshot.schema_version)
	var normalized_snapshot := snapshot.duplicate(true)
	if source_schema_version <= 3:
		## Older sessions had no invader position because protection targets were
		## damaged immediately. They cannot truthfully recover lost approach
		## progress, so restore them at their recorded route origin rather than
		## granting a hit on the protected target.
		for route_id in [CommittedForceSnapshot.FRONT_ROUTE, CommittedForceSnapshot.SIDE_ROUTE]:
			var legacy_route: Dictionary = Dictionary(normalized_snapshot.routes.get(route_id, {}))
			legacy_route.enemy_position_fixed = 0
			normalized_snapshot.routes[route_id] = legacy_route
		normalized_snapshot.schema_version = SNAPSHOT_SCHEMA_VERSION
	if source_schema_version < SNAPSHOT_SCHEMA_VERSION:
		## Pre-v5 sessions predate a repair-in-progress state.  Preserve their
		## recorded target HP exactly and upgrade them to the only truthful
		## compatible state: no repair was pending at the moment of the save.
		normalized_snapshot.mission_objective_state["protect_target_repair_phase"] = PROTECT_TARGET_REPAIR_IDLE
		normalized_snapshot.mission_objective_state["protect_target_repair_progress_ticks"] = 0
		normalized_snapshot.mission_objective_state["protect_target_repair_required_ticks"] = 0
		normalized_snapshot.mission_objective_state["protect_target_repair_amount"] = 0
		normalized_snapshot.schema_version = SNAPSHOT_SCHEMA_VERSION
	var restored_squads: Array[Dictionary] = []
	var expected_squads: Dictionary = {}
	for original in squads:
		expected_squads[int(original.squad_id)] = original
	var restored_squad_ids: Dictionary = {}
	for squad_value in Array(normalized_snapshot.squads):
		if not squad_value is Dictionary:
			return false
		var squad: Dictionary = squad_value
		if typeof(squad.get("squad_id", null)) != TYPE_INT:
			return false
		var squad_id := int(squad.get("squad_id", 0))
		var original: Dictionary = expected_squads.get(squad_id, {})
		if (
			original.is_empty()
			or restored_squad_ids.has(squad_id)
			or not _has_matching_snapshot_value_types(squad, original)
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
		restored_squad_ids[squad_id] = true
		restored_squads.append(squad.duplicate(true))
	if restored_squads.size() != squads.size():
		return false
	var restored_routes: Dictionary = Dictionary(normalized_snapshot.routes).duplicate(true)
	for route_id in [CommittedForceSnapshot.FRONT_ROUTE, CommittedForceSnapshot.SIDE_ROUTE]:
		var original_route: Dictionary = routes.get(route_id, {})
		var restored_route: Dictionary = restored_routes.get(route_id, {})
		if (
			original_route.is_empty()
			or restored_route.is_empty()
			or not _has_matching_snapshot_value_types(restored_route, original_route)
			or int(restored_route.get("enemy_initial_members", -1)) != int(original_route.enemy_initial_members)
			or int(restored_route.get("gate_initial_hp", -1)) != int(original_route.gate_initial_hp)
			or int(restored_route.get("distance_fixed", -1)) != int(original_route.distance_fixed)
			or int(restored_route.get("enemy_total_hp", -1)) < 0
			or int(restored_route.get("enemy_position_fixed", -1)) < 0
			or int(restored_route.get("enemy_position_fixed", 0)) > int(original_route.distance_fixed)
			or int(restored_route.get("gate_hp", -1)) < 0
			or int(restored_route.get("gate_hp", 0)) > int(original_route.gate_initial_hp)
		):
			return false
	var restored_pending: Variant = _orders_from_snapshot(Array(normalized_snapshot.pending_orders))
	var restored_accepted: Variant = _orders_from_snapshot(Array(normalized_snapshot.accepted_orders))
	if restored_pending == null or restored_accepted == null:
		return false
	var valid_squad_ids: Dictionary = {}
	for squad in restored_squads:
		valid_squad_ids[int(squad.squad_id)] = true
	var accepted_orders_by_id: Dictionary = {}
	var highest_order_id := 0
	for order in restored_accepted:
		if (
			order.session_id != session_id
			or not valid_squad_ids.has(order.squad_id)
			or order.issued_tick > int(normalized_snapshot.current_tick)
		):
			return false
		accepted_orders_by_id[order.order_id] = order
		highest_order_id = maxi(highest_order_id, order.order_id)
	for order in restored_pending:
		if (
			not accepted_orders_by_id.has(order.order_id)
			or order.session_id != session_id
			or not valid_squad_ids.has(order.squad_id)
			or not _orders_match(order, accepted_orders_by_id[order.order_id])
		):
			return false
	if int(normalized_snapshot.next_order_id) <= highest_order_id:
		return false
	current_tick = int(normalized_snapshot.current_tick)
	next_order_id = int(normalized_snapshot.next_order_id)
	squads = restored_squads
	routes = restored_routes
	pending_orders = restored_pending
	accepted_orders = restored_accepted
	retreat_was_ordered = bool(normalized_snapshot.retreat_was_ordered)
	forced_retreat_requested = bool(normalized_snapshot.forced_retreat_requested)
	mission_objective_state = Dictionary(normalized_snapshot.mission_objective_state).duplicate(true)
	if source_schema_version == 1:
		# Version-one sessions applied their confirmed plan at tick zero. Preserve
		# that already-paid historical effect instead of starting a second build.
		_initialize_wartime_facilities(true)
	else:
		wartime_facility_state = Dictionary(normalized_snapshot.wartime_facility_state).duplicate(true)
		if source_schema_version == 2:
			for index in Array(wartime_facility_state.get("facilities", [])).size():
				var legacy_record: Dictionary = Dictionary(wartime_facility_state.facilities[index])
				var maximum := int(FACILITY_MAX_DURABILITY.get(StringName(legacy_record.get("kind", &"")), 0))
				legacy_record.max_durability = maximum
				legacy_record.durability = maximum
				wartime_facility_state.facilities[index] = legacy_record
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


func _initialize_wartime_facilities(legacy_active := false) -> void:
	wartime_facility_state = {"facilities": []}
	var plan: Dictionary = request.wartime_facility_plan
	for facility_value in Array(plan.get("facilities", [])):
		if not facility_value is Dictionary:
			continue
		var facility: Dictionary = facility_value
		var kind := StringName(facility.get("kind", &""))
		var route_id := StringName(facility.get("route_id", &""))
		var record := {
			"facility_id": StringName(facility.get("facility_id", &"")),
			"kind": kind,
			"route_id": route_id,
			"phase": FACILITY_PHASE_ACTIVE if legacy_active else FACILITY_PHASE_CONSTRUCTING,
			"progress_ticks": int(FACILITY_BUILD_TICKS.get(kind, 0)) if legacy_active else 0,
			"required_ticks": int(FACILITY_BUILD_TICKS.get(kind, 0)),
			"max_durability": int(FACILITY_MAX_DURABILITY.get(kind, 0)),
			"durability": int(FACILITY_MAX_DURABILITY.get(kind, 0)),
		}
		Array(wartime_facility_state.facilities).append(record)


func _advance_wartime_facilities() -> void:
	var facilities: Array = Array(wartime_facility_state.get("facilities", [])).duplicate(true)
	for index in facilities.size():
		var record: Dictionary = Dictionary(facilities[index])
		var phase := StringName(record.get("phase", &""))
		if phase in [FACILITY_PHASE_CONSTRUCTING, FACILITY_PHASE_REPAIRING]:
			record.progress_ticks = mini(
				int(record.get("progress_ticks", 0)) + 1,
				int(record.get("required_ticks", 0))
			)
			if int(record.progress_ticks) >= int(record.required_ticks):
				record.phase = FACILITY_PHASE_ACTIVE
				if phase == FACILITY_PHASE_REPAIRING:
					record.required_ticks = int(FACILITY_BUILD_TICKS.get(StringName(record.get("kind", &"")), 0))
					record.progress_ticks = int(record.required_ticks)
				record.durability = int(record.get("max_durability", 0))
				_apply_completed_wartime_facility(record, phase == FACILITY_PHASE_CONSTRUCTING)
				if phase == FACILITY_PHASE_REPAIRING:
					last_tick_facility_events.append({
						"kind": record.kind, "route_id": record.route_id,
						"event": &"REPAIR_COMPLETED", "tick": current_tick,
					})
		facilities[index] = record
	wartime_facility_state.facilities = facilities


func _apply_completed_wartime_facility(record: Dictionary, emit_event: bool) -> void:
	var kind := StringName(record.get("kind", &""))
	var route_id := StringName(record.get("route_id", &""))
	if kind == WartimeFacilityPlan.KIND_WATCH_PLATFORM:
		pass
	elif kind == WartimeFacilityPlan.KIND_SIEGE_RAM and routes.has(route_id):
		var route: Dictionary = routes[route_id]
		var damage := mini(SIEGE_RAM_GATE_DAMAGE, int(route.gate_hp))
		route.gate_hp = int(route.gate_hp) - damage
		routes[route_id] = route
		if emit_event:
			last_tick_facility_events.append({
				"kind": kind, "route_id": route_id, "event": &"GATE_DAMAGED", "damage": damage, "tick": current_tick,
			})
	elif kind == WartimeFacilityPlan.KIND_ARROW_TOWER and routes.has(route_id):
		pass
	if emit_event:
		last_tick_facility_events.append({
			"kind": kind,
			"route_id": route_id,
			"event": &"CONSTRUCTION_COMPLETED",
			"tick": current_tick,
		})


func begin_wartime_facility_repair(facility_id: StringName) -> bool:
	if completed or facility_id == &"":
		return false
	var facilities: Array = Array(wartime_facility_state.get("facilities", [])).duplicate(true)
	for index in facilities.size():
		var record: Dictionary = Dictionary(facilities[index])
		if StringName(record.get("facility_id", &"")) != facility_id:
			continue
		if StringName(record.get("phase", &"")) not in [FACILITY_PHASE_DAMAGED, FACILITY_PHASE_DESTROYED]:
			return false
		record.phase = FACILITY_PHASE_REPAIRING
		record.progress_ticks = 0
		record.required_ticks = FACILITY_REPAIR_TICKS
		facilities[index] = record
		wartime_facility_state.facilities = facilities
		last_tick_facility_events.append({
			"kind": record.kind, "route_id": record.route_id,
			"event": &"REPAIR_STARTED", "tick": current_tick,
		})
		return true
	return false


func can_begin_protect_target_repair() -> bool:
	return (
		not completed
		and mission_definition != null
		and mission_definition.objective_type == MissionDefinition.OBJECTIVE_PROTECT
		and StringName(mission_objective_state.get("protect_target_repair_phase", &""))
			== PROTECT_TARGET_REPAIR_IDLE
		and int(mission_objective_state.get("protect_target_hp", 0)) > 0
		and int(mission_objective_state.get("protect_target_hp", 0))
			< int(mission_objective_state.get("protect_target_max_hp", 0))
	)


func begin_protect_target_repair() -> bool:
	if not can_begin_protect_target_repair():
		return false
	var missing_hp := (
		int(mission_objective_state.protect_target_max_hp)
		- int(mission_objective_state.protect_target_hp)
	)
	mission_objective_state["protect_target_repair_phase"] = PROTECT_TARGET_REPAIRING
	mission_objective_state["protect_target_repair_progress_ticks"] = 0
	mission_objective_state["protect_target_repair_required_ticks"] = PROTECT_TARGET_REPAIR_TICKS
	mission_objective_state["protect_target_repair_amount"] = mini(
		PROTECT_TARGET_REPAIR_HP,
		missing_hp
	)
	last_tick_facility_events.append({
		"kind": &"GATE", "route_id": &"",
		"event": &"GATE_REPAIR_STARTED", "tick": current_tick,
	})
	return true


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


func _orders_match(left: BattleOrder, right: BattleOrder) -> bool:
	return (
		left.order_id == right.order_id
		and left.session_id == right.session_id
		and left.squad_id == right.squad_id
		and left.issued_tick == right.issued_tick
		and left.command == right.command
	)


## Snapshot dictionaries are untrusted external input. Validate their exact
## fields and runtime types before numeric/string conversion so malformed data
## cannot be coerced into a superficially valid authoritative battle state.
func _has_matching_snapshot_value_types(value: Dictionary, expected: Dictionary) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key) or typeof(value[key]) != typeof(expected[key]):
			return false
	return true


func _is_valid_snapshot(snapshot: Dictionary) -> bool:
	var schema_version = snapshot.get("schema_version", null)
	if typeof(schema_version) != TYPE_INT or int(schema_version) not in [1, 2, 3, 4, SNAPSHOT_SCHEMA_VERSION]:
		return false
	var expected_keys: Array = SNAPSHOT_KEYS.duplicate()
	if int(schema_version) == 1:
		expected_keys.erase("wartime_facility_state")
	return (
		snapshot.size() == expected_keys.size()
		and _has_exact_snapshot_keys(snapshot, expected_keys)
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
		and (
			(
				_has_valid_legacy_mission_objective_state(
					Dictionary(snapshot.get("mission_objective_state", {}))
				)
				## Test and migration tooling may rewrite only the outer schema tag
				## while retaining an otherwise valid contemporary target state.
				## Accept that representation, then normalize its repair state below;
				## actual historical records still use the narrower legacy shape.
				or _has_valid_mission_objective_state(
					Dictionary(snapshot.get("mission_objective_state", {}))
				)
			)
			if int(schema_version) < SNAPSHOT_SCHEMA_VERSION
			else _has_valid_mission_objective_state(
				Dictionary(snapshot.get("mission_objective_state", {}))
			)
		)
		and (
			int(schema_version) == 1
			or (
				int(schema_version) == 2
				and _has_valid_legacy_wartime_facility_state(Dictionary(snapshot.get("wartime_facility_state", {})))
			)
			or _has_valid_wartime_facility_state(Dictionary(snapshot.get("wartime_facility_state", {})))
		)
	)


func _has_valid_legacy_mission_objective_state(state: Dictionary) -> bool:
	if mission_definition == null:
		return state.is_empty()
	var expected := _get_base_mission_objective_state()
	return _has_valid_mission_objective_state_fields(state, expected)


func _has_valid_mission_objective_state(state: Dictionary) -> bool:
	if mission_definition == null:
		return state.is_empty()
	var expected := _get_base_mission_objective_state()
	expected["protect_target_repair_phase"] = PROTECT_TARGET_REPAIR_IDLE
	expected["protect_target_repair_progress_ticks"] = 0
	expected["protect_target_repair_required_ticks"] = 0
	expected["protect_target_repair_amount"] = 0
	if not _has_valid_mission_objective_state_fields(state, expected):
		return false
	var repair_phase := StringName(state.get("protect_target_repair_phase", &""))
	var progress := int(state.get("protect_target_repair_progress_ticks", -1))
	var required := int(state.get("protect_target_repair_required_ticks", -1))
	var amount := int(state.get("protect_target_repair_amount", -1))
	if repair_phase == PROTECT_TARGET_REPAIR_IDLE:
		return progress == 0 and required == 0 and amount == 0
	if repair_phase != PROTECT_TARGET_REPAIRING:
		return false
	return (
		mission_definition != null
		and mission_definition.objective_type == MissionDefinition.OBJECTIVE_PROTECT
		and int(state.get("protect_target_hp", 0)) > 0
		and int(state.get("protect_target_hp", 0))
			< int(state.get("protect_target_max_hp", 0))
		and required == PROTECT_TARGET_REPAIR_TICKS
		and progress >= 0
		and progress < required
		and amount > 0
		and amount <= PROTECT_TARGET_REPAIR_HP
		and amount <= (
			int(state.get("protect_target_max_hp", 0))
			- int(state.get("protect_target_hp", 0))
		)
	)


func _has_valid_mission_objective_state_fields(state: Dictionary, expected: Dictionary) -> bool:
	if mission_definition == null or not _has_matching_snapshot_value_types(state, expected):
		return false
	if (
		StringName(state.get("objective_type", &"")) != mission_definition.objective_type
		or str(state.get("protect_target_name", "")) != mission_definition.protect_target_name
		## Mission content supplies the minimum durable target capacity. Scenario
		## setup may raise it for a reinforced objective, but snapshots may never
		## reduce it below the configured baseline or exceed their own maximum.
		or int(state.get("protect_target_max_hp", -1)) < mission_definition.protect_target_hp
		or int(state.get("remaining_enemy_count", -1)) < 0
		or int(state.get("protect_target_hp", -1)) < 0
		or int(state.get("protect_target_hp", 0))
			> int(state.get("protect_target_max_hp", 0))
	):
		return false
	if mission_definition.objective_type != MissionDefinition.OBJECTIVE_PROTECT:
		return (
			int(state.get("protect_target_hp", -1)) == 0
			and int(state.get("protect_target_max_hp", -1)) == 0
		)
	return true


func _get_base_mission_objective_state() -> Dictionary:
	if mission_definition == null:
		return {}
	return {
		"objective_type": mission_definition.objective_type,
		"remaining_enemy_count": request.enemy_force.enemy_count,
		"protect_target_name": mission_definition.protect_target_name,
		"protect_target_hp": mission_definition.protect_target_hp,
		"protect_target_max_hp": mission_definition.protect_target_hp,
		"scout_found": false,
		"extraction_reached": false,
	}


func _has_exact_snapshot_keys(snapshot: Dictionary, expected_keys: Array = SNAPSHOT_KEYS) -> bool:
	for key in expected_keys:
		if not snapshot.has(key):
			return false
	return true


func _has_valid_wartime_facility_state(state: Dictionary) -> bool:
	if state.size() != 1 or typeof(state.get("facilities", null)) != TYPE_ARRAY:
		return false
	var expected_by_id: Dictionary = {}
	for planned_value in Array(request.wartime_facility_plan.get("facilities", [])):
		if not planned_value is Dictionary:
			return false
		var planned: Dictionary = planned_value
		expected_by_id[StringName(planned.get("facility_id", &""))] = planned
	var seen_ids: Dictionary = {}
	for record_value in Array(state.facilities):
		if not record_value is Dictionary:
			return false
		var record: Dictionary = record_value
		if record.size() != 8:
			return false
		var facility_id := StringName(record.get("facility_id", &""))
		var planned: Dictionary = Dictionary(expected_by_id.get(facility_id, {}))
		if (
			planned.is_empty()
			or seen_ids.has(facility_id)
			or typeof(record.get("facility_id", null)) != TYPE_STRING_NAME
			or typeof(record.get("kind", null)) != TYPE_STRING_NAME
			or typeof(record.get("route_id", null)) != TYPE_STRING_NAME
			or typeof(record.get("phase", null)) != TYPE_STRING_NAME
			or typeof(record.get("progress_ticks", null)) != TYPE_INT
			or typeof(record.get("required_ticks", null)) != TYPE_INT
			or typeof(record.get("max_durability", null)) != TYPE_INT
			or typeof(record.get("durability", null)) != TYPE_INT
			or StringName(record.kind) != StringName(planned.kind)
			or StringName(record.route_id) != StringName(planned.route_id)
			or StringName(record.phase) not in [FACILITY_PHASE_CONSTRUCTING, FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED, FACILITY_PHASE_DESTROYED, FACILITY_PHASE_REPAIRING]
			or int(record.max_durability) != int(FACILITY_MAX_DURABILITY.get(StringName(record.kind), -1))
			or int(record.durability) < 0
			or int(record.durability) > int(record.max_durability)
			or (StringName(record.phase) in [FACILITY_PHASE_CONSTRUCTING, FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED, FACILITY_PHASE_DESTROYED] and int(record.required_ticks) != int(FACILITY_BUILD_TICKS.get(StringName(record.kind), -1)))
			or (StringName(record.phase) == FACILITY_PHASE_REPAIRING and int(record.required_ticks) != FACILITY_REPAIR_TICKS)
			or int(record.progress_ticks) < 0
			or int(record.progress_ticks) > int(record.required_ticks)
			or (StringName(record.phase) == FACILITY_PHASE_CONSTRUCTING and int(record.progress_ticks) >= int(record.required_ticks))
			or (StringName(record.phase) == FACILITY_PHASE_ACTIVE and (int(record.progress_ticks) != int(record.required_ticks) or int(record.durability) != int(record.max_durability)))
			or (StringName(record.phase) == FACILITY_PHASE_DAMAGED and (int(record.progress_ticks) != int(record.required_ticks) or int(record.durability) <= 0 or int(record.durability) >= int(record.max_durability)))
			or (StringName(record.phase) == FACILITY_PHASE_DESTROYED and (int(record.progress_ticks) != int(record.required_ticks) or int(record.durability) != 0))
			or (StringName(record.phase) == FACILITY_PHASE_REPAIRING and int(record.progress_ticks) >= int(record.required_ticks))
		):
			return false
		seen_ids[facility_id] = true
	return seen_ids.size() == expected_by_id.size()


func _has_valid_legacy_wartime_facility_state(state: Dictionary) -> bool:
	if state.size() != 1 or typeof(state.get("facilities", null)) != TYPE_ARRAY:
		return false
	for record_value in Array(state.facilities):
		if not record_value is Dictionary:
			return false
		var record: Dictionary = record_value
		var kind := StringName(record.get("kind", &""))
		if (
			record.size() != 6
			or typeof(record.get("facility_id", null)) != TYPE_STRING_NAME
			or typeof(record.get("kind", null)) != TYPE_STRING_NAME
			or typeof(record.get("route_id", null)) != TYPE_STRING_NAME
			or typeof(record.get("phase", null)) != TYPE_STRING_NAME
			or typeof(record.get("progress_ticks", null)) != TYPE_INT
			or typeof(record.get("required_ticks", null)) != TYPE_INT
			or kind not in FACILITY_BUILD_TICKS
			or StringName(record.get("phase", &"")) not in [FACILITY_PHASE_CONSTRUCTING, FACILITY_PHASE_ACTIVE]
			or int(record.get("required_ticks", -1)) != int(FACILITY_BUILD_TICKS[kind])
			or int(record.get("progress_ticks", -1)) < 0
			or int(record.get("progress_ticks", 0)) > int(record.get("required_ticks", 0))
		):
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


func _advance_mission_enemy_positions() -> void:
	if (
		mission_definition == null
		or mission_definition.objective_type != MissionDefinition.OBJECTIVE_PROTECT
	):
		return
	var advance_per_tick := _positive_integer_divide(
		request.committed_force.move_speed_fixed,
		4
	)
	for route_id in [CommittedForceSnapshot.FRONT_ROUTE, CommittedForceSnapshot.SIDE_ROUTE]:
		var route: Dictionary = Dictionary(routes[route_id])
		if int(route.get("enemy_total_hp", 0)) <= 0:
			continue
		var route_advance_per_tick := maxi(
			int(
				advance_per_tick
				* _get_wartime_facility_enemy_advance_basis_points(route_id)
				/ BASIS_POINTS
			),
			1
		)
		route.enemy_position_fixed = mini(
			int(route.get("enemy_position_fixed", 0)) + route_advance_per_tick,
			int(route.distance_fixed)
		)
		routes[route_id] = route


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
	var facility_damage: Dictionary = {}
	if current_tick % ATTACK_INTERVAL_TICKS != 0:
		return {
			"gate_damage": gate_damage,
			"enemy_damage": enemy_damage,
			"player_damage": player_damage,
			"facility_damage": facility_damage,
		}
	_apply_arrow_tower_damage_intents(enemy_damage)

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
		if (
			mission_definition != null
			and mission_definition.objective_type == MissionDefinition.OBJECTIVE_PROTECT
			and not _enemy_has_reached_objective(route_id)
		):
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
		var barricade_basis_points := _get_wartime_facility_incoming_damage_basis_points(route_id)
		var squad_damage := _positive_integer_divide(
			damage * barricade_basis_points,
			BASIS_POINTS
		)
		player_damage[int(target.squad_id)] = squad_damage
		var barricade_id := _get_active_barricade_id(route_id)
		if barricade_id != &"":
			facility_damage[barricade_id] = damage - squad_damage
	return {
		"gate_damage": gate_damage,
		"enemy_damage": enemy_damage,
		"player_damage": player_damage,
		"facility_damage": facility_damage,
	}


## The shared damage application below remains the only writer of route HP.
## This hook merely adds an interval-bound intent for the already selected
## battle route; snapshots retain the resulting HP like all other combat.
func _apply_arrow_tower_damage_intents(enemy_damage: Dictionary) -> void:
	if current_tick % ARROW_TOWER_ATTACK_INTERVAL_TICKS != 0:
		return
	var route_id: StringName = &""
	var volley_damage := 0
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if (
			StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_ARROW_TOWER
			and StringName(record.get("phase", &"")) in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]
		):
			route_id = StringName(record.get("route_id", &""))
			volley_damage = _get_arrow_tower_volley_damage(record)
			break
	if not routes.has(route_id):
		return
	var route: Dictionary = routes[route_id]
	if int(route.get("enemy_total_hp", 0)) <= 0:
		return
	var damage := mini(volley_damage, int(route.enemy_total_hp))
	enemy_damage[route_id] = int(enemy_damage.get(route_id, 0)) + damage
	last_tick_facility_events.append({
		"kind": WartimeFacilityPlan.KIND_ARROW_TOWER,
		"route_id": route_id,
		"damage": damage,
		"tick": current_tick,
	})


func _get_arrow_tower_volley_damage(record: Dictionary) -> int:
	if StringName(record.get("phase", &"")) == FACILITY_PHASE_ACTIVE:
		return ARROW_TOWER_DAMAGE_PER_VOLLEY
	var max_durability := maxi(int(record.get("max_durability", 0)), 1)
	var durability := clampi(int(record.get("durability", 0)), 1, max_durability)
	return _positive_integer_divide(
		ARROW_TOWER_DAMAGE_PER_VOLLEY * durability,
		max_durability
	)


func _get_wartime_facility_incoming_damage_basis_points(route_id: StringName) -> int:
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if (
			StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE
			and StringName(record.get("phase", &"")) in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]
			and StringName(record.get("route_id", &"")) == route_id
		):
			return _get_barricade_incoming_damage_basis_points(record)
	return BASIS_POINTS


## A complete barricade passes 65% of ordinary route damage. Once damaged,
## remaining durability deterministically reduces the amount it can absorb:
## at zero it protects nothing, without introducing a second HP or casualty
## authority. Integer math keeps the result stable across snapshots and ticks.
func _get_barricade_incoming_damage_basis_points(record: Dictionary) -> int:
	return _get_barricade_durability_basis_points(
		record,
		BARRICADE_INCOMING_DAMAGE_BASIS_POINTS
	)


func _get_wartime_facility_enemy_advance_basis_points(route_id: StringName) -> int:
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if (
			StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE
			and StringName(record.get("phase", &"")) in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]
			and StringName(record.get("route_id", &"")) == route_id
		):
			return _get_barricade_durability_basis_points(
				record,
				BARRICADE_ENEMY_ADVANCE_BASIS_POINTS
			)
	return BASIS_POINTS


## Both a damaged barrier's protection and its route delay derive from the
## one saved durability value. `full_effect_basis_points` is the fraction
## passed through at full health; no separate simulation state is needed.
func _get_barricade_durability_basis_points(
	record: Dictionary,
	full_effect_basis_points: int
) -> int:
	if StringName(record.get("phase", &"")) == FACILITY_PHASE_ACTIVE:
		return full_effect_basis_points
	var max_durability := maxi(int(record.get("max_durability", 0)), 1)
	var durability := clampi(int(record.get("durability", 0)), 0, max_durability)
	var maximum_absorbed_basis_points := (
		BASIS_POINTS - full_effect_basis_points
	)
	var absorbed_basis_points := _positive_integer_divide(
		maximum_absorbed_basis_points * durability,
		max_durability
	)
	return clampi(BASIS_POINTS - absorbed_basis_points, full_effect_basis_points, BASIS_POINTS)


func _get_active_barricade_id(route_id: StringName) -> StringName:
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if (
			StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE
			and StringName(record.get("phase", &"")) in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]
			and StringName(record.get("route_id", &"")) == route_id
		):
			return StringName(record.get("facility_id", &""))
	return &""


## Once invaders have broken or bypassed a route barricade, they can dismantle
## the route's tower before they resume gate damage. This is a normal facility
## damage intent and leaves target selection, durability, repair, and restore
## under the same BattleSession authority as every other temporary work.
func _get_active_arrow_tower_id(route_id: StringName) -> StringName:
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if (
			StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_ARROW_TOWER
			and StringName(record.get("phase", &"")) in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]
			and StringName(record.get("route_id", &"")) == route_id
		):
			return StringName(record.get("facility_id", &""))
	return &""


## A watch platform is a route-local observation work, not a second fog-of-war
## owner. When invaders reach an undefended route after its barricade and tower
## are gone, they can damage the saved platform; the existing projection then
## immediately stops exposing its exact count until a repair completes.
func _get_active_watch_platform_id(route_id: StringName) -> StringName:
	for record_value in Array(wartime_facility_state.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if (
			StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_WATCH_PLATFORM
			and StringName(record.get("phase", &"")) in [FACILITY_PHASE_ACTIVE, FACILITY_PHASE_DAMAGED]
			and StringName(record.get("route_id", &"")) == route_id
		):
			return StringName(record.get("facility_id", &""))
	return &""


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
	_apply_wartime_facility_damage(Dictionary(intents.get("facility_damage", {})))
	_apply_mission_objective_damage()


func _apply_wartime_facility_damage(damage_by_id: Dictionary) -> void:
	if damage_by_id.is_empty():
		return
	var facilities: Array = Array(wartime_facility_state.get("facilities", [])).duplicate(true)
	for index in facilities.size():
		var record: Dictionary = Dictionary(facilities[index])
		var facility_id := StringName(record.get("facility_id", &""))
		if not damage_by_id.has(facility_id):
			continue
		var damage := int(damage_by_id[facility_id])
		if damage <= 0:
			continue
		record.durability = maxi(int(record.get("durability", 0)) - damage, 0)
		record.phase = FACILITY_PHASE_DESTROYED if int(record.durability) == 0 else FACILITY_PHASE_DAMAGED
		facilities[index] = record
		last_tick_facility_events.append({
			"kind": record.kind, "route_id": record.route_id,
			"event": &"DESTROYED" if int(record.durability) == 0 else &"DAMAGED",
			"damage": damage, "durability": record.durability, "tick": current_tick,
		})
	wartime_facility_state.facilities = facilities


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


## Restores only a terminal authority record that was durably published before
## macro writeback.  The live simulation snapshot remains separate: no tick is
## replayed, so a restart cannot recalculate casualties or mint another result.
func restore_terminal_result(authority_snapshot: Dictionary) -> bool:
	if request == null or completed or authority_snapshot.is_empty():
		return false
	var restored := BattleResult.from_authority_snapshot(authority_snapshot)
	if (
		not restored.is_consistent()
		or restored.transaction_id != request.transaction_id
		or restored.session_id != session_id
		or restored.level_id != request.level_id
		or restored.player_snapshot_digest != request.committed_force.get_digest()
		or restored.enemy_snapshot_digest != request.enemy_force.get_digest()
	):
		return false
	completed = true
	result = restored
	_terminal_authority_record = {
		"result": authority_snapshot.duplicate(true),
		"completion": {
			"session_id": session_id,
			"state_digest": "restored-terminal",
			"route_ids": routes.keys().duplicate(),
		},
	}
	return true


func _initialize_mission_objective_state() -> void:
	mission_objective_state = _get_base_mission_objective_state()
	if mission_objective_state.is_empty():
		return
	mission_objective_state["protect_target_repair_phase"] = PROTECT_TARGET_REPAIR_IDLE
	mission_objective_state["protect_target_repair_progress_ticks"] = 0
	mission_objective_state["protect_target_repair_required_ticks"] = 0
	mission_objective_state["protect_target_repair_amount"] = 0


func _advance_protect_target_repair() -> void:
	if (
		StringName(mission_objective_state.get("protect_target_repair_phase", &""))
		!= PROTECT_TARGET_REPAIRING
	):
		return
	var required := int(mission_objective_state.get("protect_target_repair_required_ticks", 0))
	var progress := mini(
		int(mission_objective_state.get("protect_target_repair_progress_ticks", 0)) + 1,
		required
	)
	mission_objective_state["protect_target_repair_progress_ticks"] = progress
	if progress < required:
		return
	var restored_hp := mini(
		int(mission_objective_state.protect_target_hp)
		+ int(mission_objective_state["protect_target_repair_amount"]),
		int(mission_objective_state.protect_target_max_hp)
	)
	mission_objective_state.protect_target_hp = restored_hp
	mission_objective_state["protect_target_repair_phase"] = PROTECT_TARGET_REPAIR_IDLE
	mission_objective_state["protect_target_repair_progress_ticks"] = 0
	mission_objective_state["protect_target_repair_required_ticks"] = 0
	mission_objective_state["protect_target_repair_amount"] = 0
	last_tick_facility_events.append({
		"kind": &"GATE", "route_id": &"",
		"event": &"GATE_REPAIR_COMPLETED", "tick": current_tick,
	})


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
	var facility_damage: Dictionary = {}
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = routes[route_id]
		if (
			int(route.enemy_total_hp) > 0
			and _enemy_has_reached_objective(route_id)
			and not _has_frontline_squad(route_id)
		):
			var raw_damage := (
				_alive_members(int(route.enemy_total_hp))
				* mission_definition.protect_damage_per_enemy
			)
			var barricade_id := _get_active_barricade_id(route_id)
			if barricade_id != &"":
				var passed_damage := _positive_integer_divide(
					raw_damage * _get_wartime_facility_incoming_damage_basis_points(route_id),
					BASIS_POINTS
				)
				damage += passed_damage
				facility_damage[barricade_id] = raw_damage - passed_damage
			else:
				var arrow_tower_id := _get_active_arrow_tower_id(route_id)
				if arrow_tower_id != &"":
					facility_damage[arrow_tower_id] = raw_damage
				else:
					var watch_platform_id := _get_active_watch_platform_id(route_id)
					if watch_platform_id != &"":
						facility_damage[watch_platform_id] = raw_damage
					else:
						damage += raw_damage
	_apply_wartime_facility_damage(facility_damage)
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


func _enemy_has_reached_objective(route_id: StringName) -> bool:
	if mission_definition == null or mission_definition.objective_type != MissionDefinition.OBJECTIVE_PROTECT:
		return true
	var route: Dictionary = routes.get(route_id, {})
	return (
		not route.is_empty()
		and int(route.get("enemy_position_fixed", 0)) >= int(route.get("distance_fixed", 0))
	)


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
