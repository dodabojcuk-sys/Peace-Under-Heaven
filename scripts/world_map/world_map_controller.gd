class_name WorldMapController
extends Node2D


signal return_to_city_requested
signal noticeboard_requested

const PresentationModel = preload(
	"res://scripts/world_map/world_map_presentation_model.gd"
)
const NODE_HIT_RADIUS := 72.0
const FORMATION_HIT_RADIUS := 58.0
const ROAD_HIT_DISTANCE := 24.0
const OVERVIEW_MARGIN_LEFT := 130.0
const OVERVIEW_MARGIN_RIGHT := 130.0
const OVERVIEW_MARGIN_TOP := 80.0
const OVERVIEW_MARGIN_BOTTOM := 98.0
const PANEL_MAP_GAP := 12.0
const SELECTION_SCREEN_MARGIN := 68.0

@onready var map_board: Control = $MapBoard
@onready var world_canvas: WorldMapCanvas = $WorldCanvas
@onready var ui_root: Control = $UI/Root
@onready var top_bar: Control = $UI/Root/TopBar
@onready var map_title: Label = $UI/Root/TopBar/MapTitle
@onready var status_summary: Label = $UI/Root/TopBar/StatusSummary
@onready var return_button: Button = $UI/Root/TopBar/ReturnButton
@onready var home_button: Button = $UI/Root/TopBar/HomeButton
@onready var overview_button: Button = $UI/Root/TopBar/OverviewButton
@onready var side_panel: Panel = $UI/Root/SidePanel
@onready var panel_title: Label = $UI/Root/SidePanel/PanelTitle
@onready var panel_close_button: Button = $UI/Root/SidePanel/CloseButton
@onready var info_label: Label = (
	$UI/Root/SidePanel/Scroll/Content/InfoLabel
)
@onready var action_hint: Label = (
	$UI/Root/SidePanel/Scroll/Content/ActionHint
)
@onready var set_target_button: Button = (
	$UI/Root/SidePanel/Scroll/Content/SetTargetButton
)
@onready var enter_city_button: Button = (
	$UI/Root/SidePanel/Scroll/Content/EnterCityButton
)
@onready var view_task_button: Button = (
	$UI/Root/SidePanel/Scroll/Content/ViewTaskButton
)

var _presentation_model := PresentationModel.new()
var _city_state_source: Node
var _snapshot: Dictionary = {}
var _selected_kind := &""
var _selected_id := &""
var _planned_route: Dictionary = {}
var _is_open := false


func _ready() -> void:
	return_button.pressed.connect(_request_return_to_city)
	home_button.pressed.connect(_request_center_home)
	overview_button.pressed.connect(_request_overview)
	panel_close_button.pressed.connect(clear_selection)
	set_target_button.pressed.connect(_set_selected_node_as_target)
	enter_city_button.pressed.connect(_enter_selected_city)
	view_task_button.pressed.connect(_view_selected_task)
	_build_snapshot()
	hide_world_map()


func configure(city_state_source: Node) -> void:
	_city_state_source = city_state_source
	if (
		_city_state_source != null
		and _city_state_source.has_signal("city_state_changed")
	):
		var refresh_callable := Callable(self, "_on_city_state_changed")
		if not _city_state_source.is_connected(
			"city_state_changed",
			refresh_callable
		):
			_city_state_source.connect(
				"city_state_changed",
				refresh_callable
			)
	_build_snapshot()


func show_world_map() -> void:
	_is_open = true
	visible = true
	ui_root.visible = true
	clear_selection()
	_build_snapshot()


func hide_world_map() -> void:
	_is_open = false
	clear_selection()
	ui_root.visible = false
	visible = false


func is_world_map_open() -> bool:
	return _is_open


func get_map_board() -> Control:
	return map_board


func get_map_size() -> Vector2:
	return Vector2(_snapshot.get("map_size", PresentationModel.MAP_SIZE))


func get_overview_center() -> Vector2:
	return get_overview_bounds().get_center()


func get_overview_bounds() -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for node in _snapshot.get("nodes", []):
		var position := Vector2(node.get("position", Vector2.ZERO))
		minimum.x = minf(minimum.x, position.x)
		minimum.y = minf(minimum.y, position.y)
		maximum.x = maxf(maximum.x, position.x)
		maximum.y = maxf(maximum.y, position.y)
	if not is_finite(minimum.x) or not is_finite(maximum.x):
		return Rect2(Vector2.ZERO, get_map_size())
	minimum -= Vector2(OVERVIEW_MARGIN_LEFT, OVERVIEW_MARGIN_TOP)
	maximum += Vector2(OVERVIEW_MARGIN_RIGHT, OVERVIEW_MARGIN_BOTTOM)
	return Rect2(minimum, maximum - minimum)


