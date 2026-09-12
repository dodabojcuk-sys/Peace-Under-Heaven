extends Control


const SURFACE := Color("0b141b")
const SURFACE_RAISED := Color("10222b")
const BORDER := Color("3a6972")
const TEXT := Color("e5f0ed")
const MUTED_TEXT := Color("9fb4b3")
const ACCENT := Color("76d2c7")
const WARNING := Color("f3c56b")
const DANGER := Color("df8d7f")

@onready var construction_controller: Node = $"../../ConstructionController"
@onready var top_status_bar: Panel = $TopStatusBar
@onready var resource_summary: Label = $TopStatusBar/ResourceSummary
@onready var current_city: Label = $TopStatusBar/CurrentCity
@onready var time_summary: Label = $TopStatusBar/TimeSummary
@onready var daily_report: Label = $TopStatusBar/DailyReport
@onready var next_stage_summary: Label = $TopStatusBar/NextStageSummary
@onready var alert_summary: Label = $TopStatusBar/AlertSummary
@onready var current_mainline_button: Button = $TopStatusBar/CurrentMainlineButton
@onready var time_speed_option: OptionButton = $TopStatusBar/TimeSpeedOption
@onready var pause_button: Button = $TopStatusBar/PauseButton
@onready var city_bar: Panel = $CityBar
@onready var city_bar_toggle: Button = $CityBarToggle
@onready var city_title: Label = $CityBar/Title
@onready var city_current: Label = $CityBar/CurrentCitySelection/Label
@onready var city_two: Label = $CityBar/City02
@onready var city_three: Label = $CityBar/City03
@onready var army_status: Label = $CityBar/ArmyStatus
@onready var minimap: Panel = $MinimapPlaceholder
@onready var minimap_label: Label = $MinimapPlaceholder/Label
@onready var construction_entry: Panel = $ConstructionEntryPanel
@onready var build_entry_button: Button = $ConstructionEntryPanel/BuildEntryButton
@onready var build_mode_status: Label = $ConstructionEntryPanel/BuildModeStatus
@onready var build_slot_content: VBoxContainer = (
	$ConstructionEntryPanel/BuildSlotContent
)
@onready var placement_orientation: Label = $ConstructionEntryPanel/PlacementOrientation
@onready var rotate_button: Button = $ConstructionEntryPanel/RotateButton
@onready var confirm_road_button: Button = $ConstructionEntryPanel/ConfirmRoadButton
@onready var cancel_placement_button: Button = $ConstructionEntryPanel/CancelPlacementButton
@onready var construction_menu: Panel = $ConstructionMenu
@onready var detail_panel: Panel = $BuildingDetailPanel
@onready var noticeboard_panel: Panel = $NoticeboardPanel

var _layout_refresh_pending := false
var governance_workspace: PanelContainer
var governance_title: Label
var governance_summary: Label
var governance_issue_detail: Label
var governance_catalog_button: Button
var governance_wood_button: Button
var governance_food_button: Button
var governance_population_summary: Label
var governance_production_minus: Button
var governance_production_plus: Button
var governance_construction_minus: Button
var governance_construction_plus: Button
var governance_medical_minus: Button
var governance_medical_plus: Button
var governance_order_minus: Button
var governance_order_plus: Button
var governance_treatment_button: Button
var governance_event_button: Button
var governance_refugee_actions: VBoxContainer
var _governance_workspace_was_visible := false
var strategy_workspace: PanelContainer
var strategy_content: VBoxContainer
var strategy_feedback: Label
var _strategy_workspace_open := false


func _ready() -> void:
	_apply_visual_tokens()
	_apply_static_copy()
	_install_governance_workspace()
	_install_strategy_workspace()
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)
	construction_controller.city_state_changed.connect(_refresh_read_model)
	construction_controller.construction_presentation_changed.connect(
		_layout_for_viewport
	)
	_refresh_read_model()
	call_deferred("_restore_product_overview")


func _restore_product_overview() -> void:
	# City switching remains a functional context control; unavailable destinations
	# stay inside that panel instead of becoming separate top-level navigation.
	city_bar.visible = false
	city_bar_toggle.visible = true


func _apply_visual_tokens() -> void:
	for panel in [
		top_status_bar,
		city_bar,
		minimap,
		construction_entry,
		construction_menu,
		detail_panel,
		noticeboard_panel,
	]:
		panel.add_theme_stylebox_override("panel", _panel_style())

	for button in find_children("*", "Button", true, false):
		_apply_button_tokens(button as Button)
	for label in find_children("*", "Label", true, false):
		(label as Label).add_theme_color_override("font_color", TEXT)

	for separator in [
		$TopStatusBar/DividerOne,
		$TopStatusBar/DividerTwo,
		$TopStatusBar/DividerThree,
		$TopStatusBar/DividerFour,
		$BuildingDetailPanel/Divider,
	]:
		(separator as ColorRect).color = BORDER


func _apply_static_copy() -> void:
	city_bar.visible = false
	city_bar_toggle.visible = true
	city_title.text = "城市序列"
	city_current.text = "黑石城\n经营中"
	city_two.text = "河湾城\n有机花园城 · 可进入"
	city_three.text = "下一城市\n未解锁"
	minimap_label.text = "部署概览 · 黑石城"
	build_entry_button.text = "城市经营"
	build_mode_status.text = "已选蓝图\n地图左键建造 · R 旋转 · 右键/Esc 取消"
	$ConstructionMenu/Title.text = "空间设施与道路"
	$BuildingDetailPanel/PanelTitle.text = "建筑档案"
	$BuildingDetailPanel/UpgradeStatusCard.text = (
		"升级状态\n当前权威未提供升级写入命令\n不会伪造等级或扣除资源"
	)
	$BuildingDetailPanel/UpgradeButton.text = "查看升级门禁"
	$BuildingDetailPanel/UpgradeConfirmation/ConfirmationText.text = (
		"无可执行升级\n\n当前唯一城市权威尚未提供建筑升级 command。\n保持当前等级，避免伪造资源或存档写入。"
	)
	$BuildingDetailPanel/UpgradeConfirmation/ConfirmUpgradeButton.text = "保持当前等级"
	$BuildingDetailPanel/UpgradeConfirmation/CancelUpgradeButton.text = "返回详情"


