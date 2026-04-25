# Implement Phase

在使用者要開始實作 feature、安排開發順序，或沿用原本 `/specflow:implement` 流程時使用。

## Goal

依 spec 與 plan 直接完成程式碼、測試與必要文件更新。

## Default Workflow

1. 先找出目標 feature 或目前 sprint 範圍。
2. 讀取對應 spec（`.md` + `.feature` 檔案）與 dependency wave。
3. 直接在 repo 內實作：
   - 功能程式碼
   - 單元測試
   - 必要的 integration / BDD scaffold
4. 自我驗證：確認實作能滿足 `.feature` 檔案中所有 Gherkin scenarios。
5. 回報阻塞、風險與下一步。

## 測試執行（playwright-bdd）

實作完成後，使用 playwright-bdd 執行 BDD 測試：

```bash
cd test
npx bddgen                    # 從 .feature 生成 Playwright tests
npx playwright test            # 執行所有場景
```

從 Cucumber JSON report 提取結果：
```bash
cat test/reports/cucumber-report.json | jq '[.[].elements[]] | length'        # 總場景數
cat test/reports/cucumber-report.json | jq '[.[].elements[] | select(.steps | all(.result.status == "passed"))] | length'  # 通過數
```

## Codex Adaptation

原 Claude 版的做法是多個 engineer / QA agents 並行。Codex 版改成：

- 預設單代理直接完成當前範圍
- 使用者明確要求 delegation 時，才能把不重疊的 task 分給 subagents
- 不要承諾「自動 code review loop」；若需要 review，直接做 code review 或產出 review checklist

## Output

- 已修改的程式碼
- 對應測試
- Scenario 覆蓋清單（對照 `.feature` 中的 scenarios）
- 未完成項目的明確清單
