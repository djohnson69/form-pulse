-- Migration: Add platform tables for Developer/TechSupport features
-- Created: 2026-01-19

-- Support tickets table
CREATE TABLE IF NOT EXISTS support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid REFERENCES orgs(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'open',
  priority text NOT NULL DEFAULT 'medium',
  category text,
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Impersonation log for tracking user emulation sessions
CREATE TABLE IF NOT EXISTS impersonation_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emulator_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emulated_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  reason text,
  actions_taken jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Active sessions tracking (supplements auth.sessions)
CREATE TABLE IF NOT EXISTS active_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id uuid REFERENCES orgs(id) ON DELETE SET NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  current_route text,
  device_info text,
  ip_address text,
  user_agent text,
  is_active boolean NOT NULL DEFAULT true,
  ended_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Error tracking table
CREATE TABLE IF NOT EXISTS error_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid REFERENCES orgs(id) ON DELETE SET NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  error_type text NOT NULL,
  error_message text NOT NULL,
  stack_trace text,
  severity text NOT NULL DEFAULT 'error',
  route text,
  device_info text,
  user_agent text,
  is_resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  occurrence_count int NOT NULL DEFAULT 1,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- API metrics table (for tracking endpoint performance)
CREATE TABLE IF NOT EXISTS api_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint text NOT NULL,
  method text NOT NULL DEFAULT 'GET',
  status_code int,
  latency_ms int NOT NULL,
  request_size_bytes int,
  response_size_bytes int,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  org_id uuid REFERENCES orgs(id) ON DELETE SET NULL,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- API metrics aggregates (for faster dashboard queries)
CREATE TABLE IF NOT EXISTS api_metrics_hourly (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hour_timestamp timestamptz NOT NULL,
  endpoint text NOT NULL,
  method text NOT NULL DEFAULT 'GET',
  total_requests int NOT NULL DEFAULT 0,
  successful_requests int NOT NULL DEFAULT 0,
  failed_requests int NOT NULL DEFAULT 0,
  avg_latency_ms numeric NOT NULL DEFAULT 0,
  p50_latency_ms numeric,
  p95_latency_ms numeric,
  p99_latency_ms numeric,
  total_request_bytes bigint NOT NULL DEFAULT 0,
  total_response_bytes bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hour_timestamp, endpoint, method)
);

