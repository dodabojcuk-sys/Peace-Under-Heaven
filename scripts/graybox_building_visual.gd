class_name GrayboxBuildingVisual
extends Node2D

## Shared, data-free building presentation for the regular and future city
## profiles.  The controller remains the only owner of building state; this
## node only turns the supplied definition, footprint, orientation and
## lifecycle into replaceable graybox geometry.

const GRID_SIZE := 40.0
const ORIENTATION_NORTH := 0
const ORIENTATION_EAST := 1
const ORIENTATION_SOUTH := 2
const ORIENTATION_WEST := 3
const ORIENTATION_NAMES := ["北", "东", "南", "西"]

var definition_id: StringName = &""
var display_name := "建筑"
var building_type := ""
var footprint := Vector2i.ONE
var orientation := ORIENTATION_NORTH
var lifecycle_state: StringName = &"running"
var connection_state: StringName = &"not_required"
var body_color := Color("718080")
var outline_color := Color("2e3b3d")
var requires_road := false
var is_road := false
var is_fixed := false
var presentation_progress := 1.0
var selected := false
var show_entrance_marker := false

var _presentation_stage: StringName = &"completed"
var _construction_pulse := 0.0
var _visual_nodes_ready := false


func configure(
	new_definition_id: StringName,
	new_display_name: String,
	new_building_type: String,
	new_footprint: Vector2i,
	new_orientation: int,
	new_body_color: Color,
	new_outline_color: Color,
	new_requires_road: bool,
	new_is_road: bool,
	new_lifecycle_state: StringName = &"running",
	new_progress := 1.0,
	new_connection_state: StringName = &"not_required",
	new_is_fixed := false
) -> void:
	definition_id = new_definition_id
	display_name = new_display_name
	building_type = new_building_type
	footprint = Vector2i(
		maxi(new_footprint.x, 1),
		maxi(new_footprint.y, 1)
	)
	orientation = posmod(new_orientation, 4)
	body_color = new_body_color
	outline_color = new_outline_color
	requires_road = new_requires_road
	is_road = new_is_road
	lifecycle_state = new_lifecycle_state
	connection_state = new_connection_state
	is_fixed = new_is_fixed
	set_presentation_progress(new_progress)
	_ensure_visual_nodes()
	_rebuild_geometry()
	_apply_presentation_state()
	queue_redraw()


func update_presentation(
	new_lifecycle_state: StringName,
	new_progress: float,
	new_connection_state: StringName,
	new_selected := false,
	new_show_entrance_marker := false
) -> void:
	lifecycle_state = new_lifecycle_state
	connection_state = new_connection_state
	selected = new_selected
	show_entrance_marker = new_show_entrance_marker
	set_presentation_progress(new_progress)
	_apply_presentation_state()
	queue_redraw()


func set_presentation_progress(new_progress: float) -> void:
	presentation_progress = clampf(new_progress, 0.0, 1.0)
	_presentation_stage = _get_stage_for_progress()
	_apply_progress_geometry()


func set_selected_state(is_selected: bool, show_entrance := false) -> void:
	selected = is_selected
	show_entrance_marker = show_entrance
	_apply_presentation_state()
	queue_redraw()


func get_presentation_stage() -> StringName:
	return _presentation_stage


func get_orientation_label() -> String:
	return ORIENTATION_NAMES[orientation]


func _ready() -> void:
	_ensure_visual_nodes()
	_apply_presentation_state()


func _process(delta: float) -> void:
	if lifecycle_state != &"constructing":
		return
	_construction_pulse = fmod(_construction_pulse + delta, 1.8)
	var marker := get_node_or_null("ConstructionMarker") as Line2D
	if marker != null and marker.visible:
		var pulse := 0.78 + 0.22 * sin(_construction_pulse * TAU / 1.8)
		marker.modulate.a = pulse
	queue_redraw()


func _ensure_visual_nodes() -> void:
	if _visual_nodes_ready:
		return
	_visual_nodes_ready = true
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	add_child(shadow)
	var foundation := Polygon2D.new()
	foundation.name = "Foundation"
	add_child(foundation)
	var body := Polygon2D.new()
	body.name = "Body"
	add_child(body)
	var side := Polygon2D.new()
	side.name = "Side"
	add_child(side)
	var roof := Polygon2D.new()
	roof.name = "Roof"
	add_child(roof)
	var detail := Polygon2D.new()
	detail.name = "Detail"
	add_child(detail)
	var farm_rows := Node2D.new()
	farm_rows.name = "FarmRows"
	for row_index in range(3):
		var row := Line2D.new()
		row.name = "Row%d" % row_index
		row.width = 3.0
		row.antialiased = true
		farm_rows.add_child(row)
	add_child(farm_rows)
	var entrance := Polygon2D.new()
	entrance.name = "Entrance"
	add_child(entrance)
	var entrance_marker := Polygon2D.new()
	entrance_marker.name = "EntranceMarker"
	add_child(entrance_marker)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 2.5
	add_child(outline)
	var construction_marker := Line2D.new()
	construction_marker.name = "ConstructionMarker"
	construction_marker.width = 2.5
	add_child(construction_marker)
	var label := Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("f2efe1"))
	add_child(label)


