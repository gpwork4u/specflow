#!/bin/sh
set -eu

# SpecFlow Local Checks（push 前 gate，不含 e2e）
# 用法：
#   local-checks.sh              # 跑全部（unit + contract）
#   local-checks.sh unit         # 只跑 unit tests
#   local-checks.sh contract     # 只跑 contract-check
#   local-checks.sh e2e          # 本地跑 e2e（debug 用；正常流程由 CI sprint-test.yml 自動跑）
#   local-checks.sh cleanup      # 強制清乾淨所有測試暫存
#
# 環境變數：
#   SPRINT=Sprint\ 1     e2e 子命令必填，決定 sprint scope
#
# Exit code：0 = 全綠；1 = 任一項失敗

CMD="${1:-all}"
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

run_e2e() {
  log "E2E full run (sprint 收斂時用)"
  [ -z "${SPRINT:-}" ] && fail "SPRINT 未設，無法決定 sprint scope（如 SPRINT='Sprint 1'）"
  bash .claude/scripts/run-sprint-tests.sh all
}

run_cleanup() {
  log "Cleanup all test artifacts"
  if [ -f dev/docker-compose.yml ]; then
    ( cd dev && docker compose down -v --remove-orphans ) 2>/dev/null || true
  fi
  rm -rf test/test-results test/screenshots test/reports test/playwright-report 2>/dev/null || true
  rm -rf .github/bug-evidence 2>/dev/null || true
  echo "✅ Cleaned all test artifacts"
}

case "$CMD" in
  all)
    run_unit
    run_contract
    echo ""
    echo "✅ Local checks all passed (unit + contract)"
    echo "ℹ️  Sprint 收斂時記得用 'SPRINT=\"Sprint N\" local-checks.sh e2e' 跑完整 e2e"
    ;;
  unit)     run_unit ;;
  contract) run_contract ;;
  e2e)      run_e2e ;;
  cleanup)  run_cleanup ;;
  *)        fail "Unknown command: $CMD" ;;
esac
