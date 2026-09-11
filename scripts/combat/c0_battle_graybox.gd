class_name C0BattleGraybox
extends Node2D


signal formal_return_completed(summary: Dictionary)
signal formal_entry_cancelled
signal noticeboard_return_completed(mission_id: StringName, summary: Dictionary)
signal noticeboard_entry_cancelled(mission_id: StringName)

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const NORTHERN_PALETTE := preload(
	"res://resources/visuals/northern_campaign_palette.gd"
)
const DEBUG_PLAYER_COUNT := 50

@onready var coordinator: CombatTransactionCoordinator = (
	$CombatTransactionCoordinator
)
@onready var city_container: Node2D = $CityContainer
@onready var tick_timer: Timer = $TickTimer
@onready var status_label: Label = $UI/RootPanel/StatusLabel
@onready var title_label: Label = $UI/RootPanel/Title
@onready var instruction_label: Label = $UI/RootPanel/Instruction
@onready var front_state_label: Label = (
	$UI/RootPanel/FrontLane/StateLabel
)
@onready var front_route_name_label: Label = (
	$UI/RootPanel/FrontLane/RouteName
)
@onready var front_enemy_marker: Panel = (
	$UI/RootPanel/FrontLane/EnemyMarker
)
@onready var front_enemy_count_label: Label = (
	$UI/RootPanel/FrontLane/EnemyMarker/Count
)
@onready var front_gate: ColorRect = $UI/RootPanel/FrontLane/FrontGate
@onready var side_state_label: Label = (
	$UI/RootPanel/SideLane/StateLabel
)
@onready var side_route_name_label: Label = (
	$UI/RootPanel/SideLane/RouteName
)
@onready var side_enemy_marker: Panel = (
	$UI/RootPanel/SideLane/EnemyMarker
)
@onready var side_enemy_count_label: Label = (
	$UI/RootPanel/SideLane/EnemyMarker/Count
)
@onready var side_gate: ColorRect = $UI/RootPanel/SideLane/SideGate
@onready var start_button: Button = $UI/RootPanel/StartButton
@onready var battlefield_panel: Panel = $UI/RootPanel/Battlefield
@onready var wartime_plan_panel: Panel = $UI/RootPanel/WartimePlanPanel
@onready var wartime_watch_button: Button = (
	$UI/RootPanel/WartimePlanPanel/WatchButton
)
@onready var wartime_ram_button: Button = (
	$UI/RootPanel/WartimePlanPanel/RamButton
)
@onready var wartime_plan_confirm_button: Button = (
	$UI/RootPanel/WartimePlanPanel/ConfirmButton
)
@onready var exit_button: Button = $UI/RootPanel/ExitButton
@onready var squad_controls: HBoxContainer = (
	$UI/RootPanel/SquadControls
)
@onready var marker_layer: Control = $UI/RootPanel/MarkerLayer
@onready var wagon_panel: Panel = (
	$UI/RootPanel/MissionObjectLayer/Wagon
)
@onready var wagon_label: Label = (
	$UI/RootPanel/MissionObjectLayer/Wagon/Label
)
@onready var wagon_health: ProgressBar = (
	$UI/RootPanel/MissionObjectLayer/Wagon/Health
)
@onready var front_search_zone: Panel = (
	$UI/RootPanel/MissionObjectLayer/FrontSearchZone
)
@onready var side_search_zone: Panel = (
	$UI/RootPanel/MissionObjectLayer/SideSearchZone
)
@onready var extraction_zone: Panel = (
	$UI/RootPanel/MissionObjectLayer/ExtractionZone
)
@onready var selected_squad_title: Label = (
	$UI/RootPanel/SelectedSquadPanel/Title
)
@onready var selected_squad_state: Label = (
	$UI/RootPanel/SelectedSquadPanel/State
)
@onready var selected_advance_button: Button = (
	$UI/RootPanel/SelectedSquadPanel/AdvanceButton
)
@onready var selected_hold_button: Button = (
	$UI/RootPanel/SelectedSquadPanel/HoldButton
)
@onready var selected_retreat_button: Button = (
	$UI/RootPanel/SelectedSquadPanel/RetreatButton
)
@onready var recent_actions_label: Label = (
	$UI/RootPanel/SelectedSquadPanel/RecentActions
)
@onready var exit_input_blocker: ColorRect = (
	$UI/RootPanel/ExitInputBlocker
)
@onready var exit_confirmation: Panel = (
	$UI/RootPanel/ExitConfirmation
)
@onready var exit_cancel_button: Button = (
	$UI/RootPanel/ExitConfirmation/CancelButton
)
@onready var exit_confirm_button: Button = (
	$UI/RootPanel/ExitConfirmation/ConfirmButton
)
@onready var result_input_blocker: ColorRect = (
	$UI/RootPanel/ResultInputBlocker
)
@onready var result_panel: Panel = $UI/RootPanel/ResultPanel
@onready var result_label: Label = (
	$UI/RootPanel/ResultPanel/Margin/Content/ResultLabel
)
@onready var confirm_button: Button = (
	$UI/RootPanel/ResultPanel/Margin/Content/Actions/ConfirmButton
)
@onready var return_button: Button = (
	$UI/RootPanel/ResultPanel/Margin/Content/Actions/ReturnButton
)

var city_scene: Node2D
var city_controller: Node
var city_ui: CanvasLayer
var city_camera: Camera2D
var request: BattleRequest
var formal_city_mode := false
var formal_committed_count := 0
var prepared_expedition_request: BattleRequest
var noticeboard_mission_mode := false
var mission_definition: MissionDefinition
var _squad_ui: Dictionary = {}
var _squad_markers: Dictionary = {}
var _confirmed_summary: Dictionary = {}
var _exit_in_progress := false
var _return_requested := false
var _resume_timer_after_exit_cancel := false
var _selected_squad_id := -1
var _presentation_snapshot: Dictionary = {}
var _recent_actions: Array[String] = []
var _pending_wartime_facility_plan: Dictionary = {}


