extends Node2D


const DRAG_THRESHOLD := 8.0
const MIN_ZOOM := 0.6
const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1
const RUNTIME_PERSISTENCE_COORDINATOR = preload(
	"res://scripts/state/runtime_campaign_persistence_coordinator.gd"
)

@onready var camera: Camera2D = $Camera2D
@onready var map_board: Control = $MapWorld/MapBoard
@onready var city_map_world: Node2D = $MapWorld
@onready var city_ui_shell: Control = $UI/Shell
@onready var campaign_world_map: WorldMapController = $CampaignWorldMap
@onready var macro_march_r0: MacroMarchR0 = (
	$UI/MacroMarchR0
)
@onready var construction_controller: Node = $ConstructionController
@onready var building_selection_controller: Node = $BuildingSelectionController
@onready var top_status_bar: Control = $UI/Shell/TopStatusBar
@onready var city_bar: Control = $UI/Shell/CityBar
@onready var city_bar_toggle: Button = $UI/Shell/CityBarToggle
@onready var minimap: CityMinimapR1 = $UI/Shell/MinimapPlaceholder
@onready var construction_entry_panel: Control = $UI/Shell/ConstructionEntryPanel
@onready var construction_menu: Control = $UI/Shell/ConstructionMenu
@onready var building_detail_panel: Control = $UI/Shell/BuildingDetailPanel
@onready var expedition_preparation_panel: Control = (
	$UI/Shell/ExpeditionPreparationPanel
)
@onready var expedition_entry_button: Button = (
	$UI/Shell/BuildingDetailPanel/FirstWarActions/MacroMarchEntryButton
)
@onready var macro_march_entry_button: Button = $UI/Shell/MacroMarchButton
@onready var expedition_result_status: Label = (
	$UI/Shell/BuildingDetailPanel/FirstWarActions/MacroMarchStatus
)

var active_drag_button: int = -1
var last_pointer_screen := Vector2.ZERO
var pending_drag_delta := Vector2.ZERO
var is_dragging := false
var city_bar_expanded := true
var world_map_open := false
var macro_march_open := false
var _city_camera_position := Vector2.ZERO
var _city_camera_zoom := Vector2.ONE
var _runtime_persistence: Node


func _ready() -> void:
	# ConstructionController owns the canonical city state. Wire the already
	# accepted V5 generation store before this root binds presentation listeners.
	_runtime_persistence = RUNTIME_PERSISTENCE_COORDINATOR.new()
	add_child(_runtime_persistence)
	_runtime_persistence.initialize(construction_controller)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	construction_controller.construction_interaction_started.connect(
		_on_construction_interaction_started
	)
	construction_controller.placing_started.connect(_on_construction_placing_started)
	city_bar_toggle.pressed.connect(toggle_city_bar)
	campaign_world_map.return_to_city_requested.connect(
		return_from_campaign_world_map
	)
	campaign_world_map.city_entry_requested.connect(
		_on_city_entry_requested
	)
	campaign_world_map.noticeboard_requested.connect(
		_on_world_map_noticeboard_requested
	)
	expedition_entry_button.pressed.connect(open_macro_march_r0)
	macro_march_entry_button.pressed.connect(open_macro_march_r0)
	macro_march_r0.return_to_city_requested.connect(return_from_macro_march_r0)
	macro_march_r0.configure(construction_controller.get_v5_army_dispatch_adapter())
	construction_controller.city_state_changed.connect(
		_refresh_macro_march_entry
	)
	construction_controller.city_state_changed.connect(_refresh_minimap)
	campaign_world_map.configure(construction_controller)
	# R1 moves city operation into the right build rail. The legacy left rail is
	# collapsible context, not a second permanent panel competing with the city.
	set_city_bar_expanded(false)
	_refresh_macro_march_entry()
	call_deferred("_initialize_camera")
	call_deferred("_refresh_minimap")
	call_deferred("_resume_persisted_expedition_if_needed")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_runtime_persistence(&"window_close")
		get_tree().quit()


func get_runtime_persistence_status() -> Dictionary:
	if _runtime_persistence == null:
		return {"status": "uninitialized"}
	return _runtime_persistence.get_status()


func flush_runtime_persistence(reason: StringName = &"explicit") -> bool:
	if _runtime_persistence == null:
		return false
	return _runtime_persistence.flush_now(reason)


func persist_expedition_departure(attempt_id: StringName) -> Dictionary:
	if _runtime_persistence == null:
		return {"success": false, "uncertain": false}
	return _runtime_persistence.persist_expedition_departure(attempt_id)


