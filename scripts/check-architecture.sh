#!/usr/bin/env bash
# UIKit / Apple MVC 架构静态检查（见仓库根目录 ARCHITECTURE.md）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAIL=0

warn() { echo "⚠️  $*"; }
fail() { echo "❌ $*"; FAIL=1; }
ok() { echo "✅ $*"; }

UI_DIRS="HSPhotos/Controllers HSPhotos/Views"

# R1: performChanges in UI
if rg -l 'performChanges' $UI_DIRS --glob '*.swift' 2>/dev/null | grep -q .; then
  fail "R1: UI 层存在 performChanges："
  rg -n 'performChanges' $UI_DIRS --glob '*.swift' || true
else
  ok "R1: UI 层无 performChanges"
fi

# R2: PhotoNumberingService in UI (allow comments only — match actual calls)
if rg -n 'PhotoNumberingService\.shared' $UI_DIRS --glob '*.swift' 2>/dev/null | grep -q .; then
  fail "R2: UI 层直连 PhotoNumberingService.shared："
  rg -n 'PhotoNumberingService\.shared' $UI_DIRS --glob '*.swift' || true
else
  ok "R2: UI 层无 PhotoNumberingService.shared"
fi

# R4: Grid mutating memberAssets
if rg -n 'memberAssets\s*(=|\.)' HSPhotos/Views/Detail/PhotoGridView.swift 2>/dev/null | grep -v 'albumSession' | grep -q .; then
  fail "R4: PhotoGridView 可能写入 memberAssets："
  rg -n 'memberAssets' HSPhotos/Views/Detail/PhotoGridView.swift || true
else
  ok "R4: PhotoGridView 未直接写 memberAssets"
fi

# R6: PhotoTagService in UI
if rg -n 'PhotoTagService\.shared' $UI_DIRS --glob '*.swift' 2>/dev/null | grep -q .; then
  fail "R6: UI 层直连 PhotoTagService.shared："
  rg -n 'PhotoTagService\.shared' $UI_DIRS --glob '*.swift' || true
else
  ok "R6: UI 层无 PhotoTagService.shared"
fi

if [[ $FAIL -eq 0 ]]; then
  ok "架构检查通过"
  exit 0
else
  echo ""
  echo "详见 ARCHITECTURE.md"
  exit 1
fi
