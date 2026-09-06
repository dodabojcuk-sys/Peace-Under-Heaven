extends SceneTree


const TITLE_SCENE: PackedScene = preload("res://scenes/title_shell.tscn")
const CITY_SCENE_PATH := "res://scenes/blank_map.tscn"
const TARGET_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_title_layout_contract()
	await _check_single_title_to_city_transition()
	if failures.is_empty():
		print("M1B_PLAYABLE_SHELL_SMOKE: PASS (%d assertions)" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error("M1B_PLAYABLE_SHELL_SMOKE: %s" % failure)
		quit(1)


func _check_title_layout_contract() -> void:
	for target_size in TARGET_SIZES:
		root.size = target_size
		var title := TITLE_SCENE.instantiate() as Control
		root.add_child(title)
		await process_frame
		await process_frame
		var title_label: Label = title.get_node("SafeArea/Center/TitlePanel/Margins/Content/Title")
		var city_label: Label = title.get_node("SafeArea/Center/TitlePanel/Margins/Content/CityName")
		var enter: Button = title.get_node("SafeArea/Center/TitlePanel/Margins/Content/EnterCityButton")
		var exit: Button = title.get_node("SafeArea/Center/TitlePanel/Margins/Content/ExitButton")
		var panel: PanelContainer = title.get_node("SafeArea/Center/TitlePanel")
		var viewport := Rect2(Vector2.ZERO, Vector2(target_size))
		var controls := [title_label, city_label, enter, exit]
		_check(
			title_label.text == "天下无战事"
				and city_label.text == "黑石城"
				and enter.text == "进入黑石城"
				and exit.text == "退出游戏",
			"%dx%d exposes the required minimal title controls" % [target_size.x, target_size.y]
		)
		_check(
			enter.has_focus(),
			"%dx%d gives keyboard focus to enter-city" % [target_size.x, target_size.y]
		)
		for control in controls:
			_check(
				_is_inside(control.get_global_rect(), panel.get_global_rect())
					and _is_inside(control.get_global_rect(), viewport),
				"%dx%d keeps %s inside the title panel and viewport" % [target_size.x, target_size.y, control.name]
			)
		for first_index in range(controls.size()):
			for second_index in range(first_index + 1, controls.size()):
				_check(
					not controls[first_index].get_global_rect().intersects(
						controls[second_index].get_global_rect()
					),
					"%dx%d title controls do not overlap" % [target_size.x, target_size.y]
				)
		var escape := InputEventAction.new()
		escape.action = &"ui_cancel"
		escape.pressed = true
		title._unhandled_key_input(escape)
		_check(
			title.is_inside_tree() and not title.get("_city_transition_requested"),
			"%dx%d Esc leaves the title shell in a stable state" % [target_size.x, target_size.y]
		)
		_check(
			title.get_node_or_null("ConstructionController") == null
				and title.find_children("RuntimeCampaignPersistenceCoordinator", "Node", true, false).is_empty(),
			"%dx%d title creates no city authority or V5 coordinator" % [target_size.x, target_size.y]
		)
		title.queue_free()
		await process_frame


func _check_single_title_to_city_transition() -> void:
	root.size = Vector2i(1152, 648)
	var title := TITLE_SCENE.instantiate() as Control
	root.add_child(title)
	await process_frame
	await process_frame
	var enter: Button = title.get_node("SafeArea/Center/TitlePanel/Margins/Content/EnterCityButton")
	enter.pressed.emit()
	enter.pressed.emit()
	await process_frame
	await process_frame
	var city := current_scene
	_check(
		city != null
			and city.scene_file_path == CITY_SCENE_PATH
			and city.get_node_or_null("ConstructionController") != null,
		"enter-city changes once into the existing canonical city scene"
	)
	_check(
		_count_city_scene_roots() == 1,
		"repeated enter activation leaves one current city scene rather than duplicate owners"
	)
	if city != null:
		city.queue_free()
	await process_frame


func _is_inside(child: Rect2, parent: Rect2) -> bool:
	return parent.encloses(child)


func _count_city_scene_roots() -> int:
	var count := 0
	for child in root.get_children():
		if child is Node and (child as Node).scene_file_path == CITY_SCENE_PATH:
			count += 1
	return count


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
