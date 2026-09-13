class_name FieldTacticsState
extends RefCounted


## Persistent R2 outer-city state.  It intentionally contains only data and
## deterministic simulation: ConstructionController remains the authority for
## resource commits and V5 remains the only disk publisher.
const SCHEMA_VERSION := 1
const ROAD_MAIN := &"MAIN"
const ROAD_NORMAL := &"NORMAL"
const ROAD_REINFORCED := &"REINFORCED"
const ROAD_BRIDGE := &"BRIDGE"
const ROAD_OPEN := &"OPEN"
const ROAD_DAMAGED := &"DAMAGED"
const SPECIALIST_SCOUT := &"SCOUT"
const SPECIALIST_ENGINEER := &"ENGINEER"
const SPECIALIST_MEDIC := &"MEDIC"
const SPECIALIST_SABOTEUR := &"SABOTEUR"
const SPECIALIST_THIEF := &"THIEF"
const SPECIALIST_SNIPER := &"SNIPER"
const SPECIALIST_ROLES := [SPECIALIST_SCOUT, SPECIALIST_ENGINEER, SPECIALIST_MEDIC, SPECIALIST_SABOTEUR, SPECIALIST_THIEF, SPECIALIST_SNIPER]
const SPECIALIST_IDLE := &"IDLE"
const SPECIALIST_MOVING := &"MOVING"
const SPECIALIST_BUILDING := &"BUILDING"
const SPECIALIST_REPAIRING := &"REPAIRING"
const SPECIALIST_BLOCKED := &"BLOCKED"
const SPECIALIST_LOST := &"LOST"
const SPECIALIST_ACTING := &"ACTING"
const ACTION_MEDICAL := &"MEDICAL"
const ACTION_SABOTAGE := &"SABOTAGE"
const ACTION_THEFT := &"THEFT"
const ACTION_SNIPER := &"SNIPER"
const ACTION_KINDS := [ACTION_MEDICAL, ACTION_SABOTAGE, ACTION_THEFT, ACTION_SNIPER]
const ACTION_NONE := &"NONE"
const ACTION_TRAVELING := &"TRAVELING"
const ACTION_WORKING := &"WORKING"
const ACTION_READY := &"READY"
const ACTION_RETURNING := &"RETURNING"
const ACTION_READY_DEPOSIT := &"READY_DEPOSIT"
const ACTION_COMPLETED := &"COMPLETED"
const ACTION_INTERRUPTED := &"INTERRUPTED"
const FOG_UNOBSERVED := &"UNOBSERVED"
const FOG_OBSERVED := &"OBSERVED"
const FOG_VISIBLE := &"VISIBLE"
const INVASION_KIND_BLACKSTONE_FIRST := &"BLACKSTONE_FIRST_INVASION"
const INVASION_DORMANT := &"DORMANT"
const INVASION_MARCHING := &"INVADING"
const INVASION_ARRIVED := &"ARRIVED"
const INVASION_HANDED_OFF := &"HANDED_OFF"
const INVASION_DEFEATED := &"DEFEATED"
const INVASION_CANCELLED := &"CANCELLED"
const INVASION_RESOLVED := &"RESOLVED"
const INVASION_CANCELLATION_SOURCE_CONTROLLED := &"SOURCE_CONTROLLED_BEFORE_DEPARTURE"
const FACILITY_WATCHTOWER := &"WATCHTOWER"
const FACILITY_ARROW_TOWER := &"ARROW_TOWER"
const FACILITY_BARRICADE := &"BARRICADE"
const FACILITY_FORTRESS := &"FORTRESS"
const FACILITY_MINEFIELD := &"MINEFIELD"
const FACILITY_ACTIVE := &"ACTIVE"
const FACILITY_DAMAGED := &"DAMAGED"
const FACILITY_DESTROYED := &"DESTROYED"
const PROJECT_FACILITY_REPAIR := &"FACILITY_REPAIR"
const PROJECT_FACILITY_UPGRADE := &"FACILITY_UPGRADE"
const SUPPLY_MOVING := &"MOVING"
const SUPPLY_WAITING_ROUTE := &"WAITING_ROUTE"
const SUPPLY_WAITING_CAPACITY := &"WAITING_CAPACITY"
const SUPPLY_COMPLETED := &"COMPLETED"
const PATH_PREFIX := "path."
const INVALID_WORLD_POSITION := Vector2i(-999999, -999999)

var roads_by_id: Dictionary = {}
var camps_by_id: Dictionary = {}
var watchtowers_by_id: Dictionary = {}
var specialists_by_id: Dictionary = {}
var projects_by_id: Dictionary = {}
var patrols_by_id: Dictionary = {}
var intel_by_subject_id: Dictionary = {}
# Tactical-location supply is a field fact.  The city controller owns only the
# final national-resource transaction; a payload is never counted in both.
var supply_inventory_by_point_id: Dictionary = {}
# One-time local reinforcements are also a tactical-location fact. They are
# deliberately separate from city rosters, enemy defenders, and cargo: only a
# successfully stationed ArmyRegistry army can receive them.
var stationed_reinforcements_by_point_id: Dictionary = {}
var supply_transports_by_id: Dictionary = {}
var point_positions_by_id: Dictionary = {}
var water_regions: Array[Rect2i] = []
var terrain_regions: Array[Dictionary] = []
var world_bounds := Rect2i(-260, -180, 1520, 1040)
var world_milliseconds := 0
var next_specialist_sequence := 1
var next_project_sequence := 1
var next_camp_sequence := 1
var next_watchtower_sequence := 1
var next_supply_transport_sequence := 1
var _specialist_path_migration_pending := false
var _supply_snapshot_restored := false
var _stationed_reinforcement_snapshot_restored := false
var _supply_checkpoint_required := false
var scout_visibility_range := 2
var watchtower_config: Dictionary = {
	"build_radius": 150,
	"visibility_range": 360,
	"food_cost": 6,
	"required_milliseconds": 6000,
	"requires_connected_camp": true,
}


func initialize_from_theater(
	points: Dictionary,
	routes: Dictionary,
	water_regions_value: Array[Rect2i] = [],
	world_bounds_value: Rect2i = Rect2i(-260, -180, 1520, 1040),
	terrain_regions_value: Array[Dictionary] = [],
	patrol_configs: Array[Dictionary] = [],
	scout_visibility_range_value := 2,
	watchtower_config_value: Dictionary = {}
) -> void:
	water_regions = water_regions_value.duplicate()
	world_bounds = world_bounds_value
	terrain_regions = terrain_regions_value.duplicate(true)
	scout_visibility_range = maxi(int(scout_visibility_range_value), 1)
	if not watchtower_config_value.is_empty():
		watchtower_config = watchtower_config_value.duplicate(true)
	for point_id_value in points:
		var point: Dictionary = Dictionary(points[point_id_value])
		point_positions_by_id[StringName(point_id_value)] = Vector2i(point.get("world_position", Vector2i.ZERO))
		# Seed only a brand-new theatre. A restored older snapshot deliberately
		# defaults to no stock, so upgrading a save cannot mint free supplies.
		if not _supply_snapshot_restored and not supply_inventory_by_point_id.has(StringName(point_id_value)):
			var initial_supply := maxi(int(point.get("initial_supply_food", 0)), 0)
			if initial_supply > 0:
				supply_inventory_by_point_id[StringName(point_id_value)] = initial_supply
		# Existing saves must never gain newly-authored local recruits merely by
		# being loaded. A fresh theatre seeds them once from the authored point.
		if not _stationed_reinforcement_snapshot_restored and not stationed_reinforcements_by_point_id.has(StringName(point_id_value)):
			var initial_reinforcements := maxi(int(point.get("initial_stationed_reinforcements", 0)), 0)
			if initial_reinforcements > 0:
				stationed_reinforcements_by_point_id[StringName(point_id_value)] = initial_reinforcements
		# Authored hostile facilities are seeded only for a brand-new theatre. A
		# restored save (including a legacy one) must not gain a new sabotage target
		# merely because content was added in a later build.
		if not _supply_snapshot_restored:
			var hostile_facility := Dictionary(point.get("initial_hostile_facility", {}))
			var facility_id := StringName(hostile_facility.get("facility_id", &""))
			if facility_id != &"" and not watchtowers_by_id.has(facility_id):
				var maximum := maxi(int(hostile_facility.get("max_durability", 100)), 1)
				watchtowers_by_id[facility_id] = {
					"authored": true,
					"watchtower_id": facility_id,
					"camp_id": StringName(point_id_value),
					"project_id": &"",
					"world_position": Vector2i(hostile_facility.get("world_position", point.get("world_position", Vector2i.ZERO))),
					"visibility_range": maxi(int(hostile_facility.get("visibility_range", 180)), 1),
					"facility_kind": StringName(hostile_facility.get("facility_kind", FACILITY_WATCHTOWER)),
					"durability": maximum,
					"max_durability": maximum,
					"state": FACILITY_ACTIVE,
					"effect_range": maxi(int(hostile_facility.get("effect_range", 180)), 1),
					"attack_interval_milliseconds": 0,
					"attack_elapsed_milliseconds": 0,
					"damage": 0,
					"route_delay_milliseconds": 0,
					"collision_damage": 0,
					"garrison_casualty_reduction_permille": 0,
					"garrison_army_id": &"",
					"mine_charges": 0,
					"mine_damage": 0,
					"owner_faction_id": StringName(hostile_facility.get("owner_faction_id", point.get("military_controller_faction_id", &"enemy"))),
					"discovered_by_faction_ids": [],
					"level": 1,
					"affected_patrol_ids": [],
					"complete": true,
				}
	if _specialist_path_migration_pending:
		_migrate_restored_specialist_paths()
		_specialist_path_migration_pending = false
	if not roads_by_id.is_empty():
		return
	for route_id_value in routes:
		var route: Dictionary = Dictionary(routes[route_id_value])
		var route_id := StringName(route_id_value)
		roads_by_id[route_id] = {
			"road_id": route_id,
			"source_point_id": StringName(route.get("source_point_id", &"")),
			"target_point_id": StringName(route.get("target_point_id", &"")),
			"route_world_points": Array(route.get("points", [])).duplicate(true),
			"road_kind": ROAD_MAIN,
			"state": ROAD_OPEN,
			"durability": 999999,
			"max_durability": 999999,
			"built": true,
			"project_id": &"",
		}
	# Finite patrols are Resource-owned participants, not presentation warnings.
	# Tests that initialize the legacy fixture without explicit configuration keep
	# the old patrol so historical focused coverage remains stable.
	if patrols_by_id.is_empty():
		var configured_patrols := patrol_configs.duplicate(true)
		if configured_patrols.is_empty() and points.has(&"northwatch_garrison") and points.has(&"reedbank_garrison"):
			configured_patrols = [{
				"patrol_id": &"patrol.ridge.001", "display_name": "北岭巡骑",
				"route_point_ids": [&"northwatch_garrison", &"reedbank_garrison"],
				"start_point_id": &"northwatch_garrison", "strength": 5,
				"wait_milliseconds": 2400,
			}]
		for config_value in configured_patrols:
			var config: Dictionary = Dictionary(config_value)
			var patrol_id := StringName(config.get("patrol_id", &""))
			var route_point_ids: Array = Array(config.get("route_point_ids", []))
			if patrol_id == &"" or route_point_ids.size() < 2:
				continue
			var start_point_id := StringName(config.get("start_point_id", route_point_ids.front()))
			var start_index := route_point_ids.find(start_point_id)
			if start_index < 0:
				start_index = 0
				start_point_id = StringName(route_point_ids.front())
			var target_index := (start_index + 1) % route_point_ids.size()
			var target_point_id := StringName(route_point_ids[target_index])
			var patrol_plan: Dictionary = plan_runtime_path(start_point_id, target_point_id)
			if patrol_plan.is_empty():
				continue
			patrols_by_id[patrol_id] = {
				"patrol_id": patrol_id,
				"display_name": str(config.get("display_name", "敌军巡逻")),
				"current_point_id": start_point_id,
				"strength": maxi(int(config.get("strength", 5)), 0),
				"phase": INVASION_DORMANT if int(config.get("activation_day", 0)) > 0 else &"PATROL",
				"invasion_kind": StringName(config.get("invasion_kind", &"")),
				"source_point_id": StringName(config.get("source_point_id", start_point_id)),
				"target_point_id": StringName(config.get("target_point_id", &"")),
				"known_route_name": str(config.get("known_route_name", "")),
				"warning_day": maxi(int(config.get("warning_day", 0)), 0),
				"activation_day": maxi(int(config.get("activation_day", 0)), 0),
				"activated_world_milliseconds": -1,
				"handoff_attempt_id": &"",
				"route_point_ids": route_point_ids.duplicate(true),
				"target_route_index": target_index,
				"wait_remaining_milliseconds": maxi(int(config.get("wait_milliseconds", 1200)), 0),
				"move_total_milliseconds": int(patrol_plan.get("duration_milliseconds", 4000)),
				"move_elapsed_milliseconds": 0,
				"move_start_position": _point_position(start_point_id),
				"move_route_world_points": Array(patrol_plan.get("points", [_point_position(start_point_id), _point_position(target_point_id)])).duplicate(true),
				"last_known_target_id": &"",
				"last_known_at_milliseconds": 0,
				"world_position": _point_position(start_point_id),
				"resolved_army_ids": [],
				"ambush_consumed_army_ids": [],
				"exposed": false,
				"last_engagement": {},
			}


func activate_configured_invasions(current_day: int) -> Array[StringName]:
	return Array(
		resolve_configured_invasion_departures(current_day).activated_invasion_ids,
		TYPE_STRING_NAME, &"", null
	)


## Departure is the only point where a configured dormant force consults its
## source controller. After departure, later ownership changes cannot rewind it.
func resolve_configured_invasion_departures(
	current_day: int,
	source_controllers_by_point_id: Dictionary = {}
) -> Dictionary:
	var activated: Array[StringName] = []
	var cancelled: Array[StringName] = []
	for patrol_id_value in patrols_by_id.keys():
		var patrol_id := StringName(patrol_id_value)
		var patrol := Dictionary(patrols_by_id[patrol_id])
		if (
			StringName(patrol.get("phase", &"")) != INVASION_DORMANT
			or int(patrol.get("activation_day", 0)) <= 0
			or current_day < int(patrol.get("activation_day", 0))
		):
			continue
		var source_point_id := StringName(patrol.get("source_point_id", &""))
		if StringName(source_controllers_by_point_id.get(source_point_id, &"")) == &"player":
			patrol.phase = INVASION_CANCELLED
			patrol.cancellation_reason = INVASION_CANCELLATION_SOURCE_CONTROLLED
			patrol.cancelled_day = current_day
			patrols_by_id[patrol_id] = patrol
			cancelled.append(patrol_id)
			continue
		patrol.phase = INVASION_MARCHING
		patrol.activated_world_milliseconds = world_milliseconds
		patrols_by_id[patrol_id] = patrol
		activated.append(patrol_id)
	_refresh_intel()
	return {
		"activated_invasion_ids": activated,
		"cancelled_invasion_ids": cancelled,
	}


func get_blackstone_invasion() -> Dictionary:
	for patrol_value in patrols_by_id.values():
		var patrol := Dictionary(patrol_value)
		if StringName(patrol.get("invasion_kind", &"")) == INVASION_KIND_BLACKSTONE_FIRST:
			return patrol.duplicate(true)
	return {}


func mark_invasion_handed_off(patrol_id: StringName, attempt_id: StringName) -> bool:
	var patrol := Dictionary(patrols_by_id.get(patrol_id, {}))
	if (
		patrol.is_empty()
		or StringName(patrol.get("phase", &"")) != INVASION_ARRIVED
		or int(patrol.get("strength", 0)) <= 0
		or attempt_id == &""
	):
		return false
	patrol.phase = INVASION_HANDED_OFF
	patrol.handoff_attempt_id = attempt_id
	patrols_by_id[patrol_id] = patrol
	return true


func resolve_invasion_handoff(
	patrol_id: StringName,
	attempt_id: StringName,
	remaining_strength: int,
	outcome: StringName
) -> bool:
	var patrol := Dictionary(patrols_by_id.get(patrol_id, {}))
	if (
		patrol.is_empty()
		or StringName(patrol.get("phase", &"")) != INVASION_HANDED_OFF
		or StringName(patrol.get("handoff_attempt_id", &"")) != attempt_id
		or remaining_strength < 0
		or outcome not in [&"VICTORY", &"RETREAT", &"DEFEAT"]
	):
		return false
	patrol.phase = INVASION_RESOLVED
	patrol.strength = remaining_strength
	patrol.resolution_outcome = outcome
	patrol.resolved_world_milliseconds = world_milliseconds
	patrols_by_id[patrol_id] = patrol
	_refresh_intel()
	return true


func dispatch_specialist(role: StringName, source_point_id: StringName) -> Dictionary:
	if role not in SPECIALIST_ROLES or source_point_id == &"":
		return {}
	var specialist_id := StringName("%s.%06d" % [String(role).to_lower(), next_specialist_sequence])
	next_specialist_sequence += 1
	var specialist := {
		"specialist_id": specialist_id,
		"role": role,
		"current_point_id": source_point_id,
		"target_point_id": source_point_id,
		"phase": SPECIALIST_IDLE,
		"move_remaining_milliseconds": 0,
		"move_total_milliseconds": 0,
		"move_elapsed_milliseconds": 0,
		"move_start_position": _point_position(source_point_id),
		"move_route_world_points": [_point_position(source_point_id)],
		"world_position": _point_position(source_point_id),
		"target_world_position": _point_position(source_point_id),
		# The playable Resource can give scouts a useful lookout radius while the
		# regression fixture keeps its historical exact-contact behavior.
		"visibility_range": scout_visibility_range if role == SPECIALIST_SCOUT else 1,
		"project_id": &"",
		"action_kind": &"", "action_stage": ACTION_NONE,
		"action_target_id": &"", "action_target_world_position": INVALID_WORLD_POSITION,
		"action_progress_milliseconds": 0, "action_required_milliseconds": 0,
		"action_cargo_food": 0, "action_result": {},
		"alive": true,
	}
	specialists_by_id[specialist_id] = specialist
	_refresh_intel()
	return specialist.duplicate(true)


func preview_specialist_action(
	specialist_id: StringName,
	action_kind: StringName,
	target_id: StringName,
	target_position: Vector2i,
	required_milliseconds: int
) -> Dictionary:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	var expected_role := {
		ACTION_MEDICAL: SPECIALIST_MEDIC, ACTION_SABOTAGE: SPECIALIST_SABOTEUR,
		ACTION_THEFT: SPECIALIST_THIEF, ACTION_SNIPER: SPECIALIST_SNIPER,
	}.get(action_kind, &"") as StringName
	if (
		specialist.is_empty() or expected_role == &""
		or StringName(specialist.get("role", &"")) != expected_role
		or not bool(specialist.get("alive", false))
		or StringName(specialist.get("phase", &"")) not in [SPECIALIST_IDLE, SPECIALIST_BLOCKED]
		or StringName(specialist.get("project_id", &"")) != &""
		or StringName(specialist.get("action_stage", ACTION_NONE)) not in [ACTION_NONE, ACTION_COMPLETED, ACTION_INTERRUPTED]
		or target_id == &"" or target_position == INVALID_WORLD_POSITION
		or required_milliseconds <= 0
	):
		return {"valid": false, "error": "该专员当前不能执行此任务"}
	var start_position := Vector2(specialist.get("world_position", INVALID_WORLD_POSITION))
	var movement_plan := _plan_specialist_land_path(start_position, Vector2(target_position))
	if movement_plan.is_empty() and start_position.distance_to(Vector2(target_position)) > 1.0:
		return {"valid": false, "error": "任务目标当前不可达"}
	return {
		"valid": true, "action_kind": action_kind, "target_id": target_id,
		"target_world_position": target_position,
		"travel_milliseconds": 0 if movement_plan.is_empty() else maxi(1800, int(movement_plan.get("duration_milliseconds", 0))),
		"required_milliseconds": required_milliseconds,
		"points": [start_position] if movement_plan.is_empty() else Array(movement_plan.get("points", [])).duplicate(true),
	}


func begin_specialist_action(
	specialist_id: StringName,
	action_kind: StringName,
	target_id: StringName,
	target_position: Vector2i,
	required_milliseconds: int
) -> Dictionary:
	var preview := preview_specialist_action(specialist_id, action_kind, target_id, target_position, required_milliseconds)
	if not bool(preview.get("valid", false)):
		return {}
	var specialist := Dictionary(specialists_by_id[specialist_id])
	specialist.action_kind = action_kind
	specialist.action_stage = ACTION_TRAVELING if int(preview.travel_milliseconds) > 0 else ACTION_WORKING
	specialist.action_target_id = target_id
	specialist.action_target_world_position = target_position
	specialist.action_progress_milliseconds = 0
	specialist.action_required_milliseconds = required_milliseconds
	specialist.action_cargo_food = 0
	specialist.action_result = {}
	specialist.target_point_id = &""
	specialist.target_world_position = target_position
	specialist.move_start_position = Vector2i(specialist.get("world_position", target_position))
	specialist.move_route_world_points = Array(preview.points).duplicate(true)
	specialist.move_total_milliseconds = int(preview.travel_milliseconds)
	specialist.move_elapsed_milliseconds = 0
	specialist.move_remaining_milliseconds = int(preview.travel_milliseconds)
	specialist.phase = SPECIALIST_MOVING if int(preview.travel_milliseconds) > 0 else SPECIALIST_ACTING
	specialists_by_id[specialist_id] = specialist
	return specialist.duplicate(true)


func return_thief_with_cargo(specialist_id: StringName, amount: int, home_point_id: StringName) -> bool:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if StringName(specialist.get("action_kind", &"")) != ACTION_THEFT or StringName(specialist.get("action_stage", &"")) != ACTION_READY or amount <= 0:
		return false
	var home_position := _point_position(home_point_id)
	var start_position := Vector2(specialist.get("world_position", INVALID_WORLD_POSITION))
	var movement_plan := _plan_specialist_land_path(start_position, Vector2(home_position))
	if home_position == INVALID_WORLD_POSITION or movement_plan.is_empty():
		return false
	var duration := maxi(1800, int(movement_plan.get("duration_milliseconds", 0)))
	specialist.action_cargo_food = amount
	specialist.action_stage = ACTION_RETURNING
	specialist.target_point_id = home_point_id
	specialist.target_world_position = home_position
	specialist.move_start_position = Vector2i(start_position)
	specialist.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
	specialist.move_total_milliseconds = duration
	specialist.move_elapsed_milliseconds = 0
	specialist.move_remaining_milliseconds = duration
	specialist.phase = SPECIALIST_MOVING
	specialists_by_id[specialist_id] = specialist
	return true


func finish_specialist_action(specialist_id: StringName, result: Dictionary = {}) -> bool:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if StringName(specialist.get("action_stage", &"")) not in [ACTION_READY, ACTION_READY_DEPOSIT]:
		return false
	specialist.action_stage = ACTION_COMPLETED
	specialist.action_result = result.duplicate(true)
	specialist.phase = SPECIALIST_IDLE
	specialist.current_point_id = StringName(specialist.get("target_point_id", &""))
	specialist.action_cargo_food = 0
	specialists_by_id[specialist_id] = specialist
	return true


func interrupt_specialist_action(specialist_id: StringName, reason: StringName) -> bool:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if specialist.is_empty() or StringName(specialist.get("action_kind", &"")) == &"":
		return false
	specialist.action_stage = ACTION_INTERRUPTED
	specialist.action_result = {"error_id": reason}
	specialist.phase = SPECIALIST_BLOCKED if bool(specialist.get("alive", false)) else SPECIALIST_LOST
	specialists_by_id[specialist_id] = specialist
	return true


func apply_specialist_sabotage(specialist_id: StringName, facility_id: StringName, damage: int) -> Dictionary:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if (
		StringName(specialist.get("action_kind", &"")) != ACTION_SABOTAGE
		or StringName(specialist.get("action_stage", &"")) != ACTION_READY
		or StringName(specialist.get("action_target_id", &"")) != facility_id
		or facility.is_empty() or damage <= 0
		or StringName(facility.get("owner_faction_id", &"player")) == &"player"
		or StringName(facility.get("state", FACILITY_ACTIVE)) == FACILITY_DESTROYED
	):
		return {}
	var before := int(facility.get("durability", 0))
	var dealt := mini(damage, before)
	facility.durability = before - dealt
	facility.state = FACILITY_DESTROYED if int(facility.durability) <= 0 else FACILITY_DAMAGED
	watchtowers_by_id[facility_id] = facility
	var result := {"facility_id": facility_id, "damage": dealt, "durability_after": int(facility.durability)}
	finish_specialist_action(specialist_id, result)
	return result


