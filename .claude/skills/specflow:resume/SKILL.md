---
name: specflow:resume
description: 從 .specflow/state.json 讀取 SpecFlow 流程進度，重建狀態後繼續執行。在 /clear context 之後、或重開 session 時用來接續工作。觸發關鍵字："resume", "繼續", "接續"。
user-invocable: true
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# SpecFlow Resume — 從上次中斷處接續

## 為什麼需要這個

SpecFlow 流程跨多個 phase 可能持續好幾小時，對話 context 會被 `/clear` 或溢出截斷。
所有持久狀態都寫在 `.specflow/state.json` + GitHub Issues，這個 skill 從這些 source of truth 重建狀態繼續跑。

## 步驟

### 1. 讀取 state file

```bash
bash .claude/scripts/state.sh show
```

如果檔案不存在 → 告知使用者「沒有進行中的流程，請用 `/specflow:start` 開始」。

### 2. 從 GitHub 重建即時狀態

對照 state.json 與當前 GitHub 狀態（避免依賴可能過時的 in_flight_agents）：

```bash
# 當前 sprint milestone
gh api "repos/:owner/:repo/milestones?state=open&sort=title" --jq '[.[] | select(.title | startswith("Sprint"))][0]'

# Sprint 內未關閉的 issue
gh issue list --milestone "$SPRINT" --state open --json number,title,labels,assignees

# 進行中的 PR
gh pr list --state open --json number,title,headRefName,statusCheckRollup,reviewDecision
```

### 3. 報告當前狀態給使用者

用簡短格式（**不要 dump 整個 state.json**）：

```
📍 接續 Sprint {N}（phase: {phase}）

進行中：
- PR #47 (engineer, feature F-002) — review 第 2/3 輪
- PR #48 (qa) — APPROVED, waiting merge
- Issue #51 (bug) — open

下一步：{next_action}
```

### 4. 詢問如何繼續

```javascript
AskUserQuestion({
  questions: [{
    question: "要從這裡繼續嗎？",
    header: "Resume",
    multiSelect: false,
    options: [
      { label: "繼續 (Recommended)", description: "從 next_action 接著跑" },
      { label: "重新評估", description: "我想看更多細節再決定" },
      { label: "重來這個 phase", description: "把當前 phase 重跑一次" }
    ]
  }]
})
```

### 5. 根據 phase 路由到對應 orchestrator

| phase | 接續動作 |
|-------|---------|
| `phase-2-spec` | 啟動 spec-writer 繼續討論 |
| `phase-3-techlead` | 啟動 tech-lead（背景） |
| `phase-4-impl` | 啟動 engineer/qa/ui-designer（背景，根據未完成的 issue） |
| `phase-4.5-review` | 對 open PR 啟動 code-review |
| `phase-4.9-infra` | 用 AskUserQuestion 確認 infra |
| `phase-5-bdd` | 執行 BDD 測試 |
| `phase-5.5-verify` | 啟動 verifier |
| `phase-6-close` | 產出 sprint log + 關 milestone |
| `phase-7-next` | 詢問是否進入下一個 sprint |

## 重要原則

- **GitHub Issues 是 source of truth**，state.json 只是 cache，衝突時以 GitHub 為準
- 不要重複建立已存在的 issue / milestone / PR
- 重啟 background agent 前先檢查對應 PR 是否已存在（避免重複工作）
