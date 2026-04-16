---
name: specflow
description: 將 Claude 版 SpecFlow 工作流重構為 Codex 可執行的專案交付 skill。用於初始化 GitHub specflow 專案、撰寫需求規格（含 Gherkin .feature 場景）、拆分 sprint 與 tasks、實作功能、準備 QA BDD step definitions（playwright-bdd）、驗證 sprint 交付（Cucumber 報告），以及 release gate 檢查。當使用者提到 specflow、規格流程、sprint 規劃、實作排程、QA 驗證、release 檢查，或想沿用 `.claude/skills/specflow:*` 的流程時使用。
---

# SpecFlow for Codex

此 skill 對應 repo 內原本的 Claude SpecFlow workflows：

- `/specflow:init`
- `/specflow:spec`
- `/specflow:plan`
- `/specflow:implement`
- `/specflow:qa`
- `/specflow:verify`
- `/specflow:release`
- `/specflow:start`

Codex 與 Claude 的差異：

- 不依賴 slash commands；改由自然語言觸發。
- 不預設自動啟動多個子代理。只有使用者明確要求 delegation / parallel agent work 時，才可使用 subagents。
- 優先直接在目前 workspace 完成工作；若 GitHub connector 不可用，就先產出本地檔案與可執行命令。

## Quick Mapping

使用者若提到下列意圖，直接套用對應 phase：

- 初始化 labels / repo 設定：讀 [references/init.md](references/init.md)
- 討論需求、建立 spec、規劃 sprint：讀 [references/spec.md](references/spec.md)
- 依 spec 拆 task / architecture / dependency wave：讀 [references/plan.md](references/plan.md)
- 開始實作 feature 或安排工程交付：讀 [references/implement.md](references/implement.md)
- 撰寫 QA BDD step definitions / playwright-bdd tests：讀 [references/qa.md](references/qa.md)
- 做 sprint 驗證或交付檢查：讀 [references/verify.md](references/verify.md)
- 準備 release / deployment gate：讀 [references/release.md](references/release.md)

## Role Mapping

若工作需要沿用原本 Claude agents 的責任分工，讀對應角色文件：

- 規格討論與需求收斂：讀 [references/roles/spec-writer.md](references/roles/spec-writer.md)
- 技術規劃與 task 拆分：讀 [references/roles/tech-lead.md](references/roles/tech-lead.md)
- 功能實作：讀 [references/roles/engineer.md](references/roles/engineer.md)
- QA BDD step definitions / playwright-bdd：讀 [references/roles/qa-engineer.md](references/roles/qa-engineer.md)
- UI dataset / design tokens / 元件規格：讀 [references/roles/ui-designer.md](references/roles/ui-designer.md)
- 審查與交付驗證：讀 [references/roles/code-review.md](references/roles/code-review.md) 或 [references/roles/verifier.md](references/roles/verifier.md)

## Working Rules

1. 全程使用繁體中文，除非使用者明確要求其他語言。
2. `specs/` 是 source of truth；若 repo 尚未有該目錄，可依需求建立最小必要結構。
3. 優先把流程轉成 Codex 目前真的能做的事：
   - 讀寫 repo 檔案
   - 執行 shell 指令
   - 使用 GitHub / 其他 connectors（若此 session 可用）
4. 對原 Claude 文件中「自動背景 agent」的部分，預設改寫成：
   - 先由目前代理完成可直接完成的部分
   - 需要並行代理時，只有在使用者明確要求下才委派
5. 不要假設 GitHub labels、milestones、PR comments 一定能直接建立；若缺少權限或 connector，就先在 `specs/` 產出對應草稿。

## Recommended Repo Layout

若使用者要完整採用 SpecFlow，可維持這個結構：

```text
specs/
  overview.md
  tech-survey.md
  dependencies.md
  features/          # .md specs + .feature Gherkin 場景
  logs/
  changes/
test/
  features/          # .feature 檔案（從 specs/features/ 複製）
  steps/             # Step definitions（playwright-bdd）
  support/           # Hooks, fixtures, helpers
  playwright.config.ts
  reports/           # Cucumber JSON/HTML + Playwright HTML
  screenshots/
design/
  tokens/
  components/
  pages/
dev/
  src/
  __tests__/
```

不要為了符合範本而硬建全部目錄；只建立這次工作實際需要的部分。

## How To Execute

收到使用者需求後：

1. 判斷屬於哪個 phase。
2. 只打開該 phase 的 reference，不要整包載入。
3. 若工作需要修改 repo，直接實作，不只停在建議。
4. 若工作涉及 GitHub 操作：
   - 先檢查本 session 是否可用對應 connector 或 CLI
   - 不可用時提供本地替代產物，例如 issue 模板、release checklist、spec markdown
5. 若使用者要求「完整 specflow 流程」，依序執行：`init -> spec -> plan -> implement -> qa -> verify -> release`，但每一步都以 Codex 能直接執行的方式落地。

## Migration Notes

原始 Claude skills 位於：

- `.claude/skills/specflow:init/SKILL.md`
- `.claude/skills/specflow:spec/SKILL.md`
- `.claude/skills/specflow:plan/SKILL.md`
- `.claude/skills/specflow:implement/SKILL.md`
- `.claude/skills/specflow:qa/SKILL.md`
- `.claude/skills/specflow:verify/SKILL.md`
- `.claude/skills/specflow:release/SKILL.md`
- `.claude/skills/specflow:start/SKILL.md`

本 skill 將它們整併成單一入口，避免把 Codex 綁死在 Claude 專屬的指令格式與 agent 能力假設上。
