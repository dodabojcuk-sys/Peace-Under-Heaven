extends Node


const TITLE_BASE := "天下无战事"
const SCENE_CITY := "CITY"
const SCENE_BATTLE_C0 := "BATTLE-C0"
const SCENE_TITLE := "TITLE"
const KNOWN_SCENES := [SCENE_TITLE, SCENE_CITY, SCENE_BATTLE_C0]
const CAMPAIGN_START_CONTINUE := &"CONTINUE"
const CAMPAIGN_START_NEW := &"NEW"
const SAVE_DIRECTORY_ARGUMENT_PREFIX := "--txwzs-v5-save-dir="
const CANDIDATE_VERSION_FORMAL_R1 := "FORMAL-CANDIDATE-R1"

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
	if mode not in [CAMPAIGN_START_CONTINUE, CAMPAIGN_START_NEW]:
		return false
	_pending_campaign_start_mode = mode
	return true


func consume_campaign_start_mode() -> StringName:
	var mode := _pending_campaign_start_mode
	_pending_campaign_start_mode = CAMPAIGN_START_CONTINUE
	return mode


func get_campaign_save_directory_override() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(SAVE_DIRECTORY_ARGUMENT_PREFIX):
			return argument.trim_prefix(SAVE_DIRECTORY_ARGUMENT_PREFIX)
	return ""


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
		and String(values.candidate) == CANDIDATE_VERSION_FORMAL_R1
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
