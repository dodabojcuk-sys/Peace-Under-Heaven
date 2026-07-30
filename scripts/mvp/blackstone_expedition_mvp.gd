class_name BlackstoneExpeditionMvp
extends Control


signal run_finished(
	outcome: StringName,
	soldiers_remaining: int,
	summary: String
)
signal return_to_city_requested

const NODE_CAMP := &"camp"
const NODE_REINFORCEMENT := &"reinforcement"
const NODE_OUTPOST := &"outpost"
const NODE_FORTRESS := &"fortress"

const OUTCOME_NONE := &"NONE"
const OUTCOME_VICTORY := &"VICTORY"
const OUTCOME_DEFEAT := &"DEFEAT"

const COMMAND_SUPPORT := &"SUPPORT"
const COMMAND_REINFORCE := &"REINFORCE"
const COMMAND_ATTACK := &"ATTACK"

const STATE_IDLE := &"IDLE"
const STATE_SOURCE_ARMED := &"SOURCE_ARMED"
const STATE_ROUTE_SELECTING := &"ROUTE_SELECTING"
const STATE_ORDER_PENDING := &"ORDER_PENDING"
const STATE_MARCHING := &"MARCHING"
const STATE_ARRIVAL_RESOLVING := &"ARRIVAL_RESOLVING"

const OPTION_INFANTRY := &"infantry"

const MODAL_NONE := &"NONE"
const MODAL_RETREAT_CONFIRM := &"RETREAT_CONFIRM"
const MODAL_RESULT := &"RESULT"

const STARTING_SOLDIERS := 10
const REINFORCEMENT_SOLDIERS := 6
const OUTPOST_ENEMIES := 5
const FORTRESS_ENEMIES := 8

const COMMAND_DRAG_THRESHOLD := 8.0
const MIN_TRAVEL_SECONDS := 6.0
const MAX_TRAVEL_SECONDS := 12.0
const MARCH_PIXELS_PER_SECOND := 48.0
const ROUTE_TEXT_CLEARANCE := 8.0

const COLOR_CANVAS := Color("#e9e1cb")
const COLOR_SURFACE := Color("#f6f0e0")
const COLOR_RAISED := Color("#fff9e9")
const COLOR_SUBTLE := Color("#d7cdb4")
const COLOR_STRONG := Color("#282a25")
const COLOR_BORDER := Color("#a79e87")
const COLOR_BORDER_STRONG := Color("#494a42")
const COLOR_PRIMARY := Color("#566243")
const COLOR_PRIMARY_HOVER := Color("#7f8b67")
const COLOR_TEXT_PRIMARY := Color("#282a25")
const COLOR_TEXT_SECONDARY := Color("#716c5e")
const COLOR_TEXT_ON_STRONG := Color("#fff9e9")
const COLOR_SUCCESS := Color("#52725a")
const COLOR_WARNING := Color("#b18a45")
const COLOR_DANGER := Color("#a34a3f")
const COLOR_DANGER_BG := Color("#823b34")
const COLOR_INFO := Color("#4f6b72")
const COLOR_OVERLAY := Color("#1c1e1bb8")

const COMMAND_LINE_VALID_COLOR := COLOR_PRIMARY
const COMMAND_LINE_INVALID_COLOR := COLOR_DANGER
const FRIENDLY_NODE_COLOR := Color.WHITE
const AVAILABLE_NODE_COLOR := Color(0.94, 1.0, 0.9, 1.0)
const VALID_TARGET_COLOR := Color(0.86, 1.0, 0.82, 1.0)
const INVALID_TARGET_COLOR := Color(1.0, 0.85, 0.82, 1.0)

@onready var soldiers_label: Label = $Header/Soldiers
@onready var status_label: Label = $Header/Status
@onready var mission_status_tag: Panel = $MissionPanel/StatusTag
@onready var mission_status_dot: ColorRect = $MissionPanel/StatusTag/Dot
@onready var mission_status_label: Label = $MissionPanel/StatusTag/Label
@onready var mission_body_label: Label = $MissionPanel/Body
@onready var battlefield: Control = $Battlefield
@onready var command_line: Line2D = $Battlefield/CommandLine
@onready var command_arrow: Polygon2D = $Battlefield/CommandArrow
@onready var camp_button: Button = $Battlefield/Camp
@onready var reinforcement_button: Button = $Battlefield/Reinforcement
@onready var outpost_button: Button = $Battlefield/Outpost
@onready var fortress_button: Button = $Battlefield/Fortress
@onready var marching_marker: Node2D = $Battlefield/MarchingArmy
@onready var marching_marker_label: Label = $Battlefield/MarchingArmy/Count
@onready var march_info: Panel = $Battlefield/MarchInfo
@onready var march_info_label: Label = $Battlefield/MarchInfo/Label
@onready var march_state_label: Label = $Battlefield/MarchInfo/StateLabel
@onready var march_percent_label: Label = (
	$Battlefield/MarchInfo/PercentLabel
)
@onready var march_progress_bar: ProgressBar = (
	$Battlefield/MarchInfo/ProgressBar
)
@onready var concurrency_tag: Panel = (
	$Battlefield/MarchInfo/ConcurrencyTag
)
@onready var legend_label: Label = $Battlefield/Legend
@onready var dispatch_bar: Panel = $DispatchBar
@onready var dispatch_route_label: Label = $DispatchBar/Route
@onready var dispatch_details_label: Label = $DispatchBar/Details
@onready var dispatch_close_button: Button = $DispatchBar/CloseButton
@onready var dispatch_percent_25: Button = $DispatchBar/Percent25
@onready var dispatch_percent_50: Button = $DispatchBar/Percent50
@onready var dispatch_percent_75: Button = $DispatchBar/Percent75
@onready var dispatch_percent_100: Button = $DispatchBar/Percent100
@onready var dispatch_confirm_button: Button = $DispatchBar/ConfirmButton
@onready var modal_overlay: ColorRect = $ModalOverlay
@onready var result_panel: Panel = $ResultPanel
@onready var result_status_tag: Panel = $ResultPanel/StatusTag
@onready var result_status_dot: ColorRect = $ResultPanel/StatusTag/Dot
@onready var result_status_label: Label = $ResultPanel/StatusTag/Label
@onready var result_title: Label = $ResultPanel/Title
@onready var result_details: Label = $ResultPanel/Details
@onready var result_source_box: Panel = $ResultPanel/SourceBox
@onready var result_source_label: Label = $ResultPanel/SourceBox/Label
@onready var retry_button: Button = $ResultPanel/RetryButton
@onready var return_button: Button = $ResultPanel/ReturnButton
@onready var modal_close_button: Button = $ResultPanel/CloseButton
@onready var cancel_button: Button = $ReturnToCityButton

var outcome := OUTCOME_NONE
var last_summary := ""

var _garrisons: Dictionary = {}
var _enemy_forces: Dictionary = {}
var _friendly_nodes: Dictionary = {}
var _reinforcement_claimed := false
var _run_finished_emitted := false

var _interaction_state := STATE_IDLE
var _interaction_pointer_screen := Vector2.ZERO
var _press_start_screen := Vector2.ZERO
var _command_source_node_id := &""
var _hovered_target_id := &""
var _pending_order: Dictionary = {}
var _dispatch_commit_in_progress := false
var _modal_mode := MODAL_NONE
var _concurrent_command_blocked_notice := false

var _marching_armies: Array[Dictionary] = []
var _next_marching_army_id := 1
var _v5_army_dispatch_adapter: V5ArmyDispatchAdapter


