class_name WarLoopState
extends RefCounted


const SCHEMA_VERSION := 6
const PHASE_IDLE := &"IDLE"
const PHASE_SIEGING := &"SIEGING"
const PHASE_OCCUPIED := &"OCCUPIED"
const PHASE_FAILED := &"FAILED"
const RESOLUTION_SURRENDER := &"SURRENDER"
const RESOLUTION_COMBAT := &"COMBAT"
const RESOLUTION_RETREAT := &"RETREAT"
const WARTIME_HANDOFF_RESERVED := &"RESERVED"
const WARTIME_HANDOFF_ACTIVE := &"ACTIVE"
const WARTIME_HANDOFF_RESULT_PENDING := &"RESULT_PENDING"

var cities_by_id: Dictionary = {}
var required_city_ids: Dictionary = {}
var active_siege: Dictionary = {}
var parallel_sieges_by_city: Dictionary = {}
var completed_resolution_ids: Dictionary = {}
var next_siege_sequence := 1
var field_tactics: FieldTacticsState = FieldTacticsState.new()


func initialize_from_theater(
	theater_points: Dictionary,
	theater_routes: Dictionary = {},
	theater_water_regions: Array[Rect2i] = [],
	theater_world_bounds: Rect2i = Rect2i(-260, -180, 1520, 1040),
	theater_terrain_regions: Array[Dictionary] = [],
	theater_patrol_configs: Array[Dictionary] = [],
	theater_scout_visibility_range := 2,
	theater_watchtower_config: Dictionary = {}
) -> void:
	field_tactics.initialize_from_theater(
		theater_points, theater_routes, theater_water_regions, theater_world_bounds,
		theater_terrain_regions, theater_patrol_configs, theater_scout_visibility_range,
		theater_watchtower_config
	)
	if not cities_by_id.is_empty():
		return
	for point_id_value in theater_points:
		var point: Dictionary = theater_points[point_id_value]
		if StringName(point.get("point_kind", &"FRIENDLY_GARRISON")) != &"ENEMY_CITY":
			continue
		var city_id := StringName(point_id_value)
		cities_by_id[city_id] = {
			"city_id": city_id,
			"story_owner_faction_id": StringName(point.get("story_owner_faction_id", &"enemy")),
			"military_controller_faction_id": StringName(point.get("military_controller_faction_id", &"enemy")),
			"required_for_victory": bool(point.get("required_for_victory", false)),
			"surrender_allowed": bool(point.get("surrender_allowed", false)),
			"gate_hp": int(point.get("gate_hp", 0)),
			"defender_count": int(point.get("defender_count", 0)),
			"defender_hp_per_member": int(point.get("defender_hp_per_member", 1)),
			"defender_attack_per_member": int(point.get("defender_attack_per_member", 0)),
			"defender_armor_per_member": int(point.get("defender_armor_per_member", 0)),
			"occupation_resolution_id": &"",
		}
		if bool(point.get("required_for_victory", false)):
			required_city_ids[city_id] = true


func get_city(city_id: StringName) -> Dictionary:
	return Dictionary(cities_by_id.get(city_id, {})).duplicate(true)


func is_enemy_city(city_id: StringName) -> bool:
	var city := get_city(city_id)
	return not city.is_empty() and StringName(city.military_controller_faction_id) != &"player"


func can_issue_attack(city_id: StringName) -> bool:
	return is_enemy_city(city_id) and (
		(active_siege.is_empty() or StringName(active_siege.get("city_id", &"")) != city_id)
		and not parallel_sieges_by_city.has(city_id)
	)


func begin_siege(
	army_id: StringName,
	order_id: StringName,
	city_id: StringName,
	attacker_count: int,
	attacker_hp_per_member: int,
	attacker_attack_per_member: int,
	attacker_armor_per_member: int,
	attacker_quality_basis_points: int,
	rules: WarLoopRules
) -> Dictionary:
	if not active_siege.is_empty():
		if not can_issue_attack(city_id):
			return {}
		var primary := active_siege.duplicate(true)
		active_siege = {}
		var parallel := begin_siege(army_id, order_id, city_id, attacker_count, attacker_hp_per_member, attacker_attack_per_member, attacker_armor_per_member, attacker_quality_basis_points, rules)
		active_siege = primary
		if not parallel.is_empty():
			parallel_sieges_by_city[city_id] = parallel.duplicate(true)
		return parallel
	var city := get_city(city_id)
	if (
		city.is_empty() or attacker_count <= 0
		or attacker_hp_per_member <= 0 or attacker_attack_per_member < 0
		or attacker_armor_per_member < 0 or rules == null
	):
		return {}
	var siege_id := StringName("siege.%06d" % next_siege_sequence)
	next_siege_sequence += 1
	var defender_count := int(city.defender_count)
	var defender_hp_per_member := int(city.defender_hp_per_member)
	var attacker_quality := attacker_attack_per_member + attacker_armor_per_member + attacker_hp_per_member
	var defender_quality := int(city.defender_attack_per_member) + int(city.defender_armor_per_member) + defender_hp_per_member
	var surrendered := (
		bool(city.surrender_allowed)
		and attacker_count * 10000 >= defender_count * roundi(rules.surrender_minimum_force_ratio * 10000.0)
		and attacker_quality * 10000 >= defender_quality * roundi(rules.surrender_minimum_quality_ratio * 10000.0)
	)
	active_siege = {
		"siege_id": siege_id,
		"army_id": army_id,
		"order_id": order_id,
		"city_id": city_id,
		"phase": PHASE_OCCUPIED if surrendered else PHASE_SIEGING,
		"resolution": RESOLUTION_SURRENDER if surrendered else &"",
		"tick": 0,
		"attacker_initial_count": attacker_count,
		"attacker_hp_per_member": attacker_hp_per_member,
		"attacker_attack_per_member": attacker_attack_per_member,
		"attacker_armor_per_member": attacker_armor_per_member,
		"attacker_total_hp": attacker_count * attacker_hp_per_member,
		"gate_hp": int(city.gate_hp),
		"defender_initial_count": defender_count,
		"defender_hp_per_member": defender_hp_per_member,
		"defender_attack_per_member": int(city.defender_attack_per_member),
		"defender_armor_per_member": int(city.defender_armor_per_member),
		"defender_total_hp": defender_count * defender_hp_per_member,
		"gate_breached": int(city.gate_hp) <= 0,
		"surrender_checked_at_arrival": true,
		"surrender_checked_after_breach": false,
		"elapsed_remainder_milliseconds": 0,
		# This is only a durable ownership relation. The army, city and siege
		# facts remain the authoritative records above; the wartime instance may
		# temporarily become the sole simulator for this siege.
		"wartime_handoff": {},
	}
	return active_siege.duplicate(true)


