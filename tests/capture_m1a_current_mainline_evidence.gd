extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"
const DEFAULT_EVIDENCE_DIR := "res://docs/m1a/evidence"

var evidence_dir := DEFAULT_EVIDENCE_DIR
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--m1a-evidence-dir="):
			evidence_dir = argument.trim_prefix("--m1a-evidence-dir=")
	var absolute_dir := ProjectSettings.globalize_path(evidence_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for target_size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = target_size
		var setup := await _make_pending_city()
		await _capture("city-entry-%dx%d.png" % [target_size.x, target_size.y])
		setup.scene.queue_free()
		await process_frame

	root.size = Vector2i(1152, 648)
	var setup := await _make_pending_city()
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var entry: Button = scene.get_node("UI/Shell/TopStatusBar/CurrentMainlineButton")
	await _capture("journey-01-city-entry.png")
	entry.emit_signal("pressed")
	await process_frame
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null:
		failures.append("top-bar mainline entry did not create formal C0 battle")
		_finish()
		return
	await _capture("journey-02-battle.png")
	for squad in battle.request.committed_force.squads:
		battle.set_squad_route(int(squad.squad_id), CommittedForceSnapshot.SIDE_ROUTE)
	if not battle.start_battle():
		failures.append("formal C0 battle did not start")
		_finish()
		return
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	if battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS) == null:
		failures.append("formal C0 battle did not reach terminal result")
		_finish()
		return
	await _capture("journey-03-result-preview.png")
	var summary := battle.confirm_pending_result()
	if summary.is_empty():
		failures.append("formal C0 result did not settle")
		_finish()
		return
	var contract := battle.coordinator.request_return_to_city()
	if contract == null or not battle.complete_return_for_test(contract.city_input_restore_frame):
		failures.append("formal C0 result did not return to city")
		_finish()
		return
	await process_frame
	city.acknowledge_first_war_result()
	await _capture("journey-04-city-return-pressure-stopped.png")
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	scene.queue_free()
	await process_frame
	var cold_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(cold_scene)
	await process_frame
	var cold_city: Node = cold_scene.get_node("ConstructionController")
	cold_city.set_process(false)
	var restored: Dictionary = cold_city.restore_v5_campaign_snapshot(snapshot)
	if not bool(restored.success):
		failures.append("post-return V5 snapshot did not cold-restore")
	else:
		await _capture("journey-05-cold-restart.png")
	cold_scene.queue_free()
	await process_frame
	_finish()


func _make_pending_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.infantry_count = 50
	city.recruitment_cap = 100
	city.food = 160
	city.wood = 40
	city.start_build_project(LOGGING_CAMP_ID)
	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
	city.infantry_count = 50
	city.food = 160
	city._refresh_city_ui()
	return {"scene": scene, "city": city}


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(evidence_dir.path_join(file_name))
	var error := image.save_png(path)
	if error != OK:
		failures.append("capture failed: %s (%d)" % [path, error])
	else:
		print("CAPTURED: %s" % path)


func _finish() -> void:
	if failures.is_empty():
		print("M1A_EVIDENCE_CAPTURE: PASS dir=%s" % evidence_dir)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("M1A_EVIDENCE_CAPTURE: FAIL dir=%s" % evidence_dir)
		quit(1)
