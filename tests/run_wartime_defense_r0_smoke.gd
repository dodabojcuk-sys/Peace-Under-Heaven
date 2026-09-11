extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var city_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(city_scene)
	await process_frame
	await process_frame
	var city: Node = city_scene.get_node("ConstructionController")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_id := StringName(roster[0].formation_id)
	var food_before := int(city.get("food"))
	var started: Dictionary = city.begin_wartime_defense_attempt([formation_id])
	_check(
		bool(started.get("success", false))
			and StringName(city.get_expedition_attempt().source_id) == BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(city.get_expedition_attempt().mission_id) == &"wartime_defense.blackstone_gate.v0"
			and int(city.get("food")) == food_before,
		"正式守城入口保存冻结编队和守城来源，不创建第二次出征粮食事务"
	)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var snapshot_validation: Dictionary = city.validate_v5_campaign_snapshot(snapshot)
	_check(
		not snapshot.is_empty()
			and bool(snapshot_validation.get("valid", false)),
		"守城 RESERVED 状态进入严格 V5 快照，而非公告板临时状态"
	)
	var gate_button := city_scene.get_node("UI/Shell/BuildingDetailPanel/CityGateActions/EnterWartimeDefenseButton") as Button
	gate_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null,
		"黑石城门的已连接正式守城按钮打开独立 C0 战时实例"
	)
	var route_button := battle.get_node(
		"UI/RootPanel/SquadControls/Squad1/RouteButton"
	) as Button
	var deployment_before: Dictionary = city.get_expedition_attempt()
	var deployment_before_route := StringName(
		Dictionary(deployment_before.committed_force_snapshot).squads[0].route_id
	)
	route_button.emit_signal("pressed")
	await process_frame
	var deployment_after: Dictionary = city.get_expedition_attempt()
	var deployment_after_route := StringName(
		Dictionary(deployment_after.committed_force_snapshot).squads[0].route_id
	)
	var deployment_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		route_button.visible
			and not route_button.disabled
			and deployment_after_route != deployment_before_route
			and StringName(battle.request.committed_force.squads[0].route_id)
				== deployment_after_route
			and StringName(deployment_after.attempt_id) == StringName(deployment_before.attempt_id)
			and int(city.get("food")) == food_before
			and not deployment_snapshot.is_empty()
			and bool(city.validate_v5_campaign_snapshot(deployment_snapshot).get("valid", false)),
		"守城 RESERVED 阶段的路线按钮经正式 GUI 入口更新冻结部署并保存，不重建出征或扣粮"
	)
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var ram_button := plan_panel.get_node("RamButton") as Button
	var arrow_button := plan_panel.get_node("ArrowTowerButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var spike_trap_button := plan_panel.get_node("SpikeTrapButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	var watched_enemy_count_label := battle.get_node(
		"UI/RootPanel/SideLane/EnemyMarker/Count"
	) as Label
	var unwatched_enemy_count_label := battle.get_node(
		"UI/RootPanel/FrontLane/EnemyMarker/Count"
	) as Label
	_check(
		watched_enemy_count_label.text.contains("敌情未明")
			and not watched_enemy_count_label.text.contains("敌军 7"),
		"守城路线在瞭望台完工前只显示可见威胁，不泄露精确来敌兵力"
	)
	_check(
		spike_trap_button.visible
			and not spike_trap_button.disabled
			and not WartimeFacilityPlan.is_available_for_source(
				WartimeFacilityPlan.KIND_SPIKE_TRAP, BattleRequest.SOURCE_MACRO_SIEGE
			),
		"守城面板提供刺钉陷阱，而围城来源不会获得错误的防守陷阱入口"
	)
	var wood_before_plan := int(city.get("wood"))
	var invalid_plan := WartimeFacilityPlan.empty_snapshot()
	invalid_plan.facilities.append(WartimeFacilityPlan.make_facility(
		WartimeFacilityPlan.KIND_SIEGE_RAM,
		CommittedForceSnapshot.FRONT_ROUTE
	))
	var rejected_ram: Dictionary = city.commit_wartime_facility_plan(
		StringName(city.get_expedition_attempt().attempt_id), invalid_plan
	)
	_check(
		not ram_button.visible
			and not bool(rejected_ram.get("success", false))
			and int(city.get("wood")) == wood_before_plan,
		"守城界面隐藏攻城槌，权威提交也拒绝绕过界面的攻城设施且不扣木材"
	)
	var foreign_crew_plan := WartimeFacilityPlan.empty_snapshot()
	foreign_crew_plan.facilities.append(WartimeFacilityPlan.make_facility(
		WartimeFacilityPlan.KIND_BARRICADE,
		CommittedForceSnapshot.SIDE_ROUTE,
		999
	))
	var rejected_foreign_crew: Dictionary = city.commit_wartime_facility_plan(
		StringName(city.get_expedition_attempt().attempt_id), foreign_crew_plan
	)
	_check(
		not bool(rejected_foreign_crew.get("success", false))
			and int(city.get("wood")) == wood_before_plan
			and Array(
				Dictionary(city.get_expedition_attempt().get("wartime_facility_plan", {})).get(
					"facilities", []
				)
			).is_empty(),
		"权威工事提交拒绝不属于本战斗的施工分队且不扣资源或写入计划"
	)
	var legacy_plan := {
		"schema_version": WartimeFacilityPlan.LEGACY_SCHEMA_VERSION,
		"facilities": [{
			"facility_id": &"barricade-side_gate",
			"kind": WartimeFacilityPlan.KIND_BARRICADE,
			"route_id": CommittedForceSnapshot.SIDE_ROUTE,
		}],
	}
	var legacy_plan_attempt: Dictionary = city.get_expedition_attempt()
	legacy_plan_attempt.wartime_facility_plan = legacy_plan.duplicate(true)
	var legacy_plan_request := BattleRequest.from_expedition_attempt(
		legacy_plan_attempt, battle.request.mission_definition
	)
	if legacy_plan_request != null:
		legacy_plan_request.phase = BattleRequest.PHASE_ACTIVE
	var legacy_plan_session := BattleSession.new(legacy_plan_request)
	var normalized_legacy_plan: Dictionary = Dictionary(
		WartimeFacilityPlan.validate_snapshot(legacy_plan).get("snapshot", {})
	)
	var migrated_legacy_barricade := _facility_by_kind(
		legacy_plan_session, WartimeFacilityPlan.KIND_BARRICADE
	)
	_check(
		legacy_plan_request != null
			and int(normalized_legacy_plan.get("schema_version", 0)) == WartimeFacilityPlan.SCHEMA_VERSION
			and int(Dictionary(Array(normalized_legacy_plan.get("facilities", []))[0]).get("construction_squad_id", -1)) == 0
			and int(migrated_legacy_barricade.get("construction_squad_id", 0)) > 0,
		"旧版无施工分队的战时计划保持可读，并在活动会话首次构造时一次绑定真实小队"
	)
	watch_button.emit_signal("pressed")
	arrow_button.emit_signal("pressed")
	barricade_button.emit_signal("pressed")
	await process_frame
	_check(
		battle != null
			and plan_panel.visible
			and not confirm_button.disabled
			and str(plan_panel.get_node("Title").text).contains("东门壕沟"),
		"守城实例复用正式工事草稿、实际路线名称与确认入口，不调用公告板临时战斗"
	)
	confirm_button.emit_signal("pressed")
	await process_frame
	var committed_plan: Dictionary = battle.request.wartime_facility_plan
	var committed_plan_routes: Array[StringName] = []
	var committed_plan_construction_squad_ids: Array[int] = []
	for facility_value in Array(committed_plan.get("facilities", [])):
		var committed_facility: Dictionary = Dictionary(facility_value)
		committed_plan_routes.append(StringName(committed_facility.get("route_id", &"")))
		committed_plan_construction_squad_ids.append(
			int(committed_facility.get("construction_squad_id", 0))
		)
	var committed_plan_uses_selected_squad := committed_plan_construction_squad_ids.all(
		func(squad_id: int) -> bool: return squad_id == 1
	)
	var committed_plan_feedback := battle.get_node(
		"UI/RootPanel/SelectedSquadPanel/RecentActions"
	) as Label
	_check(
		committed_plan_routes.size() == 3
			and committed_plan_routes.all(func(route_id: StringName) -> bool: return route_id == deployment_after_route)
			and committed_plan_uses_selected_squad
			and committed_plan_feedback.text.contains("北门先锋"),
		"可见工事草稿与确认计划均绑定玩家当前选定的守城部署路线和施工分队"
	)
	## A work is owned by its real approach, not globally by its display kind.
	## This isolated session uses the same frozen request facts and battle clock
	## to prove that two legal approaches can each receive one watch platform
	## and arrow tower without creating a second resource or combat owner.
	var dual_route_attempt: Dictionary = city.get_expedition_attempt()
	var dual_route_plan := WartimeFacilityPlan.empty_snapshot()
	for facility_kind in [
		WartimeFacilityPlan.KIND_WATCH_PLATFORM,
		WartimeFacilityPlan.KIND_ARROW_TOWER,
	]:
		for facility_route in [
			CommittedForceSnapshot.FRONT_ROUTE,
			CommittedForceSnapshot.SIDE_ROUTE,
		]:
			dual_route_plan.facilities.append(
				WartimeFacilityPlan.make_facility(facility_kind, facility_route)
			)
	dual_route_attempt.wartime_facility_plan = dual_route_plan.duplicate(true)
	var dual_route_request := BattleRequest.from_expedition_attempt(
		dual_route_attempt, battle.request.mission_definition
	)
	if dual_route_request != null:
		dual_route_request.phase = BattleRequest.PHASE_ACTIVE
	var dual_route_session := BattleSession.new(dual_route_request)
	var front_hp_before_dual := int(
		dual_route_session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_total_hp", 0)
	)
	var side_hp_before_dual := int(
		dual_route_session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_total_hp", 0)
	)
	for _tick in range(BattleSession.ARROW_TOWER_ATTACK_INTERVAL_TICKS):
		dual_route_session.step_tick()
	var dual_effects := dual_route_session.get_wartime_facility_state()
	var dual_snapshot := dual_route_session.get_snapshot()
	var restored_dual_route_session := BattleSession.new(dual_route_request)
	var dual_restore_success := restored_dual_route_session.restore_snapshot(dual_snapshot)
	_check(
		dual_route_request != null
		and bool(WartimeFacilityPlan.validate_snapshot(dual_route_plan).get("valid", false))
		and Array(dual_effects.get("watch_route_ids", [])).has(CommittedForceSnapshot.FRONT_ROUTE)
		and Array(dual_effects.get("watch_route_ids", [])).has(CommittedForceSnapshot.SIDE_ROUTE)
		and Dictionary(dual_effects.get("arrow_towers_by_route", {})).size() == 2
		and int(dual_route_session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_total_hp", 0))
			== front_hp_before_dual - BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY
		and int(dual_route_session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_total_hp", 0))
			== side_hp_before_dual - BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY
		and dual_restore_success
		and Dictionary(restored_dual_route_session.get_wartime_facility_state().get("arrow_towers_by_route", {})).size() == 2,
		"同类瞭望台与箭塔可分别部署至两条守城路线、同时生效并通过同一战斗快照恢复"
	)
	var trap_attempt: Dictionary = city.get_expedition_attempt()
	var trap_plan := WartimeFacilityPlan.empty_snapshot()
	trap_plan.facilities.append(WartimeFacilityPlan.make_facility(
		WartimeFacilityPlan.KIND_SPIKE_TRAP, CommittedForceSnapshot.SIDE_ROUTE
	))
	trap_attempt.wartime_facility_plan = trap_plan.duplicate(true)
	var trap_request := BattleRequest.from_expedition_attempt(
		trap_attempt, battle.request.mission_definition
	)
	if trap_request != null:
		trap_request.phase = BattleRequest.PHASE_ACTIVE
	var trap_session := BattleSession.new(trap_request)
	for _tick in range(int(BattleSession.FACILITY_BUILD_TICKS[WartimeFacilityPlan.KIND_SPIKE_TRAP])):
		trap_session.step_tick()
	var trap_route := trap_session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE)
	trap_route.enemy_position_fixed = int(trap_route.get("distance_fixed", 0))
	trap_session.routes[CommittedForceSnapshot.SIDE_ROUTE] = trap_route
	var trap_enemy_hp_before := int(trap_route.get("enemy_total_hp", 0))
	trap_session.step_tick()
	var triggered_trap := _facility_by_kind(
		trap_session, WartimeFacilityPlan.KIND_SPIKE_TRAP
	)
	var trap_triggered := trap_session.get_last_tick_facility_events().any(
		func(event: Dictionary) -> bool:
			return StringName(event.get("event", &"")) == &"TRAP_TRIGGERED"
	)
	var trap_destroyed_twice := trap_session.get_last_tick_facility_events().any(
		func(event: Dictionary) -> bool:
			return (
				StringName(event.get("kind", &"")) == WartimeFacilityPlan.KIND_SPIKE_TRAP
				and StringName(event.get("event", &"")) == &"DESTROYED"
			)
	)
	var trap_snapshot := trap_session.get_snapshot()
	var restored_trap_session := BattleSession.new(trap_request)
	var trap_restore_success := restored_trap_session.restore_snapshot(trap_snapshot)
	var trap_enemy_hp_after_trigger := int(
		restored_trap_session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_total_hp", 0)
	)
	restored_trap_session.step_tick()
	_check(
		trap_request != null
			and bool(WartimeFacilityPlan.validate_for_source(
				trap_plan, BattleRequest.SOURCE_WARTIME_DEFENSE
			).get("valid", false))
			and not bool(WartimeFacilityPlan.validate_for_source(
				trap_plan, BattleRequest.SOURCE_MACRO_SIEGE
			).get("valid", false))
			and StringName(triggered_trap.get("phase", &"")) == BattleSession.FACILITY_PHASE_DESTROYED
			and trap_triggered
			and not trap_destroyed_twice
			and int(trap_session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_total_hp", 0))
				== trap_enemy_hp_before - BattleSession.SPIKE_TRAP_DAMAGE_ON_TRIGGER
			and trap_restore_success
			and int(restored_trap_session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_total_hp", 0))
				== trap_enemy_hp_after_trigger,
		"刺钉陷阱在敌军实际抵达路线时一次性造成伤害并耗尽；冷恢复后不重播或重复扣除敌军生命"
	)
	_check(battle.start_battle(), "守城工事确认后由同一正式 C0 时钟启动")
	battle.tick_timer.stop()
	var session := battle.coordinator.active_session
	var objective: Dictionary = session.get_mission_objective_state()
	_check(
		StringName(objective.get("objective_type", &"")) == MissionDefinition.OBJECTIVE_PROTECT
			and str(objective.get("protect_target_name", "")) == "黑石城门"
			and int(objective.get("protect_target_hp", 0)) > 0,
		"守城实例从冻结任务读取真实城门保护目标，而非复用攻城胜利条件"
	)
	## This focused session fixture puts an invader at the real route objective
	## before the first construction can finish. The normal UI route then uses
	## the same BattleSession lifecycle; only enemy arrival is accelerated here.
	var construction_probe := BattleSession.new(battle.request)
	var probe_route: Dictionary = construction_probe.get_route_state(deployment_after_route)
	probe_route.enemy_position_fixed = int(probe_route.get("distance_fixed", 0))
	construction_probe.routes[deployment_after_route] = probe_route
	construction_probe.current_tick = BattleSession.ATTACK_INTERVAL_TICKS - 1
	var probe_gate_before := int(
		construction_probe.get_mission_objective_state().get("protect_target_hp", 0)
	)
	construction_probe.step_tick()
	var interrupted_barricade := _facility_by_kind(
		construction_probe,
		WartimeFacilityPlan.KIND_BARRICADE
	)
	var construction_interrupted := construction_probe.get_last_tick_facility_events().any(
		func(event: Dictionary) -> bool:
			return (
				StringName(event.get("event", &"")) == &"CONSTRUCTION_INTERRUPTED"
				and StringName(event.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE
			)
	)
	var interrupted_projection: Dictionary = construction_probe.get_wartime_facility_state()
	var interrupted_snapshot: Dictionary = construction_probe.get_snapshot()
	var interrupted_restore_probe := BattleSession.new(battle.request)
	var interrupted_restore_success := interrupted_restore_probe.restore_snapshot(interrupted_snapshot)
	var restored_interrupted_barricade := _facility_by_kind(
		interrupted_restore_probe,
		WartimeFacilityPlan.KIND_BARRICADE
	)
	probe_route = construction_probe.get_route_state(deployment_after_route)
	probe_route.enemy_position_fixed = 0
	construction_probe.routes[deployment_after_route] = probe_route
	var interrupted_repair_started := construction_probe.begin_wartime_facility_repair(
		StringName(interrupted_barricade.get("facility_id", &""))
	)
	construction_probe.step_tick()
	construction_probe.step_tick()
	var repaired_interrupted_barricade := _facility_by_kind(
		construction_probe,
		WartimeFacilityPlan.KIND_BARRICADE
	)
	_check(
		StringName(interrupted_barricade.get("phase", &""))
			== BattleSession.FACILITY_PHASE_INTERRUPTED
			and int(interrupted_barricade.get("progress_ticks", 0)) > 0
			and int(interrupted_barricade.get("progress_ticks", 0))
				< int(interrupted_barricade.get("required_ticks", 0))
			and int(construction_probe.get_mission_objective_state().get("protect_target_hp", 0))
				== probe_gate_before
			and not interrupted_projection.has("barricade_route_id")
			and construction_interrupted
			and interrupted_restore_success
			and StringName(restored_interrupted_barricade.get("phase", &""))
				== BattleSession.FACILITY_PHASE_INTERRUPTED
			and interrupted_repair_started
			and StringName(repaired_interrupted_barricade.get("phase", &""))
				== BattleSession.FACILITY_PHASE_ACTIVE,
		"敌军抵达时会中断未完工拒马；未生效前不提供防护，维修后才恢复作用"
	)
	## A construction detachment is an actual committed squad, not a new hidden
	## specialist. Its withdrawal must halt only its unfinished facility and be
	## carried by the normal battle snapshot without fabricating a replacement.
	var crew_loss_probe := BattleSession.new(battle.request)
	var crew_loss_barricade := _facility_by_kind(
		crew_loss_probe, WartimeFacilityPlan.KIND_BARRICADE
	)
	var construction_squad_id := int(crew_loss_barricade.get("construction_squad_id", 0))
	for squad_index in crew_loss_probe.squads.size():
		var construction_squad: Dictionary = Dictionary(crew_loss_probe.squads[squad_index])
		if int(construction_squad.get("squad_id", 0)) == construction_squad_id:
			construction_squad.exited = true
			crew_loss_probe.squads[squad_index] = construction_squad
			break
	crew_loss_probe.step_tick()
	var crew_loss_record := _facility_by_kind(
		crew_loss_probe, WartimeFacilityPlan.KIND_BARRICADE
	)
	var crew_loss_event := crew_loss_probe.get_last_tick_facility_events().any(
		func(event: Dictionary) -> bool:
			return (
				StringName(event.get("event", &"")) == &"CONSTRUCTION_CREW_LOST"
				and int(event.get("squad_id", 0)) == construction_squad_id
			)
	)
	var crew_loss_snapshot := crew_loss_probe.get_snapshot()
	var crew_loss_restore_probe := BattleSession.new(battle.request)
	var crew_loss_restore_success := crew_loss_restore_probe.restore_snapshot(crew_loss_snapshot)
	var restored_crew_loss_record := _facility_by_kind(
		crew_loss_restore_probe, WartimeFacilityPlan.KIND_BARRICADE
	)
	_check(
		construction_squad_id > 0
			and StringName(crew_loss_record.get("phase", &""))
				== BattleSession.FACILITY_PHASE_INTERRUPTED
			and crew_loss_event
			and crew_loss_restore_success
			and int(restored_crew_loss_record.get("construction_squad_id", 0))
				== construction_squad_id
			and StringName(restored_crew_loss_record.get("phase", &""))
				== BattleSession.FACILITY_PHASE_INTERRUPTED,
		"施工分队退出会中断未完工设施，并在活动战时快照恢复后保留真实分队身份"
	)
	var target_hp_before := int(objective.get("protect_target_hp", 0))
	battle.step_battle_for_test(4)
	var watched_route: Dictionary = session.get_route_state(deployment_after_route)
	var unwatched_route: Dictionary = session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE)
	var full_enemy_advance := session._positive_integer_divide(
		battle.request.committed_force.move_speed_fixed,
		4
	)
	var blocked_enemy_advance := maxi(
		int(
			full_enemy_advance
			* BattleSession.BARRICADE_ENEMY_ADVANCE_BASIS_POINTS
			/ BattleSession.BASIS_POINTS
		),
		1
	)
	var expected_observed_count := ceili(
		float(int(watched_route.get("enemy_total_hp", 0)))
		/ float(battle.request.committed_force.hp_per_member)
	)
	_check(
		StringName(session.get_wartime_facility_state().get("watch_route_id", &""))
			== deployment_after_route
			and watched_enemy_count_label.text.contains("敌军 %d" % expected_observed_count)
			and unwatched_enemy_count_label.text.contains("敌情未明"),
		"瞭望台完成后只读会话观察事实，仅向玩家选择的正式部署路线界面揭示精确兵力"
	)
	_check(
		int(session.get_mission_objective_state().get("protect_target_hp", 0)) == target_hp_before
			and int(unwatched_route.get("enemy_position_fixed", 0)) == full_enemy_advance * 4
			and int(watched_route.get("enemy_position_fixed", 0))
				== full_enemy_advance * 3 + blocked_enemy_advance,
		"守城拒马在本路线实际延缓敌军推进；未抵达城门前不偷扣保护目标生命"
	)
	## The production mission's small gate HP demonstrates ordinary loss quickly.
	## This fixture needs both real routes to reach the target so it can inspect
	## a barricade's later damage/repair lifecycle after its deliberate delay.
	session.mission_objective_state.protect_target_hp = 10000
	session.mission_objective_state.protect_target_max_hp = 10000
	var lifecycle_route: Dictionary = session.get_route_state(deployment_after_route)
	lifecycle_route.enemy_total_hp = 2500
	session.routes[deployment_after_route] = lifecycle_route
	var target_hp_before_route_contacts := int(
		session.get_mission_objective_state().get("protect_target_hp", 0)
	)
	var legacy_session_snapshot := session.get_snapshot()
	legacy_session_snapshot.schema_version = 3
	## This fixture temporarily enlarges the live target to keep the later
	## facility-damage exercise active.  A historical snapshot must still obey
	## the mission's immutable maximum target HP before strict restoration.
	legacy_session_snapshot.mission_objective_state.protect_target_hp = 540
	legacy_session_snapshot.mission_objective_state.protect_target_max_hp = 540
	for route_id in [CommittedForceSnapshot.FRONT_ROUTE, CommittedForceSnapshot.SIDE_ROUTE]:
		var legacy_route: Dictionary = Dictionary(legacy_session_snapshot.routes[route_id])
		legacy_route.erase("enemy_position_fixed")
		legacy_session_snapshot.routes[route_id] = legacy_route
	## Schema 3 predates the explicit construction-detachment identity. Keep the
	## fixture structurally historical so production migration, rather than a
	## mismatched schema tag, assigns the surviving committed squad.
	for facility_index in Array(legacy_session_snapshot.wartime_facility_state.get("facilities", [])).size():
		var legacy_facility: Dictionary = Dictionary(
			legacy_session_snapshot.wartime_facility_state.facilities[facility_index]
		)
		legacy_facility.erase("construction_squad_id")
		legacy_session_snapshot.wartime_facility_state.facilities[facility_index] = legacy_facility
	var legacy_session := BattleSession.new(battle.request)
	_check(
		legacy_session.restore_snapshot(legacy_session_snapshot)
			and int(legacy_session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_position_fixed", -1)) == 0,
		"V3 活动战时会话升级为从路线起点推进的防守敌军，不伪造旧档的抵近进度"
	)
	var malformed_session_snapshot := session.get_snapshot()
	malformed_session_snapshot.mission_objective_state["protect_target_repair_phase"] = &"BROKEN"
	var malformed_probe := BattleSession.new(battle.request)
	var live_digest_before_malformed_restore := session.get_state_digest()
	_check(
		not malformed_probe.restore_snapshot(malformed_session_snapshot)
			and session.get_state_digest() == live_digest_before_malformed_restore,
		"新格式城门维修快照严格拒绝非法阶段，且不会污染当前活动防守"
	)
	battle.step_battle_for_test(168)
	var after_construction: Dictionary = session.get_wartime_facility_state()
	var barricade: Dictionary = {}
	for record_value in Array(after_construction.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE:
			barricade = record
			break
	_check(
		int(session.get_mission_objective_state().get("protect_target_hp", 0))
			< target_hp_before_route_contacts
			and int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_position_fixed", 0))
				== int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).distance_fixed)
			and int(session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_position_fixed", 0))
				== int(session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).distance_fixed)
			and StringName(barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED
			and int(barricade.get("durability", 0)) < int(barricade.get("max_durability", 0)),
		"守城拒马完工后分担城门的真实敌军伤害，并进入可维修的受损状态"
	)
	var repair_button := battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	battle._refresh_battle_ui()
	repair_button.emit_signal("pressed")
	await process_frame
	var repair_started := false
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("facility_id", &"")) == StringName(barricade.get("facility_id", &"")):
			repair_started = StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING
			break
	_check(repair_started, "守城受损拒马可通过正式维修按钮进入可保存的维修阶段")
	var gate_repair_button := battle.get_node(
		"UI/RootPanel/WartimeGateRepairButton"
	) as Button
	var gate_repair_hp_before := int(
		session.get_mission_objective_state().get("protect_target_hp", 0)
	)
	var wood_before_gate_repair := int(city.get("wood"))
	battle._refresh_battle_ui()
	gate_repair_button.emit_signal("pressed")
	await process_frame
	var gate_repair_started: Dictionary = session.get_mission_objective_state()
	_check(
		gate_repair_button.visible
		and StringName(gate_repair_started.get("protect_target_repair_phase", &""))
			== BattleSession.PROTECT_TARGET_REPAIRING
		and int(gate_repair_started.get("protect_target_repair_amount", 0))
			== mini(
				BattleSession.PROTECT_TARGET_REPAIR_HP,
				int(gate_repair_started.get("protect_target_max_hp", 0)) - gate_repair_hp_before
			)
		and int(city.get("wood"))
			== wood_before_gate_repair - BattleSession.PROTECT_TARGET_REPAIR_WOOD_COST,
		"受损城门经正式按钮一次扣除维修木材并进入可保存的维修阶段"
	)
	var active_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	battle.abort_formal_entry()
	await process_frame
	var restored_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(restored_scene)
	await process_frame
	var restored_city: Node = restored_scene.get_node("ConstructionController")
	var restored: Dictionary = restored_city.restore_v5_campaign_snapshot(active_snapshot)
	_check(
		bool(restored.get("success", false))
			and restored_city.enter_wartime_defense_battle(),
		"守城施工后的 ACTIVE 状态冷恢复后仍只打开同一冻结防守实例"
	)
	await process_frame
	var restored_battle := restored_city.get_formal_battle_scene() as C0BattleGraybox
	var reactivated := restored_battle != null and restored_battle.start_battle()
	if restored_battle != null:
		restored_battle.tick_timer.stop()
		restored_battle.step_battle_for_test(BattleSession.FACILITY_REPAIR_TICKS)
	var repaired_after_restore := false
	for record_value in Array(restored_battle.coordinator.active_session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("facility_id", &"")) == StringName(barricade.get("facility_id", &"")):
			repaired_after_restore = (
				StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
				and int(record.get("durability", 0)) == int(record.get("max_durability", -1))
			)
			break
	var restored_session := restored_battle.coordinator.active_session
	var restored_gate_repair := restored_session.get_mission_objective_state()
	_check(
		StringName(restored_gate_repair.get("protect_target_repair_phase", &""))
			== BattleSession.PROTECT_TARGET_REPAIR_IDLE
		and int(restored_gate_repair.get("protect_target_hp", 0))
			== gate_repair_hp_before + int(gate_repair_started.get("protect_target_repair_amount", 0)),
		"城门维修中的正式会话冷恢复后只消费剩余工期，并恢复一次真实耐久"
	)
	var arrow_lifecycle_route: Dictionary = restored_session.get_route_state(deployment_after_route)
	# The formal setup and cold restore above already built/repaired this route.
	# Hold its real invaders at the reached objective with enough HP to exercise
	# the saved barricade -> tower damage chain without forging any facility,
	# resource, or terminal battle state.
	arrow_lifecycle_route.enemy_total_hp = 2500
	arrow_lifecycle_route.enemy_position_fixed = int(arrow_lifecycle_route.get("distance_fixed", 0))
	restored_session.routes[deployment_after_route] = arrow_lifecycle_route
	var barricade_destroyed := false
	for _tick in range(400):
		restored_battle.step_battle_for_test(1)
		if StringName(
			_facility_by_kind(restored_session, WartimeFacilityPlan.KIND_BARRICADE).get("phase", &"")
		) == BattleSession.FACILITY_PHASE_DESTROYED:
			barricade_destroyed = true
			break
	arrow_lifecycle_route = restored_session.get_route_state(deployment_after_route)
	# Once the actual barricade has been destroyed, lower only the fixture's
	# surviving invader HP so the tower is visibly damaged before it is destroyed.
	arrow_lifecycle_route.enemy_total_hp = 600
	arrow_lifecycle_route.enemy_position_fixed = int(arrow_lifecycle_route.get("distance_fixed", 0))
	restored_session.routes[deployment_after_route] = arrow_lifecycle_route
	var arrow_tower := _facility_by_kind(restored_session, WartimeFacilityPlan.KIND_ARROW_TOWER)
	var arrow_damaged := false
	for _tick in range(80):
		restored_battle.step_battle_for_test(1)
		arrow_tower = _facility_by_kind(restored_session, WartimeFacilityPlan.KIND_ARROW_TOWER)
		if StringName(arrow_tower.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED:
			arrow_damaged = true
			break
	var arrow_damage_before_volley := int(
		restored_session.get_route_state(deployment_after_route).get("enemy_total_hp", 0)
	)
	var expected_damaged_volley := BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY
	if arrow_damaged:
		expected_damaged_volley = restored_session._positive_integer_divide(
			BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY * int(arrow_tower.get("durability", 0)),
			int(arrow_tower.get("max_durability", 1))
		)
	restored_battle.step_battle_for_test(BattleSession.ARROW_TOWER_ATTACK_INTERVAL_TICKS)
	var arrow_damage_events := restored_session.get_last_tick_facility_events().filter(
		func(event: Dictionary) -> bool:
			return StringName(event.get("kind", &"")) == WartimeFacilityPlan.KIND_ARROW_TOWER
	)
	var arrow_route_after_volley: Dictionary = restored_session.get_route_state(deployment_after_route)
	_check(
		barricade_destroyed
			and arrow_damaged
			and not arrow_damage_events.is_empty()
			and int(Dictionary(arrow_damage_events[0]).get("damage", 0)) == expected_damaged_volley
			and int(arrow_route_after_volley.get("enemy_total_hp", 0))
				== arrow_damage_before_volley - expected_damaged_volley,
		"抵近敌军会先拆除箭塔；受损箭塔仍按真实耐久比例发出一次可核对的较弱齐射"
	)
	for _tick in range(48):
		restored_battle.step_battle_for_test(1)
		arrow_tower = _facility_by_kind(restored_session, WartimeFacilityPlan.KIND_ARROW_TOWER)
		if StringName(arrow_tower.get("phase", &"")) == BattleSession.FACILITY_PHASE_DESTROYED:
			break
	var enemy_hp_before_silent_interval := int(
		restored_session.get_route_state(deployment_after_route).get("enemy_total_hp", 0)
	)
	restored_battle.step_battle_for_test(BattleSession.ARROW_TOWER_ATTACK_INTERVAL_TICKS)
	var arrow_events_after_destroy := restored_session.get_last_tick_facility_events().filter(
		func(event: Dictionary) -> bool:
			return StringName(event.get("kind", &"")) == WartimeFacilityPlan.KIND_ARROW_TOWER
	)
	_check(
		StringName(arrow_tower.get("phase", &"")) == BattleSession.FACILITY_PHASE_DESTROYED
			and arrow_events_after_destroy.is_empty()
			and int(restored_session.get_route_state(deployment_after_route).get("enemy_total_hp", 0))
				== enemy_hp_before_silent_interval,
		"箭塔被拆除后不再攻击，后续战斗刻不会伪造额外齐射或敌军伤害"
	)
	var damaged_watch := _facility_by_kind(restored_session, WartimeFacilityPlan.KIND_WATCH_PLATFORM)
	_check(
		StringName(damaged_watch.get("phase", &"")) in [
			BattleSession.FACILITY_PHASE_DAMAGED,
			BattleSession.FACILITY_PHASE_DESTROYED,
		]
			and StringName(restored_session.get_wartime_facility_state().get("watch_route_id", &"")) != deployment_after_route,
		"拒马与箭塔失效后，敌军损坏同路瞭望台；受损瞭望台立即停止提供精确敌情"
	)
	var quiet_arrow_route: Dictionary = restored_session.get_route_state(deployment_after_route)
	quiet_arrow_route.enemy_total_hp = 0
	restored_session.routes[deployment_after_route] = quiet_arrow_route
	restored_battle._refresh_battle_ui()
	var restored_repair_button := restored_battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	var restored_repair_target_button := restored_battle.get_node(
		"UI/RootPanel/WartimeRepairTargetButton"
	) as Button
	var multiple_repair_targets_visible := restored_repair_target_button.visible
	if multiple_repair_targets_visible:
		for _switch in range(3):
			if StringName(restored_battle._selected_repairable_facility().get("facility_id", &"")) == StringName(arrow_tower.get("facility_id", &"")):
				break
			restored_repair_target_button.emit_signal("pressed")
			await process_frame
	var arrow_target_selected := StringName(
		restored_battle._selected_repairable_facility().get("facility_id", &"")
	) == StringName(arrow_tower.get("facility_id", &""))
	_check(
		multiple_repair_targets_visible
			and arrow_target_selected
			and restored_repair_button.text.contains("箭塔"),
		"同路线的拒马和箭塔同时受损时，正式维修界面允许玩家明确切换到箭塔目标"
	)
	restored_repair_button.emit_signal("pressed")
	await process_frame
	var arrow_repair_started := StringName(
		_facility_by_kind(restored_session, WartimeFacilityPlan.KIND_ARROW_TOWER).get("phase", &"")
	) == BattleSession.FACILITY_PHASE_REPAIRING
	restored_battle.step_battle_for_test(BattleSession.FACILITY_REPAIR_TICKS)
	var repaired_arrow := _facility_by_kind(restored_session, WartimeFacilityPlan.KIND_ARROW_TOWER)
	_check(
		arrow_repair_started
			and StringName(repaired_arrow.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
			and int(repaired_arrow.get("durability", 0)) == int(repaired_arrow.get("max_durability", -1))
			and int(restored_session.get_wartime_facility_state().get("arrow_tower_damage_per_volley", 0))
				== BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY,
		"正式维修入口能恢复被摧毁箭塔的耐久和完整齐射能力"
	)
	restored_battle._refresh_battle_ui()
	for _switch in range(3):
		if StringName(restored_battle._selected_repairable_facility().get("facility_id", &"")) == StringName(damaged_watch.get("facility_id", &"")):
			break
		restored_repair_target_button.emit_signal("pressed")
		await process_frame
	var watch_repair_started := StringName(
		restored_battle._selected_repairable_facility().get("facility_id", &"")
	) == StringName(damaged_watch.get("facility_id", &""))
	if watch_repair_started:
		restored_repair_button.emit_signal("pressed")
		await process_frame
		restored_battle.step_battle_for_test(BattleSession.FACILITY_REPAIR_TICKS)
	var repaired_watch := _facility_by_kind(restored_session, WartimeFacilityPlan.KIND_WATCH_PLATFORM)
	_check(
		watch_repair_started
			and StringName(repaired_watch.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
			and StringName(restored_session.get_wartime_facility_state().get("watch_route_id", &""))
				== deployment_after_route,
		"维修同一路线的瞭望台后，保存会话重新提供该路线的真实敌情投影"
	)
	var retreat_applied := (
		reactivated
		and repaired_after_restore
		and restored_battle.open_exit_confirmation()
		and restored_battle.confirm_exit_as_retreat()
		and StringName(restored_city.get_expedition_attempt().phase) == BattleRequest.PHASE_APPLIED
		and int(restored_city.get("food")) == food_before
	)
	var retreat_result_id := StringName(restored_city.get_expedition_attempt().result_id)
	var retreat_summary: Dictionary = restored_city.get_committed_battle_result_summary(retreat_result_id)
	var retreat_return_requested := (
		retreat_applied and restored_battle.request_return_to_city() != null
	)
	await process_frame
	await process_frame
	_check(
		retreat_return_requested
			and StringName(retreat_summary.get("source_id", &""))
				== BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(retreat_summary.get("mission_id", &""))
				== &"wartime_defense.blackstone_gate.v0"
			and restored_city.get_formal_battle_scene() == null
			and int(restored_city.get("first_war_state"))
				== 0,
		"守城维修跨进程恢复后通过来源专属撤离回写返回城市，保留守城身份且不伪装为主线出征"
	)

	# Do not forge a loss state: let the formal protection objective resolve
	# through the same enemy-route and gate-damage clock used in the scene.
	var defeat_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(defeat_scene)
	await process_frame
	var defeat_city: Node = defeat_scene.get_node("ConstructionController")
	var defeat_roster: Array[Dictionary] = defeat_city.get_formation_roster()
	var defeat_formation_id := StringName(defeat_roster[0].formation_id)
	var defeat_food_before := int(defeat_city.get("food"))
	var defeat_started: Dictionary = defeat_city.begin_wartime_defense_attempt([defeat_formation_id])
	var defeat_entered: bool = (
		bool(defeat_started.get("success", false))
		and defeat_city.enter_wartime_defense_battle()
	)
	await process_frame
	var defeat_battle := defeat_city.get_formal_battle_scene() as C0BattleGraybox
	var defeat_result: BattleResult
	if defeat_battle != null and defeat_battle.start_battle():
		defeat_battle.tick_timer.stop()
		defeat_result = defeat_battle.step_battle_for_test(260)
	var defeat_summary: Dictionary = (
		defeat_battle.confirm_pending_result()
		if defeat_battle != null and defeat_result != null
		else {}
	)
	var defeat_snapshot: Dictionary = defeat_city.export_v5_campaign_snapshot()
	_check(
		defeat_entered
			and defeat_result != null
			and defeat_result.outcome == BattleOutcome.Value.DEFEAT
			and not defeat_summary.is_empty()
			and StringName(defeat_summary.get("source_id", &""))
				== BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(defeat_summary.get("mission_id", &""))
				== &"wartime_defense.blackstone_gate.v0"
			and bool(defeat_city.get("city_fallen"))
			and defeat_city.get_city_defense() == 0
			and int(defeat_city.get("food")) == defeat_food_before,
		"敌军自然抵达并击破城门后，守城失败只写回同一守城结果与真实城防，不产生第二次出征粮食事务"
	)
	if defeat_battle != null:
		defeat_battle.abort_formal_entry()
	await process_frame
	var defeat_restored_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(defeat_restored_scene)
	await process_frame
	var defeat_restored_city: Node = defeat_restored_scene.get_node("ConstructionController")
	var defeat_restored: Dictionary = defeat_restored_city.restore_v5_campaign_snapshot(defeat_snapshot)
	_check(
		bool(defeat_restored.get("success", false))
			and bool(defeat_restored_city.get("city_fallen"))
			and defeat_restored_city.get_city_defense() == 0
			and StringName(
				Dictionary(defeat_restored_city.get_committed_battle_result_summary(
					StringName(defeat_city.get_expedition_attempt().result_id)
				)).get("mission_id", &"")
			) == &"wartime_defense.blackstone_gate.v0",
		"已结算的守城失守在 V5 冷恢复后保留原结果与城门状态，不会被主线运行时投影忽略"
	)

	# Win through the same formal route controls rather than synthesizing a
	# terminal result: all three real formations advance to their saved routes.
	var victory_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(victory_scene)
	await process_frame
	var victory_city: Node = victory_scene.get_node("ConstructionController")
	var victory_ids: Array[StringName] = []
	for formation_value in victory_city.get_formation_roster():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			victory_ids.append(StringName(formation.get("formation_id", &"")))
	var victory_started: Dictionary = victory_city.begin_wartime_defense_attempt(victory_ids)
	var victory_entered: bool = (
		bool(victory_started.get("success", false))
		and victory_city.enter_wartime_defense_battle()
	)
	await process_frame
	var victory_battle := victory_city.get_formal_battle_scene() as C0BattleGraybox
	var victory_result: BattleResult
	if victory_battle != null and victory_battle.start_battle():
		victory_battle.tick_timer.stop()
		var advance_button := victory_battle.get_node(
			"UI/RootPanel/SelectedSquadPanel/AdvanceButton"
		) as Button
		for squad_id in [1, 2, 3]:
			var select_button := victory_battle.get_node(
				"UI/RootPanel/SquadControls/Squad%d/SelectButton" % squad_id
			) as Button
			select_button.emit_signal("pressed")
			advance_button.emit_signal("pressed")
			await process_frame
		victory_result = victory_battle.step_battle_for_test(260)
	var victory_summary: Dictionary = (
		victory_battle.confirm_pending_result()
		if victory_battle != null and victory_result != null
		else {}
	)
	var victory_return_requested := (
		victory_battle.request_return_to_city() != null
		if victory_battle != null and not victory_summary.is_empty()
		else false
	)
	await process_frame
	await process_frame
	_check(
		victory_entered
			and victory_result != null
			and victory_result.outcome == BattleOutcome.Value.VICTORY
			and not victory_summary.is_empty()
			and victory_return_requested
			and StringName(victory_summary.get("source_id", &""))
				== BattleRequest.SOURCE_WARTIME_DEFENSE
			and not bool(victory_city.get("city_fallen"))
			and victory_city.get_city_defense() > 0
			and victory_city.get_formal_battle_scene() == null
			and int(victory_city.get("first_war_state")) == 0,
		"三支真实守军经可见选择与前进命令击退来敌，胜利只回写同一守城事务、保留城门并返回常态内城"
	)
	city_scene.queue_free()
	restored_scene.queue_free()
	defeat_scene.queue_free()
	defeat_restored_scene.queue_free()
	victory_scene.queue_free()
	await process_frame
	_finish()


func _facility_by_kind(session: BattleSession, kind: StringName) -> Dictionary:
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("kind", &"")) == kind:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("WARTIME_DEFENSE_R0_SMOKE PASS")
		quit(0)
	else:
		print("WARTIME_DEFENSE_R0_SMOKE FAIL (%d)" % failures.size())
		quit(1)
