class_name MacroMarchTheaterDefinition
extends Resource


const BLACKSTONE_CITY := &"blackstone_city"
const NORTHWATCH_GARRISON := &"northwatch_garrison"
const REEDBANK_GARRISON := &"reedbank_garrison"
const REDCLIFF_CITY := &"redcliff_city"
const SILVERFORD_CITY := &"silverford_city"
const FOREST_GARRISON := &"forest_garrison"


@export var theater_name := "黑石战区"
@export var scout_visibility_range := 2
@export var presentation_profile: Dictionary = {
	"ground_color": Color("7e966c"),
	"ground_patch_color": Color("91a878"),
	"water_color": Color("4e9bbd"),
	"water_highlight_color": Color("8bcbd0"),
	"friendly_color": Color("d9b96d"),
	"enemy_color": Color("c85745"),
}


# Coordinates are tactical-world facts. The map camera may frame only part of
# this area, but it must not invent land, forests or water in presentation.
@export var world_bounds := Rect2i(-260, -180, 1520, 1040)


# This is intentionally a Resource, so a later campaign can replace point
# names, IDs, coordinates, or road polylines without changing march authority.
@export var points: Dictionary = {
	BLACKSTONE_CITY: {
		"point_id": BLACKSTONE_CITY,
		"display_name": "黑石城",
		"world_position": Vector2i(150, 430),
	},
	NORTHWATCH_GARRISON: {
		"point_id": NORTHWATCH_GARRISON,
		"display_name": "北望驻扎点",
		"world_position": Vector2i(790, 170),
	},
	REEDBANK_GARRISON: {
		"point_id": REEDBANK_GARRISON,
		"display_name": "芦湾驻扎点",
		"world_position": Vector2i(850, 505),
	},
	REDCLIFF_CITY: {
		"point_id": REDCLIFF_CITY,
		"display_name": "赤崖城",
		"world_position": Vector2i(900, 290),
		"point_kind": &"ENEMY_CITY",
		"story_owner_faction_id": &"river_lords",
		"military_controller_faction_id": &"border_rebels",
		"required_for_victory": true,
		"surrender_allowed": false,
		"gate_hp": 240,
		"defender_count": 6,
		"defender_hp_per_member": 100,
		"defender_attack_per_member": 6,
		"defender_armor_per_member": 1,
	},
	SILVERFORD_CITY: {
		"point_id": SILVERFORD_CITY,
		"display_name": "银渡城",
		"world_position": Vector2i(910, 575),
		"point_kind": &"ENEMY_CITY",
		"story_owner_faction_id": &"river_lords",
		"military_controller_faction_id": &"river_lords",
		"required_for_victory": true,
		"surrender_allowed": true,
		"gate_hp": 180,
		"defender_count": 4,
		"defender_hp_per_member": 50,
		"defender_attack_per_member": 2,
		"defender_armor_per_member": 0,
	},
}


# Greybox tactical water is data owned by the theatre, not a screen-space
# special case. A construction line crossing this strip becomes a bridge job.
@export var water_regions: Array[Rect2i] = [
	Rect2i(515, 350, 120, 145),
]


@export var terrain_regions: Array[Dictionary] = [
	{"terrain_id": &"forest.north", "kind": &"FOREST", "rect": Rect2i(250, 80, 170, 135)},
	{"terrain_id": &"forest.east", "kind": &"FOREST", "rect": Rect2i(690, 330, 160, 115)},
	{"terrain_id": &"forest.south", "kind": &"FOREST", "rect": Rect2i(50, 510, 190, 125)},
]


@export var patrol_configs: Array[Dictionary] = [{
	"patrol_id": &"patrol.ridge.001",
	"display_name": "北岭巡骑",
	"route_point_ids": [&"northwatch_garrison", &"reedbank_garrison"],
	"start_point_id": &"northwatch_garrison",
	"strength": 5,
	"wait_milliseconds": 2400,
}]


# The ridge road is the indestructible main road. The lowland road is a
# demonstrable branch road: it may stop one order before its marked segment.
@export var routes: Dictionary = {
	&"road.blackstone.northwatch.ridge": {
		"route_id": &"road.blackstone.northwatch.ridge",
		"display_name": "北岭主道",
		"source_point_id": BLACKSTONE_CITY,
		"target_point_id": NORTHWATCH_GARRISON,
		"points": [
			Vector2i(150, 430), Vector2i(315, 320), Vector2i(515, 225),
			Vector2i(790, 170),
		],
		"blockable_segment_index": -1,
	},
	&"road.blackstone.northwatch.lowland": {
		"route_id": &"road.blackstone.northwatch.lowland",
		"display_name": "南洼支路",
		"source_point_id": BLACKSTONE_CITY,
		"target_point_id": NORTHWATCH_GARRISON,
		"points": [
			Vector2i(150, 430), Vector2i(340, 525), Vector2i(590, 460),
			Vector2i(690, 300), Vector2i(790, 170),
		],
		"blockable_segment_index": 2,
	},
	&"road.northwatch.reedbank": {
		"route_id": &"road.northwatch.reedbank",
		"display_name": "芦湾联络道",
		"source_point_id": NORTHWATCH_GARRISON,
		"target_point_id": REEDBANK_GARRISON,
		"points": [
			Vector2i(790, 170), Vector2i(650, 310), Vector2i(710, 430),
			Vector2i(850, 505),
		],
		"blockable_segment_index": -1,
	},
	&"road.reedbank.northwatch": {
		"route_id": &"road.reedbank.northwatch",
		"display_name": "芦湾联络道（返程）",
		"source_point_id": REEDBANK_GARRISON,
		"target_point_id": NORTHWATCH_GARRISON,
		"points": [
			Vector2i(850, 505), Vector2i(710, 430), Vector2i(650, 310),
			Vector2i(790, 170),
		],
		"blockable_segment_index": -1,
	},
	&"road.northwatch.redcliff": {
		"route_id": &"road.northwatch.redcliff",
		"display_name": "赤崖攻城道",
		"source_point_id": NORTHWATCH_GARRISON,
		"target_point_id": REDCLIFF_CITY,
		"points": [
			Vector2i(790, 170), Vector2i(840, 220), Vector2i(900, 290),
		],
		"blockable_segment_index": -1,
	},
	&"road.reedbank.silverford": {
		"route_id": &"road.reedbank.silverford",
		"display_name": "银渡攻城道",
		"source_point_id": REEDBANK_GARRISON,
		"target_point_id": SILVERFORD_CITY,
		"points": [
			Vector2i(850, 505), Vector2i(885, 540), Vector2i(910, 575),
		],
		"blockable_segment_index": -1,
	},
	&"road.redcliff.silverford": {
		"route_id": &"road.redcliff.silverford",
		"display_name": "赤崖至银渡道",
		"source_point_id": REDCLIFF_CITY,
		"target_point_id": SILVERFORD_CITY,
		"points": [
			Vector2i(900, 290), Vector2i(875, 430), Vector2i(910, 575),
		],
		"blockable_segment_index": -1,
	},
}
