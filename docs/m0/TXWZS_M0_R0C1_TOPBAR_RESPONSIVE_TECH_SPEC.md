# TXWZS M0 R0C.1 Top Bar Responsive Closure

## Scope

R0C.1 is a presentation-only closure on top of `bab6b78f`. It fixes the city
top bar when the settlement and mainline-pressure strings are both at their
longest. It does not change construction queues, resource transactions,
placement, roads, or save state.

## Layout contract

The top bar owns five non-overlapping regions, in display order:

1. resources;
2. active city;
3. date and settlement;
4. mainline deadline and pressure;
5. speed and pause controls.

The responsive layout derives all region rectangles from the current viewport.
Resources, city, deadline/pressure, speed, and pause retain readable minimum
widths. The date/settlement region receives the remaining width. Its date shares
the first row with the settlement; the settlement is limited to two rows and
clips only secondary trailing detail when space is exhausted. Font sizes are not
reduced for narrower viewports.

## Acceptance and verification

- Exercise the longest live settlement copy containing `今日结算` and
  `下一阶段`, together with `主线期限`, `压力`, and `治安`.
- At 1152x648, 1280x720, and 1440x900, assert each region is inside the top
  bar and every pair of region rectangles is disjoint.
- Capture one native Godot screenshot per target resolution from that same
  stress state.
- Re-run the R0C focused smoke and the full dynamic regression.

## Non-goals

No construction, resource, placement, road, persistence, deployment, merge, or
push behavior is modified.