func _ready() -> void:
	tick_timer.timeout.connect(_on_tick_timeout)
	start_button.pressed.connect(_start_battle_from_ui)
	wartime_watch_button.pressed.connect(
		_toggle_wartime_facility.bind(WartimeFacilityPlan.KIND_WATCH_PLATFORM)
	)
	wartime_ram_button.pressed.connect(
		_toggle_wartime_facility.bind(WartimeFacilityPlan.KIND_SIEGE_RAM)
	)
	wartime_plan_confirm_button.pressed.connect(_confirm_wartime_facility_plan)
	exit_button.pressed.connect(request_exit_or_return)
	exit_cancel_button.pressed.connect(cancel_exit_confirmation)
	exit_confirm_button.pressed.connect(confirm_exit_as_retreat)
	confirm_button.pressed.connect(confirm_pending_result)
	return_button.pressed.connect(request_return_to_city)
	selected_advance_button.pressed.connect(
		_issue_selected_order.bind(BattleOrder.Command.ADVANCE)
	)
	selected_hold_button.pressed.connect(
		_issue_selected_order.bind(BattleOrder.Command.HOLD)
	)
	selected_retreat_button.pressed.connect(
		_issue_selected_order.bind(BattleOrder.Command.RETREAT)
	)
	if formal_city_mode:
		_prepare_formal_city()
	else:
		_create_city_fixture()
	_create_battle_request()
	if request != null:
		_pending_wartime_facility_plan = request.wartime_facility_plan.duplicate(true)
		_resume_active_battle_if_available()
	_create_squad_controls()
	_apply_northern_visual_palette()
	_append_recent_action("选择小队，安排战前路线")
	_refresh_battle_ui()
	call_deferred("_grab_initial_focus")


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is not InputEventKey
		or not event.pressed
		or event.echo
		or not event.is_action_pressed("ui_cancel")
	):
		return
	if exit_confirmation.visible:
		cancel_exit_confirmation()
		get_viewport().set_input_as_handled()
		return
	if request_exit_or_return():
		get_viewport().set_input_as_handled()
		return
	if (
		request != null
		and request.phase == BattleRequest.PHASE_RESULT_PENDING
	):
		get_viewport().set_input_as_handled()
		return
	if exit_input_blocker.visible or result_input_blocker.visible:
		get_viewport().set_input_as_handled()


func configure_formal_city(
	city_scene_value: Node2D,
	city_controller_value: Node,
	committed_count: int
) -> void:
	formal_city_mode = true
	city_scene = city_scene_value
	city_controller = city_controller_value
	formal_committed_count = committed_count


## Uses a request already saved by the city departure transaction.  This must
## never rebuild a force snapshot or reserve food a second time.
func configure_formal_expedition(
	city_scene_value: Node2D,
	city_controller_value: Node,
	prepared_request_value: BattleRequest
) -> void:
	formal_city_mode = true
	city_scene = city_scene_value
	city_controller = city_controller_value
	prepared_expedition_request = prepared_request_value
	formal_committed_count = (
		prepared_request_value.committed_force.get_committed_total()
		if prepared_request_value != null
		and prepared_request_value.committed_force != null
		else 0
	)


func configure_noticeboard_mission(
	city_scene_value: Node2D,
	city_controller_value: Node,
	mission_definition_value: MissionDefinition
) -> void:
	formal_city_mode = true
	noticeboard_mission_mode = true
	city_scene = city_scene_value
	city_controller = city_controller_value
	mission_definition = mission_definition_value
	formal_committed_count = (
		mission_definition.committed_count
		if mission_definition != null
		else 0
	)


func _start_battle_from_ui() -> void:
	start_battle(true)


func start_battle(apply_deployment_plan := false) -> bool:
	if request == null:
		return false
	if request.phase == BattleRequest.PHASE_RESERVED:
		if not coordinator.activate_request():
			return false
	elif request.phase != BattleRequest.PHASE_ACTIVE:
		return false
	if coordinator.active_session == null and coordinator.create_session() == null:
		return false
	if not _checkpoint_active_battle_session():
		status_label.text = "战时实例检查点保存失败；请检查存档后重试"
		return false
	start_button.disabled = true
	wartime_plan_panel.visible = false
	for squad_id in _squad_ui:
		_squad_ui[squad_id].route_button.disabled = true
	if (
		apply_deployment_plan
		and not _uses_prepared_expedition()
		and _queue_concentrated_front_assault()
	):
		_append_recent_action("正门集中部署已同步推进，命令将在下一战斗刻生效")
	else:
		_append_recent_action("战斗开始，小队命令将在下一战斗刻生效")
	tick_timer.start()
	_refresh_battle_ui()
	return true


func request_exit_or_return() -> bool:
	if _exit_in_progress or request == null:
		return false
	if request.phase == BattleRequest.PHASE_RESERVED:
		return _return_before_battle()
	if request.phase == BattleRequest.PHASE_ACTIVE:
		return open_exit_confirmation()
	if request.phase == BattleRequest.PHASE_APPLIED:
		return request_return_to_city() != null
	return false


func open_exit_confirmation() -> bool:
	if (
		_exit_in_progress
		or request == null
		or request.phase != BattleRequest.PHASE_ACTIVE
		or exit_confirmation.visible
	):
		return false
	_resume_timer_after_exit_cancel = not tick_timer.is_stopped()
	tick_timer.stop()
	exit_input_blocker.visible = true
	exit_confirmation.visible = true
	exit_cancel_button.grab_focus()
	_set_selected_commands_disabled(true)
	_refresh_exit_ui()
	return true


