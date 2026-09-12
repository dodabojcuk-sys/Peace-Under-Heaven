class_name PopulationRecoveryState
extends RefCounted


const SCHEMA_VERSION := 3
const TREATMENT_IDLE := &"IDLE"
const TREATMENT_ACTIVE := &"ACTIVE"

var total_living := 0
var available := 0
var production_workers := 0
var construction_workers := 0
var medical_workers := 0
var governance_workers := 0
var training_reserved := 0
var children := 0
var elderly := 0
var resident_sick := 0
var unsettled_refugees := 0
var wounded := 0
var fallen := 0
var male_count := 0
var female_count := 0
var unknown_sex_count := 0
var growth_progress := 0
var child_age_progress := 0
var adult_age_progress := 0
var elderly_exposure_progress := 0
var next_birth_sequence := 1
var next_treatment_sequence := 1
var treatment := empty_treatment()


static func empty_treatment() -> Dictionary:
	return {
		"treatment_id": &"",
		"phase": TREATMENT_IDLE,
		"count": 0,
		"progress_milliseconds": 0,
		"required_milliseconds": 0,
		"food_cost_committed": 0,
	}


func initialize_fresh(rules: CampaignRecoveryRules, military_count: int, specialist_count := 0) -> bool:
	if rules == null or not rules.is_valid() or military_count < 0 or specialist_count < 0:
		return false
	production_workers = rules.initial_production_workers
	construction_workers = rules.initial_construction_workers
	medical_workers = rules.initial_medical_workers
	governance_workers = rules.initial_governance_workers
	training_reserved = 0
	children = 0
	elderly = 0
	resident_sick = 0
	unsettled_refugees = 0
	wounded = 0
	fallen = 0
	male_count = 0
	female_count = 0
	unknown_sex_count = 0
	growth_progress = 0
	child_age_progress = 0
	adult_age_progress = 0
	elderly_exposure_progress = 0
	next_birth_sequence = 1
	next_treatment_sequence = 1
	treatment = empty_treatment()
	total_living = maxi(
		rules.initial_living_population,
		military_count + specialist_count + production_workers + construction_workers + medical_workers + governance_workers
	)
	unknown_sex_count = total_living
	available = total_living - military_count - specialist_count - production_workers - construction_workers - medical_workers - governance_workers
	return true


func reserve_training(count: int) -> bool:
	if count <= 0 or count > available:
		return false
	available -= count
	training_reserved += count
	return true


func allocate_to_military(count: int) -> bool:
	if count <= 0 or available < count:
		return false
	available -= count
	return true


## Enrolls people who already existed in a finite external-location pool. The
## location inventory remains owned by FieldTacticsState; only the campaign
## population total changes here, in the same transaction as enlistment.
func admit_external_population(count: int) -> bool:
	if count <= 0:
		return false
	total_living += count
	unknown_sex_count += count
	return true


func accept_refugees(count: int) -> bool:
	if count <= 0:
		return false
	total_living += count
	unsettled_refugees += count
	unknown_sex_count += count
	return true


func settle_refugees(count: int, sick_count := 0) -> bool:
	if count <= 0 or count > unsettled_refugees or sick_count < 0 or sick_count > count:
		return false
	unsettled_refugees -= count
	resident_sick += sick_count
	available += count - sick_count
	return true


func record_birth() -> bool:
	if next_birth_sequence <= 0:
		return false
	total_living += 1
	children += 1
	if next_birth_sequence % 2 == 0:
		female_count += 1
	else:
		male_count += 1
	next_birth_sequence += 1
	return true


func mature_child() -> bool:
	if children <= 0:
		return false
	children -= 1
	available += 1
	return true


func age_available_adult() -> bool:
	if available <= 0:
		return false
	available -= 1
	elderly += 1
	return true


func record_sickness(count: int) -> bool:
	if count <= 0:
		return false
	if count > available + production_workers + construction_workers + governance_workers + medical_workers:
		return false
	var remaining := count
	for channel in [&"available", &"production", &"construction", &"governance", &"medical"]:
		if remaining <= 0:
			break
		var current := 0
		match channel:
			&"available": current = available
			&"production": current = production_workers
			&"construction": current = construction_workers
			&"governance": current = governance_workers
			&"medical": current = medical_workers
		var moved := mini(current, remaining)
		match channel:
			&"available": available -= moved
			&"production": production_workers -= moved
			&"construction": construction_workers -= moved
			&"governance": governance_workers -= moved
			&"medical": medical_workers -= moved
		remaining -= moved
	if remaining > 0:
		return false
	resident_sick += count
	return true


func recover_sickness(count: int) -> bool:
	if count <= 0 or count > resident_sick:
		return false
	resident_sick -= count
	available += count
	return true


