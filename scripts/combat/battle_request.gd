class_name BattleRequest
extends RefCounted


const PHASE_RESERVED := &"RESERVED"
const PHASE_ACTIVE := &"ACTIVE"
const PHASE_RESULT_PENDING := &"RESULT_PENDING"
const PHASE_APPLIED := &"APPLIED"
const PHASE_CANCELLED := &"CANCELLED"
const SOURCE_MACRO_SIEGE := &"MACRO_SIEGE"
const SOURCE_WARTIME_DEFENSE := &"WARTIME_DEFENSE"

var transaction_id: StringName
var level_id: StringName
var created_day: int
var phase: StringName
var committed_force: CommittedForceSnapshot
var enemy_force: EnemyForceSnapshot
var formal_city_entry: bool
var committed_food_cost: int
var city_defense_snapshot: int
var source_id: StringName
var first_clear_key: StringName
var reward_wood: int
var reward_food: int
var mission_definition: MissionDefinition
var wartime_facility_plan: Dictionary
## Runtime-only bridge facts for a macro siege. They are serialized by the
## owning WarLoop handoff, never by a second request ledger.
var macro_siege_start_state: Dictionary = {}


func _init(
	transaction_id_value: StringName = &"",
	level_id_value: StringName = &"",
	created_day_value := 0,
	committed_force_value: CommittedForceSnapshot = null,
	enemy_force_value: EnemyForceSnapshot = null,
	formal_city_entry_value := false,
	committed_food_cost_value := 0,
	city_defense_snapshot_value := 0,
	source_id_value: StringName = &"FIRST_WAR",
	first_clear_key_value: StringName = &"first_map.main_assault.v0",
	reward_wood_value := 30,
	reward_food_value := 20,
	mission_definition_value: MissionDefinition = null,
	wartime_facility_plan_value: Dictionary = {}
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
	source_id = source_id_value
	first_clear_key = first_clear_key_value
	reward_wood = reward_wood_value
	reward_food = reward_food_value
	mission_definition = mission_definition_value
	wartime_facility_plan = (
		wartime_facility_plan_value.duplicate(true)
		if not wartime_facility_plan_value.is_empty()
		else WartimeFacilityPlan.empty_snapshot()
	)


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
		and source_id in [
			&"FIRST_WAR",
			MissionDefinition.SOURCE_NOTICEBOARD,
			SOURCE_MACRO_SIEGE,
			SOURCE_WARTIME_DEFENSE,
		]
		and first_clear_key != &""
		and reward_wood >= 0
		and reward_food >= 0
		and bool(WartimeFacilityPlan.validate_snapshot(wartime_facility_plan).valid)
		and (
			source_id != MissionDefinition.SOURCE_NOTICEBOARD
			or (
				mission_definition != null
				and mission_definition.is_valid()
				and mission_definition.mission_id == level_id
			)
		)
	)


func is_noticeboard_mission() -> bool:
	return (
		source_id == MissionDefinition.SOURCE_NOTICEBOARD
		and mission_definition != null
	)


static func from_expedition_attempt(
	attempt: Dictionary,
	mission_definition_value: MissionDefinition = null
) -> BattleRequest:
	if attempt.is_empty():
		return null
	var committed := CommittedForceSnapshot.from_dictionary(
		Dictionary(attempt.get("committed_force_snapshot", {}))
	)
	var enemy := EnemyForceSnapshot.from_dictionary(
		Dictionary(attempt.get("enemy_force_snapshot", {}))
	)
	if committed == null or enemy == null:
		return null
	var request := BattleRequest.new(
		StringName(attempt.get("attempt_id", &"")),
		StringName(attempt.get("mainline_id", &"")),
		int(attempt.get("created_day", 0)),
		committed,
		enemy,
		true,
		int(attempt.get("food_cost", 0)),
		int(attempt.get("city_defense_snapshot", 0)),
		StringName(attempt.get("source_id", &"FIRST_WAR")),
		StringName(attempt.get("first_clear_key", &"")),
		int(attempt.get("reward_wood", 0)),
		int(attempt.get("reward_food", 0)),
		mission_definition_value,
		Dictionary(attempt.get("wartime_facility_plan", WartimeFacilityPlan.empty_snapshot()))
	)
	request.phase = StringName(attempt.get("phase", PHASE_RESERVED))
	return request if request.is_valid() else null