func cancel_exit_confirmation() -> bool:
	if not exit_confirmation.visible or _exit_in_progress:
		return false
	exit_confirmation.visible = false
	exit_input_blocker.visible = false
	if (
		_resume_timer_after_exit_cancel
		and request != null
		and request.phase == BattleRequest.PHASE_ACTIVE
	):
		tick_timer.start()
	_resume_timer_after_exit_cancel = false
	_refresh_battle_ui()
	exit_button.grab_focus()
	return true


func confirm_exit_as_retreat() -> bool:
	if (
		_exit_in_progress
		or not exit_confirmation.visible
		or request == null
		or request.phase != BattleRequest.PHASE_ACTIVE
		or coordinator.active_session == null
	):
		return false
	_exit_in_progress = true
	_resume_timer_after_exit_cancel = false
	tick_timer.stop()
	exit_confirm_button.disabled = true
	exit_cancel_button.disabled = true
	exit_confirmation.visible = false
	exit_input_blocker.visible = true

	if not coordinator.active_session.request_forced_retreat():
		_fail_exit_as_retreat("全军撤退状态未能建立")
		return false
	var battle_result := coordinator.advance_battle_tick()
	if battle_result == null:
		for squad in coordinator.active_session.squads:
			if int(squad.total_hp) <= 0 or bool(squad.exited):
				continue
			if coordinator.issue_order(
				int(squad.squad_id),
				BattleOrder.Command.RETREAT
			) == null:
				_fail_exit_as_retreat(
					"全军撤退命令未能进入确定性命令队列"
				)
				return false
		for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
			battle_result = coordinator.advance_battle_tick()
			if battle_result != null:
				break
	if battle_result == null:
		_fail_exit_as_retreat("全军撤退未生成正式战果")
		return false

	_show_pending_result(battle_result)
	if confirm_pending_result().is_empty():
		_fail_exit_as_retreat("全军撤退战果未能原子写回城市")
		return false
	if request_return_to_city() == null:
		_fail_exit_as_retreat("全军撤退战果已写回，但返回契约创建失败")
		return false
	return true


func set_squad_route(
	squad_id: int,
	route_id: StringName
) -> bool:
	if _uses_prepared_expedition():
		return false
	if not coordinator.set_squad_route(squad_id, route_id):
		return false
	_append_recent_action(
		"%s改为部署至%s"
		% [
			BattlePresentationModel.squad_name(squad_id),
			_get_route_name(route_id),
		]
	)
	_refresh_battle_ui()
	return true


func _queue_concentrated_front_assault() -> bool:
	if coordinator.active_session == null:
		return false
	var squads: Array = coordinator.active_session.squads
	if squads.is_empty():
		return false
	for squad in squads:
		if StringName(squad.route_id) != CommittedForceSnapshot.FRONT_ROUTE:
			return false
	for squad in squads:
		if coordinator.issue_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		) == null:
			return false
	return true


func issue_squad_order(
	squad_id: int,
	command: BattleOrder.Command
) -> BattleOrder:
	var order := coordinator.issue_order(squad_id, command)
	if order != null:
		_append_recent_action(
			"%s：%s命令已提交"
			% [
				BattlePresentationModel.squad_name(squad_id),
				BattlePresentationModel.command_text(command),
			]
		)
		_refresh_battle_ui()
	return order


func step_battle_for_test(tick_count: int) -> BattleResult:
	tick_timer.stop()
	var result: BattleResult
	for _index in range(tick_count):
		result = _advance_one_tick()
		if result != null:
			break
	return result


func confirm_pending_result() -> Dictionary:
	confirm_button.disabled = true
	var summary := coordinator.confirm_result()
	if summary.is_empty():
		confirm_button.disabled = false
		result_label.text = (
			"战果尚未完成持久化，请重试确认。\n"
			+ "返回城市保持锁定，兵力与奖励不会重复结算。"
		)
		confirm_button.grab_focus()
		return {}
	_confirmed_summary = summary.duplicate(true)
	result_label.text = (
		"%s\n幸存 %d｜伤亡 %d\n%s\n木材 +%d｜粮食 +%d%s%s"
		% [
			_outcome_id_text(StringName(summary.outcome)),
			int(summary.survivor_count),
			int(summary.casualty_count),
			(
				"粮草已于出征确认时扣除 %d"
				% int(summary.get("actual_food_cost", 0))
				if _uses_prepared_expedition()
				else "粮草 -%d" % int(summary.get("actual_food_cost", 0))
			),
			int(summary.accepted_wood_reward),
			int(summary.accepted_food_reward),
			"\n首通奖励已结算"
				if bool(summary.first_clear_granted)
				else "",
			_formation_result_text(summary),
		]
	)
	return_button.visible = true
	return_button.disabled = false
	confirm_button.visible = false
	call_deferred("_focus_control", return_button)
	_refresh_exit_ui()
	return summary


func request_return_to_city() -> ReturnToCityContract:
	var return_to_city := coordinator.request_return_to_city()
	if return_to_city == null:
		return null
	if _return_requested:
		return return_to_city
	_exit_in_progress = true
	_return_requested = true
	exit_button.disabled = true
	return_button.disabled = true
	call_deferred("_complete_return_after_input_guard")
	return return_to_city


func complete_return_for_test(current_frame: int) -> bool:
	if not coordinator.complete_return_to_city(current_frame):
		return false
	result_panel.visible = false
	result_input_blocker.visible = false
	$UI/RootPanel.visible = false
	_restore_city_presentation()
	if formal_city_mode:
		if noticeboard_mission_mode:
			noticeboard_return_completed.emit(
				mission_definition.mission_id,
				_confirmed_summary.duplicate(true)
			)
		else:
			formal_return_completed.emit(_confirmed_summary.duplicate(true))
		queue_free()
	return true


