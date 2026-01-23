/**
 * Rate Limiter Shared Module
 *
 * Provides rate limiting for Supabase Edge Functions using a database-backed
 * sliding window approach. This ensures consistent rate limiting across
 * distributed function invocations.
 *
 * Usage:
 *   import { checkRateLimit, RateLimitResult } from "../_shared/rate_limiter.ts";
 *
 *   const result = await checkRateLimit(supabase, `org-invite:${userId}`, 10, 60);
 *   if (!result.allowed) {
 *     return new Response("Rate limit exceeded", { status: 429 });
 *   }
 */

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: string | null;
}

/**
 * Check if a request is allowed under the rate limit.
 *
 * @param supabase - Supabase client instance (with service role)
 * @param key - Unique identifier for the rate limit bucket (e.g., "org-invite:{userId}")
 * @param maxRequests - Maximum number of requests allowed in the window
 * @param windowSeconds - Duration of the sliding window in seconds
 * @returns RateLimitResult with allowed status and remaining count
 */
// deno-lint-ignore no-explicit-any
export async function checkRateLimit(
  supabase: any,
  key: string,
  maxRequests: number,
  windowSeconds: number,
): Promise<RateLimitResult> {
  try {
    const { data, error } = await supabase.rpc("check_rate_limit", {
      p_key: key,
      p_max_requests: maxRequests,
      p_window_seconds: windowSeconds,
    });

    if (error) {
      console.error("Rate limit check error:", error);
      // On error, default to allowing (fail open for availability)
      return { allowed: true, remaining: maxRequests, resetAt: null };
    }

    return {
      allowed: data?.allowed ?? true,
      remaining: data?.remaining ?? 0,
      resetAt: data?.reset_at ?? null,
    };
  } catch (err) {
    console.error("Rate limit exception:", err);
    // Fail open on unexpected errors
    return { allowed: true, remaining: maxRequests, resetAt: null };
  }
}

/**
 * Generate a standardized rate limit key.
 *
 * @param action - The action being rate limited (e.g., "org-invite", "org-onboard")
 * @param identifier - Unique identifier (userId, IP, etc.)
 * @returns Formatted rate limit key
 */
export function rateLimitKey(action: string, identifier: string): string {
  return `${action}:${identifier}`;
}

/**
 * Create rate limit exceeded response with appropriate headers.
 *
 * @param result - RateLimitResult from checkRateLimit
 * @param corsHeaders - CORS headers to include
 * @returns Response with 429 status
 */
export function rateLimitResponse(
  result: RateLimitResult,
  corsHeaders: Record<string, string> = {},
): Response {
  const headers: Record<string, string> = {
    ...corsHeaders,
    "Content-Type": "application/json",
    "X-RateLimit-Remaining": String(result.remaining),
  };

  if (result.resetAt) {
    headers["X-RateLimit-Reset"] = result.resetAt;
    // Calculate Retry-After in seconds
    const resetTime = new Date(result.resetAt).getTime();
    const now = Date.now();
    const retryAfter = Math.max(1, Math.ceil((resetTime - now) / 1000));
    headers["Retry-After"] = String(retryAfter);
  }

  return new Response(
    JSON.stringify({
      error: "Rate limit exceeded. Please try again later.",
      remaining: result.remaining,
      resetAt: result.resetAt,
    }),
    {
      status: 429,
      headers,
    },
  );
}

/**
 * Default rate limits for different actions.
 * These can be overridden when calling checkRateLimit.
 */
export const DEFAULT_RATE_LIMITS: Record<string, { maxRequests: number; windowSeconds: number }> = {
  "org-invite": { maxRequests: 10, windowSeconds: 60 },      // 10 invites per minute
  "org-onboard": { maxRequests: 5, windowSeconds: 3600 },    // 5 orgs per hour
  "org-manage": { maxRequests: 20, windowSeconds: 60 },      // 20 operations per minute
  "payments": { maxRequests: 20, windowSeconds: 60 },        // 20 payment ops per minute
  "stripe-webhook": { maxRequests: 100, windowSeconds: 60 }, // 100 webhooks per minute
  "default": { maxRequests: 60, windowSeconds: 60 },         // 60 requests per minute
};

/**
 * Get default rate limit for an action.
 */
export function getDefaultRateLimit(action: string): { maxRequests: number; windowSeconds: number } {
  return DEFAULT_RATE_LIMITS[action] ?? DEFAULT_RATE_LIMITS["default"];
}
