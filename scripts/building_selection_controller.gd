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
@onready var upgrade_confirmation_text: Label = (
	$"../UI/Shell/BuildingDetailPanel/UpgradeConfirmation/ConfirmationText"
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
var governance_action_group: VBoxContainer
var governance_primary_action: Button
var governance_secondary_action: Button
var governance_overflow_actions: VBoxContainer
var governance_manual_action: Button
var governance_remove_action: Button
var governance_feedback: Label
var upgrade_progress_scroll: ScrollContainer
var upgrade_progress_content: VBoxContainer
var upgrade_progress_bar: ProgressBar
var upgrade_progress_label: Label
var _governance_primary_mode: StringName = &""
var _hovered_placement_id := -1


func _ready() -> void:
	_install_upgrade_progress_layout()
	_install_governance_action_group()
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
		if (
			construction_controller.has_method("get_regular_campaign_plot_at_screen_position")
			and construction_controller.has_method("select_regular_campaign_plot")
		):
			var plot := int(construction_controller.call("get_regular_campaign_plot_at_screen_position", screen_position))
			if plot >= 0:
				clear_selection()
				construction_controller.call("select_regular_campaign_plot", plot)
				return
		clear_selection()
	else:
		select_placement(placement_id)


func handle_map_hover(screen_position: Vector2) -> void:
	var next_placement_id := -1
	if not is_screen_point_blocked(screen_position):
		next_placement_id = get_placement_id_at_screen_position(screen_position)
	if next_placement_id == _hovered_placement_id:
		return
	clear_hover()
	var building: CanvasItem = construction_controller.get_building_node(
		next_placement_id
	)
	if building != null and building.has_method("set_hovered_state"):
		building.set_hovered_state(true)
		_hovered_placement_id = next_placement_id


func clear_hover() -> void:
	if _hovered_placement_id < 0:
		return
	var building: CanvasItem = construction_controller.get_building_node(
		_hovered_placement_id
	)
	if building != null and building.has_method("set_hovered_state"):
		building.set_hovered_state(false)
	_hovered_placement_id = -1


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
	if construction_controller.has_method("select_regular_campaign_placement"):
		construction_controller.call("select_regular_campaign_placement", placement_id)
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
	if construction_controller.has_road_connection_recommendation_preview():
		construction_controller.cancel_road_preview()
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
	if is_instance_valid(governance_action_group):
		governance_action_group.visible = false
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
	var build_data: Dictionary = construction_controller.get_building_data(selected_placement_id)
	if not bool(build_data.get("upgrade_available", false)):
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
	var build_data: Dictionary = construction_controller.get_building_data(selected_placement_id)
	var result: Dictionary
	if bool(build_data.get("upgrade_active", false)):
		result = construction_controller.cancel_building_upgrade(selected_placement_id)
	else:
		result = construction_controller.begin_building_upgrade(selected_placement_id)
	state = SelectionState.SELECTED
	var record: Dictionary = construction_controller.get_building_record(selected_placement_id)
	if not record.is_empty():
		_refresh_detail_panel(record)
	_show_selected_presentation()
	governance_feedback.text = (
		"操作已提交"
		if bool(result.get("success", false))
		else str(result.get("error", "操作未完成"))
	)
	governance_feedback.visible = true


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
	footprint.text = str(build_data.next_level_text)
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
	var show_upgrade_progress := not is_command_platform and not is_city_gate and bool(detail_state.get("upgrade_active", false))
	construction_progress.visible = not is_command_platform and not is_city_gate and progress_visible and not show_upgrade_progress
	prototype_status.visible = construction_progress.visible
	_sync_upgrade_progress_projection(show_upgrade_progress)
	first_war_actions.visible = is_command_platform
	city_gate_actions.visible = is_city_gate
	remove_button.visible = false
	construction_priority_option.visible = false
	priority_label.visible = false
	priority_help.visible = false
	priority_help.text = str(detail_state.get("priority_help_text", ""))
	upgrade_status_card.visible = false
	upgrade_button.visible = false
	# The compact action group replaces the old scattered lower-card controls.
	# Keeping only the status lines above it makes the primary action legible at
	# the smallest supported viewport without shrinking type.
	grid_position.visible = false
	footprint.visible = false
	description.visible = false
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
	_refresh_governance_actions(record, detail_state)


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
	var build_data: Dictionary = construction_controller.get_building_data(selected_placement_id)
	var is_upgrading := bool(build_data.get("upgrade_active", false))
	for control in _get_standard_detail_controls():
		control.visible = not is_command_platform and not is_city_gate
	construction_priority_option.visible = false
	priority_label.visible = false
	priority_help.visible = false
	construction_progress.visible = is_constructing
	prototype_status.visible = is_constructing
	_sync_upgrade_progress_projection(is_upgrading)
	upgrade_status_card.visible = false
	upgrade_button.visible = false
	first_war_actions.visible = is_command_platform
	city_gate_actions.visible = is_city_gate
	remove_button.visible = (
		false
	)
	grid_position.visible = false
	footprint.visible = false
	description.visible = false
	if is_instance_valid(governance_action_group):
		governance_action_group.visible = (
			not is_command_platform and not is_city_gate
		)
	removal_confirmation.visible = false
	upgrade_confirmation.visible = false
	detail_panel.visible = true


func _construction_orientation_text(orientation: int) -> String:
	return ["北", "东", "南", "西"][clampi(orientation, 0, 3)]


func _install_upgrade_progress_layout() -> void:
	upgrade_progress_scroll = ScrollContainer.new()
	upgrade_progress_scroll.name = "UpgradeProgressScroll"
	upgrade_progress_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_progress_scroll.offset_left = 18.0
	upgrade_progress_scroll.offset_top = 164.0
	upgrade_progress_scroll.offset_right = -18.0
	upgrade_progress_scroll.offset_bottom = -190.0
	upgrade_progress_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrade_progress_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	upgrade_progress_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_progress_scroll.visible = false
	detail_panel.add_child(upgrade_progress_scroll)

	upgrade_progress_content = VBoxContainer.new()
	upgrade_progress_content.name = "UpgradeProgressContent"
	upgrade_progress_content.custom_minimum_size = Vector2(220.0, 0.0)
	upgrade_progress_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_progress_content.add_theme_constant_override("separation", 8)
	upgrade_progress_scroll.add_child(upgrade_progress_content)

	upgrade_progress_bar = ProgressBar.new()
	upgrade_progress_bar.name = "UpgradeProgressBar"
	upgrade_progress_bar.custom_minimum_size = Vector2(0.0, 16.0)
	upgrade_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_progress_bar.show_percentage = false
	upgrade_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_progress_content.add_child(upgrade_progress_bar)

	upgrade_progress_label = Label.new()
	upgrade_progress_label.name = "UpgradeProgressLabel"
	upgrade_progress_label.custom_minimum_size = Vector2(0.0, 96.0)
	upgrade_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_progress_content.add_child(upgrade_progress_label)


func _sync_upgrade_progress_projection(visible: bool) -> void:
	if not is_instance_valid(upgrade_progress_scroll):
		return
	upgrade_progress_scroll.visible = visible
	if not visible:
		return
	upgrade_progress_bar.value = construction_progress.value
	upgrade_progress_label.text = prototype_status.text


func _install_governance_action_group() -> void:
	# The action group is a real Container anchored to the detail card. It owns
	# only temporary presentation controls; selection and city state remain with
	# their existing controllers.
	governance_action_group = VBoxContainer.new()
	governance_action_group.name = "GovernanceActionGroup"
	governance_action_group.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	governance_action_group.offset_left = 18.0
	governance_action_group.offset_right = -18.0
	governance_action_group.offset_top = -176.0
	governance_action_group.offset_bottom = -16.0
	governance_action_group.add_theme_constant_override("separation", 8)
	governance_action_group.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_panel.add_child(governance_action_group)

	governance_feedback = Label.new()
	governance_feedback.name = "GovernanceFeedback"
	governance_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	governance_feedback.custom_minimum_size = Vector2(0.0, 38.0)
	governance_feedback.visible = false
	governance_action_group.add_child(governance_feedback)

	governance_primary_action = Button.new()
	governance_primary_action.name = "GovernancePrimaryAction"
	governance_primary_action.custom_minimum_size = Vector2(0.0, 44.0)
	governance_primary_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	governance_primary_action.focus_mode = Control.FOCUS_ALL
	governance_primary_action.tooltip_text = "当前建筑的主要操作"
	governance_primary_action.pressed.connect(_on_governance_primary_pressed)
	governance_action_group.add_child(governance_primary_action)

	governance_secondary_action = Button.new()
	governance_secondary_action.name = "GovernanceSecondaryAction"
	governance_secondary_action.custom_minimum_size = Vector2(0.0, 44.0)
	governance_secondary_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	governance_secondary_action.focus_mode = Control.FOCUS_ALL
	governance_secondary_action.pressed.connect(_on_governance_secondary_pressed)
	governance_action_group.add_child(governance_secondary_action)

	governance_overflow_actions = VBoxContainer.new()
	governance_overflow_actions.name = "GovernanceOverflowActions"
	governance_overflow_actions.add_theme_constant_override("separation", 6)
	governance_overflow_actions.visible = false
	governance_action_group.add_child(governance_overflow_actions)

	governance_manual_action = Button.new()
	governance_manual_action.name = "GovernanceManualRoadAction"
	governance_manual_action.text = "手动规划道路"
	governance_manual_action.custom_minimum_size = Vector2(0.0, 44.0)
	governance_manual_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	governance_manual_action.focus_mode = Control.FOCUS_ALL
	governance_manual_action.pressed.connect(_begin_manual_road_planning)
	governance_overflow_actions.add_child(governance_manual_action)

	governance_remove_action = Button.new()
	governance_remove_action.name = "GovernanceRemoveAction"
	governance_remove_action.text = "移除建筑"
	governance_remove_action.custom_minimum_size = Vector2(0.0, 44.0)
	governance_remove_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	governance_remove_action.focus_mode = Control.FOCUS_ALL
	governance_remove_action.pressed.connect(request_removal_confirmation)
	governance_overflow_actions.add_child(governance_remove_action)


func _refresh_governance_actions(
	record: Dictionary,
	_detail_state: Dictionary
) -> void:
	if not is_instance_valid(governance_action_group):
		return
	if (
		construction_controller.has_method("is_regular_campaign_city_active")
		and bool(construction_controller.call("is_regular_campaign_city_active"))
	):
		_refresh_regular_campaign_actions(record)
		return
	var requires_road := bool(record.get("requires_road", false))
	var disconnected: bool = (
		requires_road
		and not construction_controller.is_building_connected_to_road(
			int(record.placement_id)
		)
	)
	var build_data: Dictionary = construction_controller.get_building_data(int(record.placement_id))
	governance_feedback.visible = false
	governance_overflow_actions.visible = false
	governance_secondary_action.visible = true
	governance_secondary_action.text = "更多操作"
	governance_primary_action.visible = true
	if bool(build_data.get("upgrade_active", false)):
		_governance_primary_mode = &"upgrade"
		governance_primary_action.text = "查看或取消升级"
		governance_primary_action.tooltip_text = str(build_data.get("upgrade_capability_text", "升级施工中"))
	elif bool(build_data.get("upgrade_available", false)):
		_governance_primary_mode = &"upgrade"
		governance_primary_action.text = "升级到下一等级"
		governance_primary_action.tooltip_text = " · ".join([
			str(build_data.get("upgrade_cost_text", "")),
			str(build_data.get("upgrade_duration_text", "")),
			str(build_data.get("upgrade_capability_text", "")),
		])
	elif disconnected:
		_governance_primary_mode = &"recommend"
		governance_primary_action.text = "查看接通方案"
		governance_primary_action.tooltip_text = "只预览唯一最短合法道路，不扣木材"
	else:
		_governance_primary_mode = &"status"
		governance_primary_action.text = "查看经营状态"
		governance_primary_action.tooltip_text = "查看当前建筑的权威状态说明"
	governance_manual_action.visible = requires_road
	governance_remove_action.visible = (
		bool(record.get("removable", false))
		and not construction_controller.is_city_action_locked_for_battle()
	)
	governance_secondary_action.visible = (
		governance_manual_action.visible or governance_remove_action.visible
	)


func _refresh_regular_campaign_actions(record: Dictionary) -> void:
	var connected := bool(record.get("connected", false))
	var workers := int(record.get("workers", 0))
	governance_feedback.visible = false
	governance_overflow_actions.visible = false
	governance_manual_action.visible = false
	governance_remove_action.visible = false
	governance_primary_action.visible = true
	governance_secondary_action.visible = true
	governance_primary_action.disabled = false
	governance_secondary_action.disabled = false
	if not connected:
		_governance_primary_mode = &"regular_connect"
		governance_primary_action.text = "连接道路 · 木材 2"
		governance_primary_action.tooltip_text = "提交本关现有 connect 命令"
	else:
		_governance_primary_mode = &"regular_worker_add"
		governance_primary_action.text = "增加岗位 · 当前 %d/4" % workers
		governance_primary_action.disabled = workers >= 4
		governance_primary_action.tooltip_text = "驻地军人不能同时生产和出战"
	governance_secondary_action.text = "减少岗位 · 当前 %d/4" % workers
	governance_secondary_action.disabled = workers <= 0


func _show_regular_campaign_action_result(value: Variant) -> void:
	var result := Dictionary(value) if value is Dictionary else {}
	governance_feedback.text = str(
		result.get("message", "操作已提交")
		if bool(result.get("success", false))
		else result.get("error", "操作未完成")
	)
	governance_feedback.visible = true
	var record: Dictionary = construction_controller.get_building_record(selected_placement_id)
	if not record.is_empty():
		_refresh_detail_panel(record)
		_show_selected_presentation()


func _on_governance_primary_pressed() -> void:
	if not has_selection():
		return
	match _governance_primary_mode:
		&"regular_connect":
			_show_regular_campaign_action_result(construction_controller.call("regular_campaign_connect_building", selected_placement_id))
		&"regular_worker_add":
			_show_regular_campaign_action_result(construction_controller.call("regular_campaign_adjust_workers", selected_placement_id, 1))
		&"regular_worker_remove":
			_show_regular_campaign_action_result(construction_controller.call("regular_campaign_adjust_workers", selected_placement_id, -1))
		&"upgrade":
			request_upgrade_confirmation()
		&"recommend":
			_show_road_connection_recommendation()
		&"confirm":
			if construction_controller.confirm_road_preview():
				clear_selection()
			else:
				governance_feedback.text = "接通方案已过期，请重新查看方案"
				governance_feedback.visible = true
				_governance_primary_mode = &"recommend"
				governance_primary_action.text = "重新查看接通方案"
				governance_secondary_action.visible = true
				governance_secondary_action.text = "手动规划"
		&"manual":
			_begin_manual_road_planning()
		_:
			governance_feedback.text = "%s\n%s" % [
				road_status.text,
				description.text if not description.text.is_empty() else "当前无需额外操作",
			]
			governance_feedback.visible = true


func _on_governance_secondary_pressed() -> void:
	if _governance_primary_mode in [&"regular_connect", &"regular_worker_add", &"regular_worker_remove"]:
		_show_regular_campaign_action_result(construction_controller.call("regular_campaign_adjust_workers", selected_placement_id, -1))
		return
	if _governance_primary_mode == &"confirm":
		_begin_manual_road_planning()
		return
	governance_overflow_actions.visible = not governance_overflow_actions.visible


func _show_road_connection_recommendation() -> void:
	var recommendation: Dictionary = construction_controller.preview_road_connection_recommendation(
		selected_placement_id
	)
	var status := StringName(recommendation.get("status", &"unavailable"))
	governance_feedback.visible = true
	if status == &"recommended":
		governance_feedback.text = "接通方案 · %s\n路径 %d 格 · 木材 %d · %s · %s" % [
			str(recommendation.get("target_name", "目标建筑")),
			int(recommendation.get("path_length", 0)),
			int(recommendation.get("wood_cost", 0)),
			str(recommendation.get("connection_result", "接入主路网")),
			str(recommendation.get("completion_method", "立即铺设")),
		]
		_governance_primary_mode = &"confirm"
		governance_primary_action.text = "确认铺设"
		governance_primary_action.tooltip_text = "重新验证道路和资源后立即铺设"
		governance_secondary_action.visible = true
		governance_secondary_action.text = "手动规划"
		governance_overflow_actions.visible = false
	else:
		governance_feedback.text = str(
			recommendation.get("message", "没有可用接通方案，请手动规划")
		)
		_governance_primary_mode = &"manual"
		governance_primary_action.text = "手动规划"
		governance_primary_action.tooltip_text = "进入现有道路拖拽流程"
		governance_secondary_action.visible = false
		governance_overflow_actions.visible = false


func _begin_manual_road_planning() -> void:
	if construction_controller.switch_recommended_road_to_manual():
		clear_selection()
		return
	construction_controller.begin_road_mode(get_viewport().get_mouse_position())
	clear_selection()


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
	var build_data: Dictionary = construction_controller.get_building_data(selected_placement_id)
	var record: Dictionary = construction_controller.get_building_record(selected_placement_id)
	var active := bool(build_data.get("upgrade_active", false))
	var current_level := int(record.get("level", 1))
	var target_level := current_level + 1
	panel_title.text = "%s Lv.%d → Lv.%d" % [str(record.get("display_name", "建筑")), current_level, target_level]
	for control in _get_detail_controls():
		control.visible = false
	removal_confirmation.visible = false
	upgrade_confirmation_text.text = (
		"取消后返还本次已投入资源，建筑保留当前等级。"
		if active
		else "\n".join([
			str(build_data.get("upgrade_capability_text", "")),
			"成本：%s · 工期：%s" % [
				str(build_data.get("upgrade_cost_text", "")),
				str(build_data.get("upgrade_duration_text", "")),
			],
			str(build_data.get("upgrade_condition_text", "")),
			str(build_data.get("upgrade_error", "")),
		]).strip_edges()
	)
	confirm_upgrade_button.text = "确认取消并退款" if active else "确认投入并升级"
	confirm_upgrade_button.disabled = not active and not bool(build_data.get("upgrade_valid", false))
	upgrade_confirmation.visible = true
	detail_panel.visible = true


func _get_detail_controls() -> Array[Control]:
	var controls: Array[Control] = [
		target_name,
		first_war_actions,
		city_gate_actions,
	]
	controls.append_array(_get_standard_detail_controls())
	if is_instance_valid(governance_action_group):
		controls.append(governance_action_group)
	if is_instance_valid(upgrade_progress_scroll):
		controls.append(upgrade_progress_scroll)
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
	var controls: Array[Control] = [
		top_status_bar,
		city_bar,
		city_bar_toggle,
		minimap_placeholder,
		detail_panel,
		noticeboard_panel,
	]
	var governance_workspace := detail_panel.get_parent().get_node_or_null(
		"GovernanceWorkspace"
	) as Control
	if governance_workspace != null:
		controls.append(governance_workspace)
	return controls


func _on_building_removed(placement_id: int) -> void:
	if placement_id == _hovered_placement_id:
		_hovered_placement_id = -1
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
