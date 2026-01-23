import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";

/**
 * subscription-check: Scheduled function to update subscription statuses
 *
 * This function should be called periodically (e.g., hourly via pg_cron or external scheduler)
 * to handle:
 * - Expired trials → status = 'expired'
 * - Past-due subscriptions (period ended) → status = 'past_due'
 * - Grace period expiration → status = 'canceled'
 *
 * Authentication: Uses service role key, no user auth required
 * Can be triggered via:
 * - POST with a secret key in Authorization header
 * - pg_cron calling via pg_net
 * - External scheduler (Vercel cron, GitHub Actions, etc.)
 */

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return corsResponse(req);
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const cronSecret = Deno.env.get("CRON_SECRET");

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Missing Supabase configuration." }, 500);
  }

  // Verify authorization - either cron secret or service role
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7)
    : "";

  // Allow if token matches cron secret or service key
  const isAuthorized = token === cronSecret || token === serviceKey;
  if (!isAuthorized && cronSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const now = new Date();
  const results: Record<string, number> = {
    expiredTrials: 0,
    pastDueSubscriptions: 0,
    canceledAfterGrace: 0,
    expiredInvitations: 0,
  };

  // 1. Expire trials that have ended
  const { data: expiredTrialsData } = await supabase
    .from("subscriptions")
    .update({
      status: "expired",
      updated_at: now.toISOString(),
    })
    .eq("status", "trialing")
    .lt("trial_end", now.toISOString())
    .select("id");

  results.expiredTrials = expiredTrialsData?.length ?? 0;

  // 2. Mark subscriptions as past_due if current period has ended
  const { data: pastDueData } = await supabase
    .from("subscriptions")
    .update({
      status: "past_due",
      updated_at: now.toISOString(),
    })
    .eq("status", "active")
    .lt("current_period_end", now.toISOString())
    .select("id");

  results.pastDueSubscriptions = pastDueData?.length ?? 0;

  // 3. Cancel subscriptions that have been past_due for more than 30 days (grace period)
  const gracePeriodEnd = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const { data: canceledData } = await supabase
    .from("subscriptions")
    .update({
      status: "canceled",
      canceled_at: now.toISOString(),
      updated_at: now.toISOString(),
    })
    .eq("status", "past_due")
    .lt("current_period_end", gracePeriodEnd.toISOString())
    .select("id");

  results.canceledAfterGrace = canceledData?.length ?? 0;

  // 4. Also expire old invitations using the existing RPC function
  try {
    const { data: expiredInvites } = await supabase.rpc("expire_old_invitations");
    results.expiredInvitations = expiredInvites ?? 0;
  } catch (err) {
    console.error("Failed to expire invitations:", err);
  }

  // 5. Cleanup old rate limit entries
  try {
    const { data: cleanedRateLimits } = await supabase.rpc("cleanup_rate_limits", {
      p_older_than_hours: 24,
    });
    results.cleanedRateLimits = cleanedRateLimits ?? 0;
  } catch (err) {
    // Rate limiting may not be set up yet
    console.log("Rate limit cleanup skipped:", err);
  }

  console.log("Subscription check completed:", results);

  return jsonResponse({
    ok: true,
    timestamp: now.toISOString(),
    results,
  });
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
