class_name CombatTransactionCoordinator
extends Node


const DEFAULT_LEVEL_ID := &"first_map.main_assault.v0"

var city_controller: Node
var active_request: BattleRequest
var active_session: BattleSession
var result_applier: BattleResultApplier
var return_contract: ReturnToCityContract


func configure(city_controller_value: Node) -> void:
	city_controller = city_controller_value
	result_applier = BattleResultApplier.new(city_controller)


func create_request(
	committed_total: int,
	level_id := DEFAULT_LEVEL_ID
) -> BattleRequest:
	if city_controller == null or active_request != null:
		return null
	return_contract = null
	var transaction_id: StringName = (
		city_controller.reserve_battle_force(committed_total)
	)
	if transaction_id == &"":
		return null
	var unit_role: UnitRole = city_controller.get_unit_role()
	var tech_ids: Array[StringName] = (
		city_controller.researched_tech_ids.duplicate()
	)
	var committed_snapshot := CommittedForceSnapshot.create_default(
		transaction_id,
		committed_total,
		unit_role,
		city_controller.selected_general_id,
		tech_ids,
		city_controller.get_infantry_attack_multiplier(),
		city_controller.get_infantry_defense_multiplier(),
		city_controller.supply_shortage
	)
	var enemy_snapshot := EnemyForceSnapshot.create(
		transaction_id,
		city_controller.current_day,
		city_controller.enemy_count,
		city_controller.enemy_fortification
	)
	var request := BattleRequest.new(
		transaction_id,
		level_id,
		city_controller.current_day,
		committed_snapshot,
		enemy_snapshot
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
		return false
	if return_contract.completed:
		return true
	if current_frame < return_contract.city_input_restore_frame:
		return false
	return_contract.completed = true
	active_session = null
	active_request = null
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
