import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * org-manage: Edge function for platform roles (Developer, Tech Support) to manage organizations.
 *
 * Actions:
 * - create: Create a new organization (caller does NOT become owner)
 * - update: Update organization fields
 * - delete: Soft delete (sets is_active = false)
 *
 * Required: Valid auth token from a user with profiles.role = 'developer' or 'techsupport'
 */

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(
      { error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing." },
      500,
    );
  }

  // Extract auth token
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7)
    : "";
  if (!token) {
    return jsonResponse({ error: "Missing Authorization bearer token." }, 401);
  }

  // Parse request body
  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch (_) {
    payload = {};
  }

  const action = payload.action?.toString().toLowerCase() ?? "";
  if (!["create", "update", "delete"].includes(action)) {
    return jsonResponse({ error: "Invalid action. Must be 'create', 'update', or 'delete'." }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Verify caller identity
  const { data: userInfo, error: userError } = await supabase.auth.getUser(token);
  const caller = userInfo?.user;
  if (userError || !caller) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  // Check caller's profile role - must be developer or techsupport
  const { data: callerProfile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", caller.id)
    .maybeSingle();

  const callerRole = callerProfile?.role?.toString().toLowerCase().replace(/[_-]/g, "") ?? "";
  const isPlatformRole = callerRole === "developer" || callerRole === "techsupport";

  if (!isPlatformRole) {
    return jsonResponse({ error: "Forbidden. Only developer and techsupport roles can manage organizations." }, 403);
  }

  const now = new Date().toISOString();

  // Handle actions
  if (action === "create") {
    return handleCreate(supabase, payload, now);
  } else if (action === "update") {
    return handleUpdate(supabase, payload, now);
  } else if (action === "delete") {
    return handleDelete(supabase, payload, now);
  }

  return jsonResponse({ error: "Unknown action." }, 400);
});

async function handleCreate(
  supabase: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
  now: string,
) {
  const name = payload.name?.toString().trim() ?? "";
  if (!name) {
    return jsonResponse({ error: "name is required." }, 400);
  }

  // Extract optional fields
  const orgPayload: Record<string, unknown> = {
    name,
    display_name: payload.displayName?.toString().trim() ?? null,
    industry: payload.industry?.toString().trim() ?? null,
    company_size: payload.companySize?.toString().trim() ?? null,
    website: payload.website?.toString().trim() ?? null,
    phone: payload.phone?.toString().trim() ?? null,
    address_line1: payload.addressLine1?.toString().trim() ?? null,
    address_line2: payload.addressLine2?.toString().trim() ?? null,
    city: payload.city?.toString().trim() ?? null,
    state: payload.state?.toString().trim() ?? null,
    postal_code: payload.postalCode?.toString().trim() ?? null,
    country: payload.country?.toString().trim() ?? "US",
    tax_id: payload.taxId?.toString().trim() ?? null,
    is_active: true,
    onboarding_completed: false,
    onboarding_step: 0,
    settings: {},
    metadata: {},
    created_at: now,
    updated_at: now,
  };

  const { data: org, error: orgError } = await supabase
    .from("orgs")
    .insert(orgPayload)
    .select("*")
    .single();

  if (orgError || !org) {
    return jsonResponse({ error: orgError?.message ?? "Failed to create organization." }, 500);
  }

  return jsonResponse({
    ok: true,
    org: {
      id: org.id,
      name: org.name,
      displayName: org.display_name,
      industry: org.industry,
      companySize: org.company_size,
      website: org.website,
      phone: org.phone,
      addressLine1: org.address_line1,
      addressLine2: org.address_line2,
      city: org.city,
      state: org.state,
      postalCode: org.postal_code,
      country: org.country,
      taxId: org.tax_id,
      isActive: org.is_active,
      createdAt: org.created_at,
      updatedAt: org.updated_at,
    },
  });
}

async function handleUpdate(
  supabase: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
  now: string,
) {
  const orgId = payload.orgId?.toString().trim() ?? "";
  if (!orgId) {
    return jsonResponse({ error: "orgId is required." }, 400);
  }

  // Build update payload - only include fields that were provided
  const updatePayload: Record<string, unknown> = {
    updated_at: now,
  };

  if (payload.name !== undefined) {
    const name = payload.name?.toString().trim() ?? "";
    if (!name) {
      return jsonResponse({ error: "name cannot be empty." }, 400);
    }
    updatePayload.name = name;
  }
  if (payload.displayName !== undefined) {
    updatePayload.display_name = payload.displayName?.toString().trim() || null;
  }
  if (payload.industry !== undefined) {
    updatePayload.industry = payload.industry?.toString().trim() || null;
  }
  if (payload.companySize !== undefined) {
    updatePayload.company_size = payload.companySize?.toString().trim() || null;
  }
  if (payload.website !== undefined) {
    updatePayload.website = payload.website?.toString().trim() || null;
  }
  if (payload.phone !== undefined) {
    updatePayload.phone = payload.phone?.toString().trim() || null;
  }
  if (payload.addressLine1 !== undefined) {
    updatePayload.address_line1 = payload.addressLine1?.toString().trim() || null;
  }
  if (payload.addressLine2 !== undefined) {
    updatePayload.address_line2 = payload.addressLine2?.toString().trim() || null;
  }
  if (payload.city !== undefined) {
    updatePayload.city = payload.city?.toString().trim() || null;
  }
  if (payload.state !== undefined) {
    updatePayload.state = payload.state?.toString().trim() || null;
  }
  if (payload.postalCode !== undefined) {
    updatePayload.postal_code = payload.postalCode?.toString().trim() || null;
  }
  if (payload.country !== undefined) {
    updatePayload.country = payload.country?.toString().trim() || null;
  }
  if (payload.taxId !== undefined) {
    updatePayload.tax_id = payload.taxId?.toString().trim() || null;
  }
  if (payload.isActive !== undefined) {
    updatePayload.is_active = payload.isActive === true;
  }

  const { data: org, error: updateError } = await supabase
    .from("orgs")
    .update(updatePayload)
    .eq("id", orgId)
    .select("*")
    .single();

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  if (!org) {
    return jsonResponse({ error: "Organization not found." }, 404);
  }

  return jsonResponse({
    ok: true,
    org: {
      id: org.id,
      name: org.name,
      displayName: org.display_name,
      industry: org.industry,
      companySize: org.company_size,
      website: org.website,
      phone: org.phone,
      addressLine1: org.address_line1,
      addressLine2: org.address_line2,
      city: org.city,
      state: org.state,
      postalCode: org.postal_code,
      country: org.country,
      taxId: org.tax_id,
      isActive: org.is_active,
      createdAt: org.created_at,
      updatedAt: org.updated_at,
    },
  });
}

async function handleDelete(
  supabase: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
  now: string,
) {
  const orgId = payload.orgId?.toString().trim() ?? "";
  if (!orgId) {
    return jsonResponse({ error: "orgId is required." }, 400);
  }

  // Soft delete - set is_active to false
  const { data: org, error: deleteError } = await supabase
    .from("orgs")
    .update({ is_active: false, updated_at: now })
    .eq("id", orgId)
    .select("id, name, is_active")
    .single();

  if (deleteError) {
    return jsonResponse({ error: deleteError.message }, 500);
  }

  if (!org) {
    return jsonResponse({ error: "Organization not found." }, 404);
  }

  return jsonResponse({
    ok: true,
    message: `Organization '${org.name}' has been deactivated.`,
    orgId: org.id,
  });
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
