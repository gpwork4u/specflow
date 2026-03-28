---
name: start
description: 啟動完整的 specflow 專案流程。使用者只需與 spec agent 對話確認需求和架構，之後 tech-lead 分析 → (engineer + qa 並行) → 驗證 → bug fix 全部自動背景執行。觸發關鍵字："start", "開始", "啟動專案", "新專案"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
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
```

### Phase 2：Spec 討論（使用者參與）

啟動 spec-writer agent（**前景，需使用者互動**）：
- `subagent_type: "spec-writer"`
- `run_in_background: false`
- 傳入 $ARGUMENTS

spec-writer 產出：
- Epic Issue（含技術架構）
- Feature Issues（含完整 API contract + 測試場景）
- Sprint Milestones

### Phase 3：Tech Lead 分析（背景自動）

啟動 tech-lead agent（**背景**）：
- `subagent_type: "tech-lead"`
- `run_in_background: true`

tech-lead 在每個 feature issue 留言補充實作指引，並在 epic 標註並行策略。
**不建立新 issue**，feature issue 本身就是工作項目。

### Phase 4：Engineer + QA 同時啟動（背景並行）

tech-lead 完成後，**同時**啟動：

#### Engineer Agents
讀取 tech-lead 的並行策略，分 wave 啟動：
```
Wave 1（無依賴）：每個 feature 一個 agent，同時啟動
  Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")

Wave 2（有依賴）：等 Wave 1 完成
  Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")
```

#### QA Agent
同時啟動，根據 spec API contract 撰寫 e2e test script：
```
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree")
```

### Phase 5：測試驗證（全部完成後自動）

所有 engineer PR + QA test PR 完成後：
1. 執行 e2e tests
2. 全部通過 → Phase 6
3. 有失敗 → QA 建 bug issue → engineer 修復 → 重測（最多 3 輪）

### Phase 6：Sprint 完成通知（使用者確認）

```
✅ Sprint {N} 完成！
Features: X | PRs: X | E2E Tests: X passed | Bugs fixed: X
請使用 /release 確認發佈。
```

## 重要

- **只有 spec 討論和 release 確認需要使用者**
- Engineer 和 QA **同時啟動**
- Feature 和 bug issue 就是 engineer 的工作項目，沒有額外的 task issue
