#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
FILE="$ROOT/src/app/dashboard/page.tsx"
if [[ ! -f "$ROOT/package.json" || ! -f "$FILE" ]]; then
  echo "[ERROR] Run this from the student-notes project root."
  exit 1
fi

BACKUP_ROOT="$(dirname "$ROOT")/student-notes-backups"
mkdir -p "$BACKUP_ROOT"
STAMP="$(date +%Y%m%d-%H%M%S)"
cp -p "$FILE" "$BACKUP_ROOT/dashboard-page-$STAMP.tsx"
echo "[BACKUP] $BACKUP_ROOT/dashboard-page-$STAMP.tsx"

python3 - "$FILE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
if re.search(r'export\s+const\s+instant\s*=', s):
    print("[INFO] dashboard already declares instant; unchanged.")
elif re.search(r'export\s+const\s+dynamic\s*=', s):
    raise SystemExit("[ERROR] Existing dynamic route config found; stopped.")
else:
    m = re.search(r'(?m)^export\s+default\b', s)
    if not m:
        raise SystemExit("[ERROR] Could not safely locate default export; stopped.")
    p.write_text(s[:m.start()] + "export const instant = false;\n\n" + s[m.start():])
    print("[FIX] Added export const instant = false to dashboard.")
PY

echo
echo "===== TypeScript ====="
npx tsc --noEmit

echo
echo "===== Production build ====="
npm run build

echo
echo "[PASS] Dashboard fix applied and build completed."
echo "No database changes or Git commit were made."
