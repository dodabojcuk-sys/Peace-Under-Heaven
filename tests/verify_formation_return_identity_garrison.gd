extends SceneTree

## FORMATION_RETURN_IDENTITY_R1 · 第 1 层：驻军归队的编队身份（纯 roster 逻辑）。
##
## 口径：本文件只构造 GarrisonState（RefCounted，无场景、无存档），逐条核对
## try_return_members_by_formation() 的落位、身份保持、拒绝语义与非改写保证。
## 真实存档链上的端到端归队由 tests/verify_formation_return_identity_r1.gd 覆盖。
## 每个用例都断言精确人数，不用"大致相等"或随机重试掩盖落位差异。

const INFANTRY := &"unit_role.infantry_basic"
const F1 := &"formation.blackstone.1"
const F2 := &"formation.blackstone.2"
const F3 := &"formation.blackstone.3"
const NAMES := {
	F1: "北门先锋",
	F2: "山道卫队",
	F3: "城门后备",
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error(label)


func _roster(total: int) -> GarrisonState:
	return GarrisonState.new(&"blackstone_city", INFANTRY, total)


## 返回 [f1, f2, f3] 的当前人数。
func _counts(roster: GarrisonState) -> Array:
	var result: Array = []
	for formation_value in roster.get_formations():
		result.append(int(Dictionary(formation_value).member_count))
	return result


func _departed_counts(snapshots: Array) -> Array:
	var result: Array = []
	for value in snapshots:
		result.append(int(Dictionary(value).member_count))
	return result


## 出征：按编队整编制抽走（关内只带走被点名的编队）。
func _depart_all(roster: GarrisonState) -> Array:
	var snapshots := roster.get_selected_formations([F1, F2, F3])
	_check(roster.try_extract_selected_formations(snapshots), "前置：整编制出征抽走三个编队")
	return snapshots


func _run() -> void:
	_no_casualties()
	_first_fit_control()
	_single_formation_partial()
	_multiple_formations_different_losses()
	_one_formation_wiped()
	_wounded_absent_from_return()
	_unknown_formation_is_refused()
	_non_string_name_key_is_refused()
	_insufficient_capacity_is_refused_without_mutation()
	_full_home_formation_spills_deterministically()
	_plan_edge_inputs()
	_conservation_and_identity()
	_finish()


## 1) 三编队无伤亡：归队后仍是原三编队、原人数、原名称。
func _no_casualties() -> void:
	var roster := _roster(60)
	var departed := _depart_all(roster)
	var outcome := roster.try_return_members_by_formation({F1: 20, F2: 20, F3: 20})
	_check(bool(outcome.get("ok", false)), "无伤亡：归队被接受")
	_check(int(outcome.get("returned", 0)) == 60, "无伤亡：归队人数 60")
	_check(int(outcome.get("displaced", -1)) == 0, "无伤亡：无人被改投他队")
	_check(_counts(roster) == [20, 20, 20], "无伤亡：三编队人数与出征前一致 20/20/20")
	var index := 0
	for formation_value in roster.get_formations():
		var formation: Dictionary = formation_value
		var formation_id := StringName(formation.formation_id)
		_check(
			formation_id == Array(GarrisonState.FORMATION_IDS)[index]
				and String(formation.display_name) == str(NAMES[formation_id])
				and StringName(formation.definition_id) == INFANTRY
				and int(formation.max_members) == 20,
			"无伤亡：编队 %s 身份/名称/兵种/上限未被改写" % formation_id
		)
		index += 1
	_check(_counts(roster) == _departed_counts(departed), "无伤亡：编队内容与出征快照逐项相同")


## 2) 对照：旧的按总量归队（first-fit）确实把 uneven 伤亡压进第一编队。
##    这条断言记录的是"修复前的错误落位"，不是对新接口的要求。
func _first_fit_control() -> void:
	var legacy := _roster(60)
	legacy.try_extract_selected_formations(legacy.get_selected_formations([F1, F2, F3]))
	_check(_counts(legacy) == [0, 0, 0], "对照：出征后三编队清空")
	_check(legacy.try_add_units(INFANTRY, 12), "对照：旧接口按总量 12 归队成功")
	_check(
		_counts(legacy) == [12, 0, 0],
		"对照：旧接口把 5/4/3 的三队幸存者压成 12/0/0（修复前行为）"
	)
	var fixed := _roster(60)
	fixed.try_extract_selected_formations(fixed.get_selected_formations([F1, F2, F3]))
	var outcome := fixed.try_return_members_by_formation({F1: 5, F2: 4, F3: 3})
	_check(_counts(fixed) == [5, 4, 3], "对照：新接口保留 5/4/3 的分队归属")
	_check(int(outcome.get("displaced", -1)) == 0, "对照：新接口未改投他队")


## 3) 单编队部分阵亡：只有该编队减少，别的编队不受影响。
func _single_formation_partial() -> void:
	var roster := _roster(60)
	var snapshots := roster.get_selected_formations([F2])
	_check(roster.try_extract_selected_formations(snapshots), "单编队：山道卫队出征")
	var outcome := roster.try_return_members_by_formation({F2: 7})
	_check(bool(outcome.get("ok", false)), "单编队：7 人归队被接受")
	_check(_counts(roster) == [20, 7, 20], "单编队：部分阵亡后为 20/7/20")
	_check(int(outcome.get("returned", 0)) == 7, "单编队：归队人数 7")


## 4) 多编队不同伤亡：各队各自落位。
func _multiple_formations_different_losses() -> void:
	var roster := _roster(60)
	roster.set_unit_count(INFANTRY, 45)
	var snapshots := roster.get_selected_formations([F1, F2, F3])
	_check(roster.try_extract_selected_formations(snapshots), "多编队：三队出征（15/15/15）")
	var outcome := roster.try_return_members_by_formation({F1: 14, F2: 3, F3: 9})
	_check(bool(outcome.get("ok", false)), "多编队：不同伤亡归队被接受")
	_check(_counts(roster) == [14, 3, 9], "多编队：落位为 14/3/9，不是 20/0/0 或聚合值")
	_check(int(outcome.get("displaced", -1)) == 0, "多编队：无人被改投他队")
	_check(roster.get_total_count() == 26, "多编队：驻军总数等于 14+3+9")


## 5) 一支编队全灭：该队为 0，且不得把别队的人塞进去凑数。
func _one_formation_wiped() -> void:
	var roster := _roster(60)
	roster.try_extract_selected_formations(roster.get_selected_formations([F1, F2, F3]))
	var outcome := roster.try_return_members_by_formation({F1: 20, F2: 20, F3: 0})
	_check(bool(outcome.get("ok", false)), "全灭：归队被接受")
	_check(_counts(roster) == [20, 20, 0], "全灭：城门后备保持 0 人（身份仍在）")
	_check(int(roster.get_formation(F3).member_count) == 0, "全灭：全灭编队记录仍可查询")
	_check(int(outcome.get("displaced", -1)) == 0, "全灭：未被别队人数填充")


## 6) 有伤员但未归队：伤员不在本次归队名单里，驻军只增幸存者。
func _wounded_absent_from_return() -> void:
	var roster := _roster(60)
	roster.try_extract_selected_formations(roster.get_selected_formations([F1, F2, F3]))
	# 20/20/20 出征，战斗损失 6/4/2 → 幸存者 14/16/18，伤员 3/2/1 仍在治疗链上。
	var outcome := roster.try_return_members_by_formation({F1: 14, F2: 16, F3: 18})
	_check(bool(outcome.get("ok", false)), "伤员：幸存者名单归队成功")
	_check(_counts(roster) == [14, 16, 18], "伤员：归队仅含幸存者，未预支伤员")
	_check(roster.get_total_count() == 48, "伤员：驻军总数 48（伤员不计入）")
	_check(int(outcome.get("returned", 0)) + 12 == 60, "伤员：幸存者 48 + 战损 12 = 出征 60")


## 7) 原编队身份不存在：硬拒绝，且不写任何状态。
func _unknown_formation_is_refused() -> void:
	var roster := _roster(60)
	var outcome := roster.try_return_members_by_formation({&"formation.blackstone.9": 5})
	_check(not bool(outcome.get("ok", true)), "未知编队：归队被拒绝")
	_check(StringName(outcome.get("reason", &"")) == &"INVALID_RETURN", "未知编队：拒绝原因为 INVALID_RETURN")
	_check(_counts(roster) == [20, 20, 20], "未知编队：拒绝后驻军未变（不回落到第一编队）")
	_check(int(outcome.get("returned", -1)) == 0, "未知编队：拒绝回执不谎报已归队人数")


## 8) 非 StringName 身份（伪造/串行化退化）：同样硬拒绝。
func _non_string_name_key_is_refused() -> void:
	var roster := _roster(60)
	roster.try_extract_selected_formations(roster.get_selected_formations([F1, F2, F3]))
	var outcome := roster.try_return_members_by_formation({str(F1): 10})
	_check(not bool(outcome.get("ok", true)), "字符串键：归队被拒绝")
	_check(_counts(roster) == [0, 0, 0], "字符串键：拒绝后未写入任何编队")


## 9) 容量不足：整批拒绝，不做部分归队。
func _insufficient_capacity_is_refused_without_mutation() -> void:
	var roster := _roster(60)
	roster.try_extract_selected_formations(roster.get_selected_formations([F1, F2, F3]))
	_check(roster.try_add_units(INFANTRY, 40), "前置：家中训练补入 40 人")
	_check(_counts(roster) == [20, 20, 0], "前置：训练 first-fit 后只剩城门后备的 20 个空位")
	var outcome := roster.try_return_members_by_formation({F1: 20, F2: 5})
	_check(not bool(outcome.get("ok", true)), "容量不足：25 人 > 20 空位时整批拒绝")
	_check(
		StringName(outcome.get("reason", &"")) == &"INSUFFICIENT_CAPACITY",
		"容量不足：拒绝原因为 INSUFFICIENT_CAPACITY"
	)
	_check(_counts(roster) == [20, 20, 0], "容量不足：拒绝后没有半归、也没有挤掉已驻人员")


## 10) 原编队暂时满员：先各自保序落位，溢出按花名册顺序确定性地改投并计数。
func _full_home_formation_spills_deterministically() -> void:
	var roster := _roster(60)
	roster.try_extract_selected_formations(roster.get_selected_formations([F1, F2, F3]))
	_check(roster.try_add_units(INFANTRY, 25), "前置：关内期间家中训练补入 25 人")
	_check(_counts(roster) == [20, 5, 0], "前置：北门先锋已被补满，山道卫队剩 15 空位")
	var outcome := roster.try_return_members_by_formation({F1: 10, F2: 15, F3: 10})
	_check(bool(outcome.get("ok", false)), "改投：35 人 = 35 空位时归队被接受")
	_check(int(outcome.get("returned", 0)) == 35, "改投：35 人全部归队，无人被丢弃")
	_check(_counts(roster) == [20, 20, 20], "改投：三编队均未超过 20 人上限")
	_check(int(outcome.get("displaced", -1)) == 10, "改投：北门先锋的 10 人溢出被如实计数")
	_check(
		int(outcome.get("displaced", -1)) == 10 and int(roster.get_formation(F3).member_count) == 20,
		"改投：溢出进入仍有空位的编队，且原队份额优先保留"
	)
	var again := _roster(60)
	again.try_extract_selected_formations(again.get_selected_formations([F1, F2, F3]))
	again.try_add_units(INFANTRY, 25)
	var replay := again.try_return_members_by_formation({F1: 10, F2: 15, F3: 10})
	_check(
		_counts(again) == _counts(roster) and int(replay.displaced) == int(outcome.displaced),
		"重放：同输入下落位与溢出计数完全相同（冷启动可复现）"
	)
	var tail := _roster(60)
	tail.try_extract_selected_formations(tail.get_selected_formations([F1, F2, F3]))
	tail.try_add_units(INFANTRY, 40)
	_check(_counts(tail) == [20, 20, 0], "前置：只有城门后备有空位")
	var spill := tail.try_return_members_by_formation({F1: 5})
	_check(_counts(tail) == [20, 20, 5], "改投：满员的第一编队不会吸收溢出，落向下一个有空位的编队")
	_check(int(spill.displaced) == 5, "改投：5 人溢出被计数")


## 11) 名单边界：空名单、负数、浮点一律拒绝，且拒绝前不落位。
func _plan_edge_inputs() -> void:
	var roster := _roster(60)
	roster.try_extract_selected_formations(roster.get_selected_formations([F1, F2, F3]))
	_check(not bool(roster.try_return_members_by_formation({}).get("ok", true)), "边界：空名单拒绝")
	_check(
		not bool(roster.try_return_members_by_formation({F1: -1}).get("ok", true)),
		"边界：负数拒绝"
	)
	_check(
		not bool(roster.try_return_members_by_formation({F1: 5.0}).get("ok", true)),
		"边界：浮点人数拒绝（不做隐式取整）"
	)
	_check(
		not bool(roster.try_return_members_by_formation({F1: 0}).get("ok", true)),
		"边界：全零名单拒绝（无归队事实）"
	)
	_check(_counts(roster) == [0, 0, 0], "边界：以上拒绝均未改写花名册")
	var zero_mixed := roster.try_return_members_by_formation({F1: 6, F2: 0, F3: 0})
	_check(bool(zero_mixed.get("ok", false)), "边界：全灭编队以 0 人参与名单可接受")
	_check(_counts(roster) == [6, 0, 0], "边界：0 人编队不落位，其余按身份落位")


## 12) 守恒：驻军总数 = 归队前 + 名单总数；兵种仍只有步兵；冷恢复一致。
func _conservation_and_identity() -> void:
	var roster := _roster(20)
	_check(_counts(roster) == [7, 7, 6], "守恒：20 人按花名册余数分布为 7/7/6")
	var outcome := roster.try_return_members_by_formation({F1: 1, F2: 2, F3: 3})
	_check(bool(outcome.get("ok", false)), "守恒：混合归队被接受")
	var expected := 26
	_check(roster.get_total_count() == expected, "守恒：总数 = 归队前 20 + 名单 6")
	_check(roster.get_unit_counts() == {INFANTRY: expected}, "守恒：兵种汇总仍只有步兵")
	var probe := GarrisonState.new()
	_check(probe.restore_persistence_snapshot(roster.get_persistence_snapshot()), "守恒：归队后的花名册可通过持久化校验")
	_check(_counts(probe) == _counts(roster), "守恒：冷恢复后落位与内存完全一致")


func _finish() -> void:
	if failures.is_empty():
		print("FORMATION_RETURN_IDENTITY_GARRISON PASS")
		quit(0)
		return
	print("FORMATION_RETURN_IDENTITY_GARRISON FAIL: %s" % failures)
	quit(1)
