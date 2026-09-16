extends Node


const TITLE_BASE := "天下无战事"
const SCENE_CITY := "CITY"
const SCENE_BATTLE_C0 := "BATTLE-C0"
const SCENE_TITLE := "TITLE"
const KNOWN_SCENES := [SCENE_TITLE, SCENE_CITY, SCENE_BATTLE_C0]
const CAMPAIGN_START_CONTINUE := &"CONTINUE"
const CAMPAIGN_START_NEW := &"NEW"
## Ephemeral title-to-city routing only.  This flag is deliberately consumed
## before persistence starts and is never parsed from, or recorded in, a save.
const CAMPAIGN_START_REGULAR := &"REGULAR"
const SAVE_DIRECTORY_ARGUMENT_PREFIX := "--txwzs-v5-save-dir="
const CANDIDATE_VERSION_FORMAL_R1 := "FORMAL-CANDIDATE-R1"
const CANDIDATE_VERSION_REGULAR_R1 := "REGULAR-CAMPAIGN-R1"
const CANDIDATE_VERSION_REGULAR_R1A := "REGULAR-CAMPAIGN-R1A"

var current_identity: Dictionary = {}
var current_title := ""
var _pending_campaign_start_mode: StringName = CAMPAIGN_START_CONTINUE


func _ready() -> void:
	set_process(false)
	_apply_after_scene_ready()


