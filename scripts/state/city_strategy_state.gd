class_name CityStrategyState
extends RefCounted


const SCHEMA_VERSION := 1
const SUPPORT_IDLE := &"IDLE"
const SUPPORT_ACTIVE := &"ACTIVE"
const OFFICIAL_IDS := [&"official.steward", &"official.physician", &"official.strategist"]
const TROOP_EQUIPMENT_IDS := [&"equipment.spear_kit", &"equipment.padded_armor", &"equipment.marching_kit"]
const GENERAL_EQUIPMENT_IDS := [&"equipment.general.bronze_sword", &"equipment.general.lamellar", &"equipment.general.riding_boots"]
const EQUIPMENT_IDS := TROOP_EQUIPMENT_IDS + GENERAL_EQUIPMENT_IDS
const GENERAL_SLOTS := [&"weapon", &"helmet", &"armor", &"gloves", &"boots", &"accessory"]
const SUPPORT_BY_OFFICIAL := {
	&"official.steward": &"PRODUCTION",
	&"official.physician": &"MEDICAL",
	&"official.strategist": &"DEFENSE",
}

var unlocked_official_ids: Array[StringName] = []
var appointed_official_id := &""
var campaign_energy := 0
var active_support := empty_support()
var owned_equipment_ids: Array[StringName] = []
var troop_equipment_by_slot := {&"attack": &"", &"defense": &"", &"mobility": &""}
var general_equipment_by_general_id: Dictionary = {}
var trade_day := 0
var used_trade_offer_ids: Array[StringName] = []
var next_trade_receipt_sequence := 1
var trade_receipts: Array[Dictionary] = []


func initialize_fresh(rules: CityStrategyRules) -> void:
	unlocked_official_ids.assign(OFFICIAL_IDS)
	appointed_official_id = &"official.steward"
	campaign_energy = rules.campaign_energy_max
	active_support = empty_support()
	owned_equipment_ids.clear()
	troop_equipment_by_slot = {&"attack": &"", &"defense": &"", &"mobility": &""}
	general_equipment_by_general_id.clear()
	trade_day = 0
	used_trade_offer_ids.clear()
	next_trade_receipt_sequence = 1
	trade_receipts.clear()


static func empty_legacy_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "unlocked_official_ids": [],
		"appointed_official_id": &"", "campaign_energy": 0,
		"active_support": empty_support(), "owned_equipment_ids": [],
		"troop_equipment_by_slot": {&"attack": &"", &"defense": &"", &"mobility": &""},
		"general_equipment_by_general_id": {},
		"trade_day": 0, "used_trade_offer_ids": [],
		"next_trade_receipt_sequence": 1, "trade_receipts": [],
	}


func appoint(official_id: StringName) -> bool:
	if official_id not in unlocked_official_ids:
		return false
	appointed_official_id = official_id
	return true


func begin_support(official_id: StringName, current_day: int, rules: CityStrategyRules) -> Dictionary:
	if official_id != appointed_official_id or campaign_energy <= 0 or StringName(active_support.phase) == SUPPORT_ACTIVE:
		return {}
	var support_type := SUPPORT_BY_OFFICIAL.get(official_id, &"") as StringName
	if support_type == &"":
		return {}
	campaign_energy -= 1
	active_support = {
		"phase": SUPPORT_ACTIVE,
		"official_id": official_id,
		"support_type": support_type,
		"started_day": current_day,
		"expires_day": current_day + rules.support_duration_days,
	}
	return active_support.duplicate(true)


func expire_support_for_day(current_day: int) -> bool:
	if StringName(active_support.phase) != SUPPORT_ACTIVE or current_day < int(active_support.expires_day):
		return false
	active_support = empty_support()
	return true


func own_equipment(equipment_id: StringName) -> bool:
	if equipment_id not in EQUIPMENT_IDS or equipment_id in owned_equipment_ids:
		return false
	owned_equipment_ids.append(equipment_id)
	owned_equipment_ids.sort()
	return true


func equip_troops(equipment_id: StringName) -> bool:
	if equipment_id not in owned_equipment_ids or equipment_id not in TROOP_EQUIPMENT_IDS:
		return false
	var slot := {
		&"equipment.spear_kit": &"attack",
		&"equipment.padded_armor": &"defense",
		&"equipment.marching_kit": &"mobility",
	}.get(equipment_id, &"") as StringName
	if slot == &"":
		return false
	troop_equipment_by_slot[slot] = equipment_id
	return true


func unequip_troops(equipment_id: StringName) -> bool:
	for slot in troop_equipment_by_slot:
		if StringName(troop_equipment_by_slot[slot]) == equipment_id:
			troop_equipment_by_slot[slot] = &""
			return true
	return false


