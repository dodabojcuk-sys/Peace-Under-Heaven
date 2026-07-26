extends Node2D


const DRAG_THRESHOLD := 8.0
const MIN_ZOOM := 0.6
const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1

@onready var camera: Camera2D = $Camera2D
@onready var map_board: Control = $MapWorld/MapBoard
@onready var city_map_world: Node2D = $MapWorld
@onready var city_ui_shell: Control = $UI/Shell
@onready var campaign_world_map: WorldMapController = $CampaignWorldMap
@onready var construction_controller: Node = $ConstructionController
@onready var building_selection_controller: Node = $BuildingSelectionController
@onready var top_status_bar: Control = $UI/Shell/TopStatusBar
@onready var city_bar: Control = $UI/Shell/CityBar
@onready var city_bar_toggle: Button = $UI/Shell/CityBarToggle

var active_drag_button: int = -1
var last_pointer_screen := Vector2.ZERO
var pending_drag_delta := Vector2.ZERO
var is_dragging := false
var city_bar_expanded := false
var world_map_open := false
var _city_camera_position := Vector2.ZERO
var _city_camera_zoom := Vector2.ONE


func _ready() -> void:
	get_viewport().size_changed.connect(_clamp_camera)
	construction_controller.construction_interaction_started.connect(
		_on_construction_interaction_started
	)
	construction_controller.placing_started.connect(_on_construction_placing_started)
	city_bar_toggle.pressed.connect(toggle_city_bar)
	campaign_world_map.return_to_city_requested.connect(
		return_from_campaign_world_map
	)
	campaign_world_map.noticeboard_requested.connect(
		_on_world_map_noticeboard_requested
	)
	campaign_world_map.configure(construction_controller)
	set_city_bar_expanded(false)
	call_deferred("_initialize_camera")


func _input(event: InputEvent) -> void:
	if world_map_open:
		_handle_world_map_input(event)
		return

	if (
		event is InputEventMouseButton
		and event.pressed
		and building_selection_controller.is_screen_point_blocked(event.position)
	):
		return

	if construction_controller.is_placing():
		_handle_construction_input(event)
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if (
				construction_controller.handle_escape()
				or building_selection_controller.handle_escape()
			):
				get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(event)
		else:
			_handle_drag_button(event)
	elif event is InputEventMouseMotion:
		_handle_drag_motion(event)


