class_name BattleResultApplier
extends RefCounted


var city_controller: Node
var last_error_id: StringName = &""


func _init(city_controller_value: Node = null) -> void:
	city_controller = city_controller_value


func apply_authorized(
	transaction_id: StringName,
	result_id: StringName
) -> Dictionary:
	last_error_id = &""
	if city_controller == null:
		last_error_id = &"CITY_CONTROLLER_UNAVAILABLE"
		return {}
	var summary: Dictionary = city_controller.apply_battle_result_atomic(
		transaction_id,
		result_id
	)
	if summary.is_empty():
		last_error_id = &"RESULT_SETTLEMENT_REJECTED"
	return summary
