class_name BuildingCapability
extends Resource


@export var capability_type: StringName
@export var resource_id: StringName
@export var amount: int
@export var requires_operational := true
@export var stack_rule: StringName = &"add"
