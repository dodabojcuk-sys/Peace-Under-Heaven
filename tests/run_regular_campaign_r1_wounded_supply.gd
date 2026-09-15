extends SceneTree


## A normal-command starvation regression: combat creates the wound, ordinary
## ration cycles consume the dispatched stock, and no fixture writes resources
## or troop counts. It proves that a force with no living members cannot retain
## wounded people indefinitely after actual unpaid rations.
const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const BASE := &"blackstone_city"
const SILVERFORD := &"silverford_city"
const REDCLIFF := &"redcliff_city"
const SCOPE := &"regular.qingyuan.r1"

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node_or_null("ConstructionController")
	_check(city != null, "normal scene provides the regular campaign controller")
	if city == null:
		_finish()
		return
	city.set_process(false)
	_check(bool(city.initialize_regular_campaign()), "regular campaign initializes")
	var runtime: Object = city.get("_regular_campaign") as Object
	var formation_ids := _first_formations(city.get_formation_roster(), 1)
	var depart: Dictionary = runtime.command(&"depart", {"formation_ids": formation_ids, "food": 8, "wood": 55})
	_check(bool(depart.get("success", false)), "one ordinary home formation departs with authored supplies")
	if not bool(depart.get("success", false)):
		scene.queue_free()
		_finish()
		return
	runtime.advance(1.0)
	var army_ids: Array = Array(runtime.get_snapshot().get("army_ids", []))
	var army_id := StringName(army_ids[0])

	# The clinic is built normally so this is a recoverable wounded state, but it
	# stays unstaffed while the same real rations are exhausted.
	var build: Dictionary = runtime.command(&"build", {"point_id": BASE, "kind": &"CLINIC", "plot": 0})
	runtime.advance(90.0)
	var clinic_id := _building_id(runtime.get_snapshot(), &"CLINIC")
	var connect: Dictionary = runtime.command(&"connect", {"building_id": clinic_id})
	_check(bool(build.get("success", false)) and clinic_id != &"" and bool(connect.get("success", false)), "clinic uses normal construction and road payment before the injury journey")

	# Silverford's ordinary training path brings a real, locally sourced member
	# into the deployed force. This must count as active military strength even
	# though it is excluded from the home-population settlement ledger.
	var march_silver: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": SILVERFORD})
	var silver_ready := _advance_until(runtime, city, 240.0, func() -> bool:
		var army: Dictionary = city._army_registry.get_army(army_id)
		return not city._war_loop_state.is_enemy_city(SILVERFORD) and StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and StringName(army.get("target_node_id", &"")) == SILVERFORD
	)
	var supply: Dictionary = runtime.command(&"supply", {"army_id": army_id})
	var training: Dictionary = runtime.command(&"train", {"army_id": army_id})
	var trained := _advance_until(runtime, city, 360.0, func() -> bool:
		return Dictionary(runtime.get_snapshot().get("training", {})).is_empty()
	)
	runtime.advance(15.0)
	var trained_snapshot: Dictionary = runtime.get_snapshot()
	var local_joined := int(Dictionary(trained_snapshot.get("local_by_army", {})).get(army_id, 0))
	var trained_pressure: Dictionary = Dictionary(trained_snapshot.get("pressure", {}))
	_check(
		bool(march_silver.get("success", false))
			and silver_ready
			and bool(supply.get("success", false))
			and bool(training.get("success", false))
			and trained
			and local_joined > 0
			and int(trained_pressure.get("total_military", -1)) == _living_military(city)
			and int(trained_pressure.get("total_military", -1)) != city._current_military_population(),
		"locally trained Silverford members count in pressure strength even though the population-conservation offset excludes them"
	)

	# No further supply, production, or test-side resource change follows.
	var assault: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": REDCLIFF})
	var engaged := _advance_until(runtime, city, 240.0, func() -> bool:
		var siege: Dictionary = city._war_loop_state.get_siege(REDCLIFF)
		return StringName(siege.get("phase", &"")) == WarLoopState.PHASE_SIEGING and int(siege.get("tick", 0)) >= 4
	)
	var retreat: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": BASE})
	var returned_or_closed := _advance_until(runtime, city, 240.0, func() -> bool:
		var army: Dictionary = city._army_registry.get_army(army_id)
		return StringName(army.get("phase", &"")) in [ArmyRegistry.PHASE_STATIONED, ArmyRegistry.PHASE_CLOSED]
	)
	var wounded_snapshot: Dictionary = runtime.get_snapshot()
	var wounds_before := _wounded_total(wounded_snapshot)
	var fallen_before := int(wounded_snapshot.get("fallen_home", 0))
	runtime.advance(15.0)
	var combat_snapshot: Dictionary = runtime.get_snapshot()
	var combat_pressure: Dictionary = Dictionary(combat_snapshot.get("pressure", {}))
	_check(bool(assault.get("success", false)) and engaged and bool(retreat.get("success", false)) and returned_or_closed and wounds_before > 0, "normal Redcliff combat and withdrawal create a real tracked-origin wound")
	_check(
		wounds_before + fallen_before > 0
			and int(combat_pressure.get("total_military", -1)) == _living_military(city)
			and _valid(combat_snapshot, city),
		"combat wounded and fallen remain outside pressure strength while the snapshot stays on the strict pressure schema"
	)
	if wounds_before <= 0:
		scene.queue_free()
		_finish()
		return

	# No supply, production, or test-side resource change follows. Bounded cycles
	# spend the remaining dispatched food, kill living members, then convert any
	# stranded wounded to fallen under continued unpaid rations.
	var exhausted := await _advance_ration_cycles(runtime, city, 40, func() -> bool:
		var state: Dictionary = runtime.get_snapshot()
		return int(city.get_nation_state().get_scope(SCOPE).get(&"food", -1)) == 0 and _wounded_total(state) == 0
	)
	var final_state: Dictionary = runtime.get_snapshot()
	var final_army: Dictionary = city._army_registry.get_army(army_id)
	var final_pressure: Dictionary = Dictionary(final_state.get("pressure", {}))
	_check(
		exhausted
			and _wounded_total(final_state) == 0
			and int(final_state.get("fallen_home", 0)) > fallen_before
			and StringName(final_army.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED
			and Dictionary(final_state.get("treatment", {})).is_empty()
			and int(final_pressure.get("total_military", -1)) == _living_military(city)
			and int(final_pressure.get("total_military", -1)) != city._current_military_population()
			and _valid(final_state, city),
		"continued unpaid real rations convert stranded wounded to fallen without a ghost treatment order, conservation break, or dead members counted as strength"
	)
	scene.queue_free()
	await process_frame
	_finish()


func _first_formations(roster: Array, count: int) -> Array:
	var ids: Array = []
	for value in roster:
		var formation: Dictionary = value
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
			if ids.size() == count:
				return ids
	return ids


func _building_id(snapshot: Dictionary, kind: StringName) -> StringName:
	for value in Array(snapshot.get("buildings", [])):
		var building: Dictionary = value
		if StringName(building.get("kind", &"")) == kind:
			return StringName(building.get("id", &""))
	return &""


func _wounded_total(snapshot: Dictionary) -> int:
	var total := 0
	for value in Dictionary(snapshot.get("wounded_by_army", {})).values():
		var pair: Dictionary = value
		total += int(pair.get("home", 0)) + int(pair.get("local", 0))
	return total


func _army_members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _living_military(city: Node) -> int:
	var total := int(city._garrison_state.get_total_count())
	for value in city._army_registry.get_armies():
		var army: Dictionary = value
		if StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_CLOSED:
			total += _army_members(army)
	return total


func _advance_until(runtime: Object, city: Node, maximum_seconds: float, predicate: Callable) -> bool:
	for _step in range(ceili(maximum_seconds * 4.0)):
		if predicate.call():
			return true
		runtime.advance(0.25)
		if city.city_time_paused:
			return false
	return bool(predicate.call())


func _advance_ration_cycles(runtime: Object, city: Node, maximum_cycles: int, predicate: Callable) -> bool:
	for _cycle in range(maximum_cycles):
		if predicate.call():
			return true
		var before: Dictionary = runtime.get_snapshot()
		var food_before := int(city.get_nation_state().get_scope(SCOPE).get(&"food", -1))
		runtime.advance(180.0)
		var after: Dictionary = runtime.get_snapshot()
		print("WOUNDED_RATION_TRACE cycle=%d elapsed=%d->%d phase=%s paused=%s food=%d->%d wounded=%d->%d" % [_cycle + 1, int(before.get("attempt_elapsed_ms", -1)), int(after.get("attempt_elapsed_ms", -1)), after.get("phase", &""), city.city_time_paused, food_before, int(city.get_nation_state().get_scope(SCOPE).get(&"food", -1)), _wounded_total(before), _wounded_total(after)])
		if city.city_time_paused:
			return false
		await process_frame
	return bool(predicate.call())


func _valid(payload: Dictionary, city: Node) -> bool:
	return bool(RegularCampaignRuntime.validate_snapshot(payload, city.get_nation_state().get_scoped_resources(), city._army_registry.get_snapshot()).get("valid", false))


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1_WOUNDED_SUPPLY PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("REGULAR_CAMPAIGN_R1_WOUNDED_SUPPLY FAIL: %s" % failure)
	quit(1)
