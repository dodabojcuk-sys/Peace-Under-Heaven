class_name CityLayoutProfileResolver
extends RefCounted


const BLACKSTONE_CITY_ID := &"blackstone_city"
const RIVERBEND_CITY_ID := &"riverbend_city"
const REGULAR_IMPERIAL := &"REGULAR_IMPERIAL"
const ORGANIC_GARDEN := &"ORGANIC_GARDEN"
const GRID_SIZE := 40.0
const MAP_GRID_SIZE := Vector2i(55, 35)
const MAP_SIZE := Vector2(2200.0, 1400.0)

const _CITY_TO_PROFILE := {
	BLACKSTONE_CITY_ID: REGULAR_IMPERIAL,
	RIVERBEND_CITY_ID: ORGANIC_GARDEN,
}

const _PROFILE_NAMES := {
	REGULAR_IMPERIAL: "规则帝城",
	ORGANIC_GARDEN: "有机花园城",
}


static func known_city_ids() -> Array[StringName]:
	return [BLACKSTONE_CITY_ID, RIVERBEND_CITY_ID]


static func is_known_city(city_id: StringName) -> bool:
	return _CITY_TO_PROFILE.has(city_id)


static func resolve_profile_id(city_id: StringName) -> StringName:
	return StringName(_CITY_TO_PROFILE.get(city_id, &""))


static func city_name(city_id: StringName) -> String:
	match city_id:
		BLACKSTONE_CITY_ID:
			return "黑石城"
		RIVERBEND_CITY_ID:
			return "河湾城"
	return "未知城市"


static func profile_name(profile_id: StringName) -> String:
	return str(_PROFILE_NAMES.get(profile_id, "未知布局"))


static func get_profile(profile_id: StringName) -> Dictionary:
	match profile_id:
		REGULAR_IMPERIAL:
			return _regular_imperial_profile()
		ORGANIC_GARDEN:
			return _organic_garden_profile()
	return {}


static func get_city_profile(city_id: StringName) -> Dictionary:
	var profile_id := resolve_profile_id(city_id)
	if profile_id == &"":
		return {}
	var profile := get_profile(profile_id)
	profile["city_id"] = city_id
	profile["profile_id"] = profile_id
	profile["city_name"] = city_name(city_id)
	return profile


static func _regular_imperial_profile() -> Dictionary:
	return {
		"profile_id": REGULAR_IMPERIAL,
		"map_size": MAP_SIZE,
		"grid_size": GRID_SIZE,
		"map_grid_size": MAP_GRID_SIZE,
		"road_layout_rects": [
			Rect2i(Vector2i(2, 13), Vector2i(51, 2)),
			Rect2i(Vector2i(28, 2), Vector2i(2, 31)),
		],
		"civic_court_rect": Rect2i(Vector2i(22, 7), Vector2i(6, 4)),
		"garden_reserve_rects": [],
		"gate_slot_rects": [
			Rect2i(Vector2i(26, 0), Vector2i(3, 2)),
			Rect2i(Vector2i(53, 16), Vector2i(2, 3)),
			Rect2i(Vector2i(26, 33), Vector2i(3, 2)),
			Rect2i(Vector2i(0, 16), Vector2i(2, 3)),
		],
		"gate_layout": [
			{"name": "NorthGate", "position": Vector2(1100.0, 54.0), "orientation": 0},
			{"name": "EastGate", "position": Vector2(2146.0, 700.0), "orientation": 1},
			{"name": "SouthGate", "position": Vector2(1100.0, 1346.0), "orientation": 2},
			{"name": "WestGate", "position": Vector2(54.0, 700.0), "orientation": 3},
		],
		"road_root_cells": [Vector2i(28, 13), Vector2i(7, 4)],
		"fixed_buildings": _regular_fixed_buildings(),
		"camera_focus": Vector2(1100.0, 700.0),
		"accent": Color("b89352"),
	}


static func _organic_garden_profile() -> Dictionary:
	# A fixed orthogonal garden plan: the main circulation is offset from the
	# center, turns through a T junction, and leaves unequal blocks and reserves.
	return {
		"profile_id": ORGANIC_GARDEN,
		"map_size": MAP_SIZE,
		"grid_size": GRID_SIZE,
		"map_grid_size": MAP_GRID_SIZE,
		"road_layout_rects": [
			Rect2i(Vector2i(1, 10), Vector2i(24, 2)),
			Rect2i(Vector2i(24, 10), Vector2i(2, 10)),
			Rect2i(Vector2i(24, 18), Vector2i(30, 2)),
			Rect2i(Vector2i(27, 18), Vector2i(2, 16)),
			Rect2i(Vector2i(10, 1), Vector2i(2, 10)),
			Rect2i(Vector2i(16, 11), Vector2i(2, 8)),
			Rect2i(Vector2i(6, 6), Vector2i(2, 5)),
			Rect2i(Vector2i(39, 18), Vector2i(2, 6)),
			Rect2i(Vector2i(6, 24), Vector2i(22, 2)),
			Rect2i(Vector2i(12, 24), Vector2i(2, 6)),
		],
		"civic_court_rect": Rect2i(Vector2i(19, 12), Vector2i(4, 4)),
		"garden_reserve_rects": [
			Rect2i(Vector2i(34, 4), Vector2i(13, 9)),
			Rect2i(Vector2i(4, 15), Vector2i(7, 5)),
			Rect2i(Vector2i(34, 25), Vector2i(8, 6)),
		],
		"gate_slot_rects": [
			Rect2i(Vector2i(10, 0), Vector2i(2, 2)),
			Rect2i(Vector2i(53, 18), Vector2i(2, 3)),
			Rect2i(Vector2i(27, 33), Vector2i(3, 2)),
			Rect2i(Vector2i(0, 10), Vector2i(2, 3)),
		],
		"gate_layout": [
			{"name": "NorthGate", "position": Vector2(440.0, 54.0), "orientation": 0},
			{"name": "EastGate", "position": Vector2(2146.0, 740.0), "orientation": 1},
			{"name": "SouthGate", "position": Vector2(1140.0, 1346.0), "orientation": 2},
			{"name": "WestGate", "position": Vector2(54.0, 460.0), "orientation": 3},
		],
		"road_root_cells": [Vector2i(10, 10), Vector2i(27, 18)],
		"fixed_buildings": {
			"Manor": Rect2(1120.0, 440.0, 190.0, 120.0),
			"Barracks": Rect2(520.0, 160.0, 190.0, 120.0),
			"Granary": Rect2(1600.0, 520.0, 190.0, 120.0),
			"Academy": Rect2(320.0, 800.0, 190.0, 120.0),
			"CityGate": Rect2(1240.0, 840.0, 190.0, 120.0),
			"CommandPlatform": Rect2(720.0, 760.0, 190.0, 120.0),
			"Noticeboard": Rect2(1840.0, 560.0, 160.0, 120.0),
		},
		"camera_focus": Vector2(1120.0, 760.0),
		"accent": Color("6f9a77"),
	}


static func _regular_fixed_buildings() -> Dictionary:
	return {
		"Manor": Rect2(80.0, 120.0, 190.0, 120.0),
		"Barracks": Rect2(350.0, 120.0, 190.0, 120.0),
		"Granary": Rect2(650.0, 120.0, 190.0, 120.0),
		"Academy": Rect2(80.0, 400.0, 190.0, 120.0),
		"CityGate": Rect2(350.0, 400.0, 190.0, 120.0),
		"CommandPlatform": Rect2(650.0, 400.0, 190.0, 120.0),
		"Noticeboard": Rect2(900.0, 400.0, 160.0, 120.0),
	}
