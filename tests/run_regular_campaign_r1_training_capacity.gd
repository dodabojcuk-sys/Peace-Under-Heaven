extends SceneTree


## Synthetic population-boundary fixture for Regular Campaign R1 home training.
##
## It uses a real home farm, six ordinary queued training batches, the
## canonical regular clock, and a normal withdrawal confirmation. The fixture
## settles extra civilians through the public population ledger solely to reach
## the future-city capacity boundary; it does not add soldiers, food, or a
## training result. Resource-conservation journeys remain covered separately.

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const FARM_ID := &"building.farm.t1"
const REGULAR_SCOPE := &"regular.qingyuan.r1"

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
	if city == null:
		_check(false, "formal controller is available")
		_finish(scene)
		return
	city.set_process(false)
	if not city.initialize_regular_campaign():
		_check(false, "regular campaign initializes")
		_finish(scene)
		return
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null:
		_check(false, "regular runtime is available")
		_finish(scene)
		return

	var farm: Resource = city.get_definition(FARM_ID) as Resource
	var farm_cell := _connected_farm_cell(city, farm)
	var farm_placement: int = int(city.place_definition_at_cell(FARM_ID, farm_cell, true, false))
	var second_farm_cell := _connected_farm_cell(city, farm)
	var second_farm_placement: int = int(city.place_definition_at_cell(FARM_ID, second_farm_cell, true, false))
	# Complete the ordinary home farms before the attempt opens. This preserves
	# the real city economy while avoiding a synthetic food grant for six
	# normal training batches.
	runtime.advance(540.0)
	var initial_garrison := _roster_total(city.get_formation_roster())
	var departure: Dictionary = runtime.command(&"depart", {
		"formation_ids": _formation_ids(city.get_formation_roster()),
		"food": 35,
		"wood": 0,
	})
	# SYNTHETIC population-boundary fixture: the fresh scenario owns only 20
	# spare residents, so it cannot reach the physical return boundary. Use the
	# existing refugee population-ledger lifecycle to establish a settled 20-person
	# future-city baseline; no soldiers, food, or training result is added.
	var accepted: bool = bool(city._population_recovery.accept_refugees(20))
	var settled: bool = bool(city._population_recovery.settle_refugees(20, 0))
	print(
		"TRAINING_CAPACITY_SYNTHETIC_FIXTURE farms=%d,%d garrison=%d departure=%s accepted=%s settled=%s scoped_food=%d" % [
			farm_placement,
			second_farm_placement,
			initial_garrison,
			str(bool(departure.get("success", false))),
			str(accepted),
			str(settled),
			int(city.get_nation_state().get_scope(REGULAR_SCOPE).get(&"food", 0)),
		]
	)
	_check(
		farm_placement > 0
			and second_farm_placement > 0
			and initial_garrison == 20
			and bool(departure.get("success", false))
			and accepted
			and settled
			and int(city.get_nation_state().get_scope(REGULAR_SCOPE).get(&"food", 0)) == 35,
		"a real home farm, settled future residents, and the full original garrison start the capacity boundary journey"
	)
	if farm_placement <= 0 or second_farm_placement <= 0 or not bool(departure.get("success", false)) or not accepted or not settled:
		_finish(scene)
		return

	var completed_batches := 0
	for _batch in range(6):
		var queued: Dictionary = city.request_training()
		if not bool(queued.get("success", false)):
			_check(false, "ordinary home training batch %d queues" % (completed_batches + 1))
			break
		runtime.advance(180.0)
		if city.training_queued_count == 0:
			completed_batches += 1
		else:
			_check(false, "ordinary home training batch %d completes on the canonical city boundary" % (completed_batches + 1))
			break
	var return_reserve := int(runtime.home_return_capacity_reservation())
	var garrison_after_training := _roster_total(city.get_formation_roster())
	var rejected: Dictionary = city.request_training()
	_check(
		completed_batches == 6
			and garrison_after_training == 30
			and return_reserve == initial_garrison
			and not bool(rejected.get("success", false))
			and StringName(rejected.get("error_id", &"")) == &"RETURN_CAPACITY_RESERVED",
		"home training stops at the 50-member recruitment/command budget minus the 20-member return reservation"
	)

	var withdrawal: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	var confirm: Dictionary = runtime.command(&"confirm")
	_check(
		bool(withdrawal.get("success", false))
			and bool(confirm.get("success", false))
			and _roster_total(city.get_formation_roster()) == 50
			and StringName(runtime.get_snapshot().get("phase", &"")) == &"PREPARATION",
		"the reserved return capacity lets normal confirmation settle all original soldiers without a permanent queue deadlock"
	)
	_finish(scene)


func _connected_farm_cell(city: Node, definition: Resource) -> Vector2i:
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var probe: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if bool(probe.get("valid", false)) and StringName(probe.get("connection_state", &"")) == &"connected":
				return cell
	return Vector2i(-1, -1)


func _formation_ids(roster: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for value in roster:
		var formation: Dictionary = Dictionary(value)
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _roster_total(roster: Array) -> int:
	var total := 0
	for value in roster:
		total += int(Dictionary(value).get("member_count", 0))
	return total


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish(scene: Node) -> void:
	if not failures.is_empty():
		for failure in failures:
			push_error("REGULAR_CAMPAIGN_R1_TRAINING_CAPACITY FAIL: %s" % failure)
	if scene != null:
		scene.queue_free()
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1_TRAINING_CAPACITY PASS assertions=%d" % assertions)
		quit(0)
		return
	quit(1)
