extends SceneTree

const CityScene = preload("res://scenes/blank_map.tscn")
var errors: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _city() -> Node:
	# Each comparison case must start a new generation even when the runner uses
	# one explicit isolated store. Otherwise a later scene restores the previous
	# case and the frame-split comparison no longer has a common baseline.
	root.get_node("RuntimeIdentity").request_campaign_start(&"NEW")
	var scene := CityScene.instantiate()
	root.add_child(scene)
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.initialize_regular_campaign()
	return city

func _run() -> void:
	var reference := {}
	for config in [[30, 1.0], [60, 1.0], [60, 2.0], [30, 4.0], [0, 1.0]]:
		var city := _city()
		var runtime: RegularCampaignRuntime = city._regular_campaign
		var formation: Dictionary = city._garrison_state.get_formations()[0]
		_check(runtime.command(&"depart", {"formation_ids": [formation.formation_id], "food": 8, "wood": 55}).success, "normal initial force")
		city.set_city_time_speed(float(config[1]))
		var seconds := 180.0 / float(config[1])
		var elapsed := 0.0
		var pattern := [0.011, 0.07, 0.004, 0.035, 0.02]
		var index := 0
		while elapsed < seconds - 0.00000001:
			var delta := minf(1.0 / int(config[0]) if int(config[0]) > 0 else float(pattern[index % pattern.size()]), seconds - elapsed)
			runtime.advance(delta)
			elapsed += delta
			index += 1
		var projection := {"regular": runtime.get_snapshot(), "scopes": city.get_nation_state().get_scoped_resources(), "army": city._army_registry.get_snapshot(), "day": city.current_day, "day_ms": city.get_day_elapsed_milliseconds(), "home_food": city.food}
		if reference.is_empty():
			reference = projection
		if projection != reference:
			print("TIME_DIFF ", config, " ms ", runtime.data.mainline_elapsed_ms, " remainder ", runtime.data.step_remainder_ms, " expected ", reference.regular.mainline_elapsed_ms, "/", reference.regular.step_remainder_ms)
		_check(projection == reference, "equal 180s at fps/speed %s" % str(config))
		var before := runtime.get_snapshot()
		city.set_city_time_paused(true)
		runtime.advance(600.0)
		_check(before == runtime.get_snapshot(), "pause advances no campaign owner")
		city.get_parent().queue_free()
		await process_frame
	var city := _city()
	var r: RegularCampaignRuntime = city._regular_campaign
	var ids: Array = []
	for formation in city._garrison_state.get_formations():
		ids.append(formation.formation_id)
	_check(r.command(&"depart", {"formation_ids": ids, "food": 8, "wood": 55}).success, "starvation starts from paid finite food")
	r.advance(180.0)
	_check(r._stock()[&"food"] > 0 and r._forecast().risk_id != &"STABLE" and r.data.fallen_home == 0, "warning before exhaustion has no fabricated casualty")
	r.advance(540.0)
	_check(r.data.fallen_home > 0, "repeated actual unpaid rations cause real permanent-pending losses")
	var old_time := int(r.data.mainline_elapsed_ms)
	_check(r.command(&"retry").success and r.data.mainline_elapsed_ms == old_time and r.data.fallen_home == 0, "retry restores attempt loss only and retains elapsed")
	for interval in range(90):
		r.advance(60.0)
		await process_frame
	_check(r.data.pressure.stage == 4, "finite dynamic buffer reaches terminal pressure")
	_check(not r.command(&"build", {"kind": &"WAREHOUSE", "plot": 0}).success, "terminal pressure denies nonessential local construction")
	_check(int(r.data.enemy_reserve) < 120 and int(r.data.enemy_growth_events) > 0, "time growth consumes finite authored enemy reserve")
	_check(city.export_v5_campaign_snapshot().size() > 0, "long-delay terminal state remains valid")
	city.get_parent().queue_free()
	await process_frame
	for error in errors:
		push_error(error)
	print("REGULAR_CAMPAIGN_R1_TIME %s checks=%d" % ["PASS" if errors.is_empty() else "FAIL", checks])
	quit(0 if errors.is_empty() else 1)

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		errors.append(description)
	else:
		print("PASS ", description)
