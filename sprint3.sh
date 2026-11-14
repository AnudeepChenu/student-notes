#!/usr/bin/env bash
set -Eeuo pipefail

# StudentNotes Sprint 3 stabilization script.
# Safe by default: does not overwrite application source files, install packages,
# alter Supabase, or create commits unless explicitly requested.

ROOT="$(pwd)"
APPLY_MIGRATIONS=0
DO_COMMIT=0

usage() {
  cat <<'USAGE'
StudentNotes Sprint 3

Run from the root of your student-notes project:
  bash sprint3.sh                 Run local inspection and quality checks
  bash sprint3.sh --apply-migrations  Also offer to apply pending Supabase migrations
  bash sprint3.sh --commit        Commit changes to develop if all checks pass
  bash sprint3.sh --apply-migrations --commit

Options:
  --apply-migrations  Run `supabase db push` after an explicit confirmation.
  --commit            Commit to develop after all required local checks pass.
  -h, --help          Show this help.

The script never prints secret values and never edits application source files.
USAGE
}

while (($#)); do
  case "$1" in
    --apply-migrations) APPLY_MIGRATIONS=1 ;;
    --commit) DO_COMMIT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [[ ! -f "$ROOT/package.json" ]]; then
  echo "ERROR: package.json not found. Run this script from the student-notes project root." >&2
  exit 1
fi

mkdir -p "$ROOT/reports"
REPORT="$ROOT/reports/sprint3-report-$(date +%Y%m%d-%H%M%S).txt"
PASS=0
FAIL=0
WARN=0

log() { printf '%s\n' "$*" | tee -a "$REPORT"; }
pass() { PASS=$((PASS+1)); log "[PASS] $*"; }
fail() { FAIL=$((FAIL+1)); log "[FAIL] $*"; }
warn() { WARN=$((WARN+1)); log "[WARN] $*"; }
section() { log ""; log "===== $* ====="; }

run_check() {
  local label="$1"; shift
  log "\n--- $label ---"
  if "$@" 2>&1 | tee -a "$REPORT"; then
    pass "$label"
  else
    fail "$label"
  fi
}

log "StudentNotes Sprint 3 report"
log "Date: $(date)"
log "Project: $ROOT"
log "Script mode: apply_migrations=$APPLY_MIGRATIONS, commit=$DO_COMMIT"

section "1. Project and Git inspection"
if [[ -d .git ]]; then
  pass "Git repository exists"
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  log "Current branch: ${BRANCH:-unknown}"
  if [[ "$BRANCH" == "develop" ]]; then pass "On develop branch"; else warn "Current branch is not develop; no branch will be changed automatically"; fi
  log "Git status:"
  git status --short 2>&1 | tee -a "$REPORT" || true
else
  fail "Git repository not found"
fi

if [[ -f package-lock.json ]]; then pass "package-lock.json exists"; else warn "No package-lock.json; reproducible npm ci is unavailable"; fi
if [[ -d node_modules ]]; then pass "node_modules exists"; else warn "node_modules is missing; install dependencies with npm install before running checks"; fi

section "2. Environment and secret-safety inspection"
if [[ -f .env.local ]]; then
  pass ".env.local exists (values not displayed)"
  if grep -q '^NEXT_PUBLIC_SUPABASE_URL=.' .env.local && grep -q '^NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=.' .env.local; then
    pass "Supabase URL and publishable key appear configured"
  else
    fail "Supabase URL or publishable key is missing/empty in .env.local"
  fi
else
  fail ".env.local not found"
fi

if [[ -f .gitignore ]] && grep -Eq '(^|/)\.env(\*|$)|\.env\.local' .gitignore; then
  pass ".gitignore appears to exclude environment files"
else
  warn ".gitignore does not clearly exclude .env files; check this before pushing"
fi

if git ls-files --error-unmatch .env.local >/dev/null 2>&1; then
  fail ".env.local is tracked by Git; remove it from tracking before pushing (do not delete your local file)"
else
  pass ".env.local is not tracked by Git"
fi

section "3. Supabase files and migration inspection"
for f in src/lib/supabase/client.ts src/lib/supabase/server.ts; do
  if [[ -f "$f" ]]; then pass "$f exists"; else fail "$f is missing"; fi
done
if [[ -f src/proxy.ts ]]; then
  pass "src/proxy.ts exists"
elif [[ -f src/middleware.ts ]]; then
  pass "src/middleware.ts exists"
else
  warn "Neither src/proxy.ts nor src/middleware.ts found; verify route protection for your Next.js version"
fi

MIGRATION_COUNT=0
if [[ -d supabase/migrations ]]; then
  MIGRATION_COUNT="$(find supabase/migrations -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')"
