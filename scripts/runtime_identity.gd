extends Node


const TITLE_BASE := "天下无战事"
const SCENE_CITY := "CITY"
const SCENE_BATTLE_C0 := "BATTLE-C0"
const KNOWN_SCENES := [SCENE_CITY, SCENE_BATTLE_C0]

var current_identity: Dictionary = {}
var current_title := ""


func _ready() -> void:
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


func _detect_current_scene_label() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "UNKNOWN"
	var scene_path := String(scene.scene_file_path)
	if scene_path.ends_with("/blank_map.tscn"):
		return SCENE_CITY
	if scene_path.ends_with("/c0_battle_graybox.tscn"):
		return SCENE_BATTLE_C0
	return "UNKNOWN"


static func parse_identity(
	user_args: PackedStringArray,
	fallback_scene := "UNKNOWN"
) -> Dictionary:
	var values := {
		"launcher": "",
		"scene": "",
		"branch": "",
		"commit": "",
		"dirty": "",
		"launch_id": "",
	}
	for argument in user_args:
		var text := String(argument)
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
		and not String(values.branch).is_empty()
		and commit.length() == 7
		and commit.is_valid_hex_number()
		and String(values.dirty) in ["0", "1"]
		and not String(values.launch_id).is_empty()
	)
	if not identified:
		scene = fallback_scene if fallback_scene in KNOWN_SCENES else "UNKNOWN"
	return {
		"identified": identified,
		"scene": scene,
		"branch": String(values.branch) if identified else "",
		"commit": commit.to_lower() if identified else "",
		"dirty": String(values.dirty) == "1" if identified else false,
		"launch_id": String(values.launch_id) if identified else "",
	}


static func build_window_title(
	identity: Dictionary,
	debug_build: bool
) -> String:
	if not debug_build:
		return TITLE_BASE
	var scene := String(identity.get("scene", "UNKNOWN"))
	if not bool(identity.get("identified", false)):
		return "%s · %s · DEBUG · UNIDENTIFIED" % [TITLE_BASE, scene]
	var title := "%s · %s · %s@%s · DEBUG" % [
		TITLE_BASE,
		scene,
		String(identity.get("branch", "")),
		String(identity.get("commit", "")),
	]
	if bool(identity.get("dirty", false)):
		title += " · DIRTY"
	return title