func _return_before_battle() -> bool:
	if _uses_prepared_expedition():
		status_label.text = "出征已确认且粮草已扣除：请开始战斗，或进入战斗后按撤退结算。"
		_append_recent_action("已付费出征不能静默取消，请开始战斗或按撤退结算")
		_refresh_recent_actions()
		return false
	if not coordinator.cancel_request():
		return false
	_exit_in_progress = true
	exit_button.disabled = true
	start_button.disabled = true
	call_deferred("_complete_prebattle_return_after_input_guard")
	return true


func _complete_prebattle_return_after_input_guard() -> void:
	await get_tree().process_frame
	$UI/RootPanel.visible = false
	_restore_city_presentation()
	if formal_city_mode:
		if noticeboard_mission_mode:
			noticeboard_entry_cancelled.emit(
				mission_definition.mission_id
			)
		else:
			formal_entry_cancelled.emit()
		queue_free()


func abort_formal_entry() -> void:
	if not formal_city_mode:
		return
	_restore_city_presentation()
	queue_free()


func _exit_tree() -> void:
	if (
		formal_city_mode
		and is_instance_valid(city_scene)
		and not city_scene.visible
	):
		_restore_city_presentation()


func _complete_return_after_input_guard() -> void:
	var return_to_city := coordinator.return_contract
	while (
		return_to_city != null
		and Engine.get_process_frames()
			< return_to_city.city_input_restore_frame
	):
		await get_tree().process_frame
	complete_return_for_test(Engine.get_process_frames())


func _fail_exit_as_retreat(message: String) -> void:
	push_error(message)
	_exit_in_progress = false
	exit_input_blocker.visible = false
	exit_confirmation.visible = false
	exit_confirm_button.disabled = false
	exit_cancel_button.disabled = false
	_refresh_exit_ui()


func _create_city_fixture() -> void:
	city_scene = CITY_SCENE.instantiate()
	city_container.add_child(city_scene)
	city_controller = city_scene.get_node("ConstructionController")
	city_ui = city_scene.get_node("UI")
	city_camera = city_scene.get_node("Camera2D")
	city_controller.infantry_count = DEBUG_PLAYER_COUNT
	city_ui.visible = false
	city_camera.enabled = false
	city_scene.visible = false
	city_scene.process_mode = Node.PROCESS_MODE_DISABLED
	coordinator.configure(city_controller)


func _prepare_formal_city() -> void:
	if city_scene == null or city_controller == null:
		push_error("C0 formal city entry is missing the authoritative city")
		return
	city_ui = city_scene.get_node("UI") as CanvasLayer
	city_camera = city_scene.get_node("Camera2D") as Camera2D
	# A hidden city Control must not remain the viewport focus owner. Releasing
	# it before hiding the city lets the battle modal establish a real keyboard
	# focus chain instead of leaving input on an invisible governance button.
	get_viewport().gui_release_focus()
	city_ui.visible = false
	city_camera.enabled = false
	city_scene.visible = false
	city_scene.process_mode = Node.PROCESS_MODE_DISABLED
	coordinator.configure(city_controller)


func _restore_city_presentation() -> void:
	if (
		not is_instance_valid(city_scene)
		or not is_instance_valid(city_ui)
		or not is_instance_valid(city_camera)
	):
		return
	city_ui.visible = true
	city_scene.visible = true
	city_scene.process_mode = Node.PROCESS_MODE_INHERIT
	city_camera.enabled = true
	city_camera.make_current()


func _create_battle_request() -> void:
	if prepared_expedition_request != null:
		if coordinator.has_method("adopt_expedition_request"):
			if coordinator.adopt_expedition_request(prepared_expedition_request):
				request = coordinator.active_request
				return
		push_error("C0 formal expedition coordinator rejected prepared request")
		return
	request = coordinator.create_request(
		formal_committed_count if formal_city_mode else DEBUG_PLAYER_COUNT,
		(
			mission_definition.mission_id
			if noticeboard_mission_mode
			else CombatTransactionCoordinator.DEFAULT_LEVEL_ID
		),
		formal_city_mode and not noticeboard_mission_mode,
		mission_definition
	)
	if request == null:
		push_error("C0 graybox failed to create battle request")


func _create_squad_controls() -> void:
	if request == null:
		return
	for squad_snapshot in request.committed_force.squads:
		var squad_id := int(squad_snapshot.squad_id)
		var panel := VBoxContainer.new()
		panel.name = "Squad%d" % squad_id
		panel.custom_minimum_size = Vector2(134.0, 148.0)
		squad_controls.add_child(panel)

		var select_button := Button.new()
		select_button.name = "SelectButton"
		select_button.custom_minimum_size = Vector2(0.0, 44.0)
		select_button.text = str(
			squad_snapshot.get(
				"display_name",
				BattlePresentationModel.squad_name(squad_id)
			)
		)
		select_button.pressed.connect(select_squad.bind(squad_id))
		panel.add_child(select_button)

		var status := Label.new()
		status.name = "Status"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size = Vector2(130.0, 48.0)
		panel.add_child(status)

		var route_button := Button.new()
		route_button.name = "RouteButton"
		route_button.custom_minimum_size = Vector2(0.0, 44.0)
		route_button.pressed.connect(_on_route_button_pressed.bind(squad_id))
		if _uses_prepared_expedition():
			route_button.disabled = true
			route_button.tooltip_text = "正式出征的部署已在确认时锁定"
		panel.add_child(route_button)

		_squad_ui[squad_id] = {
			"status": status,
			"route_button": route_button,
			"select_button": select_button,
		}

		var marker := Button.new()
		marker.name = "SquadMarker%d" % squad_id
		marker.size = Vector2(84.0, 54.0)
		marker.custom_minimum_size = Vector2(84.0, 54.0)
		marker.theme_type_variation = &"PrimaryButton"
		marker.text = select_button.text
		marker.pressed.connect(select_squad.bind(squad_id))
		marker_layer.add_child(marker)
		_squad_markers[squad_id] = marker
		if _selected_squad_id < 0:
			_selected_squad_id = squad_id


