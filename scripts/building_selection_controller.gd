extends Node


enum SelectionState {
	NONE,
	SELECTED,
	REMOVE_CONFIRM,
}

const SELECTION_OUTLINE_MARGIN := 4.0
const COMMAND_PLATFORM_TEMPLATE_ID := &"command_platform"

@onready var map_world: Node2D = $"../MapWorld"
@onready var selection_outline: Line2D = $"../MapWorld/ConstructionLayer/SelectionOutline"
@onready var construction_controller: Node = $"../ConstructionController"
@onready var detail_panel: Panel = $"../UI/Shell/BuildingDetailPanel"
@onready var panel_title: Label = $"../UI/Shell/BuildingDetailPanel/PanelTitle"
@onready var target_name: Label = $"../UI/Shell/BuildingDetailPanel/TargetName"
@onready var target_type: Label = $"../UI/Shell/BuildingDetailPanel/TargetType"
@onready var grid_position: Label = $"../UI/Shell/BuildingDetailPanel/GridPosition"
@onready var footprint: Label = $"../UI/Shell/BuildingDetailPanel/Footprint"
@onready var prototype_status: Label = $"../UI/Shell/BuildingDetailPanel/PrototypeStatus"
@onready var description: Label = $"../UI/Shell/BuildingDetailPanel/Description"
@onready var close_button: Button = $"../UI/Shell/BuildingDetailPanel/CloseButton"
@onready var remove_button: Button = $"../UI/Shell/BuildingDetailPanel/RemoveButton"
@onready var first_war_actions: Control = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions"
)
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
@onready var city_bar_toggle: Control = $"../UI/Shell/CityBarToggle"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"

var state := SelectionState.NONE
var selected_placement_id := -1


func _ready() -> void:
	close_button.pressed.connect(clear_selection)
	remove_button.pressed.connect(request_removal_confirmation)
	confirm_remove_button.pressed.connect(confirm_removal)
	cancel_remove_button.pressed.connect(cancel_removal_confirmation)
	construction_controller.building_removed.connect(_on_building_removed)
	construction_controller.city_state_changed.connect(_on_city_state_changed)
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
	var building: CanvasItem = construction_controller.get_building_node(placement_id)
	if (
		record.is_empty()
		or not bool(record.get("selectable", false))
		or building == null
		or not building.is_inside_tree()
	):
		clear_selection()
		return

	construction_controller.cancel_build_interaction()
	selected_placement_id = placement_id
	state = SelectionState.SELECTED
	_refresh_selection_outline(record, building)
	_refresh_detail_panel(record)
	_show_selected_presentation()
	construction_controller.set_detail_panel_active(true)


func select_building(building: CanvasItem) -> void:
	select_placement(construction_controller.get_placement_id_for_node(building))


func clear_selection() -> void:
	selected_placement_id = -1
	state = SelectionState.NONE
	selection_outline.visible = false
	detail_panel.visible = false
	removal_confirmation.visible = false
	first_war_actions.visible = false
	construction_controller.set_detail_panel_active(false)


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
	var record: Dictionary = construction_controller.get_building_record(
		selected_placement_id
	)
	if construction_controller.is_city_action_locked_for_battle():
		return
	if (
		not has_selection()
		or not bool(record.get("removable", false))
	):
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

	var placement_ids: Array[int] = construction_controller.get_placement_ids()
	for index in range(placement_ids.size() - 1, -1, -1):
		var placement_id: int = placement_ids[index]
		var record: Dictionary = construction_controller.get_building_record(
			placement_id
		)
		var building: CanvasItem = construction_controller.get_building_node(
			placement_id
		)
		if (
			record.is_empty()
			or not bool(record.get("selectable", false))
			or building == null
		):
			continue
		var selection_bounds: Rect2 = record.selection_bounds
		var building_local_position := (
			building.get_global_transform().affine_inverse()
			* map_global_position
		)
		if selection_bounds.has_point(building_local_position):
			return placement_id

	return -1


func get_building_at_screen_position(screen_position: Vector2) -> CanvasItem:
	return construction_controller.get_building_node(
		get_placement_id_at_screen_position(screen_position)
	)


