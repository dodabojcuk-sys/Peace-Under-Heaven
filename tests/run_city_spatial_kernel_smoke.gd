extends SceneTree


const GridRules = preload(
	"res://scripts/city_sandbox/city_grid_rules.gd"
)
const ProjectionRules = preload(
	"res://scripts/city_sandbox/city_projection.gd"
)
const RoadDraft = preload(
	"res://scripts/city_sandbox/city_road_draft.gd"
)

var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	if not _dependencies_can_instantiate():
		_finish()
		return
	_test_footprint_and_entrance_rotation()
	_test_invalid_entrance_models()
	_test_projection_round_trips()
	_test_road_drafts()
	_test_road_masks()
	_test_road_connectivity()
	_test_coverage_bounds_and_conflicts()
	_test_helpers_are_pure_ref_counted_objects()
	_finish()


func _dependencies_can_instantiate() -> bool:
	var dependencies := {
		"CityGridRules": GridRules,
		"CityProjection": ProjectionRules,
		"CityRoadDraft": RoadDraft,
	}
	var valid := true
	for dependency_name in dependencies:
		var dependency: Script = dependencies[dependency_name]
		if not dependency.can_instantiate():
			valid = false
			failures.append("%s 无法实例化" % dependency_name)
			push_error("FAIL: %s 无法实例化" % dependency_name)
	return valid


func _test_footprint_and_entrance_rotation() -> void:
	var origin := Vector2i(10, 20)
	var footprint := Vector2i(3, 2)
	var entrance_cell := Vector2i(0, 1)
	var entrance_facing := Vector2i.LEFT
	var expected_footprints := [
		Vector2i(3, 2),
		Vector2i(2, 3),
		Vector2i(3, 2),
		Vector2i(2, 3),
	]
	var expected_cells := [
		Vector2i(0, 1),
		Vector2i(0, 0),
		Vector2i(2, 0),
		Vector2i(1, 2),
	]
	var expected_facings := [
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
	]
	for orientation in range(4):
		var result: Dictionary = GridRules.resolve_entrance(
			origin,
			footprint,
			entrance_cell,
			entrance_facing,
			orientation
		)
		_check(bool(result.valid), "朝向 %d 的入口模型有效" % orientation)
		_check(
			Vector2i(result.footprint) == expected_footprints[orientation],
			"朝向 %d 的 footprint 正确旋转" % orientation
		)
		_check(
			Vector2i(result.entrance_cell) == expected_cells[orientation],
			"朝向 %d 的入口格正确旋转" % orientation
		)
		_check(
			Vector2i(result.entrance_facing) == expected_facings[orientation],
			"朝向 %d 的入口朝向正确旋转" % orientation
		)
		_check(
			Vector2i(result.road_contact_cell)
				== origin
				+ expected_cells[orientation]
				+ expected_facings[orientation],
			"朝向 %d 的入口外侧道路格正确" % orientation
		)


func _test_invalid_entrance_models() -> void:
	var invalid_footprint: Dictionary = GridRules.get_rotated_footprint(
		Vector2i.ZERO,
		0
	)
	_check(
		not bool(invalid_footprint.valid)
			and invalid_footprint.error == &"invalid_footprint",
		"拒绝零尺寸 footprint"
	)
	var invalid_orientation: Dictionary = GridRules.get_rotated_footprint(
		Vector2i(2, 2),
		4
	)
	_check(
		not bool(invalid_orientation.valid)
			and invalid_orientation.error == &"invalid_orientation",
		"拒绝 orientation 4"
	)
	var outside_cell: Dictionary = GridRules.resolve_entrance(
		Vector2i.ZERO,
		Vector2i(2, 2),
		Vector2i(2, 0),
		Vector2i.RIGHT,
		0
	)
	_check(
		not bool(outside_cell.valid)
			and outside_cell.error == &"entrance_cell_outside_footprint",
		"拒绝位于 footprint 外的入口格"
	)
	var diagonal_facing: Dictionary = GridRules.resolve_entrance(
		Vector2i.ZERO,
		Vector2i(2, 2),
		Vector2i.ZERO,
		Vector2i(-1, -1),
		0
	)
	_check(
		not bool(diagonal_facing.valid)
			and diagonal_facing.error == &"entrance_facing_not_cardinal",
		"拒绝非四方向入口朝向"
	)
	var inward_facing: Dictionary = GridRules.resolve_entrance(
		Vector2i.ZERO,
		Vector2i(3, 2),
		Vector2i(1, 0),
		Vector2i.LEFT,
		0
	)
	_check(
		not bool(inward_facing.valid)
			and inward_facing.error == &"entrance_facing_not_outward",
		"拒绝不从边界朝外的入口"
	)
	var negative_orientation: Dictionary = GridRules.resolve_entrance(
		Vector2i.ZERO,
		Vector2i(2, 2),
		Vector2i.ZERO,
		Vector2i.LEFT,
		-1
	)
	_check(
		not bool(negative_orientation.valid)
			and negative_orientation.error == &"invalid_orientation",
		"拒绝负数 orientation"
	)


