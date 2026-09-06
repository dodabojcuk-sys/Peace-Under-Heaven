extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const DEFAULT_EVIDENCE_DIR := "/tmp/txwzs-p1e-first-war-evidence"

var evidence_dir := DEFAULT_EVIDENCE_DIR
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--p1e-evidence-dir="):
			evidence_dir = argument.trim_prefix("--p1e-evidence-dir=")
	DirAccess.make_dir_recursive_absolute(evidence_dir)

	var preparation: Dictionary = await _make_city(20, 80)
	var preparation_scene: Node2D = preparation.scene
	var preparation_city: Node = preparation.city
	var preparation_selection: Node = preparation.selection
	var command_id := _find_command_platform(preparation_city)
	preparation_city.advance_city_time_for_test(
		preparation_city.SECONDS_PER_DAY * 5.0
	)
	preparation_selection.select_placement(command_id)
	await _capture("01-day6-warning.png")

	preparation_city.advance_city_time_for_test(
		preparation_city.SECONDS_PER_DAY
	)
	await _capture("02-day7-command-platform.png")
	preparation_city.infantry_count = 50
	preparation_city.food = 80
	preparation_city._refresh_city_ui()
	if preparation_city.enter_first_war_battle():
		await _capture("03-formal-c0-entry.png")
		await _complete_battle_and_return(
			preparation_city,
			BattleOrder.Command.ADVANCE,
			CommittedForceSnapshot.SIDE_ROUTE
		)
		await _capture("04-victory-writeback.png")
	else:
		failures.append("无法从正式军令台进入 C0")
	preparation_scene.queue_free()
	await process_frame

	var defeat: Dictionary = await _make_pending_city(1, 80)
	await _complete_battle_and_return(
		defeat.city,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	await _capture("05-defeat-writeback.png")
	defeat.scene.queue_free()
	await process_frame

	var retreat: Dictionary = await _make_pending_city(8, 80)
	await _complete_battle_and_return(
		retreat.city,
		BattleOrder.Command.RETREAT,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	await _capture("06-retreat-writeback.png")
	retreat.scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("P1E_EVIDENCE_CAPTURE PASS dir=%s" % evidence_dir)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("P1E_EVIDENCE_CAPTURE FAIL dir=%s" % evidence_dir)
		quit(1)


func _make_city(player_count: int, food_count: int) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	city.set_process(false)
	city.infantry_count = player_count
	city.food = food_count
	city._refresh_city_ui()
	return {
		"scene": scene,
		"city": city,
		"selection": selection,
	}


func _make_pending_city(
	player_count: int,
	food_count: int
) -> Dictionary:
	var setup: Dictionary = await _make_city(player_count, food_count)
	var city: Node = setup.city
	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
	city.infantry_count = player_count
	city.food = food_count
	city._refresh_city_ui()
	setup.selection.select_placement(_find_command_platform(city))
	if not city.enter_first_war_battle():
		failures.append("正式 C0 入口启动失败")
	return setup


func _complete_battle_and_return(
	city: Node,
	command: BattleOrder.Command,
	route_id: StringName
) -> void:
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null:
		failures.append("缺少正式 C0 战场")
		return
	for squad in battle.request.committed_force.squads:
		battle.set_squad_route(int(squad.squad_id), route_id)
	if not battle.start_battle():
		failures.append("C0 无法开始")
		return
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), command)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	if result == null:
		failures.append("C0 未产生结果")
		return
	if battle.confirm_pending_result().is_empty():
		failures.append("C0 战果写回失败")
		return
	var return_contract := battle.coordinator.request_return_to_city()
	if (
		return_contract == null
		or not battle.complete_return_for_test(
			return_contract.city_input_restore_frame
		)
	):
		failures.append("C0 返回城市失败")
	await process_frame
	await process_frame


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := evidence_dir.path_join(file_name)
	var error := image.save_png(path)
	if error != OK:
		failures.append("截图保存失败：%s (%d)" % [path, error])
	else:
		print("CAPTURED %s" % path)


func _find_command_platform(city: Node) -> int:
	for placement_id in city.get_placement_ids():
		var record: Dictionary = city.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == &"command_platform":
			return placement_id
	return -1
