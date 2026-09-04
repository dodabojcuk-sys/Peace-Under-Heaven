class_name RegularCitySpatialFoundation
extends Node2D


const CityGateComponent = preload("res://scripts/city_gate_component_r1.gd")
const CITY_GRID_RULES = preload("res://scripts/city_sandbox/city_grid_rules.gd")
const PROFILE_RESOLVER = preload("res://scripts/city_layout_profile_resolver.gd")
const PALETTE := preload(
	"res://resources/visuals/northern_campaign_palette.gd"
)
const GRAYBOX_BUILDING_VISUAL = preload(
	"res://scripts/graybox_building_visual.gd"
)

const MAP_SIZE := Vector2(2200.0, 1400.0)
const GRID_SIZE := 40.0
const MAP_GRID_SIZE := Vector2i(55, 35)
# The regular-city profile is the one spatial source for the graybox road
# surface and its gameplay cell projection.  Rendering and construction query
# these same cell ranges; neither side maintains a second road map.
const ROAD_LAYOUT_RECTS := [
	Rect2i(Vector2i(2, 13), Vector2i(51, 2)),
	Rect2i(Vector2i(28, 2), Vector2i(2, 31)),
]
const CIVIC_COURT_RECT := Rect2i(Vector2i(22, 7), Vector2i(6, 4))
const GATE_SLOT_RECTS := [
	Rect2i(Vector2i(26, 0), Vector2i(3, 2)),
	Rect2i(Vector2i(53, 16), Vector2i(2, 3)),
	Rect2i(Vector2i(26, 33), Vector2i(3, 2)),
	Rect2i(Vector2i(0, 16), Vector2i(2, 3)),
]
const LEGACY_RUNTIME_ROAD_ROOT := Vector2i(7, 4)
const FORMAL_ROAD_ROOT := Vector2i(28, 13)
const GATE_LAYOUT := [
	{"name": "NorthGate", "position": Vector2(1100.0, 54.0), "orientation": 0},
	{"name": "EastGate", "position": Vector2(2146.0, 700.0), "orientation": 1},
	{"name": "SouthGate", "position": Vector2(1100.0, 1346.0), "orientation": 2},
	{"name": "WestGate", "position": Vector2(54.0, 700.0), "orientation": 3},
]

const BUILDING_LABELS := {
	"Manor": "城主府",
	"Barracks": "兵营",
	"Granary": "粮仓",
	"Academy": "书院",
	"CommandPlatform": "军令台",
	"Noticeboard": "告示板",
}

var _fixed_building_proxies: Array[Dictionary] = []
var _fixed_building_visuals: Array[GrayboxBuildingVisual] = []
var _formal_road_cells: Dictionary = {}
var _formal_reserved_cells: Dictionary = {}
var _formal_wall_cells: Dictionary = {}
var _formal_gate_cells: Dictionary = {}
var _player_road_cells: Dictionary = {}
var city_id: StringName = PROFILE_RESOLVER.BLACKSTONE_CITY_ID
var layout_profile_id: StringName = PROFILE_RESOLVER.REGULAR_IMPERIAL
var _layout_profile: Dictionary = {}
var _gate_instances: Node2D


func _ready() -> void:
	z_index = -1
	_load_layout_profile(city_id)
	_build_spatial_cell_projection()
	_collect_fixed_building_proxies()
	_hide_legacy_visual_layer()
	_install_fixed_building_visuals()
	_install_gate_instances()
	queue_redraw()


func get_city_id() -> StringName:
	return city_id


func get_layout_profile_id() -> StringName:
	return layout_profile_id


func get_layout_profile_name() -> String:
	return PROFILE_RESOLVER.profile_name(layout_profile_id)


func get_layout_profile_snapshot() -> Dictionary:
	return _layout_profile.duplicate(true)


func get_camera_focus() -> Vector2:
	return Vector2(_layout_profile.get("camera_focus", MAP_SIZE * 0.5))


