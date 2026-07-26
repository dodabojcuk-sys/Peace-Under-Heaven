class_name CombatTransactionCoordinator
extends Node


const DEFAULT_LEVEL_ID := &"first_map.main_assault.v0"

var city_controller: Node
var active_request: BattleRequest
var active_session: BattleSession
var result_applier: BattleResultApplier
var return_contract: ReturnToCityContract
var _return_completed := false


func configure(city_controller_value: Node) -> void:
	city_controller = city_controller_value
	result_applier = BattleResultApplier.new(city_controller)


func create_request(
	committed_total: int,
	level_id := DEFAULT_LEVEL_ID,
	formal_city_entry := false,
	mission_definition: MissionDefinition = null
) -> BattleRequest:
	if city_controller == null or active_request != null:
		return null
	return_contract = null
	_return_completed = false
	var transaction_id: StringName = (
		city_controller.reserve_battle_force(committed_total)
	)
	if transaction_id == &"":
		return null
	var unit_role: UnitRole = city_controller.get_unit_role()
	var tech_ids: Array[StringName] = (
		city_controller.researched_tech_ids.duplicate()
	)
	var committed_food_cost: int = (
		city_controller.get_first_war_food_cost(committed_total)
		if formal_city_entry
		else 0
	)
	var committed_snapshot := CommittedForceSnapshot.create_default(
		transaction_id,
		committed_total,
		unit_role,
		city_controller.selected_general_id,
		tech_ids,
		city_controller.get_infantry_attack_multiplier(),
		city_controller.get_infantry_defense_multiplier(),
		(
			city_controller.supply_shortage
			or (
				formal_city_entry
				and city_controller.food < committed_food_cost
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
			city_controller.current_day,
			mission_definition
		)
		if mission_definition != null
		else EnemyForceSnapshot.create(
			transaction_id,
			city_controller.current_day,
			city_controller.enemy_count,
			city_controller.enemy_fortification
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
		city_controller.current_day,
		committed_snapshot,
		enemy_snapshot,
		formal_city_entry,
		committed_food_cost,
		city_controller.get_city_defense(),
		source_id,
		first_clear_key,
		mission_definition.reward_wood if mission_definition != null else 30,
		mission_definition.reward_food if mission_definition != null else 20,
		mission_definition
	)
	if not request.is_valid():
		city_controller.cancel_battle_reservation(transaction_id)
		return null
	active_request = request
	return active_request


func activate_request() -> bool:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_RESERVED
		or not city_controller.activate_battle_reservation(
			active_request.transaction_id
		)
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


func confirm_result() -> Dictionary:
	if (
		active_request == null
		or active_session == null
		or active_session.result == null
		or active_request.phase not in [
			BattleRequest.PHASE_RESULT_PENDING,
			BattleRequest.PHASE_APPLIED,
		]
	):
		return {}
	var summary := result_applier.apply(
		active_session.result,
		active_request
	)
	if summary.is_empty():
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
	active_request = null
	_return_completed = true
	return_contract = null
	return true


func cancel_request() -> bool:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_RESERVED
		or not city_controller.cancel_battle_reservation(
			active_request.transaction_id
		)
	):
		return false
	active_request.phase = BattleRequest.PHASE_CANCELLED
	active_request = null
	return true


func mark_result_pending() -> bool:
	if (
		active_request == null
		or active_request.phase != BattleRequest.PHASE_ACTIVE
		or not city_controller.mark_battle_result_pending(
			active_request.transaction_id
		)
	):
		return false
	active_request.phase = BattleRequest.PHASE_RESULT_PENDING
	return true
