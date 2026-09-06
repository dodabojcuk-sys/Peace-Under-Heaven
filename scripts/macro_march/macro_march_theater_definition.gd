class_name MacroMarchTheaterDefinition
extends Resource


const BLACKSTONE_CITY := &"blackstone_city"
const NORTHWATCH_GARRISON := &"northwatch_garrison"
const REEDBANK_GARRISON := &"reedbank_garrison"


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
}


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
}
