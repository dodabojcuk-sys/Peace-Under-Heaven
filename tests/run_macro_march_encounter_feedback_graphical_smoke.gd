extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var assertions := 0
var failures: Array[String] = []
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MACRO_MARCH_ENCOUNTER_FEEDBACK_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _user_argument_value("--txwzs-encounter-evidence-dir=")
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(3)
	var city: Node = scene.get_node("ConstructionController")
	city.food = 120
	scene.open_macro_march_r0()
	await _frames(3)
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	var source_id: StringName = &"blackstone_city"
	var target_id: StringName = &"northwatch_garrison"
	var source_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	var target_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), target_id).get("world_position", Vector2.ZERO)))

	# The command itself takes the same GUI press/hold/strip/release path as the
	# player-facing map. Only later world time is advanced by the Controller.
	_send_press(macro, source_screen)
	await create_timer(MacroMarchR0.DRAW_HOLD_SECONDS + 0.08).timeout
	await process_frame
	var formation_index := _option_index(macro, &"FORMATION")
	var expected_formation_id := StringName(Dictionary(macro._direct_dispatch_options[formation_index] if formation_index >= 0 else {}).get("formation_id", &""))
	if formation_index >= 0:
		_send_motion(macro, macro._direct_dispatch_option_rect(formation_index).get_center())
		_send_motion(macro, target_screen)
	_send_release(macro, target_screen)
	await _frames(3)
	var issued_armies: Array = Array(macro._model().get("armies", []))
	var issued_army: Dictionary = Dictionary(issued_armies.front()) if not issued_armies.is_empty() else {}
	var issued_army_id := StringName(issued_army.get("army_id", &""))
	var issued_macro: Dictionary = Dictionary(issued_army.get("macro_march", {}))
	var formal_dispatch_once := issued_armies.size() == 1 \
		and expected_formation_id != &"" \
		and _macro_uses_formation(issued_macro, expected_formation_id)

	var food_after_dispatch := int(city.food)
	# Drive the same Controller _process path used by the running city: army,
	# patrol and feedback all advance together.  Four-times speed keeps the
	# graphical evidence concise without splitting army and patrol simulation.
	city.set_city_time_speed(4.0)
	var continuous_result := await _wait_for_natural_encounter(city, issued_army_id, 8.0)
	var encounters: Array = Array(continuous_result.get("encounters", []))
	macro._selected_army_id = issued_army_id
	macro.refresh()
	await _frames(2)
	var feedback: Dictionary = macro._encounter_feedback.duplicate(true)
	var contact_from_authority := not encounters.is_empty() \
		and not feedback.is_empty() \
		and Vector2(feedback.get("world_position", Vector2.ZERO)) == Vector2(Dictionary(encounters.front()).get("contact_world_position", Vector2.ZERO)) \
		and int(Dictionary(encounters.front()).get("contact_milliseconds", -1)) >= 0
	var own_after := int(feedback.get("own_after", -1))
	var patrol_after := int(feedback.get("patrol_after", -1))
	var battle_copy_matches_authority := macro._detail_label.text.contains("敌军损失") \
		and macro._detail_label.text.contains("我军剩 %d" % own_after) \
		and int(feedback.get("own_losses", -1)) == _losses_for_army(Dictionary(encounters.front()) if not encounters.is_empty() else {}, issued_army_id)
	var audio_played_once := macro._encounter_audio_play_count == 1
	var impact_image := await _capture_viewport_image()
	_capture_evidence(impact_image, "01-encounter-impact-engine-gui.png")

	# The event is already settled. Refreshing, pausing and changing speed must
	# neither replay the presentation nor change this army's settled facts.
	var army_after_encounter: Dictionary = city._army_registry.get_army(issued_army_id)
	var members_after_encounter: int = city._macro_army_member_count(army_after_encounter)
	var food_after_encounter := int(city.food)
	city.set_city_time_paused(true)
	await create_timer(0.12).timeout
	city.set_city_time_speed(2.0)
	await create_timer(0.12).timeout
	city.set_city_time_speed(1.0)
	macro.refresh()
	await _frames(2)
	var no_repeat_settlement: bool = macro._encounter_audio_play_count == 1 \
		and city._macro_army_member_count(city._army_registry.get_army(issued_army_id)) == members_after_encounter \
		and int(city.food) == food_after_encounter \
		and int(city.food) < 120 and int(city.food) == food_after_dispatch

	# Off-screen reports never steal camera focus when they arrive. The compact
	# notification is an explicit, clickable locate affordance instead.
	var camera_before_notification := macro._camera_center
	macro._camera_center = Vector2(-240, -170)
	macro._camera_zoom = 1.80
	macro.refresh()
	await _frames(2)
	var notice_image := await _capture_viewport_image()
	_capture_evidence(notice_image, "03-encounter-offscreen-notice-engine-gui.png")
	var notification_available := macro._encounter_notification_rect.has_area() \
		and macro._camera_center != Vector2(feedback.get("world_position", Vector2.ZERO))
	if notification_available:
		_send_click(macro, macro._encounter_notification_rect.get_center())
	await _frames(2)
	var notification_focuses_only_on_click := notification_available \
		and macro._camera_center != camera_before_notification \
		and macro._camera_center.distance_to(Vector2(feedback.get("world_position", Vector2.ZERO))) < 1.0
	# The local effect is transient. Let the normal scene process finish it and
	# keep the settled army moving/standing under the Controller rather than a
	# presentation-only time path.
	await create_timer(MacroMarchR0.ENCOUNTER_FEEDBACK_SECONDS + 0.10).timeout
	var feedback_finished_with_authority_intact: bool = macro._encounter_feedback.is_empty() \
		and city._macro_army_member_count(city._army_registry.get_army(issued_army_id)) == members_after_encounter
	print("ENCOUNTER_FEEDBACK_SETTLED audio=%d members=%d feedback=%s elapsed=%s food=%d" % [macro._encounter_audio_play_count, city._macro_army_member_count(city._army_registry.get_army(issued_army_id)), JSON.stringify(macro._encounter_feedback), str(float(macro._encounter_feedback.get("elapsed_seconds", -1.0))), int(city.food)])
	var result_image := await _capture_viewport_image()
	_capture_evidence(result_image, "02-encounter-result-engine-gui.png")

	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await _frames(3)
	var restored_city: Node = restored_scene.get_node("ConstructionController")
	restored_city.set_process(false)
	var restored_ok := bool(restored_city.restore_v5_campaign_snapshot(snapshot).get("success", false))
	restored_scene.open_macro_march_r0()
	await _frames(3)
	var restored_macro: MacroMarchR0 = restored_scene.get_node("UI/MacroMarchR0")
	restored_macro._selected_army_id = issued_army_id
	restored_macro.refresh()
	await _frames(2)
	var restore_does_not_replay: bool = restored_ok \
		and restored_macro._encounter_feedback.is_empty() \
		and restored_macro._encounter_audio_play_count == 0 \
		and restored_city._army_registry.get_army(issued_army_id) == city._army_registry.get_army(issued_army_id)

	# Legacy engagement summaries may contain only loss entries. Their restored
	# report must not borrow current army/patrol strength to manufacture history.
	var legacy_snapshot := snapshot.duplicate(true)
	var patrol_id := StringName(Dictionary(encounters.front() if not encounters.is_empty() else {}).get("patrol_id", &""))
	var legacy_war_loop: Dictionary = Dictionary(legacy_snapshot.get("war_loop", {}))
	var legacy_field: Dictionary = Dictionary(legacy_war_loop.get("field_tactics", {}))
	var legacy_patrols: Dictionary = Dictionary(legacy_field.get("patrols_by_id", {}))
	var legacy_patrol: Dictionary = Dictionary(legacy_patrols.get(patrol_id, {}))
	var legacy_encounter: Dictionary = Dictionary(legacy_patrol.get("last_engagement", {}))
	legacy_encounter.erase("army_strength_before_by_army")
	legacy_encounter.erase("army_strength_after_by_army")
	legacy_encounter.erase("army_phase_after_by_army")
	legacy_encounter.erase("patrol_strength_before")
	legacy_encounter.erase("patrol_strength_after")
	legacy_encounter.erase("patrol_losses")
	legacy_patrol.last_engagement = legacy_encounter
	legacy_patrols[patrol_id] = legacy_patrol
	legacy_field.patrols_by_id = legacy_patrols
	legacy_war_loop.field_tactics = legacy_field
	legacy_snapshot.war_loop = legacy_war_loop
	var legacy_scene := CITY_SCENE.instantiate()
	root.add_child(legacy_scene)
	await _frames(3)
	var legacy_city: Node = legacy_scene.get_node("ConstructionController")
	legacy_city.set_process(false)
	var legacy_ok := bool(legacy_city.restore_v5_campaign_snapshot(legacy_snapshot).get("success", false))
	legacy_scene.open_macro_march_r0()
	await _frames(3)
	var legacy_macro: MacroMarchR0 = legacy_scene.get_node("UI/MacroMarchR0")
	legacy_macro._selected_army_id = issued_army_id
	legacy_macro.refresh()
	await _frames(2)
	var legacy_copy := legacy_macro._latest_encounter_copy(legacy_city.get_field_tactics_read_model(), issued_army_id)
	var legacy_display_is_honest: bool = legacy_ok \
		and int(legacy_copy.get("army_remaining", 0)) < 0 \
		and int(legacy_copy.get("patrol_remaining", 0)) < 0 \
		and legacy_macro._detail_label.text.contains("我军剩 未记录") \
		and legacy_macro._detail_label.text.contains("敌军剩 未记录")

	var multi_feedback := macro._encounter_feedback_copy({"display_name": "双路巡骑"}, {
		"patrol_id": &"patrol.multi", "army_ids": [&"army.lost", &"army.survived"],
		"patrol_strength_before": 8, "patrol_losses": 4, "patrol_strength_after": 4,
		"army_strength_before_by_army": {&"army.lost": 3, &"army.survived": 6},
		"army_strength_after_by_army": {&"army.lost": 0, &"army.survived": 4},
		"army_phase_after_by_army": {&"army.lost": ArmyRegistry.PHASE_CLOSED, &"army.survived": ArmyRegistry.PHASE_STATIONED},
		"formation_losses_by_army": {&"army.lost": {&"lost": 3}, &"army.survived": {&"survived": 2}},
	})
	var multi_army_results: Array = Array(multi_feedback.get("army_results", []))
	var multi_army_report_is_distinct: bool = multi_army_results.size() == 2 \
		and int(multi_feedback.get("own_losses", -1)) == 5 \
		and int(multi_feedback.get("own_after", -1)) == 4 \
		and str(multi_feedback.get("post_state", "")).contains("1支全灭") \
		and str(multi_feedback.get("post_state", "")).contains("1支驻扎待命")

	print("ENCOUNTER_FEEDBACK_TRACE formal=%s continuous=%s authority=%s copy=%s audio_once=%s no_repeat=%s notice=%s finished=%s restore=%s legacy=%s multi=%s own_after=%d patrol_after=%d food=%d" % [
		str(formal_dispatch_once), str(bool(continuous_result.get("saw_marching", false))), str(contact_from_authority), str(battle_copy_matches_authority), str(audio_played_once), str(no_repeat_settlement), str(notification_focuses_only_on_click), str(feedback_finished_with_authority_intact), str(restore_does_not_replay), str(legacy_display_is_honest), str(multi_army_report_is_distinct), own_after, patrol_after, int(city.food),
	])
	_check(formal_dispatch_once, "正式地图长按派兵只发布预期编队的一道军令")
	_check(bool(continuous_result.get("saw_marching", false)) and not encounters.is_empty(), "正式 Controller 自动推进军队与巡逻，连续经过行军、自然遭遇与后续状态")
	_check(contact_from_authority, "遭遇反馈使用权威接触时间与坐标，而非帧末巡逻位置")
	_check(battle_copy_matches_authority and own_after >= 0 and patrol_after >= 0, "侧栏战报只显示本次参与者的真实双方损失与剩余人数")
	_check(audio_played_once, "新遭遇只触发一次短促碰撞音效与表现")
	_check(no_repeat_settlement, "刷新、暂停、倍速与后续时间推进不会重复结算或重播遭遇")
	_check(notification_focuses_only_on_click, "屏幕外遭遇仅提供可点击定位通知，不强制移动镜头")
	_check(feedback_finished_with_authority_intact, "短反馈自然结束后不残留交战状态，权威军令保持后续状态")
	_check(restore_does_not_replay, "同进程快照恢复保留权威伤亡但不重播历史遭遇反馈")
	_check(legacy_display_is_honest, "旧格式战报恢复后仅显示可推导的损失，缺少的历史剩余人数明确标为未记录")
	_check(multi_army_report_is_distinct, "同次多军队遭遇合计伤亡并分别表达全灭与存活军队的后续状态")
	scene.queue_free()
	restored_scene.queue_free()
	legacy_scene.queue_free()
	await process_frame
	_finish()


