class_name WorldMapCanvas
extends Node2D


const PLAYER_COLOR := Color(0.20, 0.48, 0.50, 1.0)
const ENEMY_COLOR := Color(0.60, 0.25, 0.20, 1.0)
const FRIENDLY_COLOR := Color(0.55, 0.57, 0.42, 1.0)
const NEUTRAL_COLOR := Color(0.55, 0.52, 0.47, 1.0)
const SELECTED_COLOR := Color(0.92, 0.69, 0.26, 1.0)
const TEXT_COLOR := Color(0.20, 0.19, 0.17, 1.0)

var snapshot: Dictionary = {}
var selected_kind := &""
var selected_id := &""
var planned_route: Dictionary = {}
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func set_snapshot(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	queue_redraw()


func set_selection(kind: StringName, item_id: StringName) -> void:
	selected_kind = kind
	selected_id = item_id
	queue_redraw()


func set_planned_route(value: Dictionary) -> void:
	planned_route = value.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if snapshot.is_empty():
		return
	_draw_geography()
	_draw_roads()
	_draw_route_preview()
	_draw_nodes()
	_draw_formation()
	_draw_compass()


func _draw_geography() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(70.0, 80.0),
			Vector2(1020.0, 80.0),
			Vector2(900.0, 520.0),
			Vector2(560.0, 610.0),
			Vector2(160.0, 470.0),
		]),
		Color(0.70, 0.70, 0.57, 0.52)
	)
	for mountain in [
		Vector2(300.0, 250.0),
		Vector2(470.0, 190.0),
		Vector2(650.0, 275.0),
		Vector2(850.0, 205.0),
	]:
		draw_colored_polygon(
			PackedVector2Array([
				mountain + Vector2(-70.0, 50.0),
				mountain + Vector2(0.0, -70.0),
				mountain + Vector2(72.0, 50.0),
			]),
			Color(0.48, 0.48, 0.42, 0.70)
		)
		draw_polyline(
			PackedVector2Array([
				mountain + Vector2(-70.0, 50.0),
				mountain + Vector2(0.0, -70.0),
				mountain + Vector2(72.0, 50.0),
			]),
			Color(0.34, 0.34, 0.31, 0.65),
			5.0,
			true
		)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(120.0, 930.0),
			Vector2(1050.0, 870.0),
			Vector2(1260.0, 1450.0),
			Vector2(80.0, 1450.0),
		]),
		Color(0.76, 0.72, 0.53, 0.40)
	)
	for tree_position in [
		Vector2(240.0, 610.0),
		Vector2(330.0, 650.0),
		Vector2(260.0, 720.0),
		Vector2(1090.0, 1120.0),
		Vector2(1180.0, 1180.0),
		Vector2(1250.0, 1090.0),
	]:
		draw_circle(tree_position, 42.0, Color(0.32, 0.48, 0.36, 0.60))
		draw_circle(
			tree_position + Vector2(18.0, -22.0),
			30.0,
			Color(0.39, 0.55, 0.39, 0.58)
		)

	var river := PackedVector2Array([
		Vector2(0.0, 530.0),
		Vector2(430.0, 500.0),
		Vector2(820.0, 620.0),
		Vector2(1160.0, 670.0),
		Vector2(1490.0, 625.0),
		Vector2(1780.0, 520.0),
		Vector2(2070.0, 560.0),
		Vector2(2400.0, 720.0),
	])
	draw_polyline(river, Color(0.48, 0.66, 0.68, 0.78), 94.0, true)
	draw_polyline(river, Color(0.68, 0.80, 0.78, 0.74), 56.0, true)
	draw_string(
		_font,
		Vector2(1660.0, 500.0),
		"河湾",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		25,
		Color(0.20, 0.42, 0.45, 0.85)
	)


