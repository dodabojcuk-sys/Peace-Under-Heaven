extends SceneTree


const RESOLVER = preload("res://scripts/city_layout_profile_resolver.gd")
const CITY_GRID_RULES = preload("res://scripts/city_sandbox/city_grid_rules.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	_check(
		RESOLVER.known_city_ids() == [&"blackstone_city", &"riverbend_city"],
		"两个正式城市使用稳定 ID"
	)
	var regular: Dictionary = RESOLVER.get_city_profile(&"blackstone_city")
	var garden: Dictionary = RESOLVER.get_city_profile(&"riverbend_city")
	_check(
		RESOLVER.resolve_profile_id(&"blackstone_city") == RESOLVER.REGULAR_IMPERIAL,
		"黑石城解析为 REGULAR_IMPERIAL"
	)
	_check(
		RESOLVER.resolve_profile_id(&"riverbend_city") == RESOLVER.ORGANIC_GARDEN,
		"河湾城解析为 ORGANIC_GARDEN"
	)
	_check(
		JSON.stringify(regular) == JSON.stringify(RESOLVER.get_city_profile(&"blackstone_city")),
		"规则城布局解析确定且可重复"
	)
	_check(
		JSON.stringify(garden) == JSON.stringify(RESOLVER.get_city_profile(&"riverbend_city")),
		"花园城布局解析确定且可重复"
	)
	_check(
		JSON.stringify(regular.get("road_layout_rects"))
			!= JSON.stringify(garden.get("road_layout_rects")),
		"两种布局具有真实道路差异"
	)

	_assert_profile_geometry(regular, "规则城")
	_assert_profile_geometry(garden, "花园城")

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
	construction.set_city_time_paused(true)
	_check(
		construction.get_active_city_id() == &"blackstone_city",
		"启动默认绑定黑石城"
	)
	_check(
		construction.get_layout_profile_id() == RESOLVER.REGULAR_IMPERIAL,
		"启动默认使用规则帝城布局"
	)

	var blackstone_watchtower: int = construction.place_definition_at_cell(
		&"building.watchtower.t1",
		Vector2i(45, 30),
		false,
		true,
		1
	)
	_check(blackstone_watchtower > 0, "黑石城可使用现有权威建造命令创建运行时建筑")
	var blackstone_ids: Array = construction.get_city_layout_state_snapshot().runtime_placement_ids
	_check(blackstone_watchtower in blackstone_ids, "黑石城运行时建筑进入本城布局状态")

	_check(construction.switch_city(&"riverbend_city"), "可从正式状态切换到河湾城")
	_check(
		construction.get_layout_profile_id() == RESOLVER.ORGANIC_GARDEN,
		"河湾城切换为有机花园城布局"
	)
	_check(
		blackstone_watchtower not in construction.get_city_layout_state_snapshot().runtime_placement_ids,
		"城市切换不会泄漏黑石城运行时建筑"
	)
	var riverbend_watchtower: int = construction.place_definition_at_cell(
		&"building.watchtower.t1",
		Vector2i(47, 20),
		false,
		true,
		3
	)
	_check(riverbend_watchtower > 0, "河湾城可使用相同权威建造命令")
	var organic_road_cells: Array[Vector2i] = [Vector2i(26, 10)]
	var organic_road: Dictionary = construction.place_player_road_path(organic_road_cells)
	_check(bool(organic_road.get("success", false)), "河湾城可在有机道路旁继续铺设玩家道路")
	var riverbend_snapshot: Dictionary = construction.get_city_layout_state_snapshot()
	_check(construction.switch_city(&"blackstone_city"), "可返回黑石城")
	_check(
		construction.get_layout_profile_id() == RESOLVER.REGULAR_IMPERIAL,
		"返回黑石城恢复规则帝城布局"
	)
	_check(
		blackstone_watchtower in construction.get_city_layout_state_snapshot().runtime_placement_ids,
		"返回黑石城恢复原有运行时建筑"
	)
	_check(
		construction.switch_city(&"riverbend_city"),
		"可再次进入河湾城"
	)
	_check(
		riverbend_watchtower in construction.get_city_layout_state_snapshot().runtime_placement_ids,
		"河湾城恢复自身运行时建筑"
	)
	if bool(organic_road.get("success", false)):
		_check(
			Vector2i(26, 10) in construction.get_player_road_cells(),
			"河湾城玩家道路随本城布局状态恢复"
		)
	_check(
		construction.export_v5_campaign_snapshot().is_empty(),
		"河湾城对 V5 单城存档写入安全失败"
	)
	_check(
		not riverbend_snapshot.is_empty(),
		"河湾城切换快照可被读回"
	)

	_finish_scene(scene)


func _assert_profile_geometry(profile: Dictionary, label: String) -> void:
	var roads := _cells_from_rects(profile.get("road_layout_rects", []))
	var roots: Array[Vector2i] = []
	for root_cell in profile.get("road_root_cells", []):
		roots.append(Vector2i(root_cell))
	var connected := CITY_GRID_RULES.get_connected_road_cells(roads, roots)
	_check(connected.size() == roads.size(), "%s 正式道路全部连通" % label)
	var reserves := _cells_from_rects(profile.get("garden_reserve_rects", []))
	_check(
		_cells_intersection(roads, reserves).is_empty(),
		"%s 道路与花园保留区不重叠" % label
	)
	_check(
		profile.get("gate_slot_rects", []).size() == 4,
		"%s 保留四个统一城门槽位" % label
	)
	var fixed_cells: Dictionary = {}
	for node_name in profile.get("fixed_buildings", {}).keys():
		var rect: Rect2 = profile.fixed_buildings[node_name]
		var origin := Vector2i(floori(rect.position.x / 40.0), floori(rect.position.y / 40.0))
		var footprint := Vector2i(ceili(rect.size.x / 40.0), ceili(rect.size.y / 40.0))
		for cell in CITY_GRID_RULES.get_covered_cells(origin, footprint):
			_check(not fixed_cells.has(cell), "%s 固定建筑无相互重叠" % label)
			fixed_cells[cell] = true
		_check(
			_cells_intersection(_array_to_dict(CITY_GRID_RULES.get_covered_cells(origin, footprint)), roads).is_empty(),
			"%s 固定建筑不压占正式道路" % label
		)


func _cells_from_rects(rects: Array) -> Dictionary:
	var cells: Dictionary = {}
	for rect_value in rects:
		var rect: Rect2i = rect_value
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells[Vector2i(x, y)] = true
	return cells


func _array_to_dict(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for cell in cells:
		result[cell] = true
	return result


func _cells_intersection(left: Dictionary, right: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell in left:
		if right.has(cell):
			result[cell] = true
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("R3B_CITY_LAYOUT_PROFILES_SMOKE=PASS")
		quit(0)
	else:
		print("R3B_CITY_LAYOUT_PROFILES_SMOKE=FAIL count=%d" % failures.size())
		quit(1)
