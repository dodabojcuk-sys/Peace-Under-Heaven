class_name CombatTransactionCoordinator
extends Node


const DEFAULT_LEVEL_ID := &"first_map.main_assault.v0"

var _city_controller: Node
var active_request: BattleRequest
var active_session: BattleSession
var _bound_session: BattleSession
var result_applier: BattleResultApplier
var return_contract: ReturnToCityContract
var _return_completed := false
var _pending_result_authority: Dictionary = {}
var last_result_error_id: StringName = &""
var _army_id: StringName = &""
var _army_mode := false
var _macro_siege_city_id: StringName = &""
var _macro_siege_mode := false
var _adopted_expedition := false


func configure(city_controller_value: Node) -> bool:
	if (
		city_controller_value == null
		or not city_controller_value.has_method(
			"_accept_combat_transaction_coordinator_binding"
		)
		or not city_controller_value.has_method(
			"is_combat_transaction_coordinator_bound"
		)
	):
		return false
	if _city_controller == city_controller_value:
		return (
			result_applier != null
			and city_controller_value.is_combat_transaction_coordinator_bound(
				self
			)
		)
	if _city_controller != null:
		return false
	var candidate_applier := BattleResultApplier.new(city_controller_value)
	_city_controller = city_controller_value
	if not city_controller_value._accept_combat_transaction_coordinator_binding(
		self
	):
		_city_controller = null
		return false
	if not city_controller_value.is_combat_transaction_coordinator_bound(self):
		_city_controller = null
		return false
	result_applier = candidate_applier
	return true


func get_bound_city() -> Node:
	return _city_controller


func is_bound_to_city(city_controller_value: Node) -> bool:
	return (
		city_controller_value != null
		and _city_controller == city_controller_value
	)


func create_request(
	committed_total: int,
	level_id := DEFAULT_LEVEL_ID,
	formal_city_entry := false,
	mission_definition: MissionDefinition = null
) -> BattleRequest:
	if _city_controller == null or active_request != null:
		return null
	return_contract = null
	_return_completed = false
	_pending_result_authority = {}
	_bound_session = null
	last_result_error_id = &""
	_army_id = &""
	_army_mode = false
	_macro_siege_city_id = &""
	_macro_siege_mode = false
	_adopted_expedition = false
	var transaction_id: StringName = (
		_city_controller.reserve_battle_force(committed_total, self)
	)
	if transaction_id == &"":
		return null
	var unit_role: UnitRole = _city_controller.get_unit_role()
	var tech_ids: Array[StringName] = (
		_city_controller.researched_tech_ids.duplicate()
	)
	var committed_food_cost: int = (
		_city_controller.get_first_war_food_cost(committed_total)
		if formal_city_entry
		else 0
	)
	var committed_snapshot := CommittedForceSnapshot.create_default(
		transaction_id,
		committed_total,
		unit_role,
		_city_controller.selected_general_id,
		tech_ids,
		_city_controller.get_infantry_attack_multiplier(),
		_city_controller.get_infantry_defense_multiplier(),
		(
			_city_controller.supply_shortage
			or (
				formal_city_entry
				and _city_controller.food < committed_food_cost
			)
		)
	)
	if mission_definition != null:
		for index in range(committed_snapshot.squads.size()):
			if index >= mission_definition.player_route_pattern.size():
				break
			committed_snapshot.squads[index].route_id = (
				mission_definition.player_route_pattern[index]
			)
	var enemy_snapshot := (
		EnemyForceSnapshot.create_for_mission(
			transaction_id,
			_city_controller.current_day,
			mission_definition
		)
		if mission_definition != null
		else EnemyForceSnapshot.create(
			transaction_id,
			_city_controller.current_day,
			_city_controller.enemy_count,
			_city_controller.enemy_fortification
		)
	)
	var source_id := (
		MissionDefinition.SOURCE_NOTICEBOARD
		if mission_definition != null
		else &"FIRST_WAR"
	)
	var first_clear_key := (
		mission_definition.first_clear_key
		if mission_definition != null
		else BattleSession.FIRST_CLEAR_KEY
	)
	var request := BattleRequest.new(
		transaction_id,
		level_id,
		_city_controller.current_day,
		committed_snapshot,
		enemy_snapshot,
		formal_city_entry,
		committed_food_cost,
		_city_controller.get_city_defense(),
		source_id,
		first_clear_key,
		mission_definition.reward_wood if mission_definition != null else 30,
		mission_definition.reward_food if mission_definition != null else 20,
		mission_definition
	)
	if not request.is_valid():
		_city_controller.cancel_battle_reservation(transaction_id, self)
		return null
	active_request = request
	return active_request


