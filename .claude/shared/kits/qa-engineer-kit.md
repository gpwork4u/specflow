# qa-engineer kit — Playwright 範本（按需 Read，非常駐）

> qa-engineer.md 在初始化/寫 test/發 PR/建 bug 時才 Read。

---

## 1. 初始化

```bash
git checkout -b test/sprint-${N}-e2e
cd test
npm init -y
npm install -D @playwright/test typescript ts-node
npx playwright install chromium
mkdir -p e2e support reports screenshots
```

## 2. playwright.config.ts（純 Playwright，無 playwright-bdd/bddgen）

```typescript
import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './e2e',
  outputDir: './test-results',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
  },
  reporter: [
    ['list'],
    ['html', { outputFolder: './reports/playwright-report' }],
    ['json', { outputFile: './reports/playwright.json' }],
  ],
});
```

## 3. e2e spec 範本（每 feature 一檔，每條 AC 一個 test）

```typescript
// test/e2e/f001-resource.spec.ts
import { test, expect } from '@playwright/test';
import { TESTIDS, TOAST, API_PATHS } from '../../specs/contracts';

test.describe('F-001 Resource 管理', () => {
  // --- Happy Path ---
  test('[Happy] 建立 resource 成功', async ({ request }) => {
    const res = await request.post(API_PATHS.resourceCreate, { data: { field_a: 'test', field_b: 42 } });
    expect(res.status()).toBe(201);
    const body = await res.json();
    expect(body).toMatchObject({ field_a: 'test' });
    expect(typeof body.id).toBe('string');
  });

  // --- Error Handling ---
  test('[Error] field_a 為空時拒絕', async ({ request }) => {
    const res = await request.post(API_PATHS.resourceCreate, { data: { field_a: '' } });
    expect(res.status()).toBe(400);
    expect((await res.json()).code).toBe('INVALID_INPUT');
  });

  // --- Edge Cases ---
  test('[Edge] field_a 邊界值 100 過、101 拒', async ({ request }) => {
    expect((await request.post(API_PATHS.resourceCreate, { data: { field_a: 'x'.repeat(100) } })).status()).toBe(201);
    expect((await request.post(API_PATHS.resourceCreate, { data: { field_a: 'x'.repeat(101) } })).status()).toBe(400);
  });
});
```

UI 測試用 `page` fixture：
```typescript
test('[Happy] 使用者建立 resource 流程', async ({ page }) => {
  await page.goto('/resources');
  await page.locator(`[data-testid="${TESTIDS.createBtn}"]`).click();
  await page.getByLabel('field_a').fill('test');
  await page.locator(`[data-testid="${TESTIDS.submitBtn}"]`).click();
  await expect(page.getByText(TOAST.created)).toBeVisible();
});
```

## 4. Playwright 撰寫對照

| 用途 | API |
|------|-----|
| 開頁 | `await page.goto(url)` |
| 等待 | `await page.waitForLoadState('networkidle')` |
| 填欄位 | `await page.getByLabel('label').fill(text)` |
| 點擊 | `await page.getByRole('button', { name }).click()` 或 `page.locator(\`[data-testid="${TESTIDS.x}"]\`).click()` |
| API | `await request.post(API_PATHS.x, { data })` |
| 驗證 | `await expect(page.getByText(TOAST.x)).toBeVisible()` |

**不要手動 `sleep`** — Playwright 自動等待元素可操作。

## 5. PR 流程（deliver-first：先 draft 後 ready）

### 5a. 立刻發 draft（commit-before-stop hard rule）

```bash
git checkout -b test/sprint-${N}-e2e
# 骨架：playwright.config.ts + 每 feature 一個空 spec 檔（含 import + describe 殼）
cat > test/playwright.config.ts <<EOF
# (配置範本見 §2)
EOF
for fid in f001 f002 f003 f004 f005 f006; do
cat > "test/e2e/${fid}-stub.spec.ts" <<EOF
import { test } from '@playwright/test';
import { TESTIDS, API_PATHS, TOAST } from '../../specs/contracts';
test.describe('${fid^^} — WIP', () => { test.skip('placeholder', () => {}); });
EOF
done
git add test/
git commit -q -m "chore: scaffold e2e tests for sprint ${N}

Refs #{qa_issue_number}"
git push -u origin "test/sprint-${N}-e2e"
DRAFT=$(gh pr create --draft --title "[WIP] 🧪 Sprint ${N} E2E Tests" \
  --body "Closes #{qa_issue_number}

[WIP] Skeleton committed; AC tests in progress." \
  --label "qa" --json number --jq .number)
```

### 5b. 實作每 ~6 個 test commit + push

```bash
git add -A && git commit -q -m "test: AC implementations <progress>

Refs #{qa_issue_number}"
git push
```

### 5c. 收尾改 ready + auto-merge

```bash
gh pr edit "$DRAFT" --title "🧪 Sprint ${N} E2E Tests (Playwright)" \
  --body "Closes #{qa_issue_number}"
gh pr ready "$DRAFT"
gh pr checks "$DRAFT" --watch && gh pr merge "$DRAFT" --squash --delete-branch
```

## 6. Bug issue（完整 e2e 失敗時，sprint 收斂 orchestrator 跑）

```bash
FAILED=$(jq -r '[.suites[]?.specs[]? | select(.tests[]?.results[]?.status=="failed")] | .[] | "\(.title) (\(.file))"' test/reports/playwright.json 2>/dev/null)
# 截圖在 test/test-results/{test-name}/ 下
gh issue create --title "🐛 [Bug] {失敗描述}" --label "bug,$LANE" \
  --milestone "$SPRINT" --body "失敗 test：$FAILED
截圖：test/test-results/...
來源 spec：specs/features/fNNN-*.md AC-N"
```
LANE 從失敗 test 的 feature 性質推（backend/frontend/pipeline）。
