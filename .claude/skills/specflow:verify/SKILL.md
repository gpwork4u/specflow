---
name: specflow:verify
description: 對當前 sprint 進行三維度驗證：Completeness（完整性）、Correctness（正確性）、Coherence（一致性）。在 QA 通過後、release 前執行。觸發關鍵字："verify", "驗證", "檢查"。
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Agent
argument-hint: "[sprint編號]"
---

# Sprint 三維度驗證

在 QA 測試通過後、release 前，對 sprint 進行全面驗證。

## 🚦 前置條件（hard gate）

verifier 啟動前 **必須** 確認最近一次「Sprint E2E Test」workflow 為 success。

```bash
LATEST=$(gh run list --workflow "Sprint E2E Test" --limit 1 --json conclusion --jq '.[0].conclusion')
if [ "$LATEST" != "success" ]; then
  echo "🔴 Sprint E2E Test 未全綠（$LATEST）— verifier 不啟動。修完 bug 後 workflow 會自動再次觸發。"
  exit 0
fi
```

不是 success（含 failure / cancelled / 從未跑過）就 short-circuit、不啟動 verifier agent，並在 sprint issue 留言說明原因。

## 三維度

| 維度 | 檢查什麼 | 嚴重等級 |
|------|---------|---------|
| **Completeness** | 所有 spec 有實作？所有 acceptance criteria 都有對應 e2e test？ | CRITICAL |
| **Correctness** | 實作行為符合 spec？Playwright report 全綠？ | CRITICAL |
| **Coherence** | 程式碼風格統一？設計決策被遵守？ | WARNING |

## 執行方式

啟動 verifier agent：
- `subagent_type: "verifier"`
- `run_in_background: true`
- 傳入當前 sprint 資訊

## 產出

- `specs/verify-sprint-{N}.md` — 驗證報告
- Sprint issue comment — 結果摘要
- Bug issues（如發現 CRITICAL 問題）

## 結果

- **PASS** → 可以 `/specflow:release`
- **WARNING** → 建議修復但不阻塞
- **FAIL** → 需修復後重新 `/specflow:verify`
