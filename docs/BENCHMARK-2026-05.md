# SpecFlow Benchmark — 2026-05（請假系統）

用真實 Claude Design「請假系統」MVP 端到端跑瘦身後的 SpecFlow，目的：(1) 驗證瘦身/重構後的 prompt 在真實專案可靠執行；(2) 系統性找出靜態看 prompt 看不出的隱藏缺陷。

- **標的**：員工 / 主管 / HR 三角色請假系統，台灣勞基法假別（3700 行 JSX prototype + 設計對話）
- **demo repo**：`gpwork4u/leave-demo`（private）
- **修正去處**：PR #8（瘦身消重）+ PR #9（12 個缺陷修正 + bundle 支援）

## 驗證結果：5 種 agent 全跑通

| Agent | Issue | 產出 | 結果 |
|------|------|------|------|
| spec-writer | — | 讀 `chats/` 反推 13 feature + Epic/Sprint/milestone + 12 MVP 假設 | ✅ |
| tech-lead | — | 從 0-testid prototype 發明 56 testid + contracts.ts + 15 issue 標 lane + wave 分析 | ✅ |
| backend engineer | #3 | Prisma + seed + JWT auth + RBAC + 10 unit tests（contract 全 import） | ✅ PR #19 merged |
| frontend engineer | #9 | 登入 + AppShell + 導覽（pixel-perfect 照 `*.jsx`，testid 從 contract 加） | ✅ PR #20 merged |
| pipeline engineer | #15 | 雙子專案 Docker + compose + CI workflow | ✅ PR #21 merged |
| qa engineer | #17 | 88 個 Playwright e2e test（1:1 對應 88 條 AC，contract 全 import） | PR #22（CI billing 擋，本地 tsc 過） |

## 12 個缺陷（全已修）

### 🔴 發現⑤是核心：防漂移閘門從未運作

`contract-check.sh` 的 `report()` 在 `echo | while` 的 subshell 內累加 `VIOLATIONS`，計數無法回傳父 shell → **腳本永遠 `exit 0`**。意即 SpecFlow 標榜的 contract 防漂移閘門**從未真正擋過任何 PR**。

修好它之後，原本被它「意外抵銷」的三個誤報全部浮現成「會真的擋死 PR」，**必須一起修**否則修了⑤反而讓所有 frontend/qa PR 卡死：

| # | 缺陷 | 嚴重 | 修正 |
|---|------|------|------|
| ⑤ | contract-check 因 subshell 計數永遠 exit 0 | 🔴 | 主 shell `add_violations` + selftest 升級為「違規 exit 1 / 乾淨 exit 0」功能測試 |
| ⑥ | frontend-scaffold 在共用 `dev/` 時覆蓋 backend package.json/tsconfig | 🔴 | 偵測 backend → 隔離 scaffold 到 `dev/web/` |
| ⑧ | kit compose 範本不支援「contracts 在 build context 外」+ 雙子專案 | 🔴 | context 設 repo root + 雙子專案三服務指引 |
| ⑪ | local-checks contract 用 full mode → 任一 lane 既有債卡死全 lane（⑤延伸） | 🔴 | 改 `--diff origin/main` 只查本分支 |
| ① | sync-design 不吃新版 gzip+tar bundle | 🟡 | 自動偵測 + 解開攤平（見 DESIGN bundle 段） |
| ③ | 「從 design 抽 testid」對無 testid 的 prototype 不成立 | 🟡 | 改為 contract phase 由 ui-designer/tech-lead 發明 |
| ④ | spawn lane 前 specs/ 未 commit → worktree agent 讀不到 | 🟡 | start skill Phase 3.8 hard gate |
| ⑦ | contract-check full 模式掃 node_modules 誤報（⑤延伸） | 🟡 | prune node_modules/dist/build/coverage/.next |
| ⑫ | contract-check Check 5 把模板插值 `[data-testid="${TESTIDS.x}"]` 誤判為新 contract（⑤延伸） | 🟡 | 只算真 literal、排除 TESTIDS./API_PATHS |
| ② | Claude Design export URL 短時效（數分鐘 404） | 🟢 | 文件提示重 export + 本地快照 freeze |
| ⑨ | ready-and-merge 把 CI billing/infra 失敗誤判為程式失敗而 deadlock | 🟢 | 偵測 billing/startup_failure/BlobNotFound → exit 2 |
| ⑩ | 無 workflow YAML lint gate | 🟢 | kit 補 push 前 `yaml.safe_load` |

外加：engineer.md Step 4 路徑 bug（`overview.md`→`specs/overview.md`）、docker 自驗歧義、contract-check 單引號 path 盲點。

## 方法論心得

1. **每跑一個沒走過的 lane 就揪出該 lane 專屬 bug**（backend→⑤、frontend→⑥⑦、pipeline→⑧⑨⑩⑪、qa→⑫）。靜態 review prompt 看不出這些，必須真的執行未走過的程式路徑。
2. **修一個核心 gate 會連鎖暴露被它隱藏的下游缺陷**（⑤→⑦⑪⑫）。修可靠度核心時要追下游交互，不能只修當下那一處。
3. **token 省幅與可靠度可以雙贏**：消除 prompt/kit 與 helper script 的重複死碼（PR #8）既省 token 又消除漂移風險。

## 已知環境限制（非 SpecFlow 問題）

- demo 用的 GitHub 帳號 Actions 被 billing 擋住（job 數秒 startup_failure / BlobNotFound）→ sprint e2e、code-review、verifier 這後段無法在 CI 跑、#22 無法經 CI merge。⑨ 的修正讓 ready-and-merge 不再因此 deadlock。
- engineer/qa/ui 用 `isolation: worktree`，完整 multi-agent 跑須在以目標專案為根的 Claude Code session 執行 `/specflow:implement`。
