class_name RegularCampaignRules
extends RefCounted


## Pure, deterministic policy helpers for the Regular Campaign R1 controller.
##
## This class deliberately owns neither campaign time nor any save/resource/army
## state.  The caller advances `mainline_elapsed_ms` through the authoritative
## simulation clock, persists the returned `state`, and supplies already
## resolved production and force facts.  In particular, `effective_food_yield`
## must be the operational yield after roads, workers, health, and capacity.

const RISK_STABLE := &"STABLE"
const RISK_WARNING := &"WARNING"
const RISK_SHORTAGE := &"SHORTAGE"

const DEFAULT_CYCLE_MS := 180000
const MAX_FORECAST_CYCLES := 12
const ASSESSMENT_INTERVAL_MS := 15000
const BASE_WINDOW_MS := 1800000
const MAX_HISTORY_EXTENSION_MS := 900000
const MAX_PREPAREDNESS_EXTENSION_MS := 600000
const HISTORY_MIN_PERMILLE := 750
const HISTORY_MAX_PERMILLE := 1250
const STAGE_STEP_MS := 600000
const MAX_PRESSURE_STAGE := 4
const RECOVERY_CREDIT_PER_COMBAT_LOSS_MS := 60000
const MAX_RECOVERY_CREDIT_MS := 600000
const EXPECTED_READY_MILITARY := 20
const MILITARY_PREPAREDNESS_EXTENSION_MS := 180000
const WOUNDED_PREPAREDNESS_EXTENSION_MS := 180000
const FOOD_PREPAREDNESS_EXTENSION_MS := 240000


## Forecasts the next bounded set of local ration/harvest events without
## writing any world state.  A meal at the same instant as harvest is paid
## first, preserving the existing periodic-economy ordering.
static func forecast(
	food: int,
	capacity: int,
	yield_per_cycle: int,
	consumption_per_cycle: int,
	until_harvest_ms: int,
	until_meal_ms: int,
	cycle_ms: int = DEFAULT_CYCLE_MS
) -> Dictionary:
	var normalized_cycle := maxi(cycle_ms, 1)
	var storage_capacity := maxi(capacity, 0)
	var stock := clampi(maxi(food, 0), 0, storage_capacity)
	var starting_stock := stock
	var effective_yield := maxi(yield_per_cycle, 0)
	var effective_consumption := maxi(consumption_per_cycle, 0)
	var harvest_at := maxi(until_harvest_ms, 0)
	var meal_at := maxi(until_meal_ms, 0)
	var horizon_ms := normalized_cycle * MAX_FORECAST_CYCLES
	var deficit_ms := -1
	var harvest_events := 0
	var meal_events := 0
	var reasons: Array[StringName] = []

	# There can be one meal and one harvest per simulated cycle.  The explicit
	# counter prevents malformed schedules from expanding the forecast horizon.
	while (harvest_events < MAX_FORECAST_CYCLES and harvest_at <= horizon_ms) \
		or (meal_events < MAX_FORECAST_CYCLES and meal_at <= horizon_ms):
		var event_at := mini(
			harvest_at if harvest_events < MAX_FORECAST_CYCLES else horizon_ms + 1,
			meal_at if meal_events < MAX_FORECAST_CYCLES else horizon_ms + 1
		)
		if event_at > horizon_ms:
			break
		# Legacy periodic order: consume before harvesting when both are due.
		if meal_events < MAX_FORECAST_CYCLES and meal_at == event_at:
			meal_events += 1
			if stock < effective_consumption and deficit_ms < 0:
				deficit_ms = event_at
				_retain_reason(reasons, &"MEAL_BEFORE_HARVEST_DEFICIT")
			stock = maxi(stock - effective_consumption, 0)
			meal_at += normalized_cycle
		if harvest_events < MAX_FORECAST_CYCLES and harvest_at == event_at:
			harvest_events += 1
			var before_harvest := stock
			stock = mini(storage_capacity, stock + effective_yield)
			if stock - before_harvest < effective_yield:
				_retain_reason(reasons, &"HARVEST_CAPACITY_LIMIT")
			harvest_at += normalized_cycle

	var net := effective_yield - effective_consumption
	if effective_yield <= 0:
		_retain_reason(reasons, &"NO_EFFECTIVE_FOOD_YIELD")
	if net < 0:
		_retain_reason(reasons, &"NEGATIVE_FOOD_NET")
	if deficit_ms >= 0:
		_retain_reason(reasons, &"FORECAST_DEFICIT")
	var runway_cycles := _runway_cycles(starting_stock, effective_consumption, effective_yield)
	var risk_id := RISK_STABLE
	if deficit_ms >= 0 and deficit_ms <= maxi(until_meal_ms, 0):
		risk_id = RISK_SHORTAGE
	elif net < 0 and runway_cycles <= 2:
		risk_id = RISK_WARNING
		_retain_reason(reasons, &"NEGATIVE_NET_SHORT_RUNWAY")
	elif net >= 0 and deficit_ms >= 0:
		risk_id = RISK_WARNING
		_retain_reason(reasons, &"HARVEST_GAP_RISK")
	elif net >= 0 and stock < effective_consumption:
		# Average production cannot erase a concrete first-meal gap.  This branch
		# is normally reached only when no meal occurs inside the bounded horizon.
		risk_id = RISK_WARNING
		_retain_reason(reasons, &"LOW_STOCK_BEFORE_NEXT_MEAL")
	return {
		"risk_id": risk_id,
		"deficit_ms": deficit_ms,
		"yield": effective_yield,
		"consumption": effective_consumption,
		"net": net,
		"training_permille": _food_training_permille(risk_id),
		"growth_permille": _food_growth_permille(risk_id),
		"reasons": reasons,
		"horizon_ms": horizon_ms,
		"runway_cycles": runway_cycles,
	}


