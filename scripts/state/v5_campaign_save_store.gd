class_name V5CampaignSaveStore
extends RefCounted


const DEFAULT_DIRECTORY := "user://saves/v5_campaign/blackstone_city"
const GENERATION_PREFIX := "campaign_"
const GENERATION_SUFFIX := ".json"
const GENERATION_DIGITS := 12
const WRITER_LOCK_DIRECTORY := ".writer_lock_v5"

var directory_path: String


func _init(custom_directory_path := DEFAULT_DIRECTORY) -> void:
	directory_path = str(custom_directory_path).trim_suffix("/")


func save_snapshot(
	snapshot: Dictionary,
	validator: Callable,
	fault: Dictionary = {}
) -> Dictionary:
	if not validator.is_valid():
		return _failure(&"INVALID_VALIDATOR", "快照校验入口无效")
	var preflight = validator.call(snapshot.duplicate(true))
	if (
		typeof(preflight) != TYPE_DICTIONARY
		or not bool(preflight.get("valid", false))
	):
		return _failure(&"INVALID_SNAPSHOT", "V2 保存预检失败")
	var directory_result := _ensure_directory()
	if not bool(directory_result.success):
		return directory_result
	var lock_result := _acquire_writer_lock()
	if not bool(lock_result.success):
		return lock_result
	var result := _save_locked(
		Dictionary(preflight.snapshot).duplicate(true),
		validator,
		fault
	)
	var release_result := _release_writer_lock()
	if not bool(release_result.success):
		result["lock_release_warning"] = str(release_result.error)
	return result


func _save_locked(
	snapshot: Dictionary,
	validator: Callable,
	fault: Dictionary
) -> Dictionary:
	var sequence_result := _list_sequences()
	if not bool(sequence_result.success):
		return sequence_result
	var save_sequence := 1
	for sequence in sequence_result.sequences:
		save_sequence = maxi(save_sequence, int(sequence) + 1)
	var encoded := V5CampaignSaveCodec.encode_snapshot(
		snapshot,
		save_sequence,
		validator
	)
	if not bool(encoded.success):
		return encoded
	var final_path := get_generation_path(save_sequence)
	var temp_path := "%s/.pending_%012d_%d.tmp" % [
		directory_path,
		save_sequence,
		OS.get_process_id(),
	]
	if _path_exists(final_path) or _path_exists(temp_path):
		return _failure(&"TARGET_EXISTS", "目标或临时代次已存在")
	if bool(fault.get("write_failed", false)):
		return _failure(&"WRITE_FAILED", "注入写入失败")
	var write_result := _write_and_flush(temp_path, str(encoded.storage_text))
	if not bool(write_result.success):
		return write_result
	if bool(fault.get("corrupt_temp", false)):
		var corrupt := FileAccess.open(temp_path, FileAccess.WRITE)
		if corrupt != null:
			corrupt.store_string("{\"corrupt\":")
			corrupt.flush()
			corrupt.close()
	var reread := _read_and_decode(temp_path, validator, save_sequence)
	if not bool(reread.success):
		_remove_file_best_effort(temp_path)
		return _failure(&"REREAD_FAILED", "临时代次复读失败")
	if bool(fault.get("publish_failed", false)):
		_remove_file_best_effort(temp_path)
		return _failure(&"PUBLISH_FAILED", "注入发布失败")
	if _path_exists(final_path):
		_remove_file_best_effort(temp_path)
		return _failure(&"TARGET_EXISTS", "发布前目标代次已存在")
	var rename_error := DirAccess.rename_absolute(
		_globalize(temp_path),
		_globalize(final_path)
	)
	if rename_error != OK:
		_remove_file_best_effort(temp_path)
		return _failure(&"PUBLISH_FAILED", "代次原子发布失败")
	if bool(fault.get("corrupt_final", false)):
		var corrupt_final := FileAccess.open(final_path, FileAccess.WRITE)
		if corrupt_final != null:
			corrupt_final.store_string("{\"corrupt_final\":")
			corrupt_final.flush()
			corrupt_final.close()
	var final_read := _read_and_decode(
		final_path,
		validator,
		save_sequence
	)
	if not bool(final_read.success):
		return _failure(
			&"FINAL_REREAD_FAILED",
			"新代次已发布但最终复读失败；旧代次仍保留"
		)
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"status": "saved",
		"save_sequence": save_sequence,
		"path": final_path,
		"snapshot": final_read.snapshot.duplicate(true),
	}


func load_latest(validator: Callable) -> Dictionary:
	if not validator.is_valid():
		return _failure(&"INVALID_VALIDATOR", "快照校验入口无效")
	if not DirAccess.dir_exists_absolute(_globalize(directory_path)):
		return _failure(&"NOT_FOUND", "没有 V5 存档")
	var sequence_result := _list_sequences()
	if not bool(sequence_result.success):
		return sequence_result
	var sequences: Array = sequence_result.sequences
	if sequences.is_empty():
		return _failure(&"NOT_FOUND", "没有 V5 存档")
	sequences.sort()
	var invalid: Array[Dictionary] = []
	for index in range(sequences.size() - 1, -1, -1):
		var sequence := int(sequences[index])
		var decoded := _read_and_decode(
			get_generation_path(sequence),
			validator,
			sequence
		)
		if bool(decoded.success):
			return {
				"success": true,
				"error_id": &"",
				"error": "",
				"status": (
					"recovered_previous_generation"
					if not invalid.is_empty()
					else "loaded_latest"
				),
				"save_sequence": sequence,
				"recovered": not invalid.is_empty(),
				"invalid_generations": invalid.duplicate(true),
				"snapshot": decoded.snapshot.duplicate(true),
			}
		if StringName(decoded.error_id) in [
			&"FUTURE_STORAGE_VERSION",
			&"FUTURE_SCHEMA_VERSION",
		]:
			return _failure(
				StringName(decoded.error_id),
				"最新代次来自未来版本，拒绝降级跳过"
			)
		invalid.append({
			"save_sequence": sequence,
			"error_id": decoded.error_id,
			"error": decoded.error,
		})
	return _failure(&"ALL_INVALID", "全部 V5 存档代次无效")