func begin_specialist_theft_return(specialist_id: StringName, point_id: StringName, amount: int, home_point_id: StringName) -> Dictionary:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	var available := int(supply_inventory_by_point_id.get(point_id, 0))
	var stolen := mini(amount, available)
	if (
		StringName(specialist.get("action_kind", &"")) != ACTION_THEFT
		or StringName(specialist.get("action_stage", &"")) != ACTION_READY
		or StringName(specialist.get("action_target_id", &"")) != point_id
		or stolen <= 0
	):
		return {}
	# Plan the physical return before debiting the target inventory. A broken
	# route therefore leaves the target stock untouched and the thief waiting.
	var home_position := _point_position(home_point_id)
	var movement_plan := _plan_specialist_land_path(Vector2(specialist.get("world_position", INVALID_WORLD_POSITION)), Vector2(home_position))
	if home_position == INVALID_WORLD_POSITION or movement_plan.is_empty():
		return {}
	supply_inventory_by_point_id[point_id] = available - stolen
	if not return_thief_with_cargo(specialist_id, stolen, home_point_id):
		supply_inventory_by_point_id[point_id] = available
		return {}
	return {"point_id": point_id, "amount": stolen, "returning": true}


func apply_specialist_sniper_shot(specialist_id: StringName, patrol_id: StringName, damage: int) -> Dictionary:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	var patrol := Dictionary(patrols_by_id.get(patrol_id, {}))
	if (
		StringName(specialist.get("action_kind", &"")) != ACTION_SNIPER
		or StringName(specialist.get("action_stage", &"")) != ACTION_READY
		or StringName(specialist.get("action_target_id", &"")) != patrol_id
		or not _patrol_can_receive_field_effect(patrol) or damage <= 0
	):
		return {}
	var before := int(patrol.get("strength", 0))
	var dealt := mini(damage, before)
	patrol.strength = before - dealt
	if int(patrol.strength) <= 0:
		patrol.phase = INVASION_DEFEATED
	patrols_by_id[patrol_id] = patrol
	var result := {"patrol_id": patrol_id, "damage": dealt, "strength_after": int(patrol.strength), "exposed": true}
	finish_specialist_action(specialist_id, result)
	return result


func preview_specialist_move_from_point(source_point_id: StringName, target_point_id: StringName) -> Dictionary:
	# The Controller uses this read-only preflight before spending food to create
	# a new specialist.  Dispatching an idle specialist and discovering that the
	# requested target is unreachable must never leave a paid, unintended unit.
	var source_position := _point_position(source_point_id)
	var target_position := _point_position(target_point_id)
	if source_position == INVALID_WORLD_POSITION or target_position == INVALID_WORLD_POSITION:
		return {"valid": false, "error": "特殊单位目标不存在"}
	var movement_plan := _plan_specialist_land_path(Vector2(source_position), Vector2(target_position))
	if movement_plan.is_empty():
		return {"valid": false, "error": "特殊单位无法到达该位置"}
	return {
		"valid": true,
		"duration_milliseconds": maxi(1800, int(movement_plan.get("duration_milliseconds", 0))),
		"points": Array(movement_plan.get("points", [])).duplicate(true),
	}


func preview_specialist_move(specialist_id: StringName, target_point_id: StringName) -> Dictionary:
	# Keep direct-map feedback on the same reachability facts as the actual
	# specialist command. A target that cannot be reached must not look ready
	# merely because it has a visible map point.
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if (
		specialist.is_empty()
		or not bool(specialist.get("alive", false))
		or StringName(specialist.get("project_id", &"")) != &""
		or StringName(specialist.get("action_stage", ACTION_NONE)) not in [ACTION_NONE, ACTION_COMPLETED, ACTION_INTERRUPTED]
	):
		return {"valid": false, "error": "该专员当前无法接受新任务"}
	if target_point_id == &"" or StringName(specialist.get("current_point_id", &"")) == target_point_id:
		return {"valid": false, "error": "请选择另一处城池或驻点"}
	var target_position := _point_position(target_point_id)
	if target_position == INVALID_WORLD_POSITION:
		return {"valid": false, "error": "专员目标不存在"}
	var start_position := Vector2(specialist.get("world_position", _point_position(StringName(specialist.get("current_point_id", &"")))))
	var movement_plan := _plan_specialist_land_path(start_position, Vector2(target_position))
	if movement_plan.is_empty():
		return {"valid": false, "error": "特殊单位无法到达该位置"}
	return {
		"valid": true,
		"duration_milliseconds": maxi(1800, int(movement_plan.get("duration_milliseconds", 0))),
		"points": Array(movement_plan.get("points", [])).duplicate(true),
	}


func order_specialist_move(specialist_id: StringName, target_point_id: StringName) -> Dictionary:
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if specialist.is_empty() or not bool(specialist.get("alive", false)) or target_point_id == &"":
		return {}
	if (
		StringName(specialist.get("project_id", &"")) != &""
		or StringName(specialist.get("action_stage", ACTION_NONE)) not in [ACTION_NONE, ACTION_COMPLETED, ACTION_INTERRUPTED]
	):
		return {}
	if StringName(specialist.get("current_point_id", &"")) == target_point_id:
		return specialist.duplicate(true)
	specialist.target_point_id = target_point_id
	var start_position := Vector2(specialist.get("world_position", _point_position(StringName(specialist.get("current_point_id", &"")))))
	var target_position := _point_position(target_point_id)
	if target_position == INVALID_WORLD_POSITION:
		return {}
	var movement_plan := _plan_specialist_land_path(start_position, target_position)
	if movement_plan.is_empty():
		return {}
	var duration := maxi(1800, int(movement_plan.get("duration_milliseconds", 0)))
	specialist.move_start_position = Vector2i(start_position)
	specialist.world_position = Vector2i(start_position)
	specialist.target_world_position = target_position
	specialist.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
	specialist.move_total_milliseconds = duration
	specialist.move_elapsed_milliseconds = 0
	specialist.move_remaining_milliseconds = duration
	specialist.phase = SPECIALIST_MOVING
	specialists_by_id[specialist_id] = specialist
	return specialist.duplicate(true)


func begin_road_project(
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	road_kind: StringName,
	build_camp: bool = false
) -> Dictionary:
	var preview := preview_road_project(
		engineer_id, source_point_id, target_point_id, route_world_points, road_kind, build_camp
	)
	if not bool(preview.get("valid", false)):
		return {}
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var resolved_road_kind := StringName(preview.get("road_kind", ROAD_NORMAL))
	var resolved_target_point_id := StringName(preview.get("target_point_id", &""))
	# A camp identity is reserved when the command is confirmed, rather than
	# when work finishes.  Two engineers can therefore build concurrently
	# without both targeting the next not-yet-created camp site.
	var reserved_camp_id := StringName(preview.get("camp_id", &""))
	if build_camp:
		next_camp_sequence += 1
	var project_id := StringName("project.%06d" % next_project_sequence)
	next_project_sequence += 1
	var road_sequence := next_project_sequence
	var segment_plans: Array = Array(preview.get("segment_plans", [])).duplicate(true)
	if segment_plans.is_empty():
		return {}
	var road_id := StringName(Dictionary(segment_plans.back()).get("road_id", &""))
	var max_durability := int(Dictionary(segment_plans.back()).get("max_durability", 0))
	var required_milliseconds := 0
	for segment_value in segment_plans:
		required_milliseconds += int(Dictionary(segment_value).get("required_milliseconds", 0))
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var construction_start_position := Vector2i(preview.get("construction_start_position", INVALID_WORLD_POSITION))
	var movement_plan: Dictionary = Dictionary(preview.get("engineer_movement_plan", {})).duplicate(true)
	var travel_milliseconds := int(preview.get("travel_milliseconds", 0))
	var project := {
		"project_id": project_id,
		"project_kind": &"CONSTRUCTION",
		"engineer_id": engineer_id,
		"road_id": road_id,
		"source_point_id": source_point_id,
		"target_point_id": resolved_target_point_id,
		"route_world_points": Array(preview.get("route_world_points", [])).duplicate(true),
		"road_kind": resolved_road_kind,
		"progress_milliseconds": 0,
		"travel_milliseconds": travel_milliseconds,
		"required_milliseconds": required_milliseconds,
		"max_durability": max_durability,
		"segment_plans": segment_plans,
		"build_camp": build_camp,
		"camp_id": reserved_camp_id,
		"phase": &"TRAVELING" if travel_milliseconds > 0 else &"BUILDING",
	}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	if travel_milliseconds > 0:
		engineer.target_point_id = source_point_id
		engineer.move_start_position = Vector2i(start_position)
		engineer.target_world_position = construction_start_position
		engineer.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
		engineer.world_position = Vector2i(start_position)
		engineer.move_total_milliseconds = travel_milliseconds
		engineer.move_elapsed_milliseconds = 0
		engineer.move_remaining_milliseconds = travel_milliseconds
		engineer.phase = SPECIALIST_MOVING
	else:
		engineer.current_point_id = source_point_id
		engineer.target_point_id = source_point_id
		engineer.world_position = construction_start_position
		engineer.phase = SPECIALIST_BUILDING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func preview_road_project(
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	road_kind: StringName,
	build_camp: bool = false
) -> Dictionary:
	var canonical_route_world_points := _canonical_world_points(route_world_points)
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	if (
		engineer.is_empty() or not bool(engineer.get("alive", false))
		or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or StringName(engineer.get("phase", &"")) not in [SPECIALIST_IDLE, SPECIALIST_BLOCKED]
		or StringName(engineer.get("project_id", &"")) != &""
		or source_point_id == &"" or canonical_route_world_points.size() < 2
		or road_kind not in [ROAD_NORMAL, ROAD_REINFORCED, ROAD_BRIDGE]
	):
		return {"valid": false, "error": "工程师或施工路线当前不可用"}
	var construction_start_position := _point_position(source_point_id)
	if construction_start_position == INVALID_WORLD_POSITION:
		return {"valid": false, "error": "施工起点不是已知城池或驻扎点"}
	if Vector2(canonical_route_world_points.front()).distance_to(Vector2(construction_start_position)) > 28.0:
		return {"valid": false, "error": "施工路线必须从所选起点开始"}
	var resolved_target_point_id := target_point_id
	var reserved_camp_id: StringName = &""
	if build_camp:
		var camp_position := Vector2i(canonical_route_world_points.back())
		# A new camp is a persistent runtime point. Do not reserve an identity for a
		# marker outside the theatre or in water: preview and commit both use this
		# same authority path, so the map cannot show a place that the project later
		# refuses to create.
		if not world_bounds.has_point(camp_position):
			return {"valid": false, "error": "新驻点必须位于战区范围内"}
		if _point_is_in_water(camp_position):
			return {"valid": false, "error": "新驻点必须落在可通行陆地"}
		reserved_camp_id = StringName("camp.%06d" % next_camp_sequence)
		if resolved_target_point_id == &"":
			resolved_target_point_id = StringName("camp.site.%06d" % next_camp_sequence)
	elif resolved_target_point_id == &"" or resolved_target_point_id == source_point_id:
		return {"valid": false, "error": "请选择另一处已有驻点，或明确新建驻点"}
	if not build_camp:
		var target_position := _point_position(resolved_target_point_id)
		if target_position == INVALID_WORLD_POSITION or Vector2(canonical_route_world_points.back()).distance_to(Vector2(target_position)) > 65.0:
			return {"valid": false, "error": "施工终点没有连接所选驻点"}
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var movement_plan := _plan_specialist_land_path(start_position, construction_start_position)
	if movement_plan.is_empty():
		return {"valid": false, "error": "工程师无法到达施工起点"}
	var project_id := StringName("project.%06d" % next_project_sequence)
	var segment_plans := _build_construction_segment_plans(
		project_id, source_point_id, resolved_target_point_id, canonical_route_world_points,
		road_kind, next_project_sequence + 1
	)
	if segment_plans.is_empty():
		return {"valid": false, "error": "施工路线无法生成连续路段"}
	var required_milliseconds := 0
	for segment_value in segment_plans:
		required_milliseconds += int(Dictionary(segment_value).get("required_milliseconds", 0))
	var resolved_road_kind := road_kind_for_route(canonical_route_world_points, road_kind)
	var contains_bridge := construction_contains_bridge(canonical_route_world_points, resolved_road_kind)
	return {
		"valid": true,
		"error": "",
		"engineer_id": engineer_id,
		"source_point_id": source_point_id,
		"target_point_id": resolved_target_point_id,
		"route_world_points": canonical_route_world_points,
		"road_kind": resolved_road_kind,
		"build_camp": build_camp,
		"camp_id": reserved_camp_id,
		"segment_plans": segment_plans,
		"contains_bridge": contains_bridge,
		"required_milliseconds": required_milliseconds,
		"construction_start_position": construction_start_position,
		"engineer_movement_plan": movement_plan.duplicate(true),
		"travel_milliseconds": int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(construction_start_position) > 0.01 else 0,
	}


## R0 watchtowers are a constrained field engineering project, not a city
## building system.  A completed camp supplies the road-connected anchor; the
## tower itself is an additional observer only after its engineer finishes.
func preview_watchtower_project(engineer_id: StringName, camp_id: StringName, world_position: Vector2i, facility_kind: StringName = FACILITY_WATCHTOWER) -> Dictionary:
	var facility_config := _field_facility_config(facility_kind)
	if facility_kind not in [FACILITY_WATCHTOWER, FACILITY_ARROW_TOWER, FACILITY_BARRICADE, FACILITY_FORTRESS, FACILITY_MINEFIELD] or facility_config.is_empty():
		return {"valid": false, "error": "未知的外部设施类型"}
	var facility_name := str(facility_config.get("display_name", "瞭望塔"))
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var camp := Dictionary(camps_by_id.get(camp_id, {}))
	if (
		engineer.is_empty() or not bool(engineer.get("alive", false))
		or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or StringName(engineer.get("phase", &"")) not in [SPECIALIST_IDLE, SPECIALIST_BLOCKED]
		or StringName(engineer.get("project_id", &"")) != &""
	):
		return {"valid": false, "error": "工程师当前无法建设%s" % facility_name}
	if camp.is_empty() or not bool(camp.get("connected", false)):
		return {"valid": false, "error": "需要选择已完工且已连接的工程驻点"}
	var camp_road_id := StringName(camp.get("road_id", &""))
	if bool(watchtower_config.get("requires_connected_camp", true)) and not is_route_open(camp_road_id):
		return {"valid": false, "error": "工程驻点道路尚未通行，无法建设瞭望塔"}
	if not world_bounds.has_point(world_position):
		return {"valid": false, "error": "瞭望塔必须位于战区范围内"}
	if _point_is_in_water(world_position):
		return {"valid": false, "error": "瞭望塔必须建在可通行陆地"}
	var camp_position := Vector2(camp.get("world_position", INVALID_WORLD_POSITION))
	if camp_position == Vector2(INVALID_WORLD_POSITION):
		return {"valid": false, "error": "工程驻点位置无效"}
	var build_radius := maxi(int(watchtower_config.get("build_radius", 150)), 1)
	if camp_position.distance_to(Vector2(world_position)) > float(build_radius):
		return {"valid": false, "error": "瞭望塔必须建在工程驻点 %d 范围内" % build_radius}
	if camp_position.distance_to(Vector2(world_position)) < 32.0:
		return {"valid": false, "error": "瞭望塔不能占用工程驻点位置"}
	if not _field_facility_for_camp(camp_id, facility_kind).is_empty() or _field_facility_project_for_camp(camp_id, facility_kind) != &"":
		return {"valid": false, "error": "该工程驻点已有%s或正在建设" % facility_name}
	for tower_value in watchtowers_by_id.values():
		if Vector2(Dictionary(tower_value).get("world_position", Vector2.ZERO)).distance_to(Vector2(world_position)) < 28.0:
			return {"valid": false, "error": "瞭望塔位置被已有设施占用"}
	# A non-complete tower project has already reserved its physical footprint.
	# It must block another camp from placing an overlapping project even though
	# no completed observer exists yet.
	for project_value in projects_by_id.values():
		var existing_project: Dictionary = Dictionary(project_value)
		if (
			StringName(existing_project.get("project_kind", &"")) == &"WATCHTOWER"
			and StringName(existing_project.get("phase", &"")) != &"COMPLETE"
			and Vector2(existing_project.get("work_world_position", INVALID_WORLD_POSITION)).distance_to(Vector2(world_position)) < 28.0
		):
			return {"valid": false, "error": "瞭望塔位置被正在建设的设施占用"}
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var movement_plan := _plan_specialist_land_path(start_position, Vector2(world_position))
	if movement_plan.is_empty():
		return {"valid": false, "error": "工程师无法到达瞭望塔工地"}
	return {
		"valid": true,
		"engineer_id": engineer_id,
		"camp_id": camp_id,
		"source_point_id": StringName(camp.get("point_id", &"")),
		"road_id": camp_road_id,
		"world_position": world_position,
		"build_radius": build_radius,
		"facility_kind": facility_kind,
		"facility_name": facility_name,
		"visibility_range": maxi(int(facility_config.get("visibility_range", 1)), 1),
		"food_cost": maxi(int(facility_config.get("food_cost", 6)), 0),
		"required_milliseconds": maxi(int(facility_config.get("required_milliseconds", 6000)), 1),
		"max_durability": maxi(int(facility_config.get("max_durability", 100)), 1),
		"effect_range": maxi(int(facility_config.get("effect_range", facility_config.get("visibility_range", 1))), 1),
		"attack_interval_milliseconds": maxi(int(facility_config.get("attack_interval_milliseconds", 0)), 0),
		"damage": maxi(int(facility_config.get("damage", 0)), 0),
		"route_delay_milliseconds": maxi(int(facility_config.get("route_delay_milliseconds", 0)), 0),
		"collision_damage": maxi(int(facility_config.get("collision_damage", 0)), 0),
		"garrison_casualty_reduction_permille": clampi(int(facility_config.get("garrison_casualty_reduction_permille", 0)), 0, 1000),
		"mine_charges": maxi(int(facility_config.get("mine_charges", 0)), 0),
		"mine_damage": maxi(int(facility_config.get("mine_damage", 0)), 0),
		"engineer_movement_plan": movement_plan.duplicate(true),
		"travel_milliseconds": int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(Vector2(world_position)) > 0.01 else 0,
	}


func begin_watchtower_project(engineer_id: StringName, camp_id: StringName, world_position: Vector2i, facility_kind: StringName = FACILITY_WATCHTOWER) -> Dictionary:
	var preview := preview_watchtower_project(engineer_id, camp_id, world_position, facility_kind)
	if not bool(preview.get("valid", false)):
		return {}
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var project_id := StringName("watchtower.%06d" % next_project_sequence)
	next_project_sequence += 1
	var tower_id := StringName("watchtower.%06d" % next_watchtower_sequence)
	next_watchtower_sequence += 1
	var travel_milliseconds := int(preview.get("travel_milliseconds", 0))
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var work_position := Vector2i(preview.get("world_position", INVALID_WORLD_POSITION))
	var project := {
		"project_id": project_id,
		"project_kind": &"WATCHTOWER",
		"engineer_id": engineer_id,
		"road_id": StringName(preview.get("road_id", &"")),
		"source_point_id": StringName(preview.get("source_point_id", &"")),
		"target_point_id": StringName(preview.get("source_point_id", &"")),
		"camp_id": camp_id,
		"tower_id": tower_id,
		"facility_kind": facility_kind,
		"work_world_position": work_position,
		"route_world_points": [work_position],
		"road_kind": ROAD_NORMAL,
		"progress_milliseconds": 0,
		"travel_milliseconds": travel_milliseconds,
		"required_milliseconds": int(preview.get("required_milliseconds", 1)),
		"visibility_range": int(preview.get("visibility_range", 1)),
		"max_durability": int(preview.get("max_durability", 100)),
		"effect_range": int(preview.get("effect_range", 1)),
		"attack_interval_milliseconds": int(preview.get("attack_interval_milliseconds", 0)),
		"damage": int(preview.get("damage", 0)),
		"route_delay_milliseconds": int(preview.get("route_delay_milliseconds", 0)),
		"collision_damage": int(preview.get("collision_damage", 0)),
		"garrison_casualty_reduction_permille": int(preview.get("garrison_casualty_reduction_permille", 0)),
		"mine_charges": int(preview.get("mine_charges", 0)),
		"mine_damage": int(preview.get("mine_damage", 0)),
		"segment_plans": [],
		"build_camp": false,
		"phase": &"TRAVELING" if travel_milliseconds > 0 else &"BUILDING",
	}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	engineer.target_point_id = StringName(preview.get("source_point_id", &""))
	engineer.target_world_position = work_position
	engineer.move_start_position = Vector2i(start_position)
	engineer.move_route_world_points = Array(Dictionary(preview.get("engineer_movement_plan", {})).get("points", [])).duplicate(true)
	engineer.move_total_milliseconds = travel_milliseconds
	engineer.move_elapsed_milliseconds = 0
	engineer.move_remaining_milliseconds = travel_milliseconds
	engineer.phase = SPECIALIST_MOVING if travel_milliseconds > 0 else SPECIALIST_BUILDING
	engineer.world_position = Vector2i(start_position) if travel_milliseconds > 0 else work_position
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func _watchtower_for_camp(camp_id: StringName) -> Dictionary:
	return _field_facility_for_camp(camp_id, FACILITY_WATCHTOWER)


func _field_facility_for_camp(camp_id: StringName, facility_kind: StringName) -> Dictionary:
	for tower_value in watchtowers_by_id.values():
		var tower: Dictionary = Dictionary(tower_value)
		if StringName(tower.get("camp_id", &"")) == camp_id and StringName(tower.get("facility_kind", FACILITY_WATCHTOWER)) == facility_kind:
			return tower.duplicate(true)
	return {}


func _watchtower_project_for_camp(camp_id: StringName) -> StringName:
	return _field_facility_project_for_camp(camp_id, FACILITY_WATCHTOWER)


func _field_facility_project_for_camp(camp_id: StringName, facility_kind: StringName) -> StringName:
	for project_id_value in projects_by_id:
		var project: Dictionary = Dictionary(projects_by_id[project_id_value])
		if StringName(project.get("project_kind", &"")) == &"WATCHTOWER" and StringName(project.get("facility_kind", FACILITY_WATCHTOWER)) == facility_kind and StringName(project.get("camp_id", &"")) == camp_id and StringName(project.get("phase", &"")) != &"COMPLETE":
			return StringName(project_id_value)
	return &""


func assign_fortress_garrison(
	facility_id: StringName,
	army_id: StringName,
	army_world_position: Vector2
) -> bool:
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if (
		facility.is_empty()
		or StringName(facility.get("facility_kind", &"")) != FACILITY_FORTRESS
		or StringName(facility.get("state", FACILITY_ACTIVE)) == FACILITY_DESTROYED
		or army_id == &""
		or Vector2(facility.get("world_position", Vector2.INF)).distance_to(army_world_position)
			> float(facility.get("effect_range", 70))
	):
		return false
	for other_value in watchtowers_by_id.values():
		if StringName(Dictionary(other_value).get("garrison_army_id", &"")) == army_id:
			return false
	if StringName(facility.get("garrison_army_id", &"")) != &"":
		return false
	facility.garrison_army_id = army_id
	watchtowers_by_id[facility_id] = facility
	return true


func release_fortress_garrison(facility_id: StringName, army_id: StringName = &"") -> bool:
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if facility.is_empty() or StringName(facility.get("facility_kind", &"")) != FACILITY_FORTRESS:
		return false
	var assigned_id := StringName(facility.get("garrison_army_id", &""))
	if assigned_id == &"" or (army_id != &"" and assigned_id != army_id):
		return false
	facility.garrison_army_id = &""
	watchtowers_by_id[facility_id] = facility
	return true


