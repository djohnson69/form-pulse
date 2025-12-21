import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
  if (event.type !== "checkout.session.completed") {
    return new Response("Event ignored.", { status: 200 });
  }

  const session = event.data?.object;
  const sessionId = session?.id?.toString();
  if (!sessionId) {
    return new Response("Missing session id.", { status: 400 });
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: existing } = await supabase
    .from("payment_requests")
    .select("metadata")
    .eq("metadata->>checkoutSessionId", sessionId)
    .maybeSingle();

  const nextMetadata = {
    ...(existing?.metadata ?? {}),
    stripeEvent: event.type,
    stripeEventId: event.id?.toString(),
  };

  await supabase
    .from("payment_requests")
    .update({
      status: "paid",
      paid_at: new Date().toISOString(),
      metadata: nextMetadata,
    })
    .eq("metadata->>checkoutSessionId", sessionId);

  return new Response("ok", { status: 200 });
});

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
