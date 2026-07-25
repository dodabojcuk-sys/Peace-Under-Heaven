extends Node


enum SelectionState {
	NONE,
	SELECTED,
	REMOVE_CONFIRM,
}

const SELECTION_OUTLINE_MARGIN := 4.0

@onready var map_world: Node2D = $"../MapWorld"
@onready var placed_buildings: Node2D = $"../MapWorld/ConstructionLayer/PlacedBuildings"
@onready var selection_outline: Line2D = $"../MapWorld/ConstructionLayer/SelectionOutline"
@onready var construction_controller: Node = $"../ConstructionController"
@onready var detail_panel: Panel = $"../UI/Shell/BuildingDetailPanel"
@onready var panel_title: Label = $"../UI/Shell/BuildingDetailPanel/PanelTitle"
@onready var target_name: Label = $"../UI/Shell/BuildingDetailPanel/TargetName"
@onready var target_type: Label = $"../UI/Shell/BuildingDetailPanel/TargetType"
@onready var grid_position: Label = $"../UI/Shell/BuildingDetailPanel/GridPosition"
@onready var footprint: Label = $"../UI/Shell/BuildingDetailPanel/Footprint"
@onready var prototype_status: Label = $"../UI/Shell/BuildingDetailPanel/PrototypeStatus"
@onready var close_button: Button = $"../UI/Shell/BuildingDetailPanel/CloseButton"
@onready var remove_button: Button = $"../UI/Shell/BuildingDetailPanel/RemoveButton"
@onready var removal_confirmation: Control = (
	$"../UI/Shell/BuildingDetailPanel/RemovalConfirmation"
)
@onready var confirm_remove_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/RemovalConfirmation/ConfirmRemoveButton"
)
@onready var cancel_remove_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/RemovalConfirmation/CancelRemoveButton"
)
@onready var top_status_bar: Control = $"../UI/Shell/TopStatusBar"
@onready var city_bar: Control = $"../UI/Shell/CityBar"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"
@onready var context_bar: Control = $"../UI/Shell/ContextBar"

var state := SelectionState.NONE
var selected_placement_id := -1


func _ready() -> void:
	close_button.pressed.connect(clear_selection)
	remove_button.pressed.connect(request_removal_confirmation)
	confirm_remove_button.pressed.connect(confirm_removal)
	cancel_remove_button.pressed.connect(cancel_removal_confirmation)
	construction_controller.building_removed.connect(_on_building_removed)
	clear_selection()


func handle_map_click(screen_position: Vector2) -> void:
	if is_screen_point_blocked(screen_position):
		return

	var placement_id := get_placement_id_at_screen_position(screen_position)
	if placement_id < 0:
		clear_selection()
	else:
		select_placement(placement_id)


func select_placement(placement_id: int) -> void:
	var record: Dictionary = construction_controller.get_building_record(placement_id)
	var building: Node2D = construction_controller.get_building_node(placement_id)
	if record.is_empty() or building == null or not building.is_inside_tree():
		clear_selection()
		return

	selected_placement_id = placement_id
	state = SelectionState.SELECTED
	_refresh_selection_outline(record, building)
	_refresh_detail_panel(record)
	_show_selected_presentation()


func select_building(building: Node2D) -> void:
	select_placement(construction_controller.get_placement_id_for_node(building))


func clear_selection() -> void:
	selected_placement_id = -1
	state = SelectionState.NONE
	selection_outline.visible = false
	detail_panel.visible = false
	removal_confirmation.visible = false


func has_selection() -> bool:
	return (
		selected_placement_id >= 0
		and not construction_controller.get_building_record(
			selected_placement_id
		).is_empty()
	)


func is_awaiting_removal_confirmation() -> bool:
	return state == SelectionState.REMOVE_CONFIRM and has_selection()


func request_removal_confirmation() -> void:
	if not has_selection():
		clear_selection()
		return
	state = SelectionState.REMOVE_CONFIRM
	_show_removal_confirmation()


