extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const TARGET_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 900)]
const REGION_NAMES := [
	"resources",
	"city",
	"date_and_settlement",
	"deadline_and_pressure",
	"speed_and_pause",
]

var _assertions := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for target_size in TARGET_SIZES:
		await _check_top_bar_at(target_size)
	if _failures == 0:
		print("M0_R0C1_TOPBAR_RESPONSIVE_SMOKE: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("M0_R0C1_TOPBAR_RESPONSIVE_SMOKE: FAIL (%d failures)" % _failures)
		quit(1)


func _check_top_bar_at(target_size: Vector2i) -> void:
	root.size = target_size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node = scene.get_node("ConstructionController")
	var shell: Control = scene.get_node("UI/Shell")
	var top_bar: Control = shell.get_node("TopStatusBar")
	var daily_report: Label = top_bar.get_node("DailyReport")
	var next_stage_summary: Label = top_bar.get_node("NextStageSummary")
	var alert_summary: Label = top_bar.get_node("AlertSummary")
	var speed: OptionButton = top_bar.get_node("TimeSpeedOption")
	var pause: Button = top_bar.get_node("PauseButton")

	# A settled day produces the longest live date/settlement copy. Security is
	# deliberately non-default so the pressure row also exercises its full shape.
	controller.set_city_security_for_test(73)
	controller.advance_one_day_for_test()
	controller._refresh_city_ui()
	shell._refresh_read_model()
	await process_frame

	_check(
		daily_report.text.contains("今日结算") and next_stage_summary.text.contains("下一阶段"),
		"%dx%d uses live settlement and next-stage copy" % [target_size.x, target_size.y]
	)
	_check(
		alert_summary.text.contains("主线期限")
			and alert_summary.text.contains("压力")
			and alert_summary.text.contains("治安"),
		"%dx%d keeps deadline, pressure, and security copy" % [target_size.x, target_size.y]
	)
	_check(
		daily_report.size.y <= 36.0 and daily_report.visible,
		"%dx%d limits settlement detail to its two-line region" % [target_size.x, target_size.y]
	)
	_check(
		speed.size.x >= 78.0 and pause.size.x >= 72.0,
		"%dx%d preserves readable speed and pause controls" % [target_size.x, target_size.y]
	)

	var regions: Dictionary = shell.get_top_status_region_rects()
	var top_rect := top_bar.get_global_rect()
	for region_name in REGION_NAMES:
		var region: Rect2 = regions[region_name]
		_check(
			_is_inside(region, top_rect),
			"%dx%d %s region stays inside the top bar" % [
				target_size.x,
				target_size.y,
				region_name,
			]
		)
	for index in range(REGION_NAMES.size()):
		for other_index in range(index + 1, REGION_NAMES.size()):
			var first_name: String = REGION_NAMES[index]
			var second_name: String = REGION_NAMES[other_index]
			_check(
				not (regions[first_name] as Rect2).intersects(regions[second_name] as Rect2),
				"%dx%d %s and %s regions do not intersect" % [
					target_size.x,
					target_size.y,
					first_name,
					second_name,
				]
			)

	scene.queue_free()
	await process_frame


func _is_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.1
		and inner.position.y >= outer.position.y - 0.1
		and inner.end.x <= outer.end.x + 0.1
		and inner.end.y <= outer.end.y + 0.1
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
