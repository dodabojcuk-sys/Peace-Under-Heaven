class_name GrayboxBuildingVisual
extends Node2D

## Shared, data-free building presentation for the regular and future city
## profiles.  The controller remains the only owner of building state; this
## node only turns the supplied definition, footprint, orientation and
## lifecycle into replaceable graybox geometry.

const PALETTE := preload(
	"res://resources/visuals/northern_campaign_palette.gd"
)
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
var body_color := PALETTE.GROUND_COOL.darkened(0.22)
var outline_color := PALETTE.INK_TEAL
var requires_road := false
var is_road := false
var is_fixed := false
var presentation_progress := 1.0
var selected := false
var hovered := false
var disabled := false
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
	new_is_fixed := false,
	new_disabled := false
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
	disabled = new_disabled
	set_presentation_progress(new_progress)
	_ensure_visual_nodes()
	set_process(lifecycle_state == &"constructing")
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
	set_process(lifecycle_state == &"constructing")
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


func set_hovered_state(is_hovered: bool) -> void:
	if hovered == is_hovered:
		return
	hovered = is_hovered
	_apply_presentation_state()
	queue_redraw()


func set_disabled_state(is_disabled: bool) -> void:
	if disabled == is_disabled:
		return
	disabled = is_disabled
	_apply_presentation_state()
	queue_redraw()


func get_presentation_stage() -> StringName:
	return _presentation_stage


func get_orientation_label() -> String:
	return ORIENTATION_NAMES[orientation]


func _ready() -> void:
	_ensure_visual_nodes()
	set_process(lifecycle_state == &"constructing")
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
	var state_plate := Polygon2D.new()
	state_plate.name = "StatePlate"
	add_child(state_plate)
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
	var roof_trim := Line2D.new()
	roof_trim.name = "RoofTrim"
	roof_trim.width = 2.0
	roof_trim.antialiased = true
	add_child(roof_trim)
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
	var icon_back := Polygon2D.new()
	icon_back.name = "IconBack"
	add_child(icon_back)
	var icon_glyph := Polygon2D.new()
	icon_glyph.name = "IconGlyph"
	add_child(icon_glyph)
	var icon_lines := Node2D.new()
	icon_lines.name = "IconLines"
	for line_index in range(4):
		var icon_line := Line2D.new()
		icon_line.name = "Line%d" % line_index
		icon_line.width = 2.5
		icon_line.antialiased = true
		icon_lines.add_child(icon_line)
	add_child(icon_lines)
	var flag_pole := Line2D.new()
	flag_pole.name = "FlagPole"
	flag_pole.width = 3.0
	flag_pole.antialiased = true
	add_child(flag_pole)
	var flag := Polygon2D.new()
	flag.name = "Flag"
	add_child(flag)
	var status_badge := Polygon2D.new()
	status_badge.name = "StatusBadge"
	add_child(status_badge)
	var status_glyph := Line2D.new()
	status_glyph.name = "StatusGlyph"
	status_glyph.width = 2.5
	status_glyph.antialiased = true
	add_child(status_glyph)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 2.5
	add_child(outline)
	var construction_marker := Line2D.new()
	construction_marker.name = "ConstructionMarker"
	construction_marker.width = 2.5
	add_child(construction_marker)
	var label_back := Polygon2D.new()
	label_back.name = "LabelBack"
	add_child(label_back)
	var label := Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", PALETTE.TEXT_WARM)
	label.add_theme_color_override("font_shadow_color", PALETTE.SHADOW_DEEP)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)


