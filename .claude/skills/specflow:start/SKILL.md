---
name: specflow:start
description: 啟動完整的 specflow 專案流程。使用者只需與 spec agent 對話確認需求和架構，之後 tech-lead → (engineer + qa 並行) → verify → release 全部自動背景執行。觸發關鍵字："start", "開始", "啟動專案", "新專案"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent, AskUserQuestion
argument-hint: "[專案主題]"
---

# SpecFlow 完整流程 Orchestrator

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、API contract、技術架構、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認

## 完整流程

### Phase 0：環境檢查（自動，缺工具會中斷流程）

```bash
bash .claude/scripts/doctor.sh
```

如果 exit code != 0：呼叫 `specflow:doctor` skill 用 `AskUserQuestion` 引導使用者安裝缺失工具，**不要繼續往下跑**。

### Phase 1：初始化（自動）

```bash
LABEL_COUNT=$(gh label list --json name --jq 'length')
if [ "$LABEL_COUNT" -lt 7 ]; then
  bash .claude/scripts/init-github.sh
fi
mkdir -p specs/features specs/changes specs/changes/archive
bash .claude/scripts/state.sh init
bash .claude/scripts/state.sh phase "phase-1-init" "spec-writer 開始討論需求"
```

> **State 紀錄原則**：每進入新 phase / 啟動 background agent / 收到 agent 回報時，呼叫 `state.sh phase` 或 `state.sh agent-add/done` 寫入 `.specflow/state.json`，讓 `/specflow:resume` 可以接續。

### Phase 2：Design URL → Spec（使用者參與）

**新流程：UI 先在 Claude design 完成**。orchestrator 啟動 spec-writer 前先確認設計稿狀態：

```javascript
AskUserQuestion({
  questions: [{
    question: "UI 設計準備好了嗎？",
    header: "Design",
    multiSelect: false,
    options: [
      { label: "有 Claude design 網址", description: "貼上 https://claude.ai/design/... 或 https://claude.com/...，從設計稿出發反推 spec（Recommended）" },
      { label: "純 backend / API 專案", description: "沒有 UI，跳過 design 直接討論需求" },
      { label: "我先去做 design", description: "暫停，我去 Claude design 完成 UI 後回來執行 /specflow:resume" }
    ]
  }]
})
```

- **有網址** → 把 URL 傳給 spec-writer，它會 fetch + freeze 到 `specs/design-source.md`，然後從設計反推 spec
- **純 backend** → spec-writer 走傳統討論模式（無 design 約束）
- **去做 design** → orchestrator 暫停，state.json 標記 `phase=phase-2-await-design`

啟動 spec-writer agent（**前景，需使用者互動**）：
- `subagent_type: "spec-writer"`
- `run_in_background: false`
- 傳入 $ARGUMENTS（含 design URL，如有）

spec-writer 產出：
- `specs/design-source.md` — Claude design URL 的 fetch 快照（如有）
- `specs/` 目錄下的 spec 檔案（source of truth）
- `specs/features/*.feature` — Gherkin 場景（可執行的接受標準）
- Epic Issue + Sprint Issues
- Sprint Milestones

### Phase 3：Tech Lead 規劃（背景自動）

啟動 tech-lead agent（**背景**）：
- `subagent_type: "tech-lead"`
- `run_in_background: true`

tech-lead：
1. **上網 survey 技術選型**（WebSearch + WebFetch），產出 `specs/tech-survey.md`
2. **產出 Contract 三件套**（hard gate）— `specs/contracts/api.md` + `dom.md` + `ux-text.md` + `specs/contracts.ts`，作為 lane 之間的 single source of truth
3. 讀取 `specs/` 目錄，自動分析依賴圖譜，產出 `specs/dependencies.md`（含 contract owner 標記）
4. 驗證 .feature 檔頭都有 `@sprint-N` tag（hard gate）
5. 建立 feature issues（含 scenarios + 實作指引 + 技術選型 + contract reference）
6. 建立 QA issue（含 scenarios 清單 + contract reference）
7. 建立 design issue — **僅在 `specs/design-source.md` 存在時建**：要求 ui-designer 從 design URL 抽 tokens / 元件 / 字串到 `design/`，產出 handoff 給 tech-lead 在 contract phase 吸進 contracts/。純 backend 專案則不開 design issue。

**Contract 沒寫完不開 issue** — 否則 engineer 開始寫程式碼時 contract 還沒對齊，會出現 hardcoded literal 滿天飛。

> **Design-led 順序提示**：理想上 ui-designer 應**先於** tech-lead 完成 contract phase（因為 dom.md / ux-text.md 要吸 ui-designer 的 handoff）。orchestrator 可以先開 design issue → ui-designer 完成 handoff → tech-lead 才產 contracts → 才開 feature/qa issues。

