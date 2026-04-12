# Release Phase

在使用者要檢查是否可上線、產出 release checklist、建立版本標記時使用。

## Goal

把原本 Claude skill 的 deployment gate 轉成 Codex 可直接檢查與執行的流程。

## Gate Checklist

至少檢查：

1. 測試報告是否全數通過
2. 驗證報告是否為 PASS 或可接受的 WARNING
3. 是否仍有未解 bug
4. 是否仍有未合併的關鍵 PR

## Default Workflow

1. 先做 gate 檢查並回報阻塞項。
2. Gate 通過後，再建立：
   - release summary
   - 版本號 / tag 建議
   - GitHub release notes 草稿
3. 只有在環境、權限、remote 都具備時，才真的執行 tag / release 命令。

## Safety Rules

- 任一 gate 不過，不要執行部署命令。
- 不要假設 `origin`、`gh`、release 權限一定可用。
- 若不能直接發版，至少產出可複製使用的 release notes 與命令。