func fortress_for_army(army_id: StringName) -> Dictionary:
	for facility_value in watchtowers_by_id.values():
		var facility: Dictionary = Dictionary(facility_value)
		if (
			StringName(facility.get("facility_kind", &"")) == FACILITY_FORTRESS
			and StringName(facility.get("garrison_army_id", &"")) == army_id
			and StringName(facility.get("state", FACILITY_ACTIVE)) != FACILITY_DESTROYED
		):
			return facility.duplicate(true)
	return {}


func discover_minefield(facility_id: StringName, faction_id: StringName, specialist_id: StringName) -> bool:
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	var specialist := Dictionary(specialists_by_id.get(specialist_id, {}))
	if (
		facility.is_empty()
		or StringName(facility.get("facility_kind", &"")) != FACILITY_MINEFIELD
		or faction_id == &""
		or specialist.is_empty()
		or not bool(specialist.get("alive", false))
		or StringName(specialist.get("role", &"")) not in [SPECIALIST_SCOUT, SPECIALIST_ENGINEER]
		or Vector2(specialist.get("world_position", Vector2.INF)).distance_to(Vector2(facility.get("world_position", Vector2.ZERO))) > float(scout_visibility_range)
	):
		return false
	var discovered: Array = Array(facility.get("discovered_by_faction_ids", []))
	if faction_id not in discovered:
		discovered.append(faction_id)
	facility.discovered_by_faction_ids = discovered
	watchtowers_by_id[facility_id] = facility
	return true


func clear_discovered_minefield(facility_id: StringName, faction_id: StringName, engineer_id: StringName) -> bool:
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	if (
		facility.is_empty()
		or StringName(facility.get("facility_kind", &"")) != FACILITY_MINEFIELD
		or faction_id not in Array(facility.get("discovered_by_faction_ids", []))
		or engineer.is_empty()
		or not bool(engineer.get("alive", false))
		or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or Vector2(engineer.get("world_position", Vector2.INF)).distance_to(Vector2(facility.get("world_position", Vector2.ZERO))) > float(scout_visibility_range)
	):
		return false
	facility.mine_charges = 0
	facility.durability = 0
	facility.state = FACILITY_DESTROYED
	watchtowers_by_id[facility_id] = facility
	return true


func absorb_fortress_casualties(facility_id: StringName, prevented_count: int) -> bool:
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if (
		facility.is_empty()
		or StringName(facility.get("facility_kind", &"")) != FACILITY_FORTRESS
		or prevented_count <= 0
	):
		return false
	facility.durability = maxi(int(facility.get("durability", 0)) - prevented_count * 10, 0)
	facility.state = FACILITY_DESTROYED if int(facility.durability) <= 0 else FACILITY_DAMAGED
	if StringName(facility.state) == FACILITY_DESTROYED:
		facility.garrison_army_id = &""
	watchtowers_by_id[facility_id] = facility
	return true


func _field_facility_config(facility_kind: StringName) -> Dictionary:
	if facility_kind == FACILITY_WATCHTOWER:
		return {
			"display_name": "瞭望塔",
			"food_cost": int(watchtower_config.get("food_cost", 6)),
			"required_milliseconds": int(watchtower_config.get("required_milliseconds", 6000)),
			"max_durability": 100,
			"visibility_range": int(watchtower_config.get("visibility_range", 360)),
			"effect_range": int(watchtower_config.get("visibility_range", 360)),
			"upgrade_food_cost": int(watchtower_config.get("upgrade_food_cost", 6)),
			"upgrade_required_milliseconds": int(watchtower_config.get("upgrade_required_milliseconds", 7000)),
		}
	return Dictionary(Dictionary(watchtower_config.get("field_facilities", {})).get(facility_kind, {})).duplicate(true)


