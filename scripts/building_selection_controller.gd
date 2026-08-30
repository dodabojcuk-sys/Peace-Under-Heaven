extends Node


enum SelectionState {
	NONE,
	SELECTED,
	REMOVE_CONFIRM,
	UPGRADE_CONFIRM,
}

const SELECTION_OUTLINE_MARGIN := 4.0
const COMMAND_PLATFORM_TEMPLATE_ID := &"command_platform"
const CITY_GATE_TEMPLATE_ID := &"city_gate"
const NOTICEBOARD_TEMPLATE_ID := &"noticeboard"

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
@onready var status_badge: Label = $"../UI/Shell/BuildingDetailPanel/StatusBadge"
@onready var road_status: Label = $"../UI/Shell/BuildingDetailPanel/RoadStatus"
@onready var construction_progress: ProgressBar = (
	$"../UI/Shell/BuildingDetailPanel/ConstructionProgress"
)
@onready var priority_label: Label = (
	$"../UI/Shell/BuildingDetailPanel/PriorityLabel"
)
@onready var priority_help: Label = (
	$"../UI/Shell/BuildingDetailPanel/PriorityHelp"
)
@onready var upgrade_status_card: Label = (
	$"../UI/Shell/BuildingDetailPanel/UpgradeStatusCard"
)
@onready var construction_priority_option: OptionButton = (
	$"../UI/Shell/BuildingDetailPanel/ConstructionPriorityOption"
)
@onready var upgrade_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/UpgradeButton"
)
@onready var upgrade_confirmation: Control = (
	$"../UI/Shell/BuildingDetailPanel/UpgradeConfirmation"
)
@onready var confirm_upgrade_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/UpgradeConfirmation/ConfirmUpgradeButton"
)
@onready var cancel_upgrade_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/UpgradeConfirmation/CancelUpgradeButton"
)
@onready var close_button: Button = $"../UI/Shell/BuildingDetailPanel/CloseButton"
@onready var remove_button: Button = $"../UI/Shell/BuildingDetailPanel/RemoveButton"
@onready var first_war_actions: Control = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions"
)
@onready var city_gate_actions: Control = (
	$"../UI/Shell/BuildingDetailPanel/CityGateActions"
)
@onready var enter_world_map_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/CityGateActions/EnterWorldMapButton"
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
@onready var noticeboard_panel: Panel = $"../UI/Shell/NoticeboardPanel"
@onready var noticeboard_close_button: Button = (
	$"../UI/Shell/NoticeboardPanel/CloseButton"
)

var state := SelectionState.NONE
var selected_placement_id := -1


func _ready() -> void:
	construction_priority_option.add_item("施工优先级：高", 2)
	construction_priority_option.set_item_metadata(0, 2)
	construction_priority_option.add_item("施工优先级：普通", 1)
	construction_priority_option.set_item_metadata(1, 1)
	construction_priority_option.add_item("施工优先级：低", 0)
	construction_priority_option.set_item_metadata(2, 0)
	construction_priority_option.item_selected.connect(
		_on_construction_priority_selected
	)
	close_button.pressed.connect(clear_selection)
	upgrade_button.pressed.connect(request_upgrade_confirmation)
	confirm_upgrade_button.pressed.connect(confirm_upgrade_gate)
	cancel_upgrade_button.pressed.connect(cancel_upgrade_confirmation)
	remove_button.pressed.connect(request_removal_confirmation)
	confirm_remove_button.pressed.connect(confirm_removal)
	cancel_remove_button.pressed.connect(cancel_removal_confirmation)
	enter_world_map_button.pressed.connect(_on_enter_world_map_pressed)
	noticeboard_close_button.pressed.connect(clear_selection)
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
	if selected_placement_id >= 0 and selected_placement_id != placement_id:
		construction_controller.set_building_diagnostic_visible(
			selected_placement_id,
			false
		)
	selected_placement_id = placement_id
	state = SelectionState.SELECTED
	construction_controller.set_building_diagnostic_visible(placement_id, true)
	_refresh_selection_outline(record, building)
	if StringName(record.template_id) == NOTICEBOARD_TEMPLATE_ID:
		detail_panel.visible = false
		construction_controller.show_noticeboard_panel()
	else:
		_refresh_detail_panel(record)
		_show_selected_presentation()
	construction_controller.set_detail_panel_active(true)