func _draw_roads() -> void:
	for road in snapshot.get("roads", []):
		var road_id := StringName(road.get("id", &""))
		var path := _to_packed_points(road.get("path", []))
		if path.size() < 2:
			continue
		if selected_kind == &"ROAD" and selected_id == road_id:
			draw_polyline(path, SELECTED_COLOR, 18.0, true)
		var status := StringName(road.get("status", &""))
		var road_color := _road_color(status)
		var width := 8.0
		if status == &"OPEN":
			draw_polyline(path, road_color, width, true)
		else:
			for index in range(path.size() - 1):
				draw_dashed_line(
					path[index],
					path[index + 1],
					road_color,
					width,
					18.0 if status == &"DANGEROUS" else 12.0,
					true,
					true
				)
		if status == &"BLOCKED":
			var blocked_position := _path_midpoint(path)
			draw_line(
				blocked_position + Vector2(-18.0, -18.0),
				blocked_position + Vector2(18.0, 18.0),
				road_color,
				7.0,
				true
			)
			draw_line(
				blocked_position + Vector2(-18.0, 18.0),
				blocked_position + Vector2(18.0, -18.0),
				road_color,
				7.0,
				true
			)
		var label_position := _path_midpoint(path) + Vector2(12.0, -16.0)
		draw_string(
			_font,
			label_position,
			"%s · %s" % [
				str(road.get("name", "")),
				str(road.get("status_label", "")),
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			19,
			road_color.darkened(0.28)
		)


func _draw_route_preview() -> void:
	for road_id in planned_route.get("road_ids", []):
		var road := _find_road(StringName(road_id))
		if road.is_empty():
			continue
		var path := _to_packed_points(road.get("path", []))
		for index in range(path.size() - 1):
			draw_dashed_line(
				path[index],
				path[index + 1],
				Color(0.55, 0.31, 0.67, 0.94),
				13.0,
				24.0,
				true,
				true
			)


func _draw_nodes() -> void:
	for node in snapshot.get("nodes", []):
		var node_id := StringName(node.get("id", &""))
		var position := Vector2(node.get("position", Vector2.ZERO))
		var node_type := str(node.get("type", ""))
		var owner := StringName(node.get("owner", &"NEUTRAL"))
		var color := _owner_color(owner)
		var radius := 52.0 if node_id == &"blackstone_city" else 38.0
		if node_type == "城池":
			radius = 46.0
		if selected_kind == &"NODE" and selected_id == node_id:
			draw_arc(
				position,
				radius + 17.0,
				0.0,
				TAU,
				48,
				SELECTED_COLOR,
				9.0,
				true
			)
		draw_circle(position, radius + 7.0, Color(0.18, 0.18, 0.16, 0.82))
		draw_circle(position, radius, color)
		if node_id == &"blackstone_city" or node_type == "城池":
			var half := Vector2(radius * 0.70, radius * 0.56)
			draw_rect(
				Rect2(position - half, half * 2.0),
				Color(0.90, 0.86, 0.73, 0.88),
				false,
				6.0
			)
		elif node_type == "哨站":
			draw_colored_polygon(
				PackedVector2Array([
					position + Vector2(0.0, -24.0),
					position + Vector2(23.0, 19.0),
					position + Vector2(-23.0, 19.0),
				]),
				Color(0.90, 0.86, 0.73, 0.90)
			)
		elif node_type == "村庄":
			draw_circle(
				position + Vector2(-13.0, 4.0),
				10.0,
				Color(0.90, 0.86, 0.73, 0.90)
			)
			draw_circle(
				position + Vector2(13.0, 4.0),
				10.0,
				Color(0.90, 0.86, 0.73, 0.90)
			)
		else:
			draw_circle(
				position,
				12.0,
				Color(0.90, 0.86, 0.73, 0.90)
			)
		draw_string(
			_font,
			position + Vector2(-radius - 8.0, radius + 34.0),
			"%s · %s" % [
				str(node.get("name", "")),
				str(node.get("owner_label", "")),
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			23 if node_id == &"blackstone_city" else 20,
			TEXT_COLOR
		)
		draw_string(
			_font,
			position + Vector2(-radius - 8.0, radius + 58.0),
			str(node.get("status", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			17,
			color.darkened(0.25)
		)
		if not (node.get("missions", []) as Array).is_empty():
			var marker := position + Vector2(radius + 18.0, -radius - 12.0)
			draw_colored_polygon(
				PackedVector2Array([
					marker + Vector2(0.0, -14.0),
					marker + Vector2(14.0, 0.0),
					marker + Vector2(0.0, 14.0),
					marker + Vector2(-14.0, 0.0),
				]),
				Color(0.93, 0.68, 0.22, 1.0)
			)
			draw_string(
				_font,
				marker + Vector2(-5.0, 6.0),
				"!",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				18,
				Color(0.20, 0.18, 0.14, 1.0)
			)


func _draw_formation() -> void:
	var formation: Dictionary = snapshot.get("formation", {})
	if formation.is_empty():
		return
	var position := Vector2(formation.get("position", Vector2.ZERO))
	if selected_kind == &"FORMATION":
		draw_arc(
			position,
			44.0,
			0.0,
			TAU,
			32,
			SELECTED_COLOR,
			7.0,
			true
		)
	draw_colored_polygon(
		PackedVector2Array([
			position + Vector2(0.0, -30.0),
			position + Vector2(28.0, 0.0),
			position + Vector2(0.0, 30.0),
			position + Vector2(-28.0, 0.0),
		]),
		Color(0.17, 0.35, 0.54, 1.0)
	)
	draw_string(
		_font,
		position + Vector2(38.0, 8.0),
		"%s · %s" % [
			str(formation.get("name", "")),
			str(formation.get("troop_summary", "")),
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color(0.12, 0.24, 0.38, 1.0)
	)


func _draw_compass() -> void:
	var center := Vector2(2225.0, 185.0)
	draw_circle(center, 58.0, Color(0.90, 0.87, 0.78, 0.82))
	draw_arc(
		center,
		58.0,
		0.0,
		TAU,
		32,
		Color(0.28, 0.28, 0.25, 0.65),
		3.0,
		true
	)
	draw_line(center + Vector2(0.0, 34.0), center + Vector2(0.0, -38.0), TEXT_COLOR, 5.0)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -48.0),
			center + Vector2(-10.0, -28.0),
			center + Vector2(10.0, -28.0),
		]),
		ENEMY_COLOR
	)
	draw_string(
		_font,
		center + Vector2(-8.0, -68.0),
		"北",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		TEXT_COLOR
	)


func _find_road(road_id: StringName) -> Dictionary:
	for road in snapshot.get("roads", []):
		if StringName(road.get("id", &"")) == road_id:
			return road as Dictionary
	return {}


func _to_packed_points(value: Variant) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in value:
		points.append(Vector2(point))
	return points


func _path_midpoint(path: PackedVector2Array) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	return path[path.size() >> 1]


func _owner_color(owner: StringName) -> Color:
	match owner:
		&"PLAYER":
			return PLAYER_COLOR
		&"ENEMY":
			return ENEMY_COLOR
		&"FRIENDLY":
			return FRIENDLY_COLOR
		_:
			return NEUTRAL_COLOR


func _road_color(status: StringName) -> Color:
	match status:
		&"OPEN":
			return Color(0.48, 0.41, 0.30, 0.94)
		&"DANGEROUS":
			return Color(0.78, 0.43, 0.18, 0.96)
		&"BLOCKED":
			return Color(0.58, 0.20, 0.18, 0.96)
		&"UNSCOUTED":
			return Color(0.42, 0.43, 0.42, 0.84)
		_:
			return Color(0.45, 0.43, 0.40, 0.80)
