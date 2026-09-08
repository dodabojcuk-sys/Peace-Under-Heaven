extends SceneTree


const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const FIELD_TACTICS_STATE = preload("res://scripts/war/field_tactics_state.gd")
const WAR_LOOP_STATE = preload("res://scripts/war/war_loop_state.gd")
const ARMY_REGISTRY = preload("res://scripts/army/army_registry.gd")
const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const WAR_LOOP_RULES: WarLoopRules = preload("res://resources/war/war_loop_r1_rules.tres")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_parallel_army_contract()
	_run_field_tactics_contract()
	_run_r1_war_snapshot_migration()
	await _run_formal_controller_contract()
	await _run_damaged_road_resume_contract()
	await _run_mid_segment_camp_transfer_contract()
	_finish()


func _run_parallel_army_contract() -> void:
	var registry: ArmyRegistry = ARMY_REGISTRY.new()
	var left: Array = [{"formation_id": &"left", "definition_id": &"infantry", "display_name": "左队", "member_count": 6, "max_members": 6}]
	var right: Array = [{"formation_id": &"right", "definition_id": &"infantry", "display_name": "右队", "member_count": 7, "max_members": 7}]
	var first := registry.create_macro_march(&"player", &"blackstone_city", &"blackstone_city", &"northwatch_garrison", &"road.a", [Vector2i.ZERO, Vector2i.ONE], {&"infantry": 6}, left, 1, 100)
	var second := registry.create_macro_march(&"player", &"blackstone_city", &"blackstone_city", &"reedbank_garrison", &"road.b", [Vector2i.ZERO, Vector2i(2, 1)], {&"infantry": 7}, right, 1, 100)
	_check(not first.is_empty() and not second.is_empty() and registry.get_active_macro_armies().size() == 2, "两支不同编队可并行持有独立军令")
	var duplicate_snapshot := registry.get_snapshot()
	var duplicate_army: Dictionary = Dictionary(duplicate_snapshot.armies_by_id[second.army_id]).duplicate(true)
	duplicate_army.macro_march.formation_snapshots = left.duplicate(true)
	duplicate_army.units_by_definition_id = {&"infantry": 6}
	duplicate_snapshot.armies_by_id[second.army_id] = duplicate_army
	var duplicate_validation := ArmyRegistry.validate_snapshot(duplicate_snapshot, [&"infantry"], false)
	_check(not bool(duplicate_validation.valid) and StringName(duplicate_validation.error_id) == &"DUPLICATE_MACRO_FORMATION", "快照拒绝同一编队同时属于两支军队")
	var legacy_snapshot := registry.get_snapshot()
	Dictionary(legacy_snapshot.armies_by_id[first.army_id]).macro_march.erase("route_segments")
	var migrated_single_route := ArmyRegistry.validate_snapshot(legacy_snapshot, [&"infantry"], false)
	var legacy_path_snapshot := registry.get_snapshot()
	Dictionary(legacy_path_snapshot.armies_by_id[first.army_id]).macro_march.route_id = &"path.road.a:f|road.b:r"
	Dictionary(legacy_path_snapshot.armies_by_id[first.army_id]).route_id = &"path.road.a:f|road.b:r"
	Dictionary(legacy_path_snapshot.armies_by_id[first.army_id]).macro_march.erase("route_segments")
	var migrated_path_route := ArmyRegistry.validate_snapshot(legacy_path_snapshot, [&"infantry"], false)
	_check(
		bool(migrated_single_route.get("valid", false))
			and Array(Dictionary(Dictionary(migrated_single_route.snapshot).armies_by_id[first.army_id]).macro_march.get("route_segments", [])).size() == 1
			and bool(migrated_path_route.get("valid", false))
			and Array(Dictionary(Dictionary(migrated_path_route.snapshot).armies_by_id[first.army_id]).macro_march.get("route_segments", [])).size() == 2,
		"旧单路与复合路径句柄快照恢复时迁移为显式有向段序列"
	)