func set_city_id(next_city_id: StringName) -> bool:
	if not PROFILE_RESOLVER.is_known_city(next_city_id):
		return false
	if city_id == next_city_id and not _layout_profile.is_empty():
		return true
	city_id = next_city_id
	_load_layout_profile(city_id)
	if not is_node_ready():
		return true
	_build_spatial_cell_projection()
	_apply_profile_to_legacy_nodes()
	_sync_fixed_building_proxy_rects()
	_rebuild_gate_instances()
	queue_redraw()
	return true


func _load_layout_profile(for_city_id: StringName) -> void:
	var profile := PROFILE_RESOLVER.get_city_profile(for_city_id)
	if profile.is_empty():
		push_error("Unknown city layout profile: %s" % for_city_id)
		return
	layout_profile_id = StringName(profile.get("profile_id", &""))
	_layout_profile = profile


func _build_spatial_cell_projection() -> void:
	_formal_road_cells.clear()
	_formal_reserved_cells.clear()
	_formal_wall_cells.clear()
	_formal_gate_cells.clear()
	var road_rects: Array = _layout_profile.get("road_layout_rects", ROAD_LAYOUT_RECTS)
	for road_rect in road_rects:
		for y in range(road_rect.position.y, road_rect.end.y):
			for x in range(road_rect.position.x, road_rect.end.x):
				_formal_road_cells[Vector2i(x, y)] = true
	var civic_rect: Rect2i = _layout_profile.get(
		"civic_court_rect",
		CIVIC_COURT_RECT
	)
	for y in range(civic_rect.position.y, civic_rect.end.y):
		for x in range(civic_rect.position.x, civic_rect.end.x):
			_formal_reserved_cells[Vector2i(x, y)] = true
	for reserve_rect in _layout_profile.get("garden_reserve_rects", []):
		for y in range(reserve_rect.position.y, reserve_rect.end.y):
			for x in range(reserve_rect.position.x, reserve_rect.end.x):
				_formal_reserved_cells[Vector2i(x, y)] = true
	for x in range(MAP_GRID_SIZE.x):
		_formal_wall_cells[Vector2i(x, 0)] = true
		_formal_wall_cells[Vector2i(x, MAP_GRID_SIZE.y - 1)] = true
	for y in range(MAP_GRID_SIZE.y):
		_formal_wall_cells[Vector2i(0, y)] = true
		_formal_wall_cells[Vector2i(MAP_GRID_SIZE.x - 1, y)] = true
	for gate_rect in _layout_profile.get("gate_slot_rects", GATE_SLOT_RECTS):
		for y in range(gate_rect.position.y, gate_rect.end.y):
			for x in range(gate_rect.position.x, gate_rect.end.x):
				_formal_gate_cells[Vector2i(x, y)] = true


func get_formal_road_cells() -> Dictionary:
	return _formal_road_cells.duplicate(true)


func get_map_grid_size() -> Vector2i:
	return MAP_GRID_SIZE


func set_player_road_cells(cells: Dictionary) -> void:
	_player_road_cells.clear()
	for cell in cells:
		var typed_cell := Vector2i(cell)
		if not _formal_road_cells.has(typed_cell):
			_player_road_cells[typed_cell] = true
	queue_redraw()


func get_formal_reserved_cells() -> Dictionary:
	return _formal_reserved_cells.duplicate(true)


func get_formal_wall_cells() -> Dictionary:
	return _formal_wall_cells.duplicate(true)


func get_formal_gate_cells() -> Dictionary:
	return _formal_gate_cells.duplicate(true)


func is_formal_road_cell(cell: Vector2i) -> bool:
	return _formal_road_cells.has(cell)


func is_formal_reserved_cell(cell: Vector2i) -> bool:
	return _formal_reserved_cells.has(cell)


func is_formal_wall_cell(cell: Vector2i) -> bool:
	return _formal_wall_cells.has(cell)


func is_formal_gate_cell(cell: Vector2i) -> bool:
	return _formal_gate_cells.has(cell)


func get_road_root_cells() -> Array[Vector2i]:
	# The legacy seed keeps existing road fixtures/save validation valid while
	# the formal city profile contributes its own connected center root.
	var roots: Array[Vector2i] = []
	for root in _layout_profile.get(
		"road_root_cells",
		[FORMAL_ROAD_ROOT, LEGACY_RUNTIME_ROAD_ROOT]
	):
		roots.append(Vector2i(root))
	return roots


