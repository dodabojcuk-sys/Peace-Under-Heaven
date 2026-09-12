class_name CityStrategyRules
extends Resource


@export var campaign_energy_max := 3
@export var support_duration_days := 1
@export var production_support_permille := 250
@export var medical_support_capacity := 4
@export var defense_support_permille := 150
@export var equipment_costs := {
	&"equipment.spear_kit": {&"wood": 12},
	&"equipment.padded_armor": {&"wood": 10},
	&"equipment.marching_kit": {&"wood": 8},
	&"equipment.general.bronze_sword": {&"wood": 15},
	&"equipment.general.iron_sword": {&"wood": 18},
	&"equipment.general.scout_helmet": {&"wood": 9},
	&"equipment.general.lamellar": {&"wood": 14},
	&"equipment.general.leather_gloves": {&"wood": 8},
	&"equipment.general.riding_boots": {&"wood": 10},
	&"equipment.general.command_talisman": {&"wood": 12},
}
@export var equipment_effect_permille := 100
@export var general_equipment_effect_permille := 50
@export var equipment_experience_per_level := 100
@export var equipment_training_experience := 100
@export var equipment_training_costs := {&"wood": 4}
@export var equipment_quality_order: Array[StringName] = [&"COMMON", &"FINE", &"ELITE"]
@export var equipment_level_caps := {&"COMMON": 3, &"FINE": 5, &"ELITE": 8}
@export var equipment_rank_costs := {
	&"COMMON": {&"wood": 10},
	&"FINE": {&"wood": 18},
}
@export var general_equipment_effect_kinds := {
	&"equipment.general.bronze_sword": &"ATTACK",
	&"equipment.general.iron_sword": &"ATTACK",
	&"equipment.general.scout_helmet": &"DEFENSE",
	&"equipment.general.lamellar": &"DEFENSE",
	&"equipment.general.leather_gloves": &"ATTACK",
	&"equipment.general.riding_boots": &"MOBILITY",
	&"equipment.general.command_talisman": &"ATTACK_DEFENSE",
}
@export var trade_offers := {
	&"trade.wood_for_food": {&"spend_id": &"wood", &"spend": 10, &"gain_id": &"food", &"gain": 5},
	&"trade.food_for_wood": {&"spend_id": &"food", &"spend": 5, &"gain_id": &"wood", &"gain": 8},
}


func is_valid() -> bool:
	return campaign_energy_max > 0 and support_duration_days > 0 and production_support_permille > 0 and medical_support_capacity > 0 and defense_support_permille > 0 and equipment_effect_permille > 0 and general_equipment_effect_permille > 0 and equipment_experience_per_level > 0 and equipment_training_experience > 0
