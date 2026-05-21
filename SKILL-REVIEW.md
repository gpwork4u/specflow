# SpecFlow Skill 全面 Review（v6 benchmark 後）

**日期**: 2026-05-20
**Scope**: 7 agents / 14 scripts / 6 kits / 12 skills + state schema + workflow gaps
**Method**: 行數 / 引用一致性 + v1~v6 benchmark observation + workflow gap analysis

---

## V6 結果速覽（review 起點）

| Lane | v5 PR | v5 lines | v6 PR | v6 lines | Δ |
|---|---|---:|---|---:|---|
| backend | MERGED | 6227 | **MERGED** | 5822 | 持平 |
| qa | MERGED | 1608 | ready (not merged) | **1772** | 內容+，merge− |
| frontend | draft empty | 0 | draft with content | **79** | scaffold 生效 |
| ui-designer | draft | 1453 | draft scaffold-only | 62 | **內容大幅退步** |

**v6 端到端 merged**: 1/4（vs v5 2/4）— **退步**

**v6 PR 有實質內容**: 4/4（vs v5 3/4）— **進步**

V6 trade-off：deliver more *broad coverage* 但 *less merge depth*。

---

## 🔴 CRITICAL：specflow:implement skill 沒接最新 helper

**最嚴重的問題**。用戶實際入口是 `/specflow:implement` skill，但該 skill 用 `isolation="worktree"`（v3 證實沒用 — agent 都 cd 同一 demo dir），**沒呼叫 `dispatch-impl.sh`**（per-lane clone）、**沒呼叫 `sweep-missing-prs.sh`**（兜底）、**沒在 prompt 傳「第一個 Bash 必須是 deliver-first.sh」的約束**。

```
.claude/skills/specflow:implement/SKILL.md (line 36-48)：
Agent(subagent_type="engineer", run_in_background=true, isolation="worktree", ...)
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree", ...)
Agent(subagent_type="ui-designer", run_in_background=true, isolation="worktree", ...)
```

→ **用戶 invoke /specflow:implement 完全吃不到 v3~v6 所有 reliability 修正**。

**修正**：specflow:implement skill 必須改寫成：
1. 先跑 `dispatch-impl.sh` 為每 lane 建獨立 clone
2. 把 clone path 注入每個 agent 的 prompt（取代 isolation="worktree"）
3. 強制 prompt 含「第一個 Bash 必須是 deliver-first.sh / scaffold」
4. 4 lane 全跑完後跑 `sweep-missing-prs.sh`

---

## 🟠 HIGH：tech-lead push 不可靠

V5 tech-lead 忘 push（被 sandbox 擋了沒 retry），contract 三件套留在本地，per-lane clones 拿不到 → 我手動補推。

V6 我在 prompt 額外提醒「commit 後要 push」→ 才有 push。

**這應該是 agent.md 的硬規則，不該每次 dispatch prompt 都得提醒**。

**修正**：tech-lead.md 加「commit 後必須跑 `git push origin main && git ls-remote origin main` 驗證 origin 含此 commit；失敗 retry 1 次」。

---

## 🟠 HIGH：design-scaffold trade-off 不划算

V5 ui-designer：1453 行 component spec 但缺 handoff。
V6 ui-designer：62 行（只 scaffold + 空 handoff 表頭）。

問題：scaffold 跑掉 ~15 tool use（3 token JSON + 4 handoff file + commit + push）→ 之後 reading design source + 寫元件 spec 不夠 budget。

但 handoff 的價值低 — tech-lead 在 v6 已**先**寫好 `contracts/dom.md` + `ux-text.md`（直接從 design-source 反推），**不需要等 ui-designer 的 handoff**。Handoff 在 spec → contract 流程裡是事後驗證，不是 pre-req。

**修正**：縮小 design-scaffold 規模或拆掉。讓 ui-designer 把 budget 花在元件 spec（v5 模式）。

---

## 🟡 MEDIUM：engineer.md 結構編號混亂

```
# engineer.md 目前：
🛑 deliver-first 絕對序列（必 Bash #1）
frontend lane 專屬第二步 frontend-scaffold（必 Bash #2，僅 frontend）
🛛 環境噪音容忍
🤝 跨 lane race 處理
第〇步（frontend lane 強制 hard gate）：讀本地 design 快照     ← 為什麼是「第〇步」？
工作流程
1. 讀 issue + spec
2. 執行 deliver-first 絕對序列  ← 已在上面說過了
3. 實作（dev/ 下）
4. push 前必跑 local-checks
5. 改 draft → ready + auto-merge
```

「第〇步」、「第二步」、「工作流程 1-5」三套編號混雜。Agent 可能不清楚實際順序。

**修正**：統一改成 Step 1-N，frontend-specific 步驟標 `[frontend only]` 前綴併入主流程。

