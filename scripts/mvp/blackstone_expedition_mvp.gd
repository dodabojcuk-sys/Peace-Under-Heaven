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

const STARTING_SOLDIERS := 10
const REINFORCEMENT_SOLDIERS := 6
const OUTPOST_ENEMIES := 5
const FORTRESS_ENEMIES := 8
const COMMAND_DRAG_THRESHOLD := 10.0
const COMMAND_LINE_VALID_COLOR := Color(0.2, 0.9, 0.65, 1.0)
const COMMAND_LINE_INVALID_COLOR := Color(0.9, 0.3, 0.28, 1.0)
const CURRENT_NODE_COLOR := Color(0.72, 0.86, 1.0, 1.0)
const AVAILABLE_NODE_COLOR := Color(0.68, 1.0, 0.72, 1.0)
const VALID_TARGET_COLOR := Color(0.38, 1.0, 0.58, 1.0)
const INVALID_TARGET_COLOR := Color(1.0, 0.62, 0.6, 1.0)

@onready var soldiers_label: Label = $Header/Soldiers
@onready var status_label: Label = $Header/Status
@onready var battlefield: Control = $Battlefield
@onready var command_line: Line2D = $Battlefield/CommandLine
@onready var command_arrow: Polygon2D = $Battlefield/CommandArrow
@onready var camp_button: Button = $Battlefield/Camp
@onready var reinforcement_button: Button = $Battlefield/Reinforcement
@onready var outpost_button: Button = $Battlefield/Outpost
@onready var fortress_button: Button = $Battlefield/Fortress
@onready var army_marker: Label = $Battlefield/ArmyMarker
@onready var result_panel: Panel = $ResultPanel
@onready var result_title: Label = $ResultPanel/Title
@onready var result_details: Label = $ResultPanel/Details
@onready var retry_button: Button = $ResultPanel/RetryButton
@onready var return_button: Button = $ResultPanel/ReturnButton
@onready var cancel_button: Button = $ReturnToCityButton

var current_node_id := NODE_CAMP
var soldiers := STARTING_SOLDIERS
var outcome := OUTCOME_NONE
var last_summary := ""
var _run_finished_emitted := false
var _drag_candidate := false
var _command_dragging := false
var _drag_start_screen := Vector2.ZERO
var _hovered_target_id := &""
var _resolving_command := false


func _ready() -> void:
	retry_button.pressed.connect(start_new_run)
	return_button.pressed.connect(request_return_to_city)
	cancel_button.pressed.connect(request_return_to_city)
	start_new_run()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var screen_position: Vector2 = (
			get_global_transform_with_canvas() * event.position
		)
		if event.pressed:
			if begin_command_drag(screen_position):
				accept_event()
			elif _show_node_click_information(screen_position):
				accept_event()
			else:
				return
		else:
			var had_drag_candidate := (
				_drag_candidate or _command_dragging
			)
			if had_drag_candidate:
				end_command_drag(screen_position)
				accept_event()
	elif event is InputEventMouseMotion:
		if not _drag_candidate:
			return
		var screen_position: Vector2 = (
			get_global_transform_with_canvas() * event.position
		)
		update_command_drag(screen_position)
		accept_event()


func start_new_run() -> void:
	cancel_command_drag(false)
	current_node_id = NODE_CAMP
	soldiers = STARTING_SOLDIERS
	outcome = OUTCOME_NONE
	last_summary = ""
	_run_finished_emitted = false
	_resolving_command = false
	result_panel.visible = false
	status_label.text = "按住我军节点，拖向相邻据点派兵。"
	_refresh_presentation()


func choose_node(target_node_id: StringName) -> bool:
	if outcome != OUTCOME_NONE or _resolving_command:
		return false
	if not get_available_node_ids().has(target_node_id):
		return false

	_resolving_command = true
	current_node_id = target_node_id
	if target_node_id == NODE_REINFORCEMENT:
		soldiers += REINFORCEMENT_SOLDIERS
		status_label.text = "山路援军加入：兵力 +%d。" % (
			REINFORCEMENT_SOLDIERS
		)
	elif target_node_id == NODE_OUTPOST:
		_resolve_enemy_node("黑石前哨", OUTPOST_ENEMIES, false)
	elif target_node_id == NODE_FORTRESS:
		_resolve_enemy_node("黑石堡", FORTRESS_ENEMIES, true)

	_refresh_presentation()
	_resolving_command = false
	return true


