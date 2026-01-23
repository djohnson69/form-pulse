import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  checkRateLimit,
  rateLimitKey,
  rateLimitResponse,
} from "../_shared/rate_limiter.ts";
import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";

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

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Rate limiting by IP: 30 requests per minute to prevent enumeration attacks
  // Use x-forwarded-for header or fallback to a constant for local dev
  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const rateLimitResult = await checkRateLimit(
    supabase,
    rateLimitKey("project-share", clientIp),
    30, // max requests
    60, // window in seconds
  );
  if (!rateLimitResult.allowed) {
    return rateLimitResponse(rateLimitResult, corsHeaders);
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch (_) {
    payload = {};
  }
  const token = payload.token?.toString();
  if (!token) {
    return jsonResponse({ error: "token is required" }, 400);
  }

  const { data: project } = await supabase
    .from("projects")
    .select("*")
    .eq("share_token", token)
    .maybeSingle();

  if (!project) {
    return jsonResponse({ error: "Project not found" }, 404);
  }

  const { data: updates, error } = await supabase
    .from("project_updates")
    .select("*")
    .eq("project_id", project.id)
    .eq("is_shared", true)
    .order("created_at", { ascending: false });

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({
    project: mapProject(project),
    updates: (updates ?? []).map(mapUpdate),
  });
});

function mapProject(project: Record<string, unknown>) {
  return {
    id: project.id,
    orgId: project.org_id,
    name: project.name,
    description: project.description,
    status: project.status,
    labels: project.labels ?? [],
    coverUrl: project.cover_url,
    shareToken: project.share_token,
    createdBy: project.created_by,
    createdAt: project.created_at,
    updatedAt: project.updated_at,
    metadata: project.metadata ?? {},
  };
}

function mapUpdate(update: Record<string, unknown>) {
  return {
    id: update.id,
    projectId: update.project_id,
    orgId: update.org_id,
    userId: update.user_id,
    type: update.type,
    title: update.title,
    body: update.body,
    tags: update.tags ?? [],
    attachments: update.attachments ?? [],
    parentId: update.parent_id,
    isShared: update.is_shared ?? false,
    createdAt: update.created_at,
    metadata: update.metadata ?? {},
  };
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
