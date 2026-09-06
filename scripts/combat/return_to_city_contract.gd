class_name ReturnToCityContract
extends RefCounted


var transaction_id: StringName
var result_id: StringName
var city_input_restore_frame: int
var completed := false


func _init(
	transaction_id_value: StringName = &"",
	result_id_value: StringName = &"",
	city_input_restore_frame_value := -1
) -> void:
	transaction_id = transaction_id_value
	result_id = result_id_value
	city_input_restore_frame = city_input_restore_frame_value