func _ready() -> void:
	_apply_visual_theme()
	_refresh_static_route_projections()
	retry_button.pressed.connect(_on_modal_secondary_pressed)
	return_button.pressed.connect(_on_modal_primary_pressed)
	modal_close_button.pressed.connect(_on_modal_close_pressed)
	cancel_button.pressed.connect(open_retreat_confirmation)
	modal_overlay.gui_input.connect(_on_modal_overlay_gui_input)
	dispatch_close_button.pressed.connect(cancel_pending_order)
	dispatch_confirm_button.pressed.connect(
		confirm_pending_dispatch_percent.bind(50)
	)
	dispatch_percent_25.pressed.connect(
		confirm_pending_dispatch_percent.bind(25)
	)
	dispatch_percent_50.pressed.connect(
		confirm_pending_dispatch_percent.bind(50)
	)
	dispatch_percent_75.pressed.connect(
		confirm_pending_dispatch_percent.bind(75)
	)
	dispatch_percent_100.pressed.connect(
		confirm_pending_dispatch_percent.bind(100)
	)
	for cancel_control in [
		dispatch_bar,
		dispatch_close_button,
		dispatch_percent_25,
		dispatch_percent_50,
		dispatch_percent_75,
		dispatch_percent_100,
	]:
		cancel_control.gui_input.connect(
			_on_dispatch_cancel_gui_input
		)
	start_new_run()


func _process(delta: float) -> void:
	advance_marching_time(delta)


func configure_v5_army_dispatch_adapter(
	adapter: V5ArmyDispatchAdapter
) -> bool:
	if adapter == null:
		return false
	if (
		_v5_army_dispatch_adapter != null
		and _v5_army_dispatch_adapter != adapter
	):
		return false
	_v5_army_dispatch_adapter = adapter
	return true


