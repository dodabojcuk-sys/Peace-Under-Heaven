extends Node


signal placing_started

enum ConstructionState {
	IDLE,
	PLACING,
}

const GRID_SIZE := 40.0
const GRID_ORIGIN := Vector2.ZERO
const TEST_BUILDING_FOOTPRINT := Vector2i(3, 2)
const TEST_BUILDING_WORLD_SIZE := Vector2(
	TEST_BUILDING_FOOTPRINT.x * GRID_SIZE,
	TEST_BUILDING_FOOTPRINT.y * GRID_SIZE
)
const UI_SAFETY_MARGIN := 8.0
const PREVIEW_VALID_COLOR := Color(0.31, 0.62, 0.43, 0.72)
const PREVIEW_INVALID_COLOR := Color(0.72, 0.31, 0.28, 0.72)
const PREVIEW_VALID_OUTLINE := Color(0.12, 0.34, 0.2, 1.0)
const PREVIEW_INVALID_OUTLINE := Color(0.42, 0.12, 0.1, 1.0)
const PLACED_BUILDING_COLOR := Color(0.42, 0.5, 0.52, 1.0)
const PLACED_BUILDING_OUTLINE := Color(0.2, 0.25, 0.27, 1.0)

@onready var map_world: Node2D = $"../MapWorld"
@onready var map_board: Control = $"../MapWorld/MapBoard"
@onready var placed_buildings: Node2D = $"../MapWorld/ConstructionLayer/PlacedBuildings"
@onready var construction_preview: Node2D = $"../MapWorld/ConstructionLayer/ConstructionPreview"
@onready var preview_body: Polygon2D = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Body"
)
@onready var preview_outline: Line2D = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Outline"
)
@onready var preview_label: Label = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Label"
)
@onready var build_button: Button = (
	$"../UI/Shell/ContextBar/TemporaryBuildButton"
)
@onready var top_status_bar: Control = $"../UI/Shell/TopStatusBar"
@onready var city_bar: Control = $"../UI/Shell/CityBar"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"
@onready var context_bar: Control = $"../UI/Shell/ContextBar"

var state := ConstructionState.IDLE
var preview_origin_cell := Vector2i.ZERO
var preview_valid := false
var preview_invalid_reason := ""
var occupied_cells: Dictionary = {}
var placements: Array[Dictionary] = []
var _next_placement_id := 1


func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)
	construction_preview.visible = false


func is_placing() -> bool:
	return state == ConstructionState.PLACING


func begin_placing(screen_position: Vector2) -> void:
	if is_placing():
		update_preview(screen_position)
		return

	state = ConstructionState.PLACING
	construction_preview.visible = true
	update_preview(screen_position)
	placing_started.emit()


func cancel_placing() -> void:
	if not is_placing():
		return

	state = ConstructionState.IDLE
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""


func update_preview(screen_position: Vector2) -> void:
	if not is_placing():
		return

	var map_local_position := screen_to_map_local(screen_position)
	preview_origin_cell = map_position_to_origin_cell(map_local_position)
	_refresh_preview_for_current_cell()


func confirm_current_preview() -> bool:
	if not is_placing() or not preview_valid:
		return false

	var placement_id := _next_placement_id
	_next_placement_id += 1
	var origin_cell := preview_origin_cell
	var footprint_cells := get_footprint_cells(origin_cell)
	for cell in footprint_cells:
		occupied_cells[cell] = placement_id

	placements.append({
		"id": placement_id,
		"origin_cell": origin_cell,
		"footprint_cells": footprint_cells.duplicate(),
	})
	_create_placed_building(placement_id, origin_cell)
	_refresh_preview_for_current_cell()
	return true


func screen_to_map_local(screen_position: Vector2) -> Vector2:
	return map_world.get_global_transform_with_canvas().affine_inverse() * screen_position


func map_local_to_screen(map_local_position: Vector2) -> Vector2:
	return map_world.get_global_transform_with_canvas() * map_local_position


func map_position_to_origin_cell(map_local_position: Vector2) -> Vector2i:
	var grid_position := (map_local_position - GRID_ORIGIN) / GRID_SIZE
	return Vector2i(
		roundi(grid_position.x - TEST_BUILDING_FOOTPRINT.x * 0.5),
		roundi(grid_position.y - TEST_BUILDING_FOOTPRINT.y * 0.5)
	)


