extends SceneTree


const RULES = preload("res://scripts/regular_campaign/regular_campaign_rules.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_food_forecast()
	_check_history()
	_check_pressure()
	_check_credit_cadence_and_adaptation()
	print("REGULAR_CAMPAIGN_RULES_R1_RESULTS assertions=%d" % assertions)
	_finish()


func _check_food_forecast() -> void:
	var actual_farm_offline: Dictionary = RULES.forecast(40, 100, 0, 20, 0, 0)
	var actual_farm_online: Dictionary = RULES.forecast(40, 100, 30, 20, 0, 0)
	_check(
		actual_farm_offline.risk_id != RULES.RISK_STABLE
			and actual_farm_online.risk_id == RULES.RISK_STABLE,
		"forecast distinguishes an unfinished/unworked farm by actual yield, never nominal farm count"
	)
	var negative_stock: Dictionary = RULES.forecast(-5, 100, 0, 10, 180000, 90000)
	_check(
		negative_stock.deficit_ms == 90000 and negative_stock.risk_id == RULES.RISK_SHORTAGE,
		"invalid negative stock is treated as empty and only fails at the first unpaid meal, not at time zero"
	)
	var harvest_gap: Dictionary = RULES.forecast(5, 100, 20, 10, 60000, 30000)
	_check(
		harvest_gap.net > 0 and harvest_gap.deficit_ms == 30000
			and harvest_gap.risk_id == RULES.RISK_SHORTAGE,
		"positive average yield still exposes a meal-before-harvest gap"
	)
	var long_runway: Dictionary = RULES.forecast(100, 100, 0, 10, 0, 180000)
	var short_runway: Dictionary = RULES.forecast(20, 100, 0, 10, 0, 180000)
	_check(
		long_runway.risk_id == RULES.RISK_STABLE
			and short_runway.risk_id == RULES.RISK_WARNING
			and short_runway.runway_cycles == 2,
		"negative average supply stays stable while stocked and warns only at a two-cycle runway"
	)


func _check_history() -> void:
	var source_entries: Array = [
		{"confirmed": true, "settlement_id": &"a", "elapsed_ms": 900000, "base_window_ms": 1800000},
		{"confirmed": true, "settlement_id": &"a", "elapsed_ms": 9000000, "base_window_ms": 1800000},
		{"confirmed": false, "settlement_id": &"b", "elapsed_ms": 9000000, "base_window_ms": 1800000},
		{"confirmed": true, "settlement_id": &"c", "elapsed_ms": 9000000, "base_window_ms": 1800000},
		{"confirmed": true, "settlement_id": &"missing_elapsed"},
	]
	var history: Dictionary = RULES.summarize_confirmed_history(source_entries)
	_check(
		history.count == 2 and history.normalized_permille == 1000,
		"history uses unique confirmed settlements only and clamps fast/slow durations to 75-125 percent"
	)
	_check(
		source_entries.size() == 5 and int(source_entries[0].elapsed_ms) == 900000,
		"history helper never mutates its persisted-entry input"
	)


func _check_pressure() -> void:
	var base_facts := {
		"total_military": 30,
		"wounded": 0,
		"new_combat_losses": 0,
		"food_forecast": {"risk_id": RULES.RISK_STABLE},
		"effective_food_yield": 20,
		"food_required": 20,
		"food_stock": 40,
	}
	var initial := RULES.evaluate({"mainline_elapsed_ms": 1500000}, base_facts)
	_check(
		initial.pressure_stage == 0 and initial.promised_window_ms == RULES.BASE_WINDOW_MS,
		"initial preparation permits a deliberate 25-minute route with the default 30-minute promise"
	)
	var dispatch_facts: Dictionary = base_facts.duplicate(true)
	dispatch_facts["home_military"] = 0
	dispatch_facts["deployed_military"] = 30
	var dispatched := RULES.evaluate({"mainline_elapsed_ms": 1500000}, dispatch_facts)
	_check(
		dispatched.pressure_stage == initial.pressure_stage
			and dispatched.total_military == 30
			and dispatched.recovery_reason == initial.recovery_reason,
		"dispatching the same force out of home is not interpreted as a weakness or a recovery event"
	)
	var pressure_state: Dictionary = {"mainline_elapsed_ms": 3600000}
	var first_late := RULES.evaluate(pressure_state, base_facts)
	pressure_state = first_late
	pressure_state.mainline_elapsed_ms = 4215000
	var second_late := RULES.evaluate(pressure_state, base_facts)
	_check(
		first_late.pressure_stage == 1 and second_late.pressure_stage >= first_late.pressure_stage,
		"late pressure rises in bounded stages and does not reset the promised window"
	)
	var recovered_state: Dictionary = second_late.duplicate(true)
	recovered_state.mainline_elapsed_ms = 4230000
	var loss_facts: Dictionary = base_facts.duplicate(true)
	loss_facts["new_combat_losses"] = 2
	var first_credit := RULES.evaluate(recovered_state, loss_facts)
	recovered_state = first_credit
	recovered_state.mainline_elapsed_ms = 4245000
	var repeated_loss := RULES.evaluate(recovered_state, loss_facts)
	_check(
		int(first_credit.recovery_credit_consumed_ms) + int(first_credit.recovery_credit_balance_ms)
			== int(repeated_loss.recovery_credit_consumed_ms) + int(repeated_loss.recovery_credit_balance_ms),
		"only newly observed cumulative combat losses earn finite credit; retries cannot mint it again"
	)
	var assessed_late := RULES.evaluate({"mainline_elapsed_ms": 2145000, "history": []}, base_facts)
	var between_assessments: Dictionary = assessed_late.duplicate(true)
	between_assessments.mainline_elapsed_ms = 2148250
	var wounded_facts: Dictionary = base_facts.duplicate(true)
	wounded_facts["wounded"] = 1
	var widened_after_wound := RULES.evaluate(between_assessments, wounded_facts)
	_check(
		int(widened_after_wound.last_raw_late_ms) > int(widened_after_wound.last_assessment_ms) - int(widened_after_wound.promised_window_ms)
			and RULES.validate_pressure_schema(widened_after_wound, [], 0, int(widened_after_wound.mainline_elapsed_ms)),
		"a new wound may widen the bounded promise between assessments without invalidating the prior raw-late observation"
	)
	var exhausted_credit_state := {"mainline_elapsed_ms": 4500000, "recovery_credit_consumed_ms": RULES.MAX_RECOVERY_CREDIT_MS}
	var later_losses: Dictionary = base_facts.duplicate(true)
	later_losses["new_combat_losses"] = 99
	var exhausted_credit := RULES.evaluate(exhausted_credit_state, later_losses)
	_check(
		int(exhausted_credit.recovery_credit_balance_ms) == 0
			and int(exhausted_credit.recovery_credit_consumed_ms) == RULES.MAX_RECOVERY_CREDIT_MS,
		"recovery credit has a campaign-wide total cap even after earlier credit was consumed"
	)
	var final_state: Dictionary = {"mainline_elapsed_ms": 4500000, "pressure_stage": 4}
	var final_result := RULES.evaluate(final_state, base_facts)
	_check(
		final_result.nonessential_construction_permille == 0
			and final_result.construction_permille == 0
			and final_result.growth_permille >= 200
			and final_result.basic_training_permille >= 250,
		"the final stage stops nonessential construction while retaining basic growth and training floors"
	)
	var paused_copy: Dictionary = final_result.duplicate(true)
	var paused_again := RULES.evaluate(paused_copy, base_facts)
	_check(
		paused_again == paused_copy,
		"calling pure assessment without externally advancing mainline time cannot simulate pause-time pressure"
	)


func _check_credit_cadence_and_adaptation() -> void:
	var stable_facts := {
		"total_military": 30,
		"wounded": 0,
		"new_combat_losses": 10,
		"food_forecast": {"risk_id": RULES.RISK_STABLE},
		"effective_food_yield": 20,
		"food_required": 20,
		"food_stock": 40,
	}
	var stepped: Dictionary = RULES.evaluate({"mainline_elapsed_ms": RULES.BASE_WINDOW_MS}, stable_facts)
	for elapsed in [1815000, 1830000, 1845000, 1860000]:
		stepped.mainline_elapsed_ms = elapsed
		stepped = RULES.evaluate(stepped, stable_facts)
	var jumped: Dictionary = RULES.evaluate({"mainline_elapsed_ms": RULES.BASE_WINDOW_MS}, stable_facts)
	jumped.mainline_elapsed_ms = 1860000
	jumped = RULES.evaluate(jumped, stable_facts)
	_check(
		int(stepped.recovery_credit_consumed_ms) == int(jumped.recovery_credit_consumed_ms)
			and int(stepped.recovery_credit_balance_ms) == int(jumped.recovery_credit_balance_ms)
			and int(stepped.effective_late_ms) == int(jumped.effective_late_ms),
		"15-second assessments and one equal long advance consume the same finite recovery credit"
	)
	var strong := stable_facts.duplicate(true)
	strong.new_combat_losses = 0
	var weak := stable_facts.duplicate(true)
	weak.total_military = 4
	weak.wounded = 4
	weak.food_forecast = {"risk_id": RULES.RISK_SHORTAGE}
	weak.effective_food_yield = 0
	weak.food_required = 20
	weak.food_stock = 0
	var strong_window := RULES.evaluate({"mainline_elapsed_ms": 0}, strong)
	var weak_window := RULES.evaluate({"mainline_elapsed_ms": 0}, weak)
	_check(
		int(strong_window.preparedness_extension_ms) == 0
			and int(weak_window.preparedness_extension_ms) > 0
			and int(weak_window.promised_window_ms) > int(strong_window.promised_window_ms)
			and int(weak_window.promised_window_ms) <= RULES.BASE_WINDOW_MS + RULES.MAX_HISTORY_EXTENSION_MS,
		"total deployed-inclusive force, wounds, and operational food facts grant only a capped initial preparation buffer"
	)
	var endlessly_late: Dictionary = {"mainline_elapsed_ms": RULES.BASE_WINDOW_MS + 4 * RULES.STAGE_STEP_MS}
	for elapsed in [4215000, 4230000, 4245000]:
		endlessly_late = RULES.evaluate(endlessly_late, strong)
		endlessly_late.mainline_elapsed_ms = elapsed
	endlessly_late = RULES.evaluate(endlessly_late, strong)
	_check(
		int(endlessly_late.pressure_stage) == 4
			and int(endlessly_late.construction_permille) == 0,
		"unbounded waiting reaches final pressure despite the finite adaptive preparation buffer"
	)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_RULES_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("REGULAR_CAMPAIGN_RULES_R1_SMOKE FAIL: %s" % failure)
	quit(1)
