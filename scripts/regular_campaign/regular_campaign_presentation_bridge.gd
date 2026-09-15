class_name RegularCampaignPresentationBridge
extends Control

## Data-free bridge from the regular-campaign read model to the established
## theater and city presentation components. It never owns a clock, resource,
## building record, permission, or input decision.

const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const LOW_POLY = preload("res://scripts/macro_march/macro_march_low_poly_presentation.gd")
const CITY_FOUNDATION = preload("res://scripts/regular_city_spatial_foundation.gd")
const BUILDING_VISUAL = preload("res://scripts/graybox_building_visual.gd")
const CITY_MINIMAP = preload("res://scripts/city_minimap_r1.gd")
const PALETTE = preload("res://resources/visuals/northern_campaign_palette.gd")
const BUILDING_ART := {
	&"FARM": preload("res://assets/regular_campaign/art_r1/runtime/farm.png"),
	&"LOGGING": preload("res://assets/regular_campaign/art_r1/runtime/logging.png"),
	&"WAREHOUSE": preload("res://assets/regular_campaign/art_r1/runtime/warehouse.png"),
	&"CLINIC": preload("res://assets/regular_campaign/art_r1/runtime/clinic.png"),
}

const CITY_MAP_SIZE := Vector2(2200.0, 1400.0)
const CITY_PLOT_CELLS := [
	Vector2i(9, 8), Vector2i(19, 8), Vector2i(36, 8),
	Vector2i(9, 18), Vector2i(19, 18), Vector2i(36, 18),
]
const CITY_PLOT_FOOTPRINTS := [
	Vector2i(4, 3), Vector2i(4, 3), Vector2i(4, 3),
	Vector2i(4, 3), Vector2i(4, 3), Vector2i(4, 3),
]

var _low_poly: MacroMarchLowPolyPresentation
var _city_root := Node2D.new()
var _foundation: RegularCitySpatialFoundation
var _minimap: CityMinimapR1
var _building_visuals: Dictionary = {}
var _model: Dictionary = {}
var _mode := &"THEATER"
var _selected_building_id := &""
var _selected_plot := -1
var _camera_center := Vector2(750.0, 490.0)
var _camera_zoom := 0.50
var _city_zoom := 1.0
var _city_pan := Vector2.ZERO
var _last_production_totals: Dictionary = {}
var _production_totals_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_low_poly = LOW_POLY.new()
	_low_poly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_low_poly)
	_city_root.name = "FrontlineCityWorld"
	add_child(_city_root)
	_foundation = CITY_FOUNDATION.new()
	_foundation.name = "RegularCitySpatialFoundation"
	_foundation.city_id = &"blackstone_city"
	_city_root.add_child(_foundation)
	# The original foundation normally sits behind permanent-city siblings. In
	# this isolated projection root there is no opaque city controller sibling,
	# so keep it on this root's base layer instead of behind the campaign panel.
	_foundation.z_index = 0
	_minimap = CITY_MINIMAP.new()
	_minimap.name = "CityMinimapR1"
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)
	_minimap.set_layout_profile(
		_foundation.get_layout_profile_id(),
		_foundation.get_formal_road_cells(),
		_foundation.get_formal_reserved_cells()
	)
	resized.connect(_layout_presentations)
	_layout_presentations()
	_sync()


func set_projection(
	model: Dictionary,
	mode: StringName,
	selected_army_id: StringName,
	selected_building_id: StringName,
	selected_plot: int
) -> void:
	_model = model.duplicate(true)
	_mode = mode
	_selected_building_id = selected_building_id
	_selected_plot = selected_plot
	if is_node_ready():
		_sync(selected_army_id)


func theater_world_to_local(world_position: Vector2) -> Vector2:
	if is_instance_valid(_low_poly) and _low_poly.visible:
		return _low_poly.position + _low_poly.project_world_to_viewport(world_position)
	return Vector2.ZERO


func is_low_poly_theater_visible() -> bool:
	return is_instance_valid(_low_poly) and _low_poly.visible