func get_formal_road_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell_rect in _layout_profile.get("road_layout_rects", ROAD_LAYOUT_RECTS):
		rects.append(_cell_rect(cell_rect))
	return rects


func get_civic_court_rect() -> Rect2:
	return _cell_rect(_layout_profile.get("civic_court_rect", CIVIC_COURT_RECT))


func get_garden_reserve_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell_rect in _layout_profile.get("garden_reserve_rects", []):
		rects.append(_cell_rect(cell_rect))
	return rects


func get_profile_fixed_building_rect(node_name: String) -> Rect2:
	return Rect2(_layout_profile.get("fixed_buildings", {}).get(node_name, Rect2()))


func _cell_rect(cell_rect: Rect2i) -> Rect2:
	return Rect2(
		Vector2(cell_rect.position) * GRID_SIZE,
		Vector2(cell_rect.size) * GRID_SIZE
	)


func _collect_fixed_building_proxies() -> void:
	_apply_profile_to_legacy_nodes()
	for node_name in [
		"Manor",
		"Barracks",
		"Granary",
		"Academy",
		"CommandPlatform",
		"Noticeboard",
	]:
		var legacy_node := get_parent().get_node_or_null(node_name) as ColorRect
		if legacy_node == null:
			continue
		_fixed_building_proxies.append({
			"rect": Rect2(legacy_node.position, legacy_node.size),
			"name": node_name,
			"color": legacy_node.color,
			"legacy_node": legacy_node,
		})
		# The original control remains the single fixed-building selection owner.
		# This foundation only replaces its flat-card visual, never its state.
		legacy_node.visible = false


func _apply_profile_to_legacy_nodes() -> void:
	var fixed_buildings: Dictionary = _layout_profile.get("fixed_buildings", {})
	for node_name in fixed_buildings.keys():
		var legacy_node := get_parent().get_node_or_null(str(node_name)) as ColorRect
		if legacy_node == null:
			continue
		var rect := Rect2(fixed_buildings[node_name])
		legacy_node.position = rect.position
		legacy_node.size = rect.size


func _sync_fixed_building_proxy_rects() -> void:
	for proxy in _fixed_building_proxies:
		var node_name := str(proxy.get("name", ""))
		var rect := get_profile_fixed_building_rect(node_name)
		if rect.size == Vector2.ZERO:
			continue
		proxy["rect"] = rect
		var legacy_node := proxy.get("legacy_node") as Control
		if legacy_node != null:
			legacy_node.position = rect.position
			legacy_node.size = rect.size
		var visual := proxy.get("visual") as GrayboxBuildingVisual
		if visual != null:
			visual.position = rect.position


func _rebuild_gate_instances() -> void:
	if is_instance_valid(_gate_instances):
		_gate_instances.free()
	var container := Node2D.new()
	container.name = "GateInstances"
	add_child(container)
	_gate_instances = container
	for gate_data in _layout_profile.get("gate_layout", GATE_LAYOUT):
		var gate := CityGateComponent.new() as CityGateComponentR1
		gate.name = str(gate_data.name)
		gate.position = Vector2(gate_data.position)
		gate.configure(int(gate_data.orientation), "%s城门" % str(gate_data.name))
		container.add_child(gate)


func _install_fixed_building_visuals() -> void:
	for proxy in _fixed_building_proxies:
		var visual := GRAYBOX_BUILDING_VISUAL.new() as GrayboxBuildingVisual
		# Preserve the established node identity used by selection and smoke
		# contracts; the procedural visual replaces the artwork, not the
		# authoritative fixed-building name.
		visual.name = str(proxy.name)
		visual.position = Rect2(proxy.rect).position
		var rect := Rect2(proxy.rect)
		var footprint := Vector2i(
			maxi(1, ceili(rect.size.x / GRID_SIZE)),
			maxi(1, ceili(rect.size.y / GRID_SIZE))
		)
		var building_type := "固定预置建筑"
		visual.configure(
			StringName(str(proxy.name).to_snake_case()),
			str(BUILDING_LABELS.get(str(proxy.name), str(proxy.name))),
			building_type,
			footprint,
			0,
			Color(proxy.color),
			Color(proxy.color).darkened(0.34),
			false,
			false,
			&"fixed",
			1.0,
			&"not_required",
			true
		)
		add_child(visual)
		proxy["visual"] = visual
		_fixed_building_visuals.append(visual)
		var legacy_node := proxy.legacy_node as ColorRect
		if legacy_node != null:
			legacy_node.set_meta("graybox_visual", visual)