func _apply_after_scene_ready() -> void:
	await get_tree().process_frame
	if not OS.is_debug_build():
		return
	var fallback_scene := _detect_current_scene_label()
	current_identity = parse_identity(
		OS.get_cmdline_user_args(),
		fallback_scene
	)
	current_title = build_window_title(current_identity, true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(current_title)
	print("TXWZS_RUNTIME_IDENTITY %s" % current_title)
	set_process(true)


func _process(_delta: float) -> void:
	var scene_label := _detect_current_scene_label()
	if scene_label == "UNKNOWN":
		return
	if scene_label == String(current_identity.get("scene", "UNKNOWN")):
		return
	current_identity.scene = scene_label
	current_title = build_window_title(current_identity, true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(current_title)
	print("TXWZS_RUNTIME_IDENTITY %s" % current_title)


func _detect_current_scene_label() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "UNKNOWN"
	var scene_path := String(scene.scene_file_path)
	if scene_path.ends_with("/title_shell.tscn"):
		return SCENE_TITLE
	if scene_path.ends_with("/blank_map.tscn"):
		var controller := scene.get_node_or_null("ConstructionController")
		if (
			controller != null
			and controller.has_method("get_formal_battle_scene")
			and controller.get_formal_battle_scene() != null
		):
			return SCENE_BATTLE_C0
		return SCENE_CITY
	if scene_path.ends_with("/c0_battle_graybox.tscn"):
		return SCENE_BATTLE_C0
	return "UNKNOWN"


func request_campaign_start(mode: StringName) -> bool:
	if mode not in [
		CAMPAIGN_START_CONTINUE,
		CAMPAIGN_START_NEW,
		CAMPAIGN_START_REGULAR,
	]:
		return false
	_pending_campaign_start_mode = mode
	return true


func consume_campaign_start_mode() -> StringName:
	var mode := _pending_campaign_start_mode
	_pending_campaign_start_mode = CAMPAIGN_START_CONTINUE
	return mode


func _resolve_save_directory_args() -> Dictionary:
	# R1C 热修复：隔离参数的唯一解析入口（启动门禁 / getter / 存档服务共用同一结果），
	# 杜绝"检查的目录"与"实际使用的目录"分别解析造成的不一致。
	var result := {
		"require": false,
		"override": "",
		"override_count": 0,
		"normalized": "",
		"resolved": "",
		"error": "",
	}
	for argument in OS.get_cmdline_user_args():
		if argument == "--txwzs-require-isolated-save":
			result.require = true
		elif argument.begins_with(SAVE_DIRECTORY_ARGUMENT_PREFIX):
			result.override_count += 1
			if result.override_count > 1:
				result.error = "存档目录参数重复出现"
				return result
			result.override = argument.trim_prefix(SAVE_DIRECTORY_ARGUMENT_PREFIX)
	# 门禁缺口修复：require 携带而缺 save-dir 时必须拒绝，
	# 否则隔离要求被静默忽略（反例矩阵"缺参"例退化为正常启动）。
	if result.require and result.override_count == 0:
		result.error = "缺少 --txwzs-v5-save-dir：隔离要求不能没有显式测试存档目录"
		return result
	# 未指定覆盖目录 = 普通默认启动语义（合法，跳过全部路径校验）。
	if result.override_count == 0:
		return result
	# 词法规范化：`.`、`..`、尾斜杠、双斜杠一律拒绝（传入必须是规范化绝对路径）。
	var normalized := _lexically_normalize_absolute_path(result.override)
	if result.override != normalized:
		result.error = "存档目录须使用规范化绝对路径（不得含 .、..、尾斜杠或双斜杠）"
		return result
	# macOS 系统别名：/tmp 是 /private/tmp 的映射，统一到真实目标（不误拒正常测试）。
	if normalized.begins_with("/tmp/"):
		normalized = "/private" + normalized
	result.normalized = normalized
	# 保护清单：默认玩家存档树、TXWZS_BACKUP、旧试玩快照。
	if _is_inside_protected_player_tree(normalized):
		result.error = "不允许指向玩家存档树、TXWZS_BACKUP 或旧试玩快照"
		return result
	if not normalized.begins_with("/private/tmp/txwzs-") and not normalized.begins_with("/tmp/txwzs-"):
		result.error = "测试存档目录必须位于核准区 /tmp/txwzs- 之下"
		return result
	# 逐级校验：文件型条目与符号链接（含目录链接）一律拒绝。
	var probe := ""
	for component in normalized.trim_prefix("/").split("/"):
		probe += "/" + component
		if FileAccess.file_exists(probe):
			result.error = "路径中间存在文件型条目：" + probe
			return result
		if DirAccess.dir_exists_absolute(probe):
			var probe_dir := DirAccess.open(probe.get_base_dir())
			if probe_dir != null and probe_dir.is_link(probe):
				result.error = "路径中间存在符号链接：" + probe
				return result
	# 解析成功：normalized 为别名解析后的真实目录。
	result.resolved = normalized
	return result


func get_campaign_save_directory_override() -> String:
	# R1C 热修复：与启动门禁共用唯一解析；成功返回别名解析后的目录（不再丢失）。
	var resolved := _resolve_save_directory_args()
	if not resolved.error.is_empty():
		return ""
	return resolved.normalized


func is_save_gate_rejected() -> bool:
	# R1C 热修复：供标题/存档服务在 quit() 延迟生效前主动拒绝默认回退。
	return not _resolve_save_directory_args().error.is_empty()


func _lexically_normalize_absolute_path(path: String) -> String:
	# 词法规范化绝对路径：解析 ""、"."、".." 组件与尾斜杠。
	var parts: PackedStringArray = []
	for component in path.split("/", false):
		if component == ".":
			continue
		if component == "..":
			if parts.is_empty():
				return ""
			parts.remove_at(parts.size() - 1)
			continue
		parts.append(component)
	return "/" + "/".join(parts)


func _is_inside_protected_player_tree(normalized: String) -> bool:
	var protected_roots: PackedStringArray = [
		ProjectSettings.globalize_path("user://"),
		ProjectSettings.globalize_path("user://saves"),
		"/Users/m4-zhi/Documents/TXWZS_BACKUP",
		"/Users/m4-zhi/Documents/TXWZS_SAVE_SNAPSHOT_PRE_PLAYTEST_20260915",
	]
	for root in protected_roots:
		var normalized_root := _lexically_normalize_absolute_path(root)
		if normalized_root.is_empty():
			continue
		if normalized == normalized_root or normalized.begins_with(normalized_root + "/"):
			return true
	return false


func _enter_tree() -> void:
	# R1C 测试隔离门禁：带此标志启动的实例（游戏或 runner）必须在实例化任何
	# 场景、创建任何目录或初始化存档服务之前通过校验；失败立即拒绝启动，
	# 不落盘。普通玩家启动不带该标志，默认 user:// 行为完全不变。
	var resolved := _resolve_save_directory_args()
	if resolved.error.is_empty():
		return
	push_error("TXWZS 启动门禁拒绝：" + resolved.error)
	print("TXWZS_SAVE_GATE rejected: ", resolved.error, " override='", resolved.override, "'")
	# 自动加载器的 _enter_tree 早于主循环首帧，直接 quit 在部分启动路径下
	# 不生效；延迟一帧确保退出码可靠传递。
	get_tree().quit(3)


static func parse_identity(
	user_args: PackedStringArray,
	fallback_scene := "UNKNOWN"
) -> Dictionary:
	var values := {
		"launcher": "",
		"scene": "",
		"candidate": "",
		"branch": "",
		"commit": "",
		"dirty": "",
		"launch_id": "",
		"project_key": "",
		"save_key": "",
		"project_path": "",
		"save_directory": "",
	}
	for argument in user_args:
		var text := String(argument)
		if text.begins_with(SAVE_DIRECTORY_ARGUMENT_PREFIX):
			values.save_directory = text.trim_prefix(SAVE_DIRECTORY_ARGUMENT_PREFIX)
			continue
		for key in values:
			var prefix := "--txwzs-%s=" % key.replace("_", "-")
			if text.begins_with(prefix):
				values[key] = text.trim_prefix(prefix)
				break

	var scene := String(values.scene)
	var commit := String(values.commit)
	var identified := (
		String(values.launcher) == "1"
		and scene in KNOWN_SCENES
		and String(values.candidate) in [CANDIDATE_VERSION_FORMAL_R1, CANDIDATE_VERSION_REGULAR_R1, CANDIDATE_VERSION_REGULAR_R1A]
		and not String(values.branch).is_empty()
		and commit.length() in [7, 40]
		and commit.is_valid_hex_number()
		and String(values.dirty) in ["0", "1"]
		and not String(values.launch_id).is_empty()
		and String(values.project_key).length() == 16
		and String(values.project_key).is_valid_hex_number()
		and String(values.save_key).length() == 16
		and String(values.save_key).is_valid_hex_number()
		and not String(values.project_path).is_empty()
		and not String(values.save_directory).is_empty()
	)
	if not identified:
		scene = fallback_scene if fallback_scene in KNOWN_SCENES else "UNKNOWN"
	return {
		"identified": identified,
		"scene": scene,
		"candidate": String(values.candidate) if identified else "UNKNOWN",
		"branch": String(values.branch) if identified else "",
		"commit": commit.to_lower() if identified else "",
		"dirty": String(values.dirty) == "1" if identified else false,
		"launch_id": String(values.launch_id) if identified else "",
		"project_key": String(values.project_key).to_lower() if identified else "",
		"save_key": String(values.save_key).to_lower() if identified else "",
		"project_path": String(values.project_path) if identified else "",
		"save_directory": String(values.save_directory) if identified else "",
	}


static func build_window_title(
	identity: Dictionary,
	debug_build: bool
) -> String:
	if not debug_build:
		return TITLE_BASE
	var scene := String(identity.get("scene", "UNKNOWN"))
	if not bool(identity.get("identified", false)):
		return "%s · %s · DEBUG · UNKNOWN" % [TITLE_BASE, scene]
	var commit := String(identity.get("commit", ""))
	var display_commit := commit.substr(0, mini(commit.length(), 12))
	var title := "%s · %s · %s@%s · DEBUG" % [
		TITLE_BASE,
		scene,
		String(identity.get("branch", "")),
		display_commit,
	]
	if bool(identity.get("dirty", false)):
		title += " · DIRTY"
	return title
