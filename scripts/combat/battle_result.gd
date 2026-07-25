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
		and committed_count > 0
		and survivor_count >= 0
		and casualty_count >= 0
		and survivor_count + casualty_count == committed_count
		and enemy_casualties >= 0
	)
