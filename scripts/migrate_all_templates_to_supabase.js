#!/usr/bin/env node
/**
 * Migrate all templates (Supabase forms + React-only templates) into app_templates.
 *
 * Env vars:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY (service key)
 *   ORG_ID (defaults to demo org if unset)
 *
 * Behavior:
 * - Fetches all forms for the target org from the `forms` table.
 * - Adds the React UI-only templates (TemplateBuilder/Manager/DocumentTemplateLibrary).
 * - Deduplicates by name (prefers the form-sourced template if a name collides).
 * - Clears existing app_templates for the target org, then inserts the combined set.
 */

const { createClient } = require('@supabase/supabase-js');
const { randomUUID } = require('crypto');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ORG_ID =
  process.env.ORG_ID || '00000000-0000-0000-0000-000000000001';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    '❌ Missing env vars. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (service role).'
  );
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// React-only templates (not necessarily in forms table)
const reactTemplates = [
  {
    name: 'Daily Safety Inspection',
    type: 'checklist',
    description: 'Standard daily site safety inspection checklist',
    steps: ['Check PPE compliance', 'Inspect equipment', 'Review hazards', 'Document findings'],
    usageCount: 145,
    tags: ['safety', 'daily', 'construction'],
  },
  {
    name: 'Equipment Maintenance Workflow',
    type: 'workflow',
    description: 'Complete workflow for equipment maintenance requests',
    steps: [
      'Submit request',
      'Manager approval',
      'Maintenance scheduling',
      'Work completion',
      'Sign-off',
    ],
    assignedRoles: ['Employee', 'Manager', 'Maintenance Lead'],
    usageCount: 89,
  },
  {
    name: 'Incident Report Template',
    type: 'report',
    description: 'Standardized incident reporting format',
    fields: [
      'Incident Type',
      'Date & Time',
      'Location',
      'Description',
      'Witnesses',
      'Photos',
    ],
    usageCount: 67,
  },
  {
    name: 'New Employee Onboarding',
    type: 'workflow',
    description: 'Multi-step employee onboarding process',
    steps: [
      'Documentation',
      'Safety Training',
      'Tool Assignment',
      'Site Orientation',
      'Supervisor Meeting',
    ],
    assignedRoles: ['HR', 'Safety Manager', 'Site Supervisor'],
    usageCount: 34,
  },
  {
    name: 'Project Completion Report',
    type: 'report',
    description: 'Comprehensive project completion documentation',
    fields: [
      'Project Summary',
      'Budget Analysis',
      'Timeline Review',
      'Client Sign-off',
    ],
    usageCount: 67,
  },
  {
    name: 'Equipment Maintenance Form',
    type: 'form',
    description: 'Standard form for recording equipment maintenance',
    fields: ['Equipment ID', 'Maintenance Type', 'Parts Used', 'Hours of Service'],
    usageCount: 89,
  },
  {
    name: 'Incident Investigation',
    type: 'workflow',
    description: 'Step-by-step workflow for investigating workplace incidents',
    fields: [
      'Initial Report',
      'Witness Interviews',
      'Root Cause Analysis',
      'Corrective Actions',
    ],
    usageCount: 23,
  },
  {
    name: 'Weekly Progress Report',
    type: 'report',
    description: 'Weekly project progress summary for stakeholders',
    fields: ['Tasks Completed', 'Upcoming Milestones', 'Issues & Risks', 'Photos'],
    usageCount: 156,
  },
  {
    name: 'Equipment Inspection Form',
    type: 'form',
    description: 'Detailed equipment condition assessment and maintenance log',
    fields: ['Equipment', 'Condition', 'Issues', 'Photos'],
    usageCount: 987,
    tags: ['equipment', 'maintenance', 'inspection'],
  },
  {
    name: 'Service Contract Agreement',
    type: 'form',
    description: 'Standard service contract template with terms and conditions',
    fields: ['Parties', 'Scope', 'Terms', 'Signature'],
    usageCount: 2341,
    tags: ['contract', 'legal', 'service'],
  },
  {
    name: 'Site Safety Checklist',
    type: 'checklist',
    description: 'Pre-work safety verification checklist for job sites',
    steps: ['Verify PPE', 'Inspect site', 'Review JHA', 'Confirm emergency plan'],
    usageCount: 1567,
    tags: ['safety', 'checklist', 'pre-work'],
  },
  {
    name: 'Incident Report Form',
    type: 'report',
    description: 'Comprehensive incident documentation with witness statements',
    fields: ['Incident Type', 'Description', 'Witnesses', 'Photos'],
    usageCount: 876,
    tags: ['incident', 'report', 'safety'],
  },
  {
    name: 'Weekly Toolbox Talk',
    type: 'report',
    description: 'Weekly safety meeting documentation template',
    fields: ['Topic', 'Attendees', 'Notes', 'Actions'],
    usageCount: 654,
    tags: ['safety', 'training', 'weekly'],
  },
];

function formToTemplateRow(form) {
  return {
    id: randomUUID(),
    org_id: form.org_id,
    type: 'form',
    name: form.title,
    description: form.description,
    payload: {
      fields: form.fields ?? [],
      category: form.category,
      tags: form.tags ?? [],
      version: form.version ?? form.current_version,
      form_metadata: form.metadata ?? {},
    },
    assigned_roles: [],
    assigned_user_ids: [],
    is_active: true,
    metadata: {
      source: 'forms_table',
      usageCount: (form.metadata && form.metadata.usageCount) || 0,
    },
    created_at: form.created_at || new Date().toISOString(),
    updated_at: form.updated_at || new Date().toISOString(),
  };
}

function reactTemplateToRow(tpl) {
  return {
    id: randomUUID(),
    org_id: ORG_ID,
    type: tpl.type,
    name: tpl.name,
    description: tpl.description,
    payload: {
      steps: tpl.steps ?? [],
      fields: tpl.fields ?? [],
      tags: tpl.tags ?? [],
    },
    assigned_roles: tpl.assignedRoles ?? [],
    assigned_user_ids: [],
    is_active: true,
    metadata: {
      usageCount: tpl.usageCount ?? 0,
      source: 'react_seed',
    },
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
}

async function fetchForms() {
  const { data, error } = await supabase
    .from('forms')
    .select('*')
    .eq('org_id', ORG_ID)
    .limit(1000);
  if (error) throw error;
  return data || [];
}

async function run() {
  console.log(`🚀 Migrating forms + React templates into app_templates (org_id=${ORG_ID})`);
  const forms = await fetchForms();
  console.log(`📥 Loaded ${forms.length} forms from 'forms' table`);

  const mapByName = new Map();

  // Prefer form-sourced definitions
  for (const form of forms) {
    mapByName.set(form.title, formToTemplateRow(form));
  }

  for (const tpl of reactTemplates) {
    if (mapByName.has(tpl.name)) continue; // keep form version if name collides
    mapByName.set(tpl.name, reactTemplateToRow(tpl));
  }

  const rows = Array.from(mapByName.values());
  console.log(`🧹 Clearing existing app_templates for org ${ORG_ID}`);
  const { error: delErr } = await supabase
    .from('app_templates')
    .delete()
    .eq('org_id', ORG_ID);
  if (delErr) {
    console.error('❌ Delete failed:', delErr);
    process.exit(1);
  }

  console.log(`⬆️ Inserting ${rows.length} templates`);
  const { error: insErr } = await supabase.from('app_templates').insert(rows);
  if (insErr) {
    console.error('❌ Insert failed:', insErr);
    process.exit(1);
  }

  console.log('✅ Migration complete.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
