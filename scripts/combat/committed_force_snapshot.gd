class_name CommittedForceSnapshot
extends RefCounted


const FRONT_ROUTE := &"FRONT_GATE"
const SIDE_ROUTE := &"SIDE_GATE"
const MAX_SQUADS := 3

var transaction_id: StringName
var unit_role_id: StringName
var hp_per_member: int
var attack_per_member: int
var armor_per_member: int
var move_speed_fixed: int
var selected_general_id: StringName
var researched_tech_ids: Array[StringName] = []
var attack_basis_points := 10000
var defense_basis_points := 10000
var supply_basis_points := 10000
var squads: Array[Dictionary] = []


static func create_default(
	transaction_id_value: StringName,
	committed_total: int,
	unit_role: UnitRole,
	general_id: StringName,
	tech_ids: Array[StringName],
	attack_multiplier: float,
	defense_multiplier: float,
	supply_shortage: bool
) -> CommittedForceSnapshot:
	if (
		transaction_id_value == &""
		or committed_total <= 0
		or unit_role == null
	):
		return null

	var squad_count := mini(MAX_SQUADS, committed_total)
	var base_size := floori(float(committed_total) / float(squad_count))
	var remainder := committed_total % squad_count
	var formations: Array[Dictionary] = []
	for index in range(squad_count):
		formations.append({
			"formation_id": StringName("transient.squad.%d" % (index + 1)),
			"display_name": _default_squad_name(index + 1),
			"definition_id": unit_role.role_id,
			"member_count": base_size + (1 if index < remainder else 0),
			"max_members": base_size + (1 if index < remainder else 0),
			"squad_id": index + 1,
			"route_id": FRONT_ROUTE if index % 2 == 0 else SIDE_ROUTE,
		})
	return create_from_formations(
		transaction_id_value,
		formations,
		unit_role,
		general_id,
		tech_ids,
		attack_multiplier,
		defense_multiplier,
		supply_shortage
	)


static func create_from_formations(
	transaction_id_value: StringName,
	formation_snapshots: Array,
	unit_role: UnitRole,
	general_id: StringName,
	tech_ids: Array[StringName],
	attack_multiplier: float,
	defense_multiplier: float,
	supply_shortage: bool
) -> CommittedForceSnapshot:
	if (
		transaction_id_value == &""
		or formation_snapshots.is_empty()
		or formation_snapshots.size() > MAX_SQUADS
		or unit_role == null
	):
		return null
	var snapshot := CommittedForceSnapshot.new()
	snapshot.transaction_id = transaction_id_value
	snapshot.unit_role_id = unit_role.role_id
	snapshot.hp_per_member = unit_role.hp
	snapshot.attack_per_member = unit_role.attack
	snapshot.armor_per_member = unit_role.armor
	snapshot.move_speed_fixed = roundi(unit_role.move_speed * 16.0)
	snapshot.selected_general_id = general_id
	snapshot.researched_tech_ids.assign(tech_ids)
	snapshot.attack_basis_points = roundi(attack_multiplier * 10000.0)
	snapshot.defense_basis_points = roundi(defense_multiplier * 10000.0)
	snapshot.supply_basis_points = 9000 if supply_shortage else 10000
	var seen_formations: Dictionary = {}
	var seen_squads: Dictionary = {}
	for formation_value in formation_snapshots:
		if not formation_value is Dictionary:
			return null
		var formation: Dictionary = formation_value
		var formation_id := StringName(formation.get("formation_id", &""))
		var definition_id := StringName(formation.get("definition_id", &""))
		var squad_id := int(formation.get("squad_id", 0))
		var initial_members := int(formation.get("member_count", 0))
		var route_id := StringName(formation.get("route_id", &""))
		if (
			formation_id == &""
			or seen_formations.has(formation_id)
			or definition_id != unit_role.role_id
			or squad_id <= 0
			or seen_squads.has(squad_id)
			or initial_members <= 0
			or route_id not in [FRONT_ROUTE, SIDE_ROUTE]
		):
			return null
		seen_formations[formation_id] = true
		seen_squads[squad_id] = true
		snapshot.squads.append({
			"squad_id": squad_id,
			"formation_id": formation_id,
			"display_name": str(formation.get("display_name", _default_squad_name(squad_id))),
			"initial_members": initial_members,
			"route_id": route_id,
		})
	return snapshot


func get_committed_total() -> int:
	var total := 0
	for squad in squads:
		total += int(squad.initial_members)
	return total


func get_digest() -> String:
	var parts: Array[String] = [
		str(transaction_id),
		str(unit_role_id),
		str(hp_per_member),
		str(attack_per_member),
		str(armor_per_member),
		str(move_speed_fixed),
		str(selected_general_id),
		str(attack_basis_points),
		str(defense_basis_points),
		str(supply_basis_points),
	]
	for tech_id in researched_tech_ids:
		parts.append(str(tech_id))
	for squad in squads:
		parts.append(
			"%d:%s:%s:%d:%s" % [
				int(squad.squad_id),
				str(squad.formation_id),
				str(squad.display_name),
				int(squad.initial_members),
				str(squad.route_id),
			]
		)
	return "|".join(parts)