func _refresh_read_model() -> void:
	if not is_instance_valid(construction_controller):
		return
	var nation: Variant = construction_controller.get_nation_state()
	if nation == null:
		return
	var wood: int = int(nation.get_resource(&"wood"))
	var food: int = int(nation.get_resource(&"food"))
	resource_summary.text = "国家共享资源  木材 %d/%d · 粮食 %d/%d" % [
		wood,
		construction_controller.get_resource_capacity(&"wood"),
		food,
		construction_controller.get_resource_capacity(&"food"),
	]
	var city_name := "黑石城"
	var profile_name := "规则帝城"
	if construction_controller.has_method("get_active_city_name"):
		city_name = construction_controller.get_active_city_name()
	if construction_controller.has_method("get_layout_profile_name"):
		profile_name = construction_controller.get_layout_profile_name()
	current_city.text = "%s  ·  %s" % [city_name, profile_name]
	minimap_label.text = "部署概览 · %s" % city_name
	var mainline: Dictionary = construction_controller.get_mainline_pressure_state()
	next_stage_summary.text = "下一阶段：%s·%d日" % [
		str(mainline.next_stage_name),
		int(mainline.next_stage_days),
	]
	if construction_controller.is_campaign_pressure_cleared():
		next_stage_summary.text = "战役目标达成 · 经营继续"
	var garrison: Dictionary = construction_controller.get_garrison_snapshot()
	var queue: Dictionary = construction_controller.get_training_queue_snapshot()
	var population: Dictionary = construction_controller.get_population_recovery_read_model()
	army_status.text = "人口 %d · 可用 %d · 伤员 %d\n驻军 %d · 可派 %d/%d\n外派 %d · 训练 %d" % [
		int(population.get("total_living", 0)),
		int(population.get("available", 0)),
		int(population.get("wounded", 0)),
		int(garrison.get("total_count", 0)),
		int(garrison.get("dispatchable_count", 0)),
		int(garrison.get("effective_command_limit", 0)),
		maxi(int(population.get("military", 0)) - int(garrison.get("total_count", 0)), 0),
		int(queue.get("queued_count", 0)),
	]
	_refresh_governance_workspace(wood, food)
	_refresh_strategy_workspace()
	for label in [time_summary, daily_report, alert_summary]:
		label.add_theme_color_override("font_color", MUTED_TEXT)
	_schedule_layout_refresh()


func _schedule_layout_refresh() -> void:
	if _layout_refresh_pending:
		return
	_layout_refresh_pending = true
	call_deferred("_refresh_layout_after_state_change")


func _refresh_layout_after_state_change() -> void:
	_layout_refresh_pending = false
	_layout_for_viewport()


func _layout_for_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var width := viewport_size.x
	var height := viewport_size.y
	var edge := clampf(width * 0.015, 16.0, 32.0)
	# M1A keeps the current-mainline action inside the existing alert region.
	# Its dedicated action row protects the status copy without creating a sixth
	# floating top-bar region or reducing type at narrower viewports.
	var top_height := clampf(height * 0.11, 96.0, 104.0)
	var left_width := clampf(width * 0.17, 205.0, 250.0)
	var right_width := clampf(width * 0.23, 278.0, 340.0)
	var rail_top := top_height + edge

	top_status_bar.position = Vector2.ZERO
	top_status_bar.size = Vector2(width, top_height)
	_layout_top_status_regions(width, top_height, edge)

	city_bar.position = Vector2(edge, rail_top)
	city_bar.size = Vector2(left_width, maxf(360.0, height - rail_top - edge))
	city_bar_toggle.position = Vector2(edge + left_width - 72.0, rail_top + 10.0)
	city_bar_toggle.size = Vector2(58.0, 28.0)
	$CityBar/Title.position = Vector2(16.0, 18.0)
	$CityBar/CurrentCitySelection.position = Vector2(16.0, 52.0)
	$CityBar/CurrentCitySelection.size = Vector2(left_width - 32.0, 58.0)
	$CityBar/CurrentCitySelection/Label.position = Vector2(14.0, 11.0)
	$CityBar/CurrentCitySelection/Label.size = Vector2(left_width - 60.0, 42.0)
	city_two.position = Vector2(18.0, 128.0)
	city_two.size = Vector2(left_width - 36.0, 38.0)
	city_three.position = Vector2(18.0, 176.0)
	city_three.size = Vector2(left_width - 36.0, 38.0)
	army_status.position = Vector2(16.0, 237.0)
	army_status.size = Vector2(left_width - 32.0, 58.0)
	$CityBar/RecruitButton.position = Vector2(16.0, 305.0)
	$CityBar/RecruitButton.size = Vector2(left_width - 32.0, 34.0)
	$CityBar/GeneralOption.position = Vector2(16.0, 347.0)
	$CityBar/GeneralOption.size = Vector2(left_width - 32.0, 32.0)
	$CityBar/TechOption.position = Vector2(16.0, 387.0)
	$CityBar/TechOption.size = Vector2(left_width - 86.0, 32.0)
	$CityBar/ResearchButton.position = Vector2(left_width - 62.0, 387.0)
	$CityBar/ResearchButton.size = Vector2(46.0, 32.0)
	$CityBar/ThreatDetail.position = Vector2(16.0, 430.0)
	$CityBar/ThreatDetail.size = Vector2(left_width - 32.0, 94.0)

	minimap.position = Vector2(width - right_width - edge, rail_top)
	minimap.size = Vector2(right_width, 128.0)
	minimap_label.position = Vector2(14.0, 8.0)
	minimap_label.size = Vector2(right_width - 28.0, 20.0)
	$MinimapPlaceholder/ViewportFrame.visible = false

	var is_placing: bool = bool(construction_controller.is_placing())
	var has_build_slot := (
		construction_controller.has_method("has_build_project")
		and bool(construction_controller.has_build_project())
	)
	construction_entry.position = Vector2(width - right_width - edge, rail_top + 140.0)
	var build_slot_panel_height := 300.0
	if has_build_slot and not is_placing:
		# The BuildSlotContent VBox owns row sizing. Its 194px minimum plus the
		# status header and panel padding prevent restored children escaping the panel.
		build_slot_panel_height = 106.0 + maxf(
			194.0,
			build_slot_content.get_combined_minimum_size().y
		)
	construction_entry.size = Vector2(
		right_width,
		build_slot_panel_height if has_build_slot and not is_placing else (206.0 if is_placing else 66.0)
	)
	build_entry_button.position = Vector2(12.0, 12.0)
	build_entry_button.size = Vector2(right_width - 24.0, 42.0)
	build_mode_status.position = Vector2(14.0, 12.0)
	build_mode_status.size = Vector2(right_width - 28.0, 72.0)
	placement_orientation.position = Vector2(14.0, 82.0)
	placement_orientation.size = Vector2(right_width - 28.0, 22.0)
	rotate_button.position = Vector2(14.0, 112.0)
	rotate_button.size = Vector2((right_width - 42.0) * 0.5, 34.0)
	confirm_road_button.position = Vector2(22.0 + (right_width - 42.0) * 0.5, 112.0)
	confirm_road_button.size = Vector2((right_width - 42.0) * 0.5, 34.0)
	cancel_placement_button.position = Vector2(14.0, 154.0)
	cancel_placement_button.size = Vector2(right_width - 28.0, 34.0)

	construction_menu.position = Vector2(width - right_width - edge, rail_top + 218.0)
	construction_menu.size = Vector2(right_width, minf(390.0, height - rail_top - 230.0))
	_layout_catalog(right_width)

	# Keep an 8 px gap below the minimap while preserving the established
	# 390 px readable detail surface at the 1152x648 acceptance viewport.
	detail_panel.position = Vector2(width - right_width - edge, rail_top + 136.0)
	detail_panel.size = Vector2(right_width, minf(610.0, height - rail_top - 144.0))
	_layout_detail(right_width)
	_layout_governance_workspace(width, height, right_width, edge, rail_top)
	_layout_strategy_workspace(width, height, right_width, edge, rail_top)
	_refresh_governance_workspace()