func _run_field_tactics_contract() -> void:
	var state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	state.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	var progress_path_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	progress_path_state.initialize_from_theater(
		{&"start": {"world_position": Vector2i(0, 0)}, &"bend": {"world_position": Vector2i(100, 100)}, &"camp": {"world_position": Vector2i(0, 200)}}, {}
	)
	progress_path_state.roads_by_id = {
		&"road.start.bend": {"road_id": &"road.start.bend", "source_point_id": &"start", "target_point_id": &"bend", "route_world_points": [Vector2i(0, 0), Vector2i(100, 0), Vector2i(100, 100)], "road_kind": FieldTacticsState.ROAD_NORMAL, "state": FieldTacticsState.ROAD_OPEN, "built": true},
		&"road.start.camp": {"road_id": &"road.start.camp", "source_point_id": &"start", "target_point_id": &"camp", "route_world_points": [Vector2i(0, 0), Vector2i(0, 200)], "road_kind": FieldTacticsState.ROAD_NORMAL, "state": FieldTacticsState.ROAD_OPEN, "built": true},
	}
	var progress_path := progress_path_state.plan_runtime_path_from_progress([{"road_id": &"road.start.bend", "forward": true}], 1000, 500, &"camp")
	var progress_points: Array = Array(progress_path.get("points", []))
	_check(
		bool(progress_path.get("valid", false)) and Vector2i(progress_path.get("current_position", Vector2i.ZERO)) == Vector2i(100, 0)
			and progress_points.size() >= 3 and Vector2i(progress_points[0]) == Vector2i(100, 0) and Vector2i(progress_points[1]) == Vector2i(0, 0),
		"临时路径从有向弯道路段中点沿原道路回退接入路网，不跳到或直切路口"
	)
	var bridge_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	bridge_state.initialize_from_theater(THEATER.get_points(), THEATER.get_routes(), [Rect2i(515, 350, 120, 145)])
	var bridge_engineer := bridge_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var bridge_project := bridge_state.begin_road_project(
		StringName(bridge_engineer.specialist_id), &"blackstone_city", &"camp.site.bridge",
		[Vector2i(150, 430), Vector2i(475, 420), Vector2i(710, 410)], FieldTacticsState.ROAD_NORMAL, true
	)
	_check(
		StringName(bridge_project.get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL
			and Array(bridge_project.get("segment_plans", [])).size() == 3
			and StringName(Dictionary(Array(bridge_project.get("segment_plans", []))[0]).get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL
			and StringName(Dictionary(Array(bridge_project.get("segment_plans", []))[1]).get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE
			and StringName(Dictionary(Array(bridge_project.get("segment_plans", []))[2]).get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL
			and int(bridge_project.get("required_milliseconds", 0)) == 21000,
		"战区 Resource 水域命中的工程线拆为道路、桥梁、道路的连续施工计划"
	)
	var reinforced_bridge_segments := bridge_state._build_construction_segment_plans(
		&"project.reinforced", &"blackstone_city", &"camp.site.reinforced",
		[Vector2i(150, 430), Vector2i(475, 420), Vector2i(710, 410)], FieldTacticsState.ROAD_REINFORCED, 99
	)
	_check(
		reinforced_bridge_segments.size() == 3
			and StringName(Dictionary(reinforced_bridge_segments.front()).get("road_kind", &"")) == FieldTacticsState.ROAD_REINFORCED
			and StringName(Dictionary(reinforced_bridge_segments[1]).get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE
			and StringName(Dictionary(reinforced_bridge_segments.back()).get("road_kind", &"")) == FieldTacticsState.ROAD_REINFORCED,
		"加固道路跨水时两岸保留加固材料，仅水域段成为桥梁"
	)
	var bridge_segments: Array = Array(bridge_project.get("segment_plans", []))
	var bridge_first_advance := bridge_state.advance_world(5000)
	var bridge_first_open := bridge_state.is_route_open(StringName(Dictionary(bridge_segments[0]).get("road_id", &"")))
	var bridge_middle_closed := not bridge_state.is_route_open(StringName(Dictionary(bridge_segments[1]).get("road_id", &"")))
	var bridge_engineer_position := Vector2i(Dictionary(bridge_state.specialists_by_id[StringName(bridge_engineer.specialist_id)]).get("world_position", Vector2i.ZERO))
	var bridge_start_position := Vector2i(Array(Dictionary(bridge_segments[1]).get("route_world_points", []))[0])
	bridge_state.advance_world(11000)
	var bridge_middle_open := bridge_state.is_route_open(StringName(Dictionary(bridge_segments[1]).get("road_id", &"")))
	var bridge_last_closed := not bridge_state.is_route_open(StringName(Dictionary(bridge_segments[2]).get("road_id", &"")))
	bridge_state.advance_world(5000)
	_check(
		bridge_first_open and bridge_middle_closed and bridge_middle_open and bridge_last_closed
			and bridge_engineer_position == bridge_start_position
			and bridge_state.is_route_open(StringName(Dictionary(bridge_segments[2]).get("road_id", &""))),
		"连续施工按道路、桥梁、道路顺序开放，未完成后段不会提前通军"
	)
	var first_bridge_plan: Dictionary = Dictionary(bridge_segments[0])
	_check(
		bridge_state._point_position(StringName(first_bridge_plan.get("target_point_id", &""))) == Vector2i(Array(first_bridge_plan.get("route_world_points", [])).back()),
		"自动生成的桥头连接点解析为实际路段端点，而非世界原点"
	)
	_check(
		Array(bridge_first_advance.get("opened_road_ids", [])).size() == 1
			and StringName(Array(bridge_first_advance.get("opened_road_ids", []))[0]) == StringName(Dictionary(bridge_segments[0]).get("road_id", &"")),
		"每个施工路段首次开放都会产生可发布的权威道路事件"
	)
	var travel_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	travel_state.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	travel_state.patrols_by_id.clear()
	var traveling_engineer := travel_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var travel_project := travel_state.begin_road_project(
		StringName(traveling_engineer.specialist_id), &"northwatch_garrison", &"camp.site.travel",
		[Vector2i(790, 170), Vector2i(860, 240)], FieldTacticsState.ROAD_NORMAL, true
	)
	var before_travel := Dictionary(travel_state.specialists_by_id[StringName(traveling_engineer.specialist_id)]).duplicate(true)
	travel_state.advance_world(int(before_travel.get("move_remaining_milliseconds", 0)))
	var arrived_for_work := Dictionary(travel_state.specialists_by_id[StringName(traveling_engineer.specialist_id)]).duplicate(true)
	travel_state.advance_world(2500)
	var working_engineer := Dictionary(travel_state.specialists_by_id[StringName(traveling_engineer.specialist_id)]).duplicate(true)
	_check(
		not travel_project.is_empty()
			and StringName(before_travel.get("phase", &"")) == FieldTacticsState.SPECIALIST_MOVING
			and StringName(arrived_for_work.get("phase", &"")) == FieldTacticsState.SPECIALIST_BUILDING
			and Vector2i(arrived_for_work.get("world_position", Vector2i.ZERO)) == Vector2i(790, 170)
			and Vector2i(working_engineer.get("world_position", Vector2i.ZERO)) != Vector2i(790, 170),
		"工程师先到达施工起点，再沿当前陆地作业段推进实际位置"
	)
	var interrupted_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	interrupted_state.initialize_from_theater(
		{&"resume.start": {"world_position": Vector2i(100, 100)}, &"resume.target": {"world_position": Vector2i(420, 100)}}, {}
	)
	var lost_engineer := interrupted_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"resume.start")
	var interrupted_project := interrupted_state.begin_road_project(
		StringName(lost_engineer.specialist_id), &"resume.start", &"resume.target",
		[Vector2i(100, 100), Vector2i(420, 100)], FieldTacticsState.ROAD_NORMAL, true
	)
	var lost_engineer_state := Dictionary(interrupted_state.specialists_by_id[StringName(lost_engineer.specialist_id)])
	lost_engineer_state.alive = false
	lost_engineer_state.phase = FieldTacticsState.SPECIALIST_LOST
	interrupted_state.specialists_by_id[StringName(lost_engineer.specialist_id)] = lost_engineer_state
	interrupted_state.advance_world(1)
	var replacement_engineer := interrupted_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"resume.start")
	var resumed_project := interrupted_state.resume_interrupted_project(StringName(replacement_engineer.specialist_id), StringName(interrupted_project.project_id))
	interrupted_state.advance_world(int(interrupted_project.required_milliseconds))
	_check(
		StringName(Dictionary(interrupted_state.projects_by_id[StringName(interrupted_project.project_id)]).get("engineer_id", &"")) == StringName(replacement_engineer.specialist_id)
			and StringName(resumed_project.get("project_id", &"")) == StringName(interrupted_project.project_id)
			and interrupted_state.is_route_open(StringName(interrupted_project.road_id))
			and not interrupted_state.camps_by_id.is_empty(),
		"工程师损失后可由新工程师接续原工程，不重建道路、营地或工程身份"
	)
	var land_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	land_state.initialize_from_theater(
		{&"land.start": {"world_position": Vector2i(80, 300)}, &"land.target": {"world_position": Vector2i(720, 300)}},
		{}, [Rect2i(300, 180, 190, 240)]
	)
	var land_engineer := land_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"land.start")
	var land_move := land_state.order_specialist_move(StringName(land_engineer.specialist_id), &"land.target")
	var land_route := Array(land_move.get("move_route_world_points", []))
	land_state.advance_world(int(land_move.get("move_total_milliseconds", 0)) / 2)
	var land_midpoint := Vector2i(Dictionary(land_state.specialists_by_id[StringName(land_engineer.specialist_id)]).get("world_position", Vector2i.ZERO))
	var land_route_clear := land_route.size() > 2
	for point_index in range(1, land_route.size()):
		land_route_clear = land_route_clear and not land_state._route_crosses_water([land_route[point_index - 1], land_route[point_index]])
	_check(
		land_route_clear and not land_state._point_is_in_water(land_midpoint),
		"专家移动保存并执行绕水陆地路径，位置不会沿直线穿过水域"
	)
	var legacy_specialist_snapshot := land_state.get_snapshot()
	Dictionary(legacy_specialist_snapshot.specialists_by_id[StringName(land_engineer.specialist_id)]).erase("move_route_world_points")
	var restored_land_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	restored_land_state.initialize_from_theater(
		{&"land.start": {"world_position": Vector2i(80, 300)}, &"land.target": {"world_position": Vector2i(720, 300)}},
		{}, [Rect2i(300, 180, 190, 240)]
	)
	var restored_land_valid := restored_land_state.restore_snapshot(legacy_specialist_snapshot)
	restored_land_state.initialize_from_theater(
		{&"land.start": {"world_position": Vector2i(80, 300)}, &"land.target": {"world_position": Vector2i(720, 300)}},
		{}, [Rect2i(300, 180, 190, 240)]
	)
	var restored_land_specialist := Dictionary(restored_land_state.specialists_by_id.get(StringName(land_engineer.specialist_id), {}))
	_check(
		restored_land_valid and StringName(restored_land_specialist.get("phase", &"")) == FieldTacticsState.SPECIALIST_MOVING
			and Array(restored_land_specialist.get("move_route_world_points", [])).size() > 2,
		"旧在途专家存档缺少路径时从保存位置重规划，避免回退为穿水直线"
	)
	var bridge_crossing_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	bridge_crossing_state.initialize_from_theater(
		{&"bridge.start": {"world_position": Vector2i(80, 300)}, &"bridge.target": {"world_position": Vector2i(720, 300)}},
		{}, [Rect2i(300, -180, 190, 1040)]
	)
	bridge_crossing_state.roads_by_id[&"road.bridge.bent"] = {
		"road_id": &"road.bridge.bent", "source_point_id": &"bridge.west", "target_point_id": &"bridge.east",
		"route_world_points": [Vector2i(299, 300), Vector2i(350, 230), Vector2i(440, 230), Vector2i(490, 300)],
		"road_kind": FieldTacticsState.ROAD_BRIDGE, "state": FieldTacticsState.ROAD_OPEN,
		"durability": 100, "max_durability": 100, "built": true,
	}
	var bridge_crossing_engineer := bridge_crossing_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"bridge.start")
	var bridge_crossing_move := bridge_crossing_state.order_specialist_move(StringName(bridge_crossing_engineer.specialist_id), &"bridge.target")
	var bridge_crossing_route: Array = Array(bridge_crossing_move.get("move_route_world_points", []))
	_check(
		not bridge_crossing_move.is_empty() and bridge_crossing_route.has(Vector2i(350, 230)) and bridge_crossing_route.has(Vector2i(440, 230)),
		"专家跨越已开放弯桥时保存桥梁折线，不以桥头直线缩短路径"
	)
	var repair_land_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	repair_land_state.initialize_from_theater(
		{&"repair.start": {"world_position": Vector2i(100, 100)}, &"repair.site": {"world_position": Vector2i(420, 100)}, &"repair.end": {"world_position": Vector2i(560, 100)}}, {}
	)
	repair_land_state.roads_by_id[&"road.repair.land"] = {
		"road_id": &"road.repair.land", "source_point_id": &"repair.site", "target_point_id": &"repair.end",
		"route_world_points": [Vector2i(420, 100), Vector2i(560, 100)],
		"road_kind": FieldTacticsState.ROAD_NORMAL, "state": FieldTacticsState.ROAD_DAMAGED,
		"durability": 0, "max_durability": 70, "built": true,
	}
	var repair_land_engineer := repair_land_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"repair.start")
	var repair_land_project := repair_land_state.begin_road_repair(StringName(repair_land_engineer.specialist_id), &"road.repair.land")
	_check(
		not repair_land_project.is_empty() and StringName(repair_land_project.get("target_point_id", &"")) == &"repair.site"
			and Array(Dictionary(repair_land_state.specialists_by_id[StringName(repair_land_engineer.specialist_id)]).get("move_route_world_points", [])).size() >= 2,
		"维修端点按工程师实际陆地路径选择，不要求先存在军队道路连接"
	)
	_check(state.is_route_open(&"road.blackstone.northwatch.ridge"), "主路进入运行时路网且默认可通行")
	var multi_path := state.plan_runtime_path(&"blackstone_city", &"reedbank_garrison")
	var multi_route_id := StringName(multi_path.get("route_id", &""))
	_check(
		bool(multi_path.get("valid", false))
			and Array(multi_path.get("segments", [])).size() >= 2
			and bool(state.validate_runtime_route(&"blackstone_city", &"reedbank_garrison", multi_route_id, Array(multi_path.get("points", []))).get("valid", false))
			and int(multi_path.get("duration_milliseconds", 0)) == state.runtime_route_duration_milliseconds(multi_route_id),
		"运行时路网将连续主路解析为有序路段路径，预览与权威时长使用同一条路径"
	)
	var lowland_points: Array = Array(Dictionary(state.roads_by_id[&"road.blackstone.northwatch.lowland"]).get("route_world_points", [])).duplicate(true)
	var ridge_points: Array = Array(Dictionary(state.roads_by_id[&"road.blackstone.northwatch.ridge"]).get("route_world_points", [])).duplicate(true)
	var northwatch_reedbank_points: Array = Array(Dictionary(state.roads_by_id[&"road.northwatch.reedbank"]).get("route_world_points", [])).duplicate(true)
	var lowland_draw := lowland_points.duplicate(true)
	lowland_draw.pop_back()
	lowland_draw.append_array(northwatch_reedbank_points)
	var ridge_draw := ridge_points.duplicate(true)
	ridge_draw.pop_back()
	ridge_draw.append_array(northwatch_reedbank_points)
	var lowland_path := state.plan_runtime_path(&"blackstone_city", &"reedbank_garrison", lowland_draw)
	var ridge_path := state.plan_runtime_path(&"blackstone_city", &"reedbank_garrison", ridge_draw)
	_check(
		bool(lowland_path.get("valid", false))
			and bool(ridge_path.get("valid", false))
			and StringName(Dictionary(Array(lowland_path.get("segments", [])).front()).get("road_id", &"")) == &"road.blackstone.northwatch.lowland"
			and StringName(Dictionary(Array(ridge_path.get("segments", [])).front()).get("road_id", &"")) == &"road.blackstone.northwatch.ridge",
		"同一起终点的两条多段路线按玩家绘线选择对应道路序列"
	)
	var long_path_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	var previous_point_id: StringName = &"long.route.00"
	for segment_index in range(13):
		var next_point_id := StringName("long.route.%02d" % (segment_index + 1))
		var road_id := StringName("road.long.%02d" % segment_index)
		long_path_state.roads_by_id[road_id] = {
			"road_id": road_id,
			"source_point_id": previous_point_id,
			"target_point_id": next_point_id,
			"route_world_points": [Vector2i(segment_index * 10, 0), Vector2i((segment_index + 1) * 10, 0)],
			"road_kind": FieldTacticsState.ROAD_NORMAL,
			"state": FieldTacticsState.ROAD_OPEN,
			"durability": 70,
			"max_durability": 70,
			"built": true,
			"project_id": &"",
		}
		previous_point_id = next_point_id
	var long_path := long_path_state.plan_runtime_path(&"long.route.00", &"long.route.13", [Vector2i(0, 0), Vector2i(130, 0)])
	_check(
		bool(long_path.get("valid", false)) and Array(long_path.get("segments", [])).size() == 13,
		"图搜索可规划超过十二段的连续合法路线，而不枚举所有简单路径"
	)
	var lowland_segments: Array = Array(lowland_path.get("segments", [])).duplicate(true)
	var lowland_path_points: Array = Array(lowland_path.get("points", [])).duplicate(true)
	var lowland_duration := int(lowland_path.get("duration_milliseconds", 0))
	var lowland_road: Dictionary = Dictionary(state.roads_by_id[&"road.blackstone.northwatch.lowland"])
	lowland_road.state = FieldTacticsState.ROAD_DAMAGED
	state.roads_by_id[&"road.blackstone.northwatch.lowland"] = lowland_road
	var first_segment_blocked := state.first_unavailable_route_segment(
		StringName(lowland_path.get("route_id", &"")), lowland_segments, lowland_path_points, 0, lowland_duration
	)
	var passed_segment_ignored := state.first_unavailable_route_segment(
		StringName(lowland_path.get("route_id", &"")), lowland_segments, lowland_path_points, lowland_duration - 1, lowland_duration
	)
	lowland_road = Dictionary(state.roads_by_id[&"road.blackstone.northwatch.lowland"])
	lowland_road.state = FieldTacticsState.ROAD_OPEN
	state.roads_by_id[&"road.blackstone.northwatch.lowland"] = lowland_road
	var northwatch_reedbank_road: Dictionary = Dictionary(state.roads_by_id[&"road.northwatch.reedbank"])
	northwatch_reedbank_road.state = FieldTacticsState.ROAD_DAMAGED
	state.roads_by_id[&"road.northwatch.reedbank"] = northwatch_reedbank_road
	var forward_segment_blocked := state.first_unavailable_route_segment(
		StringName(lowland_path.get("route_id", &"")), lowland_segments, lowland_path_points, lowland_duration - 1, lowland_duration
	)
	northwatch_reedbank_road = Dictionary(state.roads_by_id[&"road.northwatch.reedbank"])
	northwatch_reedbank_road.state = FieldTacticsState.ROAD_OPEN
	state.roads_by_id[&"road.northwatch.reedbank"] = northwatch_reedbank_road
	_check(
		first_segment_blocked == 0 and passed_segment_ignored == -1 and forward_segment_blocked == 1,
		"跨段行军只因当前或前方受损道路受阻，已走过道路不会误停"
	)
	var disconnected_route := StringName("path.road.blackstone.northwatch.lowland:f|road.reedbank.silverford:f")
	var disconnected := state.validate_runtime_route(&"blackstone_city", &"silverford_city", disconnected_route, [])
	_check(
		not bool(disconnected.get("valid", false)) and StringName(disconnected.get("error_id", &"")) == &"PATH_DISCONNECTED",
		"权威确认拒绝两段开放但端点不相连的道路序列"
	)
	var patrol_partition_start: FieldTacticsState = FIELD_TACTICS_STATE.new()
	patrol_partition_start.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	var patrol_one_step: FieldTacticsState = FIELD_TACTICS_STATE.new()
	var patrol_split_step: FieldTacticsState = FIELD_TACTICS_STATE.new()
	patrol_one_step.restore_snapshot(patrol_partition_start.get_snapshot())
	patrol_split_step.restore_snapshot(patrol_partition_start.get_snapshot())
	patrol_one_step.advance_world(7000)
	patrol_split_step.advance_world(2400)
	patrol_split_step.advance_world(4000)
	patrol_split_step.advance_world(600)
	var contact_partition_start: FieldTacticsState = FIELD_TACTICS_STATE.new()
	contact_partition_start.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	contact_partition_start.dispatch_specialist(FieldTacticsState.SPECIALIST_SCOUT, &"northwatch_garrison")
	var contact_one_step: FieldTacticsState = FIELD_TACTICS_STATE.new()
	var contact_split_step: FieldTacticsState = FIELD_TACTICS_STATE.new()
	contact_one_step.restore_snapshot(contact_partition_start.get_snapshot())
	contact_split_step.restore_snapshot(contact_partition_start.get_snapshot())
	contact_one_step.advance_world(2400)
	contact_split_step.advance_world(1000)
	contact_split_step.advance_world(1400)
	_check(
		Dictionary(patrol_one_step.get_snapshot().patrols_by_id) == Dictionary(patrol_split_step.get_snapshot().patrols_by_id)
			and Dictionary(contact_one_step.get_snapshot().patrols_by_id) == Dictionary(contact_split_step.get_snapshot().patrols_by_id)
			and Dictionary(contact_one_step.get_snapshot().specialists_by_id) == Dictionary(contact_split_step.get_snapshot().specialists_by_id)
			and StringName(contact_one_step.observe_subject(&"patrol.ridge.001").get("fog_state", &"")) == StringName(contact_split_step.observe_subject(&"patrol.ridge.001").get("fog_state", &""))
			and int(contact_one_step.observe_subject(&"patrol.ridge.001").get("known_strength", 0)) == int(contact_split_step.observe_subject(&"patrol.ridge.001").get("known_strength", 0)),
		"巡逻等待、到站余量和接敌切换均满足单次推进与拆分推进一致"
	)
	var hidden := state.observe_subject(&"patrol.ridge.001")
	_check(StringName(hidden.get("fog_state", &"")) == FieldTacticsState.FOG_UNOBSERVED and int(hidden.get("known_strength", 0)) == 0, "未侦察巡逻不泄露实时兵力")
	var scout := state.dispatch_specialist(FieldTacticsState.SPECIALIST_SCOUT, &"blackstone_city")
	state.order_specialist_move(StringName(scout.specialist_id), &"northwatch_garrison")
	state.advance_world(450)
	var scout_midway := Dictionary(state.specialists_by_id[scout.specialist_id])
	_check(Vector2(scout_midway.get("world_position", Vector2.ZERO)).distance_to(Vector2(150, 430)) > 1.0 and StringName(state.observe_subject(&"patrol.ridge.001").get("fog_state", &"")) == FieldTacticsState.FOG_UNOBSERVED, "侦察兵按实际坐标连续移动，远离视野时不泄露巡逻")
	state.advance_world(1349)
	_check(StringName(Dictionary(state.specialists_by_id[scout.specialist_id]).get("current_point_id", &"")) == &"blackstone_city", "侦察兵在途期间不提前到达或揭示敌情")
	state.advance_world(1)
	var observed := state.observe_subject(&"patrol.ridge.001")
	_check(StringName(observed.get("fog_state", &"")) == FieldTacticsState.FOG_OBSERVED and int(observed.get("known_strength", 0)) == 5 and not bool(Dictionary(state.specialists_by_id[scout.specialist_id]).get("alive", true)), "侦察兵到达实际位置后获得最后情报，并会在同一节点被巡逻击杀")
	state.advance_world(1000)
	var patrol_after_departure := Dictionary(state.patrols_by_id[&"patrol.ridge.001"])
	var historical_intel := state.observe_subject(&"patrol.ridge.001")
	_check(
		Vector2(patrol_after_departure.get("world_position", Vector2.ZERO)).distance_to(Vector2(790, 170)) > 1.0
			and StringName(historical_intel.get("fog_state", &"")) == FieldTacticsState.FOG_OBSERVED
			and Vector2i(historical_intel.get("last_known_world_position", Vector2i.ZERO)) == Vector2i(790, 170),
		"巡逻在等待后沿路线实际移动；失去观察后情报保留最后观察坐标而不追踪当前位置"
	)
	state.patrols_by_id.clear()
	var engineer := state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var project := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"reedbank_garrison", [Vector2i(150, 430), Vector2i(440, 570), Vector2i(850, 505)], FieldTacticsState.ROAD_NORMAL, true)
	_check(not project.is_empty() and not state.is_route_open(StringName(project.road_id)), "工程确认后保留施工事务，未完成道路不能提前通军")
	state.advance_world(int(project.required_milliseconds) - 1)
	_check(not state.is_route_open(StringName(project.road_id)), "施工进度未满时动态道路仍不可通行")
	state.advance_world(1)
	var completed_road := Dictionary(state.roads_by_id.get(StringName(project.road_id), {}))
	_check(state.is_route_open(StringName(project.road_id)) and not state.camps_by_id.is_empty(), "工程完成后道路与道路相连驻扎点同时成为正式运行时节点")
	var runtime_route := state.validate_runtime_route(&"blackstone_city", &"reedbank_garrison", StringName(project.road_id), Array(project.route_world_points))
	_check(bool(runtime_route.get("valid", false)) and state.runtime_route_duration_milliseconds(StringName(project.road_id)) >= 6000, "完工工程道路进入正式军令校验与行军时长计算")
	_check(state.damage_road(StringName(project.road_id), 999) and not state.is_route_open(StringName(project.road_id)), "敌方造成的真实路损会改变通行状态")
	var repair := state.begin_road_repair(StringName(engineer.specialist_id), StringName(project.road_id))
	var repair_project := Dictionary(repair)
	var repair_travel := int(Dictionary(state.specialists_by_id[StringName(engineer.specialist_id)]).get("move_total_milliseconds", 0))
	_check(
		not repair.is_empty()
			and StringName(repair_project.get("target_point_id", &"")) == &"reedbank_garrison"
			and not state.is_route_open(StringName(project.road_id)),
		"受损道路只从工程师当前可达的桥头或道路端点建立维修事务，不能隔空立即修好"
	)
	var repair_start_snapshot := state.get_snapshot()
	var one_step_repair: FieldTacticsState = FIELD_TACTICS_STATE.new()
	var split_step_repair: FieldTacticsState = FIELD_TACTICS_STATE.new()
	one_step_repair.restore_snapshot(repair_start_snapshot)
	split_step_repair.restore_snapshot(repair_start_snapshot)
	one_step_repair.advance_world(repair_travel + int(repair.required_milliseconds))
	split_step_repair.advance_world(repair_travel)
	split_step_repair.advance_world(int(repair.required_milliseconds))
	_check(
		Dictionary(one_step_repair.get_snapshot().roads_by_id) == Dictionary(split_step_repair.get_snapshot().roads_by_id)
			and Dictionary(one_step_repair.get_snapshot().projects_by_id) == Dictionary(split_step_repair.get_snapshot().projects_by_id)
			and Dictionary(one_step_repair.get_snapshot().specialists_by_id) == Dictionary(split_step_repair.get_snapshot().specialists_by_id)
			and one_step_repair.is_route_open(StringName(project.road_id)),
		"维修到场帧余量计入施工：一次推进与拆分推进得到相同道路和项目状态"
	)
	state.advance_world(repair_travel)
	_check(not state.is_route_open(StringName(project.road_id)), "工程师到达维修点的同一时间步不跳过维修工期")
	state.advance_world(int(repair.required_milliseconds) - 1)
	_check(not state.is_route_open(StringName(project.road_id)), "维修进度未完成时道路继续阻断军队通行")
	state.advance_world(1)
	var reverse_points := Array(project.route_world_points).duplicate(true)
	reverse_points.reverse()
	_check(
		state.is_route_open(StringName(project.road_id))
			and bool(state.validate_runtime_route(&"reedbank_garrison", &"blackstone_city", StringName(project.road_id), reverse_points).get("valid", false)),
		"工程师到场完成后恢复原道路身份，并允许同一路段反向往返"
	)
	state.order_specialist_move(StringName(engineer.specialist_id), &"blackstone_city")
	state.advance_world(int(Dictionary(state.specialists_by_id[StringName(engineer.specialist_id)]).get("move_total_milliseconds", 0)))
	var camp_project := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"camp.site.000001", [Vector2i(150, 430), Vector2i(355, 410), Vector2i(470, 355)], FieldTacticsState.ROAD_NORMAL, true)
	state.advance_world(int(camp_project.get("required_milliseconds", 0)))
	var runtime_points := state.get_runtime_points()
	_check(not camp_project.is_empty() and runtime_points.has(&"camp.site.000001") and state.validate_runtime_route(&"blackstone_city", &"camp.site.000001", StringName(camp_project.get("road_id", &"")), Array(camp_project.get("route_world_points", []))).get("valid", false), "玩家指定的新工程驻点以运行时坐标进入可通军路网")
	var concurrent_engineer := state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var first_concurrent := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"", [Vector2i(150, 430), Vector2i(275, 360)], FieldTacticsState.ROAD_NORMAL, true)
	var second_concurrent := state.begin_road_project(StringName(concurrent_engineer.specialist_id), &"blackstone_city", &"", [Vector2i(150, 430), Vector2i(285, 510)], FieldTacticsState.ROAD_NORMAL, true)
	_check(
		not first_concurrent.is_empty() and not second_concurrent.is_empty()
			and StringName(first_concurrent.target_point_id) != StringName(second_concurrent.target_point_id)
			and StringName(first_concurrent.camp_id) != StringName(second_concurrent.camp_id)
			and state.next_camp_sequence == 5,
		"两名工程师在首项完工前确认工程时分别保留不同驻点编号"
	)
	var snapshot := state.get_snapshot()
	var restored: FieldTacticsState = FIELD_TACTICS_STATE.new()
	_check(restored.restore_snapshot(snapshot) and restored.is_route_open(StringName(project.road_id)), "施工、驻点、道路与探索记录可随战役快照冷恢复")
	var invalid := snapshot.duplicate(true)
	invalid.next_project_sequence = 0
	_check(not FieldTacticsState.new().restore_snapshot(invalid), "无效战术快照在写入前被拒绝")


