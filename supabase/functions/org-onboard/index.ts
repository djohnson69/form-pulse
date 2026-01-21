import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const TEMPLATE_FORMS = [
  {
    idSuffix: "jobsite-safety",
    title: "Job Site Safety Walk",
    description: "15-point safety walkthrough with photo capture",
    category: "Safety",
    tags: ["safety", "construction", "audit"],
    version: "1.0.0",
    metadata: { riskLevel: "medium" },
    fields: [
      {
        id: "siteName",
        label: "Site name",
        type: "text",
        placeholder: "South Plant 7",
        isRequired: true,
        order: 1,
      },
      {
        id: "inspector",
        label: "Inspector",
        type: "text",
        placeholder: "Your name",
        isRequired: true,
        order: 2,
      },
      {
        id: "ppe",
        label: "PPE compliance",
        type: "checkbox",
        options: ["Hard hat", "Vest", "Gloves", "Eye protection"],
        isRequired: true,
        order: 3,
      },
      { id: "hazards", label: "Hazards observed", type: "textarea", order: 4 },
      { id: "photos", label: "Attach photos", type: "photo", order: 5 },
      { id: "location", label: "GPS location", type: "location", order: 6 },
      {
        id: "signature",
        label: "Supervisor signature",
        type: "signature",
        order: 7,
      },
    ],
  },
  {
    idSuffix: "equipment-checkout",
    title: "Equipment Checkout",
    description: "Log equipment issue/return with QR scan",
    category: "Operations",
    tags: ["inventory", "logistics", "assets"],
    version: "1.1.0",
    metadata: { requiresSupervisor: true },
    fields: [
      {
        id: "assetTag",
        label: "Asset tag / QR",
        type: "barcode",
        order: 1,
        isRequired: true,
      },
      {
        id: "condition",
        label: "Condition",
        type: "radio",
        options: ["Excellent", "Good", "Fair", "Damaged"],
        order: 2,
        isRequired: true,
      },
      { id: "notes", label: "Notes", type: "textarea", order: 3 },
      {
        id: "photos",
        label: "Proof of condition",
        type: "photo",
        order: 4,
      },
    ],
  },
  {
    idSuffix: "visitor-log",
    title: "Visitor Log",
    description: "Quick intake with badge printing flag",
    category: "Security",
    tags: ["security", "front-desk"],
    version: "0.9.0",
    metadata: {},
    fields: [
      {
        id: "fullName",
        label: "Full name",
        type: "text",
        order: 1,
        isRequired: true,
      },
      { id: "company", label: "Company", type: "text", order: 2 },
      { id: "host", label: "Host", type: "text", order: 3 },
      {
        id: "purpose",
        label: "Purpose",
        type: "dropdown",
        options: ["Delivery", "Interview", "Maintenance", "Audit", "Other"],
        order: 4,
      },
      { id: "arrivedAt", label: "Arrival time", type: "datetime", order: 5 },
      { id: "badge", label: "Badge required", type: "toggle", order: 6 },
    ],
  },
];