func preview_field_facility_repair(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if engineer.is_empty() or not bool(engineer.get("alive", false)) or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER or StringName(engineer.get("phase", &"")) not in [SPECIALIST_IDLE, SPECIALIST_BLOCKED] or StringName(engineer.get("project_id", &"")) != &"":
		return {"valid": false, "error": "需要一名空闲且存活的工程师"}
	if facility.is_empty() or StringName(facility.get("facility_kind", FACILITY_WATCHTOWER)) == FACILITY_WATCHTOWER:
		return {"valid": false, "error": "该目标不是本批可维修的外部防御设施"}
	if int(facility.get("durability", 0)) >= int(facility.get("max_durability", 0)):
		return {"valid": false, "error": "设施当前无需维修"}
	var camp := Dictionary(camps_by_id.get(StringName(facility.get("camp_id", &"")), {}))
	if camp.is_empty() or not bool(camp.get("connected", false)) or not is_route_open(StringName(camp.get("road_id", &""))):
		return {"valid": false, "error": "设施所属驻点或补给道路已断开"}
	var start_position := Vector2(engineer.get("world_position", Vector2.ZERO))
	var work_position := Vector2(facility.get("world_position", Vector2.ZERO))
	var movement_plan := _plan_specialist_land_path(start_position, work_position)
	if movement_plan.is_empty():
		return {"valid": false, "error": "工程师无法到达受损设施"}
	var facility_kind := StringName(facility.get("facility_kind", &""))
	if facility_kind == FACILITY_MINEFIELD and StringName(facility.get("owner_faction_id", &"player")) != &"player":
		return {"valid": false, "error": "敌方地雷不能维修，只能由工程师排除"}
	return {"valid": true, "engineer_id": engineer_id, "facility_id": facility_id, "facility_kind": facility_kind, "food_cost": 3, "required_milliseconds": 4000, "restore_mine_charges": maxi(int(_field_facility_config(facility_kind).get("mine_charges", 0)), 0), "travel_milliseconds": int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(work_position) > 0.01 else 0, "engineer_movement_plan": movement_plan.duplicate(true), "world_position": Vector2i(work_position)}


func begin_field_facility_repair(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	var preview := preview_field_facility_repair(engineer_id, facility_id)
	if not bool(preview.get("valid", false)):
		return {}
	var engineer := Dictionary(specialists_by_id[engineer_id])
	var facility := Dictionary(watchtowers_by_id[facility_id])
	var project_id := StringName("facility-repair.%06d" % next_project_sequence)
	next_project_sequence += 1
	var travel := int(preview.get("travel_milliseconds", 0))
	var work_position := Vector2i(preview.get("world_position", Vector2i.ZERO))
	var project := {"project_id": project_id, "project_kind": PROJECT_FACILITY_REPAIR, "engineer_id": engineer_id, "road_id": StringName(Dictionary(camps_by_id.get(StringName(facility.get("camp_id", &"")), {})).get("road_id", &"")), "source_point_id": StringName(engineer.get("current_point_id", &"")), "target_point_id": StringName(Dictionary(camps_by_id.get(StringName(facility.get("camp_id", &"")), {})).get("point_id", &"")), "facility_id": facility_id, "facility_kind": StringName(facility.get("facility_kind", &"")), "work_world_position": work_position, "route_world_points": [work_position], "road_kind": ROAD_NORMAL, "progress_milliseconds": 0, "travel_milliseconds": travel, "required_milliseconds": int(preview.get("required_milliseconds", 4000)), "restore_mine_charges": int(preview.get("restore_mine_charges", 0)), "segment_plans": [], "build_camp": false, "phase": &"TRAVELING" if travel > 0 else &"BUILDING"}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	engineer.target_point_id = StringName(project.target_point_id)
	engineer.target_world_position = work_position
	engineer.move_start_position = Vector2i(engineer.get("world_position", work_position))
	engineer.move_route_world_points = Array(Dictionary(preview.get("engineer_movement_plan", {})).get("points", [])).duplicate(true)
	engineer.move_total_milliseconds = travel
	engineer.move_elapsed_milliseconds = 0
	engineer.move_remaining_milliseconds = travel
	engineer.phase = SPECIALIST_MOVING if travel > 0 else SPECIALIST_REPAIRING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func preview_field_facility_upgrade(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if engineer.is_empty() or not bool(engineer.get("alive", false)) or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER or StringName(engineer.get("phase", &"")) not in [SPECIALIST_IDLE, SPECIALIST_BLOCKED] or StringName(engineer.get("project_id", &"")) != &"":
		return {"valid": false, "error": "需要一名空闲且存活的工程师"}
	if facility.is_empty() or StringName(facility.get("state", FACILITY_ACTIVE)) == FACILITY_DESTROYED:
		return {"valid": false, "error": "设施不存在或已摧毁，必须先维修"}
	if int(facility.get("level", 1)) >= 2:
		return {"valid": false, "error": "该设施已达到当前最高等级"}
	for project_value in projects_by_id.values():
		var existing: Dictionary = Dictionary(project_value)
		if StringName(existing.get("facility_id", &"")) == facility_id and StringName(existing.get("phase", &"")) != &"COMPLETE":
			return {"valid": false, "error": "该设施已有维修或升级工程"}
	var camp := Dictionary(camps_by_id.get(StringName(facility.get("camp_id", &"")), {}))
	if camp.is_empty() or not bool(camp.get("connected", false)) or not is_route_open(StringName(camp.get("road_id", &""))):
		return {"valid": false, "error": "设施所属驻点或补给道路已断开"}
	var start_position := Vector2(engineer.get("world_position", Vector2.ZERO))
	var work_position := Vector2(facility.get("world_position", Vector2.ZERO))
	var movement_plan := _plan_specialist_land_path(start_position, work_position)
	if movement_plan.is_empty():
		return {"valid": false, "error": "工程师无法到达升级工地"}
	var kind := StringName(facility.get("facility_kind", FACILITY_WATCHTOWER))
	var config := _field_facility_config(kind)
	return {
		"valid": true,
		"engineer_id": engineer_id,
		"facility_id": facility_id,
		"facility_kind": kind,
		"food_cost": maxi(int(config.get("upgrade_food_cost", 6)), 0),
		"required_milliseconds": maxi(int(config.get("upgrade_required_milliseconds", 7000)), 1),
		"travel_milliseconds": int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(work_position) > 0.01 else 0,
		"engineer_movement_plan": movement_plan.duplicate(true),
		"world_position": Vector2i(work_position),
		"target_level": 2,
		"target_max_durability": ceili(float(int(facility.get("max_durability", 1))) * 1.5),
		"target_effect_range": ceili(float(int(facility.get("effect_range", 1))) * 1.2),
		"target_damage": int(facility.get("damage", 0)) + (1 if kind == FACILITY_ARROW_TOWER else 0),
		"target_route_delay_milliseconds": int(facility.get("route_delay_milliseconds", 0)) + (2000 if kind == FACILITY_BARRICADE else 0),
		"target_mine_charges": int(facility.get("mine_charges", 0)) + (1 if kind == FACILITY_MINEFIELD else 0),
		"target_garrison_reduction_permille": mini(int(facility.get("garrison_casualty_reduction_permille", 0)) + (150 if kind == FACILITY_FORTRESS else 0), 750),
	}


func begin_field_facility_upgrade(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	var preview := preview_field_facility_upgrade(engineer_id, facility_id)
	if not bool(preview.get("valid", false)):
		return {}
	var engineer := Dictionary(specialists_by_id[engineer_id])
	var facility := Dictionary(watchtowers_by_id[facility_id])
	var project_id := StringName("facility-upgrade.%06d" % next_project_sequence)
	next_project_sequence += 1
	var travel := int(preview.get("travel_milliseconds", 0))
	var work_position := Vector2i(preview.get("world_position", Vector2i.ZERO))
	var project := preview.duplicate(true)
	project.erase("valid")
	project.project_id = project_id
	project.project_kind = PROJECT_FACILITY_UPGRADE
	project.road_id = StringName(Dictionary(camps_by_id.get(StringName(facility.get("camp_id", &"")), {})).get("road_id", &""))
	project.source_point_id = StringName(engineer.get("current_point_id", &""))
	project.target_point_id = StringName(Dictionary(camps_by_id.get(StringName(facility.get("camp_id", &"")), {})).get("point_id", &""))
	project.work_world_position = work_position
	project.route_world_points = [work_position]
	project.road_kind = ROAD_NORMAL
	project.progress_milliseconds = 0
	project.travel_milliseconds = travel
	project.segment_plans = []
	project.build_camp = false
	project.phase = &"TRAVELING" if travel > 0 else &"BUILDING"
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	engineer.target_point_id = StringName(project.target_point_id)
	engineer.target_world_position = work_position
	engineer.move_start_position = Vector2i(engineer.get("world_position", work_position))
	engineer.move_route_world_points = Array(Dictionary(preview.get("engineer_movement_plan", {})).get("points", [])).duplicate(true)
	engineer.move_total_milliseconds = travel
	engineer.move_elapsed_milliseconds = 0
	engineer.move_remaining_milliseconds = travel
	engineer.phase = SPECIALIST_MOVING if travel > 0 else SPECIALIST_BUILDING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func _canonical_world_points(points: Array) -> Array:
	var canonical: Array = []
	for point in points:
		canonical.append(Vector2i(point))
	return canonical


func road_kind_for_route(route_world_points: Array, requested_road_kind: StringName) -> StringName:
	# This is the player's land-road material, not a summary of every physical
	# segment. _build_construction_segment_plans independently marks only water
	# spans as bridges, so a normal or reinforced road keeps its material on
	# both banks when submitted through the formal Controller path.
	if requested_road_kind not in [ROAD_NORMAL, ROAD_REINFORCED, ROAD_BRIDGE]:
		return ROAD_NORMAL
	return requested_road_kind


func construction_contains_bridge(route_world_points: Array, requested_road_kind: StringName) -> bool:
	return requested_road_kind == ROAD_BRIDGE or _route_crosses_water(route_world_points)


func _build_construction_segment_plans(
	project_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	requested_road_kind: StringName,
	road_sequence: int
) -> Array:
	if requested_road_kind != ROAD_BRIDGE and not _route_crosses_water(route_world_points):
		var max_durability := 150 if requested_road_kind == ROAD_REINFORCED else 70
		return [{
			"road_id": StringName("road.built.%06d" % road_sequence),
			"source_point_id": source_point_id,
			"target_point_id": target_point_id,
			"route_world_points": route_world_points.duplicate(true),
			"road_kind": requested_road_kind,
			"required_milliseconds": 9000 if requested_road_kind == ROAD_REINFORCED else 5000,
			"max_durability": max_durability,
		}]
	var sections: Array = []
	for point_index in range(1, route_world_points.size()):
		var start := Vector2(route_world_points[point_index - 1])
		var end := Vector2(route_world_points[point_index])
		# Keep construction classification as conservative as specialist movement:
		# a narrow water strip must produce a bridge segment instead of being
		# skipped by a coarse midpoint interval.
		var samples := maxi(1, ceili(start.distance_to(end)))
		for sample_index in range(1, samples + 1):
			var part_start := start.lerp(end, float(sample_index - 1) / float(samples))
			var part_end := start.lerp(end, float(sample_index) / float(samples))
			var part_kind := requested_road_kind
			if requested_road_kind != ROAD_BRIDGE and _point_is_in_water(Vector2i((part_start + part_end) * 0.5)):
				part_kind = ROAD_BRIDGE
			if sections.is_empty() or StringName(Dictionary(sections.back()).get("road_kind", &"")) != part_kind:
				sections.append({"road_kind": part_kind, "route_world_points": [Vector2i(part_start), Vector2i(part_end)]})
			else:
				Array(Dictionary(sections.back()).route_world_points).append(Vector2i(part_end))
	var plans: Array = []
	for section_index in range(sections.size()):
		var section: Dictionary = Dictionary(sections[section_index])
		var is_first := section_index == 0
		var is_last := section_index == sections.size() - 1
		var section_kind := StringName(section.get("road_kind", ROAD_NORMAL))
		var section_id := StringName("road.built.%06d" % road_sequence) if sections.size() == 1 else StringName("road.built.%06d.%02d" % [road_sequence, section_index + 1])
		plans.append({
			"road_id": section_id,
			"source_point_id": source_point_id if is_first else StringName("junction.%s.%02d" % [String(project_id), section_index]),
			"target_point_id": target_point_id if is_last else StringName("junction.%s.%02d" % [String(project_id), section_index + 1]),
			"route_world_points": Array(section.get("route_world_points", [])).duplicate(true),
			"road_kind": section_kind,
			"required_milliseconds": 11000 if section_kind == ROAD_BRIDGE else (9000 if section_kind == ROAD_REINFORCED else 5000),
			"max_durability": 100 if section_kind == ROAD_BRIDGE else (150 if section_kind == ROAD_REINFORCED else 70),
		})
	return plans


func _point_is_in_water(position: Vector2i) -> bool:
	for water_region in water_regions:
		if water_region.has_point(position):
			return true
	return false


func _route_crosses_water(route_world_points: Array) -> bool:
	for index in range(1, route_world_points.size()):
		var start := Vector2(route_world_points[index - 1])
		var end := Vector2(route_world_points[index])
		# Unit-length sampling is intentionally conservative for the greybox
		# coordinate grid. It catches narrow water strips that the former 16px
		# sampling interval could skip without relying on unavailable geometry APIs.
		var samples := maxi(1, ceili(start.distance_to(end)))
		for sample_index in range(samples + 1):
			var position := Vector2i(start.lerp(end, float(sample_index) / float(samples)))
			for water_region in water_regions:
				if water_region.has_point(position):
					return true
	return false


func damage_road(road_id: StringName, amount: int) -> bool:
	var road := Dictionary(roads_by_id.get(road_id, {}))
	if road.is_empty() or StringName(road.get("road_kind", &"")) == ROAD_MAIN or amount <= 0:
		return false
	road.durability = maxi(int(road.get("durability", 0)) - amount, 0)
	if int(road.durability) == 0:
		road.state = ROAD_DAMAGED
	roads_by_id[road_id] = road
	return true


func repair_road(engineer_id: StringName, road_id: StringName) -> bool:
	return not begin_road_repair(engineer_id, road_id).is_empty()


func preview_road_repair(engineer_id: StringName, road_id: StringName) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var road := Dictionary(roads_by_id.get(road_id, {}))
	if (
		engineer.is_empty() or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or not bool(engineer.get("alive", false)) or road.is_empty()
		or StringName(road.get("road_kind", &"")) == ROAD_MAIN
		or StringName(road.get("state", &"")) != ROAD_DAMAGED
		or StringName(engineer.get("project_id", &"")) != &""
	):
		return {"valid": false, "error": "工程师当前无法维修该道路"}
	var repair_target := _reachable_repair_endpoint(engineer, road)
	if repair_target.is_empty():
		return {"valid": false, "error": "工程师无法到达受损道路"}
	return {
		"valid": true,
		"target_point_id": StringName(repair_target.get("point_id", &"")),
		"duration_milliseconds": int(Dictionary(repair_target.get("movement_plan", {})).get("duration_milliseconds", 0)),
	}


func begin_road_repair(engineer_id: StringName, road_id: StringName) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var road := Dictionary(roads_by_id.get(road_id, {}))
	if (
		engineer.is_empty() or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or not bool(engineer.get("alive", false)) or road.is_empty()
		or StringName(road.get("road_kind", &"")) == ROAD_MAIN
		or StringName(road.get("state", &"")) != ROAD_DAMAGED
		or StringName(engineer.get("project_id", &"")) != &""
	):
		return {}
	var repair_target := _reachable_repair_endpoint(engineer, road)
	if repair_target.is_empty():
		return {}
	var project_id := StringName("repair.%06d" % next_project_sequence)
	next_project_sequence += 1
	var target_point_id := StringName(repair_target.get("point_id", &""))
	var target_position := Vector2(repair_target.get("world_position", Vector2.ZERO))
	if Vector2i(target_position) == INVALID_WORLD_POSITION:
		return {}
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var movement_plan := Dictionary(repair_target.get("movement_plan", {}))
	if movement_plan.is_empty():
		return {}
	var travel_milliseconds := int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(target_position) > 0.01 else 0
	var project := {
		"project_id": project_id,
		"project_kind": &"REPAIR",
		"engineer_id": engineer_id,
		"road_id": road_id,
		"source_point_id": StringName(engineer.get("current_point_id", &"")),
		"target_point_id": target_point_id,
		"route_world_points": [],
		"road_kind": StringName(road.get("road_kind", &"")),
		"progress_milliseconds": 0,
		"required_milliseconds": 2500,
		"max_durability": int(road.get("max_durability", 0)),
		# A repair may be rolled back within the same world step when its engineer
		# is contacted before the actual completion instant. Preserve the damaged
		# road fact so that correction does not leave a repaired bridge open.
		"repair_initial_durability": int(road.get("durability", 0)),
		"build_camp": false,
		"camp_id": &"",
		"phase": &"TRAVELING" if travel_milliseconds > 0 else &"BUILDING",
	}
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	if travel_milliseconds > 0:
		engineer.target_point_id = target_point_id
		engineer.move_start_position = Vector2i(start_position)
		engineer.target_world_position = Vector2i(target_position)
		engineer.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
		engineer.world_position = Vector2i(start_position)
		engineer.move_total_milliseconds = travel_milliseconds
		engineer.move_elapsed_milliseconds = 0
		engineer.move_remaining_milliseconds = travel_milliseconds
		engineer.phase = SPECIALIST_MOVING
	else:
		engineer.phase = SPECIALIST_REPAIRING
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func resume_interrupted_project(engineer_id: StringName, project_id: StringName) -> Dictionary:
	var engineer := Dictionary(specialists_by_id.get(engineer_id, {}))
	var project := Dictionary(projects_by_id.get(project_id, {}))
	if (
		engineer.is_empty() or project.is_empty()
		or StringName(engineer.get("role", &"")) != SPECIALIST_ENGINEER
		or not bool(engineer.get("alive", false))
		or StringName(engineer.get("project_id", &"")) != &""
		or StringName(project.get("phase", &"")) != &"INTERRUPTED"
	):
		return {}
	var target_position := _interrupted_project_work_position(project)
	if target_position == INVALID_WORLD_POSITION:
		return {}
	if StringName(project.get("project_kind", &"")) == &"REPAIR":
		var road := Dictionary(roads_by_id.get(StringName(project.get("road_id", &"")), {}))
		if road.is_empty() or StringName(road.get("state", &"")) != ROAD_DAMAGED:
			return {}
		var repair_target := _reachable_repair_endpoint(engineer, road)
		if repair_target.is_empty():
			return {}
		target_position = Vector2i(repair_target.get("world_position", INVALID_WORLD_POSITION))
		project.target_point_id = StringName(repair_target.get("point_id", &""))
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	var movement_plan := _plan_specialist_land_path(start_position, Vector2(target_position))
	if movement_plan.is_empty():
		return {}
	var travel_milliseconds := int(movement_plan.get("duration_milliseconds", 0)) if start_position.distance_to(Vector2(target_position)) > 0.01 else 0
	var previous_engineer_id := StringName(project.get("engineer_id", &""))
	if specialists_by_id.has(previous_engineer_id):
		var previous_engineer := Dictionary(specialists_by_id[previous_engineer_id])
		previous_engineer.project_id = &""
		specialists_by_id[previous_engineer_id] = previous_engineer
	project.engineer_id = engineer_id
	project.phase = &"TRAVELING" if travel_milliseconds > 0 else &"BUILDING"
	project.interruption_reason = &""
	projects_by_id[project_id] = project
	engineer.project_id = project_id
	engineer.target_world_position = target_position
	engineer.move_start_position = Vector2i(start_position)
	engineer.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
	engineer.move_total_milliseconds = travel_milliseconds
	engineer.move_elapsed_milliseconds = 0
	engineer.move_remaining_milliseconds = travel_milliseconds
	engineer.phase = SPECIALIST_MOVING if travel_milliseconds > 0 else (SPECIALIST_REPAIRING if StringName(project.get("project_kind", &"")) == &"REPAIR" else SPECIALIST_BUILDING)
	if travel_milliseconds <= 0:
		engineer.world_position = target_position
	specialists_by_id[engineer_id] = engineer
	return project.duplicate(true)


func _interrupted_project_work_position(project: Dictionary) -> Vector2i:
	if StringName(project.get("project_kind", &"")) == &"REPAIR":
		return _point_position(StringName(project.get("target_point_id", &"")))
	if StringName(project.get("project_kind", &"")) == &"WATCHTOWER":
		return Vector2i(project.get("work_world_position", INVALID_WORLD_POSITION))
	var elapsed := int(project.get("progress_milliseconds", 0))
	var accumulated := 0
	for segment_value in Array(project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		var duration := maxi(int(segment.get("required_milliseconds", 0)), 1)
		if elapsed >= accumulated + duration:
			accumulated += duration
			continue
		var points: Array = Array(segment.get("route_world_points", []))
		if points.is_empty():
			return INVALID_WORLD_POSITION
		if StringName(segment.get("road_kind", &"")) == ROAD_BRIDGE:
			return Vector2i(points.front())
		return Vector2i(_position_along_points(points, clampf(float(elapsed - accumulated) / float(duration), 0.0, 1.0)))
	return INVALID_WORLD_POSITION


func _reachable_repair_endpoint(engineer: Dictionary, road: Dictionary) -> Dictionary:
	var start_position := Vector2(engineer.get("world_position", _point_position(StringName(engineer.get("current_point_id", &"")))))
	if Vector2i(start_position) == INVALID_WORLD_POSITION:
		return {}
	var best: Dictionary = {}
	for endpoint_id_value in [road.get("source_point_id", &""), road.get("target_point_id", &"")]:
		var endpoint_id := StringName(endpoint_id_value)
		if endpoint_id == &"":
			continue
		var endpoint_position := _point_position(endpoint_id)
		if endpoint_position == INVALID_WORLD_POSITION:
			continue
		var movement_plan := _plan_specialist_land_path(start_position, Vector2(endpoint_position))
		if movement_plan.is_empty():
			continue
		var distance_units := float(movement_plan.get("distance_units", INF))
		if best.is_empty() or distance_units < float(best.get("distance_units", INF)):
			best = {
				"point_id": endpoint_id,
				"world_position": endpoint_position,
				"distance_units": distance_units,
				"movement_plan": movement_plan,
			}
	return best


static func _has_valid_references(roads: Dictionary, camps: Dictionary, watchtowers: Dictionary, specialists: Dictionary, projects: Dictionary, patrols: Dictionary, intel: Dictionary, next_watchtower_sequence_value: int = 1) -> bool:
	for road_id_value in roads:
		var road: Dictionary = Dictionary(roads[road_id_value])
		if StringName(road_id_value) == &"" or StringName(road.get("road_id", &"")) != StringName(road_id_value) or StringName(road.get("state", &"")) not in [ROAD_OPEN, ROAD_DAMAGED]:
			return false
	for specialist_id_value in specialists:
		var specialist: Dictionary = Dictionary(specialists[specialist_id_value])
		if StringName(specialist_id_value) == &"" or StringName(specialist.get("specialist_id", &"")) != StringName(specialist_id_value) or StringName(specialist.get("role", &"")) not in SPECIALIST_ROLES:
			return false
		if specialist.has("action_kind") and not _has_valid_specialist_action_state(specialist):
			return false
		var project_id := StringName(specialist.get("project_id", &""))
		if project_id != &"" and not projects.has(project_id):
			return false
	var claimed_tower_projects: Dictionary = {}
	var highest_watchtower_sequence := 0
	for project_id_value in projects:
		var project: Dictionary = Dictionary(projects[project_id_value])
		if StringName(project_id_value) == &"" or StringName(project.get("project_id", &"")) != StringName(project_id_value) or not specialists.has(StringName(project.get("engineer_id", &""))) or StringName(project.get("road_id", &"")) == &"":
			return false
		if StringName(project.get("project_kind", &"")) == &"WATCHTOWER":
			var project_tower_id := StringName(project.get("tower_id", &""))
			var project_tower_sequence := _watchtower_sequence_from_id(project_tower_id)
			if (
				not camps.has(StringName(project.get("camp_id", &"")))
				or project_tower_sequence <= 0
				or not project.get("work_world_position", null) is Vector2i
				or not _is_snapshot_int(project.get("visibility_range", null))
				or int(project.get("visibility_range", 0)) <= 0
				or claimed_tower_projects.has(project_tower_id)
			):
				return false
			claimed_tower_projects[project_tower_id] = project.duplicate(true)
			highest_watchtower_sequence = maxi(highest_watchtower_sequence, project_tower_sequence)
	for camp_id_value in camps:
		var camp: Dictionary = Dictionary(camps[camp_id_value])
		if StringName(camp_id_value) == &"" or StringName(camp.get("camp_id", &"")) != StringName(camp_id_value) or not roads.has(StringName(camp.get("road_id", &""))):
			return false
	var tower_camps: Dictionary = {}
	for tower_id_value in watchtowers:
		var tower: Dictionary = Dictionary(watchtowers[tower_id_value])
		var tower_id := StringName(tower_id_value)
		var tower_sequence := _watchtower_sequence_from_id(tower_id)
		var authored := bool(tower.get("authored", false))
		var facility_kind := StringName(tower.get("facility_kind", FACILITY_WATCHTOWER))
		var facility_state := StringName(tower.get("state", FACILITY_ACTIVE))
		if (
			(not authored and tower_sequence <= 0)
			or StringName(tower.get("watchtower_id", &"")) != tower_id
			or (not authored and not camps.has(StringName(tower.get("camp_id", &""))))
			or not tower.get("world_position", null) is Vector2i
			or not _is_snapshot_int(tower.get("visibility_range", null))
			or int(tower.get("visibility_range", 0)) <= 0
			or typeof(tower.get("complete", null)) != TYPE_BOOL
			or not bool(tower.get("complete", false))
			or facility_kind not in [FACILITY_WATCHTOWER, FACILITY_ARROW_TOWER, FACILITY_BARRICADE, FACILITY_FORTRESS, FACILITY_MINEFIELD]
			or facility_state not in [FACILITY_ACTIVE, FACILITY_DAMAGED, FACILITY_DESTROYED]
		):
			return false
		if facility_kind != FACILITY_WATCHTOWER and (
			not _is_snapshot_int(tower.get("durability", null))
			or not _is_snapshot_int(tower.get("max_durability", null))
			or int(tower.get("max_durability", 0)) <= 0
			or int(tower.get("durability", -1)) < 0
			or int(tower.get("durability", 0)) > int(tower.get("max_durability", 0))
			or not _is_snapshot_int(tower.get("effect_range", null))
			or int(tower.get("effect_range", 0)) <= 0
			or not tower.get("affected_patrol_ids", null) is Array
		):
			return false
		if tower.has("level") and (not _is_snapshot_int(tower.get("level")) or int(tower.get("level", 0)) not in [1, 2]):
			return false
		if facility_kind == FACILITY_FORTRESS and (
			not _is_snapshot_int(tower.get("garrison_casualty_reduction_permille", null))
			or int(tower.get("garrison_casualty_reduction_permille", -1)) < 0
			or int(tower.get("garrison_casualty_reduction_permille", 1001)) > 1000
			or typeof(tower.get("garrison_army_id", null)) not in [TYPE_STRING, TYPE_STRING_NAME]
		):
			return false
		if facility_kind == FACILITY_MINEFIELD and (
			not _is_snapshot_int(tower.get("mine_charges", null))
			or int(tower.get("mine_charges", -1)) < 0
			or not _is_snapshot_int(tower.get("mine_damage", null))
			or int(tower.get("mine_damage", 0)) <= 0
			or not _is_snapshot_id(tower.get("owner_faction_id", null))
			or not tower.get("discovered_by_faction_ids", null) is Array
			or (int(tower.get("mine_charges", 0)) == 0) != (facility_state == FACILITY_DESTROYED)
		):
			return false
		if facility_kind == FACILITY_MINEFIELD:
			for faction_id_value in Array(tower.get("discovered_by_faction_ids", [])):
				if not _is_snapshot_id(faction_id_value):
					return false
		# A complete project may retain its historical reservation for its own
		# completed tower. Any live reservation sharing a completed ID is a
		# collision and would otherwise make a later completion disappear. The
		# completed record must agree with that project's camp, anchor and range.
		if authored:
			if (
				StringName(tower.get("owner_faction_id", &"")) == &""
				or not tower.get("discovered_by_faction_ids", null) is Array
			):
				return false
			continue
		var tower_camp_id := StringName(tower.get("camp_id", &""))
		var tower_camp_slot := "%s:%s" % [String(tower_camp_id), String(tower.get("facility_kind", FACILITY_WATCHTOWER))]
		if tower_camps.has(tower_camp_slot) or not claimed_tower_projects.has(tower_id):
			return false
		tower_camps[tower_camp_slot] = true
		var tower_project: Dictionary = Dictionary(claimed_tower_projects[tower_id])
		if (
			StringName(tower_project.get("phase", &"")) != &"COMPLETE"
			or StringName(tower_project.get("camp_id", &"")) != tower_camp_id
			or StringName(tower_project.get("facility_kind", FACILITY_WATCHTOWER)) != facility_kind
			or Vector2i(tower_project.get("work_world_position", INVALID_WORLD_POSITION)) != Vector2i(tower.get("world_position", INVALID_WORLD_POSITION))
			or int(tower_project.get("visibility_range", 0)) != int(tower.get("visibility_range", 0))
		):
			return false
		highest_watchtower_sequence = maxi(highest_watchtower_sequence, tower_sequence)
	if next_watchtower_sequence_value <= highest_watchtower_sequence:
		return false
	for patrol_id_value in patrols:
		if StringName(patrol_id_value) == &"" or not patrols[patrol_id_value] is Dictionary:
			return false
	for subject_id_value in intel:
		if StringName(subject_id_value) == &"" or not intel[subject_id_value] is Dictionary:
			return false
	return true


static func _has_valid_specialist_action_state(specialist: Dictionary) -> bool:
	var required := [
		"action_kind", "action_stage", "action_target_id", "action_target_world_position",
		"action_progress_milliseconds", "action_required_milliseconds",
		"action_cargo_food", "action_result",
	]
	for key in required:
		if not specialist.has(key):
			return false
	if (
		typeof(specialist.action_kind) != TYPE_STRING_NAME
		or typeof(specialist.action_stage) != TYPE_STRING_NAME
		or typeof(specialist.action_target_id) != TYPE_STRING_NAME
		or not specialist.action_target_world_position is Vector2i
		or typeof(specialist.action_progress_milliseconds) != TYPE_INT
		or typeof(specialist.action_required_milliseconds) != TYPE_INT
		or typeof(specialist.action_cargo_food) != TYPE_INT
		or typeof(specialist.action_result) != TYPE_DICTIONARY
		or int(specialist.action_progress_milliseconds) < 0
		or int(specialist.action_required_milliseconds) < 0
		or int(specialist.action_cargo_food) < 0
	):
		return false
	var kind := StringName(specialist.action_kind)
	var stage := StringName(specialist.action_stage)
	if kind == &"":
		return stage == ACTION_NONE and int(specialist.action_required_milliseconds) == 0
	if kind not in ACTION_KINDS or stage not in [ACTION_TRAVELING, ACTION_WORKING, ACTION_READY, ACTION_RETURNING, ACTION_READY_DEPOSIT, ACTION_COMPLETED, ACTION_INTERRUPTED]:
		return false
	return int(specialist.action_required_milliseconds) > 0 and int(specialist.action_progress_milliseconds) <= int(specialist.action_required_milliseconds)


static func _is_snapshot_id(value: Variant) -> bool:
	return (typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING) and StringName(value) != &""


static func _is_snapshot_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT


static func _watchtower_sequence_from_id(value: StringName) -> int:
	var text := String(value)
	if not text.begins_with("watchtower."):
		return 0
	var sequence_text := text.trim_prefix("watchtower.")
	if not sequence_text.is_valid_int() or sequence_text != "%06d" % int(sequence_text):
		return 0
	return int(sequence_text)


static func _supply_segment_endpoints(segment: Dictionary, roads: Dictionary) -> Dictionary:
	if not segment.has("road_id") or not segment.has("forward") or typeof(segment.get("forward")) != TYPE_BOOL:
		return {}
	var road_id_value: Variant = segment.get("road_id")
	if not _is_snapshot_id(road_id_value):
		return {}
	var road := Dictionary(roads.get(StringName(road_id_value), {}))
	if road.is_empty() or not road.get("route_world_points", null) is Array:
		return {}
	var points: Array = Array(road.get("route_world_points", [])).duplicate(true)
	if points.size() < 2:
		return {}
	for point in points:
		if not point is Vector2i:
			return {}
	if not _is_snapshot_id(road.get("source_point_id")) or not _is_snapshot_id(road.get("target_point_id")):
		return {}
	var forward := bool(segment.get("forward"))
	if not forward:
		points.reverse()
	return {
		"road_id": StringName(road_id_value),
		"source_point_id": StringName(road.get("source_point_id")) if forward else StringName(road.get("target_point_id")),
		"target_point_id": StringName(road.get("target_point_id")) if forward else StringName(road.get("source_point_id")),
		"points": points,
	}


static func _has_valid_stationed_reinforcement_state(inventory: Dictionary) -> bool:
	for point_id_value in inventory:
		if not _is_snapshot_id(point_id_value) or not _is_snapshot_int(inventory[point_id_value]) or int(inventory[point_id_value]) < 0:
			return false
		# R0 has one authored Silverford pool. Its authored amount remains a
		# theatre Resource setting, so persistence validates the identity and the
		# finite non-negative fact without baking this sample's current value (4)
		# into every compatible save.
		if StringName(point_id_value) != &"silverford_city":
			return false
	return true


static func _has_valid_supply_state(inventory: Dictionary, transports: Dictionary, roads: Dictionary, next_sequence: Variant) -> bool:
	if not _is_snapshot_int(next_sequence) or int(next_sequence) <= 0:
		return false
	var source_totals: Dictionary = {}
	var greatest_sequence := 0
	for point_id_value in inventory:
		if not _is_snapshot_id(point_id_value) or not _is_snapshot_int(inventory[point_id_value]) or int(inventory[point_id_value]) < 0:
			return false
		source_totals[StringName(point_id_value)] = int(inventory[point_id_value])
	for transport_id_value in transports:
		if not _is_snapshot_id(transport_id_value) or not transports[transport_id_value] is Dictionary:
			return false
		var transport: Dictionary = Dictionary(transports[transport_id_value])
		var transport_id := StringName(transport_id_value)
		var id_text := String(transport_id)
		if not id_text.begins_with("supply.") or id_text.length() != 13 or not id_text.substr(7).is_valid_int():
			return false
		var sequence := int(id_text.substr(7))
		if sequence <= 0 or sequence >= int(next_sequence):
			return false
		greatest_sequence = maxi(greatest_sequence, sequence)
		if (
			not _is_snapshot_id(transport.get("transport_id")) or StringName(transport.get("transport_id")) != transport_id
			or not _is_snapshot_id(transport.get("source_point_id")) or not _is_snapshot_id(transport.get("target_point_id"))
			or not _is_snapshot_int(transport.get("amount")) or int(transport.get("amount")) <= 0
			or not _is_snapshot_int(transport.get("total_milliseconds")) or int(transport.get("total_milliseconds")) <= 0
			or not _is_snapshot_int(transport.get("elapsed_milliseconds")) or int(transport.get("elapsed_milliseconds")) < 0
			or int(transport.get("elapsed_milliseconds")) > int(transport.get("total_milliseconds"))
			or not _is_snapshot_id(transport.get("phase")) or StringName(transport.get("phase")) not in [SUPPLY_MOVING, SUPPLY_WAITING_ROUTE, SUPPLY_WAITING_CAPACITY, SUPPLY_COMPLETED]
			or typeof(transport.get("deposited")) != TYPE_BOOL
			or not _is_snapshot_int(transport.get("last_checkpoint_elapsed_milliseconds"))
			or not transport.get("world_position", null) is Vector2i
			or not transport.get("route_segments", null) is Array
			or not transport.get("route_world_points", null) is Array
		):
			return false
		var phase := StringName(transport.get("phase"))
		var elapsed := int(transport.get("elapsed_milliseconds"))
		var total := int(transport.get("total_milliseconds"))
		if int(transport.get("last_checkpoint_elapsed_milliseconds")) < 0 or int(transport.get("last_checkpoint_elapsed_milliseconds")) > elapsed:
			return false
		if bool(transport.get("deposited")) != (phase == SUPPLY_COMPLETED):
			return false
		var route_segments: Array = Array(transport.get("route_segments", []))
		var route_points: Array = Array(transport.get("route_world_points", []))
		if route_segments.is_empty() or route_points.size() < 2:
			return false
		for route_point in route_points:
			# Check the concrete coordinate type before converting/comparing it. A
			# malformed middle point must reject a snapshot, never reach Vector2()
			# and turn an invalid save into a script error.
			if not route_point is Vector2i:
				return false
		var expected_points: Array = []
		var previous_target := &""
		var route_tokens: Array[String] = []
		for segment_value in route_segments:
			if not segment_value is Dictionary:
				return false
			var endpoints := _supply_segment_endpoints(Dictionary(segment_value), roads)
			if endpoints.is_empty() or (previous_target != &"" and StringName(endpoints.get("source_point_id", &"")) != previous_target):
				return false
			previous_target = StringName(endpoints.get("target_point_id", &""))
			route_tokens.append("%s:%s" % [String(endpoints.get("road_id", &"")), "f" if bool(Dictionary(segment_value).get("forward")) else "r"])
			var segment_points: Array = Array(endpoints.get("points", []))
			if expected_points.is_empty():
				expected_points.append_array(segment_points)
			else:
				if expected_points.back() != segment_points.front():
					return false
				expected_points.append_array(segment_points.slice(1))
		# A supply route is a durable physical promise. Rebuild its directed road
		# polyline exactly so a manipulated middle point cannot move cargo across a
		# river or shorten the route while preserving the endpoints.
		if StringName(transport.get("route_id", &"")) != StringName("%s%s" % [PATH_PREFIX, "|".join(route_tokens)]) or StringName(transport.get("source_point_id")) != StringName(_supply_segment_endpoints(Dictionary(route_segments.front()), roads).get("source_point_id", &"")) or StringName(transport.get("target_point_id")) != previous_target or route_points != expected_points:
			return false
		if phase in [SUPPLY_WAITING_CAPACITY, SUPPLY_COMPLETED] and elapsed != total:
			return false
		if phase in [SUPPLY_MOVING, SUPPLY_WAITING_ROUTE] and elapsed >= total:
			return false
		if phase == SUPPLY_WAITING_ROUTE and (not _is_snapshot_id(transport.get("blocked_road_id")) or not roads.has(StringName(transport.get("blocked_road_id")))):
			return false
		if phase != SUPPLY_WAITING_ROUTE and StringName(transport.get("blocked_road_id", &"")) != &"":
			return false
		source_totals[StringName(transport.get("source_point_id"))] = int(source_totals.get(StringName(transport.get("source_point_id")), 0)) + int(transport.get("amount"))
	if greatest_sequence >= int(next_sequence):
		return false
	# R0 deliberately has one finite Silverford stock.  Counting every durable
	# payload (including completed receipts) detects snapshots that claim both
	# the original location inventory and the same cargo at once.
	if int(source_totals.get(&"silverford_city", 0)) > 20:
		return false
	return true


func is_route_open(route_id: StringName) -> bool:
	if String(route_id).begins_with(PATH_PREFIX):
		for segment in _path_segments(route_id):
			if not is_route_open(StringName(segment.get("road_id", &""))):
				return false
		return not _path_segments(route_id).is_empty()
	var road := Dictionary(roads_by_id.get(route_id, {}))
	return not road.is_empty() and bool(road.get("built", false)) and StringName(road.get("state", &"")) == ROAD_OPEN


func first_unavailable_route_segment(
	route_id: StringName,
	route_segments: Array,
	route_world_points: Array,
	progress_milliseconds: int,
	total_milliseconds: int
) -> int:
	var resolved_segments := route_segments.duplicate(true)
	if resolved_segments.is_empty():
		resolved_segments = _path_segments(route_id)
	if resolved_segments.is_empty() and route_id != &"":
		resolved_segments = [{"road_id": route_id, "forward": true}]
	if resolved_segments.is_empty():
		return 0
	var total_length := 0.0
	for point_index in range(1, route_world_points.size()):
		total_length += Vector2(route_world_points[point_index - 1]).distance_to(Vector2(route_world_points[point_index]))
	var progressed_length := total_length * clampf(
		float(progress_milliseconds) / float(maxi(total_milliseconds, 1)), 0.0, 1.0
	)
	var current_segment_index := 0
	var consumed_length := 0.0
	for segment_index in range(resolved_segments.size()):
		var segment: Dictionary = Dictionary(resolved_segments[segment_index])
		var segment_points: Array = _route_segment_world_points(segment)
		var segment_length := 0.0
		for point_index in range(1, segment_points.size()):
			segment_length += Vector2(segment_points[point_index - 1]).distance_to(Vector2(segment_points[point_index]))
		consumed_length += segment_length
		if progressed_length < consumed_length - 0.0001:
			current_segment_index = segment_index
			break
		current_segment_index = mini(segment_index + 1, resolved_segments.size() - 1)
	for segment_index in range(current_segment_index, resolved_segments.size()):
		if not is_route_open(StringName(Dictionary(resolved_segments[segment_index]).get("road_id", &""))):
			return segment_index
	return -1


func validate_runtime_route(source_point_id: StringName, target_point_id: StringName, route_id: StringName, route_world_points: Array) -> Dictionary:
	if String(route_id).begins_with(PATH_PREFIX):
		return _validate_runtime_path(source_point_id, target_point_id, route_id, route_world_points)
	var road := Dictionary(roads_by_id.get(route_id, {}))
	if road.is_empty():
		return {"valid": false, "error_id": &"UNKNOWN_ROAD", "error": "该道路不存在"}
	if not is_route_open(route_id):
		return {"valid": false, "error_id": &"ROAD_DAMAGED", "error": "该道路尚未完工或已损坏"}
	if source_point_id == target_point_id:
		return {"valid": false, "error_id": &"ILLEGAL_ENDPOINT", "error": "道路不连接当前驻点与目标驻点"}
	var forward := (
		StringName(road.get("source_point_id", &"")) == source_point_id
		and StringName(road.get("target_point_id", &"")) == target_point_id
		and route_world_points == Array(road.get("route_world_points", []))
	)
	var reverse_points := Array(road.get("route_world_points", [])).duplicate(true)
	reverse_points.reverse()
	var reverse := (
		StringName(road.get("target_point_id", &"")) == source_point_id
		and StringName(road.get("source_point_id", &"")) == target_point_id
		and route_world_points == reverse_points
	)
	if not forward and not reverse:
		return {"valid": false, "error_id": &"ILLEGAL_ENDPOINT", "error": "道路不连接当前驻点与目标驻点"}
	var traversed := road.duplicate(true)
	if reverse:
		traversed.source_point_id = source_point_id
		traversed.target_point_id = target_point_id
		traversed.route_world_points = reverse_points
	traversed.segment_ids = [{"road_id": route_id, "forward": not reverse}]
	return {"valid": true, "error_id": &"", "error": "", "route": traversed}


func runtime_route_duration_milliseconds(route_id: StringName) -> int:
	if String(route_id).begins_with(PATH_PREFIX):
		return _path_duration_milliseconds(_path_world_points(route_id))
	var road := Dictionary(roads_by_id.get(route_id, {}))
	var points: Array = road.get("route_world_points", [])
	var length := 0.0
	for index in range(1, points.size()):
		length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	return maxi(6000, ceili(length * 20.0))


func plan_runtime_path(source_point_id: StringName, target_point_id: StringName, preferred_world_points: Array = [], required_road_id: StringName = &"") -> Dictionary:
	if source_point_id == &"" or target_point_id == &"" or source_point_id == target_point_id:
		return {"valid": false, "error": "起点和目标必须是不同的合法据点"}
	# A route choice is an explicit physical-road requirement, not a best-effort
	# cursor-proximity hint.  Resolve both directions through the same open-road
	# graph, then choose the shorter lawful composition.  This keeps persistence
	# on real road ids/directions and never silently substitutes another road.
	if required_road_id != &"":
		var required_road := Dictionary(roads_by_id.get(required_road_id, {}))
		if required_road.is_empty() or not bool(required_road.get("built", false)):
			return {"valid": false, "error": "指定道路尚未完成"}
		if StringName(required_road.get("state", &"")) != ROAD_OPEN:
			return {"valid": false, "error": "指定道路当前不可通行"}
		var required_points: Array = Array(required_road.get("route_world_points", []))
		if required_points.size() < 2:
			return {"valid": false, "error": "指定道路几何无效"}
		var candidates: Array[Dictionary] = []
		for forward in [true, false]:
			var entry_id := StringName(required_road.get("source_point_id", &"")) if forward else StringName(required_road.get("target_point_id", &""))
			var exit_id := StringName(required_road.get("target_point_id", &"")) if forward else StringName(required_road.get("source_point_id", &""))
			var before := {"valid": true, "segments": [], "points": [required_points.front()]} if source_point_id == entry_id else plan_runtime_path(source_point_id, entry_id)
			var after := {"valid": true, "segments": [], "points": [required_points.back()]} if exit_id == target_point_id else plan_runtime_path(exit_id, target_point_id)
			if not bool(before.get("valid", false)) or not bool(after.get("valid", false)):
				continue
			var segments: Array = Array(before.get("segments", [])).duplicate(true)
			segments.append({"road_id": required_road_id, "forward": forward})
			segments.append_array(Array(after.get("segments", [])))
			var points := _path_world_points_from_segments(segments)
			if points.size() < 2:
				continue
			candidates.append({"valid": true, "route_id": _path_id(segments), "segments": segments, "points": points, "duration_milliseconds": _path_duration_milliseconds(points)})
		if candidates.is_empty():
			return {"valid": false, "error": "指定道路无法连接当前起点与目标"}
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("duration_milliseconds", 0)) < int(right.get("duration_milliseconds", 0)) or (int(left.get("duration_milliseconds", 0)) == int(right.get("duration_milliseconds", 0)) and String(left.get("route_id", &"")) < String(right.get("route_id", &""))))
		return candidates.front()
	var frontier: Array[Dictionary] = [{"point_id": source_point_id, "segments": [], "cost": 0.0}]
	var best_cost_by_point: Dictionary = {source_point_id: 0.0}
	while not frontier.is_empty():
		var cheapest_index := 0
		for frontier_index in range(1, frontier.size()):
			if float(frontier[frontier_index].get("cost", INF)) < float(frontier[cheapest_index].get("cost", INF)):
				cheapest_index = frontier_index
		var current: Dictionary = frontier.pop_at(cheapest_index)
		var current_point := StringName(current.get("point_id", &""))
		var current_cost := float(current.get("cost", INF))
		if current_cost > float(best_cost_by_point.get(current_point, INF)) + 0.0001:
			continue
		if current_point == target_point_id:
			var segments: Array = current.get("segments", [])
			var route_id := _path_id(segments)
			var points := _path_world_points_from_segments(segments)
			return {"valid": true, "route_id": route_id, "segments": segments, "points": points, "duration_milliseconds": _path_duration_milliseconds(points)}
		for road_value in roads_by_id.values():
			var road: Dictionary = road_value
			if not bool(road.get("built", false)) or StringName(road.get("state", &"")) != ROAD_OPEN:
				continue
			var next_point := &""
			var forward := true
			if StringName(road.get("source_point_id", &"")) == current_point:
				next_point = StringName(road.get("target_point_id", &""))
			elif StringName(road.get("target_point_id", &"")) == current_point:
				next_point = StringName(road.get("source_point_id", &""))
				forward = false
			if next_point == &"":
				continue
			var next_cost := current_cost + _road_traversal_cost(road, forward, preferred_world_points)
			if next_cost >= float(best_cost_by_point.get(next_point, INF)) - 0.0001:
				continue
			var next_segments: Array = Array(current.get("segments", [])).duplicate(true)
			next_segments.append({"road_id": StringName(road.get("road_id", &"")), "forward": forward})
			best_cost_by_point[next_point] = next_cost
			frontier.append({"point_id": next_point, "segments": next_segments, "cost": next_cost})
	return {"valid": false, "error": "没有连通的已完工道路路径"}


func preview_supply_transport(source_point_id: StringName, target_point_id: StringName) -> Dictionary:
	var amount := maxi(int(supply_inventory_by_point_id.get(source_point_id, 0)), 0)
	if amount <= 0:
		return {"valid": false, "error": "该地点没有可运回的粮草"}
	var plan := plan_runtime_path(source_point_id, target_point_id)
	if not bool(plan.get("valid", false)):
		return {"valid": false, "error": str(plan.get("error", "没有可通行的运输道路"))}
	return {
		"valid": true,
		"source_point_id": source_point_id,
		"target_point_id": target_point_id,
		"amount": amount,
		"route_id": StringName(plan.get("route_id", &"")),
		"route_segments": Array(plan.get("segments", [])).duplicate(true),
		"route_world_points": Array(plan.get("points", [])).duplicate(true),
		"duration_milliseconds": int(plan.get("duration_milliseconds", 0)),
	}


func get_stationed_reinforcements(point_id: StringName) -> int:
	return maxi(int(stationed_reinforcements_by_point_id.get(point_id, 0)), 0)


func consume_stationed_reinforcements(point_id: StringName, amount: int) -> bool:
	if point_id == &"" or amount <= 0 or amount > get_stationed_reinforcements(point_id):
		return false
	stationed_reinforcements_by_point_id[point_id] = get_stationed_reinforcements(point_id) - amount
	return true


func begin_supply_transport(source_point_id: StringName, target_point_id: StringName) -> Dictionary:
	var preview := preview_supply_transport(source_point_id, target_point_id)
	if not bool(preview.get("valid", false)):
		return {}
	var amount := int(preview.get("amount", 0))
	if amount <= 0:
		return {}
	var transport_id := StringName("supply.%06d" % next_supply_transport_sequence)
	next_supply_transport_sequence += 1
	supply_inventory_by_point_id[source_point_id] = maxi(int(supply_inventory_by_point_id.get(source_point_id, 0)) - amount, 0)
	var points: Array = Array(preview.get("route_world_points", [])).duplicate(true)
	supply_transports_by_id[transport_id] = {
		"transport_id": transport_id,
		"source_point_id": source_point_id,
		"target_point_id": target_point_id,
		"amount": amount,
		"route_id": StringName(preview.get("route_id", &"")),
		"route_segments": Array(preview.get("route_segments", [])).duplicate(true),
		"route_world_points": points,
		"total_milliseconds": maxi(int(preview.get("duration_milliseconds", 0)), 1),
		"elapsed_milliseconds": 0,
		"phase": SUPPLY_MOVING,
		"world_position": Vector2i(points.front()),
		"blocked_road_id": &"",
		"deposited": false,
		"last_checkpoint_elapsed_milliseconds": 0,
	}
	return Dictionary(supply_transports_by_id[transport_id]).duplicate(true)


func get_supply_transport(transport_id: StringName) -> Dictionary:
	return Dictionary(supply_transports_by_id.get(transport_id, {})).duplicate(true)


func complete_supply_transport(transport_id: StringName) -> bool:
	var transport := Dictionary(supply_transports_by_id.get(transport_id, {}))
	if transport.is_empty() or StringName(transport.get("phase", &"")) not in [SUPPLY_WAITING_CAPACITY, SUPPLY_MOVING] or int(transport.get("elapsed_milliseconds", 0)) < int(transport.get("total_milliseconds", 0)) or bool(transport.get("deposited", false)):
		return false
	transport.phase = SUPPLY_COMPLETED
	transport.deposited = true
	transport.blocked_road_id = &""
	transport.world_position = _point_position(StringName(transport.get("target_point_id", &"")))
	supply_transports_by_id[transport_id] = transport
	_supply_checkpoint_required = true
	return true


func mark_supply_transport_waiting_capacity(transport_id: StringName) -> bool:
	var transport := Dictionary(supply_transports_by_id.get(transport_id, {}))
	if transport.is_empty() or StringName(transport.get("phase", &"")) == SUPPLY_COMPLETED:
		return false
	# A full warehouse is a durable state transition, not a per-frame event.  The
	# controller retries the same payload after capacity changes, so repeatedly
	# asking it to checkpoint while nothing changed would create unbounded saves.
	if StringName(transport.get("phase", &"")) == SUPPLY_WAITING_CAPACITY and StringName(transport.get("blocked_road_id", &"")) == &"":
		return false
	transport.phase = SUPPLY_WAITING_CAPACITY
	transport.blocked_road_id = &""
	supply_transports_by_id[transport_id] = transport
	_supply_checkpoint_required = true
	return true


func consume_supply_checkpoint_required() -> bool:
	var required := _supply_checkpoint_required
	_supply_checkpoint_required = false
	return required


func _supply_route_segment_index_at_progress(route_segments: Array, route_points: Array, elapsed_milliseconds: int, total_milliseconds: int) -> int:
	if route_segments.is_empty() or route_points.size() < 2:
		return 0
	var total_length := _points_length(route_points)
	if total_length <= 0.001:
		return 0
	var travelled_length := total_length * clampf(float(elapsed_milliseconds) / maxf(float(total_milliseconds), 1.0), 0.0, 1.0)
	var consumed_length := 0.0
	for index in range(route_segments.size()):
		var segment_length := _points_length(_route_segment_world_points(Dictionary(route_segments[index])))
		if travelled_length <= consumed_length + segment_length + 0.001:
			return index
		consumed_length += segment_length
	return route_segments.size() - 1


func _advance_supply_transports(delta_milliseconds: int, repaired_road_open_offsets: Dictionary = {}) -> Array[StringName]:
	var ready_to_unload: Array[StringName] = []
	var transport_ids: Array = supply_transports_by_id.keys()
	transport_ids.sort()
	for transport_id_value in transport_ids:
		var transport_id := StringName(transport_id_value)
		var transport := Dictionary(supply_transports_by_id[transport_id])
		var phase := StringName(transport.get("phase", &""))
		if phase == SUPPLY_COMPLETED:
			continue
		var route_segments: Array = Array(transport.get("route_segments", []))
		var route_points: Array = Array(transport.get("route_world_points", []))
		var total := maxi(int(transport.get("total_milliseconds", 0)), 1)
		var elapsed := clampi(int(transport.get("elapsed_milliseconds", 0)), 0, total)
		if elapsed < total:
			var unavailable := first_unavailable_route_segment(
				StringName(transport.get("route_id", &"")), route_segments, route_points, elapsed, total
			)
			if unavailable >= 0:
				if StringName(transport.get("phase", &"")) != SUPPLY_WAITING_ROUTE:
					_supply_checkpoint_required = true
				transport.phase = SUPPLY_WAITING_ROUTE
				transport.blocked_road_id = StringName(Dictionary(route_segments[unavailable]).get("road_id", &""))
				supply_transports_by_id[transport_id] = transport
				continue
			transport.phase = SUPPLY_MOVING
			transport.blocked_road_id = &""
			# Roads repaired during this step become usable only after their real
			# work-completion offset.  Convoys retain the same clock as projects;
			# they never receive the portion of the frame that the bridge was still
			# damaged.  This also keeps one large step equivalent to split steps.
			var deferred_milliseconds := 0
			var current_segment_index := _supply_route_segment_index_at_progress(route_segments, route_points, elapsed, total)
			for segment_index in range(current_segment_index, route_segments.size()):
				var road_id := StringName(Dictionary(route_segments[segment_index]).get("road_id", &""))
				deferred_milliseconds = maxi(deferred_milliseconds, int(repaired_road_open_offsets.get(road_id, 0)))
			var usable_milliseconds := maxi(delta_milliseconds - clampi(deferred_milliseconds, 0, delta_milliseconds), 0)
			elapsed = mini(elapsed + usable_milliseconds, total)
			transport.elapsed_milliseconds = elapsed
			transport.world_position = Vector2i(_position_along_points(route_points, float(elapsed) / float(total)))
			if elapsed >= int(transport.get("last_checkpoint_elapsed_milliseconds", 0)) + 1000 or elapsed >= total:
				transport.last_checkpoint_elapsed_milliseconds = elapsed
				_supply_checkpoint_required = true
		if elapsed >= total:
			transport.world_position = _point_position(StringName(transport.get("target_point_id", &"")))
			# This phase means the physical convoy arrived but its shared-stock
			# transaction has not committed. The controller may retry after capacity
			# becomes available without duplicating the payload.
			if StringName(transport.get("phase", &"")) != SUPPLY_WAITING_CAPACITY:
				transport.phase = SUPPLY_MOVING
			ready_to_unload.append(transport_id)
		supply_transports_by_id[transport_id] = transport
	return ready_to_unload


## Plans from a marching army's exact position without inventing a permanent
## node. The first connector is a clipped portion of the already-confirmed
## physical road; only after reaching one of that road's endpoints may normal
## network search continue.
func plan_runtime_path_from_progress(route_segments: Array, total_milliseconds: int, progress_milliseconds: int, target_point_id: StringName) -> Dictionary:
	if route_segments.is_empty() or total_milliseconds <= 0 or target_point_id == &"":
		return {"valid": false, "error": "缺少可定位的原军令路径"}
	var ordered_segments: Array[Dictionary] = []
	var lengths: Array[float] = []
	var total_length := 0.0
	for segment_value in route_segments:
		var segment: Dictionary = Dictionary(segment_value)
		var road := Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {}))
		# A damaged *future* segment is exactly why callers use this method.  We
		# still need its geometry to locate the marching army, but only the
		# physical segment under the army may serve as the temporary connector.
		if road.is_empty():
			return {"valid": false, "error": "军令引用的道路不存在"}
		var points: Array = _route_segment_world_points(segment)
		var length := _points_length(points)
		if points.size() < 2 or length <= 0.001:
			return {"valid": false, "error": "军令路段几何无效"}
		ordered_segments.append({
			"road_id": StringName(segment.get("road_id", &"")),
			"forward": bool(segment.get("forward", false)),
			"points": points,
			"source_point_id": StringName(segment.get("source_point_id", StringName(road.get("source_point_id", &"")) if bool(segment.get("forward", false)) else StringName(road.get("target_point_id", &"")))),
			"target_point_id": StringName(segment.get("target_point_id", StringName(road.get("target_point_id", &"")) if bool(segment.get("forward", false)) else StringName(road.get("source_point_id", &"")))),
		})
		lengths.append(length)
		total_length += length
	var travelled := total_length * clampf(float(progress_milliseconds) / float(total_milliseconds), 0.0, 1.0)
	var consumed := 0.0
	for segment_index in range(ordered_segments.size()):
		var segment: Dictionary = ordered_segments[segment_index]
		var length := lengths[segment_index]
		if travelled > consumed + length and segment_index < ordered_segments.size() - 1:
			consumed += length
			continue
		var local_progress := clampf((travelled - consumed) / length, 0.0, 1.0)
		var current_position := _position_along_points(Array(segment.points), local_progress)
		if not is_route_open(StringName(segment.get("road_id", &""))):
			return {"valid": false, "error": "军队当前位置所在道路不可通行", "current_position": Vector2i(current_position), "origin_segment_index": segment_index}
		var candidates: Array[Dictionary] = []
		for endpoint_key in ["source_point_id", "target_point_id"]:
			var endpoint_id := StringName(segment.get(endpoint_key, &""))
			if endpoint_id == &"":
				continue
			var connector := _clip_points_to_endpoint(Array(segment.points), local_progress, endpoint_key == "target_point_id")
			# `plan_runtime_path` rightly rejects same-point march orders, but an
			# endpoint can itself be the lawful safe garrison for this temporary
			# transfer.  In that case the clipped connector is the complete path.
			var onward := {"valid": true, "route_id": &"", "segments": [], "points": [connector.back()]} if endpoint_id == target_point_id else plan_runtime_path(endpoint_id, target_point_id)
			if not bool(onward.get("valid", false)):
				continue
			var points := connector.duplicate(true)
			var onward_points: Array = Array(onward.get("points", []))
			if not points.is_empty() and not onward_points.is_empty():
				onward_points.pop_front()
			points.append_array(onward_points)
			var duration := maxi(1, ceili(_points_length(points) * 20.0))
			# Persist the physical road that the clipped connector belongs to.  Its
			# geometry is deliberately carried in `points`; the `partial` marker
			# prevents a later reader from mistaking it for a newly-created road.
			var transfer_segments: Array = [{
				"road_id": StringName(segment.get("road_id", &"")),
				"forward": bool(segment.get("forward", false)) if endpoint_key == "target_point_id" else not bool(segment.get("forward", false)),
				"partial": true,
				"route_world_points": connector.duplicate(true),
				"source_point_id": &"",
				"target_point_id": endpoint_id,
			}]
			for onward_segment_value in Array(onward.get("segments", [])):
				var onward_segment := Dictionary(onward_segment_value).duplicate(true)
				onward_segment.route_world_points = _route_segment_world_points(onward_segment)
				var onward_road := Dictionary(roads_by_id.get(StringName(onward_segment.get("road_id", &"")), {}))
				onward_segment.source_point_id = StringName(onward_road.get("source_point_id", &"")) if bool(onward_segment.get("forward", false)) else StringName(onward_road.get("target_point_id", &""))
				onward_segment.target_point_id = StringName(onward_road.get("target_point_id", &"")) if bool(onward_segment.get("forward", false)) else StringName(onward_road.get("source_point_id", &""))
				transfer_segments.append(onward_segment)
			candidates.append({"valid": true, "route_id": StringName(onward.get("route_id", &"")), "segments": transfer_segments, "points": points, "duration_milliseconds": duration, "current_position": Vector2i(current_position), "origin_segment_index": segment_index})
		if candidates.is_empty():
			return {"valid": false, "error": "没有从当前位置可达的友方驻点", "current_position": Vector2i(current_position), "origin_segment_index": segment_index}
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.duration_milliseconds) < int(right.duration_milliseconds) or (int(left.duration_milliseconds) == int(right.duration_milliseconds) and String(left.route_id) < String(right.route_id)))
		return candidates.front()
	return {"valid": false, "error": "军令进度不在有效路段内"}


