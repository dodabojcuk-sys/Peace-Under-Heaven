extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"
const DEFAULT_EVIDENCE_DIR := "res://docs/m1a/evidence"
const REQUIRED_SCREENSHOT_NAMES := [
	"01-city-mainline-entry-1152x648.png",
	"02-battle-entry-1152x648.png",
	"03-battle-running-1152x648.png",
	"04-settlement-preview-1152x648.png",
	"05-settlement-error-or-nonvictory-1152x648.png",
	"06-returned-city-cleared-1152x648.png",
	"07-cold-restart-preserved-1152x648.png",
	"08-longest-state-1280x720.png",
	"09-longest-state-1440x900.png",
	"10-build-state-after-battle-1440x900.png",
]

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
	root.size = Vector2i(1152, 648)
	var setup := await _make_pending_city()
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var entry: Button = scene.get_node("UI/Shell/TopStatusBar/CurrentMainlineButton")
	await _capture("01-city-mainline-entry-1152x648.png")
	await _capture("journey-01-city-entry.png")
	entry.emit_signal("pressed")
	await process_frame
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null:
		failures.append("top-bar mainline entry did not create formal C0 battle")
		_finish()
		return
	await _capture("02-battle-entry-1152x648.png")
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
	battle.step_battle_for_test(60)
	await _capture("03-battle-running-1152x648.png")
	await _capture("journey-03-battle-running.png")
	if battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS) == null:
		failures.append("formal C0 battle did not reach terminal result")
		_finish()
		return
	await _capture("04-settlement-preview-1152x648.png")
	await _capture("journey-04-settlement-preview.png")
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
	await _capture("06-returned-city-cleared-1152x648.png")
	await _capture("journey-05-city-return-pressure-stopped.png")
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	root.size = Vector2i(1440, 900)
	await _capture("10-build-state-after-battle-1440x900.png")
	scene.queue_free()
	await process_frame
	root.size = Vector2i(1152, 648)
	var cold_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(cold_scene)
	await process_frame
	var cold_city: Node = cold_scene.get_node("ConstructionController")
	cold_city.set_process(false)
	var restored: Dictionary = cold_city.restore_v5_campaign_snapshot(snapshot)
	if not bool(restored.success):
		failures.append("post-return V5 snapshot did not cold-restore")
	else:
		await _capture("07-cold-restart-preserved-1152x648.png")
		await _capture("journey-06-cold-restart.png")
	cold_scene.queue_free()
	await process_frame
	await _capture_nonvictory_preview()
	await _capture_longest_state(Vector2i(1280, 720), "08-longest-state-1280x720.png")
	await _capture_longest_state(Vector2i(1440, 900), "09-longest-state-1440x900.png")
	_build_contact_sheet()
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


func _capture_nonvictory_preview() -> void:
	root.size = Vector2i(1152, 648)
	var setup := await _make_pending_city()
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	city.infantry_count = 8
	city.food = 160
	if not city.enter_first_war_battle():
		failures.append("nonvictory evidence could not enter formal C0")
		scene.queue_free()
		return
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null or not battle.start_battle():
		failures.append("nonvictory evidence could not start formal C0")
		scene.queue_free()
		return
	battle.tick_timer.stop()
	for squad in battle.request.committed_force.squads:
		battle.set_squad_route(int(squad.squad_id), CommittedForceSnapshot.FRONT_ROUTE)
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), BattleOrder.Command.RETREAT)
	if battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS) == null:
		failures.append("nonvictory evidence did not reach terminal result")
	else:
		await _capture("05-settlement-error-or-nonvictory-1152x648.png")
	battle.queue_free()
	scene.queue_free()
	await process_frame


func _capture_longest_state(target_size: Vector2i, file_name: String) -> void:
	root.size = target_size
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.set_city_security_for_test(73)
	city.advance_one_day_for_test()
	city._refresh_city_ui()
	await _capture(file_name)
	scene.queue_free()
	await process_frame


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		failures.append("capture requires a rendering-capable Godot display: %s" % file_name)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append("capture returned an empty image: %s" % file_name)
		return
	var path := ProjectSettings.globalize_path(evidence_dir.path_join(file_name))
	var error := image.save_png(path)
	if error != OK:
		failures.append("capture failed: %s (%d)" % [path, error])
	else:
		print("CAPTURED: %s" % path)


func _build_contact_sheet() -> void:
	var cell_size := Vector2i(576, 324)
	var sheet := Image.create(
		cell_size.x * 2,
		cell_size.y * 5,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color.BLACK)
	for index in range(REQUIRED_SCREENSHOT_NAMES.size()):
		var source := Image.load_from_file(
			ProjectSettings.globalize_path(
				evidence_dir.path_join(REQUIRED_SCREENSHOT_NAMES[index])
			)
		)
		if source == null or source.is_empty():
			failures.append("contact sheet source missing: %s" % REQUIRED_SCREENSHOT_NAMES[index])
			return
		source.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i(
			(index % 2) * cell_size.x,
			(index / 2) * cell_size.y
		)
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, cell_size), destination)
	var path := ProjectSettings.globalize_path(
		evidence_dir.path_join("m1a-current-mainline-return-loop-r0-contact-sheet.png")
	)
	var error := sheet.save_png(path)
	if error != OK:
		failures.append("contact sheet save failed: %s (%d)" % [path, error])
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