func advance_siege(rules: WarLoopRules) -> Dictionary:
	if (
		active_siege.is_empty()
		or StringName(active_siege.phase) != PHASE_SIEGING
		or has_active_wartime_handoff(StringName(active_siege.get("city_id", &"")))
		or rules == null
	):
		return {}
	active_siege.tick = int(active_siege.tick) + 1
	var attacker_members := _alive_members(int(active_siege.attacker_total_hp), int(active_siege.attacker_hp_per_member))
	var defender_members := _alive_members(int(active_siege.defender_total_hp), int(active_siege.defender_hp_per_member))
	if attacker_members <= 0:
		active_siege.phase = PHASE_FAILED
		active_siege.resolution = RESOLUTION_COMBAT
		return active_siege.duplicate(true)
	var attacker_damage := maxi(1, attacker_members * int(active_siege.attacker_attack_per_member) * rules.attacker_damage_basis_points / 10000)
	if int(active_siege.gate_hp) > 0:
		active_siege.gate_hp = maxi(int(active_siege.gate_hp) - attacker_damage, 0)
		if int(active_siege.gate_hp) == 0:
			active_siege.gate_breached = true
			active_siege.surrender_checked_after_breach = true
	else:
		var mitigated := maxi(1, attacker_damage - int(active_siege.defender_armor_per_member))
		active_siege.defender_total_hp = maxi(int(active_siege.defender_total_hp) - mitigated, 0)
	if defender_members > 0:
		var defender_damage := maxi(1, defender_members * int(active_siege.defender_attack_per_member) * rules.defender_damage_basis_points / 10000)
		var attacker_mitigated := maxi(1, defender_damage - int(active_siege.attacker_armor_per_member))
		active_siege.attacker_total_hp = maxi(int(active_siege.attacker_total_hp) - attacker_mitigated, 0)
	if int(active_siege.attacker_total_hp) <= 0:
		active_siege.phase = PHASE_FAILED
		active_siege.resolution = RESOLUTION_COMBAT
	elif int(active_siege.defender_total_hp) == 0:
		active_siege.phase = PHASE_OCCUPIED
		active_siege.resolution = RESOLUTION_COMBAT
	return active_siege.duplicate(true)


func get_active_sieges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not active_siege.is_empty():
		result.append(active_siege.duplicate(true))
	for city_id_value in parallel_sieges_by_city:
		result.append(Dictionary(parallel_sieges_by_city[city_id_value]).duplicate(true))
	return result


# Siege identity is the transaction boundary.  `active_siege` is retained as a
# backwards-compatible primary projection; callers that run more than one
# battle must always address the city explicitly.
func get_siege(city_id: StringName) -> Dictionary:
	if StringName(active_siege.get("city_id", &"")) == city_id:
		return active_siege.duplicate(true)
	return Dictionary(parallel_sieges_by_city.get(city_id, {})).duplicate(true)


## Field medics stabilize only partial HP of currently living attackers. The
## ceiling is the existing survivor count, so this cannot recreate a casualty
## or bypass the city wounded/recovery owner.
func heal_siege_attacker(city_id: StringName, amount: int) -> Dictionary:
	var siege := get_siege(city_id)
	if siege.is_empty() or amount <= 0 or _wartime_handoff_blocks_field_mutation(siege):
		return {}
	var hp_per_member := maxi(int(siege.get("attacker_hp_per_member", 1)), 1)
	var current_hp := maxi(int(siege.get("attacker_total_hp", 0)), 0)
	var living_members := _alive_members(current_hp, hp_per_member)
	var maximum_hp := living_members * hp_per_member
	var healed := mini(amount, maxi(maximum_hp - current_hp, 0))
	if healed <= 0:
		return {}
	siege.attacker_total_hp = current_hp + healed
	_write_siege(city_id, siege)
	return {"city_id": city_id, "healed_hp": healed, "attacker_total_hp": int(siege.attacker_total_hp)}


