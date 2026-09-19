#!/bin/bash
# FORMATION_RETURN_IDENTITY_R1 定向跑批：四个结算族 × 冷启动分段。
# 每个 stage 是独立 Godot 进程 + 真实 load_latest 冷启动，同一族共用一条隔离存档链。
# 全部写入 /private/tmp 下的独立目录；禁止使用真实玩家存档。
# 工程入口由脚本自身位置推导，避免硬编码 worktree 路径。
set -u

GODOT="/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="res://tests/verify_formation_return_identity_r1.gd"
HARD_LIMIT="${FRI_HARD_LIMIT:-360}"
WORK="${FRI_WORK_DIR:-/private/tmp/txwzs-fri-$(date +%s)-$$}"

# 默认跑全部四个用例；FRI_CASES="D" 可只跑指定用例做快速复现。
read -r -a CASES <<< "${FRI_CASES:-A B C D}"
stages_of() {
  case "$1" in
    D) echo "depart attrite confirm post" ;;
    *) echo "depart attrite confirm post verify" ;;
  esac
}

failures=0
echo "FRI_WORK $WORK"
echo "FRI_PROJ $PROJ"

for case_id in "${CASES[@]}"; do
  SAVES="$WORK/saves-$case_id"
  FACTS="$WORK/facts-$case_id"
  mkdir -p "$SAVES" "$FACTS"
  for stage in $(stages_of "$case_id"); do
    log="$WORK/${case_id}_${stage}.log"
    "$GODOT" --headless --path "$PROJ" --script "$SCRIPT" -- \
      --txwzs-require-isolated-save \
      --txwzs-v5-save-dir="$SAVES" \
      --facts-dir="$FACTS" \
      --case="$case_id" \
      --stage="$stage" > "$log" 2>&1 &
    pid=$!
    ( sleep "$HARD_LIMIT"; kill -9 "$pid" 2>/dev/null ) &
    waiter=$!
    wait "$pid" 2>/dev/null
    code=$?
    kill "$waiter" 2>/dev/null
    wait "$waiter" 2>/dev/null

    pass=$(grep -c "^PASS" "$log")
    crashes=$(grep -c "^SCRIPT ERROR" "$log")
    summary=$(grep -E "^FORMATION_RETURN_IDENTITY_R1 " "$log" | tail -1)
    if [ "$code" = "0" ] && printf '%s' "$summary" | grep -q " PASS$" && [ "$crashes" = "0" ]; then
      echo "OK   $case_id/$stage  assertions=$pass"
    else
      echo "FAIL $case_id/$stage  exit=$code assertions=$pass script_errors=$crashes"
      printf '%s\n' "$summary"
      grep -E "^ASSERT_FAIL" "$log" | head -12
      grep -E "^FRI " "$log" | tail -8
      failures=$((failures + 1))
    fi
  done
done

garrison_log="$WORK/garrison_layer1.log"
"$GODOT" --headless --path "$PROJ" --script "res://tests/verify_formation_return_identity_garrison.gd" \
  > "$garrison_log" 2>&1
layer1_code=$?
layer1_pass=$(grep -c "^PASS" "$garrison_log")
if [ "$layer1_code" = "0" ] && grep -q "^FORMATION_RETURN_IDENTITY_GARRISON PASS$" "$garrison_log"; then
  echo "OK   layer1/garrison  assertions=$layer1_pass"
else
  echo "FAIL layer1/garrison  exit=$layer1_code assertions=$layer1_pass"
  grep -E "^FORMATION_RETURN_IDENTITY_GARRISON FAIL" "$garrison_log" | head -3
  failures=$((failures + 1))
fi

echo "FRI_RESULT cases=${#CASES[@]} failures=$failures work=$WORK"
[ "$failures" = "0" ] || exit 1