func record_elderly_death(count := 1) -> bool:
	if count <= 0 or count > elderly:
		return false
	elderly -= count
	total_living -= count
	fallen += count
	_remove_sex_count(count)
	return true


func _remove_sex_count(count: int) -> void:
	var remaining := count
	var removed := mini(unknown_sex_count, remaining)
	unknown_sex_count -= removed
	remaining -= removed
	removed = mini(male_count, remaining)
	male_count -= removed
	remaining -= removed
	female_count = maxi(female_count - remaining, 0)


func complete_training(count: int) -> bool:
	if count <= 0 or count > training_reserved:
		return false
	training_reserved -= count
	return true


func cancel_training(count: int) -> bool:
	if count <= 0 or count > training_reserved:
		return false
	training_reserved -= count
	available += count
	return true


func allocate_worker(channel: StringName, delta: int) -> bool:
	if channel not in [&"production", &"construction", &"medical", &"governance"] or delta == 0:
		return false
	var current := 0
	match channel:
		&"production": current = production_workers
		&"construction": current = construction_workers
		&"medical": current = medical_workers
		&"governance": current = governance_workers
	if delta > 0 and delta > available:
		return false
	if delta < 0 and -delta > current:
		return false
	available -= delta
	match channel:
		&"production": production_workers += delta
		&"construction": construction_workers += delta
		&"medical": medical_workers += delta
		&"governance": governance_workers += delta
	return true


func allocate_specialist() -> bool:
	if available <= 0:
		return false
	available -= 1
	return true


func release_specialist() -> void:
	available += 1


func record_fallen(count: int) -> bool:
	if count <= 0 or count > total_living:
		return false
	fallen += count
	total_living -= count
	_remove_sex_count(count)
	return true


func record_casualties(casualties: int, wounded_permille: int) -> Dictionary:
	if casualties <= 0 or casualties > total_living or wounded_permille < 0 or wounded_permille > 1000:
		return {}
	var wounded_added := clampi(roundi(float(casualties * wounded_permille) / 1000.0), 0, casualties)
	var fallen_added := casualties - wounded_added
	wounded += wounded_added
	fallen += fallen_added
	total_living -= fallen_added
	_remove_sex_count(fallen_added)
	return {"casualties": casualties, "wounded": wounded_added, "fallen": fallen_added}


func begin_treatment(count: int, food_cost: int, required_milliseconds: int) -> Dictionary:
	if count <= 0 or count > wounded or food_cost < 0 or required_milliseconds <= 0 or StringName(treatment.phase) != TREATMENT_IDLE or next_treatment_sequence <= 0:
		return {}
	treatment = {
		"treatment_id": StringName("treatment.blackstone.%06d" % next_treatment_sequence),
		"phase": TREATMENT_ACTIVE,
		"count": count,
		"progress_milliseconds": 0,
		"required_milliseconds": required_milliseconds,
		"food_cost_committed": food_cost,
	}
	next_treatment_sequence += 1
	return treatment.duplicate(true)


func advance_treatment(delta_milliseconds: int) -> Dictionary:
	if delta_milliseconds <= 0 or StringName(treatment.phase) != TREATMENT_ACTIVE:
		return {}
	treatment.progress_milliseconds = mini(
		int(treatment.progress_milliseconds) + delta_milliseconds,
		int(treatment.required_milliseconds)
	)
	if int(treatment.progress_milliseconds) < int(treatment.required_milliseconds):
		return {}
	return treatment.duplicate(true)


