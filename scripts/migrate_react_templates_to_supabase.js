#!/usr/bin/env node
/**
 * Seed the Supabase app_templates table with the React template set.
 *
 * Usage:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... ORG_ID=... node scripts/migrate_react_templates_to_supabase.js
 *
 * Notes:
 * - Uses the service role key so it can upsert into app_templates. Do NOT expose that key to the client.
 * - Upserts on (org_id, name) so reruns are idempotent.
 */
const { createClient } = require('@supabase/supabase-js');
const { randomUUID } = require('crypto');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ORG_ID = process.env.ORG_ID || '00000000-0000-0000-0000-000000000001';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing env vars. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (service role).');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Combined React template lists (TemplateBuilder, TemplateManager, DocumentTemplateLibrary)
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

async function run() {
  console.log(`🚀 Seeding ${reactTemplates.length} templates into app_templates (org_id=${ORG_ID})`);

  const names = reactTemplates.map((t) => t.name);
  const { error: deleteErr } = await supabase
    .from('app_templates')
    .delete()
    .eq('org_id', ORG_ID)
    .in('name', names);
  if (deleteErr) {
    console.error('❌ Pre-clean failed:', deleteErr);
    process.exit(1);
  }

  const rows = reactTemplates.map((tpl) => ({
    id: randomUUID(),
    org_id: ORG_ID,
    type: tpl.type,
    name: tpl.name,
    description: tpl.description,
    payload: {
      steps: tpl.steps ?? [],
      fields: tpl.fields ?? [],
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
  }));

  const { error } = await supabase.from('app_templates').insert(rows);

  if (error) {
    console.error('❌ Insert failed:', error);
    process.exit(1);
  }

  console.log('✅ Templates seeded successfully.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
