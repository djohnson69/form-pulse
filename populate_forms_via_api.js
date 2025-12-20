#!/usr/bin/env node
// Populate all templates into Supabase using the service role key by parsing supabase/populate_all_forms.sql.
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = 'https://xpcibptzncfmifaneoop.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_KEY;
const ORG_ID = '00000000-0000-0000-0000-000000000001';
const SQL_FILE = path.join(__dirname, 'supabase', 'populate_all_forms.sql');

function stripOuterQuotes(value) {
  const trimmed = value.trim();
  if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
    return trimmed.slice(1, -1).replace(/''/g, "'");
  }
  return trimmed;
}

function parseTags(value) {
  const match = value.match(/ARRAY\[(.*)\]/i);
  if (!match) return [];
  const inner = match[1];
  const tags = [];
  const regex = /'((?:[^']|'{2})*)'/g;
  let m;
  while ((m = regex.exec(inner)) !== null) {
    tags.push(m[1].replace(/''/g, "'").trim());
  }
  return tags;
}

function parseJsonField(value) {
  const noCast = value.replace(/::jsonb$/i, '');
  return JSON.parse(stripOuterQuotes(noCast));
}

function parseFormBlocks(sql) {
  const regex = /INSERT INTO forms\s*\(.*?\)\s*VALUES\s*\(\s*([\s\S]*?)\)\s*ON CONFLICT/gi;
  const forms = [];
  let match;
  while ((match = regex.exec(sql)) !== null) {
    const block = match[1];
    const lines = block
      .split(/\n/)
      .map((l) => l.trim())
      .filter(Boolean)
      .map((l) => l.replace(/,$/, ''));

    if (lines.length < 11) continue;

    const [
      id,
      orgId,
      title,
      description,
      category,
      tags,
      isPublished,
      version,
      createdBy,
      createdAt,
      fields,
      metadata,
    ] = lines;

    forms.push({
      id: stripOuterQuotes(id),
      org_id: stripOuterQuotes(orgId),
      title: stripOuterQuotes(title),
      description: stripOuterQuotes(description),
      category: stripOuterQuotes(category),
      tags: parseTags(tags),
      is_published: isPublished.toLowerCase().includes('true'),
      version: stripOuterQuotes(version),
      created_by: stripOuterQuotes(createdBy),
      created_at: stripOuterQuotes(createdAt),
      fields: parseJsonField(fields),
      metadata: parseJsonField(metadata),
    });
  }
  return forms;
}

async function loadForms() {
  if (!SUPABASE_SERVICE_ROLE_KEY) {
    console.error('❌ Missing SUPABASE_SERVICE_KEY (service role key). Set it in your environment.');
    process.exit(1);
  }

  if (!fs.existsSync(SQL_FILE)) {
    console.error('❌ SQL file not found:', SQL_FILE);
    process.exit(1);
  }

  const sql = fs.readFileSync(SQL_FILE, 'utf8');
  const parsed = parseFormBlocks(sql).map((f) => ({
    ...f,
    org_id: ORG_ID,
  }));

  // Deduplicate by id (keep last occurrence)
  const deduped = Array.from(
    parsed
      .reduce((map, form) => map.set(form.id, form), new Map())
      .values()
  );

  if (!deduped.length) {
    console.error('❌ No forms parsed from SQL. Check file format.');
    process.exit(1);
  }

  console.log(`🚀 Loading ${deduped.length} forms into Supabase via API...\n`);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let loaded = 0;
  let errors = 0;

  // Batch upserts to avoid payload size limits
  const batchSize = 50;
  for (let i = 0; i < deduped.length; i += batchSize) {
    const batch = deduped.slice(i, i + batchSize);
    const { error, data } = await supabase.from('forms').upsert(batch, {
      onConflict: 'id',
      returning: 'minimal',
    });
    if (error) {
      console.error(`❌ Batch ${i / batchSize + 1} failed:`, error.message);
      errors += batch.length;
    } else {
      loaded += batch.length;
      console.log(`✅ Batch ${i / batchSize + 1}: upserted ${batch.length}`);
    }
  }

  console.log(`\n📊 Summary:`);
  console.log(`   ✅ Successfully loaded: ${loaded}`);
  console.log(`   ❌ Errors: ${errors}`);
  console.log(`\n🎉 Done! Refresh your app to see the templates.`);
}

loadForms().catch((err) => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
