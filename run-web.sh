#!/bin/bash
# Run web app with Supabase configuration
# Usage: ./run-web.sh

cd "$(dirname "$0")/apps/web" || exit 1

flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW \
  --dart-define=SUPABASE_BUCKET=formbridge-attachments \
  "$@"
