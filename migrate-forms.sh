#!/bin/bash
# Export forms from local backend and import to Supabase

SUPABASE_URL="https://xpcibptzncfmifaneoop.supabase.co"
SUPABASE_ANON_KEY="sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW"
BACKEND_URL="http://localhost:8080"
ORG_ID="00000000-0000-0000-0000-000000000001"

echo "🚀 Form Migration Tool"
echo "======================"
echo ""

# Check if backend is running
if ! curl -s "${BACKEND_URL}/api/forms" > /dev/null 2>&1; then
  echo "❌ Backend server not running on ${BACKEND_URL}"
  echo "💡 Start it with: dart packages/backend/bin/server.dart"
  echo ""
  echo "Or, manually populate Supabase with SQL:"
  echo "   1. Open Supabase Dashboard > SQL Editor"
  echo "   2. Run: supabase/populate_forms_quick.sql (adds 3 test forms)"
  echo "   3. Or copy all forms from server.dart to SQL INSERT statements"
  exit 1
fi

echo "✅ Backend server is running"
echo "📥 Fetching forms from backend..."

# Get forms from backend
FORMS_JSON=$(curl -s "${BACKEND_URL}/api/forms")
FORMS_COUNT=$(echo "$FORMS_JSON" | jq '.forms | length')

echo "📊 Found $FORMS_COUNT forms in backend"
echo ""

if [ "$FORMS_COUNT" -eq 0 ]; then
  echo "❌ No forms found in backend"
  exit 1
fi

echo "📤 Importing forms to Supabase..."
echo ""

# Import each form (Note: This requires proper authentication and RLS setup)
# For now, let's just show instructions

echo "⚠️  Direct import requires service role key (not anon key)"
echo ""
echo "📋 To populate Supabase forms table:"
echo ""
echo "Option 1: Use Supabase Dashboard"
echo "   1. Save backend forms to file:"
echo "      curl ${BACKEND_URL}/api/forms > forms_export.json"
echo "   2. Convert to SQL INSERT statements"
echo "   3. Run in Supabase SQL Editor"
echo ""
echo "Option 2: Create SQL from forms export"
echo "   - See supabase/populate_forms_quick.sql for examples"
echo ""
echo "Option 3: Use the backend as your source of truth"
echo "   - Keep using local Dart backend on port 8080"
echo "   - Point app to localhost:8080 instead of Supabase"
echo ""

# Save forms export for reference
echo "$FORMS_JSON" > /tmp/forms_export.json
echo "💾 Forms exported to: /tmp/forms_export.json"
echo ""
