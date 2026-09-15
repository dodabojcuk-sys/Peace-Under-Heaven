extends SceneTree

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var mode := "A"
var facts_path := "/tmp/txwzs-regular-engagement-cold-facts.json"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--facts="):
			facts_path = arg.trim_prefix("--facts=")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	if mode == "A":
		await _stage_a(scene, city)
	else:
		await _stage_b(scene, city)
	print("R1A_ENGAGEMENT_COLD_%s %s failures=%s" % [mode, "PASS" if failures.is_empty() else "FAIL", str(failures)])
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)


func _stage_a(scene: Node, city: Node) -> void:
	_expect(city.initialize_regular_campaign(), "A initializes regular campaign")
	var runtime: RegularCampaignRuntime = city._regular_campaign
	var formation_ids: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			formation_ids.append(formation.formation_id)
	_expect(bool(runtime.command(&"depart", {"formation_ids": formation_ids, "food": 30, "wood": 55}).get("success", false)), "A departs through existing transaction")
	runtime.advance(1.0)
	var armies: Array = runtime.get_read_model().get("armies", [])
	var army_id := StringName(Dictionary(armies[1]).get("army_id", &""))
	_expect(bool(runtime.command(&"move", {"army_id": army_id, "target_id": &"redcliff_city"}).get("success", false)), "A issues existing Redcliff order")
	_advance_until(runtime, func(): return not city._war_loop_state.get_siege(&"redcliff_city").is_empty(), 180.0)
	var siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	_expect(not siege.is_empty() and StringName(siege.get("phase", &"")) == WarLoopState.PHASE_SIEGING, "A saves an active rejected-surrender siege")
	var facts := {
		"siege_id": String(siege.get("siege_id", &"")),
		"army_id": String(siege.get("army_id", &"")),
		"tick": int(siege.get("tick", -1)),
		"gate_hp": int(siege.get("gate_hp", -1)),
		"attacker_total_hp": int(siege.get("attacker_total_hp", -1)),
		"defender_total_hp": int(siege.get("defender_total_hp", -1)),
	}
	var file := FileAccess.open(facts_path, FileAccess.WRITE)
	_expect(file != null, "A opens temporary fact receipt")
	if file != null:
		file.store_string(JSON.stringify(facts))
		file.close()
	_expect(scene.flush_runtime_persistence(&"regular_engagement_cold_a"), "A flushes the active siege through existing V5 persistence")


func _stage_b(_scene: Node, city: Node) -> void:
	var file := FileAccess.open(facts_path, FileAccess.READ)
	_expect(file != null, "B reads A fact receipt")
	var expected: Dictionary = JSON.parse_string(file.get_as_text()) if file != null else {}
	if file != null:
		file.close()
	var runtime: RegularCampaignRuntime = city._regular_campaign
	_expect(runtime != null and runtime.enabled(), "B cold-loads the existing regular campaign")
	if runtime == null or not runtime.enabled():
		return
	var siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	var same_facts := (
		String(siege.get("siege_id", &"")) == str(expected.get("siege_id", ""))
		and String(siege.get("army_id", &"")) == str(expected.get("army_id", ""))
		and int(siege.get("tick", -2)) == int(expected.get("tick", -1))
		and int(siege.get("gate_hp", -2)) == int(expected.get("gate_hp", -1))
		and int(siege.get("attacker_total_hp", -2)) == int(expected.get("attacker_total_hp", -1))
		and int(siege.get("defender_total_hp", -2)) == int(expected.get("defender_total_hp", -1))
	)
	_expect(same_facts, "B restores the same siege tick, gate, attacker and defender facts without replay")
	var before_view: Dictionary = city.export_v5_campaign_snapshot()
	city.show_regular_campaign()
	await process_frame
	var view: RegularCampaignView = city._regular_campaign_view
	view.refresh(true)
	await process_frame
	var model_sieges: Array = view._model.get("sieges", [])
	var presentation: MacroMarchLowPolyPresentation = view._map._presentation._low_poly
	_expect(model_sieges.size() == 1 and presentation._engagement_root.get_child_count() == 1, "B projects exactly one current engagement instead of replaying historical contacts")
	_expect(city.export_v5_campaign_snapshot() == before_view, "B presentation restore is read-only")


func _advance_until(runtime: RegularCampaignRuntime, predicate: Callable, maximum_seconds: float) -> void:
	var elapsed := 0.0
	while not predicate.call() and elapsed < maximum_seconds:
		runtime.advance(0.25)
		elapsed += 0.25


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)