## Temporary safe-camp paths may begin in the middle of a physical road.  In
## that case the clipped geometry is persisted on the segment so availability,
## movement and cold recovery all measure the same path instead of expanding it
## back to the full road.
func _route_segment_world_points(segment: Dictionary) -> Array:
	var embedded = segment.get("route_world_points", null)
	if embedded is Array and Array(embedded).size() >= 2:
		return Array(embedded).duplicate(true)
	var points: Array = Array(Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {})).get("route_world_points", [])).duplicate(true)
	if not bool(segment.get("forward", false)):
		points.reverse()
	return points


func _points_length(points: Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	return length


func _clip_points_to_endpoint(points: Array, progress: float, toward_end: bool) -> Array:
	if points.size() < 2:
		return points.duplicate(true)
	var total_length := _points_length(points)
	var remaining_length := total_length * clampf(progress, 0.0, 1.0)
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var segment_length := start.distance_to(end)
		if segment_length <= 0.001:
			continue
		if remaining_length <= segment_length or index == points.size() - 1:
			var position := Vector2i(start.lerp(end, clampf(remaining_length / segment_length, 0.0, 1.0)))
			var result: Array = [position]
			if toward_end:
				for point_index in range(index, points.size()):
					if Vector2(result.back()) != Vector2(points[point_index]):
						result.append(points[point_index])
			else:
				for point_index in range(index - 1, -1, -1):
					if Vector2(result.back()) != Vector2(points[point_index]):
						result.append(points[point_index])
			return result
		remaining_length -= segment_length
	return [Vector2i(points.back())]


func _road_traversal_cost(road: Dictionary, forward: bool, preferred_world_points: Array) -> float:
	var points: Array = Array(road.get("route_world_points", [])).duplicate(true)
	if not forward:
		points.reverse()
	var length := 0.0
	for point_index in range(1, points.size()):
		length += Vector2(points[point_index - 1]).distance_to(Vector2(points[point_index]))
	if preferred_world_points.size() < 2:
		return length
	var draw_penalty := 0.0
	for point in points:
		var nearest := INF
		for draw_index in range(1, preferred_world_points.size()):
			nearest = minf(nearest, _distance_to_segment(Vector2(point), Vector2(preferred_world_points[draw_index - 1]), Vector2(preferred_world_points[draw_index])))
		draw_penalty += nearest
	return length + draw_penalty * 12.0 / float(maxi(points.size(), 1))


func _path_id(segments: Array) -> StringName:
	if segments.size() == 1:
		return StringName(Dictionary(segments.front()).get("road_id", &""))
	var tokens: Array[String] = []
	for segment_value in segments:
		var segment: Dictionary = segment_value
		tokens.append("%s:%s" % [String(segment.get("road_id", &"")), "f" if bool(segment.get("forward", false)) else "r"])
	return StringName(PATH_PREFIX + "|".join(tokens))


func _path_segments(route_id: StringName) -> Array[Dictionary]:
	if not String(route_id).begins_with(PATH_PREFIX):
		return []
	var result: Array[Dictionary] = []
	for token in String(route_id).trim_prefix(PATH_PREFIX).split("|", false):
		var parts := token.rsplit(":", true, 1)
		if parts.size() != 2 or not roads_by_id.has(StringName(parts[0])) or parts[1] not in ["f", "r"]:
			return []
		result.append({"road_id": StringName(parts[0]), "forward": parts[1] == "f"})
	return result


func _path_world_points(route_id: StringName) -> Array:
	return _path_world_points_from_segments(_path_segments(route_id))


func _path_world_points_from_segments(segments: Array) -> Array:
	var result: Array = []
	for segment_value in segments:
		var segment: Dictionary = segment_value
		var points: Array = Array(Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {})).get("route_world_points", [])).duplicate(true)
		if not bool(segment.get("forward", false)):
			points.reverse()
		if not result.is_empty() and (points.is_empty() or Vector2(result.back()) != Vector2(points.front())):
			return []
		if not result.is_empty() and not points.is_empty():
			points.pop_front()
		result.append_array(points)
	return result


func _path_duration_milliseconds(points: Array) -> int:
	var length := 0.0
	for index in range(1, points.size()):
		length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	return maxi(6000, ceili(length * 20.0))


func _validate_runtime_path(source_point_id: StringName, target_point_id: StringName, route_id: StringName, route_world_points: Array) -> Dictionary:
	var segments := _path_segments(route_id)
	if segments.size() < 2:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径缺少连续道路段"}
	var expected_point_id := source_point_id
	for segment_value in segments:
		var segment: Dictionary = segment_value
		var road: Dictionary = Dictionary(roads_by_id.get(StringName(segment.get("road_id", &"")), {}))
		var segment_start := StringName(road.get("source_point_id", &"")) if bool(segment.get("forward", false)) else StringName(road.get("target_point_id", &""))
		var segment_end := StringName(road.get("target_point_id", &"")) if bool(segment.get("forward", false)) else StringName(road.get("source_point_id", &""))
		if road.is_empty() or segment_start != expected_point_id:
			return {"valid": false, "error_id": &"PATH_DISCONNECTED", "error": "军令路径包含未连接的道路段"}
		expected_point_id = segment_end
	if expected_point_id != target_point_id:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径没有抵达指定目标"}
	var points := _path_world_points_from_segments(segments)
	if points.is_empty() or points != route_world_points:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径与已确认路段不一致"}
	var first: Dictionary = Dictionary(segments.front())
	var last: Dictionary = Dictionary(segments.back())
	var first_road := Dictionary(roads_by_id.get(StringName(first.road_id), {}))
	var last_road := Dictionary(roads_by_id.get(StringName(last.road_id), {}))
	var actual_source := StringName(first_road.get("source_point_id", &"")) if bool(first.forward) else StringName(first_road.get("target_point_id", &""))
	var actual_target := StringName(last_road.get("target_point_id", &"")) if bool(last.forward) else StringName(last_road.get("source_point_id", &""))
	if actual_source != source_point_id or actual_target != target_point_id:
		return {"valid": false, "error_id": &"PATH_MISMATCH", "error": "军令路径端点与命令不一致"}
	if not is_route_open(route_id):
		return {"valid": false, "error_id": &"ROAD_DAMAGED", "error": "路径道路不再可通行"}
	return {"valid": true, "error_id": &"", "error": "", "route": {"route_id": route_id, "route_world_points": points, "segment_ids": segments}}


func _path_draw_score(drawn: Array, path: Array) -> float:
	if drawn.is_empty():
		return 0.0
	if path.size() < 2:
		return INF
	var total := 0.0
	for value in drawn:
		var nearest := INF
		for index in range(1, path.size()):
			nearest = minf(nearest, _distance_to_segment(Vector2(value), Vector2(path[index - 1]), Vector2(path[index])))
		total += nearest
	return total / float(drawn.size()) + Vector2(drawn.front()).distance_to(Vector2(path.front())) + Vector2(drawn.back()).distance_to(Vector2(path.back()))


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var squared := segment.length_squared()
	if squared <= 0.0001:
		return point.distance_to(start)
	return point.distance_to(start + segment * clampf((point - start).dot(segment) / squared, 0.0, 1.0))