fi
if [[ "$MIGRATION_COUNT" -gt 0 ]]; then
  pass "Found $MIGRATION_COUNT SQL migration file(s)"
  find supabase/migrations -maxdepth 1 -type f -name '*.sql' -print | sort | tee -a "$REPORT"
else
  fail "No SQL migration files found under supabase/migrations"
fi

if command -v supabase >/dev/null 2>&1; then
  pass "Supabase CLI is installed ($(supabase --version 2>/dev/null | head -n 1))"
  if [[ -f supabase/config.toml ]]; then pass "supabase/config.toml exists"; else warn "supabase/config.toml not found; CLI project may not be initialized"; fi
  if [[ -f supabase/.temp/project-ref ]]; then pass "Supabase project appears linked"; else warn "No local Supabase project-ref found; run supabase link if you intend to push migrations"; fi
else
  warn "Supabase CLI is not installed; database migration cannot be applied by this script"
fi

section "4. Application quality checks"
if [[ ! -d node_modules ]]; then
  warn "Skipping npm checks because node_modules is missing"
else
  # Read package scripts without displaying environment values.
  HAS_LINT="$(node -e 'const p=require("./package.json");process.stdout.write(p.scripts&&p.scripts.lint?"yes":"no")')"
  HAS_TYPECHECK="$(node -e 'const p=require("./package.json");process.stdout.write(p.scripts&&p.scripts.typecheck?"yes":"no")')"

  if [[ "$HAS_LINT" == "yes" ]]; then
    run_check "ESLint" npm run lint
  else
    warn "No lint script in package.json; ESLint check skipped"
  fi

  if [[ "$HAS_TYPECHECK" == "yes" ]]; then
    run_check "TypeScript typecheck script" npm run typecheck
  elif [[ -x node_modules/.bin/tsc ]]; then
    run_check "TypeScript (tsc --noEmit)" ./node_modules/.bin/tsc --noEmit
  else
    warn "TypeScript compiler not found; typecheck skipped"
  fi

  run_check "Next.js production build" npm run build
fi

section "5. Optional Supabase migration application"
if [[ "$APPLY_MIGRATIONS" -eq 1 ]]; then
  if ! command -v supabase >/dev/null 2>&1; then
    fail "Cannot apply migrations: Supabase CLI is not installed"
  elif [[ ! -f supabase/config.toml ]]; then
    fail "Cannot apply migrations: supabase/config.toml is missing; initialize/link the correct project first"
  elif [[ ! -f supabase/.temp/project-ref ]]; then
    fail "Cannot apply migrations: project is not linked. Run supabase link --project-ref YOUR_PROJECT_REF first"
  else
    warn "This will apply pending SQL migrations to the linked Supabase project. Review every SQL file and confirm the linked project is the intended one."
    read -r -p "Type APPLY to run 'supabase db push': " CONFIRM
    if [[ "$CONFIRM" == "APPLY" ]]; then
      run_check "Supabase db push" supabase db push
    else
      warn "Migration push cancelled by user"
    fi
  fi
else
  log "Skipped database changes. To opt in, rerun with --apply-migrations after reviewing the SQL files."
fi

section "6. Optional Git commit"
if [[ "$DO_COMMIT" -eq 1 ]]; then
  if [[ "$FAIL" -gt 0 ]]; then
    warn "Commit skipped because one or more checks failed"
  elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "Commit skipped: not a Git repository"
  elif [[ "$(git branch --show-current)" != "develop" ]]; then
    warn "Commit skipped: switch to develop manually, inspect status, then rerun with --commit"
  else
    log "Files to be committed:"
    git status --short | tee -a "$REPORT"
    read -r -p "Type COMMIT to stage all changes and create a Sprint 3 commit: " CONFIRM_COMMIT
    if [[ "$CONFIRM_COMMIT" == "COMMIT" ]]; then
      git add -A
      if git diff --cached --quiet; then
        warn "No staged changes; nothing to commit"
      else
        if git commit -m "chore: stabilize sprint 3 application" 2>&1 | tee -a "$REPORT"; then
          pass "Sprint 3 commit created"
          log "Push with: git push origin develop"
        else
          fail "Git commit failed"
        fi
      fi
    else
      warn "Commit cancelled by user"
    fi
  fi
else
  log "Skipped Git commit. No files were staged or committed."
fi

section "7. Summary"
log "Passed: $PASS"
log "Failed: $FAIL"
log "Warnings: $WARN"
log "Report saved to: $REPORT"
if [[ "$FAIL" -gt 0 ]]; then
  log "Result: ACTION REQUIRED — fix failures before marking Sprint 3 complete."
  exit 1
else
  log "Result: LOCAL CHECKS PASSED — manually verify Supabase/browser flows before declaring Sprint 3 complete."
fi
