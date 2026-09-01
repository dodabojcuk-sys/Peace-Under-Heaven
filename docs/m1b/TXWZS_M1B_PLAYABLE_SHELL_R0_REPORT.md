# TXWZS M1B Standalone Playable Shell R0 report

## Result

```text
RESULT=M1B_ENGINEERING_BLOCKED_EXPORT_TEMPLATES
BASE_HEAD=598310360dd82da917e7816d56ad585e663fddd7
PRODUCT_SOURCE_CHANGED=YES
MAIN_SCENE=TITLE_SHELL
TITLE_TO_CITY=PASS
V5_EXISTING_SAVE_RESTORE=PASS_BY_EXISTING_R2_LIFECYCLE_AND_53_OF_53_REGRESSION
V5_SCHEMA_CHANGED=NO
DUPLICATE_STATE_OWNER=NO
FULL_REGRESSION=PASS_53_OF_53
EDITOR_IMPORT=PASS
MAIN_SCENE_HEADLESS_SMOKE=PASS
BLANK_MAP_HEADLESS_SMOKE=PASS
C0_HEADLESS_SMOKE=PASS
STANDALONE_MACOS_APP=BLOCKED_MISSING_GODOT_4_5_1_EXPORT_TEMPLATE
EXPORT_PRESET=LOCAL_IGNORED_BY_EXISTING_REPOSITORY_POLICY
SCREENSHOT_COUNT=0_NO_STANDALONE_ARTIFACT
OBVIOUS_OVERLAP_OR_CLIPPING=NOT_CLAIMED_NO_NATIVE_CAPTURE
L3_LONG_VIDEO=DEFERRED_NOT_A_GATE
HUMAN_FOUNDER_ACCEPTANCE=NOT_CLAIMED
PUSH=NO
MERGE=NO
DEPLOY=NO
```

## Implemented product boundary

`res://scenes/title_shell.tscn` is now the formal `run/main_scene`. Its
container hierarchy is:

```text
TitleShell
├── Background
└── SafeArea (MarginContainer)
    └── Center (CenterContainer)
        └── TitlePanel (PanelContainer)
            └── Margins (MarginContainer)
                └── Content (VBoxContainer)
                    ├── 天下无战事
                    ├── 黑石城
                    ├── 进入黑石城
                    └── 退出游戏
```

The title script owns only initial keyboard focus, `ui_cancel` consumption,
normal app exit, and a guarded one-shot `change_scene_to_packed()` transition
to the existing `blank_map.tscn`. It does not instantiate or query
`ConstructionController`, `RuntimeCampaignPersistenceCoordinator`, V5 store,
codec, or snapshot. Therefore the existing city scene remains the only runtime
authority and the only place that restores a V5 campaign or flushes on a normal
window-close request.

`project.godot` now names the product `天下无战事`. The local
`export_presets.cfg` has one portable `macOS Debug` preset: no absolute export
path, unsigned, Universal, `org.txwzs.heishicheng`, and no
certificate/notarization settings. The repository's existing `.gitignore`
explicitly excludes `export_presets.cfg`; it was therefore intentionally not
force-added or committed. This preserves project policy while leaving the
reproducible local preset available for a later retry once the exact template
is installed. No schema, storage version, resource, construction, road,
placement, battle, or save behavior changed.

## Verification

| Check | Actual result |
| --- | --- |
| M1B focused runner | PASS, 44 assertions |
| Title layout | PASS at 1152×648, 1280×720, 1440×900; required rects inside panel/viewport and pairwise disjoint |
| Keyboard contract | PASS: initial focus on `进入黑石城`; title Esc remains stable |
| Ownership contract | PASS: title creates no city authority or persistence coordinator |
| Transition contract | PASS: repeated entry activation leaves exactly one existing city scene |
| R2 V5 lifecycle | PASS in `run_m1a1_runtime_persistence_lifecycle_smoke.gd` |
| M1A/M1A.1/R0C/R0C.1 | PASS in the complete dynamic set |
| Full dynamic runners | PASS, 53/53 |
| Godot 4.5.1 editor import | PASS |
| Formal title main scene / blank map / C0 headless smokes | PASS / PASS / PASS |
| `git diff --check` | PASS before the product/report commits |

## Export blocker

The engine used was:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
4.5.1.stable.official.f62fdbde1
```

The user-level export-template directory existed but was empty. The exact
official `Godot_v4.5.1-stable_export_templates.tpz` archive is a full
approximately-1.3-GB package. Its official GitHub release download was
reachable but limited to roughly 0.12 MB/s (more than three hours estimated).
Two alternate exact-file paths returned HTTP 404. The incomplete task-local
archive was not installed or used.

The deterministic export attempt was:

```sh
Godot --headless --path . --export-debug "macOS Debug" \
  /Users/m4-zhi/Downloads/TXWZS_M1B_PLAYABLE_SHELL_R0/天下无战事.app
```

Godot rejected it because this exact expected file was absent:

```text
/Users/m4-zhi/Library/Application Support/Godot/export_templates/4.5.1.stable/macos.zip
```

No app bundle was produced. Consequently the requested standalone launch
smoke and four native/standalone screenshots were not performed or claimed.
This is an export-environment blocker, not evidence of a product, V5, or UI
failure.

## Sources and skill routing

| Source | Version / license | Actually read | Adoption |
| --- | --- | --- | --- |
| Godot official documentation | 4.5 pages | macOS export, Containers, SceneTree scene-change pages | Adopted: one official scene transition, nested containers, and a single portable macOS preset. The project remains on Godot 4.5.1. |
| `Maaack/Godot-Game-Template` | GitHub release `v1.4.6`, MIT | README and `MainMenuSetup.md` | Adopted only the high-level menu layering idea. Rejected its plugin/global-state/menu stack because it would introduce unneeded settings and save ownership. Its 4.6 animation warning was not used. |
| `htdt/godogen` | GitHub `main`, MIT; exact commit query timed out on the constrained network | README | Adopted only the short visible-result/proof discipline. No code, scripts, generator, publish flow, C#, or dependency was used. |

The requested local skills `using-godot-prompter`, `godot-ui`, `responsive-ui`,
`input-handling`, `save-load`, `export-pipeline`, `godot-testing`, and
`godot-code-review` were searched for before work and are not installed. They
are not claimed as used. The equivalent review was the official Godot 4.5
documentation plus focused geometry/ownership tests, full dynamic regression,
editor import, scene smokes, and source diff review.

## Review scope

The M1B diff has one title script, one title scene, a formal-main-scene switch,
one export preset, one focused runner, and status/decision/report updates. It
introduces no second state owner, no V5 parsing logic, no hard-coded filesystem
path in product code/config, no absolute-pixel title layout, no new asset or
dependency, and no battle/build/road/resource rule change. The only unfulfilled
M1B requirement is the standalone export evidence blocked above.
