extends SceneTree


## SAVE_RECOVERY_FAILSAFE_R1 controlled recovery matrix. Every case runs in a
## fresh isolated directory under /private/tmp/txwzs-recovery-failsafe-*, never
## touching the player's default store. Cases:
##  A  empty directory + CONTINUE   -> initial classic generation, no campaign
##  B  valid PREPARATION cold restore (no rebuild)
##  C  valid ACTIVE cold restore (no rebuild)
##  D  latest generation corrupt    -> explicit previous-generation fallback,
##     corrupt file kept byte-identical, no new campaign
##  E1 readable JSON but invalid regular_campaign, single generation
##     -> load_blocked, nothing written
##  E2 same corruption with a valid earlier generation -> fallback again
##  F  every generation unrecoverable -> load_blocked, all hashes unchanged
##  G  explicit REGULAR new game      -> initialize_new only here, old files kept

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const RUNTIME_IDENTITY = preload("res://scripts/runtime_identity.gd")
const REGULAR_SCOPE := &"regular.qingyuan.r1"
const BASE := &"blackstone_city"
const DELIVERY_DIR := "/Users/m4-zhi/Documents/TXWZS_RECOVERY_FAILSAFE_R1_DELIVERY"

var failures: Array[String] = []
var _case_log: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	if not mode.is_empty():
		await _run_worker(mode)
		return
	_run_matrix()


