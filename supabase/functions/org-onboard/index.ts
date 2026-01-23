import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  checkRateLimit,
  rateLimitKey,
  rateLimitResponse,
} from "../_shared/rate_limiter.ts";
import { getCorsHeaders } from "../_shared/cors.ts";

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

// Timeout for individual team invite operations (5 seconds)
const INVITE_TIMEOUT_MS = 5000;

// Internal roles get employee records (for Org Chart, HR, Training)
// External roles (client, vendor, viewer) do NOT get employee records
const INTERNAL_ROLES = new Set([
  "superadmin",
  "admin",
  "manager",
  "supervisor",
  "employee",
  "maintenance",
  "techsupport",
]);

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
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

  // Rate limiting: 5 org creations per hour per user
  const rateLimitResult = await checkRateLimit(
    supabase,
    rateLimitKey("org-onboard", user.id),
    5,    // max requests
    3600, // window in seconds (1 hour)
  );
  if (!rateLimitResult.allowed) {
    return rateLimitResponse(rateLimitResult, corsHeaders);
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

  // Extract user metadata for profile
  const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
  const firstName = meta.firstName?.toString().trim() ??
    meta.first_name?.toString().trim() ??
    "";
  const lastName = meta.lastName?.toString().trim() ??
    meta.last_name?.toString().trim() ??
    "";
  const userPhone = meta.phone?.toString().trim() ?? "";

  // Use transactional RPC to create org, membership, profile, employee, and subscription atomically
  // This prevents orphaned data if any step fails
  const { data: txResult, error: txError } = await supabase.rpc("create_org_with_owner", {
    p_org_name: orgName,
    p_display_name: displayName,
    p_industry: industry,
    p_company_size: companySize,
    p_website: website,
    p_phone: phone,
    p_address_line1: addressLine1,
    p_address_line2: addressLine2,
    p_city: city,
    p_state: state,
    p_postal_code: postalCode,
    p_country: country,
    p_tax_id: taxId,
    p_user_id: user.id,
    p_user_email: user.email ?? "",
    p_first_name: firstName,
    p_last_name: lastName,
    p_user_phone: userPhone,
    p_plan_name: planName,
    p_billing_cycle: billingCycle,
    p_trial_days: TRIAL_DAYS,
  });

  if (txError || !txResult?.success) {
    const errorMsg = txError?.message ?? txResult?.error ?? "Org creation transaction failed.";
    console.error("Org creation transaction error:", errorMsg);
    return jsonResponse({ error: errorMsg }, 500);
  }

  const orgId = txResult.org_id as string;
  const trialEnd = new Date(txResult.trial_end as string);

  // Org object for response (minimal info needed)
  const org = {
    id: orgId,
    name: orgName,
    created_at: now,
  };

  // Create billing info if email provided (non-critical, uses separate RPC)
  if (billingEmail) {
    const { data: billingResult, error: billingError } = await supabase.rpc("add_org_billing_info", {
      p_org_id: orgId,
      p_billing_email: billingEmail,
      p_billing_name: billingName ?? orgName,
      p_address_line1: billingAddressLine1 ?? addressLine1,
      p_address_line2: billingAddressLine2 ?? addressLine2,
      p_city: billingCity ?? city,
      p_state: billingState ?? state,
      p_postal_code: billingPostalCode ?? postalCode,
      p_country: billingCountry,
      p_tax_id: billingTaxId ?? taxId,
      p_po_required: poRequired,
      p_stripe_customer_id: stripeCustomerId,
      p_stripe_payment_method_id: stripePaymentMethodId,
    });
    if (billingError || !billingResult?.success) {
      console.error("Billing info insert error:", billingError?.message ?? billingResult?.error);
      // Non-fatal - continue without billing info
    }
  }

  // Create template forms
  const formRows = TEMPLATE_FORMS.map((form) => ({
    id: `${orgId}-${form.idSuffix}`,
    org_id: orgId,
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

  // Process team invitations with timeout protection
  const invitationResults: Array<{ email: string; success: boolean; error?: string }> = [];

  // Helper function to process a single invite with all its DB operations
  async function processInvite(email: string, role: string): Promise<void> {
    // Invite user via Supabase Auth
    const inviteRes = await supabase.auth.admin.inviteUserByEmail(email, {
      data: {
        org_id: orgId,
        role,
      },
    });

    if (inviteRes.error) {
      throw new Error(inviteRes.error.message);
    }

    const invitedUserId = inviteRes.data?.user?.id;
    if (!invitedUserId) {
      throw new Error("No user ID returned");
    }

    // Create org membership for invited user
    const memberRole = role === "admin" ? "admin" : "member";
    await supabase.from("org_members").upsert(
      {
        org_id: orgId,
        user_id: invitedUserId,
        role: memberRole,
      },
      { onConflict: "org_id,user_id" },
    );

    // Create profile for invited user
    await supabase.from("profiles").upsert(
      {
        id: invitedUserId,
        org_id: orgId,
        email,
        role,
        updated_at: now,
      },
      { onConflict: "id" },
    );

    // Record invitation
    await supabase.from("user_invitations").insert({
      org_id: orgId,
      email,
      role,
      invited_by: user!.id,
      invited_at: now,
      status: "pending",
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    });

    // Create employee record for internal roles only
    // External roles (client, vendor, viewer) don't appear in Org Chart
    if (INTERNAL_ROLES.has(role)) {
      await supabase.from("employees").upsert(
        {
          org_id: orgId,
          user_id: invitedUserId,
          first_name: null,
          last_name: null,
          email,
          position: mapRoleToPosition(role),
          department: mapRoleToDepartment(role),
          hire_date: now,
          is_active: true,
          metadata: {
            role,
            invitedBy: user!.id,
            isSupervisor: ["superadmin", "admin", "manager", "supervisor"].includes(role),
            isManager: ["superadmin", "admin", "manager"].includes(role),
          },
        },
        { onConflict: "org_id,user_id" },
      );
    }
  }

  for (const invite of teamInvites) {
    const email = invite.email?.toString().trim();
    const role = invite.role?.toString().trim() ?? "employee";

    if (!email || !email.includes("@")) continue;

    try {
      // Use Promise.race to enforce timeout on each invite
      await Promise.race([
        processInvite(email, role),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("Invite timeout")), INVITE_TIMEOUT_MS)
        ),
      ]);
      invitationResults.push({ email, success: true });
    } catch (err) {
      invitationResults.push({ email, success: false, error: String(err) });
    }
  }

  return jsonResponse({
    ok: true,
    org: {
      id: orgId,
      name: orgName,
      createdAt: now,
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

// Map app role to default position for employee record
function mapRoleToPosition(role: string): string {
  const positionMap: Record<string, string> = {
    superadmin: "Owner / Executive",
    admin: "Administrator",
    manager: "Manager",
    supervisor: "Supervisor",
    employee: "Team Member",
    maintenance: "Maintenance Technician",
    techsupport: "Technical Support",
  };
  return positionMap[role] || "Team Member";
}

// Map app role to default department for employee record
function mapRoleToDepartment(role: string): string {
  const deptMap: Record<string, string> = {
    superadmin: "Executive",
    admin: "Administration",
    manager: "Management",
    supervisor: "Operations",
    employee: "Operations",
    maintenance: "Maintenance",
    techsupport: "IT Support",
  };
  return deptMap[role] || "General";
}
