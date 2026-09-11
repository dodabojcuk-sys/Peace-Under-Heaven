extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FIELD_WATCHTOWER_R0_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-field-watchtower-evidence-dir=")
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	# Isolate authority for this evidence run. The camp is a finished Field camp
	# fixture; existing Field R2 coverage owns the road-project-to-camp lifecycle.
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	city.food = 80
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	field.camps_by_id[&"camp.watchtower.graphical"] = {
		"camp_id": &"camp.watchtower.graphical", "point_id": &"camp.watchtower.graphical.point",
		"road_id": &"road.blackstone.northwatch.ridge", "display_name": "林间工程驻点",
		"world_position": Vector2i(360, 610), "durability": 80, "connected": true,
	}
	field.patrols_by_id[&"patrol.watchtower.graphical"] = {
		"patrol_id": &"patrol.watchtower.graphical", "current_point_id": &"", "world_position": Vector2i(700, 620),
		"strength": 3, "phase": &"PATROL", "route_point_ids": [], "last_engagement": {},
	}
	var engineer_result: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_result.get("specialist", {})).get("specialist_id", &""))
	scene.open_macro_march_r0()
	await process_frame
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro._camera_center = Vector2(560, 540)
	macro._camera_zoom = 0.60
	macro.refresh()
	city.set_city_time_paused(true)
	var blackstone_screen := macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	_click_map(macro, blackstone_screen)
	await process_frame
	macro.refresh()
	var engineer_selected := macro._selected_specialist_id == engineer_id \
		and macro._watchtower_button.is_inside_tree() \
		and macro._watchtower_button.visible \
		and not macro._watchtower_button.disabled
	_capture("watchtower-01-engineer-selected-engine-gui.png")
	# Map press/release above is GUI pointer evidence. The visible Button is
	# asserted, then its connected action is exercised separately because this
	# SceneTree runner cannot synthesize a native Control click.
	macro._watchtower_button.pressed.emit()
	await process_frame
	macro.refresh()
	var camp_screen := macro._world_to_screen(Vector2(360, 610))
	_click_map(macro, camp_screen)
	var target_world := Vector2i(440, 620)
	_click_map(macro, macro._world_to_screen(Vector2(target_world)))
	await process_frame
	macro.refresh()
	var food_before := int(city.food)
	var draft: Dictionary = macro._watchtower_draft.duplicate(true)
	var preview_visible := macro._watchtower_mode \
		and bool(draft.get("valid", false)) \
		and macro._confirm_button.is_inside_tree() \
		and macro._confirm_button.visible \
		and not macro._confirm_button.disabled \
		and int(city.food) == food_before \
		and macro._detail_label.text.contains("瞭望塔施工计划")
	_capture("watchtower-02-plan-preview-engine-gui.png")
	macro._confirm_button.pressed.emit()
	await process_frame
	macro.refresh()
	var projects: Dictionary = Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {}))
	var project := _first_project(projects)
	var started_once := not project.is_empty() \
		and StringName(project.get("project_kind", &"")) == &"WATCHTOWER" \
		and int(city.food) == food_before - int(draft.get("food_cost", 0)) \
		and macro._watchtower_draft.is_empty()
	_capture("watchtower-03-engineer-travel-engine-gui.png")
	city.set_city_time_paused(false)
	city.advance_war_loop_time(int(project.get("travel_milliseconds", 0)) + int(project.get("required_milliseconds", 0)))
	city.set_city_time_paused(true)
	await process_frame
	macro.refresh()
	var towers: Dictionary = Dictionary(city.get_field_tactics_read_model().get("watchtowers_by_id", {}))
	var intel: Dictionary = Dictionary(city.get_field_tactics_read_model().get("intel_by_subject_id", {}))
	var displayed_tower: Node = macro._low_poly_presentation._point_root.find_child("FieldWatchtower", true, false)
	var completed_visible: bool = towers.size() == 1 \
		and StringName(Dictionary(intel.get(&"patrol.watchtower.graphical", {})).get("fog_state", &"")) == FieldTacticsState.FOG_VISIBLE \
		and displayed_tower != null
	_capture("watchtower-04-complete-and-vision-engine-gui.png")
	_check(engineer_selected, "地图 GUI 点击选中工程师后，右栏显示可用的建瞭望塔操作")
	_check(preview_visible, "工程驻点与合法陆地的 GUI 点击保留瞭望塔计划，确认前不扣粮")
	_check(started_once, "可见开工按钮的连接动作只创建一项瞭望塔工程并扣除一次预览费用")
	_check(completed_visible, "工程师按 Controller 世界时间到场完工后，地图塔、低模节点与由塔获得的真实敌情同时出现")
	print("FIELD_WATCHTOWER_R0_GUI_EVIDENCE map_pointer_input=true button_action_signal=true fixture_finished_camp=true")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FIELD_WATCHTOWER_R0_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_WATCHTOWER_R0_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _click_map(macro: MacroMarchR0, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	macro._on_gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	macro._on_gui_input(release)


func _first_project(projects: Dictionary) -> Dictionary:
	var ids: Array = projects.keys()
	ids.sort()
	return Dictionary(projects.get(ids.front(), {})) if not ids.is_empty() else {}


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var image := root.get_texture().get_image()
	image.save_png(evidence_directory.path_join(filename))


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
