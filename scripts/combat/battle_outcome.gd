class_name BattleOutcome
extends RefCounted


enum Value {
	VICTORY,
	DEFEAT,
	RETREAT,
}


static func to_id(value: Value) -> StringName:
	match value:
		Value.VICTORY:
			return &"VICTORY"
		Value.DEFEAT:
			return &"DEFEAT"
		Value.RETREAT:
			return &"RETREAT"
	return &""
