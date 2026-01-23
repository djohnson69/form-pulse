import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";
import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return corsResponse(req);
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Missing Supabase configuration." }, 500);
  }
  if (!stripeSecretKey) {
    return jsonResponse({ error: "Missing Stripe configuration." }, 500);
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7)
    : "";
  if (!token) {
    return jsonResponse({ error: "Missing Authorization bearer token." }, 401);
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch (_) {
    payload = {};
  }

  const orgId = payload.orgId?.toString() ?? "";
  const action = payload.action?.toString() ?? "portal"; // portal, cancel, resume
  const returnUrl = payload.returnUrl?.toString() ?? "";

  if (!orgId) {
    return jsonResponse({ error: "orgId is required." }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Verify user is authenticated and is admin of the org
  const { data: userInfo, error: userError } = await supabase.auth.getUser(token);
  const caller = userInfo?.user;
  if (userError || !caller) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const { data: membership, error: membershipError } = await supabase
    .from("org_members")
    .select("org_id, role")
    .eq("user_id", caller.id)
    .eq("org_id", orgId)
    .maybeSingle();

  if (membershipError || !membership) {
    return jsonResponse({ error: "Not a member of this organization." }, 403);
  }

  if (membership.role !== "owner" && membership.role !== "admin") {
    return jsonResponse({ error: "Only admins can manage subscriptions." }, 403);
  }

  // Get subscription
  const { data: subscription, error: subError } = await supabase
    .from("subscriptions")
    .select("*")
    .eq("org_id", orgId)
    .maybeSingle();

  if (subError || !subscription) {
    return jsonResponse({ error: "No subscription found." }, 404);
  }

  if (!subscription.stripe_customer_id) {
    return jsonResponse({ error: "No Stripe customer associated with subscription." }, 400);
  }

  const stripe = new Stripe(stripeSecretKey, {
    apiVersion: "2023-10-16",
    httpClient: Stripe.createFetchHttpClient(),
  });

  try {
    switch (action) {
      case "portal": {
        // Create billing portal session
        const session = await stripe.billingPortal.sessions.create({
          customer: subscription.stripe_customer_id,
          return_url: returnUrl || `${supabaseUrl}/settings/billing`,
        });

        return jsonResponse({
          ok: true,
          url: session.url,
        });
      }

      case "cancel": {
        // Cancel subscription at period end
        if (!subscription.stripe_subscription_id) {
          return jsonResponse({ error: "No active Stripe subscription." }, 400);
        }

        await stripe.subscriptions.update(subscription.stripe_subscription_id, {
          cancel_at_period_end: true,
        });

        // Update local record
        await supabase
          .from("subscriptions")
          .update({
            cancel_at_period_end: true,
            canceled_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", subscription.id);

        return jsonResponse({
          ok: true,
          message: "Subscription will be canceled at end of billing period.",
        });
      }

      case "resume": {
        // Resume a canceled subscription
        if (!subscription.stripe_subscription_id) {
          return jsonResponse({ error: "No active Stripe subscription." }, 400);
        }

        await stripe.subscriptions.update(subscription.stripe_subscription_id, {
          cancel_at_period_end: false,
        });

        // Update local record
        await supabase
          .from("subscriptions")
          .update({
            cancel_at_period_end: false,
            canceled_at: null,
            updated_at: new Date().toISOString(),
          })
          .eq("id", subscription.id);

        return jsonResponse({
          ok: true,
          message: "Subscription resumed.",
        });
      }

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (error) {
    console.error("Stripe error:", error);
    return jsonResponse({ error: error.message ?? "Stripe error occurred." }, 500);
  }
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