func _test_projection_round_trips() -> void:
	var origin := Vector2(100.0, 80.0)
	var orthogonal_x := Vector2(-40.0, 0.0)
	var orthogonal_y := Vector2(0.0, -40.0)
	var grid_position := Vector2(3.25, 4.5)
	var orthogonal_visual: Dictionary = ProjectionRules.grid_to_visual(
		grid_position,
		origin,
		orthogonal_x,
		orthogonal_y
	)
	var orthogonal_grid: Dictionary = ProjectionRules.visual_to_grid(
		Vector2(orthogonal_visual.position),
		origin,
		orthogonal_x,
		orthogonal_y
	)
	_check(bool(orthogonal_visual.valid), "正交投影有效")
	_check(
		Vector2(orthogonal_grid.grid_position).is_equal_approx(grid_position),
		"正交投影 round-trip 保持逻辑坐标"
	)

	var near_top_down_x := Vector2(-48.0, -18.0)
	var near_top_down_y := Vector2(48.0, -18.0)
	var near_visual: Dictionary = ProjectionRules.grid_to_visual(
		grid_position,
		origin,
		near_top_down_x,
		near_top_down_y
	)
	var near_grid: Dictionary = ProjectionRules.visual_to_grid(
		Vector2(near_visual.position),
		origin,
		near_top_down_x,
		near_top_down_y
	)
	_check(bool(near_visual.valid), "近俯视仿射投影有效")
	_check(
		Vector2(near_grid.grid_position).is_equal_approx(grid_position),
		"近俯视投影 round-trip 保持逻辑坐标"
	)

	var anchored_visual: Dictionary = ProjectionRules.grid_to_visual(
		Vector2(7.5, 8.5),
		origin,
		orthogonal_x,
		orthogonal_y
	)
	var snapped: Dictionary = ProjectionRules.visual_to_nearest_cell(
		Vector2(anchored_visual.position),
		origin,
		orthogonal_x,
		orthogonal_y
	)
	_check(
		bool(snapped.valid) and Vector2i(snapped.cell) == Vector2i(7, 8),
		"默认以单元格中心锚点吸附"
	)

	var singular_forward: Dictionary = ProjectionRules.grid_to_visual(
		Vector2.ONE,
		Vector2.ZERO,
		Vector2(1.0, 1.0),
		Vector2(2.0, 2.0)
	)
	var singular_inverse: Dictionary = ProjectionRules.visual_to_grid(
		Vector2.ONE,
		Vector2.ZERO,
		Vector2(1.0, 1.0),
		Vector2(2.0, 2.0)
	)
	_check(
		not bool(singular_forward.valid)
			and singular_forward.error == &"singular_basis",
		"正向转换拒绝奇异 basis"
	)
	_check(
		not bool(singular_inverse.valid)
			and singular_inverse.error == &"singular_basis",
		"逆向转换拒绝奇异 basis"
	)