func begin_command_drag(screen_position: Vector2) -> bool:
	if (
		outcome != OUTCOME_NONE
		or _resolving_command
		or result_panel.visible
		or _drag_candidate
	):
		return false
	var source_node_id := _get_node_id_at_screen_position(screen_position)
	if source_node_id != current_node_id:
		return false
	_drag_candidate = true
	_command_dragging = false
	_drag_start_screen = screen_position
	_hovered_target_id = &""
	return true


func update_command_drag(screen_position: Vector2) -> bool:
	if not _drag_candidate or outcome != OUTCOME_NONE:
		return false
	if not _command_dragging:
		if (
			screen_position.distance_to(_drag_start_screen)
			< COMMAND_DRAG_THRESHOLD
		):
			return true
		_command_dragging = true
		command_line.visible = true
		command_arrow.visible = true
		status_label.text = "拖向高亮的相邻据点，松开下令。"
	_update_command_line(screen_position)
	return true


func end_command_drag(screen_position: Vector2) -> bool:
	if not _drag_candidate:
		return false
	if not _command_dragging:
		_clear_command_drag_state()
		status_label.text = "轻点不会派兵；请按住我军节点并拖向目标。"
		_refresh_node_highlights()
		return false

	_update_command_line(screen_position)
	var target_node_id := _hovered_target_id
	var is_valid_target := get_available_node_ids().has(target_node_id)
	_clear_command_drag_state()
	_refresh_node_highlights()
	if not is_valid_target:
		status_label.text = "无效目标：命令已取消，战区状态未改变。"
		return false
	return choose_node(target_node_id)


func cancel_command_drag(show_message := true) -> bool:
	if not _drag_candidate and not _command_dragging:
		command_line.visible = false
		command_arrow.visible = false
		_hovered_target_id = &""
		_refresh_node_highlights()
		return false
	_clear_command_drag_state()
	_refresh_node_highlights()
	if show_message:
		status_label.text = "指挥已取消，战区状态未改变。"
	return true


func is_command_drag_active() -> bool:
	return _drag_candidate


func is_command_line_visible() -> bool:
	return command_line.visible and command_arrow.visible


func get_hovered_target_id() -> StringName:
	return _hovered_target_id


func get_available_node_ids() -> Array[StringName]:
	if outcome != OUTCOME_NONE:
		return []
	match current_node_id:
		NODE_CAMP:
			return [NODE_REINFORCEMENT, NODE_OUTPOST]
		NODE_REINFORCEMENT:
			return [NODE_OUTPOST]
		NODE_OUTPOST:
			return [NODE_FORTRESS]
	return []


func get_soldiers() -> int:
	return soldiers


func get_outcome() -> StringName:
	return outcome


func get_current_node_id() -> StringName:
	return current_node_id


func request_return_to_city() -> void:
	cancel_command_drag(false)
	return_to_city_requested.emit()


func handle_escape() -> bool:
	if cancel_command_drag():
		return true
	request_return_to_city()
	return true


func _resolve_enemy_node(
	display_name: String,
	enemy_count: int,
	is_final_node: bool
) -> void:
	var soldiers_before := soldiers
	if soldiers_before <= enemy_count:
		soldiers = 0
		_finish_run(
			OUTCOME_DEFEAT,
			"%s：我方 %d 对敌军 %d，兵力不足，出征失败。"
			% [display_name, soldiers_before, enemy_count]
		)
		return

	soldiers -= enemy_count
	if is_final_node:
		_finish_run(
			OUTCOME_VICTORY,
			"%s：我方 %d 对敌军 %d，剩余 %d 人，成功攻下黑石堡。"
			% [display_name, soldiers_before, enemy_count, soldiers]
		)
	else:
		status_label.text = (
			"%s胜利：%d - %d = %d 人。下一目标是黑石堡。"
			% [display_name, soldiers_before, enemy_count, soldiers]
		)


