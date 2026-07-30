class_name V5CampaignSaveCodec
extends RefCounted


const STORAGE_KIND := "txwzs_campaign_save"
const STORAGE_VERSION := 1
const MAX_EXACT_JSON_INTEGER := 9007199254740991
const ENVELOPE_KEYS := [
	"storage_kind",
	"storage_version",
	"city_id",
	"save_sequence",
	"payload_json",
	"payload_sha256",
]


static func encode_snapshot(
	snapshot: Dictionary,
	save_sequence: int,
	validator: Callable
) -> Dictionary:
	if (
		save_sequence <= 0
		or save_sequence > MAX_EXACT_JSON_INTEGER
		or not validator.is_valid()
	):
		return _failure(&"ENCODE_PREFLIGHT", "存档编码预检失败")
	var validation = validator.call(snapshot.duplicate(true))
	if (
		typeof(validation) != TYPE_DICTIONARY
		or not bool(validation.get("valid", false))
	):
		return _failure(&"INVALID_SNAPSHOT", "V2 快照校验失败")
	var normalized: Dictionary = validation.snapshot
	var dto_result := _encode_variant(normalized)
	if not bool(dto_result.success):
		return dto_result
	var payload_json := _canonical_json(dto_result.value)
	var envelope := {
		"storage_kind": STORAGE_KIND,
		"storage_version": STORAGE_VERSION,
		"city_id": V5CampaignSnapshot.CITY_ID,
		"save_sequence": save_sequence,
		"payload_json": payload_json,
		"payload_sha256": calculate_sha256(payload_json),
	}
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"storage_text": _canonical_json(envelope),
		"save_sequence": save_sequence,
		"snapshot": normalized.duplicate(true),
	}


static func decode_storage_text(
	storage_text: String,
	validator: Callable
) -> Dictionary:
	if storage_text.is_empty() or not validator.is_valid():
		return _failure(&"DECODE_PREFLIGHT", "存档解码预检失败")
	var json := JSON.new()
	if json.parse(storage_text) != OK or not json.data is Dictionary:
		return _failure(&"PARSE_FAILED", "存档 envelope JSON 非法")
	var envelope: Dictionary = json.data
	if not _has_exact_keys(envelope, ENVELOPE_KEYS):
		return _failure(&"INVALID_ENVELOPE", "存档 envelope 字段非法")
	for key in [
		"storage_kind",
		"city_id",
		"payload_json",
		"payload_sha256",
	]:
		if typeof(envelope[key]) != TYPE_STRING:
			return _failure(&"INVALID_ENVELOPE", "存档 envelope 类型非法")
	var version_result := _decode_json_integer(
		envelope.storage_version
	)
	var sequence_result := _decode_json_integer(envelope.save_sequence)
	if not bool(version_result.success) or not bool(sequence_result.success):
		return _failure(&"INVALID_ENVELOPE", "存档版本或代次不是整数")
	var storage_version := int(version_result.value)
	var save_sequence := int(sequence_result.value)
	if storage_version > STORAGE_VERSION:
		return _failure(&"FUTURE_STORAGE_VERSION", "未知未来存储版本")
	if storage_version != STORAGE_VERSION:
		return _failure(&"UNSUPPORTED_STORAGE_VERSION", "不支持的存储版本")
	if (
		save_sequence <= 0
		or str(envelope.storage_kind) != STORAGE_KIND
		or str(envelope.city_id) != V5CampaignSnapshot.CITY_ID
	):
		return _failure(&"INVALID_ENVELOPE", "存档身份或代次非法")
	var payload_json := str(envelope.payload_json)
	var payload_sha256 := str(envelope.payload_sha256)
	if (
		not _is_lowercase_sha256(payload_sha256)
		or calculate_sha256(payload_json) != payload_sha256
	):
		return _failure(&"CHECKSUM_FAILED", "payload checksum 非法")
	var canonical_envelope := {
		"storage_kind": str(envelope.storage_kind),
		"storage_version": storage_version,
		"city_id": str(envelope.city_id),
		"save_sequence": save_sequence,
		"payload_json": payload_json,
		"payload_sha256": payload_sha256,
	}
	if _canonical_json(canonical_envelope) != storage_text:
		return _failure(&"NON_CANONICAL_ENVELOPE", "envelope 不是规范 JSON")
	var payload_parser := JSON.new()
	if (
		payload_parser.parse(payload_json) != OK
		or not payload_parser.data is Dictionary
	):
		return _failure(&"PARSE_FAILED", "payload JSON 非法")
	var decoded := _decode_variant(payload_parser.data)
	if not bool(decoded.success) or not decoded.value is Dictionary:
		return _failure(&"PAYLOAD_DECODE_FAILED", "payload 类型恢复失败")
	var validation = validator.call(Dictionary(decoded.value).duplicate(true))
	if (
		typeof(validation) != TYPE_DICTIONARY
		or not bool(validation.get("valid", false))
	):
		if StringName(
			validation.get("error_id", &"")
		) == &"FUTURE_SCHEMA_VERSION":
			return _failure(
				&"FUTURE_SCHEMA_VERSION",
				"未知未来 CampaignSnapshot schema"
			)
		return _failure(&"INVALID_SNAPSHOT", "磁盘 V2 快照领域校验失败")
	var canonical_dto := _encode_variant(validation.snapshot)
	if (
		not bool(canonical_dto.success)
		or _canonical_json(canonical_dto.value) != payload_json
	):
		return _failure(&"NON_CANONICAL_PAYLOAD", "payload 不是规范 JSON")
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"save_sequence": save_sequence,
		"snapshot": Dictionary(validation.snapshot).duplicate(true),
		"payload_json": payload_json,
		"payload_sha256": payload_sha256,
	}


