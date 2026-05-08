#!/bin/sh
set -eu

# SpecFlow Local Checks
# 用途：所有「非 build/lint」的檢查在本地跑（CI 只做 build + lint）
# 用法：
#   local-checks.sh              # 跑全部（unit + contract + bddgen-undefined）
#   local-checks.sh unit         # 只跑 unit tests
#   local-checks.sh contract     # 只跑 contract-check
#   local-checks.sh bdd-gate     # 只跑 bddgen --list-undefined
#   local-checks.sh bdd          # 跑完整 BDD scenario（4 lane 收斂時用）
#
# 環境變數：
#   SCOPE=qa|engineer    對應 PR 類型，控制要跑哪些（預設全跑）
#   SPRINT_TAG=@sprint-N BDD 過濾範圍（跑 bdd 子命令時必填）
#
# Exit code：0 = 全綠；1 = 任一項失敗

CMD="${1:-all}"
SCOPE="${SCOPE:-all}"
ROOT="${ROOT:-.}"
cd "$ROOT"

log() { printf '\n=== %s ===\n' "$*"; }
fail() { echo "❌ $*" >&2; exit 1; }

run_unit() {
  log "Unit tests"
  if [ -f dev/package.json ]; then
    ( cd dev && npm ci --silent 2>/dev/null || npm install --silent )
    ( cd dev && npm test ) || fail "Unit tests 失敗"
  elif [ -f dev/go.mod ]; then
    ( cd dev && go test ./... ) || fail "Go tests 失敗"
  else
    echo "ℹ️  dev/ 沒有 package.json / go.mod — skip unit"
  fi
}

run_contract() {
  log "Contract check (grep)"
  bash .claude/scripts/contract-check.sh || fail "Contract 違規"
}

run_bdd_gate() {
  log "BDD step coverage (no undefined)"
  if [ ! -d test ] || [ ! -f test/package.json ]; then
    echo "ℹ️  test/ 尚未初始化 — skip"
    return
  fi
  ( cd test && npm ci --silent 2>/dev/null || npm install --silent )

  # 找當前 sprint
  MILESTONE=$(gh api "repos/$(gh repo view --json nameWithOwner --jq .nameWithOwner)/milestones?state=open&sort=title&direction=asc" \
    --jq '[.[] | select(.title | startswith("Sprint"))][0].title // empty' 2>/dev/null || echo "")
  if [ -z "$MILESTONE" ]; then
    echo "ℹ️  找不到開放 Sprint milestone — skip bdd-gate"
    return
  fi
  SPRINT_NUM=$(echo "$MILESTONE" | grep -oE '[0-9]+' | head -1)
  TAG="@sprint-${SPRINT_NUM}"

  # 同步當前 sprint 的 .feature
  mkdir -p test/features
  rm -f test/features/*.feature 2>/dev/null || true
  COUNT=0
  for f in specs/features/*.feature; do
    [ -f "$f" ] || continue
    if grep -qE "^[[:space:]]*${TAG}\b" "$f"; then
      cp "$f" test/features/
      COUNT=$((COUNT + 1))
    fi
  done
  [ "$COUNT" = "0" ] && { echo "ℹ️  ${TAG} 沒有 .feature — skip"; return; }

  ( cd test && \
    UNDEF=$(npx bddgen --list-undefined 2>&1 || true); \
    UNDEF_CNT=$(echo "$UNDEF" | grep -cE "^\s*(Given|When|Then|And|But)\b" || true); \
    if [ "$UNDEF_CNT" != "0" ]; then \
      echo "$UNDEF"; \
      echo "❌ ${TAG} 範圍內有 $UNDEF_CNT 個 undefined step"; \
      exit 1; \
    fi; \
    echo "✅ 0 undefined steps in ${TAG}" )
}

run_bdd_full() {
  log "BDD full scenario run (sprint 收斂時用)"
  [ -z "${SPRINT_TAG:-}" ] && fail "SPRINT_TAG 未設，無法決定要跑哪個 sprint 的 scenario"
  bash .claude/scripts/run-sprint-tests.sh all
}

case "$CMD" in
  all)
    run_unit
    run_contract
    run_bdd_gate
    echo ""
    echo "✅ Local checks all passed (unit + contract + bdd-gate)"
    echo "ℹ️  Sprint 收斂時記得用 'local-checks.sh bdd' 跑完整 BDD"
    ;;
  unit)     run_unit ;;
  contract) run_contract ;;
  bdd-gate) run_bdd_gate ;;
  bdd)      run_bdd_full ;;
  *)        fail "Unknown command: $CMD" ;;
esac
