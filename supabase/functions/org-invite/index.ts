import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ALLOWED_APP_ROLES = new Set([
  "superadmin",
  "admin",
  "manager",
  "supervisor",
  "employee",
  "maintenance",
  "techsupport",
  "client",
  "vendor",
  "viewer",
]);

// Platform-level roles that can only be assigned by developers
const PLATFORM_ONLY_ROLES = new Set(["developer", "techsupport"]);

// Roles that org admins (superadmin, admin) can assign
const ORG_ASSIGNABLE_ROLES = new Set([
  "admin",
  "manager",
  "supervisor",
  "employee",
  "maintenance",
  "client",
  "vendor",
  "viewer",
]);

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

  const email = payload.email?.toString().trim() ?? "";
  if (!email || !email.includes("@")) {
    return jsonResponse({ error: "Valid email is required." }, 400);
  }

  const appRole = normalizeRole(payload.role?.toString());
  if (!appRole) {
    return jsonResponse(
      { error: "role is required (e.g. employee, admin, superadmin)." },
      400,
    );
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: userInfo, error: userError } = await supabase.auth.getUser(
    token,
  );
  const caller = userInfo?.user;
  if (userError || !caller) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  // Get caller's app role first to check for platform-level roles
  const { data: callerProfile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", caller.id)
    .maybeSingle();

  const callerAppRole = callerProfile?.role?.toString().toLowerCase() ?? "";

  // Platform-level roles (developer, techsupport) can operate across orgs
  const isPlatformRole = callerAppRole === "developer" || callerAppRole === "techsupport";

  const { data: membership, error: membershipError } = await supabase
    .from("org_members")
    .select("org_id, role")
    .eq("user_id", caller.id)
    .maybeSingle();

  // For platform roles, they may not have an org_members entry - that's OK
  // They can specify the target orgId in the request payload
  if (!isPlatformRole) {
    if (membershipError || !membership?.org_id) {
      return jsonResponse({ error: "Caller has no organization." }, 400);
    }

    const membershipRole = membership.role?.toString() ?? "member";
    if (membershipRole !== "owner" && membershipRole !== "admin") {
      return jsonResponse({ error: "Forbidden." }, 403);
    }
  }

  // Only developers can assign platform-level roles (developer, techsupport)
  if (callerAppRole !== "developer") {
    if (PLATFORM_ONLY_ROLES.has(appRole)) {
      return jsonResponse(
        { error: "Cannot assign platform-level roles (developer, techSupport). Only developers can do this." },
        403,
      );
    }

    // Prevent creating additional superadmins - each org has one owner
    if (appRole === "superadmin") {
      return jsonResponse(
        { error: "Cannot create additional superAdmins. Each organization has one owner." },
        403,
      );
    }

    // Admins (non-superadmin) cannot assign admin role
    if (callerAppRole === "admin" && appRole === "admin") {
      return jsonResponse(
        { error: "Admins cannot assign the admin role. Only superAdmins can do this." },
        403,
      );
    }
  }

  // Determine target org - platform roles can specify orgId in payload
  let orgId: string | undefined;
  if (isPlatformRole && payload.orgId) {
    orgId = payload.orgId.toString();
  } else {
    orgId = membership?.org_id?.toString();
  }

  if (!orgId) {
    return jsonResponse({ error: isPlatformRole
      ? "Platform roles must specify orgId in the request."
      : "Caller has no organization." }, 400);
  }

  let invitedUserId: string | null = null;
  let inviteSent = false;

  const inviteRes = await supabase.auth.admin.inviteUserByEmail(email, {
    data: {
      firstName: payload.firstName ?? payload.first_name ?? null,
      lastName: payload.lastName ?? payload.last_name ?? null,
    },
  });

  if (inviteRes.error) {
    const existingId = await findAuthUserIdByEmail(supabase, email);
    if (!existingId) {
      return jsonResponse({ error: inviteRes.error.message }, 500);
    }
    invitedUserId = existingId;
  } else {
    invitedUserId = inviteRes.data?.user?.id ?? null;
    inviteSent = true;
  }

  if (!invitedUserId) {
    return jsonResponse({ error: "Unable to resolve user id." }, 500);
  }

  const { data: existingMembership } = await supabase
    .from("org_members")
    .select("org_id, role")
    .eq("user_id", invitedUserId)
    .maybeSingle();

  if (existingMembership?.org_id && existingMembership.org_id !== orgId) {
    return jsonResponse(
      { error: "User already belongs to another organization." },
      409,
    );
  }

  const orgMemberRole = resolveMembershipRole(appRole);
  const membershipUpsert = await supabase.from("org_members").upsert(
    {
      org_id: orgId,
      user_id: invitedUserId,
      role: orgMemberRole,
    },
    { onConflict: "org_id,user_id" },
  );
  if (membershipUpsert.error) {
    return jsonResponse({ error: membershipUpsert.error.message }, 500);
  }

  const firstName = payload.firstName?.toString().trim() ??
    payload.first_name?.toString().trim() ??
    "";
  const lastName = payload.lastName?.toString().trim() ??
    payload.last_name?.toString().trim() ??
    "";
  const phone = payload.phone?.toString().trim() ?? "";
  const now = new Date().toISOString();

  const profileUpsert = await supabase.from("profiles").upsert(
    {
      id: invitedUserId,
      org_id: orgId,
      email,
      first_name: firstName || null,
      last_name: lastName || null,
      phone: phone || null,
      role: appRole,
      updated_at: now,
    },
    { onConflict: "id" },
  );
  if (profileUpsert.error) {
    return jsonResponse({ error: profileUpsert.error.message }, 500);
  }

  return jsonResponse({
    ok: true,
    orgId,
    userId: invitedUserId,
    email,
    role: appRole,
    orgMemberRole,
    inviteSent,
  });
});

function normalizeRole(role: string | undefined | null) {
  if (!role) return null;
  const normalized = role.replaceAll("_", "").replaceAll("-", "").toLowerCase()
    .trim();
  if (!normalized) return null;
  if (!ALLOWED_APP_ROLES.has(normalized)) return null;
  return normalized;
}

function resolveMembershipRole(appRole: string) {
  if (appRole === "superadmin") return "owner";
  if (appRole === "admin") return "admin";
  return "member";
}

async function findAuthUserIdByEmail(
  supabase: ReturnType<typeof createClient>,
  email: string,
) {
  let page = 1;
  const perPage = 200;
  const target = email.toLowerCase();
  while (page <= 10) {
    const res = await supabase.auth.admin.listUsers({ page, perPage });
    if (res.error) return null;
    const users = res.data?.users ?? [];
    for (const user of users) {
      if ((user.email ?? "").toLowerCase() === target) {
        return user.id ?? null;
      }
    }
    if (users.length < perPage) return null;
    page += 1;
  }
  return null;
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
