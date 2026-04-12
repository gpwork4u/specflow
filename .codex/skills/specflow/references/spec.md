# Spec Phase

在使用者要建立產品規格、討論需求、切 sprint 時使用。

## Goal

把模糊需求整理成 `specs/` 內可執行的規格文件，必要時同步映射到 GitHub Issues / Milestones。

## Core Workflow

1. 先確認專案目標、主要使用者、關鍵場景、限制條件。
2. 將需求整理為 source-of-truth 文件，優先落地到：
   - `specs/overview.md`
   - `specs/features/*.md`
3. 規劃 sprint，切成可交付的增量，而不是技術層分工。
4. 若 GitHub 能用，再把內容轉成：
   - Epic
   - Sprint issues / milestones
   - Feature issues

## Output Shape

最少應包含：

- 問題定義
- 範圍與非範圍
- 使用者流程 / scenarios
- 驗收標準
- sprint 切分

## Important Rules

- sprint 切分要先跟使用者確認，不能直接假設。
- 若需求仍有缺口，先補齊規格，不要急著進 implement。
- 全程使用繁體中文。