func equip_general(general_id: StringName, equipment_id: StringName) -> bool:
	if general_id == &"" or equipment_id not in owned_equipment_ids or equipment_id not in GENERAL_EQUIPMENT_IDS:
		return false
	var slot := {
		&"equipment.general.bronze_sword": &"weapon",
		&"equipment.general.lamellar": &"armor",
		&"equipment.general.riding_boots": &"boots",
	}.get(equipment_id, &"") as StringName
	if slot == &"":
		return false
	var loadout: Dictionary = Dictionary(general_equipment_by_general_id.get(general_id, empty_general_loadout())).duplicate(true)
	loadout[slot] = equipment_id
	general_equipment_by_general_id[general_id] = loadout
	return true


func unequip_general(general_id: StringName, equipment_id: StringName) -> bool:
	var loadout: Dictionary = Dictionary(general_equipment_by_general_id.get(general_id, {})).duplicate(true)
	if loadout.is_empty():
		return false
	for slot in loadout:
		if StringName(loadout[slot]) == equipment_id:
			loadout[slot] = &""
			general_equipment_by_general_id[general_id] = loadout
			return true
	return false


func general_has_equipment(general_id: StringName, equipment_id: StringName) -> bool:
	return equipment_id in Dictionary(general_equipment_by_general_id.get(general_id, {})).values()


