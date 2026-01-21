-- Enhance orgs table with enterprise company information
-- Adds industry, company size, contact details, branding, etc.

-- Add new columns to orgs table
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS industry text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS company_size text;  -- '1-10', '11-50', '51-200', '201-500', '501-1000', '1000+'
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS website text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS logo_url text;

-- Address fields
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS address_line1 text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS address_line2 text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS postal_code text;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS country text DEFAULT 'US';

-- Tax information
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS tax_id text;  -- EIN, VAT number, etc.

-- Onboarding status
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS onboarding_step integer NOT NULL DEFAULT 0;

-- Settings and metadata
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS settings jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE orgs ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_orgs_industry ON orgs(industry);
CREATE INDEX IF NOT EXISTS idx_orgs_company_size ON orgs(company_size);
CREATE INDEX IF NOT EXISTS idx_orgs_onboarding_completed ON orgs(onboarding_completed);

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_orgs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS orgs_updated_at_trigger ON orgs;
CREATE TRIGGER orgs_updated_at_trigger
  BEFORE UPDATE ON orgs
  FOR EACH ROW
  EXECUTE FUNCTION update_orgs_updated_at();

-- Industries enum reference (stored as text for flexibility)
COMMENT ON COLUMN orgs.industry IS 'Industry categories: technology, healthcare, manufacturing, construction, retail, finance, education, government, nonprofit, hospitality, transportation, agriculture, energy, media, legal, real_estate, professional_services, other';

-- Company size enum reference
COMMENT ON COLUMN orgs.company_size IS 'Company size ranges: 1-10, 11-50, 51-200, 201-500, 501-1000, 1000+';