func _install_governance_workspace() -> void:
	# This workspace is presentation-only. It gives the existing construction
	# controller a clear default entry without creating a city-management state.
	governance_workspace = PanelContainer.new()
	governance_workspace.name = "GovernanceWorkspace"
	governance_workspace.mouse_filter = Control.MOUSE_FILTER_STOP
	governance_workspace.add_theme_stylebox_override("panel", _panel_style())
	add_child(governance_workspace)

	var margin := MarginContainer.new()
	margin.name = "GovernanceMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	governance_workspace.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "GovernanceScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "GovernanceContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	scroll.add_child(content)

	governance_title = Label.new()
	governance_title.name = "Title"
	governance_title.text = "城市经营"
	governance_title.add_theme_color_override("font_color", TEXT)
	content.add_child(governance_title)

	governance_summary = Label.new()
	governance_summary.name = "HealthyResourceSummary"
	governance_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	governance_summary.add_theme_color_override("font_color", MUTED_TEXT)
	content.add_child(governance_summary)

	governance_issue_detail = Label.new()
	governance_issue_detail.name = "IssueDetail"
	governance_issue_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	governance_issue_detail.add_theme_color_override("font_color", WARNING)
	governance_issue_detail.visible = false
	content.add_child(governance_issue_detail)

	governance_catalog_button = _make_governance_button("查看设施与道路")
	governance_catalog_button.name = "GovernanceCatalogButton"
	governance_catalog_button.pressed.connect(construction_controller.open_construction_menu)
	content.add_child(governance_catalog_button)

	governance_wood_button = _make_governance_button("补充木材 · 伐木场")
	governance_wood_button.name = "GovernanceWoodButton"
	governance_wood_button.pressed.connect(_start_governance_definition.bind(&"logging_camp"))

	governance_food_button = _make_governance_button("稳定粮食 · 农田")
	governance_food_button.name = "GovernanceFoodButton"
	governance_food_button.pressed.connect(_start_governance_definition.bind(&"farm"))
	var production_shortcuts := HBoxContainer.new()
	production_shortcuts.name = "ProductionShortcuts"
	production_shortcuts.add_theme_constant_override("separation", 6)
	production_shortcuts.add_child(governance_wood_button)
	production_shortcuts.add_child(governance_food_button)
	content.add_child(production_shortcuts)

	governance_population_summary = Label.new()
	governance_population_summary.name = "PopulationRecoverySummary"
	governance_population_summary.mouse_filter = Control.MOUSE_FILTER_STOP
	governance_population_summary.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	governance_population_summary.tooltip_text = "点击查看伤员治疗入口；查看不会扣粮或调动人员。"
	governance_population_summary.gui_input.connect(_on_population_summary_input)
	governance_population_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	governance_population_summary.add_theme_color_override("font_color", MUTED_TEXT)
	content.add_child(governance_population_summary)

	var production_row := HBoxContainer.new()
	production_row.add_child(_make_row_label("生产岗位"))
	governance_production_minus = _make_small_action("−")
	governance_production_minus.name = "ProductionWorkerMinus"
	governance_production_minus.pressed.connect(_adjust_workforce.bind(&"production", -1))
	production_row.add_child(governance_production_minus)
	governance_production_plus = _make_small_action("+")
	governance_production_plus.name = "ProductionWorkerPlus"
	governance_production_plus.pressed.connect(_adjust_workforce.bind(&"production", 1))
	production_row.add_child(governance_production_plus)
	production_row.add_child(_make_row_label("施工"))
	governance_construction_minus = _make_small_action("−")
	governance_construction_minus.name = "ConstructionWorkerMinus"
	governance_construction_minus.pressed.connect(_adjust_workforce.bind(&"construction", -1))
	production_row.add_child(governance_construction_minus)
	governance_construction_plus = _make_small_action("+")
	governance_construction_plus.name = "ConstructionWorkerPlus"
	governance_construction_plus.pressed.connect(_adjust_workforce.bind(&"construction", 1))
	production_row.add_child(governance_construction_plus)
	content.add_child(production_row)

	var care_row := HBoxContainer.new()
	care_row.add_child(_make_row_label("医疗岗位"))
	governance_medical_minus = _make_small_action("−")
	governance_medical_minus.name = "MedicalWorkerMinus"
	governance_medical_minus.pressed.connect(_adjust_workforce.bind(&"medical", -1))
	care_row.add_child(governance_medical_minus)
	governance_medical_plus = _make_small_action("+")
	governance_medical_plus.name = "MedicalWorkerPlus"
	governance_medical_plus.pressed.connect(_adjust_workforce.bind(&"medical", 1))
	care_row.add_child(governance_medical_plus)
	care_row.add_child(_make_row_label("治理"))
	governance_order_minus = _make_small_action("−")
	governance_order_minus.name = "GovernanceWorkerMinus"
	governance_order_minus.pressed.connect(_adjust_workforce.bind(&"governance", -1))
	care_row.add_child(governance_order_minus)
	governance_order_plus = _make_small_action("+")
	governance_order_plus.name = "GovernanceWorkerPlus"
	governance_order_plus.pressed.connect(_adjust_workforce.bind(&"governance", 1))
	care_row.add_child(governance_order_plus)
	content.add_child(care_row)

	var wellbeing_buildings := HBoxContainer.new()
	wellbeing_buildings.name = "WellbeingBuildingShortcuts"
	var housing_button := _make_governance_button("建设民居")
	housing_button.name = "GovernanceHousingButton"
	housing_button.pressed.connect(_start_governance_definition.bind(&"building.housing.t1"))
	wellbeing_buildings.add_child(housing_button)
	var clinic_button := _make_governance_button("建设医舍")
	clinic_button.name = "GovernanceClinicButton"
	clinic_button.pressed.connect(_start_governance_definition.bind(&"building.clinic.t1"))
	wellbeing_buildings.add_child(clinic_button)
	content.add_child(wellbeing_buildings)

	governance_refugee_actions = VBoxContainer.new()
	governance_refugee_actions.name = "RefugeeActions"
	governance_refugee_actions.add_theme_constant_override("separation", 4)
	content.add_child(governance_refugee_actions)

	governance_treatment_button = _make_governance_button("治疗伤员")
	governance_treatment_button.name = "WoundedTreatmentButton"
	governance_treatment_button.pressed.connect(_begin_wounded_treatment)
	content.add_child(governance_treatment_button)
	governance_event_button = _make_governance_button("安排治安处置")
	governance_event_button.name = "GovernanceEventButton"
	governance_event_button.pressed.connect(_resolve_governance_event)
	content.add_child(governance_event_button)
	var strategy_button := _make_governance_button("战略支持 · 文官 / 装备 / 贸易")
	strategy_button.name = "CityStrategyEntryButton"
	strategy_button.pressed.connect(_open_strategy_workspace)
	content.add_child(strategy_button)