func _wartime_handoff_blocks_field_mutation(siege: Dictionary) -> bool:
	var handoff := Dictionary(siege.get("wartime_handoff", {}))
	return StringName(handoff.get("phase", &"")) in [
		WARTIME_HANDOFF_RESERVED, WARTIME_HANDOFF_ACTIVE, WARTIME_HANDOFF_RESULT_PENDING,
	]


func advance_siege_at(city_id: StringName, rules: WarLoopRules) -> Dictionary:
	if city_id == &"":
		return {}
	if StringName(active_siege.get("city_id", &"")) == city_id:
		return advance_siege(rules)
	var parallel := Dictionary(parallel_sieges_by_city.get(city_id, {})).duplicate(true)
	if parallel.is_empty():
		return {}
	var primary := active_siege.duplicate(true)
	active_siege = parallel
	var result := advance_siege(rules)
	parallel_sieges_by_city[city_id] = active_siege.duplicate(true)
	active_siege = primary
	return result


func mark_retreat_at(city_id: StringName, rules: WarLoopRules) -> Dictionary:
	if StringName(active_siege.get("city_id", &"")) == city_id:
		return mark_retreat(rules)
	var parallel := Dictionary(parallel_sieges_by_city.get(city_id, {})).duplicate(true)
	if parallel.is_empty():
		return {}
	var primary := active_siege.duplicate(true)
	active_siege = parallel
	var result := mark_retreat(rules)
	parallel_sieges_by_city[city_id] = active_siege.duplicate(true)
	active_siege = primary
	return result


func occupy_siege(city_id: StringName, resolution_id: StringName) -> Dictionary:
	if StringName(active_siege.get("city_id", &"")) == city_id:
		return occupy_active_city(resolution_id)
	var parallel := Dictionary(parallel_sieges_by_city.get(city_id, {})).duplicate(true)
	if parallel.is_empty():
		return {}
	var primary := active_siege.duplicate(true)
	active_siege = parallel
	var result := occupy_active_city(resolution_id)
	parallel_sieges_by_city.erase(city_id)
	active_siege = primary
	return result


func close_failed_siege_at(city_id: StringName, resolution_id: StringName) -> Dictionary:
	if StringName(active_siege.get("city_id", &"")) == city_id:
		return close_failed_siege(resolution_id)
	var parallel := Dictionary(parallel_sieges_by_city.get(city_id, {})).duplicate(true)
	if parallel.is_empty():
		return {}
	var primary := active_siege.duplicate(true)
	active_siege = parallel
	var result := close_failed_siege(resolution_id)
	parallel_sieges_by_city.erase(city_id)
	active_siege = primary
	return result


func advance_siege_elapsed(city_id: StringName, elapsed_milliseconds: int, rules: WarLoopRules) -> Array[Dictionary]:
	var siege := get_siege(city_id)
	if (
		siege.is_empty()
		or StringName(siege.get("phase", &"")) != PHASE_SIEGING
		or has_active_wartime_handoff(city_id)
		or elapsed_milliseconds <= 0
		or rules == null
	):
		return []
	var accumulated := int(siege.get("elapsed_remainder_milliseconds", 0)) + elapsed_milliseconds
	var ticks := accumulated / rules.combat_tick_milliseconds
	siege.elapsed_remainder_milliseconds = accumulated % rules.combat_tick_milliseconds
	_write_siege(city_id, siege)
	var results: Array[Dictionary] = []
	for _tick in range(ticks):
		var result := advance_siege_at(city_id, rules)
		if result.is_empty():
			break
		results.append(result)
		if StringName(result.get("phase", &"")) != PHASE_SIEGING:
			break
	return results


func _write_siege(city_id: StringName, siege: Dictionary) -> void:
	if StringName(active_siege.get("city_id", &"")) == city_id:
		active_siege = siege.duplicate(true)
	elif parallel_sieges_by_city.has(city_id):
		parallel_sieges_by_city[city_id] = siege.duplicate(true)


func begin_wartime_handoff(
	city_id: StringName,
	transaction_id: StringName,
	battle_request_snapshot: Dictionary
) -> Dictionary:
	var siege := get_siege(city_id)
	if (
		siege.is_empty()
		or transaction_id == &""
		or battle_request_snapshot.is_empty()
		or StringName(siege.get("phase", &"")) != PHASE_SIEGING
		or not Dictionary(siege.get("wartime_handoff", {})).is_empty()
	):
		return {}
	siege.wartime_handoff = {
		"transaction_id": transaction_id,
		"phase": WARTIME_HANDOFF_RESERVED,
		"result_id": &"",
		"battle_session_snapshot": {},
		"result_authority_snapshot": {},
		"battle_request_snapshot": battle_request_snapshot.duplicate(true),
		"terminal_combat_state": {},
	}
	_write_siege(city_id, siege)
	return siege.duplicate(true)


func set_wartime_handoff_phase(
	city_id: StringName,
	transaction_id: StringName,
	phase: StringName
) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or transaction_id == &""
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or phase not in [WARTIME_HANDOFF_ACTIVE, WARTIME_HANDOFF_RESULT_PENDING]
	):
		return {}
	var current_phase := StringName(handoff.get("phase", &""))
	if (
		(current_phase == WARTIME_HANDOFF_RESERVED and phase != WARTIME_HANDOFF_ACTIVE)
		or (current_phase == WARTIME_HANDOFF_ACTIVE and phase != WARTIME_HANDOFF_RESULT_PENDING)
		or current_phase == WARTIME_HANDOFF_RESULT_PENDING
	):
		return {}
	handoff.phase = phase
	siege.wartime_handoff = handoff
	_write_siege(city_id, siege)
	return siege.duplicate(true)