func _rebuild_geometry() -> void:
	if not _visual_nodes_ready:
		return
	var world_size := Vector2(footprint) * GRID_SIZE
	var inset := 4.0
	var depth := clampf(minf(world_size.x, world_size.y) * 0.18, 8.0, 18.0)
	var state_plate := get_node("StatePlate") as Polygon2D
	state_plate.polygon = _rectangle_polygon(
		world_size - Vector2(4.0, 4.0),
		Vector2(2.0, 2.0)
	)
	var shadow := get_node("Shadow") as Polygon2D
	# Shadows are decorative and must never imply that the building occupies an
	# adjacent road cell. Keep the full silhouette inside the logical footprint.
	shadow.polygon = PackedVector2Array([
		Vector2(10.0, 14.0),
		Vector2(world_size.x - 2.0, 14.0),
		Vector2(world_size.x - 2.0, world_size.y - 2.0),
		Vector2(10.0, world_size.y - 2.0),
	])
	shadow.color = PALETTE.SHADOW
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
	var roof_trim := get_node("RoofTrim") as Line2D
	roof_trim.points = _closed_polygon_points(roof.polygon)
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
		row.default_color = PALETTE.ROAD_EDGE.lerp(PALETTE.JADE, 0.24)
	var entrance := get_node("Entrance") as Polygon2D
	entrance.polygon = _entrance_polygon(world_size, orientation)
	var entrance_marker := get_node("EntranceMarker") as Polygon2D
	entrance_marker.polygon = _entrance_marker_polygon(world_size, orientation)
	var icon_center := Vector2(
		world_size.x * 0.5,
		maxf(depth + 16.0, minf(world_size.y * 0.40, world_size.y - 38.0))
	)
	var icon_radius := clampf(minf(world_size.x, world_size.y) * 0.17, 8.0, 18.0)
	var icon_back := get_node("IconBack") as Polygon2D
	icon_back.polygon = _diamond_polygon(icon_center, icon_radius + 5.0)
	var icon_glyph := get_node("IconGlyph") as Polygon2D
	icon_glyph.polygon = _icon_polygon(icon_center, icon_radius)
	var icon_lines := get_node("IconLines") as Node2D
	var line_sets := _icon_line_sets(icon_center, icon_radius)
	for line_index in range(4):
		var icon_line := icon_lines.get_node("Line%d" % line_index) as Line2D
		icon_line.points = (
			line_sets[line_index]
			if line_index < line_sets.size()
			else PackedVector2Array()
		)
	var flag_pole := get_node("FlagPole") as Line2D
	var pole_x := world_size.x - 14.0
	flag_pole.points = PackedVector2Array([
		Vector2(pole_x, 6.0),
		Vector2(pole_x, minf(world_size.y - 8.0, 42.0)),
	])
	var flag := get_node("Flag") as Polygon2D
	flag.polygon = PackedVector2Array([
		Vector2(pole_x, 8.0),
		Vector2(maxf(5.0, pole_x - 24.0), 12.0),
		Vector2(pole_x, 23.0),
	])
	var status_center := Vector2(13.0, 13.0)
	var status_badge := get_node("StatusBadge") as Polygon2D
	status_badge.polygon = _diamond_polygon(status_center, 8.0)
	var status_glyph := get_node("StatusGlyph") as Line2D
	status_glyph.points = PackedVector2Array([
		status_center - Vector2(3.0, 3.0),
		status_center + Vector2(3.0, 3.0),
		status_center,
		status_center + Vector2(3.0, -3.0),
		status_center - Vector2(3.0, 3.0),
	])
	var outline := get_node("Outline") as Line2D
	outline.points = _rectangle_outline_points(world_size)
	var construction_marker := get_node("ConstructionMarker") as Line2D
	construction_marker.points = PackedVector2Array([
		Vector2(inset + 3.0, inset + 3.0),
		Vector2(world_size.x - inset - 3.0, world_size.y - inset - 3.0),
		Vector2(inset + 3.0, world_size.y - inset - 3.0),
		Vector2(world_size.x - inset - 3.0, inset + 3.0),
	])
	var label_height := minf(28.0, maxf(world_size.y - depth - 5.0, 16.0))
	var label_rect := Rect2(
		Vector2(inset + 3.0, world_size.y - label_height - inset),
		Vector2(
			maxf(world_size.x - inset * 2.0 - 6.0, 18.0),
			label_height
		)
	)
	var label_back := get_node("LabelBack") as Polygon2D
	label_back.polygon = _rectangle_polygon(label_rect.size, label_rect.position)
	var label := get_node("Label") as Label
	label.position = label_rect.position
	label.size = label_rect.size
	_apply_progress_geometry()