func _install_strategy_workspace() -> void:
	strategy_workspace = PanelContainer.new()
	strategy_workspace.name = "CityStrategyWorkspace"
	strategy_workspace.mouse_filter = Control.MOUSE_FILTER_STOP
	strategy_workspace.add_theme_stylebox_override("panel", _panel_style())
	strategy_workspace.visible = false
	add_child(strategy_workspace)
	var margin := MarginContainer.new()
	margin.name = "StrategyMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	strategy_workspace.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "StrategyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	strategy_content = VBoxContainer.new()
	strategy_content.name = "StrategyContent"
	strategy_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strategy_content.add_theme_constant_override("separation", 5)
	scroll.add_child(strategy_content)


func _open_strategy_workspace() -> void:
	_strategy_workspace_open = true
	_refresh_strategy_workspace()
	_refresh_governance_workspace()


func _close_strategy_workspace() -> void:
	_strategy_workspace_open = false
	_refresh_strategy_workspace()
	_refresh_governance_workspace()


func _strategy_action(method: StringName, argument: StringName = &"") -> void:
	var result: Dictionary = construction_controller.call(method, argument) if argument != &"" else construction_controller.call(method)
	var success_copy: String = str({
		&"appoint_city_official": "文官任命已更新",
		&"activate_city_official_support": "文官支援已启用",
		&"craft_city_equipment": "装备制造完成，尚未自动装配",
		&"equip_city_troops": "制式装备已装配",
		&"unequip_city_troops": "制式装备已卸下",
		&"equip_city_general": "将领装备已装配",
		&"unequip_city_general": "将领装备已卸下",
		&"train_city_equipment": "装备培养完成",
		&"rank_up_city_equipment": "装备升阶完成",
		&"execute_city_trade": "交易完成并已生成回执",
	}.get(method, "操作完成"))
	strategy_feedback.text = success_copy if bool(result.get("success", false)) else str(result.get("error", "操作失败"))
	_refresh_strategy_workspace.call_deferred(false)


func _strategy_inherit_action(target_id: StringName, source_id: StringName) -> void:
	var result: Dictionary = construction_controller.inherit_city_equipment_experience(target_id, source_id)
	strategy_feedback.text = "经验继承完成，来源装备已消耗" if bool(result.get("success", false)) else str(result.get("error", "继承失败"))
	_refresh_strategy_workspace.call_deferred(false)


