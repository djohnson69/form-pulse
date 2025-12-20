#!/usr/bin/env node
// Convert forms JSON to SQL INSERT statements for Supabase

const fs = require('fs');
const path = require('path');

const ORG_ID = '00000000-0000-0000-0000-000000000001';

// Read forms from export
const formsJsonPath = '/tmp/forms_export.json';
const formsData = JSON.parse(fs.readFileSync(formsJsonPath, 'utf8'));
const forms = formsData.forms;

console.log(`Processing ${forms.length} forms...`);

// Generate SQL
let sql = `-- Form Templates for Supabase
-- Auto-generated from backend server
-- Total forms: ${forms.length}
-- Run this in Supabase SQL Editor

BEGIN;

`;

forms.forEach((form, index) => {
  const id = form.id.replace(/'/g, "''");
  const title = form.title.replace(/'/g, "''");
  const description = (form.description || '').replace(/'/g, "''");
  const category = (form.category || 'Other').replace(/'/g, "''");
  const tags = form.tags ? `ARRAY[${form.tags.map(t => `'${t.replace(/'/g, "''")}'`).join(', ')}]` : 'ARRAY[]::text[]';
  const version = (form.version || '1.0.0').replace(/'/g, "''");
  const createdBy = (form.createdBy || 'system').replace(/'/g, "''");
  const createdAt = form.createdAt || new Date().toISOString();
  
  // Convert fields to JSONB
  const fields = JSON.stringify(form.fields || []).replace(/'/g, "''");
  const metadata = JSON.stringify(form.metadata || {}).replace(/'/g, "''");

  sql += `INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by, created_at, fields, metadata)
VALUES (
  '${id}',
  '${ORG_ID}',
  '${title}',
  '${description}',
  '${category}',
  ${tags},
  ${form.isPublished !== false},
  '${version}',
  '${createdBy}',
  '${createdAt}',
  '${fields}'::jsonb,
  '${metadata}'::jsonb
)
ON CONFLICT (id, org_id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  tags = EXCLUDED.tags,
  is_published = EXCLUDED.is_published,
  version = EXCLUDED.version,
  updated_at = NOW();

`;

  if ((index + 1) % 20 === 0) {
    console.log(`  Processed ${index + 1}/${forms.length} forms...`);
  }
});

sql += `
COMMIT;

-- Verify insertion
SELECT category, COUNT(*) as count 
FROM forms 
WHERE org_id = '${ORG_ID}'
GROUP BY category 
ORDER BY category;

SELECT 'Successfully inserted ' || COUNT(*)::text || ' forms' as result
FROM forms
WHERE org_id = '${ORG_ID}';
`;

// Write to file
const outputPath = path.join(__dirname, 'supabase', 'populate_all_forms.sql');
fs.writeFileSync(outputPath, sql);

console.log(`\n✅ Generated SQL file: ${outputPath}`);
console.log(`📊 Total forms: ${forms.length}`);
console.log(`\n📋 Next steps:`);
console.log(`   1. Open Supabase Dashboard > SQL Editor`);
console.log(`   2. Copy the contents of: supabase/populate_all_forms.sql`);
console.log(`   3. Paste and run the SQL`);
console.log(`   4. Verify forms are inserted`);
console.log(`   5. Reload your Flutter app\n`);
