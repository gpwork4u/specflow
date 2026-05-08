---
name: specflow:qa
description: 啟動 QA 撰寫 Playwright e2e tests。根據 spec .md 中的 acceptance criteria 撰寫 Playwright 測試，與 engineer 同時進行。觸發關鍵字："qa", "測試", "test", "e2e"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[sprint編號]"
---

# QA E2E Test 撰寫流程（純 Playwright）

QA 根據 `specs/features/*.md` 的 acceptance criteria 撰寫 Playwright e2e tests。
**與 engineer 同時啟動**，不需要等實作完成（QA 只依賴 spec，不依賴實作）。

## 流程

### 撰寫 e2e tests（與 engineer 並行）

啟動 qa-engineer agent：
- `subagent_type: "qa-engineer"`
- `run_in_background: true`
- `isolation: "worktree"`
- 傳入當前 sprint milestone

QA 會：
1. 從 `specs/sprints/sprint-N.md` 取得當前 sprint 的 feature ID 清單
2. 為每個 feature 建立 `test/e2e/f{N}-{name}.spec.ts`
3. 把 spec .md 中每條 acceptance criterion 轉成一個 Playwright `test('[Happy/Error/Edge] {AC 描述}', ...)`
4. 設定 `test/playwright.config.ts`
5. 發 PR

### 執行測試（sprint 收斂時，orchestrator 跑）

所有 4 lane drain 完畢後，orchestrator 跑：

```bash
SPRINT="Sprint N" bash .claude/scripts/local-checks.sh e2e
```

- 全綠 → state.sprint_test_outcome=success → verifier 接手
- 有失敗 → 建立 bug issue（附截圖 + 失敗 test 名稱）→ engineer 修 → 重跑

## 產出

- e2e tests PR（`test/e2e/*.spec.ts` + `test/support/`）
- Playwright JSON + HTML 測試報告
- Bug issues（如有，附截圖 + 失敗 test 名稱）

## 重要

- **Spec acceptance criteria 是 source of truth** — QA 不修改 spec，只把 AC 轉成可執行 tests
- QA 只依賴 spec .md，不依賴 engineer 實作
- 如果 AC 不夠明確，QA 在 feature issue 上提問
- **只實作當前 sprint scope，不能多做**：未來 sprint 的 feature 不要預寫 e2e test
- **不擴充驗證**：spec AC 寫什麼就驗什麼，不順手加 assertion
- 失敗自動截圖（`screenshot: 'only-on-failure'`）
- Selector / API path / 字串都從 `specs/contracts.ts` import，禁止 hardcoded