func _run_matrix() -> void:
	var root_dir := "/private/tmp/txwzs-recovery-failsafe-%d-%d" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	]
	var dir_a := root_dir + "/a"
	var dir_b := root_dir + "/b"
	var dir_e := root_dir + "/e"
	var dir_e2 := root_dir + "/e2"
	var dir_f := root_dir + "/f"
	var dir_g := root_dir + "/g"
	for path in [dir_a, dir_b, dir_e, dir_e2, dir_f, dir_g]:
		DirAccess.make_dir_recursive_absolute(path)

	# Title gate on an empty directory: no continuable campaign, so the title
	# can only offer explicit new-game entries.
	var empty_store := V5CampaignSaveStore.new(dir_a)
	_check(not empty_store.has_any_generation(), "A: 空目录 has_any_generation=false（标题无可继续进度）")

	_case("A", dir_a, {}, "a_empty", func() -> Dictionary:
		var worker := _worker("A", dir_a)
		var listing := _campaign_files(dir_a)
		_check(_workers_passed([worker]), "A: CONTINUE+空目录 → 初始经典代次、无战役、不 initialize_new")
		_check(listing.size() == 1, "A: 恰好生成 1 个初始代次（实际 %d）" % listing.size())
		_check(listing.size() == 1 and not FileAccess.get_file_as_string(listing[0]).contains("attempt_sequence"),
			"A: 初始代次无任何战役运行时数据（未伪造战役）")
		return {"worker": worker["output"], "generations": listing.size()}
	)

	_case("B_produce", dir_b, {}, "b_produce", func() -> Dictionary:
		var worker := _worker("B_PRODUCE", dir_b)
		_check(_workers_passed([worker]), "B: REGULAR 显式新局产出 gen1(新战役)+gen2(推进后事实)")
		return {"worker": worker["output"]}
	)
	var b_facts := _load_facts(dir_b, "b")
	var b_files := _hash_dir(dir_b)

	_inventory(dir_b, "after_B_produce")
	_case("B_verify", dir_b, b_files, "b_verify", func() -> Dictionary:
		var worker := _worker("B_VERIFY", dir_b)
		var restored := _load_facts(dir_b, "b_verify")
		_check(_workers_passed([worker]), "B: 冷启动恢复 PREPARATION（loaded_latest，无重建）")
		_check(_facts_equal(restored, b_facts), "B: 恢复事实与 gen2 一致（mainline/资源逐项相等）")
		_check(int(restored.get("mainline_ms", -1)) != 0, "B: mainline=%d ≠ 0 证明数据来自磁盘而非 initialize_new" % int(restored.get("mainline_ms", -1)))
		return {"worker": worker["output"], "facts": restored}
	)

	_case("C_produce", dir_b, _hash_dir(dir_b), "c_produce", func() -> Dictionary:
		var worker := _worker("C_PRODUCE", dir_b)
		_check(_workers_passed([worker]), "C: 真实 depart 产出 ACTIVE 代次 gen3")
		return {"worker": worker["output"]}
	)
	var c_facts := _load_facts(dir_b, "c")
	_check(String(c_facts.get("phase", "")) == "ACTIVE" and Array(c_facts.get("armies", [])).size() > 0,
		"C: gen3 事实为 ACTIVE 且军队非空")

	_inventory(dir_b, "after_C_produce")
	_case("C_verify", dir_b, _hash_dir(dir_b), "c_verify", func() -> Dictionary:
		var worker := _worker("C_VERIFY", dir_b)
		var restored := _load_facts(dir_b, "c_verify")
		_check(_workers_passed([worker]), "C: 冷启动恢复 ACTIVE（loaded_latest，无重建）")
		_check(_facts_equal(restored, c_facts), "C: ACTIVE 事实逐项一致（军队/压力/时间/资源）")
		return {"worker": worker["output"], "facts": restored}
	)

	_inventory(dir_b, "after_C_verify")
	_case("D_produce", dir_b, _hash_dir(dir_b), "d_produce", func() -> Dictionary:
		var worker := _worker("D_PRODUCE", dir_b)
		_check(_workers_passed([worker]), "D: 产出可区分的 gen4（农田工程推进）")
		return {"worker": worker["output"]}
	)
	var d_files := _hash_dir(dir_b)
	var gen4 := _latest_generation_path(dir_b)
	_corrupt_file_plain(gen4)
	var gen4_after := _hash_file(gen4)
	_check(gen4_after != d_files.get(gen4, ""), "D: gen4 已被 注入损坏（测试注入，非产品行为）")

	_inventory(dir_b, "after_D_produce")
	_case("D_verify", dir_b, _hash_dir(dir_b), "d_verify", func() -> Dictionary:
		var worker := _worker("D_VERIFY", dir_b)
		var restored := _load_facts(dir_b, "d_verify")
		_check(_workers_passed([worker]), "D: 最新代损坏 → 回退上一合法代（recovered_previous_generation）")
		_check(_facts_equal(restored, c_facts), "D: 恢复事实等于 gen3（而非 gen4），无新战役")
		_check(not _facts_equal(restored, _stored_facts(dir_b, "d")), "D: 恢复事实确实不同于被损坏的 gen4")
		_check(_hash_file(gen4) == gen4_after, "D: 损坏的 gen4 文件逐字节保留，未被覆盖或删除")
		return {"worker": worker["output"], "facts": restored}
	)

	# E2: dedicated two-generation directory. Latest generation is readable
	# JSON with a consistent outer hash, but its regular_campaign payload is
	# validator-invalid -> must fall back to the previous valid generation.
	_case("E2_produce", dir_e2, {}, "e2_produce", func() -> Dictionary:
		var worker := _worker("E2_PRODUCE", dir_e2)
		_check(_workers_passed([worker]), "E2: 产出两代目录（gen1 全新 + gen2 推进）")
		return {"worker": worker["output"]}
	)
	var e2_gen1_facts := _load_facts(dir_e2, "e2_gen1")
	var e2_latest := _latest_generation_path(dir_e2)
	_check(_surgically_invalidate_regular_campaign(e2_latest), "E2: 最新代 payload 校验失败注入完成")
	var e2_after_surgery := _hash_file(e2_latest)

	_case("E2_verify", dir_e2, _hash_dir(dir_e2), "e2_verify", func() -> Dictionary:
		var worker := _worker("E2_VERIFY", dir_e2)
		var restored := _load_facts(dir_e2, "e2_verify")
		_check(_workers_passed([worker]), "E2: 最新代校验失败 → 显式回退上一合法代（recovered）")
		_check(_facts_equal(restored, e2_gen1_facts), "E2: 回退事实等于 gen1（PREPARATION 全新事实）")
		_check(_hash_file(e2_latest) == e2_after_surgery, "E2: 被注入的损坏代次逐字节保留")
		return {"worker": worker["output"], "facts": restored}
	)

	# E1: single generation, readable JSON, validator-failing payload.
	_case("E1_produce", dir_e, {}, "e1_produce", func() -> Dictionary:
		var worker := _worker("E1_PRODUCE", dir_e)
		_check(_workers_passed([worker]), "E1: 产出单代目录")
		return {"worker": worker["output"]}
	)
	var e1_gen := _latest_generation_path(dir_e)
	_check(_surgically_invalidate_regular_campaign(e1_gen), "E1: gen1 payload 校验失败注入完成")
	var e1_before := _hash_file(e1_gen)

	_case("E1_verify", dir_e, _hash_dir(dir_e), "e1_verify", func() -> Dictionary:
		var worker := _worker("E1_VERIFY", dir_e)
		_check(_workers_passed([worker]), "E1: 全部代次不可恢复 → load_blocked，运行时禁用、不落新档")
		_check(_hash_file(e1_gen) == e1_before, "E1: 唯一代次逐字节保留")
		_check(_campaign_files(dir_e).size() == 1, "E1: 未产生新代次")
		return {"worker": worker["output"]}
	)

	# F: every generation unrecoverable.
	_case("F_produce", dir_f, {}, "f_produce", func() -> Dictionary:
		var worker := _worker("F_PRODUCE", dir_f)
		_check(_workers_passed([worker]), "F: 产出两个合法代次")
		return {"worker": worker["output"]}
	)
	var f_gens := _campaign_files(dir_f)
	for gen in f_gens:
		_corrupt_file_plain(gen)
	var f_before := _hash_dir(dir_f)

	_case("F_verify", dir_f, _hash_dir(dir_f), "f_verify", func() -> Dictionary:
		var worker := _worker("F_VERIFY", dir_f)
		_check(_workers_passed([worker]), "F: 全部代次损坏 → load_blocked（RECOVERY_FAILED 等价态）")
		var after := _hash_dir(dir_f)
		var same := after.size() == f_before.size()
		var detail := ""
		if same:
			for path in f_before:
				if _hash_file(path) != f_before[path]:
					same = false
					detail = "%s %s->%s" % [path, f_before[path].substr(0, 12), _hash_file(path).substr(0, 12)]
		_check(same, "F: 启动前后所有存档文件逐字节一致、无新代次 %s" % detail)
		return {"worker": worker["output"]}
	)

	# G: explicit REGULAR new game over an existing campaign.
	_case("G_produce1", dir_g, {}, "g1", func() -> Dictionary:
		var worker := _worker("G_PRODUCE1", dir_g)
		_check(_workers_passed([worker]), "G: 第一次显式新局建立旧战役（gen1+gen2）")
		return {"worker": worker["output"]}
	)
	var g_before := _hash_dir(dir_g)

	_case("G_produce2", dir_g, g_before, "g2", func() -> Dictionary:
		var worker := _worker("G_PRODUCE2", dir_g)
		_check(_workers_passed([worker]), "G: 再次显式新局 → initialize_new 产生全新最新代（不伪装恢复）")
		var after := _hash_dir(dir_g)
		var old_kept := true
		for path in g_before:
			if path != _latest_generation_path(dir_g) and _hash_file(path) != g_before[path]:
				old_kept = false
		_check(old_kept and after.size() == g_before.size() + 1,
			"G: 旧代次全部保留且恰好新增 1 个最新代")
		_check(_stored_facts(dir_g, "g2").get("mainline_ms", -1) == 0,
			"G: 新局 mainline=0（全新战役，与恢复失败严格区分）")
		return {"worker": worker["output"]}
	)

	_write_summary(root_dir)
	_finish()


