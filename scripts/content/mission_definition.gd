class_name MissionDefinition
extends Resource


const SOURCE_NOTICEBOARD := &"NOTICEBOARD"
const SOURCE_WARTIME_DEFENSE := &"WARTIME_DEFENSE"
const RETURN_CITY := &"CITY"
const OBJECTIVE_ELIMINATE := &"ELIMINATE_ALL"
const OBJECTIVE_PROTECT := &"PROTECT_AND_ELIMINATE"
const OBJECTIVE_SCOUT := &"FIND_AND_EXTRACT"

@export var mission_id: StringName
@export var title: String
@export var description: String
@export var objective_type: StringName
@export var objective_text: String
@export var risk_label: String
@export var layout_id: StringName
@export var source: StringName = SOURCE_NOTICEBOARD
@export var return_destination: StringName = RETURN_CITY
@export var committed_count := 20
@export var player_route_pattern: Array[StringName] = []
@export var front_route_name := "路线一"
@export var side_route_name := "路线二"
@export var front_enemy_count := 0
@export var side_enemy_count := 0
@export var front_gate_hp := 0
@export var side_gate_hp := 0
@export var front_distance_units := 40
@export var side_distance_units := 40
@export var protect_target_name := ""
@export var protect_target_hp := 0
@export var protect_damage_per_enemy := 0
@export var scout_route_id: StringName
@export var scout_search_distance_units := 0
@export var reward_wood := 0
@export var reward_food := 0
@export var first_clear_key: StringName


func is_valid() -> bool:
	if (
		mission_id == &""
		or title.is_empty()
		or description.is_empty()
		or objective_type not in [
			OBJECTIVE_ELIMINATE,
			OBJECTIVE_PROTECT,
			OBJECTIVE_SCOUT,
		]
		or objective_text.is_empty()
		or risk_label.is_empty()
		or layout_id == &""
		or source not in [SOURCE_NOTICEBOARD, SOURCE_WARTIME_DEFENSE]
		or return_destination != RETURN_CITY
		or committed_count <= 0
		or front_enemy_count < 0
		or side_enemy_count < 0
		or front_enemy_count + side_enemy_count <= 0
		or front_gate_hp < 0
		or side_gate_hp < 0
		or front_distance_units <= 0
		or side_distance_units <= 0
		or reward_wood < 0
		or reward_food < 0
		or first_clear_key == &""
	):
		return false
	for route_id in player_route_pattern:
		if route_id not in [
			CommittedForceSnapshot.FRONT_ROUTE,
			CommittedForceSnapshot.SIDE_ROUTE,
		]:
			return false
	if (
		objective_type == OBJECTIVE_PROTECT
		and (
			protect_target_name.is_empty()
			or protect_target_hp <= 0
			or protect_damage_per_enemy <= 0
		)
	):
		return false
	if (
		objective_type == OBJECTIVE_SCOUT
		and (
			scout_route_id not in [
				CommittedForceSnapshot.FRONT_ROUTE,
				CommittedForceSnapshot.SIDE_ROUTE,
			]
			or scout_search_distance_units <= 0
		)
	):
		return false
	return true


func get_enemy_total() -> int:
	return front_enemy_count + side_enemy_count


func get_reward_text() -> String:
	var parts: Array[String] = []
	if reward_wood > 0:
		parts.append("木材 %d" % reward_wood)
	if reward_food > 0:
		parts.append("粮食 %d" % reward_food)
	return "无" if parts.is_empty() else "、".join(parts)
