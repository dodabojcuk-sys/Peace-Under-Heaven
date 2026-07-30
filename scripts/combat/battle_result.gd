class_name BattleResult
extends RefCounted


var result_id: StringName
var transaction_id: StringName
var session_id: StringName
var level_id: StringName
var outcome := BattleOutcome.Value.DEFEAT
var started_day: int
var finished_tick: int
var committed_count: int
var survivor_count: int
var casualty_count: int
var enemy_casualties: int
var breached_route: StringName
var orders_digest: String
var player_snapshot_digest: String
var enemy_snapshot_digest: String
var first_clear_key: StringName


func is_consistent() -> bool:
	return (
		result_id != &""
		and transaction_id != &""
		and session_id != &""
		and level_id != &""
		and outcome in [
			BattleOutcome.Value.VICTORY,
			BattleOutcome.Value.DEFEAT,
			BattleOutcome.Value.RETREAT,
		]
		and finished_tick >= 0
		and committed_count > 0
		and survivor_count >= 0
		and casualty_count >= 0
		and survivor_count + casualty_count == committed_count
		and enemy_casualties >= 0
	)


func get_duration_milliseconds() -> int:
	return finished_tick * BattleSession.TICK_MILLISECONDS


func get_authority_snapshot() -> Dictionary:
	return {
		"result_id": result_id,
		"transaction_id": transaction_id,
		"session_id": session_id,
		"level_id": level_id,
		"outcome": outcome,
		"started_day": started_day,
		"finished_tick": finished_tick,
		"committed_count": committed_count,
		"survivor_count": survivor_count,
		"casualty_count": casualty_count,
		"enemy_casualties": enemy_casualties,
		"breached_route": breached_route,
		"orders_digest": orders_digest,
		"player_snapshot_digest": player_snapshot_digest,
		"enemy_snapshot_digest": enemy_snapshot_digest,
		"first_clear_key": first_clear_key,
	}


func matches_authority_snapshot(authority_snapshot: Dictionary) -> bool:
	return authority_snapshot == get_authority_snapshot()


static func from_authority_snapshot(
	authority_snapshot: Dictionary
) -> BattleResult:
	var result := BattleResult.new()
	result.result_id = StringName(authority_snapshot.get("result_id", &""))
	result.transaction_id = StringName(
		authority_snapshot.get("transaction_id", &"")
	)
	result.session_id = StringName(authority_snapshot.get("session_id", &""))
	result.level_id = StringName(authority_snapshot.get("level_id", &""))
	result.outcome = int(authority_snapshot.get("outcome", -1)) as BattleOutcome.Value
	result.started_day = int(authority_snapshot.get("started_day", 0))
	result.finished_tick = int(authority_snapshot.get("finished_tick", -1))
	result.committed_count = int(authority_snapshot.get("committed_count", 0))
	result.survivor_count = int(authority_snapshot.get("survivor_count", -1))
	result.casualty_count = int(authority_snapshot.get("casualty_count", -1))
	result.enemy_casualties = int(authority_snapshot.get("enemy_casualties", -1))
	result.breached_route = StringName(
		authority_snapshot.get("breached_route", &"")
	)
	result.orders_digest = str(authority_snapshot.get("orders_digest", ""))
	result.player_snapshot_digest = str(
		authority_snapshot.get("player_snapshot_digest", "")
	)
	result.enemy_snapshot_digest = str(
		authority_snapshot.get("enemy_snapshot_digest", "")
	)
	result.first_clear_key = StringName(
		authority_snapshot.get("first_clear_key", &"")
	)
	return result
