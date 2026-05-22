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

- **有網址** → 把 URL 傳給 spec-writer，它會跑 `sync-design.sh` 下載 HTML + 截圖到 `specs/design-source/`，然後從本地快照反推 spec（後續所有 agent 只讀本地，不再上網 fetch）
- **純 backend** → spec-writer 走傳統討論模式（無 design 約束）
- **去做 design** → orchestrator 暫停，state.json 標記 `phase=phase-2-await-design`

啟動 spec-writer agent（**前景，需使用者互動**）：
- `subagent_type: "spec-writer"`
- `run_in_background: false`
- 傳入 $ARGUMENTS（含 design URL，如有）

spec-writer 產出：
- `specs/design-source.md` — Claude design URL 的 fetch 快照（如有）
- `specs/` 目錄下的 spec 檔案（source of truth）
- `specs/features/*.md` 中的 acceptance criteria（QA 轉成 Playwright e2e tests）
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
4. 驗證 specs/sprints/sprint-N.md 存在且列出 feature ID（hard gate）
5. 建立 feature issues（含 scenarios + 實作指引 + 技術選型 + contract reference）
6. 建立 QA issue（含 scenarios 清單 + contract reference）
7. 建立 design issue — **僅在 `specs/design-source.md` 存在時建**：要求 ui-designer 從 design URL 抽 tokens / 元件 / 字串到 `design/`，產出 handoff 給 tech-lead 在 contract phase 吸進 contracts/。純 backend 專案則不開 design issue。

**Contract 沒寫完不開 issue** — 否則 engineer 開始寫程式碼時 contract 還沒對齊，會出現 hardcoded literal 滿天飛。

> **Design-led 順序提示**：理想上 ui-designer 應**先於** tech-lead 完成 contract phase（因為 dom.md / ux-text.md 要吸 ui-designer 的 handoff）。orchestrator 可以先開 design issue → ui-designer 完成 handoff → tech-lead 才產 contracts → 才開 feature/qa issues。

### Phase 3.8：把 specs/ commit 進 main（hard gate — 否則 lane agent 讀不到）

spec-writer 與 tech-lead 寫的 `specs/`（overview / features / sprints / contracts / contracts.ts / dependencies）若還停在 working tree **未進版控**，worktree-isolated 的 engineer/qa/ui-designer 從 origin clone 後**完全讀不到 spec 與 contract**，整個 sprint 會憑空亂寫。spawn lane 前必須確認 specs/ 已在 main：

```bash
cd <project-root>
if [ -n "$(git status --porcelain specs/)" ]; then
  git add specs/
  git commit -q -m "docs(spec): sprint 規劃產出（spec + contracts）納入版控"
  git push -q origin main || {
    # main 受保護無法直推 → 開 PR 合併
    git checkout -b "chore/sprint-specs" && git push -u -q origin chore/sprint-specs
    PR=$(gh pr create --title "docs(spec): sprint specs + contracts" --body "spec-writer + tech-lead 產出" --json number --jq .number)
    gh pr merge "$PR" --squash --delete-branch && git checkout main && git pull -q
  }
fi
# 確認 contract 三件套 + contracts.ts 確實在 main 上（讀不到就 short-circuit）
git cat-file -e "main:specs/contracts.ts" 2>/dev/null || { echo "🔴 specs/contracts.ts 不在 main，lane agent 會讀不到，停"; exit 1; }
```

### Phase 3.9：記錄 sprint_base_sha（給 sprint-end review 用）

在啟動 lane 前先把當前 main HEAD 紀錄起來，這是 sprint review 的 diff 起點（須在 Phase 3.8 commit 之後）：

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

就可以直接 merge。Engineer / QA agent 在自己的 loop 裡發完 PR 就走 `ready-and-merge.sh` **自行 merge**（ready→等 CI→squash merge 三合一）。

Branch protection 配合改成只要 `build-and-lint` 過、不再要求 approval（見 `init-github.sh`）。理由見 `docs/DESIGN-RATIONALE.md`。

