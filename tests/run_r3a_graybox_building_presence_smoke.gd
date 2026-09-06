extends SceneTree

const GRAYBOX_BUILDING_VISUAL = preload(
	"res://scripts/graybox_building_visual.gd"
)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式主场景可加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var construction: Node = scene.get_node("ConstructionController")
	var foundation: Node = scene.get_node(
		"MapWorld/RegularCitySpatialFoundation"
	)
	var fixed_visuals: Array[Node] = []
	for child in foundation.get_children():
		if child is GrayboxBuildingVisual:
			fixed_visuals.append(child)
	_check(fixed_visuals.size() >= 6, "固定城政建筑使用共享灰盒表现组件")
	for visual in fixed_visuals:
		_check(visual.get_node_or_null("Foundation") != null,
			"固定建筑包含真实占地地基")
		_check(visual.get_node_or_null("Roof") != null,
			"固定建筑包含顶面体量")
		_check(visual.get_node_or_null("Entrance") != null,
			"固定建筑包含入口表现")

	var definition: Resource = construction.get_definition(
		&"building.logging_camp.t1"
	)
	_check(definition != null, "表现组件读取真实伐木场定义")
	if definition == null:
		_finish_scene(scene)
		return

	var base_footprint: Vector2i = definition.footprint
	var orientations := [0, 1, 2, 3]
	var entrance_signatures: Array[String] = []
	for direction in orientations:
		var visual := GRAYBOX_BUILDING_VISUAL.new() as GrayboxBuildingVisual
		visual.configure(
			definition.definition_id,
			definition.display_name,
			definition.building_type,
			construction.get_rotated_footprint(definition, direction),
			direction,
			definition.body_color,
			definition.outline_color,
			definition.requires_road,
			false,
			&"constructing",
			0.1,
			&"disconnected"
		)
		root.add_child(visual)
		var expected_footprint: Vector2i = construction.get_rotated_footprint(
			definition,
			direction
		)
		_check(visual.footprint == expected_footprint,
			"方向 %d 的视觉占地读取权威旋转 footprint" % direction)
		var foundation_polygon: PackedVector2Array = (
			visual.get_node("Foundation") as Polygon2D
		).polygon
		_check(
			is_equal_approx(
				foundation_polygon[2].x,
				float(expected_footprint.x) * GrayboxBuildingVisual.GRID_SIZE
			)
			and is_equal_approx(
				foundation_polygon[2].y,
				float(expected_footprint.y) * GrayboxBuildingVisual.GRID_SIZE
			),
			"方向 %d 的地基与权威占地一致" % direction
		)
		var marker := visual.get_node("EntranceMarker") as Polygon2D
		entrance_signatures.append(_polygon_signature(marker.polygon))
		_check(visual.get_orientation_label() == ["北", "东", "南", "西"][direction],
			"方向 %d 的入口朝向标签稳定" % direction)
		visual.queue_free()
	_check(
		entrance_signatures.size() == 4
			and entrance_signatures[0] != entrance_signatures[1]
			and entrance_signatures[1] != entrance_signatures[2]
			and entrance_signatures[2] != entrance_signatures[3],
		"N/E/S/W 入口视觉位置均发生真实方向变化"
	)
	_check(base_footprint == Vector2i(2, 2), "伐木场基准定义保持 2 x 2")

	var type_visual_signatures: Dictionary = {}
	for definition_id in [
		&"building.farm.t1",
		&"building.logging_camp.t1",
		&"building.warehouse.t1",
	]:
		var type_definition: Resource = construction.get_definition(definition_id)
		_check(type_definition != null, "%s 使用真实建筑定义" % definition_id)
		if type_definition == null:
			continue
		var type_visual := GRAYBOX_BUILDING_VISUAL.new() as GrayboxBuildingVisual
		type_visual.configure(
			type_definition.definition_id,
			type_definition.display_name,
			type_definition.building_type,
			type_definition.footprint,
			GrayboxBuildingVisual.ORIENTATION_NORTH,
			type_definition.body_color,
			type_definition.outline_color,
			type_definition.requires_road,
			false
		)
		root.add_child(type_visual)
		var detail := type_visual.get_node("Detail") as Polygon2D
		var roof := type_visual.get_node("Roof") as Polygon2D
		type_visual_signatures[definition_id] = "%s|%d|%s" % [
			detail.color.to_html(),
			detail.polygon.size(),
			_polygon_signature(roof.polygon),
		]
		type_visual.queue_free()
	var unique_type_signatures: Dictionary = {}
	for signature in type_visual_signatures.values():
		unique_type_signatures[signature] = true
	_check(
		type_visual_signatures.size() == 3
			and unique_type_signatures.size() == 3,
		"农田、伐木场、仓库使用可辨认的灰盒轮廓"
	)

	var fallback := GRAYBOX_BUILDING_VISUAL.new() as GrayboxBuildingVisual
	fallback.configure(
		&"building.unknown.r3a",
		"未知建筑",
		"unknown",
		Vector2i.ONE,
		0,
		Color("718080"),
		Color("2e3b3d"),
		false,
		false
	)
	root.add_child(fallback)
	_check(fallback.get_presentation_stage() == &"completed",
		"未识别建筑类型使用中性 fallback")
	_check(fallback.get_node("Body") is Polygon2D,
		"fallback 仍有程序化主体体块")
	fallback.queue_free()

	var origin := Vector2i(20, 20)
	var placement_id: int = construction.place_definition_at_cell(
		definition.definition_id,
		origin,
		false,
		false,
		GrayboxBuildingVisual.ORIENTATION_EAST
	)
	_check(placement_id > 0, "可从权威接口创建施工中的伐木场")
	if placement_id > 0:
		var record: Dictionary = construction.get_building_record(placement_id)
		var runtime_visual: CanvasItem = construction.get_building_node(placement_id)
		_check(runtime_visual is GrayboxBuildingVisual,
			"运行时建筑节点使用共享灰盒表现组件")
		_check(record.footprint == Vector2i(2, 2),
			"方形建筑旋转后占地保持权威尺寸")
		_check(
			(runtime_visual as GrayboxBuildingVisual).get_presentation_stage()
				== &"foundation",
			"施工开始先显示 foundation 阶段"
		)
		var runtime_marker := (
			(runtime_visual as GrayboxBuildingVisual).get_node("EntranceMarker")
			as Polygon2D
		)
		_check(
			runtime_marker.visible and runtime_marker.color.r > runtime_marker.color.g,
			"未接路状态显示克制的入口阻断提示"
		)
		(runtime_visual as GrayboxBuildingVisual).update_presentation(
			&"constructing", 0.1, &"connected", false, true
		)
		_check(
			runtime_marker.visible and runtime_marker.color.g > runtime_marker.color.r,
			"已接路状态显示运行入口提示"
		)
		(runtime_visual as GrayboxBuildingVisual).update_presentation(
			&"constructing", 0.1, &"disconnected", false, false
		)

		var before_visual_state: Dictionary = construction.get_city_state()
		(runtime_visual as GrayboxBuildingVisual).update_presentation(
			&"constructing", 0.45, &"disconnected", true, true
		)
		var after_visual_state: Dictionary = construction.get_city_state()
		_check(before_visual_state == after_visual_state,
			"表现层更新不写资源、道路或建筑权威状态")
		_check(
			(runtime_visual as GrayboxBuildingVisual).get_presentation_stage()
				== &"frame",
			"中段进度显示主体形成阶段"
		)

		construction.set_city_time_paused(true)
		await process_frame
		var paused_progress := (
			runtime_visual as GrayboxBuildingVisual
		).presentation_progress
		construction.advance_city_frame_for_test(60.0)
		await process_frame
		_check(
			is_equal_approx(
				(runtime_visual as GrayboxBuildingVisual).presentation_progress,
				paused_progress
			),
			"暂停时施工表现不会自行推进"
		)
		construction.set_city_time_paused(false)
		construction.advance_one_day_for_test()
		await process_frame
		_check(
			(runtime_visual as GrayboxBuildingVisual).get_presentation_stage()
				== &"completed",
			"权威日结后视觉阶段进入 completed"
		)

		var snapshot: Dictionary = construction.export_v5_campaign_snapshot()
		var restore_result: Dictionary = construction.restore_v5_campaign_snapshot(
			snapshot
		)
		_check(bool(restore_result.get("success", false)),
			"V5 存档重载仍可恢复建筑表现输入")
		var restored_record: Dictionary = construction.get_building_record(placement_id)
		_check(
			int(restored_record.get("orientation", -1))
				== GrayboxBuildingVisual.ORIENTATION_EAST,
			"V5 存档重载保留建筑东向"
		)
		var restored_visual: CanvasItem = construction.get_building_node(placement_id)
		_check(restored_visual is GrayboxBuildingVisual,
			"V5 存档重载重建共享灰盒节点")

	construction.remove_placed_building(placement_id)

	_finish_scene(scene)


func _polygon_signature(polygon: PackedVector2Array) -> String:
	var parts: Array[String] = []
	for point in polygon:
		parts.append("%.1f,%.1f" % [point.x, point.y])
	return ";".join(parts)


func _finish_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("R3A_GRAYBOX_BUILDING_PRESENCE_SMOKE PASS")
		quit(0)
	else:
		print("R3A_GRAYBOX_BUILDING_PRESENCE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