func _first_timed_contact_milliseconds(first: Array, second: Array, distance: float) -> float:
	var first_contact := INF
	for first_value in first:
		var first_segment: Dictionary = Dictionary(first_value)
		var first_start_time := float(first_segment.get("start_milliseconds", first_segment.get("start_offset_milliseconds", 0.0)))
		var first_end_time := float(first_segment.get("end_milliseconds", first_segment.get("end_offset_milliseconds", first_start_time)))
		for second_value in second:
			var second_segment: Dictionary = Dictionary(second_value)
			var second_start_time := float(second_segment.get("start_milliseconds", second_segment.get("start_offset_milliseconds", 0.0)))
			var second_end_time := float(second_segment.get("end_milliseconds", second_segment.get("end_offset_milliseconds", second_start_time)))
			var overlap_start := maxf(first_start_time, second_start_time)
			var overlap_end := minf(first_end_time, second_end_time)
			if overlap_end < overlap_start - 0.0001:
				continue
			var first_duration := maxf(first_end_time - first_start_time, 0.0001)
			var second_duration := maxf(second_end_time - second_start_time, 0.0001)
			var first_from := Vector2(first_segment.get("from", Vector2.ZERO))
			var first_to := Vector2(first_segment.get("to", first_from))
			var second_from := Vector2(second_segment.get("from", Vector2.ZERO))
			var second_to := Vector2(second_segment.get("to", second_from))
			var first_at_start := first_from.lerp(first_to, clampf((overlap_start - first_start_time) / first_duration, 0.0, 1.0))
			var first_at_end := first_from.lerp(first_to, clampf((overlap_end - first_start_time) / first_duration, 0.0, 1.0))
			var second_at_start := second_from.lerp(second_to, clampf((overlap_start - second_start_time) / second_duration, 0.0, 1.0))
			var second_at_end := second_from.lerp(second_to, clampf((overlap_end - second_start_time) / second_duration, 0.0, 1.0))
			var relative_start := first_at_start - second_at_start
			var relative_delta := (first_at_end - second_at_end) - relative_start
			var radius_squared := distance * distance
			var c := relative_start.length_squared() - radius_squared
			if c <= 0.0:
				first_contact = minf(first_contact, overlap_start)
				continue
			var a := relative_delta.length_squared()
			if a <= 0.000001:
				continue
			var b := 2.0 * relative_start.dot(relative_delta)
			var discriminant := b * b - 4.0 * a * c
			if discriminant < 0.0:
				continue
			var entry_ratio := (-b - sqrt(discriminant)) / (2.0 * a)
			if entry_ratio >= -0.0001 and entry_ratio <= 1.0001:
				first_contact = minf(first_contact, lerpf(overlap_start, overlap_end, clampf(entry_ratio, 0.0, 1.0)))
	return first_contact


## Shared read-only contact helpers for controller-owned encounter summaries.
## FieldTacticsState already uses these timed traces for specialists and guards;
## exposing the same calculation prevents a macro patrol report from placing an
## encounter at the end of a frame instead of at the actual contact instant.
func first_timed_contact_milliseconds(first: Array, second: Array, distance: float) -> float:
	return _first_timed_contact_milliseconds(first, second, distance)


func _timed_trace_position_at(trace: Array, time_milliseconds: float) -> Vector2:
	for segment_value in trace:
		var segment: Dictionary = Dictionary(segment_value)
		var start_time := float(segment.get("start_milliseconds", segment.get("start_offset_milliseconds", 0.0)))
		var end_time := float(segment.get("end_milliseconds", segment.get("end_offset_milliseconds", start_time)))
		if time_milliseconds < start_time - 0.0001 or time_milliseconds > end_time + 0.0001:
			continue
		var from := Vector2(segment.get("from", Vector2.ZERO))
		var to := Vector2(segment.get("to", from))
		return from.lerp(to, clampf((time_milliseconds - start_time) / maxf(end_time - start_time, 0.0001), 0.0, 1.0))
	return Vector2(Dictionary(trace.back()).get("to", Vector2.ZERO)) if not trace.is_empty() else Vector2.ZERO


func timed_trace_position_at(trace: Array, time_milliseconds: float) -> Vector2:
	return _timed_trace_position_at(trace, time_milliseconds)


func position_has_terrain_kind(position: Vector2, terrain_kind: StringName) -> bool:
	for region_value in terrain_regions:
		var region: Dictionary = Dictionary(region_value)
		if StringName(region.get("kind", &"")) == terrain_kind and Rect2i(region.get("rect", Rect2i())).has_point(Vector2i(position)):
			return true
	return false


func apply_patrol_encounter(patrol_id: StringName, army_ids: Array[StringName], patrol_losses: int, ambush_army_ids: Array[StringName], summary: Dictionary) -> Dictionary:
	var patrol: Dictionary = Dictionary(patrols_by_id.get(patrol_id, {}))
	if patrol.is_empty() or army_ids.is_empty() or patrol_losses < 0 or patrol_losses > int(patrol.get("strength", 0)):
		return {}
	var resolved_ids: Array = Array(patrol.get("resolved_army_ids", [])).duplicate()
	for army_id in army_ids:
		if army_id == &"" or army_id in resolved_ids:
			return {}
		resolved_ids.append(army_id)
	var consumed_ambush_ids: Array = Array(patrol.get("ambush_consumed_army_ids", [])).duplicate()
	for army_id in ambush_army_ids:
		if army_id not in army_ids or army_id in consumed_ambush_ids:
			return {}
		consumed_ambush_ids.append(army_id)
	patrol.strength = int(patrol.get("strength", 0)) - patrol_losses
	patrol.resolved_army_ids = resolved_ids
	patrol.ambush_consumed_army_ids = consumed_ambush_ids
	patrol.exposed = true
	patrol.last_engagement = summary.duplicate(true)
	patrols_by_id[patrol_id] = patrol
	intel_by_subject_id[patrol_id] = {
		"subject_id": patrol_id,
		"fog_state": FOG_VISIBLE,
		"last_known_point_id": StringName(patrol.get("current_point_id", &"")),
		"last_known_world_position": Vector2i(summary.get("world_position", patrol.get("world_position", Vector2i.ZERO))),
		"last_observed_milliseconds": world_milliseconds,
		"known_strength": int(patrol.strength),
	}
	return patrol.duplicate(true)


func damage_nearest_engineered_road(position: Vector2, radius: float, amount: int) -> StringName:
	var best_road_id := &""
	var best_distance := INF
	var road_ids := roads_by_id.keys()
	road_ids.sort()
	for road_id_value in road_ids:
		var road_id := StringName(road_id_value)
		var road: Dictionary = Dictionary(roads_by_id[road_id])
		if StringName(road.get("road_kind", &"")) == ROAD_MAIN or not bool(road.get("built", false)) or StringName(road.get("state", &"")) != ROAD_OPEN:
			continue
		var points: Array = Array(road.get("route_world_points", []))
		for index in range(1, points.size()):
			var distance := _distance_to_segment(position, Vector2(points[index - 1]), Vector2(points[index]))
			if distance < best_distance:
				best_distance = distance
				best_road_id = road_id
	if best_road_id != &"" and best_distance <= radius and damage_road(best_road_id, amount):
		return best_road_id
	return &""


func get_runtime_points() -> Dictionary:
	var points: Dictionary = {}
	for camp_value in camps_by_id.values():
		var camp: Dictionary = camp_value
		var point_id := StringName(camp.get("point_id", &""))
		if point_id == &"":
			continue
		points[point_id] = {
			"point_id": point_id,
			"display_name": String(camp.get("display_name", "工程驻点")),
			"world_position": Vector2(camp.get("world_position", _road_endpoint_position(StringName(camp.get("road_id", &""))))),
			"point_kind": &"FRIENDLY_GARRISON",
			# A finished project exposes a tactical camp, not a second city.  These
			# are presentation capabilities read from the authoritative Field state;
			# no UI selection is allowed to promote it into an inner-city owner.
			"location_role": &"ENGINEERED_GARRISON",
			"allows_inner_city_actions": false,
			"military_controller_faction_id": &"player",
		}
	return points


func advance_world(delta_milliseconds: int, guard_positions_by_army: Dictionary = {}, guard_traces_by_army: Dictionary = {}) -> Dictionary:
	if delta_milliseconds <= 0:
		return {}
	world_milliseconds += delta_milliseconds
	var completed: Array[StringName] = []
	var opened_road_ids: Array[StringName] = []
	var engagements: Array[Dictionary] = []
	var patrol_movements: Array[Dictionary] = []
	var arrived_invasion_ids: Array[StringName] = []
	var facility_events: Array[Dictionary] = []
	var specialist_movements: Dictionary = {}
	var specialist_project_ids: Dictionary = {}
	var specialist_action_work_milliseconds: Dictionary = {}
	var ready_specialist_action_ids: Array[StringName] = []
	var project_step_facts: Dictionary = {}
	var supply_ready_to_unload: Array[StringName] = []
	var repaired_road_open_offsets: Dictionary = {}
	# A repair may begin in the middle of this world step. Keep the unused part
	# of the step for its work progress so one long advance and split advances
	# produce identical durable state.
	var project_arrival_work_milliseconds: Dictionary = {}
	for specialist_id_value in specialists_by_id.keys():
		var moving_id := StringName(specialist_id_value)
		var moving := Dictionary(specialists_by_id[moving_id])
		if not bool(moving.get("alive", false)):
			# A specialist can be lost on the approach as well as while already
			# working.  Leaving a TRAVELING project live would make a later restore
			# look like a tower is still reachable and would hide the interruption.
			var lost_project_id := StringName(moving.get("project_id", &""))
			if projects_by_id.has(lost_project_id):
				var lost_project := Dictionary(projects_by_id[lost_project_id])
				if StringName(lost_project.get("phase", &"")) in [&"TRAVELING", &"BUILDING"]:
					lost_project.phase = &"INTERRUPTED"
					lost_project.interruption_reason = &"ENGINEER_LOST"
					projects_by_id[lost_project_id] = lost_project
			continue
		if StringName(moving.get("phase", &"")) != SPECIALIST_MOVING:
			continue
		var move_remaining_before := int(moving.get("move_remaining_milliseconds", 0))
		var move_elapsed_before := int(moving.get("move_elapsed_milliseconds", 0))
		var specialist_start_position := Vector2i(moving.get("world_position", Vector2i.ZERO))
		moving.move_elapsed_milliseconds = mini(int(moving.get("move_elapsed_milliseconds", 0)) + delta_milliseconds, int(moving.get("move_total_milliseconds", 0)))
		moving.move_remaining_milliseconds = maxi(int(moving.get("move_total_milliseconds", 0)) - int(moving.get("move_elapsed_milliseconds", 0)), 0)
		var move_progress := float(moving.get("move_elapsed_milliseconds", 0)) / maxf(float(moving.get("move_total_milliseconds", 1)), 1.0)
		moving.world_position = Vector2i(_position_along_points(
			Array(moving.get("move_route_world_points", [moving.get("move_start_position", Vector2i.ZERO), moving.get("target_world_position", Vector2i.ZERO)])),
			move_progress
		))
		if int(moving.move_remaining_milliseconds) == 0:
			moving.current_point_id = StringName(moving.target_point_id)
			moving.world_position = Vector2i(moving.get("target_world_position", Vector2i.ZERO))
			var action_stage := StringName(moving.get("action_stage", ACTION_NONE))
			if action_stage == ACTION_TRAVELING:
				moving.action_stage = ACTION_WORKING
				moving.phase = SPECIALIST_ACTING
				specialist_action_work_milliseconds[moving_id] = maxi(delta_milliseconds - move_remaining_before, 0)
			elif action_stage == ACTION_RETURNING:
				moving.action_stage = ACTION_READY_DEPOSIT
				moving.phase = SPECIALIST_ACTING
				ready_specialist_action_ids.append(moving_id)
			var active_project_id := StringName(moving.get("project_id", &""))
			var active_project := Dictionary(projects_by_id.get(active_project_id, {}))
			if StringName(active_project.get("phase", &"")) == &"TRAVELING" and StringName(active_project.get("project_kind", &"")) in [&"REPAIR", &"CONSTRUCTION", &"WATCHTOWER", PROJECT_FACILITY_REPAIR, PROJECT_FACILITY_UPGRADE]:
				active_project.phase = &"BUILDING"
				projects_by_id[active_project_id] = active_project
				project_arrival_work_milliseconds[active_project_id] = maxi(delta_milliseconds - move_remaining_before, 0)
				moving.phase = SPECIALIST_REPAIRING if StringName(active_project.get("project_kind", &"")) in [&"REPAIR", PROJECT_FACILITY_REPAIR] else SPECIALIST_BUILDING
			elif action_stage not in [ACTION_TRAVELING, ACTION_RETURNING]:
				moving.phase = SPECIALIST_IDLE
		specialists_by_id[moving_id] = moving
		var specialist_trace := _timed_route_movement_records(
			moving_id, Array(moving.get("move_route_world_points", [specialist_start_position, moving.get("world_position", specialist_start_position)])),
			move_elapsed_before, int(moving.get("move_elapsed_milliseconds", move_elapsed_before)),
			maxi(int(moving.get("move_total_milliseconds", 1)), 1), 0
		)
		var specialist_move_milliseconds := mini(move_remaining_before, delta_milliseconds)
		var arrived_project_id := StringName(moving.get("project_id", &""))
		var continues_as_project := int(project_arrival_work_milliseconds.get(arrived_project_id, 0)) > 0
		if specialist_trace.is_empty() or (specialist_move_milliseconds < delta_milliseconds and not continues_as_project):
			var final_position := Vector2(moving.get("world_position", specialist_start_position))
			specialist_trace.append({
				"from": final_position, "to": final_position,
				"start_offset_milliseconds": specialist_move_milliseconds,
				"end_offset_milliseconds": delta_milliseconds,
			})
		specialist_movements[moving_id] = specialist_trace
	for specialist_id_value in specialists_by_id.keys():
		var action_specialist_id := StringName(specialist_id_value)
		var action_specialist := Dictionary(specialists_by_id[action_specialist_id])
		if not bool(action_specialist.get("alive", false)) or StringName(action_specialist.get("phase", &"")) != SPECIALIST_ACTING or StringName(action_specialist.get("action_stage", &"")) != ACTION_WORKING:
			continue
		var work_milliseconds := int(specialist_action_work_milliseconds.get(action_specialist_id, delta_milliseconds))
		action_specialist.action_progress_milliseconds = mini(
			int(action_specialist.get("action_progress_milliseconds", 0)) + work_milliseconds,
			int(action_specialist.get("action_required_milliseconds", 0))
		)
		if int(action_specialist.action_progress_milliseconds) >= int(action_specialist.get("action_required_milliseconds", 0)):
			action_specialist.action_stage = ACTION_READY
			ready_specialist_action_ids.append(action_specialist_id)
		specialists_by_id[action_specialist_id] = action_specialist
	for project_id_value in projects_by_id.keys():
		var project_id := StringName(project_id_value)
		var project := Dictionary(projects_by_id[project_id])
		if StringName(project.get("phase", &"")) != &"BUILDING":
			continue
		var engineer := Dictionary(specialists_by_id.get(StringName(project.engineer_id), {}))
		if engineer.is_empty() or not bool(engineer.get("alive", false)):
			project.phase = &"INTERRUPTED"
			project.interruption_reason = &"ENGINEER_LOST"
			projects_by_id[project_id] = project
			continue
		var project_delta_milliseconds := int(project_arrival_work_milliseconds.get(project_id, delta_milliseconds))
		if project_delta_milliseconds <= 0:
			continue
		var progress_before := int(project.get("progress_milliseconds", 0))
		var work_start_offset := delta_milliseconds - project_delta_milliseconds
		var work_consumed := mini(project_delta_milliseconds, maxi(int(project.get("required_milliseconds", 0)) - progress_before, 0))
		var engineer_id := StringName(project.engineer_id)
		specialist_project_ids[engineer_id] = project_id
		project_step_facts[project_id] = {
			"progress_before": progress_before,
			"work_start_offset": work_start_offset,
			"work_consumed": work_consumed,
		}
		project.progress_milliseconds = mini(
			progress_before + project_delta_milliseconds,
			int(project.required_milliseconds)
		)
		if StringName(project.get("project_kind", &"")) == &"CONSTRUCTION":
			_update_engineer_construction_position(engineer, project)
			specialists_by_id[engineer_id] = engineer
			opened_road_ids.append_array(_open_completed_construction_segments(project_id, project))
		elif StringName(project.get("project_kind", &"")) in [&"WATCHTOWER", PROJECT_FACILITY_REPAIR, PROJECT_FACILITY_UPGRADE]:
			engineer.world_position = Vector2i(project.get("work_world_position", engineer.get("world_position", Vector2i.ZERO)))
			specialists_by_id[engineer_id] = engineer
		var construction_trace := _timed_project_work_records(
			engineer_id, project, progress_before, int(project.progress_milliseconds), work_start_offset
		)
		if construction_trace.is_empty():
			var work_position := Vector2(engineer.get("world_position", Vector2.ZERO))
			construction_trace.append({
				"from": work_position, "to": work_position,
				"start_offset_milliseconds": work_start_offset,
				"end_offset_milliseconds": work_start_offset + work_consumed,
			})
		if work_start_offset + work_consumed < delta_milliseconds:
			var final_work_position := Vector2(engineer.get("world_position", Vector2.ZERO))
			construction_trace.append({
				"from": final_work_position, "to": final_work_position,
				"start_offset_milliseconds": work_start_offset + work_consumed,
				"end_offset_milliseconds": delta_milliseconds,
			})
		var existing_trace: Array = Array(specialist_movements.get(engineer_id, []))
		existing_trace.append_array(construction_trace)
		specialist_movements[engineer_id] = existing_trace
		if int(project.progress_milliseconds) == int(project.required_milliseconds):
			project.phase = &"COMPLETE"
			if StringName(project.get("project_kind", &"")) == &"REPAIR":
				var repaired_road := Dictionary(roads_by_id.get(StringName(project.road_id), {}))
				if repaired_road.is_empty():
					project.phase = &"INTERRUPTED"
					projects_by_id[project_id] = project
					continue
				repaired_road.durability = int(repaired_road.max_durability)
				repaired_road.state = ROAD_OPEN
				roads_by_id[StringName(project.road_id)] = repaired_road
				repaired_road_open_offsets[StringName(project.road_id)] = work_start_offset + work_consumed
			elif StringName(project.get("project_kind", &"")) == &"CONSTRUCTION":
				opened_road_ids.append_array(_open_completed_construction_segments(project_id, project))
			elif StringName(project.get("project_kind", &"")) == &"WATCHTOWER":
				_create_completed_watchtower(project)
			elif StringName(project.get("project_kind", &"")) == PROJECT_FACILITY_REPAIR:
				var repaired_facility_id := StringName(project.get("facility_id", &""))
				var repaired_facility := Dictionary(watchtowers_by_id.get(repaired_facility_id, {}))
				if repaired_facility.is_empty():
					project.phase = &"INTERRUPTED"
					project.interruption_reason = &"FACILITY_MISSING"
					projects_by_id[project_id] = project
					continue
				repaired_facility.durability = int(repaired_facility.get("max_durability", 1))
				repaired_facility.state = FACILITY_ACTIVE
				if StringName(repaired_facility.get("facility_kind", &"")) == FACILITY_MINEFIELD:
					repaired_facility.mine_charges = maxi(int(project.get("restore_mine_charges", 0)), 1)
				watchtowers_by_id[repaired_facility_id] = repaired_facility
			elif StringName(project.get("project_kind", &"")) == PROJECT_FACILITY_UPGRADE:
				if not _complete_field_facility_upgrade(project):
					project.phase = &"INTERRUPTED"
					project.interruption_reason = &"FACILITY_MISSING"
					projects_by_id[project_id] = project
					continue
			engineer.phase = SPECIALIST_IDLE
			if StringName(project.get("project_kind", &"")) != &"REPAIR":
				engineer.current_point_id = StringName(project.get("target_point_id", &""))
				engineer.target_point_id = StringName(project.get("target_point_id", &""))
				# A new camp does not exist until _create_completed_camp below.  The
				# final physical road endpoint is already authoritative here, whereas
				# resolving the not-yet-created camp would incorrectly place the
				# engineer at the zero vector for one persistence frame.
				engineer.world_position = Vector2i(project.get("work_world_position", _road_endpoint_position(StringName(project.get("road_id", &""))))) if StringName(project.get("project_kind", &"")) in [&"WATCHTOWER", PROJECT_FACILITY_REPAIR, PROJECT_FACILITY_UPGRADE] else Vector2i(_road_endpoint_position(StringName(project.get("road_id", &""))))
			engineer.project_id = &""
			specialists_by_id[engineer_id] = engineer
			if bool(project.build_camp):
				_create_completed_camp(
					StringName(project.target_point_id), StringName(project.road_id),
					StringName(project.get("camp_id", &""))
				)
			completed.append(project_id)
		projects_by_id[project_id] = project
	for patrol_id_value in patrols_by_id.keys():
		var patrol_id := StringName(patrol_id_value)
		var patrol := Dictionary(patrols_by_id[patrol_id])
		if int(patrol.get("strength", 0)) <= 0:
			if StringName(patrol.get("invasion_kind", &"")) != &"" and StringName(patrol.get("phase", &"")) not in [INVASION_HANDED_OFF, INVASION_DEFEATED, INVASION_CANCELLED, INVASION_RESOLVED]:
				patrol.phase = INVASION_DEFEATED
				patrols_by_id[patrol_id] = patrol
			continue
		if StringName(patrol.get("phase", &"")) in [INVASION_DORMANT, INVASION_ARRIVED, INVASION_HANDED_OFF, INVASION_DEFEATED, INVASION_CANCELLED, INVASION_RESOLVED]:
			continue
		# Consume all of this world step across wait→move→arrival transitions.
		# Otherwise a large frame would discard its post-arrival remainder and
		# patrol positions would depend on call partitioning.
		var patrol_remaining_milliseconds := delta_milliseconds
		var patrol_transitions := 0
		while patrol_remaining_milliseconds > 0 and patrol_transitions < 16:
			patrol_transitions += 1
			var transition_start_offset := delta_milliseconds - patrol_remaining_milliseconds
			var patrol_wait := mini(int(patrol.get("wait_remaining_milliseconds", 0)), patrol_remaining_milliseconds)
			if patrol_wait > 0:
				var wait_position := Vector2i(patrol.get("world_position", Vector2i.ZERO))
				patrol.wait_remaining_milliseconds = int(patrol.get("wait_remaining_milliseconds", 0)) - patrol_wait
				patrol_remaining_milliseconds -= patrol_wait
				patrol_movements.append({
					"patrol_id": patrol_id, "from": wait_position, "to": wait_position,
					"start_offset_milliseconds": transition_start_offset,
					"end_offset_milliseconds": transition_start_offset + patrol_wait,
				})
				if patrol_remaining_milliseconds <= 0:
					break
			var patrol_route: Array = Array(patrol.get("route_point_ids", []))
			if patrol_route.size() < 2:
				break
			var target_index := clampi(int(patrol.get("target_route_index", 0)), 0, patrol_route.size() - 1)
			var target_point_id := StringName(patrol_route[target_index])
			var target_position := _point_position(target_point_id)
			var patrol_total_milliseconds := maxi(int(patrol.get("move_total_milliseconds", 1)), 1)
			var to_arrival_milliseconds := maxi(patrol_total_milliseconds - int(patrol.get("move_elapsed_milliseconds", 0)), 0)
			var patrol_move := mini(patrol_remaining_milliseconds, to_arrival_milliseconds)
			if patrol_move <= 0:
				break
			var patrol_start_position := Vector2i(patrol.get("world_position", patrol.get("move_start_position", Vector2i.ZERO)))
			var patrol_move_start_offset := delta_milliseconds - patrol_remaining_milliseconds
			var patrol_elapsed_before := int(patrol.get("move_elapsed_milliseconds", 0))
			patrol.move_elapsed_milliseconds = int(patrol.get("move_elapsed_milliseconds", 0)) + patrol_move
			patrol_remaining_milliseconds -= patrol_move
			var patrol_progress := float(patrol.get("move_elapsed_milliseconds", 0)) / float(patrol_total_milliseconds)
			var patrol_route_points: Array = Array(patrol.get("move_route_world_points", [patrol.get("move_start_position", Vector2i.ZERO), target_position]))
			patrol.world_position = Vector2i(_position_along_points(patrol_route_points, patrol_progress))
			patrol_movements.append_array(_timed_route_movement_records(
				patrol_id, patrol_route_points, patrol_elapsed_before,
				int(patrol.get("move_elapsed_milliseconds", 0)), patrol_total_milliseconds,
				patrol_move_start_offset
			))
			if int(patrol.get("move_elapsed_milliseconds", 0)) < patrol_total_milliseconds:
				break
			patrol.current_point_id = target_point_id
			patrol.world_position = target_position
			if (
				StringName(patrol.get("phase", &"")) == INVASION_MARCHING
				and target_point_id == StringName(patrol.get("target_point_id", &""))
			):
				patrol.phase = INVASION_ARRIVED
				patrol.wait_remaining_milliseconds = 0
				patrol.move_elapsed_milliseconds = 0
				patrol.move_total_milliseconds = 0
				patrol.move_start_position = target_position
				patrol.move_route_world_points = [target_position]
				arrived_invasion_ids.append(patrol_id)
				patrol_remaining_milliseconds = 0
				break
			patrol.target_route_index = (target_index + 1) % patrol_route.size()
			patrol.wait_remaining_milliseconds = 1200
			patrol.move_elapsed_milliseconds = 0
			patrol.move_start_position = target_position
			var next_target_id := StringName(patrol_route[int(patrol.target_route_index)])
			var next_plan: Dictionary = plan_runtime_path(target_point_id, next_target_id)
			patrol.move_route_world_points = Array(next_plan.get("points", [target_position, _point_position(next_target_id)])).duplicate(true)
			patrol.move_total_milliseconds = int(next_plan.get("duration_milliseconds", patrol_total_milliseconds))
		patrols_by_id[patrol_id] = patrol
		for specialist_id_value in specialists_by_id.keys():
			var specialist_id := StringName(specialist_id_value)
			var specialist := Dictionary(specialists_by_id[specialist_id])
			var specialist_position := Vector2(specialist.get("world_position", Vector2.ZERO))
			var specialist_trace: Array = Array(specialist_movements.get(specialist_id, [{
				"from": specialist_position, "to": specialist_position,
				"start_offset_milliseconds": 0, "end_offset_milliseconds": delta_milliseconds,
			}]))
			var patrol_traces: Array = []
			for movement_value in patrol_movements:
				var movement: Dictionary = Dictionary(movement_value)
				if StringName(movement.get("patrol_id", &"")) == patrol_id:
					patrol_traces.append(movement.duplicate(true))
			if patrol_traces.is_empty():
				patrol_traces.append({
					"from": patrol.get("world_position", Vector2i.ZERO), "to": patrol.get("world_position", Vector2i.ZERO),
					"start_offset_milliseconds": 0, "end_offset_milliseconds": delta_milliseconds,
				})
			var contact_milliseconds := _first_timed_contact_milliseconds(specialist_trace, patrol_traces, 28.0)
			if bool(specialist.get("alive", false)) and contact_milliseconds < INF:
				# Contact grants one last report before the observer is removed;
				# _refresh_intel then downgrades it to historical knowledge.
				intel_by_subject_id[patrol_id] = {
					"subject_id": patrol_id,
					"fog_state": FOG_VISIBLE,
					"last_known_point_id": StringName(patrol.current_point_id),
					"last_known_world_position": Vector2i(patrol.get("world_position", Vector2i.ZERO)),
					"last_observed_milliseconds": world_milliseconds,
					"known_strength": int(patrol.strength),
				}
				var guard_army_ids: Array[StringName] = []
				for army_id_value in guard_positions_by_army:
					var guard_position := Vector2(guard_positions_by_army[army_id_value])
					var guard_trace: Array = Array(guard_traces_by_army.get(army_id_value, [{
						"from": guard_position, "to": guard_position,
						"start_milliseconds": 0, "end_milliseconds": delta_milliseconds,
					}]))
					if _timed_trace_position_at(guard_trace, contact_milliseconds).distance_to(_timed_trace_position_at(specialist_trace, contact_milliseconds)) <= 72.0:
						guard_army_ids.append(StringName(army_id_value))
				if guard_army_ids.is_empty():
					specialist.alive = false
					specialist.phase = SPECIALIST_LOST
					if StringName(specialist.get("action_kind", &"")) != &"":
						specialist.action_stage = ACTION_INTERRUPTED
						specialist.action_result = {"error_id": &"SPECIALIST_LOST"}
					var project_id := StringName(specialist_project_ids.get(specialist_id, specialist.get("project_id", &"")))
					if projects_by_id.has(project_id):
						var interrupted_project := Dictionary(projects_by_id[project_id])
						var step_fact: Dictionary = Dictionary(project_step_facts.get(project_id, {}))
						if not step_fact.is_empty():
							var work_before_contact := clampi(
								roundi(contact_milliseconds - float(step_fact.work_start_offset)),
								0, int(step_fact.work_consumed)
							)
							var contact_progress := mini(
								int(step_fact.progress_before) + work_before_contact,
								int(interrupted_project.get("required_milliseconds", 0))
							)
							if contact_progress < int(interrupted_project.get("progress_milliseconds", 0)):
								interrupted_project.progress_milliseconds = contact_progress
								_remove_project_roads_opened_after(project_id, interrupted_project, contact_progress, opened_road_ids)
								if StringName(interrupted_project.get("project_kind", &"")) == &"REPAIR":
									var repaired_road_id := StringName(interrupted_project.get("road_id", &""))
									var reverted_road := Dictionary(roads_by_id.get(repaired_road_id, {}))
									if not reverted_road.is_empty():
										reverted_road.state = ROAD_DAMAGED
										# Older repair projects predate the within-step correction field. Their
										# stored road is still the damaged authoritative fact, so retain that
										# value rather than manufacturing a zero-durability bridge on restore.
										reverted_road.durability = int(interrupted_project.get(
											"repair_initial_durability", reverted_road.get("durability", 0)
										))
										roads_by_id[repaired_road_id] = reverted_road
									repaired_road_open_offsets.erase(repaired_road_id)
								elif StringName(interrupted_project.get("project_kind", &"")) == &"WATCHTOWER":
									# Project completion is provisional until this step's timed
									# contacts resolve. A patrol that reaches the engineer before
									# the final work millisecond must not leave a completed tower,
									# observer, or completion checkpoint behind.
									watchtowers_by_id.erase(StringName(interrupted_project.get("tower_id", &"")))
								completed.erase(project_id)
						if StringName(interrupted_project.get("phase", &"")) in [&"TRAVELING", &"BUILDING", &"COMPLETE"] and int(interrupted_project.get("progress_milliseconds", 0)) < int(interrupted_project.get("required_milliseconds", 0)):
							interrupted_project.phase = &"INTERRUPTED"
							interrupted_project.interruption_reason = &"ENGINEER_LOST"
							projects_by_id[project_id] = interrupted_project
							specialist.project_id = project_id
					specialists_by_id[specialist_id] = specialist
				engagements.append({"patrol_id": patrol_id, "specialist_id": specialist_id, "guard_army_ids": guard_army_ids, "point_id": patrol.current_point_id, "world_position": Vector2i(_timed_trace_position_at(patrol_traces, contact_milliseconds)), "contact_milliseconds": contact_milliseconds})
	# Repair completion is provisional until the time-aware specialist contacts
	# above are resolved. Only then may a convoy consume the post-repair remainder
	# of this world step; an interrupted repair leaves its damaged road unavailable.
	facility_events = _apply_field_facility_effects(delta_milliseconds, patrol_movements)
	supply_ready_to_unload = _advance_supply_transports(delta_milliseconds, repaired_road_open_offsets)
	for facility_id_value in watchtowers_by_id.keys():
		var facility := Dictionary(watchtowers_by_id[facility_id_value])
		if StringName(facility.get("facility_kind", &"")) != FACILITY_MINEFIELD or StringName(facility.get("owner_faction_id", &"player")) == &"player":
			continue
		for specialist_id_value in specialists_by_id.keys():
			if discover_minefield(StringName(facility_id_value), &"player", StringName(specialist_id_value)):
				facility_events.append({"facility_id": StringName(facility_id_value), "facility_kind": FACILITY_MINEFIELD, "effect": &"MINE_DISCOVERED"})
				break
	_refresh_intel()
	return {"success": true, "completed_project_ids": completed, "opened_road_ids": opened_road_ids, "arrived_invasion_ids": arrived_invasion_ids, "facility_events": facility_events, "engagements": engagements, "patrol_movements": patrol_movements, "ready_specialist_action_ids": ready_specialist_action_ids, "ready_supply_transport_ids": supply_ready_to_unload, "world_milliseconds": world_milliseconds, "delta_milliseconds": delta_milliseconds}