### Phase 4.9：Infra 確認（Sprint 測試前，需使用者確認）

所有 PR 通過 code review 並合併後，**在執行測試前**向使用者確認 infra 狀態。
使用 `AskUserQuestion` 提供一致的 UI 介面：

```javascript
// Step 1: 確認測試環境
AskUserQuestion({
  questions: [
    {
      question: "Sprint {N} 的 e2e 測試準備開始，測試環境怎麼處理？",
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

### Phase 5：Sprint e2e 測試（CI 自動跑，orchestrator 等結果）

**e2e 在 CI 上跑** — 4 lane 全關後 `.github/workflows/sprint-test.yml` 自動觸發。orchestrator 此 phase 只需輪詢 workflow 結果。

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

# 2. Workflow 已被最後一個 issue close 自動觸發了；orchestrator 輪詢結果
echo "4 lane 全關，等 Sprint E2E Test workflow..."
for i in $(seq 1 80); do  # 最多等 40 分鐘（每次 30s）
  RUN=$(gh run list --workflow "Sprint E2E Test" --limit 1 \
    --json conclusion,status,databaseId --jq '.[0]')
  STATUS=$(echo "$RUN" | jq -r '.status')
  CONCLUSION=$(echo "$RUN" | jq -r '.conclusion')
  RUN_ID=$(echo "$RUN" | jq -r '.databaseId')
  [ "$STATUS" = "completed" ] && break
  echo "[$i] workflow status: $STATUS"
  sleep 30
done

# 3. 寫結果到 state.json
if [ "$CONCLUSION" = "success" ]; then
  bash .claude/scripts/state.sh set sprint_test_outcome '"success"'
  bash .claude/scripts/state.sh phase "phase-5.5-review" "啟動 sprint code review"
else
  bash .claude/scripts/state.sh set sprint_test_outcome "\"$CONCLUSION\""
  bash .claude/scripts/state.sh phase "phase-5-e2e" "e2e workflow 未通過"
  # workflow 已自動建 bug issue + lane 重新打開（見 sprint-test.yml）
  # orchestrator 不用做事，等 engineer 修完 bug 關掉 → workflow 自動再次觸發 → 回到此 phase 輪詢
fi
```

- `success` → 進入 Phase 5.5 sprint code review → Phase 5.6 verifier
- `failure` → workflow 已自動建 bug issue（lane label 從失敗推測）→ engineer lane 重啟修復 → bug close 自動觸發新 workflow run → orchestrator 重新進入 Phase 5 輪詢

> e2e 上 CI 的 5 點理由（可重現 / 可見性 / artifacts 集中 / verifier 信任源 / 解放本機）見 `docs/DESIGN-RATIONALE.md`。

### Phase 5.5：Sprint Code Review（背景自動，一次性全面審查）

e2e 全綠後啟動 code-review agent 對**整個 sprint diff** 做一次全面 review：

```
Agent(subagent_type="code-review", run_in_background=true,
      prompt="sprint=$SPRINT, sprint_base=$SPRINT_BASE_SHA")
```

Code reviewer 檢查：
- **Contract 對齊（CRITICAL）**：testid / API path / toast 三邊是否一致
- **Spec 一致性（CRITICAL）**：實作是否覆蓋所有當前 sprint feature 的 acceptance criteria
- **安全性（CRITICAL）**：injection / 認證 / 敏感資料
- **Code 品質（WARNING）**：命名、重複邏輯、error handling
- **跨 lane 一致（WARNING）**：backend/frontend/qa 對接點
- **Docker / Infra（WARNING）**：example 檔同步

結果：
- **PASS / WARNING** → 進入 Phase 5.6 verifier
- **FAIL（有 CRITICAL）** → 對每個 CRITICAL 建 bug issue（自動推 lane）→ engineer 修 → 重跑 e2e → 重 review
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

🧪 E2E 測試結果（docker compose 環境）：
  Unit Tests: X passed
  E2E Tests: X/Y passed (Playwright)

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
