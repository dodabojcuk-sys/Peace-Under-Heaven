extends SceneTree
const CITY := preload("res://scenes/blank_map.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := CITY.instantiate()
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var initial: Dictionary = city.export_v5_campaign_snapshot()
	for fps in [30, 60, 120]:
		check(city.restore_v5_campaign_snapshot(initial).success, "restore identical clock input")
		var before: int = city.get_day_elapsed_milliseconds()
		for i in fps * 2: city.advance_city_time(1.0 / fps)
		var advanced: int = city.get_day_elapsed_milliseconds() - before
		print("CLOCK fps=", fps, " milliseconds=", advanced)
		check(advanced == 2000, "two seconds stay two seconds at %d FPS" % fps)
	check(city.MAINLINE_PRESSURE_PROFILE.get_next_stage_summary(1).days_until == 7, "day one is seven days from day-eight economic pressure")
	check(city.MAINLINE_PRESSURE_PROFILE.get_next_stage_summary(7).days_until == 1, "day seven is one day before pressure")
	var forecast: Dictionary = city.get_city_food_forecast()
	check(forecast.upkeep == 7 and forecast.income == 0, "fresh city exposes actual food deficit")
	check(city.get_campaign_progress_diagnostics().has("persistence"), "stagnation diagnosis includes real save status")
	scene.queue_free()
	await process_frame
	print("BLACKSTONE_CLOCK_SMOKE ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures.append(message)