func _on_route_button_pressed(squad_id: int) -> void:
	if (
		_uses_prepared_expedition()
		or request == null
		or request.phase != BattleRequest.PHASE_RESERVED
	):
		return
	for squad in request.committed_force.squads:
		if int(squad.squad_id) != squad_id:
			continue
		var next_route := (
			CommittedForceSnapshot.SIDE_ROUTE
			if StringName(squad.route_id)
				== CommittedForceSnapshot.FRONT_ROUTE
			else CommittedForceSnapshot.FRONT_ROUTE
		)
		set_squad_route(squad_id, next_route)
		return


func select_squad(squad_id: int) -> bool:
	if not _squad_ui.has(squad_id):
		return false
	_selected_squad_id = squad_id
	_refresh_battle_ui()
	return true


func _issue_selected_order(command: BattleOrder.Command) -> void:
	if (
		_selected_squad_id < 0
		or _exit_in_progress
		or exit_confirmation.visible
		or request == null
		or request.phase != BattleRequest.PHASE_ACTIVE
	):
		return
	issue_squad_order(_selected_squad_id, command)


func _on_tick_timeout() -> void:
	_advance_one_tick()


func _advance_one_tick() -> BattleResult:
	var prior_session_snapshot: Dictionary = (
		coordinator.active_session.get_snapshot()
		if coordinator.active_session != null
		else {}
	)
	var battle_result := coordinator.advance_battle_tick()
	if battle_result == null and coordinator.active_session != null:
		if not _checkpoint_active_battle_session():
			coordinator.active_session.restore_snapshot(prior_session_snapshot)
			status_label.text = "战时实例检查点保存失败；本战斗刻未提交"
			_refresh_battle_ui()
			return null
	if battle_result != null and city_controller != null and city_controller.has_method("clear_active_battle_session_checkpoint"):
		city_controller.clear_active_battle_session_checkpoint(request.transaction_id)
	_refresh_battle_ui()
	if battle_result != null:
		tick_timer.stop()
		_show_pending_result(battle_result)
	return battle_result


func _resume_active_battle_if_available() -> void:
	if (
		request == null
		or request.phase != BattleRequest.PHASE_ACTIVE
		or coordinator.active_session != null
	):
		return
	if coordinator.create_session() == null:
		push_error("C0 failed to reconstruct active battle session")
		return
	var attempt: Dictionary = (
		city_controller.get_expedition_attempt()
		if city_controller != null and city_controller.has_method("get_expedition_attempt")
		else {}
	)
	var snapshot: Dictionary = Dictionary(
		attempt.get("battle_session_snapshot", {})
	)
	if not snapshot.is_empty() and not coordinator.active_session.restore_snapshot(snapshot):
		push_error("C0 active battle session snapshot rejected")
		return
	tick_timer.start()
	_append_recent_action(
		"已恢复第 %d 战斗刻" % coordinator.active_session.current_tick
	)


func _checkpoint_active_battle_session() -> bool:
	if (
		not _uses_prepared_expedition()
		or city_controller == null
		or request == null
		or coordinator.active_session == null
		or not city_controller.has_method("checkpoint_active_battle_session")
	):
		return true
	var result: Dictionary = city_controller.checkpoint_active_battle_session(
		request.transaction_id,
		coordinator.active_session.get_snapshot()
	)
	return bool(result.get("success", false))


func _refresh_battle_ui() -> void:
	if request == null:
		status_label.text = "战斗请求创建失败"
		_refresh_exit_ui()
		return
	var next_snapshot := BattlePresentationModel.build_snapshot(
		request,
		coordinator.active_session,
		mission_definition,
		_selected_squad_id
	)
	_capture_presentation_changes(_presentation_snapshot, next_snapshot)
	_presentation_snapshot = next_snapshot
	title_label.text = str(next_snapshot.title)
	status_label.text = (
		"战前部署 · 参战 %d 人 · 粮草已锁定 %d"
		% [
			request.committed_force.get_committed_total(),
			request.committed_food_cost,
		]
		if request.phase == BattleRequest.PHASE_RESERVED
		else "%s · %.1f 秒" % [
			str(next_snapshot.phase_text),
			float(next_snapshot.elapsed_seconds),
		]
	)
	var objective_text := str(next_snapshot.objective_text)
	if mission_definition == null:
		objective_text = "突破任一城门并击溃该路线守军"
	instruction_label.text = "目标：%s｜%s" % [
		objective_text,
		str(next_snapshot.objective.progress_text),
	]
	var routes: Array = next_snapshot.routes
	_refresh_route_ui(
		routes[0],
		front_route_name_label,
		front_state_label,
		front_enemy_marker,
		front_enemy_count_label,
		front_gate,
		next_snapshot.objective
	)
	_refresh_route_ui(
		routes[1],
		side_route_name_label,
		side_state_label,
		side_enemy_marker,
		side_enemy_count_label,
		side_gate,
		next_snapshot.objective
	)
	for state in next_snapshot.squads:
		var squad_id := int(state.squad_id)
		_squad_ui[squad_id].status.text = "%d/%d 人\n%s" % [
			int(state.alive_members),
			int(state.initial_members),
			str(state.state_text),
		]
		_squad_ui[squad_id].route_button.text = (
			"%s（部署已锁定）" % str(state.route_name)
			if _uses_prepared_expedition()
			else str(state.route_name)
		)
		_squad_ui[squad_id].route_button.visible = request.phase == BattleRequest.PHASE_RESERVED
		_squad_ui[squad_id].route_button.disabled = _uses_prepared_expedition()
		_squad_ui[squad_id].select_button.text = (
			"▶ %s" % str(state.name)
			if bool(state.selected)
			else str(state.name)
		)
		_update_marker(state)
	_refresh_selected_squad(next_snapshot)
	_refresh_mission_objects(next_snapshot.objective)
	start_button.visible = request.phase == BattleRequest.PHASE_RESERVED
	_refresh_wartime_plan_ui()
	_refresh_recent_actions()
	_refresh_exit_ui()


