#!/bin/sh
set -eu

# SpecFlow Sprint Test Runner
# 用途：本機 + CI 共用同一份測試流程
# 用法：
#   run-sprint-tests.sh [feature-glob]
#     feature-glob = "all"（預設）跑全部
#                  = "specs/features/F-002*.feature" 跑特定 feature
# 環境變數：
#   BASE_URL          測試目標 URL（預設 http://localhost:3000）
#   SKIP_DOCKER=1     不啟動 docker compose（假設服務已在跑）
#   SKIP_HEALTH=1     不等 health check
# Exit code：0 = 全部測試通過；非 0 = 任一階段失敗

FEATURE_GLOB="${1:-all}"
BASE_URL="${BASE_URL:-http://localhost:3000}"
REPORT_DIR="test/reports"
SCREENSHOT_DIR="test/screenshots"

mkdir -p "$REPORT_DIR" "$SCREENSHOT_DIR"

log() { printf '\n=== %s ===\n' "$*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# ---- 1. 啟動 docker（除非略過）----
if [ "${SKIP_DOCKER:-0}" != "1" ]; then
  log "Starting docker compose"
  ( cd dev && \
    [ -f docker-compose.yml ] || cp docker-compose.example.yml docker-compose.yml; \
    [ -f .env ] || cp .env.example .env; \
    docker compose up -d --build )

  if [ "${SKIP_HEALTH:-0}" != "1" ]; then
    log "Waiting for health check at $BASE_URL/health"
    for i in $(seq 1 30); do
      if curl -sf "$BASE_URL/health" > /dev/null 2>&1; then
        echo "✅ Services ready"
        break
      fi
      [ "$i" = "30" ] && fail "Service health check timeout"
      printf '.'; sleep 2
    done
  fi
fi

cleanup() {
  if [ "${SKIP_DOCKER:-0}" != "1" ]; then
    log "Stopping docker compose"
    ( cd dev && docker compose down ) || true
  fi
}
trap cleanup EXIT

# ---- 2. Unit tests ----
log "Unit tests"
( cd dev && npm ci --silent 2>/dev/null || npm install --silent )
( cd dev && npm test ) || fail "Unit tests failed"

# ---- 3. 同步 .feature 到 test/features/ ----
log "Sync feature files"
mkdir -p test/features
if [ "$FEATURE_GLOB" = "all" ]; then
  cp specs/features/*.feature test/features/ 2>/dev/null || true
else
  # 只複製指定的 feature（給 PR-level 測試用）
  cp $FEATURE_GLOB test/features/ 2>/dev/null || fail "No feature matched: $FEATURE_GLOB"
fi

# ---- 4. BDD tests ----
log "BDD tests (playwright-bdd)"
( cd test && npm ci --silent 2>/dev/null || npm install --silent )
( cd test && npx playwright install --with-deps chromium > /dev/null 2>&1 || npx playwright install chromium )

REPORT_JSON="$REPORT_DIR/cucumber.json"
HTML_REPORT="$REPORT_DIR/playwright-report"
(
  cd test && \
  BASE_URL="$BASE_URL" npx bddgen && \
  BASE_URL="$BASE_URL" npx playwright test \
    --reporter=json,html \
    --output="../$SCREENSHOT_DIR" \
    > "../$REPORT_JSON" 2>&1
) || {
  echo "❌ BDD tests failed — see $REPORT_JSON"
  # 解析失敗統計（如有）
  if [ -f "$REPORT_JSON" ] && command -v jq > /dev/null; then
    PASS=$(jq '.stats.expected // 0' "$REPORT_JSON" 2>/dev/null || echo "?")
    FAIL=$(jq '.stats.unexpected // 0' "$REPORT_JSON" 2>/dev/null || echo "?")
    echo "   pass=$PASS fail=$FAIL"
  fi
  exit 1
}

# ---- 5. Coverage check：所有 .feature scenario 都有跑到嗎 ----
log "Scenario coverage check"
TOTAL_SCENARIOS=$(grep -rh "^\s*Scenario\(\| Outline\):" specs/features/ 2>/dev/null | wc -l | tr -d ' ')
RAN_SCENARIOS=$(jq '[.suites[]?.specs[]?] | length' "$REPORT_JSON" 2>/dev/null || echo "0")

echo "Spec scenarios: $TOTAL_SCENARIOS"
echo "Tests run: $RAN_SCENARIOS"

if [ "$FEATURE_GLOB" = "all" ] && [ "$RAN_SCENARIOS" -lt "$TOTAL_SCENARIOS" ]; then
  fail "Coverage gap: $RAN_SCENARIOS / $TOTAL_SCENARIOS scenarios executed. 有 .feature 場景沒被測到。"
fi

log "✅ All tests passed"
