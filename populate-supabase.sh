#!/bin/bash
# Automatically populate Supabase with forms using the generated SQL

SUPABASE_PROJECT="xpcibptzncfmifaneoop"
SQL_FILE="supabase/populate_all_forms.sql"

echo "🚀 Supabase Forms Population"
echo "=============================="
echo ""
echo "📄 SQL file: $SQL_FILE"
echo ""

if [ ! -f "$SQL_FILE" ]; then
  echo "❌ SQL file not found. Run: node generate_forms_sql.js first"
  exit 1
fi

FILE_SIZE=$(wc -l < "$SQL_FILE")
echo "📊 SQL file has $FILE_SIZE lines"
echo ""

echo "📋 To populate forms in Supabase:"
echo ""
echo "1️⃣  Open in browser:"
echo "   https://supabase.com/dashboard/project/$SUPABASE_PROJECT/sql/new"
echo ""
echo "2️⃣  Copy the SQL file contents:"
echo "   cat $SQL_FILE | pbcopy    # Copies to clipboard"
echo ""
echo "3️⃣  Paste in SQL Editor and click RUN"
echo ""
echo "4️⃣  Verify success - you should see:"
echo "   'Successfully inserted 186 forms'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press ENTER to copy SQL to clipboard and open Supabase dashboard..."

# Copy to clipboard
cat "$SQL_FILE" | pbcopy
echo "✅ SQL copied to clipboard!"
echo ""

# Open Supabase SQL editor
open "https://supabase.com/dashboard/project/$SUPABASE_PROJECT/sql/new"
echo "🌐 Opening Supabase SQL Editor..."
echo ""
echo "Now paste (⌘V) and click RUN in the SQL Editor"
echo ""