func _refresh_wartime_plan_ui() -> void:
	if request == null:
		wartime_plan_panel.visible = false
		battlefield_panel.offset_bottom = -202.0
		return
	var can_edit := (
		_uses_prepared_expedition()
		and request.phase == BattleRequest.PHASE_RESERVED
	)
	wartime_plan_panel.visible = can_edit
	battlefield_panel.offset_bottom = -300.0 if can_edit else -202.0
	if not can_edit:
		return
	var saved_plan: Dictionary = request.wartime_facility_plan
	var is_committed := not Array(saved_plan.get("facilities", [])).is_empty()
	var pending_plan: Dictionary = (
		saved_plan if is_committed else _pending_wartime_facility_plan
	)
	var has_watch := WartimeFacilityPlan.has_kind(
		pending_plan, WartimeFacilityPlan.KIND_WATCH_PLATFORM
	)
	var has_ram := WartimeFacilityPlan.has_kind(
		pending_plan, WartimeFacilityPlan.KIND_SIEGE_RAM
	)
	wartime_watch_button.text = (
		"瞭望台 · 已选" if has_watch else "瞭望台 · 木材 6"
	)
	wartime_ram_button.text = (
		"攻城槌 · 已选" if has_ram else "攻城槌 · 木材 8"
	)
	wartime_watch_button.disabled = is_committed
	wartime_ram_button.disabled = is_committed
	wartime_plan_confirm_button.visible = not is_committed
	wartime_plan_confirm_button.disabled = (
		Array(pending_plan.get("facilities", [])).is_empty()
	)
	if is_committed:
		wartime_plan_panel.get_node("Title").text = "战时工事已确认（仅本次战斗）"
	else:
		wartime_plan_panel.get_node("Title").text = "战时工事（仅本次战斗）"


func _toggle_wartime_facility(kind: StringName) -> void:
	if (
		request == null
		or request.phase != BattleRequest.PHASE_RESERVED
		or not _uses_prepared_expedition()
		or not Array(request.wartime_facility_plan.get("facilities", [])).is_empty()
	):
		return
	var facilities: Array = Array(
		_pending_wartime_facility_plan.get("facilities", [])
	).duplicate(true)
	var remaining: Array[Dictionary] = []
	var removed := false
	for facility_value in facilities:
		var facility: Dictionary = facility_value
		if StringName(facility.get("kind", &"")) == kind:
			removed = true
			continue
		remaining.append(facility)
	if not removed:
		remaining.append(WartimeFacilityPlan.make_facility(
			kind, CommittedForceSnapshot.FRONT_ROUTE
		))
	_pending_wartime_facility_plan = {
		"schema_version": WartimeFacilityPlan.SCHEMA_VERSION,
		"facilities": remaining,
	}
	_refresh_battle_ui()


func _confirm_wartime_facility_plan() -> void:
	if (
		city_controller == null
		or request == null
		or not city_controller.has_method("commit_wartime_facility_plan")
	):
		return
	var result: Dictionary = city_controller.commit_wartime_facility_plan(
		request.transaction_id,
		_pending_wartime_facility_plan
	)
	if not bool(result.get("success", false)):
		status_label.text = str(result.get("error", "战时工事确认失败"))
		_append_recent_action(status_label.text)
		_refresh_recent_actions()
		return
	request.wartime_facility_plan = Dictionary(result.plan).duplicate(true)
	_pending_wartime_facility_plan = request.wartime_facility_plan.duplicate(true)
	_append_recent_action("战时工事已确认，资源已一次性扣除")
	_refresh_battle_ui()


func _refresh_exit_ui() -> void:
	if request == null:
		exit_button.text = "返回内城"
		exit_button.disabled = true
		return
	if request.phase == BattleRequest.PHASE_RESERVED:
		exit_button.text = (
			"出征已确认"
			if _uses_prepared_expedition()
			else "返回内城"
		)
	elif request.phase == BattleRequest.PHASE_ACTIVE:
		exit_button.text = "退出战斗"
	elif request.phase == BattleRequest.PHASE_RESULT_PENDING:
		exit_button.text = "请先确认战果"
	elif request.phase == BattleRequest.PHASE_APPLIED:
		exit_button.text = "返回内城"
	else:
		exit_button.text = "正在返回"
	exit_button.disabled = (
		_exit_in_progress
		or exit_confirmation.visible
		or request.phase == BattleRequest.PHASE_RESULT_PENDING
		or request.phase == BattleRequest.PHASE_CANCELLED
	)


func _refresh_route_ui(
	route: Dictionary,
	name_label: Label,
	state_label: Label,
	enemy_marker: Panel,
	enemy_count_label: Label,
	gate: ColorRect,
	objective: Dictionary
) -> void:
	name_label.text = str(route.name)
	var threatens_wagon := (
		bool(objective.get("show_wagon", false))
		and str(route.name) in Array(
			objective.get("attacking_routes", [])
		)
	)
	enemy_count_label.text = "敌军 %d\n%s" % [
		int(route.enemy_count),
		(
			"已肃清"
			if int(route.enemy_count) <= 0
			else (
				"攻击粮车"
				if threatens_wagon
				else (
					"接战中"
					if not Array(route.engaged_squad_ids).is_empty()
					else "据守"
				)
			)
		),
	]
	enemy_marker.visible = int(route.enemy_count) > 0
	gate.visible = bool(route.has_obstacle) and int(route.gate_hp) > 0
	state_label.text = (
		"%s · 障碍 %d/%d"
		% [
			str(route.enemy_status),
			int(route.gate_hp),
			int(route.gate_max_hp),
		]
		if bool(route.has_obstacle)
		else (
			"正在威胁粮车"
			if threatens_wagon
			else str(route.enemy_status)
		)
	)


