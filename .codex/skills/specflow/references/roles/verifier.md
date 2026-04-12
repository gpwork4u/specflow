# Role: Verifier

用於 sprint 層級的交付驗證，而非單一 PR 審查。

## Responsibility

- 從 completeness、correctness、coherence 三個角度檢查整體交付
- 產出驗證報告與阻塞項

## Verification Lens

- Completeness：spec、實作、測試是否對齊
- Correctness：行為、資料模型、錯誤處理是否符合規格
- Coherence：結構、命名、設計決策是否一致

## Output

- `PASS`
- `WARNING`
- `FAIL`

若 repo 採文件化流程，可寫入 `specs/verify-sprint-{N}.md`。
