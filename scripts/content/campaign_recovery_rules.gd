class_name CampaignRecoveryRules
extends Resource


@export var initial_living_population := 72
@export var initial_production_workers := 12
@export var initial_construction_workers := 12
@export_range(0, 1000) var wounded_permille := 500
@export var treatment_batch_size := 6
@export var treatment_food_per_person := 1
@export var treatment_milliseconds_per_person := 1000
@export var production_workers_for_full_output := 12
@export var construction_workers_for_full_speed := 12


func is_valid() -> bool:
	return (
		initial_living_population > 0
		and initial_production_workers >= 0
		and initial_construction_workers >= 0
		and initial_production_workers + initial_construction_workers <= initial_living_population
		and wounded_permille >= 0 and wounded_permille <= 1000
		and treatment_batch_size > 0
		and treatment_food_per_person >= 0
		and treatment_milliseconds_per_person > 0
		and production_workers_for_full_output > 0
		and construction_workers_for_full_speed > 0
	)