func get_home_position() -> Vector2:
	var home := _presentation_model.get_node(
		_snapshot,
		PresentationModel.HOME_NODE_ID
	)
	return Vector2(home.get("position", get_overview_center()))


func get_navigation_safe_rect(viewport_rect: Rect2) -> Rect2:
	var top := viewport_rect.position.y
	var right := viewport_rect.end.x
	if top_bar.is_visible_in_tree():
		top = maxf(top, top_bar.get_global_rect().end.y)
	if side_panel.is_visible_in_tree():
		right = minf(
			right,
			side_panel.get_global_rect().position.x - PANEL_MAP_GAP
		)
	return Rect2(
		Vector2(viewport_rect.position.x, top),
		Vector2(
			maxf(right - viewport_rect.position.x, 0.0),
			viewport_rect.end.y - top
		)
	)


func is_screen_point_blocked(screen_position: Vector2) -> bool:
	for control in [top_bar, side_panel]:
		if (
			control.is_visible_in_tree()
			and control.get_global_rect().has_point(screen_position)
		):
			return true
	return false


func handle_screen_click(screen_position: Vector2) -> void:
	if is_screen_point_blocked(screen_position):
		return
	var local_position := (
		world_canvas.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)
	handle_world_click(local_position)


func handle_world_click(world_position: Vector2) -> void:
	var formation: Dictionary = _snapshot.get("formation", {})
	if (
		not formation.is_empty()
		and world_position.distance_to(
			Vector2(formation.get("position", Vector2.ZERO))
		) <= FORMATION_HIT_RADIUS
	):
		select_formation()
		return

	var nearest_node_id := &""
	var nearest_node_distance := INF
	for node in _snapshot.get("nodes", []):
		var distance := world_position.distance_to(
			Vector2(node.get("position", Vector2.ZERO))
		)
		if distance <= NODE_HIT_RADIUS and distance < nearest_node_distance:
			nearest_node_distance = distance
			nearest_node_id = StringName(node.get("id", &""))
	if nearest_node_id != &"":
		select_node(nearest_node_id)
		return

	var nearest_road_id := &""
	var nearest_road_distance := INF
	for road in _snapshot.get("roads", []):
		var distance := _distance_to_path(
			world_position,
			road.get("path", [])
		)
		if distance <= ROAD_HIT_DISTANCE and distance < nearest_road_distance:
			nearest_road_distance = distance
			nearest_road_id = StringName(road.get("id", &""))
	if nearest_road_id != &"":
		select_road(nearest_road_id)
		return
	clear_selection()


func select_node(node_id: StringName) -> bool:
	var node := _presentation_model.get_node(_snapshot, node_id)
	if node.is_empty():
		return false
	_selected_kind = &"NODE"
	_selected_id = node_id
	_planned_route = {}
	_show_node_panel(node)
	_ensure_anchor_visible(Vector2(node.get("position", Vector2.ZERO)))
	_refresh_canvas()
	return true


func select_road(road_id: StringName) -> bool:
	var road := _presentation_model.get_road(_snapshot, road_id)
	if road.is_empty():
		return false
	_selected_kind = &"ROAD"
	_selected_id = road_id
	_planned_route = {}
	panel_title.text = str(road.get("name", "道路"))
	info_label.text = (
		"道路：%s\n连接：%s → %s\n状态：%s\n\n"
		+ "该道路当前只支持查看与路线预览。"
	) % [
		str(road.get("name", "")),
		_node_name(StringName(road.get("from", &""))),
		_node_name(StringName(road.get("to", &""))),
		str(road.get("status_label", "")),
	]
	action_hint.text = _road_action_hint(StringName(road.get("status", &"")))
	set_target_button.visible = false
	enter_city_button.visible = false
	view_task_button.visible = false
	side_panel.visible = true
	_ensure_anchor_visible(_road_anchor(road))
	_refresh_canvas()
	return true


