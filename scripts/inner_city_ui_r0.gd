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
@onready var alert_summary: Label = $TopStatusBar/AlertSummary
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
@onready var confirm_placement_button: Button = $ConstructionEntryPanel/ConfirmPlacementButton
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
		$BuildingDetailPanel/Divider,
	]:
		(separator as ColorRect).color = BORDER


func _apply_static_copy() -> void:
	city_bar.visible = false
	city_bar_toggle.visible = true
	city_title.text = "城市序列"
	city_current.text = "黑石城\n经营中"
	city_two.text = "河湾城\n战略目标"
	city_three.text = "下一城市\n未解锁"
	minimap_label.text = "部署概览 · 黑石城"
	build_entry_button.text = "建造目录"
	build_mode_status.text = "已选蓝图\n点击地块确认 · Esc 取消"
	$ConstructionMenu/Title.text = "可建造蓝图"
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
	resource_summary.text = "国家共享资源  木材 %d · 粮食 %d" % [wood, food]
	current_city.text = "黑石城  ·  一城经营投影"
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
	var top_height := clampf(height * 0.078, 66.0, 82.0)
	var left_width := clampf(width * 0.17, 205.0, 250.0)
	var right_width := clampf(width * 0.23, 278.0, 340.0)
	var rail_top := top_height + edge

	top_status_bar.position = Vector2.ZERO
	top_status_bar.size = Vector2(width, top_height)
	resource_summary.position = Vector2(edge, 14.0)
	resource_summary.size = Vector2(left_width + 115.0, 28.0)
	$TopStatusBar/DividerOne.position = Vector2(left_width + 132.0, 14.0)
	$TopStatusBar/DividerOne.size = Vector2(1.0, top_height - 28.0)
	current_city.position = Vector2(left_width + 152.0, 14.0)
	current_city.size = Vector2(220.0, 28.0)
	$TopStatusBar/DividerTwo.position = Vector2(left_width + 385.0, 14.0)
	$TopStatusBar/DividerTwo.size = Vector2(1.0, top_height - 28.0)
	time_summary.position = Vector2(left_width + 405.0, 14.0)
	time_summary.size = Vector2(88.0, 28.0)
	daily_report.position = Vector2(left_width + 500.0, 14.0)
	daily_report.size = Vector2(maxf(140.0, width - right_width - left_width - 560.0), 28.0)
	$TopStatusBar/TimeSpeedOption.position = Vector2(width - 235.0, 14.0)
	$TopStatusBar/TimeSpeedOption.size = Vector2(78.0, 34.0)
	$TopStatusBar/PauseButton.position = Vector2(width - 149.0, 14.0)
	$TopStatusBar/PauseButton.size = Vector2(72.0, 34.0)
	alert_summary.position = Vector2(width - 410.0, 16.0)
	alert_summary.size = Vector2(160.0, 28.0)

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
	construction_entry.position = Vector2(width - right_width - edge, rail_top + 140.0)
	construction_entry.size = Vector2(right_width, 174.0 if is_placing else 66.0)
	build_entry_button.position = Vector2(12.0, 12.0)
	build_entry_button.size = Vector2(right_width - 24.0, 42.0)
	build_mode_status.position = Vector2(14.0, 12.0)
	build_mode_status.size = Vector2(right_width - 28.0, 28.0)
	placement_orientation.position = Vector2(14.0, 46.0)
	placement_orientation.size = Vector2(right_width - 28.0, 22.0)
	rotate_button.position = Vector2(14.0, 76.0)
	rotate_button.size = Vector2((right_width - 42.0) * 0.5, 34.0)
	confirm_placement_button.position = Vector2(22.0 + (right_width - 42.0) * 0.5, 76.0)
	confirm_placement_button.size = Vector2((right_width - 42.0) * 0.5, 34.0)
	cancel_placement_button.position = Vector2(14.0, 118.0)
	cancel_placement_button.size = Vector2(right_width - 28.0, 34.0)

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
	for node_name in ["TargetName", "TargetType", "GridPosition", "Footprint", "PrototypeStatus", "Description", "UpgradeStatusCard"]:
		var label := $BuildingDetailPanel.get_node(node_name) as Label
		label.size.x = width - 40.0
	$BuildingDetailPanel/RemoveButton.size.x = width - 40.0
	$BuildingDetailPanel/UpgradeButton.size.x = width - 40.0


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
