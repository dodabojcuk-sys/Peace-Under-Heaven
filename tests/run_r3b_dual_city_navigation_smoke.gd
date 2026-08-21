extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式主场景可加载")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var construction: Node = scene.get_node("ConstructionController")
	var world_map: Node = scene.get_node("CampaignWorldMap")
	construction.set_city_time_paused(true)
	_check(scene.open_campaign_world_map(), "可从正式城市打开世界地图")
	_check(world_map.is_world_map_open(), "世界地图进入可交互状态")
	_check(world_map.select_node(&"riverbend_city"), "可按稳定 ID 选择河湾城")
	var enter_button: Button = world_map.get_node(
		"UI/Root/SidePanel/Scroll/Content/EnterCityButton"
	)
	_check(enter_button.visible, "河湾城显示正式进入按钮")
	_check(not enter_button.disabled, "河湾城进入按钮可用")
	enter_button.emit_signal("pressed")
	await process_frame
	await process_frame
	_check(not scene.is_campaign_world_map_open(), "进入城市后世界地图关闭")
	_check(
		construction.get_active_city_id() == &"riverbend_city",
		"进入河湾城后单一城市状态权威切换 ID"
	)
	_check(
		construction.get_layout_profile_id() == &"ORGANIC_GARDEN",
		"进入河湾城后正式布局为 ORGANIC_GARDEN"
	)
	_check(
		str(construction.get_city_state().get("city_name", "")) == "河湾城",
		"城市只读状态显示河湾城名称"
	)

	_check(scene.open_campaign_world_map(), "河湾城仍可返回世界地图")
	_check(world_map.select_node(&"blackstone_city"), "可按稳定 ID 选择黑石城")
	_check(not enter_button.disabled, "黑石城进入按钮保持可用")
	enter_button.emit_signal("pressed")
	await process_frame
	await process_frame
	_check(
		construction.get_active_city_id() == &"blackstone_city",
		"可从世界地图返回黑石城"
	)
	_check(
		construction.get_layout_profile_id() == &"REGULAR_IMPERIAL",
		"返回黑石城后规则帝城布局恢复"
	)

	_finish_scene(scene)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("R3B_DUAL_CITY_NAVIGATION_SMOKE=PASS")
		quit(0)
	else:
		print("R3B_DUAL_CITY_NAVIGATION_SMOKE=FAIL count=%d" % failures.size())
		quit(1)
