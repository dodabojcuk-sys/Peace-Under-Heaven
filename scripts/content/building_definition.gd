class_name BuildingDefinition
extends Resource


@export var definition_id: StringName
@export var display_name: String
@export var building_type: String
@export var description: String
@export var placement_kind: StringName = &"placed"
@export var footprint := Vector2i.ONE
@export var road_anchor_offsets: Array[Vector2i] = []
@export var requires_road := false
@export var wood_cost := 0
@export var food_cost := 0
@export var capabilities: Array[BuildingCapability] = []
@export var body_color := Color(0.42, 0.5, 0.52, 1.0)
@export var outline_color := Color(0.2, 0.25, 0.27, 1.0)


func get_capability(capability_type: StringName) -> BuildingCapability:
	for capability in capabilities:
		if capability != null and capability.capability_type == capability_type:
			return capability
	return null