func _payload_string(payload: String, key: String) -> String:
	var marker := "[\"%s\"," % key
	var start := payload.find(marker)
	if start < 0:
		return "?"
	var value_at := payload.find("\"", start + marker.length())
	if value_at < 0:
		return "?"
	var end := payload.find("\"", value_at + 1)
	if end < 0:
		return "?"
	return payload.substr(value_at + 1, end - value_at - 1)


func _inventory(dir: String, tag: String) -> void:
	for path in _campaign_files(dir):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var head := "UNPARSEABLE"
		if parsed is Dictionary:
			var payload := String(Dictionary(parsed).get("payload_json", ""))
			head = "phase=%s attempt=%s" % [
				_payload_string(payload, "phase"),
				_payload_string(payload, "attempt_sequence"),
			]
		print("INVENTORY[%s] %s %s" % [tag, path.get_file(), head])


func _case(case_name: String, dir: String, before: Variant, facts_suffix: String, body: Callable) -> void:
	var before_after := {}
	if not before.is_empty():
		before_after = before
	var result: Dictionary = body.call()
	if result.has("worker"):
		print("WORKER_OUT[%s]\n%s\n[/WORKER_OUT]" % [case_name, str(result["worker"])])
	result["case"] = case_name
	result["dir"] = dir
	result["files_before_count"] = before_after.size()
	result["files_after_count"] = _hash_dir(dir).size()
	_case_log.append(result)
	print("FAILSAFE_CASE %s done" % case_name)


