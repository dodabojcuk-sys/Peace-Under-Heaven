# V5 Strategic Time, Pause, War Block, and Scene Matrix Contract V0

## Status and scope

Task: `V5-P2-T004`

Status: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

This contract freezes when city strategic time may advance and therefore when
TrainingQueue may advance. It does not implement an autoload clock, offline
progress, background simulation, new scene lifecycle, or V5-G2 runtime work.

## Sole time authority

The persistent source fields are:

```text
current_day
day_elapsed_milliseconds
city_time_speed_id
manual_pause
war_block_reason
```

The current float `day_elapsed_seconds` remains a compatibility field until a
save-schema migration. Persistent V5 time uses an exact integer millisecond
representation. Display progress and labels are derived.

Only the city strategic-time authority may cross a day boundary. TrainingQueue
completion is a consequence of that boundary and cannot be driven by
`BattleSession`, UI animation, scene `_process`, operating-system time, or
load-time guessing.

## Time-source matrix

| Context | Ordinary frame delta | Strategic time | TrainingQueue | Rule |
| --- | --- | --- | --- | --- |
| City scene active, running | accepted × selected speed | advances | may complete at a crossed day boundary | normal source |
| City scene active, manual pause | ignored | frozen | frozen | UI and map input remain usable |
| Ordinary UI panel/modal open | accepted | advances | may complete | panels do not create implicit pause |
| First-war warning | accepted | advances | may complete | warning is not a block |
| War pending decision | ignored | frozen | frozen | explicit war block |
| Battle scene active | ignored | frozen during live battle | frozen during live battle | no double-counting |
| Authorized battle settlement | terminal duration once | advances by recorded battle duration | may complete for crossed boundaries | coordinator/city atomic entry only |
| Result awaiting acknowledgement | ignored when the war contract blocks | frozen | frozen | acknowledgement is not a second clock |
| Victory/retreat resolved and unblocked | accepted after return | resumes | may complete | no catch-up for blocked wall time |
| Defeat/city-fallen blocked state | ignored | frozen | frozen | later recovery needs a named contract |
| World-map or Blackstone presentation switch without authority handoff | ignored by unloaded presentation | unchanged | unchanged | scene switch is not elapsed time |
| Save/load | no elapsed-time inference | restored exact value | restored exact phase | no offline progress in V5 |
| Test-only explicit day boundary | explicit controlled delta | advances only through the same boundary function | same completion semantics | test helper is not production input |

## Scene-transition rules

1. A scene can render or request time but cannot own the persistent clock.
2. Unloading the city scene must not silently discard or duplicate the clock.
3. V5 does not compute elapsed time from `Time.get_unix_time_from_system()`.
4. A transition record may carry stable scene/context IDs, never a Node
   reference, viewport state, or pixel coordinate.
5. Returning from battle applies the terminal `finished_tick × tick_ms`
   duration exactly once through the authorized settlement transaction.
6. Replaying an already-applied result cannot advance time again.

## Pause and speed rules

- `manual_pause` affects normal city-frame advancement only.
- Speed is one stable allowed ID (`1x`, `2x`, `4x`) mapped to a numeric
  multiplier by configuration.
- Changing speed must be rejected while the war contract blocks time.
- Battle settlement duration is simulation fact and is not multiplied by the
  selected city speed.
- No UI widget stores independent pause or speed truth.

## Boundary ordering

At each crossed strategic day boundary:

1. increment the authoritative day;
2. resolve existing city daily economy in its frozen order;
3. complete eligible TrainingQueue orders through the garrison entry;
4. update threat/war state;
5. emit one read-model refresh.

If any required authoritative write fails, the whole boundary fails and the
pre-boundary time, queue, garrison, resources, and ledgers are restored.

The current runtime ordering remains authoritative until G2. This contract does
not reorder existing P1 systems.

## Invariants

- `0 <= day_elapsed_milliseconds < milliseconds_per_day`;
- normal time does not advance while manually paused or war-blocked;
- the same real frame or settlement cannot be consumed twice;
- training does not advance without strategic time;
- ordinary UI never changes the time source;
- scene presentation cannot synthesize catch-up time;
- all saved time values are exact, finite, and UI-independent.

## G2 acceptance matrix

G2 must test every row above, including:

- pause at one millisecond before a boundary;
- 1×/2×/4× crossing the same boundary;
- war block before and after queue eligibility;
- battle settlement crossing zero, one, and multiple day boundaries;
- duplicate result replay;
- city → world map → city without elapsed-time mutation;
- save/load while paused and while running.
