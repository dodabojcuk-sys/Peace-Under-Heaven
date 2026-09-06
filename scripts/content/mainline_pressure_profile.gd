class_name MainlinePressureProfile
extends Resource


@export var profile_id: StringName = &"mainline.blackstone.m0"
@export var level_id: StringName = &"first_map.main_assault.v0"
@export_range(2, 99, 1) var deadline_day := 7
@export var stage_overdue_days: Array[int] = [0, 1, 3, 5, 7]
@export var construction_modifier_permille: Array[int] = [1000, 900, 700, 450, 150]
@export var production_modifier_permille: Array[int] = [1000, 900, 750, 500, 150]
@export_range(1, 1000, 1) var essential_floor_permille := 250
@export_range(0, 100, 1) var default_security := 50
@export_range(0, 1000, 1) var maximum_security_mitigation_permille := 600
@export var wood_loss_by_stage: Array[int] = [0, 2, 4, 7, 10]
@export var food_loss_by_stage: Array[int] = [0, 1, 3, 5, 8]
@export var defense_damage_by_stage: Array[int] = [0, 0, 0, 1, 2]


func get_stage_index(current_day: int) -> int:
	var overdue_days := maxi(current_day - deadline_day, 0)
	var result := 0
	for index in range(stage_overdue_days.size()):
		if overdue_days >= stage_overdue_days[index]:
			result = index
	return mini(result, 4)


func get_stage_id(current_day: int) -> StringName:
	return StringName("PRESSURE_%d" % get_stage_index(current_day))


func get_stage_display_name(current_day: int) -> String:
	return ["正常", "紧张", "吃紧", "危急", "濒临崩溃"][get_stage_index(current_day)]


func get_next_stage_summary(current_day: int) -> Dictionary:
	var current_index := get_stage_index(current_day)
	if current_index >= stage_overdue_days.size() - 1:
		return {"name": "已达最高压力", "days_until": 0}
	var next_index := current_index + 1
	var overdue_days := maxi(current_day - deadline_day, 0)
	return {
		"name": ["正常", "紧张", "吃紧", "危急", "濒临崩溃"][next_index],
		"days_until": maxi(stage_overdue_days[next_index] - overdue_days, 0),
	}


func get_construction_modifier_permille(current_day: int) -> int:
	return construction_modifier_permille[get_stage_index(current_day)]


func get_production_modifier_permille(current_day: int) -> int:
	return production_modifier_permille[get_stage_index(current_day)]


func get_loss_for_day(current_day: int, security: int) -> Dictionary:
	var stage_index := get_stage_index(current_day)
	var security_ratio := clampf(float(security) / 100.0, 0.0, 1.0)
	var mitigation := roundi(
		security_ratio * float(maximum_security_mitigation_permille)
	)
	var retained := 1000 - mitigation
	return {
		"wood": ceili(float(wood_loss_by_stage[stage_index] * retained) / 1000.0),
		"food": ceili(float(food_loss_by_stage[stage_index] * retained) / 1000.0),
		"city_defense_damage": ceili(
			float(defense_damage_by_stage[stage_index] * retained) / 1000.0
		),
	}