## The terminal authority is kept beside the takeover link, not in a second
## combat ledger.  A process may die after terminal simulation but before the
## one permitted macro writeback; retaining this record makes that state
## resumable and prevents replaying the battle to manufacture a new result.
func mark_wartime_handoff_result_pending(
	city_id: StringName,
	transaction_id: StringName,
	result_authority_snapshot: Dictionary,
	terminal_combat_state: Dictionary
) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or result_authority_snapshot.is_empty()
		or terminal_combat_state.is_empty()
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WARTIME_HANDOFF_ACTIVE
	):
		return {}
	handoff.phase = WARTIME_HANDOFF_RESULT_PENDING
	handoff.result_authority_snapshot = result_authority_snapshot.duplicate(true)
	handoff.terminal_combat_state = terminal_combat_state.duplicate(true)
	siege.wartime_handoff = handoff
	_write_siege(city_id, siege)
	return siege.duplicate(true)


## Schema-five handoffs were created before their immutable request had a
## dedicated persisted home.  Existing active sessions may materialize that
## missing fact once during migration; all newly-created handoffs start with it.
func materialize_legacy_wartime_request(
	city_id: StringName,
	transaction_id: StringName,
	battle_request_snapshot: Dictionary
) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or battle_request_snapshot.is_empty()
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or not Dictionary(handoff.get("battle_request_snapshot", {})).is_empty()
	):
		return {}
	handoff.battle_request_snapshot = battle_request_snapshot.duplicate(true)
	siege.wartime_handoff = handoff
	_write_siege(city_id, siege)
	return siege.duplicate(true)


## A reserved macro takeover owns one immutable request snapshot.  Facility
## planning is the one allowed pre-activation amendment: it replaces that
## snapshot atomically before the battle session exists, never a second army
## or resource ledger.
func replace_reserved_wartime_request_snapshot(
	city_id: StringName,
	transaction_id: StringName,
	battle_request_snapshot: Dictionary
) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or transaction_id == &""
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WARTIME_HANDOFF_RESERVED
		or not Dictionary(handoff.get("battle_session_snapshot", {})).is_empty()
		or not Dictionary(handoff.get("result_authority_snapshot", {})).is_empty()
		or not Dictionary(handoff.get("terminal_combat_state", {})).is_empty()
		or not _has_valid_wartime_request_snapshot(battle_request_snapshot, transaction_id)
	):
		return {}
	handoff.battle_request_snapshot = battle_request_snapshot.duplicate(true)
	siege.wartime_handoff = handoff
	_write_siege(city_id, siege)
	return siege.duplicate(true)


func checkpoint_wartime_handoff_session(
	city_id: StringName,
	transaction_id: StringName,
	session_snapshot: Dictionary
) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or session_snapshot.is_empty()
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) not in [WARTIME_HANDOFF_ACTIVE, WARTIME_HANDOFF_RESULT_PENDING]
	):
		return {}
	handoff.battle_session_snapshot = session_snapshot.duplicate(true)
	siege.wartime_handoff = handoff
	_write_siege(city_id, siege)
	return siege.duplicate(true)


func resolve_wartime_handoff(
	city_id: StringName,
	transaction_id: StringName,
	result_id: StringName,
	victory: bool,
	retreated: bool,
	attacker_total_hp: int,
	defender_total_hp: int,
	gate_hp: int
) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or result_id == &""
		or attacker_total_hp < 0
		or defender_total_hp < 0
		or gate_hp < 0
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WARTIME_HANDOFF_RESULT_PENDING
	):
		return {}
	siege.attacker_total_hp = attacker_total_hp
	siege.defender_total_hp = defender_total_hp
	siege.gate_hp = gate_hp
	siege.gate_breached = gate_hp == 0
	if victory:
		siege.phase = PHASE_OCCUPIED
		siege.resolution = RESOLUTION_COMBAT
	else:
		siege.phase = PHASE_FAILED
		siege.resolution = RESOLUTION_RETREAT if retreated else RESOLUTION_COMBAT
	handoff.result_id = result_id
	siege.wartime_handoff = handoff
	_write_siege(city_id, siege)
	return siege.duplicate(true)


func get_wartime_handoff(city_id: StringName) -> Dictionary:
	return Dictionary(get_siege(city_id).get("wartime_handoff", {})).duplicate(true)


func cancel_reserved_wartime_handoff(city_id: StringName, transaction_id: StringName) -> Dictionary:
	var siege := get_siege(city_id)
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	if (
		siege.is_empty()
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WARTIME_HANDOFF_RESERVED
		or not Dictionary(handoff.get("battle_session_snapshot", {})).is_empty()
	):
		return {}
	siege.wartime_handoff = {}
	_write_siege(city_id, siege)
	return siege.duplicate(true)


func has_active_wartime_handoff(city_id: StringName) -> bool:
	var handoff := get_wartime_handoff(city_id)
	return StringName(handoff.get("phase", &"")) in [
		WARTIME_HANDOFF_RESERVED,
		WARTIME_HANDOFF_ACTIVE,
		WARTIME_HANDOFF_RESULT_PENDING,
	]