### Phase 3.9：記錄 sprint_base_sha（給 sprint-end review 用）

在啟動 lane 前先把當前 main HEAD 紀錄起來，這是 sprint review 的 diff 起點：

```bash
SPRINT_BASE=$(git rev-parse main)
bash .claude/scripts/state.sh set sprint_base_sha "\"$SPRINT_BASE\""
echo "Sprint base SHA: $SPRINT_BASE"
```

### Phase 4：每個 lane 啟動 1 個 agent（背景並行，lane 內循序）

**Lane 制度**：每種類型的 agent **同時只跑一個**，避免 worktree 衝突、token 浪費、merge race condition。每個 agent 在自己 lane 內 loop 認領未完成的 issue。

| Lane | Agent | 認領條件 |
|------|-------|---------|
| backend | engineer | label `feature,backend` 或 `bug,backend`，未 assigned |
| frontend | engineer | label `feature,frontend` 或 `bug,frontend`，未 assigned |
| pipeline | engineer | label `feature,pipeline` 或 `bug,pipeline`，未 assigned |
| qa | qa-engineer | label `qa`，當前 sprint |
| ui | ui-designer | label `design`，當前 sprint |

#### 啟動策略

先檢查當前 sprint 各 lane 是否有 issue，**只啟動有工作的 lane**：

```bash
SPRINT="{current_sprint_milestone}"
for LANE in backend frontend pipeline; do
  COUNT=$(gh issue list --milestone "$SPRINT" --label "$LANE" --state open --json number --jq 'length')
  if [ "$COUNT" -gt 0 ]; then
    echo "啟動 engineer lane=$LANE（$COUNT 個 issue 待認領）"
    bash .claude/scripts/state.sh agent-add "engineer-$LANE" 0 null "" "running"
    # Agent(subagent_type="engineer", run_in_background=true, isolation="worktree",
    #       prompt="lane=$LANE, sprint=$SPRINT")
  fi
done

# QA 與 UI 各最多 1 個
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree",
      prompt="sprint=$SPRINT")

if [ "$(gh issue list --milestone "$SPRINT" --label "design" --state open --json number --jq 'length')" -gt 0 ]; then
  Agent(subagent_type="ui-designer", run_in_background=true, isolation="worktree",
        prompt="sprint=$SPRINT")
fi
```

**最多 5 個 background agent 同時跑**（backend / frontend / pipeline / qa / ui-designer），各自循序處理 lane 內所有 issue。

### Phase 4.5：PR 自動 merge（不再 per-PR review）

**Code review 改成 sprint-end 一次性執行**（見 Phase 5.5），這裡的 PR 只要：
1. CI build-and-lint 通過
2. push 前 `local-checks.sh` 通過（engineer / qa agent 自己會跑）

就可以直接 merge。Engineer / QA agent 在自己的 loop 裡發完 PR 就**自行 merge**：

```bash
# Engineer / QA agent loop 內的 merge 邏輯
gh pr checks {pr_number} --watch  # 等 CI 跑完
gh pr merge {pr_number} --squash --delete-branch  # build-and-lint 過就 merge
```

**為什麼不 per-PR review**：
- per-PR 看不到跨 lane 對齊問題（frontend testid 對 qa testid 各自看都對，合起來不對）
- Engineer 等 review 卡住 lane drain
- 改成 sprint-end 一次完整 review 看到全貌、找問題更準

Branch protection 配合改成只要 `build-and-lint` 過、不再要求 approval（見 `init-github.sh`）。

### Phase 4.9：Infra 確認（Sprint 測試前，需使用者確認）

所有 PR 通過 code review 並合併後，**在執行測試前**向使用者確認 infra 狀態。
使用 `AskUserQuestion` 提供一致的 UI 介面：

```javascript
// Step 1: 確認測試環境
AskUserQuestion({
  questions: [
    {
      question: "Sprint {N} 的 BDD 測試準備開始，測試環境怎麼處理？",
      header: "Infra",
      multiSelect: false,
      options: [
        {
          label: "自動部署 (Recommended)",
          description: "使用 docker compose up 自動啟動所有服務（根據 specs/infra.md 設定）",
          preview: "cd dev\ncp docker-compose.example.yml docker-compose.yml\ncp .env.example .env\ndocker compose up -d --build\n\n# 等待 health check 通過後自動執行測試"
        },
        {
          label: "服務已在運行",
          description: "我的本機服務已經在跑了，直接執行測試就好"
        },
        {
          label: "需要調整設定",
          description: "port 或設定有衝突，我先處理完再開始"
        }
      ]
    },
    {
      question: "App 的測試 URL 是？",
      header: "URL",
      multiSelect: false,
      options: [
        { label: "http://localhost:3000 (Recommended)", description: "Docker Compose 預設（見 specs/infra.md）" },
        { label: "http://localhost:8000", description: "Python/FastAPI 預設" },
        { label: "http://localhost:8080", description: "Go/Java 預設" }
      ]
    }
  ]
})
```

