extends SceneTree

## Cold Continue over a completed normal graphical journey created by this batch.
## An explicit isolated directory is mandatory; no default player save is opened.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var isolated := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--txwzs-v5-save-dir=") and argument.trim_prefix("--txwzs-v5-save-dir=").get_file().begins_with("txwzs-regular-final-media-"):
			isolated = true
	if not isolated:
		push_error("Explicit batch-owned completed-journey save is required")
		quit(1)
		return
	var scene: Node = load("res://scenes/blank_map.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var runtime: RegularCampaignRuntime = city._regular_campaign
	if runtime == null:
		push_error("Completed regular campaign did not restore through Continue")
		quit(1)
		return
	var before: Dictionary = city.export_v5_campaign_snapshot()
	if before.is_empty() or runtime.data.phase != &"COMPLETED" or runtime.data.history.size() != 1 or runtime.data.summary.kind != &"VICTORY":
		failures.append("completed victory/history did not cold restore")
	var repeated := runtime.command(&"confirm")
	if repeated.success or city.export_v5_campaign_snapshot() != before:
		failures.append("cold completed confirmation was not idempotent")
	var old_time := int(runtime.data.mainline_elapsed_ms)
	city.set_city_time_paused(false)
	runtime.advance(30.0)
	if runtime.data.phase != &"COMPLETED" or runtime.data.pressure.stage != 0 or runtime.data.mainline_elapsed_ms <= old_time or city.export_v5_campaign_snapshot().is_empty():
		failures.append("home continuation after cold victory failed")
	print("COMPLETED_COLD_RESTORE ", "PASS" if failures.is_empty() else "FAIL", " history=", runtime.data.history, " result=", runtime.data.summary, " errors=", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
