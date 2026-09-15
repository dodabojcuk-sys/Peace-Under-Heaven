extends SceneTree


## Normal-command integration coverage for Regular Campaign R1.
##
## This runner never adds food, wood, soldiers, a battle result, or a save
## fixture. It starts the regular mode from the formal blank-map controller and
## uses only its exposed initialization plus runtime commands. Persistence must
## be redirected by the invoking command to an isolated save directory.

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const REGULAR_SCOPE := &"regular.qingyuan.r1"
const BASE := &"blackstone_city"
const NORTHWATCH := &"northwatch_garrison"

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var setup := await _make_regular_city()
	if setup.is_empty():
		_check(false, "regular controller initializes before the normal-command journey")
		_finish()
		return
	var scene: Node = setup.scene
	var city: Node = setup.city
	var runtime: Object = setup.runtime
	await _check_normal_journey(city, runtime)
	scene.queue_free()
	await process_frame
	_finish()


func _make_regular_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node_or_null("ConstructionController")
	_check(city != null, "formal blank-map scene exposes the ConstructionController")
	if city == null:
		scene.queue_free()
		return {}
	city.set_process(false)
	if not city.has_method(&"initialize_regular_campaign"):
		_check(false, "ConstructionController exposes the regular-campaign initialization API")
		scene.queue_free()
		return {}
	var initialized = city.initialize_regular_campaign()
	_check(_is_success(initialized), "normal controller initialization starts Regular Campaign R1")
	# The controller currently exposes initialization but no public runtime getter.
	# Read this controller-owned object only to issue the same commands that its
	# regular-campaign view uses; the runner never writes the field or its data.
	var runtime: Object = city.get("_regular_campaign") as Object
	_check(runtime != null and runtime.enabled(), "controller exposes one enabled regular-campaign runtime")
	if runtime == null or not runtime.enabled():
		scene.queue_free()
		return {}
	return {"scene": scene, "city": city, "runtime": runtime}