func _run_worker(mode: String) -> void:
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	var scene: Node = CITY_SCENE.instantiate()
	if mode in ["B_PRODUCE", "E1_PRODUCE", "E2_PRODUCE", "F_PRODUCE", "G_PRODUCE1", "G_PRODUCE2"]:
		var identity: Node = root.get_node("/root/RuntimeIdentity")
		identity.request_campaign_start(RUNTIME_IDENTITY.CAMPAIGN_START_REGULAR)
	root.add_child(scene)
	var city: Node = scene.get_node_or_null("ConstructionController")
	if city != null:
		city.set_process(false)
	await process_frame
	await process_frame
	var passed := false
	match mode:
		"A":
			passed = _stage_a(city, scene)
		"B_PRODUCE":
			passed = _stage_b_produce(city, scene)
		"B_VERIFY":
			passed = _stage_b_verify(city, scene, save_directory)
		"C_PRODUCE":
			passed = _stage_c_produce(city, scene)
		"C_VERIFY":
			passed = _stage_c_verify(city, scene, save_directory)
		"D_PRODUCE":
			passed = _stage_d_produce(city, scene)
		"D_VERIFY":
			passed = _stage_d_verify(city, scene, save_directory)
		"E1_PRODUCE":
			passed = _stage_e1_produce(city)
		"E2_PRODUCE":
			passed = _stage_e2_produce(city, scene)
		"E1_VERIFY":
			passed = _stage_e1_verify(city, scene)
		"E2_VERIFY":
			passed = _stage_e2_verify(city, scene, save_directory)
		"F_PRODUCE":
			passed = _stage_f_produce(city, scene)
		"F_VERIFY":
			passed = _stage_f_verify(city, scene)
		"G_PRODUCE1":
			passed = _stage_g1(city, scene)
		"G_PRODUCE2":
			passed = _stage_g2(city, scene, save_directory)
		_:
			push_error("Unknown failsafe stage: %s" % mode)
	scene.queue_free()
	await process_frame
	_write_marker(save_directory, mode, passed)
	quit(0 if passed else 1)


func _stage_a(city: Node, scene: Node) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") if city != null else null
	print("FAILSAFE_A status=%s loaded=%s regular_null=%s writes_blocked=%s" % [
		str(status.get("status", "?")), str(status.get("loaded", false)),
		str(runtime == null), str(status.get("writes_blocked", false)),
	])
	return str(status.get("status", "")) == "created_initial_generation" and runtime == null


