extends Node


signal placing_started
signal construction_interaction_started
signal building_removed(placement_id: int)

enum ConstructionState {
	IDLE,
	CHOOSING_TEMPLATE,
	PLACING,
}

const GRID_SIZE := 40.0
const GRID_ORIGIN := Vector2.ZERO
const PLACEMENT_KIND_FIXED := &"fixed"
const PLACEMENT_KIND_PLACED := &"placed"
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
const PRESET_BUILDING_DEFINITIONS := [
	{
		"node_path": "../MapWorld/Manor",
		"template_id": &"manor",
		"display_name": "城主府 L1",
		"description": "城市行政中枢（灰盒占位）",
	},
	{
		"node_path": "../MapWorld/Barracks",
		"template_id": &"barracks",
		"display_name": "兵营 L1",
		"description": "军事训练设施（灰盒占位）",
	},
	{
		"node_path": "../MapWorld/Granary",
		"template_id": &"granary",
		"display_name": "粮仓 L2",
		"description": "城市粮食储备（灰盒占位）",
	},
	{
		"node_path": "../MapWorld/Academy",
		"template_id": &"academy",
		"display_name": "学院 L1",
		"description": "研究与教育设施（灰盒占位）",
	},
	{
		"node_path": "../MapWorld/CityGate",
		"template_id": &"city_gate",
		"display_name": "城门 L1",
		"description": "城市出入口（灰盒占位）",
	},
	{
		"node_path": "../MapWorld/CommandPlatform",
		"template_id": &"command_platform",
		"display_name": "军令台 L1",
		"description": "军事命令设施（功能尚未接入）",
	},
]

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
@onready var construction_entry_panel: Control = (
	$"../UI/Shell/ConstructionEntryPanel"
)
@onready var build_entry_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/BuildEntryButton"
)
@onready var build_mode_status: Label = (
	$"../UI/Shell/ConstructionEntryPanel/BuildModeStatus"
)
@onready var construction_menu: Control = (
	$"../UI/Shell/ConstructionMenu"
)
@onready var build_template_button: Button = (
	$"../UI/Shell/ConstructionMenu/TestBuildingButton"
)
@onready var close_construction_menu_button: Button = (
	$"../UI/Shell/ConstructionMenu/CloseButton"
)
@onready var top_status_bar: Control = $"../UI/Shell/TopStatusBar"
@onready var city_bar: Control = $"../UI/Shell/CityBar"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"
@onready var building_detail_panel: Control = $"../UI/Shell/BuildingDetailPanel"

var state := ConstructionState.IDLE
var preview_origin_cell := Vector2i.ZERO
var preview_valid := false
var preview_invalid_reason := ""
var occupied_cells: Dictionary = {}
var building_records_by_id: Dictionary = {}
var placement_order: Array[int] = []
var _next_placement_id := 1
var _detail_panel_active := false


func _ready() -> void:
	_register_preset_buildings()
	build_entry_button.pressed.connect(_on_build_entry_pressed)
	build_template_button.pressed.connect(_on_build_template_pressed)
	close_construction_menu_button.pressed.connect(cancel_build_interaction)
	construction_preview.visible = false
	_sync_construction_ui()


func is_placing() -> bool:
	return state == ConstructionState.PLACING


func is_choosing_template() -> bool:
	return state == ConstructionState.CHOOSING_TEMPLATE


func open_construction_menu() -> void:
	if is_choosing_template():
		return

	state = ConstructionState.CHOOSING_TEMPLATE
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()
	construction_interaction_started.emit()


func begin_placing(screen_position: Vector2) -> void:
	if is_placing():
		update_preview(screen_position)
		return

	state = ConstructionState.PLACING
	construction_preview.visible = true
	_sync_construction_ui()
	update_preview(screen_position)
	placing_started.emit()


func cancel_placing() -> void:
	if not is_placing():
		return

	state = ConstructionState.IDLE
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()


func cancel_build_interaction() -> void:
	if state == ConstructionState.IDLE:
		return

	state = ConstructionState.IDLE
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()


func handle_escape() -> bool:
	if not is_choosing_template():
		return false
	cancel_build_interaction()
	return true


func set_detail_panel_active(active: bool) -> void:
	_detail_panel_active = active
	_sync_construction_ui()


