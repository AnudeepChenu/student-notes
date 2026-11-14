#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
FILE="$ROOT/src/app/admin/page.tsx"

if [[ ! -f "$ROOT/package.json" || ! -f "$FILE" ]]; then
  echo "[ERROR] Run this from the student-notes project root; src/app/admin/page.tsx was not found."
  exit 1
fi

BACKUP_ROOT="$(dirname "$ROOT")/student-notes-backups"
mkdir -p "$BACKUP_ROOT"
STAMP="$(date +%Y%m%d-%H%M%S)"
cp -p "$FILE" "$BACKUP_ROOT/admin-page-$STAMP.tsx"
echo "[BACKUP] Saved original admin page to $BACKUP_ROOT/admin-page-$STAMP.tsx"

python3 - "$FILE" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text()

if re.search(r'export\s+const\s+instant\s*=', source):
    print("[INFO] admin page already declares instant; no edit needed.")
elif re.search(r'export\s+const\s+dynamic\s*=', source):
    raise SystemExit("[ERROR] Found an existing dynamic route config. Stopped without editing.")
else:
    match = re.search(r'(?m)^export\s+default\b', source)
    if not match:
        raise SystemExit("[ERROR] Could not find the default page export. Stopped without editing.")
    source = source[:match.start()] + "export const instant = false;\n\n" + source[match.start():]
    path.write_text(source)
    print("[FIX] Added export const instant = false to src/app/admin/page.tsx.")
PY

echo
echo "===== TypeScript ====="
npx tsc --noEmit

echo
echo "===== Production build ====="
npm run build

echo
echo "[PASS] Admin prerender fix and production build completed."
echo "No database changes and no Git commit were made."