func _apply_field_facility_effects(delta_milliseconds: int, patrol_movements: Array = []) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for tower_id_value in watchtowers_by_id.keys():
		var tower_id := StringName(tower_id_value)
		var facility := Dictionary(watchtowers_by_id[tower_id])
		var facility_kind := StringName(facility.get("facility_kind", FACILITY_WATCHTOWER))
		var delayed_ids: Array = Array(facility.get("affected_patrol_ids", []))
		if facility_kind == FACILITY_WATCHTOWER or StringName(facility.get("state", FACILITY_ACTIVE)) == FACILITY_DESTROYED:
			continue
		var facility_position := Vector2(facility.get("world_position", Vector2.ZERO))
		if facility_kind == FACILITY_ARROW_TOWER:
			var interval := maxi(int(facility.get("attack_interval_milliseconds", 4000)), 1)
			facility.attack_elapsed_milliseconds = int(facility.get("attack_elapsed_milliseconds", 0)) + delta_milliseconds
			while int(facility.attack_elapsed_milliseconds) >= interval:
				facility.attack_elapsed_milliseconds = int(facility.attack_elapsed_milliseconds) - interval
				var target_id := _closest_effective_patrol_id(facility_position, float(facility.get("effect_range", 220)))
				if target_id == &"":
					# Volleys are not banked while no target exists. A newly entering
					# patrol must remain on the field for one authored interval.
					facility.attack_elapsed_milliseconds = 0
					break
				var patrol := Dictionary(patrols_by_id[target_id])
				var strength_before := int(patrol.get("strength", 0))
				var damage := mini(maxi(int(facility.get("damage", 1)), 1), strength_before)
				patrol.strength = strength_before - damage
				if int(patrol.strength) <= 0 and StringName(patrol.get("invasion_kind", &"")) != &"":
					patrol.phase = INVASION_DEFEATED
				patrols_by_id[target_id] = patrol
				events.append({"facility_id": tower_id, "facility_kind": facility_kind, "patrol_id": target_id, "effect": &"DAMAGE", "amount": damage, "strength_after": int(patrol.strength)})
		elif facility_kind == FACILITY_BARRICADE:
			for patrol_id_value in patrols_by_id.keys():
				var patrol_id := StringName(patrol_id_value)
				var patrol := Dictionary(patrols_by_id[patrol_id])
				if patrol_id in delayed_ids or not _patrol_can_receive_field_effect(patrol):
					continue
				if facility_position.distance_to(Vector2(patrol.get("world_position", Vector2.INF))) > float(facility.get("effect_range", 42)):
					continue
				var delay := maxi(int(facility.get("route_delay_milliseconds", 8000)), 0)
				patrol.wait_remaining_milliseconds = int(patrol.get("wait_remaining_milliseconds", 0)) + delay
				patrols_by_id[patrol_id] = patrol
				delayed_ids.append(patrol_id)
				var durability_before := int(facility.get("durability", facility.get("max_durability", 160)))
				facility.durability = maxi(durability_before - maxi(int(facility.get("collision_damage", 45)), 0), 0)
				facility.state = FACILITY_DESTROYED if int(facility.durability) <= 0 else FACILITY_DAMAGED
				events.append({"facility_id": tower_id, "facility_kind": facility_kind, "patrol_id": patrol_id, "effect": &"DELAY", "amount": delay, "durability_after": int(facility.durability)})
		elif facility_kind == FACILITY_MINEFIELD:
			var charges := maxi(int(facility.get("mine_charges", 0)), 0)
			if charges > 0:
				for movement_value in patrol_movements:
					var movement: Dictionary = Dictionary(movement_value)
					var patrol_id := StringName(movement.get("patrol_id", &""))
					if patrol_id == &"" or patrol_id in delayed_ids:
						continue
					var patrol := Dictionary(patrols_by_id.get(patrol_id, {}))
					if not _patrol_can_receive_field_effect(patrol):
						continue
					var closest := Geometry2D.get_closest_point_to_segment(
						facility_position,
						Vector2(movement.get("from", facility_position)),
						Vector2(movement.get("to", facility_position))
					)
					if closest.distance_to(facility_position) > float(facility.get("effect_range", 34)):
						continue
					var strength_before := int(patrol.get("strength", 0))
					var damage := mini(maxi(int(facility.get("mine_damage", 1)), 1), strength_before)
					patrol.strength = strength_before - damage
					if int(patrol.strength) <= 0 and StringName(patrol.get("invasion_kind", &"")) != &"":
						patrol.phase = INVASION_DEFEATED
					patrols_by_id[patrol_id] = patrol
					delayed_ids.append(patrol_id)
					charges -= 1
					events.append({"facility_id": tower_id, "facility_kind": facility_kind, "patrol_id": patrol_id, "effect": &"MINE_TRIGGER", "amount": damage, "charges_after": charges, "strength_after": int(patrol.strength)})
					break
			facility.mine_charges = charges
			facility.durability = 1 if charges > 0 else 0
			facility.state = FACILITY_ACTIVE if charges > 0 else FACILITY_DESTROYED
		facility.affected_patrol_ids = Array(facility.get("affected_patrol_ids", [])) if facility_kind != FACILITY_BARRICADE else delayed_ids
		if facility_kind == FACILITY_MINEFIELD:
			facility.affected_patrol_ids = delayed_ids
		watchtowers_by_id[tower_id] = facility
	return events


func _closest_effective_patrol_id(position: Vector2, effect_range: float) -> StringName:
	var closest_id: StringName = &""
	var closest_distance := INF
	for patrol_id_value in patrols_by_id.keys():
		var patrol_id := StringName(patrol_id_value)
		var patrol := Dictionary(patrols_by_id[patrol_id])
		if not _patrol_can_receive_field_effect(patrol):
			continue
		var distance := position.distance_to(Vector2(patrol.get("world_position", Vector2.INF)))
		if distance <= effect_range and distance < closest_distance:
			closest_id = patrol_id
			closest_distance = distance
	return closest_id


func _patrol_can_receive_field_effect(patrol: Dictionary) -> bool:
	return int(patrol.get("strength", 0)) > 0 and StringName(patrol.get("phase", &"")) not in [
		INVASION_DORMANT, INVASION_ARRIVED, INVASION_HANDED_OFF,
		INVASION_DEFEATED, INVASION_CANCELLED, INVASION_RESOLVED,
	]


func _open_completed_construction_segments(project_id: StringName, project: Dictionary) -> Array[StringName]:
	var opened: Array[StringName] = []
	var elapsed := int(project.get("progress_milliseconds", 0))
	var accumulated := 0
	var segment_plans: Array = Array(project.get("segment_plans", []))
	if segment_plans.is_empty():
		segment_plans = [{
			"road_id": StringName(project.get("road_id", &"")),
			"source_point_id": StringName(project.get("source_point_id", &"")),
			"target_point_id": StringName(project.get("target_point_id", &"")),
			"route_world_points": Array(project.get("route_world_points", [])).duplicate(true),
			"road_kind": StringName(project.get("road_kind", ROAD_NORMAL)),
			"required_milliseconds": int(project.get("required_milliseconds", 0)),
			"max_durability": int(project.get("max_durability", 0)),
		}]
	for segment_value in segment_plans:
		var segment: Dictionary = Dictionary(segment_value)
		accumulated += int(segment.get("required_milliseconds", 0))
		var road_id := StringName(segment.get("road_id", &""))
		if elapsed < accumulated or road_id == &"" or roads_by_id.has(road_id):
			continue
		roads_by_id[road_id] = {
			"road_id": road_id,
			"source_point_id": StringName(segment.get("source_point_id", &"")),
			"target_point_id": StringName(segment.get("target_point_id", &"")),
			"route_world_points": Array(segment.get("route_world_points", [])).duplicate(true),
			"road_kind": StringName(segment.get("road_kind", ROAD_NORMAL)),
			"state": ROAD_OPEN,
			"durability": int(segment.get("max_durability", 0)),
			"max_durability": int(segment.get("max_durability", 0)),
			"built": true,
			"project_id": project_id,
		}
		opened.append(road_id)
	return opened


