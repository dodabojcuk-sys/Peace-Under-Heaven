class_name BattleRequest
extends RefCounted


const PHASE_RESERVED := &"RESERVED"
const PHASE_ACTIVE := &"ACTIVE"
const PHASE_RESULT_PENDING := &"RESULT_PENDING"
const PHASE_APPLIED := &"APPLIED"
const PHASE_CANCELLED := &"CANCELLED"

var transaction_id: StringName
var level_id: StringName
var created_day: int
var phase: StringName
var committed_force: CommittedForceSnapshot
var enemy_force: EnemyForceSnapshot
var formal_city_entry: bool
var committed_food_cost: int
var city_defense_snapshot: int


func _init(
	transaction_id_value: StringName = &"",
	level_id_value: StringName = &"",
	created_day_value := 0,
	committed_force_value: CommittedForceSnapshot = null,
	enemy_force_value: EnemyForceSnapshot = null,
	formal_city_entry_value := false,
	committed_food_cost_value := 0,
	city_defense_snapshot_value := 0
) -> void:
	transaction_id = transaction_id_value
	level_id = level_id_value
	created_day = created_day_value
	phase = PHASE_RESERVED
	committed_force = committed_force_value
	enemy_force = enemy_force_value
	formal_city_entry = formal_city_entry_value
	committed_food_cost = committed_food_cost_value
	city_defense_snapshot = city_defense_snapshot_value


func is_valid() -> bool:
	return (
		transaction_id != &""
		and level_id != &""
		and created_day > 0
		and committed_force != null
		and enemy_force != null
		and committed_force.transaction_id == transaction_id
		and enemy_force.transaction_id == transaction_id
		and committed_food_cost >= 0
		and city_defense_snapshot >= 0
	)