## Reads only completed, uniquely settled historical mainlines.  Each usable
## duration is normalized against its own authored baseline then clamped, so a
## single speedrun or stalled campaign cannot dictate an unbounded future window.
static func summarize_confirmed_history(entries: Array, default_base_window_ms: int = BASE_WINDOW_MS) -> Dictionary:
	var normalized_values: Array[int] = []
	var settlement_ids: Dictionary = {}
	for value in entries:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		if not bool(entry.get("confirmed", false)):
			continue
		var settlement_id := StringName(entry.get("settlement_id", &""))
		var elapsed_ms := int(entry.get("elapsed_ms", -1))
		var baseline_ms := int(entry.get("base_window_ms", entry.get("baseline_ms", default_base_window_ms)))
		if settlement_id == &"" or settlement_ids.has(settlement_id) or elapsed_ms <= 0 or baseline_ms <= 0:
			continue
		settlement_ids[settlement_id] = true
		var normalized := clampi(
			int((elapsed_ms * 1000) / baseline_ms),
			HISTORY_MIN_PERMILLE,
			HISTORY_MAX_PERMILLE
		)
		normalized_values.append(normalized)
	var total := 0
	for normalized in normalized_values:
		total += normalized
	var average := 1000 if normalized_values.is_empty() else int(total / normalized_values.size())
	return {
		"count": normalized_values.size(),
		"normalized_permille": average,
		"settlement_ids": settlement_ids.keys(),
	}


