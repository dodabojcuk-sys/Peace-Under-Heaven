class_name BattleAttemptState
extends RefCounted


# Battle retries own attempt-local input only. Persistent city and mainline
# progression deliberately stay outside this boundary.
var attempt_id: StringName = &""
var elapsed_ticks := 0
var issued_order_ids: Array[StringName] = []


func restore_attempt(snapshot: Dictionary) -> bool:
	if (
		typeof(snapshot.get("attempt_id", null)) != TYPE_STRING_NAME
		or StringName(snapshot.attempt_id) == &""
		or typeof(snapshot.get("elapsed_ticks", null)) != TYPE_INT
		or int(snapshot.elapsed_ticks) < 0
		or typeof(snapshot.get("issued_order_ids", null)) != TYPE_ARRAY
	):
		return false
	attempt_id = StringName(snapshot.attempt_id)
	elapsed_ticks = int(snapshot.elapsed_ticks)
	issued_order_ids.assign(snapshot.issued_order_ids)
	return true