func advance_parallel_sieges(rules: WarLoopRules) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var primary := active_siege.duplicate(true)
	if not primary.is_empty():
		var primary_result := advance_siege(rules)
		if not primary_result.is_empty():
			results.append(primary_result)
		primary = active_siege.duplicate(true)
	for city_id_value in parallel_sieges_by_city.keys():
		var city_id := StringName(city_id_value)
		active_siege = Dictionary(parallel_sieges_by_city[city_id]).duplicate(true)
		var result := advance_siege(rules)
		parallel_sieges_by_city[city_id] = active_siege.duplicate(true)
		if not result.is_empty():
			results.append(result)
	active_siege = primary
	return results


func mark_retreat(rules: WarLoopRules) -> Dictionary:
	if active_siege.is_empty() or StringName(active_siege.phase) != PHASE_SIEGING or rules == null:
		return {}
	var alive_before_retreat := _alive_members(
		int(active_siege.attacker_total_hp), int(active_siege.attacker_hp_per_member)
	)
	var retreat_loss := mini(alive_before_retreat, maxi(
		rules.retreat_minimum_loss,
		ceili(float(alive_before_retreat) * float(rules.retreat_loss_basis_points) / 10000.0)
	))
	active_siege.attacker_total_hp = maxi(
		int(active_siege.attacker_total_hp) - retreat_loss * int(active_siege.attacker_hp_per_member),
		0
	)
	active_siege.phase = PHASE_FAILED
	active_siege.resolution = RESOLUTION_RETREAT
	return active_siege.duplicate(true)


func occupy_active_city(resolution_id: StringName) -> Dictionary:
	if (
		active_siege.is_empty() or StringName(active_siege.phase) != PHASE_OCCUPIED
		or resolution_id == &"" or completed_resolution_ids.has(resolution_id)
	):
		return {}
	var city_id := StringName(active_siege.city_id)
	var city := get_city(city_id)
	if city.is_empty():
		return {}
	city.military_controller_faction_id = &"player"
	city.gate_hp = int(active_siege.gate_hp)
	city.defender_count = 0
	city.occupation_resolution_id = resolution_id
	cities_by_id[city_id] = city
	completed_resolution_ids[resolution_id] = true
	var result := active_siege.duplicate(true)
	active_siege = {}
	return result


func close_failed_siege(resolution_id: StringName) -> Dictionary:
	if active_siege.is_empty() or StringName(active_siege.phase) != PHASE_FAILED or resolution_id == &"":
		return {}
	if completed_resolution_ids.has(resolution_id):
		return {}
	var city_id := StringName(active_siege.city_id)
	var city := get_city(city_id)
	if city.is_empty():
		return {}
	city.gate_hp = int(active_siege.gate_hp)
	city.defender_count = _alive_members(
		int(active_siege.defender_total_hp), int(active_siege.defender_hp_per_member)
	)
	cities_by_id[city_id] = city
	completed_resolution_ids[resolution_id] = true
	var result := active_siege.duplicate(true)
	active_siege = {}
	return result


