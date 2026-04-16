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

### Phase 1：初始化（自動）

```bash
LABEL_COUNT=$(gh label list --json name --jq 'length')
if [ "$LABEL_COUNT" -lt 7 ]; then
  bash .claude/scripts/init-github.sh
fi
mkdir -p specs/features specs/changes specs/changes/archive
```

### Phase 2：Spec 討論（使用者參與）

啟動 spec-writer agent（**前景，需使用者互動**）：
- `subagent_type: "spec-writer"`
- `run_in_background: false`
- 傳入 $ARGUMENTS

spec-writer 產出：
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
2. 讀取 `specs/` 目錄，自動分析依賴圖譜，產出 `specs/dependencies.md`
3. 建立 feature issues（含 scenarios + 實作指引 + 技術選型）
4. 建立 QA issue（含 scenarios 清單）
5. 建立 design issue（含 UI 元件清單，如 sprint 有 UI 功能）

### Phase 4：Engineer + QA + UI Designer 同時啟動（背景並行）

tech-lead 完成後，根據 `specs/dependencies.md` 的 wave 分組：

#### Wave 0（先行，同時啟動）
```
# UI Designer — 建立 component dataset
Agent(subagent_type="ui-designer", run_in_background=true, isolation="worktree")

# QA — 撰寫 test scripts
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree")

# Engineer（無 UI 依賴的 feature）
Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")
```

#### Wave 1（Wave 0 完成後）
```
# Engineer（需要 UI 元件的 feature，等 ui-designer 完成）
Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")
```

### Phase 4.5：Code Review（每個 PR 完成後自動觸發）

Engineer 或 QA 發 PR 後，**自動啟動 code-review agent** 進行審查：

```
# 使用 sonnet 模型（只讀不寫，節省 token 成本）
Agent(subagent_type="code-review", run_in_background=true)
  input: PR #{pr_number}, Issue #{issue_number}
```

**Review Loop（最多 3 輪）**：
1. code-review agent 審查 PR → APPROVE / REQUEST_CHANGES
2. REQUEST_CHANGES → 通知對應的 engineer/qa agent 處理 review comments → 推送修正
3. code-review agent 重新 review
4. APPROVED → PR ready to merge

**重要**：
- Branch protection 要求 1 approval + 所有 conversation resolved 才能 merge
- code-review 使用 sonnet 模型，因為只需要閱讀和判斷，不需要生成程式碼
- engineer 已有處理 review comments 的機制（見 engineer.md 第七步）
- 所有 PR 通過 review 並合併後 → Phase 5

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

### Phase 5：Sprint BDD 測試（Infra 確認後自動執行）

QA 執行 sprint 完整 BDD 測試（使用 Phase 4.9 確認的環境）：
1. 如需要，用 `dev/docker-compose.yml` 啟動服務
2. 確認 health check 通過
3. `npx bddgen` 從 .feature 生成 Playwright tests
4. `BASE_URL={使用者確認的 URL} npx playwright test`
5. 停止服務（如果是自動部署的）
6. 全部 .feature scenarios 通過 → Phase 5.5
7. 有失敗 → QA 建 bug issue（附截圖 + 失敗 Gherkin 場景）→ engineer 修復 → 重測（最多 3 輪）

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

### Phase 5.5：三維度驗證（背景自動）

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
