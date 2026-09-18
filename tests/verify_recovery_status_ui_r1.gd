extends SceneTree


## RECOVERY_STATUS_UI_R1 title-page recovery status matrix. Every case boots
## the real title scene (or produces fixtures with the real city scene) in a
## cold subprocess against an isolated
## /private/tmp/txwzs-recovery-ui-<random> directory. The precheck must stay
## read-only: file inventory + SHA256 must be identical across every title run.

const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const TITLE_SCENE := preload("res://scenes/title_shell.tscn")
const RUNTIME_IDENTITY := preload("res://scripts/runtime_identity.gd")
const DELIVERY_DIR := "/Users/m4-zhi/Documents/TXWZS_RECOVERY_STATUS_UI_R1_DELIVERY"

var failures: Array[String] = []
var _case_log: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	if not mode.is_empty():
		await _run_worker(mode)
		return
	_run_matrix()


func _run_matrix() -> void:
	var root_dir := "/private/tmp/txwzs-recovery-ui-%d-%d" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	]
	var dir_no_save := root_dir + "/no-save"
	var dir_valid := root_dir + "/valid"
	var dir_previous := root_dir + "/previous"
	var dir_single_invalid := root_dir + "/single-invalid"
	var dir_all_invalid := root_dir + "/all-invalid"
	var dir_future_schema := root_dir + "/future-schema"
	var dir_future_storage := root_dir + "/future-storage"
	var dir_new_game := root_dir + "/new-game"
	for path in [
		dir_no_save, dir_valid, dir_previous, dir_single_invalid,
		dir_all_invalid, dir_future_schema, dir_future_storage, dir_new_game,
	]:
		DirAccess.make_dir_recursive_absolute(path)

	# 1 NO_SAVE
	_run_title_case(1, "NO_SAVE", dir_no_save, [],
		{"status": "NO_SAVE", "continue_disabled": true, "label_contains": "尚无可继续"},
		"1: 空目录 → NO_SAVE，继续游戏禁用，新局入口正常")

	# Produce fixtures: gen1(+gen2 where needed).
	_check(_worker("PRODUCE", dir_valid).passed, "fixture: valid 目录产出合法战役代次")
	_check(_worker("PRODUCE2", dir_previous).passed, "fixture: previous 目录产出两代")
	_check(_worker("PRODUCE1", dir_single_invalid).passed, "fixture: single-invalid 目录产出恰一代")
	_check(_worker("PRODUCE2", dir_all_invalid).passed, "fixture: all-invalid 目录产出两代")
	_check(_worker("PRODUCE2", dir_future_schema).passed, "fixture: future-schema 目录产出两代")
	_check(_worker("PRODUCE2", dir_future_storage).passed, "fixture: future-storage 目录产出两代")
	_check(_worker("PRODUCE2", dir_new_game).passed, "fixture: new-game 目录产出两代")

	# 2 RECOVERABLE_LATEST
	_run_title_case(2, "RECOVERABLE_LATEST", dir_valid, [],
		{"status": "RECOVERABLE_LATEST", "continue_disabled": false, "label_contains": "检测到黑石战役存档"},
		"2: 合法最新代 → RECOVERABLE_LATEST，继续游戏可用")

	# 3 RECOVERABLE_PREVIOUS (plain-corrupt latest, previous valid)
	_corrupt_file_plain(_latest_generation_path(dir_previous))
	_run_title_case(3, "RECOVERABLE_PREVIOUS", dir_previous, [],
		{"status": "RECOVERABLE_PREVIOUS", "continue_disabled": false, "label_contains": "最新存档不可用，将恢复到上一可用存档"},
		"3: 最新代损坏、上一代合法 → RECOVERABLE_PREVIOUS，带恢复提示")

	# 4 single invalid (validator-level), 5 all invalid
	_check(_surgically_invalidate_regular_campaign(_latest_generation_path(dir_single_invalid)),
		"fixture: 单代 payload 校验失败注入完成")
	_run_title_case(4, "RECOVERY_FAILED", dir_single_invalid, [],
		{"status": "RECOVERY_FAILED", "continue_disabled": true, "label_contains": "所有存档代次均无法恢复"},
		"4: 唯一代次无效 → RECOVERY_FAILED，继续游戏禁用")
	for gen in _campaign_files(dir_all_invalid):
		_corrupt_file_plain(gen)
	_run_title_case(5, "RECOVERY_FAILED", dir_all_invalid, [],
		{"status": "RECOVERY_FAILED", "continue_disabled": true, "label_contains": "所有存档代次均无法恢复"},
		"5: 全部代次无效 → RECOVERY_FAILED，继续游戏禁用")

	# 6 FUTURE_SCHEMA_VERSION / 7 FUTURE_STORAGE_VERSION
	_check(_bump_payload_schema_version(_latest_generation_path(dir_future_schema)),
		"fixture: payload schema_version 提升到未来值（重算 payload 哈希）")
	_run_title_case(6, "FUTURE_VERSION", dir_future_schema, [],
		{"status": "FUTURE_VERSION", "continue_disabled": true, "label_contains": "该存档由更新版本创建"},
		"6: FUTURE_SCHEMA_VERSION → FUTURE_VERSION，继续游戏禁用")
	_check(_bump_storage_version(_latest_generation_path(dir_future_storage)),
		"fixture: envelope storage_version 提升到未来值")
	_run_title_case(7, "FUTURE_VERSION", dir_future_storage, [],
		{"status": "FUTURE_VERSION", "continue_disabled": true, "label_contains": "该存档由更新版本创建"},
		"7: FUTURE_STORAGE_VERSION → FUTURE_VERSION，继续游戏禁用")

	# 10+11 explicit new game over an existing campaign: title must not write,
	# the confirmed REGULAR boot creates exactly one new generation, old kept.
	var new_game_before := _hash_dir(dir_new_game)
	var title_worker := _worker("TITLE_NEWGAME", dir_new_game)
	_check(title_worker.passed, "10: 标题自身不写档；确认后 REGULAR 启动创建新代（不伪装恢复）")
	var new_game_after := _hash_dir(dir_new_game)
	var old_kept := true
	for path in new_game_before:
		if _hash_file(path) != new_game_before[path]:
			old_kept = false
	_check(
		old_kept and new_game_after.size() == new_game_before.size() + 1,
		"11: 旧 generation 文件逐字节保留且恰好新增 1 个最新代"
	)

	_write_summary(root_dir)
	_finish()


