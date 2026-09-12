# Wartime spatial battle R1

Status: implemented and verified in the engine. Human play acceptance is OPEN.
Base: `45018750a6bc7e2aa2c3c351dad7c4276e7f45e2`.

## Product scope and ownership

Normal city, persistent field theatre and temporary wartime instance remain
separate. Macro assault presents the exterior and target gates only; it does
not unlock construction inside the enemy's normal city. Population expansion
is deferred. The spatial runtime serves `MACRO_SIEGE` and `WARTIME_DEFENSE`.
First-war/noticeboard legacy C0 missions retain their historical runtime.
Their two-route tests are not the acceptance contract for these spatial battles.

`BattleSession` owns integer positions, navigation targets, work assignments
and timed effects. Scene controls only project state and submit commands.
Existing force snapshots, living-member HP, damage coefficients, resource and
energy transactions, checkpoint owner and one-time result writer are reused.
No second save owner, duplicated army or scene-node serialization is added.
The same handed-off field enemy remains frozen until settlement.

## Player interaction and geometry

Select a formation on the map or roster. Before activation, click a green
staging node to create its deployment draft. Invalid deployment clears that
formation's stale draft. Starting commits the existing formations and actual
HP at those positions. Click a visible work site, choose its existing crew,
and confirm the resource-priced plan before starting.

During battle, click a route node to move or a known enemy/gate to attack.
Hold fights from the current position; retreat travels to the connected
outside/inside evacuation edge and remains vulnerable in transit. The global
exit confirmation uses the existing accelerated full-retreat settlement.
Invalid commands report a reason without submitting a replacement order.
The scrollable right inspector shows selection, coordinates, task, HP and
recent damage cause without covering the map.

The graybox uses two horizontal corridors at y=24/64, cross connections at
x=20/60/100, and a wall at x=80. Logical coordinates use integer sixteenths.
Motion is continuous along the graph on fixed 250 ms battle ticks; there is
no turn-based tile movement. Closed gates disconnect inside and outside.
Cross-route movement changes travel distance and actual engagement; the
formation's frozen source-route identity never changes. An already breached
macro side gate remains a legal flank rather than being silently restored.

Range uses Manhattan distance: infantry 10, defensive parapet 28, hostile
gate defenders 12, towers 36, work 8, medical station 36. Parapet and tower
arrows explicitly may cross a gate; ordinary movement and infantry attacks
cannot. UI diamonds and corridor fields use this same metric. Enemy approach
stops for actual melee engagement or an active barricade footprint.

## Works and support

| Work | Position and actual effect |
| --- | --- |
| Arrow tower | Defense x=84, assault x=60; fires at living enemies within 36 |
| Barricade | Gate approach x=76; arrests incoming enemies at its outer footprint, where it can be attacked |
| Spike trap | Exterior x=60; consumed by a living enemy entering its trigger range |
| Observation post | Interior x=100; completed post reveals its corridor using existing intel rules |
| Siege ram | Exterior x=76; crew must approach and finish preparation before gate damage |

Crews physically travel within work range. Assigned work occupies their
combat action; death, retreat or another command interrupts it. Existing
paid repair can resume interrupted/damaged works. Gate repair also assigns a
live reachable crew. Materials are never refunded by reloading. Destruction
during repair normalizes its progress envelope so the strict snapshot remains
restorable. Work records belong only to this battle and cannot become field
facilities or normal-city buildings.

Physician healing restores only partial HP of living members within the
staging medical radius and legal line of sight. Strategist haste changes
actual travel, attack/protection target a specific formation, and route-domain
support applies inside the displayed full corridor (y plus/minus 8), including
formations that entered from the other source route. Entering, leaving and
expiry update the same calculation. Commands use existing shared energy and
atomic support receipts. Field medic, saboteur, thief, sniper, engineer and
scout actions remain in their appropriate persistent field context.

## Save compatibility and failure boundaries

Battle-session schema 9 adds one versioned spatial subrecord; campaign save
ownership is unchanged. Schema 1-8 active battles deterministically project
recorded scalar progress onto the corresponding corridor. This keeps HP,
battle tick, gate durability, work progress, effects and completion facts.
No new deployment is granted after an old battle has advanced. Terminal old
sessions restore the existing separate terminal result without another tick.
Current malformed spatial coordinates/receipts are rejected.

Positions, task targets and remaining work/effect ticks round-trip exactly.
Rendering-frame remainder is not authoritative: recovery resumes from the
last committed 250 ms tick. Failed commands/checkpoints retain the existing
rollback boundary. Victory/retreat/defeat/wipe still use the existing one-time
source writeback. A settled zero-strength invasion must remain RESOLVED when
the world clock resumes; this release fixes that terminal-state regression.

## Validation and trade-offs

See [verification and coverage](../milestones/wartime-spatial-r1/VERIFICATION.md).
Finite authored corridors and aggregated enemy groups keep navigation and
recovery deterministic and maintainable. This is a functional graybox, not
final art, arbitrary placement or unconstrained battlefield navigation.
Automated engine input, accelerated recordings and regressions are implementation
evidence. Native-pointer feel, normal-speed balance and Founder acceptance
remain OPEN.
