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

	var squad_count := mini(MAX_SQUADS, committed_total)
	var base_size := floori(float(committed_total) / float(squad_count))
	var remainder := committed_total % squad_count
	for index in range(squad_count):
		snapshot.squads.append({
			"squad_id": index + 1,
			"initial_members": base_size + (1 if index < remainder else 0),
			"route_id": FRONT_ROUTE if index % 2 == 0 else SIDE_ROUTE,
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
			"%d:%d:%s" % [
				int(squad.squad_id),
				int(squad.initial_members),
				str(squad.route_id),
			]
		)
	return "|".join(parts)
