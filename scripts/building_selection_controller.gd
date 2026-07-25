extends Node


const SELECTION_OUTLINE_MARGIN := 4.0

@onready var map_world: Node2D = $"../MapWorld"
@onready var placed_buildings: Node2D = $"../MapWorld/ConstructionLayer/PlacedBuildings"
@onready var selection_outline: Line2D = $"../MapWorld/ConstructionLayer/SelectionOutline"
@onready var detail_panel: Panel = $"../UI/Shell/BuildingDetailPanel"
@onready var target_name: Label = $"../UI/Shell/BuildingDetailPanel/TargetName"
@onready var target_type: Label = $"../UI/Shell/BuildingDetailPanel/TargetType"
@onready var grid_position: Label = $"../UI/Shell/BuildingDetailPanel/GridPosition"
@onready var footprint: Label = $"../UI/Shell/BuildingDetailPanel/Footprint"
@onready var prototype_status: Label = $"../UI/Shell/BuildingDetailPanel/PrototypeStatus"
@onready var close_button: Button = $"../UI/Shell/BuildingDetailPanel/CloseButton"
@onready var top_status_bar: Control = $"../UI/Shell/TopStatusBar"
@onready var city_bar: Control = $"../UI/Shell/CityBar"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"
@onready var context_bar: Control = $"../UI/Shell/ContextBar"

var selected_building: Node2D = null


func _ready() -> void:
	close_button.pressed.connect(clear_selection)
	clear_selection()


func handle_map_click(screen_position: Vector2) -> void:
	if is_screen_point_blocked(screen_position):
		return

	var building := get_building_at_screen_position(screen_position)
	if building == null:
		clear_selection()
	else:
		select_building(building)


func select_building(building: Node2D) -> void:
	if not is_instance_valid(building) or not building.is_inside_tree():
		clear_selection()
		return

	if selected_building != building:
		_disconnect_selected_building()
	selected_building = building
	if not selected_building.tree_exited.is_connected(_on_selected_building_tree_exited):
		selected_building.tree_exited.connect(_on_selected_building_tree_exited)
	_refresh_selection_outline()
	_refresh_detail_panel()


func clear_selection() -> void:
	_disconnect_selected_building()
	selected_building = null
	selection_outline.visible = false
	detail_panel.visible = false


func has_selection() -> bool:
	return is_instance_valid(selected_building)


func get_building_at_screen_position(screen_position: Vector2) -> Node2D:
	var map_local_position := (
		map_world.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)
	var map_global_position := map_world.to_global(map_local_position)

	for index in range(placed_buildings.get_child_count() - 1, -1, -1):
		var building := placed_buildings.get_child(index) as Node2D
		if building == null or not building.has_meta("selection_bounds"):
			continue

		var selection_bounds: Rect2 = building.get_meta("selection_bounds")
		var building_local_position := building.to_local(map_global_position)
		if selection_bounds.has_point(building_local_position):
			return building

	return null


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


func _refresh_selection_outline() -> void:
	var selection_bounds: Rect2 = selected_building.get_meta("selection_bounds")
	var expanded_bounds := selection_bounds.grow(SELECTION_OUTLINE_MARGIN)
	selection_outline.points = PackedVector2Array([
		expanded_bounds.position,
		Vector2(expanded_bounds.end.x, expanded_bounds.position.y),
		expanded_bounds.end,
		Vector2(expanded_bounds.position.x, expanded_bounds.end.y),
		expanded_bounds.position,
	])
	selection_outline.global_transform = selected_building.global_transform
	selection_outline.visible = true


func _refresh_detail_panel() -> void:
	var origin_cell: Vector2i = selected_building.get_meta("origin_cell")
	var footprint_cells: Vector2i = selected_building.get_meta("footprint_cells")
	target_name.text = str(selected_building.get_meta("display_name", "测试建筑"))
	target_type.text = "类型：%s" % str(
		selected_building.get_meta("building_type", "中性测试建筑")
	)
	grid_position.text = "网格位置：(%d, %d)" % [origin_cell.x, origin_cell.y]
	footprint.text = "占地：%d × %d" % [footprint_cells.x, footprint_cells.y]
	prototype_status.text = "状态：%s" % str(
		selected_building.get_meta("prototype_status", "原型 / 运行中")
	)
	detail_panel.visible = true


func _get_ui_occlusion_controls() -> Array[Control]:
	return [
		top_status_bar,
		city_bar,
		minimap_placeholder,
		context_bar,
		detail_panel,
	]


func _disconnect_selected_building() -> void:
	if (
		is_instance_valid(selected_building)
		and selected_building.tree_exited.is_connected(_on_selected_building_tree_exited)
	):
		selected_building.tree_exited.disconnect(_on_selected_building_tree_exited)


func _on_selected_building_tree_exited() -> void:
	selected_building = null
	selection_outline.visible = false
	detail_panel.visible = false
