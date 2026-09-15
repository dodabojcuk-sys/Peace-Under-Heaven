extends SceneTree

## Evidence runner for the short, authoritative Qingyuan engagement window.
## Preparation and march setup are compressed before REALTIME_SEGMENT_START.
## From that marker onward only the normal controller process and the visible
## 1x/pause/continue controls advance or stop campaign time.

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var output_directory := "/tmp/txwzs-regular-campaign-engagement-realtime"
var viewport_size := Vector2i(1280, 720)
var scene: Node2D
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_directory = arg.trim_prefix("--output=")
		elif arg.begins_with("--viewport="):
			var parts := arg.trim_prefix("--viewport=").split("x")
			if parts.size() == 2:
				viewport_size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(output_directory)
	root.size = viewport_size
	scene = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _hold_frames(4)
	city = scene.get_node("ConstructionController")
	city.set_process(false)
	_expect(city.initialize_regular_campaign(), "regular campaign initializes in an isolated store")
	runtime = city._regular_campaign
	city.show_regular_campaign()
	view = city._regular_campaign_view
	await _hold_frames(4)

	var formation_ids: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			formation_ids.append(formation.formation_id)
	_expect(bool(runtime.command(&"depart", {"formation_ids": formation_ids, "food": 30, "wood": 55}).get("success", false)), "compressed setup uses the existing departure transaction")
	runtime.advance(1.0)
	var armies: Array = runtime.get_read_model().get("armies", [])
	if armies.size() < 3:
		_expect(false, "three real formations exist after departure")
		_finish()
		return
	var assault_army_id := StringName(Dictionary(armies[1]).get("army_id", &""))
	_expect(bool(runtime.command(&"move", {"army_id": assault_army_id, "target_id": &"silverford_city"}).get("success", false)), "compressed setup submits the existing Silverford order")
	_advance_setup_until(func(): return not city._war_loop_state.is_enemy_city(&"silverford_city"), 180.0)
	_expect(bool(runtime.command(&"move", {"army_id": assault_army_id, "target_id": &"redcliff_city"}).get("success", false)), "compressed setup submits the existing Redcliff order")
	_advance_setup_until(func(): return not city._war_loop_state.get_siege(&"redcliff_city").is_empty(), 120.0)
	var starting_siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	_expect(not starting_siege.is_empty() and StringName(starting_siege.get("phase", &"")) == WarLoopState.PHASE_SIEGING, "real-time segment begins from the actual rejected-surrender siege")
	view.refresh(true)
	await _hold_frames(3)
	await _capture("00-realtime-siege-start.png")

	var one_x := _find_button_exact(view, "1×")
	var pause := _find_button_exact(view, "暂停")
	_expect(one_x != null and pause != null, "player-visible 1x and pause controls are available")
	if one_x == null or pause == null:
		_finish()
		return
	await _click_control(one_x)
	city.set_process(true)
	var segment_start_attempt_ms := int(runtime.data.attempt_elapsed_ms)
	var segment_start_tick := int(starting_siege.get("tick", 0))
	print("R1A_REALTIME_SEGMENT_START ", JSON.stringify({
		"attempt_ms": segment_start_attempt_ms,
		"siege_tick": segment_start_tick,
		"gate_hp": int(starting_siege.get("gate_hp", 0)),
		"attacker_count": _alive_count(starting_siege, true),
		"defender_count": _alive_count(starting_siege, false),
		"speed": city.get_city_time_speed(),
	}))

	# Give the player a short live read, then exercise the same visible pause
	# control used in ordinary play. No runtime.advance call occurs below.
	await _hold_realtime_frames(6)
	await _click_control(pause)
	var paused_siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	var paused_attempt_ms := int(runtime.data.attempt_elapsed_ms)
	await _hold_realtime_frames(24)
	_expect(city._war_loop_state.get_siege(&"redcliff_city") == paused_siege and int(runtime.data.attempt_elapsed_ms) == paused_attempt_ms, "visible pause freezes combat actions and campaign time")
	await _capture("01-realtime-paused.png")
	await _click_control(_find_button_exact(view, "暂停"))

	var gate_window_frames := await _wait_realtime_until(func():
		var siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
		return not siege.is_empty() and int(siege.get("gate_hp", 1)) == 0 and int(siege.get("defender_total_hp", 0)) > 0,
		120
	)
	var breached: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	_expect(not breached.is_empty() and int(breached.get("gate_hp", 1)) == 0 and int(breached.get("defender_total_hp", 0)) > 0, "normal-time playback reaches breached gate while defenders remain")
	await _capture("02-realtime-gate-breached.png")
	var completion_frames := await _wait_realtime_until(func(): return runtime.data.phase == &"PENDING", 360)
	_expect(runtime.data.phase == &"PENDING", "normal-time controller process reaches the existing pending result")
	view.refresh(true)
	await _capture("03-realtime-engagement-finished.png")

	var battle_ticks := segment_start_tick
	if not starting_siege.is_empty():
		# The final active record is removed by the established writeback, so the
		# total duration is reported from the known 250ms WarLoop tick and observed
		# normal-time attempt delta, excluding the visible paused interval.
		battle_ticks += maxi(0, (int(runtime.data.attempt_elapsed_ms) - segment_start_attempt_ms) / RegularCampaignRuntime.STEP_MS)
	print("R1A_REALTIME_SEGMENT_END ", JSON.stringify({
		"battle_game_ms": battle_ticks * RegularCampaignRuntime.STEP_MS,
		"visible_unpaused_game_ms": int(runtime.data.attempt_elapsed_ms) - segment_start_attempt_ms,
		"gate_breach_frames_after_continue": gate_window_frames,
		"completion_frames_after_breach": completion_frames,
		"paused_frames": 24,
		"phase": String(runtime.data.phase),
		"summary": Dictionary(runtime.data.summary).duplicate(true),
	}))
	_finish()


func _advance_setup_until(predicate: Callable, maximum_seconds: float) -> void:
	var elapsed := 0.0
	while not predicate.call() and elapsed < maximum_seconds:
		runtime.advance(0.25)
		elapsed += 0.25


func _hold_realtime_frames(count: int) -> void:
	for index in count:
		await process_frame
		if index % 2 == 0 and is_instance_valid(view):
			view.refresh()


func _wait_realtime_until(predicate: Callable, frame_limit: int) -> int:
	for frame in frame_limit:
		if predicate.call():
			view.refresh(true)
			return frame
		await process_frame
		if frame % 2 == 0:
			view.refresh()
	view.refresh(true)
	return frame_limit


func _alive_count(siege: Dictionary, attacker: bool) -> int:
	var prefix := "attacker" if attacker else "defender"
	return ceili(float(int(siege.get("%s_total_hp" % prefix, 0))) / float(maxi(1, int(siege.get("%s_hp_per_member" % prefix, 1)))))


func _find_button_exact(root_node: Node, text: String) -> Button:
	for child in root_node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.visible and button.text == text:
			return button
	return null


func _click_control(control: Control) -> void:
	await _click_position(control.get_global_rect().get_center())


func _click_position(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _hold_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _capture(filename: String) -> void:
	view.refresh(true)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_directory.path_join(filename)
	var result := image.save_png(path)
	_expect(result == OK, "capture saved: %s" % filename)
	print("R1A_REALTIME_IMAGE ", path, " pixels=", image.get_size())


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)


func _finish() -> void:
	print("R1A_REALTIME_ENGAGEMENT ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	if is_instance_valid(scene):
		scene.queue_free()
	quit(0 if failures.is_empty() else 1)