func record_trade(offer_id: StringName, current_day: int) -> Dictionary:
	if trade_day != current_day:
		trade_day = current_day
		used_trade_offer_ids.clear()
	if offer_id in used_trade_offer_ids:
		return {}
	var receipt := {"receipt_id": StringName("trade.blackstone.%06d" % next_trade_receipt_sequence), "offer_id": offer_id, "day": current_day}
	next_trade_receipt_sequence += 1
	used_trade_offer_ids.append(offer_id)
	used_trade_offer_ids.sort()
	trade_receipts.append(receipt)
	return receipt.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unlocked_official_ids": unlocked_official_ids.duplicate(),
		"appointed_official_id": appointed_official_id,
		"campaign_energy": campaign_energy,
		"active_support": active_support.duplicate(true),
		"owned_equipment_ids": owned_equipment_ids.duplicate(),
		"troop_equipment_by_slot": troop_equipment_by_slot.duplicate(true),
		"general_equipment_by_general_id": general_equipment_by_general_id.duplicate(true),
		"trade_day": trade_day,
		"used_trade_offer_ids": used_trade_offer_ids.duplicate(),
		"next_trade_receipt_sequence": next_trade_receipt_sequence,
		"trade_receipts": trade_receipts.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var result := validate_snapshot(snapshot)
	if not bool(result.valid):
		return false
	var value: Dictionary = result.snapshot
	unlocked_official_ids.assign(value.unlocked_official_ids)
	appointed_official_id = StringName(value.appointed_official_id)
	campaign_energy = int(value.campaign_energy)
	active_support = Dictionary(value.active_support).duplicate(true)
	owned_equipment_ids.assign(value.owned_equipment_ids)
	troop_equipment_by_slot = Dictionary(value.troop_equipment_by_slot).duplicate(true)
	general_equipment_by_general_id = Dictionary(value.general_equipment_by_general_id).duplicate(true)
	trade_day = int(value.trade_day)
	used_trade_offer_ids.assign(value.used_trade_offer_ids)
	next_trade_receipt_sequence = int(value.next_trade_receipt_sequence)
	trade_receipts.assign(Array(value.trade_receipts).duplicate(true))
	return true


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	var keys := ["schema_version", "unlocked_official_ids", "appointed_official_id", "campaign_energy", "active_support", "owned_equipment_ids", "troop_equipment_by_slot", "general_equipment_by_general_id", "trade_day", "used_trade_offer_ids", "next_trade_receipt_sequence", "trade_receipts"]
	if snapshot.size() != keys.size():
		return {"valid": false}
	for key in keys:
		if not snapshot.has(key):
			return {"valid": false}
	if typeof(snapshot.schema_version) != TYPE_INT or int(snapshot.schema_version) != SCHEMA_VERSION or typeof(snapshot.unlocked_official_ids) != TYPE_ARRAY or typeof(snapshot.appointed_official_id) != TYPE_STRING_NAME or typeof(snapshot.campaign_energy) != TYPE_INT or int(snapshot.campaign_energy) < 0 or typeof(snapshot.active_support) != TYPE_DICTIONARY or typeof(snapshot.owned_equipment_ids) != TYPE_ARRAY or typeof(snapshot.troop_equipment_by_slot) != TYPE_DICTIONARY or typeof(snapshot.general_equipment_by_general_id) != TYPE_DICTIONARY or typeof(snapshot.trade_day) != TYPE_INT or int(snapshot.trade_day) < 0 or typeof(snapshot.used_trade_offer_ids) != TYPE_ARRAY or typeof(snapshot.next_trade_receipt_sequence) != TYPE_INT or int(snapshot.next_trade_receipt_sequence) <= 0 or typeof(snapshot.trade_receipts) != TYPE_ARRAY:
		return {"valid": false}
	if not _valid_unique_ids(snapshot.unlocked_official_ids, OFFICIAL_IDS) or not _valid_unique_ids(snapshot.owned_equipment_ids, EQUIPMENT_IDS):
		return {"valid": false}
	if StringName(snapshot.appointed_official_id) != &"" and StringName(snapshot.appointed_official_id) not in snapshot.unlocked_official_ids:
		return {"valid": false}
	var support: Dictionary = snapshot.active_support
	if support.size() != 5 or typeof(support.get("phase")) != TYPE_STRING_NAME or typeof(support.get("official_id")) != TYPE_STRING_NAME or typeof(support.get("support_type")) != TYPE_STRING_NAME or typeof(support.get("started_day")) != TYPE_INT or typeof(support.get("expires_day")) != TYPE_INT:
		return {"valid": false}
	var phase := StringName(support.phase)
	if phase == SUPPORT_IDLE:
		if support != empty_support():
			return {"valid": false}
	elif phase != SUPPORT_ACTIVE or StringName(support.official_id) not in snapshot.unlocked_official_ids or StringName(support.support_type) != StringName(SUPPORT_BY_OFFICIAL.get(StringName(support.official_id), &"")) or int(support.started_day) <= 0 or int(support.expires_day) <= int(support.started_day):
		return {"valid": false}
	var slots: Dictionary = snapshot.troop_equipment_by_slot
	if slots.size() != 3:
		return {"valid": false}
	for slot in [&"attack", &"defense", &"mobility"]:
		if not slots.has(slot) or typeof(slots[slot]) != TYPE_STRING_NAME or (StringName(slots[slot]) != &"" and StringName(slots[slot]) not in snapshot.owned_equipment_ids):
			return {"valid": false}
	var assigned_general_items := {}
	for general_id_value in snapshot.general_equipment_by_general_id:
		if typeof(general_id_value) != TYPE_STRING_NAME or StringName(general_id_value) == &"" or typeof(snapshot.general_equipment_by_general_id[general_id_value]) != TYPE_DICTIONARY:
			return {"valid": false}
		var loadout: Dictionary = snapshot.general_equipment_by_general_id[general_id_value]
		if loadout.size() != GENERAL_SLOTS.size():
			return {"valid": false}
		for slot in GENERAL_SLOTS:
			if not loadout.has(slot) or typeof(loadout[slot]) != TYPE_STRING_NAME:
				return {"valid": false}
			var equipment_id := StringName(loadout[slot])
			if equipment_id != &"" and (equipment_id not in snapshot.owned_equipment_ids or equipment_id not in GENERAL_EQUIPMENT_IDS or assigned_general_items.has(equipment_id)):
				return {"valid": false}
			if equipment_id != &"":
				assigned_general_items[equipment_id] = true
	if not _valid_unique_ids(snapshot.used_trade_offer_ids, [&"trade.wood_for_food", &"trade.food_for_wood"]):
		return {"valid": false}
	var seen_receipts := {}
	var maximum_sequence := 0
	for receipt_value in snapshot.trade_receipts:
		if typeof(receipt_value) != TYPE_DICTIONARY:
			return {"valid": false}
		var receipt: Dictionary = receipt_value
		if receipt.size() != 3 or typeof(receipt.get("receipt_id")) != TYPE_STRING_NAME or typeof(receipt.get("offer_id")) != TYPE_STRING_NAME or typeof(receipt.get("day")) != TYPE_INT or int(receipt.day) <= 0 or StringName(receipt.offer_id) not in [&"trade.wood_for_food", &"trade.food_for_wood"] or seen_receipts.has(StringName(receipt.receipt_id)):
			return {"valid": false}
		var parts := str(receipt.receipt_id).split(".")
		if parts.size() != 3 or not parts[2].is_valid_int():
			return {"valid": false}
		maximum_sequence = maxi(maximum_sequence, int(parts[2]))
		seen_receipts[StringName(receipt.receipt_id)] = true
	if int(snapshot.next_trade_receipt_sequence) <= maximum_sequence:
		return {"valid": false}
	for offer_id in snapshot.used_trade_offer_ids:
		var found := false
		for receipt_value in snapshot.trade_receipts:
			var receipt: Dictionary = receipt_value
			if StringName(receipt.offer_id) == StringName(offer_id) and int(receipt.day) == int(snapshot.trade_day):
				found = true
				break
		if not found:
			return {"valid": false}
	return {"valid": true, "snapshot": snapshot.duplicate(true)}


static func empty_support() -> Dictionary:
	return {"phase": SUPPORT_IDLE, "official_id": &"", "support_type": &"", "started_day": 0, "expires_day": 0}


static func empty_general_loadout() -> Dictionary:
	return {&"weapon": &"", &"helmet": &"", &"armor": &"", &"gloves": &"", &"boots": &"", &"accessory": &""}


static func _valid_unique_ids(values: Array, allowed: Array) -> bool:
	var seen := {}
	for value in values:
		if typeof(value) != TYPE_STRING_NAME or StringName(value) not in allowed or seen.has(StringName(value)):
			return false
		seen[StringName(value)] = true
	return true
