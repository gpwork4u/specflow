---
name: specflow:change
description: 為已完成的專案新增需求變更（Change Request）。spec-writer 評估影響範圍 → 建立 CR 文件 + 新 Sprint milestone → 走原本的 tech-lead → engineer + qa → verify 流程。觸發關鍵字："change", "新需求", "需求變更", "CR", "後續功能", "新增功能"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent, AskUserQuestion
argument-hint: "[變更描述]"
---

# Change Request 流程（專案完成後新增需求）

當專案已 release 但需要新增/修改功能時，用這個流程。**不是改 spec 重來**，而是把變更當作新的迭代層疊上去，並透過既有 .feature 自動形成回歸測試。

## 何時使用

- 既有專案已完成第一輪 Sprint，使用者想新增功能
- 既有功能行為需要調整（不是 bug fix）
- 對外部依賴 / API contract 的變更

> Bug fix **不要**用這個流程，直接 `/specflow:implement` 或在現有 sprint 新增 bug issue。

## 流程

### Step 0：環境檢查與 state 紀錄

```bash
bash .claude/scripts/doctor.sh || exit 1
bash .claude/scripts/state.sh phase "phase-cr-discuss" "spec-writer 評估 CR 影響範圍"
```

### Step 1：找出 CR 編號

```bash
EXISTING=$(ls specs/changes/CR-*.md 2>/dev/null | wc -l | tr -d ' ')
CR_NUM=$((EXISTING + 1))
CR_ID="CR-$(printf '%03d' $CR_NUM)"
```

### Step 2：spec-writer 互動討論（前景）

啟動 spec-writer 評估影響：

```
Agent(subagent_type="spec-writer", run_in_background=false)
  input: |
    這是一個 Change Request：$ARGUMENTS

    請執行：
    1. 讀取 specs/ 既有規格，找出受影響的 features
    2. 評估影響範圍：哪些 .feature 場景需要新增/修改？哪些既有 scenario 變成回歸測試？
    3. 用 AskUserQuestion 與使用者確認需求細節（含 backwards compatibility 取捨）
    4. 產出 specs/changes/$CR_ID.md，包含：
       - 變更描述
       - 影響的 Features（清單）
       - 新增的 .feature scenarios（直接 append 到對應的 specs/features/F-XXX.feature，不刪除既有 scenario）
       - 回歸風險評估
       - 拆分為 sprint 的計畫（如果 CR 大的話可分多個 sprint）
    5. 為這個 CR 建立 GitHub Milestone "Sprint N+1: $CR_ID"（N = 目前最大 sprint 編號）
    6. 建立 Epic-style change issue（label: change）連結 CR 文件
```

### Step 3：確認 spec-writer 產出後，走標準流程

```bash
bash .claude/scripts/state.sh phase "phase-cr-techlead" "tech-lead 規劃 CR 實作"
```

接著啟動 tech-lead → engineer + qa → verify（與 `specflow:start` 的 Phase 3 之後相同）：

```
Agent(subagent_type="tech-lead", run_in_background=true)
  input: 為新建立的 milestone "Sprint N+1: $CR_ID" 拆 issue
```

之後 Phase 4-7 與 `specflow:start` 完全相同。

## 既有 .feature 的處理規則

- **新增 scenario** → append 到既有 F-XXX.feature 檔尾。既有 scenario 保留 = 自動回歸測試
- **修改既有行為** → 在 .feature 加新的 Scenario，描述新行為；舊的 scenario 如果不再合法，**標記 `@deprecated` tag**（不刪除，保留歷史可追溯），並在 spec changelog 註明
- **完全移除功能** → 移到 `specs/features/archive/`，並在 CR 文件記載原因

## 為什麼這樣設計

- **Source of truth 仍是 specs/features/*.feature**，CR 文件只是 changelog
- **既有 scenario 不刪 = 回歸測試自動覆蓋**，BDD coverage check 會抓到回歸破壞
- **沿用 sprint 流程**，無需學新工具或新概念
- **可累積**：CR-001、CR-002... 一路加上去，每個都是獨立可驗證的迭代

## 需要新 label

確認 `change` label 存在（`init-github.sh` 會建立；若舊專案沒有，手動補）：

```bash
gh label create change --color "BFD4F2" --description "Change Request" 2>/dev/null || true
```
