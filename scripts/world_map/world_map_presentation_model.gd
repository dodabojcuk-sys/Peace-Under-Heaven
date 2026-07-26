class_name WorldMapPresentationModel
extends RefCounted


const MAP_SIZE := Vector2(2400.0, 1500.0)
const HOME_NODE_ID := &"blackstone_city"
const DEMO_FORMATION_ID := &"blackstone_guard"

const NODE_CONFIGS := [
	{
		"id": &"blackstone_city",
		"name": "黑石城",
		"type": "主城",
		"owner": &"PLAYER",
		"position": Vector2(480.0, 760.0),
		"base_status": "安稳",
		"mission_ids": [],
	},
	{
		"id": &"north_slope_outpost",
		"name": "北坡哨站",
		"type": "哨站",
		"owner": &"PLAYER",
		"position": Vector2(860.0, 340.0),
		"base_status": "北部高地",
		"mission_ids": [&"noticeboard.outskirts_sweep.v0", &"noticeboard.missing_scout.v0"],
	},
	{
		"id": &"southern_village",
		"name": "南部村庄",
		"type": "村庄",
		"owner": &"FRIENDLY",
		"position": Vector2(870.0, 1150.0),
		"base_status": "友好",
		"mission_ids": [],
	},
	{
		"id": &"riverbend_supply_route",
		"name": "河湾粮道",
		"type": "粮道节点",
		"owner": &"NEUTRAL",
		"position": Vector2(1450.0, 760.0),
		"base_status": "危险",
		"mission_ids": [&"noticeboard.supply_relief.v0"],
	},
	{
		"id": &"riverbend_city",
		"name": "河湾城",
		"type": "城池",
		"owner": &"ENEMY",
		"position": Vector2(1970.0, 650.0),
		"base_status": "敌方控制",
		"mission_ids": [],
	},
]

const ROAD_CONFIGS := [
	{
		"id": &"blackstone_to_north_slope",
		"name": "黑石北道",
		"from": &"blackstone_city",
		"to": &"north_slope_outpost",
		"status": &"OPEN",
		"path": [
			Vector2(480.0, 760.0),
			Vector2(580.0, 610.0),
			Vector2(725.0, 455.0),
			Vector2(860.0, 340.0),
		],
	},
	{
		"id": &"blackstone_to_southern_village",
		"name": "南部驿道",
		"from": &"blackstone_city",
		"to": &"southern_village",
		"status": &"OPEN",
		"path": [
			Vector2(480.0, 760.0),
			Vector2(610.0, 900.0),
			Vector2(730.0, 1040.0),
			Vector2(870.0, 1150.0),
		],
	},
	{
		"id": &"north_slope_to_supply_route",
		"name": "北岭旧道",
		"from": &"north_slope_outpost",
		"to": &"riverbend_supply_route",
		"status": &"UNSCOUTED",
		"path": [
			Vector2(860.0, 340.0),
			Vector2(1050.0, 420.0),
			Vector2(1205.0, 590.0),
			Vector2(1450.0, 760.0),
		],
	},
	{
		"id": &"southern_village_to_supply_route",
		"name": "河湾南路",
		"from": &"southern_village",
		"to": &"riverbend_supply_route",
		"status": &"DANGEROUS",
		"path": [
			Vector2(870.0, 1150.0),
			Vector2(1080.0, 1080.0),
			Vector2(1260.0, 920.0),
			Vector2(1450.0, 760.0),
		],
	},
	{
		"id": &"supply_route_to_riverbend_city",
		"name": "河湾东关道",
		"from": &"riverbend_supply_route",
		"to": &"riverbend_city",
		"status": &"BLOCKED",
		"path": [
			Vector2(1450.0, 760.0),
			Vector2(1630.0, 700.0),
			Vector2(1805.0, 690.0),
			Vector2(1970.0, 650.0),
		],
	},
]


func build_snapshot(
	city_state: Dictionary,
	mission_catalog: Array[Dictionary]
) -> Dictionary:
	var mission_by_id: Dictionary = {}
	for mission in mission_catalog:
		var mission_id := StringName(mission.get("mission_id", &""))
		if mission_id != &"":
			mission_by_id[mission_id] = mission.duplicate(true)

	var nodes: Array[Dictionary] = []
	for config in NODE_CONFIGS:
		var node: Dictionary = config.duplicate(true)
		node["owner_label"] = owner_label(StringName(node.owner))
		node["status"] = _derive_node_status(
			StringName(node.id),
			str(node.base_status),
			city_state
		)
		node["garrison_summary"] = _derive_garrison_summary(
			StringName(node.id),
			city_state
		)
		var missions: Array[Dictionary] = []
		for mission_id in node.mission_ids:
			if mission_by_id.has(mission_id):
				missions.append(
					(mission_by_id[mission_id] as Dictionary).duplicate(true)
				)
		node["missions"] = missions
		nodes.append(node)

	var roads: Array[Dictionary] = []
	for config in ROAD_CONFIGS:
		var road: Dictionary = config.duplicate(true)
		road["status_label"] = road_status_label(StringName(road.status))
		roads.append(road)

	var available_infantry := maxi(
		int(
			city_state.get(
				"available_infantry_count",
				city_state.get("infantry_count", 0)
			)
		),
		0
	)
	return {
		"map_id": &"first_campaign_world_map_v0",
		"map_name": "黑石—河湾战役区域",
		"map_size": MAP_SIZE,
		"home_node_id": HOME_NODE_ID,
		"nodes": nodes,
		"roads": roads,
		"formation": {
			"id": DEMO_FORMATION_ID,
			"name": "黑石守备队",
			"owner": &"PLAYER",
			"owner_label": owner_label(&"PLAYER"),
			"position": Vector2(610.0, 835.0),
			"troop_summary": "可用步兵 %d" % available_infantry,
			"status": "驻扎黑石城",
			"position_source": &"NON_PERSISTENT_PRESENTATION_FIXTURE",
			"persistent": false,
		},
		"source_summary": {
			"day": int(city_state.get("day", 1)),
			"first_war_state": StringName(
				city_state.get("first_war_state", &"PREPARATION")
			),
			"city_fallen": bool(city_state.get("city_fallen", false)),
			"active_noticeboard_mission_id": StringName(
				city_state.get("active_noticeboard_mission_id", &"")
			),
		},
	}


