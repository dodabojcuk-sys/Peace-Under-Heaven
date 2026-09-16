extends SceneTree

## R1C 热修复短测：存档目录解析与实际使用一致性。
## 每个情形由矩阵脚本以独立进程运行并传入期望；本脚本只读 RuntimeIdentity
## 的统一解析与 V5CampaignSaveStore，不接触真实玩家档、备份或旧快照。

const RUNTIME_IDENTITY := preload("res://scripts/runtime_identity.gd")
const SAVE_STORE := preload("res://scripts/state/v5_campaign_save_store.gd")

var failures: Array[String] = []
var case_id := ""
var save_dir := ""
var expect_dir := ""
var expect_rejected := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case_id = arg.trim_prefix("--case=")
		elif arg.begins_with("--save-dir="):
			save_dir = arg.trim_prefix("--save-dir=")
		elif arg.begins_with("--expect-dir="):
			expect_dir = arg.trim_prefix("--expect-dir=")
		elif arg == "--expect-rejected":
			expect_rejected = true
	if expect_dir.is_empty():
		expect_dir = save_dir

	# --script 模式下无 autoload：直接实例化 RuntimeIdentity（不进树，不触发门禁
	# quit；门禁进程级行为由矩阵 bash 层以真实退出码覆盖）。
	var identity: Node = RUNTIME_IDENTITY.new()

	# 统一解析结果与 getter（两者必须一致）
	var resolved: Dictionary = identity._resolve_save_directory_args()
	var getter_dir: String = identity.get_campaign_save_directory_override()
	var rejected: bool = identity.is_save_gate_rejected()
	var resolved_dir: String = str(resolved.get("normalized", ""))
	var store_dir: String = ""

	print("ACTUAL resolved=", resolved_dir, " getter=", getter_dir, " rejected=", rejected, " error=", str(resolved.get("error", "")))
	print("EXPECT case=", case_id, " expect_dir=", expect_dir, " expect_rejected=", expect_rejected)

	if expect_rejected:
		_expect(rejected, "解析结果为拒绝态")
		_expect(getter_dir.is_empty(), "拒绝态 getter 返回空串（不回退默认档）")
		_finish(rejected)
		return

	_expect(not rejected, "合法路径不被拒绝")
	_expect(not resolved_dir.is_empty(), "解析目录非空")
	_expect(getter_dir == resolved_dir, "getter 与解析目录一致")

	match case_id:
		"none":
			_expect(getter_dir.is_empty(), "无参数时 getter 为空（默认语义）")
			_finish(true)
			return
		"plain":
			var expected_resolved: String = expect_dir
			if expected_resolved.begins_with("/tmp/"):
				expected_resolved = "/private" + expected_resolved
			print("PLAIN_CMP getter_len=", getter_dir.length(), " expected_len=", expected_resolved.length(), " equal=", getter_dir == expected_resolved)
			_expect(getter_dir == expected_resolved, "普通显式覆盖由 getter 保留（能力不丢失）")
			_finish(true)
			return
		"isolated":
			print("STEP-isolated entering store write/read")
		_:
			push_error("未知 case：" + case_id)
			quit(2)
			return

	# ---- require/isolated：实际走存档服务做最小写入与读取 ----
	var store: V5CampaignSaveStore = SAVE_STORE.new(getter_dir)
	store_dir = store.directory_path
	print("STORE_DIR=", store_dir)

	print("PATHS specified=", expect_dir, " resolved=", resolved_dir, " getter=", getter_dir, " store=", store_dir)
	_expect(resolved_dir == getter_dir and getter_dir == store_dir, "指定/解析/getter/存档服务四路径一致（规范化后）")
	_expect(not store_dir.is_empty(), "存档服务目录非空")

	var snapshot := {
		"version": 1,
		"note": "save-path-resolution hotfix minimal write",
		"sequence_probe": 1,
	}
	var write_result: Dictionary = store.save_snapshot(
		snapshot,
		func(_validated: Variant) -> Dictionary:
			return {"valid": true, "snapshot": _validated},
		{}
	)
	_expect(bool(write_result.get("success", false)), "最小写入成功（store.save_snapshot success）")

	_expect(store.has_any_generation(), "写后目录出现有效 generation")
	var generation_files: PackedStringArray = DirAccess.get_files_at(store_dir)
	var read_back_text := ""
	for generation_file in generation_files:
		if generation_file.begins_with("campaign_") and generation_file.ends_with(".json"):
			var file := FileAccess.open(store_dir.path_join(generation_file), FileAccess.READ)
			if file != null:
				read_back_text = file.get_as_text()
			break
	_expect(not read_back_text.is_empty(), "最小读取：写出的 generation 可读回且非空")

	_finish(true)


func _padded(value: int) -> String:
	return "%012d" % value


func _finish(ok: bool) -> void:
	print("R1C_SAVE_PATH case=", case_id, " ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	quit(0 if ok and failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)
