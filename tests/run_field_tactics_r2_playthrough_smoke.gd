extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var _route_seed_snapshot: Dictionary = {}


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var terrain_kinds: Array[StringName] = []
	for terrain_value in THEATER.get_terrain_regions():
		terrain_kinds.append(StringName(Dictionary(terrain_value).get("kind", &"")))
	_check(
		THEATER.get_definition_id() == &"blackstone_playable_r2"
			and THEATER.get_points().has(&"forest_garrison")
			and THEATER.get_points().has(&"ridge_watch")
			and THEATER.get_water_regions().size() == 3
			and &"FOREST" in terrain_kinds and &"ROCKS" in terrain_kinds
			and not THEATER.get_route(&"road.forest.silverford.approach").is_empty(),
		"正式试玩加载独立战区 Resource，而不是只换色的综合回归布局"
	)
	await _capture_route_seed_snapshot()
	await _run_main_road_route()
	await _run_engineering_route()
	_finish()


## Route A and Route B must begin with the same authored theatre facts.  A
## configured V5 directory is useful for persistence workers, but its normal
## event publication would otherwise let Route B inherit Route A's resolved
## patrol and dispatched formations.  Restore one clean production snapshot at
## the start of each route; cross-process persistence remains separately tested.
func _capture_route_seed_snapshot() -> void:
	var seed_scene := CITY_SCENE.instantiate()
	root.add_child(seed_scene)
	await process_frame
	await process_frame
	var seed_city: Node = seed_scene.get_node("ConstructionController")
	_route_seed_snapshot = seed_city.export_v5_campaign_snapshot()
	if _route_seed_snapshot.is_empty():
		failures.append("正式试玩无法导出两条路线共用的干净 V5 基线")
	seed_scene.queue_free()
	await process_frame


