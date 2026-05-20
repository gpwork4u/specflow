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

> **更新（2026-05-20 第二次調查）**：grep agent log 的 `stop_reason` + `is_error` + 末段 tool call 後得出真實根因；下方 §3 內容已重寫。原假設「Layer B: maxTurns 砍太緊」**已否決**（frontmatter `maxTurns` 不被 harness 強制執行）。

### 真正的停止訊號（evidence-backed）

| Agent | frontmatter maxTurns | 實際 assistant 訊息數 | 超過 |
|---|---:|---:|---:|
| spec-writer | 30 | 38 | +8 |
| tech-lead | 35 | 61 | +26 |
| ui-designer | 30 | 46 | +16 |
| qa-engineer | 40 | 62 | +22 |
| backend engineer | 50 | 77 | +27 |
| frontend engineer | 50 | 78 | +28 |

**每個 agent 都跑過 frontmatter maxTurns。frontmatter 是 informational only，不是 hard limit。** 真正的停止來自 harness 的 sub-agent ceiling：

- 4 個 lane agent 末 `stop_reason: tool_use`，**last_action 都是 active tool call**（Write / Edit / Bash 進行中），不是模型自己決定「我完工了」
- frontend engineer 跑 9.99 分鐘（599,495ms）撞 **harness 10-min wall-clock cap**
- 其他 agent 在 5-7 分鐘就停 → harness 還有另一條 cap（疑似 sub-agent 工具呼叫總數約 60-65 的上限）
- Context 沒滿（max 130K 字 vs 200K limit）

### 層 A：同 working dir race（次要）

4 個 agent 各有自己的 `.claude/worktrees/agent-XXX` **隔離 worktree**（frontmatter `isolation: worktree` 有生效），但 prompt 叫他們 `cd /Volumes/2tb/project/leave-mvp-demo` 寫絕對路徑 → 4 agent 共寫同一 demo 目錄，互看彼此 `??` 檔案。Layer A 假設方向對。

### 層 C：rtk wrapper 雜訊放大（**confirmed primary amplifier**）

3 個 agent 的 `is_error` 都來自 zsh 初始化錯誤：
```
setValueForKeyFakeAssocArray:27: command not found: _encode
```
Bash exit code 1/2 但其實命令成功。**Agent 把這當失敗 → 觸發「無進展即停」誤判迴圈，浪費 turn budget**。

來源：oh-my-zsh `urltools` plugin（雖然 `plugins=(git)` 沒明列，但被間接觸發；確切觸發路徑未完全釐清）。

**處理動作 & 部分驗證**：
- ✅ 已 `brew uninstall rtk`（Rust Token Killer）+ 移除 `rtk-rewrite.sh` PreToolUse hook + 刪 CLAUDE.md/RTK.md 引用
- ✅ rtk 移除後**簡單 Bash 命令完全沒雜訊**（echo / git status / git log / git config 都乾淨）
- ⚠️ **`git commit` 之類較複雜 git 命令仍會偶發雜訊**（猜測走 hooks/pager 路徑生成新 zsh subshell 觸發 urltools 路徑）
- 結論：rtk 不是唯一觸發者，但移除 rtk 後**多數 Bash 路徑乾淨**了；剩下的零星觸發點需另外抓（urltools 壞檔 / oh-my-zsh init 路徑）

這不是 skill 缺陷而是我 dev 環境問題，但**它顯著放大了所有可靠度問題**：雜訊讓 stop-rule false-positive，讓 agent 多花 turn 解讀「這個 exit 1 是真的還是假的」，讓最後撞 harness cap 的時候 deliverable 還沒到位。

## 4. 結論

| 維度 | 結果 |
|---|---|
| Token 率（靜態） | 常駐 prompt −64.7%；workflow 實際更高（系統 prompt 每 turn 重送的算術倍率） |
| Token 率（實測，整 sprint） | 541K tok / 6 agent / 45 min — 完成 spec → contract → 4 lane code（但未 merge）|
| 單 agent 階段可靠度 | ✅ 上升（hard gate 留行內、O5 條件式 survey 工作正常、所有產出規範守住）|
| 4 lane 並行階段可靠度 | ⚠️ 下降，**主因是 rtk 雜訊污染（已解）+ harness sub-agent cap 撞牆時 deliverable 還沒就位** |

### 行動項（給 skill — 已根據第二次調查修正）

| 優先 | 項目 | 狀態 |
|---|---|---|
| ~~P0：maxTurns 上調~~ | ❌ **否決** — frontmatter maxTurns 不被 harness 強制 |
| **P0：commit-before-stop 硬規定** | 待做 — agent prompt 反轉順序：先寫骨架 → commit → push → PR → 再 refine。撞 harness cap 時 deliverable 已落地。**唯一真正的 skill 修正項** |
| P1：engineer.md 加 worktree 隔離自驗 | 待做 — HEAD 應是 main 或自己 branch、untracked 應只有自己寫的，否則先確認 isolation |
| P1：dispatch helper / 改 specflow:implement | 待做 — 確保 4 lane dispatch 時各自有獨立 target dir，不只是 worktree 隔離 |
| P2：「無進展即停」防誤觸 | 待做 — Bash 非零 exit 先看 stderr/stdout 內容，不對環境噪音反應 |

### 行動項（給 dev 環境 — 部分解）

- ✅ **rtk 已移除**（`brew uninstall rtk` + 移 PreToolUse hook + 刪 RTK.md/CLAUDE.md 引用），多數簡單 Bash 路徑乾淨
- ⚠️ **剩餘觸發點待清**：`git commit` 等複雜命令仍偶發雜訊；urltools 壞檔 / oh-my-zsh init 路徑要追完才完全乾淨。下次 benchmark 前最好處理掉

