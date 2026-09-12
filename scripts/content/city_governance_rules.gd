class_name CityGovernanceRules
extends Resource


@export var days_per_season := 3
@export var base_housing_capacity := 72
@export var winter_housing_penalty := 8
@export var civilians_per_food := 20
@export var shortage_warning_days := 1
@export var disease_trigger_days := 2
@export var disease_cases_per_day := 2
@export var base_medical_capacity := 6
@export var medical_workers_for_full_care := 4
@export var governance_workers_for_stability := 4
@export var shortage_health_loss_permille := 60
@export var housing_health_loss_permille := 35
@export var passive_health_recovery_permille := 25
@export var initial_health_permille := 1000
@export var disorder_threshold := 45
@export var governance_action_food_cost := 2
@export var growth_progress_per_day := 250
@export var birth_progress_required := 1000
@export var growth_health_threshold_permille := 800
@export var child_maturation_person_days := 960
@export var adult_ageing_person_days := 4800
@export var elderly_exposure_person_days := 24
@export var cold_consequence_trigger_days := 2
@export var pressure_warning_threshold := 20
@export var pressure_event_threshold := 35
@export var pressure_bandit_threshold := 55
@export var pressure_unrest_threshold := 75
@export var pressure_per_shortage_day := 12
@export var pressure_recovery_per_stable_day := 8
@export var event_escalation_days := 2
@export var petty_theft_food_loss := 2
@export var governance_resolution_pressure_relief := 18
@export var refugee_sources: Array[Dictionary] = [
	{
		"case_id": &"refugee.blackstone.northroad.001",
		"source_event_id": &"invasion.blackstone.001",
		"display_name": "北道避战村民",
		"arrival_day": 6,
		"count": 9,
		"medical_burden": 2,
	},
]


func is_valid() -> bool:
	return (
		days_per_season > 0
		and base_housing_capacity > 0
		and winter_housing_penalty >= 0
		and civilians_per_food > 0
		and disease_trigger_days > 0
		and disease_cases_per_day > 0
		and base_medical_capacity >= 0
		and medical_workers_for_full_care > 0
		and governance_workers_for_stability > 0
		and initial_health_permille > 0
		and initial_health_permille <= 1000
		and disorder_threshold >= 0
		and disorder_threshold <= 100
		and governance_action_food_cost >= 0
		and growth_progress_per_day > 0
		and birth_progress_required > 0
		and growth_health_threshold_permille >= 250
		and growth_health_threshold_permille <= 1000
		and child_maturation_person_days > 0
		and adult_ageing_person_days > 0
		and elderly_exposure_person_days > 0
		and cold_consequence_trigger_days > 0
		and pressure_warning_threshold >= 0
		and pressure_event_threshold >= pressure_warning_threshold
		and pressure_bandit_threshold >= pressure_event_threshold
		and pressure_unrest_threshold >= pressure_bandit_threshold
		and pressure_unrest_threshold <= 100
		and pressure_per_shortage_day > 0
		and pressure_recovery_per_stable_day > 0
		and event_escalation_days > 0
		and petty_theft_food_loss >= 0
		and governance_resolution_pressure_relief > 0
		and _refugee_sources_are_valid()
	)


func _refugee_sources_are_valid() -> bool:
	var ids := {}
	for source_value in refugee_sources:
		var source: Dictionary = source_value
		var case_id := StringName(source.get("case_id", &""))
		if case_id == &"" or ids.has(case_id) or StringName(source.get("source_event_id", &"")) == &"" or int(source.get("arrival_day", 0)) <= 0 or int(source.get("count", 0)) <= 0 or int(source.get("medical_burden", 0)) < 0 or int(source.get("medical_burden", 0)) > int(source.get("count", 0)):
			return false
		ids[case_id] = true
	return true
