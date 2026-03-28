---
name: init
description: 初始化 GitHub repo 的 issue labels、project 設定。在開始使用 specflow 工作流前執行一次。觸發關鍵字："init", "初始化", "setup"。
user-invocable: true
allowed-tools: Bash, Read
argument-hint: "[owner/repo]"
---

# 初始化 SpecFlow GitHub 設定

在開始使用 specflow 工作流前，執行此 skill 初始化 GitHub repo 的 labels 和基礎設定。

## 執行方式

1. 確認 repo 資訊（從 `$ARGUMENTS` 或 `git remote` 取得）
2. 執行初始化 script：

```bash
bash .claude/scripts/init-github.sh {owner/repo}
```

3. 驗證 labels 建立成功：

```bash
gh label list --repo {owner/repo}
```

## 前置條件

- `gh` CLI 已安裝且已登入
- 對目標 repo 有 admin 或 write 權限
- repo 已存在（此 skill 不會建立 repo）

## 完成後

提醒使用者可用 `/spec` 開始討論需求。
