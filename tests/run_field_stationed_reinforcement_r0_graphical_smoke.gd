extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FIELD_STATIONED_REINFORCEMENT_R0_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	THEATER.use_playable_definition()
	evidence_directory = _argument_value("--txwzs-field-reinforcement-evidence-dir=")
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	# Keep graphical evidence away from a player's active V5 store.
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city.food = 80
	city.set_process(false)
	city._ensure_war_loop_initialized()
	city._war_loop_state.field_tactics.patrols_by_id.clear()
	print("REINFORCEMENT_GUI_ROSTER count=%d food=%d" % [city.get_formation_roster().size(), city.food])
	var silverford := Dictionary(city._war_loop_state.cities_by_id.get(&"silverford_city", {}))
	silverford.military_controller_faction_id = &"player"
	city._war_loop_state.cities_by_id[&"silverford_city"] = silverford
	var stationed := _station_silverford(city)
	scene.open_macro_march_r0()
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro._camera_center = Vector2(850, 580)
	macro._camera_zoom = 0.58
	macro.refresh()
	city.set_city_time_paused(true)
	var silverford_screen := macro._world_to_screen(Vector2(THEATER.get_point(&"silverford_city").get("world_position", Vector2.ZERO)))
	_click_map(macro, silverford_screen)
	await process_frame
	macro.refresh()
	var map_selected_stationed := macro._selected_army_id == StringName(stationed.get("army_id", &"")) \
		and macro._location_details_button.is_inside_tree() and macro._location_details_button.visible
	macro._location_details_button.pressed.emit()
	await process_frame
	macro.refresh()
	var initial_detail := macro._location_detail_mode and macro._selected_point_id == &"silverford_city" \
		and map_selected_stationed and macro._detail_label.text.contains("当地待编兵员：4") and not macro._stationed_reinforcement_button.visible \
		and macro._location_garrison_buttons.size() == 1
	_capture("field-reinforcement-01-location-detail-engine-gui.png")
	# The map inspection above is an actual GUI press/release. SceneTree cannot
	# dispatch synthetic OS clicks to native Buttons, so we assert the in-tree
	# controls and exercise their already-connected action signal separately.
	macro._location_garrison_buttons.front().pressed.emit()
	await process_frame
	macro.refresh()
	var army_id := StringName(stationed.get("army_id", &""))
	var preview_detail := macro._selected_reinforcement_army_id == army_id \
		and macro._stationed_reinforcement_button.is_inside_tree() and macro._stationed_reinforcement_button.visible \
		and not macro._stationed_reinforcement_button.disabled and macro._stationed_reinforcement_button.text == "补充 4 人" \
		and macro._detail_label.text.contains("北门先锋 7/20 +4")
	_capture("field-reinforcement-02-selected-army-engine-gui.png")
	var members_before := _members(city._army_registry.get_army(army_id))
	macro._stationed_reinforcement_button.pressed.emit()
	await process_frame
	macro.refresh()
	var after: Dictionary = city._army_registry.get_army(army_id)
	var committed := _members(after) == members_before + 4 \
		and int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1)) == 0 \
		and macro._stationed_reinforcement_button.visible and macro._stationed_reinforcement_button.disabled \
		and macro._detail_label.text.contains("当地已无可补充兵源")
	print("REINFORCEMENT_GUI_COMMIT members=%d->%d stock=%d status=%s" % [members_before, _members(after), int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1)), macro._status_label.text])
	_capture("field-reinforcement-03-completed-engine-gui.png")
	_check(initial_detail, "地图 GUI 点击已占领银渡城后显示当地兵源，并要求玩家明确选择实际驻军")
	_check(preview_detail, "选定驻军后地点详情显示编队现有人数、上限、稳定分配和可用补员按钮")
	_check(committed, "可见补员按钮的连接动作只增加所选驻军一次并耗尽权威地点兵源")
	print("FIELD_STATIONED_REINFORCEMENT_R0_GUI_EVIDENCE map_pointer_input=true button_action_signal=true")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FIELD_STATIONED_REINFORCEMENT_R0_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_STATIONED_REINFORCEMENT_R0_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _station_silverford(city: Node) -> Dictionary:
	var roster: Array = city.get_formation_roster()
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"silverford_city")
	if roster.is_empty() or not bool(route.get("valid", false)):
		return {}
	var issued: Dictionary = city.commit_macro_march_from_city([StringName(Dictionary(roster.front()).get("formation_id", &""))], &"silverford_city", StringName(route.get("route_id", &"")), Array(route.get("points", [])))
	var army: Dictionary = Dictionary(issued.get("army", {}))
	if army.is_empty():
		return {}
	city.set_city_time_paused(false)
	for _step in range(400):
		city._process(0.1)
		var current: Dictionary = city._army_registry.get_army(StringName(army.get("army_id", &"")))
		if StringName(current.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED:
			return current
	return city._army_registry.get_army(StringName(army.get("army_id", &"")))


func _members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _click_map(macro: MacroMarchR0, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	macro._on_gui_input(press)
	var release := press.duplicate()
	release.pressed = false
	macro._on_gui_input(release)


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	root.get_texture().get_image().save_png(evidence_directory.path_join(filename))


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
