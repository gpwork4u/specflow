# ui-designer kit — UI/UX 規則 + tokens/元件/頁面範本（按需 Read，非常駐）

> ui-designer.md 在設計檢查 / 產出 token / 元件 / 頁面 / PR 時才 Read 本檔。

---

## 1. UI/UX 設計規則（參考 [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)，依優先級）

設計每個元件/頁面**逐一檢查**。**忠實還原 design 優先**：design 與下列規則衝突時不自行修正，記到 `design/open-questions.md`。

| Pri | 類別 | 關鍵規則 |
|-----|------|---------|
| 1 CRITICAL | Accessibility | 文字/背景對比 ≥4.5:1（WCAG 2.1 AA）；互動元素有 visible focus（ring/outline）；圖片有 alt；完整 keyboard nav（Tab/Enter/Escape）；ARIA labels（aria-label/expanded/hidden）；表單有可見 `<label>` |
| 2 CRITICAL | Touch & Interaction | 觸控目標 ≥44×44pt 間距 ≥8px；點擊有視覺回饋（scale/opacity/ripple）；載入有 loading（spinner/skeleton/progress）；破壞性操作有確認 |
| 3 HIGH | Performance | 圖片 WebP/AVIF + 明確寬高（避免 layout shift）；非首屏 lazy load；CLS <0.1 |
| 4 HIGH | Style | 一致 icon set（Lucide/Phosphor/Heroicons），**禁 emoji 當 icon**；SVG 優先；單一專案風格一致 |
| 5 HIGH | Layout & Responsive | Mobile-first；斷點 sm:640 md:768 lg:1024 xl:1280；禁水平捲軸；Grid/Flexbox 避免固定寬 |
| 6 MEDIUM | Typography & Color | 行高 1.5–1.75，行寬 65–75 字元；semantic color tokens（primary/error/muted）不寫死；最多 3 字重 + 明確 size scale |
| 7 MEDIUM | Animation | 150–300ms；只用 transform/opacity（GPU）；尊重 `prefers-reduced-motion`；傳達狀態非裝飾 |
| 8 MEDIUM | Forms & Feedback | 可見 label（非 placeholder-only）；錯誤訊息在欄位正下方用 error 色；成功/錯誤用 Toast；長操作顯示進度 |
| 9 HIGH | Navigation | 底部導航 ≤5 項；切換保留 scroll；支援 deep linking |
| 10 LOW | Charts & Data | 圖表類型合適（趨勢 Line / 比較 Bar / 佔比 Pie）；調色盤色盲友善；有 legend + tooltip |

**Pre-Delivery Checklist**（PR 前逐項）：Visual（無 emoji icon / 一致 icon set / semantic tokens / 穩定 loading·empty·error）｜Interaction（44×44pt / tap feedback / 150-300ms / focus）｜Accessibility（4.5:1 / ARIA / keyboard / alt）｜Light/Dark（兩模式對比通過 / token-driven）｜Layout（mobile-first / 4·8dp spacing / 無水平捲軸）。

---

## 2. Design Tokens 範本（`design/tokens/`）

**colors.json**（從 design 抽真實值，命名色抽出對應 hex；缺色票記 open-questions）：
```json
{ "color": {
  "primary": { "50":"#eff6ff","100":"#dbeafe","500":"#3b82f6","600":"#2563eb","700":"#1d4ed8","900":"#1e3a8a" },
  "neutral": { "50":"#fafafa","100":"#f5f5f5","200":"#e5e5e5","500":"#737373","700":"#404040","900":"#171717" },
  "success": { "500":"#22c55e","700":"#15803d" }, "warning": { "500":"#eab308","700":"#a16207" },
  "error": { "500":"#ef4444","700":"#b91c1c" },
  "background": { "default":"#ffffff","subtle":"#fafafa","muted":"#f5f5f5" },
  "foreground": { "default":"#171717","muted":"#737373","subtle":"#a3a3a3" },
  "border": { "default":"#e5e5e5","strong":"#d4d4d4" } } }
```
**typography.json**: `font.family{sans,mono}` / `size{xs..3xl}` / `weight{normal..bold}` / `lineHeight{tight,normal,relaxed}`。
**spacing.json**: `spacing{0..16}` / `radius{sm..full}` / `shadow{sm,md,lg}`。

---

## 3. 元件規格（`design/components/{name}/spec.md` + `example.tsx`）

spec.md 區塊：用途 / Variants 表 / Sizes 表（Height·Padding·Font）/ Props 表（Prop·Type·Default·說明）/ States 表（default·hover·active·focus·disabled·loading）/ Accessibility（role·keyboard·aria-disabled·aria-busy）/ 使用範例指向 example.tsx。

example.tsx：基於 tech-survey 選定的 UI 框架，列出各 variant/size/icon/disabled/loading/fullWidth 的 JSX 用例。

```markdown
# Button
## Variants
| Variant | 用途 | 外觀 |
|---------|------|------|
| primary | 主要操作 | 填滿 primary-600 白字 |
| secondary | 次要 | 邊框 border-default 前景字 |
| danger | 破壞性 | 填滿 error-500 白字 |
| ghost | 低優先 | 無邊框 hover 顯背景 |
## Sizes: sm 32px / md 40px / lg 48px（Padding 用 spacing token）
## Props: variant | size | disabled | loading | icon | fullWidth
## States: default / hover(+10%) / active(-5%) / focus(ring 2px primary-500) / disabled(opacity .5) / loading(spinner)
## Accessibility: role=button; keyboard Enter/Space; disabled→aria-disabled; loading→aria-busy
```

---

## 4. 頁面 Layout 規格（`design/pages/`）

`layout.md`（共用 nav/sidebar/footer）+ 每 feature 一檔 `fNNN-{name}.md`。格式：對應 Feature issue / ASCII Layout 圖 / 使用的元件清單（指向 components/）/ 響應式行為表（斷點→變化）。

---

## 5. Commit + PR + issue 回報

```bash
git add design/
git commit -m "design: add UI component dataset for sprint {N}

- Design tokens (colors, typography, spacing)
- Component specs and examples
- Page layout specifications
- Contract handoff (testid + ux-text)

Refs #{design_issue_number}"
git push -u origin design/sprint-{N}-components

gh pr create --title "🎨 Sprint {N} UI Component Dataset" --label "design" --body "$(cat <<'BODY'
## Summary
Sprint {N} UI component dataset，供前端 engineer 開發。
## Design Tokens
- design/tokens/{colors,typography,spacing}.json
## Components
| 元件 | Spec | Example |
|------|------|---------|
| Button | design/components/button/spec.md | ✅ |
## Pages
| 頁面 | Layout |
|------|--------|
| Dashboard | design/pages/f001-dashboard.md |
## Contract Handoff
- design/components-handoff.md（testid → tech-lead 吸進 contracts/dom.md）
- design/ux-text-handoff.md（字串 → tech-lead 吸進 contracts/ux-text.md）
Refs #{design_issue_number}
BODY
)"

gh issue comment {design_issue_number} --body "🎨 Design PR: #{pr_number}"
gh issue comment {sprint_issue_number} --body "🎨 UI Component Dataset PR: #{pr_number}"
```

---

## 6. 產出如何被使用

Engineer 實作有 UI 的 feature：讀 `design/tokens/` → `design/components/{name}/spec.md` + `example.tsx` → `design/pages/{page}.md` → 在 `dev/` 實作遵循 spec。**Engineer 不改 `design/`**，發現設計問題在 design issue 留言回報。
