# Formal candidate usability R1

Baseline: `0da50abe317a9941f661c827c5b511917a081f2e`.

## Goal

Make the existing Blackstone candidate safe to launch and easy to identify,
then verify its established interaction paths without changing campaign,
building, population, or art scope.

## Candidate identity and save ownership

- The launcher derives branch, full commit, dirty state, canonical project path,
  and canonical save directory at launch time. Unknown or direct runs remain
  visibly unidentified; no old commit is used as a fallback.
- A runtime is the same candidate only when project key, commit, dirty state,
  and save key all match. A same-candidate launch reports and attempts to focus
  the existing process.
- The save key is derived from the canonical save directory. Any live writable
  runtime with that key blocks a second writer even when its project checkout or
  commit differs.
- Different commits may coexist only when their save keys differ. Existing
  windows are never terminated by the launcher.
- `RUN_ISOLATED_TXWZS.command` is a thin entry into the same launcher. It creates
  a fresh temporary save root and prints the exact directory so the session can
  be reopened explicitly with `RUN_CURRENT_TXWZS.command --save-dir <path>`.

The V5 persistence coordinator remains the only save owner. Launcher checks are
process-level admission checks, not a second snapshot or event ledger.

## Player-facing identity

The title page shows `Formal Candidate R1` plus the actual abbreviated commit
when launched through the candidate entry. Branch, full commit, project path,
save directory, and launch identifier are available only through an on-demand
development-details disclosure. Direct or malformed launches display `UNKNOWN`.
The native window title follows the active title, city, or battle scene.

## Personnel explanation

Macro-siege settlement freezes a read-only personnel accounting summary after
the existing army, population-recovery, and city-control owners have committed:

`initial military + additions = garrison + field army + wounded + fallen`

The Blackstone campaign's initial military is the existing 20-person starting
garrison. Additions are derived from the authoritative current military and
recovery totals; no resource is granted and no casualty is reclassified. The
battle result separately shows the local equation
`committed = survivors + newly wounded + newly fallen`, so campaign totals and
this battle's losses are not added twice.

## Acceptance and verification

- Same candidate focuses instead of launching a duplicate.
- Different save directories allow independent versions; the same save key is
  rejected, including concurrent launcher attempts.
- Title, city, and battle window identity follow the actual launch commit.
- Empty isolated store supports New Game; a normal exit and reopen supports
  Continue from the same directory.
- Native pointer and keyboard checks cover the formal title, city, map-command,
  battle, result, cancellation, return, pause, and speed surfaces where macOS
  accessibility control can reach them.
- Engine GUI and domain tests retain their separate evidence labels. Three
  existing target resolutions are checked for clipping and interaction state.

Human feel, balance judgement, and Founder acceptance remain separate gates.