func get_v5_dispatch_read_model() -> Dictionary:
	return (
		_v5_army_dispatch_adapter.get_dispatch_read_model()
		if _v5_army_dispatch_adapter != null
		else {}
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var screen_position: Vector2 = (
			get_global_transform_with_canvas() * event.position
		)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _cancel_pending_order_from_mouse(event):
				accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if _interaction_state == STATE_ORDER_PENDING:
				if not dispatch_bar.get_global_rect().has_point(
					screen_position
				):
					cancel_pending_order()
					accept_event()
				return
			if begin_command_interaction(screen_position):
				accept_event()
			elif _show_node_click_information(screen_position):
				accept_event()
		elif release_command_interaction(screen_position):
			accept_event()
	elif event is InputEventMouseMotion:
		if not _is_pointer_interaction_active():
			return
		var screen_position: Vector2 = (
			get_global_transform_with_canvas() * event.position
		)
		update_command_pointer(screen_position)
		accept_event()


func _on_dispatch_cancel_gui_input(event: InputEvent) -> void:
	if _cancel_pending_order_from_mouse(event):
		get_viewport().set_input_as_handled()


func _cancel_pending_order_from_mouse(event: InputEvent) -> bool:
	if (
		event is not InputEventMouseButton
		or event.button_index != MOUSE_BUTTON_RIGHT
		or not event.pressed
	):
		return false
	return cancel_pending_order()


func start_new_run() -> void:
	_modal_mode = MODAL_NONE
	_hide_modal_presentation()
	_clear_all_interaction(false)
	_clear_marching_armies()
	_garrisons = {
		NODE_CAMP: STARTING_SOLDIERS,
		NODE_REINFORCEMENT: 0,
		NODE_OUTPOST: 0,
		NODE_FORTRESS: 0,
	}
	_enemy_forces = {
		NODE_CAMP: 0,
		NODE_REINFORCEMENT: 0,
		NODE_OUTPOST: OUTPOST_ENEMIES,
		NODE_FORTRESS: FORTRESS_ENEMIES,
	}
	_friendly_nodes = {
		NODE_CAMP: true,
		NODE_REINFORCEMENT: false,
		NODE_OUTPOST: false,
		NODE_FORTRESS: false,
	}
	_reinforcement_claimed = false
	outcome = OUTCOME_NONE
	last_summary = ""
	_run_finished_emitted = false
	_next_marching_army_id = 1
	_concurrent_command_blocked_notice = false
	status_label.text = (
		"按住我方驻军节点拖向相邻据点，松开后选择派兵数量。"
	)
	_refresh_presentation()


func begin_command_interaction(screen_position: Vector2) -> bool:
	if _modal_mode != MODAL_NONE:
		return false
	if (
		_interaction_state == STATE_MARCHING
		or not _marching_armies.is_empty()
	):
		_show_concurrent_command_blocked()
		return false
	if (
		_interaction_state != STATE_IDLE
		or outcome != OUTCOME_NONE
	):
		return false
	var source_node_id := _get_node_id_at_screen_position(screen_position)
	if (
		source_node_id == &""
		or not is_node_friendly(source_node_id)
		or get_garrison(source_node_id) <= 0
	):
		return false
	_command_source_node_id = source_node_id
	_press_start_screen = screen_position
	_interaction_pointer_screen = screen_position
	_hovered_target_id = &""
	_transition_state(STATE_SOURCE_ARMED)
	status_label.text = "%s：拖向绿色相邻据点；短按只查看信息。" % (
		_get_node_display_name(source_node_id)
	)
	return true


func update_command_pointer(screen_position: Vector2) -> bool:
	if not _is_pointer_interaction_active():
		return false
	_interaction_pointer_screen = screen_position
	if (
		_interaction_state == STATE_SOURCE_ARMED
		and screen_position.distance_to(_press_start_screen)
			>= COMMAND_DRAG_THRESHOLD
	):
		_transition_state(STATE_ROUTE_SELECTING)
		command_line.visible = true
		command_arrow.visible = true
	if _interaction_state == STATE_ROUTE_SELECTING:
		_update_command_line(screen_position)
	return true


func release_command_interaction(screen_position: Vector2) -> bool:
	if not _is_pointer_interaction_active():
		return false
	_interaction_pointer_screen = screen_position
	if _interaction_state == STATE_SOURCE_ARMED:
		var source_node_id := _command_source_node_id
		_clear_pointer_visuals()
		_reset_pointer_fields()
		_transition_state(STATE_IDLE)
		_show_node_information(source_node_id)
		return true
	_update_command_line(screen_position)
	var source_node_id := _command_source_node_id
	var target_node_id := _hovered_target_id
	var is_valid_target := (
		target_node_id != source_node_id
		and get_available_node_ids(source_node_id).has(target_node_id)
		and _command_type_for_target(target_node_id) != &""
	)
	if not is_valid_target:
		_clear_pointer_visuals()
		_reset_pointer_fields()
		_transition_state(STATE_IDLE)
		status_label.text = "无效目标：路线已取消，驻军状态未改变。"
		return true
	return _open_pending_order(source_node_id, target_node_id)


func cancel_command_interaction(show_message := true) -> bool:
	if _interaction_state == STATE_ORDER_PENDING:
		return cancel_pending_order(show_message)
	if not _is_pointer_interaction_active():
		return false
	_clear_pointer_visuals()
	_reset_pointer_fields()
	_transition_state(STATE_IDLE)
	if show_message:
		status_label.text = "路线选择已取消，驻军状态未改变。"
	return true


func cancel_pending_order(show_message := true) -> bool:
	if _interaction_state != STATE_ORDER_PENDING:
		return false
	_hide_dispatch_bar()
	_clear_pointer_visuals()
	_pending_order.clear()
	_reset_pointer_fields()
	_transition_state(STATE_IDLE)
	if show_message:
		status_label.text = "调遣已取消，驻军状态未改变。"
	return true


func begin_command_drag(screen_position: Vector2) -> bool:
	return begin_command_interaction(screen_position)


func update_command_drag(screen_position: Vector2) -> bool:
	return update_command_pointer(screen_position)


func end_command_drag(screen_position: Vector2) -> bool:
	return release_command_interaction(screen_position)


func _open_pending_order(
	source_node_id: StringName,
	target_node_id: StringName
) -> bool:
	if _interaction_state != STATE_ROUTE_SELECTING:
		return false
	var source_position := _get_node_center_local(source_node_id)
	var target_position := _get_node_center_local(target_node_id)
	var distance := source_position.distance_to(target_position)
	var duration := clampf(
		distance / MARCH_PIXELS_PER_SECOND,
		MIN_TRAVEL_SECONDS,
		MAX_TRAVEL_SECONDS
	)
	var available_count := get_garrison(source_node_id)
	var command_type := _command_type_for_target(target_node_id)
	_pending_order = {
		"source_node_id": source_node_id,
		"target_node_id": target_node_id,
		"route_id": _route_id(source_node_id, target_node_id),
		"route": [source_position, target_position],
		"command_type": command_type,
		"travel_duration": duration,
		"current_available": available_count,
		"dispatch_options": _dispatch_options_for_source(source_node_id),
		"created_at_msec": Time.get_ticks_msec(),
		"valid": true,
	}
	_transition_state(STATE_ORDER_PENDING)
	_show_dispatch_bar()
	_update_command_line_to_target(source_node_id, target_node_id)
	status_label.text = "路线已选：点击下方比例立即%s；Esc、右键或点空白取消。" % (
		_command_display_name(command_type)
	)
	return true


func confirm_pending_dispatch_percent(percent: int) -> bool:
	if (
		_interaction_state != STATE_ORDER_PENDING
		or _dispatch_commit_in_progress
		or not _revalidate_pending_order()
	):
		return false
	var source_node_id := StringName(
		_pending_order.get("source_node_id", &"")
	)
	var target_node_id := StringName(
		_pending_order.get("target_node_id", &"")
	)
	var choices := build_dispatch_amount_choices(
		get_garrison(source_node_id)
	)
	var selected_choice: Dictionary = {}
	for choice in choices:
		if int(choice.get("percent", 0)) == percent:
			selected_choice = choice
			break
	if (
		selected_choice.is_empty()
		or not bool(selected_choice.get("enabled", false))
	):
		return false
	var dispatch_amount := int(selected_choice.get("amount", 0))
	_dispatch_commit_in_progress = true
	var succeeded := _create_marching_command_from_pending(
		source_node_id,
		target_node_id,
		dispatch_amount
	)
	_dispatch_commit_in_progress = false
	return succeeded


func _revalidate_pending_order() -> bool:
	if (
		not bool(_pending_order.get("valid", false))
		or outcome != OUTCOME_NONE
		or not _marching_armies.is_empty()
	):
		return false
	var source_node_id := StringName(
		_pending_order.get("source_node_id", &"")
	)
	var target_node_id := StringName(
		_pending_order.get("target_node_id", &"")
	)
	if (
		not is_node_friendly(source_node_id)
		or get_garrison(source_node_id) <= 0
		or target_node_id == source_node_id
		or not get_available_node_ids(source_node_id).has(target_node_id)
		or _command_type_for_target(target_node_id) == &""
		or String(_pending_order.get("route_id", ""))
			!= _route_id(source_node_id, target_node_id)
	):
		return false
	return true


func _create_marching_command_from_pending(
	source_node_id: StringName,
	target_node_id: StringName,
	dispatch_amount: int
) -> bool:
	if _interaction_state != STATE_ORDER_PENDING:
		return false
	var source_before := get_garrison(source_node_id)
	var command_type := _command_type_for_target(target_node_id)
	if (
		source_before <= 0
		or dispatch_amount < 1
		or dispatch_amount > source_before
		or command_type == &""
	):
		return false
	var route: Array = _pending_order.get("route", [])
	if route.size() != 2:
		return false
	var source_position := Vector2(route[0])
	var target_position := Vector2(route[1])
	var duration := float(
		_pending_order.get("travel_duration", MIN_TRAVEL_SECONDS)
	)
	var army_id := "march_%04d" % _next_marching_army_id
	_next_marching_army_id += 1
	var army := {
		"unique_id": army_id,
		"source_node_id": source_node_id,
		"target_node_id": target_node_id,
		"dispatch_option_id": OPTION_INFANTRY,
		"troop_counts": {"infantry": dispatch_amount},
		"total_count": dispatch_amount,
		"commander_id": null,
		"route_id": _route_id(source_node_id, target_node_id),
		"progress": 0.0,
		"travel_duration": duration,
		"status": STATE_MARCHING,
		"command_type": command_type,
		"resolved": false,
		"source_position": source_position,
		"target_position": target_position,
	}
	_set_garrison(source_node_id, source_before - dispatch_amount)
	_marching_armies.append(army)
	_pending_order.clear()
	_hide_dispatch_bar()
	_clear_pointer_visuals()
	_reset_pointer_fields()
	_transition_state(STATE_MARCHING)
	_concurrent_command_blocked_notice = false
	_refresh_marching_presentation()
	_refresh_presentation()
	status_label.text = "%s：%d 名步兵正在从%s前往%s。" % [
		_command_display_name(command_type),
		dispatch_amount,
		_get_node_display_name(source_node_id),
		_get_node_display_name(target_node_id),
	]
	return true


func advance_marching_time(delta_seconds: float) -> bool:
	if (
		delta_seconds <= 0.0
		or _interaction_state != STATE_MARCHING
		or _marching_armies.is_empty()
	):
		return false
	var army: Dictionary = _marching_armies[0]
	if bool(army.get("resolved", false)):
		return false
	var duration := float(army.get("travel_duration", 0.0))
	if duration < 1.0:
		return false
	var progress := clampf(
		float(army.get("progress", 0.0))
			+ delta_seconds / duration,
		0.0,
		1.0
	)
	army["progress"] = progress
	_marching_armies[0] = army
	_refresh_marching_presentation()
	if progress >= 1.0:
		_resolve_marching_arrival(String(army.get("unique_id", "")))
	return true


func _resolve_marching_arrival(army_id: String) -> bool:
	if (
		_interaction_state != STATE_MARCHING
		or _marching_armies.is_empty()
	):
		return false
	var army: Dictionary = _marching_armies[0]
	if (
		String(army.get("unique_id", "")) != army_id
		or bool(army.get("resolved", false))
	):
		return false
	army["resolved"] = true
	army["status"] = STATE_ARRIVAL_RESOLVING
	_marching_armies[0] = army
	_transition_state(STATE_ARRIVAL_RESOLVING)
	var source_node_id := StringName(army.get("source_node_id", &""))
	var target_node_id := StringName(army.get("target_node_id", &""))
	var dispatch_amount := int(army.get("total_count", 0))
	var command_type := StringName(army.get("command_type", &""))
	_marching_armies.remove_at(0)
	_concurrent_command_blocked_notice = false
	_hide_marching_presentation()
	if command_type in [COMMAND_SUPPORT, COMMAND_REINFORCE]:
		_resolve_support(source_node_id, target_node_id, dispatch_amount)
	elif command_type == COMMAND_ATTACK:
		_resolve_attack(source_node_id, target_node_id, dispatch_amount)
	else:
		_transition_state(STATE_IDLE)
		return false
	if outcome == OUTCOME_NONE:
		_transition_state(STATE_IDLE)
	_refresh_presentation()
	return true


func get_dispatch_options() -> Array[Dictionary]:
	var source_node_id := _command_source_node_id
	if _interaction_state == STATE_ORDER_PENDING:
		source_node_id = StringName(
			_pending_order.get("source_node_id", &"")
		)
	return _dispatch_options_for_source(source_node_id)


func _dispatch_options_for_source(
	source_node_id: StringName
) -> Array[Dictionary]:
	var available_count := get_garrison(source_node_id)
	return [
		{
			"id": OPTION_INFANTRY,
			"label": "步兵／驻军",
			"selection_kind": &"troop_type",
			"available_count": available_count,
			"enabled": available_count > 0,
			"troop_type_ids": [&"infantry"],
			"formation_id": null,
			"commander_id": null,
		},
	]


func build_dispatch_amount_choices(
	available_count: int
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var seen_amounts: Dictionary = {}
	for percent in [25, 50, 75, 100]:
		var amount := _dispatch_amount_for_percent(
			available_count,
			percent
		)
		var duplicate := seen_amounts.has(amount)
		var enabled := amount > 0 and not duplicate
		if amount > 0 and not duplicate:
			seen_amounts[amount] = true
		choices.append({
			"percent": percent,
			"amount": amount,
			"remaining": maxi(available_count - amount, 0),
			"enabled": enabled,
			"duplicate": duplicate,
		})
	return choices


func get_pending_order() -> Dictionary:
	return _pending_order.duplicate(true)


func get_interaction_state() -> StringName:
	return _interaction_state


func is_command_drag_active() -> bool:
	return _is_pointer_interaction_active()


func is_command_line_visible() -> bool:
	return command_line.visible and command_arrow.visible


func is_dispatch_bar_visible() -> bool:
	return dispatch_bar.visible


func get_hovered_target_id() -> StringName:
	return _hovered_target_id


func get_marching_armies() -> Array[Dictionary]:
	return _marching_armies.duplicate(true)


func get_active_marching_army() -> Dictionary:
	if _marching_armies.is_empty():
		return {}
	return _marching_armies[0].duplicate(true)


func is_marching() -> bool:
	return (
		_interaction_state == STATE_MARCHING
		and not _marching_armies.is_empty()
	)


func get_available_node_ids(
	source_node_id: StringName
) -> Array[StringName]:
	if outcome != OUTCOME_NONE:
		return []
	if (
		source_node_id == &""
		or not is_node_friendly(source_node_id)
		or get_garrison(source_node_id) <= 0
	):
		return []
	match source_node_id:
		NODE_CAMP:
			return [NODE_REINFORCEMENT, NODE_OUTPOST]
		NODE_REINFORCEMENT:
			return [NODE_CAMP, NODE_OUTPOST]
		NODE_OUTPOST:
			return [NODE_CAMP, NODE_REINFORCEMENT, NODE_FORTRESS]
		NODE_FORTRESS:
			return [NODE_OUTPOST]
	return []


func get_garrison(node_id: StringName) -> int:
	return int(_garrisons.get(node_id, 0))


func get_enemy_force(node_id: StringName) -> int:
	return int(_enemy_forces.get(node_id, 0))


func is_node_friendly(node_id: StringName) -> bool:
	return bool(_friendly_nodes.get(node_id, false))


func is_reinforcement_claimed() -> bool:
	return _reinforcement_claimed


func get_soldiers() -> int:
	return get_total_soldiers()


func get_total_soldiers() -> int:
	var total := get_total_garrisoned_soldiers()
	for army in _marching_armies:
		if not bool(army.get("resolved", false)):
			total += int(army.get("total_count", 0))
	return total


func get_total_garrisoned_soldiers() -> int:
	var total := 0
	for node_id in [
		NODE_CAMP,
		NODE_REINFORCEMENT,
		NODE_OUTPOST,
		NODE_FORTRESS,
	]:
		if is_node_friendly(node_id):
			total += get_garrison(node_id)
	return total


func get_outcome() -> StringName:
	return outcome


func request_return_to_city() -> void:
	if is_marching():
		status_label.text = "部队正在行军，抵达并结算后才能返回城市。"
		return
	cancel_command_interaction(false)
	_modal_mode = MODAL_NONE
	_hide_modal_presentation()
	return_to_city_requested.emit()


func handle_escape() -> bool:
	if _modal_mode == MODAL_RETREAT_CONFIRM:
		cancel_retreat_confirmation()
		return true
	if _modal_mode == MODAL_RESULT:
		return true
	if cancel_command_interaction():
		return true
	if is_marching():
		status_label.text = "部队正在行军，本原型不支持中途撤回。"
		return true
	open_retreat_confirmation()
	return true


func open_retreat_confirmation() -> bool:
	if outcome != OUTCOME_NONE or is_marching():
		if is_marching():
			status_label.text = "部队正在行军，抵达并结算后才能撤退。"
		return false
	cancel_command_interaction(false)
	_modal_mode = MODAL_RETREAT_CONFIRM
	_refresh_result_presentation()
	return true


func cancel_retreat_confirmation() -> bool:
	if _modal_mode != MODAL_RETREAT_CONFIRM:
		return false
	_modal_mode = MODAL_NONE
	_hide_modal_presentation()
	status_label.text = "撤退已取消，可以继续选择驻军与路线。"
	return true


func confirm_retreat() -> bool:
	if _modal_mode != MODAL_RETREAT_CONFIRM or outcome != OUTCOME_NONE:
		return false
	_modal_mode = MODAL_NONE
	_hide_modal_presentation()
	request_return_to_city()
	return true


func get_modal_mode() -> StringName:
	return _modal_mode


func is_modal_open() -> bool:
	return (
		_modal_mode != MODAL_NONE
		and modal_overlay.visible
		and result_panel.visible
	)


func _on_modal_secondary_pressed() -> void:
	cancel_retreat_confirmation()


func _on_modal_primary_pressed() -> void:
	if _modal_mode == MODAL_RETREAT_CONFIRM:
		confirm_retreat()
	elif _modal_mode == MODAL_RESULT:
		request_return_to_city()


func _on_modal_close_pressed() -> void:
	if _modal_mode == MODAL_RETREAT_CONFIRM:
		cancel_retreat_confirmation()


func _on_modal_overlay_gui_input(event: InputEvent) -> void:
	if (
		_modal_mode == MODAL_RETREAT_CONFIRM
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		cancel_retreat_confirmation()
		get_viewport().set_input_as_handled()


func _configure_modal(
	tag_text: String,
	tone: Color,
	title_text: String,
	body_text: String,
	source_text: String,
	secondary_text: String,
	primary_text: String,
	show_secondary: bool
) -> void:
	result_status_label.text = tag_text
	result_title.text = title_text
	result_details.text = body_text
	result_source_label.text = source_text
	retry_button.visible = show_secondary
	retry_button.text = secondary_text
	return_button.text = primary_text
	modal_close_button.visible = show_secondary
	retry_button.position = Vector2(136.0, 216.0)
	retry_button.size = Vector2(136.0, 40.0)
	return_button.position = Vector2(280.0, 216.0)
	return_button.size = Vector2(136.0, 40.0)
	_apply_status_tag_style(
		result_status_tag,
		result_status_dot,
		result_status_label,
		tone
	)
	_style_button(retry_button, &"secondary")
	if _modal_mode == MODAL_RETREAT_CONFIRM:
		_style_button(return_button, &"danger")
	elif outcome == OUTCOME_VICTORY:
		_style_button(return_button, &"primary")
	else:
		_style_button(return_button, &"secondary")


func _hide_modal_presentation() -> void:
	modal_overlay.visible = false
	result_panel.visible = false
	modal_close_button.visible = false


func _apply_visual_theme() -> void:
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray([
		"Noto Sans",
		"PingFang SC",
		"Heiti SC",
		"Arial Unicode MS",
	])
	var local_theme := Theme.new()
	local_theme.default_font = ui_font
	local_theme.default_font_size = 14
	theme = local_theme

	$Background.color = COLOR_CANVAS
	modal_overlay.color = COLOR_OVERLAY
	$Header.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_STRONG, COLOR_STRONG, 0, 0)
	)
	$MissionPanel.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_SURFACE, COLOR_BORDER, 12, 1)
	)
	$MissionPanel/Rule.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_SUBTLE, COLOR_SUBTLE, 8, 0)
	)
	$Battlefield/Surface.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_SURFACE, COLOR_BORDER, 12, 1)
	)
	$Battlefield/TerrainNorth.add_theme_stylebox_override(
		"panel",
		_make_style_box(Color("#ddd4bb"), Color("#ddd4bb"), 110, 0)
	)
	$Battlefield/TerrainSouth.add_theme_stylebox_override(
		"panel",
		_make_style_box(Color("#d8ceb2"), Color("#d8ceb2"), 120, 0)
	)
	dispatch_bar.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_RAISED, COLOR_BORDER_STRONG, 12, 2)
	)
	march_info.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_RAISED, COLOR_BORDER_STRONG, 12, 2)
	)
	result_panel.add_theme_stylebox_override(
		"panel",
		_make_style_box(
			COLOR_RAISED,
			COLOR_BORDER_STRONG,
			12,
			1,
			Color(0.11, 0.12, 0.105, 0.28),
			22,
			Vector2(0.0, 12.0)
		)
	)
	result_source_box.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_SUBTLE, COLOR_SUBTLE, 8, 0)
	)
	_style_progress_bar()
	_apply_status_tag_style(
		concurrency_tag,
		$Battlefield/MarchInfo/ConcurrencyTag/Dot,
		$Battlefield/MarchInfo/ConcurrencyTag/Label,
		COLOR_DANGER
	)

	for node_button in [
		camp_button,
		reinforcement_button,
		outpost_button,
		fortress_button,
	]:
		_style_node_button(node_button)
	for button in [
		dispatch_percent_25,
		dispatch_percent_75,
		dispatch_percent_100,
		dispatch_close_button,
		modal_close_button,
	]:
		_style_button(button, &"secondary")
	_style_button(dispatch_percent_50, &"primary")
	_style_button(dispatch_confirm_button, &"primary")
	_style_button(cancel_button, &"danger")
	_style_button(retry_button, &"secondary")
	_style_button(return_button, &"primary")

	for label_node in find_children("*", "Label", true, false):
		var label := label_node as Label
		if label != null:
			label.add_theme_color_override(
				"font_color",
				COLOR_TEXT_PRIMARY
			)
	$Title.add_theme_color_override(
		"font_color",
		COLOR_TEXT_ON_STRONG
	)
	soldiers_label.add_theme_color_override(
		"font_color",
		COLOR_TEXT_ON_STRONG
	)
	status_label.add_theme_color_override(
		"font_color",
		COLOR_PRIMARY_HOVER
	)
	$MissionPanel/Body.add_theme_color_override(
		"font_color",
		COLOR_TEXT_SECONDARY
	)
	$MissionPanel/Rule/Label.add_theme_color_override(
		"font_color",
		COLOR_TEXT_SECONDARY
	)
	$MissionPanel/Hint.add_theme_color_override(
		"font_color",
		COLOR_PRIMARY
	)
	dispatch_details_label.add_theme_color_override(
		"font_color",
		COLOR_TEXT_SECONDARY
	)
	march_state_label.add_theme_color_override(
		"font_color",
		COLOR_INFO
	)
	march_percent_label.add_theme_color_override(
		"font_color",
		COLOR_TEXT_SECONDARY
	)
	result_details.add_theme_color_override(
		"font_color",
		COLOR_TEXT_SECONDARY
	)
	result_source_label.add_theme_color_override(
		"font_color",
		COLOR_PRIMARY
	)
	marching_marker_label.add_theme_color_override(
		"font_color",
		COLOR_TEXT_ON_STRONG
	)
	marching_marker_label.add_theme_color_override(
		"font_outline_color",
		COLOR_STRONG
	)
	$Battlefield/MarchingArmy/Flag.color = COLOR_INFO
	concurrency_tag.visible = false


