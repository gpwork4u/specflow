# QA Phase

在使用者要建立 BDD step definitions、撰寫 playwright-bdd 測試、或驗證 feature coverage 時使用。

## Goal

依 spec 的 Gherkin `.feature` 場景撰寫 step definitions，不等待所有實作都完成才開始。
使用 playwright-bdd 將 .feature 轉為原生 Playwright tests。

## Workflow

1. 讀取 `specs/features/*.feature` 的 Gherkin 場景和 `specs/features/*.md` 的 API contract。
2. 複製 `.feature` 檔案到 `test/features/`。
3. 撰寫 step definitions（`test/steps/`）：
   - `common.steps.ts` — 共用步驟（登入、通用驗證）
   - `api.steps.ts` — API 測試步驟（HTTP request/response）
   - `ui.steps.ts` — UI 測試步驟（頁面互動）
4. 設定 `test/playwright.config.ts`（playwright-bdd 設定）。
5. 使用 `npx bddgen` 生成 Playwright test 檔案。
6. 執行 `npx playwright test` 驗證。
7. 產出報告：
   - Cucumber JSON Report: `test/reports/cucumber-report.json`
   - Cucumber HTML Report: `test/reports/cucumber-report.html`
   - Playwright HTML Report: `test/reports/html/`

## 目錄結構

```
test/
├── features/         # .feature 檔案（從 specs/features/ 複製）
├── steps/            # Step definitions（playwright-bdd）
│   ├── common.steps.ts
│   ├── api.steps.ts
│   └── ui.steps.ts
├── support/          # Hooks, fixtures, helpers
├── playwright.config.ts
├── reports/
└── screenshots/
```

## Rules

- **Feature 檔案是 source of truth** — 不修改 .feature 內容，只實作 step definitions
- QA 以 spec 為依據，不以目前實作缺陷當作真相。
- spec 不夠明確時，先補規格或列出待確認問題。
- 若 repo 尚未有測試框架，先建立 playwright-bdd 最小可執行樣板，不要過度搭建。
- 失敗時建 Bug Issue，附截圖 + Gherkin 場景 + 重現步驟。