## Boots the real title scene in a cold subprocess and asserts the mapped
## status, button state, status copy and read-only file inventory.
func _run_title_case(case_id: int, status: String, dir: String, _extra: Array, expect: Dictionary, message: String) -> void:
	var before := _hash_dir(dir)
	var before_count := before.size()
	var worker := _worker("TITLE", dir)
	var facts := _load_facts(dir, "title")
	var after := _hash_dir(dir)
	var read_only := after.size() == before_count
	if read_only:
		for path in before:
			if _hash_file(path) != before[path]:
				read_only = false
	_check(worker.passed, message)
	_check(str(facts.get("status", "?")) == status, "%s → 预检状态=%s" % [message, status])
	_check(bool(facts.get("continue_disabled", true)) == bool(expect.get("continue_disabled", true)),
		"%s → 继续游戏禁用=%s" % [message, str(expect.get("continue_disabled", true))])
	_check(str(facts.get("label", "")).contains(str(expect.get("label_contains", ""))),
		"%s → 状态文案包含「%s」" % [message, str(expect.get("label_contains", ""))])
	_check(read_only, "%s → 预检前后文件清单与 SHA256 完全一致（只读）" % message)
	_check(not str(facts.get("details", "")).contains("/private/tmp"),
		"%s → 开发详情不暴露完整路径" % message)
	_case_log.append({
		"case": case_id,
		"status": status,
		"worker": worker["output"],
		"facts": facts,
		"files_before": before_count,
		"files_after": after.size(),
		"read_only": read_only,
	})
	print("STATUS_UI_CASE %s done" % status)