func _refresh_strategy_workspace(clear_feedback := false) -> void:
	if not is_instance_valid(strategy_workspace):
		return
	strategy_workspace.visible = _strategy_workspace_open
	if not _strategy_workspace_open:
		return
	var preserved_feedback := "" if clear_feedback or not is_instance_valid(strategy_feedback) else strategy_feedback.text
	for child in strategy_content.get_children():
		strategy_content.remove_child(child)
		child.queue_free()
	var title_row := HBoxContainer.new()
	var title := _make_row_label("战略支持")
	title.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title)
	var close := _make_small_action("返回")
	close.name = "CityStrategyCloseButton"
	close.pressed.connect(_close_strategy_workspace)
	title_row.add_child(close)
	strategy_content.add_child(title_row)
	strategy_feedback = Label.new()
	strategy_feedback.name = "CityStrategyFeedback"
	strategy_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strategy_feedback.add_theme_color_override("font_color", WARNING)
	strategy_feedback.text = preserved_feedback
	strategy_content.add_child(strategy_feedback)
	var model: Dictionary = construction_controller.get_city_strategy_read_model()
	var active: Dictionary = Dictionary(model.get("active_support", {}))
	var support_copy := "无支援生效"
	if StringName(active.get("phase", &"")) == &"ACTIVE" and bool(model.get("active_support_effective", false)):
		var support_names := {&"PRODUCTION": "生产", &"MEDICAL": "医疗", &"DEFENSE": "防御"}
		support_copy = "%s支援生效中 · 剩余 %d 日（第 %d 日边界结束）" % [str(support_names.get(StringName(active.get("support_type", &"")), "城市")), maxi(int(active.get("expires_day", 0)) - construction_controller.current_day, 0), int(active.get("expires_day", 0))]
	elif StringName(active.get("phase", &"")) == &"ACTIVE":
		support_copy = "支援已到期 · 等待保存重试"
	var overview := _make_row_label("关卡能量 %d/3 · %s" % [int(model.get("campaign_energy", 0)), support_copy])
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strategy_content.add_child(overview)
	strategy_content.add_child(_strategy_section_label("文官任命与支援"))
	var official_names: Dictionary = Dictionary(model.get("official_names", {}))
	var support_descriptions: Dictionary = Dictionary(model.get("support_descriptions", {}))
	for official_id_value in Array(model.get("unlocked_official_ids", [])):
		var official_id := StringName(official_id_value)
		var appointed := official_id == StringName(model.get("appointed_official_id", &""))
		var button := _make_governance_button(("已任命 · " if appointed else "任命 · ") + str(official_names.get(official_id, official_id)))
		button.name = "Official_%s" % String(official_id).replace(".", "_")
		button.disabled = appointed
		button.pressed.connect(_strategy_action.bind(&"appoint_city_official", official_id))
		strategy_content.add_child(button)
		var description := _make_row_label("  %s" % str(support_descriptions.get(official_id, "")))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		strategy_content.add_child(description)
	var support_button := _make_governance_button("启用当前文官支援 · 消耗 1 能量")
	support_button.name = "ActivateOfficialSupportButton"
	support_button.disabled = int(model.get("campaign_energy", 0)) <= 0 or StringName(active.get("phase", &"")) == &"ACTIVE"
	support_button.pressed.connect(_strategy_action.bind(&"activate_city_official_support", &""))
	strategy_content.add_child(support_button)
	strategy_content.add_child(_strategy_section_label("编队制式装备 · 制造与装配分开"))
	var equipment_names: Dictionary = Dictionary(model.get("equipment_names", {}))
	var equipment_costs: Dictionary = Dictionary(model.get("equipment_costs", {}))
	var owned: Array = Array(model.get("owned_equipment_ids", []))
	var slots: Dictionary = Dictionary(model.get("troop_equipment_by_slot", {}))
	var general_loadouts: Dictionary = Dictionary(model.get("general_equipment_by_general_id", {}))
	var growth_models: Dictionary = Dictionary(model.get("equipment_growth_models", {}))
	var rank_costs: Dictionary = Dictionary(model.get("equipment_rank_costs", {}))
	var quality_names: Dictionary = Dictionary(model.get("quality_names", {}))
	var slot_names: Dictionary = Dictionary(model.get("general_slot_names", {}))
	var selected_general_id := StringName(model.get("selected_general_id", &""))
	var general_section_added := false
	for equipment_id_value in CityStrategyState.EQUIPMENT_IDS:
		var equipment_id := StringName(equipment_id_value)
		var owned_item := equipment_id in owned
		var is_general_item := equipment_id in CityStrategyState.GENERAL_EQUIPMENT_IDS
		if is_general_item and not general_section_added:
			strategy_content.add_child(_strategy_section_label("将领装备 · %s · 六槽" % str(model.get("selected_general_name", "未选择将领"))))
			var loadout: Dictionary = Dictionary(general_loadouts.get(selected_general_id, CityStrategyState.empty_general_loadout()))
			for slot in CityStrategyState.GENERAL_SLOTS:
				var equipped_name := str(equipment_names.get(StringName(loadout.get(slot, &"")), "空"))
				strategy_content.add_child(_make_row_label("%s：%s" % [str(slot_names.get(slot, slot)), equipped_name]))
			general_section_added = true
		var equipped := equipment_id in slots.values() or equipment_id in Dictionary(general_loadouts.get(selected_general_id, {})).values()
		var copy := ("卸下 · " if equipped else ("装配 · " if owned_item else "制造 · ")) + str(equipment_names.get(equipment_id, equipment_id))
		if not owned_item:
			copy += " · 木材 %d · 制造后需另行装配" % int(Dictionary(equipment_costs.get(equipment_id, {})).get(&"wood", 0))
		var equipment_button := _make_governance_button(copy)
		equipment_button.name = "Equipment_%s" % String(equipment_id).replace(".", "_")
		var method := &"craft_city_equipment"
		if equipped:
			method = &"unequip_city_general" if is_general_item else &"unequip_city_troops"
		elif owned_item:
			method = &"equip_city_general" if is_general_item else &"equip_city_troops"
		equipment_button.disabled = is_general_item and owned_item and selected_general_id == &""
		equipment_button.pressed.connect(_strategy_action.bind(method, equipment_id))
		strategy_content.add_child(equipment_button)
		if is_general_item and owned_item:
			var growth: Dictionary = Dictionary(growth_models.get(equipment_id, {}))
			var growth_copy := "%s · Lv.%d/%d · 累计经验 %d · 当前加成 %s" % [
				str(quality_names.get(StringName(growth.get("quality_id", &"COMMON")), "常备")), int(growth.get("level", 1)), int(growth.get("level_cap", 3)), int(growth.get("experience", 0)), str(float(int(growth.get("effect_permille", 0))) / 10.0) + "%",
			]
			strategy_content.add_child(_make_row_label(growth_copy))
			var train := _make_governance_button("培养 · 木材 4 → 经验 +100")
			train.name = "Train_%s" % String(equipment_id).replace(".", "_")
			train.pressed.connect(_strategy_action.bind(&"train_city_equipment", equipment_id))
			strategy_content.add_child(train)
			var rank_cost: Dictionary = Dictionary(rank_costs.get(StringName(growth.get("quality_id", &"COMMON")), {}))
			var rank := _make_governance_button("升阶 · 木材 %d · 保留累计经验" % int(rank_cost.get(&"wood", 0)))
			rank.name = "Rank_%s" % String(equipment_id).replace(".", "_")
			rank.disabled = not bool(growth.get("can_rank_up", false))
			rank.pressed.connect(_strategy_action.bind(&"rank_up_city_equipment", equipment_id))
			strategy_content.add_child(rank)
	if &"equipment.general.bronze_sword" in owned and &"equipment.general.iron_sword" in owned:
		var bronze_growth: Dictionary = Dictionary(growth_models.get(&"equipment.general.bronze_sword", {}))
		var inherit := _make_governance_button("继承预览 · 青铜佩剑 → 精铁长剑 · 来源将消失")
		inherit.name = "InheritBronzeSwordToIronSword"
		inherit.disabled = bool(bronze_growth.get("assigned", false))
		inherit.tooltip_text = "已装配的来源装备必须先卸下" if inherit.disabled else "目标获得来源累计经验与基础经验；超出当前等级上限的经验会保留"
		inherit.pressed.connect(_strategy_inherit_action.bind(&"equipment.general.iron_sword", &"equipment.general.bronze_sword"))
		strategy_content.add_child(inherit)
	strategy_content.add_child(_strategy_section_label("当日贸易 · 预览后一次成交"))
	var offers: Dictionary = Dictionary(model.get("trade_offers", {}))
	for offer_id_value in offers.keys():
		var offer_id := StringName(offer_id_value)
		var offer: Dictionary = offers[offer_id]
		var resource_names := {&"wood": "木材", &"food": "粮食"}
		var trade_button := _make_governance_button("%d %s → %d %s · 成交后 %d/%d · %s" % [int(offer.spend), str(resource_names.get(StringName(offer.spend_id), offer.spend_id)), int(offer.gain), str(resource_names.get(StringName(offer.gain_id), offer.gain_id)), int(offer.get("gain_available", 0)) + int(offer.gain), int(offer.get("gain_capacity", 0)), "今日可交易" if bool(offer.get("can_execute", false)) else str(offer.get("blocked_reason", "不可交易"))])
		trade_button.name = "Trade_%s" % String(offer_id).replace(".", "_")
		trade_button.disabled = not bool(offer.get("can_execute", false))
		trade_button.tooltip_text = str(offer.get("blocked_reason", ""))
		trade_button.pressed.connect(_strategy_action.bind(&"execute_city_trade", offer_id))
		strategy_content.add_child(trade_button)