func adopt_expedition_request(request: BattleRequest) -> bool:
	if (
		_city_controller == null
		or active_request != null
		or request == null
		or not request.is_valid()
		or not request.formal_city_entry
		or request.is_noticeboard_mission()
		or request.phase not in [
			BattleRequest.PHASE_RESERVED,
			BattleRequest.PHASE_ACTIVE,
		]
		or not _city_controller.has_method(
			"authorize_prepared_battle_request"
		)
		or not _city_controller.authorize_prepared_battle_request(
			request,
			self
		)
	):
		return false
	return_contract = null
	_return_completed = false
	_pending_result_authority = {}
	_bound_session = null
	last_result_error_id = &""
	_army_id = &""
	_army_mode = false
	_macro_siege_city_id = &""
	_macro_siege_mode = false
	_adopted_expedition = true
	active_request = request
	return true


func create_army_request(
	army_id: StringName,
	level_id: StringName,
	enemy_count: int,
	enemy_fortification := 0
) -> BattleRequest:
	if (
		_city_controller == null
		or active_request != null
		or army_id == &""
		or level_id == &""
		or enemy_count <= 0
		or enemy_fortification < 0
	):
		return null
	var army: Dictionary = _city_controller.get_army_state(army_id)
	if (
		army.is_empty()
		or StringName(army.phase) != ArmyRegistry.PHASE_SETTLEMENT_PENDING
	):
		return null
	var transaction_id := StringName(army.transaction_id)
	var units: Dictionary = army.units_by_definition_id
	var committed_total := 0
	for count in units.values():
		committed_total += int(count)
	if committed_total <= 0:
		return null
	return_contract = null
	_return_completed = false
	_pending_result_authority = {}
	_bound_session = null
	last_result_error_id = &""
	_adopted_expedition = false
	var committed_snapshot := CommittedForceSnapshot.create_default(
		transaction_id,
		committed_total,
		_city_controller.get_unit_role(),
		_city_controller.selected_general_id,
		_city_controller.researched_tech_ids.duplicate(),
		_city_controller.get_infantry_attack_multiplier(),
		_city_controller.get_infantry_defense_multiplier(),
		_city_controller.supply_shortage
	)
	var enemy_snapshot := EnemyForceSnapshot.create(
		transaction_id,
		_city_controller.current_day,
		enemy_count,
		enemy_fortification
	)
	var request := BattleRequest.new(
		transaction_id,
		level_id,
		_city_controller.current_day,
		committed_snapshot,
		enemy_snapshot,
		false,
		0,
		_city_controller.get_city_defense(),
		&"FIRST_WAR",
		StringName("v5.encounter.%s" % String(level_id)),
		0,
		0
	)
	if not request.is_valid():
		return null
	_army_id = army_id
	_army_mode = true
	active_request = request
	return active_request


## Macro sieges retain their existing army and order.  The controller creates
## the request from those facts and atomically installs the durable handoff
## relation before this coordinator exposes the reserved instance to the UI.
func create_macro_siege_request(
	army_id: StringName,
	city_id: StringName
) -> BattleRequest:
	if (
		_city_controller == null
		or active_request != null
		or army_id == &""
		or city_id == &""
		or not _city_controller.has_method("prepare_macro_siege_battle_request")
	):
		return null
	var request: BattleRequest = _city_controller.prepare_macro_siege_battle_request(
		army_id, city_id, self
	)
	if request == null or not request.is_valid() or request.source_id != BattleRequest.SOURCE_MACRO_SIEGE:
		return null
	return_contract = null
	_return_completed = false
	_pending_result_authority = {}
	_bound_session = null
	last_result_error_id = &""
	_adopted_expedition = false
	_army_id = army_id
	_army_mode = false
	_macro_siege_city_id = city_id
	_macro_siege_mode = true
	active_request = request
	return active_request


