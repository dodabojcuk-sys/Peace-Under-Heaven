extends SceneTree


# SUPERSEDED_BY_R0C: R0B's catalog-to-map timed-foundation contract is
# intentionally unreachable. This regression keeps its legality/error/input
# contributions while asserting the replacement boundary.
const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var _failures := 0
var _assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node = scene.get_node("ConstructionController")
	controller.set_process(false)
	var build_button: Button = scene.get_node(
		"UI/Shell/GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/GovernanceCatalogButton"
	)
	var camp_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)
	var initial_count: int = controller.get_building_count()
	await _click(build_button.get_global_rect().get_center())
	_check(controller.is_choosing_template(), "actual UI click opens the catalog")
	await _click(camp_button.get_global_rect().get_center())
	_check(
		controller.has_build_project() and not controller.is_placing(),
		"SUPERSEDED_BY_R0C: building selection starts the off-map slot"
	)
	_check(
		controller.get_building_count() == initial_count,
		"SUPERSEDED_BY_R0C: selection cannot create a map foundation"
	)
	_check(
		not controller.begin_placing_definition(
			&"building.logging_camp.t1",
			Vector2(400.0, 300.0)
		),
		"occupied single slot cannot reopen R0B direct foundation placement"
	)
	_check(
		controller._player_failure_message({"reason_code": &"ROAD_OVERLAP"})
			== "无法建造：与道路重叠"
		and controller._ready_placement_failure_message(
			{"reason_code": &"ROAD_OVERLAP"}
		) == "无法放置：与道路重叠",
		"structured R0B legality survives with phase-correct R0C copy"
	)
	_check(
		not scene.has_node(
			"UI/Shell/ConstructionEntryPanel/ConfirmPlacementButton"
		),
		"no independent building confirmation button returns"
	)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var entry: Control = scene.get_node("UI/Shell/ConstructionEntryPanel")
		_check(
			entry.get_global_rect().end.x <= float(viewport_size.x)
			and entry.get_global_rect().end.y <= float(viewport_size.y),
			"%dx%d R0C slot rail stays inside the viewport" % [
				viewport_size.x,
				viewport_size.y,
			]
		)
	scene.queue_free()
	await process_frame
	if _failures == 0:
		print("M0_R0B_SUPERSEDED_BY_R0C_SMOKE: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("M0_R0B_SUPERSEDED_BY_R0C_SMOKE: FAIL (%d failures)" % _failures)
		quit(1)


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