func _strategy_section_label(copy: String) -> Label:
	var label := _make_row_label(copy)
	label.add_theme_color_override("font_color", ACCENT)
	return label


func _make_governance_button(copy: String) -> Button:
	var button := Button.new()
	button.text = copy
	button.custom_minimum_size = Vector2(0.0, 28.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_tokens(button)
	return button


func _make_row_label(copy: String) -> Label:
	var label := Label.new()
	label.text = copy
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TEXT)
	return label


func _make_small_action(copy: String) -> Button:
	var button := _make_governance_button(copy)
	button.custom_minimum_size = Vector2(38.0, 26.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return button


func _show_governance_action_result(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		governance_issue_detail.text = str(result.get("error", "本次操作未完成，请检查当前人员、资源和保存状态"))
		governance_issue_detail.visible = true


func _adjust_workforce(channel: StringName, delta: int) -> void:
	_show_governance_action_result(construction_controller.adjust_city_workforce(channel, delta))


func _on_population_summary_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var scroll := governance_treatment_button.get_parent().get_parent() as ScrollContainer
		if scroll != null:
			scroll.ensure_control_visible(governance_treatment_button)
			governance_treatment_button.grab_focus()
		governance_population_summary.accept_event()


func _begin_wounded_treatment() -> void:
	_show_governance_action_result(construction_controller.begin_wounded_treatment())


func _resolve_governance_event() -> void:
	_show_governance_action_result(construction_controller.resolve_city_governance_event())


func _decide_refugee(case_id: StringName, decision: StringName) -> void:
	_show_governance_action_result(construction_controller.decide_refugee_case(case_id, decision))


func _settle_refugee(case_id: StringName) -> void:
	_show_governance_action_result(construction_controller.settle_refugee_case(case_id))


func _start_governance_definition(definition_id: StringName) -> void:
	construction_controller.begin_placing_definition(
		definition_id,
		get_viewport().get_mouse_position()
	)


func _layout_governance_workspace(
	width: float,
	height: float,
	right_width: float,
	edge: float,
	rail_top: float
) -> void:
	if not is_instance_valid(governance_workspace):
		return
	var governance_width := minf(maxf(right_width, 390.0), width - edge * 2.0)
	governance_workspace.position = Vector2(width - governance_width - edge, rail_top + 140.0)
	governance_workspace.size = Vector2(
		governance_width,
		minf(430.0, height - rail_top - 154.0)
	)


func _layout_strategy_workspace(
	width: float,
	height: float,
	right_width: float,
	edge: float,
	rail_top: float
) -> void:
	if not is_instance_valid(strategy_workspace):
		return
	var strategy_width := minf(maxf(right_width, 430.0), width - edge * 2.0)
	strategy_workspace.position = Vector2(width - strategy_width - edge, rail_top + 112.0)
	strategy_workspace.size = Vector2(strategy_width, minf(520.0, height - rail_top - 126.0))


func _refresh_governance_workspace(
	wood_override := -1,
	food_override := -1
) -> void:
	if not is_instance_valid(governance_workspace):
		return
	var nation: Variant = construction_controller.get_nation_state()
	if nation == null:
		return
	var wood: int = wood_override if wood_override >= 0 else int(nation.get_resource(&"wood"))
	var food: int = food_override if food_override >= 0 else int(nation.get_resource(&"food"))
	var wood_capacity: int = construction_controller.get_resource_capacity(&"wood")
	var food_capacity: int = construction_controller.get_resource_capacity(&"food")
	var issues: Array[String] = []
	if wood < 40:
		issues.append("木材偏低：优先补充伐木场或调整道路计划")
	if food < 40:
		issues.append("粮食偏低：优先补充农田")
	if construction_controller.get_construction_in_progress_count() > 0:
		issues.append("有建筑正在施工；资源摘要已保留")
	governance_summary.text = "资源摘要 · 木材 %d/%d · 粮食 %d/%d" % [
		wood,
		wood_capacity,
		food,
		food_capacity,
	]
	var forecast: Dictionary = construction_controller.get_city_food_forecast()
	governance_summary.text += "\n当前日产 %d · 日需 %d · 净额 %+d" % [int(forecast.income), int(forecast.upkeep), int(forecast.net)]
	governance_summary.tooltip_text = "按当前已完工、连路、在岗建筑估算；日界先付口粮再入库，贸易、军令和事件另计。可建设农田、调岗或贸易处理缺口。"
	var population: Dictionary = construction_controller.get_population_recovery_read_model()
	var governance: Dictionary = construction_controller.get_city_governance_read_model()
	var treatment: Dictionary = Dictionary(population.get("treatment", {}))
	var treatment_active := StringName(treatment.get("phase", &"")) == &"ACTIVE"
	governance_population_summary.text = (
		"劳动力 %d · 住房余 %d · 粮食日需 %d · 压力 %d · 待安置 %d\n儿童 %d · 成年 %d · 老年 %d｜岗位 产%d / 施%d / 医%d / 治%d\n军事 %d · 伤%d · 病%d · 难民医疗%d · 死亡%d%s｜%s季 %d%% · 住房%d/%d · 治安%d%s"
		% [
			int(population.get("available", 0)),
			int(governance.get("housing_surplus", 0)),
			int(governance.get("food_required", 0)),
			int(governance.get("pressure_points", 0)),
			int(population.get("unsettled_refugees", 0)),
			int(population.get("children", 0)),
			int(population.get("adults", 0)),
			int(population.get("elderly", 0)),
			int(population.get("production_workers", 0)),
			int(population.get("construction_workers", 0)),
			int(population.get("medical_workers", 0)),
			int(population.get("governance_workers", 0)),
			int(population.get("military", 0)),
			int(population.get("wounded", 0)),
			int(governance.get("diseased_count", 0)),
			int(governance.get("refugee_medical_burden", 0)),
			int(population.get("fallen", 0)),
			" · 治疗中 %d/%d" % [int(treatment.get("progress_milliseconds", 0)), int(treatment.get("required_milliseconds", 0))] if treatment_active else "",
			str(governance.get("season_name", "")),
			floori(float(int(governance.get("health_permille", 0))) / 10.0),
			int(population.get("total_living", 0)),
			int(governance.get("housing_capacity", 0)),
			int(governance.get("security", 0)),
			" · 增长受阻：%s" % str(governance.get("growth_blocker", "")) if not str(governance.get("growth_blocker", "")).is_empty() else " · 增长条件满足",
		]
	)
	for child in governance_refugee_actions.get_children():
		child.queue_free()
	var refugee_cases: Dictionary = Dictionary(governance.get("refugee_cases_by_id", {}))
	var refugee_ids := refugee_cases.keys()
	refugee_ids.sort()
	for case_id_value in refugee_ids:
		var case_id := StringName(case_id_value)
		var refugee_case: Dictionary = Dictionary(refugee_cases[case_id])
		var phase := StringName(refugee_case.phase)
		if phase not in [&"PENDING", &"DEFERRED", &"WAITING_HOUSING"]:
			continue
		var preview := _make_row_label("%s · %d 人 · 医疗负担 %d · %s" % [str(refugee_case.display_name), int(refugee_case.count), int(refugee_case.medical_burden), "待决定" if phase in [&"PENDING", &"DEFERRED"] else "已接纳，等待住房"])
		preview.add_theme_color_override("font_color", WARNING)
		governance_refugee_actions.add_child(preview)
		var row := HBoxContainer.new()
		if phase in [&"PENDING", &"DEFERRED"]:
			var accept := _make_governance_button("接纳")
			accept.name = "RefugeeAcceptButton"
			accept.tooltip_text = "人口一次加入待安置组；不会立即成为劳动力。"
			accept.pressed.connect(_decide_refugee.bind(case_id, &"ACCEPT"))
			row.add_child(accept)
			var defer := _make_governance_button("暂缓")
			defer.tooltip_text = "保持同一来源与人数，不生成新事件。"
			defer.pressed.connect(_decide_refugee.bind(case_id, &"DEFER"))
			row.add_child(defer)
			var reject := _make_governance_button("拒绝")
			reject.tooltip_text = "关闭该来源；首版没有临时夸大惩罚。"
			reject.pressed.connect(_decide_refugee.bind(case_id, &"REJECT"))
			row.add_child(reject)
		else:
			var settle := _make_governance_button("完成安置")
			settle.name = "RefugeeSettleButton"
			settle.disabled = int(governance.get("housing_shortfall", 0)) > 0
			settle.tooltip_text = "需要实际住房覆盖全部人口；完成后转为可用成年人。"
			settle.pressed.connect(_settle_refugee.bind(case_id))
			row.add_child(settle)
		governance_refugee_actions.add_child(row)
	governance_production_minus.disabled = int(population.get("production_workers", 0)) <= 0
	governance_construction_minus.disabled = int(population.get("construction_workers", 0)) <= 0
	governance_production_plus.disabled = int(population.get("available", 0)) <= 0
	governance_construction_plus.disabled = int(population.get("available", 0)) <= 0
	governance_medical_minus.disabled = int(population.get("medical_workers", 0)) <= 0
	governance_medical_plus.disabled = int(population.get("available", 0)) <= 0
	governance_order_minus.disabled = int(population.get("governance_workers", 0)) <= 0
	governance_order_plus.disabled = int(population.get("available", 0)) <= 0
	var treatment_preview: Dictionary = construction_controller.preview_wounded_treatment()
	governance_treatment_button.disabled = not bool(treatment_preview.valid)
	for button in [governance_production_plus, governance_construction_plus, governance_medical_plus, governance_order_plus]:
		button.tooltip_text = "没有可用人员；可从其他岗位调回，或等待训练、治疗、安置完成。" if button.disabled else "分配 1 名现有可用人员"
	for button in [governance_production_minus, governance_construction_minus, governance_medical_minus, governance_order_minus]:
		button.tooltip_text = "该岗位已无人可调回" if button.disabled else "调回 1 人；会降低该岗位能力"
	governance_treatment_button.tooltip_text = str(treatment_preview.error) if not bool(treatment_preview.valid) else "只治疗现有伤员，使用当前医舍与真实医疗人员"
	governance_treatment_button.text = "治疗进行中 · 占用医疗容量" if treatment_active else "治疗 %d 人 · %d 粮" % [int(treatment_preview.count), int(treatment_preview.food_cost)]
	governance_event_button.visible = StringName(Dictionary(governance.get("active_event", {})).get("phase", &"")) == &"ACTIVE"
	governance_event_button.disabled = int(population.get("governance_workers", 0)) < 2
	governance_event_button.tooltip_text = "治理岗位还缺 %d 人" % maxi(2 - int(population.get("governance_workers", 0)), 0) if governance_event_button.disabled else "处置当前事件仍需 2 粮；粮食和住房原因需要另外处理。"
	if governance_event_button.visible:
		governance_event_button.text = "处置当前事件 · 粮食 2 · 压力 -18"
	if not str(governance.get("active_issue", "")).is_empty():
		issues.push_front(str(governance.active_issue))
	governance_issue_detail.visible = not issues.is_empty()
	governance_issue_detail.text = "\n".join(issues)
	var show_workspace: bool = (
		not _strategy_workspace_open
		and
		not construction_controller.is_placing()
		and not construction_controller.is_choosing_template()
		and not detail_panel.visible
		and not (
			construction_controller.has_method("has_build_project")
			and bool(construction_controller.has_build_project())
		)
	)
	governance_workspace.visible = show_workspace
	if show_workspace:
		# The legacy entry becomes the modal placement surface only; it must not
		# compete with the default governance workspace.
		construction_entry.visible = false
		if not _governance_workspace_was_visible and is_visible_in_tree():
			governance_catalog_button.grab_focus.call_deferred()
	_governance_workspace_was_visible = show_workspace


func _layout_catalog(width: float) -> void:
	$ConstructionMenu/Title.position = Vector2(16.0, 16.0)
	$ConstructionMenu/CloseButton.position = Vector2(width - 52.0, 10.0)
	$ConstructionMenu/CloseButton.size = Vector2(38.0, 34.0)
	var button_y := 58.0
	for button in [
		$ConstructionMenu/RoadButton,
		$ConstructionMenu/LoggingCampButton,
		$ConstructionMenu/FarmButton,
		$ConstructionMenu/WarehouseButton,
		$ConstructionMenu/WatchtowerButton,
	]:
		button.position = Vector2(14.0, button_y)
		button.size = Vector2(width - 28.0, 54.0)
		button_y += 61.0


func _layout_detail(width: float) -> void:
	$BuildingDetailPanel/PanelTitle.position = Vector2(18.0, 16.0)
	$BuildingDetailPanel/CloseButton.position = Vector2(width - 52.0, 10.0)
	$BuildingDetailPanel/CloseButton.size = Vector2(38.0, 34.0)
	$BuildingDetailPanel/Divider.position = Vector2(18.0, 56.0)
	$BuildingDetailPanel/Divider.size = Vector2(width - 36.0, 1.0)
	for node_name in ["TargetName", "TargetType", "GridPosition", "Footprint", "PrototypeStatus", "Description", "RoadStatus", "PriorityLabel", "PriorityHelp", "UpgradeStatusCard"]:
		var label := $BuildingDetailPanel.get_node(node_name) as Label
		label.size.x = width - 40.0
	$BuildingDetailPanel/StatusBadge.size.x = width - 174.0
	$BuildingDetailPanel/ConstructionProgress.size.x = width - 40.0
	$BuildingDetailPanel/ConstructionPriorityOption.size.x = width - 40.0
	$BuildingDetailPanel/RemoveButton.size.x = width - 40.0
	$BuildingDetailPanel/UpgradeButton.size.x = width - 40.0


func _layout_top_status_regions(width: float, top_height: float, edge: float) -> void:
	# The top bar has five ordered ownership regions. Their minimums protect
	# mainline status and time controls; only settlement detail yields width.
	var gap := clampf(width * 0.008, 8.0, 12.0)
	var resource_width := clampf(width * 0.21, 232.0, 270.0)
	var city_width := clampf(width * 0.15, 160.0, 200.0)
	var alert_width := clampf(width * 0.20, 220.0, 288.0)
	var speed_width := 78.0
	var pause_width := 72.0
	var fixed_width := (
		resource_width
		+ city_width
		+ alert_width
		+ speed_width
		+ pause_width
		+ gap * 4.0
		+ edge * 2.0
	)
	var settlement_width := maxf(168.0, width - fixed_width)
	var x := edge
	var label_y := floorf((top_height - 22.0) * 0.5)
	var control_y := floorf((top_height - 44.0) * 0.5)
	var separator_y := 8.0
	var separator_height := maxf(0.0, top_height - separator_y * 2.0)

	resource_summary.position = Vector2(x, label_y)
	resource_summary.size = Vector2(resource_width, 22.0)
	x += resource_width + gap
	_layout_top_separator($TopStatusBar/DividerOne, x - gap * 0.5, separator_y, separator_height)

	current_city.position = Vector2(x, label_y)
	current_city.size = Vector2(city_width, 22.0)
	x += city_width + gap
	_layout_top_separator($TopStatusBar/DividerTwo, x - gap * 0.5, separator_y, separator_height)

	time_summary.position = Vector2(x, 8.0)
	time_summary.size = Vector2(104.0, 20.0)
	daily_report.position = Vector2(x + 110.0, 8.0)
	# Date and settlement own two rows: the date and settlement share row one;
	# next-stage detail receives row two. Trailing settlement detail clips here.
	daily_report.size = Vector2(maxf(0.0, settlement_width - 110.0), 20.0)
	daily_report.visible = true
	daily_report.clip_text = true
	daily_report.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	next_stage_summary.position = Vector2(x + 110.0, 26.0)
	next_stage_summary.size = Vector2(maxf(0.0, settlement_width - 110.0), 20.0)
	next_stage_summary.clip_text = true
	next_stage_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	x += settlement_width + gap
	_layout_top_separator($TopStatusBar/DividerThree, x - gap * 0.5, separator_y, separator_height)

	alert_summary.position = Vector2(x, 8.0)
	alert_summary.size = Vector2(alert_width, 38.0)
	alert_summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	alert_summary.clip_text = true
	current_mainline_button.position = Vector2(x, top_height - 48.0)
	current_mainline_button.size = Vector2(alert_width, 44.0)
	x += alert_width + gap
	_layout_top_separator($TopStatusBar/DividerFour, x - gap * 0.5, separator_y, separator_height)

	time_speed_option.position = Vector2(x, control_y)
	time_speed_option.size = Vector2(speed_width, 44.0)
	x += speed_width + gap
	pause_button.position = Vector2(x, control_y)
	pause_button.size = Vector2(pause_width, 44.0)


func _layout_top_separator(separator: ColorRect, x: float, y: float, height: float) -> void:
	separator.position = Vector2(x, y)
	separator.size = Vector2(1.0, height)


func get_top_status_region_rects() -> Dictionary:
	return {
		"resources": resource_summary.get_global_rect(),
		"city": current_city.get_global_rect(),
		"date_and_settlement": time_summary.get_global_rect().merge(
			daily_report.get_global_rect()
		).merge(
			next_stage_summary.get_global_rect()
		),
		"deadline_and_pressure": alert_summary.get_global_rect().merge(
			current_mainline_button.get_global_rect()
		),
		"speed_and_pause": time_speed_option.get_global_rect().merge(
			pause_button.get_global_rect()
		),
	}


func get_visible_construction_child_rects() -> Dictionary:
	var rects := {}
	for control in [
		build_entry_button,
		build_mode_status,
		placement_orientation,
		rotate_button,
		confirm_road_button,
		cancel_placement_button,
		$ConstructionEntryPanel/BuildSlotContent/BuildSlotProgress,
		$ConstructionEntryPanel/BuildSlotContent/BuildSlotDetail,
		$ConstructionEntryPanel/BuildSlotContent/BuildSlotPrimaryButton,
		$ConstructionEntryPanel/BuildSlotContent/BuildSlotCancelButton,
	]:
		var node := control as Control
		if node.visible:
			rects[node.name] = node.get_global_rect()
	return rects


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 6
	return style


func _apply_button_tokens(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(SURFACE_RAISED, BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color("16333c"), ACCENT))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1e4650"), ACCENT))
	button.add_theme_stylebox_override("disabled", _button_style(SURFACE, Color("263942")))


func _button_style(color: Color, outline: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style