func cancel_removal_confirmation() -> void:
	if not is_awaiting_removal_confirmation():
		return
	state = SelectionState.SELECTED
	_show_selected_presentation()


func confirm_removal() -> bool:
	if not is_awaiting_removal_confirmation():
		return false

	var placement_id := selected_placement_id
	if not construction_controller.remove_placed_building(placement_id):
		return false
	if selected_placement_id == placement_id:
		clear_selection()
	return true


func handle_escape() -> bool:
	if is_awaiting_removal_confirmation():
		cancel_removal_confirmation()
		return true
	if has_selection():
		clear_selection()
		return true
	return false


func get_placement_id_at_screen_position(screen_position: Vector2) -> int:
	var map_local_position := (
		map_world.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)
	var map_global_position := map_world.to_global(map_local_position)

	for index in range(placed_buildings.get_child_count() - 1, -1, -1):
		var building := placed_buildings.get_child(index) as Node2D
		if building == null:
			continue
		var placement_id: int = construction_controller.get_placement_id_for_node(
			building
		)
		if placement_id < 0:
			continue
		var record: Dictionary = construction_controller.get_building_record(
			placement_id
		)
		if record.is_empty():
			continue
		var selection_bounds: Rect2 = record.selection_bounds
		var building_local_position := building.to_local(map_global_position)
		if selection_bounds.has_point(building_local_position):
			return placement_id

	return -1


func get_building_at_screen_position(screen_position: Vector2) -> Node2D:
	return construction_controller.get_building_node(
		get_placement_id_at_screen_position(screen_position)
	)


func is_detail_panel_point(screen_position: Vector2) -> bool:
	return (
		detail_panel.is_visible_in_tree()
		and detail_panel.get_global_rect().has_point(screen_position)
	)


func is_screen_point_blocked(screen_position: Vector2) -> bool:
	for ui_control in _get_ui_occlusion_controls():
		if (
			ui_control.is_visible_in_tree()
			and ui_control.get_global_rect().has_point(screen_position)
		):
			return true
	return false


func _refresh_selection_outline(record: Dictionary, building: Node2D) -> void:
	var selection_bounds: Rect2 = record.selection_bounds
	var expanded_bounds := selection_bounds.grow(SELECTION_OUTLINE_MARGIN)
	selection_outline.points = PackedVector2Array([
		expanded_bounds.position,
		Vector2(expanded_bounds.end.x, expanded_bounds.position.y),
		expanded_bounds.end,
		Vector2(expanded_bounds.position.x, expanded_bounds.end.y),
		expanded_bounds.position,
	])
	selection_outline.global_transform = building.global_transform
	selection_outline.visible = true


func _refresh_detail_panel(record: Dictionary) -> void:
	var origin_cell: Vector2i = record.origin_cell
	var footprint_cells: Vector2i = record.footprint
	target_name.text = str(record.display_name)
	target_type.text = "类型：%s" % str(record.building_type)
	grid_position.text = "网格位置：(%d, %d)" % [origin_cell.x, origin_cell.y]
	footprint.text = "占地：%d × %d" % [footprint_cells.x, footprint_cells.y]
	prototype_status.text = "状态：%s" % str(record.prototype_status)


func _show_selected_presentation() -> void:
	panel_title.text = "已选择目标"
	for control in _get_detail_controls():
		control.visible = true
	removal_confirmation.visible = false
	detail_panel.visible = true


func _show_removal_confirmation() -> void:
	panel_title.text = "确认移除"
	for control in _get_detail_controls():
		control.visible = false
	removal_confirmation.visible = true
	detail_panel.visible = true


func _get_detail_controls() -> Array[Control]:
	return [
		target_name,
		target_type,
		grid_position,
		footprint,
		prototype_status,
		remove_button,
	]


func _get_ui_occlusion_controls() -> Array[Control]:
	return [
		top_status_bar,
		city_bar,
		minimap_placeholder,
		context_bar,
		detail_panel,
	]


func _on_building_removed(placement_id: int) -> void:
	if placement_id == selected_placement_id:
		clear_selection()