// Default trial period in days
const TRIAL_DAYS = 14;

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
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(
      { error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing." },
      500,
    );
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

  const orgName = payload.orgName?.toString().trim() ??
    payload.name?.toString().trim() ??
    "";
  if (!orgName) {
    return jsonResponse({ error: "orgName is required." }, 400);
  }

  // Enhanced organization fields
  const displayName = payload.displayName?.toString().trim() ?? null;
  const industry = payload.industry?.toString().trim() ?? null;
  const companySize = payload.companySize?.toString().trim() ?? null;
  const website = payload.website?.toString().trim() ?? null;
  const phone = payload.phone?.toString().trim() ?? null;
  const addressLine1 = payload.addressLine1?.toString().trim() ?? null;
  const addressLine2 = payload.addressLine2?.toString().trim() ?? null;
  const city = payload.city?.toString().trim() ?? null;
  const state = payload.state?.toString().trim() ?? null;
  const postalCode = payload.postalCode?.toString().trim() ?? null;
  const country = payload.country?.toString().trim() ?? "US";
  const taxId = payload.taxId?.toString().trim() ?? null;

  // Subscription fields
  const planName = payload.planName?.toString().trim() ?? "pro";
  const billingCycle = payload.billingCycle?.toString().trim() ?? "monthly";

  // Billing info fields
  const billingEmail = payload.billingEmail?.toString().trim() ?? null;
  const billingName = payload.billingName?.toString().trim() ?? null;
  const billingAddressLine1 = payload.billingAddressLine1?.toString().trim() ?? null;
  const billingAddressLine2 = payload.billingAddressLine2?.toString().trim() ?? null;
  const billingCity = payload.billingCity?.toString().trim() ?? null;
  const billingState = payload.billingState?.toString().trim() ?? null;
  const billingPostalCode = payload.billingPostalCode?.toString().trim() ?? null;
  const billingCountry = payload.billingCountry?.toString().trim() ?? "US";
  const billingTaxId = payload.billingTaxId?.toString().trim() ?? null;
  const poRequired = payload.poRequired === true;

  // Stripe payment info (from signup flow)
  const stripeCustomerId = payload.stripeCustomerId?.toString().trim() ?? null;
  const stripePaymentMethodId = payload.stripePaymentMethodId?.toString().trim() ?? null;

  // Team invites
  const teamInvites = Array.isArray(payload.teamInvites) ? payload.teamInvites : [];

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: userInfo, error: userError } = await supabase.auth.getUser(
    token,
  );
  const user = userInfo?.user;
  if (userError || !user) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  // Check if user already has an org
  const { data: existingMembership } = await supabase
    .from("org_members")
    .select("org_id, role")
    .eq("user_id", user.id)
    .maybeSingle();
  if (existingMembership?.org_id) {
    return jsonResponse({
      ok: true,
      orgId: existingMembership.org_id,
      membershipRole: existingMembership.role ?? "member",
      alreadyInitialized: true,
    });
  }

  const now = new Date().toISOString();

  // Create organization with enhanced fields
  const orgPayload: Record<string, unknown> = {
    name: orgName,
    display_name: displayName,
    industry,
    company_size: companySize,
    website,
    phone,
    address_line1: addressLine1,
    address_line2: addressLine2,
    city,
    state,
    postal_code: postalCode,
    country,
    tax_id: taxId,
    onboarding_completed: true,
    onboarding_step: 6, // All steps completed
    settings: {},
    metadata: {},
    updated_at: now,
  };

  const { data: org, error: orgError } = await supabase
    .from("orgs")
    .insert(orgPayload)
    .select("id,name,created_at")
    .single();
  if (orgError || !org) {
    return jsonResponse({ error: orgError?.message ?? "Org create failed." }, 500);
  }

  // Create membership for the org creator as owner
  const membershipInsert = await supabase.from("org_members").insert({
    org_id: org.id,
    user_id: user.id,
    role: "owner",
  });
  if (membershipInsert.error) {
    return jsonResponse({ error: membershipInsert.error.message }, 500);
  }

  // Create profile for the user
  const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
  const firstName = meta.firstName?.toString().trim() ??
    meta.first_name?.toString().trim() ??
    "";
  const lastName = meta.lastName?.toString().trim() ??
    meta.last_name?.toString().trim() ??
    "";
  const userPhone = meta.phone?.toString().trim() ?? "";

  const profilePayload: Record<string, unknown> = {
    id: user.id,
    org_id: org.id,
    email: user.email,
    first_name: firstName || null,
    last_name: lastName || null,
    phone: userPhone || null,
    role: "superadmin",
    updated_at: now,
  };

  const profileUpsert = await supabase.from("profiles").upsert(
    profilePayload,
    { onConflict: "id" },
  );
  if (profileUpsert.error) {
    return jsonResponse({ error: profileUpsert.error.message }, 500);
  }

  // Get the selected plan
  const { data: plan, error: planError } = await supabase
    .from("subscription_plans")
    .select("*")
    .eq("name", planName)
    .eq("is_active", true)
    .maybeSingle();

  // Create subscription with trial
  const trialStart = new Date();
  const trialEnd = new Date(trialStart.getTime() + TRIAL_DAYS * 24 * 60 * 60 * 1000);

  const subscriptionPayload: Record<string, unknown> = {
    org_id: org.id,
    plan_id: plan?.id ?? null,
    status: "trialing",
    billing_cycle: billingCycle,
    trial_start: trialStart.toISOString(),
    trial_end: trialEnd.toISOString(),
    current_period_start: trialStart.toISOString(),
    current_period_end: trialEnd.toISOString(),
    created_at: now,
    updated_at: now,
  };

  const subscriptionInsert = await supabase.from("subscriptions").insert(subscriptionPayload);
  if (subscriptionInsert.error) {
    console.error("Subscription insert error:", subscriptionInsert.error);
    // Non-fatal - continue without subscription if table doesn't exist
  }

  // Create billing info if email provided
  if (billingEmail) {
    const billingInfoPayload: Record<string, unknown> = {
      org_id: org.id,
      billing_email: billingEmail,
      billing_name: billingName ?? orgName,
      address_line1: billingAddressLine1 ?? addressLine1,
      address_line2: billingAddressLine2 ?? addressLine2,
      city: billingCity ?? city,
      state: billingState ?? state,
      postal_code: billingPostalCode ?? postalCode,
      country: billingCountry,
      tax_id: billingTaxId ?? taxId,
      po_required: poRequired,
      // Stripe payment method info (collected during signup)
      stripe_customer_id: stripeCustomerId,
      stripe_payment_method_id: stripePaymentMethodId,
      created_at: now,
      updated_at: now,
    };

    const billingInfoInsert = await supabase.from("billing_info").insert(billingInfoPayload);
    if (billingInfoInsert.error) {
      console.error("Billing info insert error:", billingInfoInsert.error);
      // Non-fatal - continue without billing info if table doesn't exist
    }
  }

  // Create template forms
  const formRows = TEMPLATE_FORMS.map((form) => ({
    id: `${org.id}-${form.idSuffix}`,
    org_id: org.id,
    title: form.title,
    description: form.description,
    category: form.category,
    tags: form.tags,
    fields: form.fields,
    metadata: form.metadata,
    is_published: true,
    version: form.version,
    created_by: "system",
    created_at: now,
    updated_at: now,
  }));

  const formsInsert = await supabase.from("forms").insert(formRows);
  if (formsInsert.error) {
    return jsonResponse({ error: formsInsert.error.message }, 500);
  }

  // Process team invitations
  const invitationResults: Array<{ email: string; success: boolean; error?: string }> = [];

  for (const invite of teamInvites) {
    const email = invite.email?.toString().trim();
    const role = invite.role?.toString().trim() ?? "employee";

    if (!email || !email.includes("@")) continue;

    try {
      // Invite user via Supabase Auth
      const inviteRes = await supabase.auth.admin.inviteUserByEmail(email, {
        data: {
          org_id: org.id,
          role,
        },
      });

      if (inviteRes.error) {
        invitationResults.push({ email, success: false, error: inviteRes.error.message });
        continue;
      }

      const invitedUserId = inviteRes.data?.user?.id;
      if (!invitedUserId) {
        invitationResults.push({ email, success: false, error: "No user ID returned" });
        continue;
      }

      // Create org membership for invited user
      const memberRole = role === "admin" ? "admin" : "member";
      await supabase.from("org_members").upsert(
        {
          org_id: org.id,
          user_id: invitedUserId,
          role: memberRole,
        },
        { onConflict: "org_id,user_id" },
      );

      // Create profile for invited user
      await supabase.from("profiles").upsert(
        {
          id: invitedUserId,
          org_id: org.id,
          email,
          role,
          updated_at: now,
        },
        { onConflict: "id" },
      );

      // Record invitation
      await supabase.from("user_invitations").insert({
        org_id: org.id,
        email,
        role,
        invited_by: user.id,
        invited_at: now,
        status: "pending",
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      });

      invitationResults.push({ email, success: true });
    } catch (err) {
      invitationResults.push({ email, success: false, error: String(err) });
    }
  }

  return jsonResponse({
    ok: true,
    org: {
      id: org.id,
      name: org.name,
      createdAt: org.created_at,
    },
    subscription: {
      status: "trialing",
      plan: planName,
      trialEnd: trialEnd.toISOString(),
    },
    seededForms: formRows.length,
    invitations: invitationResults,
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
