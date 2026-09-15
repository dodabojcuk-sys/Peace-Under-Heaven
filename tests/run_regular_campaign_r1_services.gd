extends SceneTree


## End-to-end service-chain coverage for Regular Campaign R1.
##
## This runner begins at the formal blank-map entry and uses only regular
## campaign commands. It never adds resources, soldiers, battle outcomes, or
## fixtures. Invoke it with an isolated --txwzs-v5-save-dir argument.

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const REGULAR_SCOPE := &"regular.qingyuan.r1"
const BASE := &"blackstone_city"
const SILVERFORD := &"silverford_city"
const REDCLIFF := &"redcliff_city"

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node_or_null("ConstructionController")
	if city == null:
		_check(false, "formal blank-map scene exposes ConstructionController")
		_finish(scene)
		return
	city.set_process(false)
	if not _is_success(city.initialize_regular_campaign()):
		_check(false, "formal controller starts the regular campaign")
		_finish(scene)
		return
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not runtime.enabled():
		_check(false, "regular campaign runtime is enabled")
		_finish(scene)
		return

	var initial_roster := _roster_total(city.get_formation_roster())
	var initial_food := int(city.food)
	var initial_wood := int(city.wood)
	var army_ids := _formation_ids(city.get_formation_roster())
	var departure: Dictionary = _command(runtime, &"depart", {
		"formation_ids": army_ids,
		"food": 30,
		"wood": 55,
	})
	var snapshot: Dictionary = runtime.get_snapshot()
	var regular_ids: Array = Array(snapshot.get("army_ids", []))
	_check(
		bool(departure.get("success", false))
			and initial_roster == 20
			and initial_food - int(city.food) == 30
			and initial_wood - int(city.wood) == 55
			and int(_scope(city).get(&"food", -1)) == 30
			and int(_scope(city).get(&"wood", -1)) == 55
			and regular_ids.size() == 3
			and _army_total(city, regular_ids) == 20,
		"normal entry transfers the real 20-soldier roster and exactly 30 food / 55 wood into the scoped campaign inventory"
	)
	if not bool(departure.get("success", false)) or regular_ids.is_empty():
		_finish(scene)
		return
	runtime.advance(2.0)

	var logging_id := _build_complete_connect(runtime, &"LOGGING", 0)
	if logging_id == &"":
		_finish(scene)
		return
	var logging_workers := _command(runtime, &"workers", {"building_id": logging_id, "count": 4})
	runtime.advance(360.0)
	snapshot = runtime.get_snapshot()
	_check(
		bool(logging_workers.get("success", false))
			and int(Dictionary(snapshot.get("totals", {})).get("wood_produced", 0)) == 36
			and int(_scope(city).get(&"wood", -1)) == 49,
		"a connected four-worker logging camp earns two real 18-wood cycles before later construction"
	)

	var farm_id := _build_complete_connect(runtime, &"FARM", 1)
	if farm_id == &"":
		_finish(scene)
		return
	var farm_workers := _command(runtime, &"workers", {"building_id": farm_id, "count": 4})
	runtime.advance(540.0)
	snapshot = runtime.get_snapshot()
	_check(
		bool(farm_workers.get("success", false))
			and int(Dictionary(snapshot.get("totals", {})).get("wood_produced", 0)) == 108
			and int(Dictionary(snapshot.get("totals", {})).get("food_produced", 0)) == 66
			and int(_scope(city).get(&"wood", -1)) == 74,
		"farm completion and three further logging cycles use real production, rations, and timed construction payments"
	)

	var clinic_id := _build_complete_connect(runtime, &"CLINIC", 2)
	if clinic_id == &"":
		_finish(scene)
		return
	var clinic_workers := _command(runtime, &"workers", {"building_id": clinic_id, "count": 4})
	runtime.advance(540.0)
	var warehouse_id := _build_complete_connect(runtime, &"WAREHOUSE", 3)
	if warehouse_id == &"":
		_finish(scene)
		return
	var after_services: Dictionary = runtime.get_snapshot()
	_check(
		bool(clinic_workers.get("success", false))
			and _connected_kind_count(after_services, &"LOGGING") == 1
			and _connected_kind_count(after_services, &"FARM") == 1
			and _connected_kind_count(after_services, &"CLINIC") == 1
			and _connected_kind_count(after_services, &"WAREHOUSE") == 1
			and int(Dictionary(after_services.get("totals", {})).get("wood_used", 0)) == 198
			and int(_read_local_capacity(runtime)) == 200
			and _runtime_snapshot_is_valid(runtime, city),
		"clinic and warehouse follow the logging-first material chain with their authored costs, road fees, and raised storage capacity"
	)

	var service_army := StringName(regular_ids[0])
	var march_silver := _command(runtime, &"move", {"army_id": service_army, "target_id": SILVERFORD})
	var silver_controlled := _advance_until(runtime, city, 240.0, func() -> bool:
		return not city._war_loop_state.is_enemy_city(SILVERFORD)
	)
	var stock_before_supply := _scope(city)
	var field = city._war_loop_state.field_tactics
	var supply_before := int(Dictionary(field.supply_inventory_by_point_id).get(SILVERFORD, 0))
	var supply: Dictionary = _command(runtime, &"supply", {"army_id": service_army})
	var stock_after_supply := _scope(city)
	var supply_after := int(Dictionary(field.supply_inventory_by_point_id).get(SILVERFORD, 0))
	var training: Dictionary = _command(runtime, &"train", {"army_id": service_army})
	var move_while_training: Dictionary = _command(runtime, &"move", {"army_id": service_army, "target_id": REDCLIFF})
	var training_finished := _advance_until(runtime, city, 720.0, func() -> bool:
		return Dictionary(runtime.get_snapshot().get("training", {})).is_empty()
	)
	var after_training: Dictionary = runtime.get_snapshot()
	var local_joined := int(after_training.get("local_joined", 0))
	_check(
		bool(march_silver.get("success", false))
			and silver_controlled
			and not city._war_loop_state.is_level_cleared()
			and supply_before > 0
			and bool(supply.get("success", false))
			and int(stock_after_supply.get(&"food", 0)) > int(stock_before_supply.get(&"food", 0))
			and supply_after < supply_before
			and bool(training.get("success", false))
			and not bool(move_while_training.get("success", false))
			and training_finished
			and local_joined > 0
			and int(Dictionary(after_training.get("local_by_army", {})).get(service_army, 0)) == local_joined,
		"controlled Silverford provides finite supply and local training; training blocks movement and its finished recruits retain local provenance"
	)
	if not silver_controlled or not training_finished or local_joined <= 0:
		_finish(scene)
		return

	# Keep the locally trained force at Silverford. A separate home-origin force
	# supplies the retreat case, so clinic recovery proves that home casualties
	# stay reserved until settlement while local recruits still never return home.
	var release_logging: Dictionary = _command(runtime, &"workers", {"building_id": logging_id, "count": 0})
	var release_farm: Dictionary = _command(runtime, &"workers", {"building_id": farm_id, "count": 0})
	var battle_army := StringName(regular_ids[1])
	var members_before_retreat := _army_members(city._army_registry.get_army(battle_army))
	var assault: Dictionary = _command(runtime, &"move", {"army_id": battle_army, "target_id": REDCLIFF})
	var engaged := _advance_until(runtime, city, 120.0, func() -> bool:
		var siege: Dictionary = city._war_loop_state.get_siege(REDCLIFF)
		return StringName(siege.get("phase", &"")) == WarLoopState.PHASE_SIEGING and int(siege.get("tick", 0)) >= 4
	)
	var retreat: Dictionary = _command(runtime, &"move", {"army_id": battle_army, "target_id": BASE})
	var returned_to_base := _advance_until(runtime, city, 180.0, func() -> bool:
		var army: Dictionary = city._army_registry.get_army(battle_army)
		return StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and StringName(army.get("target_node_id", &"")) == BASE
	)
	var post_retreat: Dictionary = runtime.get_snapshot()
	var wounded_before_treatment := _wounded_home(post_retreat)
	var fallen_before_treatment := int(post_retreat.get("fallen_home", 0))
	var members_after_retreat := _army_members(city._army_registry.get_army(battle_army))
	var treatment: Dictionary = _command(runtime, &"treat")
	var treatment_finished := _advance_until(runtime, city, 180.0, func() -> bool:
		return Dictionary(runtime.get_snapshot().get("treatment", {})).is_empty()
	)
	var post_treatment: Dictionary = runtime.get_snapshot()
	var members_after_treatment := _army_members(city._army_registry.get_army(battle_army))
	_check(
		bool(release_logging.get("success", false))
			and bool(release_farm.get("success", false))
			and bool(assault.get("success", false))
			and engaged
			and bool(retreat.get("success", false))
			and returned_to_base
			and members_after_retreat < members_before_retreat
			and wounded_before_treatment > 0
			and fallen_before_treatment > 0
			and bool(treatment.get("success", false))
			and treatment_finished
			and _wounded_home(post_treatment) < wounded_before_treatment
			and members_after_treatment > members_after_retreat
			and int(post_treatment.get("fallen_home", 0)) == fallen_before_treatment,
		"a real mid-siege retreat creates wounded and fallen; a connected staffed clinic restores only wounded living members"
	)
	if not treatment_finished:
		_finish(scene)
		return

	var withdrawal: Dictionary = _command(runtime, &"outcome", {"kind": &"WITHDRAW"})
	var before_confirm: Dictionary = runtime.get_snapshot()
	var confirmed: Dictionary = _command(runtime, &"confirm")
	var final_roster := _roster_total(city.get_formation_roster())
	_check(
		bool(withdrawal.get("success", false))
			and bool(confirmed.get("success", false))
			and StringName(runtime.get_snapshot().get("phase", &"")) == &"PREPARATION"
			and final_roster == initial_roster - fallen_before_treatment
			and final_roster != initial_roster - fallen_before_treatment + local_joined
			and int(before_confirm.get("local_joined", 0)) == local_joined,
		"withdraw-preview confirmation returns only home survivors: local recruits stay local and fallen members are never recreated"
	)
	_finish(scene)


