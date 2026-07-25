class_name BattleOrder
extends RefCounted


enum Command {
	ADVANCE,
	HOLD,
	RETREAT,
}


var order_id: int
var session_id: StringName
var squad_id: int
var issued_tick: int
var command: Command


func _init(
	order_id_value := 0,
	session_id_value: StringName = &"",
	squad_id_value := 0,
	issued_tick_value := 0,
	command_value := Command.HOLD
) -> void:
	order_id = order_id_value
	session_id = session_id_value
	squad_id = squad_id_value
	issued_tick = issued_tick_value
	command = command_value
