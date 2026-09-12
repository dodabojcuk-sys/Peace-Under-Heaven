class_name RuntimeCampaignPersistenceCoordinator
extends Node


const SAVE_STORE = preload("res://scripts/state/v5_campaign_save_store.gd")
const SAVE_DIRECTORY_ARGUMENT_PREFIX := "--txwzs-v5-save-dir="
const DIRTY_FLUSH_DELAY_SECONDS := 0.5

var _controller: Node
var _store: V5CampaignSaveStore
var _dirty_flush_timer: Timer
var _is_initialized := false
var _is_flushing := false
var _dirty := false
var _writes_blocked := false
var _status := {
	"status": "uninitialized",
	"loaded": false,
	"recovered": false,
	"save_sequence": 0,
	"save_directory": "",
	"error_id": &"",
	"error": "",
}


func initialize(controller: Node) -> Dictionary:
	if _is_initialized:
		return get_status()
	_controller = controller
	var configured_directory := _configured_save_directory()
	# Existing headless runners instantiate the real scene for gameplay checks.
	# They must never read or create a player's default user:// generation; the
	# dedicated lifecycle runner supplies an explicit isolated directory.
	if DisplayServer.get_name() == "headless" and configured_directory.is_empty():
		_writes_blocked = true
		_is_initialized = true
		_status = {
			"status": "disabled_headless_without_isolated_store",
			"loaded": false,
			"recovered": false,
			"save_sequence": 0,
			"save_directory": "",
			"error_id": &"HEADLESS_STORE_NOT_CONFIGURED",
			"error": "headless runtime persistence requires --txwzs-v5-save-dir",
		}
		return get_status()
	_store = SAVE_STORE.new(
		configured_directory if not configured_directory.is_empty() else V5CampaignSaveStore.DEFAULT_DIRECTORY
	)
	_status.save_directory = _store.directory_path
	var loaded := _store.load_and_restore(_controller)
	if bool(loaded.get("success", false)):
		_status = {
			"status": str(loaded.get("status", "loaded_latest")),
			"loaded": true,
			"recovered": bool(loaded.get("recovered", false)),
			"save_sequence": int(loaded.get("save_sequence", 0)),
			"save_directory": _store.directory_path,
			"error_id": &"",
			"error": "",
		}
	elif StringName(loaded.get("error_id", &"")) == &"NOT_FOUND":
		_status.status = "creating_initial_generation"
		if not flush_now(&"initial_city_created"):
			_status.status = "initial_generation_failed"
	else:
		# A corrupt or future save is never silently replaced with the controller's
		# default state. The V5 store has already tried whole-generation fallback.
		_writes_blocked = true
		_status = {
			"status": "load_blocked",
			"loaded": false,
			"recovered": false,
			"save_sequence": int(loaded.get("save_sequence", 0)),
			"save_directory": _store.directory_path,
			"error_id": StringName(loaded.get("error_id", &"UNKNOWN")),
			"error": str(loaded.get("error", "V5 campaign load failed")),
		}
		push_error(
			"V5 runtime persistence blocked: %s (%s)"
			% [_status.error_id, _status.error]
		)
	_is_initialized = true
	_connect_controller()
	return get_status()


func get_status() -> Dictionary:
	var result: Dictionary = _status.duplicate(true)
	result["dirty"] = _dirty
	result["writes_blocked"] = _writes_blocked
	return result


func flush_now(reason: StringName = &"explicit") -> bool:
	if _is_flushing or _writes_blocked or _controller == null or _store == null:
		return false
	_is_flushing = true
	var snapshot: Dictionary = _controller.export_v5_campaign_snapshot()
	if snapshot.is_empty():
		_is_flushing = false
		_record_save_failure(&"EMPTY_SNAPSHOT", "canonical CampaignSnapshot export failed")
		return false
	var saved := _store.save_snapshot(
		snapshot,
		Callable(_controller, "validate_v5_campaign_snapshot")
	)
	_is_flushing = false
	if not bool(saved.get("success", false)):
		_record_save_failure(
			StringName(saved.get("error_id", &"SAVE_FAILED")),
			str(saved.get("error", "V5 generation save failed"))
		)
		return false
	_dirty = false
	_status = {
		"status": (
			"created_initial_generation"
			if reason == &"initial_city_created"
			else "saved"
		),
		"loaded": bool(_status.get("loaded", false)),
		"recovered": bool(_status.get("recovered", false)),
		"save_sequence": int(saved.save_sequence),
		"save_directory": _store.directory_path,
		"error_id": &"",
		"error": "",
	}
	return true


func flush_on_normal_exit() -> bool:
	if _writes_blocked:
		return false
	return flush_now(&"normal_exit") if _dirty else true


func persist_expedition_departure(attempt_id: StringName) -> Dictionary:
	return _persist_expedition_checkpoint(
		attempt_id,
		&"",
		&"expedition_departure"
	)


func persist_expedition_battle_checkpoint(attempt_id: StringName) -> Dictionary:
	return _persist_expedition_checkpoint(
		attempt_id,
		&"",
		&"expedition_battle_checkpoint"
	)