func _finish_run(next_outcome: StringName, summary: String) -> void:
	cancel_command_drag(false)
	outcome = next_outcome
	last_summary = summary
	result_panel.visible = true
	result_title.text = (
		"黑石堡战斗胜利"
		if outcome == OUTCOME_VICTORY
		else "出征失败"
	)
	result_details.text = summary
	if not _run_finished_emitted:
		_run_finished_emitted = true
		run_finished.emit(outcome, soldiers, summary)


func _refresh_presentation() -> void:
	soldiers_label.text = "当前兵力：%d" % soldiers
	var available := get_available_node_ids()
	camp_button.disabled = false
	reinforcement_button.disabled = false
	outpost_button.disabled = false
	fortress_button.disabled = false
	_set_node_button_text(
		camp_button,
		"我方营地\n起点 · 10 名士兵",
		available.has(NODE_CAMP)
	)
	_set_node_button_text(
		reinforcement_button,
		"山路援军\n+6 名士兵",
		available.has(NODE_REINFORCEMENT)
	)
	_set_node_button_text(
		outpost_button,
		"黑石前哨\n敌军 5 人",
		available.has(NODE_OUTPOST)
	)
	_set_node_button_text(
		fortress_button,
		"黑石堡\n敌军 8 人",
		available.has(NODE_FORTRESS)
	)
	_move_army_marker()
	_refresh_node_highlights()


func _set_node_button_text(
	button: Button,
	base_text: String,
	is_available: bool
) -> void:
	button.text = (
		"可派兵 ◀\n%s" % base_text
		if is_available
		else base_text
	)


func _move_army_marker() -> void:
	var target_button := camp_button
	match current_node_id:
		NODE_REINFORCEMENT:
			target_button = reinforcement_button
		NODE_OUTPOST:
			target_button = outpost_button
		NODE_FORTRESS:
			target_button = fortress_button
	army_marker.position = (
		target_button.position
		+ Vector2(target_button.size.x * 0.5 - 32.0, -42.0)
	)


func _update_command_line(screen_position: Vector2) -> void:
	var start_button := _get_node_button(current_node_id)
	if start_button == null:
		cancel_command_drag(false)
		return
	var battlefield_inverse := (
		battlefield.get_global_transform_with_canvas().affine_inverse()
	)
	var start_position := (
		start_button.position + start_button.size * 0.5
	)
	var end_position := battlefield_inverse * screen_position
	command_line.points = PackedVector2Array([
		start_position,
		end_position,
	])
	_hovered_target_id = _get_node_id_at_screen_position(screen_position)
	var is_valid_target := get_available_node_ids().has(
		_hovered_target_id
	)
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


func _clear_command_drag_state() -> void:
	_drag_candidate = false
	_command_dragging = false
	_drag_start_screen = Vector2.ZERO
	_hovered_target_id = &""
	command_line.visible = false
	command_arrow.visible = false


func _refresh_node_highlights() -> void:
	var available := get_available_node_ids()
	for node_id in [
		NODE_CAMP,
		NODE_REINFORCEMENT,
		NODE_OUTPOST,
		NODE_FORTRESS,
	]:
		var button := _get_node_button(node_id)
		if button == null:
			continue
		button.modulate = (
			CURRENT_NODE_COLOR
			if node_id == current_node_id
			else Color.WHITE
		)
		if _command_dragging and available.has(node_id):
			button.modulate = AVAILABLE_NODE_COLOR
		if _command_dragging and node_id == _hovered_target_id:
			button.modulate = (
				VALID_TARGET_COLOR
				if available.has(node_id)
				else INVALID_TARGET_COLOR
			)


func _show_node_click_information(screen_position: Vector2) -> bool:
	var node_id := _get_node_id_at_screen_position(screen_position)
	if node_id == &"":
		return false
	if node_id == current_node_id:
		status_label.text = "我军驻扎于%s；按住此节点并拖向目标。" % (
			_get_node_display_name(node_id)
		)
	else:
		status_label.text = "%s：点击仅查看，派兵必须从当前我军节点拖出。" % (
			_get_node_display_name(node_id)
		)
	return true


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
