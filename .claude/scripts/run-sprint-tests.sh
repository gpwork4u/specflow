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
#   SPRINT_TAG        Gherkin tag 過濾（如 "@sprint-2"），只跑當前 sprint 的 scenario
#                     未指定時跑全部（含過往 sprint 的 regression）
#   SKIP_DOCKER=1     不啟動 docker compose（假設服務已在跑）
#   SKIP_HEALTH=1     不等 health check
# Exit code：0 = 全部測試通過；非 0 = 任一階段失敗

FEATURE_GLOB="${1:-all}"
BASE_URL="${BASE_URL:-http://localhost:3000}"
SPRINT_TAG="${SPRINT_TAG:-}"
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
  EXIT_CODE=$?
  log "Cleanup (exit=$EXIT_CODE)"

  # 1. Docker：down + 移除 volumes + 清 orphan，避免下次跑卡舊狀態
  if [ "${SKIP_DOCKER:-0}" != "1" ]; then
    ( cd dev && docker compose down -v --remove-orphans ) 2>/dev/null || true
  fi

  # 2. test/ 暫存資源：成功時全清；失敗時保留 screenshots/test-results 給 debug
  if [ "$EXIT_CODE" = "0" ]; then
    rm -rf test/features 2>/dev/null || true
    rm -rf test/test-results 2>/dev/null || true
    rm -rf test/screenshots 2>/dev/null || true
    rm -rf test/.bdd-gen 2>/dev/null || true   # playwright-bdd 產出的中間檔
    # reports/ 保留給 verifier，verifier 結束會再清
    echo "✅ Cleaned: docker stack + test/features + test-results + screenshots"
  else
    rm -rf test/features 2>/dev/null || true   # 已重新生成的，可清
    rm -rf test/.bdd-gen 2>/dev/null || true
    echo "⚠️  保留 test/test-results + test/screenshots + test/reports 供 debug"
    echo "    debug 完跑：bash .claude/scripts/local-checks.sh cleanup"
  fi
}
trap cleanup EXIT

# ---- 2. Unit tests ----
log "Unit tests"
( cd dev && npm ci --silent 2>/dev/null || npm install --silent )
( cd dev && npm test ) || fail "Unit tests failed"

# ---- 3. 同步 .feature 到 test/features/（只同步當前 sprint scope）----
log "Sync feature files (sprint-scoped)"
mkdir -p test/features
# 先清空避免上次殘留
rm -f test/features/*.feature 2>/dev/null || true

if [ "$FEATURE_GLOB" != "all" ]; then
  # PR-level：明確指定的 feature 子集
  cp $FEATURE_GLOB test/features/ 2>/dev/null || fail "No feature matched: $FEATURE_GLOB"
elif [ -n "$SPRINT_TAG" ]; then
  # Sprint-level：只同步檔頭含 SPRINT_TAG 的 .feature
  # 這是「不要測超過範圍」的關鍵 — 沒打 @sprint-N 的檔案被視為未排入當前 sprint
  COUNT=0
  for f in specs/features/*.feature; do
    [ -f "$f" ] || continue
    if grep -qE "^[[:space:]]*${SPRINT_TAG}\b" "$f"; then
      cp "$f" test/features/
      COUNT=$((COUNT + 1))
    fi
  done
  echo "Synced $COUNT feature file(s) tagged $SPRINT_TAG"
  [ "$COUNT" = "0" ] && fail "找不到任何標記 $SPRINT_TAG 的 .feature 檔。spec-writer 必須在檔頭 Feature: 前一行加 $SPRINT_TAG。"
else
  # 沒給 SPRINT_TAG 的 all 模式：同步所有檔（release 前回歸測試用）
  cp specs/features/*.feature test/features/ 2>/dev/null || true
fi

# ---- 4. BDD tests ----
log "BDD tests (playwright-bdd)"
( cd test && npm ci --silent 2>/dev/null || npm install --silent )
( cd test && npx playwright install --with-deps chromium > /dev/null 2>&1 || npx playwright install chromium )

PLAYWRIGHT_JSON="$REPORT_DIR/playwright.json"
CUCUMBER_JSON="$REPORT_DIR/cucumber-report.json"
HTML_REPORT="$REPORT_DIR/playwright-report"
BDD_FAILED=0
GREP_ARG=""
[ -n "$SPRINT_TAG" ] && GREP_ARG="--grep $SPRINT_TAG"

(
  cd test && \
  BASE_URL="$BASE_URL" npx bddgen && \
  BASE_URL="$BASE_URL" npx playwright test \
    $GREP_ARG \
    --reporter=json,html \
    --output="../$SCREENSHOT_DIR" \
    > "../$PLAYWRIGHT_JSON" 2>&1
) || BDD_FAILED=1

# ---- 5. Scenario coverage + pass count（用 cucumber report，跟 Gherkin 1:1）----
log "Scenario coverage check (cucumber report)"
if [ ! -f "$CUCUMBER_JSON" ]; then
  fail "找不到 cucumber report ($CUCUMBER_JSON) — 確認 playwright.config.ts 有設 cucumberReporter('json')"
fi

# 計算當前要跑的 scenario 範圍（從 test/features/ 而非 specs/features/，配合 @sprint-N tag 過濾）
if [ -n "$SPRINT_TAG" ]; then
  # 只算帶有 SPRINT_TAG 的 scenario（前一行或同 Feature header 含 tag）
  # 簡化：tag 在 Scenario 上一行，用 awk 抓
  TOTAL_SCENARIOS=$(awk -v tag="$SPRINT_TAG" '
    /^[[:space:]]*@/ { tags=$0 }
    /^[[:space:]]*Scenario(| Outline):/ {
      if (tags ~ tag) count++
      tags=""
    }
    END { print count+0 }
  ' test/features/*.feature 2>/dev/null)
else
  TOTAL_SCENARIOS=$(grep -rh "^\s*Scenario\(\| Outline\):" test/features/ 2>/dev/null | wc -l | tr -d ' ')
fi
RAN_SCENARIOS=$(jq '[.[].elements[] | select(.type=="scenario")] | length' "$CUCUMBER_JSON" 2>/dev/null || echo "0")
PASSED_SCENARIOS=$(jq '[.[].elements[] | select(.type=="scenario" and (.steps | all(.result.status == "passed")))] | length' "$CUCUMBER_JSON" 2>/dev/null || echo "0")

echo "Feature scenarios: $TOTAL_SCENARIOS"
echo "Cucumber executed: $RAN_SCENARIOS"
echo "Cucumber passed:   $PASSED_SCENARIOS"

if [ "$FEATURE_GLOB" = "all" ] && [ "$RAN_SCENARIOS" -lt "$TOTAL_SCENARIOS" ]; then
  fail "Coverage gap: $RAN_SCENARIOS / $TOTAL_SCENARIOS scenarios executed."
fi

if [ "$BDD_FAILED" = "1" ] || [ "$PASSED_SCENARIOS" -lt "$RAN_SCENARIOS" ]; then
  echo "❌ BDD tests failed — see $CUCUMBER_JSON"
  exit 1
fi

log "✅ All tests passed"