func is_level_cleared() -> bool:
	if required_city_ids.is_empty():
		return false
	for city_id in required_city_ids:
		var city := get_city(StringName(city_id))
		if StringName(city.get("military_controller_faction_id", &"enemy")) != &"player":
			return false
	return true


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"cities_by_id": cities_by_id.duplicate(true),
		"required_city_ids": required_city_ids.duplicate(true),
		"active_siege": active_siege.duplicate(true),
		"parallel_sieges_by_city": parallel_sieges_by_city.duplicate(true),
		"completed_resolution_ids": completed_resolution_ids.duplicate(true),
		"next_siege_sequence": next_siege_sequence,
		"field_tactics": field_tactics.get_snapshot(),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var normalized := snapshot.duplicate(true)
	if int(normalized.get("schema_version", 0)) in [3, 4, 5]:
		if not _has_exact_keys(normalized, [
			"schema_version", "cities_by_id", "required_city_ids", "active_siege",
			"completed_resolution_ids", "next_siege_sequence", "field_tactics", "parallel_sieges_by_city",
		]):
			return false
		_normalize_wartime_handoff_migration(Dictionary(normalized.active_siege))
		for city_id_value in Dictionary(normalized.parallel_sieges_by_city):
			var parallel_value = normalized.parallel_sieges_by_city[city_id_value]
			if not parallel_value is Dictionary:
				return false
			_normalize_wartime_handoff_migration(Dictionary(parallel_value))
		normalized.schema_version = SCHEMA_VERSION
	if int(normalized.get("schema_version", 0)) in [1, 2]:
		if not _has_exact_keys(normalized, [
			"schema_version", "cities_by_id", "required_city_ids", "active_siege",
			"completed_resolution_ids", "next_siege_sequence",
		]):
			if int(normalized.get("schema_version", 0)) == 2 and _has_exact_keys(normalized, [
				"schema_version", "cities_by_id", "required_city_ids", "active_siege",
				"completed_resolution_ids", "next_siege_sequence", "field_tactics",
			]):
				normalized.parallel_sieges_by_city = {}
			else:
				return false
		normalized.schema_version = SCHEMA_VERSION
		if int(snapshot.get("schema_version", 0)) == 1:
			normalized.field_tactics = FieldTacticsState.new().get_snapshot()
			normalized.parallel_sieges_by_city = {}
		_normalize_wartime_handoff_migration(Dictionary(normalized.active_siege))
		for city_id_value in Dictionary(normalized.parallel_sieges_by_city):
			_normalize_wartime_handoff_migration(Dictionary(normalized.parallel_sieges_by_city[city_id_value]))
	if (
		not _has_exact_keys(normalized, [
			"schema_version", "cities_by_id", "required_city_ids", "active_siege",
			"completed_resolution_ids", "next_siege_sequence", "field_tactics", "parallel_sieges_by_city",
		])
		or int(normalized.get("schema_version", 0)) != SCHEMA_VERSION
		or typeof(normalized.get("cities_by_id", null)) != TYPE_DICTIONARY
		or typeof(normalized.get("required_city_ids", null)) != TYPE_DICTIONARY
		or typeof(normalized.get("active_siege", null)) != TYPE_DICTIONARY
		or typeof(normalized.get("completed_resolution_ids", null)) != TYPE_DICTIONARY
		or typeof(normalized.get("next_siege_sequence", null)) != TYPE_INT
		or typeof(normalized.get("field_tactics", null)) != TYPE_DICTIONARY
		or typeof(normalized.get("parallel_sieges_by_city", null)) != TYPE_DICTIONARY
		or int(normalized.get("next_siege_sequence", 0)) <= 0
		or not _has_valid_cities(Dictionary(normalized.cities_by_id), Dictionary(normalized.required_city_ids))
		or not _has_valid_completed_resolutions(Dictionary(normalized.completed_resolution_ids))
		or not _has_valid_active_siege(Dictionary(normalized.active_siege), Dictionary(normalized.cities_by_id))
		or not _has_valid_parallel_sieges(Dictionary(normalized.parallel_sieges_by_city), Dictionary(normalized.cities_by_id), Dictionary(normalized.active_siege))
	):
		return false
	var restored_field_tactics := FieldTacticsState.new()
	if not restored_field_tactics.restore_snapshot(Dictionary(normalized.field_tactics)):
		return false
	cities_by_id = Dictionary(normalized.cities_by_id).duplicate(true)
	required_city_ids = Dictionary(normalized.required_city_ids).duplicate(true)
	active_siege = Dictionary(normalized.active_siege).duplicate(true)
	parallel_sieges_by_city = Dictionary(normalized.parallel_sieges_by_city).duplicate(true)
	completed_resolution_ids = Dictionary(normalized.completed_resolution_ids).duplicate(true)
	next_siege_sequence = int(normalized.next_siege_sequence)
	field_tactics = restored_field_tactics
	return true


static func _has_valid_cities(cities: Dictionary, required: Dictionary) -> bool:
	if cities.is_empty():
		# A migrated pre-war V6 campaign has no external theatre facts yet. It is
		# valid only as the paired empty record, and initialize_from_theater will
		# populate it on first use.
		return required.is_empty()
	var expected_city_keys := [
		"city_id", "story_owner_faction_id", "military_controller_faction_id",
		"required_for_victory", "surrender_allowed", "gate_hp", "defender_count",
		"defender_hp_per_member", "defender_attack_per_member", "defender_armor_per_member",
		"occupation_resolution_id",
	]
	for city_id_value in cities:
		var city_id := StringName(city_id_value)
		var city_value = cities[city_id_value]
		if city_id == &"" or not city_value is Dictionary:
			return false
		var city: Dictionary = city_value
		if (
			not _has_exact_keys(city, expected_city_keys)
			or StringName(city.get("city_id", &"")) != city_id
			or typeof(city.get("story_owner_faction_id", null)) != TYPE_STRING_NAME
			or StringName(city.story_owner_faction_id) == &""
			or typeof(city.get("military_controller_faction_id", null)) != TYPE_STRING_NAME
			or StringName(city.military_controller_faction_id) == &""
			or typeof(city.get("required_for_victory", null)) != TYPE_BOOL
			or typeof(city.get("surrender_allowed", null)) != TYPE_BOOL
			or not _is_non_negative_int(city.get("gate_hp", null))
			or not _is_non_negative_int(city.get("defender_count", null))
			or not _is_positive_int(city.get("defender_hp_per_member", null))
			or not _is_non_negative_int(city.get("defender_attack_per_member", null))
			or not _is_non_negative_int(city.get("defender_armor_per_member", null))
			or typeof(city.get("occupation_resolution_id", null)) != TYPE_STRING_NAME
		):
			return false
		if bool(city.required_for_victory) != bool(required.get(city_id, false)):
			return false
	for required_city_id_value in required:
		var required_city_id := StringName(required_city_id_value)
		if required_city_id == &"" or not cities.has(required_city_id) or required[required_city_id_value] != true:
			return false
	return true


static func _has_valid_completed_resolutions(resolutions: Dictionary) -> bool:
	for resolution_id_value in resolutions:
		if StringName(resolution_id_value) == &"" or resolutions[resolution_id_value] != true:
			return false
	return true


