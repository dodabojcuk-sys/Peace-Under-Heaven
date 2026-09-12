extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var evidence_directory := ""
var save_directory := ""
var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CITY_STRATEGY_R0_GRAPHICAL_SMOKE requires graphical Godot")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-city-strategy-evidence-dir=")
	save_directory = _argument_value("--txwzs-v5-save-dir=")
	if save_directory.is_empty():
		push_error("CITY_STRATEGY_R0_GRAPHICAL_SMOKE requires an isolated save directory")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	for size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var data := await _new_city(size)
		var entry: Button = data.shell.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceContent/CityStrategyEntryButton")
		_check(entry.is_visible_in_tree() and not entry.disabled, "战略详情入口在 %s 可见可用" % size)
		entry.pressed.emit()
		await _frames(2)
		var workspace: Control = data.shell.get_node("CityStrategyWorkspace")
		_check(workspace.is_visible_in_tree() and workspace.get_global_rect().end.y <= Vector2(size).y, "独立战略详情在 %s 不溢出窗口" % size)
		_capture("city-strategy-overview-%dx%d.png" % [size.x, size.y])
		await _drop_city(data.scene)

	var data := await _new_city(Vector2i(1280, 720))
	data.city.wood = 300
	data.city.select_general(&"general.vanguard")
	var entry: Button = data.shell.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceContent/CityStrategyEntryButton")
	entry.pressed.emit()
	await _frames(2)
	var content: VBoxContainer = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var physician: Button = content.get_node("Official_official_physician")
	_check(physician.is_visible_in_tree() and not physician.disabled, "文官任命通过可见按钮进入正式入口")
	physician.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var support: Button = content.get_node("ActivateOfficialSupportButton")
	var energy_before := int(data.city.get_city_strategy_read_model().campaign_energy)
	support.pressed.emit()
	await _frames(2)
	_check(int(data.city.get_city_strategy_read_model().campaign_energy) == energy_before - 1 and data.city.get_city_medical_capacity() > 0, "可见支援按钮只消耗一次能量并改变真实医疗能力")
	_capture("city-strategy-support-active-1280x720.png")
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var scroll: ScrollContainer = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll")
	var spear: Button = content.get_node("Equipment_equipment_spear_kit")
	scroll.ensure_control_visible(spear)
	await _frames(2)
	_check(spear.is_visible_in_tree() and not spear.disabled, "制式装备制造入口在滚动详情中可见可用")
	spear.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	spear = content.get_node("Equipment_equipment_spear_kit")
	scroll.ensure_control_visible(spear)
	await _frames(2)
	var attack_before: float = float(data.city.get_infantry_attack_multiplier())
	_check(spear.is_visible_in_tree() and not spear.disabled, "已制造装备通过同一可见入口进入装配阶段")
	spear.pressed.emit()
	await _frames(2)
	_check(data.city.get_infantry_attack_multiplier() > attack_before, "可见装配按钮改变真实正式战斗参数")
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	spear = content.get_node("Equipment_equipment_spear_kit")
	_check(spear.text.begins_with("卸下") and not spear.disabled, "装配完成后同一可见入口提供卸下操作")
	var trade: Button = content.get_node("Trade_trade_wood_for_food")
	scroll.ensure_control_visible(trade)
	await _frames(2)
	var receipts_before := Array(data.city.get_city_strategy_read_model().trade_receipts).size()
	_check(trade.is_visible_in_tree() and not trade.disabled, "贸易入口显示实际交换和仓储条件")
	trade.pressed.emit()
	await _frames(2)
	_check(Array(data.city.get_city_strategy_read_model().trade_receipts).size() == receipts_before + 1, "可见贸易按钮只生成一次正式回执")
	_capture("city-strategy-equipment-trade-1280x720.png")
	var general_items: Array[StringName] = [
		&"equipment.general.iron_sword", &"equipment.general.scout_helmet", &"equipment.general.lamellar",
		&"equipment.general.leather_gloves", &"equipment.general.riding_boots", &"equipment.general.command_talisman",
	]
	for equipment_id in general_items:
		content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
		var button: Button = content.get_node("Equipment_%s" % String(equipment_id).replace(".", "_"))
		scroll.ensure_control_visible(button)
		await _frames(1)
		button.pressed.emit()
		await _frames(2)
		content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
		button = content.get_node("Equipment_%s" % String(equipment_id).replace(".", "_"))
		scroll.ensure_control_visible(button)
		button.pressed.emit()
		await _frames(2)
	var general_loadout: Dictionary = Dictionary(data.city.get_city_strategy_read_model().general_equipment_by_general_id[&"general.vanguard"])
	_check(general_loadout.values().all(func(value: Variant) -> bool: return StringName(value) != &""), "六槽物品均通过可见制造与装配按钮进入选中将领")
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var helmet_train: Button = content.get_node("Train_equipment_general_scout_helmet")
	scroll.ensure_control_visible(helmet_train)
	helmet_train.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	helmet_train = content.get_node("Train_equipment_general_scout_helmet")
	helmet_train.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var helmet_rank: Button = content.get_node("Rank_equipment_general_scout_helmet")
	scroll.ensure_control_visible(helmet_rank)
	await _frames(1)
	_check(helmet_rank.is_visible_in_tree() and not helmet_rank.disabled, "达到等级上限后可见升阶入口说明保留累计经验")
	helmet_rank.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var bronze: Button = content.get_node("Equipment_equipment_general_bronze_sword")
	scroll.ensure_control_visible(bronze)
	bronze.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var bronze_train: Button = content.get_node("Train_equipment_general_bronze_sword")
	bronze_train.pressed.emit()
	await _frames(2)
	content = data.shell.get_node("CityStrategyWorkspace/StrategyMargin/StrategyScroll/StrategyContent")
	var inherit: Button = content.get_node("InheritBronzeSwordToIronSword")
	scroll.ensure_control_visible(inherit)
	await _frames(1)
	_check(inherit.is_visible_in_tree() and not inherit.disabled and inherit.text.contains("来源将消失"), "继承入口在确认前明确说明来源装备会被消耗")
	inherit.pressed.emit()
	await _frames(2)
	_check(&"equipment.general.bronze_sword" not in Array(data.city.get_city_strategy_read_model().owned_equipment_ids), "可见继承按钮只提交一次并移除指定来源装备")
	_capture("city-strategy-six-slot-growth-1280x720.png")
	await _drop_city(data.scene)

	if failures.is_empty():
		print("CITY_STRATEGY_R0_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("CITY_STRATEGY_R0_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city(size: Vector2i) -> Dictionary:
	root.size = size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(4)
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	await _frames(2)
	return {"scene": scene, "city": city, "shell": scene.get_node("UI/Shell")}


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var image := root.get_texture().get_image()
	if image == null or image.save_png(evidence_directory.path_join(filename)) != OK:
		failures.append("无法写入图形证据 %s" % filename)


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame


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