func _check_normal_journey(city: Node, runtime: Object) -> void:
	var fresh: Dictionary = runtime.get_snapshot()
	var home_food_before := int(city.food)
	var home_wood_before := int(city.wood)
	var garrison_before := _roster_total(city.get_formation_roster())
	var available_ids := _nonempty_formation_ids(city.get_formation_roster())
	var selected_ids: Array[StringName] = []
	if not available_ids.is_empty():
		selected_ids.append(available_ids[0])
	_check(
		StringName(fresh.get("phase", &"")) == &"PREPARATION"
			and int(fresh.get("mainline_elapsed_ms", -1)) == 0
			and selected_ids.size() > 0,
		"fresh regular campaign begins from the normal controller roster and zero mainline elapsed time"
	)

	var departure: Dictionary = runtime.command(&"depart", {
		"formation_ids": selected_ids,
		"food": 30,
		"wood": 55,
	})
	var after_departure: Dictionary = runtime.get_snapshot()
	var army_id := StringName(Array(after_departure.get("army_ids", []))[0]) if not Array(after_departure.get("army_ids", [])).is_empty() else &""
	var active_army: Dictionary = city._army_registry.get_army(army_id)
	var local_stock: Dictionary = city.get_nation_state().get_scope(REGULAR_SCOPE)
	_check(
		bool(departure.get("success", false))
			and StringName(after_departure.get("phase", &"")) == &"ACTIVE"
			and home_food_before - int(city.food) == 30
			and home_wood_before - int(city.wood) == 55
			and int(local_stock.get(&"food", -1)) == 30
			and int(local_stock.get(&"wood", -1)) == 55
			and _roster_total(city.get_formation_roster()) + _army_members(active_army) == garrison_before,
		"departure transfers one existing force and one local food/wood scope without duplicating soldiers or supplies"
	)
	if army_id == &"" or not bool(departure.get("success", false)):
		return
	runtime.advance(1.0)
	active_army = city._army_registry.get_army(army_id)
	_check(
		_runtime_snapshot_is_valid(runtime, city),
		"single-army active state remains a valid canonical campaign snapshot after entry"
	)
	_check(
		StringName(active_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED
			and StringName(active_army.get("target_node_id", &"")) == BASE,
		"the transferred force reaches the regular campaign base through its normal initial movement"
	)

	var build: Dictionary = runtime.command(&"build", {
		"point_id": BASE,
		"kind": &"FARM",
		"plot": 0,
	})
	var stock_before_build: Dictionary = city.get_nation_state().get_scope(REGULAR_SCOPE)
	runtime.advance(90.0)
	_check(
		_runtime_snapshot_is_valid(runtime, city),
		"completed local farm remains a valid canonical campaign snapshot"
	)
	var built: Dictionary = runtime.get_snapshot()
	var buildings: Array = Array(built.get("buildings", []))
	var farm_id := StringName(Dictionary(buildings[0]).get("id", &"")) if not buildings.is_empty() else &""
	var stock_after_build: Dictionary = city.get_nation_state().get_scope(REGULAR_SCOPE)
	_check(
		bool(build.get("success", false))
			and farm_id != &""
			and StringName(Dictionary(buildings[0]).get("kind", &"")) == &"FARM"
			and int(stock_after_build.get(&"wood", 0)) < int(stock_before_build.get(&"wood", 0)),
		"farm completion uses timed local construction payments instead of granting a free productive building"
	)
	if farm_id == &"":
		return

	var connect: Dictionary = runtime.command(&"connect", {"building_id": farm_id})
	var workers: Dictionary = runtime.command(&"workers", {"building_id": farm_id, "count": 4})
	runtime.advance(180.0)
	var productive: Dictionary = runtime.get_snapshot()
	var blocked_move: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": NORTHWATCH})
	_check(
		bool(connect.get("success", false))
			and bool(workers.get("success", false))
			and int(Dictionary(productive.get("totals", {})).get("food_produced", 0)) > 0
			and not bool(blocked_move.get("success", false)),
		"only connected staffed farm produces local food, and its stationed workers block moving their only army"
	)
	var release_workers: Dictionary = runtime.command(&"workers", {"building_id": farm_id, "count": 0})
	var move: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": NORTHWATCH})
	_check(
		bool(release_workers.get("success", false)) and bool(move.get("success", false)),
		"releasing workers permits a normal in-campaign movement order without a new home dispatch"
	)

	var before_withdraw: Dictionary = runtime.get_snapshot()
	var withdraw: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	var pending: Dictionary = runtime.get_snapshot()
	_check(
		bool(withdraw.get("success", false))
			and StringName(pending.get("phase", &"")) == &"PENDING"
			and int(pending.get("mainline_elapsed_ms", 0)) == int(before_withdraw.get("mainline_elapsed_ms", -1)),
		"withdrawal creates a pending settlement without rewinding the authoritative mainline clock"
	)
	var retry: Dictionary = runtime.command(&"retry")
	var after_retry: Dictionary = runtime.get_snapshot()
	_check(
		bool(retry.get("success", false))
			and StringName(after_retry.get("phase", &"")) == &"ACTIVE"
			and int(after_retry.get("mainline_elapsed_ms", 0)) == int(before_withdraw.get("mainline_elapsed_ms", -1))
			and int(after_retry.get("attempt_sequence", 0)) == int(before_withdraw.get("attempt_sequence", 0)) + 1,
		"retry restores attempt-owned facts while preserving elapsed mainline pressure and advancing only the attempt identity"
	)
	var second_withdraw: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	var confirm: Dictionary = runtime.command(&"confirm")
	var after_confirm: Dictionary = runtime.get_snapshot()
	var roster_after_confirm := _roster_total(city.get_formation_roster())
	var repeat_confirm: Dictionary = runtime.command(&"confirm")
	_check(
		bool(second_withdraw.get("success", false))
			and bool(confirm.get("success", false))
			and StringName(after_confirm.get("phase", &"")) == &"PREPARATION"
			and roster_after_confirm == garrison_before
			and not bool(repeat_confirm.get("success", false))
			and runtime.get_snapshot() == after_confirm,
		"confirmed withdrawal returns the original force once; repeating confirmation is a zero-write idempotence guard"
	)


func _nonempty_formation_ids(roster: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation_value in roster:
		var formation: Dictionary = formation_value
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _roster_total(roster: Array) -> int:
	var total := 0
	for formation_value in roster:
		total += int(Dictionary(formation_value).get("member_count", 0))
	return total


func _army_members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _is_success(value: Variant) -> bool:
	if value is Dictionary:
		return bool(Dictionary(value).get("success", false))
	return bool(value)


func _runtime_snapshot_is_valid(runtime: Object, city: Node) -> bool:
	var payload: Dictionary = runtime.get_snapshot()
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
		print("REGULAR_CAMPAIGN_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("REGULAR_CAMPAIGN_R1_SMOKE FAIL: %s" % failure)
	quit(1)
