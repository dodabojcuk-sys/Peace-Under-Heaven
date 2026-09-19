#!/bin/bash
# R2B-1 战役归来简报：定向测试分段跑批。
# 每个 stage 是独立 Godot 进程 + 真实冷启动 load_latest，共用一条隔离存档链。
# 全部写入 /private/tmp 随机目录；禁止使用真实玩家存档。
# 每个进程带硬超时：脚本自身已有看门狗，这里再兜一层，避免遗留卡死实例。
set -u

GODOT="/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot"
PROJ="/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a-theater-entry"
SCRIPT="res://tests/verify_r2b1_battle_return_brief.gd"
# 每个结算族一条独立隔离存档链：D/S/V 的 deploy 需要本关回到 PREPARATION，
# 而 S_flow 刻意停在 PENDING（回滚不提交），共用一条链会让 V_deploy 继承脏阶段。
STAGES=(W_deploy W_flow W_cold W_second D_deploy D_flow S_deploy S_flow V_deploy V_flow U_advice)
family_of() {
  case "$1" in
    W_*) echo "withdraw" ;;
    D_*) echo "defeat" ;;
    S_*) echo "savefail" ;;
    V_*) echo "victory" ;;
    *) echo "advice" ;;
  esac
}
HARD_LIMIT="${R2B1_HARD_LIMIT:-300}"

WORK="${R2B1_WORK_DIR:-/private/tmp/txwzs-r2b1-$(date +%s)-$$}"
FACTS="$WORK/facts"
mkdir -p "$FACTS"
echo "R2B1_WORK $WORK"

failures=0
for stage in "${STAGES[@]}"; do
  family=$(family_of "$stage")
  SAVES="$WORK/saves-$family"
  mkdir -p "$SAVES"
  "$GODOT" --path "$PROJ" --script "$SCRIPT" -- \
    --txwzs-require-isolated-save \
    --txwzs-v5-save-dir="$SAVES" \
    --facts-dir="$FACTS" \
    --stage="$stage" > "$WORK/$stage.log" 2>&1 &
  pid=$!
  ( sleep "$HARD_LIMIT"; kill -9 "$pid" 2>/dev/null ) &
  waiter=$!
  wait "$pid" 2>/dev/null
  code=$?
  kill "$waiter" 2>/dev/null
  wait "$waiter" 2>/dev/null

  summary=$(grep -E "^R2B1 stage=" "$WORK/$stage.log" | tail -1)
  crashes=$(grep -c "^SCRIPT ERROR" "$WORK/$stage.log")
  pass=$(grep -c "^PASS" "$WORK/$stage.log")
  if [ "$code" = "0" ] && printf '%s' "$summary" | grep -q "PASS all" && [ "$crashes" = "0" ]; then
    echo "OK   $stage  assertions=$pass  $summary"
  else
    echo "FAIL $stage  exit=$code assertions=$pass script_errors=$crashes  $summary"
    grep -E "^FAIL|^ERROR:" "$WORK/$stage.log" | head -8
    failures=$((failures + 1))
  fi
done

echo "R2B1_MATRIX stages=${#STAGES[@]} failed=$failures work=$WORK"
[ "$failures" = "0" ] || exit 1
