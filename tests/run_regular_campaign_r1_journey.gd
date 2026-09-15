extends SceneTree

const Scene = preload("res://scenes/blank_map.tscn")
var failures: Array[String] = []
var city: Node
var runtime: RegularCampaignRuntime
var visual := false
var movie := false
var evidence_dir := "res://docs/milestones/regular-campaign-r1/evidence"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	movie = "--movie" in OS.get_cmdline_user_args()
	var scene: Node
	if visual:
		root.size = Vector2i(1280, 720)
		var title: Node = load("res://scenes/title_shell.tscn").instantiate()
		root.add_child(title)
		current_scene = title
		await process_frame
		await capture("01-title")
		await click_control(title._regular_campaign_button)
		await process_frame
		# The native child dialog is confirmed at its engine signal boundary;
		# this is recorded separately from viewport mouse dispatch below.
		title._regular_campaign_confirmation.confirmed.emit()
		print("ENGINE_SIGNAL regular new-game confirmation")
		await process_frame
		await process_frame
		scene = current_scene
	else:
		scene = Scene.instantiate()
		root.add_child(scene)
		await process_frame
	city = scene.get_node("ConstructionController")
	city.set_process(false)
	if not visual:
		city.initialize_regular_campaign()
	runtime = city._regular_campaign
	if visual:
		city.show_regular_campaign()
		await capture("02-preparation")
	if movie:
		city.set_city_time_speed(4.0)
	print("INITIAL ", city.get_formation_roster(), " HOME ", city.food, "/", city.wood)
	var ids: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			ids.append(formation.formation_id)
	act(&"depart", {"formation_ids": ids, "food": 8 if "--warning" in OS.get_cmdline_user_args() else 30, "wood": 55})
	await advance(1.0)
	if visual:
		city._regular_campaign_view.refresh()
		await process_frame
		await click_position(Vector2(137, 409))
		if city._regular_campaign_view._selected_army_id != runtime.data.army_ids[1]:
			failures.append("visible stacked army marker did not select the second army")
		else:
			print("ENGINE_MOUSE stacked army selection PASS")
	print("POST DEPART valid=", city.validate_v5_campaign_snapshot(city.export_v5_campaign_snapshot()).get("valid"))
	act(&"build", {"point_id": &"blackstone_city", "kind": &"LOGGING" if "--slow" in OS.get_cmdline_user_args() else &"FARM", "plot": 0})
	await advance(90.0)
	print("AFTER BUILD ", runtime.data.buildings, " stock ", runtime._stock(), " paused ", city.city_time_paused)
	if not runtime.data.buildings.is_empty():
		var id: StringName = runtime.data.buildings[0].id
		if "--warning" in OS.get_cmdline_user_args():
			await advance(90.0)
			await capture("07-food-warning")
		act(&"connect", {"building_id": id})
		act(&"workers", {"building_id": id, "count": 4})
	if "--slow" in OS.get_cmdline_user_args():
		await advance(360.0)
		act(&"build", {"kind": &"FARM", "plot": 1})
		await advance(90.0)
		if runtime.data.buildings.size() > 1:
			var farm: StringName = runtime.data.buildings[1].id
			act(&"connect", {"building_id": farm})
			act(&"workers", {"building_id": farm, "count": 4})
	if visual:
		city._regular_campaign_view._set_tab(&"BUILD")
		await capture("03-productive-base")
	if "--warning" in OS.get_cmdline_user_args():
		city._regular_campaign_view._set_tab(&"OVERVIEW")
		await capture("08-forecast-repaired")
	var home_farm := &"building.farm.t1"
	var definition: Resource = city.get_definition(home_farm)
	var cell := Vector2i(-1, -1)
	for y in range(35):
		for x in range(55):
			var probe: Dictionary = city.evaluate_origin_cell_for_definition(Vector2i(x, y), definition, false, false, 0)
			if probe.get("valid", false) and probe.get("connection_state", &"") == &"connected":
				cell = Vector2i(x, y)
				break
		if cell.x >= 0:
			break
	var home_farm_id: int = city.place_definition_at_cell(home_farm, cell, true, false)
	print("NORMAL_HOME_FARM ", home_farm_id, " ", cell)
	if home_farm_id < 0:
		failures.append("home farm normal construction failed")
	if "--pressure" in OS.get_cmdline_user_args():
		for interval in range(90):
			runtime.advance(60.0)
			await process_frame
		city._regular_campaign_view._set_tab(&"OVERVIEW")
		await capture("10-high-pressure")
		var verified: bool = runtime.data.pressure.stage == 4 and runtime.data.enemy_growth_events > 0 and not city.export_v5_campaign_snapshot().is_empty()
		print("REGULAR_PRESSURE_GRAPHICAL ", "PASS" if verified else "FAIL", " pressure=", runtime.data.pressure, " enemy_events=", runtime.data.enemy_growth_events)
		quit(0 if verified else 1)
		return
	if "--slow" in OS.get_cmdline_user_args():
		await advance(330.0)
		print("SLOW preparation_elapsed=", runtime.data.mainline_elapsed_ms, " home=", city.food, "/", city.wood, " local=", runtime._stock(), " pressure=", runtime.data.pressure.stage)
	var armies: Array = runtime.data.army_ids.duplicate()
	if armies.size() > 1:
		if visual:
			city._regular_campaign_view._set_tab(&"ARMIES")
			await capture("11-local-command")
		act(&"move", {"army_id": armies[1], "target_id": &"silverford_city"})
		await advance(240.0)
		await capture("04-silverford-controlled")
		print("AFTER SILVER ", runtime.data.phase, " ", city._war_loop_state.get_snapshot().cities_by_id, " reserve=", runtime.data.enemy_reserve)
		act(&"move", {"army_id": armies[1], "target_id": &"redcliff_city"})
		if armies.size() > 2:
			if "--slow" in OS.get_cmdline_user_args():
				act(&"workers", {"building_id": runtime.data.buildings[0].id, "count": 0})
			act(&"move", {"army_id": armies[2], "target_id": &"redcliff_city"})
		await advance(240.0)
	print("END_ARMIES ", city._army_registry.get_snapshot().armies_by_id)
	print("END_CITIES ", city._war_loop_state.get_snapshot().cities_by_id)
	print("END ", runtime.data.phase, " ", runtime.data.summary, " valid ", city.validate_v5_campaign_snapshot(city.export_v5_campaign_snapshot()).get("valid"))
	if runtime.data.phase == &"PENDING":
		if visual:
			city._regular_campaign_view._set_tab(&"RESULT")
		await capture("05-victory-preview")
		act(&"confirm")
	await capture("06-settled")
	if visual:
		city._regular_campaign_view._hide_campaign()
		await capture("09-home-after-settlement")
	print("FINAL ", runtime.data.phase, " ", failures)
	print("JOURNEY_METRICS ", JSON.stringify({"mainline_ms": runtime.data.mainline_elapsed_ms, "attempt_ms": runtime.data.attempt_elapsed_ms, "enemy_events": runtime.data.enemy_growth_events, "enemy_reserve": runtime.data.enemy_reserve, "history": runtime.data.history, "summary": runtime.data.summary, "home_food": city.food, "home_wood": city.wood, "phase": runtime.data.phase}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() and runtime.data.phase == &"COMPLETED" else 1)

func act(action: StringName, args: Dictionary = {}) -> void:
	var result := runtime.command(action, args)
	print("ACTION ", action, " ", result)
	if not result.get("success", false):
		failures.append(str(action) + ": " + str(result))

func click_control(control: Control) -> void:
	print("ENGINE_MOUSE control=", control.name, " rect=", control.get_global_rect(), " visible=", control.is_visible_in_tree())
	await click_position(control.get_global_rect().get_center(), control.get_viewport())

func click_position(position: Vector2, viewport: Viewport = null) -> void:
	if viewport == null:
		viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame

func advance(seconds: float) -> void:
	if movie:
		for frame in range(ceili(seconds * 20.0 / 4.0)):
			runtime.advance(1.0 / 20.0)
			await process_frame
	else:
		runtime.advance(seconds)

func capture(label: String) -> void:
	if not visual:
		return
	if city != null and city._regular_campaign_view != null:
		city._regular_campaign_view.refresh()
	for frame in range(3 if not movie else 20):
		if movie and runtime != null:
			runtime.advance(1.0 / 20.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(evidence_dir.path_join(label + ("-movie" if movie else "") + ".png"))
	if img.save_png(path) != OK:
		failures.append("screenshot failed " + label)
	print("IMAGE ", path, " pixels=", img.get_size(), " window=", DisplayServer.window_get_size(), " viewport=", root.size)
	if not movie and label in ["02-preparation", "03-productive-base", "05-victory-preview", "06-settled"]:
		for target_size in [Vector2i(1152, 648), Vector2i(1920, 1080)]:
			root.size = target_size
			for frame in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var resized := root.get_texture().get_image()
			var variant_path := ProjectSettings.globalize_path(evidence_dir.path_join("%s-%dx%d.png" % [label, resized.get_width(), resized.get_height()]))
			resized.save_png(variant_path)
			print("IMAGE ", variant_path, " pixels=", resized.get_size(), " window=", DisplayServer.window_get_size(), " viewport=", root.size)
		root.size = Vector2i(1280, 720)
		await process_frame
