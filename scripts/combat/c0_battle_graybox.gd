class_name C0BattleGraybox
extends Node2D


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const DEBUG_PLAYER_COUNT := 50

@onready var coordinator: CombatTransactionCoordinator = (
	$CombatTransactionCoordinator
)
@onready var city_container: Node2D = $CityContainer
@onready var tick_timer: Timer = $TickTimer
@onready var status_label: Label = $UI/RootPanel/StatusLabel
@onready var front_state_label: Label = (
	$UI/RootPanel/FrontLane/StateLabel
)
@onready var side_state_label: Label = (
	$UI/RootPanel/SideLane/StateLabel
)
@onready var start_button: Button = $UI/RootPanel/StartButton
@onready var squad_controls: HBoxContainer = (
	$UI/RootPanel/SquadControls
)
@onready var marker_layer: Control = $UI/RootPanel/MarkerLayer
@onready var result_input_blocker: ColorRect = (
	$UI/RootPanel/ResultInputBlocker
)
@onready var result_panel: Panel = $UI/RootPanel/ResultPanel
@onready var result_label: Label = (
	$UI/RootPanel/ResultPanel/ResultLabel
)
@onready var confirm_button: Button = (
	$UI/RootPanel/ResultPanel/ConfirmButton
)
@onready var return_button: Button = (
	$UI/RootPanel/ResultPanel/ReturnButton
)

var city_scene: Node2D
var city_controller: Node
var city_ui: CanvasLayer
var city_camera: Camera2D
var request: BattleRequest
var _squad_ui: Dictionary = {}
var _squad_markers: Dictionary = {}


func _ready() -> void:
	tick_timer.timeout.connect(_on_tick_timeout)
	start_button.pressed.connect(start_battle)
	confirm_button.pressed.connect(confirm_pending_result)
	return_button.pressed.connect(request_return_to_city)
	_create_city_fixture()
	_create_battle_request()
	_create_squad_controls()
	_refresh_battle_ui()


func start_battle() -> bool:
	if (
		request == null
		or request.phase != BattleRequest.PHASE_RESERVED
		or not coordinator.activate_request()
		or coordinator.create_session() == null
	):
		return false
	start_button.disabled = true
	for squad_id in _squad_ui:
		_squad_ui[squad_id].route_button.disabled = true
		_set_command_buttons_disabled(int(squad_id), false)
	tick_timer.start()
	_refresh_battle_ui()
	return true


func set_squad_route(
	squad_id: int,
	route_id: StringName
) -> bool:
	if not coordinator.set_squad_route(squad_id, route_id):
		return false
	_refresh_battle_ui()
	return true


func issue_squad_order(
	squad_id: int,
	command: BattleOrder.Command
) -> BattleOrder:
	var order := coordinator.issue_order(squad_id, command)
	if order != null:
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
		return {}
	result_label.text = (
		"%s\n幸存 %d｜伤亡 %d\n木材 +%d｜粮食 +%d%s"
		% [
			str(summary.outcome),
			int(summary.survivor_count),
			int(summary.casualty_count),
			int(summary.accepted_wood_reward),
			int(summary.accepted_food_reward),
			"\n首通奖励已结算"
				if bool(summary.first_clear_granted)
				else "",
		]
	)
	return_button.visible = true
	return_button.disabled = false
	return summary


func request_return_to_city() -> ReturnToCityContract:
	var return_to_city := coordinator.request_return_to_city()
	if return_to_city == null:
		return null
	return_button.disabled = true
	call_deferred("_complete_return_after_input_guard")
	return return_to_city


func complete_return_for_test(current_frame: int) -> bool:
	if not coordinator.complete_return_to_city(current_frame):
		return false
	result_panel.visible = false
	result_input_blocker.visible = false
	$UI/RootPanel.visible = false
	city_ui.visible = true
	city_scene.visible = true
	city_scene.process_mode = Node.PROCESS_MODE_INHERIT
	city_camera.enabled = true
	city_camera.make_current()
	return true


