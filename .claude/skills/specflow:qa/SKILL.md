---
name: specflow:qa
description: 啟動 QA 撰寫 BDD step definitions。根據 Gherkin .feature 場景撰寫 playwright-bdd step definitions，與 engineer 同時進行，不需等實作完成。觸發關鍵字："qa", "測試", "test", "e2e", "bdd"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[sprint編號]"
---

# QA BDD Test 撰寫流程（playwright-bdd）

QA 根據 `specs/features/*.feature` 的 Gherkin 場景撰寫 step definitions。
使用 playwright-bdd 將 .feature 轉為原生 Playwright tests。
與 engineer **同時啟動**，不需要等實作完成。

## 流程

### 撰寫 Step Definitions（與 engineer 並行）

啟動 qa-engineer agent：
- `subagent_type: "qa-engineer"`
- `run_in_background: true`
- `isolation: "worktree"`
- 傳入當前 sprint milestone

QA 會：
1. 複製 `specs/features/*.feature` 到 `test/features/`
2. 撰寫 step definitions（`test/steps/`）實作每個 Given/When/Then
3. 設定 playwright-bdd config
4. 發 step definitions PR

### 執行驗證（engineer 完成後）

所有 engineer PR 合併後，QA 執行 BDD 測試：
- `npx bddgen` 生成 Playwright tests
- `npx playwright test` 執行所有場景
- 全部通過 → 在 feature issues 留言確認
- 有失敗 → 建立 bug issue（附截圖 + Gherkin 場景）

### Bug 修復迴圈

bug issue 建立後自動啟動 engineer agent 背景修復，修復後 QA 重新驗證。

## 產出

- Step definitions PR（`test/steps/` + `test/support/`）
- Cucumber JSON + HTML 測試報告
- Bug issues（如有，附截圖 + 失敗場景）

## 重要

- **Feature 檔案是 source of truth** — QA 不修改 .feature 內容，只實作 step definitions
- QA 只依賴 spec .feature + .md，不依賴 engineer 實作
- 如果 .feature 場景不夠明確，QA 會在 feature issue 上提問