func _stage_b_produce(city: Node, scene: Node) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		print("FAILSAFE_B_PRODUCE no_runtime status=%s" % str(status.get("status", "?")))
		return false
	runtime.call("advance", 4.0)
	var saved: bool = scene.flush_runtime_persistence(&"failsafe_case_b")
	_store_facts(_argument_value("--txwzs-v5-save-dir="), "b", _facts(city, runtime))
	print("FAILSAFE_B_PRODUCE status=%s saved=%s facts=%s" % [
		str(status.get("status", "?")), str(saved), str(_facts(city, runtime)),
	])
	return saved


func _stage_b_verify(city: Node, scene: Node, save_directory: String) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	var ok := runtime != null and bool(runtime.call("enabled"))
	if ok:
		_store_facts(save_directory, "b_verify", _facts(city, runtime))
	print("FAILSAFE_B_VERIFY status=%s recovered=%s facts=%s" % [
		str(status.get("status", "?")), str(status.get("recovered", false)),
		str(_facts(city, runtime) if ok else {}),
	])
	return ok and str(status.get("status", "")) == "loaded_latest" and not bool(status.get("recovered", false))


func _stage_c_produce(city: Node, scene: Node) -> bool:
	print("FAILSAFE_BOOT status=%s facts=%s" % [
		str(scene.get_runtime_persistence_status().get("status", "?")),
		str(_facts(city, city.get("_regular_campaign")) if city.get("_regular_campaign") != null else {}),
	])
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		return false
	var departure: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 30, "wood": 55,
	})
	if not bool(departure.get("success", false)):
		print("FAILSAFE_C_PRODUCE depart_failed=%s" % str(departure))
		return false
	runtime.call("advance", 2.0)
	var saved: bool = scene.flush_runtime_persistence(&"failsafe_case_c")
	_store_facts(_argument_value("--txwzs-v5-save-dir="), "c", _facts(city, runtime))
	print("FAILSAFE_C_PRODUCE saved=%s facts=%s" % [str(saved), str(_facts(city, runtime))])
	return saved


func _stage_c_verify(city: Node, scene: Node, save_directory: String) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	var ok := runtime != null and bool(runtime.call("enabled"))
	if ok:
		_store_facts(save_directory, "c_verify", _facts(city, runtime))
	print("FAILSAFE_C_VERIFY status=%s facts=%s" % [
		str(status.get("status", "?")), str(_facts(city, runtime) if ok else {}),
	])
	return ok and str(status.get("status", "")) == "loaded_latest"


func _stage_d_produce(city: Node, scene: Node) -> bool:
	print("FAILSAFE_BOOT status=%s facts=%s" % [
		str(scene.get_runtime_persistence_status().get("status", "?")),
		str(_facts(city, city.get("_regular_campaign")) if city.get("_regular_campaign") != null else {}),
	])
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		return false
	runtime.call("advance", 8.0)
	var saved: bool = scene.flush_runtime_persistence(&"failsafe_case_d")
	_store_facts(_argument_value("--txwzs-v5-save-dir="), "d", _facts(city, runtime))
	print("FAILSAFE_D_PRODUCE saved=%s facts=%s" % [str(saved), str(_facts(city, runtime))])
	return saved


func _stage_d_verify(city: Node, scene: Node, save_directory: String) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	var ok := runtime != null and bool(runtime.call("enabled"))
	if ok:
		_store_facts(save_directory, "d_verify", _facts(city, runtime))
	print("FAILSAFE_D_VERIFY status=%s recovered=%s facts=%s" % [
		str(status.get("status", "?")), str(status.get("recovered", false)),
		str(_facts(city, runtime) if ok else {}),
	])
	return (
		ok
		and str(status.get("status", "")) == "recovered_previous_generation"
		and bool(status.get("recovered", false))
	)


func _stage_e2_produce(city: Node, scene: Node) -> bool:
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		return false
	_store_facts(_argument_value("--txwzs-v5-save-dir="), "e2_gen1", _facts(city, runtime))
	runtime.call("advance", 4.0)
	return scene.flush_runtime_persistence(&"failsafe_case_e2")


