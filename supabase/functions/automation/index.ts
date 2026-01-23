import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";

const CERT_EXPIRY_WARNING_DAYS = 30;
const TASK_DUE_WINDOW_HOURS = 24;
const ASSET_MAINTENANCE_WINDOW_DAYS = 7;

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return corsResponse(req);
  }
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(
      { error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing." },
      500,
    );
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch (_) {
    payload = {};
  }
  const orgId = payload.orgId?.toString();

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: rules, error } = await supabase
    .from("notification_rules")
    .select("*")
    .eq("is_active", true);

  if (error || !rules) {
    return jsonResponse(
      { error: error?.message ?? "Failed to load notification rules." },
      500,
    );
  }

  const byOrg = new Map<string, Record<string, unknown>[]>();
  for (const rule of rules) {
    const ruleOrg = rule.org_id?.toString();
    if (!ruleOrg) continue;
    if (orgId && ruleOrg !== orgId) continue;
    const list = byOrg.get(ruleOrg) ?? [];
    list.push(rule);
    byOrg.set(ruleOrg, list);
  }

  const results: Record<string, unknown> = {};
  for (const [org, orgRules] of byOrg.entries()) {
    const summary = await runOrgRules(supabase, org, orgRules);
    results[org] = summary;
  }

  return jsonResponse({ ok: true, results });
});

async function runOrgRules(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  rules: Record<string, unknown>[],
) {
  const now = new Date();
  const counts = {
    submission: await countRecentSubmissions(supabase, orgId, now),
    task_due: await countDueTasks(supabase, orgId, now),
    training_expire: await countExpiringTraining(supabase, orgId, now),
    asset_due: await countAssetMaintenance(supabase, orgId, now),
    inspection_due: await countDueInspections(supabase, orgId, now),
    sop_ack_due: await countPendingSopAcknowledgements(supabase, orgId),
  };

  let fired = 0;
  let notificationsSent = 0;
  const breakdown: Record<string, number> = {};

  for (const rule of rules) {
    const triggerType = rule.trigger_type?.toString() ?? "unknown";
    const count = (counts as Record<string, number>)[triggerType] ?? 0;
    if (count === 0) continue;
    breakdown[triggerType] = (breakdown[triggerType] ?? 0) + count;
    const targets = await resolveRuleTargets(supabase, orgId, rule);
    await supabase.from("notification_events").insert({
      org_id: orgId,
      rule_id: rule.id,
      status: "fired",
      fired_at: new Date().toISOString(),
      payload: {
        trigger: triggerType,
        count,
      },
    });
    if (targets.length === 0) continue;
    const message =
      rule.message_template?.toString() ??
      defaultMessage(triggerType, count);
    const payload = targets.map((userId) => ({
      org_id: orgId,
      user_id: userId,
      title: rule.name ?? "Automation",
      body: message,
      type: triggerType,
      is_read: false,
    }));
    await supabase.from("notifications").insert(payload);
    fired += 1;
    notificationsSent += targets.length;
  }

  return {
    rulesChecked: rules.length,
    rulesFired: fired,
    notificationsSent,
    breakdown,
  };
}

async function resolveRuleTargets(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  rule: Record<string, unknown>,
) {
  const targetType = rule.target_type?.toString() ?? "org";
  const targetIds = Array.isArray(rule.target_ids)
    ? rule.target_ids.map((id) => id?.toString()).filter(Boolean)
    : [];
  if (targetType === "org") {
    const { data } = await supabase
      .from("org_members")
      .select("user_id")
      .eq("org_id", orgId);
    return (data ?? [])
      .map((row) => row.user_id?.toString())
      .filter(Boolean);
  }
  if (targetType === "user") {
    return targetIds;
  }
  if (targetType === "team") {
    if (targetIds.length === 0) return [];
    const { data } = await supabase
      .from("team_members")
      .select("user_id")
      .in("team_id", targetIds);
    return (data ?? [])
      .map((row) => row.user_id?.toString())
      .filter(Boolean);
  }
  return [];
}

async function countRecentSubmissions(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  now: Date,
) {
  const since = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
  const { data } = await supabase
    .from("submissions")
    .select("id")
    .eq("org_id", orgId)
    .gte("created_at", since);
  return data?.length ?? 0;
}

