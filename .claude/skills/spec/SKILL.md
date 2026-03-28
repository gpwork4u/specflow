---
name: spec
description: 啟動 spec 討論流程。與使用者討論需求、規劃 sprint 階段、將功能需求以 GitHub Issue + Milestone 發佈。觸發關鍵字："spec", "規格", "需求", "新專案"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[spec名稱或主題]"
---

# Spec 討論流程

你正在協助使用者建立產品規格（Spec）並規劃 sprint 階段。

## 流程

1. **確認目標**：先確認使用者想建立什麼專案的 spec
2. **啟動 spec-writer agent**：使用 Agent tool 搭配 `subagent_type: "spec-writer"` 啟動
3. **Sprint 規劃**：spec-writer 會與使用者討論功能分階段，確認每個 sprint 要交付的範圍
4. **發佈到 GitHub**：確認後以 Issue + Milestone 形式發佈

## 執行方式

啟動 spec-writer agent 時傳入：
- 使用者提供的專案描述：$ARGUMENTS
- GitHub repo 資訊（owner/repo）

## 產出

- GitHub Milestones（每個 sprint 一個）
- Epic Issue（總覽，含 sprint 規劃）
- Feature Issues（每個功能一個，歸屬到對應 sprint milestone）
- Labels（spec, epic, feature, plan, task, qa, bug）

## 重要提醒

- 全程使用繁體中文
- **Sprint 劃分必須與使用者確認後才能發佈**
- 完成後提醒使用者可用 `/plan` 進入下一階段
