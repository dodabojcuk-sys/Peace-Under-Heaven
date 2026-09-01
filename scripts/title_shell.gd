class_name TitleShell
extends Control


const CITY_SCENE := preload("res://scenes/blank_map.tscn")

@onready var enter_city_button: Button = %EnterCityButton
@onready var exit_button: Button = %ExitButton

var _city_transition_requested := false


func _ready() -> void:
	enter_city_button.pressed.connect(_on_enter_city_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	call_deferred("_focus_enter_city")


func _unhandled_key_input(event: InputEvent) -> void:
	# The title has no modal stack to dismiss. Consume Esc deliberately instead
	# of leaking it into an uninitialized city interaction path.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_enter_city_pressed() -> void:
	if _city_transition_requested:
		return
	_city_transition_requested = true
	enter_city_button.disabled = true
	get_tree().change_scene_to_packed(CITY_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _focus_enter_city() -> void:
	if not _city_transition_requested:
		enter_city_button.grab_focus()