func _run_r1_war_snapshot_migration() -> void:
	var legacy := {
		"schema_version": 1,
		"cities_by_id": {},
		"required_city_ids": {},
		"active_siege": {},
		"completed_resolution_ids": {},
		"next_siege_sequence": 1,
	}
	var state: WarLoopState = WAR_LOOP_STATE.new()
	_check(state.restore_snapshot(legacy) and state.get_snapshot().has("field_tactics"), "R1 单攻城快照迁移为带战区状态的 R2 快照")
	var parallel: WarLoopState = WAR_LOOP_STATE.new()
	parallel.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	var silverford := parallel.get_city(&"silverford_city")
	silverford.surrender_allowed = false
	parallel.cities_by_id[&"silverford_city"] = silverford
	var red_siege := parallel.begin_siege(&"army.red", &"macro.order.000101", &"redcliff_city", 12, 100, 8, 1, 10000, WAR_LOOP_RULES)
	var silver_siege := parallel.begin_siege(&"army.silver", &"macro.order.000102", &"silverford_city", 12, 100, 8, 1, 10000, WAR_LOOP_RULES)
	var parallel_ticks := parallel.advance_parallel_sieges(WAR_LOOP_RULES)
	var parallel_snapshot := parallel.get_snapshot()
	var parallel_restored: WarLoopState = WAR_LOOP_STATE.new()
	_check(not red_siege.is_empty() and not silver_siege.is_empty() and parallel.get_active_sieges().size() == 2 and parallel_ticks.size() == 2 and parallel_restored.restore_snapshot(parallel_snapshot) and parallel_restored.get_active_sieges().size() == 2, "不同敌城可保留并推进独立攻城记录并冷恢复")