func persist_expedition_settlement(
	attempt_id: StringName,
	result_id: StringName
) -> Dictionary:
	if _runtime_persistence == null:
		return {"success": false, "uncertain": false}
	return _runtime_persistence.persist_expedition_settlement(
		attempt_id,
		result_id
	)


func persist_macro_march_checkpoint() -> Dictionary:
	if _runtime_persistence == null:
		return {"success": false}
	return _runtime_persistence.persist_macro_march_checkpoint()


func _input(event: InputEvent) -> void:
	# This fullscreen modal owns every pointer/key while visible. Returning here
	# keeps root map gestures from racing GUI dispatch; the Control handles
	# ui_cancel through its own unhandled-key path.
	if expedition_preparation_panel.visible:
		return
	if macro_march_open:
		if (
			event.is_action_pressed(&"ui_cancel")
		):
			return_from_macro_march_r0()
			get_viewport().set_input_as_handled()
		return

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
		building_selection_controller.clear_hover()
		_handle_construction_input(event)
		return

	if event is InputEventKey:
		if event.is_action_pressed(&"rotate_placement") and not event.echo:
			if construction_controller.rotate_preview():
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_cancel") and not event.echo:
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
		if active_drag_button == -1:
			building_selection_controller.handle_map_hover(event.position)
		else:
			building_selection_controller.clear_hover()
		_handle_drag_motion(event)


