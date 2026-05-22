#!/usr/bin/env bash
# frontend-scaffold.sh — 1 個 Bash 建 Vite+React+TS+Tailwind 骨架 + commit + push
# 用於 frontend lane 避開「先 npm install 確認再 commit」的 turn-burn 本能（v3 + v5 frontend 失敗模式）
# 設計原則：宣告 deps + 寫設定檔即可，**不**跑 npm install（留給 dev / CI），骨架立刻 commit
#
# Usage:
#   frontend-scaffold.sh <issue_num>
#   前提：deliver-first.sh 已跑過（branch + draft PR 已建）
#
# Exit non-zero 才算失敗。

set -e
ISSUE_NUM="$1"
[ -z "$ISSUE_NUM" ] && { echo "Usage: $0 <issue_num>" >&2; exit 2; }

# 決定前端目錄：若 dev/ 已有「非前端」package.json（backend 同居一個 dev/），
# scaffold 進 dev/web/ 隔離，**絕不覆蓋 backend 的 package.json / tsconfig.json**。
# 純前端專案（dev/ 無 package.json 或本來就是 react）維持 dev/ 根（向後相容）。
if [ -f dev/package.json ] && ! grep -q '"react"' dev/package.json; then
  WEB_DIR="dev/web"
  SPECS_REL="../../specs/contracts.ts"
  echo "ℹ️  偵測到 dev/ 已有 backend package.json → 前端 scaffold 隔離到 dev/web/（不覆蓋 backend）"
else
  WEB_DIR="dev"
  SPECS_REL="../specs/contracts.ts"
fi

mkdir -p "$WEB_DIR"/src/{components,pages,api,lib} "$WEB_DIR/public"

# 已有骨架就 skip（idempotent）
if [ -f "$WEB_DIR/package.json" ] && [ -f "$WEB_DIR/vite.config.ts" ]; then
  echo "(scaffold 已存在於 $WEB_DIR，skip)"
  exit 0
fi

cat > "$WEB_DIR"/package.json <<'EOF'
{
  "name": "leave-frontend",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.21.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "vite": "^5.0.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.32",
    "autoprefixer": "^10.4.16"
  }
}
EOF

cat > "$WEB_DIR"/tsconfig.json <<EOF
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "lib": ["ES2022", "DOM"],
    "paths": { "@contracts": ["${SPECS_REL}"] }
  },
  "include": ["src"]
}
EOF

cat > "$WEB_DIR"/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [react()],
  server: { port: 3000, proxy: { '/api': 'http://localhost:3001' } },
});
EOF

cat > "$WEB_DIR"/index.html <<'EOF'
<!doctype html>
<html lang="zh-Hant">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>請假系統</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > "$WEB_DIR"/src/main.tsx <<EOF
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode><App /></React.StrictMode>
);
EOF

cat > "$WEB_DIR"/src/App.tsx <<EOF
// [WIP] Stub — implementation in progress (Refs #${ISSUE_NUM})
export default function App() {
  return <div className="p-8">WIP — frontend MVP scaffolding</div>;
}
EOF

cat > "$WEB_DIR"/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat > "$WEB_DIR"/tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: { extend: {} },
  plugins: [],
};
EOF

cat > "$WEB_DIR"/postcss.config.js <<'EOF'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

# commit + push（用 commit-progress 統一邏輯）
if [ -x .claude/scripts/commit-progress.sh ]; then
  bash .claude/scripts/commit-progress.sh "chore: scaffold Vite+React+TS+Tailwind skeleton" "$ISSUE_NUM"
else
  git add dev/
  git commit -q -m "chore: scaffold Vite+React+TS+Tailwind skeleton

Refs #${ISSUE_NUM}"
  git push -q
fi

echo "✅ frontend scaffold committed + pushed (deps declared in package.json，npm install 延後到 dev/CI)"
