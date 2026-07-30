class_name GarrisonState
extends RefCounted


const SCHEMA_VERSION := 1

var city_id: StringName
var _unit_counts: Dictionary = {}


func _init(
	city_id_value := &"blackstone_city",
	initial_definition_id := &"",
	initial_count := 0
) -> void:
	city_id = StringName(city_id_value)
	if StringName(initial_definition_id) != &"":
		set_unit_count(StringName(initial_definition_id), initial_count)


func get_unit_count(definition_id: StringName) -> int:
	return int(_unit_counts.get(definition_id, 0))


func set_unit_count(definition_id: StringName, count: int) -> bool:
	if definition_id == &"" or count < 0:
		return false
	_unit_counts[definition_id] = count
	return true


func try_add_units(
	definition_id: StringName,
	count: int,
	capacity := -1
) -> bool:
	if definition_id == &"" or count <= 0:
		return false
	var next_count := get_unit_count(definition_id) + count
	if capacity >= 0 and next_count > capacity:
		return false
	_unit_counts[definition_id] = next_count
	return true


func try_remove_units(
	definition_id: StringName,
	count: int
) -> bool:
	if definition_id == &"" or count <= 0:
		return false
	var current_count := get_unit_count(definition_id)
	if count > current_count:
		return false
	_unit_counts[definition_id] = current_count - count
	return true


func get_total_count() -> int:
	var total := 0
	for count in _unit_counts.values():
		total += int(count)
	return total


func get_unit_counts() -> Dictionary:
	return _unit_counts.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"city_id": city_id,
		"unit_counts": get_unit_counts(),
		"total_count": get_total_count(),
	}