func is_construction_ui_point(screen_position: Vector2) -> bool:
	for ui_control in [construction_entry_panel, construction_menu]:
		if (
			ui_control.is_visible_in_tree()
			and ui_control.get_global_rect().has_point(screen_position)
		):
			return true
	return false


func update_preview(screen_position: Vector2) -> void:
	if not is_placing():
		return

	var map_local_position := screen_to_map_local(screen_position)
	preview_origin_cell = map_position_to_origin_cell(map_local_position)
	_refresh_preview_for_current_cell()


func confirm_current_preview() -> bool:
	if not is_placing() or not preview_valid:
		return false

	var placement_id := _create_runtime_building(preview_origin_cell)
	if placement_id < 0:
		return false
	_refresh_preview_for_current_cell()
	return true


func get_building_count() -> int:
	return building_records_by_id.size()


func get_placement_ids() -> Array[int]:
	return placement_order.duplicate()


func get_building_record(placement_id: int) -> Dictionary:
	var record: Dictionary = building_records_by_id.get(placement_id, {})
	return record.duplicate(true) if not record.is_empty() else {}


func get_building_node(placement_id: int) -> CanvasItem:
	var record: Dictionary = building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return null
	var building := record.get("node") as CanvasItem
	return building if is_instance_valid(building) else null


func get_placement_id_for_node(building: CanvasItem) -> int:
	if not is_instance_valid(building) or not building.has_meta("placement_id"):
		return -1
	var placement_id := int(building.get_meta("placement_id"))
	var record: Dictionary = building_records_by_id.get(placement_id, {})
	if record.is_empty() or record.get("node") != building:
		return -1
	return placement_id


func remove_placed_building(placement_id: int) -> bool:
	var record: Dictionary = building_records_by_id.get(placement_id, {})
	if (
		record.is_empty()
		or record.get("placement_kind") != PLACEMENT_KIND_PLACED
		or not bool(record.get("removable", false))
	):
		return false

	var building := record.get("node") as Node2D
	if (
		not is_instance_valid(building)
		or not building.is_inside_tree()
		or building.get_parent() != placed_buildings
	):
		return false

	var footprint_cells: Array = record.get("occupied_footprint_cells", [])
	for cell in footprint_cells:
		if occupied_cells.get(cell, -1) != placement_id:
			push_error(
				"Cannot remove placement %d: occupancy ownership mismatch at %s"
				% [placement_id, cell]
			)
			return false

	_release_runtime_record(placement_id, true)
	building.queue_free()
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


func _on_build_entry_pressed() -> void:
	open_construction_menu()


func _on_build_template_pressed() -> void:
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
		building_detail_panel,
		construction_entry_panel,
		construction_menu,
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


func _create_runtime_building(origin_cell: Vector2i) -> int:
	var footprint_cells := get_footprint_cells(origin_cell)
	if not _footprint_is_inside_map(origin_cell):
		return -1
	for cell in footprint_cells:
		if occupied_cells.has(cell):
			return -1

	var placement_id := _allocate_placement_id()
	var building := _create_placed_building_node(placement_id, origin_cell)
	var record := {
		"placement_id": placement_id,
		"placement_kind": PLACEMENT_KIND_PLACED,
		"template_id": &"test_building",
		"display_name": "测试建筑",
		"building_type": "中性测试建筑",
		"description": "用于验证建造、选择与安全移除闭环",
		"origin_cell": origin_cell,
		"footprint": TEST_BUILDING_FOOTPRINT,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(Vector2.ZERO, TEST_BUILDING_WORLD_SIZE),
		"lifecycle_state": &"running",
		"prototype_status": "原型 / 运行中",
		"selectable": true,
		"removable": true,
		"movable": false,
		"node": building,
	}
	building_records_by_id[placement_id] = record
	placement_order.append(placement_id)
	for cell in footprint_cells:
		occupied_cells[cell] = placement_id
	building.tree_exited.connect(
		_on_runtime_building_tree_exited.bind(placement_id, building),
		CONNECT_ONE_SHOT
	)
	return placement_id


func _create_placed_building_node(
	placement_id: int,
	origin_cell: Vector2i
) -> Node2D:
	var building := Node2D.new()
	building.name = "TestBuilding%03d" % placement_id
	building.position = cell_to_map_local(origin_cell)
	building.set_meta("placement_id", placement_id)

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
	return building