func to_dictionary() -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"unit_role_id": unit_role_id,
		"hp_per_member": hp_per_member,
		"attack_per_member": attack_per_member,
		"armor_per_member": armor_per_member,
		"move_speed_fixed": move_speed_fixed,
		"selected_general_id": selected_general_id,
		"researched_tech_ids": researched_tech_ids.duplicate(),
		"attack_basis_points": attack_basis_points,
		"defense_basis_points": defense_basis_points,
		"supply_basis_points": supply_basis_points,
		"squads": squads.duplicate(true),
	}


static func from_dictionary(value: Dictionary) -> CommittedForceSnapshot:
	var expected_keys := [
		"transaction_id", "unit_role_id", "hp_per_member",
		"attack_per_member", "armor_per_member", "move_speed_fixed",
		"selected_general_id", "researched_tech_ids", "attack_basis_points",
		"defense_basis_points", "supply_basis_points", "squads",
	]
	if not _has_exact_keys(value, expected_keys):
		return null
	if (
		typeof(value.transaction_id) != TYPE_STRING_NAME
		or StringName(value.transaction_id) == &""
		or typeof(value.unit_role_id) != TYPE_STRING_NAME
		or StringName(value.unit_role_id) == &""
		or typeof(value.hp_per_member) != TYPE_INT
		or int(value.hp_per_member) <= 0
		or typeof(value.attack_per_member) != TYPE_INT
		or int(value.attack_per_member) < 0
		or typeof(value.armor_per_member) != TYPE_INT
		or int(value.armor_per_member) < 0
		or typeof(value.move_speed_fixed) != TYPE_INT
		or int(value.move_speed_fixed) <= 0
		or typeof(value.selected_general_id) != TYPE_STRING_NAME
		or typeof(value.researched_tech_ids) != TYPE_ARRAY
		or typeof(value.attack_basis_points) != TYPE_INT
		or typeof(value.defense_basis_points) != TYPE_INT
		or typeof(value.supply_basis_points) != TYPE_INT
		or typeof(value.squads) != TYPE_ARRAY
		or Array(value.squads).is_empty()
		or Array(value.squads).size() > MAX_SQUADS
	):
		return null
	var snapshot := CommittedForceSnapshot.new()
	snapshot.transaction_id = StringName(value.transaction_id)
	snapshot.unit_role_id = StringName(value.unit_role_id)
	snapshot.hp_per_member = int(value.hp_per_member)
	snapshot.attack_per_member = int(value.attack_per_member)
	snapshot.armor_per_member = int(value.armor_per_member)
	snapshot.move_speed_fixed = int(value.move_speed_fixed)
	snapshot.selected_general_id = StringName(value.selected_general_id)
	for tech_id_value in value.researched_tech_ids:
		if typeof(tech_id_value) != TYPE_STRING_NAME:
			return null
		snapshot.researched_tech_ids.append(StringName(tech_id_value))
	snapshot.attack_basis_points = int(value.attack_basis_points)
	snapshot.defense_basis_points = int(value.defense_basis_points)
	snapshot.supply_basis_points = int(value.supply_basis_points)
	var seen_formations: Dictionary = {}
	var seen_squads: Dictionary = {}
	for squad_value in value.squads:
		if not squad_value is Dictionary:
			return null
		var squad: Dictionary = squad_value
		if not _has_exact_keys(squad, [
			"squad_id", "formation_id", "display_name", "initial_members", "route_id",
		]):
			return null
		var squad_id := int(squad.squad_id)
		var formation_id := StringName(squad.formation_id)
		if (
			typeof(squad.squad_id) != TYPE_INT
			or squad_id <= 0
			or seen_squads.has(squad_id)
			or typeof(squad.formation_id) != TYPE_STRING_NAME
			or formation_id == &""
			or seen_formations.has(formation_id)
			or typeof(squad.display_name) != TYPE_STRING
			or str(squad.display_name).is_empty()
			or typeof(squad.initial_members) != TYPE_INT
			or int(squad.initial_members) <= 0
			or typeof(squad.route_id) != TYPE_STRING_NAME
			or StringName(squad.route_id) not in [FRONT_ROUTE, SIDE_ROUTE]
		):
			return null
		seen_squads[squad_id] = true
		seen_formations[formation_id] = true
		snapshot.squads.append(squad.duplicate(true))
	return snapshot


static func _default_squad_name(squad_id: int) -> String:
	return ["一队", "二队", "三队"][clampi(squad_id - 1, 0, 2)]


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true
