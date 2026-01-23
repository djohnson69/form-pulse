-- Migration: Add demo vendors for "Your Company" organization
-- These are vendor companies that the demo org works with

INSERT INTO vendors (
  id,
  org_id,
  company_name,
  contact_name,
  email,
  phone_number,
  address,
  website,
  service_category,
  certifications,
  is_active,
  created_at
) VALUES
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111111',
    'Acme Supply Co.',
    'John Acme',
    'contact@acmesupply.test',
    '+1-555-111-1111',
    '100 Industrial Way, Chicago, IL 60601',
    'https://acmesupply.test',
    'General Supplies',
    ARRAY['ISO 9001', 'OSHA Certified'],
    true,
    NOW()
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '11111111-1111-1111-1111-111111111111',
    'BuildRight Materials',
    'Sarah Builder',
    'orders@buildright.test',
    '+1-555-222-2222',
    '500 Construction Blvd, Denver, CO 80201',
    'https://buildright.test',
    'Construction Materials',
    ARRAY['LEED Certified', 'Green Building Council'],
    true,
    NOW()
  ),
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '11111111-1111-1111-1111-111111111111',
    'TechParts Inc.',
    'Mike Tech',
    'sales@techparts.test',
    '+1-555-333-3333',
    '200 Silicon Drive, Austin, TX 78701',
    'https://techparts.test',
    'Electronic Components',
    ARRAY['UL Listed', 'RoHS Compliant'],
    true,
    NOW()
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '11111111-1111-1111-1111-111111111111',
    'SafetyFirst Equipment',
    'Lisa Safety',
    'info@safetyfirst.test',
    '+1-555-444-4444',
    '300 Protection Lane, Seattle, WA 98101',
    'https://safetyfirst.test',
    'Safety Equipment',
    ARRAY['ANSI Certified', 'NIOSH Approved'],
    true,
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  company_name = EXCLUDED.company_name,
  contact_name = EXCLUDED.contact_name,
  email = EXCLUDED.email,
  phone_number = EXCLUDED.phone_number,
  address = EXCLUDED.address,
  website = EXCLUDED.website,
  service_category = EXCLUDED.service_category,
  certifications = EXCLUDED.certifications,
  is_active = EXCLUDED.is_active;