func _handle_construction_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			construction_controller.cancel_placing()
			_stop_drag()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(event)
			construction_controller.update_preview(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_handle_drag_button(event)
			construction_controller.update_preview(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			construction_controller.cancel_placing()
			_stop_drag()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			construction_controller.confirm_current_preview()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_handle_drag_motion(event)
		construction_controller.update_preview(event.position)


func _handle_drag_button(event: InputEventMouseButton) -> void:
	if (
		event.button_index != MOUSE_BUTTON_LEFT
		and event.button_index != MOUSE_BUTTON_MIDDLE
		and event.button_index != MOUSE_BUTTON_RIGHT
	):
		return

	if event.pressed:
		if active_drag_button != -1:
			return
		active_drag_button = event.button_index
		last_pointer_screen = event.position
		pending_drag_delta = Vector2.ZERO
		is_dragging = false
	elif event.button_index == active_drag_button:
		var is_map_click := (
			event.button_index == MOUSE_BUTTON_LEFT
			and not is_dragging
			and pending_drag_delta.length() < DRAG_THRESHOLD
		)
		_stop_drag()
		if is_map_click:
			if world_map_open:
				campaign_world_map.handle_screen_click(event.position)
			else:
				building_selection_controller.handle_map_click(event.position)


func _handle_drag_motion(event: InputEventMouseMotion) -> void:
	if active_drag_button == -1:
		return

	var screen_delta := event.position - last_pointer_screen
	last_pointer_screen = event.position
	pending_drag_delta += screen_delta
	if not is_dragging:
		if pending_drag_delta.length() < DRAG_THRESHOLD:
			return
		is_dragging = true

	screen_delta = pending_drag_delta
	pending_drag_delta = Vector2.ZERO
	camera.position -= screen_delta / camera.zoom.x
	_clamp_camera()


func _handle_zoom(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return

	var zoom_direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
	var old_zoom := camera.zoom.x
	var new_zoom := clampf(old_zoom + zoom_direction * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, old_zoom):
		return

	var viewport_size := get_viewport_rect().size
	var cursor_from_center := event.position - viewport_size * 0.5
	var world_under_cursor := camera.position + cursor_from_center / old_zoom
	camera.zoom = Vector2.ONE * new_zoom
	camera.position = world_under_cursor - cursor_from_center / new_zoom
	_clamp_camera()


func _initialize_camera() -> void:
	camera.enabled = true
	camera.zoom = Vector2.ONE
	center_world_position_in_safe_area(map_board.size * 0.5)
	_clamp_camera()


func _stop_drag() -> void:
	active_drag_button = -1
	pending_drag_delta = Vector2.ZERO
	is_dragging = false


func _on_construction_placing_started() -> void:
	_stop_drag()
	building_selection_controller.clear_selection()


func _on_construction_interaction_started() -> void:
	_stop_drag()
	building_selection_controller.clear_selection()


func toggle_city_bar() -> void:
	set_city_bar_expanded(not city_bar_expanded)


func set_city_bar_expanded(expanded: bool) -> void:
	var old_safe_rect := get_navigation_safe_rect()
	city_bar_expanded = expanded
	city_bar.visible = city_bar_expanded
	city_bar_toggle.text = "收起" if city_bar_expanded else "展开"
	city_bar_toggle.position.x = 160.0 if city_bar_expanded else 8.0
	if not is_node_ready():
		return
	var new_safe_rect := get_navigation_safe_rect()
	camera.position += (
		old_safe_rect.get_center() - new_safe_rect.get_center()
	) / camera.zoom.x
	_clamp_camera()


func is_city_bar_expanded() -> bool:
	return city_bar_expanded


func get_navigation_safe_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	if world_map_open:
		return campaign_world_map.get_navigation_safe_rect(viewport_rect)
	var left := viewport_rect.position.x
	var top := viewport_rect.position.y
	if top_status_bar.is_visible_in_tree():
		top = maxf(top, top_status_bar.get_global_rect().end.y)
	if city_bar_expanded and city_bar.is_visible_in_tree():
		left = maxf(left, city_bar.get_global_rect().end.x)
	return Rect2(
		Vector2(left, top),
		Vector2(viewport_rect.end.x - left, viewport_rect.end.y - top)
	)


func center_world_position_in_safe_area(world_position: Vector2) -> void:
	var viewport_center := get_viewport_rect().get_center()
	var safe_center := get_navigation_safe_rect().get_center()
	camera.position = world_position - (
		(safe_center - viewport_center) / camera.zoom.x
	)


func focus_world_rect_in_safe_area(
	world_rect: Rect2,
	fit_zoom := false
) -> void:
	if fit_zoom and world_rect.size.x > 0.0 and world_rect.size.y > 0.0:
		var safe_size := get_navigation_safe_rect().size
		var fit_scale := minf(
			safe_size.x / world_rect.size.x,
			safe_size.y / world_rect.size.y
		)
		var target_zoom := clampf(fit_scale, MIN_ZOOM, MAX_ZOOM)
		camera.zoom = Vector2.ONE * target_zoom
	center_world_position_in_safe_area(world_rect.get_center())
	_clamp_camera()


func _clamp_camera() -> void:
	var map_size := map_board.size
	var viewport_rect := get_viewport_rect()
	var viewport_center := viewport_rect.get_center()
	var safe_rect := get_navigation_safe_rect()
	var minimum := (viewport_center - safe_rect.position) / camera.zoom.x
	var maximum := map_size - (safe_rect.end - viewport_center) / camera.zoom.x

	if minimum.x > maximum.x:
		camera.position.x = (
			map_size.x * 0.5
			- (safe_rect.get_center().x - viewport_center.x) / camera.zoom.x
		)
	else:
		camera.position.x = clampf(camera.position.x, minimum.x, maximum.x)

	if minimum.y > maximum.y:
		camera.position.y = (
			map_size.y * 0.5
			- (safe_rect.get_center().y - viewport_center.y) / camera.zoom.x
		)
	else:
		camera.position.y = clampf(camera.position.y, minimum.y, maximum.y)


func open_campaign_world_map() -> bool:
	if world_map_open:
		return false
	_stop_drag()
	construction_controller.cancel_build_interaction()
	building_selection_controller.clear_selection()
	_city_camera_position = camera.position
	_city_camera_zoom = camera.zoom
	city_map_world.visible = false
	city_ui_shell.visible = false
	world_map_open = true
	campaign_world_map.show_world_map()
	map_board = campaign_world_map.get_map_board()
	camera.zoom = Vector2.ONE * 0.64
	center_world_position_in_safe_area(
		campaign_world_map.get_overview_center()
	)
	_clamp_camera()
	return true


func return_from_campaign_world_map() -> bool:
	if not world_map_open:
		return false
	_stop_drag()
	campaign_world_map.hide_world_map()
	world_map_open = false
	map_board = city_map_world.get_node("MapBoard") as Control
	city_map_world.visible = true
	city_ui_shell.visible = true
	camera.zoom = _city_camera_zoom
	camera.position = _city_camera_position
	_clamp_camera()
	return true


func center_world_map_on_home() -> void:
	if not world_map_open:
		return
	center_world_position_in_safe_area(
		campaign_world_map.get_home_position()
	)
	_clamp_camera()


func is_campaign_world_map_open() -> bool:
	return world_map_open


func _handle_world_map_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			campaign_world_map.handle_escape()
			_stop_drag()
			get_viewport().set_input_as_handled()
		return

	if (
		event is InputEventMouseButton
		and event.pressed
		and campaign_world_map.is_screen_point_blocked(event.position)
	):
		return

	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_WHEEL_UP
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			_handle_zoom(event)
		else:
			_handle_drag_button(event)
	elif event is InputEventMouseMotion:
		_handle_drag_motion(event)


func _on_world_map_noticeboard_requested() -> void:
	if not return_from_campaign_world_map():
		return
	construction_controller.show_noticeboard_panel()
	construction_controller.set_detail_panel_active(true)
