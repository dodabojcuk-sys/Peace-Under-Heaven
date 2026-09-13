extends SceneTree


const TITLE_SCENE: PackedScene = preload("res://scenes/title_shell.tscn")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_override: String = root.get_node("RuntimeIdentity").get_campaign_save_directory_override()
	_check(not save_override.is_empty(), "candidate entry smoke uses an explicit isolated save directory")
	change_scene_to_packed(TITLE_SCENE)
	await process_frame
	await process_frame
	var title := current_scene as TitleShell
	var continue_button := title.get_node("SafeArea/Center/TitlePanel/Margins/Content/EnterCityButton") as Button
	var new_button := title.get_node("SafeArea/Center/TitlePanel/Margins/Content/NewGameButton") as Button
	_check(continue_button.disabled and not new_button.disabled, "empty isolated store offers new game and disables continue")
	new_button.pressed.emit()
	(title.get_node("NewGameConfirmation") as ConfirmationDialog).confirmed.emit()
	await process_frame
	await process_frame
	var first_city := current_scene
	var first_controller := first_city.get_node("ConstructionController")
	var created_status: Dictionary = first_city.get_runtime_persistence_status()
	_check(
		StringName(created_status.get("status", &"")) == &"created_new_campaign_generation"
			and int(created_status.get("save_sequence", 0)) == 1
			and first_controller.current_day == 1,
		"new game enters the canonical city and publishes one fresh V5 generation"
	)
	first_controller.current_day = 4
	first_controller.day_elapsed_seconds = 12.0
	first_controller.city_state_changed.emit()
	_check(first_city.flush_runtime_persistence(&"candidate_entry_probe"), "candidate progress saves through the existing coordinator")
	await process_frame
	await process_frame
	change_scene_to_packed(TITLE_SCENE)
	await process_frame
	await process_frame
	title = current_scene as TitleShell
	continue_button = title.get_node("SafeArea/Center/TitlePanel/Margins/Content/EnterCityButton") as Button
	_check(not continue_button.disabled and continue_button.has_focus(), "existing isolated V5 generation enables and focuses continue")
	continue_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var continued_city := current_scene
	var continued_controller := continued_city.get_node("ConstructionController")
	var continued_status: Dictionary = continued_city.get_runtime_persistence_status()
	print("CANDIDATE_CONTINUE_TRACE status=%s loaded=%s day=%d elapsed=%0.3f" % [str(continued_status.get("status", "")), str(continued_status.get("loaded", false)), int(continued_controller.current_day), float(continued_controller.day_elapsed_seconds)])
	_check(
		bool(continued_status.get("loaded", false))
			and int(continued_controller.current_day) == 4
			and float(continued_controller.day_elapsed_seconds) >= 12.0
			and float(continued_controller.day_elapsed_seconds) < 13.0,
		"continue restores the saved campaign through the same city authority"
	)
	if failures.is_empty():
		print("BLACKSTONE_CANDIDATE_ENTRY_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("BLACKSTONE_CANDIDATE_ENTRY_R1_SMOKE FAIL: %s" % failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
