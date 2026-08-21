class_name RegularCitySpatialFoundation
extends Node2D


const CityGateComponent = preload("res://scripts/city_gate_component_r1.gd")
const CITY_GRID_RULES = preload("res://scripts/city_sandbox/city_grid_rules.gd")
const PROFILE_RESOLVER = preload("res://scripts/city_layout_profile_resolver.gd")
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
	# Regular axial city: walls, a civic axis, and distinct wards. This is a
	# graybox spatial layer, intentionally without a permanent logic grid.
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("c6bea2"), true)
	draw_rect(Rect2(Vector2(28.0, 28.0), MAP_SIZE - Vector2(56.0, 56.0)), Color("6d7164"), false, 18.0)
	draw_rect(Rect2(Vector2(74.0, 74.0), MAP_SIZE - Vector2(148.0, 148.0)), Color("d7cfb2"), true)
	_draw_ward(Rect2(150.0, 130.0, 620.0, 410.0), Color("c8bea2"))
	_draw_ward(Rect2(835.0, 130.0, 530.0, 410.0), Color("cec5a9"))
	_draw_ward(Rect2(1430.0, 130.0, 580.0, 410.0), Color("c8bea2"))
	_draw_ward(Rect2(150.0, 770.0, 620.0, 430.0), Color("cec5a9"))
	_draw_ward(Rect2(835.0, 770.0, 530.0, 430.0), Color("c8bea2"))
	_draw_ward(Rect2(1430.0, 770.0, 580.0, 430.0), Color("cec5a9"))
	for road_rect in get_formal_road_rects():
		_draw_road(road_rect)
	_draw_player_roads()
	# This is an open civic court rather than a foreground gate: it anchors the
	# axial roads without becoming a dominant facade in the default viewport.
	var civic_courtyard := get_civic_court_rect()
	draw_rect(civic_courtyard, Color("b89352"), true)
	draw_rect(civic_courtyard, Color("755c35"), false, 4.0)
	draw_rect(civic_courtyard.grow(-24.0), Color("d8cda8"), true)
	draw_circle(civic_courtyard.get_center(), 18.0, Color("a57d3e"))


func _draw_organic_garden_city() -> void:
	# The garden profile stays orthogonal, but its T-junctions, unequal wards,
	# and reserves break the rigid axial cross without introducing a second grid.
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("b8c7a9"), true)
	draw_rect(
		Rect2(Vector2(28.0, 28.0), MAP_SIZE - Vector2(56.0, 56.0)),
		Color("557060"),
		false,
		18.0
	)
	draw_rect(Rect2(Vector2(74.0, 74.0), MAP_SIZE - Vector2(148.0, 148.0)), Color("d1d2af"), true)
	for ward in [
		[Rect2(130.0, 120.0, 640.0, 420.0), Color("c7c7a4")],
		[Rect2(820.0, 120.0, 490.0, 420.0), Color("d0caaa")],
		[Rect2(1450.0, 120.0, 600.0, 420.0), Color("c3c9a4")],
		[Rect2(130.0, 780.0, 640.0, 430.0), Color("d0caaa")],
		[Rect2(820.0, 780.0, 490.0, 430.0), Color("c6cda9")],
		[Rect2(1450.0, 780.0, 600.0, 430.0), Color("d0caaa")],
	]:
		_draw_ward(ward[0], ward[1])
	for reserve_rect in get_garden_reserve_rects():
		draw_rect(reserve_rect, Color("8fb18b"), true)
		draw_rect(reserve_rect.grow(-14.0), Color("6f9a77"), false, 4.0)
		var center := reserve_rect.get_center()
		for offset in [Vector2(-42.0, -24.0), Vector2(30.0, 18.0), Vector2(4.0, -52.0)]:
			draw_circle(center + offset, 18.0, Color("6d966c"))
	for road_rect in get_formal_road_rects():
		_draw_road(road_rect)
	_draw_player_roads()
	var civic_courtyard := get_civic_court_rect()
	draw_rect(civic_courtyard, Color("a78e60"), true)
	draw_rect(civic_courtyard, Color("6f5f42"), false, 4.0)
	draw_rect(civic_courtyard.grow(-22.0), Color("d8cda8"), true)
	draw_circle(civic_courtyard.get_center(), 18.0, Color("7f9c79"))


func _draw_ward(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect.grow(-20.0), Color("dcd4ba"), false, 3.0)
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
	draw_rect(shadow, Color(0.17, 0.17, 0.14, 0.18), true)
	draw_rect(rect, Color("a29b7e"), true)
	var roof := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x * 0.5, -18.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x, 24.0),
		rect.position + Vector2(0.0, 24.0),
	])
	draw_colored_polygon(roof, Color("c2ad7b"))
	draw_rect(rect, Color("756c56"), false, 2.0)


func _draw_road(rect: Rect2) -> void:
	draw_rect(rect, Color("8f8060"), true)
	draw_line(rect.position + Vector2(0.0, rect.size.y * 0.5), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5), Color("c6b889"), 3.0)


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
	var road_color := Color("958665")
	draw_rect(rect.grow(-1.0), road_color, true)
	draw_rect(rect.grow(-1.0), Color("655840"), false, 2.0)
	draw_circle(center, GRID_SIZE * 0.18, Color("c6b889"))
	if mask & CITY_GRID_RULES.MASK_NORTH:
		draw_line(center, Vector2(center.x, rect.position.y), Color("c6b889"), 7.0)
	if mask & CITY_GRID_RULES.MASK_EAST:
		draw_line(center, Vector2(rect.end.x, center.y), Color("c6b889"), 7.0)
	if mask & CITY_GRID_RULES.MASK_SOUTH:
		draw_line(center, Vector2(center.x, rect.end.y), Color("c6b889"), 7.0)
	if mask & CITY_GRID_RULES.MASK_WEST:
		draw_line(center, Vector2(rect.position.x, center.y), Color("c6b889"), 7.0)
