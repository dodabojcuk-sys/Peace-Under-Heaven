class_name TechNode
extends Resource


@export var tech_id: StringName
@export var display_name: String
@export var branch_id: StringName
@export var cost: int
@export var prerequisite_ids: Array[StringName] = []
@export var effect_type: StringName
@export var effect_amount: float