func _rebuild_geometry() -> void:
	if not _visual_nodes_ready:
		return
	var world_size := Vector2(footprint) * GRID_SIZE
	var inset := 4.0
	var depth := clampf(minf(world_size.x, world_size.y) * 0.18, 8.0, 18.0)
	var shadow := get_node("Shadow") as Polygon2D
	shadow.polygon = PackedVector2Array([
		Vector2(12.0, 16.0),
		Vector2(world_size.x + 12.0, 16.0),
		Vector2(world_size.x + 12.0, world_size.y + 12.0),
		Vector2(12.0, world_size.y + 12.0),
	])
	shadow.color = Color(0.12, 0.14, 0.13, 0.28)
	var foundation := get_node("Foundation") as Polygon2D
	foundation.polygon = _rectangle_polygon(world_size)
	var body_rect := Rect2(
		Vector2(inset, depth + inset),
		Vector2(world_size.x - inset * 2.0, world_size.y - depth - inset * 2.0)
	)
	var body := get_node("Body") as Polygon2D
	body.polygon = _rectangle_polygon(body_rect.size, body_rect.position)
	var side := get_node("Side") as Polygon2D
	side.polygon = _side_polygon(body_rect)
	var roof := get_node("Roof") as Polygon2D
	roof.polygon = _roof_polygon(world_size, depth)
	var detail := get_node("Detail") as Polygon2D
	detail.polygon = _detail_polygon(world_size, body_rect)
	var farm_rows := get_node("FarmRows") as Node2D
	for row_index in range(3):
		var row := farm_rows.get_node("Row%d" % row_index) as Line2D
		var offset := 10.0 + row_index * 12.0
		if orientation in [ORIENTATION_EAST, ORIENTATION_WEST]:
			row.points = PackedVector2Array([
				Vector2(body_rect.position.x + offset, body_rect.position.y + 8.0),
				Vector2(body_rect.position.x + offset, body_rect.end.y - 8.0),
			])
		else:
			row.points = PackedVector2Array([
				Vector2(body_rect.position.x + 8.0, body_rect.position.y + offset),
				Vector2(body_rect.end.x - 8.0, body_rect.position.y + offset),
			])
		row.default_color = Color("6f713f")
	var entrance := get_node("Entrance") as Polygon2D
	entrance.polygon = _entrance_polygon(world_size, orientation)
	var entrance_marker := get_node("EntranceMarker") as Polygon2D
	entrance_marker.polygon = _entrance_marker_polygon(world_size, orientation)
	var outline := get_node("Outline") as Line2D
	outline.points = _rectangle_outline_points(world_size)
	var construction_marker := get_node("ConstructionMarker") as Line2D
	construction_marker.points = PackedVector2Array([
		Vector2(inset + 3.0, inset + 3.0),
		Vector2(world_size.x - inset - 3.0, world_size.y - inset - 3.0),
		Vector2(inset + 3.0, world_size.y - inset - 3.0),
		Vector2(world_size.x - inset - 3.0, inset + 3.0),
	])
	var label := get_node("Label") as Label
	label.position = Vector2(inset + 2.0, depth + inset + 2.0)
	label.size = Vector2(
		maxf(world_size.x - inset * 2.0 - 4.0, 20.0),
		maxf(world_size.y - depth - inset * 2.0 - 4.0, 20.0)
	)
	_apply_progress_geometry()


func _apply_progress_geometry() -> void:
	if not _visual_nodes_ready:
		return
	var progress := presentation_progress
	var foundation := get_node("Foundation") as Polygon2D
	var body := get_node("Body") as Polygon2D
	var side := get_node("Side") as Polygon2D
	var roof := get_node("Roof") as Polygon2D
	var detail := get_node("Detail") as Polygon2D
	var farm_rows := get_node("FarmRows") as Node2D
	var entrance := get_node("Entrance") as Polygon2D
	foundation.modulate.a = 0.9 if progress > 0.0 else 0.72
	body.modulate.a = lerpf(0.16, 1.0, clampf(progress * 1.55, 0.0, 1.0))
	side.modulate.a = lerpf(0.05, 1.0, clampf((progress - 0.08) * 1.7, 0.0, 1.0))
	roof.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.3) * 1.55, 0.0, 1.0))
	detail.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.5) * 2.0, 0.0, 1.0))
	farm_rows.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.18) * 1.6, 0.0, 1.0))
	entrance.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.35) * 2.0, 0.0, 1.0))