func _build_complete_connect(runtime: Object, kind: StringName, plot: int) -> StringName:
	var build: Dictionary = _command(runtime, &"build", {
		"point_id": BASE,
		"kind": kind,
		"plot": plot,
	})
	if not bool(build.get("success", false)):
		_check(false, "%s construction command succeeds" % String(kind))
		return &""
	runtime.advance(90.0)
	var building_id := _building_id(runtime.get_snapshot(), kind)
	if building_id == &"":
		_check(false, "%s completes through timed construction" % String(kind))
		return &""
	var connect: Dictionary = _command(runtime, &"connect", {"building_id": building_id})
	_check(bool(connect.get("success", false)), "%s pays its real road connection" % String(kind))
	return building_id if bool(connect.get("success", false)) else &""


func _advance_until(runtime: Object, city: Node, maximum_seconds: float, predicate: Callable) -> bool:
	for _tick in range(ceili(maximum_seconds * 4.0)):
		if predicate.call():
			return true
		runtime.advance(0.25)
		if city.city_time_paused:
			return false
	return bool(predicate.call())


func _command(runtime: Object, action: StringName, args: Dictionary = {}) -> Dictionary:
	var result: Dictionary = runtime.command(action, args)
	print("ACTION %s %s" % [String(action), str(result)])
	return result


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


