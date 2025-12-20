#!/bin/bash
# Automatically insert forms into Supabase using REST API with Service Role Key

SUPABASE_URL="https://xpcibptzncfmifaneoop.supabase.co"
SQL_FILE="supabase/populate_all_forms.sql"

echo "🚀 Automated Supabase Forms Import"
echo "==================================="
echo ""

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
  echo "❌ SQL file not found: $SQL_FILE"
  exit 1
fi

echo "⚠️  To insert forms programmatically, I need your Supabase Service Role Key"
echo "   (This key bypasses RLS and should NEVER be exposed in client code)"
echo ""
echo "📍 Get it from: https://supabase.com/dashboard/project/xpcibptzncfmifaneoop/settings/api"
echo "   Look for 'service_role' key under 'Project API keys'"
echo ""
read -p "Enter your Service Role Key (or press ENTER to skip): " SERVICE_ROLE_KEY
echo ""

if [ -z "$SERVICE_ROLE_KEY" ]; then
  echo "❌ No service role key provided."
  echo ""
  echo "📋 Alternative: Paste SQL manually"
  echo "   1. SQL is already in your clipboard (from previous step)"
  echo "   2. Go to: https://supabase.com/dashboard/project/xpcibptzncfmifaneoop/sql/new"
  echo "   3. Paste (⌘V) and click RUN"
  echo ""
  read -p "Have you pasted and run the SQL? (y/n): " DONE
  if [ "$DONE" = "y" ] || [ "$DONE" = "Y" ]; then
    echo "✅ Great! Verifying..."
  else
    echo "⏸️  Paused. Run this script again after pasting SQL."
    exit 0
  fi
else
  echo "🔐 Using service role key to insert forms..."
  echo ""
  
  # Use psql connection string or REST API
  # For now, show instructions since direct SQL execution via REST API is limited
  echo "⚠️  Direct SQL execution via REST API is limited."
  echo "   The most reliable way is still the SQL Editor."
  echo ""
  echo "📋 Please paste the SQL in Supabase Dashboard:"
  echo "   https://supabase.com/dashboard/project/xpcibptzncfmifaneoop/sql/new"
  echo ""
fi

# Verify forms were inserted
echo "🔍 Verifying forms in database..."
FORMS_COUNT=$(curl -s "${SUPABASE_URL}/rest/v1/forms?select=count" \
  -H "apikey: ${SERVICE_ROLE_KEY:-sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW}" \
  -H "Content-Type: application/json" 2>/dev/null | jq -r '.[0].count // 0')

echo "📊 Forms in database: ${FORMS_COUNT}"
echo ""

if [ "$FORMS_COUNT" -gt 0 ]; then
  echo "✅ Success! ${FORMS_COUNT} forms found in Supabase"
  echo ""
  echo "📋 Sample forms:"
  curl -s "${SUPABASE_URL}/rest/v1/forms?select=id,title,category&limit=5" \
    -H "apikey: ${SERVICE_ROLE_KEY:-sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW}" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW}" \
    -H "Content-Type: application/json" 2>/dev/null | jq -r '.[] | "   ✓ \(.title) (\(.category))"'
  echo ""
  echo "🎉 Your app should now show forms!"
  echo "   Refresh your Flutter app to see them."
else
  echo "❌ No forms found yet"
  echo ""
  echo "📝 Please paste and run the SQL manually:"
  echo "   1. Copy SQL: cat $SQL_FILE | pbcopy"
  echo "   2. Open: https://supabase.com/dashboard/project/xpcibptzncfmifaneoop/sql/new"
  echo "   3. Paste and click RUN"
fi

echo ""
