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
	)
