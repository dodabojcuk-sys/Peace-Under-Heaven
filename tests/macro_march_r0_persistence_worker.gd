extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var passed := false
	match mode:
		"A":
			city.food = 50
			var roster: Array[Dictionary] = city.get_formation_roster()
			var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
			var issued: Dictionary = city.commit_macro_march_from_city(
				[StringName(roster[0].formation_id)], &"northwatch_garrison",
				StringName(route.route_id), Array(route.points)
			)
			var army: Dictionary = issued.get("army", {})
			if bool(issued.success):
				var macro: Dictionary = army.macro_march
				var before := _progress_before_segment(
					Array(route.points), int(route.blockable_segment_index), int(macro.total_millis)
				)
				city.set_macro_march_route_blocked_for_scenario(StringName(route.route_id), true)
				city.block_macro_march_at_segment(
					StringName(army.army_id), StringName(macro.order_id),
					int(route.blockable_segment_index), before, &"临时路旁驻扎点"
				)
				passed = scene.flush_runtime_persistence(&"macro_worker_a")
		"B":
			var army: Dictionary = city.get_macro_march_army()
			var resumed: Dictionary = {}
			if StringName(army.phase) == ArmyRegistry.PHASE_BLOCKED:
				var macro: Dictionary = army.macro_march
				resumed = city.resume_blocked_macro_march(
					StringName(army.army_id), StringName(macro.order_id)
				)
			elif StringName(army.phase) == ArmyRegistry.PHASE_MARCHING:
				# Scenario-only road blocks are intentionally transient. The formal
				# scene can therefore resume the persisted BLOCKED order during startup.
				resumed = army
			if not resumed.is_empty():
				var resumed_macro: Dictionary = resumed.macro_march
				city._advance_all_macro_marches_seconds(
					float(int(resumed_macro.total_millis) - int(resumed_macro.progress_millis)) / 1000.0
				)
				var arrived: Dictionary = city.get_macro_march_army()
				passed = (
					StringName(arrived.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED
					and StringName(arrived.get("target_node_id", &"")) == &"northwatch_garrison"
					and scene.flush_runtime_persistence(&"macro_worker_b")
				)
			if not passed:
				print("MACRO_MARCH_WORKER_B_RESUMED %s" % JSON.stringify(resumed))
		"C":
			var army: Dictionary = city.get_macro_march_army()
			passed = (
				StringName(army.phase) == ArmyRegistry.PHASE_STATIONED
				and StringName(army.target_node_id) == &"northwatch_garrison"
			)
	if not passed:
		print("MACRO_MARCH_WORKER_%s_STATUS %s" % [mode, JSON.stringify(scene.get_runtime_persistence_status())])
		print("MACRO_MARCH_WORKER_%s_ARMY %s" % [mode, JSON.stringify(city.get_macro_march_army())])
	print("MACRO_MARCH_WORKER_%s %s pid=%d" % [mode, "PASS" if passed else "FAIL", OS.get_process_id()])
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _progress_before_segment(points: Array, segment_index: int, total_millis: int) -> int:
	var total := 0.0
	var prior := 0.0
	for index in range(1, points.size()):
		var length := Vector2(points[index - 1]).distance_to(Vector2(points[index]))
		total += length
		if index < segment_index:
			prior += length
	return roundi(float(total_millis) * prior / maxf(total, 1.0))
