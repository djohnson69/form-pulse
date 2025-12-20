#!/bin/bash
# Verify Supabase database has forms and user membership (requires service role key)

SUPABASE_URL="https://xpcibptzncfmifaneoop.supabase.co"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY:-}"

if [ -z "$SUPABASE_SERVICE_KEY" ]; then
  echo "❌ Missing SUPABASE_SERVICE_KEY (service role key). Export it and rerun."
  echo "   Get it from Supabase Dashboard > Settings > API > service_role"
  exit 1
fi

echo "🔍 Checking Supabase Forms Table..."
echo ""

# Check if forms table has data
FORMS_COUNT=$(curl -s "${SUPABASE_URL}/rest/v1/forms?select=count" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
  -H "Content-Type: application/json" | jq -r '.[0].count // 0')

echo "📊 Forms in database: ${FORMS_COUNT}"

if [ "$FORMS_COUNT" -eq 0 ]; then
  echo "❌ No forms found in Supabase!"
  echo ""
  echo "💡 The forms table is empty. You need to:"
  echo "   1. Insert the 360+ templates from the backend into Supabase"
  echo "   2. Or create a migration script to populate forms table"
  echo ""
else
  echo "✅ Forms table has data"
  echo ""
  # Show sample of forms
  echo "📋 Sample forms:"
  curl -s "${SUPABASE_URL}/rest/v1/forms?select=id,title,category&limit=5" \
    -H "apikey: ${SUPABASE_SERVICE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
    -H "Content-Type: application/json" | jq -r '.[] | "   - \(.id): \(.title) (\(.category))"'
  echo ""
fi

echo ""
echo "🔐 To check if a user is in org_members, you need to:"
echo "   1. Sign up/login in the app first"
echo "   2. Get user_id from Supabase Dashboard > Authentication > Users"
echo "   3. Run this SQL in Supabase SQL Editor:"
echo ""
echo "   SELECT * FROM org_members WHERE user_id = 'YOUR_USER_ID';"
echo ""
echo "   If empty, add user with:"
echo "   INSERT INTO org_members (org_id, user_id, role)"
echo "   VALUES ('00000000-0000-0000-0000-000000000001', 'YOUR_USER_ID', 'admin');"
echo ""
