---
name: specflow:doctor
description: 檢查 SpecFlow 流程的前置工具（git/gh/jq/node/docker）與 GitHub repo 狀態。第一次啟動專案前、或流程跑到一半懷疑環境出問題時執行。觸發關鍵字："doctor", "check env", "環境檢查"。
user-invocable: true
allowed-tools: Bash, Read, AskUserQuestion
---

# SpecFlow Doctor — 前置工具檢查

## 步驟

1. 執行檢查腳本：
   ```
   bash .claude/scripts/doctor.sh
   ```
2. 讀取 `.specflow/doctor-report.md` 確認結果

## 缺工具時的處理

如果 exit code = 1（有必要工具缺失），用 `AskUserQuestion` 詢問使用者要怎麼處理：

```javascript
AskUserQuestion({
  questions: [{
    question: "缺少必要工具：{tool 列表}。要怎麼處理？",
    header: "Install",
    multiSelect: false,
    options: [
      {
        label: "幫我安裝 (Recommended)",
        description: "自動執行 brew install 等指令",
        preview: "brew install gh jq node@20"
      },
      {
        label: "我自己裝",
        description: "給我安裝指令，我手動處理"
      },
      {
        label: "跳過",
        description: "暫時不裝，我知道後續可能會壞"
      }
    ]
  }]
})
```

如果只缺可選工具（如 docker），告知後讓使用者選擇繼續或先裝。

## 何時呼叫

- `specflow:start` 第一步自動呼叫
- 使用者直接 `/specflow:doctor` 手動檢查
- 任何流程懷疑環境問題時

## 產出

- `.specflow/doctor-report.md` — 最新的檢查報告（git ignored）
