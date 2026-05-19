#!/bin/sh
set -eu
# SpecFlow skill 基礎設施自測（回歸守門）
# 把「手動驗過一次」變成可重跑的回歸保護。CI 與本機皆可跑。
# 用法：bash .claude/scripts/selftest.sh
# exit 0 = 全綠；非 0 = 有回歸

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SC="$ROOT/.claude/scripts"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T"

# ---- 1. state.sh 並發鎖（lane 制 5 agent 同寫，防 lost-update）----
mkdir -p .specflow
cp "$SC/state.sh" state.sh
bash state.sh init >/dev/null 2>&1
i=1; while [ "$i" -le 30 ]; do ( bash state.sh agent-add "a$i" "$i" null "" running ) & i=$((i+1)); done
wait
N=$(jq '.in_flight_agents|length' .specflow/state.json 2>/dev/null || echo 0)
[ "$N" -eq 30 ] && ok "state.sh 並發鎖 30/30" || bad "state.sh 並發鎖 $N/30（lost-update 回歸）"

# ---- 2. state.sh schema / 既有指令完整（lane-close / set / get）----
bash state.sh lane-close qa >/dev/null 2>&1 || true
LC=$(bash state.sh lane-status 2>/dev/null | grep -c 'qa=true' || echo 0)
[ "$LC" -eq 1 ] && ok "state.sh lane-close/lane-status 正常" || bad "state.sh lane-close 回歸"
bash state.sh set sprint_test_outcome '"success"' >/dev/null 2>&1 || true
[ "$(bash state.sh get sprint_test_outcome 2>/dev/null)" = "success" ] \
  && ok "state.sh set/get + schema 完整" || bad "state.sh set/get 回歸"

# ---- 3. 所有 shell 腳本語法正確 ----
SYN_OK=1
for s in "$SC"/*.sh; do
  sh -n "$s" 2>/dev/null || { bad "語法錯誤: $(basename "$s")"; SYN_OK=0; }
done
[ "$SYN_OK" -eq 1 ] && ok "全部 .sh 腳本語法正確（$(ls "$SC"/*.sh | wc -l | tr -d ' ') 支）"

# ---- 4. contract-check.sh 能擋 hardcoded 違規（specflow 核心防漂移）----
if [ -f "$SC/contract-check.sh" ]; then
  sh -n "$SC/contract-check.sh" 2>/dev/null \
    && ok "contract-check.sh 可執行（contracts 三件套防線）" \
    || bad "contract-check.sh 語法錯誤"
else
  bad "contract-check.sh 不存在（specflow 防漂移核心）"
fi

# ---- 5. doctor.sh 可跑且不誤殺 ----
if sh -n "$SC/doctor.sh" 2>/dev/null; then ok "doctor.sh 語法正確"; else bad "doctor.sh 語法錯誤"; fi

echo "----------------------------------------"
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
