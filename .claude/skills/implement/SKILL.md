---
name: implement
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

## 完成後
所有 PR 完成 → 執行 e2e tests → 有 bug 自動建 issue + 修復 → 通知使用者
