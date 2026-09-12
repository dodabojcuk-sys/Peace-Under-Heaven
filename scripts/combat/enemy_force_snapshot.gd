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


static func create_for_mission_count(
	transaction_id_value: StringName,
	day_value: int,
	mission: MissionDefinition,
	enemy_count_value: int
) -> EnemyForceSnapshot:
	if enemy_count_value <= 0 or mission == null or not mission.is_valid():
		return null
	var snapshot := EnemyForceSnapshot.new()
	snapshot.transaction_id = transaction_id_value
	snapshot.snapshot_day = day_value
	snapshot.enemy_count = enemy_count_value
	snapshot.fortification_level = 0
	var authored_total := maxi(mission.get_enemy_total(), 1)
	var front_enemy := clampi(
		roundi(float(enemy_count_value * mission.front_enemy_count) / float(authored_total)),
		0,
		enemy_count_value
	)
	snapshot.route_states = {
		FRONT_ROUTE: {
			"enemy_members": front_enemy,
			"gate_hp": mission.front_gate_hp,
		},
		SIDE_ROUTE: {
			"enemy_members": enemy_count_value - front_enemy,
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


func to_dictionary() -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"snapshot_day": snapshot_day,
		"enemy_count": enemy_count,
		"fortification_level": fortification_level,
		"route_states": route_states.duplicate(true),
	}


static func from_dictionary(value: Dictionary) -> EnemyForceSnapshot:
	var expected_keys := [
		"transaction_id", "snapshot_day", "enemy_count",
		"fortification_level", "route_states",
	]
	if not _has_exact_keys(value, expected_keys):
		return null
	if (
		typeof(value.transaction_id) != TYPE_STRING_NAME
		or StringName(value.transaction_id) == &""
		or typeof(value.snapshot_day) != TYPE_INT
		or int(value.snapshot_day) <= 0
		or typeof(value.enemy_count) != TYPE_INT
		or int(value.enemy_count) <= 0
		or typeof(value.fortification_level) != TYPE_INT
		or int(value.fortification_level) < 0
		or typeof(value.route_states) != TYPE_DICTIONARY
	):
		return null
	var routes: Dictionary = value.route_states
	if routes.size() != 2:
		return null
	var total := 0
	for route_id in [FRONT_ROUTE, SIDE_ROUTE]:
		var route_value = routes.get(route_id)
		if not route_value is Dictionary:
			return null
		var route: Dictionary = route_value
		if (
			not _has_exact_keys(route, ["enemy_members", "gate_hp"])
			or typeof(route.enemy_members) != TYPE_INT
			or int(route.enemy_members) < 0
			or typeof(route.gate_hp) != TYPE_INT
			or int(route.gate_hp) < 0
		):
			return null
		total += int(route.enemy_members)
	if total != int(value.enemy_count):
		return null
	var snapshot := EnemyForceSnapshot.new()
	snapshot.transaction_id = StringName(value.transaction_id)
	snapshot.snapshot_day = int(value.snapshot_day)
	snapshot.enemy_count = int(value.enemy_count)
	snapshot.fortification_level = int(value.fortification_level)
	snapshot.route_states = routes.duplicate(true)
	return snapshot


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true
