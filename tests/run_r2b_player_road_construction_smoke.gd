extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const CITY_ROAD_DRAFT = preload("res://scripts/city_sandbox/city_road_draft.gd")
const CITY_GRID_RULES = preload("res://scripts/city_sandbox/city_grid_rules.gd")
const ROAD_ID := &"building.road.t1"
const LOGGING_ID := &"building.logging_camp.t1"

var failures: Array[String] = []
var confirm_signal_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var construction: Node = scene.get_node("ConstructionController")
	var map_controller: Node = scene
	var foundation: Node = scene.get_node(
		"MapWorld/RegularCitySpatialFoundation"
	)
	var construction_entry: Control = scene.get_node(
		"UI/Shell/ConstructionEntryPanel"
	)
	var construction_menu: Control = scene.get_node(
		"UI/Shell/ConstructionMenu"
	)
	var road_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/RoadButton"
	)
	var confirm_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/ConfirmRoadButton"
	)
	var build_mode_status: Label = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildModeStatus"
	)
	construction.set_city_time_paused(true)

	_check(
		road_button.text.contains("道路")
			and construction_menu.visible == false,
		"右侧目录保留真实道路入口且默认关闭"
	)
	_check(
		CITY_ROAD_DRAFT.build_draft(
			[Vector2i(18, 14), Vector2i(18, 19)]
		).valid,
		"道路草稿接受连续正交直线"
	)
	_check(
		not CITY_ROAD_DRAFT.build_draft(
			[Vector2i(18, 14), Vector2i(19, 15)]
		).valid,
		"道路草稿拒绝对角线"
	)
	var local_topology := {
		Vector2i(10, 10): true,
		Vector2i(11, 10): true,
		Vector2i(12, 10): true,
		Vector2i(11, 9): true,
		Vector2i(11, 11): true,
	}
	_check(
		CITY_GRID_RULES.get_road_mask(
			Vector2i(11, 10), local_topology
		) == CITY_GRID_RULES.MASK_NORTH
			| CITY_GRID_RULES.MASK_EAST
			| CITY_GRID_RULES.MASK_SOUTH
			| CITY_GRID_RULES.MASK_WEST,
		"道路拓扑掩码支持十字连接"
	)
	_check(
		CITY_GRID_RULES.get_road_mask(
			Vector2i(10, 10), local_topology
		) == CITY_GRID_RULES.MASK_EAST,
		"道路拓扑掩码支持端点"
	)

	var formal_roads: Dictionary = construction.get_formal_road_cells()
	_check(
		formal_roads.size() == foundation.get_formal_road_cells().size()
			and formal_roads.size() > 0,
		"玩家道路与正式道路共享唯一空间投影"
	)
	_check(
		not construction.evaluate_road_path(_cells([Vector2i(18, 14)])).valid,
		"重复选择正式道路不会产生零成本伪建造"
	)
	_check(
		str(construction.evaluate_road_path(_cells([Vector2i(22, 8)])).reason)
			== "道路占用保留区域",
		"道路拒绝中央保留区域"
	)
	_check(
		str(construction.evaluate_road_path(_cells([Vector2i(10, 0)])).reason)
			== "道路占用城墙",
		"道路拒绝城墙边界"
	)
	_check(
		str(construction.evaluate_road_path(
			_cells([Vector2i(18, 15), Vector2i(19, 16)])
		).reason) == "道路路径必须保持正交连续",
		"道路权威验证拒绝非连续折线"
	)

	var map_start: Vector2 = construction.map_local_to_screen(
		construction.cell_to_map_local(Vector2i(18, 14)) + Vector2(20.0, 20.0)
	)
	var map_end: Vector2 = construction.map_local_to_screen(
		construction.cell_to_map_local(Vector2i(18, 18)) + Vector2(20.0, 20.0)
	)
	construction.open_construction_menu()
	_check(construction_menu.visible, "打开右侧道路目录")
	road_button.emit_signal("pressed")
	_check(
		construction.is_road_placing()
			and construction_entry.visible
			and confirm_button.disabled,
		"选择道路进入拖拽模式且未固定前禁止确认"
	)
	var player_before: Dictionary = construction.get_player_road_cells()
	var wood_before: int = construction.wood
	_drag_via_root(map_controller, map_start, map_end)
	_check(
		construction.has_road_preview()
			and construction.preview_valid
			and construction.get_road_draft_snapshot().unique_cells.size() == 5
			and not confirm_button.disabled,
		"原生输入路径生成可确认的正交道路预览"
	)
	_check(
		build_mode_status.text.contains("道路工具")
			and build_mode_status.text.contains("已接入城市道路网络"),
		"连接状态和道路工具提示进入右栏"
	)
	confirm_signal_count = 0
	confirm_button.pressed.connect(_record_confirm_pressed)
	var count_before: int = construction.get_building_count()
	confirm_button.emit_signal("pressed")
	await process_frame
	var count_after_first: int = construction.get_building_count()
	var wood_after_first: int = construction.wood
	confirm_button.emit_signal("pressed")
	_check(confirm_signal_count == 2, "两次测试输入各触发一次确认 pressed 信号")
	_check(
		count_after_first == count_before + 4
			and construction.get_building_count() == count_after_first
			and wood_before - wood_after_first == 8
			and construction.get_player_road_cells().size() == 4
			and player_before.is_empty()
			and not construction.is_road_placing(),
		"道路确认通过唯一权威事务恰好创建新格并扣除精确成本"
	)
	_check(
		construction.get_road_draft_snapshot().is_empty(),
		"道路确认后清除草稿与局部预览"
	)

	var isolated_start: Vector2 = construction.map_local_to_screen(
		construction.cell_to_map_local(Vector2i(35, 24)) + Vector2(20.0, 20.0)
	)
	var isolated_end: Vector2 = construction.map_local_to_screen(
		construction.cell_to_map_local(Vector2i(37, 24)) + Vector2(20.0, 20.0)
	)
	construction.open_construction_menu()
	road_button.emit_signal("pressed")
	_drag_via_root(map_controller, isolated_start, isolated_end)
	_check(
		construction.preview_valid
			and construction.preview_connection_state == &"isolated"
			and build_mode_status.text.contains("琥珀"),
		"孤立道路以琥珀状态提示仍可铺设"
	)
	construction.cancel_road_preview()
	_check(
		construction.get_player_road_cells().size() == 4
			and construction.wood == wood_after_first
			and not construction.has_road_preview(),
		"取消孤立道路不扣资源、不写入道路"
	)

	var logging_id: int = construction.place_definition_at_cell(
		LOGGING_ID,
		Vector2i(18, 19),
		true,
		false,
		0
	)
	_check(logging_id > 0, "道路旁的伐木场通过既有建造权威写入")
	var road_before_day: Dictionary = construction.get_player_road_cells().duplicate(true)
	var wood_before_day: int = construction.wood
	construction.set_city_time_paused(false)
	_check(construction.advance_one_day_for_test(), "道路连接闭环推进一个正常日结")
	construction.set_city_time_paused(true)
	_check(
		construction.is_building_operational(logging_id)
			and construction.get_operational_status(logging_id).label
			.contains("运行中：入口已接路")
			and construction.wood == wood_before_day - 40 + 18,
		"连接道路使施工增量付清后在下一日运行并产出"
	)

	var snapshot: Dictionary = construction.export_v5_campaign_snapshot()
	_check(
		int(snapshot.schema_version) == 4
			and snapshot.placements.size() >= 5,
		"玩家道路复用 V4 placement 持久化"
	)
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	_check(
		bool(restored.restore_v5_campaign_snapshot(snapshot).success),
		"含玩家道路的 V5 快照可恢复"
	)
	_check(
		restored.get_player_road_cells() == road_before_day
			and restored.is_building_operational(logging_id)
			and restored.get_building_record(logging_id).orientation == 0,
		"重载后道路、生产连通派生和既有朝向保持"
	)
	var legacy_scene := CITY_SCENE.instantiate()
	root.add_child(legacy_scene)
	await process_frame
	await process_frame
	var legacy: Node = legacy_scene.get_node("ConstructionController")
	var legacy_snapshot: Dictionary = legacy.export_v5_campaign_snapshot()
	_check(
		bool(legacy.restore_v5_campaign_snapshot(legacy_snapshot).success)
			and legacy.get_player_road_cells().is_empty(),
		"不含道路 placement 的旧 V5 存档保持兼容并不伪造道路"
	)

	scene.queue_free()
	restored_scene.queue_free()
	legacy_scene.queue_free()
	await process_frame
	_finish()


func _drag_via_root(scene: Node, start: Vector2, finish: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	scene._input(press)

	var motion := InputEventMouseMotion.new()
	motion.position = finish
	scene._input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	scene._input(release)


func _record_confirm_pressed() -> void:
	confirm_signal_count += 1


func _cells(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(Vector2i(value))
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("R2B_PLAYER_ROAD_CONSTRUCTION_SMOKE PASS")
		quit(0)
	else:
		print("R2B_PLAYER_ROAD_CONSTRUCTION_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
