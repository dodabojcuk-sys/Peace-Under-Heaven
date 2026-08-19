#!/bin/bash
set -Eeuo pipefail

EXPECTED_ROOT='/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0'
EXPECTED_BRANCH='codex/product-successor-inner-city-r0'
CANONICAL='/Users/m4-zhi/Documents/codex-workspace/txwzs2-reconstructed-cb7c87ba'
LEGACY='/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2'
QUARANTINE='/Users/m4-zhi/Downloads/txwzs2-rg-o1-external-object-preservation-20260805-v1'

ROOT="$(git rev-parse --show-toplevel)"
[ "$ROOT" = "$EXPECTED_ROOT" ]
[ "$(pwd -P)" = "$EXPECTED_ROOT" ]
[ "$(realpath "$ROOT")" = "$EXPECTED_ROOT" ]
[ "$(git branch --show-current)" = "$EXPECTED_BRANCH" ]
[ -f "$ROOT/REPOSITORY_ROLE.md" ]
grep -Fxq 'REPOSITORY_ROLE=ACTIVE_PRODUCT_SUCCESSOR' "$ROOT/REPOSITORY_ROLE.md"
[ ! -e "$ROOT/.git/objects/info/alternates" ]
[ "$ROOT" != "$CANONICAL" ]
[ "$ROOT" != "$LEGACY" ]
[ "$ROOT" != "$QUARANTINE" ]
[ "${ROOT#/Users/m4-zhi/Downloads/}" = "$ROOT" ]

while IFS= read -r remote_name; do
  remote_url="$(git remote get-url "$remote_name")"
  case "$remote_url" in
    *txwzs2-reconstructed-cb7c87ba*|*godot-天下无战事2*|*txwzs2-rg-o1-external-object-preservation-20260805-v1*)
      exit 1
      ;;
  esac
done < <(git remote)

printf 'ACTIVE_PRODUCT_REPOSITORY_ASSERTION=PASS\n'
