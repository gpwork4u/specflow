---
name: qa
description: 啟動 QA 撰寫 e2e test script。根據 spec API contract 撰寫測試程式碼，與 engineer 同時進行，不需等實作完成。觸發關鍵字："qa", "測試", "test", "e2e"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[sprint編號]"
---

# QA E2E Test Script 撰寫流程

QA 根據 spec 的 API contract 和測試場景撰寫 e2e test script 程式碼。
與 engineer **同時啟動**，不需要等實作完成。

## 流程

### 撰寫測試（與 engineer 並行）

啟動 qa-engineer agent：
- `subagent_type: "qa-engineer"`
- `run_in_background: true`
- `isolation: "worktree"`
- 傳入當前 sprint milestone

QA 會：
1. 讀取 feature issues 中的 API contract
2. 撰寫 e2e test script 程式碼
3. 發 test PR

### 執行驗證（engineer 完成後）

所有 engineer PR 合併後，通知 QA 執行測試：
- 全部通過 → 在 feature issues 留言確認
- 有失敗 → 建立 bug issue（`bug` + `task` label）

### Bug 修復迴圈

bug issue 建立後自動啟動 engineer agent 背景修復，修復後 QA 重新驗證。

## 產出

- E2E test script PR
- Feature issues 上的測試覆蓋留言
- Bug issues（如有）

## 重要

- QA 只依賴 spec API contract，不依賴 engineer 實作
- 如果 spec 不夠明確，QA 會在 feature issue 上提問