func _hide_legacy_visual_layer() -> void:
	# The original MapWorld children remain state and selection anchors where
	# applicable, but their card/road artwork must not compete with the R1 city.
	for sibling in get_parent().get_children():
		if sibling == self or sibling.name == "ConstructionLayer":
			continue
		if sibling is CanvasItem:
			(sibling as CanvasItem).visible = false


func _install_gate_instances() -> void:
	_rebuild_gate_instances()


func _draw() -> void:
	if layout_profile_id == PROFILE_RESOLVER.ORGANIC_GARDEN:
		_draw_organic_garden_city()
		return
	# Rendering remains a projection of the formal profile. The restrained
	# ground variation below is deterministic and carries no collision or state.
	_draw_city_ground(false)
	_draw_ward(Rect2(150.0, 130.0, 620.0, 410.0), PALETTE.GROUND_SAND)
	_draw_ward(Rect2(835.0, 130.0, 530.0, 410.0), PALETTE.GROUND_PALE)
	_draw_ward(Rect2(1430.0, 130.0, 580.0, 410.0), PALETTE.GROUND_SAND)
	_draw_ward(Rect2(150.0, 770.0, 620.0, 430.0), PALETTE.GROUND_PALE)
	_draw_ward(Rect2(835.0, 770.0, 530.0, 430.0), PALETTE.GROUND_SAND)
	_draw_ward(Rect2(1430.0, 770.0, 580.0, 430.0), PALETTE.GROUND_PALE)
	for road_rect in get_formal_road_rects():
		_draw_road(road_rect)
	_draw_formal_road_intersections()
	_draw_player_roads()
	_draw_civic_courtyard(PALETTE.COPPER_GOLD)


func _draw_organic_garden_city() -> void:
	# The garden profile stays orthogonal, but its T-junctions, unequal wards,
	# and reserves break the rigid axial cross without introducing a second grid.
	_draw_city_ground(true)
	for ward in [
		[Rect2(130.0, 120.0, 640.0, 420.0), PALETTE.GROUND_COOL],
		[Rect2(820.0, 120.0, 490.0, 420.0), PALETTE.GROUND_PALE],
		[Rect2(1450.0, 120.0, 600.0, 420.0), PALETTE.GROUND_COOL],
		[Rect2(130.0, 780.0, 640.0, 430.0), PALETTE.GROUND_PALE],
		[Rect2(820.0, 780.0, 490.0, 430.0), PALETTE.GROUND_COOL],
		[Rect2(1450.0, 780.0, 600.0, 430.0), PALETTE.GROUND_PALE],
	]:
		_draw_ward(ward[0], ward[1])
	for reserve_rect in get_garden_reserve_rects():
		draw_rect(reserve_rect, PALETTE.with_alpha(PALETTE.JADE, 0.34), true)
		draw_rect(
			reserve_rect.grow(-14.0),
			PALETTE.with_alpha(PALETTE.INK_SOFT, 0.62),
			false,
			4.0
		)
		var center := reserve_rect.get_center()
		for offset in [Vector2(-42.0, -24.0), Vector2(30.0, 18.0), Vector2(4.0, -52.0)]:
			draw_circle(center + offset, 18.0, PALETTE.with_alpha(PALETTE.JADE, 0.58))
	for road_rect in get_formal_road_rects():
		_draw_road(road_rect)
	_draw_formal_road_intersections()
	_draw_player_roads()
	_draw_civic_courtyard(PALETTE.JADE)


