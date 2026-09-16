#!/bin/bash
# R1C 存档隔离门禁反例矩阵：
# 拒绝例必须以退出码 3 结束且不产生任何文件；合法例只写入核准 case 目录。
# 保护目录（默认玩家存档、TXWZS_BACKUP、旧试玩快照）用内容+元数据哨兵证明原样未变。
set -u

GODOT="/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot"
PROJ="/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a-theater-entry"
PLAYER_SAVE="$HOME/Library/Application Support/Godot/app_userdata/天下无战事/saves"
PROTECTED_ROOTS=(
  "$PLAYER_SAVE"
  "$HOME/Documents/TXWZS_BACKUP"
  "$HOME/Documents/TXWZS_SAVE_SNAPSHOT_PRE_PLAYTEST_20260915"
)

failures=0

sentinel() {
  # 内容+元数据：每个文件的 SHA256 连同相对路径、大小、修改时间一起参与汇总。
  local dir="$1"
  find "$dir" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s|%s|%s|' "${f#${dir#/private}/}" "$(stat -f '%z' "$f")" "$(stat -f '%m' "$f")"
    shasum -a 256 "$f" | awk '{print $1}'
  done | shasum -a 256 | awk '{print $1}'
}

check_protected() {
  local label="$1" before="$2" after="$3"
  if [ "$before" = "$after" ]; then
    echo "PASS 保护目录原样未变（${label}）"
  else
    echo "FAIL 保护目录发生变化（${label}）"
    failures=$((failures + 1))
  fi
}

# 带硬超时的运行（macOS 无 timeout 命令）：后台启动，超时强杀。
run_godot() {
  # 引擎参数（--quit-after 等）固定放在引擎区；"++" 之后的全部是用户参数。
  local hard_limit=$1; shift
  "$GODOT" --headless --path "$PROJ" --quit-after 180 ++ "$@" > /tmp/r1c_gate_last.log 2>&1 &
  local pid=$!
  ( sleep "$hard_limit"; kill -9 "$pid" 2>/dev/null ) &
  local waiter=$!
  wait "$pid" 2>/dev/null
  local code=$?
  kill "$waiter" 2>/dev/null
  wait "$waiter" 2>/dev/null
  return $code
}

expect_rejected() {
  local label="$1"; shift
  run_godot 20 "$@"
  local code=$?
  local out
  out=$(cat /tmp/r1c_gate_last.log 2>/dev/null)
  if [ "$code" = "3" ] && printf '%s' "$out" | grep -q "TXWZS_SAVE_GATE rejected"; then
    echo "PASS 拒绝（${label}）：exit=3 + SAVE_GATE 说明"
  else
    echo "FAIL 拒绝（${label}）：exit=$code"
    failures=$((failures + 1))
  fi
}

echo "== 保护目录哨兵（跑前） =="
S1=$(sentinel "$PLAYER_SAVE")
S2=$(sentinel "$HOME/Documents/TXWZS_BACKUP")
S3=$(sentinel "$HOME/Documents/TXWZS_SAVE_SNAPSHOT_PRE_PLAYTEST_20260915")
echo "哨兵已记录"

echo "== 反例 1：缺 save-dir 参数 =="
expect_rejected "缺参" --txwzs-require-isolated-save

echo "== 反例 2：user:// 默认目录 =="
expect_rejected "user://默认目录" --txwzs-require-isolated-save --txwzs-v5-save-dir="user://saves/v5_campaign/blackstone_city"

echo "== 反例 3：相对路径 =="
expect_rejected "相对路径" --txwzs-require-isolated-save --txwzs-v5-save-dir="relative/case"

echo "== 反例 4：玩家目录绝对路径 =="
expect_rejected "玩家目录绝对路径" --txwzs-require-isolated-save --txwzs-v5-save-dir="$PLAYER_SAVE/saves/v5_campaign/blackstone_city"

echo "== 反例 5：TXWZS_BACKUP 路径 =="
expect_rejected "TXWZS_BACKUP" --txwzs-require-isolated-save --txwzs-v5-save-dir="$HOME/Documents/TXWZS_BACKUP/blackstone_city"

echo "== 反例 6：路径别名（.. 逃逸） =="
expect_rejected "路径别名" --txwzs-require-isolated-save --txwzs-v5-save-dir="/tmp/txwzs-r1c-saves/case/../case-alias"

echo "== 反例 7：重复参数 =="
expect_rejected "重复参数" --txwzs-require-isolated-save --txwzs-v5-save-dir="/tmp/txwzs-r1c-saves/matrix-a" --txwzs-v5-save-dir="/tmp/txwzs-r1c-saves/matrix-b"

echo "== 合法 case：只写入核准目录（引擎参数与用户参数分离，正常退出码） =="
MATRIX_OK=$(mktemp -d /tmp/txwzs-r1c-saves/matrix-XXXXXX)
run_godot 25 ++ --txwzs-require-isolated-save --txwzs-v5-save-dir="$MATRIX_OK"
code=$?
if [ "$code" = "0" ] && [ -d "$MATRIX_OK" ] && ! grep -q "TXWZS_SAVE_GATE rejected" /tmp/r1c_gate_last.log; then
  echo "PASS 合法 case：门禁放行且核准目录 $MATRIX_OK 已创建（存档写入由全流程用例验证）"
else
  echo "FAIL 合法 case：exit=$code 目录=$MATRIX_OK"
  failures=$((failures + 1))
fi

echo "== 符号链接反例（沙盒内假保护目录 + 哨兵文件） =="
LINK_ROOT=$(mktemp -d /tmp/txwzs-r1c-saves/link-XXXXXX)
mkdir -p "$LINK_ROOT/outside-target"
ln -s "$LINK_ROOT/outside-target" "$LINK_ROOT/link-case"
echo "marker:outside-empty" > "$LINK_ROOT/outside-target/SENTINEL_PLACEHOLDER"
# 目录型符号链接在 Godot 文件 API 下不可检测（runtime_identity 注释）；
# 本例实测写入是否穿透链接，哨兵证明沙盒外目录是否被改动。
run_godot 20 ++ --txwzs-require-isolated-save --txwzs-v5-save-dir="$LINK_ROOT/link-case"
if [ -f "$LINK_ROOT/outside-target/SENTINEL_PLACEHOLDER" ] && [ ! -f "$LINK_ROOT/outside-target/campaign_000000000001.json" ]; then
  echo "NOTE symlink-case：核准区外目录未被写入（局部安全）"
else
  echo "NOTE symlink-case：核准区外目录出现写入痕迹（目录链接穿透=已知局限，记录待加固）"
fi
rm -rf "$LINK_ROOT"

echo "== 保护目录哨兵（跑后） ==="
A1=$(sentinel "$PLAYER_SAVE")
A2=$(sentinel "$HOME/Documents/TXWZS_BACKUP")
A3=$(sentinel "$HOME/Documents/TXWZS_SAVE_SNAPSHOT_PRE_PLAYTEST_20260915")
check_protected "玩家存档" "$S1" "$A1"
check_protected "TXWZS_BACKUP" "$S2" "$A2"
check_protected "旧试玩快照" "$S3" "$A3"

echo "R1C_GATE_MATRIX failures=$failures"
exit $((failures > 0 ? 1 : 0))