static func _has_valid_active_siege(siege: Dictionary, cities: Dictionary) -> bool:
	if siege.is_empty():
		return true
	var expected_siege_keys := [
		"siege_id", "army_id", "order_id", "city_id", "phase", "resolution", "tick",
		"attacker_initial_count", "attacker_hp_per_member", "attacker_attack_per_member",
		"attacker_armor_per_member", "attacker_total_hp", "gate_hp", "defender_initial_count",
		"defender_hp_per_member", "defender_attack_per_member", "defender_armor_per_member",
		"defender_total_hp", "gate_breached", "surrender_checked_at_arrival",
		"surrender_checked_after_breach", "elapsed_remainder_milliseconds",
		"wartime_handoff",
	]
	if not _has_exact_keys(siege, expected_siege_keys):
		return false
	var city_id := StringName(siege.get("city_id", &""))
	if (
		StringName(siege.get("siege_id", &"")) == &""
		or StringName(siege.get("army_id", &"")) == &""
		or StringName(siege.get("order_id", &"")) == &""
		or city_id == &"" or not cities.has(city_id)
		or StringName(Dictionary(cities[city_id]).get("military_controller_faction_id", &"")) == &"player"
		or StringName(siege.get("phase", &"")) not in [PHASE_SIEGING, PHASE_OCCUPIED, PHASE_FAILED]
		or StringName(siege.get("resolution", &"")) not in [&"", RESOLUTION_SURRENDER, RESOLUTION_COMBAT, RESOLUTION_RETREAT]
		or not _is_non_negative_int(siege.get("tick", null))
		or not _is_positive_int(siege.get("attacker_initial_count", null))
		or not _is_positive_int(siege.get("attacker_hp_per_member", null))
		or not _is_non_negative_int(siege.get("attacker_attack_per_member", null))
		or not _is_non_negative_int(siege.get("attacker_armor_per_member", null))
		or not _is_non_negative_int(siege.get("attacker_total_hp", null))
		or not _is_non_negative_int(siege.get("gate_hp", null))
		or not _is_non_negative_int(siege.get("defender_initial_count", null))
		or not _is_positive_int(siege.get("defender_hp_per_member", null))
		or not _is_non_negative_int(siege.get("defender_attack_per_member", null))
		or not _is_non_negative_int(siege.get("defender_armor_per_member", null))
		or not _is_non_negative_int(siege.get("defender_total_hp", null))
		or typeof(siege.get("gate_breached", null)) != TYPE_BOOL
		or typeof(siege.get("surrender_checked_at_arrival", null)) != TYPE_BOOL
		or typeof(siege.get("surrender_checked_after_breach", null)) != TYPE_BOOL
		or not _is_non_negative_int(siege.get("elapsed_remainder_milliseconds", null))
		or not _has_valid_wartime_handoff(Dictionary(siege.get("wartime_handoff", {})))
	):
		return false
	if int(siege.gate_hp) == 0 and not bool(siege.gate_breached):
		return false
	if StringName(siege.phase) == PHASE_SIEGING and StringName(siege.resolution) != &"":
		return false
	if StringName(siege.phase) != PHASE_SIEGING and StringName(siege.resolution) == &"":
		return false
	return true


static func _normalize_wartime_handoff_migration(siege: Dictionary) -> void:
	if siege.is_empty():
		return
	if not siege.has("wartime_handoff"):
		siege.wartime_handoff = {}
		return
	var handoff_value = siege.get("wartime_handoff", {})
	if handoff_value is Dictionary and not Dictionary(handoff_value).is_empty():
		var handoff: Dictionary = Dictionary(handoff_value)
		if not handoff.has("result_authority_snapshot"):
			handoff.result_authority_snapshot = {}
		if not handoff.has("battle_request_snapshot"):
			handoff.battle_request_snapshot = {}
		if not handoff.has("terminal_combat_state"):
			handoff.terminal_combat_state = {}
		# Schema-five RESULT_PENDING records contain an authoritative terminal
		# result but predate exact HP persistence. Derive the same rounded values
		# that that release would have written back once, mark no new result, and
		# let the first schema-six save make the compatibility fact durable.
		if (
			StringName(handoff.get("phase", &"")) == WARTIME_HANDOFF_RESULT_PENDING
			and Dictionary(handoff.get("terminal_combat_state", {})).is_empty()
		):
			var legacy_result := BattleResult.from_authority_snapshot(
				Dictionary(handoff.get("result_authority_snapshot", {}))
			)
			if legacy_result.is_consistent():
				var defender_remaining := maxi(
					int(siege.get("defender_initial_count", 0)) - legacy_result.enemy_casualties,
					0
				)
				handoff.terminal_combat_state = {
					"attacker_total_hp": legacy_result.survivor_count * int(siege.get("attacker_hp_per_member", 1)),
					"defender_total_hp": defender_remaining * int(siege.get("defender_hp_per_member", 1)),
					"gate_hp": 0 if legacy_result.outcome == BattleOutcome.Value.VICTORY else int(siege.get("gate_hp", 0)),
				}
		siege.wartime_handoff = handoff


