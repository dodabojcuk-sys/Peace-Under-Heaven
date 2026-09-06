class_name ExpeditionPreparationPanel
extends Control


signal selection_changed(formation_ids: Array[StringName])
signal confirm_requested(formation_ids: Array[StringName])
signal cancel_requested

const TRANSITION_SECONDS := 0.16

@onready var card: PanelContainer = $Center/Card
@onready var mainline_title: Label = $Center/Card/Margin/Content/MainlineTitle
@onready var mainline_detail: Label = $Center/Card/Margin/Content/MainlineDetail
@onready var food_summary: Label = $Center/Card/Margin/Content/FoodSummary
@onready var formation_list: VBoxContainer = $Center/Card/Margin/Content/FormationList
@onready var selection_summary: Label = $Center/Card/Margin/Content/SelectionSummary
@onready var validation_message: Label = $Center/Card/Margin/Content/ValidationMessage
@onready var cancel_button: Button = $Center/Card/Margin/Content/Actions/CancelButton
@onready var confirm_button: Button = $Center/Card/Margin/Content/Actions/ConfirmButton

var _formation_buttons: Dictionary = {}
var _transition: Tween
var _is_refreshing := false


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false


func open_with_model(model: Dictionary) -> void:
	visible = true
	_rebuild_formations(Array(model.get("formations", [])))
	update_model(model)
	_play_open_transition()
	_focus_first_available_control.call_deferred()


func update_model(model: Dictionary) -> void:
	mainline_title.text = str(model.get("mainline_name", "当前主线"))
	mainline_detail.text = "目标：%s\n剩余期限：%s" % [
		str(model.get("objective", "完成当前主线")),
		str(model.get("deadline_text", "未知")),
	]
	food_summary.text = "当前粮食  %d   ·   粮草公式  向上取整（兵力 ÷ %d）" % [
		int(model.get("food", 0)),
		int(model.get("maintenance_units_per_food", 1)),
	]
	selection_summary.text = "已选 %d 队 · %d 人   粮草 %d   出征后剩余 %d" % [
		int(model.get("selected_formation_count", 0)),
		int(model.get("selected_total", 0)),
		int(model.get("food_cost", 0)),
		int(model.get("food_after", model.get("food", 0))),
	]
	var reason := str(model.get("blocked_reason", ""))
	validation_message.text = reason if not reason.is_empty() else "编队与粮草核验通过"
	validation_message.theme_type_variation = (
		&"WarningLabel" if not reason.is_empty() else &"SuccessLabel"
	)
	confirm_button.disabled = not bool(model.get("can_confirm", false))
	_is_refreshing = true
	var selected: Array = model.get("selected_formation_ids", [])
	for formation_id in _formation_buttons:
		var button := _formation_buttons[formation_id] as CheckButton
		button.button_pressed = formation_id in selected
	_is_refreshing = false


func show_error(message: String) -> void:
	validation_message.text = message
	validation_message.theme_type_variation = &"WarningLabel"
	confirm_button.grab_focus()


func close_panel() -> void:
	_kill_transition()
	visible = false
	_formation_buttons.clear()
	for child in formation_list.get_children():
		child.queue_free()


func get_selected_formation_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for formation_id in GarrisonState.FORMATION_IDS:
		var button := _formation_buttons.get(formation_id) as CheckButton
		if button != null and button.button_pressed:
			result.append(formation_id)
	return result


func get_card_rect() -> Rect2:
	return card.get_global_rect()


func _rebuild_formations(formations: Array) -> void:
	_formation_buttons.clear()
	for child in formation_list.get_children():
		child.queue_free()
	for formation_value in formations:
		if not formation_value is Dictionary:
			continue
		var formation: Dictionary = formation_value
		var formation_id := StringName(formation.get("formation_id", &""))
		var button := CheckButton.new()
		button.name = "Formation%s" % str(formation_id).get_slice(".", 2)
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.text = "%s  ·  %d / %d 人%s" % [
			str(formation.get("display_name", "未命名编队")),
			int(formation.get("member_count", 0)),
			int(formation.get("max_members", 0)),
			"  ·  待整补" if int(formation.get("member_count", 0)) == 0 else "",
		]
		button.disabled = int(formation.get("member_count", 0)) <= 0
		button.toggled.connect(_on_formation_toggled.bind(formation_id))
		formation_list.add_child(button)
		_formation_buttons[formation_id] = button


func _on_formation_toggled(_pressed: bool, _formation_id: StringName) -> void:
	if _is_refreshing:
		return
	selection_changed.emit(get_selected_formation_ids())


func _on_confirm_pressed() -> void:
	confirm_button.disabled = true
	confirm_requested.emit(get_selected_formation_ids())


func _on_cancel_pressed() -> void:
	cancel_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	accept_event()
	cancel_requested.emit()


func _focus_first_available_control() -> void:
	for formation_id in GarrisonState.FORMATION_IDS:
		var button := _formation_buttons.get(formation_id) as CheckButton
		if button != null and not button.disabled:
			button.grab_focus()
			return
	cancel_button.grab_focus()


func _play_open_transition() -> void:
	_kill_transition()
	card.modulate.a = 0.0
	card.scale = Vector2(0.985, 0.985)
	card.pivot_offset = card.size * 0.5
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(card, "modulate:a", 1.0, TRANSITION_SECONDS)
	_transition.tween_property(card, "scale", Vector2.ONE, TRANSITION_SECONDS)


func _kill_transition() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = null
