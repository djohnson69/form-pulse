import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Supported Stripe event types
const SUPPORTED_EVENTS = new Set([
  "checkout.session.completed",
  "charge.refunded",
  "invoice.payment_failed",
  "customer.subscription.deleted",
  "customer.subscription.updated",
]);

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!supabaseUrl || !serviceKey || !webhookSecret) {
    return new Response("Missing Stripe webhook configuration.", {
      status: 500,
    });
  }

  const signatureHeader = req.headers.get("stripe-signature");
  if (!signatureHeader) {
    return new Response("Missing Stripe signature header.", { status: 400 });
  }

  const payload = await req.text();
  const signature = await computeSignature(
    payload,
    signatureHeader,
    webhookSecret,
  );
  if (!signature) {
    return new Response("Signature verification failed.", { status: 400 });
  }

  const event = JSON.parse(payload);
  const eventId = event.id?.toString();
  const eventType = event.type?.toString();

  // Ignore unsupported events early
  if (!SUPPORTED_EVENTS.has(eventType)) {
    console.log(`Stripe webhook: Ignoring unsupported event type: ${eventType}`);
    return new Response(
      JSON.stringify({ received: true, ignored: true, reason: "unsupported_event_type" }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Idempotency check: Skip if we've already processed this event
  if (eventId) {
    const { data: existingEvent } = await supabase
      .from("stripe_webhook_events")
      .select("id")
      .eq("event_id", eventId)
      .maybeSingle();

    if (existingEvent) {
      console.log(`Stripe webhook: Duplicate event ${eventId} skipped`);
      return new Response(
        JSON.stringify({ received: true, duplicate: true }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Record the event before processing to prevent race conditions
    const { error: insertError } = await supabase
      .from("stripe_webhook_events")
      .insert({
        event_id: eventId,
        event_type: eventType,
        metadata: { timestamp: event.created },
      });

    if (insertError) {
      // If insert fails due to unique constraint, another request got there first
      if (insertError.code === "23505") {
        console.log(`Stripe webhook: Concurrent duplicate ${eventId} skipped`);
        return new Response(
          JSON.stringify({ received: true, duplicate: true }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      console.error("Failed to record webhook event:", insertError);
    }
  }

  // Route to appropriate handler based on event type
  const eventData = event.data?.object;

  try {
    switch (eventType) {
      case "checkout.session.completed":
        await handleCheckoutCompleted(supabase, eventData, eventId);
        break;
      case "charge.refunded":
        await handleRefund(supabase, eventData, eventId);
        break;
      case "invoice.payment_failed":
        await handlePaymentFailed(supabase, eventData, eventId);
        break;
      case "customer.subscription.deleted":
        await handleSubscriptionCanceled(supabase, eventData, eventId);
        break;
      case "customer.subscription.updated":
        await handleSubscriptionUpdated(supabase, eventData, eventId);
        break;
      default:
        console.log(`Stripe webhook: No handler for ${eventType}`);
    }

    console.log(`Stripe webhook: Successfully processed ${eventType} (${eventId})`);
    return new Response(
      JSON.stringify({ received: true, processed: true }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error(`Stripe webhook: Error processing ${eventType}:`, err);
    return new Response(
      JSON.stringify({ received: true, error: "Webhook processing failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

// Handler for successful checkout
// deno-lint-ignore no-explicit-any
async function handleCheckoutCompleted(supabase: any, session: any, eventId: string) {
  const sessionId = session?.id?.toString();
  if (!sessionId) {
    console.log("Stripe webhook: checkout.session.completed missing session id");
    return;
  }

  const { data: existing } = await supabase
    .from("payment_requests")
    .select("metadata")
    .eq("metadata->>checkoutSessionId", sessionId)
    .maybeSingle();

  const nextMetadata = {
    ...(existing?.metadata ?? {}),
    stripeEvent: "checkout.session.completed",
    stripeEventId: eventId,
  };

  await supabase
    .from("payment_requests")
    .update({
      status: "paid",
      paid_at: new Date().toISOString(),
      metadata: nextMetadata,
    })
    .eq("metadata->>checkoutSessionId", sessionId);

  console.log(`Stripe webhook: Marked payment as paid for session ${sessionId}`);
}

// Handler for refunds
// deno-lint-ignore no-explicit-any
async function handleRefund(supabase: any, charge: any, eventId: string) {
  const chargeId = charge?.id?.toString();
  const paymentIntentId = charge?.payment_intent?.toString();

  if (!chargeId && !paymentIntentId) {
    console.log("Stripe webhook: charge.refunded missing identifiers");
    return;
  }

  // Try to find the payment by payment intent ID or charge ID
  const searchField = paymentIntentId
    ? "metadata->>stripePaymentIntentId"
    : "metadata->>stripeChargeId";
  const searchValue = paymentIntentId ?? chargeId;

  const { data: existing } = await supabase
    .from("payment_requests")
    .select("id, metadata")
    .eq(searchField, searchValue)
    .maybeSingle();

  if (!existing) {
    // Also try by checkout session ID stored in the charge metadata
    const checkoutSessionId = charge?.metadata?.checkout_session_id;
    if (checkoutSessionId) {
      const { data: bySession } = await supabase
        .from("payment_requests")
        .select("id, metadata")
        .eq("metadata->>checkoutSessionId", checkoutSessionId)
        .maybeSingle();

      if (bySession) {
        await updatePaymentStatus(supabase, bySession, "refunded", eventId, charge);
        return;
      }
    }
    console.log(`Stripe webhook: No payment found for refund ${chargeId}`);
    return;
  }

  await updatePaymentStatus(supabase, existing, "refunded", eventId, charge);
  console.log(`Stripe webhook: Marked payment ${existing.id} as refunded`);
}

// Handler for failed payments
// deno-lint-ignore no-explicit-any
async function handlePaymentFailed(supabase: any, invoice: any, eventId: string) {
  const customerId = invoice?.customer?.toString();
  const subscriptionId = invoice?.subscription?.toString();

  if (!customerId) {
    console.log("Stripe webhook: invoice.payment_failed missing customer");
    return;
  }

  // Update subscription status if we can find it
  if (subscriptionId) {
    // First fetch existing metadata to merge with new data
    const { data: existingSub } = await supabase
      .from("subscriptions")
      .select("metadata")
      .eq("stripe_subscription_id", subscriptionId)
      .maybeSingle();

    const updatedMetadata = {
      ...(existingSub?.metadata ?? {}),
      lastPaymentFailed: new Date().toISOString(),
      stripeEventId: eventId,
    };

    await supabase
      .from("subscriptions")
      .update({
        status: "past_due",
        updated_at: new Date().toISOString(),
        metadata: updatedMetadata,
      })
      .eq("stripe_subscription_id", subscriptionId);
  }

  // Also update by customer ID in billing_info
  const { data: billingInfo } = await supabase
    .from("billing_info")
    .select("org_id")
    .eq("stripe_customer_id", customerId)
    .maybeSingle();

  if (billingInfo?.org_id) {
    await supabase
      .from("subscriptions")
      .update({
        status: "past_due",
        updated_at: new Date().toISOString(),
      })
      .eq("org_id", billingInfo.org_id)
      .eq("status", "active");

    console.log(`Stripe webhook: Marked subscription for org ${billingInfo.org_id} as past_due`);
  }
}

// Handler for subscription cancellation
// deno-lint-ignore no-explicit-any
async function handleSubscriptionCanceled(supabase: any, subscription: any, eventId: string) {
  const subscriptionId = subscription?.id?.toString();
  const customerId = subscription?.customer?.toString();

  if (!subscriptionId && !customerId) {
    console.log("Stripe webhook: subscription.deleted missing identifiers");
    return;
  }

  // Update by Stripe subscription ID
  if (subscriptionId) {
    const { count } = await supabase
      .from("subscriptions")
      .update({
        status: "canceled",
        canceled_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_subscription_id", subscriptionId);

    if (count && count > 0) {
      console.log(`Stripe webhook: Marked subscription ${subscriptionId} as canceled`);
      return;
    }
  }

  // Fallback: find by customer ID
  if (customerId) {
    const { data: billingInfo } = await supabase
      .from("billing_info")
      .select("org_id")
      .eq("stripe_customer_id", customerId)
      .maybeSingle();

    if (billingInfo?.org_id) {
      await supabase
        .from("subscriptions")
        .update({
          status: "canceled",
          canceled_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("org_id", billingInfo.org_id)
        .in("status", ["active", "trialing", "past_due"]);

      console.log(`Stripe webhook: Marked subscription for org ${billingInfo.org_id} as canceled`);
    }
  }
}

// Handler for subscription updates (plan changes, etc.)
// deno-lint-ignore no-explicit-any
async function handleSubscriptionUpdated(supabase: any, subscription: any, _eventId: string) {
  const subscriptionId = subscription?.id?.toString();
  const status = subscription?.status?.toString();

  if (!subscriptionId) {
    console.log("Stripe webhook: subscription.updated missing id");
    return;
  }

  // Map Stripe status to our status
  const statusMap: Record<string, string> = {
    active: "active",
    past_due: "past_due",
    canceled: "canceled",
    unpaid: "past_due",
    trialing: "trialing",
    incomplete: "incomplete",
    incomplete_expired: "expired",
  };

  const mappedStatus = statusMap[status] ?? status;

  await supabase
    .from("subscriptions")
    .update({
      status: mappedStatus,
      current_period_start: subscription.current_period_start
        ? new Date(subscription.current_period_start * 1000).toISOString()
        : undefined,
      current_period_end: subscription.current_period_end
        ? new Date(subscription.current_period_end * 1000).toISOString()
        : undefined,
      updated_at: new Date().toISOString(),
    })
    .eq("stripe_subscription_id", subscriptionId);

  console.log(`Stripe webhook: Updated subscription ${subscriptionId} status to ${mappedStatus}`);
}

// Helper to update payment status
// deno-lint-ignore no-explicit-any
async function updatePaymentStatus(supabase: any, payment: any, status: string, eventId: string, eventData: any) {
  const nextMetadata = {
    ...(payment.metadata ?? {}),
    stripeEvent: `charge.${status}`,
    stripeEventId: eventId,
    refundedAt: status === "refunded" ? new Date().toISOString() : undefined,
    refundAmount: eventData?.amount_refunded,
  };

  await supabase
    .from("payment_requests")
    .update({
      status,
      metadata: nextMetadata,
      updated_at: new Date().toISOString(),
    })
    .eq("id", payment.id);
}

async function computeSignature(
  payload: string,
  signatureHeader: string,
  secret: string,
) {
  const parts = signatureHeader.split(",").reduce((acc, item) => {
    const [key, value] = item.split("=");
    if (key && value) acc[key] = value;
    return acc;
  }, {} as Record<string, string>);
  const timestamp = parts.t;
  const signature = parts.v1;
  if (!timestamp || !signature) return null;

  const signedPayload = `${timestamp}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const rawSignature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedPayload),
  );
  const expected = [...new Uint8Array(rawSignature)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return expected === signature ? signature : null;
}
