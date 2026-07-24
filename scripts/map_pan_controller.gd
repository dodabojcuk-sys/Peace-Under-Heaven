extends Control


@onready var pan_content: Control = $PanContent
var is_dragging: bool = false
var dragging_button: int = -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_pan_button(event)
	elif event is InputEventMouseMotion:
		_handle_pan_motion(event)


func _handle_pan_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_MIDDLE and event.button_index != MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_dragging = false
			dragging_button = -1
		return

	if event.pressed:
		is_dragging = true
		dragging_button = event.button_index
	else:
		if event.button_index == dragging_button:
			is_dragging = false
			dragging_button = -1


func _handle_pan_motion(event: InputEventMouseMotion) -> void:
	if not is_dragging:
		return

	if dragging_button == MOUSE_BUTTON_MIDDLE and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		is_dragging = false
		dragging_button = -1
		return
	if dragging_button == MOUSE_BUTTON_RIGHT and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_dragging = false
		dragging_button = -1
		return

	pan_content.position += event.relative
