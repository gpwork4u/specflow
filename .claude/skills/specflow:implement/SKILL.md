---
name: specflow:implement
description: 啟動實作流程（Lane 制：每個類型同時最多 1 個 agent）。Backend / Frontend / Pipeline 各自 1 個 engineer，加 1 個 QA、1 個 UI Designer，共最多 5 個 background agent。觸發關鍵字："implement", "實作", "開發"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[feature issue 編號，或 all]"
---

# 實作流程（Lane 制）

**核心規則**：每個 lane 同時最多 1 個 agent，agent 在 lane 內 loop 認領 issue。
避免 worktree 衝突、token 暴增、merge race condition。

| Lane | Agent | Issue 條件 |
|------|-------|-----------|
| backend | engineer | `feature,backend` 或 `bug,backend`，open 且未 assigned |
| frontend | engineer | `feature,frontend` 或 `bug,frontend` |
| pipeline | engineer | `feature,pipeline` 或 `bug,pipeline` |
| qa | qa-engineer | `qa`，當前 sprint |
| ui | ui-designer | `design`，當前 sprint |

## 情況 A：指定單一 issue

`$ARGUMENTS` 指定 issue 編號，從該 issue 的 lane label 自動判斷類型，啟動 1 個對應 agent 處理該 issue。

## 情況 B：全部（預設）— 啟動 lane

```bash
SPRINT="{current_sprint}"

# Engineer：三個 lane 各最多 1 個（只啟動有 issue 的）
for LANE in backend frontend pipeline; do
  COUNT=$(gh issue list --milestone "$SPRINT" --label "$LANE" --state open --json number --jq 'length')
  if [ "$COUNT" -gt 0 ]; then
    bash .claude/scripts/state.sh agent-add "engineer-$LANE" 0 null "" "running"
    # Agent(subagent_type="engineer", run_in_background=true, isolation="worktree",
    #       prompt="lane=$LANE, sprint=$SPRINT, 循序清空 lane 全部 open issues")
  fi
done

# QA：1 個（撰寫 step definitions）
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree",
      prompt="sprint=$SPRINT")

# UI Designer：1 個（只在有 design issue 時）
DESIGN=$(gh issue list --milestone "$SPRINT" --label "design" --state open --json number --jq 'length')
[ "$DESIGN" -gt 0 ] && Agent(
  subagent_type="ui-designer", run_in_background=true, isolation="worktree",
  prompt="sprint=$SPRINT"
)
```

**最多 5 個 background agent**：backend / frontend / pipeline / qa / ui-designer。

## Code Review Loop（每個 PR 完成後自動觸發）

每當 engineer 或 QA 發 PR，**code-review agent 在背景啟動**審查（sonnet model，唯讀，無 lane 限制可同時多個）：

```
Agent(subagent_type="code-review", run_in_background=true)
  input: PR #{pr_number}, Issue #{issue_number}
```

### Review 結果處理

- **APPROVED** → PR ready to merge（branch protection 檢查通過後 merge）
- **REQUEST_CHANGES** → 在原 issue 加 `needs-revision` label，**該 lane 的下一輪 loop 會優先處理**（同 lane engineer 不會搶兩個 worktree）
- **最多 3 輪**：超過標記 `blocked`，需人工介入

## 完成後

所有 lane drain 完畢 + 所有 PR merge → `specflow:start` Phase 4.9 infra 確認 → Phase 5 BDD 測試
