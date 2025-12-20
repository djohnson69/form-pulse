#!/bin/bash
# Verify Supabase integration is complete and ready for testing
# Run this before starting development

echo "🔍 Verifying Supabase Integration..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter
checks_passed=0
checks_failed=0

# Check if files exist
echo "📁 Checking required files..."

files=(
  "apps/mobile/pubspec.yaml"
  "apps/mobile/lib/main.dart"
  "supabase/schema.sql"
  "supabase/seed.sql"
  ".vscode/launch.json"
  "run-mobile.sh"
  "run-web.sh"
  "SUPABASE_QUICKREF.md"
  "SUPABASE_SETUP.md"
  "SUPABASE_PREFLIGHT.md"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo -e "${GREEN}✓${NC} $file"
    ((checks_passed++))
  else
    echo -e "${RED}✗${NC} $file (missing)"
    ((checks_failed++))
  fi
done

echo ""
echo "📦 Checking package dependencies..."

# Check app has supabase_flutter
if grep -q "supabase_flutter:" apps/mobile/pubspec.yaml; then
  echo -e "${GREEN}✓${NC} Mobile app has supabase_flutter"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} App missing supabase_flutter"
  ((checks_failed++))
fi

echo ""
echo "🔧 Checking configuration..."

# Check main.dart has Supabase.initialize
if grep -q "Supabase.initialize" apps/mobile/lib/main.dart; then
  echo -e "${GREEN}✓${NC} App initializes Supabase"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} App doesn't initialize Supabase"
  ((checks_failed++))
fi

# Check for dart-define support
if grep -q "String.fromEnvironment" apps/mobile/lib/main.dart; then
  echo -e "${GREEN}✓${NC} App uses dart-define for config"
  ((checks_passed++))
else
  echo -e "${YELLOW}⚠${NC}  App might have hardcoded values"
  ((checks_failed++))
fi

# Check run scripts are executable
echo ""
echo "🏃 Checking run scripts..."

if [ -x "run-mobile.sh" ]; then
  echo -e "${GREEN}✓${NC} run-mobile.sh is executable"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} run-mobile.sh is not executable"
  echo "   Run: chmod +x run-mobile.sh"
  ((checks_failed++))
fi

if [ -x "run-web.sh" ]; then
  echo -e "${GREEN}✓${NC} run-web.sh is executable"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} run-web.sh is not executable"
  echo "   Run: chmod +x run-web.sh"
  ((checks_failed++))
fi

echo ""
echo "🗄️  Checking database schema..."

# Check schema.sql has required tables
tables=("orgs" "org_members" "profiles" "forms" "submissions" "attachments" "notifications")
for table in "${tables[@]}"; do
  if grep -q "create table.*$table" supabase/schema.sql; then
    echo -e "${GREEN}✓${NC} Schema includes $table table"
    ((checks_passed++))
  else
    echo -e "${RED}✗${NC} Schema missing $table table"
    ((checks_failed++))
  fi
done

# Check for storage policies
if grep -q "formbridge-attachments" supabase/schema.sql; then
  echo -e "${GREEN}✓${NC} Storage bucket policies configured"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} Storage bucket policies missing"
  ((checks_failed++))
fi

echo ""
echo "🧱 Checking forms schema columns..."

if grep -q "id text primary key" supabase/schema.sql && grep -q "fields jsonb" supabase/schema.sql && grep -q "metadata jsonb" supabase/schema.sql; then
  echo -e "${GREEN}✓${NC} forms table uses text ids with fields/tags/metadata columns"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} forms table schema missing text id or fields/tags/metadata columns"
  ((checks_failed++))
fi

# Check for org prefix in upload code
echo ""
echo "🔐 Checking security implementation..."

if grep -q "org-\$_orgId" apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Upload paths use org prefix"
  ((checks_passed++))
else
  if grep -q "org-\$orgId" apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Upload paths use org prefix"
    ((checks_passed++))
  else
    echo -e "${RED}✗${NC} Upload paths missing org prefix"
    ((checks_failed++))
  fi
fi

# Check pending queue has orgId
if grep -q "orgId" apps/mobile/lib/features/dashboard/data/pending_queue.dart 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Offline queue supports org prefix"
  ((checks_passed++))
else
  echo -e "${RED}✗${NC} Offline queue missing org support"
  ((checks_failed++))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Summary: ${GREEN}$checks_passed passed${NC}, ${RED}$checks_failed failed${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $checks_failed -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed! Ready for testing.${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Apply schema.sql in Supabase Dashboard"
  echo "2. Create storage bucket: formbridge-attachments"
  echo "3. Apply seed.sql for demo data"
  echo "4. Run the app: ./run-mobile.sh"
  echo "5. Follow SUPABASE_PREFLIGHT.md checklist"
  echo ""
  exit 0
else
  echo -e "${RED}❌ Some checks failed. Please review and fix.${NC}"
  echo ""
  echo "See SUPABASE_SETUP.md for detailed setup instructions."
  echo ""
  exit 1
fi
