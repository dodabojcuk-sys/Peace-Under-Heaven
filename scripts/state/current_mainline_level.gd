class_name CurrentMainlineLevel
extends RefCounted


const SNAPSHOT_KEYS := [
	"level_id",
	"activated_day",
	"deadline_day",
	"pressure_stage_id",
	"cleared",
	"cleared_day",
	"applied_event_ids",
	"permanent_losses",
]

var profile: MainlinePressureProfile
var level_id: StringName
var activated_day := 1
var deadline_day := 7
var pressure_stage_id: StringName = &"PRESSURE_0"
var cleared := false
var cleared_day := 0
var applied_event_ids: Dictionary = {}
var permanent_losses := {
	"wood": 0,
	"food": 0,
	"city_defense_damage": 0,
}


func _init(source_profile: MainlinePressureProfile = null) -> void:
	profile = source_profile
	if profile != null:
		level_id = profile.level_id
		deadline_day = profile.deadline_day


func advance_to_day(current_day: int) -> void:
	if profile == null or cleared:
		return
	var next_index := profile.get_stage_index(current_day)
	var current_index := _stage_index(pressure_stage_id)
	if next_index > current_index:
		pressure_stage_id = StringName("PRESSURE_%d" % next_index)


func mark_cleared(current_day: int) -> void:
	if cleared:
		return
	cleared = true
	cleared_day = current_day


func build_pressure_event(current_day: int, security: int) -> Dictionary:
	advance_to_day(current_day)
	if cleared or profile == null or _stage_index(pressure_stage_id) <= 0:
		return {}
	var event_id := StringName("%s.day_%d" % [level_id, current_day])
	if applied_event_ids.has(event_id):
		return {}
	return {
		"event_id": event_id,
		"day": current_day,
		"stage_id": pressure_stage_id,
		"losses": profile.get_loss_for_day(current_day, security),
	}


func commit_pressure_event(event: Dictionary) -> bool:
	var event_id := StringName(event.get("event_id", &""))
	var losses: Dictionary = event.get("losses", {})
	if event_id == &"" or applied_event_ids.has(event_id):
		return false
	for key in permanent_losses:
		permanent_losses[key] = int(permanent_losses[key]) + int(losses.get(key, 0))
	applied_event_ids[event_id] = true
	return true


func get_snapshot() -> Dictionary:
	return {
		"level_id": level_id,
		"activated_day": activated_day,
		"deadline_day": deadline_day,
		"pressure_stage_id": pressure_stage_id,
		"cleared": cleared,
		"cleared_day": cleared_day,
		"applied_event_ids": applied_event_ids.duplicate(true),
		"permanent_losses": permanent_losses.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	level_id = StringName(snapshot.level_id)
	activated_day = int(snapshot.activated_day)
	deadline_day = int(snapshot.deadline_day)
	pressure_stage_id = StringName(snapshot.pressure_stage_id)
	cleared = bool(snapshot.cleared)
	cleared_day = int(snapshot.cleared_day)
	applied_event_ids = Dictionary(snapshot.applied_event_ids).duplicate(true)
	permanent_losses = Dictionary(snapshot.permanent_losses).duplicate(true)
	return true


static func validate_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.size() != SNAPSHOT_KEYS.size():
		return false
	for key in SNAPSHOT_KEYS:
		if not snapshot.has(key):
			return false
	if (
		typeof(snapshot.level_id) != TYPE_STRING_NAME
		or StringName(snapshot.level_id) == &""
		or typeof(snapshot.activated_day) != TYPE_INT
		or int(snapshot.activated_day) <= 0
		or typeof(snapshot.deadline_day) != TYPE_INT
		or int(snapshot.deadline_day) <= int(snapshot.activated_day)
		or typeof(snapshot.pressure_stage_id) != TYPE_STRING_NAME
		or _stage_index(StringName(snapshot.pressure_stage_id)) < 0
		or typeof(snapshot.cleared) != TYPE_BOOL
		or typeof(snapshot.cleared_day) != TYPE_INT
		or int(snapshot.cleared_day) < 0
		or typeof(snapshot.applied_event_ids) != TYPE_DICTIONARY
		or typeof(snapshot.permanent_losses) != TYPE_DICTIONARY
	):
		return false
	if (
		Dictionary(snapshot.permanent_losses).size() != 3
		or (bool(snapshot.cleared) and int(snapshot.cleared_day) < int(snapshot.activated_day))
		or (not bool(snapshot.cleared) and int(snapshot.cleared_day) != 0)
	):
		return false
	for event_id in snapshot.applied_event_ids:
		if (
			typeof(event_id) != TYPE_STRING_NAME
			or StringName(event_id) == &""
			or snapshot.applied_event_ids[event_id] != true
		):
			return false
	for key in ["wood", "food", "city_defense_damage"]:
		if (
			not snapshot.permanent_losses.has(key)
			or typeof(snapshot.permanent_losses[key]) != TYPE_INT
			or int(snapshot.permanent_losses[key]) < 0
		):
			return false
	return true


static func _stage_index(stage_id: StringName) -> int:
	var value := String(stage_id)
	if not value.begins_with("PRESSURE_"):
		return -1
	var index := int(value.trim_prefix("PRESSURE_"))
	return index if index >= 0 and index <= 4 else -1
