extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("RECOVERY_DEFENSE_EXPANSION_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-recovery-defense-evidence-dir=")
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(4)
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	await _frames(2)
	_capture("recovery-01-normal-city-population-engine-gui.png")

	# This fixture uses the formal controller commands but pre-creates one
	# connected engineering camp. It is layout/effect evidence, not a claim that
	# the player performed the entire campaign at normal speed in this runner.
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	var anchor := Vector2i(MacroMarchTheater.get_point(&"northwatch_garrison").get("world_position", Vector2i.ZERO))
	field.camps_by_id[&"camp.recovery.gui"] = {
		"camp_id": &"camp.recovery.gui", "point_id": &"northwatch_garrison",
		"road_id": &"road.blackstone.northwatch.ridge", "display_name": "北望防线驻点",
		"world_position": anchor, "durability": 80, "connected": true,
	}
	var dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(dispatch.get("specialist", {})).get("specialist_id", &""))
	var issued: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.recovery.gui", anchor + Vector2i(70, 0), FieldTacticsState.FACILITY_FORTRESS)
	var project := Dictionary(issued.get("project", {}))
	city.advance_war_loop_time(int(project.get("travel_milliseconds", 0)) + int(project.get("required_milliseconds", 0)))
	var fortress_id := StringName(project.get("tower_id", &""))

	scene.open_macro_march_r0()
	await _frames(4)
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro._camera_center = Vector2(anchor)
	macro._camera_zoom = 0.95
	macro._selected_specialist_id = engineer_id
	macro._selected_field_facility_id = fortress_id
	macro.refresh()
	await _frames(3)
	_capture("recovery-02-fortress-detail-engine-gui.png")

	var fortress := Dictionary(field.watchtowers_by_id.get(fortress_id, {}))
	var city_shell: Control = scene.get_node("UI/Shell")
	var governance: Control = city_shell.get_node("GovernanceWorkspace")
	var macro_detail: Label = macro._detail_label
	var valid := (
		governance.get_global_rect().end.y <= root.size.y
		and fortress_id != &""
		and StringName(fortress.get("facility_kind", &"")) == FieldTacticsState.FACILITY_FORTRESS
		and macro_detail.text.contains("外部战区")
		and macro_detail.text.contains("驻军")
	)
	print("RECOVERY_DEFENSE_EXPANSION_GUI_TRACE viewport=%s fortress=%s detail=%s" % [str(root.size), String(fortress_id), macro_detail.text.replace("\n", " / ")])
	scene.queue_free()
	await process_frame
	if valid:
		print("RECOVERY_DEFENSE_EXPANSION_GRAPHICAL_SMOKE PASS")
		quit(0)
		return
	push_error("RECOVERY_DEFENSE_EXPANSION_GRAPHICAL_SMOKE FAIL")
	quit(1)


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	root.get_texture().get_image().save_png(evidence_directory.path_join(filename))


func _frames(count: int) -> void:
	for _frame in range(maxi(count, 0)):
		await process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