func activate_request() -> bool:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_RESERVED
	):
		return false
	if _macro_siege_mode:
		if not _city_controller.authorize_macro_siege_battle_activation(
			_army_id, _macro_siege_city_id, active_request.transaction_id, self
		):
			return false
	elif _army_mode:
		if not _city_controller.authorize_army_encounter_activation(
			_army_id,
			active_request.transaction_id,
			self
		):
			return false
	elif not _city_controller.activate_battle_reservation(
		active_request.transaction_id,
		self
	):
		return false
	active_request.phase = BattleRequest.PHASE_ACTIVE
	return true


func set_squad_route(
	squad_id: int,
	route_id: StringName
) -> bool:
	if (
		active_request == null
		or _adopted_expedition
		or active_request.phase != BattleRequest.PHASE_RESERVED
		or route_id not in [
			CommittedForceSnapshot.FRONT_ROUTE,
			CommittedForceSnapshot.SIDE_ROUTE,
		]
	):
		return false
	for squad in active_request.committed_force.squads:
		if int(squad.squad_id) == squad_id:
			squad.route_id = route_id
			return true
	return false


func create_session() -> BattleSession:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_ACTIVE
		or active_session != null
	):
		return null
	var session := BattleSession.new(active_request)
	if session.request == null:
		return null
	active_session = session
	_bound_session = session
	return active_session


func advance_battle_tick() -> BattleResult:
	if active_session == null or active_session.completed:
		return active_session.result if active_session != null else null
	active_session.step_tick()
	if active_session.completed:
		if not mark_result_pending():
			return null
		return active_session.result
	return null


func issue_order(
	squad_id: int,
	command: BattleOrder.Command
) -> BattleOrder:
	if active_session == null:
		return null
	return active_session.issue_order(squad_id, command)


func confirm_result(payload: BattleResult = null) -> Dictionary:
	last_result_error_id = &""
	if (
		active_request == null
		or _bound_session == null
		or active_request.phase not in [
			BattleRequest.PHASE_RESULT_PENDING,
			BattleRequest.PHASE_APPLIED,
		]
	):
		last_result_error_id = &"RESULT_NOT_PENDING"
		return {}
	if _pending_result_authority.is_empty():
		last_result_error_id = &"RESULT_AUTHORITY_UNAVAILABLE"
		return {}
	if payload != null and not payload.matches_authority_snapshot(_pending_result_authority):
		last_result_error_id = &"RESULT_PAYLOAD_CONFLICT"
		return {}
	var summary: Dictionary = result_applier.apply_authorized(
		active_request.transaction_id,
		StringName(_pending_result_authority.get("result_id", &""))
	)
	if summary.is_empty():
		last_result_error_id = result_applier.last_error_id
		return {}
	active_request.phase = BattleRequest.PHASE_APPLIED
	return summary


func request_return_to_city() -> ReturnToCityContract:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_APPLIED
		or active_session == null
		or active_session.result == null
	):
		return null
	if return_contract == null:
		return_contract = ReturnToCityContract.new(
			active_request.transaction_id,
			active_session.result.result_id,
			Engine.get_process_frames() + 1
		)
	return return_contract


func complete_return_to_city(current_frame: int) -> bool:
	if return_contract == null:
		return _return_completed
	if return_contract.completed:
		return true
	if current_frame < return_contract.city_input_restore_frame:
		return false
	return_contract.completed = true
	active_session = null
	_bound_session = null
	active_request = null
	_pending_result_authority = {}
	_return_completed = true
	return_contract = null
	_army_id = &""
	_army_mode = false
	_macro_siege_city_id = &""
	_macro_siege_mode = false
	_adopted_expedition = false
	return true


