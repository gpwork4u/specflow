# SpecFlow Slim-Skill Benchmark Report

**日期**: 2026-05-20
**Demo repo**: https://github.com/gpwork4u/leave-mvp-demo (private)
**測試標的**: 請假系統 MVP（Employee + Manager，1 Sprint，6 features, 88 ACs）
**Skill version**: branch `skill/reusable-merge`（O2 瘦身後）

---

## 1. Token 用量（實測）

| Phase | Agent | Model | Tokens | Duration | Tool uses | 結果 |
|---|---|---|---:|---:|---:|---|
| Spec | spec-writer | opus | 85,065 | 7:00 | 30 | ✅ 完整：6 features / 88 AC / Epic + Sprint Milestone |
| Tech-lead | tech-lead | opus | 86,991 | 9:43 | 43 | ✅ 完整：contract 三件套 + 8 issue / O5 壓 WebSearch 到 2 次 |
| Impl-backend | engineer | sonnet | 71,143 | 5:55 | 62 | ⚠️ 寫到 tsconfig 收尾段中斷 |
| Impl-frontend | engineer | sonnet | 133,591 | 9:59 | 61 | ⚠️ 5 頁元件寫完，糾結 static serving 中斷 |
| Impl-design | ui-designer | sonnet | 89,150 | 4:48 | 42 | ⚠️ tokens + 9 元件寫完，handoff/PR 前中斷 |
| Impl-qa | qa-engineer | sonnet | 75,514 | 7:18 | 46 | ⚠️ 6 spec 檔寫完，commit 階段中斷 |
| **小計** | | | **541,454** | **44:43** | **284** | |

opus 2 個 agent 跑了 172K tok（spec + tech-lead）；sonnet 4 個 agent 跑了 369K tok（4 lane impl）。

## 2. 靜態 token 估算對比

| 量測項 | 瘦身前 | 瘦身後 | 減幅 |
|---|---:|---:|---:|
| 7 agent 常駐 prompt（字元） | 108,552 | 38,230 | **−64.8%** |
| 7 agent 常駐 prompt（token 估） | ~27,138 | ~9,557 | **−64.7%** |
| Kit（按需 Read 非常駐） | — | ~9,581 tok | 每 agent 跑到產出步驟 Read 1 次，非每 turn 重付 |

**為什麼實際省幅大於 64%**：系統 prompt 每 turn 重送（prompt cache 有幫忙但 long-context cache miss 仍貴）。832 行的 spec-writer 跑 30 turns 每 turn 都付固定成本；127 行版本砍到 1/7。Kit 是「跑到產出步驟一次性讀進來」，不像系統 prompt 每 turn 重付。

## 3. 可靠度觀察（**核心發現**）

### ✅ 單 agent 階段 — 完美

- **spec-writer**（opus 自動代答模式）：6 個 feature spec 完整、88 AC、Epic + Sprint Milestone + Sprint Issue 全在 GitHub，O1/AC checkbox/contract placeholder 規範全守住。85K tok 內收斂。
- **tech-lead**（opus，O5 條件式 survey）：tech-survey 只 2 次 WebSearch（其餘技術棧釘死直接引 spec）、contract 三件套齊全（api/dom/ux-text + contracts.ts typed export）、8 issue 含 lane label + Contracts section + Design Reference、Sprint issue 留言並行策略、dependencies.md 含 Contract owner 表。87K tok 內收斂。

兩個 opus 階段是 SpecFlow 流程**最大 risk 點**（最複雜決策、最長 context、不可逆產出），都在預算內乾淨完成。**O5 條件式 survey 是 token 殺手**：technique-pinned 專案下 tech-lead 從預期的 ~150K tok（含 5+ WebSearch survey）壓到 87K，省 40%+。

### ⚠️ 平行 4-lane 階段 — 全部中斷在 commit/PR 收尾前

| Agent | 中斷位置 | 末訊號 |
|---|---|---|
| backend engineer | tsconfig 設定 | "Now I need to update the server tsconfig..." |
| frontend engineer | static file serving | "Let me add static serving to the server's index.ts..." |
| ui-designer | component spec → handoff | "Now create component specs:" |
| qa-engineer | commit + PR | "Now add .gitignore for test artifacts and commit + PR:" |

**核心檔案產出完整**（dev/ 59 檔含 server+frontend、test/e2e/ 6 spec 檔、design/ 18 檔 含 tokens+components），但 **0 個 PR 開、0 個 merge**。

### 根因有兩層

#### 層 A：我的 dispatch 操作錯誤（非 skill 問題）

dispatch 4 個 background agent 時**漏傳 `isolation: "worktree"` 參數**。Agent 工具的 isolation 是 caller 傳的，不是 agent frontmatter 控制的。結果 4 個 agent 在同一個 working tree 並行寫檔：
- backend 在 `feature/3-auth-jwt` checkout 出來開工
- 其他 3 個 agent 接著進來，git HEAD 已在 feature/3-auth-jwt 上，繼承這個分支
- 都看到對方未追蹤的 `??` 檔案，誤判專案狀態
- frontend engineer 卡在「Dockerfile 是 backend 寫的，我能不能改 server/index.ts 加 static serving」這種跨 lane 越界判斷 → 燒掉 turn