func select_formation() -> bool:
	var formation: Dictionary = _snapshot.get("formation", {})
	if formation.is_empty():
		return false
	_selected_kind = &"FORMATION"
	_selected_id = StringName(formation.get("id", &""))
	panel_title.text = str(formation.get("name", "玩家编队"))
	info_label.text = (
		"归属：%s\n兵力：%s\n位置：%s\n\n"
		+ "编队位置为非持久 Graybox 演示；兵力摘要来自当前城市真实状态。"
	) % [
		str(formation.get("owner_label", "")),
		str(formation.get("troop_summary", "")),
		str(formation.get("status", "")),
	]
	action_hint.text = (
		str(_planned_route.get("status", "选择一处地图节点以预览计划路线"))
	)
	set_target_button.visible = false
	enter_city_button.visible = false
	view_task_button.visible = false
	side_panel.visible = true
	_ensure_anchor_visible(
		Vector2(formation.get("position", Vector2.ZERO))
	)
	_refresh_canvas()
	return true


func clear_selection() -> void:
	_selected_kind = &""
	_selected_id = &""
	side_panel.visible = false
	_refresh_canvas()


func handle_escape() -> bool:
	if side_panel.visible:
		clear_selection()
		return true
	_request_return_to_city()
	return true


func set_target_node(node_id: StringName) -> bool:
	var route := _presentation_model.build_route_preview(
		_snapshot,
		node_id
	)
	if route.is_empty():
		return false
	_planned_route = route
	_selected_kind = &"NODE"
	_selected_id = node_id
	var node := _presentation_model.get_node(_snapshot, node_id)
	_show_node_panel(node)
	action_hint.text = str(route.get("status", ""))
	_ensure_anchor_visible(Vector2(node.get("position", Vector2.ZERO)))
	_refresh_canvas()
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_selected_kind() -> StringName:
	return _selected_kind


func get_selected_id() -> StringName:
	return _selected_id


func get_planned_route() -> Dictionary:
	return _planned_route.duplicate(true)


func get_map_ui_controls() -> Array[Control]:
	return [top_bar, side_panel]


func get_selected_anchor_world() -> Vector2:
	match _selected_kind:
		&"NODE":
			var node := _presentation_model.get_node(_snapshot, _selected_id)
			return Vector2(node.get("position", Vector2.ZERO))
		&"ROAD":
			var road := _presentation_model.get_road(_snapshot, _selected_id)
			return _road_anchor(road)
		&"FORMATION":
			var formation: Dictionary = _snapshot.get("formation", {})
			return Vector2(formation.get("position", Vector2.ZERO))
	return Vector2.ZERO


func _build_snapshot() -> void:
	var city_state: Dictionary = {}
	var missions: Array[Dictionary] = []
	if _city_state_source != null:
		if _city_state_source.has_method("get_city_state"):
			city_state = _city_state_source.get_city_state()
		if (
			_city_state_source.has_method("get_noticeboard_mission_ids")
			and _city_state_source.has_method(
				"get_noticeboard_mission_definition"
			)
		):
			for mission_id in (
				_city_state_source.get_noticeboard_mission_ids()
			):
				var definition = (
					_city_state_source.get_noticeboard_mission_definition(
						mission_id
					)
				)
				if definition == null:
					continue
				var mission_state := &"AVAILABLE"
				if _city_state_source.has_method(
					"get_noticeboard_mission_state"
				):
					mission_state = (
						_city_state_source.get_noticeboard_mission_state(
							mission_id
						)
					)
				missions.append({
					"mission_id": definition.mission_id,
					"display_name": definition.title,
					"objective_summary": definition.objective_text,
					"state": mission_state,
					"state_label": _mission_state_label(mission_state),
				})
	_snapshot = _presentation_model.build_snapshot(city_state, missions)
	map_title.text = str(_snapshot.get("map_name", "外城战役地图"))
	status_summary.text = "第 %d 日 · 黑石城至河湾城" % int(
		city_state.get("day", 1)
	)
	_refresh_canvas()


func _show_node_panel(node: Dictionary) -> void:
	var mission_lines: Array[String] = []
	for mission in node.get("missions", []):
		mission_lines.append(
			"%s（%s）" % [
				str(mission.get("display_name", "")),
				str(mission.get("state_label", "")),
			]
		)
	var mission_text := (
		"无已关联任务"
		if mission_lines.is_empty()
		else "\n".join(mission_lines)
	)
	panel_title.text = str(node.get("name", "地图节点"))
	info_label.text = (
		"类型：%s\n归属：%s\n状态：%s\n驻军：%s\n\n关联任务：\n%s"
	) % [
		str(node.get("type", "")),
		str(node.get("owner_label", "")),
		str(node.get("status", "")),
		str(node.get("garrison_summary", "尚未侦察")),
		mission_text,
	]
	set_target_button.visible = true
	set_target_button.disabled = (
		StringName(node.get("id", &"")) == PresentationModel.HOME_NODE_ID
	)
	enter_city_button.visible = true
	enter_city_button.disabled = (
		StringName(node.get("id", &"")) != PresentationModel.HOME_NODE_ID
	)
	view_task_button.visible = not mission_lines.is_empty()
	view_task_button.disabled = mission_lines.is_empty()
	action_hint.text = _node_action_hint(node)
	side_panel.visible = true


