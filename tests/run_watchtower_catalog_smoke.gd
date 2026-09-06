extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const WATCHTOWER_ID := &"building.watchtower.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var watchtower_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/WatchtowerButton"
	)
	var catalog_ids: Array[StringName] = (
		city.get_build_catalog_definition_ids()
	)
	_check(
		not watchtower_button.visible
			and not catalog_ids.has(WATCHTOWER_ID),
		"通用建造菜单按定义资格隐藏瞭望塔"
	)
	_check(
		city.get_definition(WATCHTOWER_ID) != null
			and city.get_definition_ids().has(WATCHTOWER_ID),
		"瞭望塔定义仍注册并可查询"
	)
	for expected_id in [
		&"building.road.t1",
		&"building.logging_camp.t1",
		&"building.farm.t1",
		&"building.warehouse.t1",
	]:
		_check(
			catalog_ids.has(expected_id),
			"其他可建定义保持目录可见：%s" % expected_id
		)
	var before_count: int = city.get_building_count()
	var watchtower_id: int = city.place_definition_at_cell(
		WATCHTOWER_ID,
		Vector2i(20, 20),
		false,
		true
	)
	_check(
		watchtower_id > 0
			and city.get_building_count() == before_count + 1
			and city.get_building_record(watchtower_id).definition_id
				== WATCHTOWER_ID,
		"瞭望塔 fixture placement、查询和显示仍可使用"
	)
	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("WATCHTOWER_CATALOG_SMOKE PASS")
		quit(0)
	else:
		print("WATCHTOWER_CATALOG_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