func _apply_progress_geometry() -> void:
	if not _visual_nodes_ready:
		return
	var progress := presentation_progress
	var foundation := get_node("Foundation") as Polygon2D
	var body := get_node("Body") as Polygon2D
	var side := get_node("Side") as Polygon2D
	var roof := get_node("Roof") as Polygon2D
	var roof_trim := get_node("RoofTrim") as Line2D
	var detail := get_node("Detail") as Polygon2D
	var farm_rows := get_node("FarmRows") as Node2D
	var entrance := get_node("Entrance") as Polygon2D
	var icon_back := get_node("IconBack") as Polygon2D
	var icon_glyph := get_node("IconGlyph") as Polygon2D
	var icon_lines := get_node("IconLines") as Node2D
	var flag_pole := get_node("FlagPole") as Line2D
	var flag := get_node("Flag") as Polygon2D
	foundation.modulate.a = 0.9 if progress > 0.0 else 0.72
	body.modulate.a = lerpf(0.16, 1.0, clampf(progress * 1.55, 0.0, 1.0))
	side.modulate.a = lerpf(0.05, 1.0, clampf((progress - 0.08) * 1.7, 0.0, 1.0))
	roof.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.3) * 1.55, 0.0, 1.0))
	roof_trim.modulate.a = roof.modulate.a
	detail.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.5) * 2.0, 0.0, 1.0))
	farm_rows.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.18) * 1.6, 0.0, 1.0))
	entrance.modulate.a = lerpf(0.0, 1.0, clampf((progress - 0.35) * 2.0, 0.0, 1.0))
	var identity_alpha := lerpf(0.0, 1.0, clampf((progress - 0.36) * 1.8, 0.0, 1.0))
	icon_back.modulate.a = identity_alpha
	icon_glyph.modulate.a = identity_alpha
	icon_lines.modulate.a = identity_alpha
	flag_pole.modulate.a = identity_alpha
	flag.modulate.a = identity_alpha


