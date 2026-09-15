# Regular Campaign R1B.2 Publish Provenance

- Safe parent: `f1ad13ec62ed57ceb71b089b4fa83b5d9607129b`
- Complete source snapshot: `7f1bff27d9185453b5e2f2bce2ecb9de5167d027`
- Preserved source branch: `codex/txwzs-regular-campaign-r1a-theater-entry`
- Publish branch: `codex/txwzs-regular-campaign-r1b2-publish`

## Approved exclusions

The following files are non-runtime input recordings. Complete byte-identical
copies are preserved outside the repository under
`/Users/m4-zhi/Documents/TXWZS_BACKUP/r1b2-excluded-media-20260915.AMk5r8/`.

| Repository path | SHA-256 |
| --- | --- |
| `docs/milestones/regular-campaign-art-r1/evidence/normal-flow/r1-art-closeout-realtime-input.avi` | `1bb8f88f96ac72ac94177eb85a37eef419c8d1b8298dc7530e85fcd71717b41b` |
| `docs/milestones/regular-campaign-r1a-theater-entry/evidence/full-battle-20260914/qingyuan-full-input-original.avi` | `43694486bb961f7d3c83c60560e9219442ca2d3e7d48690e7685a24e542d592e` |

## Snapshot comparison

The staged publish tree was compared path-by-path, including content object ID
and file mode, against the complete source snapshot. The only differences are
the two exclusions above, the matching `.gitignore` safeguards, this provenance
record, and the publish-lineage entry in `CURRENT_STATE.md`.

No source commit is a second parent. Existing gameplay code, scenes, runtime
assets, tests, small evidence, save ownership and schema are copied as one exact
snapshot from the source tree.

## Verification

Verification used a fresh archive extraction of the publish commit, with no
pre-existing `.godot` import cache and a distinct explicit save directory for
every runner.

- fresh Godot 4.5.1 editor import and script registration: pass;
- R1B.2 normal graphical input loop: pass;
- regular-campaign services and resource isolation: 11/11 pass;
- theater/city round trip and cold context: 16/16 pass;
- campaign time/frame split and pause behavior: 23/23 pass;
- publish tree comparison and `git diff --check`: pass.

The graphical loop reported Godot's existing ObjectDB leak warning at process
shutdown after all assertions passed; it did not write to the player save or
change the exit status.