func _complete_return_after_input_guard() -> void:
	var return_to_city := coordinator.return_contract
	while (
		return_to_city != null
		and Engine.get_process_frames()
			< return_to_city.city_input_restore_frame
	):
		await get_tree().process_frame
	complete_return_for_test(Engine.get_process_frames())


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


func _create_battle_request() -> void:
	request = coordinator.create_request(DEBUG_PLAYER_COUNT)
	if request == null:
		push_error("C0 graybox failed to create battle request")


func _create_squad_controls() -> void:
	if request == null:
		return
	for squad_snapshot in request.committed_force.squads:
		var squad_id := int(squad_snapshot.squad_id)
		var panel := VBoxContainer.new()
		panel.name = "Squad%d" % squad_id
		panel.custom_minimum_size = Vector2(340.0, 104.0)
		squad_controls.add_child(panel)

		var status := Label.new()
		status.name = "Status"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(status)

		var route_button := Button.new()
		route_button.name = "RouteButton"
		route_button.pressed.connect(_on_route_button_pressed.bind(squad_id))
		panel.add_child(route_button)

		var actions := HBoxContainer.new()
		actions.name = "Actions"
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(actions)
		var advance_button := _add_command_button(
			actions,
			"AdvanceButton",
			"前进",
			squad_id,
			BattleOrder.Command.ADVANCE
		)
		var hold_button := _add_command_button(
			actions,
			"HoldButton",
			"坚守",
			squad_id,
			BattleOrder.Command.HOLD
		)
		var retreat_button := _add_command_button(
			actions,
			"RetreatButton",
			"撤退",
			squad_id,
			BattleOrder.Command.RETREAT
		)
		_squad_ui[squad_id] = {
			"status": status,
			"route_button": route_button,
			"advance_button": advance_button,
			"hold_button": hold_button,
			"retreat_button": retreat_button,
		}
		_set_command_buttons_disabled(squad_id, true)

		var marker := ColorRect.new()
		marker.name = "SquadMarker%d" % squad_id
		marker.size = Vector2(26.0, 26.0)
		marker.color = Color(0.77, 0.67, 0.38, 1.0)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marker_text := Label.new()
		marker_text.text = str(squad_id)
		marker_text.size = marker.size
		marker_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(marker_text)
		marker_layer.add_child(marker)
		_squad_markers[squad_id] = marker