func _army_total(city: Node, army_ids: Array) -> int:
	var total := 0
	for id_value in army_ids:
		total += _army_members(city._army_registry.get_army(StringName(id_value)))
	return total


func _army_members(army: Dictionary) -> int:
	var total := 0
	for value in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(value)
	return total


func _scope(city: Node) -> Dictionary:
	return city.get_nation_state().get_scope(REGULAR_SCOPE)


func _building_id(snapshot: Dictionary, kind: StringName) -> StringName:
	for value in Array(snapshot.get("buildings", [])):
		var building: Dictionary = Dictionary(value)
		if StringName(building.get("kind", &"")) == kind:
			return StringName(building.get("id", &""))
	return &""


func _connected_kind_count(snapshot: Dictionary, kind: StringName) -> int:
	var count := 0
	for value in Array(snapshot.get("buildings", [])):
		var building: Dictionary = Dictionary(value)
		if StringName(building.get("kind", &"")) == kind and bool(building.get("connected", false)):
			count += 1
	return count


func _read_local_capacity(runtime: Object) -> int:
	var model: Dictionary = runtime.get_read_model()
	return int(Dictionary(model.get("local", {})).get("capacity", 0))


func _wounded_home(snapshot: Dictionary) -> int:
	var total := 0
	for value in Dictionary(snapshot.get("wounded_by_army", {})).values():
		total += int(Dictionary(value).get("home", 0))
	return total


func _runtime_snapshot_is_valid(runtime: Object, city: Node) -> bool:
	var validation: Dictionary = RegularCampaignRuntime.validate_snapshot(
		runtime.get_snapshot(),
		city.get_nation_state().get_scoped_resources(),
		city._army_registry.get_snapshot()
	)
	return bool(validation.get("valid", false))


func _is_success(value: Variant) -> bool:
	return bool(Dictionary(value).get("success", false)) if value is Dictionary else bool(value)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish(scene: Node) -> void:
	if not failures.is_empty():
		for failure in failures:
			push_error("REGULAR_CAMPAIGN_R1_SERVICES FAIL: %s" % failure)
	if scene != null:
		scene.queue_free()
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1_SERVICES PASS assertions=%d" % assertions)
		quit(0)
		return
	quit(1)
