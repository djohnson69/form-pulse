#!/bin/bash
# Run mobile app with Supabase configuration
# Usage: ./run-mobile.sh [device]

ROOT_DIR="$(dirname "$0")"
if [ -f "$ROOT_DIR/.env.local" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ROOT_DIR/.env.local"
  set +a
fi

OPENAI_DEFINES=()
if [ -n "$OPENAI_API_KEY" ]; then
  OPENAI_DEFINES+=(--dart-define=OPENAI_API_KEY="$OPENAI_API_KEY")
fi
if [ -n "$OPENAI_MODEL" ]; then
  OPENAI_DEFINES+=(--dart-define=OPENAI_MODEL="$OPENAI_MODEL")
fi
if [ -n "$OPENAI_BASE_URL" ]; then
  OPENAI_DEFINES+=(--dart-define=OPENAI_BASE_URL="$OPENAI_BASE_URL")
fi
if [ -n "$OPENAI_ORG" ]; then
  OPENAI_DEFINES+=(--dart-define=OPENAI_ORG="$OPENAI_ORG")
fi
if [ -n "$OPENAI_CLIENT_FALLBACK" ]; then
  OPENAI_DEFINES+=(--dart-define=OPENAI_CLIENT_FALLBACK="$OPENAI_CLIENT_FALLBACK")
fi

cd "$ROOT_DIR/apps/mobile" || exit 1

if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if [ -f "/etc/ssl/cert.pem" ]; then
  export SSL_CERT_FILE="/etc/ssl/cert.pem"
fi

export COCOAPODS_DISABLE_STATS=1
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

XATTR_CLEANER_PID=""
if command -v xattr >/dev/null 2>&1; then
  (
    while true; do
      if [ -d "build/ios/Debug-iphonesimulator" ]; then
        xattr -cr "build/ios/Debug-iphonesimulator" >/dev/null 2>&1 || true
      elif [ -d "build/ios" ]; then
        xattr -cr "build/ios" >/dev/null 2>&1 || true
      fi
      sleep 0.25
    done
  ) &
  XATTR_CLEANER_PID="$!"
  trap 'kill "$XATTR_CLEANER_PID" 2>/dev/null || true' EXIT
fi

flutter run \
  --dart-define=SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwY2licHR6bmNmbWlmYW5lb29wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4NTE1ODcsImV4cCI6MjA4MTQyNzU4N30.sMzKoqj0GhLsD8tRd73j9NOjEa_ucz0dkh3TwoXD4Tg \
  --dart-define=SUPABASE_BUCKET=formbridge-attachments \
  "${OPENAI_DEFINES[@]}" \
  "$@"
