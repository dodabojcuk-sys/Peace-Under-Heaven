extends SceneTree


const RUNTIME_IDENTITY_SCRIPT := preload("res://scripts/runtime_identity.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_clean_city_identity()
	_test_dirty_city_identity()
	_test_battle_identity()
	_test_unidentified_identity()
	_test_release_title()
	call_deferred("_finish")


func _test_clean_city_identity() -> void:
	var identity: Dictionary = RUNTIME_IDENTITY_SCRIPT.parse_identity(
		_identified_args("CITY", "main", "abcdef1", "0"),
		"CITY"
	)
	_expect(bool(identity.identified), "clean CITY arguments are identified")
	_expect(
		RUNTIME_IDENTITY_SCRIPT.build_window_title(identity, true)
			== "天下无战事 · CITY · main@abcdef1 · DEBUG",
		"clean CITY title contains branch and commit"
	)


func _test_dirty_city_identity() -> void:
	var identity: Dictionary = RUNTIME_IDENTITY_SCRIPT.parse_identity(
		_identified_args("CITY", "feature/test", "1234abc", "1"),
		"CITY"
	)
	_expect(bool(identity.identified), "dirty CITY arguments are identified")
	_expect(
		RUNTIME_IDENTITY_SCRIPT.build_window_title(identity, true)
			== (
				"天下无战事 · CITY · feature/test@1234abc"
				+ " · DEBUG · DIRTY"
			),
		"dirty CITY title is explicit"
	)


func _test_battle_identity() -> void:
	var identity: Dictionary = RUNTIME_IDENTITY_SCRIPT.parse_identity(
		_identified_args("BATTLE-C0", "main", "7654321", "0"),
		"BATTLE-C0"
	)
	_expect(bool(identity.identified), "BATTLE-C0 arguments are identified")
	_expect(
		RUNTIME_IDENTITY_SCRIPT.build_window_title(identity, true)
			== "天下无战事 · BATTLE-C0 · main@7654321 · DEBUG",
		"BATTLE-C0 title cannot be confused with CITY"
	)


func _test_unidentified_identity() -> void:
	var city_identity: Dictionary = RUNTIME_IDENTITY_SCRIPT.parse_identity(
		PackedStringArray(),
		"CITY"
	)
	_expect(
		not bool(city_identity.identified),
		"missing launcher arguments remain unidentified"
	)
	_expect(
		RUNTIME_IDENTITY_SCRIPT.build_window_title(city_identity, true)
			== "天下无战事 · CITY · DEBUG · UNIDENTIFIED",
		"direct CITY launch is visibly unidentified"
	)
	var battle_identity: Dictionary = RUNTIME_IDENTITY_SCRIPT.parse_identity(
		PackedStringArray(),
		"BATTLE-C0"
	)
	_expect(
		RUNTIME_IDENTITY_SCRIPT.build_window_title(battle_identity, true)
			== "天下无战事 · BATTLE-C0 · DEBUG · UNIDENTIFIED",
		"direct BATTLE-C0 launch remains distinguishable and unidentified"
	)


func _test_release_title() -> void:
	var identity: Dictionary = RUNTIME_IDENTITY_SCRIPT.parse_identity(
		_identified_args("CITY", "main", "abcdef1", "1"),
		"CITY"
	)
	_expect(
		RUNTIME_IDENTITY_SCRIPT.build_window_title(identity, false)
			== "天下无战事",
		"release title does not claim debug Git identity"
	)


func _identified_args(
	scene: String,
	branch: String,
	commit: String,
	dirty: String
) -> PackedStringArray:
	return PackedStringArray([
		"--txwzs-launcher=1",
		"--txwzs-scene=%s" % scene,
		"--txwzs-branch=%s" % branch,
		"--txwzs-commit=%s" % commit,
		"--txwzs-dirty=%s" % dirty,
		"--txwzs-launch-id=test-launch",
	])


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("RUNTIME_IDENTITY_SMOKE PASS")
		quit(0)
		return
	print("RUNTIME_IDENTITY_SMOKE FAIL (%d)" % failures.size())
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
