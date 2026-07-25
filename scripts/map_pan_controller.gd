extends Node2D


const DRAG_THRESHOLD := 8.0
const MIN_ZOOM := 0.6
const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1

@onready var camera: Camera2D = $Camera2D
@onready var map_board: Control = $MapWorld/MapBoard

var active_drag_button: int = -1
var last_pointer_screen := Vector2.ZERO
var pending_drag_delta := Vector2.ZERO
var is_dragging := false


func _ready() -> void:
	get_viewport().size_changed.connect(_clamp_camera)
	call_deferred("_initialize_camera")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(event)
		else:
			_handle_drag_button(event)
	elif event is InputEventMouseMotion:
		_handle_drag_motion(event)


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
		_stop_drag()


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
	camera.position = map_board.size * 0.5
	_clamp_camera()


func _stop_drag() -> void:
	active_drag_button = -1
	pending_drag_delta = Vector2.ZERO
	is_dragging = false


func _clamp_camera() -> void:
	var map_size := map_board.size
	var viewport_size := get_viewport_rect().size
	var visible_half_size := viewport_size / (2.0 * camera.zoom.x)
	var minimum := visible_half_size
	var maximum := map_size - visible_half_size

	if minimum.x > maximum.x:
		camera.position.x = map_size.x * 0.5
	else:
		camera.position.x = clampf(camera.position.x, minimum.x, maximum.x)

	if minimum.y > maximum.y:
		camera.position.y = map_size.y * 0.5
	else:
		camera.position.y = clampf(camera.position.y, minimum.y, maximum.y)