func pan_surface(screen_delta: Vector2) -> void:
	if _mode == &"THEATER":
		var projected := _project_theater(_camera_center) - screen_delta / maxf(_camera_zoom, 0.01)
		_camera_center = _unproject_theater(projected)
	else:
		_city_pan += screen_delta
	_layout_presentations()
	_sync()


func zoom_surface(factor: float, anchor: Vector2) -> void:
	if _mode == &"THEATER":
		_camera_zoom = clampf(_camera_zoom * factor, 0.48, 2.4)
	else:
		var old_scale := maxf(_city_root.scale.x, 0.01)
		var world_anchor := (anchor - _city_root.position) / old_scale
		_city_zoom = clampf(_city_zoom * factor, 1.0, 2.4)
		_layout_presentations()
		_city_root.position = anchor - world_anchor * _city_root.scale.x
		_city_pan = _city_root.position - (size - CITY_MAP_SIZE * _city_root.scale.x) * 0.5
	_sync()


func city_plot_rect(plot: int) -> Rect2:
	if plot < 0 or plot >= CITY_PLOT_CELLS.size():
		return Rect2()
	var world_rect := Rect2(
		Vector2(CITY_PLOT_CELLS[plot]) * 40.0,
		Vector2(CITY_PLOT_FOOTPRINTS[plot]) * 40.0
	)
	return Rect2(_city_root.position + world_rect.position * _city_root.scale, world_rect.size * _city_root.scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_presentations()
		_sync()


func _layout_presentations() -> void:
	if not is_instance_valid(_low_poly):
		return
	_low_poly.position = Vector2.ZERO
	_low_poly.size = size
	# Preserve a readable lower bound on the established city camera scale.
	# Compact layouts may crop the outer wall slightly; the existing drag/zoom
	# input reaches those edges without changing plot or building coordinates.
	var base_scale := maxf(minf(size.x / CITY_MAP_SIZE.x, size.y / CITY_MAP_SIZE.y) * 0.96, 0.34)
	var city_scale := base_scale * _city_zoom
	_city_root.scale = Vector2.ONE * city_scale
	_city_root.position = (size - CITY_MAP_SIZE * city_scale) * 0.5 + _city_pan
	if is_instance_valid(_minimap):
		_minimap.position = Vector2(maxf(8.0, size.x - 196.0), maxf(8.0, size.y - 128.0))
		_minimap.size = Vector2(184.0, 116.0)
		_update_minimap()


func _sync(selected_army_id: StringName = &"") -> void:
	if not is_instance_valid(_low_poly) or not is_instance_valid(_foundation):
		return
	var theater_visible := _mode == &"THEATER" and _low_poly.is_available()
	_low_poly.visible = theater_visible
	_city_root.visible = _mode == &"CITY"
	_minimap.visible = _mode == &"CITY"
	if theater_visible:
		THEATER.use_regular_definition()
		_low_poly.sync(
			THEATER,
			_theater_model(),
			_theater_field(),
			_camera_center,
			_camera_zoom,
			selected_army_id
		)
	if _mode == &"CITY":
		_sync_city()


func _theater_model() -> Dictionary:
	var cities: Dictionary = {}
	for point_id_value in Dictionary(_model.get("points", {})).keys():
		var point_id := StringName(point_id_value)
		var point := Dictionary(Dictionary(_model.get("points", {})).get(point_id, {}))
		cities[point_id] = {
			"military_controller_faction_id": &"player" if bool(point.get("controlled", false)) else &"enemy"
		}
	return {
		"armies": Array(_model.get("armies", [])).duplicate(true),
		"sieges": Array(_model.get("sieges", [])).duplicate(true),
		"war_loop": {"cities_by_id": cities},
	}


func _theater_field() -> Dictionary:
	var roads: Dictionary = {}
	for route_id_value in Dictionary(_model.get("routes", {})).keys():
		var route_id := StringName(route_id_value)
		var route := Dictionary(Dictionary(_model.get("routes", {})).get(route_id, {}))
		roads[route_id] = {
			"road_id": route_id,
			"route_world_points": Array(route.get("world_points", route.get("points", []))).duplicate(true),
			"road_kind": StringName(route.get("road_kind", &"NORMAL")),
			"state": StringName(route.get("state", &"READY")),
		}
	return {
		"roads_by_id": roads,
		"camps_by_id": {},
		"watchtowers_by_id": {},
		"specialists_by_id": {},
		"visible_patrols_by_id": {},
		"projects_by_id": {},
	}


func _sync_city() -> void:
	var view_context := Dictionary(_model.get("view_context", {}))
	var city_id := StringName(view_context.get("city_id", &"blackstone_city"))
	if city_id != &"" and city_id != _foundation.get_city_id() and _foundation.set_city_id(city_id):
		_minimap.set_layout_profile(
			_foundation.get_layout_profile_id(),
			_foundation.get_formal_road_cells(),
			_foundation.get_formal_reserved_cells()
		)
	var records: Array = Array(Dictionary(_model.get("local", {})).get("buildings", [])).duplicate(true)
	var project := Dictionary(Dictionary(_model.get("local", {})).get("project", {}))
	var seen: Dictionary = {}
	var occupied_rects: Array[Rect2] = []
	for record_value in records:
		var record := Dictionary(record_value)
		var id := StringName(record.get("id", &""))
		seen[id] = true
		occupied_rects.append(_plot_world_rect(int(record.get("plot", -1))))
		_sync_building_visual(id, record, false)
	if not project.is_empty():
		var project_id := StringName(project.get("id", &""))
		seen[project_id] = true
		occupied_rects.append(_plot_world_rect(int(project.get("plot", -1))))
		_sync_building_visual(project_id, project, true)
	for id_value in _building_visuals.keys():
		if seen.has(id_value):
			continue
		var stale := _building_visuals[id_value] as Node
		if is_instance_valid(stale):
			stale.queue_free()
		_building_visuals.erase(id_value)
	var road_cells := _connected_road_cells(records)
	_foundation.set_player_road_cells(road_cells)
	_foundation.set_occupied_presentation_rects(occupied_rects)
	_minimap.set_player_road_cells(road_cells)
	_update_minimap()
	_sync_production_feedback()


func _update_minimap() -> void:
	if not is_instance_valid(_minimap) or _city_root.scale.x <= 0.0:
		return
	var visible_world_size := size / _city_root.scale.x
	var camera_center := (size * 0.5 - _city_root.position) / _city_root.scale.x
	_minimap.update_world_view(camera_center, 1.0, Rect2(Vector2.ZERO, visible_world_size))


func _sync_building_visual(id: StringName, record: Dictionary, constructing: bool) -> void:
	var plot := int(record.get("plot", -1))
	if plot < 0 or plot >= CITY_PLOT_CELLS.size():
		return
	var visual := _building_visuals.get(id) as GrayboxBuildingVisual
	var kind := StringName(record.get("kind", &""))
	var style := _building_style(kind)
	var progress := 1.0
	if constructing:
		progress = float(record.get("progress_ms", 0)) / maxf(float(record.get("required_ms", 1)), 1.0)
	if visual == null:
		visual = BUILDING_VISUAL.new()
		visual.name = String(id).replace(".", "_")
		visual.set_meta("regular_building_id", id)
		visual.position = Vector2(CITY_PLOT_CELLS[plot]) * 40.0
		visual.configure(
			StringName(style.definition_id), String(style.display_name), String(style.building_type),
			CITY_PLOT_FOOTPRINTS[plot], 0, Color(style.body_color), Color(style.outline_color),
			true, false, &"constructing" if constructing else &"running", progress,
			&"disconnected" if not bool(record.get("connected", false)) else &"connected"
		)
		_city_root.add_child(visual)
		_building_visuals[id] = visual
		if BUILDING_ART.has(kind):
			visual.set_art_texture(BUILDING_ART[kind])
	var is_selected := id == _selected_building_id or plot == _selected_plot
	visual.update_presentation(
		&"constructing" if constructing else &"running",
		progress,
		&"connected" if bool(record.get("connected", false)) else &"disconnected",
		is_selected,
		is_selected or not bool(record.get("connected", false))
	)
	var paused := bool(_model.get("paused", false))
	var operational := (
		not constructing
		and bool(record.get("connected", false))
		and int(record.get("workers", 0)) > 0
	)
	visual.set_activity_state(constructing and bool(record.get("advancing", true)) and not paused, operational and not paused, paused)


func _plot_world_rect(plot: int) -> Rect2:
	if plot < 0 or plot >= CITY_PLOT_CELLS.size():
		return Rect2()
	return Rect2(Vector2(CITY_PLOT_CELLS[plot]) * 40.0, Vector2(CITY_PLOT_FOOTPRINTS[plot]) * 40.0)


func _sync_production_feedback() -> void:
	var totals := Dictionary(_model.get("totals", {}))
	if not _production_totals_ready:
		_last_production_totals = totals.duplicate(true)
		_production_totals_ready = true
		return
	var changes := {
		&"FARM": int(totals.get("food_produced", 0)) - int(_last_production_totals.get("food_produced", 0)),
		&"LOGGING": int(totals.get("wood_produced", 0)) - int(_last_production_totals.get("wood_produced", 0)),
	}
	for kind in changes:
		var amount := int(changes[kind])
		if amount <= 0:
			continue
		for id_value in _building_visuals:
			var visual := _building_visuals[id_value] as GrayboxBuildingVisual
			if is_instance_valid(visual) and visual.definition_id == StringName(_building_style(kind).definition_id):
				visual.show_deposit(amount, "粮" if kind == &"FARM" else "木")
				break
	_last_production_totals = totals.duplicate(true)


func _building_style(kind: StringName) -> Dictionary:
	match kind:
		&"FARM":
			return {"definition_id": &"farm", "display_name": "农田", "building_type": "农业", "body_color": PALETTE.JADE, "outline_color": PALETTE.INK_TEAL}
		&"LOGGING":
			return {"definition_id": &"logging_camp", "display_name": "伐木场", "building_type": "采集", "body_color": PALETTE.COPPER_GOLD, "outline_color": PALETTE.INK_BLUE}
		&"WAREHOUSE":
			return {"definition_id": &"warehouse", "display_name": "仓储", "building_type": "仓储", "body_color": PALETTE.GROUND_COOL, "outline_color": PALETTE.INK_TEAL}
		&"CLINIC":
			return {"definition_id": &"clinic", "display_name": "医舍", "building_type": "医疗", "body_color": PALETTE.GROUND_PALE, "outline_color": PALETTE.INK_BLUE}
	return {"definition_id": &"building", "display_name": "设施", "building_type": "设施", "body_color": PALETTE.GROUND_COOL, "outline_color": PALETTE.INK_TEAL}


func _project_theater(world: Vector2) -> Vector2:
	return Vector2(world.x + world.y * 0.20, world.y * 0.72)


func _unproject_theater(projected: Vector2) -> Vector2:
	var world_y := projected.y / 0.72
	return Vector2(projected.x - world_y * 0.20, world_y)


func _connected_road_cells(records: Array) -> Dictionary:
	var cells: Dictionary = {}
	for record_value in records:
		var record := Dictionary(record_value)
		if not bool(record.get("connected", false)):
			continue
		var plot := int(record.get("plot", -1))
		if plot < 0 or plot >= CITY_PLOT_CELLS.size():
			continue
		var cell := Vector2i(CITY_PLOT_CELLS[plot])
		var x: int = cell.x + 1
		var start_y: int = cell.y + Vector2i(CITY_PLOT_FOOTPRINTS[plot]).y
		var target_y: int = 13 if cell.y < 13 else 14
		var step: int = 1 if start_y <= target_y else -1
		for y in range(start_y, target_y + step, step):
			cells[Vector2i(x, y)] = true
	return cells