**這是我這次 benchmark 的 procedural bug，不算 skill 本身缺陷**。但暴露了一個 skill 文件改進機會：應該在 engineer.md 明示「**只在傳入 worktree 路徑內工作；若 git HEAD 不是 main / 看到非自己寫的 untracked 檔，先確認 isolation 是否生效**」。

#### 層 B：maxTurns 砍太緊（**真實 skill reliability 問題**）

handoff 提到 O2 順帶把 maxTurns 回調：engineer 80→50、qa 50→40、ui-designer 40→30。**Sonnet 工具呼叫密集型工作下這偏緊**：

- backend engineer 62 tool uses / ui-designer 42 tool uses / frontend 61 / qa 46 — 都接近或超過 maxTurns 砍後值
- 末端訊號都是 work 已寫完正準備 commit/PR，但下一輪沒了
- 即使 isolation 正確，這個 maxTurns 仍可能不夠

**證據強度**：4/4 同樣 pattern 不像偶發。應該回調或差異化：
- engineer maxTurns 從 50 → 70-80（feature impl 平均 60+ tool uses 包含 npm install、Dockerfile、unit test）
- qa maxTurns 從 40 → 60（6 spec 檔 × Read/Write/格式化）
- ui-designer maxTurns 從 30 → 50（9 元件 × spec.md + example.tsx + tokens 已是 30+）

或者另一條路：**在 agent prompt 加 "commit-before-stop" 硬規定**——「即使要停，最低要 git add + commit + push + 開 PR；只有這幾步不算工作量」。這樣 reliability 不靠 maxTurns 而靠 prompt 強約束。

#### 層 C：「無進展即停」可能 false-positive 觸發

每個 slim agent 都加了「同題試 2 次未解 → 停損」。在 race-condition 環境下，agent 看到 git status 一堆 `??`，可能誤判「咦怎麼有別人的檔，我搞錯了」連續查 2 次 → 觸發停損。沒辦法分辨「真的卡住」vs「環境混亂」。

## 4. 結論

| 維度 | 結果 |
|---|---|
| Token 率（靜態） | 常駐 prompt −64.7%；workflow 實際更高（系統 prompt 每 turn 重送的算術倍率） |
| Token 率（實測，整 sprint） | 541K tok / 6 agent / 45 min — 完成 spec → contract → 4 lane code（但未 merge）|
| 單 agent 階段可靠度 | ✅ 上升（hard gate 留行內、O5 條件式 survey 工作正常、所有產出規範守住）|
| 4 lane 並行階段可靠度 | ⚠️ 下降（root cause：我漏傳 isolation + maxTurns 偏緊）|

### 行動項（給 skill）

| 優先 | 項目 | 預估工作 |
|---|---|---|
| P0 | maxTurns 上調：engineer 50→80、qa 40→60、ui-designer 30→50（或差異化） | 改 frontmatter，1 commit |
| P0 | 在 engineer/qa/ui-designer 加「commit-before-stop」硬規定段（即使要停最低要 git add + commit + push + PR） | 文字改動，1 commit |
| P1 | engineer.md 加「驗證 worktree 隔離」段（HEAD 應是 main 或自己的 branch，untracked 應只有自己寫的） | 文字改動，併入 P0 commit |
| P1 | 寫一個 `dispatch-impl.sh` 或在 `.claude/scripts/` 加 helper 確保 dispatch 時帶 isolation 參數 | 1 commit |
| P2 | 「無進展即停」加防誤觸條件：只在 build/test 真的紅 + 試 2 次的情況才停，不對 git status 反應 | 文字改動 |

### 行動項（給我下一次 benchmark）

- dispatch 4 個 agent 時必須 `isolation: "worktree"`
- 或退一步：先單跑 backend → merge → 再單跑 frontend → merge（順序非並行）
- 不要在 spec/tech-lead 之外的 4 lane 直接從同一個主 session 平行 dispatch；應該用 specflow:implement 這個 skill 入口（它本身會處理 worktree）

## 5. 附錄：demo repo 現況

- Repo: https://github.com/gpwork4u/leave-mvp-demo（private）
- main branch: 只 1 個 init commit
- 3 個 dangling branch：`feature/3-auth-jwt`、`feature/8-frontend-mvp`、`test/sprint-1-e2e`（全在本地 worktree，未 push）
- 大量 untracked 檔案在 working tree（spec/contract/dev/design/test 全部，是 4 個 agent 平行寫的）
- 8 個 GitHub feature/design/qa issue 開 open 中
- 0 PR

要復原成可繼續的狀態：手動 commit 各 branch 切回 main + 推 PR，或乾脆把工作丟掉 redo with 正確 isolation。**沒急著做這事 — 重點是 benchmark 數據已經拿到**。