## Produces the next persisted rule state with the current activity modifiers at
## its top level. The function is safe to call repeatedly; before `next_eval_ms`
## it returns a deep copy of the supplied state and does not consume recovery
## credit.
static func evaluate(state: Dictionary, facts: Dictionary, config: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var base_window_ms := maxi(int(config.get("base_window_ms", BASE_WINDOW_MS)), 1)
	var interval_ms := maxi(int(config.get("assessment_interval_ms", ASSESSMENT_INTERVAL_MS)), 1)
	var now_ms := maxi(int(next_state.get("mainline_elapsed_ms", 0)), 0)
	var history_entries: Array = Array(next_state.get("settlement_history", next_state.get("history", [])))
	var history := summarize_confirmed_history(history_entries, base_window_ms)
	var history_window_ms := int((base_window_ms * int(history.normalized_permille)) / 1000)
	var maximum_window_ms := history_window_ms + MAX_HISTORY_EXTENSION_MS
	var existing_window := int(next_state.get("promised_window_ms", history_window_ms))
	# Actual force, recovery, and operational food facts may grant preparation
	# room once, but never move the deadline from the current time or exceed the
	# public 15-minute cap. A later farm completion can only retain this promise.
	var preparedness_extension_ms := _preparedness_extension_ms(facts, config)
	var target_window_ms := history_window_ms + preparedness_extension_ms
	# A corrupted/outdated state is repaired to the current public hard limit;
	# valid state thereafter only grows, never resets from a new assessment.
	var promised_window_ms := clampi(maxi(existing_window, target_window_ms), history_window_ms, maximum_window_ms)
	var last_assessment_ms := int(next_state.get("last_assessment_ms", -interval_ms))
	var due := now_ms >= last_assessment_ms + interval_ms
	if due:
		last_assessment_ms = now_ms
		var observed_losses := maxi(int(next_state.get("observed_combat_losses", 0)), 0)
		var cumulative_losses := maxi(int(facts.get("new_combat_losses", 0)), 0)
		var genuine_new_losses := maxi(cumulative_losses - observed_losses, 0)
		observed_losses = maxi(observed_losses, cumulative_losses)
		var consumed_credit := maxi(int(next_state.get("recovery_credit_consumed_ms", 0)), 0)
		var prior_credit_balance := maxi(int(next_state.get("recovery_credit_balance_ms", 0)), 0)
		var awarded_credit := mini(
			genuine_new_losses * RECOVERY_CREDIT_PER_COMBAT_LOSS_MS,
			maxi(MAX_RECOVERY_CREDIT_MS - consumed_credit - prior_credit_balance, 0)
		)
		var credit_balance := prior_credit_balance + awarded_credit
		var raw_late_ms := maxi(now_ms - promised_window_ms, 0)
		var prior_raw_late_ms := maxi(int(next_state.get("last_raw_late_ms", 0)), 0)
		var new_late_ms := maxi(raw_late_ms - prior_raw_late_ms, 0)
		# Credit compensates only newly accrued lateness. Re-evaluation at the
		# same elapsed time cannot consume the balance again.
		var applied_credit := mini(new_late_ms, credit_balance)
		credit_balance -= applied_credit
		var effective_late_ms := maxi(raw_late_ms - consumed_credit - applied_credit, 0)
		var desired_stage := clampi(int(effective_late_ms / STAGE_STEP_MS), 0, MAX_PRESSURE_STAGE)
		var previous_stage := clampi(int(next_state.get("pressure_stage", 0)), 0, MAX_PRESSURE_STAGE)
		var recovery_streak := 0
		var pressure_stage := previous_stage
		if desired_stage > previous_stage:
			pressure_stage = mini(previous_stage + 1, desired_stage)
		elif desired_stage < previous_stage:
			recovery_streak = maxi(int(next_state.get("pressure_recovery_streak", 0)), 0) + 1
			if recovery_streak >= 2:
				pressure_stage = previous_stage - 1
				recovery_streak = 0
		else:
			recovery_streak = 0
		next_state["observed_combat_losses"] = observed_losses
		next_state["recovery_credit_balance_ms"] = credit_balance
		next_state["recovery_credit_consumed_ms"] = consumed_credit + applied_credit
		next_state["last_raw_late_ms"] = raw_late_ms
		next_state["pressure_stage"] = pressure_stage
		next_state["pressure_recovery_streak"] = recovery_streak
		next_state["last_assessment_ms"] = last_assessment_ms
	next_state["mainline_elapsed_ms"] = now_ms
	next_state["promised_window_ms"] = promised_window_ms
	next_state["preparedness_extension_ms"] = preparedness_extension_ms
	next_state["history_normalized_permille"] = int(history.normalized_permille)
	next_state["history_confirmed_count"] = int(history.count)
	next_state["next_eval_ms"] = last_assessment_ms + interval_ms

	var food_risk := _food_risk_from_facts(facts)
	var stage := clampi(int(next_state.get("pressure_stage", 0)), 0, MAX_PRESSURE_STAGE)
	var pressure_modifiers := _pressure_modifiers(stage)
	var food_training := _food_training_permille(food_risk)
	var food_growth := _food_growth_permille(food_risk)
	var recovery_reason := _recovery_reason(facts, food_risk, int(next_state.get("recovery_credit_balance_ms", 0)))
	next_state["construction_permille"] = int(pressure_modifiers.construction_permille)
	next_state["nonessential_construction_permille"] = int(pressure_modifiers.nonessential_construction_permille)
	next_state["growth_permille"] = mini(int(pressure_modifiers.growth_permille), food_growth)
	next_state["basic_training_permille"] = mini(int(pressure_modifiers.basic_training_permille), food_training)
	next_state["pressure_stage"] = stage
	# `stage` is retained as the compact controller-facing alias. The longer key
	# makes the persisted meaning unambiguous for future callers.
	next_state["stage"] = stage
	next_state["food_risk_id"] = food_risk
	next_state["recovery_reason"] = recovery_reason
	next_state["total_military"] = maxi(int(facts.get("total_military", 0)), 0)
	next_state["effective_late_ms"] = maxi(
		now_ms - promised_window_ms - int(next_state.get("recovery_credit_consumed_ms", 0)),
		0
	)
	return next_state


## Validates the persisted portion of an evaluated pressure result.  Runtime
## snapshots supply resolved food facts; this helper deliberately does not own
## campaign state or inspect any city/controller object.
static func validate_pressure_schema(
	pressure: Dictionary,
	history_entries: Array,
	combat_losses_total: int,
	mainline_elapsed_ms: int,
	base_window_ms: int = BASE_WINDOW_MS
) -> bool:
	var required := [
		"mainline_elapsed_ms", "history", "promised_window_ms", "preparedness_extension_ms",
		"history_normalized_permille", "history_confirmed_count", "next_eval_ms",
		"observed_combat_losses", "recovery_credit_balance_ms",
		"recovery_credit_consumed_ms", "last_raw_late_ms", "pressure_stage",
		"pressure_recovery_streak", "last_assessment_ms", "construction_permille",
		"nonessential_construction_permille", "growth_permille",
		"basic_training_permille", "stage", "food_risk_id", "recovery_reason",
		"total_military", "effective_late_ms",
	]
	if pressure.size() != required.size():
		return false
	for key in required:
		if not pressure.has(key):
			return false
	if not pressure.history is Array or Array(pressure.history) != history_entries:
		return false
	for key in [
		"mainline_elapsed_ms", "promised_window_ms", "preparedness_extension_ms",
		"history_normalized_permille", "history_confirmed_count", "next_eval_ms",
		"observed_combat_losses", "recovery_credit_balance_ms",
		"recovery_credit_consumed_ms", "last_raw_late_ms", "pressure_stage",
		"pressure_recovery_streak", "last_assessment_ms", "construction_permille",
		"nonessential_construction_permille", "growth_permille",
		"basic_training_permille", "stage", "total_military", "effective_late_ms",
	]:
		if typeof(pressure[key]) != TYPE_INT or int(pressure[key]) < 0:
			return false
	if (
		typeof(pressure.food_risk_id) != TYPE_STRING_NAME
		or typeof(pressure.recovery_reason) != TYPE_STRING_NAME
	):
		return false
	var now_ms := maxi(mainline_elapsed_ms, 0)
	if int(pressure.mainline_elapsed_ms) != now_ms:
		return false
	var history := summarize_confirmed_history(history_entries, base_window_ms)
	var history_window_ms := int((base_window_ms * int(history.normalized_permille)) / 1000)
	if (
		int(pressure.history_normalized_permille) != int(history.normalized_permille)
		or int(pressure.history_confirmed_count) != int(history.count)
		or int(pressure.promised_window_ms) < history_window_ms
		or int(pressure.promised_window_ms) > history_window_ms + MAX_HISTORY_EXTENSION_MS
		or int(pressure.preparedness_extension_ms) > MAX_PREPAREDNESS_EXTENSION_MS
		or int(pressure.observed_combat_losses) > maxi(combat_losses_total, 0)
		or int(pressure.recovery_credit_balance_ms) + int(pressure.recovery_credit_consumed_ms) > MAX_RECOVERY_CREDIT_MS
		or int(pressure.last_assessment_ms) > now_ms
		or int(pressure.next_eval_ms) != int(pressure.last_assessment_ms) + ASSESSMENT_INTERVAL_MS
		or now_ms >= int(pressure.next_eval_ms)
	):
		return false
	var stage := int(pressure.stage)
	var expected_effective_late := maxi(
		int(pressure.last_assessment_ms) - int(pressure.promised_window_ms) - int(pressure.recovery_credit_consumed_ms),
		0
	)
	if (
		stage != int(pressure.pressure_stage)
		or stage > MAX_PRESSURE_STAGE
		# `promised_window_ms` can grow between scheduled assessments when a new
		# wound/food fact grants bounded preparation room.  In that interval the
		# prior raw-late observation still refers to the earlier, smaller promise.
		or int(pressure.last_raw_late_ms) > maxi(int(pressure.last_assessment_ms) - history_window_ms, 0)
		or stage < clampi(int(expected_effective_late / STAGE_STEP_MS), 0, MAX_PRESSURE_STAGE)
		or int(pressure.effective_late_ms) != maxi(now_ms - int(pressure.promised_window_ms) - int(pressure.recovery_credit_consumed_ms), 0)
	):
		return false
	var risk := StringName(pressure.food_risk_id)
	if risk not in [RISK_STABLE, RISK_WARNING, RISK_SHORTAGE]:
		return false
	var modifiers := _pressure_modifiers(stage)
	if (
		int(pressure.construction_permille) != int(modifiers.construction_permille)
		or int(pressure.nonessential_construction_permille) != int(modifiers.nonessential_construction_permille)
		or int(pressure.growth_permille) != mini(int(modifiers.growth_permille), _food_growth_permille(risk))
		or int(pressure.basic_training_permille) != mini(int(modifiers.basic_training_permille), _food_training_permille(risk))
		or StringName(pressure.recovery_reason) not in [&"RESTORE_LOCAL_FOOD", &"STABILIZE_LOCAL_FOOD", &"TREAT_WOUNDED", &"USE_FINITE_COMBAT_RECOVERY", &"ADVANCE_MAINLINE"]
	):
		return false
	return true


static func validate_pressure_snapshot(
	pressure: Dictionary,
	history_entries: Array,
	combat_losses_total: int,
	facts: Dictionary,
	base_window_ms: int = BASE_WINDOW_MS
) -> bool:
	if not validate_pressure_schema(pressure, history_entries, combat_losses_total, int(facts.get("mainline_elapsed_ms", -1)), base_window_ms):
		return false
	var stage := int(pressure.stage)
	var food_risk := _food_risk_from_facts(facts)
	if StringName(pressure.food_risk_id) != food_risk:
		return false
	var modifiers := _pressure_modifiers(stage)
	if (
		int(pressure.construction_permille) != int(modifiers.construction_permille)
		or int(pressure.nonessential_construction_permille) != int(modifiers.nonessential_construction_permille)
		or int(pressure.growth_permille) != mini(int(modifiers.growth_permille), _food_growth_permille(food_risk))
		or int(pressure.basic_training_permille) != mini(int(modifiers.basic_training_permille), _food_training_permille(food_risk))
		or StringName(pressure.recovery_reason) != _recovery_reason(facts, food_risk, int(pressure.recovery_credit_balance_ms))
	):
		return false
	return true


static func _food_risk_from_facts(facts: Dictionary) -> StringName:
	var forecast_fact: Dictionary = Dictionary(facts.get("food_forecast", {}))
	var risk := StringName(forecast_fact.get("risk_id", RISK_STABLE))
	if risk != RISK_STABLE and risk != RISK_WARNING and risk != RISK_SHORTAGE:
		risk = RISK_STABLE
	var effective_yield := maxi(int(facts.get("effective_food_yield", 0)), 0)
	var required := maxi(int(facts.get("food_required", 0)), 0)
	var stock := maxi(int(facts.get("food_stock", 0)), 0)
	if risk == RISK_STABLE and effective_yield < required and stock == 0:
		return RISK_SHORTAGE
	return risk


static func _preparedness_extension_ms(facts: Dictionary, config: Dictionary) -> int:
	var expected_military := maxi(int(config.get("expected_ready_military", EXPECTED_READY_MILITARY)), 1)
	var total_military := maxi(int(facts.get("total_military", 0)), 0)
	var military_gap := clampi(expected_military - total_military, 0, expected_military)
	var military_extension := int(
		(MILITARY_PREPAREDNESS_EXTENSION_MS * military_gap) / expected_military
	)
	var wounded := maxi(int(facts.get("wounded", 0)), 0)
	var wounded_extension := mini(
		WOUNDED_PREPAREDNESS_EXTENSION_MS,
		wounded * int(config.get("wounded_extension_per_person_ms", 30000))
	)
	var food_risk := _food_risk_from_facts(facts)
	var food_extension := 0
	if food_risk == RISK_SHORTAGE:
		food_extension = FOOD_PREPAREDNESS_EXTENSION_MS
	elif food_risk == RISK_WARNING:
		food_extension = int(FOOD_PREPAREDNESS_EXTENSION_MS / 2)
	var configured_cap := clampi(
		int(config.get("max_preparedness_extension_ms", MAX_PREPAREDNESS_EXTENSION_MS)),
		0,
		MAX_HISTORY_EXTENSION_MS
	)
	return mini(military_extension + wounded_extension + food_extension, configured_cap)


static func _pressure_modifiers(stage: int) -> Dictionary:
	match clampi(stage, 0, MAX_PRESSURE_STAGE):
		0:
			return {"construction_permille": 1000, "nonessential_construction_permille": 1000, "growth_permille": 1000, "basic_training_permille": 1000}
		1:
			return {"construction_permille": 850, "nonessential_construction_permille": 800, "growth_permille": 800, "basic_training_permille": 850}
		2:
			return {"construction_permille": 700, "nonessential_construction_permille": 500, "growth_permille": 600, "basic_training_permille": 700}
		3:
			return {"construction_permille": 500, "nonessential_construction_permille": 200, "growth_permille": 400, "basic_training_permille": 550}
		_:
			return {"construction_permille": 0, "nonessential_construction_permille": 0, "growth_permille": 200, "basic_training_permille": 250}


static func _food_training_permille(risk_id: StringName) -> int:
	if risk_id == RISK_SHORTAGE:
		return 250
	if risk_id == RISK_WARNING:
		return 600
	return 1000


static func _food_growth_permille(risk_id: StringName) -> int:
	if risk_id == RISK_SHORTAGE:
		return 200
	if risk_id == RISK_WARNING:
		return 500
	return 1000


static func _recovery_reason(facts: Dictionary, food_risk: StringName, available_credit_ms: int) -> StringName:
	if food_risk == RISK_SHORTAGE:
		return &"RESTORE_LOCAL_FOOD"
	if food_risk == RISK_WARNING:
		return &"STABILIZE_LOCAL_FOOD"
	if maxi(int(facts.get("wounded", 0)), 0) > 0:
		return &"TREAT_WOUNDED"
	if available_credit_ms > 0:
		return &"USE_FINITE_COMBAT_RECOVERY"
	return &"ADVANCE_MAINLINE"


static func _runway_cycles(stock: int, consumption: int, yield_amount: int) -> int:
	if consumption <= 0:
		return MAX_FORECAST_CYCLES
	if yield_amount >= consumption:
		return MAX_FORECAST_CYCLES
	return int(maxi(stock, 0) / maxi(consumption - yield_amount, 1))


static func _retain_reason(reasons: Array[StringName], reason: StringName) -> void:
	if not reasons.has(reason):
		reasons.append(reason)
