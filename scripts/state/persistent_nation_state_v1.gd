class_name PersistentNationStateV1
extends RefCounted


const SCHEMA_VERSION := 1
const STATE_KIND := &"one_city_national_read_model"
const NATION_ID := &"nation.txwzs2"
const SHARED_RESOURCE_IDS: Array[StringName] = [
	&"food",
	&"tech_points",
	&"wood",
]


## Builds a detached, one-city national read model from the existing city authority.
## This is a projection only: it never owns, writes, caches, or persists state.
static func read(city_authority: Object) -> Dictionary:
	if city_authority == null or not is_instance_valid(city_authority):
		return _failure(
			&"MISSING_CITY_AUTHORITY",
			"缺少当前城市状态权威"
		)
	if (
		not city_authority.has_method("export_v5_campaign_snapshot")
		or not city_authority.has_method("validate_v5_campaign_snapshot")
		or not city_authority.has_method("get_nation_state")
	):
		return _failure(
			&"UNSUPPORTED_CITY_AUTHORITY",
			"城市状态权威不支持 V5 只读快照合同"
		)

	var exported = city_authority.call("export_v5_campaign_snapshot")
	if typeof(exported) != TYPE_DICTIONARY or Dictionary(exported).is_empty():
		return _failure(
			&"INVALID_CITY_SNAPSHOT",
			"城市权威未提供可投影的 V5 快照"
		)
	var validation = city_authority.call(
		"validate_v5_campaign_snapshot",
		Dictionary(exported).duplicate(true)
	)
	if (
		typeof(validation) != TYPE_DICTIONARY
		or not bool(Dictionary(validation).get("valid", false))
		or typeof(Dictionary(validation).get("snapshot", null))
			!= TYPE_DICTIONARY
	):
		return _failure(
			&"INVALID_CITY_SNAPSHOT",
			"城市权威 V5 快照未通过既有校验"
		)

	var snapshot: Dictionary = Dictionary(
		Dictionary(validation).snapshot
	).duplicate(true)
	var city_id := StringName(snapshot.get("city_id", &""))
	if city_id == &"" or typeof(snapshot.get("city", null)) != TYPE_DICTIONARY:
		return _failure(
			&"INVALID_CITY_SNAPSHOT",
			"城市权威 V5 快照缺少稳定城市身份或城市数据"
		)
	var city: Dictionary = Dictionary(snapshot.city).duplicate(true)
	var nation_state = city_authority.call("get_nation_state")
	if (
		nation_state == null
		or not is_instance_valid(nation_state)
		or not nation_state.has_method("get_shared_resources")
	):
		return _failure(
			&"INVALID_NATION_AUTHORITY",
			"城市组合根未提供国家状态权威"
		)
	var shared_resources = nation_state.call("get_shared_resources")
	if (
		typeof(shared_resources) != TYPE_DICTIONARY
		or Dictionary(shared_resources).keys().size()
			!= SHARED_RESOURCE_IDS.size()
	):
		return _failure(
			&"INVALID_NATION_RESOURCES",
			"国家状态权威未提供完整共享资源"
		)
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"state": {
			"schema_version": SCHEMA_VERSION,
			"state_kind": STATE_KIND,
			"nation_id": NATION_ID,
			"city_id": city_id,
			"city_ids": [city_id],
			"shared_resource_ids": SHARED_RESOURCE_IDS.duplicate(),
			"shared_resources": Dictionary(shared_resources).duplicate(true),
			"cities_by_id": {city_id: snapshot.duplicate(true)},
		}.duplicate(true),
	}


static func _failure(error_id: StringName, error: String) -> Dictionary:
	return {
		"success": false,
		"error_id": error_id,
		"error": error,
		"state": {},
	}
