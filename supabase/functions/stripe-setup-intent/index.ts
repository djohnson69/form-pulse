import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";
import {
  checkRateLimit,
  rateLimitKey,
  rateLimitResponse,
} from "../_shared/rate_limiter.ts";
import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";

/**
 * Creates a Stripe SetupIntent for collecting payment method during signup.
 * This allows collecting and validating a credit card without charging immediately.
 * The payment method will be used for automatic billing after the trial period.
 */
serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return corsResponse(req);
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!stripeSecretKey) {
    return jsonResponse({ error: "Missing Stripe configuration." }, 500);
  }
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing." }, 500);
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch (_) {
    payload = {};
  }

  const email = payload.email?.toString() ?? "";
  const companyName = payload.companyName?.toString() ?? "";
  const billingName = payload.billingName?.toString();
  const billingAddress = payload.billingAddress as Record<string, string> | undefined;

  if (!email) {
    return jsonResponse({ error: "Email is required." }, 400);
  }

  // Rate limiting by email: 5 setup intents per minute per email
  // This prevents enumeration and abuse during signup
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const rateLimitResult = await checkRateLimit(
    supabase,
    rateLimitKey("stripe-setup-intent", email.toLowerCase()),
    5,  // max requests
    60, // window in seconds
  );
  if (!rateLimitResult.allowed) {
    return rateLimitResponse(rateLimitResult, corsHeaders);
  }

  const stripe = new Stripe(stripeSecretKey, {
    apiVersion: "2023-10-16",
    httpClient: Stripe.createFetchHttpClient(),
  });

  try {
    // Create a new Stripe customer for this signup
    const customerData: Stripe.CustomerCreateParams = {
      email: email,
      name: billingName ?? companyName,
      metadata: {
        pending_signup: "true",
        company_name: companyName,
      },
    };

    // Add billing address if provided
    if (billingAddress) {
      customerData.address = {
        line1: billingAddress.line1 ?? "",
        line2: billingAddress.line2 ?? "",
        city: billingAddress.city ?? "",
        state: billingAddress.state ?? "",
        postal_code: billingAddress.postalCode ?? "",
        country: billingAddress.country ?? "US",
      };
    }

    const customer = await stripe.customers.create(customerData);

    // Create a SetupIntent to collect and save the payment method
    const setupIntent = await stripe.setupIntents.create({
      customer: customer.id,
      payment_method_types: ["card"],
      usage: "off_session", // Allow charging the card later without customer present
      metadata: {
        pending_signup: "true",
        company_name: companyName,
      },
    });

    return jsonResponse({
      ok: true,
      clientSecret: setupIntent.client_secret,
      customerId: customer.id,
      setupIntentId: setupIntent.id,
    });
  } catch (error: unknown) {
    console.error("Stripe error:", error);
    const errorMessage = error instanceof Error ? error.message : "Failed to create setup intent.";
    return jsonResponse(
      { error: errorMessage },
      500
    );
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
