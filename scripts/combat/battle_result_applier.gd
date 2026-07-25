class_name BattleResultApplier
extends RefCounted


var city_controller: Node


func _init(city_controller_value: Node = null) -> void:
	city_controller = city_controller_value


func apply(
	battle_result: BattleResult,
	request: BattleRequest
) -> Dictionary:
	if city_controller == null:
		return {}
	return city_controller.apply_battle_result_atomic(
		battle_result,
		request
	)