func _update_marker(state: Dictionary) -> void:
	var squad_id := int(state.squad_id)
	var marker := _squad_markers[squad_id] as Button
	var lane := (
		$UI/RootPanel/FrontLane as ColorRect
		if StringName(state.route_id)
			== CommittedForceSnapshot.FRONT_ROUTE
		else $UI/RootPanel/SideLane as ColorRect
	)
	var position_ratio := float(state.position_ratio)
	var formation_offset := (
		float((squad_id - 1) * 68)
		if position_ratio <= 0.02
		else 0.0
	)
	var travel_width := maxf(lane.size.x - 210.0, 240.0)
	marker.position = Vector2(
		lane.position.x + 8.0 + travel_width * position_ratio
			+ formation_offset,
		lane.position.y + 10.0
	)
	marker.text = "%s\n%d/%d" % [
		str(state.name),
		int(state.alive_members),
		int(state.initial_members),
	]
	marker.modulate = (
		Color(1.0, 0.84, 0.43, 1.0)
		if bool(state.selected)
		else Color(0.82, 0.86, 0.78, 1.0)
	)
	marker.visible = int(state.alive_members) > 0 and str(state.state_text) != "已撤离"


func _refresh_selected_squad(snapshot: Dictionary) -> void:
	var selected: Dictionary = {}
	for state in snapshot.squads:
		if int(state.squad_id) == _selected_squad_id:
			selected = state
			break
	if selected.is_empty():
		selected_squad_title.text = "当前小队：未选择"
		selected_squad_state.text = "点击战场中的小队标记"
		_set_selected_commands_disabled(true)
		return
	selected_squad_title.text = "当前小队：%s" % str(selected.name)
	selected_squad_state.text = "%s｜%d/%d 人\n%s｜命令：%s" % [
		str(selected.route_name),
		int(selected.alive_members),
		int(selected.initial_members),
		str(selected.state_text),
		str(selected.command_text),
	]
	_set_selected_commands_disabled(not bool(selected.command_enabled))


func _refresh_mission_objects(objective: Dictionary) -> void:
	wagon_panel.visible = bool(objective.get("show_wagon", false))
	front_search_zone.visible = false
	side_search_zone.visible = false
	extraction_zone.visible = false
	if wagon_panel.visible:
		var hp := int(objective.get("wagon_hp", 0))
		var max_hp := maxi(int(objective.get("wagon_max_hp", 1)), 1)
		wagon_label.text = "%s %d/%d%s" % [
			str(objective.get("wagon_name", "护送目标")),
			hp,
			max_hp,
			(
				" · 已被摧毁"
				if bool(objective.get("failed", false))
				else (
					" · 遭受威胁"
					if bool(objective.get("wagon_danger", false))
					else " · 安全"
				)
			),
		]
		wagon_health.max_value = max_hp
		wagon_health.value = hp
	if bool(objective.get("show_search", false)):
		front_search_zone.visible = true
		side_search_zone.visible = true
		extraction_zone.visible = true
		var zones: Array = objective.get("search_zones", [])
		for zone in zones:
			var panel := (
				front_search_zone
				if StringName(zone.route_id)
					== CommittedForceSnapshot.FRONT_ROUTE
				else side_search_zone
			)
			var label := panel.get_node("Label") as Label
			label.text = str(zone.label)
		extraction_zone.get_node("Label").text = (
			"已安全撤离"
			if bool(objective.get("extraction_reached", false))
			else "安全撤离区"
		)


func _set_selected_commands_disabled(disabled: bool) -> void:
	selected_advance_button.disabled = disabled
	selected_hold_button.disabled = disabled
	selected_retreat_button.disabled = disabled


func _capture_presentation_changes(
	previous: Dictionary,
	current: Dictionary
) -> void:
	if previous.is_empty() or current.is_empty():
		return
	var previous_routes := _index_by(previous.routes, "route_id")
	for route in current.routes:
		var before: Dictionary = previous_routes.get(route.route_id, {})
		if (
			not before.is_empty()
			and int(before.enemy_count) != int(route.enemy_count)
		):
			_append_recent_action(
				"%s敌军：%d → %d"
				% [
					str(route.name),
					int(before.enemy_count),
					int(route.enemy_count),
				]
			)
		if (
			not before.is_empty()
			and int(before.gate_hp) != int(route.gate_hp)
		):
			_append_recent_action(
				"%s障碍：%d → %d"
				% [
					str(route.name),
					int(before.gate_hp),
					int(route.gate_hp),
				]
			)
	var previous_squads := _index_by(previous.squads, "squad_id")
	for squad in current.squads:
		var before_squad: Dictionary = previous_squads.get(
			squad.squad_id,
			{}
		)
		if (
			not before_squad.is_empty()
			and int(before_squad.alive_members)
				!= int(squad.alive_members)
		):
			_append_recent_action(
				"%s兵力：%d → %d"
				% [
					str(squad.name),
					int(before_squad.alive_members),
					int(squad.alive_members),
				]
			)
		if (
			not before_squad.is_empty()
			and str(before_squad.state_text) != str(squad.state_text)
			and str(squad.state_text) in [
				"接敌中",
				"已撤离",
				"失去战斗能力",
			]
		):
			_append_recent_action(
				"%s：%s" % [str(squad.name), str(squad.state_text)]
			)
	var before_objective: Dictionary = previous.objective
	var current_objective: Dictionary = current.objective
	if (
		bool(current_objective.get("show_wagon", false))
		and int(before_objective.get("wagon_hp", -1))
			!= int(current_objective.get("wagon_hp", -1))
	):
		_append_recent_action(
			"粮车受损：%d → %d"
			% [
				int(before_objective.get("wagon_hp", 0)),
				int(current_objective.get("wagon_hp", 0)),
			]
		)
	if (
		not bool(before_objective.get("scout_found", false))
		and bool(current_objective.get("scout_found", false))
	):
		_append_recent_action("已找到失踪斥候，立即向撤离区返回")