func _run_main_road_route() -> void:
	var context := await _new_city()
	var city: Node = context.city
	var scene: Node = context.scene
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	scene.open_macro_march_r0()
	var route_start_world := int(city._war_loop_state.field_tactics.world_milliseconds)
	var initial_food: int = city.food
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_ids: Array[StringName] = []
	for formation in roster:
		formation_ids.append(StringName(formation.formation_id))
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var north_plan: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison", Array(ridge.points))
	var issue: Dictionary = _ui_confirm_march_from_city(macro_screen, formation_ids, Array(north_plan.points))
	var army_id := StringName(Dictionary(issue.get("army", {})).get("army_id", &""))
	_advance_until_phase(city, army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	var patrol := Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
	var patrol_wait := 0
	while army_id not in Array(patrol.get("resolved_army_ids", [])) and patrol_wait < 60000:
		city._process(0.1)
		patrol_wait += 100
		patrol = Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
	var after_patrol: Dictionary = city._army_registry.get_army(army_id)
	var count_after_patrol: int = city._macro_army_member_count(after_patrol)
	var red_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var red_issue: Dictionary = await _ui_confirm_march_from_station(macro_screen, army_id, Array(red_route.points))
	_advance_until_city_owned(city, &"redcliff_city", 30000)
	var silver_route: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
	var silver_issue: Dictionary = await _ui_confirm_march_from_station(macro_screen, army_id, Array(silver_route.points))
	_advance_until_city_owned(city, &"silverford_city", 30000)
	var final_army: Dictionary = city._army_registry.get_army(army_id)
	var elapsed := int(city._war_loop_state.field_tactics.world_milliseconds) - route_start_world
	var food_spent: int = initial_food - int(city.food)
	var casualties: int = 20 - city._macro_army_member_count(final_army)
	_check(
		initial_food == 80 and bool(issue.get("success", false))
			and army_id in Array(patrol.get("resolved_army_ids", []))
			and count_after_patrol < 20 and count_after_patrol > 0
			and bool(red_issue.get("success", false)) and bool(silver_issue.get("success", false))
			and bool(city.get_macro_march_read_model().get("level_cleared", false))
			and food_spent > 0 and city.food >= 0 and casualties > 0
			and StringName(final_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"主路正式路线从默认资源出征，经历有限巡逻伤亡后连续占领两座必占城"
	)
	print("R2_PLAYTHROUGH_ROUTE_A elapsed_ms=%d food_remaining=%d food_spent=%d army_casualties=%d specialist_losses=0" % [elapsed, city.food, food_spent, casualties])
	await _drop(context.scene)


func _run_engineering_route() -> void:
	var context := await _new_city()
	var city: Node = context.city
	var route_start_world := int(city._war_loop_state.field_tactics.world_milliseconds)
	var scene: Node = context.scene
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	scene.open_macro_march_r0()
	var initial_food: int = city.food
	var roster: Array[Dictionary] = city.get_formation_roster()
	# Both specialists enter through visible actions. The scout receives a real
	# map target before the player commits to the central crossing.
	macro_screen._scout_button.emit_signal("pressed")
	var scout_id := macro_screen._selected_scout_id
	var scout_dispatch := {"success": scout_id != &""}
	_ui_frame_world_points(macro_screen, [
		Vector2(THEATER.get_point(&"blackstone_city").world_position),
		Vector2(THEATER.get_point(&"ridge_watch").world_position),
	])
	var scout_target_click := InputEventMouseButton.new()
	scout_target_click.button_index = MOUSE_BUTTON_LEFT
	scout_target_click.pressed = true
	scout_target_click.position = macro_screen._world_to_screen(Vector2(THEATER.get_point(&"ridge_watch").world_position))
	macro_screen._on_gui_input(scout_target_click)
	scout_target_click = scout_target_click.duplicate()
	scout_target_click.pressed = false
	macro_screen._on_gui_input(scout_target_click)
	var scout_order := {
		"success": StringName(Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(scout_id, {})).get("phase", &"")) == FieldTacticsState.SPECIALIST_MOVING,
	}
	var scouting_elapsed := 0
	while scouting_elapsed < 12000:
		city._process(0.1)
		scouting_elapsed += 100
		var intel: Dictionary = city._war_loop_state.field_tactics.observe_subject(&"patrol.ridge.001")
		if StringName(intel.get("fog_state", &"")) != FieldTacticsState.FOG_UNOBSERVED:
			break
	# The reconnaissance route includes a real return order. The scout does not
	# linger on the patrol's departure point merely to manufacture a casualty.
	_advance_until_specialist_phase(city, scout_id, FieldTacticsState.SPECIALIST_IDLE, 16000)
	macro_screen._scout_button.emit_signal("pressed")
	_ui_frame_world_points(macro_screen, [
		Vector2(THEATER.get_point(&"ridge_watch").world_position),
		Vector2(THEATER.get_point(&"blackstone_city").world_position),
	])
	_ui_click_world(macro_screen, Vector2(THEATER.get_point(&"blackstone_city").world_position))
	_advance_until_specialist_phase(city, scout_id, FieldTacticsState.SPECIALIST_IDLE, 16000)
	macro_screen._engineer_button.emit_signal("pressed")
	var engineer_id := _active_engineer_id(city)
	var engineer_dispatch := {"success": engineer_id != &""}
	var bridge_points: Array = [
		Vector2i(135, 650), Vector2i(340, 635), Vector2i(500, 625),
		Vector2i(620, 615), Vector2i(760, 610),
	]
	var bridge_ui := _ui_confirm_engineering(
		macro_screen, engineer_id, &"blackstone_city", &"forest_garrison", bridge_points
	)
	var bridge_project: Dictionary = Dictionary(bridge_ui.get("project", {}))
	var bridge_project_id := StringName(bridge_project.get("project_id", &""))
	_advance_until_project_phase(city, bridge_project_id, &"COMPLETE", 40000)
	var completed_project := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(bridge_project_id, {}))
	var bridge_segment_ids: Array[StringName] = []
	for segment_value in Array(completed_project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		if StringName(segment.get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE:
			bridge_segment_ids.append(StringName(segment.get("road_id", &"")))
	var forest_plan: Dictionary = city.plan_field_path(&"blackstone_city", &"forest_garrison", bridge_points)
	var field_issue: Dictionary = _ui_confirm_march_from_city(
		macro_screen, [StringName(roster[0].formation_id), StringName(roster[1].formation_id), StringName(roster[2].formation_id)],
		Array(forest_plan.get("points", []))
	)
	var field_army_id := StringName(Dictionary(field_issue.get("army", {})).get("army_id", &""))
	var field_initial_count: int = city._macro_army_member_count(Dictionary(field_issue.get("army", {})))
	_advance_until_phase(city, field_army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	var ambush_wait := 0
	while ambush_wait < 40000:
		var patrol := Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
		if field_army_id in Array(patrol.get("ambush_consumed_army_ids", [])):
			break
		city._process(0.1)
		ambush_wait += 100
	var patrol_after_ambush := Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
	# The natural sample route now uses the completed crossing and the authored
	# eastern approach. Damage injection and recovery remain in their dedicated
	# fault-regression suite, so these metrics describe an actual player choice.
	var silver_route: Dictionary = THEATER.get_route(&"road.forest.silverford.approach")
	var silver_issue: Dictionary = await _ui_confirm_march_from_station(macro_screen, field_army_id, Array(silver_route.points))
	_advance_until_city_owned(city, &"silverford_city", 30000)
	var red_reverse_points := Array(THEATER.get_route(&"road.redcliff.silverford").points).duplicate(true)
	red_reverse_points.reverse()
	var red_plan: Dictionary = city.plan_field_path(&"silverford_city", &"redcliff_city", red_reverse_points)
	var red_issue: Dictionary = await _ui_confirm_march_from_station(macro_screen, field_army_id, Array(red_plan.get("points", [])))
	_advance_until_city_owned(city, &"redcliff_city", 40000)
	var final_army: Dictionary = city._army_registry.get_army(field_army_id)
	var army_casualties: int = field_initial_count - city._macro_army_member_count(final_army)
	var specialist_losses := 0
	var lost_specialist_roles: Array[String] = []
	for specialist_value in city._war_loop_state.field_tactics.specialists_by_id.values():
		var specialist: Dictionary = Dictionary(specialist_value)
		if not bool(specialist.get("alive", false)):
			specialist_losses += 1
			lost_specialist_roles.append(String(specialist.get("role", &"UNKNOWN")))
	var elapsed := int(city._war_loop_state.field_tactics.world_milliseconds) - route_start_world
	var food_spent: int = initial_food - int(city.food)
	var patrol_resolved := int(patrol_after_ambush.get("strength", -1)) == 0
	var ambush_count := Array(patrol_after_ambush.get("ambush_consumed_army_ids", [])).size()
	_check(
		initial_food == 80 and bool(engineer_dispatch.get("success", false))
			and bool(scout_dispatch.get("success", false)) and bool(scout_order.get("success", false))
			and not bridge_project.is_empty() and StringName(completed_project.get("phase", &"")) == &"COMPLETE" and not bridge_segment_ids.is_empty()
			and bool(field_issue.get("success", false))
			and patrol_resolved and ambush_count > 0
			and bool(silver_issue.get("success", false)) and bool(red_issue.get("success", false))
			and bool(city.get_macro_march_read_model().get("level_cleared", false))
			and elapsed > 0 and food_spent > 0 and city.food >= 0
			and army_casualties >= 0 and specialist_losses >= 0
			and StringName(final_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"工程自然路线从默认资源完成侦察、界面修桥、林地伏击及双城结算，不依赖断路注入或强制专家损失"
	)
	print("R2_PLAYTHROUGH_ROUTE_B elapsed_ms=%d food_remaining=%d food_spent=%d army_casualties=%d specialist_losses=%d lost_roles=%s ambushes=%d" % [
		elapsed, city.food, food_spent, army_casualties, specialist_losses, str(lost_specialist_roles), ambush_count,
	])
	await _drop(context.scene)


func _ui_confirm_engineering(
	macro_screen: MacroMarchR0,
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	points: Array
) -> Dictionary:
	macro_screen._selected_specialist_id = engineer_id
	macro_screen._build_side_road()
	_ui_frame_world_points(macro_screen, points)
	_ui_click_world(macro_screen, Vector2(points.front()))
	_ui_draw_world_route(macro_screen, points)
	var draft := macro_screen._engineering_draft.duplicate(true)
	var requested_target := StringName(draft.get("requested_target_point_id", &""))
	if requested_target != target_point_id or StringName(draft.get("source_point_id", &"")) != source_point_id:
		return {"draft": draft, "project": {}}
	macro_screen._confirm_draft()
	var field: Dictionary = macro_screen._dispatch_adapter.get_field_tactics_read_model()
	var specialist := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(engineer_id, {}))
	var project := Dictionary(Dictionary(field.get("projects_by_id", {})).get(StringName(specialist.get("project_id", &"")), {}))
	return {"draft": draft, "project": project}


func _ui_click_world(macro_screen: MacroMarchR0, world_position: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = macro_screen._world_to_screen(world_position)
	macro_screen._on_gui_input(click)
	click = click.duplicate()
	click.pressed = false
	macro_screen._on_gui_input(click)


func _ui_frame_world_points(macro_screen: MacroMarchR0, points: Array) -> void:
	if points.is_empty():
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point_value in points:
		minimum = minimum.min(Vector2(point_value))
		maximum = maximum.max(Vector2(point_value))
	var world_center := (minimum + maximum) * 0.5
	var bounds := THEATER.get_world_bounds()
	var normalized := (world_center - bounds.position) / bounds.size
	var minimap := macro_screen._minimap_rect()
	var minimap_click := InputEventMouseButton.new()
	minimap_click.button_index = MOUSE_BUTTON_LEFT
	minimap_click.pressed = true
	minimap_click.position = minimap.position + normalized * minimap.size
	macro_screen._on_gui_input(minimap_click)
	minimap_click = minimap_click.duplicate()
	minimap_click.pressed = false
	macro_screen._on_gui_input(minimap_click)
	for _step in 4:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = macro_screen._map_rect().get_center()
		macro_screen._on_gui_input(wheel)


func _ui_confirm_march_from_city(macro_screen: MacroMarchR0, formation_ids: Array[StringName], points: Array) -> Dictionary:
	macro_screen._selected_army_id = &""
	macro_screen._selected_formation_ids = formation_ids.duplicate()
	var before_ids: Array = macro_screen._dispatch_adapter.get_macro_march_read_model().armies.map(func(value): return StringName(Dictionary(value).get("army_id", &"")))
	_ui_frame_world_points(macro_screen, points)
	_ui_draw_world_route(macro_screen, points)
	macro_screen._confirm_draft()
	for army_value in Array(macro_screen._dispatch_adapter.get_macro_march_read_model().armies):
		var army: Dictionary = Dictionary(army_value)
		if StringName(army.get("army_id", &"")) not in before_ids:
			return {"success": true, "army": army}
	return {"success": false}


func _ui_confirm_march_from_station(macro_screen: MacroMarchR0, army_id: StringName, points: Array) -> Dictionary:
	if army_id == &"" or points.size() < 2:
		return {"success": false}
	_ui_frame_world_points(macro_screen, points)
	var source_world := Vector2(points.front())
	var target_world := Vector2(points.back())
	var before := _station_command_snapshot(macro_screen, army_id)
	print("R2_STATION_CONTINUATION_TRACE stage=before %s" % _station_command_trace(before, macro_screen))

	# The release-to-issue UI has no confirm button. First reject a locked army
	# released on its own camp, proving that the failed continuation has no food
	# or order side effect before the real Silverford/Redcliff release.
	var rejected := await _ui_direct_station_dispatch(macro_screen, army_id, source_world, source_world)
	var after_reject := _station_command_snapshot(macro_screen, army_id)
	var rejected_without_side_effect := not bool(rejected.get("success", false)) \
		and StringName(after_reject.get("order_id", &"")) == StringName(before.get("order_id", &"")) \
		and int(after_reject.get("food", -1)) == int(before.get("food", -2)) \
		and not macro_screen._direct_dispatch_pending \
		and macro_screen._draft_route.is_empty()
	print("R2_STATION_CONTINUATION_TRACE stage=rejected %s no_side_effect=%s" % [
		_station_command_trace(after_reject, macro_screen), str(rejected_without_side_effect),
	])

	var issued := await _ui_direct_station_dispatch(macro_screen, army_id, source_world, target_world)
	var after_issue := _station_command_snapshot(macro_screen, army_id)
	var expected_food_spent := int(issued.get("food_cost", 0))
	var success := bool(issued.get("success", false)) \
		and StringName(after_issue.get("army_id", &"")) == army_id \
		and StringName(after_issue.get("order_id", &"")) != StringName(before.get("order_id", &"")) \
		and int(before.get("food", -1)) - int(after_issue.get("food", -1)) == expected_food_spent \
		and rejected_without_side_effect
	print("R2_STATION_CONTINUATION_TRACE stage=issued %s success=%s expected_food_spent=%d" % [
		_station_command_trace(after_issue, macro_screen), str(success), expected_food_spent,
	])
	return {"success": success, "army": Dictionary(after_issue.get("army", {})), "rejected_without_side_effect": rejected_without_side_effect}


func _ui_direct_station_dispatch(
	macro_screen: MacroMarchR0,
	army_id: StringName,
	source_world: Vector2,
	target_world: Vector2
) -> Dictionary:
	var source_screen := macro_screen._world_to_screen(source_world)
	var target_screen := macro_screen._world_to_screen(target_world)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = source_screen
	macro_screen._on_gui_input(press)
	# Let the running scene consume real elapsed hold time. Calling a private
	# _process shortcut here would bypass the long-press contract under test.
	await create_timer(MacroMarchR0.DRAW_HOLD_SECONDS + 0.08).timeout
	await process_frame
	var option_index := -1
	for index in range(macro_screen._direct_dispatch_options.size()):
		var option: Dictionary = Dictionary(macro_screen._direct_dispatch_options[index])
		if StringName(option.get("kind", &"")) == &"ARMY" and StringName(option.get("army_id", &"")) == army_id:
			option_index = index
			break
	if option_index < 0:
		var missing := {"success": false, "error": "驻军未出现在长按选择条"}
		print("R2_STATION_CONTINUATION_TRACE stage=picker_missing options=%s" % str(macro_screen._direct_dispatch_options))
		return missing
	var option_motion := InputEventMouseMotion.new()
	option_motion.position = macro_screen._direct_dispatch_option_rect(option_index).get_center()
	macro_screen._on_gui_input(option_motion)
	var hovered_expected_army := macro_screen._direct_dispatch_hover_index == option_index
	var target_motion := InputEventMouseMotion.new()
	target_motion.position = target_screen
	macro_screen._on_gui_input(target_motion)
	var preview_food_cost := int(macro_screen._direct_dispatch_preview.get("food_cost", 0))
	# The expected destination comes from the authored theatre, independently of
	# the map hit-test used to drive this GUI gesture.  This prevents a mirrored
	# or stale projection from quietly certifying a different city as correct.
	var expected_target_id := _theater_point_id_at_world(target_world)
	var locked_expected_army := StringName(macro_screen._direct_dispatch_locked.get("army_id", &"")) == army_id
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target_screen
	macro_screen._on_gui_input(release)
	await process_frame
	var army := _army_from_macro_model(macro_screen, army_id)
	var order := Dictionary(army.get("macro_march", {}))
	return {
		"success": StringName(army.get("army_id", &"")) == army_id
			and StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING
			and StringName(order.get("target_point_id", &"")) == expected_target_id
			and hovered_expected_army and locked_expected_army,
		"army": army,
		"food_cost": preview_food_cost,
		"error": macro_screen._status_label.text,
	}


func _station_command_snapshot(macro_screen: MacroMarchR0, army_id: StringName) -> Dictionary:
	var model := macro_screen._dispatch_adapter.get_macro_march_read_model()
	var army := _army_from_macro_model(macro_screen, army_id)
	var order := Dictionary(army.get("macro_march", {}))
	return {
		"army": army,
		"army_id": StringName(army.get("army_id", &"")),
		"phase": StringName(army.get("phase", &"")),
		"target_node_id": StringName(army.get("target_node_id", &"")),
		"current_point_id": StringName(army.get("current_point_id", &"")),
		"order_id": StringName(order.get("order_id", &"")),
		"order_source": StringName(order.get("source_point_id", &"")),
		"order_target": StringName(order.get("target_point_id", &"")),
		"route_id": StringName(order.get("route_id", &"")),
		"food": int(model.get("food", -1)),
		"selected_army_id": macro_screen._selected_army_id,
		"selected_formation_ids": macro_screen._selected_formation_ids.duplicate(),
		"model_source_point_id": StringName(model.get("source_point_id", &"")),
	}


func _station_command_trace(snapshot: Dictionary, macro_screen: MacroMarchR0) -> String:
	return "army=%s phase=%s target_node=%s current_point=%s order=%s order_source=%s order_target=%s route=%s selected_army=%s formations=%s direct_pending=%s picker=%s locked=%s preview=%s error=%s status=%s" % [
		String(snapshot.get("army_id", &"")), String(snapshot.get("phase", &"")), String(snapshot.get("target_node_id", &"")), String(snapshot.get("current_point_id", &"")),
		String(snapshot.get("order_id", &"")), String(snapshot.get("order_source", &"")), String(snapshot.get("order_target", &"")), String(snapshot.get("route_id", &"")),
		String(macro_screen._selected_army_id), str(macro_screen._selected_formation_ids), str(macro_screen._direct_dispatch_pending), str(macro_screen._direct_dispatch_picker_open),
		str(macro_screen._direct_dispatch_locked), str(macro_screen._direct_dispatch_preview), macro_screen._direct_dispatch_error, macro_screen._status_label.text,
	]


func _army_from_macro_model(macro_screen: MacroMarchR0, army_id: StringName) -> Dictionary:
	for army_value in Array(macro_screen._dispatch_adapter.get_macro_march_read_model().get("armies", [])):
		var army: Dictionary = Dictionary(army_value)
		if StringName(army.get("army_id", &"")) == army_id:
			return army
	return {}


func _theater_point_id_at_world(world_position: Vector2) -> StringName:
	var point_ids: Array = THEATER.get_points().keys()
	point_ids.sort()
	for point_id_value in point_ids:
		var point_id := StringName(point_id_value)
		var point: Dictionary = THEATER.get_point(point_id)
		if Vector2(point.get("world_position", Vector2.INF)).distance_to(world_position) <= 0.1:
			return point_id
	return &""


func _ui_draw_world_route(macro_screen: MacroMarchR0, points: Array) -> void:
	if points.size() < 2:
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = macro_screen._world_to_screen(Vector2(points.front()))
	macro_screen._on_gui_input(press)
	macro_screen._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for point in points.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro_screen._world_to_screen(Vector2(point))
		macro_screen._on_gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = macro_screen._world_to_screen(Vector2(points.back()))
	macro_screen._on_gui_input(release)


func _advance_until_phase(city: Node, army_id: StringName, phase: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		if StringName(city._army_registry.get_army(army_id).get("phase", &"")) == phase:
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_city_owned(city: Node, city_id: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var cities: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).get("cities_by_id", {})
		if StringName(Dictionary(cities.get(city_id, {})).get("military_controller_faction_id", &"")) == &"player":
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_project_phase(city: Node, project_id: StringName, phase: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var project := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(project_id, {}))
		if StringName(project.get("phase", &"")) == phase:
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_specialist_phase(city: Node, specialist_id: StringName, phase: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var specialist := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(specialist_id, {}))
		if StringName(specialist.get("phase", &"")) == phase:
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_blocked_waiting(city: Node, army_id: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var army: Dictionary = city._army_registry.get_army(army_id)
		var transfer := Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
		if StringName(transfer.get("phase", &"")) == &"WAITING":
			return
		city._process(0.1)
		elapsed += 100


func _advance_world_milliseconds(city: Node, requested_milliseconds: int) -> void:
	var remaining := requested_milliseconds
	while remaining > 0:
		var step := mini(remaining, 100)
		city._process(float(step) / 1000.0)
		remaining -= step


func _repair_damaged_engineered_roads(city: Node) -> void:
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	var road_ids: Array = field.roads_by_id.keys()
	road_ids.sort()
	for road_id_value in road_ids:
		var road_id := StringName(road_id_value)
		var road: Dictionary = Dictionary(field.roads_by_id[road_id])
		if StringName(road.get("state", &"")) != FieldTacticsState.ROAD_DAMAGED or StringName(road.get("road_kind", &"")) == FieldTacticsState.ROAD_MAIN:
			continue
		var engineer_id := _active_engineer_id(city)
		if engineer_id == &"":
			return
		var repair: Dictionary = city.begin_field_road_repair(engineer_id, road_id)
		var project_id := StringName(Dictionary(repair.get("project", {})).get("project_id", &""))
		if bool(repair.get("success", false)) and project_id != &"":
			_advance_until_project_phase(city, project_id, &"COMPLETE", 30000)


func _active_engineer_id(city: Node) -> StringName:
	var ids: Array = city._war_loop_state.field_tactics.specialists_by_id.keys()
	ids.sort()
	for specialist_id_value in ids:
		var specialist: Dictionary = Dictionary(city._war_loop_state.field_tactics.specialists_by_id[specialist_id_value])
		if bool(specialist.get("alive", false)) and StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_ENGINEER and StringName(specialist.get("project_id", &"")) == &"":
			return StringName(specialist_id_value)
	return &""


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	if not _route_seed_snapshot.is_empty():
		var restored: Dictionary = city.restore_v5_campaign_snapshot(_route_seed_snapshot)
		if not bool(restored.get("success", false)):
			failures.append("正式试玩路线无法恢复共用的干净 V5 基线")
	city.set_process(false)
	return {"scene": scene, "city": city}


func _drop(scene: Node) -> void:
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
		print("FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE FAIL: %s" % failure)
	quit(1)
