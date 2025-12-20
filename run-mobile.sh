#!/bin/bash
# Run mobile app with Supabase configuration
# Usage: ./run-mobile.sh [device]

cd "$(dirname "$0")/apps/mobile" || exit 1

flutter run \
  --dart-define=SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwY2licHR6bmNmbWlmYW5lb29wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4NTE1ODcsImV4cCI6MjA4MTQyNzU4N30.sMzKoqj0GhLsD8tRd73j9NOjEa_ucz0dkh3TwoXD4Tg \
  --dart-define=SUPABASE_BUCKET=formbridge-attachments \
  "$@"