func get_node(snapshot: Dictionary, node_id: StringName) -> Dictionary:
	for node in snapshot.get("nodes", []):
		if StringName(node.get("id", &"")) == node_id:
			return (node as Dictionary).duplicate(true)
	return {}


func get_road(snapshot: Dictionary, road_id: StringName) -> Dictionary:
	for road in snapshot.get("roads", []):
		if StringName(road.get("id", &"")) == road_id:
			return (road as Dictionary).duplicate(true)
	return {}


func build_route_preview(
	snapshot: Dictionary,
	target_node_id: StringName
) -> Dictionary:
	if target_node_id == &"":
		return {}
	if target_node_id == HOME_NODE_ID:
		return {
			"node_ids": [HOME_NODE_ID],
			"road_ids": [],
			"status": "编队当前驻扎黑石城",
			"contains_blocked_road": false,
		}

	var adjacency: Dictionary = {}
	for node in snapshot.get("nodes", []):
		adjacency[StringName(node.get("id", &""))] = []
	for road in snapshot.get("roads", []):
		var road_id := StringName(road.get("id", &""))
		var from_id := StringName(road.get("from", &""))
		var to_id := StringName(road.get("to", &""))
		if not adjacency.has(from_id) or not adjacency.has(to_id):
			continue
		adjacency[from_id].append({"node": to_id, "road": road_id})
		adjacency[to_id].append({"node": from_id, "road": road_id})
	for node_id in adjacency:
		adjacency[node_id].sort_custom(_sort_adjacency)

	var frontier: Array[StringName] = [HOME_NODE_ID]
	var previous_node: Dictionary = {HOME_NODE_ID: &""}
	var previous_road: Dictionary = {}
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		if current == target_node_id:
			break
		for edge in adjacency.get(current, []):
			var next_id := StringName(edge.node)
			if previous_node.has(next_id):
				continue
			previous_node[next_id] = current
			previous_road[next_id] = StringName(edge.road)
			frontier.append(next_id)

	if not previous_node.has(target_node_id):
		return {}

	var node_ids: Array[StringName] = []
	var road_ids: Array[StringName] = []
	var cursor := target_node_id
	while cursor != &"":
		node_ids.push_front(cursor)
		if cursor != HOME_NODE_ID:
			road_ids.push_front(StringName(previous_road[cursor]))
		cursor = StringName(previous_node[cursor])

	var contains_blocked := false
	var warnings: Array[String] = []
	for road_id in road_ids:
		var road := get_road(snapshot, road_id)
		var status := StringName(road.get("status", &""))
		if status == &"BLOCKED":
			contains_blocked = true
		if status != &"OPEN":
			warnings.append(
				"%s：%s" % [
					str(road.get("name", "")),
					road_status_label(status),
				]
			)
	return {
		"node_ids": node_ids,
		"road_ids": road_ids,
		"status": (
			"路线仅供预览，尚未实现正式行军"
			if warnings.is_empty()
			else "路线预览 · %s" % "；".join(warnings)
		),
		"contains_blocked_road": contains_blocked,
	}


func owner_label(owner: StringName) -> String:
	match owner:
		&"PLAYER":
			return "我方"
		&"ENEMY":
			return "敌方"
		&"FRIENDLY":
			return "友好"
		_:
			return "中立"


func road_status_label(status: StringName) -> String:
	match status:
		&"OPEN":
			return "畅通"
		&"DANGEROUS":
			return "危险"
		&"BLOCKED":
			return "封锁"
		&"UNSCOUTED":
			return "未侦察"
		_:
			return "状态未知"


func _derive_node_status(
	node_id: StringName,
	base_status: String,
	city_state: Dictionary
) -> String:
	if node_id == HOME_NODE_ID and bool(city_state.get("city_fallen", false)):
		return "城市失守"
	if node_id == &"north_slope_outpost":
		match StringName(city_state.get("first_war_state", &"PREPARATION")):
			&"WARNING":
				return "敌袭预警"
			&"PENDING":
				return "敌袭待处理"
			&"IN_BATTLE":
				return "战斗进行中"
			&"RESOLVED_VICTORY":
				return "北坡已守住"
			&"RESOLVED_RETREAT":
				return "我军已撤退"
			&"RESOLVED_DEFEAT":
				return "北坡失守"
	return base_status


func _derive_garrison_summary(
	node_id: StringName,
	city_state: Dictionary
) -> String:
	if node_id == HOME_NODE_ID:
		return "可用步兵 %d" % maxi(
			int(
				city_state.get(
					"available_infantry_count",
					city_state.get("infantry_count", 0)
				)
			),
			0
		)
	if node_id == &"north_slope_outpost":
		return "随北坡首战状态更新"
	return "尚未侦察"


func _sort_adjacency(left: Dictionary, right: Dictionary) -> bool:
	return str(left.node) < str(right.node)
