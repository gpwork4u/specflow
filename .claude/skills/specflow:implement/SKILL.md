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

## PR 自動 merge（無 per-PR review）

Engineer / QA 發 PR 後**自行等 CI 過後 merge**，不再啟動 per-PR code-review agent：

```bash
# Engineer / QA agent loop 內的 merge 邏輯
gh pr checks {pr_number} --watch
gh pr merge {pr_number} --squash --delete-branch
```

CI 只跑 build-and-lint；test 在 push 前 `local-checks.sh` 已過。Code review 改成 sprint-end 一次性執行（見 `specflow:start` Phase 5.5）。

## 完成後

所有 lane drain 完畢 + 所有 PR merge → `specflow:start` Phase 4.9 infra 確認 → Phase 5 BDD 測試 → Phase 5.5 sprint code review → Phase 5.6 verifier