func _update_engineer_construction_position(engineer: Dictionary, project: Dictionary) -> void:
	var elapsed := int(project.get("progress_milliseconds", 0))
	var accumulated := 0
	for segment_value in Array(project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		var duration := maxi(int(segment.get("required_milliseconds", 0)), 1)
		var points: Array = Array(segment.get("route_world_points", []))
		if points.is_empty():
			continue
		if elapsed >= accumulated + duration:
			engineer.world_position = Vector2i(points.back())
			accumulated += duration
			continue
		var local_progress := clampf(float(elapsed - accumulated) / float(duration), 0.0, 1.0)
		# A bridge is built from the reachable bank.  The engineer remains at its
		# start until the bridge opens instead of visually crossing water early.
		if StringName(segment.get("road_kind", &"")) == ROAD_BRIDGE:
			engineer.world_position = Vector2i(points.front())
			return
		engineer.world_position = Vector2i(_position_along_points(points, local_progress))
		return


func _timed_project_work_records(
	engineer_id: StringName,
	project: Dictionary,
	start_progress: int,
	end_progress: int,
	step_start_offset: int
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var accumulated := 0
	for segment_value in Array(project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		var duration := maxi(int(segment.get("required_milliseconds", 0)), 1)
		var segment_start := accumulated
		var segment_end := accumulated + duration
		accumulated = segment_end
		var overlap_start := maxi(start_progress, segment_start)
		var overlap_end := mini(end_progress, segment_end)
		if overlap_end <= overlap_start:
			continue
		var points: Array = Array(segment.get("route_world_points", []))
		if points.is_empty():
			continue
		var local_start := overlap_start - segment_start
		var local_end := overlap_end - segment_start
		var record_offset := step_start_offset + overlap_start - start_progress
		if StringName(segment.get("road_kind", &"")) == ROAD_BRIDGE:
			var bank := Vector2(points.front())
			records.append({
				"patrol_id": engineer_id, "from": bank, "to": bank,
				"start_offset_milliseconds": record_offset,
				"end_offset_milliseconds": record_offset + local_end - local_start,
			})
			continue
		records.append_array(_timed_route_movement_records(
			engineer_id, points, local_start, local_end, duration, record_offset
		))
	return records


func _remove_project_roads_opened_after(
	project_id: StringName,
	project: Dictionary,
	progress_milliseconds: int,
	opened_road_ids: Array[StringName]
) -> void:
	var accumulated := 0
	for segment_value in Array(project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		accumulated += int(segment.get("required_milliseconds", 0))
		var road_id := StringName(segment.get("road_id", &""))
		if accumulated <= progress_milliseconds or road_id == &"":
			continue
		var road := Dictionary(roads_by_id.get(road_id, {}))
		if StringName(road.get("project_id", &"")) == project_id:
			roads_by_id.erase(road_id)
		opened_road_ids.erase(road_id)
	if progress_milliseconds < int(project.get("required_milliseconds", 0)) and bool(project.get("build_camp", false)):
		var reserved_camp_id := StringName(project.get("camp_id", &""))
		if reserved_camp_id != &"":
			camps_by_id.erase(reserved_camp_id)


func _position_along_points(points: Array, progress: float) -> Vector2:
	var total_length := 0.0
	for point_index in range(1, points.size()):
		total_length += Vector2(points[point_index - 1]).distance_to(Vector2(points[point_index]))
	if total_length <= 0.0001:
		return Vector2(points.front()) if not points.is_empty() else Vector2.ZERO
	var target_length := total_length * clampf(progress, 0.0, 1.0)
	var consumed := 0.0
	for point_index in range(1, points.size()):
		var start := Vector2(points[point_index - 1])
		var end := Vector2(points[point_index])
		var length := start.distance_to(end)
		if target_length <= consumed + length:
			return start.lerp(end, (target_length - consumed) / maxf(length, 0.0001))
		consumed += length
	return Vector2(points.back())


func _timed_route_movement_records(patrol_id: StringName, points: Array, start_elapsed: int, end_elapsed: int, total_milliseconds: int, step_start_offset: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if points.size() < 2:
		return records
	var total_length := 0.0
	var cumulative: Array[float] = [0.0]
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
		cumulative.append(total_length)
	var start_progress := float(start_elapsed) / maxf(float(total_milliseconds), 1.0)
	var end_progress := float(end_elapsed) / maxf(float(total_milliseconds), 1.0)
	var start_distance := total_length * clampf(start_progress, 0.0, 1.0)
	var end_distance := total_length * clampf(end_progress, 0.0, 1.0)
	var trace_points: Array = [_position_along_points(points, start_progress)]
	for index in range(1, points.size() - 1):
		if cumulative[index] > start_distance + 0.0001 and cumulative[index] < end_distance - 0.0001:
			trace_points.append(Vector2(points[index]))
	trace_points.append(_position_along_points(points, end_progress))
	var trace_length := maxf(end_distance - start_distance, 0.0001)
	var elapsed_offset := float(step_start_offset)
	var movement_milliseconds := float(end_elapsed - start_elapsed)
	for index in range(1, trace_points.size()):
		var from := Vector2(trace_points[index - 1])
		var to := Vector2(trace_points[index])
		var segment_milliseconds := movement_milliseconds * from.distance_to(to) / trace_length
		records.append({
			"patrol_id": patrol_id, "from": Vector2i(from), "to": Vector2i(to),
			"start_offset_milliseconds": elapsed_offset,
			"end_offset_milliseconds": elapsed_offset + segment_milliseconds,
		})
		elapsed_offset += segment_milliseconds
	return records


func _plan_specialist_land_path(start_position: Vector2, target_position: Vector2) -> Dictionary:
	if not world_bounds.has_point(Vector2i(start_position)) or not world_bounds.has_point(Vector2i(target_position)) or not _specialist_position_is_legal(start_position) or not _specialist_position_is_legal(target_position):
		return {}
	var nodes: Array[Vector2] = [start_position, target_position]
	# A visibility graph over water bounds is sufficient for the small greybox
	# theatre: specialists may cross open land, but never cut across a water
	# region. Roads remain optional shortcuts rather than a movement requirement.
	for water in water_regions:
		var margin := 2.0
		for corner in [
			Vector2(water.position.x - margin, water.position.y - margin),
			Vector2(water.end.x + margin, water.position.y - margin),
			Vector2(water.position.x - margin, water.end.y + margin),
			Vector2(water.end.x + margin, water.end.y + margin),
		]:
			if world_bounds.has_point(Vector2i(corner)):
				nodes.append(corner)
	for road_value in roads_by_id.values():
		var bridge: Dictionary = road_value
		if StringName(bridge.get("road_kind", &"")) != ROAD_BRIDGE or not is_route_open(StringName(bridge.get("road_id", &""))):
			continue
		for bridge_point in _bridge_navigation_points(Array(bridge.get("route_world_points", []))):
			nodes.append(Vector2(bridge_point))
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for index in nodes.size():
		costs.append(0.0 if index == 0 else INF)
		previous.append(-1)
		visited.append(false)
	for _step in nodes.size():
		var current := -1
		for index in nodes.size():
			if not visited[index] and (current < 0 or costs[index] < costs[current]):
				current = index
		if current < 0 or is_inf(costs[current]):
			break
		if current == 1:
			break
		visited[current] = true
		for next_index in nodes.size():
			if next_index == current or not _specialist_segment_traversable(nodes[current], nodes[next_index]):
				continue
			var edge_distance := nodes[current].distance_to(nodes[next_index])
			# A completed bridge is deliberate infrastructure. Prefer its exact
			# physical edge over a near-shore detour, while preserving the real
			# geometry for stored distance and movement duration below.
			var traversal_cost := edge_distance * (0.55 if _is_open_bridge_edge(nodes[current], nodes[next_index]) else 1.0)
			var candidate := costs[current] + traversal_cost
			if candidate < costs[next_index]:
				costs[next_index] = candidate
				previous[next_index] = current
	if is_inf(costs[1]):
		return {}
	var reverse_points: Array = []
	var cursor := 1
	var physical_distance := 0.0
	while cursor >= 0:
		reverse_points.append(Vector2i(nodes[cursor]))
		if previous[cursor] >= 0:
			physical_distance += nodes[cursor].distance_to(nodes[previous[cursor]])
		cursor = previous[cursor]
	reverse_points.reverse()
	return {
		"points": reverse_points,
		"distance_units": physical_distance,
		"duration_milliseconds": maxi(1800, ceili(physical_distance * 2.5)),
	}


func _specialist_segment_traversable(start: Vector2, end: Vector2) -> bool:
	if not _route_crosses_water([start, end]):
		return world_bounds.has_point(Vector2i(start)) and world_bounds.has_point(Vector2i(end))
	return _is_open_bridge_edge(start, end) or _is_open_bridge_shore_connection(start, end)


func _specialist_position_is_legal(position: Vector2) -> bool:
	return not _point_is_in_water(Vector2i(position)) or _is_open_bridge_navigation_point(position)


func _is_open_bridge_navigation_point(position: Vector2) -> bool:
	for road_value in roads_by_id.values():
		var bridge: Dictionary = road_value
		if StringName(bridge.get("road_kind", &"")) != ROAD_BRIDGE or not is_route_open(StringName(bridge.get("road_id", &""))):
			continue
		for bridge_point in _bridge_navigation_points(Array(bridge.get("route_world_points", []))):
			if position.is_equal_approx(Vector2(bridge_point)):
				return true
	return false


func _is_open_bridge_edge(start: Vector2, end: Vector2) -> bool:
	for road_value in roads_by_id.values():
		var bridge: Dictionary = road_value
		if StringName(bridge.get("road_kind", &"")) != ROAD_BRIDGE or not is_route_open(StringName(bridge.get("road_id", &""))):
			continue
		var bridge_points := _bridge_navigation_points(Array(bridge.get("route_world_points", [])))
		for point_index in range(1, bridge_points.size()):
			var edge_start := Vector2(bridge_points[point_index - 1])
			var edge_end := Vector2(bridge_points[point_index])
			if (start.is_equal_approx(edge_start) and end.is_equal_approx(edge_end)) or (start.is_equal_approx(edge_end) and end.is_equal_approx(edge_start)):
				return true
	return false


func _is_open_bridge_shore_connection(start: Vector2, end: Vector2) -> bool:
	var bridge_position := end if _is_open_bridge_navigation_point(end) else (start if _is_open_bridge_navigation_point(start) else Vector2.INF)
	var land_position := start if bridge_position == end else end
	if bridge_position == Vector2.INF or _point_is_in_water(Vector2i(land_position)):
		return false
	var samples := maxi(1, ceili(land_position.distance_to(bridge_position)))
	for sample_index in range(samples):
		# Sample away from the land edge and deliberately exclude the bridge
		# navigation point.  The latter can lie on water by construction, but the
		# same shore connection must be valid in either travel direction.
		var sampled := land_position.lerp(bridge_position, float(sample_index) / float(samples))
		if _point_is_in_water(Vector2i(sampled)):
			return false
	return world_bounds.has_point(Vector2i(start)) and world_bounds.has_point(Vector2i(end))


func _bridge_navigation_points(route_world_points: Array) -> Array:
	if route_world_points.size() <= 2:
		return route_world_points.duplicate(true)
	var points: Array = [route_world_points.front()]
	for point_index in range(1, route_world_points.size() - 1):
		var previous := Vector2(route_world_points[point_index - 1])
		var current := Vector2(route_world_points[point_index])
		var following := Vector2(route_world_points[point_index + 1])
		# Unit-sampled construction geometry can contain hundreds of collinear
		# points. Keep turns and endpoints for movement without turning a bridge
		# path into a straight endpoint-to-endpoint shortcut.
		if not is_zero_approx((current - previous).cross(following - current)):
			points.append(route_world_points[point_index])
	points.append(route_world_points.back())
	return points


func observe_subject(subject_id: StringName) -> Dictionary:
	return Dictionary(intel_by_subject_id.get(subject_id, {
		"subject_id": subject_id,
		"fog_state": FOG_UNOBSERVED,
		"last_known_point_id": &"",
		"last_observed_milliseconds": 0,
		"known_strength": 0,
	})).duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"roads_by_id": roads_by_id.duplicate(true),
		"camps_by_id": camps_by_id.duplicate(true),
		"watchtowers_by_id": watchtowers_by_id.duplicate(true),
		"specialists_by_id": specialists_by_id.duplicate(true),
		"projects_by_id": projects_by_id.duplicate(true),
		"patrols_by_id": patrols_by_id.duplicate(true),
		"intel_by_subject_id": intel_by_subject_id.duplicate(true),
		"supply_inventory_by_point_id": supply_inventory_by_point_id.duplicate(true),
		"stationed_reinforcements_by_point_id": stationed_reinforcements_by_point_id.duplicate(true),
		"supply_transports_by_id": supply_transports_by_id.duplicate(true),
		"world_milliseconds": world_milliseconds,
		"next_specialist_sequence": next_specialist_sequence,
		"next_project_sequence": next_project_sequence,
		"next_camp_sequence": next_camp_sequence,
		"next_watchtower_sequence": next_watchtower_sequence,
		"next_supply_transport_sequence": next_supply_transport_sequence,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var legacy_required := ["schema_version", "roads_by_id", "camps_by_id", "specialists_by_id", "projects_by_id", "patrols_by_id", "intel_by_subject_id", "world_milliseconds", "next_specialist_sequence", "next_project_sequence", "next_camp_sequence"]
	var supply_required := legacy_required.duplicate()
	supply_required.append_array(["supply_inventory_by_point_id", "supply_transports_by_id", "next_supply_transport_sequence"])
	var required := supply_required.duplicate()
	required.append("stationed_reinforcements_by_point_id")
	var watchtower_required := required.duplicate()
	watchtower_required.append_array(["watchtowers_by_id", "next_watchtower_sequence"])
	# Field R2 introduced supply (14 fields), stationed reinforcements (15),
	# then watchtowers (17). Identify those historical layouts by their actual
	# field sets rather than one latest-legacy size branch, so formal V5 restore
	# keeps accepting every previously supported representation.
	var has_supply_state := snapshot.has("supply_inventory_by_point_id") or snapshot.has("supply_transports_by_id") or snapshot.has("next_supply_transport_sequence")
	var has_complete_supply_state := snapshot.has("supply_inventory_by_point_id") and snapshot.has("supply_transports_by_id") and snapshot.has("next_supply_transport_sequence")
	var has_reinforcement_state := snapshot.has("stationed_reinforcements_by_point_id")
	var has_watchtower_state := snapshot.has("watchtowers_by_id") or snapshot.has("next_watchtower_sequence")
	var has_complete_watchtower_state := snapshot.has("watchtowers_by_id") and snapshot.has("next_watchtower_sequence")
	if has_supply_state != has_complete_supply_state or (has_reinforcement_state and not has_complete_supply_state) or has_watchtower_state != has_complete_watchtower_state or (has_complete_watchtower_state and not has_reinforcement_state):
		return false
	var is_legacy_supply_snapshot := not has_complete_supply_state
	var is_legacy_reinforcement_snapshot := has_complete_supply_state and not has_reinforcement_state
	var expected_keys: Array = legacy_required.duplicate()
	if has_complete_supply_state:
		expected_keys.append_array(supply_required.slice(legacy_required.size()))
	if has_reinforcement_state:
		expected_keys.append("stationed_reinforcements_by_point_id")
	if has_complete_watchtower_state:
		expected_keys.append_array(["watchtowers_by_id", "next_watchtower_sequence"])
	if snapshot.size() != expected_keys.size() or typeof(snapshot.get("schema_version")) != TYPE_INT or int(snapshot.get("schema_version")) != SCHEMA_VERSION:
		return false
	for key in expected_keys:
		if not snapshot.has(key):
			return false
	if (
		not snapshot.get("roads_by_id", null) is Dictionary or not snapshot.get("camps_by_id", null) is Dictionary
		or not snapshot.get("specialists_by_id", null) is Dictionary or not snapshot.get("projects_by_id", null) is Dictionary
		or not snapshot.get("patrols_by_id", null) is Dictionary or not snapshot.get("intel_by_subject_id", null) is Dictionary
		or typeof(snapshot.get("world_milliseconds", null)) != TYPE_INT or int(snapshot.get("world_milliseconds", 0)) < 0 or typeof(snapshot.get("next_specialist_sequence", null)) != TYPE_INT or int(snapshot.get("next_specialist_sequence", 0)) <= 0
		or typeof(snapshot.get("next_project_sequence", null)) != TYPE_INT or int(snapshot.get("next_project_sequence", 0)) <= 0 or typeof(snapshot.get("next_camp_sequence", null)) != TYPE_INT or int(snapshot.get("next_camp_sequence", 0)) <= 0
		or (not is_legacy_supply_snapshot and (not snapshot.get("supply_inventory_by_point_id", null) is Dictionary or not snapshot.get("supply_transports_by_id", null) is Dictionary or typeof(snapshot.get("next_supply_transport_sequence", null)) != TYPE_INT or int(snapshot.get("next_supply_transport_sequence", 0)) <= 0))
		or (not is_legacy_supply_snapshot and not is_legacy_reinforcement_snapshot and not snapshot.get("stationed_reinforcements_by_point_id", null) is Dictionary)
		or (has_complete_watchtower_state and (not snapshot.get("watchtowers_by_id", null) is Dictionary or not _is_snapshot_int(snapshot.get("next_watchtower_sequence", null)) or int(snapshot.get("next_watchtower_sequence", 0)) <= 0))
	):
		return false
	if not _has_valid_references(
		Dictionary(snapshot.get("roads_by_id", {})), Dictionary(snapshot.get("camps_by_id", {})), Dictionary(snapshot.get("watchtowers_by_id", {})),
		Dictionary(snapshot.get("specialists_by_id", {})), Dictionary(snapshot.get("projects_by_id", {})),
		Dictionary(snapshot.get("patrols_by_id", {})), Dictionary(snapshot.get("intel_by_subject_id", {})), int(snapshot.get("next_watchtower_sequence", 1))
	):
		return false
	if not is_legacy_supply_snapshot and not _has_valid_supply_state(
		Dictionary(snapshot.get("supply_inventory_by_point_id", {})), Dictionary(snapshot.get("supply_transports_by_id", {})), Dictionary(snapshot.get("roads_by_id", {})), snapshot.get("next_supply_transport_sequence", 1)
	):
		return false
	if not is_legacy_supply_snapshot and not is_legacy_reinforcement_snapshot and not _has_valid_stationed_reinforcement_state(Dictionary(snapshot.get("stationed_reinforcements_by_point_id", {}))):
		return false
	roads_by_id = Dictionary(snapshot.roads_by_id).duplicate(true)
	camps_by_id = Dictionary(snapshot.camps_by_id).duplicate(true)
	watchtowers_by_id = Dictionary(snapshot.get("watchtowers_by_id", {})).duplicate(true)
	specialists_by_id = Dictionary(snapshot.specialists_by_id).duplicate(true)
	projects_by_id = Dictionary(snapshot.projects_by_id).duplicate(true)
	patrols_by_id = Dictionary(snapshot.patrols_by_id).duplicate(true)
	intel_by_subject_id = Dictionary(snapshot.intel_by_subject_id).duplicate(true)
	supply_inventory_by_point_id = Dictionary(snapshot.get("supply_inventory_by_point_id", {})).duplicate(true)
	stationed_reinforcements_by_point_id = Dictionary(snapshot.get("stationed_reinforcements_by_point_id", {})).duplicate(true)
	supply_transports_by_id = Dictionary(snapshot.get("supply_transports_by_id", {})).duplicate(true)
	world_milliseconds = int(snapshot.world_milliseconds)
	next_specialist_sequence = int(snapshot.next_specialist_sequence)
	next_project_sequence = int(snapshot.next_project_sequence)
	next_camp_sequence = int(snapshot.next_camp_sequence)
	next_watchtower_sequence = int(snapshot.get("next_watchtower_sequence", 1))
	next_supply_transport_sequence = int(snapshot.get("next_supply_transport_sequence", 1))
	_specialist_path_migration_pending = true
	_supply_snapshot_restored = true
	_stationed_reinforcement_snapshot_restored = true
	return true


func _migrate_restored_specialist_paths() -> void:
	for specialist_id_value in specialists_by_id.keys():
		var specialist_id := StringName(specialist_id_value)
		var specialist := Dictionary(specialists_by_id[specialist_id])
		if StringName(specialist.get("phase", &"")) != SPECIALIST_MOVING:
			continue
		if Array(specialist.get("move_route_world_points", [])).size() >= 2:
			continue
		var start_position := Vector2(specialist.get("world_position", _point_position(StringName(specialist.get("current_point_id", &"")))))
		var target_position := Vector2(specialist.get("target_world_position", INVALID_WORLD_POSITION))
		var movement_plan := _plan_specialist_land_path(start_position, target_position)
		if movement_plan.is_empty():
			var project_id := StringName(specialist.get("project_id", &""))
			if projects_by_id.has(project_id):
				var project := Dictionary(projects_by_id[project_id])
				project.phase = &"INTERRUPTED"
				project.interruption_reason = &"SPECIALIST_PATH_BLOCKED"
				projects_by_id[project_id] = project
			specialist.project_id = &""
			specialist.phase = SPECIALIST_BLOCKED
			specialist.move_remaining_milliseconds = 0
			specialist.move_elapsed_milliseconds = 0
			specialist.move_total_milliseconds = 0
			specialist.movement_block_reason = &"PATH_UNAVAILABLE"
			specialists_by_id[specialist_id] = specialist
			continue
		specialist.move_start_position = Vector2i(start_position)
		specialist.move_route_world_points = Array(movement_plan.get("points", [])).duplicate(true)
		specialist.move_total_milliseconds = int(movement_plan.get("duration_milliseconds", 0))
		specialist.move_elapsed_milliseconds = 0
		specialist.move_remaining_milliseconds = int(movement_plan.get("duration_milliseconds", 0))
		specialists_by_id[specialist_id] = specialist


func _create_completed_camp(point_id: StringName, road_id: StringName, reserved_camp_id: StringName = &"") -> void:
	# Old saves predate command-time camp reservations.  Keep their completion
	# path readable, while all new projects use their already persisted ID.
	var camp_id := reserved_camp_id
	if camp_id == &"":
		camp_id = StringName("camp.%06d" % next_camp_sequence)
		next_camp_sequence += 1
	camps_by_id[camp_id] = {
		"camp_id": camp_id,
		"point_id": point_id,
		"road_id": road_id,
		"display_name": "工程驻点 %s" % String(camp_id).trim_prefix("camp."),
		"world_position": Vector2i(_road_endpoint_position(road_id)),
		"durability": 80,
		"connected": true,
	}


func _create_completed_watchtower(project: Dictionary) -> void:
	var tower_id := StringName(project.get("tower_id", &""))
	var camp_id := StringName(project.get("camp_id", &""))
	if tower_id == &"" or camp_id == &"" or not camps_by_id.has(camp_id) or watchtowers_by_id.has(tower_id):
		return
	watchtowers_by_id[tower_id] = {
		"watchtower_id": tower_id,
		"camp_id": camp_id,
		"project_id": StringName(project.get("project_id", &"")),
		"world_position": Vector2i(project.get("work_world_position", Vector2i.ZERO)),
		"visibility_range": maxi(int(project.get("visibility_range", 1)), 1),
		"facility_kind": StringName(project.get("facility_kind", FACILITY_WATCHTOWER)),
		"durability": maxi(int(project.get("max_durability", 100)), 1),
		"max_durability": maxi(int(project.get("max_durability", 100)), 1),
		"state": FACILITY_ACTIVE,
		"effect_range": maxi(int(project.get("effect_range", project.get("visibility_range", 1))), 1),
		"attack_interval_milliseconds": maxi(int(project.get("attack_interval_milliseconds", 0)), 0),
		"attack_elapsed_milliseconds": 0,
		"damage": maxi(int(project.get("damage", 0)), 0),
		"route_delay_milliseconds": maxi(int(project.get("route_delay_milliseconds", 0)), 0),
		"collision_damage": maxi(int(project.get("collision_damage", 0)), 0),
		"garrison_casualty_reduction_permille": clampi(int(project.get("garrison_casualty_reduction_permille", 0)), 0, 1000),
		"garrison_army_id": &"",
		"mine_charges": maxi(int(project.get("mine_charges", 0)), 0),
		"mine_damage": maxi(int(project.get("mine_damage", 0)), 0),
		"owner_faction_id": &"player",
		"discovered_by_faction_ids": [&"player"],
		"level": 1,
		"affected_patrol_ids": [],
		"complete": true,
	}


func _complete_field_facility_upgrade(project: Dictionary) -> bool:
	var facility_id := StringName(project.get("facility_id", &""))
	var facility := Dictionary(watchtowers_by_id.get(facility_id, {}))
	if facility.is_empty() or int(facility.get("level", 1)) >= int(project.get("target_level", 2)):
		return false
	var old_max := maxi(int(facility.get("max_durability", 1)), 1)
	var old_durability := clampi(int(facility.get("durability", 0)), 0, old_max)
	var new_max := maxi(int(project.get("target_max_durability", old_max)), old_max)
	# Upgrade construction keeps the original facility active. Completion changes
	# capability without acting as a free repair: preserve its durability ratio.
	facility.max_durability = new_max
	facility.durability = clampi(roundi(float(old_durability * new_max) / float(old_max)), 0, new_max)
	facility.level = int(project.get("target_level", 2))
	facility.effect_range = maxi(int(project.get("target_effect_range", facility.get("effect_range", 1))), 1)
	facility.damage = maxi(int(project.get("target_damage", facility.get("damage", 0))), 0)
	facility.route_delay_milliseconds = maxi(int(project.get("target_route_delay_milliseconds", facility.get("route_delay_milliseconds", 0))), 0)
	facility.mine_charges = maxi(int(project.get("target_mine_charges", facility.get("mine_charges", 0))), 0)
	facility.garrison_casualty_reduction_permille = clampi(int(project.get("target_garrison_reduction_permille", facility.get("garrison_casualty_reduction_permille", 0))), 0, 1000)
	watchtowers_by_id[facility_id] = facility
	return true


func _road_endpoint_position(road_id: StringName) -> Vector2:
	var road: Dictionary = Dictionary(roads_by_id.get(road_id, {}))
	var points: Array = road.get("route_world_points", [])
	return Vector2(points.back()) if not points.is_empty() else Vector2.ZERO


func _point_position(point_id: StringName) -> Vector2i:
	if point_positions_by_id.has(point_id):
		return Vector2i(point_positions_by_id[point_id])
	for camp_value in camps_by_id.values():
		var camp: Dictionary = camp_value
		if StringName(camp.get("point_id", &"")) == point_id:
			return Vector2i(camp.get("world_position", _road_endpoint_position(StringName(camp.get("road_id", &"")))))
	for road_value in roads_by_id.values():
		var road: Dictionary = road_value
		var points: Array = Array(road.get("route_world_points", []))
		if points.is_empty():
			continue
		if StringName(road.get("source_point_id", &"")) == point_id:
			return Vector2i(points.front())
		if StringName(road.get("target_point_id", &"")) == point_id:
			return Vector2i(points.back())
	return INVALID_WORLD_POSITION


func _refresh_intel() -> void:
	var observers: Array[Dictionary] = []
	var scout_observers: Array[Dictionary] = []
	for specialist_value in specialists_by_id.values():
		var specialist: Dictionary = specialist_value
		if bool(specialist.get("alive", false)) and StringName(specialist.get("role", &"")) in [SPECIALIST_SCOUT, SPECIALIST_ENGINEER]:
			var observer := {
				"world_position": Vector2(specialist.get("world_position", _point_position(StringName(specialist.get("current_point_id", &""))))),
				"range": int(specialist.get("visibility_range", 1)) * 180,
			}
			observers.append(observer)
			if StringName(specialist.get("role", &"")) == SPECIALIST_SCOUT:
				scout_observers.append(observer)
	# City theft uses a durable scout report, not the mere fact that an authored
	# city marker exists. A previously inspected point remains known after the
	# scout leaves, while its live visibility is recomputed from current position.
	for point_id_value in point_positions_by_id.keys():
		var point_id := StringName(point_id_value)
		var point_position := Vector2(point_positions_by_id[point_id])
		var visible_to_scout := false
		for observer_value in scout_observers:
			var scout_observer: Dictionary = observer_value
			if point_position.distance_to(Vector2(scout_observer.world_position)) <= float(scout_observer.range):
				visible_to_scout = true
				break
		var previous_point_intel := Dictionary(intel_by_subject_id.get(point_id, {}))
		var previously_scouted := StringName(previous_point_intel.get("subject_kind", &"")) == &"POINT" and StringName(previous_point_intel.get("fog_state", FOG_UNOBSERVED)) in [FOG_VISIBLE, FOG_OBSERVED]
		if visible_to_scout or previously_scouted:
			intel_by_subject_id[point_id] = {
				"subject_id": point_id,
				"subject_kind": &"POINT",
				"fog_state": FOG_VISIBLE if visible_to_scout else FOG_OBSERVED,
				"last_known_point_id": point_id,
				"last_known_world_position": Vector2i(point_position),
				"last_observed_milliseconds": world_milliseconds if visible_to_scout else int(previous_point_intel.get("last_observed_milliseconds", 0)),
			}
	for camp_value in camps_by_id.values():
		observers.append({"world_position": Vector2(Dictionary(camp_value).get("world_position", Vector2.ZERO)), "range": 120})
	for tower_value in watchtowers_by_id.values():
		var tower: Dictionary = Dictionary(tower_value)
		if bool(tower.get("complete", false)) and StringName(tower.get("owner_faction_id", &"player")) == &"player" and StringName(tower.get("facility_kind", FACILITY_WATCHTOWER)) == FACILITY_WATCHTOWER and StringName(tower.get("state", FACILITY_ACTIVE)) != FACILITY_DESTROYED:
			observers.append({"world_position": Vector2(tower.get("world_position", Vector2.ZERO)), "range": maxi(int(tower.get("visibility_range", 1)), 1)})
	for facility_id_value in watchtowers_by_id.keys():
		var facility := Dictionary(watchtowers_by_id[facility_id_value])
		if StringName(facility.get("owner_faction_id", &"player")) == &"player":
			continue
		for observer_value in observers:
			var observer: Dictionary = observer_value
			if Vector2(facility.get("world_position", Vector2.INF)).distance_to(Vector2(observer.world_position)) <= float(observer.range):
				var discovered: Array = Array(facility.get("discovered_by_faction_ids", []))
				if &"player" not in discovered:
					discovered.append(&"player")
					facility.discovered_by_faction_ids = discovered
					watchtowers_by_id[facility_id_value] = facility
				break
	for patrol_id_value in patrols_by_id:
		var patrol: Dictionary = Dictionary(patrols_by_id[patrol_id_value])
		var patrol_id := StringName(patrol_id_value)
		var patrol_position := Vector2(patrol.get("world_position", _point_position(StringName(patrol.get("current_point_id", &"")))))
		var visible := false
		for observer_value in observers:
			var observer: Dictionary = observer_value
			if patrol_position.distance_to(Vector2(observer.world_position)) <= float(observer.range):
				visible = true
				break
		var previous := Dictionary(intel_by_subject_id.get(patrol_id, {}))
		var previously_seen := StringName(previous.get("fog_state", FOG_UNOBSERVED)) in [FOG_VISIBLE, FOG_OBSERVED]
		intel_by_subject_id[patrol_id] = {
			"subject_id": patrol_id,
			"fog_state": FOG_VISIBLE if visible else (FOG_OBSERVED if previously_seen else FOG_UNOBSERVED),
			"last_known_point_id": StringName(patrol.get("current_point_id", &"")) if visible else StringName(previous.get("last_known_point_id", &"")),
			"last_known_world_position": Vector2i(patrol_position) if visible else Vector2i(previous.get("last_known_world_position", Vector2i.ZERO)),
			"last_observed_milliseconds": world_milliseconds if visible else int(previous.get("last_observed_milliseconds", 0)),
			"known_strength": int(patrol.get("strength", 0)) if visible else int(previous.get("known_strength", 0)),
		}