func complete_treatment(treatment_id: StringName) -> int:
	if treatment_id == &"" or treatment_id != StringName(treatment.treatment_id) or StringName(treatment.phase) != TREATMENT_ACTIVE or int(treatment.progress_milliseconds) < int(treatment.required_milliseconds):
		return 0
	var count := int(treatment.count)
	if count <= 0 or count > wounded:
		return 0
	wounded -= count
	treatment = empty_treatment()
	return count


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"total_living": total_living,
		"available": available,
		"production_workers": production_workers,
		"construction_workers": construction_workers,
		"medical_workers": medical_workers,
		"governance_workers": governance_workers,
		"training_reserved": training_reserved,
		"children": children,
		"elderly": elderly,
		"resident_sick": resident_sick,
		"unsettled_refugees": unsettled_refugees,
		"wounded": wounded,
		"fallen": fallen,
		"male_count": male_count,
		"female_count": female_count,
		"unknown_sex_count": unknown_sex_count,
		"growth_progress": growth_progress,
		"child_age_progress": child_age_progress,
		"adult_age_progress": adult_age_progress,
		"elderly_exposure_progress": elderly_exposure_progress,
		"next_birth_sequence": next_birth_sequence,
		"next_treatment_sequence": next_treatment_sequence,
		"treatment": treatment.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var validation := validate_snapshot(snapshot)
	if not bool(validation.get("valid", false)):
		return false
	var normalized: Dictionary = validation.snapshot
	total_living = int(normalized.total_living)
	available = int(normalized.available)
	production_workers = int(normalized.production_workers)
	construction_workers = int(normalized.construction_workers)
	medical_workers = int(normalized.medical_workers)
	governance_workers = int(normalized.governance_workers)
	training_reserved = int(normalized.training_reserved)
	children = int(normalized.children)
	elderly = int(normalized.elderly)
	resident_sick = int(normalized.resident_sick)
	unsettled_refugees = int(normalized.unsettled_refugees)
	wounded = int(normalized.wounded)
	fallen = int(normalized.fallen)
	male_count = int(normalized.male_count)
	female_count = int(normalized.female_count)
	unknown_sex_count = int(normalized.unknown_sex_count)
	growth_progress = int(normalized.growth_progress)
	child_age_progress = int(normalized.child_age_progress)
	adult_age_progress = int(normalized.adult_age_progress)
	elderly_exposure_progress = int(normalized.elderly_exposure_progress)
	next_birth_sequence = int(normalized.next_birth_sequence)
	next_treatment_sequence = int(normalized.next_treatment_sequence)
	treatment = Dictionary(normalized.treatment).duplicate(true)
	return true


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	var keys := ["schema_version", "total_living", "available", "production_workers", "construction_workers", "medical_workers", "governance_workers", "training_reserved", "children", "elderly", "resident_sick", "unsettled_refugees", "wounded", "fallen", "male_count", "female_count", "unknown_sex_count", "growth_progress", "child_age_progress", "adult_age_progress", "elderly_exposure_progress", "next_birth_sequence", "next_treatment_sequence", "treatment"]
	if snapshot.size() != keys.size():
		return {"valid": false}
	for key in keys:
		if not snapshot.has(key):
			return {"valid": false}
	for key in ["total_living", "available", "production_workers", "construction_workers", "medical_workers", "governance_workers", "training_reserved", "children", "elderly", "resident_sick", "unsettled_refugees", "wounded", "fallen", "male_count", "female_count", "unknown_sex_count", "growth_progress", "child_age_progress", "adult_age_progress", "elderly_exposure_progress", "next_birth_sequence", "next_treatment_sequence"]:
		if typeof(snapshot.get(key)) != TYPE_INT or int(snapshot.get(key)) < 0:
			return {"valid": false}
	if int(snapshot.schema_version) != SCHEMA_VERSION or int(snapshot.next_treatment_sequence) <= 0 or int(snapshot.next_birth_sequence) <= 0 or not snapshot.treatment is Dictionary:
		return {"valid": false}
	if int(snapshot.male_count) + int(snapshot.female_count) + int(snapshot.unknown_sex_count) != int(snapshot.total_living):
		return {"valid": false}
	var treatment_value: Dictionary = snapshot.treatment
	var treatment_keys := ["treatment_id", "phase", "count", "progress_milliseconds", "required_milliseconds", "food_cost_committed"]
	if treatment_value.size() != treatment_keys.size():
		return {"valid": false}
	for key in treatment_keys:
		if not treatment_value.has(key):
			return {"valid": false}
	var phase := StringName(treatment_value.get("phase", &""))
	if phase not in [TREATMENT_IDLE, TREATMENT_ACTIVE]:
		return {"valid": false}
	for key in ["count", "progress_milliseconds", "required_milliseconds", "food_cost_committed"]:
		if typeof(treatment_value.get(key)) != TYPE_INT or int(treatment_value.get(key)) < 0:
			return {"valid": false}
	if (
		(phase == TREATMENT_IDLE and (StringName(treatment_value.treatment_id) != &"" or int(treatment_value.count) != 0 or int(treatment_value.progress_milliseconds) != 0 or int(treatment_value.required_milliseconds) != 0 or int(treatment_value.food_cost_committed) != 0))
		or (phase == TREATMENT_ACTIVE and (StringName(treatment_value.treatment_id) == &"" or int(treatment_value.count) <= 0 or int(treatment_value.count) > int(snapshot.wounded) or int(treatment_value.required_milliseconds) <= 0 or int(treatment_value.progress_milliseconds) > int(treatment_value.required_milliseconds)))
	):
		return {"valid": false}
	return {"valid": true, "snapshot": snapshot.duplicate(true)}


func invariant_matches(military_count: int, specialist_count: int) -> bool:
	if military_count < 0 or specialist_count < 0:
		return false
	return total_living == children + elderly + available + production_workers + construction_workers + medical_workers + governance_workers + training_reserved + resident_sick + unsettled_refugees + wounded + military_count + specialist_count