func _option_index(macro: MacroMarchR0, kind: StringName) -> int:
	for index in range(macro._direct_dispatch_options.size()):
		if StringName(Dictionary(macro._direct_dispatch_options[index]).get("kind", &"")) == kind:
			return index
	return -1


func _macro_uses_formation(macro: Dictionary, formation_id: StringName) -> bool:
	for snapshot_value in Array(macro.get("formation_snapshots", [])):
		if StringName(Dictionary(snapshot_value).get("formation_id", &"")) == formation_id:
			return true
	return false


func _losses_for_army(encounter: Dictionary, army_id: StringName) -> int:
	var losses := 0
	for loss_value in Dictionary(Dictionary(encounter.get("formation_losses_by_army", {})).get(army_id, {})).values():
		losses += int(loss_value)
	return losses


func _wait_for_natural_encounter(city: Node, army_id: StringName, timeout_seconds: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + roundi(timeout_seconds * 1000.0)
	var saw_marching := false
	while Time.get_ticks_msec() < deadline:
		var army: Dictionary = city._army_registry.get_army(army_id)
		saw_marching = saw_marching or StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING
		var field: Dictionary = city.get_field_tactics_read_model()
		for patrol_value in Dictionary(field.get("visible_patrols_by_id", {})).values():
			var encounter: Dictionary = Dictionary(Dictionary(patrol_value).get("last_engagement", {}))
			if army_id in Array(encounter.get("army_ids", [])):
				return {"saw_marching": saw_marching, "encounters": [encounter]}
		await process_frame
	return {"saw_marching": saw_marching, "encounters": []}


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _send_press(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	macro._on_gui_input(event)


func _send_release(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	macro._on_gui_input(event)


func _send_motion(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	macro._on_gui_input(event)


func _send_click(macro: MacroMarchR0, position: Vector2) -> void:
	_send_press(macro, position)
	_send_release(macro, position)


func _capture_viewport_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _capture_evidence(image: Image, file_name: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var path := "%s/%s" % [evidence_directory, file_name]
	if image.save_png(path) != OK:
		failures.append("无法保存遭遇图形证据：%s" % file_name)


func _user_argument_value(prefix: String) -> String:
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


func _finish() -> void:
	if failures.is_empty():
		print("MACRO_MARCH_ENCOUNTER_FEEDBACK_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_MARCH_ENCOUNTER_FEEDBACK_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)