func _stage_e1_produce(city: Node) -> bool:
	var runtime: Object = city.get("_regular_campaign") as Object
	return runtime != null and bool(runtime.call("enabled"))


func _stage_e1_verify(city: Node, scene: Node) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign")
	print("FAILSAFE_E1_VERIFY status=%s error_id=%s writes_blocked=%s regular_null=%s" % [
		str(status.get("status", "?")), str(status.get("error_id", "?")),
		str(status.get("writes_blocked", false)), str(runtime == null),
	])
	return (
		str(status.get("status", "")) == "load_blocked"
		and str(status.get("error_id", "")) == "ALL_INVALID"
		and bool(status.get("writes_blocked", false))
		and runtime == null
	)


func _stage_e2_verify(city: Node, scene: Node, save_directory: String) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	var ok := runtime != null and bool(runtime.call("enabled"))
	if ok:
		_store_facts(save_directory, "e2_verify", _facts(city, runtime))
	print("FAILSAFE_E2_VERIFY status=%s recovered=%s facts=%s" % [
		str(status.get("status", "?")), str(status.get("recovered", false)),
		str(_facts(city, runtime) if ok else {}),
	])
	return (
		ok
		and str(status.get("status", "")) == "recovered_previous_generation"
		and bool(status.get("recovered", false))
	)


func _stage_f_produce(city: Node, scene: Node) -> bool:
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		return false
	runtime.call("advance", 2.0)
	return scene.flush_runtime_persistence(&"failsafe_case_f")


func _stage_f_verify(city: Node, scene: Node) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign")
	print("FAILSAFE_F_VERIFY status=%s error_id=%s writes_blocked=%s regular_null=%s" % [
		str(status.get("status", "?")), str(status.get("error_id", "?")),
		str(status.get("writes_blocked", false)), str(runtime == null),
	])
	return (
		str(status.get("status", "")) == "load_blocked"
		and str(status.get("error_id", "")) == "ALL_INVALID"
		and bool(status.get("writes_blocked", false))
		and runtime == null
	)


func _stage_g1(city: Node, scene: Node) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	runtime.call("advance", 2.0)
	var saved: bool = scene.flush_runtime_persistence(&"failsafe_case_g1")
	print("FAILSAFE_G1 status=%s saved=%s" % [str(status.get("status", "?")), str(saved)])
	return saved


func _stage_g2(city: Node, scene: Node, save_directory: String) -> bool:
	var status: Dictionary = scene.get_runtime_persistence_status()
	var runtime: Object = city.get("_regular_campaign") as Object
	var facts: Dictionary = _facts(city, runtime) if runtime != null else {}
	_store_facts(save_directory, "g2", facts)
	print("FAILSAFE_G2 status=%s facts=%s" % [str(status.get("status", "?")), str(facts)])
	return (
		str(status.get("status", "")) == "created_new_campaign_generation"
		and int(facts.get("mainline_ms", -1)) == 0
		and String(facts.get("phase", "")) == "PREPARATION"
	)


func _facts(city: Node, runtime: Object) -> Dictionary:
	var snapshot: Dictionary = runtime.call("get_snapshot")
	var scope: Dictionary = city.get_nation_state().get_scope(REGULAR_SCOPE)
	var armies: Array = []
	for army_id_value in Array(snapshot.get("army_ids", [])):
		var army: Dictionary = city._army_registry.get_army(StringName(army_id_value))
		var members := 0
		for count in Dictionary(army.get("units_by_definition_id", {})).values():
			members += int(count)
		armies.append({
			"id": String(army.get("army_id", "")),
			"phase": String(army.get("phase", "")),
			"members": members,
		})
	var project: Dictionary = Dictionary(snapshot.get("project", {}))
	return {
		"phase": String(snapshot.get("phase", "")),
		"mainline_ms": int(snapshot.get("mainline_elapsed_ms", 0)),
		"attempt_ms": int(snapshot.get("attempt_elapsed_ms", 0)),
		"attempt_sequence": int(snapshot.get("attempt_sequence", 0)),
		"project_progress_ms": int(project.get("progress_ms", 0)),
		"scope_food": int(scope.get(&"food", 0)),
		"scope_wood": int(scope.get(&"wood", 0)),
		"combat_losses_total": int(snapshot.get("combat_losses_total", 0)),
		"armies": armies,
	}


