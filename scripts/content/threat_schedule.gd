class_name ThreatSchedule
extends Resource


@export var schedule_id: StringName
@export var max_day := 12
@export var events: Array[ThreatEventDefinition] = []


func get_event_for_day(day: int) -> ThreatEventDefinition:
	var result: ThreatEventDefinition
	for event in events:
		if event != null and event.day <= day:
			if result == null or event.day > result.day:
				result = event
	return result


func get_next_pressure_event(after_day: int) -> ThreatEventDefinition:
	for event in events:
		if (
			event != null
			and event.day > after_day
			and event.event_type != &"none"
		):
			return event
	return null