static func calculate_sha256(payload_json: String) -> String:
	var context := HashingContext.new()
	if (
		context.start(HashingContext.HASH_SHA256) != OK
		or context.update(payload_json.to_utf8_buffer()) != OK
	):
		return ""
	return context.finish().hex_encode()


static func _encode_variant(value) -> Dictionary:
	match typeof(value):
		TYPE_NIL:
			return {"success": true, "value": null}
		TYPE_BOOL, TYPE_STRING:
			return {"success": true, "value": value}
		TYPE_INT:
			if abs(int(value)) > MAX_EXACT_JSON_INTEGER:
				return _failure(&"INTEGER_OUT_OF_RANGE", "整数超出 JSON 精确范围")
			return {"success": true, "value": int(value)}
		TYPE_STRING_NAME:
			return {
				"success": true,
				"value": {
					"$type": "string_name",
					"value": String(value),
				},
			}
		TYPE_VECTOR2I:
			return {
				"success": true,
				"value": {
					"$type": "vector2i",
					"x": int(value.x),
					"y": int(value.y),
				},
			}
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				var encoded := _encode_variant(item)
				if not bool(encoded.success):
					return encoded
				items.append(encoded.value)
			return {
				"success": true,
				"value": {"$type": "array", "items": items},
			}
		TYPE_DICTIONARY:
			var entries: Array = []
			for key in value:
				var encoded_key := _encode_variant(key)
				var encoded_value := _encode_variant(value[key])
				if (
					not bool(encoded_key.success)
					or not bool(encoded_value.success)
				):
					return _failure(
						&"UNSUPPORTED_VARIANT",
						"字典包含不可编码值"
					)
				entries.append([
					encoded_key.value,
					encoded_value.value,
				])
			entries.sort_custom(func(a, b): return (
				_canonical_json(a[0]) < _canonical_json(b[0])
			))
			return {
				"success": true,
				"value": {"$type": "dictionary", "entries": entries},
			}
	return _failure(
		&"UNSUPPORTED_VARIANT",
		"V2 存档拒绝运行时或表现对象"
	)


