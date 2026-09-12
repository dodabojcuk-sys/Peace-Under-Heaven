extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
var failures: Array[String] = []


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
	var initial: Dictionary = city.get_city_strategy_read_model()
	_check(int(initial.campaign_energy) == 3 and Array(initial.unlocked_official_ids).size() == 3, "新战役确定性获得三名首版文官与三点共享能量")
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	_check(not bool(city.appoint_city_official(&"official.physician").success) and city.get_city_strategy_read_model().appointed_official_id == initial.appointed_official_id, "任命关键保存失败时选择完整回滚")
	_check(bool(city.appoint_city_official(&"official.physician").success), "正式任命入口选择医政官")
	var capacity_before: int = city.get_city_medical_capacity()
	_check(bool(city.activate_city_official_support().success) and city.get_city_medical_capacity() == capacity_before + 4, "医疗支援消耗共享能量并提高真实医疗容量")
	var wood_before: int = city.wood
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	_check(not bool(city.craft_city_equipment(&"equipment.spear_kit").success) and city.wood == wood_before and not city.get_city_strategy_read_model().owned_equipment_ids.has(&"equipment.spear_kit"), "制造关键保存失败时材料与物品归属共同回滚")
	_check(bool(city.craft_city_equipment(&"equipment.spear_kit").success) and city.wood == wood_before - 12, "确定性制造通过既有资源事务获得唯一装备")
	var attack_before: float = city.get_infantry_attack_multiplier()
	_check(bool(city.equip_city_troops(&"equipment.spear_kit").success) and city.get_infantry_attack_multiplier() > attack_before, "制式装备进入正式步兵战斗投影")
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var failed_unequip: Dictionary = city.unequip_city_troops(&"equipment.spear_kit")
	var attack_after_failed_unequip: float = city.get_infantry_attack_multiplier()
	var successful_unequip: Dictionary = city.unequip_city_troops(&"equipment.spear_kit")
	var attack_after_unequip: float = city.get_infantry_attack_multiplier()
	var reequip: Dictionary = city.equip_city_troops(&"equipment.spear_kit")
	_check(not bool(failed_unequip.success) and attack_after_failed_unequip > attack_before and bool(successful_unequip.success) and is_equal_approx(attack_after_unequip, attack_before) and bool(reequip.success), "制式装备卸下经过正式保存边界；失败恢复原装配，成功只移除临时效果")
	city.food = 0
	var trade_before: Dictionary = city.export_v5_campaign_snapshot()
	city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	_check(not bool(city.execute_city_trade(&"trade.wood_for_food").success) and city.export_v5_campaign_snapshot() == trade_before, "交易关键保存失败时付出、收益与回执零部分写入")
	var trade: Dictionary = city.execute_city_trade(&"trade.wood_for_food")
	_check(bool(trade.success) and city.food == 5 and city.wood == int(trade_before.city.wood) - 10, "一键贸易同时提交付出、获得与唯一回执")
	var after_trade: Dictionary = city.export_v5_campaign_snapshot()
	_check(not bool(city.execute_city_trade(&"trade.wood_for_food").success) and city.export_v5_campaign_snapshot() == after_trade, "同日重复交易拒绝且零副作用")
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison")
	var base_duration := int(route.get("duration_milliseconds", 0))
	_check(bool(city.craft_city_equipment(&"equipment.marching_kit").success) and bool(city.equip_city_troops(&"equipment.marching_kit").success) and city.get_macro_march_route_duration(StringName(route.get("route_id", &""))) < base_duration, "轻行装具进入正式道路耗时计算")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var issued: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(route.get("route_id", &"")), Array(route.get("points", [])))
	_check(bool(issued.get("success", false)) and int(Dictionary(issued.army).duration_milliseconds) == city.get_macro_march_route_duration(StringName(route.get("route_id", &""))), "正式军令冻结装配后的机动耗时，城内后续状态不能回写在途参数")
	var frozen_duration := int(Dictionary(issued.army).duration_milliseconds)
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var issued_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(bool(restored.restore_v5_campaign_snapshot(issued_snapshot).success) and restored.export_v5_campaign_snapshot().city_strategy == issued_snapshot.city_strategy and int(Dictionary(restored.get_army_registry_snapshot().armies_by_id.values()[0]).duration_milliseconds) == frozen_duration, "文官能量、装备归属、交易回执与在途冻结参数经正式 V5 精确恢复")
	var battle_scene := CITY_SCENE.instantiate()
	root.add_child(battle_scene)
	await process_frame
	await process_frame
	var battle_city: Node = battle_scene.get_node("ConstructionController")
	battle_city.set_process(false)
	battle_city.restart_first_map()
	battle_city.appoint_city_official(&"official.strategist")
	battle_city.activate_city_official_support()
	battle_city.craft_city_equipment(&"equipment.spear_kit")
	battle_city.equip_city_troops(&"equipment.spear_kit")
	battle_city.craft_city_equipment(&"equipment.padded_armor")
	battle_city.equip_city_troops(&"equipment.padded_armor")
	battle_city.select_general(&"general.vanguard")
	battle_city.craft_city_equipment(&"equipment.general.bronze_sword")
	var general_equipped: Dictionary = battle_city.equip_city_general(&"equipment.general.bronze_sword")
	_check(bool(general_equipped.success) and Dictionary(battle_city.get_city_strategy_read_model().general_equipment_by_general_id[&"general.vanguard"]).size() == 6, "将领六槽保留唯一归属，首版武器可从正式城市整备入口装配")
	var battle_roster: Array[Dictionary] = battle_city.get_formation_roster()
	var departure: Dictionary = battle_city.commit_expedition_attempt([StringName(battle_roster[0].formation_id)])
	var force: Dictionary = Dictionary(Dictionary(departure.get("attempt", {})).get("committed_force_snapshot", {}))
	_check(bool(departure.get("success", false)) and int(force.get("attack_basis_points", 0)) > 10000 and int(force.get("defense_basis_points", 0)) > 10000, "攻击装备、防护装备与战前文官支援冻结进正式战斗快照")
	battle_scene.queue_free()
	await process_frame
	# Reuse the first authoritative city rather than opening a fourth scene on the
	# same persistence directory while the battle fixture has a RESERVED result.
	# Advancing once expires its medical support; the next support can then test
	# the production and expiry-save boundary without cross-scene contamination.
	var expiry_city: Node = city
	expiry_city._advance_day_boundary(true)
	var base_production := int(expiry_city.get_workforce_modifier_permille(&"production"))
	var logging_definition: Resource = expiry_city.get_definition(&"building.logging_camp.t1")
	var logging_capability: Resource = logging_definition.get_capability(&"production")
	var base_logging_output := int(expiry_city._get_production_amount(logging_definition, logging_capability))
	expiry_city.appoint_city_official(&"official.steward")
	expiry_city.activate_city_official_support()
	var boosted_production := int(expiry_city.get_workforce_modifier_permille(&"production"))
	var supported_logging_output := int(expiry_city._get_production_amount(logging_definition, logging_capability))
	expiry_city.set_city_strategy_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var first_boundary := bool(expiry_city._advance_day_boundary(true))
	var expiry_read_model: Dictionary = expiry_city.get_city_strategy_read_model()
	var durable_retry_phase := StringName(Dictionary(expiry_read_model.active_support).phase)
	var expired_production := int(expiry_city.get_workforce_modifier_permille(&"production"))
	var retry_boundary := bool(expiry_city._advance_day_boundary(true))
	_check(supported_logging_output > base_logging_output, "生产支援提高正式建筑生产结算值，不直接发放资源")
	_check(first_boundary and retry_boundary and boosted_production > base_production and expired_production < boosted_production and durable_retry_phase == &"ACTIVE" and not bool(expiry_read_model.active_support_effective) and StringName(Dictionary(expiry_city.get_city_strategy_read_model().active_support).phase) == &"IDLE", "支援到期保存失败时不延长效果，界面标明待重试且下一次边界只清除一次")
	if failures.is_empty():
		print("CITY_STRATEGY_R0_SMOKE PASS assertions=18")
		quit(0)
		return
	for failure in failures:
		push_error("CITY_STRATEGY_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
