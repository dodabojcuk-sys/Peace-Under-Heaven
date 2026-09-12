# City Population and Social Pressure R0

## Product scope

This slice extends the existing regular-inner-city authority. It does not
replace the aggregate population model, create resident objects, move field
armies into city jobs, or change the field-theatre and wartime-inner-city
battle implementations.

## Population ownership and conservation

`PopulationRecoveryState` remains the single aggregate population ledger.
Military and specialist identities remain owned by their existing domains and
are included only as read-only counts in the conservation check.

```text
total_living = children
             + elderly
             + available_adults
             + production_workers
             + construction_workers
             + medical_workers
             + governance_workers
             + training_reserved
             + resident_sick
             + unsettled_refugees
             + wounded
             + living_garrison_and_field_armies
             + living_field_specialists
```

Age, sex, health and allocation are different dimensions. R0 stores age as
the mutually exclusive child/adult/elderly projection implied by the ledger.
Sex is an orthogonal aggregate whose male, female and unknown counts equal
`total_living`; it does not change work, training, recovery or recruitment
eligibility. Existing saves have no sex history, so migration preserves the
total and records every existing person as unknown. It never invents a sex
based recruitment or recovery multiplier.

Resident sickness moves a person out of an eligible city allocation into the
exclusive `resident_sick` group. Recovery returns that person to available
adult population. Fallen/dead people reduce `total_living` once and are never
treatable. An active wounded-treatment batch reserves part of the one medical
capacity before refugee and resident disease care are calculated.

## Migration

Campaign schema 15 migration is conservative and deterministic:

- preserve total living, every existing job, training reservation, wound,
  garrison, field army, specialist and cumulative fallen count;
- assign no known historic children or elderly and mark all existing sex as
  unknown;
- move the exact legacy diseased count from available adults into
  `resident_sick`; reject a snapshot that cannot fund that move rather than
  silently vacating historic jobs or inventing people;
- initialize growth, ageing, refugee and social-pressure progress at zero;
- never grant population, soldiers, resources or a favourable event.

## Adjustable R0 development rules

These values are centralized in `blackstone_city_governance_r0.tres` and are
development decisions where the project had no accepted value:

- a healthy, fully fed city with one housing space gains 250 growth progress
  per day; 1,000 progress creates one child;
- child maturation requires 960 child-person-days; adult ageing requires 4,800
  available-adult-person-days and therefore never removes a deployed person;
- sustained food or winter housing exposure warns first. Only configured
  multi-day exposure can create illness or one elderly death;
- medical capacity is shared in this order: already committed wounded care,
  accepted refugee medical burden, then resident sickness;
- the first Blackstone refugee source is a finite nine-person group displaced
  by the configured Blackstone invasion. It has one stable case identity and
  two people needing care. Accept, defer and reject are explicit, durable
  decisions; acceptance adds the group once to `unsettled_refugees`, while
  settlement requires real housing space, releases healthy settled adults to
  availability, and transfers remaining carried illness into the existing
  resident sickness and shared medical-capacity flow;
- public-order pressure accumulates from food, housing, disease and unresolved
  events, and recovers gradually from staffed governance, relief and health.
  Stable stages are petty theft, bandit disruption and local work stoppage.

## Event and transaction boundaries

An event has one stable ID, source/cause, target, current stage and per-stage
effect receipt. Petty theft removes a bounded real stock once. Bandit
disruption targets the regular-city production operation and applies a bounded
50% modifier while unresolved. Severe unrest stops regular-city production and
construction while unresolved, but never transfers Blackstone control or
creates an unsourced battle. If a future
bandit source becomes a field participant, its damage must settle only through
the existing field/battle handoff.

Governance actions address one event or pressure cause. Staffing provides
gradual recovery; relief spends a configured amount once. Neither action
repairs food, housing or health causes by itself. Opening, closing or switching
detail surfaces performs no transaction and advances no time.

## Acceptance and verification

Automated coverage must keep normal development and pressure/recovery flows
separate from direct boundary fixtures. Independent processes restore growth
progress, accepted-but-unsettled refugees, active social events, treatment and
winter pressure without reroll, population fill or duplicate costs. Existing
training, treatment, invasion, strategic support, field R2, macro siege and V5
cold-recovery regressions remain required. Engine GUI evidence is not human
normal-speed acceptance; that gate remains `OPEN`.