static func _decode_variant(dto) -> Dictionary:
	if dto == null or dto is bool or dto is String:
		return {"success": true, "value": dto}
	if dto is int or dto is float:
		var integer_result := _decode_json_integer(dto)
		if not bool(integer_result.success):
			return integer_result
		return {"success": true, "value": int(integer_result.value)}
	if not dto is Dictionary:
		return _failure(&"INVALID_DTO", "payload DTO 非法")
	var kind := str(dto.get("$type", ""))
	match kind:
		"string_name":
			if (
				not _has_exact_keys(dto, ["$type", "value"])
				or typeof(dto.value) != TYPE_STRING
			):
				return _failure(&"INVALID_DTO", "StringName DTO 非法")
			return {"success": true, "value": StringName(dto.value)}
		"vector2i":
			if not _has_exact_keys(dto, ["$type", "x", "y"]):
				return _failure(&"INVALID_DTO", "Vector2i DTO 非法")
			var x_result := _decode_json_integer(dto.x)
			var y_result := _decode_json_integer(dto.y)
			if not bool(x_result.success) or not bool(y_result.success):
				return _failure(&"INVALID_DTO", "Vector2i 整数非法")
			return {
				"success": true,
				"value": Vector2i(
					int(x_result.value),
					int(y_result.value)
				),
			}
		"array":
			if (
				not _has_exact_keys(dto, ["$type", "items"])
				or not dto.items is Array
			):
				return _failure(&"INVALID_DTO", "Array DTO 非法")
			var decoded_items: Array = []
			for item in dto.items:
				var decoded := _decode_variant(item)
				if not bool(decoded.success):
					return decoded
				decoded_items.append(decoded.value)
			return {"success": true, "value": decoded_items}
		"dictionary":
			if (
				not _has_exact_keys(dto, ["$type", "entries"])
				or not dto.entries is Array
			):
				return _failure(&"INVALID_DTO", "Dictionary DTO 非法")
			var decoded_dictionary: Dictionary = {}
			var previous_key_json := ""
			for entry in dto.entries:
				if not entry is Array or entry.size() != 2:
					return _failure(&"INVALID_DTO", "Dictionary entry 非法")
				var key_json := _canonical_json(entry[0])
				if not previous_key_json.is_empty() and key_json <= previous_key_json:
					return _failure(&"NON_CANONICAL_PAYLOAD", "字典键未严格排序")
				previous_key_json = key_json
				var key_result := _decode_variant(entry[0])
				var value_result := _decode_variant(entry[1])
				if (
					not bool(key_result.success)
					or not bool(value_result.success)
					or decoded_dictionary.has(key_result.value)
				):
					return _failure(&"INVALID_DTO", "Dictionary entry 冲突")
				decoded_dictionary[key_result.value] = value_result.value
			return {"success": true, "value": decoded_dictionary}
	return _failure(&"INVALID_DTO", "未知 payload DTO 类型")


static func _decode_json_integer(value) -> Dictionary:
	if typeof(value) == TYPE_INT:
		if abs(int(value)) > MAX_EXACT_JSON_INTEGER:
			return _failure(&"INVALID_INTEGER", "JSON 整数超出精确范围")
		return {"success": true, "value": int(value)}
	if typeof(value) != TYPE_FLOAT or not is_finite(float(value)):
		return _failure(&"INVALID_INTEGER", "JSON 值不是有限数字")
	var numeric := float(value)
	if (
		floor(numeric) != numeric
		or abs(numeric) > float(MAX_EXACT_JSON_INTEGER)
	):
		return _failure(&"INVALID_INTEGER", "JSON 数字不是精确整数")
	return {"success": true, "value": int(numeric)}


static func _canonical_json(value) -> String:
	return JSON.stringify(value, "", true, true)


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _is_lowercase_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _failure(error_id: StringName, error: String) -> Dictionary:
	return {
		"success": false,
		"error_id": error_id,
		"error": error,
	}
