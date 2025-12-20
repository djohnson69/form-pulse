#!/bin/bash
# Direct PostgreSQL connection to insert forms

SUPABASE_PROJECT="xpcibptzncfmifaneoop"
SQL_FILE="supabase/populate_all_forms.sql"

echo "🔗 Direct Database Import"
echo "========================="
echo ""

echo "📍 Get your database connection details from:"
echo "   https://supabase.com/dashboard/project/$SUPABASE_PROJECT/settings/database"
echo ""
echo "Connection string format:"
echo "   postgresql://postgres:[YOUR-PASSWORD]@db.${SUPABASE_PROJECT}.supabase.co:5432/postgres"
echo ""

read -p "Enter database password (from Supabase settings): " DB_PASSWORD

if [ -z "$DB_PASSWORD" ]; then
  echo "❌ No password provided"
  exit 1
fi

DB_HOST="db.${SUPABASE_PROJECT}.supabase.co"
DB_USER="postgres"
DB_NAME="postgres"
DB_PORT="5432"

echo ""
echo "🔄 Connecting to database and executing SQL..."
echo ""

# Check if psql is installed
if ! command -v psql &> /dev/null; then
  echo "❌ psql not found. Install PostgreSQL client:"
  echo "   brew install postgresql"
  echo ""
  echo "Or use the manual method (SQL Editor)"
  exit 1
fi

# Execute the SQL file
PGPASSWORD="$DB_PASSWORD" psql \
  -h "$DB_HOST" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -p "$DB_PORT" \
  -f "$SQL_FILE"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ SQL executed successfully!"
  echo ""
  
  # Verify
  FORMS_COUNT=$(PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -p "$DB_PORT" \
    -t -c "SELECT COUNT(*) FROM forms WHERE org_id = '00000000-0000-0000-0000-000000000001';" | tr -d ' ')
  
  echo "📊 Forms inserted: $FORMS_COUNT"
  echo "🎉 Done! Refresh your app to see the forms."
else
  echo ""
  echo "❌ Error executing SQL"
  echo "   Try the manual method instead (SQL Editor)"
fi

echo ""
