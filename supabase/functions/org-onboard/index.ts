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

  const { data: org, error: orgError } = await supabase
    .from("orgs")
    .insert({ name: orgName })
    .select("id,name,created_at")
    .single();
  if (orgError || !org) {
    return jsonResponse({ error: orgError?.message ?? "Org create failed." }, 500);
  }

  const membershipInsert = await supabase.from("org_members").insert({
    org_id: org.id,
    user_id: user.id,
    role: "owner",
  });
  if (membershipInsert.error) {
    return jsonResponse({ error: membershipInsert.error.message }, 500);
  }

  const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
  const firstName = meta.firstName?.toString().trim() ??
    meta.first_name?.toString().trim() ??
    "";
  const lastName = meta.lastName?.toString().trim() ??
    meta.last_name?.toString().trim() ??
    "";
  const phone = meta.phone?.toString().trim() ?? "";

  const now = new Date().toISOString();
  const profilePayload: Record<string, unknown> = {
    id: user.id,
    org_id: org.id,
    email: user.email,
    first_name: firstName || null,
    last_name: lastName || null,
    phone: phone || null,
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

  return jsonResponse({
    ok: true,
    org: {
      id: org.id,
      name: org.name,
      createdAt: org.created_at,
    },
    seededForms: formRows.length,
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