func _apply_presentation_state() -> void:
	if not _visual_nodes_ready:
		return
	var is_constructing := lifecycle_state == &"constructing"
	var is_disconnected := (
		requires_road and connection_state == &"disconnected"
	)
	var is_disabled := disabled or lifecycle_state in [&"disabled", &"blocked"]
	var state_plate := get_node("StatePlate") as Polygon2D
	var shadow := get_node("Shadow") as Polygon2D
	var foundation := get_node("Foundation") as Polygon2D
	var body := get_node("Body") as Polygon2D
	var side := get_node("Side") as Polygon2D
	var roof := get_node("Roof") as Polygon2D
	var roof_trim := get_node("RoofTrim") as Line2D
	var detail := get_node("Detail") as Polygon2D
	var farm_rows := get_node("FarmRows") as Node2D
	var entrance := get_node("Entrance") as Polygon2D
	var entrance_marker := get_node("EntranceMarker") as Polygon2D
	var icon_back := get_node("IconBack") as Polygon2D
	var icon_glyph := get_node("IconGlyph") as Polygon2D
	var icon_lines := get_node("IconLines") as Node2D
	var flag_pole := get_node("FlagPole") as Line2D
	var flag := get_node("Flag") as Polygon2D
	var status_badge := get_node("StatusBadge") as Polygon2D
	var status_glyph := get_node("StatusGlyph") as Line2D
	var outline := get_node("Outline") as Line2D
	var construction_marker := get_node("ConstructionMarker") as Line2D
	var label_back := get_node("LabelBack") as Polygon2D
	var label := get_node("Label") as Label
	state_plate.visible = (
		not is_road and (selected or hovered or is_disabled or is_disconnected)
	)
	shadow.visible = not is_road
	foundation.visible = true
	body.visible = not is_road
	side.visible = not is_road
	roof.visible = not is_road
	roof_trim.visible = not is_road
	detail.visible = not is_road
	farm_rows.visible = not is_road and definition_id == &"building.farm.t1"
	entrance.visible = not is_road
	entrance_marker.visible = (
		not is_road and (show_entrance_marker or is_disconnected)
	)
	construction_marker.visible = not is_road and is_constructing
	outline.visible = not is_road
	icon_back.visible = not is_road
	icon_glyph.visible = not is_road
	icon_lines.visible = not is_road
	var uses_flag := _uses_command_flag()
	flag_pole.visible = not is_road and uses_flag
	flag.visible = not is_road and uses_flag
	status_badge.visible = not is_road and (is_disabled or is_disconnected)
	status_glyph.visible = not is_road and is_disabled
	label.visible = not is_road and (selected or is_constructing or is_fixed)
	label_back.visible = label.visible
	label.text = (
		"%s\n施工中 · %s" % [display_name, _stage_label()]
		if is_constructing
		else display_name
	)
	var resting_body := body_color.lerp(PALETTE.GROUND_COOL, 0.18)
	if is_constructing:
		resting_body = resting_body.lerp(PALETTE.ROAD_SURFACE, 0.42)
	if is_disabled:
		resting_body = resting_body.lerp(PALETTE.INK_TEAL, 0.52)
	elif is_disconnected:
		resting_body = resting_body.lerp(PALETTE.ROAD_SURFACE, 0.24)
	foundation.color = (
		PALETTE.ROAD_EDGE
		if is_constructing
		else PALETTE.ROAD_SURFACE
	)
	body.color = resting_body
	side.color = resting_body.darkened(0.28)
	roof.color = resting_body.lightened(0.16).lerp(PALETTE.COPPER_GOLD, 0.10)
	roof_trim.default_color = PALETTE.with_alpha(PALETTE.ROAD_EDGE, 0.88)
	detail.color = _detail_color()
	entrance.color = PALETTE.INK_BLUE
	entrance_marker.color = (
		PALETTE.HOSTILE_RUST if is_disconnected else PALETTE.JADE
	)
	var state_accent := PALETTE.JADE
	if selected:
		state_accent = PALETTE.COPPER_GOLD
	elif is_disabled or is_disconnected:
		state_accent = PALETTE.HOSTILE_RUST
	state_plate.color = PALETTE.with_alpha(
		state_accent,
		0.18 if selected else 0.12
	)
	if selected:
		outline.default_color = PALETTE.COPPER_PALE
		outline.width = 4.0
	elif is_disabled:
		outline.default_color = PALETTE.HOSTILE_RUST
		outline.width = 3.0
	elif hovered:
		outline.default_color = PALETTE.JADE_PALE
		outline.width = 3.0
	else:
		outline.default_color = outline_color.lerp(PALETTE.INK_TEAL, 0.26)
		outline.width = 2.5
	construction_marker.default_color = PALETTE.COPPER_PALE
	icon_back.color = PALETTE.with_alpha(PALETTE.INK_BLUE, 0.76)
	icon_glyph.color = _identity_accent_color()
	for icon_line_node in icon_lines.get_children():
		var icon_line := icon_line_node as Line2D
		if icon_line != null:
			icon_line.default_color = PALETTE.TEXT_WARM
	flag_pole.default_color = PALETTE.ROAD_EDGE
	flag.color = PALETTE.COPPER_GOLD if not is_disabled else PALETTE.HOSTILE_RUST
	status_badge.color = PALETTE.HOSTILE_RUST
	status_glyph.default_color = PALETTE.TEXT_WARM
	label_back.color = PALETTE.with_alpha(PALETTE.INK_BLUE, 0.76)
	label.add_theme_color_override(
		"font_color",
		PALETTE.COPPER_PALE if is_constructing else PALETTE.TEXT_WARM
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
		return PALETTE.JADE
	if definition_id == &"building.logging_camp.t1":
		return PALETTE.COPPER_GOLD
	if definition_id == &"building.warehouse.t1":
		return PALETTE.COPPER_PALE
	if definition_id == &"building.watchtower.t1":
		return PALETTE.HOSTILE_RUST
	if definition_id in [&"manor", &"command_platform"]:
		return PALETTE.COPPER_GOLD
	if definition_id in [&"barracks", &"noticeboard"]:
		return PALETTE.HOSTILE_RUST
	if definition_id in [&"granary", &"academy"]:
		return PALETTE.JADE
	return body_color.lightened(0.24).lerp(PALETTE.COPPER_GOLD, 0.12)


func _identity_accent_color() -> Color:
	if definition_id in [
		&"manor",
		&"command_platform",
		&"granary",
		&"building.warehouse.t1",
	]:
		return PALETTE.COPPER_GOLD
	if definition_id in [
		&"academy",
		&"building.farm.t1",
		&"building.logging_camp.t1",
	]:
		return PALETTE.JADE
	if definition_id in [
		&"barracks",
		&"noticeboard",
		&"building.watchtower.t1",
	]:
		return PALETTE.HOSTILE_RUST
	return PALETTE.TEXT_MUTED


func _uses_command_flag() -> bool:
	return definition_id in [
		&"manor",
		&"barracks",
		&"command_platform",
		&"building.watchtower.t1",
	]


func _roof_polygon(world_size: Vector2, depth: float) -> PackedVector2Array:
	if definition_id == &"barracks":
		return PackedVector2Array([
			Vector2(4.0, depth + 4.0),
			Vector2(world_size.x * 0.28, 1.0),
			Vector2(world_size.x * 0.5, depth * 0.56),
			Vector2(world_size.x * 0.72, 1.0),
			Vector2(world_size.x - 4.0, depth + 4.0),
			Vector2(world_size.x - 8.0, depth + 16.0),
			Vector2(8.0, depth + 16.0),
		])
	if definition_id in [&"command_platform", &"building.watchtower.t1"]:
		return PackedVector2Array([
			Vector2(5.0, 5.0),
			Vector2(world_size.x * 0.28, 5.0),
			Vector2(world_size.x * 0.28, 1.0),
			Vector2(world_size.x * 0.46, 1.0),
			Vector2(world_size.x * 0.46, 5.0),
			Vector2(world_size.x * 0.64, 5.0),
			Vector2(world_size.x * 0.64, 1.0),
			Vector2(world_size.x - 5.0, 1.0),
			Vector2(world_size.x - 7.0, depth + 15.0),
			Vector2(7.0, depth + 15.0),
		])
	if definition_id == &"granary":
		return PackedVector2Array([
			Vector2(8.0, depth + 6.0),
			Vector2(world_size.x * 0.24, 3.0),
			Vector2(world_size.x * 0.76, 3.0),
			Vector2(world_size.x - 8.0, depth + 6.0),
			Vector2(world_size.x - 10.0, depth + 16.0),
			Vector2(10.0, depth + 16.0),
		])
	if definition_id == &"academy":
		return PackedVector2Array([
			Vector2(4.0, depth + 4.0),
			Vector2(world_size.x * 0.34, 1.0),
			Vector2(world_size.x * 0.5, 8.0),
			Vector2(world_size.x * 0.66, 1.0),
			Vector2(world_size.x - 4.0, depth + 4.0),
			Vector2(world_size.x - 8.0, depth + 16.0),
			Vector2(8.0, depth + 16.0),
		])
	if definition_id == &"noticeboard":
		return PackedVector2Array([
			Vector2(4.0, depth * 0.56),
			Vector2(world_size.x - 4.0, depth * 0.56),
			Vector2(world_size.x - 8.0, depth + 13.0),
			Vector2(8.0, depth + 13.0),
		])
	if definition_id == &"building.logging_camp.t1":
		return PackedVector2Array([
			Vector2(4.0, depth + 5.0),
			Vector2(world_size.x * 0.25, 2.0),
			Vector2(world_size.x - 4.0, depth + 9.0),
			Vector2(world_size.x - 8.0, depth + 16.0),
			Vector2(8.0, depth + 16.0),
		])
	if definition_id == &"building.farm.t1":
		return PackedVector2Array([
			Vector2(5.0, depth + 8.0),
			Vector2(world_size.x * 0.5, 5.0),
			Vector2(world_size.x - 5.0, depth + 8.0),
			Vector2(world_size.x - 9.0, depth + 15.0),
			Vector2(9.0, depth + 15.0),
		])
	if definition_id == &"building.warehouse.t1":
		return PackedVector2Array([
			Vector2(4.0, depth + 7.0),
			Vector2(world_size.x * 0.5, 2.0),
			Vector2(world_size.x - 4.0, depth + 7.0),
			Vector2(world_size.x - 7.0, depth + 17.0),
			Vector2(7.0, depth + 17.0),
		])
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
	if definition_id in [&"manor", &"command_platform"]:
		return PackedVector2Array([
			Vector2(center.x - width, body_rect.position.y + 7.0),
			Vector2(center.x + width, body_rect.position.y + 7.0),
			Vector2(center.x + width * 0.72, body_rect.position.y + 17.0),
			Vector2(center.x - width * 0.72, body_rect.position.y + 17.0),
		])
	if definition_id == &"barracks":
		return PackedVector2Array([
			Vector2(center.x - width, center.y - 3.0),
			Vector2(center.x, center.y - 11.0),
			Vector2(center.x + width, center.y - 3.0),
			Vector2(center.x, center.y + 7.0),
		])
	if definition_id == &"granary":
		return PackedVector2Array([
			Vector2(center.x - width * 0.72, body_rect.position.y + 7.0),
			Vector2(center.x + width * 0.72, body_rect.position.y + 7.0),
			Vector2(center.x + width, body_rect.position.y + 17.0),
			Vector2(center.x - width, body_rect.position.y + 17.0),
		])
	if definition_id == &"academy":
		return PackedVector2Array([
			Vector2(center.x - width, center.y - 7.0),
			Vector2(center.x, center.y - 1.0),
			Vector2(center.x + width, center.y - 7.0),
			Vector2(center.x + width, center.y + 7.0),
			Vector2(center.x, center.y + 2.0),
			Vector2(center.x - width, center.y + 7.0),
		])
	if definition_id == &"noticeboard":
		return PackedVector2Array([
			Vector2(center.x - width, center.y - 10.0),
			Vector2(center.x + width, center.y - 10.0),
			Vector2(center.x + width, center.y + 10.0),
			Vector2(center.x - width, center.y + 10.0),
		])
	return PackedVector2Array([
		Vector2(center.x - width * 0.5, center.y - 4.0),
		Vector2(center.x + width * 0.5, center.y - 4.0),
		Vector2(center.x + width * 0.5, center.y + 4.0),
		Vector2(center.x - width * 0.5, center.y + 4.0),
	])


func _icon_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	if definition_id in [&"manor", &"command_platform"]:
		return PackedVector2Array([
			center + Vector2(-radius, radius * 0.55),
			center + Vector2(-radius * 0.72, -radius * 0.55),
			center + Vector2(-radius * 0.18, -radius * 0.10),
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.25, -radius * 0.10),
			center + Vector2(radius * 0.76, -radius * 0.55),
			center + Vector2(radius, radius * 0.55),
		])
	if definition_id in [&"barracks", &"building.watchtower.t1"]:
		return PackedVector2Array([
			center + Vector2(-radius * 0.82, -radius * 0.62),
			center + Vector2(radius * 0.82, -radius * 0.62),
			center + Vector2(radius * 0.60, radius * 0.48),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.60, radius * 0.48),
		])
	if definition_id in [&"granary", &"building.warehouse.t1"]:
		return PackedVector2Array([
			center + Vector2(-radius * 0.86, -radius * 0.55),
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.86, -radius * 0.55),
			center + Vector2(radius * 0.86, radius * 0.65),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.86, radius * 0.65),
		])
	if definition_id == &"building.logging_camp.t1":
		return PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, radius * 0.46),
			center + Vector2(radius * 0.28, radius * 0.46),
			center + Vector2(radius * 0.28, radius),
			center + Vector2(-radius * 0.28, radius),
			center + Vector2(-radius * 0.28, radius * 0.46),
			center + Vector2(-radius, radius * 0.46),
		])
	if definition_id == &"building.farm.t1":
		return PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.76, -radius * 0.12),
			center + Vector2(radius * 0.32, radius),
			center + Vector2(-radius * 0.62, radius * 0.34),
		])
	if definition_id in [&"academy", &"noticeboard"]:
		return _rectangle_polygon(
			Vector2(radius * 1.62, radius * 1.30),
			center - Vector2(radius * 0.81, radius * 0.65)
		)
	return _diamond_polygon(center, radius)