### 行動項（給下次 benchmark）

- 不要從同一個主 session 平行 dispatch 4 個 lane agent 對同一個 demo 目錄；該走 `specflow:implement` skill 入口（自己處理隔離）
- 或退一步：序列跑 backend → merge → frontend → merge

## 5. 附錄：demo repo 現況

- Repo: https://github.com/gpwork4u/leave-mvp-demo（private）
- main branch: 只 1 個 init commit
- 3 個 dangling branch：`feature/3-auth-jwt`、`feature/8-frontend-mvp`、`test/sprint-1-e2e`（全在本地 worktree，未 push）
- 大量 untracked 檔案在 working tree（spec/contract/dev/design/test 全部，是 4 個 agent 平行寫的）
- 8 個 GitHub feature/design/qa issue 開 open 中
- 0 PR

要復原成可繼續的狀態：手動 commit 各 branch 切回 main + 推 PR，或乾脆把工作丟掉 redo（rtk 已移除 + commit-before-stop 套上後再來一次會乾淨很多）。**沒急著做這事 — 重點是 benchmark 數據與根因已經拿到**。

---

# Benchmark v2（deliver-first 修正後重跑，2026-05-20）

## 條件

- Demo repo: 全新（v1 已 wipe）
- Skill: branch main `b27c462` — 含 P0 deliver-first / commit-before-stop hard rule
- 同一個 Claude design URL，spec-writer 同 prompt 自動代答
- 同一個 4-lane 並行 dispatch（沒走 specflow:implement skill 入口）

## Token / Duration（v1 vs v2）

| Phase | v1 tokens | v2 tokens | Δ | v1 duration | v2 duration |
|---|---:|---:|---:|---:|---:|
| spec-writer | 85,065 | **64,640** | **−24%** | 7:00 | 6:05 |
| tech-lead | 86,991 | **79,402** | **−9%** | 9:43 | 8:42 |
| backend engineer | 71,143 | 77,107 | +8% | 5:55 | 6:51 |
| frontend engineer | 133,591 | **110,169** | **−18%** | 9:59 | 7:11 |
| ui-designer | 89,150 | 86,668 | −3% | 4:48 | 3:30 |
| qa-engineer | 75,514 | 80,057 | +6% | 7:18 | 9:33 |
| **Total** | **541,454** | **498,043** | **−8%** | **44:43** | **41:52** |

額外勝利：tech-lead 的 O5 條件式 survey 在 v2 跑了 **0 次 WebSearch**（v1 是 2 次）— spec 已釘死技術棧時規則完全發揮。

## 可靠度（**核心對照**）

| Lane | v1 PR | v2 PR | v2 結果 |
|---|---|---|---|
| backend | ❌ 0 PR | ✅ **draft #12** | 238 行 / 18 檔 / F-001 完整 + 共寫 design 檔 |
| ui-designer | ❌ 0 PR | ✅ **draft #13** | 156 行 / tokens + handoff scaffolding |
| frontend | ❌ 0 PR | ❌ 0 PR | 違反 deliver-first（試 `npm install` 驗證 build 才打算 commit） |
| qa | ❌ 0 PR | ⚠️ 本地 commit 90a4fe9，**未 push** | 違反 deliver-first（commit 完忘 push）|

**deliver-first 成功率：v1 0/4 (0%) → v2 2/4 (50%)**。明顯改善但非完美。

## 失敗分析

兩個違反 deliver-first 的 agent 都不是「敢不敢」的問題而是「順序拗不過天性」：

- **frontend**：拿到 issue 後本能先「我要先 set up Vite + 試 `npm install` 確認」再 commit。prompt 的「立刻 commit 骨架」沒擋住「先確認再做」的本能。
- **qa**：commit 是做了（本地 `90a4fe9`），但 `git push` 沒跑 → 沒 PR。「commit-before-stop」變成「commit-before-stop（local-only）」。

兩者都是 prompt 強度不夠。**「立刻」這詞太軟**；需要的是「在你呼叫任何其他工具之前，先跑這 4 行指令」的硬規格。

## 下一步 P0（v2 後）

| 項目 | 修正方向 |
|---|---|
| deliver-first **絕對化** | 加 hard sequence：「**第一個你會做的 tool call 必須是 `git checkout -b`；第二個必須是 `git commit -m '[WIP]' --allow-empty`；第三個必須是 `git push -u origin ...`；第四個必須是 `gh pr create --draft`**。在你做 Read spec / 確認 contract / 試 npm install **之前**」|
| deliver-first **自驗** | agent 每 N 個 tool call 自問：「我 PR 推上去了嗎？沒推？立刻推」|
| **共寫 demo dir race** | 4 lane 並行 dispatch 仍會互看 untracked。長遠看：走 `specflow:implement` skill 入口（它應該為每個 lane 建獨立 demo clone），不要從主 session 平行 dispatch |
| 失敗 lane 重啟自動化 | 上面 frontend + qa 那兩個失敗的 lane，應該有 helper 偵測「assigned 但 PR 沒開」→ 自動再起一個 agent 接續 |

## v2 結論

| 維度 | 結果 |
|---|---|
| Token 率 | v2 比 v1 省 8%（具體哪 phase 省最多：spec-writer −24% / frontend −18%）|
| 可靠度（PR 落地率）| v1 0% → v2 50%，**P0 修正方向對但強度不夠** |
| Skill 本身結構 | 維持原架構（kit + slim prompt + deliver-first）|
| 下一輪 P0 | deliver-first 絕對化（硬規格四步序列）+ 4-lane 共寫 race 用 specflow:implement 處理 |

仍未做：未來若要 100% PR 落地，需要前述「絕對化」+ 用 specflow:implement skill 入口（內建獨立 demo dir per lane）一起套上。
