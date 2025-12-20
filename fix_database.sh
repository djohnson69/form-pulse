#!/bin/bash
# Automatically fix and populate Supabase database

SUPABASE_URL="https://xpcibptzncfmifaneoop.supabase.co"
SUPABASE_ANON_KEY="sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW"

echo "🔧 Form Bridge Database Setup"
echo "=============================="
echo ""

# Step 1: Open Supabase SQL Editor
echo "📝 Step 1: Fix Database Schema"
echo ""
echo "Opening Supabase SQL Editor..."
open "https://supabase.com/dashboard/project/xpcibptzncfmifaneoop/sql/new"

sleep 2

# Step 2: Copy schema fix to clipboard
echo ""
echo "✅ Copying schema fix SQL to clipboard..."
cat "$(dirname "$0")/supabase/add_missing_columns.sql" | pbcopy

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  👉 PASTE (⌘V) IN SUPABASE AND CLICK 'RUN'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press ENTER after SQL runs successfully..."

# Step 3: Load forms
echo ""
echo "📊 Step 2: Load 186 Form Templates"
echo ""
echo "Copying forms SQL to clipboard..."
cat "$(dirname "$0")/supabase/populate_all_forms.sql" | pbcopy

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  👉 PASTE (⌘V) IN SUPABASE AND CLICK 'RUN'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press ENTER after forms are loaded..."

echo ""
echo "✅ Database setup complete!"
echo ""
echo "🎉 You should now have 186 form templates!"
echo ""
echo "Press 'r' in the Flutter terminal to reload the app."
echo ""
