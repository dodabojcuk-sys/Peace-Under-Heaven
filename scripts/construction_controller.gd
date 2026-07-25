extends Node


signal placing_started
signal construction_interaction_started
signal building_removed(placement_id: int)
signal city_state_changed

enum ConstructionState {
	IDLE,
	CHOOSING_TEMPLATE,
	PLACING,
}

const GRID_SIZE := 40.0
const GRID_ORIGIN := Vector2.ZERO
const PLACEMENT_KIND_FIXED := &"fixed"
const PLACEMENT_KIND_PLACED := &"placed"
const PLACEMENT_KIND_ROAD := &"road"
const ROAD_ROOT_CELLS: Array[Vector2i] = [Vector2i(7, 4)]
const BASE_RESOURCE_CAPACITY := 160
const UI_SAFETY_MARGIN := 8.0
const PREVIEW_VALID_COLOR := Color(0.31, 0.62, 0.43, 0.72)
const PREVIEW_INVALID_COLOR := Color(0.72, 0.31, 0.28, 0.72)
const PREVIEW_VALID_OUTLINE := Color(0.12, 0.34, 0.2, 1.0)
const PREVIEW_INVALID_OUTLINE := Color(0.42, 0.12, 0.1, 1.0)
const ROAD_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/road.tres"
)
const LOGGING_CAMP_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/logging_camp.tres"
)
const FARM_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/farm.tres"
)
const WAREHOUSE_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/warehouse.tres"
)
const TEST_BUILDING_FOOTPRINT := Vector2i(2, 2)
const TEST_BUILDING_WORLD_SIZE := Vector2(80.0, 80.0)
const PRESET_BUILDING_DEFINITIONS := [
	{
		"node_path": "../MapWorld/Manor",
		"template_id": &"manor",
		"display_name": "城主府 L1",
		"description": "城市行政中枢；道路网络从其右侧根格开始",
	},
	{
		"node_path": "../MapWorld/Barracks",
		"template_id": &"barracks",
		"display_name": "兵营 L1",
		"description": "军事训练设施（P1-D 接入征募）",
	},
	{
		"node_path": "../MapWorld/Granary",
		"template_id": &"granary",
		"display_name": "粮仓 L2",
		"description": "城市粮食储备（P1-B 接入容量）",
	},
	{
		"node_path": "../MapWorld/Academy",
		"template_id": &"academy",
		"display_name": "学院 L1",
		"description": "研究与教育设施（P1-D 接入科技）",
	},
	{
		"node_path": "../MapWorld/CityGate",
		"template_id": &"city_gate",
		"display_name": "城门 L1",
		"description": "城市出入口（P1-C 接入城防）",
	},
	{
		"node_path": "../MapWorld/CommandPlatform",
		"template_id": &"command_platform",
		"display_name": "军令台 L1",
		"description": "军事命令设施（真实战役契约接入前不提供假入口）",
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
@onready var construction_menu: Control = $"../UI/Shell/ConstructionMenu"
@onready var road_button: Button = $"../UI/Shell/ConstructionMenu/RoadButton"
@onready var logging_camp_button: Button = (
	$"../UI/Shell/ConstructionMenu/LoggingCampButton"
)
@onready var farm_button: Button = $"../UI/Shell/ConstructionMenu/FarmButton"
@onready var warehouse_button: Button = (
	$"../UI/Shell/ConstructionMenu/WarehouseButton"
)
@onready var close_construction_menu_button: Button = (
	$"../UI/Shell/ConstructionMenu/CloseButton"
)
@onready var top_status_bar: Control = $"../UI/Shell/TopStatusBar"
@onready var resource_summary: Label = $"../UI/Shell/TopStatusBar/ResourceSummary"
@onready var time_summary: Label = $"../UI/Shell/TopStatusBar/TimeSummary"
@onready var daily_report: Label = $"../UI/Shell/TopStatusBar/DailyReport"
@onready var end_day_button: Button = $"../UI/Shell/TopStatusBar/EndDayButton"
@onready var city_bar: Control = $"../UI/Shell/CityBar"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"
@onready var building_detail_panel: Control = $"../UI/Shell/BuildingDetailPanel"

var state := ConstructionState.IDLE
var preview_origin_cell := Vector2i.ZERO
var preview_valid := false
var preview_invalid_reason := ""
var current_day := 1
var wood := 100
var food := 80
var tech_points := 0
var last_daily_report := "尚未结算"
var last_daily_breakdown := {
	"maintenance_food": 0,
	"training_completed": 0,
	"wood_income": 0,
	"food_income": 0,
	"research_income": 0,
	"event_wood_loss": 0,
	"event_food_loss": 0,
}
var _occupied_cells: Dictionary = {}
var _building_records_by_id: Dictionary = {}
var _placement_order: Array[int] = []
var _definitions_by_id: Dictionary = {}
var _next_placement_id := 1
var _detail_panel_active := false
var _selected_definition: BuildingDefinition


func _ready() -> void:
	_register_definition(ROAD_DEFINITION)
	_register_definition(LOGGING_CAMP_DEFINITION)
	_register_definition(FARM_DEFINITION)
	_register_definition(WAREHOUSE_DEFINITION)
	_register_preset_buildings()
	build_entry_button.pressed.connect(_on_build_entry_pressed)
	road_button.pressed.connect(
		_on_definition_button_pressed.bind(ROAD_DEFINITION.definition_id)
	)
	logging_camp_button.pressed.connect(
		_on_definition_button_pressed.bind(LOGGING_CAMP_DEFINITION.definition_id)
	)
	farm_button.pressed.connect(
		_on_definition_button_pressed.bind(FARM_DEFINITION.definition_id)
	)
	warehouse_button.pressed.connect(
		_on_definition_button_pressed.bind(WAREHOUSE_DEFINITION.definition_id)
	)
	close_construction_menu_button.pressed.connect(cancel_build_interaction)
	end_day_button.pressed.connect(advance_day)
	construction_preview.visible = false
	_sync_construction_ui()
	_refresh_city_ui()


func is_placing() -> bool:
	return state == ConstructionState.PLACING


func is_choosing_template() -> bool:
	return state == ConstructionState.CHOOSING_TEMPLATE


func open_construction_menu() -> void:
	if is_choosing_template():
		return
	state = ConstructionState.CHOOSING_TEMPLATE
	_selected_definition = null
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()
	construction_interaction_started.emit()


func begin_placing(screen_position: Vector2) -> void:
	begin_placing_definition(
		LOGGING_CAMP_DEFINITION.definition_id,
		screen_position
	)


func begin_placing_definition(
	definition_id: StringName,
	screen_position: Vector2
) -> bool:
	var definition := get_definition(definition_id)
	if definition == null:
		return false
	_selected_definition = definition
	state = ConstructionState.PLACING
	construction_preview.visible = true
	_apply_preview_geometry(definition)
	_sync_construction_ui()
	update_preview(screen_position)
	placing_started.emit()
	return true


func cancel_placing() -> void:
	if not is_placing():
		return
	state = ConstructionState.IDLE
	_selected_definition = null
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()


func cancel_build_interaction() -> void:
	if state == ConstructionState.IDLE:
		return
	state = ConstructionState.IDLE
	_selected_definition = null
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
	for ui_control in [
		construction_entry_panel,
		construction_menu,
		end_day_button,
	]:
		if (
			ui_control.is_visible_in_tree()
			and ui_control.get_global_rect().has_point(screen_position)
		):
			return true
	return false


func update_preview(screen_position: Vector2) -> void:
	if not is_placing() or _selected_definition == null:
		return
	var map_local_position := screen_to_map_local(screen_position)
	preview_origin_cell = map_position_to_origin_cell(
		map_local_position,
		_selected_definition.footprint
	)
	_refresh_preview_for_current_cell()


func confirm_current_preview() -> bool:
	if (
		not is_placing()
		or not preview_valid
		or _selected_definition == null
	):
		return false
	var placement_id := place_definition_at_cell(
		_selected_definition.definition_id,
		preview_origin_cell,
		true
	)
	if placement_id < 0:
		return false
	_refresh_preview_for_current_cell()
	return true


func place_definition_at_cell(
	definition_id: StringName,
	origin_cell: Vector2i,
	charge_cost := true
) -> int:
	var definition := get_definition(definition_id)
	if definition == null:
		return -1
	var validation := evaluate_origin_cell_for_definition(
		origin_cell,
		definition,
		false
	)
	if not bool(validation.valid):
		return -1
	if charge_cost and not _can_pay_definition(definition):
		return -1

	var placement_id := _allocate_placement_id()
	var footprint_cells := get_footprint_cells(
		origin_cell,
		definition.footprint
	)
	var building := _create_placed_building_node(
		placement_id,
		origin_cell,
		definition
	)
	var world_size := _definition_world_size(definition)
	var record := _base_record()
	record.merge({
		"placement_id": placement_id,
		"placement_kind": definition.placement_kind,
		"template_id": definition.definition_id,
		"definition_id": definition.definition_id,
		"display_name": definition.display_name,
		"building_type": definition.building_type,
		"description": definition.description,
		"origin_cell": origin_cell,
		"footprint": definition.footprint,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(Vector2.ZERO, world_size),
		"lifecycle_state": &"running",
		"prototype_status": "运行中",
		"selectable": true,
		"removable": true,
		"movable": false,
		"requires_road": definition.requires_road,
		"road_anchor_offsets": definition.road_anchor_offsets.duplicate(),
		"built_day": current_day,
		"node": building,
	}, true)
	_building_records_by_id[placement_id] = record
	_placement_order.append(placement_id)
	for cell in footprint_cells:
		_occupied_cells[cell] = placement_id
	building.tree_exited.connect(
		_on_runtime_building_tree_exited.bind(placement_id, building),
		CONNECT_ONE_SHOT
	)
	if charge_cost:
		wood -= definition.wood_cost
		food -= definition.food_cost
	_refresh_city_ui()
	city_state_changed.emit()
	return placement_id


func _create_runtime_building(origin_cell: Vector2i) -> int:
	return place_definition_at_cell(
		LOGGING_CAMP_DEFINITION.definition_id,
		origin_cell,
		false
	)


func advance_day() -> bool:
	current_day += 1
	var wood_income := 0
	var food_income := 0
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or int(record.built_day) >= current_day:
			continue
		var definition := get_definition(record.definition_id)
		if definition == null or not is_building_operational(placement_id):
			continue
		var production := definition.get_capability(&"production")
		if production == null:
			continue
		if production.resource_id == &"wood":
			wood_income += production.amount
		elif production.resource_id == &"food":
			food_income += production.amount

	var wood_capacity := get_resource_capacity(&"wood")
	var food_capacity := get_resource_capacity(&"food")
	var accepted_wood := mini(wood_income, maxi(wood_capacity - wood, 0))
	var accepted_food := mini(food_income, maxi(food_capacity - food, 0))
	wood += accepted_wood
	food += accepted_food
	tech_points += 1
	last_daily_breakdown = {
		"maintenance_food": 0,
		"training_completed": 0,
		"wood_income": accepted_wood,
		"food_income": accepted_food,
		"research_income": 1,
		"event_wood_loss": 0,
		"event_food_loss": 0,
	}
	last_daily_report = "入 木%d 粮%d｜维0｜损0｜研+1" % [
		accepted_wood,
		accepted_food,
	]
	if accepted_wood < wood_income or accepted_food < food_income:
		last_daily_report += "（容量封顶）"
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_city_state() -> Dictionary:
	return {
		"day": current_day,
		"wood": wood,
		"food": food,
		"tech_points": tech_points,
		"wood_capacity": get_resource_capacity(&"wood"),
		"food_capacity": get_resource_capacity(&"food"),
		"last_daily_report": last_daily_report,
		"last_daily_breakdown": last_daily_breakdown.duplicate(true),
	}


func get_last_daily_breakdown() -> Dictionary:
	return last_daily_breakdown.duplicate(true)


func get_resource_capacity(resource_id: StringName) -> int:
	var capacity := BASE_RESOURCE_CAPACITY
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty():
			continue
		var definition := get_definition(record.definition_id)
		if definition == null:
			continue
		var storage := definition.get_capability(&"storage")
		if (
			storage != null
			and (
				storage.resource_id == resource_id
				or storage.resource_id == &"wood_food"
			)
		):
			capacity += storage.amount
	return capacity


func get_definition(definition_id: StringName) -> BuildingDefinition:
	return _definitions_by_id.get(definition_id) as BuildingDefinition


func get_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition_id in _definitions_by_id:
		result.append(definition_id)
	result.sort()
	return result


func get_building_count() -> int:
	return _building_records_by_id.size()


func get_placement_ids() -> Array[int]:
	return _placement_order.duplicate()


func get_occupied_cell_count() -> int:
	return _occupied_cells.size()


func get_occupied_placement_id(cell: Vector2i) -> int:
	return int(_occupied_cells.get(cell, -1))


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func get_building_record(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {}
	var result := record.duplicate(true)
	var status := get_operational_status(placement_id)
	result.operational_state = status.state
	result.prototype_status = status.label
	return result


func get_building_node(placement_id: int) -> CanvasItem:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return null
	var building := record.get("node") as CanvasItem
	return building if is_instance_valid(building) else null


func get_placement_id_for_node(building: CanvasItem) -> int:
	if not is_instance_valid(building) or not building.has_meta("placement_id"):
		return -1
	var placement_id := int(building.get_meta("placement_id"))
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty() or record.get("node") != building:
		return -1
	return placement_id


func get_operational_status(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {"state": &"missing", "label": "不存在"}
	if record.placement_kind == PLACEMENT_KIND_ROAD:
		var connected_roads := get_connected_road_cells()
		var road_cell: Vector2i = record.origin_cell
		if connected_roads.has(road_cell):
			return {"state": &"connected", "label": "已接入城市路网"}
		return {"state": &"isolated", "label": "未接入城主府道路根格"}
	if bool(record.requires_road) and not is_building_connected_to_road(
		placement_id
	):
		return {"state": &"disabled", "label": "停用：未接入道路"}
	if record.placement_kind == PLACEMENT_KIND_FIXED:
		return {"state": &"fixed", "label": "固定 / 可选择"}
	return {"state": &"operational", "label": "运行中"}


func is_building_operational(placement_id: int) -> bool:
	var state_id: StringName = get_operational_status(placement_id).state
	return state_id in [&"operational", &"fixed", &"connected"]


func is_building_connected_to_road(placement_id: int) -> bool:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty() or not bool(record.requires_road):
		return not record.is_empty()
	var connected_roads := get_connected_road_cells()
	var origin: Vector2i = record.origin_cell
	for offset in record.road_anchor_offsets:
		if connected_roads.has(origin + Vector2i(offset)):
			return true
	return false


func get_connected_road_cells() -> Dictionary:
	var road_cells: Dictionary = {}
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and record.placement_kind == PLACEMENT_KIND_ROAD
		):
			for cell in record.occupied_footprint_cells:
				road_cells[cell] = true

	var connected: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for root_cell in ROAD_ROOT_CELLS:
		if road_cells.has(root_cell):
			connected[root_cell] = true
			frontier.append(root_cell)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]:
			var neighbor: Vector2i = current + Vector2i(direction)
			if road_cells.has(neighbor) and not connected.has(neighbor):
				connected[neighbor] = true
				frontier.append(neighbor)
	return connected


func remove_placed_building(placement_id: int) -> bool:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if (
		record.is_empty()
		or record.placement_kind == PLACEMENT_KIND_FIXED
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
	for cell in record.occupied_footprint_cells:
		if _occupied_cells.get(cell, -1) != placement_id:
			push_error(
				"Cannot remove placement %d: occupancy ownership mismatch at %s"
				% [placement_id, cell]
			)
			return false
	_release_runtime_record(placement_id, true)
	building.queue_free()
	_enforce_resource_capacity()
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func screen_to_map_local(screen_position: Vector2) -> Vector2:
	return map_world.get_global_transform_with_canvas().affine_inverse() * screen_position


func map_local_to_screen(map_local_position: Vector2) -> Vector2:
	return map_world.get_global_transform_with_canvas() * map_local_position


func map_position_to_origin_cell(
	map_local_position: Vector2,
	footprint := Vector2i.ZERO
) -> Vector2i:
	var effective_footprint := footprint
	if effective_footprint == Vector2i.ZERO:
		effective_footprint = (
			_selected_definition.footprint
			if _selected_definition != null
			else LOGGING_CAMP_DEFINITION.footprint
		)
	var grid_position := (map_local_position - GRID_ORIGIN) / GRID_SIZE
	return Vector2i(
		roundi(grid_position.x - effective_footprint.x * 0.5),
		roundi(grid_position.y - effective_footprint.y * 0.5)
	)


func cell_to_map_local(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * GRID_SIZE


func get_footprint_cells(
	origin_cell: Vector2i,
	footprint := Vector2i.ZERO
) -> Array[Vector2i]:
	var effective_footprint := (
		footprint
		if footprint != Vector2i.ZERO
		else (
			_selected_definition.footprint
			if _selected_definition != null
			else LOGGING_CAMP_DEFINITION.footprint
		)
	)
	var cells: Array[Vector2i] = []
	for y in range(effective_footprint.y):
		for x in range(effective_footprint.x):
			cells.append(origin_cell + Vector2i(x, y))
	return cells


func evaluate_origin_cell(origin_cell: Vector2i) -> Dictionary:
	var definition := (
		_selected_definition
		if _selected_definition != null
		else LOGGING_CAMP_DEFINITION
	)
	return evaluate_origin_cell_for_definition(origin_cell, definition, true)


func evaluate_origin_cell_for_definition(
	origin_cell: Vector2i,
	definition: BuildingDefinition,
	check_ui := true
) -> Dictionary:
	if definition == null:
		return _validation_result(false, "缺少建筑定义")
	var footprint_cells := get_footprint_cells(
		origin_cell,
		definition.footprint
	)
	if not _footprint_is_inside_map(origin_cell, definition.footprint):
		return _validation_result(false, "超出地图")
	for cell in footprint_cells:
		if _occupied_cells.has(cell):
			return _validation_result(false, "位置已占用")
	var screen_rect := get_footprint_screen_rect(
		origin_cell,
		definition.footprint
	)
	if check_ui:
		if not _screen_rect_is_inside_viewport(screen_rect):
			return _validation_result(false, "超出可操作区域", screen_rect)
		for ui_control in _get_ui_occlusion_controls():
			if (
				ui_control.is_visible_in_tree()
				and ui_control.get_global_rect().grow(
					UI_SAFETY_MARGIN
				).intersects(screen_rect)
			):
				return _validation_result(false, "被界面遮挡", screen_rect)
	if not _can_pay_definition(definition):
		return _validation_result(
			false,
			"木材不足（需要 %d）" % definition.wood_cost,
			screen_rect
		)
	return _validation_result(true, "", screen_rect)


func get_footprint_screen_rect(
	origin_cell: Vector2i,
	footprint := Vector2i.ZERO
) -> Rect2:
	var effective_footprint := (
		footprint
		if footprint != Vector2i.ZERO
		else (
			_selected_definition.footprint
			if _selected_definition != null
			else LOGGING_CAMP_DEFINITION.footprint
		)
	)
	var map_origin := cell_to_map_local(origin_cell)
	var map_end := map_origin + Vector2(effective_footprint) * GRID_SIZE
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


func _on_definition_button_pressed(definition_id: StringName) -> void:
	begin_placing_definition(definition_id, get_viewport().get_mouse_position())


func _refresh_preview_for_current_cell() -> void:
	if _selected_definition == null:
		return
	var validation := evaluate_origin_cell_for_definition(
		preview_origin_cell,
		_selected_definition,
		true
	)
	preview_valid = validation.valid
	preview_invalid_reason = validation.reason
	construction_preview.position = cell_to_map_local(preview_origin_cell)
	preview_body.color = (
		PREVIEW_VALID_COLOR if preview_valid else PREVIEW_INVALID_COLOR
	)
	preview_outline.default_color = (
		PREVIEW_VALID_OUTLINE if preview_valid else PREVIEW_INVALID_OUTLINE
	)
	preview_label.text = (
		"%s\n可放置" % _selected_definition.display_name
		if preview_valid
		else "%s\n%s" % [
			_selected_definition.display_name,
			preview_invalid_reason,
		]
	)


func _apply_preview_geometry(definition: BuildingDefinition) -> void:
	var world_size := _definition_world_size(definition)
	preview_body.polygon = _rectangle_polygon(world_size)
	preview_outline.points = _rectangle_outline_points(world_size)
	preview_label.size = world_size
	preview_label.position = Vector2.ZERO


func _footprint_is_inside_map(
	origin_cell: Vector2i,
	footprint: Vector2i
) -> bool:
	var map_grid_size := Vector2i(
		floori(map_board.size.x / GRID_SIZE),
		floori(map_board.size.y / GRID_SIZE)
	)
	return (
		origin_cell.x >= 0
		and origin_cell.y >= 0
		and origin_cell.x + footprint.x <= map_grid_size.x
		and origin_cell.y + footprint.y <= map_grid_size.y
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


func _create_placed_building_node(
	placement_id: int,
	origin_cell: Vector2i,
	definition: BuildingDefinition
) -> Node2D:
	var building := Node2D.new()
	building.name = "Placement%03d" % placement_id
	building.position = cell_to_map_local(origin_cell)
	building.set_meta("placement_id", placement_id)
	var world_size := _definition_world_size(definition)

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _rectangle_polygon(world_size)
	body.color = definition.body_color
	building.add_child(body)

	var outline := Line2D.new()
	outline.name = "Outline"
	outline.points = _rectangle_outline_points(world_size)
	outline.width = 3.0
	outline.default_color = definition.outline_color
	building.add_child(outline)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(3.0, 3.0)
	label.size = world_size - Vector2(6.0, 6.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = definition.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(
		"font_size",
		11 if definition.placement_kind == PLACEMENT_KIND_ROAD else 14
	)
	label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.96, 0.93, 1.0)
	)
	building.add_child(label)

	placed_buildings.add_child(building)
	return building


func _release_runtime_record(
	placement_id: int,
	require_complete_ownership: bool
) -> bool:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if (
		record.is_empty()
		or record.placement_kind == PLACEMENT_KIND_FIXED
	):
		return false
	var footprint_cells: Array = record.occupied_footprint_cells
	if require_complete_ownership:
		for cell in footprint_cells:
			if _occupied_cells.get(cell, -1) != placement_id:
				return false
	for cell in footprint_cells:
		if _occupied_cells.get(cell, -1) == placement_id:
			_occupied_cells.erase(cell)
		elif not require_complete_ownership:
			push_error(
				"Placement %d exited with occupancy mismatch at %s"
				% [placement_id, cell]
			)
	_building_records_by_id.erase(placement_id)
	_placement_order.erase(placement_id)
	building_removed.emit(placement_id)
	return true


func _on_runtime_building_tree_exited(
	placement_id: int,
	building: Node2D
) -> void:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return
	if record.get("node") != building:
		push_error(
			"Placement %d tree exit did not match its authoritative node"
			% placement_id
		)
		return
	_release_runtime_record(placement_id, false)
	city_state_changed.emit()


func _register_definition(definition: BuildingDefinition) -> void:
	if (
		definition == null
		or definition.definition_id == &""
		or _definitions_by_id.has(definition.definition_id)
	):
		push_error("Invalid or duplicate building definition")
		return
	_definitions_by_id[definition.definition_id] = definition


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
		if _occupied_cells.has(cell):
			push_error(
				"Preset building %s overlaps placement %s at %s"
				% [building.name, _occupied_cells[cell], cell]
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
	var record := _base_record()
	record.merge({
		"placement_id": placement_id,
		"placement_kind": PLACEMENT_KIND_FIXED,
		"template_id": definition.template_id,
		"definition_id": definition.template_id,
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
		"built_day": 0,
		"node": building,
	}, true)
	building.set_meta("placement_id", placement_id)
	_building_records_by_id[placement_id] = record
	_placement_order.append(placement_id)
	for cell in footprint_cells:
		_occupied_cells[cell] = placement_id


func _base_record() -> Dictionary:
	return {
		"placement_id": -1,
		"placement_kind": &"",
		"template_id": &"",
		"definition_id": &"",
		"display_name": "",
		"building_type": "",
		"description": "",
		"origin_cell": Vector2i.ZERO,
		"footprint": Vector2i.ZERO,
		"occupied_footprint_cells": [],
		"selection_bounds": Rect2(),
		"lifecycle_state": &"",
		"prototype_status": "",
		"operational_state": &"",
		"selectable": false,
		"removable": false,
		"movable": false,
		"requires_road": false,
		"road_anchor_offsets": [],
		"built_day": 0,
		"node": null,
	}


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


func _can_pay_definition(definition: BuildingDefinition) -> bool:
	return (
		wood >= definition.wood_cost
		and food >= definition.food_cost
	)


func _sync_construction_ui() -> void:
	construction_entry_panel.visible = not _detail_panel_active
	build_entry_button.visible = state != ConstructionState.PLACING
	build_mode_status.visible = state == ConstructionState.PLACING
	if state == ConstructionState.PLACING and _selected_definition != null:
		build_mode_status.text = "建造中：%s\n右键 / Esc 取消" % (
			_selected_definition.display_name
		)
	construction_menu.visible = (
		not _detail_panel_active
		and state == ConstructionState.CHOOSING_TEMPLATE
	)


func _refresh_city_ui() -> void:
	resource_summary.text = "木材 %d/%d · 粮食 %d/%d" % [
		wood,
		get_resource_capacity(&"wood"),
		food,
		get_resource_capacity(&"food"),
	]
	time_summary.text = "第 %d 日" % current_day
	daily_report.text = last_daily_report


func _enforce_resource_capacity() -> void:
	wood = mini(wood, get_resource_capacity(&"wood"))
	food = mini(food, get_resource_capacity(&"food"))


func _definition_world_size(definition: BuildingDefinition) -> Vector2:
	return Vector2(definition.footprint) * GRID_SIZE


func _rectangle_polygon(world_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(world_size.x, 0.0),
		world_size,
		Vector2(0.0, world_size.y),
	])


func _rectangle_outline_points(world_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(world_size.x, 0.0),
		world_size,
		Vector2(0.0, world_size.y),
		Vector2.ZERO,
	])
