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
@onready var placement_orientation: Label = $ConstructionEntryPanel/PlacementOrientation
@onready var rotate_button: Button = $ConstructionEntryPanel/RotateButton
@onready var confirm_road_button: Button = $ConstructionEntryPanel/ConfirmRoadButton
@onready var cancel_placement_button: Button = $ConstructionEntryPanel/CancelPlacementButton
@onready var construction_menu: Panel = $ConstructionMenu
@onready var detail_panel: Panel = $BuildingDetailPanel
@onready var noticeboard_panel: Panel = $NoticeboardPanel


func _ready() -> void:
	_apply_visual_tokens()
	_apply_static_copy()
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)
	construction_controller.city_state_changed.connect(_refresh_read_model)
	construction_controller.construction_presentation_changed.connect(
		_layout_for_viewport
	)
	_refresh_read_model()
	call_deferred("_restore_product_overview")


func _restore_product_overview() -> void:
	# R1 makes the right build rail the sole permanent city-operation surface.
	# The legacy city context can still be explicitly opened without owning state.
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
	build_entry_button.text = "建造目录"
	build_mode_status.text = "已选蓝图\n地图左键建造 · R 旋转 · 右键/Esc 取消"
	$ConstructionMenu/Title.text = "建造 · 建筑 / 道路"
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
	var garrison: Dictionary = construction_controller.get_garrison_snapshot()
	var queue: Dictionary = construction_controller.get_training_queue_snapshot()
	army_status.text = "驻军 / 训练\n驻军 %d · 可派 %d/%d\n队列 %d · 建造中 %d 项" % [
		int(garrison.get("total_count", 0)),
		int(garrison.get("dispatchable_count", 0)),
		int(garrison.get("effective_command_limit", 0)),
		int(queue.get("queued_count", 0)),
		construction_controller.get_construction_in_progress_count(),
	]
	for label in [time_summary, daily_report, alert_summary]:
		label.add_theme_color_override("font_color", MUTED_TEXT)


func _layout_for_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var width := viewport_size.x
	var height := viewport_size.y
	var edge := clampf(width * 0.015, 16.0, 32.0)
	# M1A keeps the current-mainline action inside the existing alert region.
	# Its dedicated action row protects the status copy without creating a sixth
	# floating top-bar region or reducing type at narrower viewports.
	var top_height := clampf(height * 0.095, 82.0, 96.0)
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
	construction_entry.size = Vector2(
		right_width,
		300.0 if has_build_slot and not is_placing else (206.0 if is_placing else 66.0)
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
	$ConstructionEntryPanel/BuildSlotProgress.position = Vector2(14.0, 78.0)
	$ConstructionEntryPanel/BuildSlotProgress.size = Vector2(right_width - 28.0, 22.0)
	$ConstructionEntryPanel/BuildSlotDetail.position = Vector2(14.0, 108.0)
	$ConstructionEntryPanel/BuildSlotDetail.size = Vector2(right_width - 28.0, 88.0)
	$ConstructionEntryPanel/BuildSlotPrimaryButton.position = Vector2(14.0, 204.0)
	$ConstructionEntryPanel/BuildSlotPrimaryButton.size = Vector2(right_width - 28.0, 34.0)
	$ConstructionEntryPanel/BuildSlotCancelButton.position = Vector2(14.0, 246.0)
	$ConstructionEntryPanel/BuildSlotCancelButton.size = Vector2(right_width - 28.0, 34.0)

	construction_menu.position = Vector2(width - right_width - edge, rail_top + 218.0)
	construction_menu.size = Vector2(right_width, minf(390.0, height - rail_top - 230.0))
	_layout_catalog(right_width)

	detail_panel.position = Vector2(width - right_width - edge, rail_top + 140.0)
	detail_panel.size = Vector2(right_width, minf(610.0, height - rail_top - 154.0))
	_layout_detail(right_width)


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
	var control_y := floorf((top_height - 34.0) * 0.5)
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
	current_mainline_button.position = Vector2(x, top_height - 30.0)
	current_mainline_button.size = Vector2(alert_width, 24.0)
	x += alert_width + gap
	_layout_top_separator($TopStatusBar/DividerFour, x - gap * 0.5, separator_y, separator_height)

	time_speed_option.position = Vector2(x, control_y)
	time_speed_option.size = Vector2(speed_width, 34.0)
	x += speed_width + gap
	pause_button.position = Vector2(x, control_y)
	pause_button.size = Vector2(pause_width, 34.0)


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