func _run_worker(mode: String) -> void:
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	var scene: Node
	if mode == "TITLE" or mode == "TITLE_NEWGAME":
		scene = TITLE_SCENE.instantiate()
	else:
		var identity: Node = root.get_node("/root/RuntimeIdentity")
		identity.request_campaign_start(RUNTIME_IDENTITY.CAMPAIGN_START_REGULAR)
		scene = CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var passed := false
	match mode:
		"PRODUCE1":
			passed = true
		"PRODUCE":
			passed = _stage_produce(scene, false)
		"PRODUCE2":
			passed = _stage_produce(scene, true)
		"TITLE":
			passed = _stage_title(scene, save_directory)
		"TITLE_NEWGAME":
			passed = await _stage_title_newgame(scene, save_directory)
		_:
			push_error("Unknown recovery-ui stage: %s" % mode)
	scene.queue_free()
	await process_frame
	_write_marker(save_directory, mode, passed)
	quit(0 if passed else 1)


func _stage_produce(scene: Node, advance_once: bool) -> bool:
	var city: Node = scene.get_node_or_null("ConstructionController")
	if city == null:
		return false
	city.set_process(false)
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		return false
	if advance_once:
		runtime.call("advance", 4.0)
	return scene.flush_runtime_persistence(&"recovery_ui_fixture")


func _stage_title(scene: Node, save_directory: String) -> bool:
	# _ready already ran the read-only precheck. Freeze nothing; the title is
	# static. Read the mapped state.
	var status := str(scene.get("recovery_status"))
	var details := str(scene.get("recovery_details"))
	var label := str(scene.get("status_label").text)
	var continue_disabled := bool(scene.get("enter_city_button").disabled)
	var facts := {
		"status": status,
		"details": details,
		"label": label,
		"continue_disabled": continue_disabled,
		"button_text": str(scene.get("enter_city_button").text),
		"dev_details_has_generation": details.contains("RecoveryUsableGeneration"),
	}
	_store_facts(save_directory, "title", facts)
	print("RECOVERY_UI_TITLE status=%s disabled=%s label=%s details=%s" % [
		status, str(continue_disabled), label, details.replace("\n", " | "),
	])
	return (
		facts["dev_details_has_generation"]
		and not details.contains("/private/tmp")
	)


func _stage_title_newgame(scene: Node, save_directory: String) -> bool:
	var before := _campaign_files(save_directory)
	var facts_before := _hash_dir(save_directory)
	# The confirmation dialog must carry the corrected copy.
	var confirmation: ConfirmationDialog = scene.get("_regular_campaign_confirmation")
	var copy_ok := str(confirmation.dialog_text).contains("将默认进入新进度")
	var copy_no_old_claim := not str(confirmation.dialog_text).contains("不会加载")
	# Confirm the REGULAR new game exactly like the button flow does. The title
	# itself must not write anything; the subsequent city boot creates the gen.
	scene.set("_city_transition_requested", false)
	scene.call("_on_regular_campaign_confirmed")
	await process_frame
	await process_frame
	await process_frame
	var city: Node = root.get_node_or_null("BlankMap")
	if city == null:
		for child in root.get_children():
			if child.get_node_or_null("ConstructionController") != null:
				city = child
				break
	var city_controller: Node = city.get_node_or_null("ConstructionController") if city != null else null
	if city_controller == null:
		return false
	city_controller.set_process(false)
	await process_frame
	var runtime: Object = city_controller.get("_regular_campaign") as Object
	var fresh_campaign := runtime != null and bool(runtime.call("enabled"))
	var after := _hash_dir(save_directory)
	var old_kept := true
	for path in facts_before:
		if _hash_file(path) != facts_before[path]:
			old_kept = false
	var facts := {
		"copy_ok": copy_ok,
		"copy_no_old_claim": copy_no_old_claim,
		"title_wrote_nothing": old_kept and after.size() == facts_before.size(),
		"fresh_campaign": fresh_campaign,
		"new_generation_count": after.size(),
	}
	_store_facts(save_directory, "title", facts)
	print("RECOVERY_UI_NEWGAME copy=%s no_old_claim=%s title_wrote=%s fresh=%s gens=%d->%d" % [
		str(copy_ok), str(copy_no_old_claim),
		str(old_kept and after.size() == facts_before.size()),
		str(fresh_campaign), facts_before.size(), after.size(),
	])
	return (
		copy_ok and copy_no_old_claim
		and old_kept
		and after.size() == facts_before.size() + 1
		and fresh_campaign
	)