func is_detail_panel_point(screen_position: Vector2) -> bool:
	return (
		detail_panel.is_visible_in_tree()
		and detail_panel.get_global_rect().has_point(screen_position)
	)


func is_screen_point_blocked(screen_position: Vector2) -> bool:
	if construction_controller.is_construction_ui_point(screen_position):
		return true
	for ui_control in _get_ui_occlusion_controls():
		if (
			ui_control.is_visible_in_tree()
			and ui_control.get_global_rect().has_point(screen_position)
		):
			return true
	return false


func _refresh_selection_outline(
	record: Dictionary,
	building: CanvasItem
) -> void:
	var selection_bounds: Rect2 = record.selection_bounds
	var expanded_bounds := selection_bounds.grow(SELECTION_OUTLINE_MARGIN)
	selection_outline.points = PackedVector2Array([
		expanded_bounds.position,
		Vector2(expanded_bounds.end.x, expanded_bounds.position.y),
		expanded_bounds.end,
		Vector2(expanded_bounds.position.x, expanded_bounds.end.y),
		expanded_bounds.position,
	])
	selection_outline.global_transform = building.get_global_transform()
	selection_outline.visible = true


func _refresh_detail_panel(record: Dictionary) -> void:
	var origin_cell: Vector2i = record.origin_cell
	var footprint_cells: Vector2i = record.footprint
	target_name.text = str(record.display_name)
	target_type.text = "类型：%s" % str(record.building_type)
	grid_position.text = "网格位置：(%d, %d)" % [origin_cell.x, origin_cell.y]
	footprint.text = "占地：%d × %d" % [footprint_cells.x, footprint_cells.y]
	prototype_status.text = "状态：%s" % str(record.prototype_status)
	description.text = str(record.description)
	var is_command_platform := (
		StringName(record.template_id) == COMMAND_PLATFORM_TEMPLATE_ID
	)
	for control in _get_standard_detail_controls():
		control.visible = not is_command_platform
	first_war_actions.visible = is_command_platform
	remove_button.visible = (
		not is_command_platform
		and bool(record.get("removable", false))
	)
	remove_button.disabled = (
		construction_controller.is_city_action_locked_for_battle()
	)


func _show_selected_presentation() -> void:
	panel_title.text = "已选择目标"
	var record: Dictionary = construction_controller.get_building_record(
		selected_placement_id
	)
	target_name.visible = true
	var is_command_platform := (
		StringName(record.template_id) == COMMAND_PLATFORM_TEMPLATE_ID
	)
	for control in _get_standard_detail_controls():
		control.visible = not is_command_platform
	first_war_actions.visible = is_command_platform
	remove_button.visible = (
		not is_command_platform
		and bool(record.get("removable", false))
	)
	removal_confirmation.visible = false
	detail_panel.visible = true


func _show_removal_confirmation() -> void:
	panel_title.text = "确认移除"
	for control in _get_detail_controls():
		control.visible = false
	removal_confirmation.visible = true
	detail_panel.visible = true


func _get_detail_controls() -> Array[Control]:
	var controls: Array[Control] = [
		target_name,
		first_war_actions,
	]
	controls.append_array(_get_standard_detail_controls())
	return controls


func _get_standard_detail_controls() -> Array[Control]:
	return [
		target_type,
		grid_position,
		footprint,
		prototype_status,
		description,
		remove_button,
	]


func _get_ui_occlusion_controls() -> Array[Control]:
	return [
		top_status_bar,
		city_bar,
		city_bar_toggle,
		minimap_placeholder,
		detail_panel,
	]


func _on_building_removed(placement_id: int) -> void:
	if placement_id == selected_placement_id:
		clear_selection()


func _on_city_state_changed() -> void:
	if not has_selection() or state != SelectionState.SELECTED:
		return
	var record: Dictionary = construction_controller.get_building_record(
		selected_placement_id
	)
	var building: CanvasItem = construction_controller.get_building_node(
		selected_placement_id
	)
	if record.is_empty() or building == null:
		clear_selection()
		return
	_refresh_selection_outline(record, building)
	_refresh_detail_panel(record)