func _add_command_button(
	parent: HBoxContainer,
	node_name: String,
	text_value: String,
	squad_id: int,
	command: BattleOrder.Command
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(92.0, 32.0)
	button.pressed.connect(_on_command_button_pressed.bind(squad_id, command))
	parent.add_child(button)
	return button


func _on_route_button_pressed(squad_id: int) -> void:
	if request == null or request.phase != BattleRequest.PHASE_RESERVED:
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


func _on_command_button_pressed(
	squad_id: int,
	command: BattleOrder.Command
) -> void:
	issue_squad_order(squad_id, command)


func _on_tick_timeout() -> void:
	_advance_one_tick()


func _advance_one_tick() -> BattleResult:
	var battle_result := coordinator.advance_battle_tick()
	_refresh_battle_ui()
	if battle_result != null:
		tick_timer.stop()
		_show_pending_result(battle_result)
	return battle_result


func _refresh_battle_ui() -> void:
	if request == null:
		status_label.text = "C0 Battle Graybox · 请求创建失败"
		return
	var tick := (
		coordinator.active_session.current_tick
		if coordinator.active_session != null
		else 0
	)
	status_label.text = (
		"C0 Battle Graybox · %s · Tick %d · %.2fs"
		% [
			str(request.phase),
			tick,
			float(tick * BattleSession.TICK_MILLISECONDS) / 1000.0,
		]
	)
	var front := _get_display_route_state(
		CommittedForceSnapshot.FRONT_ROUTE
	)
	var side := _get_display_route_state(
		CommittedForceSnapshot.SIDE_ROUTE
	)
	front_state_label.text = "正门｜门 HP %d｜守军 %d" % [
		int(front.gate_hp),
		int(front.enemy_members),
	]
	side_state_label.text = "侧门｜门 HP %d｜守军 %d" % [
		int(side.gate_hp),
		int(side.enemy_members),
	]
	for squad_snapshot in request.committed_force.squads:
		var squad_id := int(squad_snapshot.squad_id)
		var state := _get_display_squad_state(squad_snapshot)
		var route_name := (
			"正门"
			if StringName(state.route_id)
				== CommittedForceSnapshot.FRONT_ROUTE
			else "侧门"
		)
		_squad_ui[squad_id].status.text = (
			"小队 %d｜人数 %d｜%s"
			% [squad_id, int(state.alive_members), str(state.command_name)]
		)
		_squad_ui[squad_id].route_button.text = "路线：%s（战前可切换）" % (
			route_name
		)
		_update_marker(squad_id, state)


func _get_display_route_state(route_id: StringName) -> Dictionary:
	if coordinator.active_session == null:
		var initial: Dictionary = request.enemy_force.route_states[route_id]
		return {
			"gate_hp": int(initial.gate_hp),
			"enemy_members": int(initial.enemy_members),
		}
	var route := coordinator.active_session.get_route_state(route_id)
	return {
		"gate_hp": int(route.gate_hp),
		"enemy_members": _alive_members_for_ui(int(route.enemy_total_hp)),
	}


func _get_display_squad_state(snapshot: Dictionary) -> Dictionary:
	if coordinator.active_session == null:
		return {
			"route_id": StringName(snapshot.route_id),
			"alive_members": int(snapshot.initial_members),
			"position_fixed": 0,
			"command_name": "待命",
			"exited": false,
		}
	var state := coordinator.active_session.get_squad_state(
		int(snapshot.squad_id)
	)
	return {
		"route_id": StringName(state.route_id),
		"alive_members": _alive_members_for_ui(int(state.total_hp)),
		"position_fixed": int(state.position_fixed),
		"command_name": _command_name(int(state.active_order)),
		"exited": bool(state.exited),
	}


func _update_marker(squad_id: int, state: Dictionary) -> void:
	var route_id := StringName(state.route_id)
	var distance := (
		BattleSession.FRONT_DISTANCE_FIXED
		if route_id == CommittedForceSnapshot.FRONT_ROUTE
		else BattleSession.SIDE_DISTANCE_FIXED
	)
	var ratio := clampf(
		float(int(state.position_fixed)) / float(distance),
		0.0,
		1.0
	)
	var marker := _squad_markers[squad_id] as ColorRect
	marker.position = Vector2(
		190.0 + 730.0 * ratio,
		151.0 if route_id == CommittedForceSnapshot.FRONT_ROUTE else 311.0
	) + Vector2(0.0, float((squad_id - 1) * 9))
	marker.visible = not bool(state.exited) and int(state.alive_members) > 0


func _show_pending_result(battle_result: BattleResult) -> void:
	result_input_blocker.visible = true
	result_panel.visible = true
	confirm_button.visible = true
	confirm_button.disabled = false
	return_button.visible = false
	return_button.disabled = true
	result_label.text = (
		"%s\nTick %d｜幸存 %d｜伤亡 %d\n确认后写回城市"
		% [
			BattleOutcome.to_id(battle_result.outcome),
			battle_result.finished_tick,
			battle_result.survivor_count,
			battle_result.casualty_count,
		]
	)
	for squad_id in _squad_ui:
		_set_command_buttons_disabled(int(squad_id), true)


func _set_command_buttons_disabled(squad_id: int, disabled: bool) -> void:
	if not _squad_ui.has(squad_id):
		return
	for key in [
		"advance_button",
		"hold_button",
		"retreat_button",
	]:
		_squad_ui[squad_id][key].disabled = disabled


func _alive_members_for_ui(total_hp: int) -> int:
	if total_hp <= 0:
		return 0
	@warning_ignore("integer_division")
	return (
		total_hp + request.committed_force.hp_per_member - 1
	) / request.committed_force.hp_per_member


func _command_name(command: BattleOrder.Command) -> String:
	if command == BattleOrder.Command.ADVANCE:
		return "前进"
	if command == BattleOrder.Command.RETREAT:
		return "撤退"
	return "坚守"
