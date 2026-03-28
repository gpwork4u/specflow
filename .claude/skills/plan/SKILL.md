---
name: plan
description: 啟動技術規劃流程。Tech Lead 讀取當前 sprint 的 spec issues，拆分為 task issues。觸發關鍵字："plan", "規劃", "拆分", "架構"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[sprint編號]"
---

# 技術規劃流程

Tech Lead 讀取當前 sprint 的 spec issues，拆分為可執行的 task issues。

## 流程

1. **定位 Sprint**：找到當前 open 的 sprint milestone（或使用者指定的 sprint）
2. **啟動 tech-lead agent**：使用 Agent tool 搭配 `subagent_type: "tech-lead"` 啟動
3. **產出 Task Issues**：tech-lead 將功能拆分為 task issues，歸屬同一 sprint milestone
4. **標註並行性**：明確標示哪些 task 可以並行執行

## 執行方式

啟動 tech-lead agent 時傳入：
- GitHub repo 資訊
- 當前 sprint milestone 名稱（或 $ARGUMENTS 指定的 sprint）
- 指示其只處理當前 sprint 的 issues

## 產出

- 技術架構 Issue（首個 sprint 時建立）
- Task Issues（歸屬當前 sprint milestone，標記 `task`）
- Epic 上的規劃總結 comment

## 重要提醒

- 全程使用繁體中文
- 只處理當前 sprint 的內容
- 明確標示可並行的 task groups
- 完成後提醒使用者可用 `/implement` 開始實作