func _make_style_box(
	background: Color,
	border: Color,
	radius: int,
	border_width: int,
	shadow_color := Color.TRANSPARENT,
	shadow_size := 0,
	shadow_offset := Vector2.ZERO
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	return style


func _style_node_button(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state_name in [
		"normal",
		"hover",
		"pressed",
		"disabled",
		"focus",
	]:
		button.add_theme_stylebox_override(state_name, empty)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT_PRIMARY)


func _style_button(button: Button, intent: StringName) -> void:
	var normal_bg := COLOR_RAISED
	var normal_border := COLOR_BORDER_STRONG
	var hover_bg := COLOR_SUBTLE
	var pressed_bg := COLOR_BORDER
	var font_color := COLOR_TEXT_PRIMARY
	if intent == &"primary":
		normal_bg = COLOR_PRIMARY
		normal_border = COLOR_PRIMARY_HOVER
		hover_bg = COLOR_PRIMARY_HOVER
		pressed_bg = COLOR_STRONG
		font_color = COLOR_TEXT_ON_STRONG
	elif intent == &"danger":
		normal_bg = COLOR_DANGER_BG
		normal_border = COLOR_DANGER
		hover_bg = COLOR_DANGER
		pressed_bg = Color("#6d302b")
		font_color = COLOR_TEXT_ON_STRONG
	button.add_theme_stylebox_override(
		"normal",
		_make_style_box(normal_bg, normal_border, 8, 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_style_box(hover_bg, normal_border, 8, 1)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_style_box(pressed_bg, normal_border, 8, 1)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_style_box(COLOR_SUBTLE, COLOR_BORDER, 8, 1)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_style_box(Color.TRANSPARENT, normal_border, 8, 1)
	)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override(
		"font_disabled_color",
		COLOR_TEXT_SECONDARY
	)
	button.add_theme_font_size_override("font_size", 12)


func _style_progress_bar() -> void:
	march_progress_bar.add_theme_stylebox_override(
		"background",
		_make_style_box(COLOR_SUBTLE, COLOR_SUBTLE, 999, 0)
	)
	march_progress_bar.add_theme_stylebox_override(
		"fill",
		_make_style_box(COLOR_INFO, COLOR_INFO, 999, 0)
	)


func _apply_status_tag_style(
	panel: Panel,
	dot: ColorRect,
	label: Label,
	tone: Color
) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_style_box(COLOR_SUBTLE, tone, 999, 1)
	)
	dot.color = tone
	label.add_theme_color_override("font_color", tone)


func _command_type_for_target(target_node_id: StringName) -> StringName:
	if is_node_friendly(target_node_id):
		return COMMAND_SUPPORT
	if (
		target_node_id == NODE_REINFORCEMENT
		and not _reinforcement_claimed
	):
		return COMMAND_REINFORCE
	if get_enemy_force(target_node_id) > 0:
		return COMMAND_ATTACK
	return &""


func _resolve_support(
	source_node_id: StringName,
	target_node_id: StringName,
	dispatch_amount: int
) -> void:
	var reinforcement_bonus := 0
	if (
		target_node_id == NODE_REINFORCEMENT
		and not _reinforcement_claimed
	):
		_reinforcement_claimed = true
		reinforcement_bonus = REINFORCEMENT_SOLDIERS
	_friendly_nodes[target_node_id] = true
	_set_garrison(
		target_node_id,
		get_garrison(target_node_id) + dispatch_amount + reinforcement_bonus
	)
	if reinforcement_bonus > 0:
		status_label.text = (
			"抵达山路援军：派出 %d，援军 +%d，目标驻军 %d。"
			% [
				dispatch_amount,
				reinforcement_bonus,
				get_garrison(target_node_id),
			]
		)
	else:
		status_label.text = (
			"支援抵达：%s向%s增援 %d 人。"
			% [
				_get_node_display_name(source_node_id),
				_get_node_display_name(target_node_id),
				dispatch_amount,
			]
		)


func _resolve_attack(
	source_node_id: StringName,
	target_node_id: StringName,
	dispatch_amount: int
) -> void:
	var enemy_count := get_enemy_force(target_node_id)
	if dispatch_amount <= enemy_count:
		if get_total_soldiers() <= 0:
			_finish_run(
				OUTCOME_DEFEAT,
				"%s：%d 人抵达后进攻敌军 %d，失败且已无可用驻军。"
				% [
					_get_node_display_name(target_node_id),
					dispatch_amount,
					enemy_count,
				]
			)
			return
		status_label.text = (
			"进攻失败：派出 %d 对敌军 %d；%s仍留守 %d 人。"
			% [
				dispatch_amount,
				enemy_count,
				_get_node_display_name(source_node_id),
				get_garrison(source_node_id),
			]
		)
		return
	var survivors := dispatch_amount - enemy_count
	_enemy_forces[target_node_id] = 0
	_friendly_nodes[target_node_id] = true
	_set_garrison(target_node_id, survivors)
	if target_node_id == NODE_FORTRESS:
		_finish_run(
			OUTCOME_VICTORY,
			"黑石堡：%d 人抵达后歼敌 %d，幸存 %d 人驻守；战斗胜利。"
			% [dispatch_amount, enemy_count, survivors]
		)
	else:
		status_label.text = (
			"%s胜利：抵达 %d 人，歼敌 %d，幸存 %d 人驻守。"
			% [
				_get_node_display_name(target_node_id),
				dispatch_amount,
				enemy_count,
				survivors,
			]
		)


func _finish_run(next_outcome: StringName, summary: String) -> void:
	_clear_all_interaction(false)
	outcome = next_outcome
	last_summary = summary
	_modal_mode = MODAL_RESULT
	_refresh_state_presentation()
	_refresh_result_presentation()
	if not _run_finished_emitted:
		_run_finished_emitted = true
		run_finished.emit(outcome, get_total_soldiers(), summary)


func _set_garrison(node_id: StringName, value: int) -> void:
	_garrisons[node_id] = maxi(value, 0)


func _refresh_presentation() -> void:
	soldiers_label.text = _build_force_summary()
	camp_button.disabled = false
	reinforcement_button.disabled = false
	outpost_button.disabled = false
	fortress_button.disabled = false
	_refresh_node_presentation(NODE_CAMP)
	_refresh_node_presentation(NODE_REINFORCEMENT)
	_refresh_node_presentation(NODE_OUTPOST)
	_refresh_node_presentation(NODE_FORTRESS)
	_refresh_node_highlights()
	_refresh_state_presentation()
	_refresh_result_presentation()
	cancel_button.disabled = is_marching()


func _node_button_text(node_id: StringName) -> String:
	var prefix := ""
	if is_node_friendly(node_id) and get_garrison(node_id) > 0:
		prefix = "◆ 可发兵\n"
	if is_node_friendly(node_id):
		return "%s%s\n我方驻军 %d" % [
			prefix,
			_get_node_display_name(node_id),
			get_garrison(node_id),
		]
	if (
		node_id == NODE_REINFORCEMENT
		and not _reinforcement_claimed
	):
		return "山路援军\n待接应 · +%d" % REINFORCEMENT_SOLDIERS
	return "%s\n敌军 %d" % [
		_get_node_display_name(node_id),
		get_enemy_force(node_id),
	]


func _build_force_summary() -> String:
	var parts: Array[String] = []
	for node_id in [
		NODE_CAMP,
		NODE_REINFORCEMENT,
		NODE_OUTPOST,
		NODE_FORTRESS,
	]:
		if is_node_friendly(node_id) and get_garrison(node_id) > 0:
			parts.append(
				"%s %d" % [
					_short_node_display_name(node_id),
					get_garrison(node_id),
				]
			)
	var marching_count := 0
	if not _marching_armies.is_empty():
		marching_count = int(
			_marching_armies[0].get("total_count", 0)
		)
	parts.append("活动行军 %d" % marching_count)
	return "　".join(parts)


func _refresh_node_presentation(node_id: StringName) -> void:
	var button := _get_node_button(node_id)
	if button == null:
		return
	var name_label := button.get_node_or_null("Name") as Label
	var detail_label := button.get_node_or_null("Detail") as Label
	if name_label == null or detail_label == null:
		button.text = _node_button_text(node_id)
		return
	button.text = ""
	name_label.text = _get_node_display_name(node_id)
	if is_node_friendly(node_id):
		var suffix := (
			"可发兵"
			if get_garrison(node_id) > 0 and not is_marching()
			else "行军中" if is_marching() else "无驻军"
		)
		detail_label.text = "我方驻军 %d · %s" % [
			get_garrison(node_id),
			suffix,
		]
		detail_label.add_theme_color_override(
			"font_color",
			COLOR_PRIMARY
		)
	elif (
		node_id == NODE_REINFORCEMENT
		and not _reinforcement_claimed
	):
		detail_label.text = "待接应 · +%d" % REINFORCEMENT_SOLDIERS
		detail_label.add_theme_color_override(
			"font_color",
			COLOR_TEXT_SECONDARY
		)
	else:
		detail_label.text = "敌军 %d · 目标" % get_enemy_force(node_id)
		detail_label.add_theme_color_override(
			"font_color",
			COLOR_TEXT_SECONDARY
		)


func _refresh_state_presentation() -> void:
	var label := "待命令"
	var tone := COLOR_INFO
	var body := "击溃黑石堡守军。所有路线必须由实际驻军来源显式发起。"
	if outcome == OUTCOME_VICTORY:
		label = "已完成"
		tone = COLOR_SUCCESS
		body = "黑石堡守军已被击溃。胜利只结算一次，来源由真实结果决定。"
	elif outcome == OUTCOME_DEFEAT:
		label = "失败 / 阻断"
		tone = COLOR_DANGER
		body = "本次行动未达成任务目标；不发放胜利奖励。"
	elif _interaction_state == STATE_ORDER_PENDING:
		label = "待确认"
		tone = COLOR_WARNING
	elif _interaction_state in [STATE_MARCHING, STATE_ARRIVAL_RESOLVING]:
		label = "行军中"
		tone = COLOR_INFO
	mission_status_label.text = label
	mission_body_label.text = body
	_apply_status_tag_style(
		mission_status_tag,
		mission_status_dot,
		mission_status_label,
		tone
	)


func _refresh_result_presentation() -> void:
	if outcome == OUTCOME_NONE and _modal_mode != MODAL_RETREAT_CONFIRM:
		_hide_modal_presentation()
		return
	modal_overlay.visible = true
	result_panel.visible = true
	if _modal_mode == MODAL_RETREAT_CONFIRM and outcome == OUTCOME_NONE:
		_configure_modal(
			"进行中",
			COLOR_WARNING,
			"确认撤退？",
			"撤退会结束本次战区行动；不会触发胜利，也不会发放胜利奖励。",
			"结果来源：玩家主动撤退",
			"取消",
			"确认撤退",
			true
		)
		return
	_modal_mode = MODAL_RESULT
	if outcome == OUTCOME_VICTORY:
		_configure_modal(
			"已完成",
			COLOR_SUCCESS,
			"战区胜利",
			last_summary,
			"结果来源：黑石堡抵达结算 · 城市奖励由城市权威应用",
			"",
			"返回城市",
			false
		)
	else:
		_configure_modal(
			"失败 / 阻断",
			COLOR_DANGER,
			"行动失败",
			last_summary,
			"结果来源：前线失败结算 · 无胜利奖励",
			"",
			"返回城市",
			false
		)


func _show_dispatch_bar() -> void:
	dispatch_bar.visible = true
	legend_label.visible = false
	var source_node_id := StringName(
		_pending_order.get("source_node_id", &"")
	)
	var target_node_id := StringName(
		_pending_order.get("target_node_id", &"")
	)
	var command_type := StringName(
		_pending_order.get("command_type", &"")
	)
	var duration := float(_pending_order.get("travel_duration", 0.0))
	var available_count := get_garrison(source_node_id)
	dispatch_route_label.text = "%s → %s　·　%s　·　约 %.1f 秒" % [
		_get_node_display_name(source_node_id),
		_get_node_display_name(target_node_id),
		_command_display_name(command_type),
		duration,
	]
	dispatch_details_label.text = (
		"可派 %d · 比例对应实际人数见按钮提示"
		% available_count
	)
	var choices := build_dispatch_amount_choices(available_count)
	var buttons := [
		dispatch_percent_25,
		dispatch_percent_50,
		dispatch_percent_75,
		dispatch_percent_100,
	]
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var button: Button = buttons[index]
		var percent := int(choice.get("percent", 0))
		var prefix := "全部" if percent == 100 else "%d%%" % percent
		button.text = prefix
		button.tooltip_text = "派出 %d · 留守 %d" % [
			int(choice.get("amount", 0)),
			int(choice.get("remaining", 0)),
		]
		button.disabled = not bool(choice.get("enabled", false))
	dispatch_confirm_button.disabled = false


func _hide_dispatch_bar() -> void:
	dispatch_bar.visible = false
	legend_label.visible = false


func _dispatch_amount_for_percent(
	source_garrison: int,
	percent: int
) -> int:
	if source_garrison <= 0:
		return 0
	return clampi(
		ceili(float(source_garrison) * float(percent) / 100.0),
		1,
		source_garrison
	)


func _update_command_line(screen_position: Vector2) -> void:
	var start_button := _get_node_button(_command_source_node_id)
	if start_button == null:
		cancel_command_interaction()
		return
	var battlefield_inverse := (
		battlefield.get_global_transform_with_canvas().affine_inverse()
	)
	var start_position := _get_node_marker_center_local(
		_command_source_node_id
	)
	var end_position := battlefield_inverse * screen_position
	_hovered_target_id = _get_node_id_at_screen_position(screen_position)
	var is_valid_target := (
		_hovered_target_id != _command_source_node_id
		and get_available_node_ids(_command_source_node_id).has(
			_hovered_target_id
		)
		and _command_type_for_target(_hovered_target_id) != &""
	)
	if is_valid_target:
		end_position = _get_route_target_projection_local(
			_command_source_node_id,
			_hovered_target_id,
			command_line.width
		)
	command_line.points = PackedVector2Array([start_position, end_position])
	var line_color := (
		COMMAND_LINE_VALID_COLOR
		if is_valid_target
		else COMMAND_LINE_INVALID_COLOR
	)
	command_line.default_color = line_color
	command_arrow.color = line_color
	command_arrow.position = end_position
	command_arrow.rotation = (end_position - start_position).angle()
	_refresh_node_highlights()
	if is_valid_target:
		var target_type := _command_type_for_target(_hovered_target_id)
		status_label.text = "%s → %s · %s · 约 %.1f 秒；松开选择兵数。" % [
			_get_node_display_name(_command_source_node_id),
			_get_node_display_name(_hovered_target_id),
			_command_display_name(target_type),
			_travel_duration(_command_source_node_id, _hovered_target_id),
		]


func _update_command_line_to_target(
	source_node_id: StringName,
	target_node_id: StringName
) -> void:
	_command_source_node_id = source_node_id
	_hovered_target_id = target_node_id
	var source_position := _get_node_marker_center_local(source_node_id)
	var target_position := _get_route_target_projection_local(
		source_node_id,
		target_node_id,
		command_line.width
	)
	command_line.points = PackedVector2Array([
		source_position,
		target_position,
	])
	command_line.default_color = COMMAND_LINE_VALID_COLOR
	command_line.visible = true
	command_arrow.color = COMMAND_LINE_VALID_COLOR
	command_arrow.position = target_position
	command_arrow.rotation = (target_position - source_position).angle()
	command_arrow.visible = true
	_refresh_node_highlights()


func _refresh_marching_presentation() -> void:
	if _marching_armies.is_empty():
		_hide_marching_presentation()
		return
	var army: Dictionary = _marching_armies[0]
	var progress := float(army.get("progress", 0.0))
	var source_position := Vector2(
		army.get("source_position", Vector2.ZERO)
	)
	var target_position := Vector2(
		army.get("target_position", Vector2.ZERO)
	)
	marching_marker.visible = true
	marching_marker.position = source_position.lerp(target_position, progress)
	var count := int(army.get("total_count", 0))
	marching_marker_label.text = "步 %d" % count
	march_info.visible = true
	var duration := float(army.get("travel_duration", 1.0))
	var eta := maxf(duration * (1.0 - progress), 0.0)
	march_info_label.text = "%s → %s · %d 人" % [
		_get_node_display_name(
			StringName(army.get("source_node_id", &""))
		),
		_get_node_display_name(
			StringName(army.get("target_node_id", &""))
		),
		count,
	]
	var progress_percent := roundi(progress * 100.0)
	march_state_label.text = "行军中 · 约 %.1f 秒抵达" % eta
	march_percent_label.text = "%d%%" % progress_percent
	march_progress_bar.value = float(progress_percent)
	concurrency_tag.visible = _concurrent_command_blocked_notice
	soldiers_label.text = _build_force_summary()
	_refresh_state_presentation()


func _hide_marching_presentation() -> void:
	marching_marker.visible = false
	march_info.visible = false
	concurrency_tag.visible = false


func _clear_marching_armies() -> void:
	_marching_armies.clear()
	_concurrent_command_blocked_notice = false
	_hide_marching_presentation()


func _clear_pointer_visuals() -> void:
	command_line.visible = false
	command_arrow.visible = false
	_hovered_target_id = &""
	_refresh_node_highlights()


func _reset_pointer_fields() -> void:
	_interaction_pointer_screen = Vector2.ZERO
	_press_start_screen = Vector2.ZERO
	_command_source_node_id = &""
	_hovered_target_id = &""


func _clear_all_interaction(show_message := false) -> void:
	_hide_dispatch_bar()
	_pending_order.clear()
	_clear_pointer_visuals()
	_reset_pointer_fields()
	_dispatch_commit_in_progress = false
	_interaction_state = STATE_IDLE
	if show_message:
		status_label.text = "指挥已取消。"


func _is_pointer_interaction_active() -> bool:
	return _interaction_state in [
		STATE_SOURCE_ARMED,
		STATE_ROUTE_SELECTING,
	]


func _transition_state(next_state: StringName) -> bool:
	if next_state == _interaction_state:
		return true
	var allowed := false
	match _interaction_state:
		STATE_IDLE:
			allowed = next_state == STATE_SOURCE_ARMED
		STATE_SOURCE_ARMED:
			allowed = next_state in [STATE_ROUTE_SELECTING, STATE_IDLE]
		STATE_ROUTE_SELECTING:
			allowed = next_state in [STATE_ORDER_PENDING, STATE_IDLE]
		STATE_ORDER_PENDING:
			allowed = next_state in [STATE_MARCHING, STATE_IDLE]
		STATE_MARCHING:
			allowed = next_state == STATE_ARRIVAL_RESOLVING
		STATE_ARRIVAL_RESOLVING:
			allowed = next_state == STATE_IDLE
	if not allowed:
		push_error(
			"非法黑石堡交互状态转换：%s → %s"
			% [_interaction_state, next_state]
		)
		return false
	_interaction_state = next_state
	_refresh_state_presentation()
	return true


func _refresh_node_highlights() -> void:
	var available := get_available_node_ids(_command_source_node_id)
	for node_id in [
		NODE_CAMP,
		NODE_REINFORCEMENT,
		NODE_OUTPOST,
		NODE_FORTRESS,
	]:
		var button := _get_node_button(node_id)
		if button == null:
			continue
		button.modulate = Color.WHITE
		var marker := button.get_node_or_null("Marker") as Panel
		if marker == null:
			continue
		var marker_color := (
			COLOR_SUCCESS
			if is_node_friendly(node_id)
			else COLOR_INFO
				if (
					node_id == NODE_REINFORCEMENT
					and not _reinforcement_claimed
				)
				else COLOR_DANGER
		)
		var marker_border := COLOR_BORDER_STRONG
		if (
			_interaction_state in [
				STATE_ROUTE_SELECTING,
				STATE_ORDER_PENDING,
			]
			and available.has(node_id)
		):
			marker_border = COLOR_PRIMARY_HOVER
		if (
			_interaction_state in [
				STATE_ROUTE_SELECTING,
				STATE_ORDER_PENDING,
			]
			and node_id == _hovered_target_id
		):
			marker_border = (
				COLOR_SUCCESS if available.has(node_id) else COLOR_DANGER
			)
		marker.add_theme_stylebox_override(
			"panel",
			_make_style_box(marker_color, marker_border, 29, 3)
		)


func _show_node_click_information(screen_position: Vector2) -> bool:
	var node_id := _get_node_id_at_screen_position(screen_position)
	if node_id == &"":
		return false
	return _show_node_information(node_id)


func _show_node_information(node_id: StringName) -> bool:
	if node_id == &"":
		return false
	if is_marching():
		_show_concurrent_command_blocked()
		var army := get_active_marching_army()
		status_label.text = "%s正在前往%s；抵达前不能再次下令。" % [
			_get_node_display_name(
				StringName(army.get("source_node_id", &""))
			),
			_get_node_display_name(
				StringName(army.get("target_node_id", &""))
			),
		]
		return true
	if is_node_friendly(node_id):
		status_label.text = "%s：我方驻军 %d；按住并拖向相邻据点。" % [
			_get_node_display_name(node_id),
			get_garrison(node_id),
		]
	elif node_id == NODE_REINFORCEMENT:
		status_label.text = "山路援军：部队抵达后一次性加入 6 人。"
	else:
		status_label.text = "%s：已知敌军 %d；从相邻己方节点发令。" % [
			_get_node_display_name(node_id),
			get_enemy_force(node_id),
		]
	return true


func _show_concurrent_command_blocked() -> void:
	if not is_marching():
		return
	_concurrent_command_blocked_notice = true
	concurrency_tag.visible = true
	status_label.text = "并发命令已阻止：原行军继续，抵达前不能再次下令。"


func _get_node_id_at_screen_position(
	screen_position: Vector2
) -> StringName:
	for node_id in [
		NODE_CAMP,
		NODE_REINFORCEMENT,
		NODE_OUTPOST,
		NODE_FORTRESS,
	]:
		var button := _get_node_button(node_id)
		if (
			button != null
			and button.get_global_rect().has_point(screen_position)
		):
			return node_id
	return &""


func _get_node_button(node_id: StringName) -> Button:
	match node_id:
		NODE_CAMP:
			return camp_button
		NODE_REINFORCEMENT:
			return reinforcement_button
		NODE_OUTPOST:
			return outpost_button
		NODE_FORTRESS:
			return fortress_button
	return null


func _get_node_center_local(node_id: StringName) -> Vector2:
	var button := _get_node_button(node_id)
	if button == null:
		return Vector2.ZERO
	return button.position + button.size * 0.5


func _get_node_marker_center_local(node_id: StringName) -> Vector2:
	var button := _get_node_button(node_id)
	if button == null:
		return Vector2.ZERO
	var marker := button.get_node_or_null("Marker") as Control
	if marker == null:
		return _get_node_center_local(node_id)
	return button.position + marker.position + marker.size * 0.5


func _refresh_static_route_projections() -> void:
	_set_static_route_projection(
		$Battlefield/CampToReinforcement,
		NODE_CAMP,
		NODE_REINFORCEMENT
	)
	_set_static_route_projection(
		$Battlefield/CampToOutpost,
		NODE_CAMP,
		NODE_OUTPOST
	)
	_set_static_route_projection(
		$Battlefield/ReinforcementToOutpost,
		NODE_REINFORCEMENT,
		NODE_OUTPOST
	)
	_set_static_route_projection(
		$Battlefield/OutpostToFortress,
		NODE_OUTPOST,
		NODE_FORTRESS
	)


func _set_static_route_projection(
	line: Line2D,
	source_node_id: StringName,
	target_node_id: StringName
) -> void:
	line.points = PackedVector2Array([
		_get_node_marker_center_local(source_node_id),
		_get_route_target_projection_local(
			source_node_id,
			target_node_id,
			line.width
		),
	])


func _get_route_target_projection_local(
	source_node_id: StringName,
	target_node_id: StringName,
	line_width: float
) -> Vector2:
	var source_position := _get_node_marker_center_local(source_node_id)
	var marker_position := _get_node_marker_center_local(target_node_id)
	var protected_text_rect := _get_node_text_rect_local(target_node_id).grow(
		ROUTE_TEXT_CLEARANCE + line_width * 0.5
	)
	var entry_ratio := _segment_first_rect_entry_ratio(
		source_position,
		marker_position,
		protected_text_rect
	)
	if entry_ratio < 0.0:
		return marker_position
	# The route stops at the outer edge of the target information area when
	# its approach would otherwise cut through the title or detail text.
	return source_position.lerp(marker_position, maxf(entry_ratio - 0.001, 0.0))


func _get_node_text_rect_local(node_id: StringName) -> Rect2:
	var button := _get_node_button(node_id)
	if button == null:
		return Rect2()
	var title := button.get_node_or_null("Name") as Control
	var detail := button.get_node_or_null("Detail") as Control
	if title == null or detail == null:
		return Rect2()
	var title_rect := Rect2(
		button.position + title.position,
		title.size
	)
	var detail_rect := Rect2(
		button.position + detail.position,
		detail.size
	)
	return title_rect.merge(detail_rect)


func _segment_first_rect_entry_ratio(
	from: Vector2,
	to: Vector2,
	rect: Rect2
) -> float:
	var delta := to - from
	var first_entry := INF
	for boundary_x in [rect.position.x, rect.end.x]:
		if is_zero_approx(delta.x):
			continue
		var ratio: float = (float(boundary_x) - from.x) / delta.x
		var y: float = from.y + delta.y * ratio
		if ratio >= 0.0 and ratio <= 1.0 and y >= rect.position.y and y <= rect.end.y:
			first_entry = minf(first_entry, ratio)
	for boundary_y in [rect.position.y, rect.end.y]:
		if is_zero_approx(delta.y):
			continue
		var ratio: float = (float(boundary_y) - from.y) / delta.y
		var x: float = from.x + delta.x * ratio
		if ratio >= 0.0 and ratio <= 1.0 and x >= rect.position.x and x <= rect.end.x:
			first_entry = minf(first_entry, ratio)
	return -1.0 if is_inf(first_entry) else first_entry


func _travel_duration(
	source_node_id: StringName,
	target_node_id: StringName
) -> float:
	var distance := _get_node_center_local(source_node_id).distance_to(
		_get_node_center_local(target_node_id)
	)
	return clampf(
		distance / MARCH_PIXELS_PER_SECOND,
		MIN_TRAVEL_SECONDS,
		MAX_TRAVEL_SECONDS
	)


func _route_id(
	source_node_id: StringName,
	target_node_id: StringName
) -> String:
	return "%s_to_%s" % [
		String(source_node_id),
		String(target_node_id),
	]


func _command_display_name(command_type: StringName) -> String:
	match command_type:
		COMMAND_SUPPORT:
			return "支援"
		COMMAND_REINFORCE:
			return "接应"
		COMMAND_ATTACK:
			return "进攻"
	return "调遣"


func _get_node_display_name(node_id: StringName) -> String:
	match node_id:
		NODE_CAMP:
			return "我方营地"
		NODE_REINFORCEMENT:
			return "山路援军"
		NODE_OUTPOST:
			return "黑石前哨"
		NODE_FORTRESS:
			return "黑石堡"
	return "空白区域"


func _short_node_display_name(node_id: StringName) -> String:
	match node_id:
		NODE_CAMP:
			return "营地"
		NODE_REINFORCEMENT:
			return "援军"
		NODE_OUTPOST:
			return "前哨"
		NODE_FORTRESS:
			return "黑石堡"
	return "未知"
