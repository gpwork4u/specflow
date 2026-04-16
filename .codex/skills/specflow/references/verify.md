# Verify Phase

在使用者要對當前 sprint 做交付驗證時使用。

## Goal

從完整性、正確性、一致性三個角度檢查交付品質。
以 Gherkin `.feature` 場景和 Cucumber 測試報告（`test/reports/cucumber-report.json`）為驗證基準。

## Dimensions

- Completeness：spec 是否有對應實作與測試；所有 `.feature` scenario 是否都有通過的 BDD 測試
- Correctness：行為是否符合 spec 與錯誤處理約定；Cucumber report 是否全綠
- Coherence：命名、風格、設計決策是否一致

## Workflow

1. 對照 `specs/features/*.feature`（Gherkin 場景）與程式碼、測試。
2. 讀取 `test/reports/cucumber-report.json` 驗證場景通過狀態。
3. 比對 `.feature` 中定義的 scenario 數量與 Cucumber report 中已執行的場景數量。
4. 執行可行的 tests / linters / build。
5. 產出驗證結果；若 repo 採用文件化流程，可寫入 `specs/verify-sprint-{N}.md`。

## Result Policy

- `PASS`：可進入 release gate
- `WARNING`：不阻塞，但要清楚列出風險
- `FAIL`：阻塞，列出修復項目

## Codex Adaptation

原 Claude 版會叫 verifier agent。Codex 版直接由目前代理執行驗證與報告。
