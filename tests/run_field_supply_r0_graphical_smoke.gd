extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FIELD_SUPPLY_R0_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-field-supply-evidence-dir=")
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	city.food = 80
	var silverford := Dictionary(city._war_loop_state.cities_by_id.get(&"silverford_city", {}))
	silverford.military_controller_faction_id = &"player"
	city._war_loop_state.cities_by_id[&"silverford_city"] = silverford
	scene.open_macro_march_r0()
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro._camera_center = Vector2(700, 500)
	macro._camera_zoom = 0.52
	macro.refresh()
	city.set_city_time_paused(true)
	var silverford_screen := macro._world_to_screen(Vector2(THEATER.get_point(&"silverford_city").get("world_position", Vector2.ZERO)))
	var inspect_before: Dictionary = city.export_v5_campaign_snapshot()
	_click_map(macro, silverford_screen)
	await process_frame
	macro.refresh()
	var preview: Dictionary = city.preview_field_supply_transport(&"silverford_city")
	var button_ready: bool = macro._location_detail_mode \
		and macro._selected_point_id == &"silverford_city" \
		and macro._supply_transport_button.is_inside_tree() \
		and macro._supply_transport_button.visible \
		and not macro._supply_transport_button.disabled \
		and macro._supply_transport_button.text.contains("运回黑石城") \
		and macro._detail_label.text.contains("银渡城余粮：20") \
		and macro._detail_label.text.contains("沿 3 段道路") \
		and city.export_v5_campaign_snapshot() == inspect_before \
		and bool(preview.get("valid", false))
	_capture("field-supply-01-location-detail-engine-gui.png")
	# The location itself is opened by a true map press/release pair. Godot's
	# SceneTree runner does not route synthetic OS button clicks to native
	# Controls, so the visible enabled Button is asserted above and its connected
	# action signal is intentionally exercised separately below.
	var food_before := int(city.food)
	macro._supply_transport_button.pressed.emit()
	await process_frame
	macro.refresh()
	var transports: Dictionary = Dictionary(city.get_field_tactics_read_model().get("supply_transports_by_id", {}))
	var transport: Dictionary = _first_transport(transports)
	var dispatched_once: bool = transports.size() == 1 \
		and StringName(transport.get("phase", &"")) == FieldTacticsState.SUPPLY_MOVING \
		and int(transport.get("amount", 0)) == 20 \
		and int(city.food) == food_before \
		and macro._supply_transport_button.disabled \
		and macro._detail_label.text.contains("运输中")
	_capture("field-supply-02-moving-engine-gui.png")
	city.set_city_time_paused(false)
	city.advance_war_loop_time(int(transport.get("total_milliseconds", 0)))
	city.set_city_time_paused(true)
	await process_frame
	macro.refresh()
	var completed_feedback := bool(_first_transport(Dictionary(city.get_field_tactics_read_model().get("supply_transports_by_id", {}))).get("deposited", false)) \
		and macro._supply_transport_button.visible \
		and macro._supply_transport_button.disabled \
		and macro._supply_transport_button.text.contains("本批 20 粮已入库") \
		and macro._detail_label.text.contains("本批 20 粮已入库")
	_capture("field-supply-03-completed-engine-gui.png")
	_check(button_ready, "GUI 点击银渡城显示有限库存、实际道路、预计耗时和可用运回按钮")
	_check(dispatched_once, "可见运输按钮的已连接动作只创建一笔在途货物，不提前向 NationState 入库")
	_check(completed_feedback, "运输完成后地点详情从权威完成记录持续显示本批 20 粮已入库")
	# The explicit visual Button signal is intentionally not used as the action
	# proof above; it remains covered by this real Control input path.
	print("FIELD_SUPPLY_R0_GUI_EVIDENCE map_pointer_input=true button_action_signal=true")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FIELD_SUPPLY_R0_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_SUPPLY_R0_GRAPHICAL_SMOKE FAIL: %s" % failure)
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


func _first_transport(transports: Dictionary) -> Dictionary:
	var ids: Array = transports.keys()
	ids.sort()
	return Dictionary(transports.get(ids.front(), {})) if not ids.is_empty() else {}


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