func _run_formal_controller_contract() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var lowland: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
	var first: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(ridge.route_id), Array(ridge.points))
	var second: Dictionary = city.commit_macro_march_from_city([StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(lowland.route_id), Array(lowland.points))
	_check(bool(first.get("success", false)) and bool(second.get("success", false)) and Array(city.get_macro_march_read_model().armies).size() == 2, "正式城市入口可对不同编队提交两支并行军令")
	var duplicate: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(ridge.route_id), Array(ridge.points))
	_check(not bool(duplicate.get("success", false)), "正式入口拒绝已经由第一支军队占用的编队")
	var scout: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	_check(bool(scout.get("success", false)) and bool(engineer.get("success", false)), "侦察兵和工程师通过正式城市资源事务派遣")
	var project: Dictionary = city.begin_field_road_project(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), &"blackstone_city", &"reedbank_garrison", [Vector2i(150, 430), Vector2i(515, 425), Vector2i(635, 425), Vector2i(850, 505)], FieldTacticsState.ROAD_NORMAL, true)
	var project_required_milliseconds := int(Dictionary(project.get("project", {})).get("required_milliseconds", 0))
	city.advance_war_loop_time(project_required_milliseconds)
	var field_model: Dictionary = city.get_field_tactics_read_model()
	var formal_segments: Array = Array(Dictionary(project.get("project", {})).get("segment_plans", []))
	_check(
		bool(project.get("success", false)) and not Dictionary(field_model.projects_by_id).is_empty() and not Dictionary(field_model.camps_by_id).is_empty()
			and formal_segments.size() >= 3
			and StringName(Dictionary(formal_segments.front()).get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL
			and StringName(Dictionary(formal_segments[1]).get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE
			and StringName(Dictionary(formal_segments.back()).get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL,
		"正式 Controller 入口保留陆地材料，仅将跨水区段规划为桥梁"
	)
	var bridge_crossing_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var bridge_crossing_specialist_id := StringName(Dictionary(bridge_crossing_dispatch.get("specialist", {})).get("specialist_id", &""))
	var bridge_crossing_move: Dictionary = city.order_field_specialist_move(bridge_crossing_specialist_id, &"reedbank_garrison")
	var generated_bridge_points: Array = Array(Dictionary(formal_segments[1]).get("route_world_points", []))
	var bridge_crossing_route: Array = Array(Dictionary(bridge_crossing_move.get("specialist", {})).get("move_route_world_points", []))
	city.advance_war_loop_time(int(Dictionary(bridge_crossing_move.get("specialist", {})).get("move_total_milliseconds", 0)))
	var bridge_crossing_after: Dictionary = Dictionary(city.get_field_tactics_read_model().specialists_by_id.get(bridge_crossing_specialist_id, {}))
	_check(
		bool(bridge_crossing_dispatch.get("success", false)) and bool(bridge_crossing_move.get("success", false))
			and bridge_crossing_route.has(generated_bridge_points.front()) and bridge_crossing_route.has(generated_bridge_points.back())
			and Vector2i(bridge_crossing_after.get("world_position", Vector2i.ZERO)) == Vector2i(850, 505),
		"正式工程生成的桥段、桥头和道路可被后续工程师实际跨越"
	)
	var bridge_return_move: Dictionary = city.order_field_specialist_move(bridge_crossing_specialist_id, &"blackstone_city")
	var bridge_return_route: Array = Array(Dictionary(bridge_return_move.get("specialist", {})).get("move_route_world_points", []))
	var legacy_specialist_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var legacy_war_loop: Dictionary = Dictionary(legacy_specialist_snapshot.war_loop)
	var legacy_field: Dictionary = Dictionary(legacy_war_loop.field_tactics)
	var legacy_specialists: Dictionary = Dictionary(legacy_field.specialists_by_id)
	var legacy_specialist: Dictionary = Dictionary(legacy_specialists[bridge_crossing_specialist_id])
	legacy_specialist.erase("move_route_world_points")
	legacy_specialists[bridge_crossing_specialist_id] = legacy_specialist
	legacy_field.specialists_by_id = legacy_specialists
	legacy_war_loop.field_tactics = legacy_field
	legacy_specialist_snapshot.war_loop = legacy_war_loop
	var canonical_legacy_validation: Dictionary = city.validate_v5_campaign_snapshot(legacy_specialist_snapshot)
	var legacy_restored_scene := CITY_SCENE.instantiate()
	root.add_child(legacy_restored_scene)
	await process_frame
	var legacy_restored: Node = legacy_restored_scene.get_node("ConstructionController")
	legacy_restored.set_process(false)
	var legacy_restore_result: Dictionary = legacy_restored.restore_v5_campaign_snapshot(legacy_specialist_snapshot)
	var legacy_restored_specialist: Dictionary = Dictionary(legacy_restored.get_field_tactics_read_model().specialists_by_id.get(bridge_crossing_specialist_id, {}))
	_check(
		bool(bridge_return_move.get("success", false))
			and bridge_return_route.has(generated_bridge_points.front()) and bridge_return_route.has(generated_bridge_points.back())
			and bool(canonical_legacy_validation.get("valid", false))
			and bool(legacy_restore_result.get("success", false))
			and Array(legacy_restored_specialist.get("move_route_world_points", [])).size() >= 2
			and legacy_restored.export_v5_campaign_snapshot() == Dictionary(canonical_legacy_validation.get("snapshot", {})),
		"正式 V5 恢复会以战区水域标准化旧专家路径，并保持严格快照核对"
	)
	legacy_restored_scene.queue_free()
	await process_frame
	city.advance_war_loop_time(int(Dictionary(bridge_return_move.get("specialist", {})).get("move_total_milliseconds", 0)))
	var bridge_return_after: Dictionary = Dictionary(city.get_field_tactics_read_model().specialists_by_id.get(bridge_crossing_specialist_id, {}))
	var generated_bridge_id := StringName(Dictionary(formal_segments[1]).get("road_id", &""))
	var field_state: FieldTacticsState = city._war_loop_state.field_tactics
	field_state.damage_road(generated_bridge_id, 999)
	var damaged_bridge_move: Dictionary = city.order_field_specialist_move(bridge_crossing_specialist_id, &"reedbank_garrison")
	var damaged_bridge_route: Array = Array(Dictionary(damaged_bridge_move.get("specialist", {})).get("move_route_world_points", []))
	_check(
		StringName(bridge_return_after.get("current_point_id", &"")) == &"blackstone_city"
			and not field_state._is_open_bridge_edge(Vector2(generated_bridge_points[0]), Vector2(generated_bridge_points[1]))
			and not damaged_bridge_route.has(generated_bridge_points.front()) and not damaged_bridge_route.has(generated_bridge_points.back()),
		"同一座正式生成桥可双向通行；损坏后不再作为任一方向的可通行桥面"
	)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restored_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(bool(restored_result.get("success", false)) and Array(restored.get_macro_march_read_model().armies).size() == 2 and not Dictionary(restored.get_field_tactics_read_model().camps_by_id).is_empty(), "两支军令与工程战区状态可在同一正式快照冷恢复")
	scene.queue_free()
	restored_scene.queue_free()
	await process_frame
	await _run_formal_multisegment_march_contract()


func _run_formal_multisegment_march_contract() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var lowland: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
	var northwatch_reedbank: Dictionary = THEATER.get_route(&"road.northwatch.reedbank")
	var draw_points := Array(lowland.points).duplicate(true)
	draw_points.pop_back()
	draw_points.append_array(Array(northwatch_reedbank.points))
	var plan: Dictionary = city.plan_field_path(&"blackstone_city", &"reedbank_garrison", draw_points)
	var route_id := StringName(plan.get("route_id", &""))
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"reedbank_garrison", route_id, Array(plan.get("points", []))
	)
	var issued_army: Dictionary = Dictionary(issued.get("army", {}))
	var issued_macro: Dictionary = Dictionary(issued_army.get("macro_march", {}))
	var food_after_issue := int(city.food)
	city._advance_all_macro_marches_seconds(float(int(plan.get("duration_milliseconds", 0))) / 1000.0)
	var arrived: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restore_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	var restored_army: Dictionary = restored._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	_check(
		bool(plan.get("valid", false))
			and bool(issued.get("success", false))
			and Array(issued_macro.get("route_segments", [])).size() == 2
			and StringName(Dictionary(Array(issued_macro.get("route_segments", [])).front()).get("road_id", &"")) == &"road.blackstone.northwatch.lowland"
			and StringName(arrived.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED
			and StringName(arrived.get("target_node_id", &"")) == &"reedbank_garrison"
			and int(city.food) == food_after_issue
			and bool(restore_result.get("success", false))
			and Array(Dictionary(restored_army.get("macro_march", {})).get("route_segments", [])).size() == 2,
		"正式绘线确认的多段军令保留段序列、连续抵达且冷恢复不重复扣粮"
	)
	scene.queue_free()
	restored_scene.queue_free()
	await process_frame


func _run_damaged_road_resume_contract() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 140
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var route_points := [Vector2i(150, 430), Vector2i(340, 470), Vector2i(480, 440)]
	var project: Dictionary = city.begin_field_road_project(
		StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
		&"blackstone_city", &"camp.site.resume", route_points, FieldTacticsState.ROAD_NORMAL, true
	)
	city.advance_war_loop_time(int(Dictionary(project.get("project", {})).get("required_milliseconds", 0)))
	var road_id := StringName(Dictionary(project.get("project", {})).get("road_id", &""))
	var roster: Array[Dictionary] = city.get_formation_roster()
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"camp.site.resume", road_id, route_points
	)
	var army_before_damage: Dictionary = Dictionary(issued.get("army", {}))
	var food_after_issue := int(city.food)
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.damage_road(road_id, 999)
	city._advance_all_macro_marches_seconds(1.0)
	var blocked: Dictionary = city._army_registry.get_army(StringName(army_before_damage.get("army_id", &"")))
	var repair: Dictionary = city.begin_field_road_repair(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), road_id)
	var repair_engineer := Dictionary(field.specialists_by_id[StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))])
	city.advance_war_loop_time(int(repair_engineer.get("move_remaining_milliseconds", 0)) + int(Dictionary(repair.get("project", {})).get("required_milliseconds", 0)))
	var resumed: Dictionary = city._army_registry.get_army(StringName(army_before_damage.get("army_id", &"")))
	city._advance_all_macro_marches_seconds(1.0)
	var advancing: Dictionary = city._army_registry.get_army(StringName(army_before_damage.get("army_id", &"")))
	_check(
		bool(project.get("success", false)) and bool(issued.get("success", false)) and bool(repair.get("success", false))
			and StringName(blocked.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED
			and StringName(resumed.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING
			and StringName(Dictionary(resumed.get("macro_march", {})).get("order_id", &"")) == StringName(Dictionary(army_before_damage.get("macro_march", {})).get("order_id", &""))
			and int(city.food) == food_after_issue - int(repair.get("food_cost", 0))
			and int(Dictionary(advancing.get("macro_march", {})).get("progress_millis", 0)) > int(Dictionary(resumed.get("macro_march", {})).get("progress_millis", 0)),
		"真实受损道路使军令就近受阻；到场维修后原 order 自动恢复且不重复扣行军粮"
	)
	scene.queue_free()
	await process_frame


## This goes through the production Controller rather than calling the Field
## planner alone.  The second original segment is damaged while the army is in
## the first curved segment, so a valid result must preserve the mid-road
## position and physically return along that curve before entering the camp
## branch.
func _run_mid_segment_camp_transfer_contract() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 200
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var camp_points := [Vector2i(150, 430), Vector2i(150, 555)]
	var project: Dictionary = city.begin_field_road_project(
		StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
		&"blackstone_city", &"camp.site.mid_transfer", camp_points, FieldTacticsState.ROAD_NORMAL, true
	)
	city.advance_war_loop_time(int(Dictionary(project.get("project", {})).get("required_milliseconds", 0)))
	var target_points := [Vector2i(790, 170), Vector2i(895, 245)]
	var target_project: Dictionary = city.begin_field_road_project(
		StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
		&"northwatch_garrison", &"camp.site.mid_target", target_points, FieldTacticsState.ROAD_NORMAL, true
	)
	city.advance_war_loop_time(int(Dictionary(target_project.get("project", {})).get("travel_milliseconds", 0)) + int(Dictionary(target_project.get("project", {})).get("required_milliseconds", 0)))
	var target_road_id := StringName(Dictionary(target_project.get("project", {})).get("road_id", &""))
	var lowland: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
	var drawn_points := Array(lowland.points).duplicate(true)
	drawn_points.pop_back()
	drawn_points.append_array(target_points)
	var main_plan: Dictionary = city.plan_field_path(&"blackstone_city", &"camp.site.mid_target", drawn_points)
	var roster: Array[Dictionary] = city.get_formation_roster()
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"camp.site.mid_target", StringName(main_plan.get("route_id", &"")), Array(main_plan.get("points", []))
	)
	var issued_army: Dictionary = Dictionary(issued.get("army", {}))
	var issued_macro: Dictionary = Dictionary(issued_army.get("macro_march", {}))
	var original_order_id := StringName(issued_macro.get("order_id", &""))
	var food_after_issue := int(city.food)
	# 4.5 seconds places the army just past the first lowland bend; returning
	# to the nearby camp is shorter than continuing to Northwatch.
	city._advance_all_macro_marches_seconds(4.5)
	var before_damage: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	var before_macro: Dictionary = Dictionary(before_damage.get("macro_march", {}))
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.damage_road(target_road_id, 999)
	city._advance_all_macro_marches_seconds(0.1)
	var blocked: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	var blocked_macro: Dictionary = Dictionary(blocked.get("macro_march", {}))
	var transfer: Dictionary = Dictionary(blocked_macro.get("blocked_transfer", {}))
	var transfer_points: Array = Array(transfer.get("route_world_points", []))
	var transfer_total_seconds := float(int(transfer.get("total_millis", 0))) / 1000.0
	city._advance_all_macro_marches_seconds(transfer_total_seconds)
	var stationed: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	var stationed_transfer: Dictionary = Dictionary(Dictionary(stationed.get("macro_march", {})).get("blocked_transfer", {}))
	var food_before_repair := int(city.food)
	var repair: Dictionary = city.begin_field_road_repair(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), target_road_id)
	var repairing_engineer: Dictionary = Dictionary(field.specialists_by_id[StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))])
	city.advance_war_loop_time(int(repairing_engineer.get("move_remaining_milliseconds", 0)) + int(Dictionary(repair.get("project", {})).get("required_milliseconds", 0)))
	var returning: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	var return_transfer: Dictionary = Dictionary(Dictionary(returning.get("macro_march", {})).get("blocked_transfer", {}))
	city._advance_all_macro_marches_seconds(float(int(return_transfer.get("total_millis", 0))) / 1000.0)
	city.advance_war_loop_time(1)
	var resumed: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	city._advance_all_macro_marches_seconds(1.0)
	var resumed_advancing: Dictionary = city._army_registry.get_army(StringName(issued_army.get("army_id", &"")))
	_check(
		bool(project.get("success", false)) and bool(target_project.get("success", false)) and bool(main_plan.get("valid", false)) and bool(issued.get("success", false)) and bool(repair.get("success", false))
			and int(before_macro.get("progress_millis", 0)) > 0
			and StringName(blocked.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED
			and StringName(transfer.get("phase", &"")) == &"TO_CAMP"
			and StringName(transfer.get("target_point_id", &"")) == &"camp.site.mid_transfer"
			and StringName(Dictionary(Array(transfer.get("route_segments", [])).front()).get("road_id", &"")) == &"road.blackstone.northwatch.lowland"
			and bool(Dictionary(Array(transfer.get("route_segments", [])).front()).get("partial", false))
			and transfer_points.size() >= 3
			and Vector2(transfer_points[0]).distance_to(Vector2(transfer_points[1])) > 1.0
			and int(blocked_macro.get("progress_millis", 0)) == int(before_macro.get("progress_millis", 0))
			and StringName(stationed_transfer.get("phase", &"")) == &"WAITING"
			and StringName(Dictionary(stationed.get("macro_march", {})).get("order_id", &"")) == original_order_id
			and food_before_repair == food_after_issue,
		"正式 Controller 在前方断路后从低洼弯道路中实际回退并转移到可达工程驻点，原令和粮食保持不变"
	)
	_check(
		StringName(return_transfer.get("phase", &"")) == &"TO_RESUME"
			and StringName(resumed.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING
			and StringName(Dictionary(resumed.get("macro_march", {})).get("order_id", &"")) == original_order_id
			and int(Dictionary(resumed_advancing.get("macro_march", {})).get("progress_millis", 0)) > int(Dictionary(resumed.get("macro_march", {})).get("progress_millis", 0)),
		"维修完成后军队先沿临时路径返回冻结位置，再以同一原军令继续行军"
	)
	scene.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("FIELD_TACTICS_R2_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_TACTICS_R2_SMOKE FAIL: %s" % failure)
	quit(1)
