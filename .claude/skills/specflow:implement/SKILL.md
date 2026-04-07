---
name: specflow:implement
description: 啟動實作流程。多個 engineer agent 背景並行認領 feature issues，同時 QA agent 根據 spec 撰寫 e2e test。觸發關鍵字："implement", "實作", "開發"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[feature issue 編號，或 all]"
---

# 實作流程（Engineer + QA 同時進行）

## 情況 A：指定 feature
$ARGUMENTS 指定 feature issue 編號，啟動一個 engineer agent。

## 情況 B：全部（預設）

同時啟動：

### Engineer Agents
讀取當前 sprint 的 `feature` issues，分 wave 啟動：
```
Wave 1（無依賴）：每個 feature 一個 agent
  Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")

Wave 2（有依賴）：等 Wave 1 完成
```

### QA Agent（同步進行）
```
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree")
```

## Code Review Loop（每個 PR 完成後自動觸發）

每個 Engineer PR 或 QA PR 完成後，啟動 code-review agent 審查：

```
# 使用 sonnet 模型（只讀不寫，節省 token 成本）
Agent(subagent_type="code-review", run_in_background=true)
  input: PR #{pr_number}, Issue #{issue_number}
```

### Review 結果處理

- **APPROVED** → PR ready to merge
- **REQUEST_CHANGES** → 對應的 engineer/qa agent 自動處理 review comments 並推送修正 → code-review 重新 review
- **最多 3 輪**：超過 3 輪標記 `blocked`，需人工介入

### 觸發方式

Engineer PR 和 QA PR 可以**並行 review**，因為 code-review agent 不需要 worktree（只讀不寫）：

```
# 同時啟動多個 review
Agent(subagent_type="code-review", run_in_background=true)  # review engineer PR #1
Agent(subagent_type="code-review", run_in_background=true)  # review engineer PR #2
Agent(subagent_type="code-review", run_in_background=true)  # review QA PR
```

## 完成後
所有 PR 通過 code review 並合併 → 執行 e2e tests → 有 bug 自動建 issue + 修復 → 通知使用者