func _facts_equal(actual: Dictionary, expected: Dictionary) -> bool:
	for key in ["phase", "mainline_ms", "attempt_ms", "attempt_sequence", "project_progress_ms", "scope_food", "scope_wood", "combat_losses_total", "armies"]:
		if actual.get(key) != expected.get(key):
			return false
	return true


func _formation_ids(city: Node) -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation_value in city.get_formation_roster():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _store_facts(save_directory: String, suffix: String, facts: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var file := FileAccess.open(save_directory.path_join("failsafe_%s.facts" % suffix), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(facts))


func _load_facts(save_directory: String, suffix: String) -> Dictionary:
	var path := save_directory.path_join("failsafe_%s.facts" % suffix)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _stored_facts(dir: String, suffix: String) -> Dictionary:
	return _load_facts(dir, suffix)


func _write_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("failsafe_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("FAILSAFE_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path("res://tests/verify_save_recovery_failsafe_r1.gd"), "--",
			"--mode=%s" % mode,
			"--txwzs-require-isolated-save",
			"--txwzs-v5-save-dir=%s" % save_directory,
		]),
		output,
		true
	)
	var marker_path := save_directory.path_join("failsafe_%s.result" % mode.to_lower())
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {
		"mode": mode,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"passed": exit_code == 0 and marker == "FAILSAFE_%s PASS" % mode,
	}


func _workers_passed(workers: Array[Dictionary]) -> bool:
	for worker in workers:
		if not bool(worker.get("passed", false)):
			return false
	return true


func _campaign_files(dir: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return result
	var directory := DirAccess.open(dir)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name.begins_with("campaign_") and name.ends_with(".json"):
			result.append(dir + "/" + name)
		name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func _hash_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<missing>"
	return FileAccess.get_file_as_string(path).sha256_text()


func _hash_dir(dir: String) -> Dictionary:
	var result := {}
	for path in _campaign_files(dir):
		result[path] = _hash_file(path)
	return result


func _latest_generation_path(dir: String) -> String:
	var files := _campaign_files(dir)
	return files[files.size() - 1] if not files.is_empty() else ""


func _generation_path(dir: String, sequence: int) -> String:
	return "%s/campaign_%012d.json" % [dir, sequence]


func _corrupt_file_plain(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("{\"corrupted_by_test\":")
		file.flush()
		file.close()


func _surgically_invalidate_regular_campaign(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and Dictionary(parsed).has("payload_json"):
		var storage: Dictionary = parsed
		var payload := String(storage["payload_json"])
		var marker := "[\"attempt_sequence\","
		var start := payload.find(marker)
		if start < 0:
			return false
		var end := payload.find("]", start)
		if end < 0:
			return false
		storage["payload_json"] = (
			payload.substr(0, start)
			+ marker + "\"failsafe_corrupt\"]"
			+ payload.substr(end + 1)
		)
		storage["payload_sha256"] = String(storage["payload_json"]).sha256_text()
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(JSON.stringify(storage))
		file.flush()
		file.close()
		return true
	return false


func _write_summary(root_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(DELIVERY_DIR)
	var payload := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"isolated_root": root_dir,
		"all_passed": failures.is_empty(),
		"cases": _case_log,
	}
	var file := FileAccess.open(DELIVERY_DIR + "/matrix_summary.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		file.close()
	print("FAILSAFE_SUMMARY_WRITTEN %s/matrix_summary.json" % DELIVERY_DIR)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAILSAFE FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("SAVE_RECOVERY_FAILSAFE_R1 PASS cases=%d" % _case_log.size())
		quit(0)
		return
	for failure in failures:
		push_error("SAVE_RECOVERY_FAILSAFE_R1 FAIL: %s" % failure)
	quit(1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
