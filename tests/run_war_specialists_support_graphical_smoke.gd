extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/c0_battle_graybox.tscn")
const FACILITY_ID := &"facility.redcliff.lookout.001"

var evidence_directory := ""
var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WAR_SPECIALISTS_SUPPORT_GRAPHICAL_SMOKE requires graphical Godot")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-war-specialists-support-evidence-dir=")
	if _argument_value("--txwzs-v5-save-dir=").is_empty():
		push_error("WAR_SPECIALISTS_SUPPORT_GRAPHICAL_SMOKE requires an isolated save directory")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(4)
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city._war_loop_state.field_tactics.patrols_by_id.clear()
	scene.open_macro_march_r0()
	await _frames(3)
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	var action_menu: MenuButton = macro._action_specialist_menu
	_check(action_menu.is_visible_in_tree() and not action_menu.disabled and action_menu.get_popup().item_count == 4, "地图正式入口显示四种战争专员")
	var food_before := int(city.food)
	action_menu.get_popup().id_pressed.emit(1)
	await _frames(2)
	var field: Dictionary = city.get_field_tactics_read_model()
	var specialist := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(macro._selected_specialist_id, {}))
	_check(StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SABOTEUR and int(city.food) == food_before - 7, "可见菜单经正式事务获得并选中破坏员")
	var facility := Dictionary(city._war_loop_state.field_tactics.watchtowers_by_id.get(FACILITY_ID, {}))
	facility.discovered_by_faction_ids = [&"player"]
	city._war_loop_state.field_tactics.watchtowers_by_id[FACILITY_ID] = facility
	macro.refresh()
	await _frames(2)
	var target_screen := macro._world_to_screen(Vector2(facility.get("world_position", Vector2.ZERO)))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = target_screen
	macro._on_gui_input(click)
	await _frames(2)
	specialist = Dictionary(Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).get(macro._selected_specialist_id, {}))
	_check(StringName(specialist.get("action_kind", &"")) == FieldTacticsState.ACTION_SABOTAGE and StringName(specialist.get("action_target_id", &"")) == FACILITY_ID, "地图点击把已知敌方设施提交为真实破坏目标")
	_capture("field-saboteur-action-engine-gui.png")

	macro.queue_free()
	await _frames(2)
	city.appoint_city_official(&"official.strategist")
	var roster: Array[Dictionary] = city.get_formation_roster()
	city.commit_expedition_attempt([StringName(roster[0].formation_id)])
	var request := BattleRequest.from_expedition_attempt(city.get_expedition_attempt())
	var battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	battle.configure_formal_expedition(scene, city, request)
	root.add_child(battle)
	await _frames(3)
	_check(battle.start_battle(), "正式出征进入活动 BattleSession")
	battle.tick_timer.stop()
	battle._selected_squad_id = 1
	battle._refresh_battle_ui()
	await _frames(2)
	var support_menu: MenuButton = battle.official_support_button
	_check(support_menu.is_visible_in_tree() and not support_menu.disabled and support_menu.text.contains("能量 3"), "战斗界面显示当前文官和共享关卡能量")
	support_menu.get_popup().id_pressed.emit(1)
	await _frames(2)
	_check(int(city.get_city_strategy_read_model().campaign_energy) == 2 and Array(battle.coordinator.active_session.get_official_support_state().effects).size() == 1, "可见战中菜单单次提交疾行命令并扣除一份能量")
	_capture("battle-official-support-engine-gui.png")

	battle.queue_free()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("WAR_SPECIALISTS_SUPPORT_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("WAR_SPECIALISTS_SUPPORT_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var image := root.get_texture().get_image()
	if image == null or image.save_png(evidence_directory.path_join(filename)) != OK:
		failures.append("无法保存图形证据 %s" % filename)


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
