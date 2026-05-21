# SpecFlow 設計取捨理由（給人看，不入 prompt）

本檔收錄 orchestrator / agent 流程「為什麼這樣設計」的說明，從各 SKILL/agent prompt 抽出來，避免常駐 prompt 載入純解釋性散文。改流程前先讀這裡理解原意。

## 為什麼不做 per-PR review（改成 sprint-end 一次性 review）

- per-PR 看不到跨 lane 對齊問題（frontend testid 對 qa testid 各自看都對，合起來不對）
- Engineer 等 review 會卡住 lane drain
- 改成 sprint-end 對整個 sprint diff 一次完整 review，看得到全貌、找問題更準

配套：branch protection 改成只要 `build-and-lint` 過、不再要求 approval（見 `init-github.sh`）。
（對應 `specflow:start` Phase 4.5 / 5.5）

## 為什麼 e2e 上 CI（不在本機跑）

1. **可重現**：標準 ubuntu env，不受個別開發機影響
2. **可見性**：team / 使用者直接看 actions tab，不用本機重跑
3. **Artifacts 集中**：playwright trace / 截圖 / report 在 actions run 裡，保留 30 天
4. **Verifier 信任源**：直接讀 workflow conclusion，不用靠 state.json 自我宣告
5. **解放本機**：orchestrator 不用佔用 docker port，可同時做別的事

（對應 `specflow:start` Phase 5）