func _draw_city_ground(is_garden: bool) -> void:
	var outer_color := (
		PALETTE.GROUND_COOL.lerp(PALETTE.JADE, 0.08)
		if is_garden
		else PALETTE.GROUND_WARM.darkened(0.07)
	)
	var inner_color := (
		PALETTE.GROUND_WARM.lerp(PALETTE.JADE, 0.04)
		if is_garden
		else PALETTE.GROUND_WARM
	)
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), outer_color, true)
	var inner_rect := Rect2(
		Vector2(74.0, 74.0),
		MAP_SIZE - Vector2(148.0, 148.0)
	)
	draw_rect(inner_rect, inner_color, true)
	_draw_ground_variation(inner_rect, is_garden)
	_draw_city_wall()


func _draw_ground_variation(bounds: Rect2, is_garden: bool) -> void:
	# Broad, quiet tonal patches avoid a flat board while staying subordinate to
	# roads and footprints. Their deterministic pattern keeps captures stable.
	for y in range(int(bounds.position.y) + 26, int(bounds.end.y) - 20, 132):
		for x in range(int(bounds.position.x) + 24, int(bounds.end.x) - 20, 164):
			var pattern_index := posmod((x / 4) + (y / 3), 5)
			var patch_color := (
				PALETTE.GROUND_COOL
				if pattern_index in [0, 3]
				else PALETTE.GROUND_PALE
			)
			if is_garden and pattern_index == 2:
				patch_color = PALETTE.JADE
			var patch := Rect2(
				Vector2(x, y),
				Vector2(116.0 + float(pattern_index * 5), 82.0)
			)
			draw_rect(
				patch,
				PALETTE.with_alpha(patch_color, 0.075),
				true
			)
			draw_line(
				patch.position + Vector2(15.0, patch.size.y - 13.0),
				patch.position + Vector2(patch.size.x - 18.0, patch.size.y - 7.0),
				PALETTE.with_alpha(PALETTE.GROUND_MARK, 0.13),
				1.5,
				true
			)


func _draw_city_wall() -> void:
	var wall_rect := Rect2(
		Vector2(28.0, 28.0),
		MAP_SIZE - Vector2(56.0, 56.0)
	)
	draw_rect(wall_rect, PALETTE.WALL_STONE, false, 18.0)
	draw_rect(
		wall_rect.grow(-13.0),
		PALETTE.with_alpha(PALETTE.WALL_HIGHLIGHT, 0.82),
		false,
		3.0
	)
	# Stone joints are visual-only and remain inside the formal wall band.
	for x in range(92, int(MAP_SIZE.x) - 80, 168):
		draw_line(Vector2(x, 20.0), Vector2(x + 20.0, 38.0), PALETTE.WALL_HIGHLIGHT, 2.0)
		draw_line(
			Vector2(x, MAP_SIZE.y - 38.0),
			Vector2(x + 20.0, MAP_SIZE.y - 20.0),
			PALETTE.WALL_HIGHLIGHT,
			2.0
		)
	for y in range(92, int(MAP_SIZE.y) - 80, 168):
		draw_line(Vector2(20.0, y), Vector2(38.0, y + 20.0), PALETTE.WALL_HIGHLIGHT, 2.0)
		draw_line(
			Vector2(MAP_SIZE.x - 38.0, y),
			Vector2(MAP_SIZE.x - 20.0, y + 20.0),
			PALETTE.WALL_HIGHLIGHT,
			2.0
		)


func _draw_ward(rect: Rect2, color: Color) -> void:
	draw_rect(rect, PALETTE.with_alpha(PALETTE.SHADOW, 0.12), true)
	draw_rect(rect.grow(-7.0), color, true)
	draw_rect(
		rect.grow(-20.0),
		PALETTE.with_alpha(PALETTE.GROUND_PALE, 0.82),
		false,
		3.0
	)
	draw_line(
		rect.position + Vector2(30.0, rect.size.y - 26.0),
		Vector2(rect.end.x - 34.0, rect.end.y - 26.0),
		PALETTE.with_alpha(PALETTE.GROUND_MARK, 0.18),
		2.0
	)
	# These are non-interactive ward volumes, not selectable production
	# buildings. They make the foundation read as a city before art production.
	for local_rect in [
		Rect2(54.0, 60.0, 100.0, 72.0),
		Rect2(rect.size.x - 174.0, 74.0, 112.0, 78.0),
		Rect2(rect.size.x * 0.5 - 54.0, rect.size.y - 126.0, 108.0, 74.0),
	]:
		_draw_ambient_volume(
			Rect2(rect.position + local_rect.position, local_rect.size)
		)


