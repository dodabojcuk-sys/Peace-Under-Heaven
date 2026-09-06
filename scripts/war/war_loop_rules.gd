class_name WarLoopRules
extends Resource


# Reversible engineering defaults for WAR_LOOP_BATCH_R1. These values are
# deliberately kept out of UI code and are not product-balance approval.
@export var surrender_minimum_force_ratio := 3.0
@export var surrender_minimum_quality_ratio := 1.5
@export var retreat_loss_basis_points := 500
@export var retreat_minimum_loss := 1
@export var combat_tick_milliseconds := 250
@export var attacker_damage_basis_points := 10000
@export var defender_damage_basis_points := 8500