func persist_expedition_settlement(
	attempt_id: StringName,
	result_id: StringName
) -> Dictionary:
	if result_id == &"":
		return {"success": false, "uncertain": false}
	return _persist_expedition_checkpoint(
		attempt_id,
		result_id,
		&"expedition_settlement"
	)


func persist_macro_march_checkpoint() -> Dictionary:
	# Macro marching has no battle result ledger. Its canonical ArmyRegistry
	# snapshot is the checkpoint, and ordinary headless scene tests retain the
	# existing opt-out unless they explicitly configure an isolated store.
	if (
		_writes_blocked
		and StringName(_status.get("error_id", &""))
			== &"HEADLESS_STORE_NOT_CONFIGURED"
	):
		return {
			"success": true,
			"uncertain": false,
			"headless_test_store_disabled": true,
		}
	if flush_now(&"macro_march_checkpoint"):
		return {"success": true, "uncertain": false}
	# V5 save publication may have reached disk before the store's final reread
	# failed. Reuse the existing latest-generation validation path so callers do
	# not roll back a durable enemy-city arrival and later create a duplicate
	# siege/order on restart.
	if (
		_store != null
		and _controller != null
		and StringName(_status.get("error_id", &"")) == &"FINAL_REREAD_FAILED"
	):
		var expected: Dictionary = _controller.export_v5_campaign_snapshot()
		var loaded := _store.load_latest(
			Callable(_controller, "validate_v5_campaign_snapshot")
		)
		if bool(loaded.get("success", false)) and Dictionary(loaded.get("snapshot", {})) == expected:
			return {"success": true, "uncertain": false, "recovered_after_final_reread": true}
	return {"success": false, "uncertain": false}


func _persist_expedition_checkpoint(
	attempt_id: StringName,
	result_id: StringName,
	reason: StringName
) -> Dictionary:
	if attempt_id == &"":
		return {"success": false, "uncertain": false}
	if (
		_writes_blocked
		and StringName(_status.get("error_id", &""))
			== &"HEADLESS_STORE_NOT_CONFIGURED"
	):
		return {
			"success": true,
			"uncertain": false,
			"headless_test_store_disabled": true,
		}
	if flush_now(reason):
		return {"success": true, "uncertain": false}
	if _store == null or _controller == null:
		return {"success": false, "uncertain": false}
	var published_may_be_uncertain := (
		StringName(_status.get("error_id", &"")) == &"FINAL_REREAD_FAILED"
	)
	if not published_may_be_uncertain:
		return {"success": false, "uncertain": false}
	var loaded := _store.load_latest(
		Callable(_controller, "validate_v5_campaign_snapshot")
	)
	if not bool(loaded.get("success", false)):
		return {"success": false, "uncertain": true}
	var persisted_attempt: Dictionary = Dictionary(
		loaded.snapshot
	).get("expedition_attempt", {})
	var expected_attempt: Dictionary = (
		_controller.get_expedition_attempt()
		if _controller.has_method("get_expedition_attempt")
		else {}
	)
	if (
		StringName(persisted_attempt.get("attempt_id", &"")) == attempt_id
		and not expected_attempt.is_empty()
		and persisted_attempt == expected_attempt
		and (
			result_id == &""
			or (
				bool(persisted_attempt.get("settled", false))
				and StringName(persisted_attempt.get("result_id", &""))
					== result_id
				and Dictionary(
					Dictionary(loaded.snapshot).get(
						"settlement_ledger", {}
					).get("committed_results_by_id", {})
				).has(result_id)
			)
		)
	):
		_dirty = false
		_status.status = "saved_after_generation_verification"
		_status.error_id = &""
		_status.error = ""
		_status.save_sequence = int(loaded.save_sequence)
		return {
			"success": true,
			"uncertain": false,
			"verified_after_publish_warning": true,
		}
	return {"success": false, "uncertain": false}


func _connect_controller() -> void:
	if _controller == null or not _controller.has_signal("city_state_changed"):
		return
	var state_changed := Callable(self, "_on_canonical_state_changed")
	if not _controller.city_state_changed.is_connected(state_changed):
		_controller.city_state_changed.connect(state_changed)
	_dirty_flush_timer = Timer.new()
	_dirty_flush_timer.one_shot = true
	_dirty_flush_timer.wait_time = DIRTY_FLUSH_DELAY_SECONDS
	_dirty_flush_timer.timeout.connect(_on_dirty_flush_timeout)
	add_child(_dirty_flush_timer)


func _on_canonical_state_changed() -> void:
	if not _is_initialized or _writes_blocked:
		return
	_dirty = true
	if _dirty_flush_timer != null and _dirty_flush_timer.is_inside_tree():
		_dirty_flush_timer.start()


func _on_dirty_flush_timeout() -> void:
	if _dirty:
		flush_now(&"canonical_state_dirty")


func _record_save_failure(error_id: StringName, error: String) -> void:
	_status.error_id = error_id
	_status.error = error
	_status.status = "save_failed"
	push_error("V5 runtime persistence save failed: %s (%s)" % [error_id, error])


func _configured_save_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(SAVE_DIRECTORY_ARGUMENT_PREFIX):
			var configured := argument.trim_prefix(SAVE_DIRECTORY_ARGUMENT_PREFIX)
			if not configured.is_empty():
				return configured
	return ""
