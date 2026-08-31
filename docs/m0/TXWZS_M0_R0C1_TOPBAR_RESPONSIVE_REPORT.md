# TXWZS M0 R0C.1 Top-Bar Responsive Closure Report

```text
BASELINE=bab6b78f0556799645733a399f84412fba2b8cf7
SCOPE=TOP_BAR_PRESENTATION_ONLY

TOP_BAR_REGIONS=resources,city,date_and_settlement,deadline_and_pressure,speed_and_pause
DATE_SETTLEMENT_BUDGET=2_ROWS
FONT_SIZE_REDUCTION=NO
ABSOLUTE_SINGLE_RESOLUTION_PATCH=NO

LONGEST_LIVE_COPY=今日结算+下一阶段+主线期限+压力+治安
LAYOUT_1152X648=PASS
LAYOUT_1280X720=PASS
LAYOUT_1440X900=PASS
REGION_RECTANGLES_PAIRWISE_DISJOINT=PASS
R0C1_FOCUSED=PASS_57_ASSERTIONS
R0C_FOCUSED=PASS_33_ASSERTIONS
FULL_DYNAMIC_REGRESSION=PASS_49_OF_49_RUNNERS
MAIN_SCENE_HEADLESS_SMOKE=PASS
EDITOR_PARSE_IMPORT=PASS
NATIVE_SCREENSHOTS=PASS_3_OF_3

CONSTRUCTION_QUEUE=UNCHANGED
RESOURCE_TRANSACTIONS=UNCHANGED
PLACEMENT=UNCHANGED
ROADS=UNCHANGED
SAVE_LOGIC=UNCHANGED
PUSH=NO
MERGE=NO
DEPLOY=NO
```

## Result

The previous top bar derived some labels from left-side offsets and others from
right-side offsets. Under long settlement and pressure copy, their rectangles
could converge and draw over each other. R0C.1 now derives five ordered regions
from the active viewport and gives deadline/pressure plus speed/pause protected
minimum widths.

Date and settlement share the first row; the next stage is the second row.
Trailing settlement detail may elide in that region, but the primary settlement
and next-stage labels remain present. No font size is reduced for smaller
viewports.

## Evidence

- [1152x648](evidence/r0c1/topbar-longest-state-1152x648.png)
- [1280x720](evidence/r0c1/topbar-longest-state-1280x720.png)
- [1440x900](evidence/r0c1/topbar-longest-state-1440x900.png)

The evidence and automated checks are engineering evidence only. Founder visual
acceptance remains outside this task; no push, merge, deploy, or gameplay work
was performed.
