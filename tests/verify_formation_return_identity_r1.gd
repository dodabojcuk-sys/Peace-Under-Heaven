extends SceneTree

## FORMATION_RETURN_IDENTITY_R1 · 第 2 层：战后归队的编队身份（真实存档链）。
##
## 口径：每个 --stage 都是独立进程 + 同一隔离沙盒目录，boot 走正式 load_latest
## 恢复链；状态变化只经 runtime.command() 与 runtime.advance()，不注水、不改 data、
## 不绕过 persist。伤亡全部来自真实交战或真实断粮规则。
##
## 用例（各用自己的沙盒目录，互不继承）：
##   A 无伤亡撤军：三编队原样归队 + 幂等 + 冷启动 + 第二次出征
##   B 断粮伤亡：第一编队全灭、其余编队不同伤亡、身份仍各自归位
##   C 交战伤员：COMBAT 减员 + 本国伤员进 PopulationRecovery、不算已归队
##   D 胜利与当地人员：溪渡招募当地人员 → 双城占领 VICTORY → 当地人员不留主城
##
## facts JSON 落在各沙盒目录，供下一阶段冷启动比对。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const F1 := &"formation.blackstone.1"
const F2 := &"formation.blackstone.2"
const F3 := &"formation.blackstone.3"
const FORMATION_ORDER: Array[StringName] = [F1, F2, F3]
const FORMATION_NAMES := {
	F1: "北门先锋",
	F2: "山道卫队",
	F3: "城门后备",
}

var failures: Array[String] = []
var stage := ""
var case_id := "A"
var save_dir := ""
var facts_dir := ""
var city: Node
var runtime: RegularCampaignRuntime


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		print("ASSERT_FAIL ", label)
		failures.append(label)
		push_error(label)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _int_array(value: Variant) -> Array:
	var result: Array = []
	for item in Array(value):
		result.append(int(item))
	return result


func _str_array(value: Variant) -> Array:
	var result: Array = []
	for item in Array(value):
		result.append(str(item))
	return result


func _read_facts(name: String) -> Dictionary:
	var file := FileAccess.open(facts_dir.path_join(name), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return _dict(_normalize_json(parsed))


## JSON 把所有数字读回成 float（7 → 7.0），不归一化会把"数值一致"误判成不一致。
func _normalize_json(value: Variant) -> Variant:
	if value is Dictionary:
		var normalized := {}
		for key in value:
			normalized[str(key)] = _normalize_json(value[key])
		return normalized
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalize_json(item))
		return items
	if value is float and float(value) == float(int(value)):
		return int(value)
	return value


