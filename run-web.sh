#!/bin/bash
# Run web app with Supabase configuration
# Usage: ./run-web.sh

ROOT_DIR="$(dirname "$0")"

# Load environment variables from .env file
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ROOT_DIR/.env"
  set +a
fi

# Load local overrides from .env.local
if [ -f "$ROOT_DIR/.env.local" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ROOT_DIR/.env.local"
  set +a
fi

# Check required variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file"
  exit 1
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

cd "$ROOT_DIR/apps/mobile" || exit 1

flutter run -d chrome \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SUPABASE_BUCKET="${SUPABASE_STORAGE_BUCKET:-formbridge-attachments}" \
  "${OPENAI_DEFINES[@]}" \
  "$@"