---

## 🟡 MEDIUM：state.json schema 缺欄位

resume 流程要重啟需要知道：
- 每 lane 的 clone path 在哪（`dispatch-impl.sh` 創的）
- 每 lane 已開的 PR 號（避免重開）
- 每 lane 的 last commit SHA

當前 state.json 只有 `in_flight_agents` array + `lane_closed` boolean。

**修正**：加 `lane_state: { backend: { clone_path, draft_pr, last_sha }, ... }` 欄位，由 `state.sh lane-track <lane> <field> <value>` 寫入。

---

## 🟢 LOW：剩下幾個小事

| 問題 | 影響 | 修正方向 |
|---|---|---|
| skill SKILL.md 0/12 引用新 helper | 大部分 skill 是讀寫 specs/，但 implement 漏接是核心問題（CRITICAL 已列） | 全 skill 過一遍補 reference |
| code-review 是唯一無 kit reference 的 agent | 它 192 行已精簡，目前 OK | 不動 |
| sweep-missing-prs 從 commit message 抓 #N | deliver-first.sh empty commit 含 #N → 可抓到；手動 commit 可能漏 | 已 OK，但 prompt 規範鼓勵 Refs #N |
| rtk noise 仍出現 | env 問題非 skill | 已記錄 |
| design-scaffold 用 `_TODO` 標記 | agent 不確定是否要填 | scaffold 註解明確說明 |

---

## P7 建議修正計劃（按優先順序）

### P7.1【CRITICAL】更新 specflow:implement skill

```bash
# 偽碼：新版 skill 流程
SPRINT=...
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

for LANE in backend frontend qa design; do
  HAS_ISSUES=$(gh issue list --milestone "$SPRINT" --label "$LANE" --state open --json number --jq 'length')
  [ "$HAS_ISSUES" -eq 0 ] && continue
  CLONE=$(bash .claude/scripts/dispatch-impl.sh "$REPO" "$LANE")
  bash .claude/scripts/state.sh set "lane_state.$LANE.clone_path" "\"$CLONE\""
  # Spawn agent with prompt including:
  #   - cwd: $CLONE
  #   - "第一個 Bash 必須是 deliver-first.sh"
  #   - frontend lane 加「第二個 Bash 必須是 frontend-scaffold.sh」
  Agent(subagent_type=..., run_in_background=true, prompt="cd $CLONE && ...")
done

# 4 lane drain 後 sweep
bash .claude/scripts/sweep-missing-prs.sh
```

### P7.2【HIGH】tech-lead.md push 自驗

加段：
```
commit + push 後必須驗證 origin/main 含此 commit：
git push origin main && git ls-remote origin main | grep "$(git rev-parse HEAD)"
失敗 → retry 1 次。
```

### P7.3【HIGH】design-scaffold 縮小或拆除

兩條路二選一：
- A. **縮成只建 open-questions.md**（1 個 file，1 tool use）— scaffold 成本降到最低
- B. **完全拆除 design-scaffold**，讓 ui-designer 走 v5 模式（先寫元件 spec，handoff 留到 sprint review）

我建議 A，handoff 改成「ui-designer 寫完後若還有 turn 就寫」非硬規。

### P7.4【MEDIUM】engineer.md 編號統一

改成 Step 1-7 連貫，frontend-only 步驟標 `[frontend]` 前綴：
```
Step 1: deliver-first（所有 lane）
Step 2 [frontend]: frontend-scaffold
Step 3 [frontend]: 讀本地 design 快照
Step 4: 讀 issue + spec
Step 5: 實作（dev/ 下）
Step 6: 每 ~10 檔 commit-progress
Step 7: 改 draft → ready + auto-merge
```

### P7.5【MEDIUM】state.json schema 擴充

加 `lane_state` 欄位 + `state.sh lane-track` 指令。

### P7.6【LOW】ready-and-merge helper

```bash
ready-and-merge.sh "$PR_NUM"
# gh pr ready → gh pr checks --watch → gh pr merge --squash --delete-branch
# 3 個 Bash 省到 1 個。對 backend / qa 收尾很有用。
```

---

## 結論

V6 揭露的最大問題不是 reliability，是**用戶實際入口 `specflow:implement` skill 沒接最新 helper**。等於 v3~v6 所有努力對「直接 invoke skill 的使用者」是看不見的。

P7.1 是 P0 等級。其他 P7.2~P7.5 是中等 / 低，可慢慢來。

V6 design-scaffold trade-off 是反例：勤勉加修正不一定是進步，要看實際輸出。**P6 應該回退 design-scaffold，保留 frontend-scaffold**（前者吃 budget 沒產生對等價值，後者讓 v5 frontend 從 0 → v6 79 行）。
