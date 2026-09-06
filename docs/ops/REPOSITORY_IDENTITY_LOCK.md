# TXWZS2 Product Successor Identity Lock

The active mutation root is:

`/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0`

Its product branch is `codex/product-successor-inner-city-r0`. It was cloned
without local object sharing from the frozen Canonical source at commit
`4292ade22bbd3b4b14e48d98475ac50c1da265f6` and tree
`a7231a44b8805a60b44ecd697053a55394bdde7d`.

The lock prevents treating any of the following as a mutable product root:

| Location | Role | Mutation policy |
| --- | --- | --- |
| `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2` | Historical Legacy Workspace, absent at lock time | No mutation; do not substitute another path |
| `/Users/m4-zhi/Documents/codex-workspace/txwzs2-reconstructed-cb7c87ba` | Forensic Canonical | Read-only frozen source |
| `/Users/m4-zhi/Downloads/txwzs2-rg-o1-external-object-preservation-20260805-v1` | Quarantined RG-O1 v1 evidence | No mutation; not a code or recovery source |

Before a product write, local commit, test, or Godot execution, run
`tools/assert_active_product_repo.sh`. The assertion rejects this repository
when its realpath, role, branch, remote configuration, or object-store
independence no longer matches this lock.

```text
RG_O1_EXTERNAL_PRESERVATION_VALID=NO
G4_STARTED=NO
PUSH_ALLOWED=NO
DEPLOY_ALLOWED=NO
```
