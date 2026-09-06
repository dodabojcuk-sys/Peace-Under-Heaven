class_name WorldMapCanvas
extends Node2D


const PLAYER_COLOR := Color(0.20, 0.48, 0.50, 1.0)
const ENEMY_COLOR := Color(0.60, 0.25, 0.20, 1.0)
const FRIENDLY_COLOR := Color(0.55, 0.57, 0.42, 1.0)
const NEUTRAL_COLOR := Color(0.55, 0.52, 0.47, 1.0)
const SELECTED_COLOR := Color(0.92, 0.69, 0.26, 1.0)
const TEXT_COLOR := Color(0.20, 0.19, 0.17, 1.0)
const LABEL_BACKGROUND := Color(0.91, 0.88, 0.76, 0.90)
const ROUTE_PREVIEW_COLOR := Color(0.49, 0.24, 0.66, 0.96)
const ROUTE_PREVIEW_UNDERLAY := Color(0.95, 0.89, 0.69, 0.92)

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


func get_road_visual_encoding(status: StringName) -> Dictionary:
	match status:
		&"OPEN":
			return {
				"pattern": &"SOLID",
				"symbol": "✓",
				"label": "畅通",
			}
		&"DANGEROUS":
			return {
				"pattern": &"DASHED_WARNING",
				"symbol": "!",
				"label": "危险",
			}
		&"BLOCKED":
			return {
				"pattern": &"BROKEN_BLOCK",
				"symbol": "×",
				"label": "封锁",
			}
		&"UNSCOUTED":
			return {
				"pattern": &"DOTTED_UNKNOWN",
				"symbol": "?",
				"label": "未侦察",
			}
	return {
		"pattern": &"UNKNOWN",
		"symbol": "?",
		"label": "状态未知",
	}


func get_route_preview_visual_encoding() -> Dictionary:
	return {
		"pattern": &"DOUBLE_DASHED_ARROW",
		"label": "计划路线 · 尚未出征",
		"persistent": false,
	}


func get_faction_symbol(owner: StringName) -> String:
	match owner:
		&"PLAYER":
			return "〔我〕"
		&"ENEMY":
			return "〔敌〕"
		&"FRIENDLY":
			return "〔友〕"
		_:
			return "〔中〕"


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
		var encoding := get_road_visual_encoding(status)
		var road_color := _road_color(status)
		var width := 8.0
		if StringName(encoding.pattern) == &"SOLID":
			draw_polyline(path, road_color, width, true)
		else:
			for index in range(path.size() - 1):
				draw_dashed_line(
					path[index],
					path[index + 1],
					road_color,
					width,
					18.0 if status == &"DANGEROUS" else 11.0,
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
		_draw_road_status_marker(path, status, encoding, road_color)
		var label_position := _path_midpoint(path) + Vector2(18.0, -20.0)
		_draw_text_plate(
			label_position,
			"%s %s · %s" % [
				str(encoding.symbol),
				str(road.get("name", "")),
				str(encoding.label),
			],
			18,
			road_color.darkened(0.30)
		)


func _draw_route_preview() -> void:
	var label_drawn := false
	for road_id in planned_route.get("road_ids", []):
		var road := _find_road(StringName(road_id))
		if road.is_empty():
			continue
		var path := _to_packed_points(road.get("path", []))
		for index in range(path.size() - 1):
			draw_line(
				path[index],
				path[index + 1],
				ROUTE_PREVIEW_UNDERLAY,
				20.0,
				true
			)
			draw_dashed_line(
				path[index],
				path[index + 1],
				ROUTE_PREVIEW_COLOR,
				11.0,
				22.0,
				true,
				true
			)
		_draw_route_arrow(path)
		if not label_drawn:
			var route_encoding := get_route_preview_visual_encoding()
			_draw_text_plate(
				_path_midpoint(path) + Vector2(18.0, 38.0),
				str(route_encoding.label),
				18,
				ROUTE_PREVIEW_COLOR.darkened(0.18)
			)
			label_drawn = true


func _draw_nodes() -> void:
	for node in snapshot.get("nodes", []):
		var node_id := StringName(node.get("id", &""))
		var position := Vector2(node.get("position", Vector2.ZERO))
		var node_type := str(node.get("type", ""))
		var owner := StringName(node.get("owner", &"NEUTRAL"))
		var color := _owner_color(owner)
		var radius := _node_visual_radius(node_id, node_type)
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
		draw_circle(position, radius + 9.0, Color(0.18, 0.18, 0.16, 0.86))
		draw_circle(position, radius, color)
		if node_id == &"blackstone_city" or node_type == "城池":
			_draw_city_emblem(position, radius, owner)
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
		var label_position := _node_label_baseline(
			node_id,
			position,
			radius
		)
		_draw_text_plate(
			label_position,
			"%s %s" % [
				get_faction_symbol(owner),
				str(node.get("name", "")),
			],
			23 if node_id == &"blackstone_city" or node_type == "城池" else 20,
			TEXT_COLOR
		)
		_draw_text_plate(
			label_position + Vector2(0.0, 28.0),
			"%s · %s" % [
				str(node.get("owner_label", "")),
				str(node.get("status", "")),
			],
			16,
			color.darkened(0.28)
		)
		if not (node.get("missions", []) as Array).is_empty():
			var marker := position + Vector2(radius + 22.0, -radius - 24.0)
			draw_circle(
				marker,
				18.0,
				Color(0.20, 0.18, 0.14, 0.86)
			)
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
			52.0,
			0.0,
			TAU,
			32,
			SELECTED_COLOR,
			7.0,
			true
		)
	draw_line(
		position + Vector2(-18.0, 30.0),
		position + Vector2(-18.0, -34.0),
		Color(0.12, 0.23, 0.34, 1.0),
		7.0,
		true
	)
	draw_colored_polygon(
		PackedVector2Array([
			position + Vector2(-14.0, -34.0),
			position + Vector2(34.0, -22.0),
			position + Vector2(-14.0, -5.0),
		]),
		Color(0.17, 0.35, 0.54, 1.0)
	)
	draw_circle(
		position + Vector2(-18.0, 31.0),
		10.0,
		Color(0.17, 0.35, 0.54, 1.0)
	)
	draw_string(
		_font,
		position + Vector2(-4.0, -17.0),
		"军",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color(0.94, 0.90, 0.76, 1.0)
	)
	_draw_text_plate(
		position + Vector2(36.0, 10.0),
		"%s · %s" % [
			str(formation.get("name", "")),
			str(formation.get("troop_summary", "")),
		],
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


func _draw_road_status_marker(
	path: PackedVector2Array,
	status: StringName,
	encoding: Dictionary,
	road_color: Color
) -> void:
	var marker := _path_midpoint(path)
	match status:
		&"DANGEROUS":
			draw_colored_polygon(
				PackedVector2Array([
					marker + Vector2(0.0, -18.0),
					marker + Vector2(17.0, 14.0),
					marker + Vector2(-17.0, 14.0),
				]),
				Color(0.94, 0.69, 0.22, 1.0)
			)
		&"UNSCOUTED":
			draw_circle(
				marker,
				17.0,
				Color(0.91, 0.88, 0.76, 0.96)
			)
			draw_arc(
				marker,
				17.0,
				0.0,
				TAU,
				24,
				road_color,
				4.0,
				true
			)
		&"OPEN":
			draw_circle(
				marker,
				15.0,
				Color(0.91, 0.88, 0.76, 0.92)
			)
			draw_arc(
				marker,
				15.0,
				0.0,
				TAU,
				24,
				road_color,
				3.0,
				true
			)
		&"BLOCKED":
			return
	draw_string(
		_font,
		marker + Vector2(-6.0, 7.0),
		str(encoding.symbol),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		19,
		road_color.darkened(0.25)
	)


func _draw_route_arrow(path: PackedVector2Array) -> void:
	if path.size() < 2:
		return
	var center_index := maxi((path.size() - 1) >> 1, 0)
	var start := path[center_index]
	var end := path[center_index + 1]
	var direction := (end - start).normalized()
	if direction.is_zero_approx():
		return
	var midpoint := start.lerp(end, 0.5)
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			midpoint + direction * 22.0,
			midpoint - direction * 14.0 + side * 14.0,
			midpoint - direction * 14.0 - side * 14.0,
		]),
		ROUTE_PREVIEW_COLOR
	)


