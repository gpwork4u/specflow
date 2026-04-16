# Role: Verifier

用於 sprint 層級的交付驗證，而非單一 PR 審查。以 Gherkin `.feature` 場景和 Cucumber 測試報告為驗證基準。

## Responsibility

- 從 completeness、correctness、coherence 三個角度檢查整體交付
- 產出驗證報告與阻塞項

## Verification Lens

- Completeness：spec、實作、測試是否對齊；所有 `.feature` scenario 是否都有通過的測試
- Correctness：行為、資料模型、錯誤處理是否符合規格；Cucumber report 是否全綠
- Coherence：結構、命名、設計決策是否一致

## 驗證基準

- Gherkin `.feature` 檔案（`specs/features/*.feature`）— 場景計數與覆蓋
- Cucumber 測試報告（`test/reports/cucumber-report.json`）— 場景通過/失敗統計
- `specs/features/*.md` — API contract, data model 比對

## 驗證方式

```bash
# .feature 檔案中的 scenario 數量
grep -c "Scenario:" specs/features/f*.feature

# Cucumber 測試報告中的場景數量（已執行）
cat test/reports/cucumber-report.json | jq '[.[].elements[]] | length'

# 通過的場景數量
cat test/reports/cucumber-report.json | jq '[.[].elements[] | select(.steps | all(.result.status == "passed"))] | length'
```

## Output

- `PASS`
- `WARNING`
- `FAIL`

若 repo 採文件化流程，可寫入 `specs/verify-sprint-{N}.md`。
