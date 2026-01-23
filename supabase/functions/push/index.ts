import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  checkRateLimit,
  rateLimitKey,
  rateLimitResponse,
} from "../_shared/rate_limiter.ts";
import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";

const FCM_URL = "https://fcm.googleapis.com/fcm/send";

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
  const fcmKey = Deno.env.get("FCM_SERVER_KEY");
  if (!supabaseUrl || !serviceKey || !fcmKey) {
    return jsonResponse(
      {
        error:
          "SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or FCM_SERVER_KEY missing.",
      },
      500,
    );
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Extract and verify auth token
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7)
    : "";
  if (!token) {
    return jsonResponse({ error: "Missing Authorization bearer token." }, 401);
  }

  const { data: userInfo, error: userError } = await supabase.auth.getUser(token);
  const caller = userInfo?.user;
  if (userError || !caller) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  // Rate limiting: 100 notifications per minute per user
  const rateLimitResult = await checkRateLimit(
    supabase,
    rateLimitKey("push", caller.id),
    100, // max requests
    60,  // window in seconds
  );
  if (!rateLimitResult.allowed) {
    return rateLimitResponse(rateLimitResult, corsHeaders);
  }

  const payload = await req.json();
  const title = payload.title?.toString() ?? "Form Bridge";
  const body = payload.body?.toString() ?? "";
  const orgId = payload.orgId?.toString();
  const userId = payload.userId?.toString();
  const data = payload.data ?? {};

  if (!orgId && !userId) {
    return jsonResponse({ error: "orgId or userId is required." }, 400);
  }

  // Verify caller has permission to send to this org/user
  if (orgId) {
    const { data: membership } = await supabase
      .from("org_members")
      .select("role")
      .eq("org_id", orgId)
      .eq("user_id", caller.id)
      .maybeSingle();

    if (!membership) {
      return jsonResponse({ error: "Not authorized to send notifications to this organization." }, 403);
    }
  }

  if (userId && userId !== caller.id) {
    // Allow sending to self, or check if caller is admin/superadmin in same org
    const { data: callerProfile } = await supabase
      .from("profiles")
      .select("org_id, role")
      .eq("id", caller.id)
      .maybeSingle();

    const { data: targetProfile } = await supabase
      .from("profiles")
      .select("org_id")
      .eq("id", userId)
      .maybeSingle();

    const isAdmin = callerProfile?.role === "superadmin" || callerProfile?.role === "admin";
    const sameOrg = callerProfile?.org_id && callerProfile.org_id === targetProfile?.org_id;

    if (!isAdmin || !sameOrg) {
      return jsonResponse({ error: "Not authorized to send notifications to this user." }, 403);
    }
  }

  let query = supabase
    .from("device_tokens")
    .select("token")
    .eq("is_active", true);
  if (orgId) {
    query = query.eq("org_id", orgId);
  }
  if (userId) {
    query = query.eq("user_id", userId);
  }

  const { data: tokens, error } = await query;
  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }
  const targets = (tokens ?? [])
    .map((row) => row.token?.toString())
    .filter((token) => token && token.length > 0);
  if (targets.length === 0) {
    return jsonResponse({ ok: true, sent: 0 });
  }

  const result = await fetch(FCM_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${fcmKey}`,
    },
    body: JSON.stringify({
      registration_ids: targets,
      notification: { title, body },
      data,
    }),
  });
  if (!result.ok) {
    const message = await result.text();
    return jsonResponse({ error: message }, 500);
  }
  const response = await result.json();
  return jsonResponse({ ok: true, sent: targets.length, response });
});

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