func _write_facts(name: String, facts: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(facts_dir)
	var file := FileAccess.open(facts_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		_expect(false, "写 facts " + name)
		return
	file.store_line(JSON.stringify(facts))
	file.close()


func _finish() -> void:
	var tag := "FORMATION_RETURN_IDENTITY_R1 %s %s" % [case_id, stage]
	if failures.is_empty():
		print(tag + " PASS")
		quit(0)
		return
	print(tag + " FAIL: %s" % [", ".join(failures)])
	quit(1)


func _wait_boot() -> bool:
	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in range(12):
		await process_frame
	city = scene.get_node_or_null("ConstructionController")
	if city == null:
		_expect(false, "城市场景未装载")
		return false
	runtime = city.get("_regular_campaign")
	return true


# ── 观察辅助（只读正式读模型与权威快照）────────────────────────────────

func _garrison_vector() -> Array:
	var result: Array = []
	for value in Array(_dict(runtime.get_read_model().get("home", {})).get("formations", [])):
		result.append(int(_dict(value).get("member_count", 0)))
	return result


func _garrison_ids() -> Array:
	var result: Array = []
	for value in Array(_dict(runtime.get_read_model().get("home", {})).get("formations", [])):
		result.append(str(_dict(value).get("formation_id", "")))
	return result


func _chosen_formations() -> Array:
	var chosen: Array = []
	var vector := _garrison_vector()
	for index in vector.size():
		if int(vector[index]) > 0:
			chosen.append(FORMATION_ORDER[index])
	return chosen


## 按总量 first-fit 的落位预测（即修复前行为），用来证明用例有判别力。
func _first_fit_prediction(before: Array, total: int) -> Array:
	var next_vector := before.duplicate()
	var remaining := total
	for index in next_vector.size():
		var accepted := mini(remaining, maxi(0, 20 - int(next_vector[index])))
		next_vector[index] = int(next_vector[index]) + accepted
		remaining -= accepted
	return next_vector


## 各编队应收回的本国幸存者：只由出征账本 + 军队自带编队身份推导。
## 这里刻意按 army_ids 与账本的下标配对，而产品代码按 formation_id 关联，
## 两者一致才说明身份链没有靠顺序巧合成立。
func _expected_returns() -> Dictionary:
	var ledger: Array = Array(_dict(runtime.data.departure_ledger).get("formations", []))
	var army_ids: Array = Array(runtime.data.army_ids)
	var result: Dictionary = {}
	if ledger.size() != army_ids.size():
		return result
	for value in ledger:
		result[str(_dict(value).get("formation_id", ""))] = 0
	for index in ledger.size():
		var formation_id := str(_dict(ledger[index]).get("formation_id", ""))
		var army := _dict(city._army_registry.get_army(StringName(army_ids[index])))
		var members := 0
		for count in Dictionary(army.get("units_by_definition_id", {})).values():
			members += int(count)
		result[formation_id] = int(result.get(formation_id, 0)) + members \
			- int(_dict(runtime.data.local_by_army).get(StringName(army_ids[index]), 0))
	return result


func _army_formation_ids() -> Array:
	var result: Array = []
	for army_value in Array(runtime.get_read_model().get("armies", [])):
		var snapshots: Array = Array(_dict(army_value).get("macro_march", {}).get("formation_snapshots", []))
		result.append(str(_dict(snapshots[0]).get("formation_id", "")) if snapshots.size() == 1 else "")
	return result


func _army_member_counts() -> Array:
	var result: Array = []
	for army_value in Array(runtime.get_read_model().get("armies", [])):
		var members := 0
		for count in Dictionary(_dict(army_value).get("units_by_definition_id", {})).values():
			members += int(count)
		result.append(members)
	return result


func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total


func _accounting() -> Dictionary:
	return _dict(city.call("get_blackstone_personnel_accounting"))


func _recovery() -> Dictionary:
	return _dict(city.call("get_population_recovery_read_model"))


func _snapshot_facts() -> Dictionary:
	var ledger_formations: Array = []
	for value in Array(_dict(runtime.data.departure_ledger).get("formations", [])):
		ledger_formations.append({
			"id": str(_dict(value).get("formation_id", "")),
			"count": int(_dict(value).get("member_count", 0)),
			"definition_id": str(_dict(value).get("definition_id", "")),
			"display_name": str(_dict(value).get("display_name", "")),
		})
	var scope := _dict(city.get_nation_state().get_scope(runtime.SCOPE))
	var locals: Array = []
	for id in Array(runtime.data.army_ids):
		locals.append(int(_dict(runtime.data.local_by_army).get(StringName(id), 0)))
	return {
		"phase": str(runtime.data.phase),
		"attempt_sequence": int(runtime.data.attempt_sequence),
		"garrison": _garrison_vector(),
		"garrison_ids": _garrison_ids(),
		"army_ids": Array(runtime.data.army_ids).map(func(id): return str(id)),
		"army_formations": _army_formation_ids(),
		"army_members": _army_member_counts(),
		"local_by_army": locals,
		"wounded_home": int(runtime._wounded(true)),
		"wounded_local": int(runtime._wounded(false)),
		"fallen_home": int(runtime.data.fallen_home),
		"fallen_local": int(runtime.data.fallen_local),
		"local_joined": int(runtime.data.local_joined),
		"home_alive": int(runtime._home_alive()),
		"ledger": ledger_formations,
		"scope_food": int(scope.get("food", 0)),
		"scope_wood": int(scope.get("wood", 0)),
		"home_food": int(city.food),
		"home_wood": int(city.wood),
		"recovery_wounded": int(_recovery().get("wounded", 0)),
		"recovery_fallen": int(_recovery().get("fallen", 0)),
		"accounted_total": int(_accounting().get("accounted_total", 0)),
		"summary_kind": str(_dict(runtime.data.summary).get("kind", "")),
		"summary_survivors": int(_dict(runtime.data.summary).get("survivors", 0)),
	}


# ── 推进辅助 ────────────────────────────────────────────────────────────

func _available_army_ids() -> Array:
	var result: Array = []
	for id in Array(runtime.data.army_ids):
		var army := _dict(city._army_registry.get_army(StringName(id)))
		if not army.is_empty() and StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_CLOSED:
			result.append(StringName(id))
	return result


func _move_army_to(army_id: StringName, target: StringName, budget_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + budget_ms
	var last_error := ""
	while Time.get_ticks_msec() < deadline:
		var move: Dictionary = runtime.command(&"move", {"army_id": army_id, "target_id": target})
		if bool(move.get("success", false)):
			return true
		last_error = str(move.get("error", ""))
		runtime.advance(2.0)
	print("FRI move_failed army=%s target=%s error=%s" % [army_id, target, last_error])
	return false


func _wait_not_marching(budget_ms: int) -> void:
	var deadline := Time.get_ticks_msec() + budget_ms
	while Time.get_ticks_msec() < deadline:
		var pending := false
		for id in Array(runtime.data.army_ids):
			var army := _dict(city._army_registry.get_army(StringName(id)))
			if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING:
				pending = true
		if not pending:
			return
		runtime.advance(2.0)


## 用一支仍有战斗力的军队攻打目标，推进到该城归我方或预算耗尽。
## keep_army 非空时绝不调动该军队：带着当地新募人员的那一支必须活到结算，
## "当地人员不带回主城"才有可核对的对象。
func _capture(target: StringName, budget_ms: int, keep_army: StringName = &"") -> bool:
	for attempt in range(6):
		var ids: Array = []
		for id in _available_army_ids():
			if StringName(id) != keep_army:
				ids.append(id)
		if ids.is_empty():
			return false
		var army_id := StringName(ids[attempt % ids.size()])
		if not await _move_army_to(army_id, target, 30000):
			continue
		var deadline := Time.get_ticks_msec() + budget_ms
		while Time.get_ticks_msec() < deadline:
			runtime.advance(2.0)
			if str(_dict(city._war_loop_state.cities_by_id.get(target, {}))
					.get("military_controller_faction_id", "")) == "player":
				return true
			if StringName(runtime.data.phase) == &"PENDING":
				return true
			if StringName(_dict(city._army_registry.get_army(army_id)).get("phase", &"")) == ArmyRegistry.PHASE_CLOSED:
				break
	return false


# ── 阶段 ───────────────────────────────────────────────────────────────

func _stage_depart() -> void:
	_expect(runtime == null or not runtime.enabled(), "新沙盒启动时战役干净")
	_expect(city.call("initialize_regular_campaign"), "常规候选战役初始化")
	runtime = city.get("_regular_campaign")
	_expect(runtime != null and runtime.enabled(), "战役运行时已启用")
	var vector := _garrison_vector()
	print("FRI baseline garrison=", vector, " ids=", _garrison_ids())
	_expect(vector == [7, 7, 6], "新档初始驻军为 7/7/6（三队人数不同，落位可判别）")
	_expect(_garrison_ids() == [str(F1), str(F2), str(F3)], "编队身份与名称顺序稳定")
	var food := 8 if case_id == "B" else 30
	var depart: Dictionary = runtime.command(&"depart",
		{"formation_ids": _chosen_formations(), "food": food, "wood": 55})
	if not bool(depart.get("success", false)):
		print("FRI DEPART_ERROR=", str(depart.get("error", "")))
	_expect(bool(depart.get("success", false)), "正式 depart 成功")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "出征后 ACTIVE")
	var facts := _snapshot_facts()
	_write_facts("facts-depart.json", facts)
	_expect(Array(facts.get("army_ids")).size() == 3, "每编队一支军队（3 支）")
	_expect(facts.get("army_formations") == [str(F1), str(F2), str(F3)], "每支军队自带来源编队身份")
	_expect(facts.get("army_members") == [7, 7, 6], "每支军队人数等于其来源编队人数")
	_expect(facts.get("ledger") == [
		{"id": str(F1), "count": 7, "definition_id": "unit_role.infantry_basic", "display_name": "北门先锋"},
		{"id": str(F2), "count": 7, "definition_id": "unit_role.infantry_basic", "display_name": "山道卫队"},
		{"id": str(F3), "count": 6, "definition_id": "unit_role.infantry_basic", "display_name": "城门后备"},
	], "出征账本保存原 formation_id/名称/兵种/人数")
	_expect(_garrison_vector() == [0, 0, 0], "出征后主城三编队全部清空")


func _stage_attrite() -> void:
	var depart := _read_facts("facts-depart.json")
	_expect(not depart.is_empty(), "读取出征阶段 facts")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "attrite：冷启动恢复 ACTIVE（关内军队跨进程）")
	_expect(_army_formation_ids() == depart.get("army_formations"), "attrite：军队来源编队冷启动一致")
	_wait_not_marching(40000)
	match case_id:
		"A":
			runtime.advance(1.0)
		"B":
			# 真实断粮规则：口粮需求远高于携粮时按 army_ids 顺序连续减员。
			var deadline := Time.get_ticks_msec() + 90000
			while Time.get_ticks_msec() < deadline:
				var members := _army_member_counts()
				if members.size() == 3 and int(members[0]) == 0 and int(members[1]) < 7:
					break
				runtime.advance(2.0)
		"C":
			var ids := _available_army_ids()
			_expect(not ids.is_empty(), "C：有可用军队")
			if not ids.is_empty():
				_expect(await _move_army_to(StringName(ids[0]), &"redcliff_city", 60000),
					"C：向红岩城行军命令成功")
				var deadline := Time.get_ticks_msec() + 90000
				while Time.get_ticks_msec() < deadline:
					runtime.advance(2.0)
					if int(runtime.data.combat_losses_total) > 0:
						break
			print("FRI C combat_losses=", int(runtime.data.combat_losses_total))
		"D":
			# 先取溪渡（控制后才能在当地招募），再取红岩，最后双城占领自动胜利。
			var first := await _capture(&"silverford_city", 120000)
			print("FRI D silverford captured=", first, " phase=", runtime.data.phase)
			_expect(first, "D：溪渡占领")
			var recruited_army := &""
			if StringName(runtime.data.phase) == &"ACTIVE":
				for id in _available_army_ids():
					var army := _dict(city._army_registry.get_army(StringName(id)))
					if StringName(army.get("target_node_id", &"")) != &"silverford_city":
						continue
					var train: Dictionary = runtime.command(&"train", {"army_id": StringName(id)})
					print("FRI D train=", str(train.get("success", false)), " ", str(train.get("error", "")))
					if bool(train.get("success", false)):
						recruited_army = StringName(id)
						var deadline := Time.get_ticks_msec() + 60000
						while Time.get_ticks_msec() < deadline and int(runtime.data.local_joined) == 0:
							runtime.advance(2.0)
					break
			# 招募了当地人员的那一支就地驻住，红岩由其余编队去打：
			# 否则当地人员在最后一战里全部阵亡，本用例就失去"不带回主城"的验证对象。
			var second := await _capture(&"redcliff_city", 120000, recruited_army)
			print("FRI D redcliff captured=", second, " phase=", runtime.data.phase,
				" recruited_army=", recruited_army)
			_expect(second, "D：红岩占领")
			_expect(int(runtime.data.local_joined) > 0, "D：确有当地加入人员")
		_:
			_expect(false, "未知用例 " + case_id)
	# 用一个正式行动收口本阶段：advance() 只在 command() 里落检查点，
	# 直接结束进程会丢掉刚推进的状态，下一阶段就无法做数值级冷启动比对。
	var save_point: Dictionary = runtime.command(&"view", {"surface": &"THEATER", "city_id": &""})
	_expect(bool(save_point.get("success", false)), "attrite：以正式行动落盘检查点")
	var facts := _snapshot_facts()
	_write_facts("facts-attrite.json", facts)
	print("FRI attrite garrison=", facts.get("garrison"), " members=", facts.get("army_members"),
		" wounded_home=", facts.get("wounded_home"), " fallen_home=", facts.get("fallen_home"),
		" locals=", facts.get("local_by_army"), " home_alive=", facts.get("home_alive"))
	match case_id:
		"A":
			_expect(facts.get("army_members") == [7, 7, 6], "A：三编队均未伤亡")
			_expect(int(facts.get("fallen_home")) == 0, "A：无阵亡")
		"B":
			_expect(int(facts.get("fallen_home")) > 0, "B：断粮造成真实本国阵亡")
			_expect(facts.get("army_members") == [0, 0, 0] or int(Array(facts.get("army_members"))[0]) == 0,
				"B：第一编队军队全灭")
			_expect(int(Array(facts.get("army_members"))[1]) < 7, "B：第二编队部分减员")
			_expect(int(Array(facts.get("army_members"))[2]) == 6, "B：第三编队未受损")
			_expect(int(facts.get("wounded_home")) == 0, "B：断粮不产生战斗伤员")
		"C":
			_expect(str(facts.get("summary_kind")).is_empty(), "C：结算前无摘要")
			_expect(int(Array(facts.get("army_members"))[0]) < 7, "C：交战使第一编队减员")
			_expect(int(facts.get("wounded_home")) > 0, "C：交战产生本国伤员")
		"D":
			_expect(int(facts.get("local_joined")) > 0, "C/D：当地人员已计入当地兵源")
			_expect(_sum(_int_array(facts.get("local_by_army"))) > 0,
				"D：结算时当地新募人员仍在世（%d 人），可核对不带回主城" % [
					_sum(_int_array(facts.get("local_by_army")))])


func _stage_confirm() -> void:
	var attrite := _read_facts("facts-attrite.json")
	_expect(not attrite.is_empty(), "读取伤亡阶段 facts")
	# D 的双城占领在 attrite 阶段就自动胜利进入 PENDING；其余用例仍需在 confirm 内
	# 用正式 outcome 结算，因此两者都是合法冷启动落点。
	_expect(StringName(runtime.data.phase) == &"ACTIVE"
			or StringName(runtime.data.phase) == &"PENDING",
		"confirm：冷启动恢复 ACTIVE 或 PENDING（实际 %s）" % runtime.data.phase)
	var cold := _snapshot_facts()
	for key in ["army_ids", "army_formations", "army_members", "local_by_army",
			"wounded_home", "fallen_home", "home_alive", "ledger", "attempt_sequence",
			"scope_food", "scope_wood"]:
		_expect(cold.get(key) == attrite.get(key),
			"confirm：数值级冷启动一致 %s（落盘 %s / 恢复 %s）" % [key,
				str(attrite.get(key)), str(cold.get(key))])
	var before_vector := _garrison_vector()
	_expect(before_vector == [0, 0, 0], "confirm：结算前主城编队为空（出征后未在家补员）")
	var kind := &"DEFEAT" if case_id == "C" else (&"VICTORY" if case_id == "D" else &"WITHDRAW")
	if StringName(runtime.data.phase) == &"ACTIVE":
		var outcome: Dictionary = runtime.command(&"outcome", {"kind": kind})
		if not bool(outcome.get("success", false)):
			print("FRI OUTCOME_ERROR=", str(outcome.get("error", "")))
		_expect(bool(outcome.get("success", false)), "%s 正式成功" % kind)
	_expect(StringName(runtime.data.phase) == &"PENDING", "结算前进入 PENDING")
	# 归队预期与一切"结算前"基线都必须在 outcome 之后取：_outcome() 会解算在途攻城，
	# COMBAT 减员到这一刻才落地，早取会拿到尚未定稿的伤亡数。
	var pending := _snapshot_facts()
	_write_facts("facts-pending.json", pending)
	_expect(_sum(pending.get("army_members")) <= _sum(attrite.get("army_members")),
		"outcome 只可能减少关内兵力（%d → %d）" % [
			_sum(attrite.get("army_members")), _sum(pending.get("army_members"))])
	var expected := _expected_returns()
	var home_alive := int(pending.get("home_alive"))
	_expect(home_alive > 0, "结算时确有本国幸存者归队")
	_expect(_sum(expected.values()) == home_alive, "按编队归属的幸存者合计 = 本国幸存者总量")
	print("FRI confirm expected=", expected, " home_alive=", home_alive,
		" locals=", pending.get("local_by_army"),
		" members attrite=", attrite.get("army_members"), " pending=", pending.get("army_members"))
	var summary := _dict(runtime.data.summary)
	_expect(int(summary.get("survivors", -1)) == home_alive, "摘要幸存者数与本国幸存者一致")
	_expect(int(summary.get("fallen", -1)) == int(pending.get("fallen_home")), "摘要阵亡数一致")
	_expect(int(summary.get("wounded", -1)) == int(pending.get("wounded_home")), "摘要伤员数一致")
	var recovery_before := _recovery()
	var accounting_before := _accounting()
	var confirm: Dictionary = runtime.command(&"confirm")
	if not bool(confirm.get("success", false)):
		print("FRI CONFIRM_ERROR=", str(confirm.get("error", "")))
	_expect(bool(confirm.get("success", false)), "确认损益（正式事务）成功")
	var after_vector := _garrison_vector()
	print("FRI garrison before=", before_vector, " after=", after_vector, " expected=", expected)
	var wanted: Array = []
	for index in FORMATION_ORDER.size():
		wanted.append(int(before_vector[index]) + int(expected.get(str(FORMATION_ORDER[index]), 0)))
	_expect(after_vector == wanted, "各编队只收回自己那支军队的本国幸存者")
	_expect(after_vector != _first_fit_prediction(before_vector, home_alive),
		"对照：结果不等于按总量 first-fit 的落位（用例具判别力）")
	_expect(_garrison_ids() == [str(F1), str(F2), str(F3)], "结算后编队身份仍为三份且顺序不变")
	var raw: Array = city._garrison_state.get_formations()
	_expect(raw.size() == 3, "驻军花名册仍为三条编队记录")
	for index in raw.size():
		var formation := _dict(raw[index])
		_expect(StringName(formation.get("formation_id", &"")) == FORMATION_ORDER[index]
				and String(formation.get("display_name", "")) == str(FORMATION_NAMES[FORMATION_ORDER[index]])
				and int(formation.get("max_members", 0)) == 20,
			"编队 %s 身份/显示名/上限未被改写" % FORMATION_ORDER[index])
	_expect(_sum(after_vector) == home_alive, "驻军总数恰等于本国幸存者数")
	var locals := _sum(_int_array(pending.get("local_by_army")))
	_expect(int(_accounting().get("accounted_total", 0)) - int(accounting_before.get("accounted_total", 0))
		== int(pending.get("wounded_home")) + int(pending.get("fallen_home")) - locals,
		"人口守恒：主城在册增量 = 本国伤员 + 本国阵亡 − 留在当地的人员")
	var recovery_after := _recovery()
	_expect(int(recovery_after.get("fallen", 0)) - int(recovery_before.get("fallen", 0))
		== int(pending.get("fallen_home")), "阵亡永久移除并计入 PopulationRecovery")
	if int(pending.get("wounded_home")) > 0:
		_expect(int(recovery_after.get("wounded", 0)) - int(recovery_before.get("wounded", 0))
			== int(pending.get("wounded_home")), "伤员继续进入 PopulationRecovery 而非已归队驻军")
	if locals > 0:
		_expect(_sum(after_vector) == home_alive and home_alive + locals > home_alive,
			"当地人员不带回主城：驻军仅含 %d 名本国幸存者，未吸收 %d 名当地人员" % [home_alive, locals])
	for id_value in Array(runtime.data.army_ids):
		var army := _dict(city._army_registry.get_army(StringName(id_value)))
		_expect(StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED,
			"军队 %s 已关闭" % id_value)
	# R2B-1 回执：必须在"重复 confirm"之前读取——第二次 confirm 失败时
	# command() 会把候选回执清空，这是 R2B-1 既定语义。
	var receipt := _dict(runtime._settlement_receipt)
	_expect(runtime.has_settlement_receipt(), "回执在持久化成功后转正")
	_expect(int(receipt.get("survivors", -1)) == home_alive, "R2B-1 回执 survivors 与本国幸存者一致")
	_expect(int(receipt.get("fallen", -1)) == int(pending.get("fallen_home")), "R2B-1 回执 fallen 一致")
	_expect(int(receipt.get("wounded", -1)) == int(pending.get("wounded_home")), "R2B-1 回执 wounded 一致")
	_expect(int(receipt.get("local_people", -1)) == int(pending.get("local_joined")), "R2B-1 回执 local_people 一致")
	_expect(str(receipt.get("settlement_id", "")).begins_with("regular.settlement."), "R2B-1 回执具备结算身份")
	var advice := _dict(city.call("_campaign_return_advice", receipt))
	_expect(not advice.is_empty(), "R2B-1 归来简报建议仍可由回执生成")
	print("FRI receipt=", JSON.stringify(receipt))
	var dup: Dictionary = runtime.command(&"confirm")
	_expect(not bool(dup.get("success", false)), "重复 confirm 被拒绝")
	_expect(_garrison_vector() == after_vector, "重复 confirm 后驻军完全未再变化（幂等）")
	var expected_phase := &"COMPLETED" if case_id == "D" else &"PREPARATION"
	_expect(StringName(runtime.data.phase) == expected_phase,
		"结算后阶段为 %s" % expected_phase)
	var facts := _snapshot_facts()
	_write_facts("facts-confirm.json", facts)


func _stage_post() -> void:
	var confirm_facts := _read_facts("facts-confirm.json")
	_expect(not confirm_facts.is_empty(), "读取结算阶段 facts")
	var saved_vector := _int_array(confirm_facts.get("garrison"))
	_expect(_garrison_vector() == saved_vector, "冷启动后驻军落位与结算时完全一致")
	_expect(_garrison_ids() == confirm_facts.get("garrison_ids"), "冷启动后编队身份顺序一致")
	_expect(int(_accounting().get("accounted_total", 0)) == int(confirm_facts.get("accounted_total", 0)),
		"冷启动后人口核算一致")
	var raw: Array = city._garrison_state.get_formations()
	for index in raw.size():
		_expect(StringName(_dict(raw[index]).formation_id) == FORMATION_ORDER[index]
			and int(_dict(raw[index]).member_count) == int(saved_vector[index]),
			"冷启动编队 %s 人数与身份保持（%d 人）" % [FORMATION_ORDER[index], int(saved_vector[index])])
	if case_id == "D":
		_expect(StringName(runtime.data.phase) == &"COMPLETED", "D：胜利后本关 COMPLETED")
		print("FRI post 跳过第二次出征：phase=", runtime.data.phase)
		return
	_expect(StringName(runtime.data.phase) == &"PREPARATION", "冷启动恢复 PREPARATION")
	var vector := _garrison_vector()
	var chosen := _chosen_formations()
	print("FRI redeploy vector=", vector, " chosen=", chosen)
	var depart: Dictionary = runtime.command(&"depart",
		{"formation_ids": chosen, "food": 20, "wood": 10})
	if not bool(depart.get("success", false)):
		print("FRI REDEPLOY_ERROR=", str(depart.get("error", "")))
	_expect(bool(depart.get("success", false)), "第二次正式 depart 成功")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "第二次出征 ACTIVE")
	_expect(int(runtime.data.attempt_sequence) == int(confirm_facts.get("attempt_sequence")) + 1,
		"attempt_sequence 恰好 +1")
	var facts := _snapshot_facts()
	_write_facts("facts-post.json", facts)
	var expected_ledger: Array = []
	var expected_ids: Array = []
	var expected_counts: Array = []
	for index in vector.size():
		if int(vector[index]) > 0:
			expected_ledger.append({
				"id": str(FORMATION_ORDER[index]),
				"count": int(vector[index]),
				"definition_id": "unit_role.infantry_basic",
				"display_name": str(FORMATION_NAMES[FORMATION_ORDER[index]]),
			})
			expected_ids.append(str(FORMATION_ORDER[index]))
			expected_counts.append(int(vector[index]))
	_expect(facts.get("ledger") == expected_ledger, "第二次出征账本 = 结算后的真实编队结构")
	_expect(facts.get("army_formations") == expected_ids, "第二次出征每支军队按各自编队身份成军")
	_expect(facts.get("army_members") == expected_counts, "第二次出征每支军队人数 = 该编队人数")


