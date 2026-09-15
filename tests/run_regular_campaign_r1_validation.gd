extends SceneTree


## Cold-restore boundary coverage. Invoke with a separate save directory, for
## example `-- --txwzs-v5-save-dir=/tmp/regular-r1-validation`, so this runner
## never reads or writes a player campaign.
const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const REGULAR_SCOPE := &"regular.qingyuan.r1"

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node_or_null("ConstructionController")
	_check(city != null, "normal scene provides a controller for validation coverage")
	if city == null:
		_finish()
		return
	city.set_process(false)
	var initialized = city.initialize_regular_campaign()
	_check(bool(initialized), "regular campaign initializes before snapshot validation")
	var runtime: Object = city.get("_regular_campaign") as Object
	var formation_ids: Array[StringName] = []
	for formation_value in city.get_formation_roster():
		var formation: Dictionary = formation_value
		if int(formation.get("member_count", 0)) > 0:
			formation_ids.append(StringName(formation.get("formation_id", &"")))
			break
	var departed: Dictionary = runtime.command(&"depart", {"formation_ids": formation_ids, "food": 30, "wood": 55})
	_check(bool(departed.get("success", false)), "normal departure produces a canonical active snapshot")
	if not bool(departed.get("success", false)):
		scene.queue_free()
		_finish()
		return
	runtime.advance(1.0)
	var snapshot: Dictionary = runtime.get_snapshot()
	_check(_valid(snapshot, city), "unmodified active snapshot passes strict cold-restore validation")

	var ledger_food := snapshot.duplicate(true)
	ledger_food.departure_ledger.food += 1
	_check(not _valid(ledger_food, city), "forged departure ledger food cannot detach entry scope from original transfer")

	var entry_building := snapshot.duplicate(true)
	entry_building.entry.state.buildings = [{"id": &"regular.building.000001", "kind": &"FARM", "plot": 0, "world_position": Vector2i(80, 715), "phase": &"ACTIVE", "progress_permille": 1000, "workers": 0, "connected": false, "durability": 100}]
	_check(not _valid(entry_building, city), "entry state cannot forge completed construction before the first attempt tick")

	var entry_war := snapshot.duplicate(true)
	entry_war.entry.war_loop.schema_version = -1
	_check(not _valid(entry_war, city), "entry WarLoop snapshot must restore through its authoritative probe")

	var empty_pressure := snapshot.duplicate(true)
	empty_pressure.pressure = {}
	_check(not _valid(empty_pressure, city), "active cold restore rejects an empty pressure record")

	var forged_modifier := snapshot.duplicate(true)
	forged_modifier.pressure.construction_permille = 999
	_check(not _valid(forged_modifier, city), "construction modifier must match the saved pressure stage and food risk")

	var forged_credit := snapshot.duplicate(true)
	forged_credit.pressure.recovery_credit_balance_ms = 600001
	_check(not _valid(forged_credit, city), "finite recovery credit cannot exceed the campaign cap")

	var forged_observed_losses := snapshot.duplicate(true)
	forged_observed_losses.pressure.observed_combat_losses = int(snapshot.combat_losses_total) + 1
	_check(not _valid(forged_observed_losses, city), "observed recovery losses cannot exceed authoritative combat losses")

	var observed_reedbank := snapshot.duplicate(true)
	observed_reedbank.scouted = {&"reedbank_garrison": {"defender_count": 0, "observed_ms": 0}}
	_check(_valid(observed_reedbank, city), "authored reedbank visibility persists as a legal observed point")
	var malformed_scout := snapshot.duplicate(true)
	malformed_scout.scouted = {&"reedbank_garrison": "invalid"}
	_check(not _valid(malformed_scout, city), "malformed scouting values reject without a typed-assignment exception")

	var malformed_project := snapshot.duplicate(true)
	malformed_project.project = {"id": &"regular.building.000002", "kind": &"FARM", "plot": 0, "progress_ms": 45000, "required_ms": 90000, "paid_wood": 1, "paid_food": 0, "wood_cost": 45, "food_cost": 0}
	malformed_project.next_building_id = 3
	_check(not _valid(malformed_project, city), "project paid costs must equal its recorded build progress")

	var logging_build: Dictionary = runtime.command(&"build", {"point_id": &"blackstone_city", "kind": &"LOGGING", "plot": 0})
	_check(bool(logging_build.get("success", false)) and _valid(runtime.get_snapshot(), city), "normal zero-progress logging project persists with exact authored costs")

	scene.queue_free()
	await process_frame
	_finish()


func _valid(payload: Dictionary, city: Node) -> bool:
	var validation := RegularCampaignRuntime.validate_snapshot(
		payload,
		city.get_nation_state().get_scoped_resources(),
		city._army_registry.get_snapshot()
	)
	return bool(validation.get("valid", false))


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1_VALIDATION PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("REGULAR_CAMPAIGN_R1_VALIDATION FAIL: %s" % failure)
	quit(1)