func _draw_ambient_volume(rect: Rect2) -> void:
	var shadow := Rect2(rect.position + Vector2(10.0, 13.0), rect.size)
	draw_rect(shadow, PALETTE.SHADOW, true)
	draw_rect(rect, PALETTE.GROUND_COOL.darkened(0.09), true)
	var roof := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x * 0.5, -18.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x, 24.0),
		rect.position + Vector2(0.0, 24.0),
	])
	draw_colored_polygon(roof, PALETTE.ROAD_RUT)
	draw_line(
		rect.position + Vector2(rect.size.x * 0.5, -18.0),
		rect.position + Vector2(rect.size.x * 0.5, 21.0),
		PALETTE.with_alpha(PALETTE.ROAD_EDGE, 0.52),
		2.0
	)
	draw_rect(rect, PALETTE.ROAD_EDGE, false, 2.0)
	var door_rect := Rect2(
		Vector2(rect.get_center().x - 8.0, rect.end.y - 20.0),
		Vector2(16.0, 20.0)
	)
	draw_rect(door_rect, PALETTE.with_alpha(PALETTE.INK_BLUE, 0.62), true)


func _draw_road(rect: Rect2) -> void:
	# Three layers: compacted shoulder, travel surface, then quiet wagon ruts.
	draw_rect(rect.grow(5.0), PALETTE.with_alpha(PALETTE.SHADOW, 0.24), true)
	draw_rect(rect, PALETTE.ROAD_EDGE, true)
	draw_rect(rect.grow(-6.0), PALETTE.ROAD_SURFACE, true)
	draw_rect(
		rect.grow(-11.0),
		PALETTE.with_alpha(PALETTE.ROAD_DUST, 0.42),
		true
	)
	if rect.size.x >= rect.size.y:
		for y_ratio in [0.38, 0.62]:
			var y: float = rect.position.y + rect.size.y * float(y_ratio)
			draw_line(
				Vector2(rect.position.x + 7.0, y),
				Vector2(rect.end.x - 7.0, y),
				PALETTE.with_alpha(PALETTE.ROAD_RUT, 0.66),
				2.0,
				true
			)
	else:
		for x_ratio in [0.38, 0.62]:
			var x: float = rect.position.x + rect.size.x * float(x_ratio)
			draw_line(
				Vector2(x, rect.position.y + 7.0),
				Vector2(x, rect.end.y - 7.0),
				PALETTE.with_alpha(PALETTE.ROAD_RUT, 0.66),
				2.0,
				true
			)


func _draw_formal_road_intersections() -> void:
	var roads := get_formal_road_rects()
	for first_index in range(roads.size()):
		for second_index in range(first_index + 1, roads.size()):
			var intersection := roads[first_index].intersection(roads[second_index])
			if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
				continue
			draw_rect(intersection, PALETTE.ROAD_EDGE, true)
			draw_rect(intersection.grow(-6.0), PALETTE.ROAD_SURFACE, true)
			draw_circle(
				intersection.get_center(),
				minf(intersection.size.x, intersection.size.y) * 0.26,
				PALETTE.ROAD_DUST
			)
			draw_arc(
				intersection.get_center(),
				minf(intersection.size.x, intersection.size.y) * 0.31,
				0.0,
				TAU,
				24,
				PALETTE.with_alpha(PALETTE.ROAD_RUT, 0.72),
				2.0,
				true
			)


