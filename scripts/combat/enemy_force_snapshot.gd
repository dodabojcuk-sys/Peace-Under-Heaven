class_name EnemyForceSnapshot
extends RefCounted


const FRONT_ROUTE := &"FRONT_GATE"
const SIDE_ROUTE := &"SIDE_GATE"
const FRONT_BASE_GATE_HP := 600
const SIDE_BASE_GATE_HP := 360
const GATE_HP_PER_FORTIFICATION := 120

var transaction_id: StringName
var snapshot_day: int
var enemy_count: int
var fortification_level: int
var route_states: Dictionary = {}


static func create(
	transaction_id_value: StringName,
	day_value: int,
	enemy_count_value: int,
	fortification_value: int
) -> EnemyForceSnapshot:
	if (
		transaction_id_value == &""
		or day_value <= 0
		or enemy_count_value <= 0
		or fortification_value < 0
	):
		return null
	var snapshot := EnemyForceSnapshot.new()
	snapshot.transaction_id = transaction_id_value
	snapshot.snapshot_day = day_value
	snapshot.enemy_count = enemy_count_value
	snapshot.fortification_level = fortification_value
	var front_enemy := floori(float(enemy_count_value * 2 + 4) / 5.0)
	snapshot.route_states = {
		FRONT_ROUTE: {
			"enemy_members": front_enemy,
			"gate_hp": FRONT_BASE_GATE_HP
				+ GATE_HP_PER_FORTIFICATION * fortification_value,
		},
		SIDE_ROUTE: {
			"enemy_members": enemy_count_value - front_enemy,
			"gate_hp": SIDE_BASE_GATE_HP
				+ GATE_HP_PER_FORTIFICATION * fortification_value,
		},
	}
	return snapshot


static func create_for_mission(
	transaction_id_value: StringName,
	day_value: int,
	mission: MissionDefinition
) -> EnemyForceSnapshot:
	if (
		transaction_id_value == &""
		or day_value <= 0
		or mission == null
		or not mission.is_valid()
	):
		return null
	var snapshot := EnemyForceSnapshot.new()
	snapshot.transaction_id = transaction_id_value
	snapshot.snapshot_day = day_value
	snapshot.enemy_count = mission.get_enemy_total()
	snapshot.fortification_level = 0
	snapshot.route_states = {
		FRONT_ROUTE: {
			"enemy_members": mission.front_enemy_count,
			"gate_hp": mission.front_gate_hp,
		},
		SIDE_ROUTE: {
			"enemy_members": mission.side_enemy_count,
			"gate_hp": mission.side_gate_hp,
		},
	}
	return snapshot


func get_digest() -> String:
	var front: Dictionary = route_states.get(FRONT_ROUTE, {})
	var side: Dictionary = route_states.get(SIDE_ROUTE, {})
	return "%s|%d|%d|%d|%d:%d|%d:%d" % [
		str(transaction_id),
		snapshot_day,
		enemy_count,
		fortification_level,
		int(front.get("enemy_members", 0)),
		int(front.get("gate_hp", 0)),
		int(side.get("enemy_members", 0)),
		int(side.get("gate_hp", 0)),
	]
