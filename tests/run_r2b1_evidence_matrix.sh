#!/bin/bash
# R2B-1 战役归来简报：可见操作取证跑批。
# 每个 --case 独立 Godot 进程 + 独立隔离存档目录（战役 3 走完 COMPLETED 后
# 同一存档链无法回到备战页，共用目录会让后面的用例继承脏阶段）。
# 产出 SHOT 行与 EVIDENCE_MODE 行，供 R2B1_RESULTS.md 的逐图口径表引用。
# 全程隔离存档；禁止使用真实玩家存档。
set -u

GODOT="/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot"
PROJ="/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a-theater-entry"
SCRIPT="res://tests/capture_r2b1_evidence.gd"
OUT="${R2B1_EVIDENCE_OUT:-/Users/m4-zhi/Documents/TXWZS_R2B1_DELIVERY}"
CASES=(withdraw retained victory defeat food_risk)
HARD_LIMIT="${R2B1_EVIDENCE_HARD_LIMIT:-540}"

WORK="${R2B1_EVIDENCE_WORK:-/private/tmp/txwzs-r2b1-vis-$(date +%s)-$$}"
mkdir -p "$WORK" "$OUT"
echo "R2B1_EVIDENCE_WORK $WORK"
echo "R2B1_EVIDENCE_OUT $OUT"

failures=0
for case_id in "${CASES[@]}"; do
  SAVES="$WORK/saves-$case_id"
  mkdir -p "$SAVES"
  "$GODOT" --path "$PROJ" --script "$SCRIPT" -- \
    --txwzs-require-isolated-save \
    --txwzs-v5-save-dir="$SAVES" \
    --out-dir="$OUT" \
    --case="$case_id" > "$WORK/$case_id.log" 2>&1 &
  pid=$!
  ( sleep "$HARD_LIMIT"; kill -9 "$pid" 2>/dev/null ) &
  waiter=$!
  wait "$pid" 2>/dev/null
  code=$?
  kill "$waiter" 2>/dev/null
  wait "$waiter" 2>/dev/null

  summary=$(grep -E "^R2B1_EVIDENCE case=" "$WORK/$case_id.log" | tail -1)
  crashes=$(grep -c "^SCRIPT ERROR" "$WORK/$case_id.log")
  shots=$(grep -c "^SHOT " "$WORK/$case_id.log")
  modes=$(grep -E "^EVIDENCE_MODE" "$WORK/$case_id.log" | tr '\n' ' ')
  if [ "$code" = "0" ] && printf '%s' "$summary" | grep -q "PASS all" && [ "$crashes" = "0" ]; then
    echo "OK   $case_id  shots=$shots  $modes"
  else
    echo "FAIL $case_id  exit=$code shots=$shots script_errors=$crashes  $summary"
    grep -E "^FAIL|^ERROR:" "$WORK/$case_id.log" | head -8
    failures=$((failures + 1))
  fi
done

echo "R2B1_EVIDENCE cases=${#CASES[@]} failed=$failures work=$WORK"
[ "$failures" = "0" ] || exit 1
