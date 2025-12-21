import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const FCM_URL = "https://fcm.googleapis.com/fcm/send";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
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

  const payload = await req.json();
  const title = payload.title?.toString() ?? "Form Bridge";
  const body = payload.body?.toString() ?? "";
  const orgId = payload.orgId?.toString();
  const userId = payload.userId?.toString();
  const data = payload.data ?? {};

  if (!orgId && !userId) {
    return jsonResponse({ error: "orgId or userId is required." }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

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