func _draw_civic_courtyard(accent: Color) -> void:
	# Open civic court: a quiet command-table landmark, never a foreground gate.
	var courtyard := get_civic_court_rect()
	draw_rect(courtyard, PALETTE.ROAD_EDGE, true)
	draw_rect(courtyard.grow(-5.0), PALETTE.ROAD_DUST, true)
	draw_rect(courtyard.grow(-23.0), PALETTE.GROUND_WARM, true)
	draw_rect(
		courtyard.grow(-23.0),
		PALETTE.with_alpha(PALETTE.ROAD_EDGE, 0.62),
		false,
		3.0
	)
	var center := courtyard.get_center()
	draw_circle(center, 21.0, PALETTE.with_alpha(PALETTE.INK_TEAL, 0.86))
	draw_circle(center, 13.0, accent)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(
			center + direction * 26.0,
			center + direction * 45.0,
			PALETTE.with_alpha(accent, 0.74),
			3.0,
			true
		)


func _draw_player_roads() -> void:
	if _player_road_cells.is_empty():
		return
	var all_roads := _formal_road_cells.duplicate(true)
	for cell in _player_road_cells:
		all_roads[Vector2i(cell)] = true
	for cell in _player_road_cells:
		_draw_player_road_tile(Vector2i(cell), all_roads)


func _draw_player_road_tile(cell: Vector2i, all_roads: Dictionary) -> void:
	var rect := Rect2(Vector2(cell) * GRID_SIZE, Vector2.ONE * GRID_SIZE)
	var mask := CITY_GRID_RULES.get_road_mask(cell, all_roads)
	var center := rect.get_center()
	# Shoulder pass keeps neighboring tiles visually joined without turning the
	# whole logical cell into a flat square.
	draw_circle(center, GRID_SIZE * 0.38, PALETTE.ROAD_EDGE)
	if mask & CITY_GRID_RULES.MASK_NORTH:
		draw_line(center, Vector2(center.x, rect.position.y), PALETTE.ROAD_EDGE, GRID_SIZE * 0.74)
	if mask & CITY_GRID_RULES.MASK_EAST:
		draw_line(center, Vector2(rect.end.x, center.y), PALETTE.ROAD_EDGE, GRID_SIZE * 0.74)
	if mask & CITY_GRID_RULES.MASK_SOUTH:
		draw_line(center, Vector2(center.x, rect.end.y), PALETTE.ROAD_EDGE, GRID_SIZE * 0.74)
	if mask & CITY_GRID_RULES.MASK_WEST:
		draw_line(center, Vector2(rect.position.x, center.y), PALETTE.ROAD_EDGE, GRID_SIZE * 0.74)
	draw_circle(center, GRID_SIZE * 0.29, PALETTE.ROAD_SURFACE)
	if mask & CITY_GRID_RULES.MASK_NORTH:
		draw_line(center, Vector2(center.x, rect.position.y), PALETTE.ROAD_SURFACE, GRID_SIZE * 0.54)
	if mask & CITY_GRID_RULES.MASK_EAST:
		draw_line(center, Vector2(rect.end.x, center.y), PALETTE.ROAD_SURFACE, GRID_SIZE * 0.54)
	if mask & CITY_GRID_RULES.MASK_SOUTH:
		draw_line(center, Vector2(center.x, rect.end.y), PALETTE.ROAD_SURFACE, GRID_SIZE * 0.54)
	if mask & CITY_GRID_RULES.MASK_WEST:
		draw_line(center, Vector2(rect.position.x, center.y), PALETTE.ROAD_SURFACE, GRID_SIZE * 0.54)
	var connection_count := _road_connection_count(mask)
	if connection_count >= 3:
		draw_circle(center, GRID_SIZE * 0.20, PALETTE.ROAD_DUST)
		draw_arc(
			center,
			GRID_SIZE * 0.24,
			0.0,
			TAU,
			18,
			PALETTE.ROAD_RUT,
			2.0,
			true
		)
	else:
		draw_circle(center, GRID_SIZE * 0.08, PALETTE.with_alpha(PALETTE.ROAD_RUT, 0.76))


func _road_connection_count(mask: int) -> int:
	var count := 0
	for direction_mask in [
		CITY_GRID_RULES.MASK_NORTH,
		CITY_GRID_RULES.MASK_EAST,
		CITY_GRID_RULES.MASK_SOUTH,
		CITY_GRID_RULES.MASK_WEST,
	]:
		if mask & direction_mask:
			count += 1
	return count