-- Enable RLS
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE impersonation_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_metrics_hourly ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_support_tickets_org ON support_tickets(org_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created ON support_tickets(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_impersonation_log_emulator ON impersonation_log(emulator_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_log_emulated ON impersonation_log(emulated_user_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_log_started ON impersonation_log(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_active_sessions_user ON active_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_active_sessions_org ON active_sessions(org_id);
CREATE INDEX IF NOT EXISTS idx_active_sessions_active ON active_sessions(is_active) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_error_events_org ON error_events(org_id);
CREATE INDEX IF NOT EXISTS idx_error_events_type ON error_events(error_type);
CREATE INDEX IF NOT EXISTS idx_error_events_severity ON error_events(severity);
CREATE INDEX IF NOT EXISTS idx_error_events_created ON error_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_events_unresolved ON error_events(is_resolved) WHERE is_resolved = false;

CREATE INDEX IF NOT EXISTS idx_api_metrics_endpoint ON api_metrics(endpoint);
CREATE INDEX IF NOT EXISTS idx_api_metrics_created ON api_metrics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_metrics_user ON api_metrics(user_id);

CREATE INDEX IF NOT EXISTS idx_api_metrics_hourly_time ON api_metrics_hourly(hour_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_api_metrics_hourly_endpoint ON api_metrics_hourly(endpoint);

-- RLS Policies

-- Support tickets: Platform roles can see all, org members can see their own org's tickets
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles read all support tickets') THEN
    CREATE POLICY "Platform roles read all support tickets"
      ON support_tickets FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles manage support tickets') THEN
    CREATE POLICY "Platform roles manage support tickets"
      ON support_tickets FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Org members read own org tickets') THEN
    CREATE POLICY "Org members read own org tickets"
      ON support_tickets FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM org_members m
          WHERE m.org_id = support_tickets.org_id
          AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users create own tickets') THEN
    CREATE POLICY "Users create own tickets"
      ON support_tickets FOR INSERT
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Impersonation log: Only platform roles can access
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles read impersonation log') THEN
    CREATE POLICY "Platform roles read impersonation log"
      ON impersonation_log FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles manage impersonation log') THEN
    CREATE POLICY "Platform roles manage impersonation log"
      ON impersonation_log FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;
END $$;

-- Active sessions: Platform roles see all, users see their own
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles read all sessions') THEN
    CREATE POLICY "Platform roles read all sessions"
      ON active_sessions FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users manage own sessions') THEN
    CREATE POLICY "Users manage own sessions"
      ON active_sessions FOR ALL
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Error events: Only platform roles can access
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles read error events') THEN
    CREATE POLICY "Platform roles read error events"
      ON error_events FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Platform roles manage error events') THEN
    CREATE POLICY "Platform roles manage error events"
      ON error_events FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('developer', 'techSupport', 'superAdmin')
        )
      );
  END IF;

  -- Allow any authenticated user to insert error events (for error reporting)
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users insert errors') THEN
    CREATE POLICY "Authenticated users insert errors"
      ON error_events FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

-- API metrics: Only developers can access
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Developers read api metrics') THEN
    CREATE POLICY "Developers read api metrics"
      ON api_metrics FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role = 'developer'
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Developers read api metrics hourly') THEN
    CREATE POLICY "Developers read api metrics hourly"
      ON api_metrics_hourly FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role = 'developer'
        )
      );
  END IF;

  -- Allow service role to insert metrics (from edge functions)
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service role insert api metrics') THEN
    CREATE POLICY "Service role insert api metrics"
      ON api_metrics FOR INSERT
      WITH CHECK (true);
  END IF;
END $$;

-- Function to log impersonation start
CREATE OR REPLACE FUNCTION log_impersonation_start(
  p_emulated_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO impersonation_log (emulator_id, emulated_user_id, reason)
  VALUES (auth.uid(), p_emulated_user_id, p_reason)
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

-- Function to log impersonation end
CREATE OR REPLACE FUNCTION log_impersonation_end(
  p_log_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE impersonation_log
  SET ended_at = now()
  WHERE id = p_log_id
  AND emulator_id = auth.uid()
  AND ended_at IS NULL;
END;
$$;

-- Function to update session activity
CREATE OR REPLACE FUNCTION update_session_activity(
  p_session_id uuid,
  p_route text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE active_sessions
  SET
    last_activity_at = now(),
    current_route = COALESCE(p_route, current_route)
  WHERE id = p_session_id
  AND user_id = auth.uid()
  AND is_active = true;
END;
$$;

-- Function to end a session
CREATE OR REPLACE FUNCTION end_user_session(
  p_session_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE active_sessions
  SET
    is_active = false,
    ended_at = now()
  WHERE id = p_session_id
  AND user_id = auth.uid();
END;
$$;

-- Function to start a new session
CREATE OR REPLACE FUNCTION start_user_session(
  p_device_info text DEFAULT NULL,
  p_user_agent text DEFAULT NULL,
  p_ip_address text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session_id uuid;
  v_user_id uuid := auth.uid();
  v_org_id uuid;
BEGIN
  -- Get user's org_id
  SELECT org_id INTO v_org_id
  FROM profiles
  WHERE id = v_user_id;

  -- End any existing active sessions for this user
  UPDATE active_sessions
  SET is_active = false, ended_at = now()
  WHERE user_id = v_user_id AND is_active = true;

  -- Create new session
  INSERT INTO active_sessions (user_id, org_id, device_info, user_agent, ip_address)
  VALUES (v_user_id, v_org_id, p_device_info, p_user_agent, p_ip_address)
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

-- Function to report an error
CREATE OR REPLACE FUNCTION report_error(
  p_error_type text,
  p_error_message text,
  p_stack_trace text DEFAULT NULL,
  p_severity text DEFAULT 'error',
  p_route text DEFAULT NULL,
  p_device_info text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_error_id uuid;
  v_user_id uuid := auth.uid();
  v_org_id uuid;
BEGIN
  -- Get user's org_id if logged in
  IF v_user_id IS NOT NULL THEN
    SELECT org_id INTO v_org_id
    FROM profiles
    WHERE id = v_user_id;
  END IF;

  -- Check for existing similar error in last 24 hours
  SELECT id INTO v_error_id
  FROM error_events
  WHERE error_type = p_error_type
  AND error_message = p_error_message
  AND is_resolved = false
  AND last_seen_at > now() - interval '24 hours'
  LIMIT 1;

  IF v_error_id IS NOT NULL THEN
    -- Increment occurrence count
    UPDATE error_events
    SET
      occurrence_count = occurrence_count + 1,
      last_seen_at = now()
    WHERE id = v_error_id;
  ELSE
    -- Insert new error
    INSERT INTO error_events (
      org_id, user_id, error_type, error_message, stack_trace,
      severity, route, device_info
    )
    VALUES (
      v_org_id, v_user_id, p_error_type, p_error_message, p_stack_trace,
      p_severity, p_route, p_device_info
    )
    RETURNING id INTO v_error_id;
  END IF;

  RETURN v_error_id;
END;
$$;