func select_building(building: CanvasItem) -> void:
	select_placement(construction_controller.get_placement_id_for_node(building))


func clear_selection() -> void:
	if selected_placement_id >= 0:
		construction_controller.set_building_diagnostic_visible(
			selected_placement_id,
			false
		)
	selected_placement_id = -1
	state = SelectionState.NONE
	selection_outline.visible = false
	detail_panel.visible = false
	noticeboard_panel.visible = false
	removal_confirmation.visible = false
	upgrade_confirmation.visible = false
	first_war_actions.visible = false
	city_gate_actions.visible = false
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


func is_awaiting_upgrade_confirmation() -> bool:
	return state == SelectionState.UPGRADE_CONFIRM and has_selection()


func request_upgrade_confirmation() -> void:
	if not has_selection() or is_awaiting_removal_confirmation():
		return
	state = SelectionState.UPGRADE_CONFIRM
	_show_upgrade_confirmation()


func cancel_upgrade_confirmation() -> void:
	if not is_awaiting_upgrade_confirmation():
		return
	state = SelectionState.SELECTED
	_show_selected_presentation()


func confirm_upgrade_gate() -> void:
	if not is_awaiting_upgrade_confirmation():
		return
	# The current city authority deliberately exposes no building upgrade writer.
	# This confirmation must never simulate an upgrade, cost, or save mutation.
	state = SelectionState.SELECTED
	_show_selected_presentation()


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
	if is_awaiting_upgrade_confirmation():
		cancel_upgrade_confirmation()
		return true
	if is_awaiting_removal_confirmation():
		cancel_removal_confirmation()
		return true
	if has_selection():
		clear_selection()
		return true
	if noticeboard_panel.visible:
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
	var build_data: Dictionary = construction_controller.get_building_data(
		int(record.placement_id)
	)
	var detail_state: Dictionary = construction_controller.get_building_detail_state(
		int(record.placement_id)
	)
	var is_fixed := StringName(record.placement_kind) == &"fixed"
	target_name.text = str(record.display_name)
	target_type.text = (
		"%s\n核心作用：%s" % [
			str(build_data.level_text),
			str(detail_state.get("effect_text", build_data.effect_text)),
		]
		if is_fixed
		else "核心作用：%s" % str(detail_state.get("effect_text", build_data.effect_text))
	)
	status_badge.text = "状态：%s" % str(detail_state.get("primary_status_text", build_data.status_text))
	road_status.text = str(detail_state.get("road_text", "道路：不需要"))
	grid_position.text = str(detail_state.get(
		"orientation_text",
		"朝向：%s" % _construction_orientation_text(int(record.get("orientation", 0)))
	))
	footprint.text = "下一级：当前切片未开放"
	var progress_visible := bool(detail_state.get("progress_visible", false))
	construction_progress.visible = progress_visible
	construction_progress.value = float(detail_state.get("progress_percent", 0))
	prototype_status.visible = progress_visible
	var is_missing := StringName(
		detail_state.get("primary_status_id", &"")
	) == &"MISSING_RESOURCES"
	var remaining_line := str(detail_state.get("remaining_text", ""))
	if is_missing:
		remaining_line = "%s（%s）" % [
			remaining_line,
			str(detail_state.get("missing_text", "")),
		]
	prototype_status.text = "\n".join([
		str(detail_state.get("progress_text", "")),
		str(detail_state.get("paid_text", "")),
		remaining_line,
		str(detail_state.get("eta_text", "")),
	]).replace("\n\n", "\n")
	description.text = (
		"前置：初始固定设施\n状态：固定 / 可选择"
		if is_fixed
		else str(detail_state.get("status_reason_text", ""))
	)
	var is_command_platform := (
		StringName(record.template_id) == COMMAND_PLATFORM_TEMPLATE_ID
	)
	var is_city_gate := (
		StringName(record.template_id) == CITY_GATE_TEMPLATE_ID
	)
	var is_constructing := StringName(record.lifecycle_state) == &"constructing"
	for control in _get_standard_detail_controls():
		control.visible = not is_command_platform and not is_city_gate
	construction_progress.visible = (
		not is_command_platform and not is_city_gate and progress_visible
	)
	prototype_status.visible = construction_progress.visible
	first_war_actions.visible = is_command_platform
	city_gate_actions.visible = is_city_gate
	remove_button.visible = (
		not is_command_platform
		and not is_city_gate
		and bool(record.get("removable", false))
	)
	remove_button.disabled = (
		construction_controller.is_city_action_locked_for_battle()
	)
	construction_priority_option.visible = (
		not is_command_platform and not is_city_gate and bool(detail_state.get("priority_visible", false))
	)
	priority_label.visible = construction_priority_option.visible
	priority_help.visible = construction_priority_option.visible
	priority_help.text = str(detail_state.get("priority_help_text", ""))
	upgrade_status_card.visible = false
	upgrade_button.visible = false
	if is_constructing:
		var priority := int(detail_state.get("priority", build_data.construction_priority))
		for index in range(construction_priority_option.item_count):
			if int(construction_priority_option.get_item_metadata(index)) == priority:
				construction_priority_option.select(index)
				break
	upgrade_status_card.text = "升级状态\n%s\n%s" % [
		str(build_data.level_text),
		str(build_data.next_level_text),
	]


