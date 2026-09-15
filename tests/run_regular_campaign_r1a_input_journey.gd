extends SceneTree

const PLOT_CELLS := [
	Vector2i(9, 8), Vector2i(19, 8), Vector2i(36, 8),
	Vector2i(9, 18), Vector2i(19, 18), Vector2i(36, 18),
]

var failures: Array[String] = []
var output_directory := "/tmp/txwzs-regular-campaign-r1a-input"
var scene: Node2D
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView
var camera: Camera2D
var selection: Node
var viewport_size := Vector2i(1280, 720)


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
	var title: Node = load("res://scenes/title_shell.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await _hold_frames(8)
	await _click_control(title._regular_campaign_button)
	await process_frame
	_expect(title._regular_campaign_confirmation.visible, "normal title entry opens confirmation")
	await _press_key(KEY_ENTER)
	_expect(await _wait_until(func(): return current_scene is Node2D, 60), "normal title confirmation opens the city scene")
	if not current_scene is Node2D:
		_finish()
		return

	scene = current_scene
	city = scene.get_node("ConstructionController")
	# The journey owns compressed wait advancement. Disable the ordinary process
	# tick so MovieWriter frame holds cannot also advance the campaign a second
	# time; production input uses the same runtime and persistence authorities.
	city.set_process(false)
	runtime = city._regular_campaign
	camera = scene.get_node("Camera2D")
	selection = scene.get_node("BuildingSelectionController")
	await _hold_frames(20)
	_expect(not city.is_regular_campaign_view_visible(), "fresh regular campaign starts on the established city main screen")
	_expect(scene.get_node("MapWorld").visible and scene.get_node("UI/Shell").visible, "normal MapWorld and original UI shell are the host")
	_expect(_find_button_prefix(scene, "进入青原战区") != null, "regular preparation owns the mainline entry instead of legacy Blackstone")
	var top_bar := scene.get_node("UI/Shell/TopStatusBar")
	var regular_context_copy := "%s\n%s\n%s" % [top_bar.get_node("AlertSummary").text, top_bar.get_node("NextStageSummary").text, top_bar.get_node("CurrentMainlineButton").text]
	_expect("赤崖" not in regular_context_copy and "银渡" not in regular_context_copy and "第 7 日" not in regular_context_copy, "regular preparation does not enable old Blackstone objectives or deadlines: %s" % regular_context_copy.replace("\n", " / "))
	await _capture("00-normal-entry-main-city.png")

	var theater_entry := _find_button_exact(scene, "进入青原战区")
	_expect(theater_entry != null, "original top bar exposes the campaign theater entry")
	if theater_entry == null:
		_finish()
		return
	await _click_control(theater_entry)
	await _hold_frames(18)
	view = city._regular_campaign_view
	_expect(view != null and view.visible, "theater opens from the original city screen")
	var depart := _find_button_exact(view, "确认首批投入 · 进入战役")
	_expect(depart != null and not depart.disabled, "departure remains available in the theater preparation surface")
	if depart == null:
		_finish()
		return
	await _click_control(depart)
	if runtime.data.phase != &"ACTIVE" and is_instance_valid(depart):
		depart.grab_focus()
		await _press_key(KEY_ENTER)
	_expect(await _wait_until(func(): return runtime.data.phase == &"ACTIVE", 100), "normal theater control submits departure once")
	if runtime.data.phase != &"ACTIVE":
		_finish()
		return
	runtime.advance(1.0)
	view.refresh(true)
	await _hold_frames(30)
	await _capture("01-theater-after-departure.png")

	var city_position := view._map.get_global_rect().position + view._map._screen(view._map._vec(view._point(&"blackstone_city").world_position))
	await _drag_left(city_position, city_position + Vector2(28, 0))
	_expect(view.visible, "theater drag does not misfire city entry")
	city_position = view._map.get_global_rect().position + view._map._screen(view._map._vec(view._point(&"blackstone_city").world_position))
	await _click_position(city_position)
	_expect(await _wait_until(func(): return city.is_regular_campaign_city_active(), 60), "map click enters the licensed wartime city")
	if not city.is_regular_campaign_city_active():
		_finish()
		return
	await _hold_frames(25)
	_expect(not city.is_regular_campaign_view_visible(), "wartime city replaces the preview with the established main viewport")
	_expect(is_equal_approx(camera.zoom.x, 1.0), "wartime city opens at the established operational scale")
	_expect(_find_button_exact(scene, "返回本关战区") != null, "wartime city action uses the current theater instead of permanent dispatch eligibility")
	_expect(not _visible_text_contains(scene, "无法出征：没有可派编队"), "wartime city never exposes the permanent no-formation prompt")
	await _capture("02-wartime-main-city.png")

	var farm_screen := _screen_for_world(_plot_center(4))
	_expect(farm_screen.x > 260.0 and farm_screen.x < float(viewport_size.x) - 310.0 and farm_screen.y > 100.0 and farm_screen.y < float(viewport_size.y) - 40.0, "the normal operational camera includes a real farm plot outside persistent UI rails")
	_expect(city.get_regular_campaign_plot_at_screen_position(farm_screen) == 4, "the visible farm plot shares the formal camera and hit transform: %s" % farm_screen)
	var build_entry := _find_button_exact(scene, "战时建设")
	_expect(build_entry != null, "original construction entry exposes legal plots only while building")
	if build_entry != null:
		await _click_control(build_entry)
	await _click_world(_plot_center(4))
	var farm := _find_button_prefix(scene, "农田 ·")
	_expect(farm != null and not farm.disabled, "real map plot opens the original construction catalog")
	if farm != null:
		await _click_control(farm)
	_expect(not runtime.data.project.is_empty() and runtime.data.project.kind == &"FARM", "catalog action starts the authoritative farm project")
	await _hold_frames(24)
	runtime.advance(90.0)
	city.refresh_regular_campaign_city()
	await _hold_frames(24)

	await _click_world(_plot_center(4))
	_expect(selection.has_selection(), "existing selection controller opens the built farm detail")
	var farm_record: Dictionary = city.get_building_record(selection.selected_placement_id)
	var farm_visual: CanvasItem = city._regular_campaign_city_host.get_visual(selection.selected_placement_id)
	_expect(StringName(farm_record.get("id", &"")) == StringName(runtime.data.buildings[0].id), "detail keeps the same authoritative farm building id")
	_expect(is_instance_valid(farm_visual) and int(farm_visual.get_meta("regular_campaign_placement_id", -1)) == selection.selected_placement_id, "the real farm record owns an in-world selectable visual")
	if is_instance_valid(farm_visual):
		var art := farm_visual.get_node("ArtSprite") as Sprite2D
		_expect(art.texture != null and art.texture.resource_path.ends_with("/farm.png"), "the formal MapWorld farm uses the preserved farm texture")
	var camera_before_detail := camera.position
	var zoom_before_detail := camera.zoom
	var connect := _find_button_exact(scene, "连接道路 · 木材 2")
	_expect(connect != null, "built farm detail exposes road connection")
	if connect != null:
		await _click_control(connect)
	for count in range(4):
		var add_worker := _find_button_prefix(scene, "增加岗位")
		if add_worker != null and not add_worker.disabled:
			await _click_control(add_worker)
	_expect(bool(runtime.data.buildings[0].connected) and int(runtime.data.buildings[0].workers) == 4, "road and job operations persist on the campaign building")
	_expect(camera.position.is_equal_approx(camera_before_detail) and camera.zoom.is_equal_approx(zoom_before_detail), "detail operations do not reset the camera")
	runtime.advance(180.0)
	city.refresh_regular_campaign_city()
	await _hold_frames(30)
	await _capture("03-connected-staffed-farm.png")

	selection.clear_selection()
	var camera_before_pan := camera.position
	await _drag_middle(Vector2(690, 440), Vector2(550, 355))
	await _hold_frames(16)
	var zoom_before_wheel := camera.zoom.x
	await _wheel(Vector2(620, 410), MOUSE_BUTTON_WHEEL_UP)
	await _hold_frames(18)
	_expect(not camera.position.is_equal_approx(camera_before_pan) and camera.zoom.x > zoom_before_wheel, "original pan and zoom operate in the wartime city")
	await _click_world(_plot_center(4))
	_expect(selection.has_selection(), "building hit testing follows the transformed map")
	var preserved_position := camera.position
	var preserved_zoom := camera.zoom
	var pause_button := _find_button_exact(scene, "暂停")
	_expect(pause_button != null, "original top bar retains the campaign pause control")
	if pause_button != null:
		await _click_control(pause_button)
	var elapsed_before_round_trip := int(runtime.data.mainline_elapsed_ms)
	await _capture("04-pan-zoom-selection.png")

	var return_button := _find_button_exact(scene, "返回本关战区")
	_expect(return_button != null, "original top bar exposes return to the same theater")
	if return_button != null:
		await _click_control(return_button)
	_expect(await _wait_until(func(): return city.is_regular_campaign_view_visible(), 60), "top-bar return opens the same theater")
	_expect(int(runtime.data.mainline_elapsed_ms) == elapsed_before_round_trip, "route transition does not advance campaign time")
	await _hold_frames(28)
	view = city._regular_campaign_view
	var army := Dictionary(view._model.armies[0])
	var army_position := view._map.get_global_rect().position + view._map._army_marker_position(army, {})
	await _click_position(army_position)
	var target_position := view._map.get_global_rect().position + view._map._screen(view._map._vec(view._point(&"northwatch_garrison").world_position))
	await _click_position(target_position)
	var moved_army: Dictionary = city._army_registry.get_army(StringName(army.get("army_id", army.get("id", &""))))
	_expect(StringName(moved_army.get("target_node_id", &"")) == &"northwatch_garrison", "formal theater input submits one existing in-campaign movement order")
	view.refresh(true)
	var moving_army := Dictionary(view._model.armies[0])
	var moving_army_position := view._map.get_global_rect().position + view._map._army_marker_position(moving_army, {})
	await _click_position(moving_army_position)
	city_position = view._map.get_global_rect().position + view._map._screen(view._map._vec(view._point(&"blackstone_city").world_position))
	await _click_position(city_position)
	_expect(await _wait_until(func(): return city.is_regular_campaign_city_active(), 60), "theater map re-enters the same licensed city")
	await _hold_frames(30)
	_expect(camera.position.is_equal_approx(preserved_position) and camera.zoom.is_equal_approx(preserved_zoom), "theater round trip restores the same city camera")
	_expect(runtime.data.buildings.size() == 1 and int(runtime.data.buildings[0].workers) == 4, "theater round trip preserves the same building and jobs")
	await _capture("05-round-trip-restored.png")

	var ledger_before_leave := Dictionary(runtime.data.departure_ledger).duplicate(true)
	var time_before_leave := int(runtime.data.mainline_elapsed_ms)
	var leave_via_city := _find_button_exact(scene, "返回本关战区")
	if leave_via_city != null:
		await _click_control(leave_via_city)
	_expect(await _wait_until(func(): return city.is_regular_campaign_view_visible(), 60), "same wartime city returns to its theater before temporary leave")
	view = city._regular_campaign_view
	var leave := _find_button_exact(view, "暂离关卡 · 返回永久主城")
	_expect(leave != null, "existing temporary-leave control is available")
	if leave != null:
		await _click_control(leave)
	await _hold_frames(12)
	_expect(not city.is_regular_campaign_view_visible() and not city.is_regular_campaign_city_active(), "temporary leave restores the permanent main city")
	var continue_entry := _find_button_exact(scene, "查看青原战区")
	_expect(continue_entry != null, "permanent city continues the same regular campaign without legacy mode copy")
	if continue_entry != null:
		await _click_control(continue_entry)
	_expect(await _wait_until(func(): return city.is_regular_campaign_view_visible(), 60), "campaign continues from the existing main-screen entry")
	_expect(Dictionary(runtime.data.departure_ledger) == ledger_before_leave and int(runtime.data.mainline_elapsed_ms) == time_before_leave, "temporary leave does not redispatch, re-charge, or advance the campaign")

	# Waiting below is compressed through the authoritative campaign clock. All
	# commands still enter through visible controls/map hits; this journey never
	# calls outcome, occupation, damage, or confirmation APIs directly.
	view = city._regular_campaign_view
	if city.is_city_time_paused():
		await _click_control(_find_button_exact(view, "暂停"))
	var armies: Array = Array(view._model.get("armies", []))
	_expect(armies.size() >= 3, "the formal departure retains all three real formations")
	if armies.size() < 3:
		_finish()
		return
	var assault_army_id := StringName(Dictionary(armies[1]).get("army_id", &""))
	var reserve_army_id := StringName(Dictionary(armies[2]).get("army_id", &""))
	await _select_army_marker(assault_army_id)
	_expect(view._selected_army_id == assault_army_id, "stacked formal marker selects the intended second formation")
	await _select_army_marker(reserve_army_id)
	_expect(view._selected_army_id == reserve_army_id, "same-point formations can be selected separately instead of always using the first")
	await _select_army_marker(assault_army_id)
	await _click_theater_point(&"silverford_city")
	_expect(StringName(city._army_registry.get_army(assault_army_id).target_node_id) == &"silverford_city", "map input orders the selected formation to Silverford")
	await _advance_campaign_until(func(): return not city._war_loop_state.is_enemy_city(&"silverford_city"), 180.0)
	_expect(runtime.data.phase == &"ACTIVE" and city._war_loop_state.is_enemy_city(&"redcliff_city"), "Silverford resolves first without ending the whole campaign")
	_expect(runtime.feedback.contains("交战已结束") and not runtime.feedback.contains("招降成功"), "current Silverford force does not falsely claim surrender when the real rule falls through to combat: %s" % runtime.feedback)
	view.refresh(true)
	await _capture("06-silverford-surrendered-redcliff-remains.png")

	await _click_theater_point(&"redcliff_city")
	_expect(StringName(city._army_registry.get_army(assault_army_id).target_node_id) == &"redcliff_city", "map input orders the same identified formation to Redcliff")
	await _advance_campaign_until(func(): return not city._war_loop_state.get_siege(&"redcliff_city").is_empty(), 90.0)
	var siege_before_round_trip: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	_expect(not siege_before_round_trip.is_empty() and StringName(siege_before_round_trip.resolution) == &"", "Redcliff rejects surrender and starts an actual siege")
	_expect(runtime.feedback.contains("拒绝招降") and runtime.feedback.contains("开始进攻"), "refused surrender exposes the real transition into the active siege")
	view.refresh(true)
	var presented_sieges: Array = Array(view._model.get("sieges", []))
	_expect(presented_sieges.size() == 1 and int(Dictionary(presented_sieges[0]).get("gate_hp", -1)) == int(siege_before_round_trip.gate_hp), "formal theater projects the authoritative attacker, gate and defender state")
	var presented_army := _presented_army(assault_army_id)
	var army_presentation := Dictionary(presented_army.get("presentation", {}))
	_expect(int(army_presentation.get("current_count", -1)) == int(Dictionary(presented_sieges[0]).get("attacker_count", -2)) and int(army_presentation.get("entry_count", -1)) == int(siege_before_round_trip.get("attacker_initial_count", -2)), "army marker and engagement card share current combat count while preserving explicit entry count")
	_expect(view._map._army_label(presented_army).contains("当前可战"), "engaged map label identifies its number as current combat strength")
	var presentation: MacroMarchLowPolyPresentation = view._map._presentation._low_poly
	var actor: Node3D = presentation._army_nodes.get(assault_army_id, null)
	var actor_screen := presentation._camera.unproject_position(actor.global_position) if actor != null else Vector2.ZERO
	var marker_screen := _marker_position_for(assault_army_id)
	_expect(actor != null and actor_screen.distance_to(marker_screen) <= 2.0, "stacked low-poly formation and clickable command marker share the same army anchor")
	_expect(presentation._engagement_root.get_child_count() == 1 and StringName(presentation._engagement_root.get_child(0).get_meta("attack_source_army_id", &"")) == assault_army_id, "aggregate contact visual names the real attacking army without creating soldier actors")
	await _capture("07-redcliff-siege-start.png")

	await _select_army_marker(assault_army_id)
	_expect(view._selected_army_id.is_empty(), "clicking the selected army exits command mode")
	await _click_theater_point(&"blackstone_city")
	_expect(await _wait_until(func(): return city.is_regular_campaign_city_active(), 60), "active combat permits a normal wartime-city round trip")
	var siege_in_city: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	_expect(StringName(siege_in_city.get("siege_id", &"")) == StringName(siege_before_round_trip.get("siege_id", &"")), "entering the city preserves the same engagement")
	var city_pause := _find_button_exact(scene, "暂停")
	if city_pause != null:
		await _click_control(city_pause)
	var paused_siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	runtime.advance(3.0)
	_expect(city._war_loop_state.get_siege(&"redcliff_city") == paused_siege, "pause stops the engagement without duplicate progression")
	if city_pause != null:
		await _click_control(city_pause)
	await _click_control(_find_button_exact(scene, "返回本关战区"))
	_expect(await _wait_until(func(): return city.is_regular_campaign_view_visible(), 60), "city returns to the same active theater")
	view = city._regular_campaign_view
	_expect(StringName(city._war_loop_state.get_siege(&"redcliff_city").get("siege_id", &"")) == StringName(siege_before_round_trip.get("siege_id", &"")), "theater return keeps engagement identity")

	await _advance_campaign_until(func():
		var siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
		return not siege.is_empty() and int(siege.get("gate_hp", 1)) == 0 and int(siege.get("defender_total_hp", 0)) > 0,
		90.0
	)
	var breached: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	_expect(not breached.is_empty() and int(breached.gate_hp) == 0 and int(breached.defender_total_hp) > 0, "gate breach remains an in-progress battle while defenders survive")
	_expect(runtime.data.phase == &"ACTIVE" and city._war_loop_state.is_enemy_city(&"redcliff_city"), "gate zero is not misreported as campaign victory")
	view.refresh(true)
	var breached_projection := Dictionary(Array(view._model.get("sieges", []))[0])
	var breached_army := _presented_army(assault_army_id)
	_expect(bool(breached_projection.get("gate_breached", false)) and int(breached_projection.get("defender_count", 0)) > 0, "breached gate presentation continues to identify surviving defenders")
	_expect(int(Dictionary(breached_army.get("presentation", {})).get("current_count", -1)) == int(breached_projection.get("attacker_count", -2)), "map and engagement card remain on the same current-combat count after casualties")
	await _capture("08-redcliff-gate-breached-defenders-remain.png")
	await _advance_campaign_until(func(): return runtime.data.phase == &"PENDING", 120.0)
	_expect(runtime.data.phase == &"PENDING" and not city._war_loop_state.is_enemy_city(&"redcliff_city"), "defenders are resolved before control changes and the full objective completes")
	_expect(int(runtime.data.summary.get("fallen", 0)) > 0 or int(runtime.data.summary.get("wounded", 0)) > 0, "the observed engagement produces real casualties")
	view.refresh(true)
	_expect(Array(view._model.get("sieges", [])).is_empty() and presentation._engagement_root.get_child_count() == 0, "finished engagement removes stale attack relations and contact actors")
	await _capture("09-victory-pending-settlement.png")

	var summary_before_confirm := Dictionary(runtime.data.summary).duplicate(true)
	var home_food_before_confirm: int = city.food
	var home_wood_before_confirm: int = city.wood
	view.refresh(true)
	await _click_control(_find_button_exact(view, "结算"))
	await _hold_frames(2)
	var confirm := _find_button_exact(view, "确认损益并归队")
	_expect(confirm != null, "pending result exposes the formal confirmation control")
	if confirm != null:
		await _click_control(confirm)
	_expect(runtime.data.phase == &"COMPLETED", "formal confirmation completes settlement once")
	_expect(city.food - home_food_before_confirm == int(runtime.data.summary.get("food_return_actual", 0)) and city.wood - home_wood_before_confirm == int(runtime.data.summary.get("wood_return_actual", 0)), "actual returned resources match the settlement receipt")
	var return_home := _find_button_exact(view, "返回永久主城")
	_expect(return_home != null, "completed result exposes the formal return-to-city control")
	if return_home != null:
		await _click_control(return_home)
	_expect(not city.is_regular_campaign_view_visible() and not city.is_regular_campaign_city_active(), "confirmation returns to permanent-city operation")
	var settled_formations: Array = city.get_formation_roster()
	var settlement_id := StringName(runtime.data.settlement_id)
	view.refresh(true)
	_expect(runtime.data.phase == &"COMPLETED" and StringName(runtime.data.settlement_id) == settlement_id and city.get_formation_roster() == settled_formations, "completed result cannot replay survivor or resource handover")
	_expect(int(runtime.data.summary.get("survivors", -1)) == 17 and int(runtime.data.summary.get("wounded", -1)) == 1 and int(runtime.data.summary.get("fallen", -1)) == 2 and int(runtime.data.summary.get("food_return_actual", -1)) == 66 and int(runtime.data.summary.get("wood_return_actual", -1)) == 8, "same initial state and commands retain the 06869cd combat and settlement result")
	print("R1A_FULL_BATTLE_SETTLEMENT ", JSON.stringify({"before_confirm": summary_before_confirm, "after_confirm": runtime.data.summary, "home_food": city.food, "home_wood": city.wood, "assault_army": assault_army_id, "reserve_army": reserve_army_id, "snapshot_valid": city.validate_v5_campaign_snapshot(city.export_v5_campaign_snapshot()).get("valid", false)}))
	await _capture("10-permanent-city-after-settlement.png")

	print("R1A_INPUT_JOURNEY ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	_finish()


func _click_theater_point(point_id: StringName) -> void:
	view.refresh(true)
	var position := view._map.get_global_rect().position + view._map._screen(view._map._vec(view._point(point_id).world_position))
	await _click_position(position)


func _select_army_marker(army_id: StringName) -> void:
	view.refresh(true)
	var stacked: Dictionary = {}
	for army_value in Array(view._model.get("armies", [])):
		var army := Dictionary(army_value)
		var position := view._map._army_marker_position(army, stacked)
		if StringName(army.get("army_id", &"")) == army_id:
			await _click_position(view._map.get_global_rect().position + position)
			return
	_expect(false, "army marker exists for %s" % army_id)


func _presented_army(army_id: StringName) -> Dictionary:
	for army_value in Array(view._model.get("armies", [])):
		var army := Dictionary(army_value)
		if StringName(army.get("army_id", &"")) == army_id:
			return army
	return {}


func _marker_position_for(army_id: StringName) -> Vector2:
	var stacked: Dictionary = {}
	for army_value in Array(view._model.get("armies", [])):
		var army := Dictionary(army_value)
		var position := view._map._army_marker_position(army, stacked)
		if StringName(army.get("army_id", &"")) == army_id:
			return position
	return Vector2.ZERO


func _advance_campaign_until(predicate: Callable, maximum_seconds: float) -> void:
	var elapsed := 0.0
	while not predicate.call() and elapsed < maximum_seconds:
		runtime.advance(0.25)
		elapsed += 0.25
		if fmod(elapsed, 1.0) == 0.0:
			view.refresh()
			await process_frame


func _plot_center(plot: int) -> Vector2:
	return Vector2(PLOT_CELLS[plot]) * 40.0 + Vector2(80.0, 60.0)


func _screen_for_world(world_position: Vector2) -> Vector2:
	return scene.get_node("MapWorld").get_global_transform_with_canvas() * world_position


func _click_world(world_position: Vector2) -> void:
	await _click_position(_screen_for_world(world_position))


func _wait_until(predicate: Callable, frame_limit: int) -> bool:
	for frame in frame_limit:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _hold_frames(count: int) -> void:
	for frame in count:
		await process_frame


func _click_control(control: Control) -> void:
	await _reveal_control(control)
	await _click_position(control.get_global_rect().get_center())


func _reveal_control(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	var scroll: ScrollContainer
	while ancestor != null:
		if ancestor is ScrollContainer:
			scroll = ancestor
			break
		ancestor = ancestor.get_parent()
	if scroll == null:
		return
	for attempt in 30:
		var rect := control.get_global_rect()
		var viewport_rect := scroll.get_global_rect()
		if rect.position.y >= viewport_rect.position.y and rect.end.y <= viewport_rect.end.y:
			return
		var wheel := InputEventMouseButton.new()
		wheel.position = viewport_rect.get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if rect.get_center().y > viewport_rect.get_center().y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		root.push_input(wheel, true)
		await process_frame


func _click_position(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _drag_left(start: Vector2, finish: Vector2) -> void:
	await _drag(start, finish, MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MASK_LEFT)


func _drag_middle(start: Vector2, finish: Vector2) -> void:
	await _drag(start, finish, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_MASK_MIDDLE)


func _drag(start: Vector2, finish: Vector2, button: int, mask: int) -> void:
	var down := InputEventMouseButton.new()
	down.position = start
	down.global_position = start
	down.button_index = button
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	motion.button_mask = mask
	root.push_input(motion, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = finish
	up.global_position = finish
	up.button_index = button
	up.pressed = false
	root.push_input(up, true)
	await process_frame


func _wheel(position: Vector2, button_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button_index
	event.pressed = true
	root.push_input(event, true)
	await process_frame


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _find_button_exact(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child
	return null


func _find_button_prefix(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text.begins_with(prefix) and child.is_visible_in_tree():
			return child
	return null


func _visible_text_contains(node: Node, needle: String) -> bool:
	for child in node.find_children("*", "Label", true, false):
		if child is Label and child.is_visible_in_tree() and needle in child.text:
			return true
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.is_visible_in_tree() and needle in child.text:
			return true
	return false


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for frame in (30 if "--recording" in OS.get_cmdline_user_args() else 3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_directory.path_join(filename)
	if image == null or image.save_png(path) != OK:
		failures.append("capture failed: " + path)
	else:
		print("R1A_INPUT_IMAGE ", path, " pixels=", image.get_size())


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)


func _finish() -> void:
	quit(0 if failures.is_empty() else 1)