func _release_runtime_record(
	placement_id: int,
	require_complete_ownership: bool
) -> bool:
	var record: Dictionary = building_records_by_id.get(placement_id, {})
	if (
		record.is_empty()
		or record.get("placement_kind") != PLACEMENT_KIND_PLACED
	):
		return false

	var footprint_cells: Array = record.get("occupied_footprint_cells", [])
	if require_complete_ownership:
		for cell in footprint_cells:
			if occupied_cells.get(cell, -1) != placement_id:
				return false

	for cell in footprint_cells:
		if occupied_cells.get(cell, -1) == placement_id:
			occupied_cells.erase(cell)
		elif not require_complete_ownership:
			push_error(
				"Placement %d exited with occupancy mismatch at %s"
				% [placement_id, cell]
			)

	building_records_by_id.erase(placement_id)
	placement_order.erase(placement_id)
	building_removed.emit(placement_id)
	return true


func _on_runtime_building_tree_exited(
	placement_id: int,
	building: Node2D
) -> void:
	var record: Dictionary = building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return
	if record.get("node") != building:
		push_error(
			"Placement %d tree exit did not match its authoritative node"
			% placement_id
		)
		return
	_release_runtime_record(placement_id, false)


func _register_preset_buildings() -> void:
	for definition in PRESET_BUILDING_DEFINITIONS:
		var building := get_node(str(definition.node_path)) as Control
		if building == null:
			push_error("Missing preset building: %s" % definition.node_path)
			continue
		_register_fixed_building(building, definition)


func _register_fixed_building(
	building: Control,
	definition: Dictionary
) -> void:
	var map_rect := Rect2(building.position, building.size)
	var footprint_cells := _get_cells_intersecting_map_rect(map_rect)
	for cell in footprint_cells:
		if occupied_cells.has(cell):
			push_error(
				"Preset building %s overlaps placement %s at %s"
				% [building.name, occupied_cells[cell], cell]
			)
			return

	var origin_cell := Vector2i(
		floori(map_rect.position.x / GRID_SIZE),
		floori(map_rect.position.y / GRID_SIZE)
	)
	var footprint_end := Vector2i(
		ceili(map_rect.end.x / GRID_SIZE),
		ceili(map_rect.end.y / GRID_SIZE)
	)
	var placement_id := _allocate_placement_id()
	var record := {
		"placement_id": placement_id,
		"placement_kind": PLACEMENT_KIND_FIXED,
		"template_id": definition.template_id,
		"display_name": definition.display_name,
		"building_type": "固定预置建筑",
		"description": definition.description,
		"origin_cell": origin_cell,
		"footprint": footprint_end - origin_cell,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(Vector2.ZERO, building.size),
		"lifecycle_state": &"fixed",
		"prototype_status": "固定 / 可选择",
		"selectable": true,
		"removable": false,
		"movable": false,
		"node": building,
	}
	building.set_meta("placement_id", placement_id)
	building_records_by_id[placement_id] = record
	placement_order.append(placement_id)
	for cell in footprint_cells:
		occupied_cells[cell] = placement_id


func _get_cells_intersecting_map_rect(map_rect: Rect2) -> Array[Vector2i]:
	var start_cell := Vector2i(
		floori(map_rect.position.x / GRID_SIZE),
		floori(map_rect.position.y / GRID_SIZE)
	)
	var end_cell := Vector2i(
		ceili(map_rect.end.x / GRID_SIZE),
		ceili(map_rect.end.y / GRID_SIZE)
	)
	var cells: Array[Vector2i] = []
	for y in range(start_cell.y, end_cell.y):
		for x in range(start_cell.x, end_cell.x):
			cells.append(Vector2i(x, y))
	return cells


func _allocate_placement_id() -> int:
	var placement_id := _next_placement_id
	_next_placement_id += 1
	return placement_id


func _sync_construction_ui() -> void:
	construction_entry_panel.visible = not _detail_panel_active
	build_entry_button.visible = state != ConstructionState.PLACING
	build_mode_status.visible = state == ConstructionState.PLACING
	construction_menu.visible = (
		not _detail_panel_active
		and state == ConstructionState.CHOOSING_TEMPLATE
	)


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