func _apply_presentation_state() -> void:
	if not _visual_nodes_ready:
		return
	var is_constructing := lifecycle_state == &"constructing"
	var is_disconnected := (
		requires_road and connection_state == &"disconnected"
	)
	var shadow := get_node("Shadow") as Polygon2D
	var foundation := get_node("Foundation") as Polygon2D
	var body := get_node("Body") as Polygon2D
	var side := get_node("Side") as Polygon2D
	var roof := get_node("Roof") as Polygon2D
	var detail := get_node("Detail") as Polygon2D
	var farm_rows := get_node("FarmRows") as Node2D
	var entrance := get_node("Entrance") as Polygon2D
	var entrance_marker := get_node("EntranceMarker") as Polygon2D
	var outline := get_node("Outline") as Line2D
	var construction_marker := get_node("ConstructionMarker") as Line2D
	var label := get_node("Label") as Label
	shadow.visible = not is_road
	foundation.visible = true
	body.visible = not is_road
	side.visible = not is_road
	roof.visible = not is_road
	detail.visible = not is_road
	farm_rows.visible = not is_road and definition_id == &"building.farm.t1"
	entrance.visible = not is_road
	entrance_marker.visible = (
		not is_road and (show_entrance_marker or is_disconnected)
	)
	construction_marker.visible = not is_road and is_constructing
	outline.visible = not is_road
	label.visible = not is_road and (selected or is_constructing or is_fixed)
	label.text = (
		"%s\n施工中 · %s" % [display_name, _stage_label()]
		if is_constructing
		else display_name
	)
	foundation.color = Color("75694f") if is_constructing else Color("8b7b5d")
	body.color = body_color.lerp(Color("767064"), 0.38) if is_constructing else body_color
	side.color = body_color.darkened(0.30)
	roof.color = body_color.lightened(0.18)
	detail.color = _detail_color()
	entrance.color = Color("332c22")
	entrance_marker.color = (
		Color("d39b45") if is_disconnected else Color("4d9a78")
	)
	outline.default_color = (
		Color("e2bb65") if selected else outline_color
	)
	construction_marker.default_color = Color("e7b760")
	label.add_theme_color_override(
		"font_color",
		Color("f6e7b2") if is_constructing else Color("f2efe1")
	)
	_apply_progress_geometry()


func _get_stage_for_progress() -> StringName:
	if lifecycle_state != &"constructing":
		return &"completed"
	if presentation_progress < 0.30:
		return &"foundation"
	if presentation_progress < 0.72:
		return &"frame"
	return &"partial_mass"


func _stage_label() -> String:
	match _presentation_stage:
		&"foundation":
			return "地基"
		&"frame":
			return "主体形成"
		&"partial_mass":
			return "收尾"
	return "落成"


func _detail_color() -> Color:
	if definition_id == &"building.farm.t1":
		return Color("a7a45b")
	if definition_id == &"building.logging_camp.t1":
		return Color("b4844f")
	if definition_id == &"building.warehouse.t1":
		return Color("b7a66f")
	if definition_id == &"building.watchtower.t1":
		return Color("8a7250")
	if definition_id in [&"manor", &"command_platform"]:
		return Color("d7b668")
	return body_color.lightened(0.28)


func _roof_polygon(world_size: Vector2, depth: float) -> PackedVector2Array:
	var ridge_offset := 0.0
	var ridge_ratio := 0.5
	if orientation in [ORIENTATION_EAST, ORIENTATION_WEST]:
		ridge_offset = world_size.x * 0.08
		ridge_ratio = 0.42 if orientation == ORIENTATION_EAST else 0.58
	var ridge := Vector2(world_size.x * ridge_ratio + ridge_offset, 0.0)
	return PackedVector2Array([
		Vector2(4.0, depth + 3.0),
		ridge,
		Vector2(world_size.x - 4.0, depth + 3.0),
		Vector2(world_size.x - 8.0, depth + 16.0),
		Vector2(8.0, depth + 16.0),
	])