func _test_road_drafts() -> void:
	var fast_draft: Dictionary = RoadDraft.build_draft([
		Vector2i(0, 0),
		Vector2i(3, 2),
	])
	var expected_fast: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(3, 1),
		Vector2i(3, 2),
	]
	_check(
		fast_draft.axis_priority == &"x_then_y",
		"道路插值固定使用 X 后 Y 轴优先"
	)
	_check(
		fast_draft.ordered_cells == expected_fast,
		"快速拖动用 Manhattan 插值补齐且无断格"
	)

	var reverse: Array[Vector2i] = RoadDraft.interpolate_segment(
		Vector2i(3, 2),
		Vector2i(0, 0)
	)
	_check(
		reverse == [
			Vector2i(3, 2),
			Vector2i(2, 2),
			Vector2i(1, 2),
			Vector2i(0, 2),
			Vector2i(0, 1),
			Vector2i(0, 0),
		],
		"反向拖动保持同一轴优先规则"
	)

	var backtrack: Dictionary = RoadDraft.build_draft([
		Vector2i(0, 0),
		Vector2i(2, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
	])
	_check(
		backtrack.ordered_cells == [
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
		],
		"ordered_cells 保留真实回拖顺序"
	)
	_check(
		backtrack.unique_cells == [
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
		],
		"unique_cells 按首次出现顺序去重"
	)
	var repeated: Dictionary = RoadDraft.build_draft([
		Vector2i(4, 4),
		Vector2i(4, 4),
		Vector2i(4, 4),
	])
	_check(
		repeated.ordered_cells == [Vector2i(4, 4)]
			and repeated.unique_cells == [Vector2i(4, 4)],
		"重复采样点不会制造伪道路步骤"
	)
	_check(
		RoadDraft.build_draft([
			Vector2i(0, 0),
			Vector2i(3, 2),
		]) == fast_draft,
		"相同采样输入产生完全相同 draft"
	)


func _test_road_masks() -> void:
	var center := Vector2i(10, 10)
	for expected_mask in range(16):
		var roads: Dictionary = {center: true}
		if expected_mask & GridRules.MASK_NORTH:
			roads[center + Vector2i.UP] = true
		if expected_mask & GridRules.MASK_EAST:
			roads[center + Vector2i.RIGHT] = true
		if expected_mask & GridRules.MASK_SOUTH:
			roads[center + Vector2i.DOWN] = true
		if expected_mask & GridRules.MASK_WEST:
			roads[center + Vector2i.LEFT] = true
		_check(
			GridRules.get_road_mask(center, roads) == expected_mask,
			"道路 mask %d 正确" % expected_mask
		)


func _test_road_connectivity() -> void:
	var roots: Array[Vector2i] = [Vector2i.ZERO]
	var single: Dictionary = {Vector2i.ZERO: true}
	_check(
		GridRules.get_connected_road_cells(single, roots).size() == 1,
		"单格根道路连通"
	)

	var network: Dictionary = {
		Vector2i(0, 0): true,
		Vector2i(1, 0): true,
		Vector2i(2, 0): true,
		Vector2i(1, 1): true,
		Vector2i(1, 2): true,
		Vector2i(2, 1): true,
		Vector2i(5, 5): true,
	}
	var connected: Dictionary = GridRules.get_connected_road_cells(
		network,
		roots
	)
	_check(connected.size() == 6, "分叉与环路 BFS 不重复计数")
	_check(not connected.has(Vector2i(5, 5)), "断开的道路不进入连通集")

	network.erase(Vector2i(1, 0))
	var disconnected: Dictionary = GridRules.get_connected_road_cells(
		network,
		roots
	)
	_check(disconnected.size() == 1, "移除桥接格后路网断开")
	network[Vector2i(1, 0)] = true
	var reconnected: Dictionary = GridRules.get_connected_road_cells(
		network,
		roots
	)
	_check(reconnected.size() == 6, "恢复桥接格后路网重连")

	var missing_root: Dictionary = GridRules.get_connected_road_cells(
		network,
		[Vector2i(9, 9)]
	)
	_check(missing_root.is_empty(), "不存在的根格不会生成虚假连通")


func _test_coverage_bounds_and_conflicts() -> void:
	var cells: Array[Vector2i] = GridRules.get_covered_cells(
		Vector2i(2, 3),
		Vector2i(3, 2)
	)
	_check(cells.size() == 6, "3 x 2 建筑覆盖六格")
	_check(
		cells == [
			Vector2i(2, 3),
			Vector2i(3, 3),
			Vector2i(4, 3),
			Vector2i(2, 4),
			Vector2i(3, 4),
			Vector2i(4, 4),
		],
		"多格建筑按行稳定列出 covered cells"
	)
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(10, 8))
	_check(
		GridRules.is_footprint_within_bounds(
			Vector2i(7, 6),
			Vector2i(3, 2),
			bounds
		),
		"贴近右下边界的 footprint 仍合法"
	)
	_check(
		not GridRules.is_footprint_within_bounds(
			Vector2i(8, 6),
			Vector2i(3, 2),
			bounds
		),
		"拒绝越过右边界的 footprint"
	)
	_check(
		not GridRules.is_footprint_within_bounds(
			Vector2i(-1, 0),
			Vector2i(1, 1),
			bounds
		),
		"拒绝越过左边界的 footprint"
	)
	var occupied: Dictionary = {
		Vector2i(3, 3): 11,
		Vector2i(4, 4): 12,
		Vector2i(9, 9): 13,
	}
	var conflicts: Array[Vector2i] = GridRules.find_occupied_conflicts(
		cells,
		occupied
	)
	_check(
		conflicts == [Vector2i(3, 3), Vector2i(4, 4)],
		"占用冲突只返回 covered cells 中的冲突格"
	)
	_check(occupied.size() == 3, "占用查询不修改输入字典")
	_check(
		GridRules.get_covered_cells(
			Vector2i.ZERO,
			Vector2i(0, 2)
		).is_empty(),
		"非法 footprint 不产生覆盖格"
	)


func _test_helpers_are_pure_ref_counted_objects() -> void:
	var grid_helper = GridRules.new()
	var projection_helper = ProjectionRules.new()
	var draft_helper = RoadDraft.new()
	_check(grid_helper is RefCounted, "网格 helper 只继承 RefCounted")
	_check(projection_helper is RefCounted, "投影 helper 只继承 RefCounted")
	_check(draft_helper is RefCounted, "道路 helper 只继承 RefCounted")
	_check(not (grid_helper is Node), "网格 helper 不产生 Node")
	_check(not (projection_helper is Node), "投影 helper 不产生 Node")
	_check(not (draft_helper is Node), "道路 helper 不产生 Node")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("CITY_SPATIAL_KERNEL_SMOKE PASS")
		quit(0)
	else:
		print("CITY_SPATIAL_KERNEL_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