根據使用者回答：

- **自動部署** → 執行 `cd dev && docker compose up -d --build`，等待 health check，自動進入 Phase 5
- **服務已在運行** → 跳過 docker compose，直接用指定 URL 進入 Phase 5
- **需要調整設定** → 暫停等待使用者處理完畢，再次確認後進入 Phase 5

**如果使用者選了自訂 URL（Other）**，將 BASE_URL 傳入 QA agent。

### Phase 5：Sprint BDD 測試（本地執行，orchestrator 跑）

**BDD 不在 CI 上跑** — playwright + docker compose 在 GitHub Actions 上慢、易超時、port 衝突；改在 orchestrator 的本地環境跑（使用者的機器或 self-hosted runner）。

```bash
SPRINT="{current_sprint}"
SPRINT_NUM=$(echo "$SPRINT" | grep -oE '[0-9]+' | head -1)

# 1. 確認 4 lane 全關（feature/design/qa/bug）
for LABEL in feature design qa bug; do
  OPEN=$(gh issue list --milestone "$SPRINT" --label "$LABEL" --state open --json number --jq 'length')
  if [ "$OPEN" != "0" ]; then
    echo "Lane $LABEL 還有 $OPEN 個 open issue，等 engineer/qa drain"
    bash .claude/scripts/state.sh phase "phase-4-impl" "wait lane $LABEL"
    exit 0
  fi
done

# 2. 確認本機 docker / node 已就緒（doctor.sh 已在 phase 0 跑過，這裡只做最終確認）
docker compose version >/dev/null 2>&1 || { echo "🔴 docker compose 不在，無法跑 BDD"; exit 1; }

# 3. 跑 BDD（限定 @sprint-N scope）
SPRINT_TAG="@sprint-${SPRINT_NUM}" \
BASE_URL="${BASE_URL:-http://localhost:3000}" \
  bash .claude/scripts/run-sprint-tests.sh all
OUTCOME=$?

# 4. 寫結果到 state.json，BDD 過 → 進 sprint review；BDD 失敗 → 建 bug 重啟 lane
if [ "$OUTCOME" = "0" ]; then
  bash .claude/scripts/state.sh set sprint_test_outcome '"success"'
  bash .claude/scripts/state.sh phase "phase-5.5-review" "啟動 sprint code review"
else
  bash .claude/scripts/state.sh set sprint_test_outcome '"failure"'
  bash .claude/scripts/state.sh phase "phase-5-bdd" "BDD 失敗，建 bug issue"
fi
```

#### 失敗處理（orchestrator 自動建 bug + 重啟 lane）

```bash
if [ "$OUTCOME" != "0" ]; then
  # 從 cucumber JSON 抽失敗 scenario
  FAILED=$(jq -r '
    [.[].elements[] | select(.steps | any(.result.status == "failed"))]
    | map("- \(.name) (\(.tags[0].name // "no-tag"))") | join("\n")
  ' test/reports/cucumber-report.json 2>/dev/null || echo "(無法解析 report)")

  # 從 tag 推 lane（@backend / @frontend / @pipeline），預設 backend
  LANE=$(echo "$FAILED" | grep -oE '@(backend|frontend|pipeline)' | head -1 | tr -d '@')
  LANE="${LANE:-backend}"

  gh issue create \
    --title "🐛 [Bug] Sprint $SPRINT BDD failed" \
    --label "bug,$LANE" \
    --milestone "$SPRINT" \
    --body "本地 BDD 測試失敗（@sprint-${SPRINT_NUM}）

### 失敗的 Scenario
$FAILED

### 報告
\`test/reports/cucumber-report.json\` + \`test/screenshots/\`

### 修復流程
Engineer 修完 PR merge → 關此 bug → orchestrator 自動回到 Phase 5 重跑 BDD"
fi
```

- `success` → 進入 Phase 5.5 verifier
- `failure` → 自動建 bug issue（4 lane 重新打破平衡） → engineer lane 重啟 → drain → 回到 Phase 5 重跑 BDD

#### 為什麼 BDD 不上 CI

1. **本地 docker compose 比 CI 快** — image cache、不用每次 cold-pull
2. **port 衝突風險** — CI 上 Playwright + docker compose 容易 race
3. **可重現** — 出錯時使用者機器上直接 `npx playwright show-trace` 看 trace
4. **省 CI 分鐘** — sprint 收斂頻率不高（每次 sprint 結束 1 次），不需要每次 PR 都跑

CI 只負責**輕量 gate**（unit / lint / contract-check / bddgen 0 undefined），重量級 e2e 留在本地。