## Title/menu code may inspect availability, but only the runtime coordinator
## loads or writes the canonical campaign.
func has_any_generation() -> bool:
	var sequences := _list_sequences()
	return bool(sequences.get("success", false)) and not Array(sequences.get("sequences", [])).is_empty()


func load_and_restore(controller: Node) -> Dictionary:
	var loaded := load_latest(
		Callable(controller, "validate_v5_campaign_snapshot")
	)
	if not bool(loaded.success):
		return loaded
	var restore: Dictionary = controller.restore_v5_campaign_snapshot(
		loaded.snapshot.duplicate(true)
	)
	if not bool(restore.get("success", false)):
		return {
			"success": false,
			"error_id": &"APPLY_FAILED",
			"error": str(restore.get("error", "V5 apply failed")),
			"status": "apply_failed",
			"save_sequence": loaded.save_sequence,
		}
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"status": loaded.status,
		"save_sequence": loaded.save_sequence,
		"recovered": loaded.recovered,
		"snapshot": loaded.snapshot.duplicate(true),
	}


func get_generation_path(save_sequence: int) -> String:
	return "%s/%s%0*d%s" % [
		directory_path,
		GENERATION_PREFIX,
		GENERATION_DIGITS,
		save_sequence,
		GENERATION_SUFFIX,
	]


func get_writer_lock_path() -> String:
	return "%s/%s" % [directory_path, WRITER_LOCK_DIRECTORY]


func _read_and_decode(
	path: String,
	validator: Callable,
	expected_sequence: int
) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(&"READ_FAILED", "无法读取存档代次")
	var text := file.get_as_text()
	file.close()
	var decoded := V5CampaignSaveCodec.decode_storage_text(
		text,
		validator
	)
	if not bool(decoded.success):
		return decoded
	if int(decoded.save_sequence) != expected_sequence:
		return _failure(&"SEQUENCE_MISMATCH", "文件名与内容代次不一致")
	return decoded


func _write_and_flush(path: String, text: String) -> Dictionary:
	if _path_exists(path):
		return _failure(&"TARGET_EXISTS", "临时文件已存在")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure(&"WRITE_FAILED", "无法创建临时文件")
	file.store_string(text)
	if file.get_error() != OK:
		file.close()
		return _failure(&"WRITE_FAILED", "临时文件写入失败")
	file.flush()
	var flush_error := file.get_error()
	file.close()
	if flush_error != OK:
		return _failure(&"FLUSH_FAILED", "临时文件 flush 失败")
	return {"success": true}


func _ensure_directory() -> Dictionary:
	var global := _globalize(directory_path)
	if DirAccess.dir_exists_absolute(global):
		return {"success": true}
	if DirAccess.make_dir_recursive_absolute(global) != OK:
		return _failure(&"DIRECTORY_FAILED", "无法创建存档目录")
	return {"success": true}


func _acquire_writer_lock() -> Dictionary:
	var error := DirAccess.make_dir_absolute(
		_globalize(get_writer_lock_path())
	)
	if error != OK:
		return _failure(&"WRITER_LOCKED", "V5 writer lock 已被占用")
	return {"success": true}


func _release_writer_lock() -> Dictionary:
	var error := DirAccess.remove_absolute(
		_globalize(get_writer_lock_path())
	)
	if error != OK:
		return _failure(&"LOCK_RELEASE_FAILED", "writer lock 释放失败")
	return {"success": true}


func _list_sequences() -> Dictionary:
	var global := _globalize(directory_path)
	if not DirAccess.dir_exists_absolute(global):
		return {"success": true, "sequences": []}
	var directory := DirAccess.open(global)
	if directory == null:
		return _failure(&"DIRECTORY_FAILED", "无法列出存档目录")
	var sequences: Array[int] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		var sequence := _parse_sequence(file_name)
		if sequence > 0:
			sequences.append(sequence)
		file_name = directory.get_next()
	directory.list_dir_end()
	return {"success": true, "sequences": sequences}


func _parse_sequence(file_name: String) -> int:
	if (
		not file_name.begins_with(GENERATION_PREFIX)
		or not file_name.ends_with(GENERATION_SUFFIX)
	):
		return 0
	var digits := file_name.trim_prefix(
		GENERATION_PREFIX
	).trim_suffix(GENERATION_SUFFIX)
	if digits.length() != GENERATION_DIGITS or not digits.is_valid_int():
		return 0
	return int(digits)


func _path_exists(path: String) -> bool:
	var global := _globalize(path)
	return (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(global)
		or DirAccess.dir_exists_absolute(global)
	)


func _remove_file_best_effort(path: String) -> void:
	if FileAccess.file_exists(path) or FileAccess.file_exists(_globalize(path)):
		DirAccess.remove_absolute(_globalize(path))


func _globalize(path: String) -> String:
	return ProjectSettings.globalize_path(path)


static func _failure(error_id: StringName, error: String) -> Dictionary:
	return {
		"success": false,
		"error_id": error_id,
		"error": error,
	}