static func _has_valid_wartime_handoff(handoff: Dictionary) -> bool:
	if handoff.is_empty():
		return true
	if not _has_exact_keys(handoff, [
		"transaction_id", "phase", "result_id", "battle_session_snapshot",
		"result_authority_snapshot", "battle_request_snapshot", "terminal_combat_state",
	]):
		return false
	var phase := StringName(handoff.get("phase", &""))
	if not (
		typeof(handoff.get("transaction_id", null)) == TYPE_STRING_NAME
		and StringName(handoff.get("transaction_id", &"")) != &""
		and typeof(handoff.get("phase", null)) == TYPE_STRING_NAME
		and phase in [
			WARTIME_HANDOFF_RESERVED,
			WARTIME_HANDOFF_ACTIVE,
			WARTIME_HANDOFF_RESULT_PENDING,
		]
		and typeof(handoff.get("result_id", null)) == TYPE_STRING_NAME
		and typeof(handoff.get("battle_session_snapshot", null)) == TYPE_DICTIONARY
		and typeof(handoff.get("result_authority_snapshot", null)) == TYPE_DICTIONARY
		and typeof(handoff.get("battle_request_snapshot", null)) == TYPE_DICTIONARY
		and typeof(handoff.get("terminal_combat_state", null)) == TYPE_DICTIONARY
	):
		return false
	var result_snapshot: Dictionary = Dictionary(handoff.result_authority_snapshot)
	var terminal_state: Dictionary = Dictionary(handoff.terminal_combat_state)
	if not _has_valid_wartime_request_snapshot(
		Dictionary(handoff.battle_request_snapshot), StringName(handoff.transaction_id)
	):
		return false
	if phase != WARTIME_HANDOFF_RESULT_PENDING:
		return result_snapshot.is_empty() and terminal_state.is_empty()
	if result_snapshot.is_empty():
		return false
	if not _has_valid_wartime_terminal_state(terminal_state):
		return false
	var result := BattleResult.from_authority_snapshot(result_snapshot)
	return (
		result.is_consistent()
		and result.transaction_id == StringName(handoff.transaction_id)
		and result.session_id == StringName("%s-session" % handoff.transaction_id)
	)


static func _has_valid_wartime_terminal_state(state: Dictionary) -> bool:
	return (
		_has_exact_keys(state, ["attacker_total_hp", "defender_total_hp", "gate_hp"])
		and _is_non_negative_int(state.get("attacker_total_hp", null))
		and _is_non_negative_int(state.get("defender_total_hp", null))
		and _is_non_negative_int(state.get("gate_hp", null))
	)


## An empty request snapshot is accepted only for a migrated schema-five
## handoff. ConstructionController materializes it once and persists it before
## reopening C0. Any non-empty value is checked here so malformed saves never
## reach the scene bridge as apparently-valid combat facts.
static func _has_valid_wartime_request_snapshot(
	snapshot: Dictionary,
	transaction_id: StringName
) -> bool:
	if snapshot.is_empty():
		return true
	if not _has_exact_keys(snapshot, [
		"level_id", "created_day", "committed_force_snapshot", "enemy_force_snapshot",
		"city_defense_snapshot", "first_clear_key", "wartime_facility_plan", "macro_siege_start_state",
	]):
		return false
	if (
		typeof(snapshot.get("level_id", null)) != TYPE_STRING_NAME
		or StringName(snapshot.get("level_id", &"")) == &""
		or not _is_positive_int(snapshot.get("created_day", null))
		or typeof(snapshot.get("committed_force_snapshot", null)) != TYPE_DICTIONARY
		or typeof(snapshot.get("enemy_force_snapshot", null)) != TYPE_DICTIONARY
		or not _is_non_negative_int(snapshot.get("city_defense_snapshot", null))
		or typeof(snapshot.get("first_clear_key", null)) != TYPE_STRING_NAME
		or StringName(snapshot.get("first_clear_key", &"")) == &""
		or typeof(snapshot.get("wartime_facility_plan", null)) != TYPE_DICTIONARY
		or not _has_valid_wartime_terminal_state(Dictionary(snapshot.get("macro_siege_start_state", {})))
	):
		return false
	var committed := CommittedForceSnapshot.from_dictionary(
		Dictionary(snapshot.committed_force_snapshot)
	)
	var enemy := EnemyForceSnapshot.from_dictionary(Dictionary(snapshot.enemy_force_snapshot))
	return (
		committed != null
		and enemy != null
		and committed.transaction_id == transaction_id
		and enemy.transaction_id == transaction_id
		# This snapshot belongs exclusively to a macro-siege takeover. Keep the
		# source-specific facility boundary at restoration rather than making the
		# generic request object reject a not-yet-activated defense request.
		and bool(WartimeFacilityPlan.validate_for_source(
			Dictionary(snapshot.wartime_facility_plan),
			BattleRequest.SOURCE_MACRO_SIEGE
		).valid)
	)


static func _has_valid_parallel_sieges(parallel: Dictionary, cities: Dictionary, primary: Dictionary) -> bool:
	for city_id_value in parallel:
		var city_id := StringName(city_id_value)
		var siege_value = parallel[city_id_value]
		if (
			city_id == &"" or not siege_value is Dictionary
			or city_id == StringName(primary.get("city_id", &""))
			or not _has_valid_active_siege(Dictionary(siege_value), cities)
			or StringName(Dictionary(siege_value).get("city_id", &"")) != city_id
		):
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(key):
			return false
	return true


static func _is_non_negative_int(value) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0


static func _is_positive_int(value) -> bool:
	return typeof(value) == TYPE_INT and int(value) > 0




static func _alive_members(total_hp: int, hp_per_member: int) -> int:
	return ceili(float(maxi(total_hp, 0)) / float(maxi(hp_per_member, 1)))