func _handle_construction_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.is_action_pressed(&"rotate_placement"):
				if not construction_controller.is_road_placing():
					construction_controller.rotate_preview()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed(&"ui_cancel"):
				construction_controller.handle_escape()
				_stop_drag()
				get_viewport().set_input_as_handled()
		return

	# The construction rail owns pointer input over its controls. The root
	# controller still receives `_input` before Control nodes, so never turn a
	# button hover/click into a new map preview cell or invalidate a valid ghost.
	if (
		event is InputEventMouseButton
		or event is InputEventMouseMotion
	) and construction_controller.is_construction_ui_point(event.position):
		if (
			construction_controller.is_road_placing()
			and event is InputEventMouseButton
			and not event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
			and construction_controller.is_road_drag_active()
		):
			construction_controller.finish_road_drag(event.position)
			get_viewport().set_input_as_handled()
			return
		if (
			event is InputEventMouseButton
			and not event.pressed
			and event.button_index == active_drag_button
		):
			_stop_drag()
		return

	if event is InputEventMouseButton:
		if construction_controller.is_road_placing():
			_handle_road_construction_button(event)
			return
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
			# R0B: the physical map click is the single building commit action.
			# The controller revalidates this exact pointer position before writing.
			construction_controller.commit_building_from_map_click(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if construction_controller.is_road_placing():
			if construction_controller.is_road_drag_active():
				construction_controller.update_road_drag(event.position)
		else:
			_handle_drag_motion(event)
			construction_controller.update_preview(event.position)


func _handle_road_construction_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if construction_controller.has_road_preview():
			construction_controller.cancel_road_preview()
		else:
			construction_controller.cancel_placing()
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_handle_drag_button(event)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if not construction_controller.is_construction_ui_point(event.position):
			construction_controller.begin_road_drag(event.position)
			get_viewport().set_input_as_handled()
	else:
		construction_controller.finish_road_drag(event.position)
		get_viewport().set_input_as_handled()


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
	_refresh_minimap()


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
	_refresh_minimap()


func _initialize_camera() -> void:
	camera.enabled = true
	camera.zoom = Vector2.ONE
	center_world_position_in_safe_area(map_board.size * 0.5)
	_clamp_camera()
	_refresh_minimap()


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
	var right := viewport_rect.end.x
	for rail_control in [
		minimap,
		construction_entry_panel,
		construction_menu,
		building_detail_panel,
	]:
		if rail_control.is_visible_in_tree():
			right = minf(right, rail_control.get_global_rect().position.x)
	return Rect2(
		Vector2(left, top),
		Vector2(right - left, viewport_rect.end.y - top)
	)


func center_world_position_in_safe_area(world_position: Vector2) -> void:
	var viewport_center := get_viewport_rect().get_center()
	var safe_center := get_navigation_safe_rect().get_center()
	camera.position = world_position - (
		(safe_center - viewport_center) / camera.zoom.x
	)
	_refresh_minimap()


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
	_refresh_minimap()


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
	show_world_map_overview()
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


func _on_city_entry_requested(city_id: StringName) -> void:
	if not world_map_open:
		return
	if not construction_controller.has_method("switch_city"):
		return
	if not return_from_campaign_world_map():
		return
	if not construction_controller.switch_city(city_id):
		return
	building_selection_controller.clear_selection()
	construction_controller.cancel_build_interaction()
	_city_camera_position = construction_controller.get_layout_camera_focus()
	_city_camera_zoom = Vector2.ONE
	camera.position = _city_camera_position
	camera.zoom = _city_camera_zoom
	_clamp_camera()
	_refresh_minimap()


func center_world_map_on_home() -> void:
	if not world_map_open:
		return
	center_world_position_in_safe_area(
		campaign_world_map.get_home_position()
	)
	_clamp_camera()


func show_world_map_overview() -> void:
	if not world_map_open:
		return
	campaign_world_map.clear_selection()
	focus_world_rect_in_safe_area(
		campaign_world_map.get_overview_bounds(),
		true
	)


func ensure_world_map_position_visible(
	world_position: Vector2,
	screen_margin := 64.0
) -> void:
	if not world_map_open:
		return
	var safe_rect := get_navigation_safe_rect().grow(-screen_margin)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return
	var screen_position := (
		campaign_world_map.world_canvas.get_global_transform_with_canvas()
		* world_position
	)
	var desired_screen_position := Vector2(
		clampf(
			screen_position.x,
			safe_rect.position.x,
			safe_rect.end.x
		),
		clampf(
			screen_position.y,
			safe_rect.position.y,
			safe_rect.end.y
		)
	)
	camera.position -= (
		desired_screen_position - screen_position
	) / camera.zoom.x
	_clamp_camera()


func is_campaign_world_map_open() -> bool:
	return world_map_open


func open_macro_march_r0() -> bool:
	if (
		macro_march_open
		or world_map_open
		or construction_controller.is_city_action_locked_for_battle()
	):
		_refresh_macro_march_entry()
		return false
	_stop_drag()
	construction_controller.cancel_build_interaction()
	building_selection_controller.clear_selection()
	_city_camera_position = camera.position
	_city_camera_zoom = camera.zoom
	# The outer-city view hides city interaction but must never stop the
	# controller's single authoritative world clock.  Construction input has
	# already been cancelled above and the city shell is hidden below.
	city_map_world.visible = false
	city_ui_shell.visible = false
	macro_march_open = true
	macro_march_r0.visible = true
	macro_march_r0.refresh()
	return true


func return_from_macro_march_r0() -> bool:
	if not macro_march_open:
		return false
	macro_march_r0.visible = false
	macro_march_open = false
	city_map_world.visible = true
	city_ui_shell.visible = true
	camera.zoom = _city_camera_zoom
	camera.position = _city_camera_position
	_clamp_camera()
	_refresh_macro_march_entry()
	return true


func is_macro_march_r0_open() -> bool:
	return macro_march_open


func _refresh_macro_march_entry() -> void:
	var is_locked: bool = (
		construction_controller.is_city_action_locked_for_battle()
	)
	expedition_entry_button.visible = not is_locked
	expedition_result_status.visible = not is_locked
	expedition_entry_button.disabled = is_locked
	macro_march_entry_button.visible = not is_locked
	macro_march_entry_button.disabled = is_locked
	expedition_entry_button.tooltip_text = (
		"敌袭待处理，先完成北坡首战"
		if is_locked
		else "进入黑石外城宏观军令战区"
	)
	macro_march_entry_button.tooltip_text = expedition_entry_button.tooltip_text


func _on_viewport_size_changed() -> void:
	_clamp_camera()
	_refresh_minimap()


func _refresh_minimap() -> void:
	if not is_inside_tree() or not is_node_ready() or not is_instance_valid(minimap):
		return
	minimap.update_world_view(
		camera.position,
		camera.zoom.x,
		get_navigation_safe_rect()
	)
	if construction_controller.has_method("get_layout_profile_id"):
		minimap.set_layout_profile(
			construction_controller.get_layout_profile_id(),
			construction_controller.get_formal_road_cells(),
			construction_controller.get_formal_reserved_cells()
		)
	minimap.set_player_road_cells(
		construction_controller.get_player_road_cells()
	)


func _handle_world_map_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_pressed(&"ui_cancel") and not event.echo:
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


func _resume_persisted_expedition_if_needed() -> void:
	if construction_controller.has_method("resume_persisted_expedition"):
		construction_controller.resume_persisted_expedition()


func _on_world_map_noticeboard_requested() -> void:
	if not return_from_campaign_world_map():
		return
	construction_controller.show_noticeboard_panel()
	construction_controller.set_detail_panel_active(true)
