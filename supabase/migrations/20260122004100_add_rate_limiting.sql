-- Migration: Add rate limiting infrastructure
-- Provides database-backed rate limiting for Edge Functions

-- Rate limits table for tracking request counts
CREATE TABLE IF NOT EXISTS rate_limits (
  key text PRIMARY KEY,
  count int NOT NULL DEFAULT 1,
  window_start timestamptz NOT NULL DEFAULT NOW()
);

-- Index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_start ON rate_limits(window_start);

-- Function to check and update rate limit atomically
-- Uses a sliding window approach
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_key text,
  p_max_requests int,
  p_window_seconds int
) RETURNS jsonb AS $$
DECLARE
  v_now timestamptz;
  v_window_start timestamptz;
  v_count int;
  v_allowed boolean;
  v_remaining int;
  v_reset_at timestamptz;
BEGIN
  v_now := NOW();
  v_window_start := v_now - (p_window_seconds || ' seconds')::interval;

  -- Try to get existing record within the window
  SELECT count, window_start INTO v_count, v_reset_at
  FROM rate_limits
  WHERE key = p_key AND window_start > v_window_start
  FOR UPDATE;

  IF FOUND THEN
    -- Record exists and is within window
    IF v_count >= p_max_requests THEN
      -- Rate limit exceeded
      v_allowed := false;
      v_remaining := 0;
      v_reset_at := v_reset_at + (p_window_seconds || ' seconds')::interval;
    ELSE
      -- Increment counter
      UPDATE rate_limits
      SET count = count + 1
      WHERE key = p_key;

      v_count := v_count + 1;
      v_allowed := true;
      v_remaining := GREATEST(0, p_max_requests - v_count);
      v_reset_at := v_reset_at + (p_window_seconds || ' seconds')::interval;
    END IF;
  ELSE
    -- No record or expired - create/reset
    INSERT INTO rate_limits (key, count, window_start)
    VALUES (p_key, 1, v_now)
    ON CONFLICT (key) DO UPDATE SET
      count = 1,
      window_start = v_now;

    v_allowed := true;
    v_remaining := p_max_requests - 1;
    v_reset_at := v_now + (p_window_seconds || ' seconds')::interval;
  END IF;

  RETURN jsonb_build_object(
    'allowed', v_allowed,
    'remaining', v_remaining,
    'reset_at', v_reset_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to service role (Edge Functions use service role)
GRANT EXECUTE ON FUNCTION check_rate_limit(text, int, int) TO service_role;

-- Cleanup function to remove expired rate limit entries
-- Should be called periodically (e.g., daily via pg_cron)
CREATE OR REPLACE FUNCTION cleanup_rate_limits(p_older_than_hours int DEFAULT 24)
RETURNS int AS $$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM rate_limits
  WHERE window_start < NOW() - (p_older_than_hours || ' hours')::interval;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute for cleanup
GRANT EXECUTE ON FUNCTION cleanup_rate_limits(int) TO service_role;

-- RLS: rate_limits table should only be accessible via RPC functions
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

-- No direct access policies - all access through SECURITY DEFINER functions
-- This prevents users from viewing or manipulating rate limits directly
