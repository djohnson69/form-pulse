import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Creates a Stripe SetupIntent for collecting payment method during signup.
 * This allows collecting and validating a credit card without charging immediately.
 * The payment method will be used for automatic billing after the trial period.
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!stripeSecretKey) {
    return jsonResponse({ error: "Missing Stripe configuration." }, 500);
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
  } catch (error) {
    console.error("Stripe error:", error);
    return jsonResponse(
      { error: error.message ?? "Failed to create setup intent." },
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