func _index_by(items: Array, key: String) -> Dictionary:
	var indexed := {}
	for item in items:
		indexed[item.get(key)] = item
	return indexed


func _append_recent_action(message: String) -> void:
	if message.is_empty():
		return
	if not _recent_actions.is_empty() and _recent_actions[-1] == message:
		return
	_recent_actions.append(message)
	while _recent_actions.size() > 3:
		_recent_actions.pop_front()


func _refresh_recent_actions() -> void:
	var lines: Array[String] = ["最近战况"]
	for message in _recent_actions:
		lines.append("· %s" % message)
	recent_actions_label.text = "\n".join(lines)


func _get_route_name(route_id: StringName) -> String:
	if mission_definition != null:
		return (
			mission_definition.front_route_name
			if route_id == CommittedForceSnapshot.FRONT_ROUTE
			else mission_definition.side_route_name
		)
	return (
		"正门路线"
		if route_id == CommittedForceSnapshot.FRONT_ROUTE
		else "侧门路线"
	)


func _show_pending_result(battle_result: BattleResult) -> void:
	exit_confirmation.visible = false
	exit_input_blocker.visible = false
	result_input_blocker.visible = true
	result_panel.visible = true
	confirm_button.visible = true
	confirm_button.disabled = false
	return_button.visible = false
	return_button.disabled = true
	result_label.text = (
		"%s\n第 %d 战斗刻｜幸存 %d｜伤亡 %d\n%s\n确认后写回城市%s"
		% [
			_outcome_text(battle_result.outcome),
			battle_result.finished_tick,
			battle_result.survivor_count,
			battle_result.casualty_count,
			(
				"粮草已于出征确认时扣除"
				if _uses_prepared_expedition()
				else "确认后结算粮草与伤亡"
			),
			_formation_result_text_from_result(battle_result),
		]
	)
	_append_recent_action("战斗结束：%s" % _outcome_text(battle_result.outcome))
	_set_selected_commands_disabled(true)
	call_deferred("_focus_control", confirm_button)
	_refresh_exit_ui()


func _grab_initial_focus() -> void:
	if is_instance_valid(start_button) and start_button.visible:
		_focus_control(start_button)


func _focus_control(control: Control) -> void:
	if not is_instance_valid(control) or not control.visible or control.disabled:
		return
	var previous_owner := get_viewport().gui_get_focus_owner()
	if is_instance_valid(previous_owner):
		previous_owner.release_focus()
	get_viewport().gui_release_focus()
	control.focus_mode = Control.FOCUS_ALL
	control.grab_focus()


func _apply_northern_visual_palette() -> void:
	$UI/RootPanel.color = NORTHERN_PALETTE.INK_BLUE
	$UI/RootPanel/TopBar.color = NORTHERN_PALETTE.INK_TEAL
	$UI/RootPanel/SideLane.color = Color(
		NORTHERN_PALETTE.ROAD_DUST.r,
		NORTHERN_PALETTE.ROAD_DUST.g,
		NORTHERN_PALETTE.ROAD_DUST.b,
		0.24
	)
	$UI/RootPanel/FrontLane.color = NORTHERN_PALETTE.with_alpha(
		NORTHERN_PALETTE.ROAD_SURFACE,
		0.28
	)
	front_gate.color = Color.TRANSPARENT
	side_gate.color = Color.TRANSPARENT


func _uses_prepared_expedition() -> bool:
	return prepared_expedition_request != null and not noticeboard_mission_mode


func _formation_result_text(summary: Dictionary) -> String:
	return _formation_result_text_from_rows(
		Array(summary.get("formation_results", []))
	)


func _formation_result_text_from_result(battle_result: BattleResult) -> String:
	if battle_result == null:
		return ""
	return _formation_result_text_from_rows(battle_result.formation_results)


func _formation_result_text_from_rows(rows: Array) -> String:
	if rows.is_empty():
		return ""
	var names: Dictionary = {}
	if request != null and request.committed_force != null:
		for squad in request.committed_force.squads:
			names[StringName(squad.get("formation_id", &""))] = str(
				squad.get("display_name", BattlePresentationModel.squad_name(int(squad.squad_id)))
		)
	var lines: Array[String] = ["编队结算"]
	for row in rows:
		var formation_id := StringName(row.get("formation_id", &""))
		var display_name := str(names.get(formation_id, formation_id))
		lines.append("%s：%d/%d" % [
			display_name,
			int(row.get("survivor_count", 0)),
			int(row.get("departure_count", 0)),
		])
	return "\n" + "\n".join(lines)


func _outcome_text(outcome: BattleOutcome.Value) -> String:
	if outcome == BattleOutcome.Value.VICTORY:
		return "胜利"
	if outcome == BattleOutcome.Value.RETREAT:
		return "主动撤退"
	return "失败"


func _outcome_id_text(outcome: StringName) -> String:
	if outcome == &"VICTORY":
		return "胜利"
	if outcome == &"RETREAT":
		return "主动撤退"
	return "失败"
