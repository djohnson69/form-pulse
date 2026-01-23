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
  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const successUrl = Deno.env.get("STRIPE_SUCCESS_URL");
  const cancelUrl = Deno.env.get("STRIPE_CANCEL_URL");

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(
      { error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing." },
      500,
    );
  }
  if (!stripeKey || !successUrl || !cancelUrl) {
    return jsonResponse(
      { error: "Stripe env vars missing." },
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

  // Rate limiting: 20 payment requests per minute per user
  const rateLimitResult = await checkRateLimit(
    supabase,
    rateLimitKey("payments", caller.id),
    20, // max requests
    60, // window in seconds
  );
  if (!rateLimitResult.allowed) {
    return rateLimitResponse(rateLimitResult, corsHeaders);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse({ error: "Invalid JSON payload." }, 400);
  }

  const requestId = payload.requestId?.toString();
  if (!requestId) {
    return jsonResponse({ error: "requestId is required." }, 400);
  }

  const amount = Number(payload.amount ?? 0);
  const currency = (payload.currency ?? "USD").toString().toLowerCase();
  const description = payload.description?.toString() ?? "Payment request";
  const orgId = payload.orgId?.toString();
  const projectId = payload.projectId?.toString();

  if (!amount || amount <= 0) {
    return jsonResponse({ error: "Valid amount is required." }, 400);
  }

  const params = new URLSearchParams();
  params.append("mode", "payment");
  params.append("success_url", successUrl);
  params.append("cancel_url", cancelUrl);
  params.append("line_items[0][quantity]", "1");
  params.append("line_items[0][price_data][currency]", currency);
  params.append(
    "line_items[0][price_data][product_data][name]",
    description,
  );
  params.append(
    "line_items[0][price_data][unit_amount]",
    Math.round(amount * 100).toString(),
  );
  params.append("client_reference_id", requestId);
  params.append("metadata[request_id]", requestId);
  if (orgId) params.append("metadata[org_id]", orgId);
  if (projectId) params.append("metadata[project_id]", projectId);

  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params,
  });

  if (!response.ok) {
    const text = await response.text();
    return jsonResponse(
      { error: `Stripe error (${response.status}): ${text}` },
      500,
    );
  }

  const session = await response.json();
  const checkoutUrl = session.url?.toString();
  const sessionId = session.id?.toString();

  const { data: existing } = await supabase
    .from("payment_requests")
    .select("metadata")
    .eq("id", requestId)
    .maybeSingle();

  const nextMetadata = {
    ...(existing?.metadata ?? {}),
    provider: "stripe",
    checkoutUrl,
    checkoutSessionId: sessionId,
  };

  await supabase
    .from("payment_requests")
    .update({
      metadata: nextMetadata,
      status: "pending_payment",
    })
    .eq("id", requestId);

  return jsonResponse({
    requestId,
    checkoutUrl,
    checkoutSessionId: sessionId,
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
