extends SceneTree

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	_check(bool(city.initialize_regular_campaign()), "campaign initializes")
	var runtime: RegularCampaignRuntime = city._regular_campaign
	var formations: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			formations.append(formation.formation_id)
	_check(bool(runtime.command(&"depart", {"formation_ids": formations, "food": 30, "wood": 55}).success), "departure succeeds")
	_check(runtime.data.view_context.surface == &"THEATER", "departure defaults to this campaign theater")
	var before := runtime.get_snapshot()
	city.set_city_time_speed(2.0)
	city.set_city_time_paused(true)
	_check(not bool(runtime.command(&"view", {"surface": &"CITY", "city_id": &"redcliff_city"}).success), "enemy city cannot open a wartime inner city")
	_check(not bool(runtime.command(&"view", {"surface": &"CITY", "city_id": &"northwatch_garrison"}).success), "ordinary garrison cannot open a wartime inner city")
	_check(bool(runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"}).success), "authorized city opens its wartime inner city")
	_check(runtime.data.view_context.city_id == &"blackstone_city", "inner city retains location identity")
	_check(city.is_city_time_paused() and is_equal_approx(city.get_city_time_speed(), 2.0), "entry preserves pause and speed")
	_check(int(runtime.data.mainline_elapsed_ms) == int(before.mainline_elapsed_ms) and runtime.data.army_ids == before.army_ids, "entry does not advance time or redispatch armies")
	var city_snapshot := runtime.get_snapshot()
	_check(bool(runtime.command(&"view", {"surface": &"THEATER"}).success), "inner city returns to the same campaign theater")
	_check(city.is_city_time_paused() and is_equal_approx(city.get_city_time_speed(), 2.0), "return preserves pause and speed")
	_check(int(runtime.data.mainline_elapsed_ms) == int(city_snapshot.mainline_elapsed_ms) and runtime.data.departure_ledger == city_snapshot.departure_ledger, "return does not advance time or repeat asset transfer")
	var validation := RegularCampaignRuntime.validate_snapshot(runtime.get_snapshot(), city.get_nation_state().get_scoped_resources(), city._army_registry.get_snapshot())
	_check(bool(validation.valid), "view context remains valid in the authoritative save payload")
	var production_snapshot := runtime.get_snapshot()
	var restored := RegularCampaignRuntime.new(city)
	restored.restore(production_snapshot)
	_check(restored.data.view_context.surface == &"THEATER", "cold-restored runtime retains the campaign view context")
	var restored_once := restored.get_snapshot()
	_check(restored_once.totals == production_snapshot.totals and restored_once.departure_ledger == production_snapshot.departure_ledger, "cold restore preserves accumulated totals and departure cost without replay")
	restored.restore(production_snapshot)
	_check(restored.get_snapshot() == restored_once, "repeated cold restore is idempotent for all campaign records and timers")
	scene.queue_free()
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1A_THEATER_ENTRY PASS assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
