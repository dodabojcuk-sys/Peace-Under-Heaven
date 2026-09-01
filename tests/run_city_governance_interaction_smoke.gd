extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var first: Dictionary = await _new_city()
	var city: Node = first.city
	var shell: Control = first.shell
	city.set_city_time_paused(true)

	var unique_id: int = city.place_definition_at_cell(
		LOGGING_ID, Vector2i(33, 16), false, true, 0
	)
	_check(unique_id > 0, "治理 fixture 创建未接通建筑")
	var snapshot_before := _persistent_road_snapshot(city)
	var recommendation: Dictionary = city.query_road_connection_recommendation(unique_id)
	_check(
		_persistent_road_snapshot(city) == snapshot_before,
		"接通方案查询不写资源、道路、placement 或预览"
	)
	_check(
		StringName(recommendation.get("status", &"")) == &"recommended"
		and int(recommendation.get("path_length", 0)) > 0,
		"唯一最短合法路径可被推荐"
	)

	var preview: Dictionary = city.preview_road_connection_recommendation(unique_id)
	_check(
		StringName(preview.get("status", &"")) == &"recommended"
		and city.has_road_connection_recommendation_preview()
		and city.preview_valid,
		"推荐只进入现有道路 preview 生命周期"
	)
	_check(
		_persistent_road_snapshot(city) == snapshot_before,
		"推荐预览前资源和道路仍完全不变"
	)
	var wood_before_confirm: int = city.wood
	var road_cells_before_confirm: Dictionary = city.get_player_road_cells().duplicate(true)
	var expected_cost: int = int(preview.get("wood_cost", 0))
	var planned_new_cells: Array = city.evaluate_road_path(
		preview.get("cells", [])
	).get("new_cells", [])
	_check(city.confirm_road_preview(), "确认铺设复用既有道路确认入口")
	_check(
		city.wood == wood_before_confirm - expected_cost
		and city.get_player_road_cells().size() == (
			road_cells_before_confirm.size() + planned_new_cells.size()
		),
		"确认恰好扣一次木材并创建一次道路 placement"
	)
	_check(
		not city.confirm_road_preview()
		and city.wood == wood_before_confirm - expected_cost,
		"重复确认不会重复扣费或落地"
	)

	var second: Dictionary = await _new_city()
	var ambiguous_city: Node = second.city
	ambiguous_city.set_city_time_paused(true)
	var ambiguous_id: int = ambiguous_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(31, 17), false, true, 0
	)
	var ambiguous: Dictionary = ambiguous_city.query_road_connection_recommendation(
		ambiguous_id
	)
	_check(
		StringName(ambiguous.get("status", &"")) == &"ambiguous"
		and str(ambiguous.get("message", "")) == "存在多种接通方式，请手动规划。",
		"多条等长最短路线不会依赖邻居顺序自动选择"
	)
	var ambiguous_before := _persistent_road_snapshot(ambiguous_city)
	var rejected_preview: Dictionary = ambiguous_city.preview_road_connection_recommendation(
		ambiguous_id
	)
	_check(
		StringName(rejected_preview.get("status", &"")) == &"ambiguous"
		and _persistent_road_snapshot(ambiguous_city) == ambiguous_before,
		"多方案拒绝和手动规划入口不写国家状态"
	)
	var impossible_definition := BuildingDefinition.new()
	impossible_definition.definition_id = &"test.governance.no_road_exit"
	impossible_definition.display_name = "无出口治理 fixture"
	impossible_definition.building_type = "测试建筑"
	impossible_definition.placement_kind = &"placed"
	impossible_definition.footprint = Vector2i.ONE
	impossible_definition.road_anchor_offsets = [Vector2i(0, -60)]
	impossible_definition.build_days = 0
	ambiguous_city._register_definition(impossible_definition)
	var impossible_id: int = ambiguous_city.place_definition_at_cell(
		impossible_definition.definition_id, Vector2i(40, 20), false, true, 0
	)
	var unavailable: Dictionary = ambiguous_city.query_road_connection_recommendation(
		impossible_id
	)
	_check(
		StringName(unavailable.get("status", &"")) == &"unavailable"
		and not str(unavailable.get("message", "")).is_empty(),
		"无合法接通路径会保留准确原因"
	)

	var third: Dictionary = await _new_city()
	var stale_city: Node = third.city
	stale_city.set_city_time_paused(true)
	var stale_id: int = stale_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(33, 16), false, true, 0
	)
	var stale_preview: Dictionary = stale_city.preview_road_connection_recommendation(stale_id)
	_check(StringName(stale_preview.get("status", &"")) == &"recommended", "可生成过期校验 fixture")
	var stale_cells: Array = stale_preview.get("cells", [])
	if stale_cells.size() >= 2:
		var changed_path: Array[Vector2i] = [Vector2i(stale_cells[0])]
		_check(
			bool(stale_city.place_player_road_path(changed_path).get("success", false)),
			"外部地图改变走既有道路 writer"
		)
		_check(
			not stale_city.confirm_road_preview(),
			"状态变化后旧接通预览被重新验证拒绝"
		)

	var fourth: Dictionary = await _new_city()
	var poor_city: Node = fourth.city
	poor_city.set_city_time_paused(true)
	var poor_id: int = poor_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(33, 16), false, true, 0
	)
	var poor_plan: Dictionary = poor_city.query_road_connection_recommendation(poor_id)
	poor_city.wood = 0
	var poor_preview: Dictionary = poor_city.preview_road_connection_recommendation(poor_id)
	_check(
		StringName(poor_plan.get("status", &"")) == &"recommended"
		and StringName(poor_preview.get("status", &"")) == &"unavailable"
		and str(poor_preview.get("message", "")).contains("木材不足"),
		"资源不足时确认前阻止道路写入并给出原因"
	)

	var workspace := shell.get_node("GovernanceWorkspace") as Control
	var build_entry := shell.get_node("ConstructionEntryPanel/BuildEntryButton") as Button
	_check(
		workspace.visible
		and build_entry.text == "城市经营"
		and shell.get_node("CityBarToggle").visible,
		"默认进入城市经营，城市切换维持既有功能入口"
	)
	var selection: Node = (first.scene as Node).get_node("BuildingSelectionController")
	var card_id: int = city.place_definition_at_cell(
		LOGGING_ID, Vector2i(36, 16), false, true, 0
	)
	selection.select_placement(card_id)
	await process_frame
	var action_group := shell.get_node("BuildingDetailPanel/GovernanceActionGroup") as Control
	var primary := action_group.get_node("GovernancePrimaryAction") as Button
	_check(
		action_group.visible
		and primary.visible
		and primary.text == "查看接通方案",
		"未接通建筑卡片只暴露一个明确主操作"
	)
	for child in action_group.get_children():
		if child is Control and (child as Control).visible:
			_check(
				action_group.get_global_rect().encloses((child as Control).get_global_rect()),
				"建筑卡片可见操作保持在所属容器内"
			)
	for target_size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = target_size
		await process_frame
		await process_frame
		var detail_panel := shell.get_node("BuildingDetailPanel") as Control
		var minimap := shell.get_node("MinimapPlaceholder") as Control
		_check(
			detail_panel.get_global_rect().encloses(action_group.get_global_rect())
			and not detail_panel.get_global_rect().intersects(minimap.get_global_rect())
			and not detail_panel.get_global_rect().intersects(
				shell.get_node("TopStatusBar").get_global_rect()
			),
			"%dx%d 建筑操作容器不越界、不遮挡小地图或顶栏" % [target_size.x, target_size.y]
		)
	selection.clear_selection()
	for target_size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = target_size
		await process_frame
		await process_frame
		_check(
			workspace.visible
			and workspace.get_global_rect().encloses(
				workspace.get_node("GovernanceMargin").get_global_rect()
			)
			and not workspace.get_global_rect().intersects(
				shell.get_node("TopStatusBar").get_global_rect()
			),
			"%dx%d 城市经营容器不越界且不侵入顶栏" % [target_size.x, target_size.y]
		)

	var save_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored: Dictionary = await _new_city()
	var restored_city: Node = restored.city
	_check(
		bool(restored_city.restore_v5_campaign_snapshot(save_snapshot).get("success", false))
		and restored_city.get_player_road_cells() == city.get_player_road_cells(),
		"保存和冷启动恢复后已铺道路继续存在"
	)

	for fixture in [first, second, third, fourth, restored]:
		(fixture.scene as Node).queue_free()
	await process_frame
	_finish()


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	return {
		"scene": scene,
		"city": scene.get_node("ConstructionController"),
		"shell": scene.get_node("UI/Shell"),
	}


func _persistent_road_snapshot(city: Node) -> Dictionary:
	return {
		"wood": city.wood,
		"roads": city.get_player_road_cells().duplicate(true),
		"placements": city.get_building_count(),
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures.append(label)
	push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("CITY_GOVERNANCE_INTERACTION_SMOKE PASS")
		quit(0)
		return
	print("CITY_GOVERNANCE_INTERACTION_SMOKE FAIL (%d)" % failures.size())
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