func _campaign_files(dir: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return result
	var directory := DirAccess.open(dir)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name.begins_with("campaign_") and name.ends_with(".json"):
			result.append(dir + "/" + name)
		name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func _hash_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<missing>"
	return FileAccess.get_file_as_string(path).sha256_text()


func _hash_dir(dir: String) -> Dictionary:
	var result := {}
	for path in _campaign_files(dir):
		result[path] = _hash_file(path)
	return result


func _latest_generation_path(dir: String) -> String:
	var files := _campaign_files(dir)
	return files[files.size() - 1] if not files.is_empty() else ""


func _corrupt_file_plain(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("{\"corrupted_by_test\":")
		file.flush()
		file.close()


## Keeps outer envelope/hashes consistent so decode reaches the domain
## validator, which must reject the corrupted attempt_sequence type.
func _surgically_invalidate_regular_campaign(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and Dictionary(parsed).has("payload_json"):
		var storage: Dictionary = parsed
		var payload := String(storage["payload_json"])
		var marker := "[\"attempt_sequence\","
		var start := payload.find(marker)
		if start < 0:
			return false
		var end := payload.find("]", start)
		if end < 0:
			return false
		storage["payload_json"] = (
			payload.substr(0, start)
			+ marker + "\"failsafe_corrupt\"]"
			+ payload.substr(end + 1)
		)
		storage["payload_sha256"] = String(storage["payload_json"]).sha256_text()
		return _store_json(path, storage)
	return false


## Keeps outer envelope/hashes consistent so decode reaches the domain
## validator, which must reject the future schema version.
func _bump_payload_schema_version(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and Dictionary(parsed).has("payload_json"):
		var storage: Dictionary = parsed
		var payload := String(storage["payload_json"])
		var current_schema := V5CampaignSnapshot.SCHEMA_VERSION
		var marker := "[\"schema_version\",%d]" % current_schema
		if not payload.contains(marker):
			return false
		storage["payload_json"] = payload.replace(
			marker,
			"[\"schema_version\",%d]" % (current_schema + 1)
		)
		storage["payload_sha256"] = String(storage["payload_json"]).sha256_text()
		return _store_json(path, storage)
	return false


## Future storage envelope version: codec must refuse with
## FUTURE_STORAGE_VERSION before any payload work.
func _bump_storage_version(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and Dictionary(parsed).has("storage_version"):
		var storage: Dictionary = parsed
		storage["storage_version"] = int(storage["storage_version"]) + 1
		return _store_json(path, storage)
	return false


func _store_json(path: String, storage: Dictionary) -> bool:
	# JSON.parse yields floats for integer literals; the canonical envelope
	# re-serialization must keep storage_version/save_sequence as integers.
	if storage.has("save_sequence"):
		storage["save_sequence"] = int(storage["save_sequence"])
	if storage.has("storage_version"):
		storage["storage_version"] = int(storage["storage_version"])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(storage, "", true, true))
	file.flush()
	file.close()
	return true


func _store_facts(save_directory: String, suffix: String, facts: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var file := FileAccess.open(save_directory.path_join("recovery_ui_%s.facts" % suffix), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(facts))


func _load_facts(save_directory: String, suffix: String) -> Dictionary:
	var path := save_directory.path_join("recovery_ui_%s.facts" % suffix)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("recovery_ui_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("RECOVERY_UI_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path("res://tests/verify_recovery_status_ui_r1.gd"), "--",
			"--mode=%s" % mode,
			"--txwzs-require-isolated-save",
			"--txwzs-v5-save-dir=%s" % save_directory,
		]),
		output,
		true
	)
	var marker_path := save_directory.path_join("recovery_ui_%s.result" % mode.to_lower())
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {
		"mode": mode,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"passed": exit_code == 0 and marker == "RECOVERY_UI_%s PASS" % mode,
	}


func _write_summary(root_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(DELIVERY_DIR)
	var payload := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"isolated_root": root_dir,
		"all_passed": failures.is_empty(),
		"cases": _case_log,
	}
	var file := FileAccess.open(DELIVERY_DIR + "/recovery_status_summary.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		file.close()
	print("RECOVERY_UI_SUMMARY_WRITTEN %s/recovery_status_summary.json" % DELIVERY_DIR)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("RECOVERY_UI FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("RECOVERY_STATUS_UI_R1 PASS")
		quit(0)
		return
	for failure in failures:
		push_error("RECOVERY_STATUS_UI_R1 FAIL: %s" % failure)
	quit(1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