func _node_action_hint(node: Dictionary) -> String:
	var node_id := StringName(node.get("id", &""))
	if node_id == PresentationModel.HOME_NODE_ID:
		return "黑石城可返回内城；编队当前驻扎于此。"
	if not _planned_route.is_empty() and _selected_id == node_id:
		return str(_planned_route.get("status", ""))
	if StringName(node.get("owner", &"")) == &"ENEMY":
		return "敌方城池；正式行军与战斗尚未实现。"
	return "可设为计划目标；只显示路线，不会推进时间或结算行军。"


func _set_selected_node_as_target() -> void:
	if _selected_kind != &"NODE":
		return
	set_target_node(_selected_id)


func _enter_selected_city() -> void:
	if (
		_selected_kind == &"NODE"
		and _selected_id == PresentationModel.HOME_NODE_ID
	):
		_request_return_to_city()


func _view_selected_task() -> void:
	if _selected_kind != &"NODE":
		return
	var node := _presentation_model.get_node(_snapshot, _selected_id)
	if (node.get("missions", []) as Array).is_empty():
		return
	noticeboard_requested.emit()


func _request_return_to_city() -> void:
	if not _is_open:
		return
	return_to_city_requested.emit()


func _request_center_home() -> void:
	if not _is_open:
		return
	var parent := get_parent()
	if parent != null and parent.has_method("center_world_map_on_home"):
		parent.center_world_map_on_home()


func _request_overview() -> void:
	if not _is_open:
		return
	var parent := get_parent()
	if parent != null and parent.has_method("show_world_map_overview"):
		parent.show_world_map_overview()


func _on_city_state_changed() -> void:
	if not _is_open:
		return
	var previous_kind := _selected_kind
	var previous_id := _selected_id
	_build_snapshot()
	if previous_kind == &"NODE":
		select_node(previous_id)
	elif previous_kind == &"ROAD":
		select_road(previous_id)
	elif previous_kind == &"FORMATION":
		select_formation()


func _refresh_canvas() -> void:
	if not is_node_ready():
		return
	world_canvas.set_snapshot(_snapshot)
	world_canvas.set_selection(_selected_kind, _selected_id)
	world_canvas.set_planned_route(_planned_route)


func _ensure_anchor_visible(world_position: Vector2) -> void:
	var parent := get_parent()
	if (
		parent != null
		and parent.has_method("ensure_world_map_position_visible")
	):
		parent.ensure_world_map_position_visible(
			world_position,
			SELECTION_SCREEN_MARGIN
		)


func _road_anchor(road: Dictionary) -> Vector2:
	var path: Array = road.get("path", [])
	if path.is_empty():
		return Vector2.ZERO
	return Vector2(path[path.size() >> 1])


func _node_name(node_id: StringName) -> String:
	var node := _presentation_model.get_node(_snapshot, node_id)
	return str(node.get("name", node_id))


func _road_action_hint(status: StringName) -> String:
	match status:
		&"OPEN":
			return "道路畅通；本轮仅支持查看。"
		&"DANGEROUS":
			return "道路危险；正式风险结算尚未实现。"
		&"BLOCKED":
			return "道路封锁；当前不能执行正式行军。"
		&"UNSCOUTED":
			return "道路尚未侦察；不显示虚构情报。"
	return "道路状态未知。"


func _mission_state_label(state: StringName) -> String:
	match state:
		&"AVAILABLE":
			return "可接受"
		&"IN_PROGRESS":
			return "进行中"
		&"COMPLETED":
			return "已完成"
		_:
			return "状态未知"


func _distance_to_path(point: Vector2, path_value: Variant) -> float:
	var path: Array = path_value
	if path.size() < 2:
		return INF
	var best := INF
	for index in range(path.size() - 1):
		best = minf(
			best,
			_distance_to_segment(
				point,
				Vector2(path[index]),
				Vector2(path[index + 1])
			)
		)
	return best


func _distance_to_segment(
	point: Vector2,
	start: Vector2,
	end: Vector2
) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf(
		(point - start).dot(segment) / segment.length_squared(),
		0.0,
		1.0
	)
	return point.distance_to(start + segment * ratio)
