#!/usr/bin/env bash
# SyncNote — one-command bootstrap for new users.
#
# Usage: ./setup.sh
#
# Interactive. Offers three paths:
#   1) Demo mode      — no backend, instant, in-memory notes
#   2) Guided Supabase — opens browser to signup, auto-applies schema
#   3) Existing Supabase — paste URL+key, auto-applies schema

set -euo pipefail

log()  { printf "\033[1;34m→\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- 1. deps ----------
log "checking deps"
command -v flutter >/dev/null || die "flutter not found. install: https://docs.flutter.dev/get-started/install"
command -v dart    >/dev/null || die "dart not found (should ship with flutter)"
ok "flutter $(flutter --version | head -1 | awk '{print $2}')"

# ---------- 2. pub deps ----------
log "fetching flutter deps"
flutter pub get >/dev/null
ok "flutter deps ready"

if [[ -d cli ]]; then
  log "fetching CLI deps"
  (cd cli && dart pub get >/dev/null) || warn "CLI deps failed (skip)"
fi

# ---------- 3. pick mode ----------
cat <<EOF

pick backend mode:
  [1] Demo         — works right now, in-memory, no sync (test the UI)
  [2] New Supabase — walks you through creating a free project in browser
  [3] Existing     — paste URL + key of a project you already have
  [q] Quit

EOF
read -rp "choice [1/2/3/q]: " CHOICE

CFG_FILE="lib/config/env.dart"
ENV_FILE=".env.local"

write_env_dart() {
  local URL="$1" KEY="$2"
  cat > "$CFG_FILE" <<EOF
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '${URL}',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '${KEY}',
  );
  static const openAiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );
  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && !supabaseUrl.contains('YOUR-');
}
EOF
  cat > "$ENV_FILE" <<EOF
SUPABASE_URL=${URL}
SUPABASE_ANON_KEY=${KEY}
EOF
  ok "wrote $CFG_FILE + $ENV_FILE"
}

apply_schema_psql() {
  local PROJECT_REF="$1" DB_PASSWORD="$2"
  local CONN="postgresql://postgres.${PROJECT_REF}:${DB_PASSWORD}@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
  if ! command -v psql >/dev/null; then
    warn "psql not installed — install: pacman -S postgresql-libs   OR paste supabase/schema.sql into the SQL editor manually"
    return
  fi
  log "applying schema via psql…"
  if psql "$CONN" -f supabase/schema.sql >/dev/null 2>&1; then
    ok "schema applied"
  else
    warn "psql failed — check DB password + region. Fallback: paste supabase/schema.sql into SQL Editor manually"
  fi
}

open_url() {
  local U="$1"
  if command -v xdg-open >/dev/null; then xdg-open "$U" >/dev/null 2>&1 &
  elif command -v open   >/dev/null; then open      "$U" >/dev/null 2>&1 &
  else echo "open: $U"; fi
}

case "$CHOICE" in
  1|demo)
    # Leave placeholder in env.dart so app falls into demo mode.
    if [[ -f "$CFG_FILE" ]] && grep -q "YOUR-PROJECT" "$CFG_FILE"; then
      ok "demo mode active (no config change needed)"
    else
      write_env_dart "https://YOUR-PROJECT.supabase.co" "YOUR-ANON-KEY"
      ok "demo mode set"
    fi
    ;;
  2|new)
    cat <<EOF

opening supabase.com/dashboard in your browser…

follow these steps:
  1. sign in (github fastest)
  2. click "New Project"
  3. name: syncnote
  4. copy the DB password to a safe place (you'll need it in a sec)
  5. pick closest region → Create

wait ~1 min for provisioning, then come back here.
EOF
    open_url "https://supabase.com/dashboard/projects"
    read -rp "hit enter when project is ready… "
    cat <<EOF

now grab these from the dashboard:
  - Project URL:      Project Settings → General → Reference ID (subdomain is: <ref>.supabase.co)
  - Publishable key:  Project Settings → API Keys → Publishable key (copy button)
  - DB password:      the one you set at creation
EOF
    read -rp "Project URL (https://xxx.supabase.co): " SB_URL
    read -rp "Publishable/anon key (sb_publishable_… or eyJ…): " SB_KEY
    read -rsp "DB password (needed once to apply schema): " DB_PW; echo
    [[ -z "$SB_URL" || -z "$SB_KEY" ]] && die "URL + key required"
    write_env_dart "$SB_URL" "$SB_KEY"
    # Extract project ref from URL for psql conn.
    REF=$(echo "$SB_URL" | sed -E 's|https://([^.]+)\.supabase\.co|\1|')
    if [[ -n "$DB_PW" && -n "$REF" ]]; then
      apply_schema_psql "$REF" "$DB_PW"
    else
      warn "skipping schema — paste supabase/schema.sql into SQL Editor manually"
    fi
    cat <<EOF

one more thing — disable email confirmation for local dev:
  → Dashboard → Authentication → Providers → Email → toggle OFF "Confirm email" → Save
EOF
    open_url "${SB_URL/https:\/\//https://supabase.com/dashboard/project/}${REF}/auth/providers"
    ;;
  3|existing)
    read -rp "Project URL (https://xxx.supabase.co): " SB_URL
    read -rp "Publishable/anon key (sb_publishable_… or eyJ…): " SB_KEY
    [[ -z "$SB_URL" || -z "$SB_KEY" ]] && die "URL + key required"
    write_env_dart "$SB_URL" "$SB_KEY"
    read -rp "apply schema automatically? need DB password (y/N): " ANS
    if [[ "$ANS" == "y" || "$ANS" == "Y" ]]; then
      read -rsp "DB password: " DB_PW; echo
      REF=$(echo "$SB_URL" | sed -E 's|https://([^.]+)\.supabase\.co|\1|')
      apply_schema_psql "$REF" "$DB_PW"
    else
      warn "paste supabase/schema.sql into SQL Editor manually"
    fi
    ;;
  q|quit)
    exit 0
    ;;
  *)
    die "invalid choice"
    ;;
esac

# ---------- 4. next steps ----------
cat <<EOF

$(ok "setup complete")

compiling CLI binary → bin/syncnote…
EOF

# ---------- 5. compile CLI ----------
if command -v dart >/dev/null && [[ -d cli ]]; then
  mkdir -p bin
  if (cd cli && dart compile exe bin/syncnote.dart -o ../bin/syncnote >/dev/null 2>&1); then
    ok "compiled bin/syncnote ($(du -h bin/syncnote | cut -f1))"
    # try to install to user path
    LOCAL="$HOME/.local/bin"
    mkdir -p "$LOCAL"
    if install -m 755 bin/syncnote "$LOCAL/syncnote" 2>/dev/null; then
      ok "installed → $LOCAL/syncnote"
      case ":$PATH:" in
        *":$LOCAL:"*) ;;
        *) warn "add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
      esac
    fi
  else
    warn "CLI compile skipped"
  fi
fi

cat <<EOF

run one of:
  syncnote          — terminal notes UI (if installed to PATH)
  ./bin/syncnote    — same, local
  just cli          — dev run from source
  just chrome       — Flutter web in Brave/Chrome
  just android      — Flutter on first plugged phone
  just apk          — build + install APK on plugged phone (no Play Store)
  just run          — Flutter Linux desktop
  just web          — bundle + serve :8765 (LAN accessible)

no 'just'? fallback:
  ./bin/syncnote
  flutter run -d chrome
  flutter build apk --release && flutter install
EOF