async function countDueTasks(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  now: Date,
) {
  const { data } = await supabase
    .from("tasks")
    .select("id, due_date, status")
    .eq("org_id", orgId);
  let count = 0;
  for (const row of data ?? []) {
    const due = row.due_date ? new Date(row.due_date) : null;
    if (!due) continue;
    if (row.status?.toString() === "completed") continue;
    const diffHours = (due.getTime() - now.getTime()) / 3600000;
    if (diffHours >= 0 && diffHours <= TASK_DUE_WINDOW_HOURS) {
      count += 1;
    }
  }
  return count;
}

async function countExpiringTraining(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  now: Date,
) {
  const { data } = await supabase
    .from("training_records")
    .select("id, expiration_date, status")
    .eq("org_id", orgId);
  let count = 0;
  for (const row of data ?? []) {
    const expires = row.expiration_date
      ? new Date(row.expiration_date)
      : null;
    if (!expires) continue;
    if (row.status?.toString() === "expired") continue;
    const days = (expires.getTime() - now.getTime()) / 86400000;
    if (days >= 0 && days <= CERT_EXPIRY_WARNING_DAYS) {
      count += 1;
    }
  }
  return count;
}

async function countAssetMaintenance(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  now: Date,
) {
  const { data } = await supabase
    .from("equipment")
    .select("id, next_maintenance_date, is_active")
    .eq("org_id", orgId)
    .eq("is_active", true);
  let count = 0;
  for (const row of data ?? []) {
    const nextDate = row.next_maintenance_date
      ? new Date(row.next_maintenance_date)
      : null;
    if (!nextDate) continue;
    const days = (nextDate.getTime() - now.getTime()) / 86400000;
    if (days <= ASSET_MAINTENANCE_WINDOW_DAYS) {
      count += 1;
    }
  }
  return count;
}

async function countDueInspections(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
  now: Date,
) {
  const { data } = await supabase
    .from("equipment")
    .select("id, inspection_cadence, next_inspection_at, is_active")
    .eq("org_id", orgId)
    .eq("is_active", true);
  let count = 0;
  for (const row of data ?? []) {
    const cadence = row.inspection_cadence?.toString();
    if (!cadence) continue;
    const nextAt = row.next_inspection_at
      ? new Date(row.next_inspection_at)
      : null;
    if (!nextAt) continue;
    if (nextAt.getTime() <= now.getTime()) {
      count += 1;
    }
  }
  return count;
}

async function countPendingSopAcknowledgements(
  supabase: ReturnType<typeof createClient>,
  orgId: string,
) {
  const { data: docs } = await supabase
    .from("sop_documents")
    .select("id, current_version_id, status")
    .eq("org_id", orgId)
    .eq("status", "published");
  if (!docs || docs.length === 0) return 0;
  const { data: members } = await supabase
    .from("org_members")
    .select("user_id")
    .eq("org_id", orgId);
  const memberIds = (members ?? [])
    .map((row) => row.user_id?.toString())
    .filter(Boolean) as string[];
  if (memberIds.length === 0) return 0;
  const sopIds = docs
    .map((doc) => doc.id?.toString())
    .filter(Boolean) as string[];
  if (sopIds.length === 0) return 0;
  const { data: acknowledgements } = await supabase
    .from("sop_acknowledgements")
    .select("sop_id, version_id, user_id")
    .eq("org_id", orgId)
    .in("sop_id", sopIds);
  const acked = new Set<string>();
  for (const row of acknowledgements ?? []) {
    const sopId = row.sop_id?.toString();
    const versionId = row.version_id?.toString();
    const userId = row.user_id?.toString();
    if (!sopId || !versionId || !userId) continue;
    acked.add(`${sopId}:${versionId}:${userId}`);
  }
  let count = 0;
  for (const doc of docs) {
    const sopId = doc.id?.toString();
    const versionId = doc.current_version_id?.toString();
    if (!sopId || !versionId) continue;
    for (const userId of memberIds) {
      if (!acked.has(`${sopId}:${versionId}:${userId}`)) {
        count += 1;
      }
    }
  }
  return count;
}

function defaultMessage(type: string, count: number) {
  switch (type) {
    case "submission":
      return `${count} new submissions in the last 24 hours.`;
    case "task_due":
      return `${count} tasks due within 24 hours.`;
    case "training_expire":
      return `${count} certifications expiring soon.`;
    case "asset_due":
      return `${count} assets need maintenance.`;
    case "inspection_due":
      return `${count} inspections due.`;
    case "sop_ack_due":
      return `${count} SOP acknowledgements pending.`;
    default:
      return "Automation triggered.";
  }
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
