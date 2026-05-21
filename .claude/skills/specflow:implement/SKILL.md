---
name: specflow:implement
description: 啟動實作流程（Lane 制：每個類型同時最多 1 個 agent）。Backend / Frontend / Pipeline 各自 1 個 engineer，加 1 個 QA、1 個 UI Designer，共最多 5 個 background agent。觸發關鍵字："implement", "實作", "開發"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[feature issue 編號，或 all]"
---

# 實作流程（Lane 制 + per-lane clone 隔離）

**核心規則**：每個 lane 同時最多 1 個 agent，agent 在 lane 內 loop 認領 issue。

**⚠️ 隔離方式（v6 後更新，不要用 `isolation="worktree"`）**：`isolation="worktree"` 只隔離 agent 自己的 specflow worktree，4 個 agent 仍會 cd 到同一個 repo 寫檔造成 cross-lane race（benchmark v3 實證）。**正確做法是用 `dispatch-impl.sh` 為每個 lane 建立獨立 demo clone**，agent 在自己的 clone 工作，只透過 origin fetch 看別人 merged 的結果。

| Lane | Agent | Issue 條件 |
|------|-------|-----------|
| backend | engineer | `feature,backend` 或 `bug,backend`，open 且未 assigned |
| frontend | engineer | `feature,frontend` 或 `bug,frontend` |
| pipeline | engineer | `feature,pipeline` 或 `bug,pipeline` |
| qa | qa-engineer | `qa`，當前 sprint |
| ui | ui-designer | `design`，當前 sprint |

## 情況 A：指定單一 issue

`$ARGUMENTS` 指定 issue 編號，從該 issue 的 lane label 自動判斷類型。先 `CLONE=$(bash .claude/scripts/dispatch-impl.sh "$REPO" "$LANE")` 建 clone，再啟動 1 個對應 agent（cwd=$CLONE）處理該 issue。

## 情況 B：全部（預設）— per-lane clone + 啟動 lane

```bash
SPRINT="{current_sprint}"
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

# 為每個有 issue 的 lane 建立 isolated clone + 啟動 agent
for LANE in backend frontend pipeline; do
  COUNT=$(gh issue list --milestone "$SPRINT" --label "$LANE" --state open --json number --jq 'length')
  [ "$COUNT" -eq 0 ] && continue
  CLONE=$(bash .claude/scripts/dispatch-impl.sh "$REPO" "$LANE")
  bash .claude/scripts/state.sh lane-track "engineer-$LANE" clone_path "$CLONE"
  bash .claude/scripts/state.sh agent-add "engineer-$LANE" 0 null "" "running"
  # Agent(subagent_type="engineer", run_in_background=true,
  #   prompt="cwd=$CLONE, lane=$LANE, sprint=$SPRINT。
  #           認領每個 issue 後【第一個 Bash 必須是】
  #             DRAFT_PR=$(bash .claude/scripts/deliver-first.sh \"$ISSUE\" \"$SLUG\" \"$TITLE\" \"feature,$LANE\")
  #           frontend lane【第二個 Bash 必須是】bash .claude/scripts/frontend-scaffold.sh \"$ISSUE\"
  #           完成才能 Read spec / 寫 code。循序清空 lane 全部 open issues。
  #           lane 清空跑 state.sh lane-close feature（自動觸發 sweep）。")
done

# QA：1 個 clone + agent
QA=$(gh issue list --milestone "$SPRINT" --label "qa" --state open --json number --jq 'length')
if [ "$QA" -gt 0 ]; then
  CLONE=$(bash .claude/scripts/dispatch-impl.sh "$REPO" "qa")
  bash .claude/scripts/state.sh lane-track "qa" clone_path "$CLONE"
  # Agent(subagent_type="qa-engineer", run_in_background=true,
  #   prompt="cwd=$CLONE, sprint=$SPRINT。第一個 Bash 必須是 deliver-first.sh（branch_prefix test/）。")
fi

# UI Designer：1 個 clone + agent（只在有 design issue 時）
DESIGN=$(gh issue list --milestone "$SPRINT" --label "design" --state open --json number --jq 'length')
if [ "$DESIGN" -gt 0 ]; then
  CLONE=$(bash .claude/scripts/dispatch-impl.sh "$REPO" "design")
  bash .claude/scripts/state.sh lane-track "design" clone_path "$CLONE"
  # Agent(subagent_type="ui-designer", run_in_background=true,
  #   prompt="cwd=$CLONE, sprint=$SPRINT。第一個 Bash 必須是 deliver-first.sh（branch_prefix design/）。")
fi
```

**最多 5 個 background agent**：backend / frontend / pipeline / qa / ui-designer，各自獨立 clone。

> **前提**：dispatch 4 lane 前，tech-lead 的 contract 三件套 commit **必須已 push 到 origin/main**（否則 clone 拿不到 contracts）。tech-lead.md 已含 push 自驗；orchestrator 可在 dispatch 前再確認 `git ls-remote origin main` 含最新 contract commit。

## Agent 內的 deliver-first（不可省）

每個 engineer / qa / ui-designer agent 認領 issue 後**第一個 Bash 必須是 `deliver-first.sh`**（1 個 Bash 完成 fetch+rebase → branch → empty commit → push + draft PR）。frontend lane 第二個 Bash 必須是 `frontend-scaffold.sh`。詳見各 agent.md 的 🛑 deliver-first 段。

## PR 自動 merge（無 per-PR review）

Engineer / QA 發 PR 後**自行 `gh pr ready` → 等 CI → merge**，不啟動 per-PR code-review agent：

```bash
gh pr ready {pr_number}
gh pr checks {pr_number} --watch
gh pr merge {pr_number} --squash --delete-branch
```

CI 只跑 build-and-lint；test 在 push 前 `local-checks.sh` 已過。Code review 改成 sprint-end 一次性執行（見 `specflow:start` Phase 5.5）。

## 4 lane drain 後（orchestrator 兜底）

所有 lane agent 回報後，orchestrator **跑一次 sweep 補開漏掉的 PR**（agent 撞 cap 沒開 PR 的安全網）：

```bash
# 在主 demo repo（非 clone）跑
bash .claude/scripts/sweep-missing-prs.sh
```

`state.sh lane-close` 已會自動觸發 sweep，這裡是雙保險。

## 完成後

所有 lane drain 完畢 + 所有 PR merge → `specflow:start` Phase 4.9 infra 確認 → Phase 5 e2e 測試 → Phase 5.5 sprint code review → Phase 5.6 verifier
