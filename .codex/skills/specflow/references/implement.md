# Implement Phase

在使用者要開始實作 feature、安排開發順序，或沿用原本 `/specflow:implement` 流程時使用。

## Goal

依 spec 與 plan 直接完成程式碼、測試與必要文件更新。

## Default Workflow

1. 先找出目標 feature 或目前 sprint 範圍。
2. 讀取對應 spec 與 dependency wave。
3. 直接在 repo 內實作：
   - 功能程式碼
   - 單元測試
   - 必要的 integration / e2e scaffold
4. 執行可行的驗證。
5. 回報阻塞、風險與下一步。

## Codex Adaptation

原 Claude 版的做法是多個 engineer / QA agents 並行。Codex 版改成：

- 預設單代理直接完成當前範圍
- 使用者明確要求 delegation 時，才能把不重疊的 task 分給 subagents
- 不要承諾「自動 code review loop」；若需要 review，直接做 code review 或產出 review checklist

## Output

- 已修改的程式碼
- 對應測試
- 未完成項目的明確清單