func _stage_verify() -> void:
	if _read_facts("facts-post.json").is_empty():
		print("FRI verify 跳过：无第二次出征")
		return
	var post := _read_facts("facts-post.json")
	_expect(StringName(runtime.data.phase) == &"ACTIVE", "verify：第二次出征冷启动仍为 ACTIVE")
	_expect(_army_formation_ids() == post.get("army_formations"), "verify：第二次出征的编队身份冷启动一致")
	_expect(_army_member_counts() == _int_array(post.get("army_members")), "verify：第二次出征的编队人数冷启动一致")
	_expect(_garrison_vector() == [0, 0, 0], "verify：第二次出征后主城三编队清空")
	var expected := {}
	var home_alive := 0
	var outcome: Dictionary = runtime.command(&"outcome", {"kind": &"WITHDRAW"})
	_expect(bool(outcome.get("success", false)), "verify：第二次撤军成功")
	# 与 confirm 阶段同理：outcome 之后伤亡数才定稿。
	expected = _expected_returns()
	home_alive = int(runtime._home_alive())
	var confirm: Dictionary = runtime.command(&"confirm")
	if not bool(confirm.get("success", false)):
		print("FRI VERIFY_CONFIRM_ERROR=", str(confirm.get("error", "")))
	_expect(bool(confirm.get("success", false)), "verify：第二次结算成功")
	var wanted: Array = []
	for index in FORMATION_ORDER.size():
		wanted.append(int(expected.get(str(FORMATION_ORDER[index]), 0)))
	_expect(_garrison_vector() == wanted, "verify：第二次归队同样按各自编队落位")
	_expect(_sum(_garrison_vector()) == home_alive, "verify：第二次驻军总数 = 本国幸存者")
	print("FRI verify garrison=", _garrison_vector(), " expected=", wanted)


func _run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage = arg.trim_prefix("--stage=")
		elif arg.begins_with("--case="):
			case_id = arg.trim_prefix("--case=")
		elif arg.begins_with("--txwzs-v5-save-dir="):
			save_dir = arg.trim_prefix("--txwzs-v5-save-dir=")
		elif arg.begins_with("--facts-dir="):
			facts_dir = arg.trim_prefix("--facts-dir=")
		elif arg == "--txwzs-require-isolated-save":
			isolated = true
	if not isolated or save_dir.is_empty() or facts_dir.is_empty() or stage.is_empty():
		push_error("FRI：需要 --txwzs-require-isolated-save、--txwzs-v5-save-dir、--case、--stage、--facts-dir")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(facts_dir)
	if not await _wait_boot():
		_finish()
		return
	match stage:
		"depart":
			await _stage_depart()
		"attrite":
			await _stage_attrite()
		"confirm":
			await _stage_confirm()
		"post":
			await _stage_post()
		"verify":
			await _stage_verify()
		_:
			push_error("未知 stage：" + stage)
			quit(2)
			return
	_finish()