func _draw_city_emblem(
	position: Vector2,
	radius: float,
	owner: StringName
) -> void:
	draw_arc(
		position,
		radius - 8.0,
		0.0,
		TAU,
		40,
		Color(0.92, 0.87, 0.72, 0.92),
		4.0,
		true
	)
	var half := Vector2(radius * 0.66, radius * 0.52)
	draw_rect(
		Rect2(position - half, half * 2.0),
		Color(0.92, 0.87, 0.72, 0.94),
		false,
		6.0
	)
	for offset in [-0.46, 0.0, 0.46]:
		var tower_center := position + Vector2(radius * offset, -half.y)
		draw_rect(
			Rect2(tower_center - Vector2(7.0, 9.0), Vector2(14.0, 18.0)),
			Color(0.92, 0.87, 0.72, 0.94)
		)
	var flag_color := _owner_color(owner).lightened(0.06)
	var flag_origin := position + Vector2(radius * 0.64, -radius * 0.64)
	draw_line(
		flag_origin,
		flag_origin + Vector2(0.0, -34.0),
		Color(0.18, 0.18, 0.16, 0.90),
		4.0,
		true
	)
	draw_colored_polygon(
		PackedVector2Array([
			flag_origin + Vector2(2.0, -34.0),
			flag_origin + Vector2(34.0, -25.0),
			flag_origin + Vector2(2.0, -15.0),
		]),
		flag_color
	)
	draw_string(
		_font,
		flag_origin + Vector2(7.0, -21.0),
		"我" if owner == &"PLAYER" else "敌",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(0.96, 0.92, 0.80, 1.0)
	)


func _draw_text_plate(
	baseline_position: Vector2,
	text: String,
	font_size: int,
	color: Color
) -> void:
	var text_size := _font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	draw_rect(
		Rect2(
			baseline_position + Vector2(-6.0, -font_size - 4.0),
			text_size + Vector2(12.0, 9.0)
		),
		LABEL_BACKGROUND
	)
	draw_string(
		_font,
		baseline_position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)


func _node_visual_radius(node_id: StringName, node_type: String) -> float:
	if node_id == &"blackstone_city" or node_type == "城池":
		return 56.0
	return 38.0


func _node_label_baseline(
	node_id: StringName,
	position: Vector2,
	radius: float
) -> Vector2:
	if node_id == &"southern_village":
		return position + Vector2(-radius - 10.0, -radius - 34.0)
	return position + Vector2(-radius - 10.0, radius + 35.0)


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