func _detail_polygon(world_size: Vector2, body_rect: Rect2) -> PackedVector2Array:
	var center := body_rect.get_center()
	var width := minf(world_size.x * 0.32, 26.0)
	if definition_id == &"building.farm.t1":
		return PackedVector2Array([
			Vector2(center.x - width * 0.5, center.y - 5.0),
			Vector2(center.x + width * 0.5, center.y - 5.0),
			Vector2(center.x + width * 0.5, center.y + 5.0),
			Vector2(center.x - width * 0.5, center.y + 5.0),
		])
	if definition_id == &"building.logging_camp.t1":
		return PackedVector2Array([
			Vector2(center.x - width * 0.5, center.y),
			Vector2(center.x + width * 0.5, center.y),
			Vector2(center.x + width * 0.5, center.y + 10.0),
			Vector2(center.x - width * 0.5, center.y + 10.0),
		])
	if definition_id == &"building.warehouse.t1":
		return PackedVector2Array([
			Vector2(body_rect.position.x + 12.0, body_rect.position.y + 9.0),
			Vector2(body_rect.end.x - 12.0, body_rect.position.y + 9.0),
			Vector2(body_rect.end.x - 12.0, body_rect.position.y + 16.0),
			Vector2(body_rect.position.x + 12.0, body_rect.position.y + 16.0),
		])
	return PackedVector2Array([
		Vector2(center.x - width * 0.5, center.y - 4.0),
		Vector2(center.x + width * 0.5, center.y - 4.0),
		Vector2(center.x + width * 0.5, center.y + 4.0),
		Vector2(center.x - width * 0.5, center.y + 4.0),
	])


func _side_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x, rect.end.y - 10.0),
		Vector2(rect.end.x, rect.end.y - 10.0),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])


func _entrance_polygon(world_size: Vector2, direction: int) -> PackedVector2Array:
	var width := minf(20.0, minf(world_size.x, world_size.y) * 0.3)
	match direction:
		ORIENTATION_NORTH:
			return PackedVector2Array([
				Vector2(world_size.x * 0.5 - width * 0.5, 0.0),
				Vector2(world_size.x * 0.5 + width * 0.5, 0.0),
				Vector2(world_size.x * 0.5 + width * 0.5, 11.0),
				Vector2(world_size.x * 0.5 - width * 0.5, 11.0),
			])
		ORIENTATION_EAST:
			return PackedVector2Array([
				Vector2(world_size.x - 11.0, world_size.y * 0.5 - width * 0.5),
				Vector2(world_size.x, world_size.y * 0.5 - width * 0.5),
				Vector2(world_size.x, world_size.y * 0.5 + width * 0.5),
				Vector2(world_size.x - 11.0, world_size.y * 0.5 + width * 0.5),
			])
		ORIENTATION_SOUTH:
			return PackedVector2Array([
				Vector2(world_size.x * 0.5 - width * 0.5, world_size.y - 11.0),
				Vector2(world_size.x * 0.5 + width * 0.5, world_size.y - 11.0),
				Vector2(world_size.x * 0.5 + width * 0.5, world_size.y),
				Vector2(world_size.x * 0.5 - width * 0.5, world_size.y),
			])
		_:
			return PackedVector2Array([
				Vector2(0.0, world_size.y * 0.5 - width * 0.5),
				Vector2(11.0, world_size.y * 0.5 - width * 0.5),
				Vector2(11.0, world_size.y * 0.5 + width * 0.5),
				Vector2(0.0, world_size.y * 0.5 + width * 0.5),
			])


func _entrance_marker_polygon(world_size: Vector2, direction: int) -> PackedVector2Array:
	var center := Vector2(world_size.x * 0.5, 0.0)
	var facing := Vector2.UP
	match direction:
		ORIENTATION_EAST:
			center = Vector2(world_size.x, world_size.y * 0.5)
			facing = Vector2.RIGHT
		ORIENTATION_SOUTH:
			center = Vector2(world_size.x * 0.5, world_size.y)
			facing = Vector2.DOWN
		ORIENTATION_WEST:
			center = Vector2(0.0, world_size.y * 0.5)
			facing = Vector2.LEFT
	var side := Vector2(-facing.y, facing.x) * 7.0
	return PackedVector2Array([
		center + facing * 12.0,
		center - facing * 2.0 + side,
		center - facing * 2.0 - side,
	])


func _rectangle_polygon(size: Vector2, position := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		position,
		position + Vector2(size.x, 0.0),
		position + size,
		position + Vector2(0.0, size.y),
	])


func _rectangle_outline_points(size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
		Vector2.ZERO,
	])
