-- Billing information table for organizations
-- Stores billing address and payment method details separately from org info

CREATE TABLE IF NOT EXISTS billing_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,

  -- Billing contact
  billing_email text NOT NULL,
  billing_name text,  -- Company name or contact name for billing

  -- Billing address (may differ from org address)
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country text DEFAULT 'US',

  -- Tax information
  tax_id text,  -- EIN, VAT, etc.
  tax_exempt boolean NOT NULL DEFAULT false,

  -- Purchase order support
  po_number text,
  po_required boolean NOT NULL DEFAULT false,

  -- Payment method info (from Stripe)
  stripe_payment_method_id text,
  payment_method_type text,  -- 'card', 'bank_account', etc.
  payment_method_last4 text,
  payment_method_brand text,  -- 'visa', 'mastercard', etc.
  payment_method_exp_month integer,
  payment_method_exp_year integer,

  -- Metadata
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  -- Each org has one billing info record
  UNIQUE (org_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_billing_info_org_id ON billing_info(org_id);
CREATE INDEX IF NOT EXISTS idx_billing_info_stripe_payment_method ON billing_info(stripe_payment_method_id);

-- Enable RLS
ALTER TABLE billing_info ENABLE ROW LEVEL SECURITY;

-- Only admins can view billing info
CREATE POLICY "Admins can view billing info"
  ON billing_info FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = billing_info.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );

-- Only admins can update billing info
CREATE POLICY "Admins can update billing info"
  ON billing_info FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = billing_info.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );

-- Only admins can insert billing info
CREATE POLICY "Admins can insert billing info"
  ON billing_info FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = billing_info.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );

-- Invoice history table
CREATE TABLE IF NOT EXISTS invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,

  -- Stripe invoice info
  stripe_invoice_id text UNIQUE,
  stripe_invoice_number text,
  stripe_invoice_url text,
  stripe_invoice_pdf text,

  -- Invoice details
  amount_due integer NOT NULL,  -- in cents
  amount_paid integer NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'usd',
  status text NOT NULL,  -- draft, open, paid, void, uncollectible

  -- Period
  period_start timestamptz,
  period_end timestamptz,

  -- Dates
  due_date timestamptz,
  paid_at timestamptz,

  -- Metadata
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invoices_org_id ON invoices(org_id);
CREATE INDEX IF NOT EXISTS idx_invoices_stripe_invoice_id ON invoices(stripe_invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);

-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Only admins can view invoices
CREATE POLICY "Admins can view invoices"
  ON invoices FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM org_members om
      WHERE om.org_id = invoices.org_id
        AND om.user_id = auth.uid()
        AND om.role IN ('owner', 'admin')
    )
  );
