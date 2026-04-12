# Plan Phase

在使用者要做架構規劃、task 拆分、依賴排序時使用。

## Goal

從現有 spec 推出可執行的技術計畫與交付順序。

## Default Workflow

1. 讀取當前 sprint 相關 spec。
2. 產出或更新：
   - `specs/tech-survey.md`
   - `specs/dependencies.md`
   - 必要的 feature / task 文件
3. 將工作拆成可並行與需串行的 waves。
4. 清楚標註：
   - 哪些 task 先做
   - 哪些 task 依賴 UI / API / infra
   - 哪些 task 可以先寫測試

## Expected Deliverables

- 技術選型結論
- 依賴圖或 wave 分組
- 每個 task 的責任範圍
- 驗收方式

## Codex Adaptation

原 Claude 版會叫 tech-lead agent 背景產生規劃；在 Codex 內預設由目前代理直接完成。

只有當使用者明確要求多代理並行時，才可考慮把獨立 task 分給 subagents。
