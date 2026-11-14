#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT/reports/sprint3-backup-$STAMP"

if [[ ! -f "$ROOT/package.json" || ! -d "$ROOT/src/app" ]]; then
  echo "[ERROR] Run this script from the student-notes project root."
  exit 1
fi
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] This folder is not a Git repository."
  exit 1
fi
BRANCH="$(git -C "$ROOT" branch --show-current)"
if [[ "$BRANCH" != "develop" ]]; then
  echo "[ERROR] Expected branch develop; current branch is $BRANCH. Switch to develop first."
  exit 1
fi

BOOKMARKS="$ROOT/src/app/bookmarks/page.tsx"
LOGIN="$ROOT/src/app/login/page.tsx"
LANDING="$ROOT/src/app/page.tsx"
for file in "$BOOKMARKS" "$LOGIN" "$LANDING"; do
  if [[ ! -f "$file" ]]; then
    echo "[ERROR] Missing expected file: ${file#$ROOT/}"
    exit 1
  fi
done

mkdir -p "$BACKUP_DIR"
cp -p "$BOOKMARKS" "$BACKUP_DIR/bookmarks-page.tsx"
cp -p "$LOGIN" "$BACKUP_DIR/login-page.tsx"
cp -p "$LANDING" "$BACKUP_DIR/landing-page.tsx"

echo "StudentNotes Sprint 3 repair"
echo "Branch: $BRANCH"
echo "Backups: $BACKUP_DIR"
echo

python3 - "$BOOKMARKS" "$LANDING" <<'PY'
from pathlib import Path
import re
import sys

bookmarks = Path(sys.argv[1])
landing = Path(sys.argv[2])

# Fix the exact explicit-any pattern reported by ESLint, if present.
src = bookmarks.read_text()
updated = re.sub(r':\s*any\[\]', '', src)
if updated != src:
    bookmarks.write_text(updated)
    print("[FIX] Removed explicit any[] annotation from bookmarks page.")
else:
    print("[INFO] No any[] annotation found; bookmarks typing left unchanged.")

# Next.js Cache Components: this page reads request-time Supabase data.
src = bookmarks.read_text()
if re.search(r'export\s+const\s+instant\s*=', src):
    print("[INFO] Bookmarks page already declares instant.")
elif re.search(r'export\s+const\s+dynamic\s*=', src):
    print("[WARN] Found a dynamic route config. Not changing it automatically.")
else:
    marker = re.search(r'(?m)^export\s+default\b', src)
    if not marker:
        raise SystemExit("[ERROR] Could not safely locate the default page export; no instant setting added.")
    src = src[:marker.start()] + "export const instant = false;\n\n" + src[marker.start():]
    bookmarks.write_text(src)
    print("[FIX] Added export const instant = false to bookmarks page.")

# Remove unused FileText symbol from the landing page's imports.
src = landing.read_text()
updated = re.sub(r'(?m)^\s*FileText,\s*\n', '', src)
if updated == src:
    updated = re.sub(r'\bFileText\s*,\s*', '', src)
    updated = re.sub(r',\s*\bFileText\b', '', updated)
if updated != src:
    landing.write_text(updated)
    print("[FIX] Removed FileText from landing page imports.")
else:
    print("[INFO] FileText not found in a safely removable import position.")
PY

echo
echo "Running ESLint autofix on affected files..."
npx eslint --fix src/app/bookmarks/page.tsx src/app/login/page.tsx src/app/page.tsx || true

echo
echo "===== ESLint ====="
LINT_STATUS=0
npm run lint || LINT_STATUS=$?

echo
echo "===== TypeScript ====="
TSC_STATUS=0
npx tsc --noEmit || TSC_STATUS=$?

echo
echo "===== Production build ====="
BUILD_STATUS=0
npm run build || BUILD_STATUS=$?

echo
echo "===== Summary ====="
echo "ESLint exit code: $LINT_STATUS"
echo "TypeScript exit code: $TSC_STATUS"
echo "Build exit code: $BUILD_STATUS"
echo "Backups: $BACKUP_DIR"

if [[ "$LINT_STATUS" -eq 0 && "$TSC_STATUS" -eq 0 && "$BUILD_STATUS" -eq 0 ]]; then
  echo "[PASS] All local checks passed. No Git commit was created."
  exit 0
else
  echo "[ACTION REQUIRED] Checks still failing. Do not commit yet."
  exit 1
fi
