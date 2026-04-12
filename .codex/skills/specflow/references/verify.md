# Verify Phase

在使用者要對當前 sprint 做交付驗證時使用。

## Goal

從完整性、正確性、一致性三個角度檢查交付品質。

## Dimensions

- Completeness：spec 是否有對應實作與測試
- Correctness：行為是否符合 spec 與錯誤處理約定
- Coherence：命名、風格、設計決策是否一致

## Workflow

1. 對照 `specs/` 與程式碼、測試。
2. 執行可行的 tests / linters / build。
3. 產出驗證結果；若 repo 採用文件化流程，可寫入 `specs/verify-sprint-{N}.md`。

## Result Policy

- `PASS`：可進入 release gate
- `WARNING`：不阻塞，但要清楚列出風險
- `FAIL`：阻塞，列出修復項目

## Codex Adaptation

原 Claude 版會叫 verifier agent。Codex 版直接由目前代理執行驗證與報告。