**每輪重測前再次確認環境**：
```javascript
AskUserQuestion({
  questions: [{
    question: "Bug 已修復，要重新執行 BDD 測試嗎？",
    header: "重測",
    multiSelect: false,
    options: [
      { label: "重新測試 (Recommended)", description: "重新啟動服務並執行所有 BDD scenarios" },
      { label: "只測失敗的", description: "只重跑上次失敗的 scenarios" },
      { label: "暫停", description: "我需要先手動檢查，稍後再測" }
    ]
  }]
})
```

### Phase 5.5：Sprint Code Review（背景自動，一次性全面審查）

BDD 全綠後啟動 code-review agent 對**整個 sprint diff** 做一次全面 review：

```
Agent(subagent_type="code-review", run_in_background=true,
      prompt="sprint=$SPRINT, sprint_base=$SPRINT_BASE_SHA")
```

Code reviewer 檢查：
- **Contract 對齊（CRITICAL）**：testid / API path / toast 三邊是否一致
- **Spec 一致性（CRITICAL）**：實作是否覆蓋所有 @sprint-N scenario
- **安全性（CRITICAL）**：injection / 認證 / 敏感資料
- **Code 品質（WARNING）**：命名、重複邏輯、error handling
- **跨 lane 一致（WARNING）**：backend/frontend/qa 對接點
- **Docker / Infra（WARNING）**：example 檔同步

結果：
- **PASS / WARNING** → 進入 Phase 5.6 verifier
- **FAIL（有 CRITICAL）** → 對每個 CRITICAL 建 bug issue（自動推 lane）→ engineer 修 → 重跑 BDD → 重 review
- 報告寫到 `specs/logs/sprint-{N}-review.md`

### Phase 5.6：三維度驗證（背景自動）

```
Agent(subagent_type="verifier", run_in_background=true)
```

Verifier 檢查：
- **Completeness**：所有 spec 有實作？所有 scenario 有 test？
- **Correctness**：實作行為符合 spec？API/error codes 一致？
- **Coherence**：程式碼風格統一？設計決策被遵守？

結果：
- PASS → Phase 6
- WARNING → Phase 6（附帶建議）
- FAIL → 建 bug issue → engineer 修復 → 重新驗證

### Phase 6：自動產出工作日誌 + 關閉 Sprint

**QA 完整測試通過 + 三維度驗證通過後自動執行，不需使用者介入。**

1. 產出 Sprint 工作日誌到 `specs/logs/sprint-{N}-log.md`
2. 在 Epic issue 留言 Sprint 報告
3. 關閉 Sprint Milestone + Sprint Issue
4. 通知使用者 Sprint 完成摘要

```
✅ Sprint {N} 完成！

📊 摘要：
Features: X | PRs: X | Bugs fixed: X

🧪 BDD 測試結果（docker compose 環境）：
  Unit Tests: X passed
  BDD Scenarios: X/Y passed (playwright-bdd)

✅ Verify: PASS（Completeness + Correctness + Coherence）

📋 工作日誌：specs/logs/sprint-{N}-log.md
驗證報告：specs/verify-sprint-{N}.md
```

### Phase 7：推進下一個 Sprint（需使用者確認）

如果有下一個 sprint milestone，向使用者確認後啟動：

```javascript
AskUserQuestion({
  questions: [{
    question: "Sprint {N} 完成！要自動開始 Sprint {N+1} 嗎？",
    header: "下一步",
    multiSelect: false,
    options: [
      { label: "開始 Sprint {N+1} (Recommended)", description: "自動啟動 tech-lead → engineer + qa 流程" },
      { label: "暫停", description: "我想先 review Sprint {N} 的成果，之後再開始" },
      { label: "直接 Release", description: "目前功能已夠用，直接進入部署流程" }
    ]
  }]
})
```

如果所有 sprint 都完成：
```javascript
AskUserQuestion({
  questions: [{
    question: "所有 Sprint 完成！下一步？",
    header: "完成",
    multiSelect: false,
    options: [
      { label: "部署 Production", description: "執行 /specflow:release 部署流程" },
      { label: "先 Review", description: "我想先檢查完整專案再部署" }
    ]
  }]
})
```

## 重要

- **只有 spec 討論需要使用者互動**
- **Sprint 之間的推進完全自動**，不需手動 release
- `/specflow:release` 僅用於 production 部署確認
- `specs/` 目錄是 source of truth，所有 agent 從這裡讀取規格
- 依賴分析自動化，不需手動判斷 wave
- 三維度驗證確保交付品質

## Context 中斷時

如果 context 滿了被 `/clear`，或關閉 session 後想接著做：執行 `/specflow:resume` 從 `.specflow/state.json` 重建狀態並繼續。**所有持久狀態都在 GitHub Issues + state.json，不在對話裡。**
