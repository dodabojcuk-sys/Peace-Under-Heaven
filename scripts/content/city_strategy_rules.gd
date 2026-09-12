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
	&"equipment.general.lamellar": {&"wood": 14},
	&"equipment.general.riding_boots": {&"wood": 10},
}
@export var equipment_effect_permille := 100
@export var general_equipment_effect_permille := 50
@export var trade_offers := {
	&"trade.wood_for_food": {&"spend_id": &"wood", &"spend": 10, &"gain_id": &"food", &"gain": 5},
	&"trade.food_for_wood": {&"spend_id": &"food", &"spend": 5, &"gain_id": &"wood", &"gain": 8},
}


func is_valid() -> bool:
	return campaign_energy_max > 0 and support_duration_days > 0 and production_support_permille > 0 and medical_support_capacity > 0 and defense_support_permille > 0 and equipment_effect_permille > 0 and general_equipment_effect_permille > 0
