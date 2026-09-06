class_name WarLoopState
extends RefCounted


const SCHEMA_VERSION := 1
const PHASE_IDLE := &"IDLE"
const PHASE_SIEGING := &"SIEGING"
const PHASE_OCCUPIED := &"OCCUPIED"
const PHASE_FAILED := &"FAILED"
const RESOLUTION_SURRENDER := &"SURRENDER"
const RESOLUTION_COMBAT := &"COMBAT"
const RESOLUTION_RETREAT := &"RETREAT"

var cities_by_id: Dictionary = {}
var required_city_ids: Dictionary = {}
var active_siege: Dictionary = {}
var completed_resolution_ids: Dictionary = {}
var next_siege_sequence := 1


func initialize_from_theater(theater_points: Dictionary) -> void:
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
	return is_enemy_city(city_id) and active_siege.is_empty()


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
	var city := get_city(city_id)
	if (
		city.is_empty() or not active_siege.is_empty() or attacker_count <= 0
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
	}
	return active_siege.duplicate(true)


func advance_siege(rules: WarLoopRules) -> Dictionary:
	if active_siege.is_empty() or StringName(active_siege.phase) != PHASE_SIEGING or rules == null:
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
		"completed_resolution_ids": completed_resolution_ids.duplicate(true),
		"next_siege_sequence": next_siege_sequence,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if (
		not _has_exact_keys(snapshot, [
			"schema_version", "cities_by_id", "required_city_ids", "active_siege",
			"completed_resolution_ids", "next_siege_sequence",
		])
		or int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION
		or typeof(snapshot.get("cities_by_id", null)) != TYPE_DICTIONARY
		or typeof(snapshot.get("required_city_ids", null)) != TYPE_DICTIONARY
		or typeof(snapshot.get("active_siege", null)) != TYPE_DICTIONARY
		or typeof(snapshot.get("completed_resolution_ids", null)) != TYPE_DICTIONARY
		or typeof(snapshot.get("next_siege_sequence", null)) != TYPE_INT
		or int(snapshot.get("next_siege_sequence", 0)) <= 0
		or not _has_valid_cities(Dictionary(snapshot.cities_by_id), Dictionary(snapshot.required_city_ids))
		or not _has_valid_completed_resolutions(Dictionary(snapshot.completed_resolution_ids))
		or not _has_valid_active_siege(Dictionary(snapshot.active_siege), Dictionary(snapshot.cities_by_id))
	):
		return false
	cities_by_id = Dictionary(snapshot.cities_by_id).duplicate(true)
	required_city_ids = Dictionary(snapshot.required_city_ids).duplicate(true)
	active_siege = Dictionary(snapshot.active_siege).duplicate(true)
	completed_resolution_ids = Dictionary(snapshot.completed_resolution_ids).duplicate(true)
	next_siege_sequence = int(snapshot.next_siege_sequence)
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
	):
		return false
	if int(siege.gate_hp) == 0 and not bool(siege.gate_breached):
		return false
	if StringName(siege.phase) == PHASE_SIEGING and StringName(siege.resolution) != &"":
		return false
	if StringName(siege.phase) != PHASE_SIEGING and StringName(siege.resolution) == &"":
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