func _icon_line_sets(center: Vector2, radius: float) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	if definition_id == &"barracks":
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.54, radius * 0.55),
			center + Vector2(radius * 0.54, -radius * 0.55),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.54, -radius * 0.55),
			center + Vector2(radius * 0.54, radius * 0.55),
		]))
	elif definition_id == &"granary":
		for y_offset in [-0.38, 0.0, 0.38]:
			lines.append(PackedVector2Array([
				center + Vector2(-radius * 0.62, radius * y_offset),
				center + Vector2(radius * 0.62, radius * y_offset),
			]))
	elif definition_id == &"academy":
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.68, -radius * 0.36),
			center,
			center + Vector2(radius * 0.68, -radius * 0.36),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.68, radius * 0.38),
			center,
			center + Vector2(radius * 0.68, radius * 0.38),
		]))
	elif definition_id in [&"command_platform", &"noticeboard"]:
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.58, -radius * 0.34),
			center + Vector2(radius * 0.48, -radius * 0.34),
			center + Vector2(radius * 0.48, radius * 0.10),
			center + Vector2(-radius * 0.58, radius * 0.10),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.40, radius * 0.10),
			center + Vector2(-radius * 0.40, radius * 0.62),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(radius * 0.30, radius * 0.10),
			center + Vector2(radius * 0.30, radius * 0.62),
		]))
	elif definition_id == &"building.logging_camp.t1":
		lines.append(PackedVector2Array([
			center + Vector2(0.0, -radius * 0.62),
			center + Vector2(0.0, radius * 0.70),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.48, radius * 0.08),
			center,
			center + Vector2(radius * 0.48, radius * 0.08),
		]))
	elif definition_id == &"building.farm.t1":
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.28, radius * 0.62),
			center + Vector2(radius * 0.30, -radius * 0.66),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.05, radius * 0.10),
			center + Vector2(-radius * 0.48, -radius * 0.14),
		]))
	elif definition_id == &"building.warehouse.t1":
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.65, 0.0),
			center + Vector2(radius * 0.65, 0.0),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(0.0, -radius * 0.70),
			center + Vector2(0.0, radius * 0.70),
		]))
	elif definition_id == &"building.watchtower.t1":
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.46, -radius * 0.22),
			center + Vector2(radius * 0.46, -radius * 0.22),
		]))
		lines.append(PackedVector2Array([
			center + Vector2(0.0, -radius * 0.22),
			center + Vector2(0.0, radius * 0.58),
		]))
	elif definition_id == &"manor":
		lines.append(PackedVector2Array([
			center + Vector2(-radius * 0.56, radius * 0.40),
			center + Vector2(radius * 0.56, radius * 0.40),
		]))
	return lines


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


func _diamond_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])


func _closed_polygon_points(polygon: PackedVector2Array) -> PackedVector2Array:
	var points := polygon.duplicate()
	if not points.is_empty():
		points.append(points[0])
	return points


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
