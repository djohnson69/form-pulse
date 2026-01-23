/**
 * CORS Configuration Shared Module
 *
 * Provides secure CORS headers for Supabase Edge Functions.
 * Restricts allowed origins to known production and development domains.
 *
 * Usage:
 *   import { getCorsHeaders, corsResponse } from "../_shared/cors.ts";
 *
 *   // In OPTIONS handler:
 *   return corsResponse(req);
 *
 *   // In other handlers:
 *   const corsHeaders = getCorsHeaders(req);
 *   return new Response(body, { headers: { ...corsHeaders, ... } });
 */

/**
 * List of allowed origins for CORS.
 * Add production and staging domains here.
 */
const ALLOWED_ORIGINS: string[] = [
  // Production domains
  "https://formpulse.app",
  "https://app.formpulse.app",
  "https://www.formpulse.app",
  // Allow custom domain from environment (for staging/preview)
  Deno.env.get("ALLOWED_ORIGIN") ?? "",
  // Local development
  "http://localhost:3000",
  "http://localhost:5173",
  "http://127.0.0.1:3000",
  "http://127.0.0.1:5173",
].filter((origin) => origin.length > 0);

/**
 * Default allowed headers for CORS requests.
 */
const ALLOWED_HEADERS = [
  "authorization",
  "x-client-info",
  "apikey",
  "content-type",
  "x-request-id",
].join(", ");

/**
 * Default allowed methods for CORS requests.
 */
const ALLOWED_METHODS = "GET, POST, PUT, DELETE, OPTIONS";

/**
 * Check if an origin is allowed.
 *
 * @param origin - The origin header from the request
 * @returns true if the origin is in the allowed list
 */
export function isOriginAllowed(origin: string | null): boolean {
  if (!origin) return false;
  return ALLOWED_ORIGINS.includes(origin);
}

/**
 * Get CORS headers for a request.
 * Returns headers with the appropriate Access-Control-Allow-Origin.
 *
 * @param req - The incoming request (used to extract Origin header)
 * @returns Headers object with CORS configuration
 */
export function getCorsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("origin");

  // If origin is allowed, echo it back (supports credentials)
  // Otherwise, use first allowed origin (requests will fail CORS check)
  const allowedOrigin = origin && isOriginAllowed(origin)
    ? origin
    : ALLOWED_ORIGINS[0] ?? "";

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": ALLOWED_HEADERS,
    "Access-Control-Allow-Methods": ALLOWED_METHODS,
    "Access-Control-Max-Age": "86400", // 24 hours preflight cache
  };
}

/**
 * Create a CORS preflight response (for OPTIONS requests).
 *
 * @param req - The incoming OPTIONS request
 * @returns Response with 204 No Content and CORS headers
 */
export function corsResponse(req: Request): Response {
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(req),
  });
}

/**
 * Create an error response with CORS headers.
 *
 * @param req - The incoming request
 * @param message - Error message to return
 * @param status - HTTP status code (default 400)
 * @returns Response with error JSON and CORS headers
 */
export function corsErrorResponse(
  req: Request,
  message: string,
  status = 400,
): Response {
  return new Response(
    JSON.stringify({ error: message }),
    {
      status,
      headers: {
        ...getCorsHeaders(req),
        "Content-Type": "application/json",
      },
    },
  );
}

/**
 * Create a JSON response with CORS headers.
 *
 * @param req - The incoming request
 * @param data - Data to serialize as JSON
 * @param status - HTTP status code (default 200)
 * @returns Response with JSON body and CORS headers
 */
export function corsJsonResponse(
  req: Request,
  data: unknown,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...getCorsHeaders(req),
        "Content-Type": "application/json",
      },
    },
  );
}