func cell_to_map_local(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * GRID_SIZE


func get_footprint_cells(origin_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(TEST_BUILDING_FOOTPRINT.y):
		for x in range(TEST_BUILDING_FOOTPRINT.x):
			cells.append(origin_cell + Vector2i(x, y))
	return cells


func evaluate_origin_cell(origin_cell: Vector2i) -> Dictionary:
	var footprint_cells := get_footprint_cells(origin_cell)
	if not _footprint_is_inside_map(origin_cell):
		return _validation_result(false, "超出地图")

	for cell in footprint_cells:
		if occupied_cells.has(cell):
			return _validation_result(false, "位置已占用")

	var screen_rect := get_footprint_screen_rect(origin_cell)
	if not _screen_rect_is_inside_viewport(screen_rect):
		return _validation_result(false, "超出可操作区域", screen_rect)

	for ui_control in _get_ui_occlusion_controls():
		if (
			ui_control.is_visible_in_tree()
			and ui_control.get_global_rect().grow(UI_SAFETY_MARGIN).intersects(screen_rect)
		):
			return _validation_result(false, "被界面遮挡", screen_rect)

	return _validation_result(true, "", screen_rect)


func get_footprint_screen_rect(origin_cell: Vector2i) -> Rect2:
	var map_origin := cell_to_map_local(origin_cell)
	var map_end := map_origin + TEST_BUILDING_WORLD_SIZE
	var corners := [
		map_local_to_screen(map_origin),
		map_local_to_screen(Vector2(map_end.x, map_origin.y)),
		map_local_to_screen(map_end),
		map_local_to_screen(Vector2(map_origin.x, map_end.y)),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _on_build_button_pressed() -> void:
	begin_placing(get_viewport().get_mouse_position())


func _refresh_preview_for_current_cell() -> void:
	var validation := evaluate_origin_cell(preview_origin_cell)
	preview_valid = validation.valid
	preview_invalid_reason = validation.reason
	construction_preview.position = cell_to_map_local(preview_origin_cell)
	preview_body.color = PREVIEW_VALID_COLOR if preview_valid else PREVIEW_INVALID_COLOR
	preview_outline.default_color = (
		PREVIEW_VALID_OUTLINE if preview_valid else PREVIEW_INVALID_OUTLINE
	)
	preview_label.text = "测试建筑\n可放置" if preview_valid else "测试建筑\n%s" % preview_invalid_reason


func _footprint_is_inside_map(origin_cell: Vector2i) -> bool:
	var map_grid_size := Vector2i(
		floori(map_board.size.x / GRID_SIZE),
		floori(map_board.size.y / GRID_SIZE)
	)
	return (
		origin_cell.x >= 0
		and origin_cell.y >= 0
		and origin_cell.x + TEST_BUILDING_FOOTPRINT.x <= map_grid_size.x
		and origin_cell.y + TEST_BUILDING_FOOTPRINT.y <= map_grid_size.y
	)


func _screen_rect_is_inside_viewport(screen_rect: Rect2) -> bool:
	var viewport_rect := get_viewport().get_visible_rect()
	return (
		screen_rect.position.x >= viewport_rect.position.x
		and screen_rect.position.y >= viewport_rect.position.y
		and screen_rect.end.x <= viewport_rect.end.x
		and screen_rect.end.y <= viewport_rect.end.y
	)


func _get_ui_occlusion_controls() -> Array[Control]:
	return [
		top_status_bar,
		city_bar,
		minimap_placeholder,
		context_bar,
	]


func _validation_result(
	valid: bool,
	reason: String,
	screen_rect := Rect2()
) -> Dictionary:
	return {
		"valid": valid,
		"reason": reason,
		"screen_rect": screen_rect,
	}


func _create_placed_building(placement_id: int, origin_cell: Vector2i) -> void:
	var building := Node2D.new()
	building.name = "TestBuilding%03d" % placement_id
	building.position = cell_to_map_local(origin_cell)
	building.set_meta("origin_cell", origin_cell)
	building.set_meta("footprint_cells", TEST_BUILDING_FOOTPRINT)

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _building_polygon()
	body.color = PLACED_BUILDING_COLOR
	building.add_child(body)

	var outline := Line2D.new()
	outline.name = "Outline"
	outline.points = _building_outline_points()
	outline.width = 3.0
	outline.default_color = PLACED_BUILDING_OUTLINE
	building.add_child(outline)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(8.0, 21.0)
	label.size = Vector2(104.0, 38.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "测试建筑"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.93, 1.0))
	building.add_child(label)

	placed_buildings.add_child(building)


func _building_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(TEST_BUILDING_WORLD_SIZE.x, 0.0),
		TEST_BUILDING_WORLD_SIZE,
		Vector2(0.0, TEST_BUILDING_WORLD_SIZE.y),
	])


func _building_outline_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(TEST_BUILDING_WORLD_SIZE.x, 0.0),
		TEST_BUILDING_WORLD_SIZE,
		Vector2(0.0, TEST_BUILDING_WORLD_SIZE.y),
		Vector2.ZERO,
	])
