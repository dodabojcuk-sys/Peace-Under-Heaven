extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const GENERAL_ITEMS: Array[StringName] = [
	&"equipment.general.iron_sword", &"equipment.general.scout_helmet",
	&"equipment.general.lamellar", &"equipment.general.leather_gloves",
	&"equipment.general.riding_boots", &"equipment.general.command_talisman",
]
var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city.wood = 300
	city.select_general(&"general.vanguard")
	var base_attack: float = city.get_infantry_attack_multiplier()
	var base_defense: float = city.get_infantry_defense_multiplier()
	for equipment_id in GENERAL_ITEMS:
		_check(bool(city.craft_city_equipment(equipment_id).success), "正式制造获得 %s" % String(equipment_id))
		_check(bool(city.equip_city_general(equipment_id).success), "正式装配 %s" % String(equipment_id))
	var loadout: Dictionary = Dictionary(city.get_city_strategy_read_model().general_equipment_by_general_id[&"general.vanguard"])
	var filled := 0
	for item in loadout.values():
		filled += 1 if StringName(item) != &"" else 0
	_check(filled == 6 and city.get_infantry_attack_multiplier() > base_attack and city.get_infantry_defense_multiplier() > base_defense, "将领六槽均有正式物品，攻击与防护效果进入真实战斗参数")

	# Bronze and iron swords share the weapon slot. Keep iron equipped and grow
	# the unassigned bronze sword so inheritance can prove the occupied-source
	# guard and the destructive transaction boundary.
	_check(bool(city.craft_city_equipment(&"equipment.general.bronze_sword").success), "同槽来源装备通过正式制造获得")
	var wood_before_training: int = city.wood
	_check(bool(city.train_city_equipment(&"equipment.general.bronze_sword").success), "培养投入现有资源并增加累计经验")
	var after_first_training: Dictionary = city.export_v5_campaign_snapshot()
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var failed_training: Dictionary = city.train_city_equipment(&"equipment.general.bronze_sword")
	_check(not bool(failed_training.success) and city.export_v5_campaign_snapshot() == after_first_training, "培养保存失败时资源与累计经验完整回滚")
	_check(bool(city.train_city_equipment(&"equipment.general.bronze_sword").success) and city.wood == wood_before_training - 8, "重复培养只按成功事务扣费并达到当前等级上限")
	var before_rank: Dictionary = city.export_v5_campaign_snapshot()
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var failed_rank: Dictionary = city.rank_up_city_equipment(&"equipment.general.bronze_sword")
	_check(not bool(failed_rank.success) and city.export_v5_campaign_snapshot() == before_rank, "升阶保存失败时品质、经验与资源共同回滚")
	_check(bool(city.rank_up_city_equipment(&"equipment.general.bronze_sword").success), "满级装备支付确定成本升至下一品质并保留累计经验")

	# An equipped source cannot be consumed. Swapping the weapon also proves that
	# the visible six-slot loadout and the authority refer to the same item.
	_check(bool(city.unequip_city_general(&"equipment.general.iron_sword").success) and bool(city.equip_city_general(&"equipment.general.bronze_sword").success), "同槽换装明确更新实际将领装备")
	var occupied_inheritance: Dictionary = city.inherit_city_equipment_experience(&"equipment.general.iron_sword", &"equipment.general.bronze_sword")
	_check(not bool(occupied_inheritance.success), "已装配来源装备不能作为继承材料")
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison")
	var route_duration: int = city.get_macro_march_route_duration(StringName(route.route_id))
	var roster: Array[Dictionary] = city.get_formation_roster()
	var issued: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(route.route_id), Array(route.points))
	var army_id := StringName(Dictionary(issued.get("army", {})).get("army_id", &""))
	var frozen_duration := int(Dictionary(issued.get("army", {})).get("duration_milliseconds", 0))
	city.unequip_city_general(&"equipment.general.bronze_sword")
	city.equip_city_general(&"equipment.general.iron_sword")
	var referenced_inheritance: Dictionary = city.inherit_city_equipment_experience(&"equipment.general.iron_sword", &"equipment.general.bronze_sword")
	_check(not bool(referenced_inheritance.success) and &"equipment.general.bronze_sword" in Array(city.get_city_strategy_read_model().owned_equipment_ids), "已被活动军令冻结引用的来源装备不能作为继承材料")
	city.advance_macro_march_time(army_id, StringName(Dictionary(issued.army).transaction_id), 0, frozen_duration)
	var before_inherit: Dictionary = city.export_v5_campaign_snapshot()
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var failed_inherit: Dictionary = city.inherit_city_equipment_experience(&"equipment.general.iron_sword", &"equipment.general.bronze_sword")
	_check(not bool(failed_inherit.success) and city.export_v5_campaign_snapshot() == before_inherit, "继承保存失败不消耗来源、不增加目标经验")
	var inherited: Dictionary = city.inherit_city_equipment_experience(&"equipment.general.iron_sword", &"equipment.general.bronze_sword")
	var inherited_model: Dictionary = city.get_city_strategy_read_model()
	var iron_growth: Dictionary = Dictionary(inherited_model.equipment_growth_models[&"equipment.general.iron_sword"])
	_check(bool(inherited.success) and &"equipment.general.bronze_sword" not in Array(inherited_model.owned_equipment_ids) and int(iron_growth.experience) == 300 and int(iron_growth.level) == 3, "继承原子消耗来源并保留超出当前品质上限的累计经验")
	_check(bool(city.rank_up_city_equipment(&"equipment.general.iron_sword").success) and int(Dictionary(city.get_city_strategy_read_model().equipment_growth_models[&"equipment.general.iron_sword"]).level) == 4, "后续升阶立即释放此前保留的超限经验")

	city.train_city_equipment(&"equipment.general.riding_boots")
	var army_after_growth: Dictionary = city._army_registry.get_army(army_id)
	_check(bool(issued.success) and frozen_duration == route_duration and int(army_after_growth.duration_milliseconds) == frozen_duration and int(Dictionary(army_after_growth.macro_march.strategy_snapshot).attack_basis_points) > roundi(base_attack * 10000.0), "军令冻结装备身份、机动与攻防参数，城内培养不回写")
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restore_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(bool(restore_result.success) and restored.export_v5_campaign_snapshot().city_strategy == snapshot.city_strategy and int(restored._army_registry.get_army(army_id).duration_milliseconds) == frozen_duration, "培养、升阶、继承与在途冻结参数经正式 V5 精确恢复")
	var legacy_snapshot := snapshot.duplicate(true)
	legacy_snapshot.city_strategy.schema_version = 1
	legacy_snapshot.city_strategy.erase("equipment_growth_by_id")
	var legacy_scene := CITY_SCENE.instantiate()
	root.add_child(legacy_scene)
	await process_frame
	await process_frame
	var legacy_city: Node = legacy_scene.get_node("ConstructionController")
	legacy_city.set_process(false)
	var legacy_restore: Dictionary = legacy_city.restore_v5_campaign_snapshot(legacy_snapshot)
	var legacy_model: Dictionary = legacy_city.get_city_strategy_read_model()
	var legacy_growth_ok := true
	for growth_value in Dictionary(legacy_model.equipment_growth_models).values():
		var growth: Dictionary = Dictionary(growth_value)
		legacy_growth_ok = legacy_growth_ok and StringName(growth.quality_id) == &"COMMON" and int(growth.experience) == 0
	_check(bool(legacy_restore.success) and Array(legacy_model.owned_equipment_ids) == Array(legacy_snapshot.city_strategy.owned_equipment_ids) and legacy_growth_ok, "旧嵌套 schema 1 只为既有物品补零经验常备记录，不补发装备或免费品质")

	if failures.is_empty():
		print("CITY_STRATEGY_GROWTH_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("CITY_STRATEGY_GROWTH_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
