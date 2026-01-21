import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
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
  const planId = payload.planId?.toString() ?? "";
  const billingCycle = payload.billingCycle?.toString() ?? "monthly";
  const successUrl = payload.successUrl?.toString() ?? "";
  const cancelUrl = payload.cancelUrl?.toString() ?? "";

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

  // Get org details
  const { data: org, error: orgError } = await supabase
    .from("orgs")
    .select("*")
    .eq("id", orgId)
    .single();

  if (orgError || !org) {
    return jsonResponse({ error: "Organization not found." }, 404);
  }

  // Get plan details
  let plan = null;
  if (planId) {
    const { data: planData, error: planError } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("id", planId)
      .single();

    if (planError || !planData) {
      return jsonResponse({ error: "Plan not found." }, 404);
    }
    plan = planData;
  }

  // Get or create subscription record
  const { data: existingSubscription } = await supabase
    .from("subscriptions")
    .select("*")
    .eq("org_id", orgId)
    .maybeSingle();

  const stripe = new Stripe(stripeSecretKey, {
    apiVersion: "2023-10-16",
    httpClient: Stripe.createFetchHttpClient(),
  });

  try {
    // Get or create Stripe customer
    let customerId = existingSubscription?.stripe_customer_id;

    if (!customerId) {
      // Get billing info
      const { data: billingInfo } = await supabase
        .from("billing_info")
        .select("*")
        .eq("org_id", orgId)
        .maybeSingle();

      const customer = await stripe.customers.create({
        email: billingInfo?.billing_email ?? caller.email ?? "",
        name: billingInfo?.billing_name ?? org.name,
        metadata: {
          org_id: orgId,
          supabase_user_id: caller.id,
        },
        address: billingInfo ? {
          line1: billingInfo.address_line1 ?? "",
          line2: billingInfo.address_line2 ?? "",
          city: billingInfo.city ?? "",
          state: billingInfo.state ?? "",
          postal_code: billingInfo.postal_code ?? "",
          country: billingInfo.country ?? "US",
        } : undefined,
      });
      customerId = customer.id;

      // Update subscription record with customer ID
      if (existingSubscription) {
        await supabase
          .from("subscriptions")
          .update({ stripe_customer_id: customerId })
          .eq("id", existingSubscription.id);
      }
    }

    // Determine price ID
    const priceId = billingCycle === "yearly"
      ? plan?.stripe_price_id_yearly
      : plan?.stripe_price_id_monthly;

    if (!priceId && plan) {
      // Create a checkout session without a specific price (for custom pricing)
      return jsonResponse({
        error: "Stripe price not configured for this plan. Please contact support.",
      }, 400);
    }

    // Create Stripe Checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: priceId ? [
        {
          price: priceId,
          quantity: 1,
        },
      ] : undefined,
      success_url: successUrl || `${supabaseUrl}/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl || `${supabaseUrl}/subscription/cancel`,
      subscription_data: {
        trial_period_days: existingSubscription?.status === "trialing" ? undefined : 14,
        metadata: {
          org_id: orgId,
          plan_id: planId,
        },
      },
      metadata: {
        org_id: orgId,
        plan_id: planId,
      },
    });

    return jsonResponse({
      ok: true,
      url: session.url,
      sessionId: session.id,
    });
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