func cancel_request() -> bool:
	if active_request == null or active_request.phase != BattleRequest.PHASE_RESERVED:
		return false
	var cancelled := false
	if _macro_siege_mode:
		cancelled = _city_controller.cancel_reserved_macro_siege_battle(
			_army_id, _macro_siege_city_id, active_request.transaction_id, self
		)
	else:
		cancelled = _city_controller.cancel_battle_reservation(
			active_request.transaction_id,
			self
		)
	if not cancelled:
		return false
	active_request.phase = BattleRequest.PHASE_CANCELLED
	active_request = null
	_bound_session = null
	_pending_result_authority = {}
	_adopted_expedition = false
	_army_id = &""
	_army_mode = false
	_macro_siege_city_id = &""
	_macro_siege_mode = false
	return true


func mark_result_pending() -> bool:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_ACTIVE
		or active_session == null
		or active_session != _bound_session
		or not active_session.completed
	):
		return false
	var authority_snapshot := active_session.get_terminal_result_snapshot()
	if (
		authority_snapshot.is_empty()
		or StringName(authority_snapshot.get("transaction_id", &""))
			!= active_request.transaction_id
		or StringName(authority_snapshot.get("session_id", &""))
			!= active_session.session_id
		or StringName(authority_snapshot.get("result_id", &"")) == &""
	):
		return false
	if _pending_result_authority.is_empty():
		_pending_result_authority = authority_snapshot.duplicate(true)
	elif _pending_result_authority != authority_snapshot:
		return false
	if _macro_siege_mode:
		if not _city_controller.authorize_macro_siege_battle_result_pending(
			_army_id,
			_macro_siege_city_id,
			active_request.transaction_id,
			authority_snapshot,
			self
		):
			return false
	elif _army_mode:
		if not _city_controller.authorize_army_encounter_result_pending(
			_army_id,
			active_request.transaction_id,
			self
		):
			return false
	elif not _city_controller.mark_battle_result_pending(
		active_request.transaction_id,
		self
	):
		return false
	active_request.phase = BattleRequest.PHASE_RESULT_PENDING
	return true


## Rehydrates a macro result that reached terminal simulation before the
## durable writeback.  It deliberately adopts the stored result rather than
## stepping the recreated session, preserving the exactly-once boundary.
func resume_macro_siege_result_pending(
	session_snapshot: Dictionary,
	result_authority_snapshot: Dictionary
) -> bool:
	if (
		not _macro_siege_mode
		or active_request == null
		or active_request.phase != BattleRequest.PHASE_RESULT_PENDING
		or active_session != null
		or session_snapshot.is_empty()
		or result_authority_snapshot.is_empty()
	):
		return false
	active_request.phase = BattleRequest.PHASE_ACTIVE
	if create_session() == null:
		active_request.phase = BattleRequest.PHASE_RESULT_PENDING
		return false
	if (
		not active_session.restore_snapshot(session_snapshot)
		or not active_session.restore_terminal_result(result_authority_snapshot)
	):
		active_session = null
		_bound_session = null
		active_request.phase = BattleRequest.PHASE_RESULT_PENDING
		return false
	active_request.phase = BattleRequest.PHASE_RESULT_PENDING
	_pending_result_authority = result_authority_snapshot.duplicate(true)
	return true


func get_authorized_settlement_for_bound_city(
	transaction_id: StringName,
	result_id: StringName
) -> Dictionary:
	if (
		active_request == null
		or _bound_session == null
		or active_session != _bound_session
		or active_request.phase not in [
			BattleRequest.PHASE_RESULT_PENDING,
			BattleRequest.PHASE_APPLIED,
		]
		or _pending_result_authority.is_empty()
		or transaction_id != active_request.transaction_id
		or result_id != StringName(_pending_result_authority.get("result_id", &""))
	):
		return {}
	var authority_snapshot := _pending_result_authority.duplicate(true)
	if (
		StringName(authority_snapshot.get("transaction_id", &"")) != transaction_id
		or StringName(authority_snapshot.get("session_id", &""))
			!= _bound_session.session_id
	):
		return {}
	return {
		"battle_result": BattleResult.from_authority_snapshot(authority_snapshot),
		"request": active_request,
		"army_id": _army_id if (_army_mode or _macro_siege_mode) else &"",
		"macro_siege_city_id": _macro_siege_city_id if _macro_siege_mode else &"",
	}