func _show_selected_presentation() -> void:
	panel_title.text = "已选择目标"
	var record: Dictionary = construction_controller.get_building_record(
		selected_placement_id
	)
	target_name.visible = true
	var is_command_platform := (
		StringName(record.template_id) == COMMAND_PLATFORM_TEMPLATE_ID
	)
	var is_city_gate := (
		StringName(record.template_id) == CITY_GATE_TEMPLATE_ID
	)
	var is_constructing := StringName(record.lifecycle_state) == &"constructing"
	for control in _get_standard_detail_controls():
		control.visible = not is_command_platform and not is_city_gate
	construction_priority_option.visible = (
		not is_command_platform and not is_city_gate and is_constructing
	)
	priority_label.visible = construction_priority_option.visible
	priority_help.visible = construction_priority_option.visible
	construction_progress.visible = is_constructing
	prototype_status.visible = is_constructing
	upgrade_status_card.visible = false
	upgrade_button.visible = false
	first_war_actions.visible = is_command_platform
	city_gate_actions.visible = is_city_gate
	remove_button.visible = (
		not is_command_platform
		and not is_city_gate
		and bool(record.get("removable", false))
	)
	removal_confirmation.visible = false
	upgrade_confirmation.visible = false
	detail_panel.visible = true


func _construction_orientation_text(orientation: int) -> String:
	return ["北", "东", "南", "西"][clampi(orientation, 0, 3)]


func _on_construction_priority_selected(index: int) -> void:
	if not has_selection():
		return
	construction_controller.set_construction_priority(
		selected_placement_id,
		int(construction_priority_option.get_item_metadata(index))
	)


func _show_removal_confirmation() -> void:
	panel_title.text = "确认移除"
	for control in _get_detail_controls():
		control.visible = false
	removal_confirmation.visible = true
	detail_panel.visible = true


func _show_upgrade_confirmation() -> void:
	panel_title.text = "升级门禁"
	for control in _get_detail_controls():
		control.visible = false
	removal_confirmation.visible = false
	upgrade_confirmation.visible = true
	detail_panel.visible = true


func _get_detail_controls() -> Array[Control]:
	var controls: Array[Control] = [
		target_name,
		first_war_actions,
		city_gate_actions,
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
		status_badge,
		road_status,
		construction_progress,
		priority_label,
		priority_help,
		construction_priority_option,
		upgrade_status_card,
		upgrade_button,
		remove_button,
	]


func _get_ui_occlusion_controls() -> Array[Control]:
	return [
		top_status_bar,
		city_bar,
		city_bar_toggle,
		minimap_placeholder,
		detail_panel,
		noticeboard_panel,
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
	if StringName(record.template_id) == NOTICEBOARD_TEMPLATE_ID:
		construction_controller.show_noticeboard_panel()
	else:
		_refresh_detail_panel(record)


func _on_enter_world_map_pressed() -> void:
	if not has_selection():
		return
	var record: Dictionary = construction_controller.get_building_record(
		selected_placement_id
	)
	if StringName(record.get("template_id", &"")) != CITY_GATE_TEMPLATE_ID:
		return
	var root := get_parent()
	if root != null and root.has_method("open_campaign_world_map"):
		root.open_campaign_world_map()
